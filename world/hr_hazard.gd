extends Node2D

# OSTATOK 1.66 — the hazards of the High Risk sites. Each site has its own:
#   gas      quarantine centre: a leaking canister breathes a green cloud;
#            inside it the survivor chokes (health, stamina, an open wound
#            festers). Seen from afar, walked round.
#   tripwire Bastion: a grenade on a stake and a wire to the next stake. The
#            wire glints only close up (better when crouching); walking or
#            running into it pulls the pin - a click, half a second, a blast
#            that hurts everyone near and calls the whole yard. Crouched you
#            step over it; up close it can be cut (wire and powder).
#   alarm    clinic: an old motion sensor with a red diode. Walking past sets
#            off the siren for several seconds - the infected come. Crouched
#            you can creep close enough to switch it off (wire and scrap).
#   steam    Vector: a vent grate that hisses and spits a warning puff, then
#            blows scalding steam for a second and a half, over and over.
# Purely local, regenerated with the sector; spent hazards stay spent while
# the sector is loaded.

var game = null
var kind = "gas"
var length = 60.0            # tripwire: from the grenade stake along +x
var radius = 42.0
var spent = false
var _t = 0.0
var _state = "idle"
var _state_t = 0.0
var _cd = 0.0
var _puffs = []
var _wire = null
var _diode = null
var _plume = null
var _warn = null
var _siren_left = 0.0
var _fuse = -1.0
var _stepped_over = false

const GAS_DPS = 1.5
const GAS_STAMINA = 7.0
const STEAM_DPS = 9.0

func setup(g, k: String, params: Dictionary = {}) -> void:
	game = g
	kind = k
	length = float(params.get("length", length))
	radius = float(params.get("radius", {"gas": 42.0, "tripwire": 0.0, "alarm": 40.0, "steam": 28.0}.get(kind, 40.0)))
	add_to_group("hr_hazards")
	set_meta("hr_hazard", kind)
	z_as_relative = true
	match kind:
		"gas": _build_gas()
		"tripwire": _build_tripwire()
		"alarm": _build_alarm()
		"steam": _build_steam()
	if kind == "tripwire" or kind == "alarm":
		add_to_group("interactable")
		set_meta("interaction_type", "hr_hazard")
		set_meta("display_name", "РАСТЯЖКА" if kind == "tripwire" else "ДАТЧИК ТРЕВОГИ")
		set_meta("interaction_radius", 30.0)
	_state_t = float(abs(hash(position)) % 400) / 100.0

# ------------------------------------------------------------------ build --
func _build_gas() -> void:
	# a dented drum on its side, green ooze at the bung
	game._ellipse(Vector2(1, 4), 9.0, 3.0, Color(0, 0, 0, 0.3), self)
	game._rect(Vector2(0, -2), Vector2(14, 8), Color("5b6658"), self)
	game._rect(Vector2(0, -5), Vector2(14, 2), Color("76826f"), self)
	game._rect(Vector2(-4, -2), Vector2(1, 8), Color("3f473c"), self)
	game._rect(Vector2(4, -2), Vector2(1, 8), Color("3f473c"), self)
	game._ellipse(Vector2(8, 2), 4.0, 1.6, Color("7fa83a"), self)
	for i in range(6):
		var a = TAU * float(i) / 6.0
		var p = game._ellipse(Vector2(cos(a), sin(a) * 0.6) * radius * 0.45, radius * 0.55, radius * 0.38, Color(0.52, 0.70, 0.22, 0.16), self)
		p.z_index = 3
		p.set_meta("phase", a)
		_puffs.append(p)

func _build_tripwire() -> void:
	# the grenade stake at the origin, the anchor stake at +length
	for x in [0.0, length]:
		game._rect(Vector2(x, -3), Vector2(2, 7), Color("4a3a2a"), self)
		game._rect(Vector2(x - 0.5, -3), Vector2(1, 7), Color("6b5640"), self)
	game._ellipse(Vector2(-2.5, -4), 2.6, 3.0, Color("4d5638"), self)
	game._rect(Vector2(-2.5, -7.5), Vector2(2, 1.5), Color("8a8c86"), self)
	_wire = Line2D.new()
	_wire.width = 0.6
	_wire.default_color = Color(0.82, 0.82, 0.76, 1.0)
	_wire.add_point(Vector2(0, -2))
	_wire.add_point(Vector2(length, -2))
	_wire.modulate.a = 0.12
	add_child(_wire)

