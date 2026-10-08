extends SceneTree
# Close-ups of north-south fences (chain-link and the PO-2 perimeter) in
# locations, to check they read as standing walls in the 3/4 view.
# xvfb-run godot --path . --rendering-driver opengl3 --script tests/qa_vertical_fence_capture.gd -- <dir>
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
func _initialize():
    call_deferred("run")
func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame
    for node in game.find_children("*","CanvasLayer",true,false):
        node.visible = false
    game.camera.enabled = false
    var cam = Camera2D.new()
    game.add_child(cam)
    cam.make_current()
    var n = 0
    for r in range(0,12):
        for y in range(-r,r+1):
            for x in range(-r,r+1):
                if max(abs(x),abs(y)) != r or n >= 4:
                    continue
                var c = Vector2i(x,y)
                if RegionCatalog.poi_for_chunk(c).is_empty():
                    continue
                game.player.global_position = Vector2(c) * 768.0 + Vector2(384,384)
                for i in range(16):
                    await process_frame
                var ch = game.loaded_chunks.get(c)
                if ch == null:
                    continue
                for f in ch.get_children():
                    if bool(f.get_meta("world_fence",false)) and abs(sin(f.rotation)) > 0.7 and n < 4:
                        game.player.global_position = f.global_position + Vector2(140,0)
                        for i in range(10):
                            await process_frame
                        game.world_minutes = 13.0 * 60.0
                        cam.global_position = f.global_position
                        cam.zoom = Vector2(2,2)
                        await process_frame
                        await RenderingServer.frame_post_draw
                        root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/vf_%d.png" % n)
                        print("VFENCE ",c," ",f.position)
                        n += 1
                        break
    quit(0)
