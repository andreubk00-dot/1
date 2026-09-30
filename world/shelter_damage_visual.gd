extends Node2D

# 1.00: procedural shelter damage + animated hit / collapse feedback.
# Persistent state still comes only from the parent HP metadata. Animation clocks
# are transient and therefore do not alter save compatibility.
var phase := 0.0

func _ready():
    z_as_relative = true
    z_index = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    queue_redraw()

func _process(delta):
    phase = fmod(phase + float(delta),TAU)
    queue_redraw()

func _damage_stage():
    if get_parent() == null:
        return 0
    return clamp(int(get_parent().get_meta("visual_damage_stage",0)),0,3)

func _kind():
    if get_parent() == null:
        return "door"
    return str(get_parent().get_meta("visual_damage_kind","door"))

func _is_reinforced():
    return get_parent() != null and bool(get_parent().get_meta("visual_reinforced",false))

func _recently_attacked():
    if get_parent() == null:
        return false
    var last_hit = int(get_parent().get_meta("breach_last_hit_ms",-1000000))
    return Time.get_ticks_msec() - last_hit < 950

func _transition_age():
    if get_parent() == null:
        return 999.0
    var started = int(get_parent().get_meta("visual_stage_change_ms",-1000000))
    return max(0.0,float(Time.get_ticks_msec() - started) / 1000.0)

func _transition_active():
    return _transition_age() < (0.72 if _damage_stage() >= 3 else 0.48)

func _breach_burst_active():
    return _damage_stage() >= 3 and _transition_age() < 0.72

func _attack_dir():
    if get_parent() == null:
        return Vector2.DOWN
    var d = get_parent().get_meta("breach_attack_dir",Vector2.DOWN)
    if typeof(d) != TYPE_VECTOR2 or d.length() <= 0.01:
        return Vector2.DOWN
    return d.normalized()

func _half_size():
    var kind = _kind()
    if kind == "window":
        return Vector2(19,15)
    if kind == "barricade":
        return Vector2(22,11)
    return Vector2(20,14)

func _draw_crack(points,alpha = 0.78,width = 1.25):
    if points.size() < 2:
        return
    var crack = PackedVector2Array(points)
    draw_polyline(crack,Color(0.12,0.085,0.06,alpha),width,true)

func _draw_damage(stage,half):
    if stage <= 0:
        return
    var y_bias = -2.0 if _kind() == "window" else 0.0
    _draw_crack([
        Vector2(-half.x*0.15,-half.y*0.58+y_bias),
        Vector2(-half.x*0.02,-half.y*0.17+y_bias),
        Vector2(-half.x*0.25,half.y*0.18+y_bias),
        Vector2(-half.x*0.08,half.y*0.54+y_bias)
    ],0.72,1.15)
    if stage >= 2:
        _draw_crack([
            Vector2(half.x*0.38,-half.y*0.62+y_bias),
            Vector2(half.x*0.14,-half.y*0.23+y_bias),
            Vector2(half.x*0.34,half.y*0.08+y_bias),
            Vector2(half.x*0.12,half.y*0.48+y_bias)
        ],0.86,1.35)
        _draw_crack([
            Vector2(-half.x*0.02,-half.y*0.17+y_bias),
            Vector2(half.x*0.15,-half.y*0.04+y_bias),
            Vector2(half.x*0.31,-half.y*0.26+y_bias)
        ],0.68,1.0)
        draw_circle(Vector2(-half.x*0.62,half.y*0.18),1.8,Color(0.19,0.12,0.075,0.72))
    if stage >= 3:
        var hole_alpha = 0.46 if _kind() != "window" else 0.28
        draw_circle(Vector2(half.x*0.02,-1.0+y_bias),min(half.x,half.y)*0.34,Color(0.035,0.032,0.028,hole_alpha))
        _draw_crack([
            Vector2(-half.x*0.72,-half.y*0.40+y_bias),
            Vector2(-half.x*0.42,-half.y*0.12+y_bias),
            Vector2(-half.x*0.66,half.y*0.38+y_bias)
        ],0.94,1.55)

func _draw_reinforcement(half):
    if not _is_reinforced() or _damage_stage() >= 3:
        return
    var c = Color(0.28,0.25,0.20,0.42)
    draw_line(Vector2(-half.x*0.78,-half.y*0.42),Vector2(half.x*0.76,half.y*0.34),c,2.0,true)
    draw_line(Vector2(-half.x*0.72,half.y*0.40),Vector2(half.x*0.72,-half.y*0.36),c,2.0,true)