func _build_alarm() -> void:
	# a grey sensor box on a short post, a red diode, a faint red cone on the floor
	game._rect(Vector2(0, -6), Vector2(2, 10), Color("5d605e"), self)
	game._rect(Vector2(0, -12), Vector2(7, 5), Color("c9cbc4"), self)
	game._rect(Vector2(0, -10), Vector2(7, 1), Color("8d908a"), self)
	_diode = game._rect(Vector2(2, -13), Vector2(1.5, 1.5), Color("ff3b2e"), self)
	_warn = game._ellipse(Vector2(0, 8), radius, radius * 0.55, Color(0.9, 0.15, 0.1, 0.05), self)
	_warn.z_index = -1

func _build_steam() -> void:
	# a floor grate with slits, rust round the frame
	game._rect(Vector2.ZERO, Vector2(22, 12), Color("2a2d2c"), self)
	game._rect(Vector2.ZERO, Vector2(20, 10), Color("1a1c1c"), self)
	for i in range(5):
		game._rect(Vector2(-8 + i * 4, 0), Vector2(1.5, 8), Color("505553"), self)
	game._rect(Vector2(0, -5.5), Vector2(22, 1), Color("7a5a3c"), self)
	_plume = CPUParticles2D.new()
	_plume.amount = 46
	_plume.lifetime = 1.1
	_plume.emitting = false
	_plume.local_coords = false
	_plume.direction = Vector2(0, -1)
	_plume.spread = 22.0
	_plume.initial_velocity_min = 40.0
	_plume.initial_velocity_max = 75.0
	_plume.gravity = Vector2(6, -18)
	_plume.scale_amount_min = 2.5
	_plume.scale_amount_max = 5.0
	var ramp = Gradient.new()
	ramp.set_color(0, Color(0.92, 0.94, 0.95, 0.75))
	ramp.set_color(1, Color(0.85, 0.88, 0.90, 0.0))
	_plume.color_ramp = ramp
	_plume.z_index = 30
	_plume.z_as_relative = false
	add_child(_plume)
	_warn = game._ellipse(Vector2(0, 0), radius, radius * 0.6, Color(1, 1, 1, 0.0), self)

# ----------------------------------------------------------------- update --
func _process(delta: float) -> void:
	if game == null or game.player == null or spent:
		return
	var pp: Vector2 = game.player.global_position
	if pp.distance_to(global_position) > 700.0:
		return
	_t += delta
	_cd = max(0.0, _cd - delta)
	match kind:
		"gas": _tick_gas(delta, pp)
		"tripwire": _tick_tripwire(delta, pp)
		"alarm": _tick_alarm(delta, pp)
		"steam": _tick_steam(delta, pp)

func _hurtable() -> bool:
	return not (game.qa_visual_mode or game.developer_invulnerable)

func _tick_gas(delta: float, pp: Vector2) -> void:
	for p in _puffs:
		var ph = float(p.get_meta("phase", 0.0))
		p.position = (Vector2(cos(ph + _t * 0.25), sin(ph + _t * 0.25) * 0.6) * radius * 0.42).round()
		p.modulate.a = 0.75 + 0.25 * sin(_t * 0.9 + ph * 2.0)
	var d = pp.distance_to(global_position)
	if d < 220.0 and _cd <= 0.0:
		game._play_distance_sfx("hz_gas", global_position, -20.0, 220.0, 0.05)
		_cd = 2.0
	if d > radius or not _hurtable():
		return
	game.health = max(0.0, game.health - GAS_DPS * delta)
	game.stamina = max(0.0, game.stamina - GAS_STAMINA * delta)
	if game.bleeding:
		game.wound_contamination = clamp(game.wound_contamination + 3.5 * delta, 0.0, 100.0)
	game.modern_survivor_hit_time = max(game.modern_survivor_hit_time, 0.08)
	if int(_t * 2.0) != int((_t - delta) * 2.0):
		game._set_survival_feedback("ЗАРАЖЁННЫЙ ГАЗ — НЕ ДЫШИ, УХОДИ", 1.0)

