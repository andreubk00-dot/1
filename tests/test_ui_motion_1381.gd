extends SceneTree
const Main = preload("res://main_script_mod.gd")
const Banter = preload("res://world/npc_conversation.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func run():
    var g = Main.new()
    root.add_child(g)
    g.set_process(false)
    await process_frame
    # The same world-space mouse point must select the same item cell at any
    # UI scale, including a scaled parent and fractional placement.
    for sc in [0.5,0.68,0.82,1.0,1.1]:
        g.inventory_panel.scale = Vector2.ONE * sc
        for y in range(g.INV_H):
            for x in range(g.INV_W):
                var local = (Vector2(x,y)+Vector2(.5,.5))*g.CELL
                var screen = g.inv_grid_control.get_global_transform_with_canvas() * local
                check(g._grid_cell_from_mouse(g.inv_grid_control,screen)==Vector2i(x,y),"scaled mouse selected wrong cell")
    g.inventory_panel.scale = Vector2.ONE * .68
    # Every authored item and every gear icon fits its actual button.
    for id in g.item_defs:
        var b = Button.new()
        b.size = Vector2(48,32)
        g.inventory_panel.add_child(b)
        g._decorate_item_button(b,id,1)
        await process_frame
        for child in b.get_children():
            if child is TextureRect:
                check(Rect2(Vector2.ZERO,b.size).encloses(Rect2(child.position,child.size)),"item art overflow: "+id)
        b.free()
        if str(g.item_defs[id].get("category",""))=="gear":
            var gear = g.equipment_buttons["head"]
            g._decorate_equipment_button(gear,"head",id)
            await process_frame
            for child in gear.get_children():
                if child is TextureRect:
                    check(Rect2(Vector2.ZERO,gear.size).encloses(Rect2(child.position,child.size)),"equipment art overflow: "+id)
    g.quick_slot_ids = ["makarov","combat_knife","","","",""]
    check(g._assign_quick_slot(3,"bandage"),"cannot bind medicine")
    check(g._assign_quick_slot(4,"water"),"cannot bind water")
    check(g._assign_quick_slot(6,"bandage"),"cannot move consumable binding")
    check(g.quick_slot_ids[2]=="" and g.quick_slot_ids[5]=="bandage","hotbar move did not preserve the empty cell")
    g._clear_quick_slot(5)
    check(g._sanitize_quick_slot_ids(g.quick_slot_ids)[5]=="","empty binding restored a ghost weapon")
    # Drag a multi-cell object by its interior, keeping the grabbed cell under
    # the pointer instead of jumping its top-left corner to the release point.
    g.inventory_open = true
    g.inventory_panel.visible = true
    g.equipment_panel.visible = true
    g.inventory_entries = [{"id":"field_backpack","qty":1,"x":0,"y":0},{"id":"bandage","qty":2,"x":4,"y":0}]
    g._ensure_runtime_item_instance_ids()
    g.inventory_drag_active = true
    g.inventory_drag_candidate_source = "inventory"
    g.inventory_drag_candidate_index = 0
    g.inventory_drag_candidate_id = "field_backpack"
    g.inventory_drag_grab_cell = Vector2i(1,1)
    var drop = g.inv_grid_control.get_global_transform_with_canvas() * (Vector2(3.5,2.5)*g.CELL)
    g._finish_inventory_drag(drop)
    check(g.inventory_entries[0].x==2 and g.inventory_entries[0].y==1,"drag ignored grabbed item cell")
    check(g.inventory_entries.size()==2 and g.inventory_entries[1].qty==2,"drag changed item count")
    g._update_hud()
    var bar = g.hud_world_root.get_node("QuickShell")
    for slot in g.hud_quick_slots:
        check(not slot.button.disabled,"hotbar editing disabled for an empty cell")
        check(not slot.button.get_global_rect().intersects(g.inventory_panel.get_global_rect()),"inventory covers hotbar drop target")
        check(not slot.button.get_global_rect().intersects(g.equipment_panel.get_global_rect()),"equipment covers hotbar drop target")
    g.inventory_open = false
    g.hunger = 23.0
    g.thirst = 41.0
    g.health = 67.0
    g.fatigue = 84.0
    g.stamina = g._survival_stamina_cap() * .5
    g.wound_infection = 17.0
    g.body_temperature = 36.5
    g._update_hud()
    check(g.hud_vital_values.health.text=="67/100","health display diverged from game state")
    check(g.hud_vital_values.hunger.text=="23/100","food reserve displayed backwards")
    check(g.hud_vital_values.thirst.text=="41/100","hydration displayed backwards")
    check(g.hud_vital_values.stamina.text=="50/100","stamina ignored the effective cap")
    check(g.hud_vital_values.infection.text=="17%","infection display diverged")
    check(g.hud_vital_values.fatigue.text=="84%","fatigue display diverged")
    g.body_condition.legs = 100.0
    g.fatigue = 0.0
    g.health = 100.0
    g.body_temperature = 33.0
    for phase in [0.0,1.5,3.0]:
        check(g._body_state_offset(phase,0.0)==Vector2.ZERO,"cold still displaces the body")
    check(is_zero_approx(g._gait_phase_delta_for_distance(0,true)),"blocked movement advances the gait")
    for running in [false,true]:
        var full = g._gait_phase_delta_for_distance(g._gait_cycle_distance(running),running)
        check(abs(full-TAU)<.001,"travelled distance and gait cycle disagree")
    var pos = g.player.global_position
    g.aim_direction = Vector2.LEFT
    g._update_player_visuals(.016)
    var anchor = g.camera.global_position
    g.aim_direction = Vector2.RIGHT
    g._update_player_visuals(.016)
    check(anchor==g.camera.global_position,"aim rotates the entire world through camera lead")
    check(g.player.global_position==pos,"visual updates move the physical player")
    var npc = preload("res://world/marauder.gd").new()
    npc.setup(g,"bandit","makarov","neutral")
    g.add_child(npc)
    check(npc.lamp!=null,"NPC has no flashlight fixture")
    if npc.lamp!=null:
        for direction in range(8):
            npc.dir8 = direction
            npc.facing = Vector2.RIGHT.rotated(direction*PI/4)
            npc._update_lamp()
            var cone_dir = Vector2.RIGHT.rotated(npc.lamp.rotation)
            check(cone_dir.dot(npc.facing)>.999,"NPC flashlight points away from the body")
    npc.free()
    g._create_faction_npc(g,{"npc_id":"lazaret_doctor","faction_id":"lazaret","name":"Доктор Миронова","pos":Vector2(400,440)})
    g._open_contract_board("lazaret","Доктор Миронова","lazaret_doctor")
    g.contract_panel.get_node("TalkToResident").pressed.emit()
    check(not g.contract_open and g.get_node_or_null("NpcChat")!=null,"quest giver has no working conversation action")
    for id in Banter.LINES:
        for i in range(6): check(Banter.line(id,i)!=Banter.line(id,i+1),"NPC immediately repeats a line")
    g.bleeding = true
    g._update_hud()
    check(g.hud_condition_label.visible and g.hud_condition_label.text.contains("КРОВЬ"),"active bleeding is hidden behind a tooltip")
    g.bleeding = false
    g._update_hud()
    check(not g.hud_condition_label.text.contains("КРОВЬ"),"bleeding alert remains after treatment")
    g._open_home_journal()
    g._update_hud()
    check(g.home_preparation_text.text.split("\n").size()<=7 and g.home_preparation_text.tooltip_text.contains("СНАРЯЖЕНИЕ"),"home summary loses detail or duplicates the vitals wall")
    for panel in [g.inventory_panel,g.equipment_panel,g.base_build_panel,g.rest_panel,g.mod_panel,g.trader_panel,g.contract_panel,g.craft_panel,g.home_journal_panel]:
        check(Rect2(Vector2.ZERO,Vector2(640,360)).encloses(panel.get_global_rect()),"context window exceeds viewport: "+str(panel.name))
    check(g.equipment_info.get_visible_line_count()>=g.equipment_info.get_line_count(),"equipment summary is clipped")
    g.free()
    await process_frame
    await create_timer(0.2).timeout
    print("UI MOTION 1.38.1: %d checks, %d failures"%[checks,failures])
    preload("res://tests/qa_teardown_1381.gd").finish(self,0 if failures==0 else 1)
