extends SceneTree
# Visual QA: renders every cell of the four faction settlements to PNG.
# xvfb-run godot --path . --script tests/qa_settlement_capture.gd -- --qa-output=/abs/dir [--qa-only=perron]
const Main = preload("res://main_script_mod.gd")
const FactionCatalog = preload("res://world/faction_catalog.gd")
const FactionSettlementCatalog = preload("res://world/faction_settlement_catalog.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
var output = ""
var only = ""
var overview = false
var closeup = false
var night = false
var audit = false
# gameplay-zoom spots: [cell offset, local position]
const CLOSEUPS = [[Vector2i(0,0),Vector2(384,420)],[Vector2i(0,0),Vector2(250,650)],[Vector2i(-1,-1),Vector2(300,250)],[Vector2i(1,0),Vector2(560,600)]]

func _initialize():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output = arg.trim_prefix("--qa-output=")
        if arg.begins_with("--qa-only="):
            only = arg.trim_prefix("--qa-only=")
        if arg == "--qa-overview":
            overview = true
        if arg == "--qa-closeup":
            closeup = true
        if arg == "--qa-night":
            night = true
        if arg == "--qa-audit":
            audit = true
    call_deferred("run")

func run():
    if output == "":
        printerr("Pass --qa-output=<dir>")
        quit(1)
        return
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame
    game.world_minutes = (22.5 if night else 13.0) * 60.0
    game.weather_state = "clear"
    for node in game.find_children("*","CanvasLayer",true,false):
        node.visible = false
    if game.camera != null:
        game.camera.enabled = false
    var cam = Camera2D.new()
    game.add_child(cam)
    cam.enabled = true
    cam.make_current()
    for faction_id in FactionCatalog.ids():
        if only != "" and faction_id != only:
            continue
        var settlement_id = str(FactionCatalog.faction(faction_id).get("settlement_id",""))
        var anchor:Vector2i = RegionCatalog.poi_by_id(settlement_id).get("coord",Vector2i.ZERO)
        if audit:
            # every sector centre and its lane corner at gameplay zoom
            var k = 0
            for offset in FactionSettlementCatalog.footprint(settlement_id):
                for local in [Vector2(384,384),Vector2(740,740)]:
                    var c = anchor + offset
                    game.player.global_position = Vector2(c) * 768.0 + local + Vector2(0,60)
                    for i in range(20):
                        await process_frame
                    game.world_minutes = (22.5 if night else 13.0) * 60.0
                    await process_frame
                    cam.global_position = Vector2(c) * 768.0 + local
                    cam.zoom = Vector2(1.0,1.0)
                    await process_frame
                    await RenderingServer.frame_post_draw
                    root.get_texture().get_image().save_png("%s/%s_audit_%02d.png" % [output,faction_id,k])
                    k += 1
            continue
        if closeup:
            var n = 0
            for spot in CLOSEUPS:
                var c = anchor + spot[0]
                game.player.global_position = Vector2(c) * 768.0 + spot[1] + Vector2(0,40)
                for i in range(24):
                    await process_frame
                cam.global_position = Vector2(c) * 768.0 + spot[1]
                cam.zoom = Vector2(1.0,1.0)
                await process_frame
                await RenderingServer.frame_post_draw
                root.get_texture().get_image().save_png("%s/%s_close%s_%d.png" % [output,faction_id,"_night" if night else "",n])
                n += 1
            continue
        if overview:
            game.player.global_position = Vector2(anchor) * 768.0 + Vector2(384,384)
            for i in range(30):
                await process_frame
            for offset in FactionSettlementCatalog.footprint(settlement_id):
                if not game.loaded_chunks.has(anchor + offset):
                    game._load_chunk(anchor + offset)
            for i in range(6):
                await process_frame
            cam.global_position = Vector2(anchor) * 768.0 + Vector2(384,384)
            cam.zoom = Vector2(360.0 / 2330.0,360.0 / 2330.0)
            await process_frame
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("%s/%s_overview.png" % [output,faction_id])
            print("CAPTURE ",faction_id," overview")
            continue
        for offset in FactionSettlementCatalog.footprint(settlement_id):
            var coord = anchor + offset
            game.player.global_position = Vector2(coord) * 768.0 + Vector2(384,720)
            for i in range(20):
                await process_frame
            if not game.loaded_chunks.has(coord):
                game._load_chunk(coord)
                await process_frame
            var loaded = game.loaded_chunks.get(coord)
            if is_instance_valid(loaded):
                print("PIECES ",faction_id," ",offset," placed=",loaded.get_meta("settlement_pieces",0)," skipped=",loaded.get_meta("settlement_pieces_skipped",[]))
            cam.global_position = Vector2(coord) * 768.0 + Vector2(384,384)
            cam.zoom = Vector2(360.0 / 780.0,360.0 / 780.0)
            await process_frame
            await RenderingServer.frame_post_draw
            root.get_texture().get_image().save_png("%s/%s_%d_%d.png" % [output,faction_id,offset.x + 1,offset.y + 1])
            print("CAPTURE ",faction_id," ",offset)
    quit(0)