func _draw_hit_fx(half):
    if get_parent() == null:
        return
    var impact = clamp(float(get_parent().get_meta("breach_impact",0.0)) / 0.35,0.0,1.0)
    if impact <= 0.015:
        return
    var outward = _attack_dir()
    var perp = Vector2(-outward.y,outward.x)
    var edge = Vector2(outward.x * half.x,outward.y * half.y)
    var c = Color(0.66,0.53,0.36,0.24 + impact * 0.46)
    draw_circle(edge - outward * 2.0,2.0 + impact * 2.2,c)
    for i in range(4):
        var lane = float(i) - 1.5
        var start = edge + perp * lane * 2.6
        var finish = start - outward * (4.0 + impact * (4.0 + float(i))) + perp * lane * 1.2
        draw_line(start,finish,c,0.8 + impact * 0.8,true)

func _draw_transition_fx(half):
    if not _transition_active():
        return
    var age = _transition_age()
    var duration = 0.72 if _damage_stage() >= 3 else 0.48
    var t = clamp(age / duration,0.0,1.0)
    var fade = 1.0 - t
    var attack = _attack_dir()
    var perp = Vector2(-attack.y,attack.x)
    var dust_c = Color(0.43,0.36,0.28,0.34 * fade)
    var chip_c = Color(0.19,0.14,0.095,0.72 * fade)
    var count = 9 if _damage_stage() >= 3 else 5
    for i in range(count):
        var fi = float(i)
        var side = -1.0 if i % 2 == 0 else 1.0
        var spread = (fi / max(1.0,float(count-1)) - 0.5) * 2.0
        var travel = 4.0 + t * (8.0 + fi * 0.85)
        var origin = perp * spread * half.x * 0.68 - attack * 2.0
        var pos = origin - attack * travel + perp * side * t * (2.0 + fi * 0.45)
        draw_circle(pos,1.1 + (1.0 - t) * 1.2,dust_c)
        if i < count - 2:
            var chip_end = pos + Vector2(side * (1.5 + fi*0.12),2.0 + t * 3.0)
            draw_line(pos,chip_end,chip_c,1.0,true)
    if _breach_burst_active():
        var ring_r = 5.0 + t * 12.0
        draw_arc(Vector2.ZERO,ring_r,0.0,TAU,20,Color(0.62,0.44,0.27,0.26*fade),1.2,true)
        # A fast downward settle sells the final break without moving collision data.
        var settle = sin(clamp(t,0.0,1.0) * PI) * 2.0
        draw_line(Vector2(-half.x*0.62,half.y*0.70+settle),Vector2(half.x*0.55,half.y*0.70+settle),Color(0.14,0.10,0.07,0.50*fade),1.6,true)

func _draw_attack_indicator(half):
    if not _recently_attacked():
        return
    var pulse = 0.5 + 0.5 * sin(phase * 7.5)
    var alpha = 0.34 + pulse * 0.32
    var c = Color(1.0,0.47,0.11,alpha)
    var pad = 3.5 + pulse * 1.25
    var left = -half.x - pad
    var right = half.x + pad
    var top = -half.y - pad
    var bottom = half.y + pad
    var arm = 4.5
    draw_line(Vector2(left,top),Vector2(left+arm,top),c,1.6,true)
    draw_line(Vector2(left,top),Vector2(left,top+arm),c,1.6,true)
    draw_line(Vector2(right,top),Vector2(right-arm,top),c,1.6,true)
    draw_line(Vector2(right,top),Vector2(right,top+arm),c,1.6,true)
    draw_line(Vector2(left,bottom),Vector2(left+arm,bottom),c,1.6,true)
    draw_line(Vector2(left,bottom),Vector2(left,bottom-arm),c,1.6,true)
    draw_line(Vector2(right,bottom),Vector2(right-arm,bottom),c,1.6,true)
    draw_line(Vector2(right,bottom),Vector2(right,bottom-arm),c,1.6,true)
    var marker = PackedVector2Array([
        Vector2(0,top-3.0-pulse),Vector2(-2.8,top-7.0-pulse),Vector2(2.8,top-7.0-pulse)
    ])
    draw_colored_polygon(marker,c)

func _draw():
    var half = _half_size()
    _draw_damage(_damage_stage(),half)
    _draw_reinforcement(half)
    _draw_hit_fx(half)
    _draw_transition_fx(half)
    _draw_attack_indicator(half)
