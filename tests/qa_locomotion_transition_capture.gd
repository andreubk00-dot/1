extends SceneTree
# Godot 4.7.2: --path . --script tests/qa_locomotion_transition_capture.gd -- --qa-output=/abs/path
const Main = preload("res://main_script_mod.gd")
var output:=""
func _initialize()->void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--qa-output="):
            output=arg.trim_prefix("--qa-output=")
    call_deferred("run")
func _snap(game,id:String,idle_time:float,motion:Vector2,weapon_id:String,melee_id:String,recoil:bool)->int:
    game.current_weapon_id=weapon_id
    game.equipped_melee_id=melee_id
    game.aim_direction=Vector2.RIGHT
    game.visual_move_direction=motion
    game.visual_move_speed=64.0 if motion!=Vector2.ZERO else 0.0
    game.movement_anim_blend=1.0 if motion!=Vector2.ZERO else 0.0
    game.modern_survivor_idle_time=idle_time
    game.reload_time=0.0
    game.weapon_cycle_time=0.0
    game.melee_swing_time=0.0
    game.modern_survivor_hit_time=0.0
    game.weapon_recoil_duration=0.2
    game.weapon_recoil_time=0.1 if recoil else 0.0
    game._update_player_visuals(0.0)
    await process_frame
    await RenderingServer.frame_post_draw
    var path="%s/%s.png" % [output,id]
    var err=root.get_texture().get_image().save_png(path)
    print("LOCOMOTION CAPTURE: ",path," err=",err)
    return err
func run()->void:
    if output=="":
        printerr("Use --qa-output=<dir>")
        quit(1)
        return
    DirAccess.make_dir_recursive_absolute(output)
    var game=Main.new()
    root.add_child(game)
    for i in range(6):
        await process_frame
    # Freeze the world update: snapshots must preserve their explicitly chosen
    # idle phase and melee equipment rather than running another gameplay tick.
    game.set_process(false)
    for node in game.find_children("*","CanvasLayer",true,false):
        node.visible=false
    var results=[]
    var snapshot_1 = await _snap(game,"akm_idle2_start",5.0,Vector2.ZERO,"akm","",false)
    results.append(snapshot_1)
    var snapshot_2 = await _snap(game,"akm_idle3_mid",12.375,Vector2.ZERO,"akm","",false)
    results.append(snapshot_2)
    var snapshot_3 = await _snap(game,"knife_idle2_start",5.0,Vector2.ZERO,"akm","combat_knife",false)
    results.append(snapshot_3)
    var snapshot_4 = await _snap(game,"pipe_idle3_mid",12.375,Vector2.ZERO,"akm","steel_pipe",false)
    results.append(snapshot_4)
    var snapshot_5 = await _snap(game,"akm_strafe_fire",0.0,Vector2.UP,"akm","",true)
    results.append(snapshot_5)
    var snapshot_6 = await _snap(game,"akm_back_fire",0.0,Vector2.LEFT,"akm","",true)
    results.append(snapshot_6)
    game.queue_free()
    await process_frame
    var clean=true
    for result in results:
        if result!=OK:
            clean=false
    quit(0 if clean else 2)
