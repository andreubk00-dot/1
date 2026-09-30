extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
const EncounterCatalog = preload("res://world/encounter_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

var checks := 0
var failures := 0

func check(ok, message):
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",message)

func _initialize():
    call_deferred("run")

func _event_nodes(chunk) -> Array:
    var out = []
    for child in chunk.get_children():
        if is_instance_valid(child) and bool(child.get_meta("world_event_root",false)):
            out.append(child)
    return out

func run():
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    check(EncounterCatalog.EVENTS.size() == 5,"unexpected encounter catalogue size")
    for event_id in EncounterCatalog.EVENTS.keys():
        var spec:Dictionary = EncounterCatalog.EVENTS[event_id]
        check(not str(spec.get("label","")).is_empty(),event_id + " has no label")
        check(not spec.get("zones",[]).is_empty(),event_id + " has no zones")
        var fp:Vector2 = spec.get("footprint",Vector2.ZERO)
        check(fp.x >= 100.0 and fp.y >= 70.0,event_id + " footprint too small to protect scene")
        check(int(spec.get("enemy_count",0)) >= 2,event_id + " is not a meaningful encounter")

    # Starter neighbourhood and authored POIs are never overwritten by random encounters.
    for y in range(-1,2):
        for x in range(-1,2):
            check(EncounterCatalog.event_for(Vector2i(x,y),"residential",2,"").is_empty(),"event spawned in starter safety ring")
    for poi in RegionCatalog.POIS:
        var coord:Vector2i = poi.get("coord",Vector2i.ZERO)
        check(EncounterCatalog.event_for(coord,str(RegionCatalog.district_profile(str(poi.get("district","old_center"))).get("zone","residential")),int(poi.get("risk",2)),str(poi.get("id",""))).is_empty(),"random event overwrote authored POI " + str(poi.get("id","")))

    # Determinism, sane density and risk-safe loot over a broad world sample.
    var selected = 0
    var eligible = 0
    var by_id = {}
    for y in range(-20,21):
        for x in range(-20,21):
            var coord = Vector2i(x,y)
            if max(abs(x),abs(y)) <= 1:
                continue
            var profile = game._chunk_profile(coord)
            if str(profile.get("poi_id","")) != "":
                continue
            eligible += 1
            var event = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),"")
            var event_again = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),"")
            check(str(event.get("id","")) == str(event_again.get("id","")),"encounter selection is nondeterministic at " + str(coord))
            if event.is_empty():
                continue
            selected += 1
            var event_id = str(event.get("id",""))
            by_id[event_id] = int(by_id.get(event_id,0)) + 1
            var profile_name = EncounterCatalog.loot_profile(event,str(profile.get("zone","residential")))
            if profile_name != "":
                check(game._loot_profile_risk(profile_name) <= int(profile.get("risk",2)),"event leaks loot above world risk: " + event_id)
    var density = float(selected) / max(1.0,float(eligible))
    check(density >= 0.035 and density <= 0.12,"encounter density outside sparse-world target: %.3f" % density)
    check(by_id.size() >= 4,"world sample lacks encounter variety")

    # Find a real deterministic event of every kind and build it through production logic.
    var coords_by_id = {}
    for y in range(-40,41):
        for x in range(-40,41):
            var coord = Vector2i(x,y)
            var profile = game._chunk_profile(coord)
            if str(profile.get("poi_id","")) != "":
                continue
            var event = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),"")
            var event_id = str(event.get("id",""))
            if event_id != "" and not coords_by_id.has(event_id):
                coords_by_id[event_id] = coord
    for event_id in EncounterCatalog.EVENTS.keys():
        check(coords_by_id.has(event_id),"no deterministic world coordinate found for " + event_id)
        if not coords_by_id.has(event_id):
            continue
        var coord:Vector2i = coords_by_id[event_id]
        var chunk = Node2D.new()
        chunk.position = Vector2(coord.x * game.CHUNK_SIZE,coord.y * game.CHUNK_SIZE)
        game.add_child(chunk)
        game._build_procedural_chunk(chunk,coord)
        var roots = _event_nodes(chunk)
        check(roots.size() == 1,event_id + " production chunk must contain exactly one event root")
        if not roots.is_empty():
            var event_root = roots[0]
            check(str(event_root.get_meta("world_event_id","")) == event_id,event_id + " root metadata mismatch")
            var er = game._world_event_rect(event_root)
            check(er.position.x >= 0.0 and er.position.y >= 0.0 and er.end.x <= game.CHUNK_SIZE and er.end.y <= game.CHUNK_SIZE,event_id + " footprint leaves chunk")
            # Buildings must never overlap an encounter footprint.
            for child in chunk.get_children():
                if child.has_meta("world_building"):
                    var size:Vector2 = child.get_meta("building_size",Vector2.ZERO)
                    var br = Rect2(child.position - size * 0.5,size).grow(8.0)
                    check(not er.intersects(br),event_id + " overlaps building " + child.name)
            # Random cars and trees generated after the encounter must respect its protected footprint.
            for child in chunk.get_children():
                if bool(child.get_meta("world_car",false)):
                    var cr = Rect2(child.position - Vector2(40,24),Vector2(80,48))
                    check(not er.grow(10.0).intersects(cr),event_id + " overlaps generated car")
                if bool(child.get_meta("world_tree",false)):
                    check(not er.grow(12.0).has_point(child.position),event_id + " overlaps generated tree")
        var infected = 0
        var event_spawn_ids = []
        for child in chunk.get_children():
            if child.has_meta("infected_kind"):
                infected += 1
                var sid = int(child.get_meta("spawn_id",-1))
                if sid >= 1100:
                    event_spawn_ids.append(sid)
        check(event_spawn_ids.size() == int(EncounterCatalog.EVENTS[event_id].get("enemy_count",0)),event_id + " event infected count mismatch")
        check(infected >= event_spawn_ids.size(),event_id + " invalid total infected count")
        chunk.queue_free()

    # Existing player construction suppresses a random scene in that chunk.
    var suppress_coord = Vector2i.ZERO
    for event_id in coords_by_id.keys():
        suppress_coord = coords_by_id[event_id]
        break
    if suppress_coord != Vector2i.ZERO:
        game.base_objects = [{"id":9001,"kind":"stash","x":suppress_coord.x * game.CHUNK_SIZE + 384.0,"y":suppress_coord.y * game.CHUNK_SIZE + 384.0,"rot":0.0}]
        var profile = game._chunk_profile(suppress_coord)
        var event = EncounterCatalog.event_for(suppress_coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),"")
        check(not event.is_empty(),"suppression QA coordinate unexpectedly has no encounter")
        var suppressed = Node2D.new()
        game.add_child(suppressed)
        check(not game._build_world_event(suppressed,suppress_coord,profile,event),"encounter spawned through an existing player base")
        suppressed.queue_free()
        game.base_objects = []

    # Event enemies use stable high spawn ids and the existing defeated persistence.
    if not coords_by_id.is_empty():
        var any_id = str(coords_by_id.keys()[0])
        var coord:Vector2i = coords_by_id[any_id]
        var profile = game._chunk_profile(coord)
        var event = EncounterCatalog.event_for(coord,str(profile.get("zone","residential")),int(profile.get("risk",2)),"")
        var sid = 1100 + (EncounterCatalog._hash(coord,101) % 200) * 10
        game.defeated["%d:%d:%d" % [coord.x,coord.y,sid]] = true
        var ch = Node2D.new()
        game.add_child(ch)
        var built = game._build_world_event(ch,coord,profile,event)
        check(built,"persistence QA event failed to build")
        var found = false
        for n in ch.get_children():
            if n.has_meta("spawn_id") and int(n.get_meta("spawn_id",-1)) == sid:
                found = true
        check(not found,"defeated event infected respawned")
        ch.queue_free()

    game.free()
    print("WORLD EVENTS ENCOUNTERS: ",checks," checks, ",failures," failures")
    quit(1 if failures else 0)
