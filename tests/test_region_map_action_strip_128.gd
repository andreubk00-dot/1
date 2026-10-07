extends SceneTree
var checks := 0
var failures := 0
func check(ok:bool,msg:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",msg)
func _initialize()->void: call_deferred("run")
func run()->void:
    var packed=load("res://main.tscn")
    check(packed!=null,"main scene failed to load")
    if packed==null: quit(1); return
    var main=packed.instantiate(); root.add_child(main)
    await process_frame; await process_frame
    check(main.region_map_panel!=null,"region map panel missing")
    check(main.region_map_plan_button!=null,"plan button missing")
    check(main.region_map_cancel_button!=null,"cancel button missing")
    var action_row=main.region_map_plan_button.get_parent()
    check(action_row is HBoxContainer,"plan button is not in fixed HBox action strip")
    check(main.region_map_cancel_button.get_parent()==action_row,"map actions do not share fixed strip")
    check(action_row.get_parent()==main.region_map_panel,"action strip is still inside scroll content")
    check(action_row.position.y>=260.0 and action_row.position.y+action_row.size.y<309.0,"action strip overlaps footer or map content")
    check(main.region_map_plan_button.size.x>70.0,"plan button too narrow")
    check(main.region_map_cancel_button.size.x>70.0,"cancel button too narrow")
    # Reproduce the long discovered-sector context that exposed the dev18 clipping.
    main.faction_state=main.FactionEconomy.default_state()
    main.current_chunk=Vector2i(0,0); main.region_map_center=Vector2i(0,0)
    for y in range(-1,2):
        for x in range(-1,2):
            main.discovered_chunks[main._zone_chunk_key(Vector2i(x,y))]=true
    main.discovered_pois["central_clinic"]=true
    main.region_map_selected_chunk=Vector2i(0,0)
    main.region_map_open=true; main.region_map_canvas.visible=true; main.region_map_panel.visible=true
    main._refresh_region_map_ui()
    await process_frame
    check(main.region_map_plan_button.visible and main.region_map_cancel_button.visible,"fixed map actions became hidden with long survey text")
    check(main.region_map_plan_button.get_global_rect().end.y <= main.region_map_panel.get_global_rect().position.y+309.0,"plan button falls into footer")
    main.queue_free(); await process_frame
    print("REGION MAP ACTION STRIP 1.28-dev1: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
