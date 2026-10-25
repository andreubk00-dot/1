extends RefCounted
# dev75: presentation only. Gameplay values and actions remain owned by Main.

static func apply(g):
    # Reduce occupied area through layout, preserving native text pixels.
    var vitals = g.hud_world_root.get_node_or_null("VitalsPanel")
    if vitals != null:
        for c in vitals.get_children():
            c.visible = false
        vitals.size = Vector2(132,94)
        var keys = ["health","stamina","hunger","thirst","temperature","infection","fatigue"]
        for i in range(keys.size()):
            var key = keys[i]
            var y = 8 + i * 12
            var icon = g._hud_make_status_texture_icon(vitals,"psyche" if key=="fatigue" else key,Vector2(6,y-1),Vector2(10,10))
            if icon != null: icon.visible = true
            var bar = g.hud_vital_bars[key]
            bar.position = Vector2(22,y)
            bar.visible = true
            var value = g.hud_vital_values[key]
            value.position = Vector2(87,y-2)
            value.size = Vector2(40,11)
            value.visible = true
    g.hud_condition_label.position = Vector2(8,94)
    g.hud_condition_label.size = Vector2(116,12)
    g.hud_condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    g.equipment_info.add_theme_font_size_override("font_size",7)
    g.equipment_info.add_theme_constant_override("line_spacing",0)
    var weapon = g.hud_world_root.get_node_or_null("WeaponPanel")
    if weapon != null:
        weapon.size.y = 54
        weapon.position.y = 298
        for c in weapon.get_children():
            if c is CanvasItem and c.get("position") != null and c.position.y >= 54:
                c.visible = false
        g.hud_weapon_art_frame.visible = false
        g.hud_weapon_art_frame.position = Vector2(9,21)
        g.hud_weapon_art_frame.size = Vector2(42,12)
        g.hud_weapon_condition_bar.position.y = 36
        g.hud_weapon_condition_bar.visible = true
        g.hud_weapon_condition_label.position.y = 34
        g.hud_weapon_condition_label.visible = true
        g.hud_weapon_condition_value_label.position.y = 34
        g.hud_weapon_condition_value_label.visible = true
        g.hud_reload_label.visible = false
        g.hud_weapon_mode_label.visible = false
    var stealth = g.hud_world_root.get_node_or_null("StealthPanel")
    if stealth != null:
        stealth.size.y = 44
        stealth.position.y = 308
        for c in stealth.get_children():
            if c is CanvasItem and c.get("position") != null and c.position.y >= 42:
                c.visible = false
    var shell = g.hud_world_root.get_node_or_null("QuickShell")
    if shell != null:
        shell.size = Vector2(210,42)
        var quick_root = shell.get_node("QuickBar")
        quick_root.size = Vector2(198,32)
        for c in quick_root.get_children():
            if not (c is Button): c.visible = false
        for i in range(g.hud_quick_slots.size()):
            var slot = g.hud_quick_slots[i]
            slot.button.position = Vector2(i*33,0)
            slot.button.size = Vector2(32,32)
            slot.back.size = Vector2(26,16)
            slot.rail.position = Vector2(3,28)
            slot.rail.size = Vector2(26,2)
            g._hud_fit_texture_rect(slot.icon,g._hud_display_texture(str(slot.id)),Vector2(3,11),Vector2(26,15))
    var env = g.hud_world_root.get_node_or_null("EnvironmentPanel")
    if env != null:
        env.size.y = 63
        for c in env.get_children():
            if c is CanvasItem and c.get("position") != null and c.position.y >= 63:
                c.visible = false
    # Keep inspection available, while everyday play shows the time, weather,
    # location, vitals and loadout rather than the entire camp report.
    for panel in [g.hud_world_root.get_node_or_null("VitalsPanel"),env]:
        if panel != null: panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var theme = Theme.new()
    theme.set_font_size("font_size","TooltipLabel",7)
    for layer in g.get_children():
        if layer is CanvasLayer:
            for c in layer.get_children():
                if c is Control: c.theme = theme
    for panel in [g.base_build_panel,g.rest_panel,g.mod_panel]:
        if panel != null:
            panel.scale = Vector2.ONE * 0.82
            panel.position = Vector2(640,360) - panel.size * panel.scale - Vector2(12,12)
    for panel in [g.trader_panel,g.contract_panel,g.craft_panel,g.home_journal_panel]:
        panel.scale = Vector2.ONE * 0.9
        panel.position = (Vector2(640,360)-panel.size*panel.scale)*0.5
    if g.base_build_panel != null:
        g.base_build_panel.size.y = 252
        for c in g.base_build_panel.get_children():
            if c is Label and c.position.y == 31:
                c.tooltip_text = c.text
                c.text = "Стройте выбранный объект рядом с собой."
                c.mouse_filter = Control.MOUSE_FILTER_STOP
            elif c is Button and c.text == "ЗАКРЫТЬ":
                c.position.y = 216
        g.base_build_panel.position = Vector2(640,360)-g.base_build_panel.size*g.base_build_panel.scale-Vector2(12,12)
    # Costs belong to the selected build action, not a permanent wall of text.
    if g.base_build_status != null:
        g.base_build_status.visible = false
    var build_ids = {"ЯЩИК":"stash","ОБОГРЕВ":"heater","ЛАМПА":"lamp","РАСКЛАДУШКА":"cot","БАРРИКАДА":"barricade","КОСТЁР":"campfire","ДОЖДЕСБОР":"rain_collector"}
    if g.base_build_panel != null:
        for c in g.base_build_panel.get_children():
            if c is Button and build_ids.has(c.text):
                c.set_meta("build_kind",build_ids[c.text])
                c.icon = load("res://art/interface/"+str(build_ids[c.text])+".svg")
                c.expand_icon = true
                c.add_theme_constant_override("icon_max_width",15)
    for label in [g.region_map_coord_label,g.region_map_readiness_label,g.region_map_active_label]:
        if label != null: label.visible = false
    if g.region_map_detail_label != null:
        g.region_map_detail_label.mouse_filter = Control.MOUSE_FILTER_STOP
    for pair in [[g.trader_panel,"trader"],[g.contract_panel,"contract"]]:
        var talk = LinkButton.new()
        talk.name = "TalkToResident"
        talk.text = "Поговорить"
        talk.position = Vector2(440,42)
        talk.size = Vector2(104,16)
        talk.add_theme_font_size_override("font_size",7)
        talk.tooltip_text = "Спросить о жизни поселения и последних событиях"
        talk.pressed.connect(g._talk_from_service_panel.bind(str(pair[1])))
        pair[0].add_child(talk)
    g.trader_subtitle.size.x = 410
    g.hud_world_root.set_meta("ui_polish_ready",true)
    refresh(g)

