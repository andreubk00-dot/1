extends SceneTree
# Godot 4.7.2: --headless --path . --script tests/test_locomotion_transition_sync_127.gd
const Harness = preload("res://tests/rest_harness.gd")
const GUNS = ["makarov","tt33","shotgun","toz34","sks","akm","pps43","izh81","aks74u","mosin"]
const MELEE = {"combat_knife":"knife","steel_pipe":"pipe","fire_axe":"axe"}
var checks := 0
var failures := 0
func check(ok:bool,why:String)->void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL ",why)
func _initialize()->void:
    call_deferred("run")
func _clear_actions(game)->void:
    game.reload_time=0.0
    game.weapon_cycle_time=0.0
    game.melee_swing_time=0.0
    game.weapon_recoil_time=0.0
    game.modern_survivor_hit_time=0.0
    game.is_sprinting=false
func _check_weapon(game,weapon_id:String,melee:bool)->void:
    _clear_actions(game)
    game.equipped_melee_id=weapon_id if melee else ""
    game.current_weapon_id="akm" if melee else weapon_id
    for spec in [
        [0.0,"Idle",0],
        [5.0,"Idle2",0],
        [5.56,"Idle2",1],
        [6.125,"Idle2",4],
        [7.249,"Idle2",7],
        [7.25,"Idle",-1],
        [11.25,"Idle3",0],
        [11.8125,"Idle3",2],
        [12.375,"Idle3",4],
        [13.499,"Idle3",7],
        [13.5,"Idle",-1]
    ]:
        game.modern_survivor_idle_time=float(spec[0])
        var clip=game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.ZERO,false)
        check(clip==str(spec[1]),"%s idle time %s expected %s got %s" % [weapon_id,str(spec[0]),str(spec[1]),clip])
        # Base Idle intentionally keeps the historical wall-clock breathing phase.
        # dev2 only phase-locks authored Idle2/Idle3 windows to frame 0.
        if int(spec[2]) >= 0 and clip != "Idle":
            check(game._modern_survivor_frame(clip,false,8)==int(spec[2]),"%s frame at %s" % [weapon_id,str(spec[0])])
        var tex=game._modern_survivor_sheet(clip)
        check(tex!=null,"%s missing clip %s" % [weapon_id,clip])
        if tex!=null:
            check(int(tex.get_width())==1024 and int(tex.get_height())==1024,"%s idle atlas geometry %s" % [weapon_id,clip])
    # Changing aim/motion must keep the existing direction-based clip mapping.
    game.modern_survivor_idle_time=0.0
    for spec in [
        [Vector2.RIGHT,"Walk"],
        [Vector2.LEFT,"RunBackwards"],
        [Vector2.UP,"StrafeLeft"],
        [Vector2.DOWN,"StrafeRight"]
    ]:
        var clip=game._modern_survivor_clip(weapon_id,Vector2.RIGHT,spec[0],true)
        check(clip==str(spec[1]),"%s walking direction expected %s got %s" % [weapon_id,str(spec[1]),clip])
    game.is_sprinting=true
    check(game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.RIGHT,true)=="Run",weapon_id+" sprint transition")
    _clear_actions(game)
    if melee:
        game.melee_swing_duration=0.30
        game.melee_swing_time=0.15
        var expected="Attack4" if weapon_id=="combat_knife" else "Attack3"
        check(game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.ZERO,false)==expected,weapon_id+" melee attack overrides idle")
        game.melee_swing_time=0.0
    else:
        game.weapon_recoil_duration=0.20
        game.weapon_recoil_time=0.10
        for spec in [
            [Vector2.ZERO,false,"Attack1"],
            [Vector2.RIGHT,true,"RunAttack"],
            [Vector2.LEFT,true,"RunBackwardsAttack"],
            [Vector2.UP,true,"StrafeLeftAttack"],
            [Vector2.DOWN,true,"StrafeRightAttack"]
        ]:
            var clip=game._modern_survivor_clip(weapon_id,Vector2.RIGHT,spec[0],bool(spec[1]))
            check(clip==str(spec[2]),"%s moving-fire clip expected %s got %s" % [weapon_id,str(spec[2]),clip])
        game.weapon_recoil_time=0.0
        game.reload_time=0.20
        check(game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.ZERO,false)=="Taunt",weapon_id+" reload overrides idle")
        game.reload_time=0.0
        game.weapon_cycle_duration=0.4
        game.weapon_cycle_time=0.2
        game.weapon_cycle_weapon_id=weapon_id
        check(game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.ZERO,false)=="Attack2",weapon_id+" cycle overrides idle")
        game.weapon_cycle_time=0.0
    game.modern_survivor_hit_time=0.10
    check(game._modern_survivor_clip(weapon_id,Vector2.RIGHT,Vector2.ZERO,false)=="TakeDamage",weapon_id+" hit overrides idle")
    _clear_actions(game)
func run()->void:
    var game=Harness.new()
    root.add_child(game)
    await process_frame
    await process_frame
    for gun in GUNS:
        _check_weapon(game,gun,false)
    for melee_id in MELEE.keys():
        _check_weapon(game,str(melee_id),true)
    game.queue_free()
    await process_frame
    print("LOCOMOTION TRANSITION SYNC 1.27-dev2: ",checks," checks / ",failures," failures")
    quit(1 if failures else 0)
