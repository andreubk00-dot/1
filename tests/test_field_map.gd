extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
var checks = 0
var failures = 0
func check(ok,message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)
func _initialize():
    call_deferred("run")
func run():
    var game = Harness.new()
    root.add_child(game)
    game._create_region_map_ui()
    game._create_home_journal_ui()
    game.current_chunk = Vector2i.ZERO
    game.discovered_chunks = {"0:0":true}
    game.discovered_pois = {}
    game._open_region_map()
    var map = game.region_map_grid
    var snapshot = game._region_map_snapshot()
    check(snapshot["cells"][Vector2i.ZERO]["known"],"visited sector is represented")
    check(not snapshot["cells"][Vector2i(3,3)]["known"],"unvisited sector remains unknown")
    check(not snapshot["cells"][Vector2i(3,3)].has("zone"),"unvisited sector does not disclose land use")
    check(snapshot["pois"].is_empty(),"undiscovered POIs must not appear")
    game.discovered_pois["central_clinic"] = true
    snapshot = game._region_map_snapshot()
    check(snapshot["pois"].size() == 1 and snapshot["pois"][0]["coord"] == Vector2i.ZERO,"discovered POI has real anchor")
    for zoom in range(3):
        map.set_zoom(zoom)
        game._pan_region_map(Vector2i(-7,4))
        var coord = game.region_map_center + Vector2i(-2,1)
        check(map.unproject(map.project(coord)) == coord,"world coordinate survives zoom and pan")
    var click = InputEventMouseButton.new()
    click.button_index = MOUSE_BUTTON_LEFT
    click.pressed = true
    var chosen = game.region_map_center + Vector2i(1,-1)
    click.position = map.project(chosen)
    map._gui_input(click)
    check(game.region_map_selected_chunk == chosen,"click selects actual world coordinate")
    game.map_marker_kind.select(2)
    game.map_marker_text.text = "Колодец"
    var old_discovery = game.discovered_chunks.duplicate()
    game._save_selected_map_marker()
    var key = game._zone_chunk_key(chosen)
    check(game.map_markers[key] == {"kind":"water","label":"Колодец"},"custom water marker stores kind and label")
    check(game.discovered_chunks == old_discovery,"personal note cannot reveal geography")
    game._region_map_select_chunk(Vector2i.ZERO)
    game._region_map_select_chunk(chosen)
    check(game.map_marker_text.text == "Колодец" and game.map_marker_kind.selected == 2,"reselecting marker restores editor")
    game.map_marker_text.text = "Новая подпись"
    game._refresh_region_map_ui()
    check(game.map_marker_text.text == "Новая подпись","periodic redraw cannot erase unfinished typing")
    var restored = game._sanitize_map_markers(JSON.parse_string(JSON.stringify(game.map_markers)))
    check(restored == game.map_markers,"notes survive JSON round trip")
    var dirty = {"x:y":{"kind":"water"},"1:2":{"kind":"invalid"},"2:2":false,"-2:3":{"kind":"note","label":"a\nb"}}
    var clean = game._sanitize_map_markers(dirty)
    check(clean.size() == 1 and clean["-2:3"]["label"] == "a b","malformed markers discarded and multiline notes normalized")
    check(game._sanitize_map_markers(null).is_empty(),"legacy saves without markers start empty")
    game._remove_selected_map_marker()
    check(not game.map_markers.has(key),"marker deletion removes persistent entry")
    game._ensure_input("region_map",KEY_M)
    game.map_marker_text.grab_focus()
    await process_frame
    var key_event = InputEventKey.new()
    key_event.pressed = true
    key_event.keycode = KEY_M
    key_event.physical_keycode = KEY_M
    key_event.unicode = 109
    root.push_input(key_event)
    check(game.region_map_open,"typing in note must not trigger map shortcut")
    check(game.map_marker_text.text == "m","letter is actually entered in focused note field")
    game.map_marker_text.release_focus()
    var before_pan = game.region_map_center
    var right = InputEventMouseButton.new()
    right.button_index = MOUSE_BUTTON_RIGHT
    right.pressed = true
    map._gui_input(right)
    var motion = InputEventMouseMotion.new()
    motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
    motion.relative = Vector2(map.step()*2,0)
    map._gui_input(motion)
    check(game.region_map_center == before_pan-Vector2i(2,0),"right drag pans in world-sector units")
    right.pressed = false
    map._gui_input(right)
    check(not map.dragging,"button release stops drag")
    var many = {}
    for i in range(150):
        many[str(i)+":0"] = {"kind":"note","label":"a".repeat(50)}
    var capped = game._sanitize_map_markers(many)
    check(capped.size() == 128 and capped["0:0"]["label"].length() == 32,"load limits marker count and label length")
    game.expedition_journal["home"] = {"key":"0:0:home","name":"Дом","chunk":[0,0],"position":[0,0]}
    game.map_marker_text.text = "Не переносить домой"
    game._navigate_home()
    check(game.region_map_selected_chunk == Vector2i.ZERO and game.map_marker_text.text == "","home navigation cannot carry editor text from another sector")
    game._close_region_map()
    check(not game.region_map_open,"map can close normally")
    game.free()
    print("FIELD MAP: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