static func refresh(g):
    if not g.hud_world_root.has_meta("ui_polish_ready"): return
    var shell = g.hud_world_root.get_node_or_null("QuickShell")
    if shell != null:
        var editing = g._inventory_item_action_mode()
        shell.visible = not g.inventory_open or editing
        shell.position = Vector2(215,83 if editing else 310)
        shell.set_meta("ui_pivot_screen",Vector2(320,104 if editing else 352))
        g._hud_scale_pivot(shell)
    if g.get_node_or_null("NpcChat") != null and g.hud_feedback_panel != null:
        g.hud_feedback_panel.visible = false
    var env = g.hud_world_root.get_node_or_null("EnvironmentPanel")
    var vitals = g.hud_world_root.get_node_or_null("VitalsPanel")
    if vitals != null:
        var condition = g._hud_compact_condition_text()
        g.hud_condition_label.visible = condition != "СТАБИЛЬНО"
        vitals.size.y = 110 if g.hud_condition_label.visible else 94
        g._hud_set_fitted_text(g.hud_condition_label,condition,6,5)
        g._hud_font_color(g.hud_condition_label,Color("e08069"))
        vitals.tooltip_text = "Кровотечение: %s · боль %s\nСырость %s · загрязнение раны %s" % ["есть" if g.bleeding else "нет",g.hud_condition_values.pain.text,g.hud_condition_values.wet.text,g.hud_condition_values.contam.text]
    var weapon = g.hud_world_root.get_node_or_null("WeaponPanel")
    if weapon != null:
        weapon.mouse_filter = Control.MOUSE_FILTER_STOP
        weapon.tooltip_text = g.hud_reload_label.text+"\n"+g.hud_weapon_mode_label.text
    var stealth = g.hud_world_root.get_node_or_null("StealthPanel")
    if stealth != null:
        stealth.mouse_filter = Control.MOUSE_FILTER_STOP
        stealth.tooltip_text = "Груз: "+g.hud_weight_label.text
    if env != null:
        env.tooltip_text = "%s\n%s\n%s\n%s" % [g.hud_env_shelter_label.text,g.hud_env_camp_label.text,g.hud_objective_label.text,g.hud_objective_sub_label.text]
    var names = {"health":"Здоровье","stamina":"Выносливость с учётом доступного предела","hunger":"Сытость: 100 — сыт, 0 — голодание","thirst":"Запас воды: 100 — напился, 0 — обезвоживание","temperature":"Температура тела; норма около 36–37,5 °C","infection":"Инфекция раны: меньше — лучше","fatigue":"Усталость: меньше — лучше"}
    for key in g.hud_vital_bars:
        var bar = g.hud_vital_bars[key]
        if bar != null:
            bar.mouse_filter = Control.MOUSE_FILTER_STOP
            bar.tooltip_text = str(names.get(key,key))+"\n"+g.hud_vital_values[key].text
    if g.region_map_detail_label != null:
        var l = g.region_map_detail_label
        if l.text != str(l.get_meta("compact_text","")):
            l.tooltip_text = l.text
            var lines = l.text.split("\n")
            l.text = "\n".join(lines.slice(0,3))
            l.set_meta("compact_text",l.text)
    if g.trader_panel.visible:
        var l = g.trader_subtitle
        if l.text != str(l.get_meta("compact_text","")):
            l.tooltip_text = l.text
            var faction = str(g.TraderCatalog.trader(g.active_trader_id).get("faction",""))
            var reputation = g.FactionEconomy.reputation(g.faction_state,faction)
            l.text = "Талоны: %d · Доверие: %s" % [int(g.faction_state.get("currency_tickets",0)),str(g.FactionCatalog.reputation_tier(reputation).get("name","ЧУЖОЙ"))]
            var crisis = g.SettlementCrisis.summary(g.faction_state,faction,g.world_day)
            if faction != "" and crisis.begins_with("КРИЗИС"):
                l.text += "\n"+crisis.split(" • ")[0]+" • "+crisis.split(" • ")[1]
            l.mouse_filter = Control.MOUSE_FILTER_STOP
            l.set_meta("compact_text",l.text)
    if g.home_journal_open and not g.home_supply_view and not g.home_defense_view:
        var l = g.home_preparation_text
        if l.text != str(l.get_meta("compact_text","")):
            l.tooltip_text = l.text
            var facts = g._expedition_readiness().get("facts",{})
            l.text = "ПЕРЕД ВЫХОДОМ\nПитьё: %.1f л • еда: %d\nПеревязка: %d • оружие: %s\nСвободно: %.1f кг" % [float(facts.get("water_liters",0)),int(facts.get("food",0)),int(facts.get("medical",0)),"готово" if facts.get("defense_ready",false) else "проверьте",float(facts.get("free_weight",0))]
            if not facts.get("clothing_ok",false): l.text += "\nПроверьте одежду."
            if not facts.get("condition_ok",false): l.text += "\nСамочувствие требует внимания."
            if not facts.get("weight_ok",false): l.text += "\nРюкзак почти полон."
            l.mouse_filter = Control.MOUSE_FILTER_STOP
            l.set_meta("compact_text",l.text)
    if g.base_build_panel != null and g.base_build_panel.visible:
        for c in g.base_build_panel.get_children():
            if c is Button and c.has_meta("build_kind"):
                c.tooltip_text = c.text+"\n"+g._base_cost_text(str(c.get_meta("build_kind")))

static func talk_from_panel(g,kind:String):
    var id = g.active_contract_npc_id if kind=="contract" else str(g.TraderCatalog.trader(g.active_trader_id).get("npc_id",""))
    for actor in g.get_tree().get_nodes_in_group("faction_npcs"):
        if str(actor.get_meta("npc_id","")) == id:
            if kind=="contract": g._close_contract_board()
            else: g._close_trader()
            g._talk_faction_npc(actor)
            return
    g._set_survival_feedback("Собеседник отошёл. Подойдите к нему, чтобы поговорить.",2.0)
