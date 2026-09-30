extends "res://main_script_mod.gd"

# Exercise production survival functions without generating the region or touching saves.
var save_calls = 0

# Most gameplay suites exercise firing/reload/cycle mechanics, not the audio device.
# Keep headless tests silent so immediate suite shutdown cannot leave AudioServer
# playback objects alive. test_weapon_audio explicitly enables the real layer.
var test_audio_enabled := false

func _play_weapon_shot_audio(weapon_id,weapon = {},instance_id = ""):
    if test_audio_enabled:
        super._play_weapon_shot_audio(weapon_id,weapon,instance_id)

func _play_weapon_reload_audio(weapon_id):
    if test_audio_enabled:
        super._play_weapon_reload_audio(weapon_id)

func _play_weapon_cycle_audio(profile):
    if test_audio_enabled:
        super._play_weapon_cycle_audio(profile)

func _play_dry_fire_audio():
    if test_audio_enabled:
        super._play_dry_fire_audio()

func _ready():
    set_process(false)
    _load_data()
    player = CharacterBody2D.new()
    add_child(player)
    player_light = PointLight2D.new()
    player.add_child(player_light)
    roof_records = [{"rect":Rect2(-50,-50,100,100)}]
    base_objects = [{"id":1,"kind":"cot","x":0.0,"y":0.0}]
    rest_source_base_id = 1
    rest_open = true
    inventory_open = true
    hunger = 90.0
    thirst = 90.0
    fatigue = 80.0
    world_day = 1
    world_minutes = 14.0 * 60.0
    weather_state = "clear"
    weather_timer = 10000.0
    equipment = {}
    _thermal_tick(0.0)

func _save_state():
    save_calls += 1

func add_source(kind,fuel_value,pos = Vector2.ZERO):
    base_objects.append({
        "id":base_objects.size() + 1,"kind":kind,"on":true,
        "fuel":fuel_value,"x":pos.x,"y":pos.y,"sound_timer":1.5
    })

func set_test_weapon_state(id,mag_value,condition_value = 100.0):
    _ensure_runtime_item_instance_ids()
    _ensure_weapon_runtime_state(false)
    var iid = _find_inventory_weapon_instance(id)
    if iid == "":
        return ""
    _set_weapon_mag_value(id,mag_value,iid)
    var state = _weapon_instance_state(id,iid,true)
    state["condition"] = condition_value
    weapon_instance_states[iid] = state
    _sync_legacy_weapon_projection_for_type(id)
    return iid
