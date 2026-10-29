extends SceneTree
# dev78: the environment and people pass.
# - a building's cornice says what it is: a shop board, a house's address plate,
#   a works' stencil, a dacha's number, nothing on a shed
# - no street lamp stands inside a building (a site plan's lamp slot under a hall)
# - district and site names stand on boards by the road, not loose on the ground,
#   and never inside a building or on the carriageway
# - settlement people are drawn sprites that breathe and turn to the survivor
# - big halls are furnished out on the floor, clinic wards included
# - town kerbs hold drifts of fallen leaves; dirt tracks do not
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func _building_rects(chunk) -> Array:
    var rects = []
    for b in chunk.get_children():
        if is_instance_valid(b) and b.has_meta("world_building"):
            var size = b.get_meta("building_size",Vector2.ZERO)
            if typeof(size) == TYPE_VECTOR2 and size != Vector2.ZERO:
                rects.append(Rect2(b.position - size * 0.5 + Vector2(8,8),size - Vector2(16,16)))
    return rects

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame

    # --- signage kinds ------------------------------------------------------------
    var kinds = {"ДОМ":"home","ПОДЪЕЗД":"home","ЖИЛОЙ БЛОК":"home","ДОМ №12":"home","ДОМ ЕГЕРЯ":"wood",
        "ДАЧА №9":"dacha","САРАЙ":"none","ХОЗБЛОК":"none","ПРОДУКТЫ":"board","АПТЕКА":"board",
        "СКЛАД":"stencil","ГАРАЖИ 1–10":"stencil","ПЧ-4":"stencil","КПП":"board","КОРДОН":"wood"}
    for t in kinds:
        check(game._facade_sign_kind(t) == kinds[t],"sign kind of %s: %s, want %s" % [t,game._facade_sign_kind(t),kinds[t]])
    var facade = Node2D.new()
    game.add_child(facade)
    game._facade_signage(facade,"ДОМ №18",180.0,74.0,0.0,"b")
    var texts = []
    for c in facade.get_children():
        if c is Label:
            texts.append(c.text)
    check(texts.size() == 1 and texts[0].ends_with(", 18"),"a house wears its address plate: %s" % [texts])
    facade.queue_free()
    facade = Node2D.new()
    game.add_child(facade)
    game._facade_signage(facade,"САРАЙ",120.0,40.0,0.0,"b")
    check(facade.get_child_count() == 0,"a shed got a sign")
    facade.queue_free()

    # --- a lamp slot under a hall -----------------------------------------------------
    var chunk = Node2D.new()
    game.add_child(chunk)
    var b = Node2D.new()
    b.position = Vector2(300,300)
    b.set_meta("world_building",true)
    b.set_meta("building_size",Vector2(200,160))
    chunk.add_child(b)
    game._create_lamp(chunk,Vector2(310,284))
    var lamps = 0
    for c in chunk.get_children():
        if c.has_meta("world_lamp"):
            lamps += 1
    check(lamps == 0,"a street lamp went up inside a building")
    game._create_lamp(chunk,Vector2(520,264))
    lamps = 0
    for c in chunk.get_children():
        if c.has_meta("world_lamp"):
            lamps += 1
    check(lamps == 1,"a lamp on the verge was refused")
    chunk.queue_free()

    # --- the world: pieces in buildings, the name boards ------------------------------
    var coords = []
    for y in range(-4,5):
        for x in range(-4,5):
            coords.append(Vector2i(x,y))
    for site in ["reserve_arsenal_bastion","quarantine_center_12"]:
        var p = RegionCatalog.poi_by_id(site)
        for off in p.get("footprint",[]):
            coords.append(p["coord"] + off)
    var signs = 0
    var leafy = 0
    for c in coords:
        if not game.loaded_chunks.has(c):
            game._load_chunk(c)
        var ch = game.loaded_chunks.get(c,null)
        if ch == null:
            continue
        var rects = _building_rects(ch)
        var did = str(ch.get_meta("district_id",""))
        var drifts = int(ch.get_meta("kerb_leaves",0))
        if drifts > 0:
            leafy += 1
            check(did.find("woodland") < 0 and did.find("rural") < 0 and did.find("dacha") < 0,"kerb leaves on a dirt track in %s (%s)" % [c,did])
        for n in ch.get_children():
            if str(n.get_meta("ground_decal","")) == "kerb_leaves":
                var lp = n.position
                var on_kerb = (abs(lp.x - 299.0) < 14.0 or abs(lp.x - 469.0) < 14.0 or abs(lp.y - 299.0) < 14.0 or abs(lp.y - 469.0) < 14.0)
                check(on_kerb,"a leaf drift away from the kerb in %s at %s" % [c,lp])
        for n in ch.get_children():
            if not (n is Node2D):
                continue
            var tag = ""
            if n.has_meta("world_lamp"):
                tag = "lamp"
            elif n.has_meta("world_tree"):
                tag = "tree"
            elif n.has_meta("world_car"):
                tag = "car"
            elif n.has_meta("world_name_sign"):
                tag = "sign"
                signs += 1
                var pos = n.position
                check(not ((pos.x > 299.0 and pos.x < 469.0) or (pos.y > 299.0 and pos.y < 469.0)),"a name board on the carriageway in %s at %s" % [c,pos])
            if tag == "":
                continue
            for r in rects:
                if r.has_point(n.position):
                    check(false,"%s inside a building in %s at %s" % [tag,c,n.position])
                    break
        game._unload_chunk(c)
        await process_frame
    check(signs >= 6,"too few district / site boards: %d" % signs)
    check(leafy >= 20,"too few town streets with kerb leaves: %d" % leafy)

    # --- the clinic ward ------------------------------------------------------------------
    var clinic = RegionCatalog.poi_by_id("regional_clinical_complex_4")
    var cc = clinic["coord"]
    game._load_chunk(cc)
    var big_fill = -1
    for n in game.loaded_chunks[cc].get_children():
        if n.has_meta("world_building") and str(n.get_meta("authored_layout","")) == "clinic":
            var sz = n.get_meta("building_size")
            if sz.x * sz.y > 100000.0:
                big_fill = int(n.get_meta("interior_fill_count",-1))
    check(big_fill >= 10,"a big clinic ward is still bare: %d pieces" % big_fill)
    game._unload_chunk(cc)

    # --- settlement people ----------------------------------------------------------------
    var perron = RegionCatalog.poi_by_id("settlement_perron")
    for off in perron.get("footprint",[]):
        game._load_chunk(perron["coord"] + off)
    await process_frame
    var npcs = get_nodes_in_group("faction_npcs")
    check(npcs.size() >= 4,"perron has %d people" % npcs.size())
    var drawn = 0
    var target = null
    for n in npcs:
        var spr = n.get_node_or_null("NpcSprite")
        if spr != null and spr.texture != null and spr.texture.get_width() == game.SURVIVOR_CELL * 12:
            drawn += 1
            target = n
    check(drawn == npcs.size(),"%d of %d settlement people are drawn sprites" % [drawn,npcs.size()])
    if target != null:
        game.player.global_position = target.global_position + Vector2(80,0)
        game._update_npc_sprites(0.016)
        check(int(target.get_meta("npc_dir",-1)) == 0,"a resident did not turn east to the survivor: %s" % target.get_meta("npc_dir",-1))
        game.player.global_position = target.global_position + Vector2(0,-90)
        game._update_npc_sprites(0.016)
        check(int(target.get_meta("npc_dir",-1)) == 6,"a resident did not turn north to the survivor: %s" % target.get_meta("npc_dir",-1))
        game.player.global_position = target.global_position + Vector2(600,0)
        game._update_npc_sprites(0.016)
        check(int(target.get_meta("npc_dir",-1)) == 2,"a resident did not look back down the street")
        var r = target.get_node("NpcSprite").region_rect
        check(r.size == Vector2(game.SURVIVOR_CELL,game.SURVIVOR_CELL) and int(r.position.y) == 2 * game.SURVIVOR_CELL,"the resident's frame is off the sheet: %s" % r)

    print("ENVIRONMENT dev78: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
