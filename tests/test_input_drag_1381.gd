extends SceneTree
const Main = preload("res://main_script_mod.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize(): call_deferred("run")
func motion(at:Vector2,held=false):
    var event = InputEventMouseMotion.new()
    event.position = at
    event.global_position = at
    event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
    root.push_input(event,true)
    await process_frame
func button(at:Vector2,pressed:bool,which=MOUSE_BUTTON_LEFT):
    var event = InputEventMouseButton.new()
    event.position = at
    event.global_position = at
    event.button_index = which
    event.pressed = pressed
    root.push_input(event,true)
    await process_frame
func drag(from:Vector2,to:Vector2):
    await motion(from)
    await button(from,true)
    await motion(to,true)
    await button(to,false)
    await process_frame
func run():
    var g = Main.new()
    root.add_child(g)
    g.set_process(false)
    g.inventory_entries = [{"id":"bandage","qty":2,"x":0,"y":0},{"id":"cap","qty":1,"x":2,"y":0}]
    g.equipment.head = ""
    g.inventory_open = true
    g._refresh_inventory_ui()
    g._update_hud()
    await process_frame
    var point = g.inv_grid_control.get_global_transform_with_canvas() * (Vector2(.5,.5)*g.CELL)
    var target = g.hud_quick_slots[5].button.get_global_rect().get_center()
    await drag(point,target)
    check(g.quick_slot_ids[5]=="bandage","mouse drag from inventory did not bind hotbar")
    check(g._inventory_count("bandage")==2,"assigning a hotkey consumed medicine")
    var another = g.hud_quick_slots[4].button.get_global_rect().get_center()
    await drag(target,another)
    check(g.quick_slot_ids[4]=="bandage","mouse drag did not move a hotbar binding")
    await button(another,true,MOUSE_BUTTON_RIGHT)
    await button(another,false,MOUSE_BUTTON_RIGHT)
    check(g.quick_slot_ids[4]=="","right click did not free a hotbar cell")
    var cap = g.inv_grid_control.get_global_transform_with_canvas() * (Vector2(2.5,.5)*g.CELL)
    await drag(cap,g.equipment_buttons.head.get_global_rect().get_center())
    check(g.equipment.head=="cap" and g._inventory_count("cap")==0,"dragging gear onto its slot did not equip it")
    var free_cell = g.inv_grid_control.get_global_transform_with_canvas() * (Vector2(3.5,2.5)*g.CELL)
    await drag(g.equipment_buttons.head.get_global_rect().get_center(),free_cell)
    check(g.equipment.head=="" and g._inventory_count("cap")==1,"dragging equipped gear back duplicated or lost it")
    var placed = false
    for entry in g.inventory_entries:
        if entry.id=="cap": placed = int(entry.x)==3 and int(entry.y)==2
    check(placed,"unequipped gear ignored the selected inventory cell")
    g._close_inventory()
    g.health = 70
    g.bleeding = true
    g._assign_quick_slot(6,"bandage")
    check(g._select_quick_slot(6),"hotkey did not use medicine")
    check(not g.bleeding and g._inventory_count("bandage")==1,"hotkey did not consume exactly one bandage")
    g.free()
    await process_frame
    print("INPUT DRAG 1.38.1: %d checks, %d failures"%[checks,failures])
    quit(0 if failures==0 else 1)
