extends SceneTree
const Harness = preload("res://tests/rest_harness.gd")
const FactionEconomy = preload("res://world/faction_economy.gd")
const SupplyEventSystem = preload("res://world/supply_event_system.gd")
const RegionMapView = preload("res://world/region_map_view.gd")

var failures := 0
var checks := 0

func check(ok:bool,message:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame
    game.faction_state = FactionEconomy.default_state()
    SupplyEventSystem.ensure_state(game.faction_state,1)
    game.faction_state["supply_events"]["next_event_day"] = 4
    var created = SupplyEventSystem.daily_tick(game.faction_state,4,game._supply_event_blocked_chunks())
    var event = created.get("event",{})
    check(not event.is_empty(),"runtime QA incident was not created")
    game.world_day = 4
    var coord = SupplyEventSystem.active_coord(game.faction_state,4)

    # System radio marker exists even before that sector has been explored.
    game.region_map_grid = RegionMapView.new()
    game.region_map_grid.size = Vector2(600,280)
    game.add_child(game.region_map_grid)
    game.region_map_center = coord
    var snapshot = game._region_map_snapshot()
    var system_markers = 0
    for mark in snapshot.get("markers",[]):
        if bool(mark.get("system",false)) and mark.get("coord",Vector2i.ZERO) == coord:
            system_markers += 1
    check(system_markers == 1,"active incident is not shown as a system map marker")
    check("SOS" in game._region_map_cell_tooltip(coord),"unexplored incident tooltip does not expose radio signal")

    # Production procedural builder gives the dynamic event priority over static random encounters.
    game.base_objects = []
    var chunk = Node2D.new()
    chunk.position = Vector2(coord) * game.CHUNK_SIZE
    game.add_child(chunk)
    game._build_procedural_chunk(chunk,coord)
    var roots = []
    for child in chunk.get_children():
        if bool(child.get_meta("world_event_root",false)):
            roots.append(child)
    check(roots.size() == 1,"supply incident must create exactly one world event root")
    if not roots.is_empty():
        var event_root = roots[0]
        check(str(event_root.get_meta("world_event_id","")) == "supply_convoy","wrong production event root id")
        check(bool(event_root.get_meta("supply_event",false)),"production root missing supply-event flag")
        check(str(event_root.get_meta("supply_event_id","")) == str(event.get("id","")),"dynamic incident id missing from scene")
        var survivors = 0
        var cargo_nodes = 0
        for node in event_root.get_children():
            if node.has_meta("supply_event_id") and str(node.get_meta("interaction_type","")) == "faction_npc":
                survivors += 1
            if str(node.get_meta("interaction_type","")) == "supply_event_cargo":
                cargo_nodes += 1
        check(survivors == 2,"fresh distress scene must have two surviving faction NPCs")
        check(cargo_nodes == 1,"supply scene must expose one cargo recovery interaction")
    var event_enemies = 0
    for enemy in get_nodes_in_group("infected"):
        if is_instance_valid(enemy) and str(enemy.get_meta("supply_event_id","")) == str(event.get("id","")):
            event_enemies += 1
    check(event_enemies == int(SupplyEventSystem.runtime_event_for_chunk(game.faction_state,coord,4).get("enemy_count",0)),"production scene infected budget mismatch")

    # After clearing the scene, the actual interaction resolves economy/reputation and removes active marker.
    for enemy in get_nodes_in_group("infected"):
        if is_instance_valid(enemy) and str(enemy.get_meta("supply_event_id","")) == str(event.get("id","")):
            enemy.queue_free()
    await process_frame
    var cargo = null
    if not roots.is_empty():
        for node in roots[0].get_children():
            if str(node.get_meta("interaction_type","")) == "supply_event_cargo":
                cargo = node
                break
    var faction_id = str(event.get("faction",""))
    var resource_id = str(event.get("cargo_resource",""))
    var resource_before = float(game.faction_state["factions"][faction_id]["resources"][resource_id])
    var rep_before = int(game.faction_state["factions"][faction_id]["reputation"])
    var tickets_before = int(game.faction_state.get("currency_tickets",0))
    check(cargo != null,"cargo interaction disappeared before resolution")
    if cargo != null:
        game._resolve_supply_event(cargo)
        await process_frame
    check(game.faction_state["supply_events"]["active"].is_empty(),"cargo interaction did not close active incident")
    check(float(game.faction_state["factions"][faction_id]["resources"][resource_id]) > resource_before,"cargo recovery did not improve settlement supply")
    check(int(game.faction_state["factions"][faction_id]["reputation"]) > rep_before,"cargo recovery did not grant reputation")
    check(int(game.faction_state.get("currency_tickets",0)) > tickets_before,"cargo recovery did not grant tickets")

    chunk.queue_free()
    game.free()
    print("SUPPLY EVENT RUNTIME 1.22-dev6: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