func _segment_distance(p: Vector2) -> float:
	var a = global_position + Vector2(0, -2)
	var b = global_position + Vector2(length, -2)
	return Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p)

func _tick_tripwire(delta: float, pp: Vector2) -> void:
	if _fuse >= 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			_explode()
		return
	var foot = pp + Vector2(0, 10)
	var d = _segment_distance(foot)
	# the wire glints only close up; crouched, the eye is nearer the ground
	var see = 90.0 if game.is_crouching else 55.0
	_wire.modulate.a = clamp(1.0 - (d - 10.0) / see, 0.10, 0.95)
	if d < 3.5:
		if game.is_crouching:
			if not _stepped_over:
				_stepped_over = true
				game._set_survival_feedback("ПЕРЕШАГНУЛ РАСТЯЖКУ", 1.4)
		else:
			_pull_pin()
	elif d > 14.0:
		_stepped_over = false
	# the infected blunder into it too
	for e in get_tree().get_nodes_in_group("infected"):
		if is_instance_valid(e) and e.global_position.distance_to(global_position) < length + 30.0 and _segment_distance(e.global_position + Vector2(0, 10)) < 3.5:
			_pull_pin()
			return

func _pull_pin() -> void:
	if _fuse >= 0.0:
		return
	_fuse = 0.6
	game._play_distance_sfx("hz_click", global_position, -6.0, 300.0, 0.02)
	if game.player.global_position.distance_to(global_position) < 160.0:
		game._set_survival_feedback("РАСТЯЖКА! В СТОРОНУ!", 1.2)

func _explode() -> void:
	spent = true
	var at = global_position + Vector2(-2, -4)
	game._play_distance_sfx("hz_explosion", at, 2.0, 1400.0, 0.03)
	game._emit_ai_sound(at, 900.0, "gunshot", 1.3)
	var pd = game.player.global_position.distance_to(at)
	if pd < 80.0 and _hurtable():
		var dmg = 58.0 * (1.0 - pd / 80.0)
		game._apply_enemy_hit(dmg, true)
	if pd < 400.0:
		game.camera_kick += (game.player.global_position - at).normalized() * 6.0 * (1.0 - pd / 400.0)
	for e in get_tree().get_nodes_in_group("infected"):
		if is_instance_valid(e):
			var ed = e.global_position.distance_to(at)
			if ed < 80.0:
				game._damage_enemy(e, 90.0 * (1.0 - ed / 80.0) + 10.0, (e.global_position - at).normalized())
	_blast_visual(at)
	if is_instance_valid(_wire):
		_wire.queue_free()
	remove_from_group("interactable")

func _blast_visual(at: Vector2) -> void:
	var fx = Node2D.new()
	fx.z_index = 30
	fx.z_as_relative = false
	game.add_child(fx)
	fx.global_position = at
	var flash = game._ellipse(Vector2.ZERO, 34.0, 22.0, Color(1.0, 0.86, 0.5, 0.85), fx)
	var scorch = game._ellipse(Vector2(0, 4), 22.0, 12.0, Color(0.05, 0.05, 0.04, 0.55), self)
	scorch.z_index = -1
	var smoke = CPUParticles2D.new()
	smoke.amount = 40
	smoke.lifetime = 2.2
	smoke.one_shot = true
	smoke.explosiveness = 0.9
	smoke.direction = Vector2(0, -1)
	smoke.spread = 180.0
	smoke.initial_velocity_min = 20.0
	smoke.initial_velocity_max = 70.0
	smoke.gravity = Vector2(4, -10)
	smoke.scale_amount_min = 3.0
	smoke.scale_amount_max = 7.0
	var ramp = Gradient.new()
	ramp.set_color(0, Color(0.30, 0.28, 0.25, 0.8))
	ramp.set_color(1, Color(0.30, 0.30, 0.30, 0.0))
	smoke.color_ramp = ramp
	fx.add_child(smoke)
	smoke.emitting = true
	var tw = fx.create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.25)
	tw.tween_interval(2.4)
	tw.tween_callback(fx.queue_free)

