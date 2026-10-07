extends SceneTree
# Visual QA for 1.27-dev1 authored idle variations.
# Run with Godot 4.7.2:
#   godot --path . --script tests/qa_idle_animation_capture.gd -- --qa-output=/abs/dir
const Main = preload("res://main_script_mod.gd")
var output := ""
func _initialize()->void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _snap(game,name:String,idle_time:float)->int:
    game.modern_survivor_idle_time=idle_time
    game.visual_move_speed=0.0; game.movement_anim_blend=0.0
    game.reload_time=0.0; game.weapon_cycle_time=0.0; game.melee_swing_time=0.0; game.weapon_recoil_time=0.0; game.modern_survivor_hit_time=0.0
    game._update_player_visuals(0.0)
    await process_frame; await RenderingServer.frame_post_draw
    var path="%s/%s.png" % [output,name]
    var err=root.get_texture().get_image().save_png(path)
    print("IDLE ANIMATION CAPTURE: ",path," clip=",game._modern_survivor_idle_sheet(game.current_weapon_id)," err=",err)
    return err
func run()->void:
    if output=="": printerr("Pass --qa-output=<dir>"); quit(1); return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Main.new(); root.add_child(game)
    for i in range(6): await process_frame
    game.current_weapon_id="akm"; game.equipped_melee_id=""; game.aim_direction=Vector2.RIGHT
    for node in game.find_children("*","CanvasLayer",true,false): node.visible=false
    var e1=await _snap(game,"idle_base",0.0)
    var e2=await _snap(game,"idle_weight_shift",5.5)
    var e3=await _snap(game,"idle_ready_shift",11.5)
    game.queue_free(); await process_frame
    quit(0 if e1==OK and e2==OK and e3==OK else 2)
