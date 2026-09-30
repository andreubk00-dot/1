extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", message)

func _initialize():
    call_deferred("run")

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    # World balance may know where loot belongs, but item metadata shown to players
    # must not contain an explicit source route.
    for raw_id in game.item_defs.keys():
        var id = str(raw_id)
        check(not game.item_defs[id].has("source_hint"), "source hint leaked into item metadata: " + id)

    game._create_inventory_ui()
    game._create_hover_inspector()
    game._hover_show_item("akm",1,"storage")
    var weapon_tip = str(game.hover_body.text)
    check(weapon_tip.find("Искать:") < 0, "weapon tooltip tells player where to find loot")
    check(weapon_tip.find("риск 5+") < 0, "weapon tooltip exposes hidden acquisition tier")
    check(weapon_tip.find("СПЕЦИАЛИЗИРОВАННОЕ") >= 0, "rarity itself should remain visible")

    game._create_region_map_ui()
    var bastion = Vector2i(4,5)
    game.discovered_chunks[game._zone_chunk_key(bastion)] = true
    game.discovered_pois["reserve_arsenal_bastion"] = true
    var tip = game._region_map_cell_tooltip(bastion)
    check(tip.find("ОПАСНОСТЬ 5/5") >= 0, "discovered danger rating should remain visible")
    for forbidden in ["АРСЕНАЛ CORE","ВНУТРЕННИЙ АРСЕНАЛ","Целевая добыча","восстановление","профиль"]:
        check(tip.find(forbidden) < 0, "map cell tooltip leaks loot/farm guidance: " + forbidden)

    game.region_map_selected_chunk = bastion
    game._refresh_region_map_ui()
    var map_text = str(game.region_map_detail_label.text)
    check(map_text.find("Опасность: 5/5") >= 0, "map detail lost discovered danger")
    for forbidden in ["профиль:","Целевая добыча","Рекомендуется:","Вход: БЕЗ","ВНУТРЕННИЙ АРСЕНАЛ","после полной выборки"]:
        check(map_text.find(forbidden) < 0, "map detail leaks discovery solution: " + forbidden)
    check(not game.region_map_readiness_label.visible, "map should not grade the player's loadout")
    var readiness = game._expedition_readiness()
    check(not readiness.has("score") and not readiness.has("total"), "readiness must not become a gear score")
    for forbidden in ["БАСТИОН","КАРАНТИН","Искать:","добыть","Рекомендуется:","профиль добычи","шанс"]:
        check(str(readiness.get("text","")).find(forbidden) < 0, "readiness leaks acquisition guidance: " + forbidden)

    game._create_home_journal_ui()
    game.current_chunk = Vector2i.ZERO
    game.roof_records[0]["building_key"] = "0:0:home"
    game.roof_records[0]["building_name"] = "ДОМ"
    game.roof_records[0]["chunk_coord"] = Vector2i.ZERO
    game._claim_current_home()
    game.base_objects.append({"id":2,"kind":"stash","x":20.0,"y":0.0})
    game.container_states["base_stash_2"] = {"name":"Домашний ящик","items":[]}
    game.expedition_active = true
    game.expedition_target_chunk = bastion
    game.expedition_target_name = "АРСЕНАЛ «БАСТИОН»"
    game.expedition_journal["supply_preset"] = 0
    game._open_home_journal()
    var preparation_text = str(game.home_preparation_text.text)
    check(preparation_text.find("САМОПРОВЕРКА ПЕРЕД ВЫХОДОМ") >= 0, "home journal lost neutral readiness facts")
    check(preparation_text.find("БАСТИОН") < 0, "home readiness leaks selected target")
    game._toggle_home_supply_view()
    var supply_text = str(game.home_report_text.text)
    check(supply_text.find("Выбранный комплект: КОРОТКИЙ ВЫХОД") >= 0, "manual supply preset should remain visible")
    check(supply_text.find("Рекомендуется:") < 0, "home supply recommends loadout from destination")
    check(supply_text.find("БАСТИОН") < 0, "home supply reveals target-specific preparation advice")
    check(supply_text.find("риск 5/5") < 0, "home supply reveals target risk as preparation advice")

    # The player keeps manual map-note tools to record knowledge earned through play.
    check(game.map_marker_kind.get_item_count() == 4, "manual map marker palette changed")
    var marker_names = []
    for i in range(game.map_marker_kind.get_item_count()):
        marker_names.append(game.map_marker_kind.get_item_text(i))
    check(marker_names == ["ОПАСНОСТЬ","ТАЙНИК","ВОДА","ЗАМЕТКА"], "manual map notes are incomplete")

    game.free()
    print("DISCOVERY PROGRESSION: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