func _tick_alarm(delta: float, pp: Vector2) -> void:
	if _siren_left > 0.0:
		_siren_left -= delta
		_diode.modulate.a = 1.0 if int(_t * 8.0) % 2 == 0 else 0.15
		if _cd <= 0.0:
			game._play_distance_sfx("base_siren", global_position, -4.0, 1200.0, 0.0)
			game._emit_ai_sound(global_position, 1000.0, "infected_call", 1.4)
			_cd = 1.6
		if _siren_left <= 0.0:
			spent = true
			_diode.modulate.a = 0.0
			remove_from_group("interactable")
		return
	_diode.modulate.a = 1.0 if fmod(_t, 1.6) < 0.18 else 0.25
	var d = pp.distance_to(global_position)
	var reach = radius * (0.45 if game.is_crouching else 1.0)
	_warn.modulate.a = clamp(1.0 - (d - radius) / 80.0, 0.0, 1.0)
	if d < reach:
		_siren_left = 7.0
		_cd = 0.0
		game._play_distance_sfx("hz_beep", global_position, -8.0, 300.0, 0.0)
		game._set_survival_feedback("СРАБОТАЛ ДАТЧИК — ОНИ ИДУТ", 1.8)

func _tick_steam(delta: float, pp: Vector2) -> void:
	_state_t -= delta
	match _state:
		"idle":
			if _state_t <= 0.0:
				_state = "warn"
				_state_t = 1.2
				game._play_distance_sfx("hz_hiss", global_position, -10.0, 320.0, 0.05)
				_plume.amount = 46
				_plume.emitting = true
				_plume.initial_velocity_max = 25.0
		"warn":
			_warn.modulate = Color(1, 1, 1, 0.10)
			if _state_t <= 0.0:
				_state = "burst"
				_state_t = 1.6
				_plume.initial_velocity_max = 75.0
				game._play_distance_sfx("hz_steam", global_position, -4.0, 500.0, 0.05)
		"burst":
			_warn.modulate = Color(1, 1, 1, 0.22)
			if pp.distance_to(global_position) < radius and _hurtable():
				game.health = max(0.0, game.health - STEAM_DPS * delta)
				game.modern_survivor_hit_time = max(game.modern_survivor_hit_time, 0.1)
				if _cd <= 0.0:
					game._set_survival_feedback("ПАР! ОЖОГ", 0.9)
					_cd = 0.8
			if _state_t <= 0.0:
				_state = "idle"
				_state_t = 3.5 + float(abs(hash(Vector2(position.x, _t))) % 300) / 100.0
				_plume.emitting = false
				_warn.modulate = Color(1, 1, 1, 0.0)

# ---------------------------------------------------------------- disarm --
func interaction_label() -> String:
	if kind == "tripwire":
		return "СНЯТЬ РАСТЯЖКУ  •  ОСТОРОЖНО"
	return "ОТКЛЮЧИТЬ ДАТЧИК"

func disarm() -> void:
	if spent:
		return
	if kind == "tripwire":
		if _fuse >= 0.0:
			return
		if not game.is_crouching and randf() < 0.35:
			# a clumsy hand on a taut wire
			_pull_pin()
			return
		spent = true
		if is_instance_valid(_wire):
			_wire.queue_free()
		game._grid_add(game.inventory_entries, "wire", 1, game.INV_W, game.INV_H)
		game._grid_add(game.inventory_entries, "gunpowder", 1, game.INV_W, game.INV_H)
		game._set_survival_feedback("РАСТЯЖКА СНЯТА  •  +ПРОВОД, +ПОРОХ", 2.0)
		game._play_distance_sfx("hz_click", global_position, -14.0, 200.0, 0.02)
	elif kind == "alarm":
		if _siren_left > 0.0:
			return
		spent = true
		_diode.modulate.a = 0.0
		_warn.modulate.a = 0.0
		game._grid_add(game.inventory_entries, "wire", 1, game.INV_W, game.INV_H)
		game._grid_add(game.inventory_entries, "scrap", 1, game.INV_W, game.INV_H)
		game._set_survival_feedback("ДАТЧИК ОТКЛЮЧЁН  •  +ПРОВОД, +ЛОМ", 2.0)
	remove_from_group("interactable")
