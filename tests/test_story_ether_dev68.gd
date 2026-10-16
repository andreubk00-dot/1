extends SceneTree
# dev68: «ЭФИР» - the narrative thread (docs/STORY_ETHER.md). Every trace is in
# the world on free floor and readable; reading it goes into the chronicle;
# Лёнька tells it as it goes; the soft hint walks the thread and goes quiet when
# it is done; the console at the deep core asks, and each answer has its effect
# on the settlements and the roads; the region's ending hears it; it is saved.
# Narrative only: no trace hands out items.
const Main = preload("res://main_script_mod.gd")
const StoryEther = preload("res://world/story_ether.gd")
const WorldChronicle = preload("res://world/world_chronicle.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func _static_rects(node: Node, out: Array) -> void:
    for child in node.get_children():
        if child is StaticBody2D:
            for sh in child.get_children():
                if sh is CollisionShape2D and sh.shape is RectangleShape2D:
                    out.append(Rect2(sh.global_position - sh.shape.size * 0.5, sh.shape.size))
        _static_rects(child, out)

func _find_note(root: Node, story_id: String):
    for n in root.find_children("*", "Node2D", true, false):
        if str(n.get_meta("story_id", "")) == story_id:
            return n
    return null

func _on_free_floor(chunk: Node, node: Node2D) -> bool:
    var rects = []
    _static_rects(chunk, rects)
    var box = Rect2(node.global_position - Vector2(6, 6), Vector2(12, 12))
    for r in rects:
        if r.intersects(box):
            return false
    return true

func run():
    # the catalogue: unique, short enough for the chronicle, the tag ties it
    var ids = StoryEther.trace_ids()
    var seen_ids = {}
    for id in ids:
        check(not seen_ids.has(id) and str(id).begins_with("ether_"), "trace id duplicated or misnamed: " + str(id))
        seen_ids[id] = true
    var all_notes = StoryEther.NOTES.values() + [StoryEther.COLUMN_NOTE]
    for n in all_notes + [StoryEther.VOICE, StoryEther.SOURCE]:
        var line = "%s — %s" % [n["title"], n["text"]]
        check(line.length() <= WorldChronicle.TEXT_LIMIT, "trace too long for the chronicle: %s (%d)" % [n["id"], line.length()])
        for forbidden in ["reward", "items", "loot", "route", "objective"]:
            check(not n.has(forbidden), "a trace hands out " + forbidden)
    check(str(StoryEther.NOTES["0,0"]["text"]).find(StoryEther.TAG) >= 0 and str(StoryEther.COLUMN_NOTE["text"]).find(StoryEther.TAG) >= 0, "the evacuation tag does not tie the start to the column")
    var convoy_profile = RegionCatalog.chunk_profile(StoryEther.COLUMN_NOTE["coord"])
    var convoy_event = EncounterCatalog.event_for(StoryEther.COLUMN_NOTE["coord"], str(convoy_profile.get("zone", "")), int(convoy_profile.get("risk", 2)), str(convoy_profile.get("poi_id", "")))
    check(str(convoy_event.get("id", "")) == str(StoryEther.COLUMN_NOTE["event_id"]), "the column's wreck is not where its note waits")

    var game = Main.new()
    root.add_child(game)
    await frames(6)
    game.developer_invulnerable = true
    var seen = func(id): return WorldChronicle.story_seen(game.faction_state, id)

    # the hint walks the thread from the start
    check(StoryEther.hint(seen, "") == StoryEther.HINTS[0][1], "the thread does not start at the radio man")

    # every placed note is in the world, on free floor, and reads into the chronicle
    var coords = []
    for key in StoryEther.NOTES.keys():
        var parts = key.split(",")
        coords.append([Vector2i(int(parts[0]), int(parts[1])), str(StoryEther.NOTES[key]["id"])])
    coords.append([StoryEther.COLUMN_NOTE["coord"], str(StoryEther.COLUMN_NOTE["id"])])
    for row in coords:
        var coord: Vector2i = row[0]
        game.player.global_position = Vector2(coord) * game.CHUNK_SIZE + Vector2(384, 384)
        game._refresh_chunks(true)
        await frames(4)
        var chunk = game.loaded_chunks.get(coord)
        check(chunk != null, "chunk not loaded for " + row[1])
        if chunk == null:
            continue
        var note = _find_note(chunk, row[1])
        check(note != null, "trace not in the world: " + row[1])
        if note == null:
            continue
        check(_on_free_floor(chunk, note), "trace lies in a solid: " + row[1])
        check(note.is_in_group("interactable") and str(note.get_meta("interaction_type")) == "story_clue", "trace cannot be read: " + row[1])
        var inv_before = game.inventory_entries.size()
        game._read_story_clue(note)
        check(bool(seen.call(row[1])), "reading did not record: " + row[1])
        check(game.inventory_entries.size() == inv_before, "a trace handed out an item: " + row[1])

    # Лёнька: the voice beat on the first talk, his line follows the thread
    var lenka = Node2D.new()
    lenka.set_meta("npc_id", "perron_radio")
    lenka.set_meta("faction_id", "perron")
    lenka.set_meta("display_name", "Лёнька")
    lenka.set_meta("npc_role", "радист")
    game.add_child(lenka)
    game._talk_faction_npc(lenka)
    check(bool(seen.call(StoryEther.VOICE["id"])), "talking to Лёнька did not let the survivor hear the voice")
    check(StoryEther.lenka_line(seen, "") == StoryEther.LENKA["relay"], "Лёнька does not follow the thread")
    check(StoryEther.hint(seen, "") == "Источник эфира — объект «Вектор», глубина −3", "the hint does not point to the source")

    # the console at the deep core
    var poi = RegionCatalog.poi_by_id(StoryEther.CONSOLE_POI)
    var ground = Vector2(poi["coord"]) * game.CHUNK_SIZE + Vector2(384, 384)
    check(game._enter_high_risk_floor(StoryEther.CONSOLE_POI, 3, ground, Vector2(999999, 999999), 2), "cannot reach the deep core")
    await frames(4)
    var console = null
    if game.high_risk_floor_root != null:
        for n in game.high_risk_floor_root.find_children("*", "Node2D", true, false):
            if str(n.get_meta("interaction_type", "")) == "ether_console":
                console = n
    check(console != null, "no broadcast console at the deep core")
    if console != null:
        check(_on_free_floor(game.high_risk_floor_root, console), "the console stands in a solid")
    var dsec = {}
    for fid in ["perron", "rubezh", "mechanics", "lazaret"]:
        dsec[fid] = float(game.faction_state["factions"][fid]["resources"]["security"])
    game._open_ether_console()
    await process_frame
    var dialog = game.get_tree().root.get_node_or_null("StoryDialog")
    check(dialog != null and dialog.buttons.size() == 3, "the console does not ask")
    check(bool(seen.call(StoryEther.SOURCE["id"])), "reaching the console did not record the source")
    check(game.get_tree().paused, "the world does not wait while deciding")
    # leaving it as it is changes nothing
    if dialog != null:
        dialog.buttons[2].emit_signal("pressed")
    await process_frame
    check(not game.get_tree().paused and str(game.story_ether["choice"]) == "", "leaving the console changed the world")
    # the truth
    game._open_ether_console()
    await process_frame
    dialog = game.get_tree().root.get_node_or_null("StoryDialog")
    if dialog != null:
        dialog.buttons[0].emit_signal("pressed")
    await process_frame
    check(str(game.story_ether["choice"]) == "truth", "the truth was not broadcast")
    for fid in dsec.keys():
        var now = float(game.faction_state["factions"][fid]["resources"]["security"])
        check(now > float(dsec[fid]), "the truth did not reach " + fid)
    check(game.ether_roaming_factor() < 1.0, "the truth does not thin the raiders' easy prey")
    check(StoryEther.hint(seen, "truth") == "", "the thread still nags after it ended")
    check(StoryEther.lenka_line(seen, "truth") == StoryEther.LENKA["truth"], "Лёнька did not hear the new voice")
    check(game._ending_text_with_ether("ИТОГ.").find(StoryEther.CHOICES["truth"]["epilogue"]) > 0, "the ending does not hear the broadcast")
    game._open_ether_console()
    await process_frame
    check(game.get_tree().root.get_node_or_null("StoryDialog") == null, "the console asks twice")

    # saved
    game._exit_high_risk_floor()
    await frames(2)
    game._save_state()
    var g2 = Main.new()
    root.add_child(g2)
    await frames(5)
    check(str(g2.story_ether["choice"]) == "truth", "the broadcast choice was not saved")
    g2.queue_free()
    await frames(2)

    # silence, on a clean thread
    game.story_ether = StoryEther.default_state()
    game._ether_choose("silence")
    check(str(game.story_ether["choice"]) == "silence" and game.ether_roaming_factor() == 1.0, "silence does not end the thread quietly")
    check(StoryEther.epilogue("silence") != StoryEther.epilogue("truth"), "silence and the truth end alike")
    check(StoryEther.epilogue("") == StoryEther.UNCHANGED_EPILOGUE, "a region that never answered has no closing line")

    print("STORY ETHER dev68: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
