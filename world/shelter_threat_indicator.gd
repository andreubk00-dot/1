extends Node2D

# Compact world-space shelter warning. It only shows two concrete things:
# the direction of a defense point hit very recently, and whether an infected
# is already inside the shelter. There is no hidden pressure meter.
var phase := 0.0
var tracked_target = null
var tracked_age_ms := 999999
var scan_timer := 0.0

func _ready():
    z_as_relative = false
    z_index = 210
    process_mode = Node.PROCESS_MODE_ALWAYS
    queue_redraw()

func _candidate_points():
    return get_tree().get_nodes_in_group("shelter_defense_points")

func _pick_active_target():
    var now = Time.get_ticks_msec()
    var best = null
    var best_hit = -1000000
    for node in _candidate_points():
        if not is_instance_valid(node):
            continue
        if get_parent() != null and node.global_position.distance_to(get_parent().global_position) > 320.0:
            continue
        var last_hit = int(node.get_meta("breach_last_hit_ms",-1000000))
        if now - last_hit > 1900:
            continue
        if last_hit > best_hit:
            best_hit = last_hit
            best = node
    tracked_target = best
    tracked_age_ms = now - best_hit if best != null else 999999
    return best

func _process(delta):
    phase = fmod(phase + float(delta),TAU)
    scan_timer -= float(delta)
    if scan_timer <= 0.0:
        scan_timer = 0.10
        _pick_active_target()
    queue_redraw()

func _target_direction():
    if not is_instance_valid(tracked_target) or get_parent() == null:
        return Vector2.ZERO
    var delta = tracked_target.global_position - get_parent().global_position
    if delta.length() <= 0.01:
        return Vector2.ZERO
    return delta.normalized()

func _intruders_active():
    if get_parent() == null:
        return 0
    return max(0,int(get_parent().get_meta("shelter_intruders_active",0)))

func _draw_intrusion_marker(pulse):
    if _intruders_active() <= 0:
        return
    var alpha = 0.58 + pulse * 0.28
    var c = Color(0.95,0.24,0.12,alpha)
    var r = 7.0 + pulse * 1.0
    var diamond = PackedVector2Array([Vector2(0,-r),Vector2(r,0),Vector2(0,r),Vector2(-r,0)])
    draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),c,1.5,true)
    draw_circle(Vector2.ZERO,1.6,c)

func _draw():
    var pulse = 0.5 + 0.5 * sin(phase * 8.0)
    _draw_intrusion_marker(pulse)
    var dir = _target_direction()
    if dir == Vector2.ZERO:
        return
    var alpha = 0.46 + pulse * 0.34
    var c = Color(1.0,0.43,0.10,alpha)
    var perp = Vector2(-dir.y,dir.x)
    var radius = 31.0 + pulse * 2.0
    var tip = dir * radius
    var base = tip - dir * 9.0
    var tri = PackedVector2Array([tip,base + perp * 5.0,base - perp * 5.0])
    draw_colored_polygon(tri,c)
    draw_line(dir * 19.0,dir * 27.0,c,1.8,true)
    var side_c = Color(c.r,c.g,c.b,alpha * 0.70)
    draw_line(dir * 22.0 + perp * 5.5,dir * 27.0 + perp * 3.0,side_c,1.2,true)
    draw_line(dir * 22.0 - perp * 5.5,dir * 27.0 - perp * 3.0,side_c,1.2,true)
