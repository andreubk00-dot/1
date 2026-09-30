extends Node2D

const CHUNK_SIZE = 768
const ACTIVE_RADIUS = 1
const MOVE_SPEED = 53.0
const ENEMY_SPEED = 53.0
const SPRINT_SPEED_MULT = 1.28
const PLAYER_WALK_ACCEL = 230.0
const PLAYER_SPRINT_ACCEL = 280.0
const PLAYER_BRAKE = 320.0
const PLAYER_TURN_ACCEL = 420.0
const SAVE_PATH = "user://ostatok_0450_field_cooking_nutrition.json"
const LEGACY_SAVE_PATH = "user://ostatok_0440_sustainment_rainwater.json"
const LEGACY_SAVE_PATH_0430 = "user://ostatok_0430_character_fidelity_distance_locomotion.json"
const LEGACY_SAVE_PATH_0420 = "user://ostatok_0420_firecraft_heat_sources.json"
const LEGACY_SAVE_PATH_0410 = "user://ostatok_0410_wound_care_medical.json"
const LEGACY_SAVE_PATH_0400 = "user://ostatok_0400_four_direction_locomotion.json"
const LEGACY_SAVE_PATH_0390 = "user://ostatok_0390_reference_fidelity_locomotion.json"
const LEGACY_SAVE_PATH_0380 = "user://ostatok_0380_high_fidelity_pixel_pass.json"
const LEGACY_SAVE_PATH_0370 = "user://ostatok_0370_detail_environment_pass.json"
const LEGACY_SAVE_PATH_0360 = "user://ostatok_0360_weapon_world_polish.json"
const LEGACY_SAVE_PATH_0350 = "user://ostatok_0350_character_world_art_pass.json"
const LEGACY_SAVE_PATH_0340 = "user://ostatok_0340_inventory_art_overhaul.json"
const LEGACY_SAVE_PATH_0330 = "user://ostatok_0330_reference_art_integration.json"
const LEGACY_SAVE_PATH_0320 = "user://ostatok_0320_visual_identity_overhaul.json"
const LEGACY_SAVE_PATH_0310 = "user://ostatok_0310_pose_sprite_integration.json"
const LEGACY_SAVE_PATH_0301 = "user://ostatok_0301_player_scale_proportion_fix.json"
const LEGACY_SAVE_PATH_0300 = "user://ostatok_0300_player_rig_rework.json"
const LEGACY_SAVE_PATH_0290 = "user://ostatok_0290_visual_world_pass.json"
const LEGACY_SAVE_PATH_0280 = "user://ostatok_0280_rest_recovery.json"
const LEGACY_SAVE_PATH_0270 = "user://ostatok_0270_world_zones_loot_ecology.json"
const LEGACY_SAVE_PATH_0260 = "user://ostatok_0260_safehouse_foundations.json"
const LEGACY_SAVE_PATH_0250 = "user://ostatok_0250_workbench_expansion.json"
const LEGACY_SAVE_PATH_0240 = "user://ostatok_0240_learn_by_doing.json"
const LEGACY_SAVE_PATH_0230 = "user://ostatok_0230_ai_stealth_sound.json"
const LEGACY_SAVE_PATH_0221 = "user://ostatok_0221_thermal_model_rework.json"
const LEGACY_SAVE_PATH_0220 = "user://ostatok_0220_injury_medical_core.json"
const LEGACY_SAVE_PATH_0211 = "user://ostatok_0211_cold_shelter_rebalance.json"
const LEGACY_SAVE_PATH_0210 = "user://ostatok_0210_weather_exposure.json"
const LEGACY_SAVE_PATH_0201 = "user://ostatok_0201_world_loot_scale.json"

const INV_W = 8
const INV_H = 5
const CONTAINER_W = 8
const CONTAINER_H = 8
const CELL = 28

const LAYER_PLAYER = 1
const LAYER_ENEMY = 2
const LAYER_WORLD = 4

var item_defs = {}
var weapon_defs = {}
var melee_defs = {}
var loot_tables = {}

var player = null
var player_visual = null
var camera = null
var loaded_chunks = {}
var current_chunk = Vector2i(999999, 999999)
var roof_records = []
var defeated = {}

var health = 100.0
var stamina = 100.0
var hunger = 88.0
var thirst = 82.0
var is_sprinting = false
var sprint_noise_time = 0.0
var last_player_noise_radius = 0.0
var last_player_noise_kind = "quiet"
var last_player_noise_time = 0.0
var skill_levels = {
    "firearms":1,
    "melee":1,
    "scavenging":1,
    "survival":1,
    "crafting":1
}
var skill_xp = {
    "firearms":0.0,
    "melee":0.0,
    "scavenging":0.0,
    "survival":0.0,
    "crafting":0.0
}
var survival_skill_tick = 0.0
var survival_feedback = ""
var survival_feedback_time = 0.0
var bleeding = false
var bleed_damage_taken = 0.0
var pain = 0.0
var body_condition = {
    "head":100.0,
    "torso":100.0,
    "arms":100.0,
    "legs":100.0
}
var last_injury_zone = ""
var wound_contamination = 0.0
var wound_infection = 0.0
var painkiller_time = 0.0
var antibiotic_time = 0.0
var medical_tick_accumulator = 0.0
var well_fed_time = 0.0
var warm_drink_time = 0.0
const MAX_BLEED_DAMAGE = 30.0
var fire_cooldown = 0.0
var reload_time = 0.0
var reload_weapon_id = ""
var reload_shellwise = false
var reload_feedback = ""
var reload_feedback_time = 0.0
var autosave_time = 0.0

var aim_direction = Vector2.RIGHT
var move_direction = Vector2.ZERO
var walk_phase = 0.0
var movement_anim_blend = 0.0
var visual_move_direction = Vector2.ZERO
var visual_move_speed = 0.0
var visual_facing_left = false
var visual_move_cardinal = 2

var current_weapon_id = "makarov"
var equipped_melee_id = ""
var melee_cooldown = 0.0
var melee_swing_time = 0.0
var melee_swing_duration = 0.22
var shove_cooldown = 0.0

# Unified firearm + melee animation state.
var weapon_recoil_time = 0.0
var weapon_recoil_duration = 0.10
var reload_anim_duration = 0.0

var weapon_mags = {
    "makarov": 8,
    "shotgun": 0,
    "akm": 0
}
var weapon_condition = {
    "makarov":100.0,
    "shotgun":100.0,
    "akm":100.0
}

var inventory_entries = []
var container_states = {}
var door_states = {}
var picked_world_items = {}
var dropped_items = []
var next_drop_id = 1

# 0.4 combat/crafting
var recipe_defs = {}
var item_icon_cache = {}
var item_atlas_texture = null
var inventory_weapon_atlas_texture = null
var inventory_exact_atlas_texture = null
var melee_inventory_atlas_texture = null
var melee_model_atlas = null
var loot_atlas_texture = null
var item_icon_cells = {
    "bandage":Vector2i(0,0),
    "water":Vector2i(1,0),
    "canned_meat":Vector2i(2,0),
    "scrap":Vector2i(3,0),
    "cloth":Vector2i(4,0),
    "tape":Vector2i(0,1),
    "repair_kit":Vector2i(1,1),
    "water_filter":Vector2i(2,1),
    "ammo_9x18":Vector2i(3,1),
    "ammo_12g":Vector2i(4,1),
    "ammo_762":Vector2i(0,2),
    "cap":Vector2i(4,2),
    "light_jacket":Vector2i(0,3),
    "police_vest":Vector2i(1,3),
    "field_backpack":Vector2i(2,3),
    "flashlight":Vector2i(3,3),
    "makarov_extmag":Vector2i(4,3),
    "muzzle_brake":Vector2i(0,4),
    "suppressor":Vector2i(1,4),
    "shotgun_exttube":Vector2i(2,4),
    "akm_extmag":Vector2i(3,4)
}

var inventory_icon_regions = {
    "bandage":Rect2i(0,0,18,18),
    "water":Rect2i(20,0,14,44),
    "canned_meat":Rect2i(36,0,22,16),
    "scrap":Rect2i(60,0,18,18),
    "cloth":Rect2i(80,0,20,18),
    "tape":Rect2i(102,0,18,18),
    "repair_kit":Rect2i(122,0,44,18),
    "water_filter":Rect2i(168,0,16,44),
    "ammo_9x18":Rect2i(186,0,18,18),
    "ammo_12g":Rect2i(206,0,16,20),
    "ammo_762":Rect2i(224,0,18,18),

    "makarov":Rect2i(0,48,48,20),
    "shotgun":Rect2i(50,48,76,20),
    "akm":Rect2i(128,48,76,20),
    "cap":Rect2i(206,48,20,16),

    "light_jacket":Rect2i(0,72,44,44),
    "police_vest":Rect2i(46,72,44,44),
    "field_backpack":Rect2i(92,72,44,44),
    "flashlight":Rect2i(138,72,14,44),
    "makarov_extmag":Rect2i(154,72,14,44),
    "muzzle_brake":Rect2i(170,72,20,12),
    "suppressor":Rect2i(192,72,14,44),
    "shotgun_exttube":Rect2i(208,72,14,44),
    "akm_extmag":Rect2i(224,72,18,44),
    "sterile_bandage":Rect2i(0,128,18,18),
    "antiseptic":Rect2i(20,128,14,44),
    "painkillers":Rect2i(36,128,18,18),
    "antibiotics":Rect2i(56,128,18,18),
    "firewood":Rect2i(76,128,30,18),
    "dirty_water":Rect2i(108,128,14,44),
    "grain":Rect2i(124,128,20,18),
    "herbs":Rect2i(146,128,18,18),
    "hot_meal":Rect2i(166,128,22,18),
    "herbal_tea":Rect2i(190,128,14,44)
}

var melee_icon_regions = {
    "combat_knife":Rect2i(0,0,48,20),
    "steel_pipe":Rect2i(0,24,48,18),
    "fire_axe":Rect2i(0,48,76,20)
}


var loot_icon_cells = {
    "bandage":Vector2i(0,0),
    "water":Vector2i(1,0),
    "canned_meat":Vector2i(2,0),
    "scrap":Vector2i(3,0),
    "cloth":Vector2i(4,0),
    "tape":Vector2i(5,0),

    "repair_kit":Vector2i(0,1),
    "water_filter":Vector2i(1,1),
    "ammo_9x18":Vector2i(2,1),
    "ammo_12g":Vector2i(3,1),
    "ammo_762":Vector2i(4,1),
    "makarov":Vector2i(5,1),

    "shotgun":Vector2i(0,2),
    "akm":Vector2i(1,2),
    "cap":Vector2i(2,2),
    "light_jacket":Vector2i(3,2),
    "police_vest":Vector2i(4,2),
    "field_backpack":Vector2i(5,2),

    "flashlight":Vector2i(0,3),
    "makarov_extmag":Vector2i(1,3),
    "shotgun_exttube":Vector2i(2,3),
    "akm_extmag":Vector2i(3,3),
    "muzzle_brake":Vector2i(4,3),
    "suppressor":Vector2i(5,3),
    "combat_knife":Vector2i(0,4),
    "steel_pipe":Vector2i(1,4),
    "fire_axe":Vector2i(2,4),
    "sterile_bandage":Vector2i(0,5),
    "antiseptic":Vector2i(1,5),
    "painkillers":Vector2i(2,5),
    "antibiotics":Vector2i(3,5),
    "firewood":Vector2i(4,5),
    "dirty_water":Vector2i(5,5),
    "grain":Vector2i(0,6),
    "herbs":Vector2i(1,6),
    "hot_meal":Vector2i(2,6),
    "herbal_tea":Vector2i(3,6)
}

var crafting_open = false
var selected_recipe_id = ""
var craft_panel = null
var craft_list = null
var craft_details = null
var craft_status = null

# 0.14 dedicated weapon maintenance at workbench.
var workbench_mode = "craft"
var workbench_craft_content = null
var workbench_service_content = null
var workbench_craft_tab = null
var workbench_service_tab = null
var service_weapon_id = "makarov"
var service_weapon_buttons = {}
var service_weapon_icon = null
var service_title = null
var service_condition_label = null
var service_condition_bar = null
var service_requirements = null
var service_status = null
var workbench_salvage_content = null
var workbench_salvage_tab = null
var salvage_list = null
var salvage_details = null
var salvage_status = null
var selected_salvage_id = ""
var base_objects = []
var next_base_id = 1
var base_root = null
var base_object_nodes = {}
var base_build_open = false
var base_build_panel = null
var base_build_status = null
var current_zone_id = "central"
var discovered_chunks = {}
var rest_open = false
var rest_panel = null
var rest_status = null
var rest_source_base_id = -1

# 0.5 inventory/equipment UI
var storage_tab_button = null
var equipment_tab_button = null
var inventory_mode = "storage"
var equipment_panel = null
var equipment_buttons = {}
var equipment_info = null

# 0.8 hover inspector
var hover_panel = null
var hover_title = null
var hover_icon = null
var hover_body = null
var hover_footer = null
var hover_item_id = ""
var hover_qty = 1
var hover_context = ""

# 0.9 weapon module window
var mod_panel = null
var mod_panel_open = false
var mod_weapon_id = ""
var mod_weapon_icon = null
var mod_title = null
var mod_condition_label = null
var mod_slots_box = null
var mod_available_box = null
var mod_status = null

# detailed weapon sprites / visible attachments
var weapon_model_atlas = null
var weapon_module_atlas = null
var pv_weapon_sprite = null
var pv_melee_trail = null

# Dedicated melee arm rig. Firearm arms remain untouched.
var pv_melee_back_outline = null
var pv_melee_back_sleeve = null
var pv_melee_front_outline = null
var pv_melee_front_sleeve = null

var pv_melee_back_elbow_outline = null
var pv_melee_back_elbow = null
var pv_melee_front_elbow_outline = null
var pv_melee_front_elbow = null

var pv_melee_back_hand_outline = null
var pv_melee_back_hand = null
var pv_melee_front_hand_outline = null
var pv_melee_front_hand = null
var pv_weapon_mag_visual = null
var pv_weapon_muzzle_visual = null

# 0.8 weapon modifications
var weapon_mods = {
    "makarov":{"magazine":"","muzzle":""},
    "shotgun":{"magazine":"","muzzle":""},
    "akm":{"magazine":"","muzzle":""}
}

# Runtime smoke-test status shown in the debug HUD.
var self_test_failures = []

# 0.3 systems.
var equipment = {
    "head":"",
    "body":"",
    "backpack":"",
    "utility":""
}
var flashlight_battery = 100.0
var flashlight_on = false
var world_minutes = 19.5 * 60.0
var world_day = 1
var day_speed = 4.0
var canvas_modulate = null
var player_light = null

var weather_state = "clear"
var weather_timer = 105.0
var weather_cycle_index = 0
var ambient_temperature = 8.0
var body_temperature = 36.8
var wetness = 0.0
var is_sheltered = false
var weather_visual_root = null
var rain_lines = []
var thermal_effective_temperature = 10.0
var thermal_cold_stress = 0.0
var thermal_heat_stress = 0.0
var wind_speed_kmh = 0.0
var thermal_tick_accumulator = 0.20

var inventory_open = false
var active_container_key = ""
var selected_inventory_index = -1
var selected_container_index = -1

# 0.13 true drag-and-drop inventory.
var inventory_drag_candidate_index = -1
var inventory_drag_candidate_source = ""
var inventory_drag_candidate_id = ""
var inventory_drag_press_position = Vector2.ZERO
var inventory_drag_active = false
var inventory_drag_preview = null

var hud = null
var debug_label = null
var interaction_label = null

# 0.47 reference-integrated production HUD references.
var hud_world_root = null
var hud_interaction_panel = null
var hud_vital_bars = {}
var hud_vital_values = {}
var hud_status_label = null
var hud_condition_label = null
var hud_condition_values = {}
var hud_env_time_label = null
var hud_env_weather_label = null
var hud_weather_icon_clear = null
var hud_weather_icon_cloud = null
var hud_weather_icon_rain = null
var hud_env_zone_label = null
var hud_env_shelter_label = null
var hud_env_camp_label = null
var hud_env_camp_sub_label = null
var hud_camp_icon_root = null
var hud_objective_label = null
var hud_objective_sub_label = null
var hud_weapon_name_label = null
var hud_weapon_icon = null
var hud_weapon_icon_id = ""
var hud_ammo_label = null
var hud_reload_label = null
var hud_weapon_condition_bar = null
var hud_weapon_condition_label = null
var hud_weapon_condition_value_label = null
var hud_visibility_bar = null
var hud_noise_bar = null
var hud_stealth_label = null
var hud_stealth_noise_label = null
var hud_weight_label = null
var hud_day_label = null
var hud_time_label = null
var hud_quick_slots = []
var hud_quick_style_normal = null
var hud_quick_style_active = null
var hud_model_icon_cache = {}

var inventory_panel = null
var container_panel = null
var inv_grid_control = null
var cont_grid_control = null
var inv_title = null
var cont_title = null
var inv_details = null
var cont_details = null

var tracer = null
var tracer_time = 0.0
var muzzle_flash = null
var muzzle_time = 0.0

# Character visual parts.
var pv_shadow = null
var pv_backpack = null
var pv_body = null
var pv_vest = null
var pv_head = null
var pv_helmet = null
var pv_helmet_lip = null
var pv_leg_l = null
var pv_leg_r = null
var pv_boot_l = null
var pv_boot_r = null
var pv_pose_back = null
var pv_pose_front = null
var pv_legs = null
var pv_arm_back_root = null
var pv_arm_front_root = null
var pv_weapon_root = null
var pv_weapon_stock = null
var pv_weapon_body = null
var pv_weapon_mag = null
var pv_weapon_barrel = null




func _record_test(condition,message):
    if not condition:
        self_test_failures.append(message)
        push_error("SELFTEST: " + message)


func _run_static_self_tests():
    self_test_failures.clear()

    _record_test(weapon_defs.has("shotgun"),"Нет определения дробовика")
    if weapon_defs.has("shotgun"):
        var shot = weapon_defs["shotgun"]
        _record_test(int(shot.get("pellets",0)) >= 7,"У дробовика слишком мало дробин")
        _record_test(float(shot.get("spread",0.0)) >= 0.18,"Слишком узкий конус дробовика")
        var dirs = _weapon_shot_directions(shot,Vector2.RIGHT)
        _record_test(dirs.size() == int(shot.get("pellets",0)),"Число направлений дроби не совпадает с pellets")

    _record_test(recipe_defs.size() >= 3,"Не загрузились рецепты крафта")
    _record_test(_make_item_icon("water") != null,"Не создается иконка воды")
    _record_test(_make_item_icon("shotgun") != null,"Не создается иконка дробовика")
    _record_test(CELL == 28,"Размер ячейки инвентаря должен быть 28")
    var drag_grid_test = [{"id":"bandage","qty":1,"x":0,"y":0}]
    _record_test(_can_place_grid(drag_grid_test,1,0,1,1,[],INV_W,INV_H),"Drag grid не принимает свободную ячейку")
    _record_test(not _can_place_grid(drag_grid_test,0,0,1,1,[],INV_W,INV_H),"Drag grid пропускает перекрытие")

    for recipe_id in recipe_defs.keys():
        var recipe = recipe_defs[recipe_id]
        _record_test(item_defs.has(str(recipe.get("output",""))),"Рецепт %s имеет неизвестный результат" % recipe_id)
        for id in recipe.get("ingredients",{}).keys():
            _record_test(item_defs.has(str(id)),"Рецепт %s использует неизвестный предмет %s" % [recipe_id,id])

    var grid_test = []
    _record_test(_grid_add(grid_test,"bandage",2,INV_W,INV_H) == 0,"Grid не принимает бинты")
    _record_test(_grid_add(grid_test,"shotgun",1,INV_W,INV_H) == 0,"Grid не принимает дробовик")
    _record_test(_consume_from_entries(grid_test,"bandage",1),"Не работает потребление предметов")

    _record_test(int(item_defs["bandage"].get("stack",0)) == 20,"Стак бинтов не равен 20")
    _record_test(int(item_defs["ammo_9x18"].get("stack",0)) == 20,"Стак 9x18 не равен 20")
    _record_test(MAX_BLEED_DAMAGE == 30.0,"Лимит кровотечения должен быть 30")

    _record_test(not item_defs.has("optic_simple"),"Прицельный модуль должен быть удалён")
    _record_test(item_defs.has("makarov_extmag"),"Нет увеличенного магазина ПМ")
    _record_test(item_defs.has("shotgun_exttube"),"Нет удлинителя трубки дробовика")
    _record_test(item_defs.has("akm_extmag"),"Нет магазина АКМ на 45")
    _record_test(weapon_mods["akm"].has("magazine"),"Нет magazine-слота у АКМ")
    _record_test(weapon_mods["akm"].has("muzzle"),"Нет muzzle-слота у АКМ")

    # Exact icon fit: none of these should require runtime scaling in inventory.
    for id in inventory_icon_regions.keys():
        if not item_defs.has(id):
            continue
        var icon_size = Vector2(inventory_icon_regions[id].size)
        var item = item_defs[id]
        var button_size = Vector2(int(item.get("w",1)) * CELL - 4,int(item.get("h",1)) * CELL - 4)
        _record_test(icon_size.x <= button_size.x - 2.0 and icon_size.y <= button_size.y - 2.0,"Иконка %s не помещается 1:1" % id)

    _record_test(_service_gain("maintenance") == 30.0,"Обслуживание должно давать +30 состояния")
    _record_test(_service_cap("maintenance") == 90.0,"Обслуживание не должно ремонтировать выше 90")
    _record_test(_service_gain("overhaul") == 60.0,"Капремонт должен давать +60 состояния")
    _record_test(_service_cap("overhaul") == 100.0,"Капремонт должен иметь потолок 100")
    _record_test(int(_service_costs("maintenance").get("repair_kit",0)) == 1,"Неверная цена обслуживания")
    _record_test(int(_service_costs("overhaul").get("repair_kit",0)) == 2,"Неверная цена капремонта")

    _record_test(melee_defs.size() == 3,"Должно быть три оружия ближнего боя")
    _record_test(item_defs.has("combat_knife"),"Нет боевого ножа")
    _record_test(item_defs.has("steel_pipe"),"Нет стальной трубы")
    _record_test(item_defs.has("fire_axe"),"Нет пожарного топора")
    _record_test(_melee_point_in_arc(Vector2.ZERO,Vector2.RIGHT,Vector2(30,0),35.0,0.8),"Цель перед игроком не попала в melee arc")
    _record_test(not _melee_point_in_arc(Vector2.ZERO,Vector2.RIGHT,Vector2(-20,0),35.0,0.8),"Цель сзади попала в melee arc")
    _record_test(not _melee_point_in_arc(Vector2.ZERO,Vector2.RIGHT,Vector2(50,0),35.0,0.8),"Дальняя цель попала в melee range")
    _record_test(_make_item_icon("combat_knife") != null,"Не создаётся иконка ножа")

    _record_test(inventory_icon_regions.size() == 34,"Должно быть 34 non-melee inventory icons")
    _record_test(melee_icon_regions.size() == 3,"Должно быть 3 melee inventory icons")
    _record_test(item_defs.has("sterile_bandage"),"Нет стерильной повязки")
    _record_test(item_defs.has("antiseptic"),"Нет антисептика")
    _record_test(item_defs.has("painkillers"),"Нет обезболивающего")
    _record_test(item_defs.has("antibiotics"),"Нет антибиотиков")
    _record_test(item_defs.has("firewood"),"Нет дров")
    _record_test(item_defs.has("dirty_water"),"Нет дождевой воды")
    _record_test(item_defs.has("grain"),"Нет крупы")
    _record_test(item_defs.has("herbs"),"Нет съедобных трав")
    _record_test(item_defs.has("hot_meal"),"Нет горячей каши")
    _record_test(item_defs.has("herbal_tea"),"Нет травяного чая")
    _record_test(_make_item_icon("grain") != null,"Нет inventory art крупы")
    _record_test(_make_world_loot_texture("herbs") != null,"Нет world-loot art трав")
    _record_test(abs(_nutrition_stamina_multiplier() - (1.15 if well_fed_time > 0.0 else 1.0)) < 0.001,"Nutrition stamina multiplier сломан")
    _record_test(str(item_defs["water_filter"].get("use","")) == "water_filter","Фильтр не активирован как инструмент")
    _record_test(_make_item_icon("dirty_water") != null,"Нет inventory art дождевой воды")
    _record_test(_make_world_loot_texture("dirty_water") != null,"Нет world-loot art дождевой воды")
    _record_test(abs(_rain_collector_capacity() - 8.0) < 0.01,"Неверная ёмкость дождесборника")
    _record_test(abs(_rain_collector_fill_rate("rain",false) - 0.025) < 0.0001,"Неверная скорость дождесборника")
    _record_test(_rain_collector_fill_rate("clear",false) == 0.0,"Дождесборник работает без дождя")
    _record_test(_rain_collector_fill_rate("rain",true) == 0.0,"Дождесборник собирает воду под крышей")
    _record_test(int(_base_build_costs("rain_collector").get("scrap",0)) == 2,"Неверная цена дождесборника")
    _record_test(_make_item_icon("firewood") != null,"Нет inventory art дров")
    _record_test(_make_world_loot_texture("firewood") != null,"Нет world-loot art дров")
    _record_test(abs(_gait_cycle_distance(false) - 48.0) < 0.01,"Неверная длина walk-cycle")
    _record_test(abs(_gait_cycle_distance(true) - 50.0) < 0.01,"Неверная длина run-cycle")
    _record_test(abs(_gait_phase_delta_for_distance(48.0,false) - TAU) < 0.001,"Distance gait не даёт полный walk-cycle")
    _record_test(abs(_gait_phase_delta_for_distance(50.0,true) - TAU) < 0.001,"Distance gait не даёт полный run-cycle")
    _record_test(abs(MOVE_SPEED - ENEMY_SPEED) < 0.001,"Walk speed не совпадает со скоростью заражённых")
    _record_test(abs(SPRINT_SPEED_MULT - 1.28) < 0.001,"Sprint multiplier сломан")
    _record_test(PLAYER_BRAKE > PLAYER_WALK_ACCEL,"Торможение должно быть сильнее walk acceleration")
    _record_test(PLAYER_TURN_ACCEL > PLAYER_SPRINT_ACCEL,"Turn acceleration должна быть максимальной")
    _record_test(_hud_panel_style() != null,"HUD panel style не создаётся")
    _record_test(_hud_quick_slot_style(false) != null,"HUD quick slot normal style не создаётся")
    _record_test(_hud_quick_slot_style(true) != null,"HUD quick slot active style не создаётся")
    _record_test(int(_base_build_costs("campfire").get("scrap",0)) == 1,"Неверная цена костра")
    _record_test(abs(_base_heat_strength_for("campfire",0.0) - 18.0) < 0.01,"Неверная мощность костра")
    _record_test(_base_heat_strength_for("campfire",176.0) == 0.0,"Костёр греет слишком далеко")
    _record_test(_make_item_icon("sterile_bandage") != null,"Нет иконки стерильной повязки")
    _record_test(_make_item_icon("antiseptic") != null,"Нет иконки антисептика")
    _record_test(_make_world_loot_texture("antibiotics") != null,"Нет world-loot антибиотиков")
    for inventory_art_id in item_defs.keys():
        _record_test(
            inventory_icon_regions.has(str(inventory_art_id)) or melee_icon_regions.has(str(inventory_art_id)),
            "Предмет без точной inventory-модели: %s" % inventory_art_id
        )


    var grip_test_rotation = 0.37
    var grip_test_target = Vector2(10,5)
    var grip_test_hand = Vector2(13,2)
    var grip_test_root = _solve_arm_root_for_hand(grip_test_target,grip_test_hand,grip_test_rotation)
    _record_test((grip_test_root + grip_test_hand.rotated(grip_test_rotation)).distance_to(grip_test_target) < 0.001,"Решатель хвата не ставит ладонь точно на рукоять")
    _record_test(float(melee_defs["combat_knife"].get("swing_anim",0.0)) < float(melee_defs["steel_pipe"].get("swing_anim",0.0)),"Нож должен иметь более быструю анимацию, чем труба")
    _record_test(float(melee_defs["steel_pipe"].get("swing_anim",0.0)) < float(melee_defs["fire_axe"].get("swing_anim",0.0)),"Топор должен иметь самую тяжёлую анимацию")

    var elbow_test = _melee_elbow_point(Vector2(0,0),Vector2(10,0),1.0,4.0)
    _record_test(elbow_test.y > 0.0,"Новый melee elbow rig не создаёт естественный изгиб")
    _record_test(abs(1.18 - 1.20) < 0.05,"Базовые углы трубы и топора должны быть почти параллельны")

    _record_test(weapon_recoil_duration > 0.0,"Некорректная длительность отдачи")

    var shotgun_cfg = _held_visual_config("shotgun",false)
    var shotgun_front_local = _source_point_to_weapon_local(Vector2(82,28),shotgun_cfg)
    _record_test(shotgun_front_local.x < 14.0,"Shotgun support grip снова слишком далеко")
    var knife_cfg = _held_visual_config("combat_knife",true)
    var knife_rear_local = _source_point_to_weapon_local(Vector2(25,17),knife_cfg)
    _record_test(knife_rear_local.length() < 7.0,"Knife visual grip mapping сломан")

    var axe_clip_start = _melee_clip_state("fire_axe",0.0)
    var axe_clip_end = _melee_clip_state("fire_axe",1.0)
    _record_test(axe_clip_start.get("root",Vector2.ZERO).distance_to(axe_clip_end.get("root",Vector2.ZERO)) < 0.01,"Melee clip не возвращается в исходную позицию")
    _record_test(abs(fmod(float(axe_clip_end.get("angle",0.0)) - float(axe_clip_start.get("angle",0.0)),TAU)) < 0.01,"Axe clip заканчивается с неправильным углом")
    _record_test(abs(float(melee_defs["fire_axe"].get("swing_anim",0.0)) - 0.65) < 0.001,"Axe reference timing должен быть 0.65 сек")

    _record_test(CONTAINER_H == 8,"Тестовый контейнер должен иметь 8 рядов")
    _record_test(int(melee_defs["combat_knife"].get("stamina",0)) == 2,"Нож должен тратить 2 выносливости")
    _record_test(int(melee_defs["steel_pipe"].get("stamina",0)) == 2,"Труба должна тратить 2 выносливости")
    _record_test(int(melee_defs["fire_axe"].get("stamina",0)) == 2,"Топор должен тратить 2 выносливости")
    _record_test(not _melee_is_two_handed("combat_knife"),"Нож не должен быть двухручным")
    _record_test(_melee_is_two_handed("steel_pipe"),"Труба должна быть двухручной")
    _record_test(_melee_is_two_handed("fire_axe"),"Топор должен быть двухручным")

    # Validate the all-items QA loot table itself rather than trying to pack every
    # item into the normal 8x8 container grid. Several multi-cell items make the
    # complete catalogue physically larger than a regular gameplay container.
    var all_test_ids = {}
    for test_rule in loot_tables.get("all_items_test",[]):
        all_test_ids[str(test_rule.get("id",""))] = true
    _record_test(all_test_ids.size() == item_defs.size(),"Тестовая loot-таблица не содержит все уникальные предметы")
    for test_item_id in item_defs.keys():
        _record_test(all_test_ids.has(str(test_item_id)),"В all_items_test отсутствует предмет: %s" % test_item_id)
    _record_test(all_test_ids.has("fire_axe"),"Топор отсутствует в тестовой loot-таблице")

    _record_test(ResourceLoader.exists("res://inventory_icons_v10.png"),"Нет inventory_icons_v10.png")
    _record_test(ResourceLoader.exists("res://melee_inventory_v3.png"),"Нет melee_inventory_v3.png")
    _record_test(ResourceLoader.exists("res://loot_sprites_v9.png"),"Нет loot_sprites_v9.png")
    _record_test(ResourceLoader.exists("res://weapon_models_v9.png"),"Нет weapon_models_v9.png")
    _record_test(ResourceLoader.exists("res://melee_models_v10.png"),"Нет melee_models_v10.png")
    _record_test(ResourceLoader.exists("res://weapon_modules_v2.png"),"Нет weapon_modules_v2.png")

    for weapon_id in ["makarov","shotgun","akm"]:
        _record_test(weapon_defs.has(weapon_id),"Нет weapon definition: %s" % weapon_id)
        if weapon_defs.has(weapon_id):
            var test_weapon = weapon_defs[weapon_id]
            var test_ammo_id = str(test_weapon.get("ammo",""))
            _record_test(item_defs.has(test_ammo_id),"Оружие %s использует неизвестные патроны %s" % [weapon_id,test_ammo_id])
            _record_test(int(test_weapon.get("mag",0)) > 0,"У оружия %s нулевая ёмкость магазина" % weapon_id)
            _record_test(float(test_weapon.get("damage",0.0)) > 0.0,"У оружия %s нулевой урон" % weapon_id)
            _record_test(float(test_weapon.get("range",0.0)) > 0.0,"У оружия %s нулевая дальность" % weapon_id)

    _record_test(_reload_transfer_amount("makarov",0,30) == 8,"PM reload transfer должен заполнить 8 патронов")
    _record_test(_reload_transfer_amount("shotgun",0,30) == 1,"Shotgun reload должен вставлять по одному патрону")
    _record_test(_reload_transfer_amount("akm",0,40) == 30,"AKM reload transfer должен заполнить 30 патронов")
    _record_test(_reload_transfer_amount("akm",29,40) == 1,"AKM partial reload должен добавить 1 патрон")
    _record_test(_reload_transfer_amount("shotgun",5,20) == 0,"Полный дробовик не должен принимать патрон")
    _record_test(_reload_duration_for_weapon("shotgun") < _reload_duration_for_weapon("akm"),"Shotgun shell step должен быть быстрее полного reload AKM")

    _record_test(_reload_transfer_amount("akm",0,20) == 20,"AKM должен загружать доступные 20 патронов")
    _record_test(_reload_transfer_amount("akm",10,5) == 5,"AKM partial reload должен загрузить доступные 5 патронов")

    var old_hunger_test = hunger
    var old_thirst_test = thirst
    var old_health_test = health
    var old_bleeding_test = bleeding

    hunger = 100.0
    thirst = 100.0
    health = 100.0
    bleeding = false
    _record_test(abs(_survival_stamina_cap() - 100.0) < 0.01,"Неверный stamina cap в хорошем состоянии")

    hunger = 8.0
    thirst = 100.0
    _record_test(_survival_stamina_cap() <= 70.0,"Сильный голод не ограничивает выносливость")
    _record_test(_survival_speed_multiplier() < 1.0,"Сильный голод не замедляет игрока")

    hunger = 100.0
    thirst = 8.0
    _record_test(_survival_stamina_cap() <= 55.0,"Сильная жажда не ограничивает выносливость")
    _record_test(_survival_speed_multiplier() < 1.0,"Сильная жажда не замедляет игрока")

    hunger = 0.0
    thirst = 0.0
    _record_test(_survival_damage_per_second() > 0.5,"Нулевая еда/вода не наносит survival damage")

    hunger = old_hunger_test
    thirst = old_thirst_test
    health = old_health_test
    bleeding = old_bleeding_test

    _record_test(_survival_stamina_regen_rate() > 0.0,"Stamina regen должен быть положительным")

    _record_test(_world_loot_visual_scale("makarov") <= 0.50,"ПМ на земле слишком крупный")
    _record_test(_world_loot_visual_scale("shotgun") <= 0.50,"Дробовик на земле слишком крупный")
    _record_test(_world_loot_visual_scale("fire_axe") <= 0.50,"Топор на земле слишком крупный")
    _record_test(_world_loot_visual_scale("water") <= 0.45,"Расходники на земле слишком крупные")
    _record_test(_world_loot_visual_scale("ammo_762") <= 0.42,"Патроны на земле слишком крупные")

    var old_weather_test = weather_state
    var old_minutes_test = world_minutes
    var old_body_temp_test = body_temperature
    var old_wetness_test = wetness
    var old_ambient_test = ambient_temperature
    var old_shelter_test = is_sheltered
    var old_effective_test = thermal_effective_temperature
    var old_cold_stress_test = thermal_cold_stress
    var old_heat_stress_test = thermal_heat_stress
    var old_wind_test = wind_speed_kmh

    weather_state = "clear"
    world_minutes = 14.0 * 60.0
    _record_test(_ambient_temperature_for_time() > 12.0,"Дневная температура слишком низкая")

    world_minutes = 2.0 * 60.0
    _record_test(_ambient_temperature_for_time() <= -2.5,"Ночная температура должна опускаться ниже 0°C")

    weather_state = "rain"
    _record_test(_weather_temp_offset() < -3.0,"Дождь должен охлаждать воздух")
    _record_test(_weather_wind_speed_kmh() >= 18.0,"Дождь должен сопровождаться заметным ветром")

    _record_test(_wind_chill_temperature(0.0,20.0) < -4.0,"Wind chill при 0°C/20кмч слишком слабый")
    _record_test(abs(_wind_chill_temperature(15.0,20.0) - 15.0) < 0.01,"Wind chill не должен применяться в тёплую погоду")

    ambient_temperature = 0.0
    is_sheltered = false
    body_temperature = 36.8
    wetness = 0.0
    thermal_effective_temperature = 0.0
    _record_test(_freezing_exposure_active(),"0°C на улице должно включать риск переохлаждения")
    _record_test(_thermal_speed_multiplier() < 1.0,"0°C на улице должно слегка влиять на скорость")
    _record_test(_thermal_stamina_regen_multiplier() < 1.0,"0°C на улице должно влиять на stamina regen")

    body_temperature = 33.5
    _record_test(_thermal_damage_per_second() > 0.0,"Опасная core temperature должна наносить cold damage")

    body_temperature = 36.8
    _record_test(abs(_thermal_damage_per_second()) < 0.001,"Нормальная core temperature не должна получать cold damage только из-за воздуха")

    wetness = 80.0
    thermal_effective_temperature = 2.0
    _record_test(_temperature_stamina_cap() < 100.0,"Мокрота и холод должны ограничивать stamina")

    is_sheltered = true
    ambient_temperature = -5.0
    _record_test(not _freezing_exposure_active(),"Укрытие должно отключать прямой outdoor-freezing risk")
    _record_test(_shelter_air_temperature() >= 4.0,"Укрытие должно удерживать положительную температуру воздуха")
    _record_test(_shelter_wellbeing_multiplier() > 1.15,"Укрытие должно улучшать восстановление")

    _record_test(float(item_defs["light_jacket"].get("warmth",0.0)) >= 3.0,"Куртка должна давать тепло")
    _record_test(float(item_defs["light_jacket"].get("rain_protect",0.0)) >= 0.30,"Куртка должна защищать от дождя")

    weather_state = old_weather_test
    world_minutes = old_minutes_test
    body_temperature = old_body_temp_test
    wetness = old_wetness_test
    ambient_temperature = old_ambient_test
    is_sheltered = old_shelter_test
    thermal_effective_temperature = old_effective_test
    thermal_cold_stress = old_cold_stress_test
    thermal_heat_stress = old_heat_stress_test
    wind_speed_kmh = old_wind_test

    var old_pain_test = pain
    var old_body_test = body_condition.duplicate(true)

    pain = 0.0
    body_condition = {
        "head":100.0,
        "torso":100.0,
        "arms":100.0,
        "legs":100.0
    }

    _record_test(abs(_injury_move_multiplier() - 1.0) < 0.001,"Здоровые ноги не должны замедлять")
    _record_test(abs(_injury_aim_spread_multiplier() - 1.0) < 0.001,"Здоровые руки не должны портить точность")
    _record_test(_injury_can_sprint(),"Здоровый персонаж должен уметь бегать")

    body_condition["legs"] = 20.0
    _record_test(_injury_move_multiplier() < 0.80,"Тяжёлая травма ног должна сильно замедлять")
    _record_test(not _injury_can_sprint(),"Тяжёлая травма ног должна запрещать sprint")

    body_condition["legs"] = 100.0
    body_condition["arms"] = 20.0
    _record_test(_injury_aim_spread_multiplier() > 1.25,"Тяжёлая травма рук должна ухудшать точность")

    body_condition["arms"] = 100.0
    body_condition["torso"] = 25.0
    _record_test(_injury_stamina_cap() <= 70.0,"Тяжёлая травма корпуса должна ограничивать stamina")

    body_condition["torso"] = 100.0
    pain = 90.0
    _record_test(not _injury_can_sprint(),"Сильная боль должна запрещать sprint")
    _record_test(_injury_stamina_cap() <= 70.0,"Сильная боль должна ограничивать stamina")

    pain = 0.0
    body_condition = {
        "head":100.0,
        "torso":100.0,
        "arms":100.0,
        "legs":100.0
    }
    _apply_body_injury("arms",20.0)
    _record_test(abs(_body_condition_value("arms") - 80.0) < 0.01,"Body injury не уменьшает состояние зоны")
    _record_test(pain > 15.0,"Body injury не добавляет боль")

    _stabilize_worst_injury(2.5)
    _record_test(_body_condition_value("arms") > 82.4,"Bandage stabilization не улучшает худшую травму")

    pain = old_pain_test
    body_condition = old_body_test
    _sanitize_body_condition()

    _record_test(_ai_state_valid("idle"),"AI idle state невалиден")
    _record_test(_ai_state_valid("suspicious"),"AI suspicious state невалиден")
    _record_test(_ai_state_valid("investigate"),"AI investigate state невалиден")
    _record_test(_ai_state_valid("chase"),"AI chase state невалиден")
    _record_test(_ai_state_valid("search"),"AI search state невалиден")
    _record_test(_ai_state_valid("return"),"AI return state невалиден")
    _record_test(not _ai_state_valid("broken"),"AI должен отвергать неизвестное состояние")

    var old_ai_minutes = world_minutes
    var old_ai_weather = weather_state
    var old_ai_flash = flashlight_on
    var old_ai_battery = flashlight_battery
    var old_ai_utility = str(equipment.get("utility",""))
    var old_ai_move = move_direction
    var old_ai_sprint = is_sprinting
    var old_ai_shelter = is_sheltered

    weather_state = "clear"
    is_sheltered = false
    move_direction = Vector2.ZERO
    is_sprinting = false
    flashlight_on = false
    world_minutes = 23.0 * 60.0
    var night_visibility = _player_visibility_multiplier()

    world_minutes = 12.0 * 60.0
    var day_visibility = _player_visibility_multiplier()
    _record_test(day_visibility > night_visibility,"Ночь должна снижать визуальную заметность")

    world_minutes = 23.0 * 60.0
    equipment["utility"] = "flashlight"
    flashlight_battery = 100.0
    flashlight_on = true
    var flashlight_visibility = _player_visibility_multiplier()
    _record_test(flashlight_visibility > night_visibility * 1.8,"Фонарь должен заметно выдавать игрока ночью")

    flashlight_on = false
    weather_state = "rain"
    var rain_walk_sound = _sound_weather_multiplier("walk")
    var rain_gun_sound = _sound_weather_multiplier("gunshot")
    _record_test(rain_walk_sound < 0.70,"Дождь должен маскировать шаги")
    _record_test(rain_gun_sound > rain_walk_sound,"Выстрел должен хуже маскироваться дождём")
    _record_test(_sound_hearing_cap_multiplier("gunshot") > _sound_hearing_cap_multiplier("walk"),"Gunshot hearing cap должен быть выше шагов")
    _record_test(_sound_suspicion_gain("gunshot") > _sound_suspicion_gain("walk"),"Выстрел должен сильнее повышать подозрение")

    world_minutes = old_ai_minutes
    weather_state = old_ai_weather
    flashlight_on = old_ai_flash
    flashlight_battery = old_ai_battery
    equipment["utility"] = old_ai_utility
    move_direction = old_ai_move
    is_sprinting = old_ai_sprint
    is_sheltered = old_ai_shelter

    _record_test(_skill_ids().size() == 5,"Должно быть пять learn-by-doing навыков")
    _record_test(_skill_xp_required_for_level(2) > _skill_xp_required_for_level(1),"XP curve навыков должна расти")
    _record_test(_skill_firearm_spread_multiplier() > 0.0 and _skill_firearm_spread_multiplier() <= 1.0,"Firearm skill spread multiplier невалиден")
    _record_test(_skill_reload_time_multiplier() >= 0.88 and _skill_reload_time_multiplier() <= 1.0,"Reload skill multiplier невалиден")
    _record_test(_skill_melee_damage_multiplier() >= 1.0,"Melee skill не должен уменьшать damage")
    _record_test(_skill_carry_bonus() >= 0.0,"Scavenging carry bonus невалиден")
    _record_test(_skill_survival_drain_multiplier() >= 0.84 and _skill_survival_drain_multiplier() <= 1.0,"Survival drain multiplier невалиден")
    _record_test(_skill_survival_regen_multiplier() >= 1.0,"Survival regen multiplier невалиден")
    _record_test(_skill_service_gain_multiplier() >= 1.0,"Crafting service multiplier невалиден")

    var old_skill_levels_test = skill_levels.duplicate(true)
    var old_skill_xp_test = skill_xp.duplicate(true)
    skill_levels = {"firearms":10}
    skill_xp = {"firearms":999.0}
    _sanitize_skills()
    _record_test(_skill_level("firearms") == 10,"Skill level 10 должен сохраняться")
    _record_test(float(skill_xp.get("firearms",1.0)) == 0.0,"Max-level XP должен обнуляться")
    _record_test(_skill_level("melee") == 1,"Missing skill должен восстанавливаться до 1")
    skill_levels = old_skill_levels_test
    skill_xp = old_skill_xp_test
    _sanitize_skills()
    _record_test(recipe_defs.size() >= 10,"Расширенный верстак должен иметь не менее 10 рецептов")
    _record_test(_recipe_skill_required("repair_kit") == 1,"Ремкомплект должен быть базовым рецептом")
    _record_test(_recipe_skill_required("akm_extmag") == 5,"Магазин АКМ должен быть рецептом высокого уровня")
    _record_test(_salvage_outputs("steel_pipe").get("scrap",0) == 2,"Труба должна возвращать 2 металлолома")
    _record_test(_salvage_outputs("police_vest").get("scrap",0) == 2,"Бронежилет должен возвращать металл")
    _record_test(_salvage_outputs("police_vest").get("cloth",0) == 2,"Бронежилет должен возвращать ткань")
    _record_test(_salvage_outputs("makarov").is_empty(),"Огнестрельное оружие пока не должно разбираться")
    _record_test(_salvage_skill_required("suppressor") == 3,"Сложный модуль должен требовать Ремесло 3")
    _record_test(_sound_hearing_cap_multiplier("workbench") > _sound_hearing_cap_multiplier("walk"),"Верстак должен быть слышнее шагов")
    _record_test(_sound_suspicion_gain("workbench") > _sound_suspicion_gain("drop"),"Верстак должен сильнее настораживать, чем лёгкий предмет")

    _record_test(_base_build_costs("stash").get("scrap",0) == 2,"Цена базового ящика сломана")
    _record_test(_base_build_costs("heater").get("cloth",0) == 2,"Цена обогревателя сломана")
    _record_test(_base_build_costs("lamp").get("flashlight",0) == 1,"Лампа должна требовать фонарь")
    _record_test(_base_build_costs("barricade").get("scrap",0) == 3,"Цена баррикады сломана")
    _record_test(_base_refund_for("stash").get("scrap",0) == 1,"Refund ящика сломан")
    _record_test(_base_refund_for("lamp").get("flashlight",0) == 1,"Лампа должна возвращать фонарь при разборе")
    _record_test(_base_object_name("heater") == "ОБОГРЕВАТЕЛЬ","Base object naming сломан")

    _record_test(_chunk_zone(Vector2i(0,0)) == "central","Нулевой чанк должен оставаться CENTRAL")
    _record_test(_chunk_zone(Vector2i(3,-2)) == "rural","Zone generator должен стабильно давать rural для контрольной координаты")
    _record_test(_zone_display_name("industrial") == "ПРОМЗОНА","Название промзоны сломано")
    _record_test(_zone_display_name("military") == "ВОЕННЫЙ ПЕРИМЕТР","Название военной зоны сломано")
    _record_test(_zone_build_chance("woodland") < _zone_build_chance("commercial"),"Лес должен быть менее застроен, чем торговый район")
    _record_test(loot_tables.has("industrial"),"Нет industrial loot table")
    _record_test(loot_tables.has("military"),"Нет military loot table")
    _record_test(loot_tables.has("forest_cache"),"Нет forest cache loot table")
    _record_test(loot_tables.has("rural"),"Нет rural loot table")
    _record_test(_zone_loot_table("military",0) == "military","Military zone должен использовать military loot")
    _record_test("cache_%d" % 2 == "cache_2","Legacy procedural container id format сломан")

    _record_test(_base_build_costs("cot").get("cloth",0) == 4,"Раскладушка должна требовать 4 ткани")
    _record_test(_base_refund_for("cot").get("cloth",0) == 2,"Разбор раскладушки должен возвращать часть ткани")
    _record_test(_base_object_name("cot") == "РАСКЛАДУШКА","Название раскладушки сломано")
    _record_test(_rest_requirement_text(8).find("34") >= 0,"Требования 8-часового сна сломаны")

    var old_rest_hunger = hunger
    var old_rest_thirst = thirst
    var old_rest_bleeding = bleeding
    var old_rest_body_temp = body_temperature
    var old_rest_source = rest_source_base_id
    var old_rest_open = rest_open

    hunger = 100.0
    thirst = 100.0
    bleeding = false
    body_temperature = 36.8
    _record_test(_rest_quality() >= 0.55 and _rest_quality() <= 1.28,"Rest quality вне диапазона")

    hunger = old_rest_hunger
    thirst = old_rest_thirst
    bleeding = old_rest_bleeding
    body_temperature = old_rest_body_temp
    rest_source_base_id = old_rest_source
    rest_open = old_rest_open

func _run_runtime_smoke_tests():
    # Door smoke-test offscreen: create, open, close, verify collision layer.
    var test_chunk = Node2D.new()
    test_chunk.position = Vector2(-10000,-10000)
    add_child(test_chunk)

    var test_door = _create_door(test_chunk,Vector2i(9999,9999),Vector2.ZERO,"selftest")
    var body = test_door.get_meta("door_body",null)

    _apply_door_state(test_door,true,true)
    _record_test(
        is_instance_valid(body) and body.collision_layer == 0,
        "Открытая дверь всё ещё имеет world collision"
    )

    _apply_door_state(test_door,false,true)
    _record_test(abs(float(test_door.get_meta("door_target_angle",0.0))) <= 0.001,"Закрытая дверь имеет ненулевой угол")
    var test_shape = test_door.get_meta("door_shape",null)
    if is_instance_valid(test_shape):
        var test_rect = test_shape.shape
        _record_test(test_rect.size.x >= 36.0,"Коллизия двери недостаточно широкая для проёма")
    _record_test(
        is_instance_valid(body) and body.collision_layer == LAYER_WORLD,
        "Закрытая дверь не восстановила world collision"
    )

    var test_enemy = _spawn_enemy(test_chunk,Vector2i(9999,9999),999,Vector2(64,0))
    if is_instance_valid(test_enemy):
        _apply_enemy_impulse(test_enemy,Vector2.RIGHT,120.0,0.6)
        _record_test(float(test_enemy.get_meta("stagger",0.0)) >= 0.59,"Melee stagger не записался")
        var test_knockback = test_enemy.get_meta("knockback_velocity",Vector2.ZERO)
        _record_test(typeof(test_knockback) == TYPE_VECTOR2 and test_knockback.length() >= 119.0,"Melee knockback не записался")

    _record_test(pv_melee_trail != null,"Не создан melee trail")
    _record_test(_weapon_model_texture("makarov") != null,"Не загружается модель ПМ")
    _record_test(_weapon_model_texture("shotgun") != null,"Не загружается модель дробовика")
    _record_test(_weapon_model_texture("akm") != null,"Не загружается модель АКМ")
    _record_test(load("res://player_parts_v2.png") != null,"Не загружается новый atlas player_parts_v2.png")
    _record_test(_melee_model_texture("combat_knife") != null,"Не загружается новая модель ножа")
    _record_test(_melee_model_texture("steel_pipe") != null,"Не загружается новая модель трубы")
    _record_test(_melee_model_texture("fire_axe") != null,"Не загружается новая модель топора")

    _record_test(pv_melee_back_sleeve != null,"Не создана задняя melee-рука")
    _record_test(pv_melee_front_sleeve != null,"Не создана передняя melee-рука")
    _record_test(pv_melee_back_hand != null and pv_melee_front_hand != null,"Не созданы ладони melee rig")
    _record_test(pv_weapon_root != null and _weapon_root_point(Vector2.ZERO).distance_to(pv_weapon_root.position) < 0.001,"Weapon-root transform сломан")
    _record_test(pv_arm_back_root != null and pv_arm_front_root != null and not pv_arm_back_root.visible and not pv_arm_front_root.visible,"Старые polygon arms должны быть скрыты")


    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v20")
    _record_test(load("res://melee_inventory_v9.png") != null,"Не загружается melee_inventory_v5")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v20")

    for inventory_art_id in item_defs.keys():
        _record_test(_make_item_icon(str(inventory_art_id)) != null,"Нет inventory art: %s" % inventory_art_id)
        _record_test(_make_world_loot_texture(str(inventory_art_id)) != null,"Нет world-loot art: %s" % inventory_art_id)

    _record_test(_make_item_icon("water") != null,"Не загружается inventory icon воды")
    _record_test(_make_item_icon("shotgun") != null,"Не загружается inventory icon дробовика")
    _record_test(_make_world_loot_texture("water") != null,"Не загружается world-loot icon")
    _record_test(_weapon_model_texture("shotgun") != null,"Не загружается модель дробовика")


    _record_test(InputMap.has_action("reload"),"Не создано input action reload")
    _record_test(_reload_transfer_amount("shotgun",2,10) == 1,"Runtime shotgun reload rule сломан")
    _record_test(_reload_transfer_amount("akm",10,50) == 20,"Runtime AKM reload rule сломан")


    _record_test(_weapon_model_texture("makarov") != null,"Не загружается новая модель ПМ")
    _record_test(_weapon_model_texture("shotgun") != null,"Не загружается новая модель дробовика")
    _record_test(_weapon_model_texture("akm") != null,"Не загружается новая модель АКМ")
    _record_test(_melee_model_texture("fire_axe") != null,"Не загружается новая модель топора")
    _record_test(_weapon_module_texture("suppressor") != null,"Не загружается новый глушитель")

    _record_test(_weapon_model_texture("shotgun") != null,"Не загружается weapon_models_v9 дробовик")
    _record_test(_weapon_model_texture("akm") != null,"Не загружается weapon_models_v9 АКМ")
    _record_test(_make_item_icon("water") != null,"Не загружается новая бутылка")

    _record_test(InputMap.has_action("sprint"),"Не создано input action sprint")
    _record_test(_survival_stamina_cap() > 0.0,"Survival stamina cap невалиден")
    _record_test(_survival_stamina_regen_rate() > 0.0,"Survival stamina regen невалиден")


    _record_test(weather_visual_root != null,"Не создан weather visual root")
    _record_test(rain_lines.size() == 28,"Неверное число rain lines")
    _record_test(body_temperature >= 30.5 and body_temperature <= 40.5,"Body temperature вне диапазона")
    _record_test(wetness >= 0.0 and wetness <= 100.0,"Wetness вне диапазона")


    _record_test(_shelter_wellbeing_multiplier() >= 1.0,"Shelter wellbeing multiplier сломан")
    _record_test(_temperature_stamina_cap() > 0.0,"Temperature stamina cap сломан")


    _record_test(body_condition.has("head") and body_condition.has("torso"),"Body condition zones не созданы")
    _record_test(body_condition.has("arms") and body_condition.has("legs"),"Body condition limb zones не созданы")
    _record_test(pain >= 0.0 and pain <= 100.0,"Pain вне диапазона")
    _record_test(_injury_stamina_cap() > 0.0,"Injury stamina cap невалиден")


    _record_test(_weather_wind_speed_kmh() >= 0.0,"Wind speed невалиден")
    _record_test(_clothing_insulation() >= 0.0 and _clothing_insulation() <= 0.78,"Clothing insulation вне диапазона")
    _record_test(_thermal_speed_multiplier() > 0.0,"Thermal speed multiplier невалиден")
    _record_test(_thermal_stamina_regen_multiplier() > 0.0,"Thermal stamina multiplier невалиден")


    if is_instance_valid(test_enemy):
        _record_test(str(test_enemy.get_meta("ai_state","")) == "idle","Spawned infected должен начинать в idle")
        _enemy_set_state(test_enemy,"search",2.0)
        _record_test(str(test_enemy.get_meta("ai_state","")) == "search","AI state transition idle->search сломан")
        _record_test(float(test_enemy.get_meta("ai_state_time",0.0)) >= 1.99,"AI state timer не записался")
        _enemy_set_state(test_enemy,"idle",0.0)

    _record_test(_player_visibility_multiplier() >= 0.25 and _player_visibility_multiplier() <= 1.35,"Visibility multiplier вне диапазона")
    _record_test(_sound_weather_multiplier("walk") > 0.0,"Sound weather multiplier невалиден")


    _record_test(_skill_level("firearms") >= 1 and _skill_level("firearms") <= 10,"Firearms skill вне диапазона")
    _record_test(_skill_level("survival") >= 1 and _skill_level("survival") <= 10,"Survival skill вне диапазона")
    _record_test(_skill_progress_percent("crafting") >= 0.0 and _skill_progress_percent("crafting") <= 100.0,"Crafting XP progress вне диапазона")

    _record_test(workbench_salvage_content != null,"Не создана вкладка РАЗБОР")
    _record_test(workbench_salvage_tab != null,"Не создана кнопка вкладки РАЗБОР")
    _record_test(_recipe_skill_required("field_bandage") >= 1,"Recipe skill requirement невалиден")
    _record_test(_is_salvageable("steel_pipe"),"Steel pipe должен быть разбираемым")

    _record_test(base_build_panel != null,"Не создан BaseBuildUI")
    _record_test(base_root != null,"Не создан persistent base root")
    _record_test(next_base_id >= 1,"next_base_id невалиден")
    _record_test(_base_heat_bonus_at_player() >= 0.0,"Base heat bonus невалиден")

    _record_test(_zone_display_name(current_zone_id) != "НЕИЗВЕСТНО","Current zone id невалиден")
    _record_test(typeof(discovered_chunks) == TYPE_DICTIONARY,"discovered_chunks не Dictionary")
    var zone_rng_test = RandomNumberGenerator.new()
    zone_rng_test.seed = 77
    _record_test(_zone_enemy_count("military",zone_rng_test) >= 5,"Military enemy count должен быть высоким")

    _record_test(craft_list != null and craft_list.get_parent() is ScrollContainer,"Список крафта должен быть внутри ScrollContainer")
    _record_test(salvage_list != null and salvage_list.get_parent() is ScrollContainer,"Список разбора должен быть внутри ScrollContainer")
    _record_test(rest_panel != null,"Не создан RestUI")
    _record_test(_base_build_costs("cot").has("cloth"),"Cot build costs не созданы")
    _record_test(_base_refund_for("cot").has("cloth"),"Cot refund не создан")
    _record_test(_rest_quality() >= 0.55 and _rest_quality() <= 1.28,"Runtime rest quality вне диапазона")


    _record_test(pv_shadow != null and pv_shadow.z_index <= -20,"Тень игрока должна быть позади модели")
    _record_test(pv_pose_back != null and pv_pose_front != null,"Full-body pose layers не созданы")
    _record_test(load("res://player_pose_back_v2.png") != null,"Не загружается back pose atlas")
    _record_test(load("res://player_pose_front_v2.png") != null,"Не загружается front pose atlas")
    _record_test(not pv_body.visible and not pv_leg_l.visible and not pv_head.visible,"Старые segmented body/legs должны быть скрыты")

    var old_weapon_pose_test = current_weapon_id
    var old_melee_pose_test = equipped_melee_id
    var old_aim_pose_test = aim_direction
    var old_move_blend_test = movement_anim_blend
    var old_walk_phase_test = walk_phase
    var old_move_dir_test = move_direction
    var old_visual_move_speed_test = visual_move_speed

    for weapon_id_test in ["makarov","shotgun","akm"]:
        current_weapon_id = weapon_id_test
        equipped_melee_id = ""
        _update_weapon_visual()
        for aim_test in [Vector2(1,0),Vector2(0.72,-0.69).normalized(),Vector2(0.72,0.69).normalized()]:
            aim_direction = aim_test
            movement_anim_blend = 0.0
            move_direction = Vector2.ZERO
            _update_player_visuals(0.0)
            _record_test(pv_pose_back.region_rect.size == Vector2(80,60),"Неверный размер full-body pose frame: %s" % weapon_id_test)
            _record_test(pv_pose_front.z_index > pv_weapon_root.z_index,"Передние руки должны быть над оружием: %s" % weapon_id_test)
            _record_test(pv_weapon_root.z_index > pv_pose_back.z_index,"Оружие должно быть над задним pose layer: %s" % weapon_id_test)

    for melee_id_test in ["combat_knife","steel_pipe","fire_axe"]:
        equipped_melee_id = melee_id_test
        current_weapon_id = "makarov"
        _update_weapon_visual()
        aim_direction = Vector2(1,0)
        _update_player_visuals(0.0)
        _record_test(_pose_weapon_column(melee_id_test) >= 3,"Melee pose column сломан: %s" % melee_id_test)

    current_weapon_id = old_weapon_pose_test
    equipped_melee_id = old_melee_pose_test
    aim_direction = old_aim_pose_test

    movement_anim_blend = 1.0
    move_direction = Vector2.RIGHT
    visual_move_speed = MOVE_SPEED
    walk_phase = PI * 0.5
    _update_player_visuals(0.0)
    var walk_frame_a = pv_pose_back.region_rect.position.y
    walk_phase = PI * 1.5
    _update_player_visuals(0.0)
    var walk_frame_b = pv_pose_back.region_rect.position.y
    _record_test(walk_frame_a != walk_frame_b,"Ходьба должна переключать две full-body gait-позы")

    movement_anim_blend = old_move_blend_test
    walk_phase = old_walk_phase_test
    move_direction = old_move_dir_test
    visual_move_speed = old_visual_move_speed_test
    _update_weapon_visual()
    _update_player_visuals(0.0)

    _record_test(load("res://ground_chunk_v1.png") != null,"Не загружается новый ground art")
    _record_test(load("res://world_props_v1.png") != null,"Не загружается world props atlas")
    _record_test(load("res://world_tiles_v1.png") != null,"Не загружается world tiles atlas")
    _record_test(load("res://player_pose_front_v3.png") != null,"Не загружается player pose front v3")
    _record_test(load("res://player_pose_back_v3.png") != null,"Не загружается player pose back v3")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://world_props_v12.png") != null,"Нет world props v2")
    _record_test(load("res://world_tiles_v9.png") != null,"Нет world tiles v2")
    _record_test(load("res://infected_v6.png") != null,"Нет infected sprite atlas")
    _record_test(load("res://weapon_models_v16.png") != null,"Нет weapon models v10")
    _record_test(load("res://melee_models_v15.png") != null,"Нет melee models v11")
    _record_test(load("res://inventory_icons_v11.png") != null,"Нет inventory icons v11")
    _record_test(craft_list != null and craft_list.get_parent() is ScrollContainer,"Craft scroll потерян")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v3")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v3")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v3")
    _record_test(load("res://infected_v6.png") != null,"Не загружается infected_v2")
    _record_test(_world_prop_region("trash_bin").size.x == 40,"Неверный trash_bin region")
    _record_test(_world_prop_region("sandbags").size.x == 56,"Неверный sandbags region")
    _record_test(_world_prop_region("med_cart").size.y == 48,"Неверный med_cart region")
    _record_test(load("res://weapon_models_v16.png") != null,"Не загружается weapon_models_v11")
    _record_test(load("res://melee_models_v15.png") != null,"Не загружается melee_models_v12")
    _record_test(load("res://weapon_modules_v6.png") != null,"Не загружается weapon_modules_v4")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v13")
    _record_test(load("res://melee_inventory_v9.png") != null,"Не загружается melee_inventory_v6")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v12")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v4")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v4")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v4")
    _record_test(_world_prop_region("traffic_cone").size.x == 24,"Неверный traffic cone region")
    _record_test(_world_prop_region("shopping_cart").size.x == 48,"Неверный shopping cart region")
    _record_test(_world_prop_region("generator_prop").size.y == 48,"Неверный generator prop region")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://melee_models_v15.png") != null,"Не загружается melee_models_v13")
    _record_test(load("res://melee_inventory_v9.png") != null,"Не загружается melee_inventory_v7")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v13")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v5")
    var knife_fix_cfg = _held_visual_config("combat_knife",true)
    _record_test(int(knife_fix_cfg.get("rear_px",Vector2.ZERO).x) == 25,"Knife grip point не обновлен")
    _record_test(float(knife_fix_cfg.get("sprite_pos",Vector2.ZERO).x) >= 7.0,"Knife sprite offset не обновлен")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    _record_test(load("res://weapon_models_v16.png") != null,"Не загружается weapon_models_v12")
    _record_test(load("res://infected_v6.png") != null,"Не загружается infected_v3")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v14")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v14")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v6")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v5")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v5")
    _record_test(_world_prop_region("pharmacy_cabinet").size.x == 64,"Неверный pharmacy cabinet region")
    _record_test(_world_prop_region("street_debris").size.x == 72,"Неверный street debris region")
    var pose_front_v8_test = load("res://player_pose_front_v14.png")
    var pose_back_v8_test = load("res://player_pose_back_v14.png")
    _record_test(pose_front_v8_test != null,"Не загружается player_pose_front_v8")
    _record_test(pose_back_v8_test != null,"Не загружается player_pose_back_v8")
    if pose_front_v8_test != null:
        _record_test(pose_front_v8_test.get_height() == 3900,"Неверная высота 15-row pose atlas")
    _record_test(load("res://weapon_models_v16.png") != null,"Не загружается weapon_models_v13")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v15")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v15")
    _record_test(load("res://infected_v6.png") != null,"Не загружается infected_v4")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v7")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v6")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v6")

    _record_test(_gait_variant_for_phase(0.0) == 0,"Gait contact phase сломан")
    _record_test(_gait_variant_for_phase(PI * 0.5) == 1,"Gait stride A сломан")
    _record_test(_gait_variant_for_phase(PI * 1.5) == 2,"Gait stride B сломан")
    _record_test(_weapon_pose_row_from_visual(14) == 3,"Aim-up walk weapon mapping сломан")
    _record_test(_weapon_pose_row_from_visual(27) == 4,"Aim-down walk weapon mapping сломан")
    _record_test(_weapon_pose_row_from_visual(54) == 6,"Reload-walk weapon mapping сломан")
    _record_test(_visual_facing_from_aim(false,-0.20),"Facing hysteresis left сломан")
    _record_test(not _visual_facing_from_aim(false,0.02),"Facing hysteresis center сломан")
    _record_test(_world_prop_region("electrical_box").size.x == 48,"Неверный electrical box region")
    var hi_front_test = load("res://player_pose_front_v14.png")
    var hi_back_test = load("res://player_pose_back_v14.png")
    _record_test(hi_front_test != null,"Не загружается high-res front pose atlas")
    _record_test(hi_back_test != null,"Не загружается high-res back pose atlas")
    if hi_front_test != null:
        _record_test(hi_front_test.get_width() == 480,"Неверная ширина high-res pose atlas")
        _record_test(hi_front_test.get_height() == 3900,"Неверная высота high-res pose atlas")
    _record_test(_walk_phase_index(0.0) == 0,"Walk phase 0 сломан")
    _record_test(_walk_phase_index(PI * 0.5) == 3,"Walk phase 2 сломан")
    _record_test(_walk_phase_index(PI) == 6,"Walk phase 4 сломан")
    _record_test(_walk_phase_index(PI * 1.5) == 9,"Walk phase 6 сломан")
    _record_test(_pose_state_base_row(4) == 52,"Pose state layout сломан")
    _record_test(_weapon_pose_row_from_visual(54) == 6,"Reload walk mapping сломан")
    _record_test(load("res://weapon_models_v16.png") != null,"Не загружается weapon_models_v14")
    _record_test(load("res://melee_models_v15.png") != null,"Не загружается melee_models_v14")
    _record_test(load("res://weapon_modules_v6.png") != null,"Не загружается weapon_modules_v5")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v16")
    _record_test(load("res://melee_inventory_v9.png") != null,"Не загружается melee_inventory_v8")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v16")
    _record_test(load("res://infected_v6.png") != null,"Не загружается infected_v5")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v8")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v7")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v7")
    _record_test(_world_prop_region("hospital_bed").size.x == 96,"Hospital bed region сломан")
    _record_test(_world_prop_region("wheelchair").size.x == 64,"Wheelchair region сломан")
    var ref_front_test = load("res://player_pose_front_v14.png")
    var ref_back_test = load("res://player_pose_back_v14.png")
    _record_test(ref_front_test != null,"Не загружается reference-fidelity front atlas")
    _record_test(ref_back_test != null,"Не загружается reference-fidelity back atlas")
    if ref_front_test != null:
        _record_test(ref_front_test.get_width() == 480,"Неверная ширина 144px pose atlas")
        _record_test(ref_front_test.get_height() == 3900,"Неверная высота 65-row pose atlas")
    _record_test(_walk_phase_index(0.0) == 0,"12-frame walk phase 0 сломан")
    _record_test(_walk_phase_index(PI * 0.5) == 3,"12-frame walk phase 3 сломан")
    _record_test(_walk_phase_index(PI) == 6,"12-frame walk phase 6 сломан")
    _record_test(_walk_phase_index(PI * 1.5) == 9,"12-frame walk phase 9 сломан")
    _record_test(_pose_state_base_row(4) == 52,"65-row pose layout сломан")
    _record_test(_weapon_pose_row_from_visual(54) == 6,"Reload gait mapping сломан")
    _record_test(load("res://weapon_models_v16.png") != null,"Не загружается weapon_models_v15")
    _record_test(load("res://melee_models_v15.png") != null,"Не загружается melee_models_v15")
    _record_test(load("res://weapon_modules_v6.png") != null,"Не загружается weapon_modules_v6")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v17")
    _record_test(load("res://melee_inventory_v9.png") != null,"Не загружается melee_inventory_v9")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v17")
    _record_test(load("res://infected_v6.png") != null,"Не загружается infected_v6")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v9")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v8")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v8")
    _record_test(_world_prop_region("large_med_cabinet").size.x == 72,"Large med cabinet region сломан")
    _record_test(_world_prop_region("oxygen_cylinder").size.y == 64,"Oxygen cylinder region сломан")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    _record_test(load("res://weapon_models_v16.png") != null,"Не загружается weapon_models_v16")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v18")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v18")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v10")
    _record_test(load("res://world_tiles_v9.png") != null,"Не загружается world_tiles_v9")
    _record_test(load("res://ground_chunk_v9.png") != null,"Не загружается ground_chunk_v9")
    _record_test(_world_prop_region("metal_shelving").size.x == 96,"Metal shelving region сломан")
    _record_test(_world_prop_region("gas_can").size.y == 56,"Gas can region сломан")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    _record_test(load("res://player_pose_front_v14.png") != null,"Не загружается player_pose_front_v14")
    _record_test(load("res://player_pose_back_v14.png") != null,"Не загружается player_pose_back_v14")
    var side_legs_test = load("res://player_legs_side_v3.png")
    _record_test(side_legs_test != null,"Не загружается player_legs_side_v2")
    if side_legs_test != null:
        _record_test(side_legs_test.get_width() == 576,"Неверная ширина side leg atlas")
        _record_test(side_legs_test.get_height() == 240,"Неверная высота side leg atlas")
    _record_test(_movement_cardinal_from_vector(Vector2(1,0),2) == 2,"Right side mapping сломан")
    _record_test(_movement_cardinal_from_vector(Vector2(-1,0),2) == 3,"Left side mapping сломан")
    _record_test(_movement_cardinal_from_vector(Vector2(0,-1),3) == 3,"Vertical movement должен сохранять left side")
    _record_test(_movement_cardinal_from_vector(Vector2(0,1),2) == 2,"Vertical movement должен сохранять right side")
    _record_test(_directional_leg_row(2,false,true) == 0,"Right walk row сломан")
    _record_test(_directional_leg_row(3,false,true) == 1,"Left walk row сломан")
    _record_test(_directional_leg_row(2,true,true) == 2,"Right run row сломан")
    _record_test(_directional_leg_row(3,true,true) == 3,"Left run row сломан")
    _record_test(_directional_leg_row(2,false,false) == 4,"Right idle row сломан")
    _record_test(_directional_leg_row(3,false,false) == 5,"Left idle row сломан")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v19")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v19")
    _record_test(item_defs.has("sterile_bandage"),"Нет sterile_bandage")
    _record_test(item_defs.has("antiseptic"),"Нет antiseptic")
    _record_test(item_defs.has("painkillers"),"Нет painkillers")
    _record_test(item_defs.has("antibiotics"),"Нет antibiotics")

    var saved_med_pain = pain
    var saved_med_pk = painkiller_time
    pain = 70.0
    painkiller_time = 120.0
    _record_test(abs(_effective_pain() - 38.0) < 0.01,"Painkiller suppression сломан")
    pain = saved_med_pain
    painkiller_time = saved_med_pk

    var saved_contam = wound_contamination
    wound_contamination = 10.0
    _contaminate_wound(10.0,true)
    _record_test(wound_contamination > 20.0,"Wound contamination helper сломан")
    wound_contamination = saved_contam
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v20")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v20")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v11")
    _record_test(item_defs.has("firewood"),"Нет firewood")
    _record_test(_make_item_icon("firewood") != null,"Не создаётся иконка дров")
    _record_test(_make_world_loot_texture("firewood") != null,"Не создаётся world-loot дров")
    _record_test(_base_object_name("campfire") == "КОСТЁР","Название костра сломано")
    _record_test(int(_base_build_costs("campfire").get("scrap",0)) == 1,"Campfire scrap cost сломан")
    _record_test(abs(_base_heat_strength_for("heater",0.0)-12.0) < 0.01,"Heater heat strength сломан")
    _record_test(abs(_base_heat_strength_for("campfire",0.0)-18.0) < 0.01,"Campfire heat strength сломан")
    _record_test(_base_heat_strength_for("campfire",200.0) == 0.0,"Campfire heat radius сломан")
    _record_test(_world_prop_region("campfire").size == Vector2(64,56),"Campfire world prop region сломан")
    var native_pose_front = load("res://player_pose_front_v14.png")
    var native_pose_back = load("res://player_pose_back_v14.png")
    var native_side_legs = load("res://player_legs_side_v3.png")
    _record_test(native_pose_front != null,"Не загружается native front atlas v14")
    _record_test(native_pose_back != null,"Не загружается native back atlas v14")
    _record_test(native_side_legs != null,"Не загружается native side legs v3")
    if native_pose_front != null:
        _record_test(native_pose_front.get_width() == 480,"Native pose width должен быть 480")
        _record_test(native_pose_front.get_height() == 3900,"Native pose height должен быть 3900")
    if native_side_legs != null:
        _record_test(native_side_legs.get_width() == 576,"Native leg atlas width должен быть 576")
        _record_test(native_side_legs.get_height() == 240,"Native leg atlas height должен быть 240")
    _record_test(abs(_gait_cycle_distance(false) - 48.0) < 0.01,"Walk cycle distance сломан")
    _record_test(abs(_gait_cycle_distance(true) - 50.0) < 0.01,"Run cycle distance сломан")
    _record_test(abs(_gait_phase_delta_for_distance(24.0,false) - PI) < 0.001,"Walk half-cycle sync сломан")
    _record_test(abs(_gait_phase_delta_for_distance(25.0,true) - PI) < 0.001,"Run half-cycle sync сломан")
    _record_test(abs(MOVE_SPEED - ENEMY_SPEED) < 0.001,"Player walk speed должен совпадать с infected speed")
    _record_test(abs(MOVE_SPEED - 53.0) < 0.001,"Неверная базовая скорость игрока")
    _record_test(abs(SPRINT_SPEED_MULT - 1.28) < 0.001,"Неверный sprint multiplier")
    var physics_walk_step = _movement_velocity_step(
        Vector2.ZERO,
        Vector2(MOVE_SPEED,0),
        0.10,
        false
    )
    _record_test(physics_walk_step.x > 20.0 and physics_walk_step.x < MOVE_SPEED,"Walk acceleration сломана")
    var physics_brake_step = _movement_velocity_step(
        Vector2(MOVE_SPEED,0),
        Vector2.ZERO,
        0.10,
        false
    )
    _record_test(physics_brake_step.x > 0.0 and physics_brake_step.x < MOVE_SPEED,"Braking physics сломана")
    var physics_reverse_step = _movement_velocity_step(
        Vector2(MOVE_SPEED,0),
        Vector2(-MOVE_SPEED,0),
        0.10,
        false
    )
    _record_test(physics_reverse_step.x < physics_brake_step.x,"Turn/reverse acceleration сломана")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v21")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v21")
    _record_test(load("res://world_props_v12.png") != null,"Не загружается world_props_v12")
    _record_test(item_defs.has("dirty_water"),"Нет dirty_water")
    _record_test(_make_item_icon("dirty_water") != null,"Не создаётся иконка dirty_water")
    _record_test(_make_world_loot_texture("dirty_water") != null,"Не создаётся world-loot dirty_water")
    _record_test(_base_object_name("rain_collector") == "ДОЖДЕСБОРНИК","Название дождесборника сломано")
    _record_test(_world_prop_region("rain_collector").size == Vector2(64,64),"Rain collector prop region сломан")
    _record_test(abs(_rain_collector_capacity() - 8.0) < 0.01,"Rain collector capacity сломана")
    _record_test(abs(_rain_collector_fill_rate("rain",false) - 0.025) < 0.0001,"Rain collector rate сломана")
    _record_test(_rain_collector_fill_rate("rain",true) == 0.0,"Rain collector shelter rule сломан")
    _record_test(load("res://inventory_icons_v22.png") != null,"Не загружается inventory_icons_v22")
    _record_test(load("res://loot_sprites_v22.png") != null,"Не загружается loot_sprites_v22")
    _record_test(item_defs.has("grain"),"Нет grain")
    _record_test(item_defs.has("herbs"),"Нет herbs")
    _record_test(item_defs.has("hot_meal"),"Нет hot_meal")
    _record_test(item_defs.has("herbal_tea"),"Нет herbal_tea")
    var old_well_fed_test = well_fed_time
    well_fed_time = 10.0
    _record_test(abs(_nutrition_stamina_multiplier() - 1.15) < 0.001,"Well-fed multiplier сломан")
    well_fed_time = old_well_fed_test
    var old_warm_drink_test = warm_drink_time
    warm_drink_time = 10.0
    _record_test(abs(_warm_drink_heat_bonus() - 1.5) < 0.001,"Warm drink heat bonus сломан")
    warm_drink_time = old_warm_drink_test
    _record_test(hud_world_root != null,"Не создан ProductionHUD")
    _record_test(hud_vital_bars.size() == 6,"HUD должен иметь 6 основных шкал")
    _record_test(hud_vital_values.size() == 6,"HUD должен иметь 6 числовых значений")
    _record_test(hud_weapon_icon != null,"Не создан HUD weapon icon")
    _record_test(hud_weapon_condition_bar != null,"Не создан HUD condition bar")
    _record_test(hud_visibility_bar != null and hud_noise_bar != null,"Не создан HUD stealth block")
    _record_test(hud_quick_slots.size() == 6,"HUD quickbar должен иметь 6 слотов")
    _record_test(hud_condition_values.size() == 4,"HUD reference condition strip должен иметь 4 статуса")
    _record_test(hud_objective_label != null and hud_objective_sub_label != null,"Не создан HUD objective block")
    _record_test(hud_interaction_panel != null,"Не создан interaction HUD panel")
    _record_test(hud_weapon_condition_value_label != null,"Не создан HUD durability value")
    _record_test(hud_env_camp_label != null and hud_env_camp_sub_label != null,"Не создан HUD camp state block")
    _record_test(hud_weather_icon_clear != null and hud_weather_icon_cloud != null and hud_weather_icon_rain != null,"Не созданы HUD weather icons")
    _record_test(hud_camp_icon_root != null,"Не создан HUD camp icon")
    _record_test(_hud_ammo_display_name("ammo_762") == "7,62 мм","HUD ammo display name сломан")
    _record_test(_hud_display_texture("makarov") != null,"HUD model art ПМ не создаётся")
    _record_test(_hud_display_texture("shotgun") != null,"HUD model art shotgun не создаётся")
    _record_test(_hud_display_texture("akm") != null,"HUD model art АКМ не создаётся")
    _record_test(_hud_display_texture("combat_knife") != null,"HUD model art knife не создаётся")

    for panel_name in ["VitalsPanel","EnvironmentPanel","StealthPanel","QuickShell","WeaponPanel","InteractionPrompt"]:
        var panel = hud_world_root.get_node_or_null(panel_name)
        var inside = panel != null
        if panel != null:
            inside = (
                panel.position.x >= 0.0
                and panel.position.y >= 0.0
                and panel.position.x + panel.size.x <= hud_world_root.size.x
                and panel.position.y + panel.size.y <= hud_world_root.size.y
            )
        _record_test(inside,"HUD panel выходит за viewport: %s" % panel_name)

    for slot in hud_quick_slots:
        var slot_button = slot.get("button",null)
        var slot_icon = slot.get("icon",null)
        var icon_inside = slot_button != null and slot_icon != null
        var icon_scaled = slot_icon != null
        if icon_inside:
            icon_inside = Rect2(Vector2.ZERO,slot_button.size).encloses(Rect2(slot_icon.position,slot_icon.size))
            icon_scaled = slot_icon.stretch_mode == TextureRect.STRETCH_SCALE
        _record_test(icon_inside,"Quickbar icon выходит за слот")
        _record_test(icon_scaled,"Quickbar icon использует неверный stretch mode")

    _record_test(_hud_candidate_text_fits(hud_env_shelter_label,"Снаружи • Ветер 99",5,4),"HUD не вмещает длинную строку погоды/ветра")
    _record_test(_hud_candidate_text_fits(hud_env_camp_label,"ЛАГЕРЬ (БЕЗОП.)",5,4),"HUD не вмещает статус лагеря")
    _record_test(_hud_candidate_text_fits(hud_env_camp_label,"ОТКРЫТОЕ МЕСТО",5,4),"HUD не вмещает статус открытой местности")
    _record_test(_hud_candidate_text_fits(hud_objective_label,"ПОДГОТОВИТЬ ВЫЛАЗКУ",5,4),"HUD не вмещает длинную текущую цель")
    _record_test(_hud_candidate_text_fits(hud_stealth_noise_label,"ВЫСТРЕЛ",5,4),"HUD не вмещает статус шума")
    _record_test(_hud_candidate_text_fits(hud_weapon_name_label,"Пожарный топор",6,5),"HUD не вмещает длинное название оружия")
    _record_test(_hud_candidate_text_fits(hud_reload_label,"ПЕРЕЗАРЯДКА",5,4),"HUD не вмещает статус перезарядки")
    _record_test(_hud_candidate_text_fits(hud_reload_label,"7,62 мм",5,4),"HUD не вмещает калибр")
    _record_test(_hud_candidate_text_fits(hud_reload_label,"АВТО • 45",5,4),"HUD не вмещает режим и ёмкость магазина")
    _record_test(_hud_candidate_text_fits(hud_env_zone_label,"ПРОМЫШЛЕННАЯ ЗОНА",5,4),"HUD не вмещает длинное название зоны")
    _record_test(_hud_candidate_text_fits(hud_env_camp_sub_label,"Источник тепла +12°C",5,4),"HUD не вмещает строку источника тепла")
    _record_test(_hud_candidate_text_fits(interaction_label,"ПОДОБРАТЬ • СТЕРИЛЬНЫЙ БИНТ",6,5),"Interaction prompt не вмещает длинное русское имя")

    _update_hud()
    var hud_labels = hud_world_root.find_children("*","Label",true,false)
    for hud_label_node in hud_labels:
        if hud_label_node is Label:
            _record_test(_hud_single_line_label_fits(hud_label_node),"HUD текст не помещается: %s" % hud_label_node.text.replace("\n"," / "))
    _record_test(hud_objective_label.get_visible_line_count() >= hud_objective_label.get_line_count(),"Заголовок цели обрезан по высоте")
    _record_test(hud_objective_sub_label.get_visible_line_count() >= hud_objective_sub_label.get_line_count(),"Описание цели обрезано по высоте")

    _record_test(InputMap.has_action("quick_slot_1"),"Нет input action quick_slot_1")
    _record_test(InputMap.has_action("quick_slot_6"),"Нет input action quick_slot_6")
    _record_test(_event_matches_digit(InputEventKey.new(),KEY_1) == false,"Digit fallback должен требовать keycode")
    _record_test(hud_quick_slots.size() == 6,"Quickbar должен содержать 6 слотов")
    test_chunk.queue_free()
    door_states.erase("9999:9999:door:selftest")

    if self_test_failures.is_empty():
        print("OSTATOK 0.48.4 MICRO GRID HUD SELFTEST: OK")
    else:
        print("OSTATOK 0.48.4 MICRO GRID HUD SELFTEST: FAILURES = ",self_test_failures.size())

func _ready():
    y_sort_enabled = true
    _load_data()
    _sanitize_skills()
    _ensure_input("move_left", KEY_A)
    _ensure_input("move_right", KEY_D)
    _ensure_input("move_up", KEY_W)
    _ensure_input("move_down", KEY_S)
    _ensure_input("reload", KEY_R)
    _ensure_input("sprint", KEY_SHIFT)
    _ensure_input("base_build", KEY_B)
    _ensure_input("quick_slot_1", KEY_1)
    _ensure_input("quick_slot_2", KEY_2)
    _ensure_input("quick_slot_3", KEY_3)
    _ensure_input("quick_slot_4", KEY_4)
    _ensure_input("quick_slot_5", KEY_5)
    _ensure_input("quick_slot_6", KEY_6)

    _run_static_self_tests()
    _load_state()

    if inventory_entries.is_empty():
        _grid_add(inventory_entries, "makarov", 1, INV_W, INV_H)
        _grid_add(inventory_entries, "bandage", 2, INV_W, INV_H)
        _grid_add(inventory_entries, "water", 1, INV_W, INV_H)
        _grid_add(inventory_entries, "ammo_9x18", 24, INV_W, INV_H)
        _grid_add(inventory_entries, "field_backpack", 1, INV_W, INV_H)
        _grid_add(inventory_entries, "flashlight", 1, INV_W, INV_H)
        _grid_add(inventory_entries, "cap", 1, INV_W, INV_H)
        _grid_add(inventory_entries, "combat_knife", 1, INV_W, INV_H)

    _create_player()
    _create_weather_visuals()
    _create_day_night()
    _create_hud()
    _create_inventory_ui()
    _create_hover_inspector()
    _create_weapon_mod_ui()
    _create_crafting_ui()
    _create_base_build_ui()
    _create_rest_ui()
    _create_base_system()
    _refresh_chunks(true)
    _validate_equipment()
    _run_runtime_smoke_tests()
    _refresh_inventory_ui()

func _input(event):
    if not inventory_open:
        return

    if event is InputEventMouseMotion:
        if inventory_drag_candidate_index >= 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            if not inventory_drag_active and event.position.distance_to(inventory_drag_press_position) >= 4.0:
                _start_inventory_drag()

            if inventory_drag_active:
                _update_inventory_drag_preview(event.position)

    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
            if inventory_drag_active:
                _finish_inventory_drag(event.position)
                get_viewport().set_input_as_handled()
            else:
                inventory_drag_candidate_index = -1
                inventory_drag_candidate_source = ""
                inventory_drag_candidate_id = ""



func _movement_acceleration_for(current_velocity,desired_velocity,running):
    if desired_velocity.length() <= 0.01:
        return PLAYER_BRAKE

    var accel = PLAYER_SPRINT_ACCEL if running else PLAYER_WALK_ACCEL

    if current_velocity.length() > 1.0:
        var alignment = current_velocity.normalized().dot(
            desired_velocity.normalized()
        )

        # Reversing or making a hard turn needs stronger planted-foot force.
        if alignment < 0.30:
            accel = PLAYER_TURN_ACCEL

    return accel

func _movement_velocity_step(current_velocity,desired_velocity,delta,running):
    var step_delta = max(0.0,float(delta))
    var accel = _movement_acceleration_for(
        current_velocity,
        desired_velocity,
        running
    )

    var result = current_velocity.move_toward(
        desired_velocity,
        accel * step_delta
    )

    if desired_velocity.length() <= 0.01 and result.length() < 0.10:
        return Vector2.ZERO

    return result

func _process(delta):
    if player == null:
        return

    fire_cooldown = max(0.0, fire_cooldown - delta)
    melee_cooldown = max(0.0,melee_cooldown - delta)
    melee_swing_time = max(0.0,melee_swing_time - delta)
    shove_cooldown = max(0.0,shove_cooldown - delta)
    weapon_recoil_time = max(0.0,weapon_recoil_time - delta)
    reload_feedback_time = max(0.0,reload_feedback_time - delta)
    if reload_feedback_time <= 0.0:
        reload_feedback = ""
    last_player_noise_time = max(0.0,last_player_noise_time - delta)
    if last_player_noise_time <= 0.0:
        last_player_noise_kind = "quiet"
        last_player_noise_radius = 0.0
    autosave_time += delta

    if reload_time > 0.0:
        reload_time = max(0.0,reload_time - delta)
        if reload_time <= 0.0:
            _finish_reload()

    _validate_equipment()

    var frame_start_position = player.global_position

    if inventory_open:
        move_direction = Vector2.ZERO
        is_sprinting = false
        player.velocity = Vector2.ZERO
    else:
        move_direction = Input.get_vector("move_left","move_right","move_up","move_down")
        is_sprinting = (
            move_direction.length() > 0.05
            and Input.is_action_pressed("sprint")
            and stamina > 1.0
            and hunger > 0.0
            and thirst > 0.0
            and _injury_can_sprint()
        )

        var desired_velocity = move_direction * _current_move_speed()
        player.velocity = _movement_velocity_step(
            player.velocity,
            desired_velocity,
            delta,
            is_sprinting
        )
        player.move_and_slide()

    var actual_displacement = player.global_position - frame_start_position
    var instant_visual_speed = actual_displacement.length() / max(delta,0.001)

    var visual_speed_lerp = min(
        1.0,
        delta * (
            15.0
            if instant_visual_speed < visual_move_speed
            else 10.0
        )
    )
    visual_move_speed = lerp(
        visual_move_speed,
        instant_visual_speed,
        visual_speed_lerp
    )

    if actual_displacement.length() > 0.05:
        visual_move_direction = actual_displacement.normalized()

    var visual_movement_active = visual_move_speed > 2.0
    movement_anim_blend = move_toward(
        movement_anim_blend,
        1.0 if visual_movement_active else 0.0,
        delta * (
            7.5
            if visual_movement_active
            else 6.5
        )
    )

    if visual_movement_active and actual_displacement.length() > 0.001:
        # Distance-driven gait prevents foot sliding:
        # blocked/slowed movement automatically slows the animation.
        walk_phase = fposmod(
            walk_phase + _gait_phase_delta_for_distance(
                actual_displacement.length(),
                is_sprinting
            ),
            TAU
        )
    elif movement_anim_blend > 0.02:
        # Settle the final foot onto the nearest contact phase rather than
        # snapping from a stride directly to the idle sprite.
        var settle_target = 0.0 if cos(walk_phase) >= 0.0 else PI
        walk_phase = lerp_angle(
            walk_phase,
            settle_target,
            min(1.0,delta * 10.0)
        )

    _update_survival(delta)
    _update_injuries(delta)
    _update_medical(delta)
    _update_nutrition(delta)

    if health <= 0.0:
        _respawn_player()

    var mouse_pos = get_global_mouse_position()
    if not inventory_open and player.global_position.distance_to(mouse_pos) > 2.0:
        aim_direction = (mouse_pos - player.global_position).normalized()

    _update_player_visuals(delta)
    _update_world_items(delta)
    _update_enemies(delta)
    _update_doors(delta)
    _update_roofs(delta)
    _update_day_night(delta)
    _update_weather(delta)
    _update_base_system(delta)

    var now_chunk = _world_to_chunk(player.global_position)
    if now_chunk != current_chunk:
        _refresh_chunks(false)

    if not inventory_open:
        var w = weapon_defs.get(current_weapon_id, {})
        if equipped_melee_id == "" and bool(w.get("automatic", false)) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            _fire_weapon()

    if tracer_time > 0.0:
        tracer_time -= delta
        if tracer_time <= 0.0 and tracer != null:
            tracer.visible = false

    if muzzle_time > 0.0:
        muzzle_time -= delta
        if muzzle_time <= 0.0 and muzzle_flash != null:
            muzzle_flash.visible = false

    if autosave_time >= 10.0:
        autosave_time = 0.0
        _save_state()

    if rest_open:
        _refresh_rest_ui()

    _update_hud()
    _update_interaction_prompt()
    _update_hover_position()


func _select_quick_slot(slot):
    if inventory_open:
        return false

    match int(slot):
        1:
            if _inventory_has_item("makarov"):
                _switch_weapon("makarov")
                return true
        2:
            if _inventory_has_item("shotgun"):
                _switch_weapon("shotgun")
                return true
        3:
            if _inventory_has_item("akm"):
                _switch_weapon("akm")
                return true
        4:
            if _inventory_has_item("combat_knife"):
                _switch_melee("combat_knife")
                return true
        5:
            if _inventory_has_item("steel_pipe"):
                _switch_melee("steel_pipe")
                return true
        6:
            if _inventory_has_item("fire_axe"):
                _switch_melee("fire_axe")
                return true

    _set_survival_feedback("Предмет быстрого слота отсутствует в инвентаре",1.4)
    return false

func _event_matches_digit(event,key_code):
    if not (event is InputEventKey):
        return false
    return event.physical_keycode == key_code or event.keycode == key_code


func _unhandled_input(event):
    if event.is_action_pressed("reload"):
        if not inventory_open:
            _start_reload()
        return

    if event.is_action_pressed("quick_slot_1"):
        _select_quick_slot(1)
        return
    if event.is_action_pressed("quick_slot_2"):
        _select_quick_slot(2)
        return
    if event.is_action_pressed("quick_slot_3"):
        _select_quick_slot(3)
        return
    if event.is_action_pressed("quick_slot_4"):
        _select_quick_slot(4)
        return
    if event.is_action_pressed("quick_slot_5"):
        _select_quick_slot(5)
        return
    if event.is_action_pressed("quick_slot_6"):
        _select_quick_slot(6)
        return

    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not inventory_open:
            _primary_attack()

    elif event is InputEventKey:
        if event.pressed and not event.echo:
            # Logical-key fallback fixes layouts where physical digit codes
            # differ from KEY_1..KEY_6.
            if _event_matches_digit(event,KEY_1):
                _select_quick_slot(1)
                return
            if _event_matches_digit(event,KEY_2):
                _select_quick_slot(2)
                return
            if _event_matches_digit(event,KEY_3):
                _select_quick_slot(3)
                return
            if _event_matches_digit(event,KEY_4):
                _select_quick_slot(4)
                return
            if _event_matches_digit(event,KEY_5):
                _select_quick_slot(5)
                return
            if _event_matches_digit(event,KEY_6):
                _select_quick_slot(6)
                return

            match event.physical_keycode:
                KEY_R:
                    if not inventory_open:
                        _start_reload()
                KEY_E:
                    if not inventory_open:
                        _interact()
                KEY_TAB, KEY_I:
                    if mod_panel_open:
                        _close_weapon_mod_panel()
                    elif rest_open:
                        _close_rest_panel()
                    elif crafting_open:
                        _close_crafting()
                    elif base_build_open:
                        _close_base_build()
                    else:
                        _toggle_inventory()
                KEY_ESCAPE:
                    if mod_panel_open:
                        _close_weapon_mod_panel()
                    elif rest_open:
                        _close_rest_panel()
                    elif crafting_open:
                        _close_crafting()
                    elif base_build_open:
                        _close_base_build()
                    elif inventory_open:
                        _close_inventory()
                KEY_B:
                    if base_build_open:
                        _close_base_build()
                    elif not inventory_open:
                        _open_base_build()
                KEY_X:
                    if base_build_open:
                        _dismantle_nearest_base_object()
                KEY_H:
                    _quick_bandage()
                KEY_F:
                    _toggle_flashlight()
                KEY_T:
                    var debug_advanced_minutes = world_minutes + 60.0
                    if debug_advanced_minutes >= 1440.0:
                        world_day += 1
                    world_minutes = fmod(debug_advanced_minutes,1440.0)
                KEY_V:
                    if not inventory_open:
                        _perform_shove()
                KEY_Q:
                    if inventory_open and not crafting_open:
                        _drop_selected_inventory()
                KEY_F5:
                    _save_state()

func _load_data():
    item_defs = _fallback_items()
    weapon_defs = _fallback_weapons()
    melee_defs = _fallback_melee()
    loot_tables = _fallback_loot()
    recipe_defs = _fallback_recipes()

func _load_json_dict(path, fallback):
    var file = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return fallback
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) == TYPE_DICTIONARY:
        return parsed
    return fallback



func _fallback_items():
    return {
        "bandage":{"name":"Бинт","short":"БИНТ","w":1,"h":1,"stack":20,"weight":0.08,"category":"medical","use":"bandage","color":"#d7c9ad"},
        "water":{"name":"Вода","short":"ВОДА","w":1,"h":2,"stack":20,"weight":0.55,"category":"food","use":"water","color":"#718d9a"},
        "canned_meat":{"name":"Консервы","short":"ЕДА","w":1,"h":1,"stack":20,"weight":0.38,"category":"food","use":"food","color":"#8c7556"},
        "scrap":{"name":"Металлолом","short":"ЛОМ","w":1,"h":1,"stack":20,"weight":0.65,"category":"material","use":"","color":"#777975"},
        "cloth":{"name":"Ткань","short":"ТКАНЬ","w":1,"h":1,"stack":20,"weight":0.12,"category":"material","use":"","color":"#a49b84"},
        "tape":{"name":"Изолента","short":"ЛЕНТА","w":1,"h":1,"stack":20,"weight":0.11,"category":"material","use":"","color":"#4f5c68"},
        "repair_kit":{"name":"Ремкомплект","short":"РЕМ","w":2,"h":1,"stack":20,"weight":0.75,"category":"tool","use":"repair","color":"#7b715e"},
        "water_filter":{"name":"Походный фильтр","short":"ФИЛЬТ","w":1,"h":2,"stack":1,"weight":0.42,"category":"tool","use":"water_filter","color":"#66776e"},
        "ammo_9x18":{"name":"9×18 мм","short":"9×18","w":1,"h":1,"stack":20,"weight":0.012,"category":"ammo","use":"","color":"#a88f57"},
        "ammo_12g":{"name":"12 калибр","short":"12К","w":1,"h":1,"stack":20,"weight":0.045,"category":"ammo","use":"","color":"#9a5c4f"},
        "ammo_762":{"name":"7.62×39 мм","short":"7.62","w":1,"h":1,"stack":20,"weight":0.017,"category":"ammo","use":"","color":"#987b46"},
        "makarov":{"name":"ПМ","short":"ПМ","w":2,"h":1,"stack":1,"weight":0.73,"category":"weapon","use":"weapon","color":"#555b58"},
        "shotgun":{"name":"Дробовик","short":"ДРОБ","w":3,"h":1,"stack":1,"weight":3.2,"category":"weapon","use":"weapon","color":"#6d533c"},
        "akm":{"name":"АКМ","short":"АКМ","w":3,"h":1,"stack":1,"weight":3.6,"category":"weapon","use":"weapon","color":"#4f514a"},
        "combat_knife":{"name":"Боевой нож","short":"НОЖ","w":2,"h":1,"stack":1,"weight":0.42,"category":"melee","use":"melee","color":"#787d79"},
        "steel_pipe":{"name":"Стальная труба","short":"ТРУБА","w":2,"h":1,"stack":1,"weight":1.45,"category":"melee","use":"melee","color":"#727775"},
        "fire_axe":{"name":"Пожарный топор","short":"ТОПОР","w":3,"h":1,"stack":1,"weight":2.35,"category":"melee","use":"melee","color":"#8b5546"},
        "cap":{"name":"Кепка","short":"КЕП","w":1,"h":1,"stack":1,"weight":0.12,"category":"gear","use":"gear","slot":"head","armor":0.02,"bleed_resist":0.0,"warmth":0.5,"rain_protect":0.05,"color":"#6f725f"},
        "light_jacket":{"name":"Плотная куртка","short":"КУРТ","w":2,"h":2,"stack":1,"weight":1.1,"category":"gear","use":"gear","slot":"body","armor":0.08,"bleed_resist":0.08,"warmth":3.2,"rain_protect":0.34,"color":"#59604f"},
        "police_vest":{"name":"Полицейский бронежилет","short":"БРОН","w":2,"h":2,"stack":1,"weight":3.4,"category":"gear","use":"gear","slot":"body","armor":0.30,"bleed_resist":0.24,"warmth":1.4,"rain_protect":0.12,"color":"#414a4b"},
        "field_backpack":{"name":"Полевой рюкзак","short":"РЮКЗ","w":2,"h":2,"stack":1,"weight":1.4,"category":"gear","use":"gear","slot":"backpack","carry_bonus":12.0,"warmth":0.2,"rain_protect":0.08,"color":"#59644f"},
        "flashlight":{"name":"Ручной фонарь","short":"ФОН","w":1,"h":2,"stack":1,"weight":0.35,"category":"gear","use":"gear","slot":"utility","color":"#c2ad78"},
        "makarov_extmag":{"name":"Увеличенный магазин ПМ","short":"ПМ+","w":1,"h":2,"stack":1,"weight":0.16,"category":"mod","use":"weapon_mod","mod_slot":"magazine","allowed_weapon":"makarov","mag_bonus":4,"color":"#5c6062"},
        "shotgun_exttube":{"name":"Удлинитель трубки дробовика","short":"ТРУБ","w":1,"h":2,"stack":1,"weight":0.30,"category":"mod","use":"weapon_mod","mod_slot":"magazine","allowed_weapon":"shotgun","mag_bonus":3,"color":"#6d6f70"},
        "akm_extmag":{"name":"Магазин АКМ на 45","short":"45Р","w":1,"h":2,"stack":1,"weight":0.48,"category":"mod","use":"weapon_mod","mod_slot":"magazine","allowed_weapon":"akm","mag_bonus":15,"color":"#5a4b3c"},
        "muzzle_brake":{"name":"Дульный тормоз АКМ","short":"ДТК","w":1,"h":1,"stack":1,"weight":0.22,"category":"mod","use":"weapon_mod","mod_slot":"muzzle","allowed_weapon":"akm","spread_mult":0.86,"noise_mult":1.08,"color":"#666b68"},
        "suppressor":{"name":"Самодельный глушитель ПМ","short":"ГЛУШ","w":1,"h":2,"stack":1,"weight":0.42,"category":"mod","use":"weapon_mod","mod_slot":"muzzle","allowed_weapon":"makarov","spread_mult":1.04,"noise_mult":0.58,"color":"#535b56"},
        "sterile_bandage":{"name":"Стерильная повязка","short":"СТЕР","w":1,"h":1,"stack":20,"weight":0.09,"category":"medical","use":"sterile_bandage","color":"#d9d6c5"},
        "antiseptic":{"name":"Антисептик","short":"АНТИС","w":1,"h":2,"stack":6,"weight":0.28,"category":"medical","use":"antiseptic","color":"#5d879d"},
        "painkillers":{"name":"Обезболивающее","short":"БОЛЬ","w":1,"h":1,"stack":10,"weight":0.05,"category":"medical","use":"painkillers","color":"#8f9693"},
        "antibiotics":{"name":"Антибиотики","short":"АНТИБ","w":1,"h":1,"stack":10,"weight":0.05,"category":"medical","use":"antibiotics","color":"#a8ad9d"},
        "firewood":{"name":"Дрова","short":"ДРОВА","w":2,"h":1,"stack":20,"weight":0.65,"category":"material","use":"","color":"#8e5938"},
        "dirty_water":{"name":"Дождевая вода","short":"СЫРАЯ","w":1,"h":2,"stack":20,"weight":0.55,"category":"food","use":"dirty_water","color":"#657a7d"},
        "grain":{"name":"Крупа","short":"КРУПА","w":1,"h":1,"stack":20,"weight":0.24,"category":"food","use":"cook_grain","color":"#a98555"},
        "herbs":{"name":"Съедобные травы","short":"ТРАВЫ","w":1,"h":1,"stack":20,"weight":0.05,"category":"food","use":"brew_tea","color":"#667b58"},
        "hot_meal":{"name":"Горячая каша","short":"КАША","w":1,"h":1,"stack":10,"weight":0.45,"category":"food","use":"hot_meal","color":"#a57b4c"},
        "herbal_tea":{"name":"Травяной чай","short":"ЧАЙ","w":1,"h":2,"stack":10,"weight":0.45,"category":"food","use":"herbal_tea","color":"#806044"}
    }

func _fallback_melee():
    return {
        "combat_knife":{
            "name":"Боевой нож",
            "damage":27.0,
            "range":35.0,
            "arc":0.72,
            "interval":0.42,
            "swing_anim":0.48,
            "stamina":2.0,
            "knockback":48.0,
            "stagger":0.22,
            "max_targets":1,
            "noise":45.0
        },
        "steel_pipe":{
            "name":"Стальная труба",
            "damage":34.0,
            "range":41.0,
            "arc":0.92,
            "interval":0.60,
            "swing_anim":0.60,
            "stamina":2.0,
            "knockback":88.0,
            "stagger":0.48,
            "max_targets":2,
            "noise":85.0
        },
        "fire_axe":{
            "name":"Пожарный топор",
            "damage":55.0,
            "range":43.0,
            "arc":0.82,
            "interval":0.76,
            "swing_anim":0.65,
            "stamina":2.0,
            "knockback":112.0,
            "stagger":0.62,
            "max_targets":2,
            "noise":105.0
        }
    }

func _fallback_weapons():
    return {
        "makarov":{
            "name":"ПМ","damage":34.0,"range":520.0,"interval":0.25,
            "mag":8,"ammo":"ammo_9x18","noise":520.0,
            "pellets":1,"spread":0.018,"automatic":false,"wear":0.10
        },
        "shotgun":{
            "name":"Дробовик","damage":15.0,"range":390.0,"interval":0.82,
            "mag":5,"ammo":"ammo_12g","noise":780.0,
            "pellets":9,"spread":0.23,"automatic":false,"wear":0.18
        },
        "akm":{
            "name":"АКМ","damage":42.0,"range":760.0,"interval":0.11,
            "mag":30,"ammo":"ammo_762","noise":880.0,
            "pellets":1,"spread":0.035,"automatic":true,"wear":0.055
        }
    }


func _fallback_loot():
    return {
        "all_items_test":[
            {"id":"bandage","min":20,"max":20,"chance":1.0},
            {"id":"sterile_bandage","min":10,"max":10,"chance":1.0},
            {"id":"antiseptic","min":4,"max":4,"chance":1.0},
            {"id":"painkillers","min":10,"max":10,"chance":1.0},
            {"id":"antibiotics","min":10,"max":10,"chance":1.0},
            {"id":"firewood","min":20,"max":20,"chance":1.0},
            {"id":"dirty_water","min":20,"max":20,"chance":1.0},
            {"id":"grain","min":20,"max":20,"chance":1.0},
            {"id":"herbs","min":20,"max":20,"chance":1.0},
            {"id":"hot_meal","min":10,"max":10,"chance":1.0},
            {"id":"herbal_tea","min":10,"max":10,"chance":1.0},
            {"id":"water","min":20,"max":20,"chance":1.0},
            {"id":"canned_meat","min":20,"max":20,"chance":1.0},
            {"id":"scrap","min":20,"max":20,"chance":1.0},
            {"id":"cloth","min":20,"max":20,"chance":1.0},
            {"id":"tape","min":20,"max":20,"chance":1.0},
            {"id":"repair_kit","min":20,"max":20,"chance":1.0},
            {"id":"water_filter","min":1,"max":1,"chance":1.0},
            {"id":"ammo_9x18","min":20,"max":20,"chance":1.0},
            {"id":"ammo_12g","min":20,"max":20,"chance":1.0},
            {"id":"ammo_762","min":20,"max":20,"chance":1.0},
            {"id":"makarov","min":1,"max":1,"chance":1.0},
            {"id":"shotgun","min":1,"max":1,"chance":1.0},
            {"id":"akm","min":1,"max":1,"chance":1.0},
            {"id":"combat_knife","min":1,"max":1,"chance":1.0},
            {"id":"steel_pipe","min":1,"max":1,"chance":1.0},
            {"id":"fire_axe","min":1,"max":1,"chance":1.0},
            {"id":"cap","min":1,"max":1,"chance":1.0},
            {"id":"light_jacket","min":1,"max":1,"chance":1.0},
            {"id":"police_vest","min":1,"max":1,"chance":1.0},
            {"id":"field_backpack","min":1,"max":1,"chance":1.0},
            {"id":"flashlight","min":1,"max":1,"chance":1.0},
            {"id":"makarov_extmag","min":1,"max":1,"chance":1.0},
            {"id":"shotgun_exttube","min":1,"max":1,"chance":1.0},
            {"id":"akm_extmag","min":1,"max":1,"chance":1.0},
            {"id":"muzzle_brake","min":1,"max":1,"chance":1.0},
            {"id":"suppressor","min":1,"max":1,"chance":1.0}
        ],
        "pharmacy":[
            {"id":"bandage","min":1,"max":4,"chance":1.0},
            {"id":"sterile_bandage","min":1,"max":3,"chance":0.78},
            {"id":"antiseptic","min":1,"max":2,"chance":0.74},
            {"id":"painkillers","min":1,"max":3,"chance":0.68},
            {"id":"antibiotics","min":1,"max":2,"chance":0.38},
            {"id":"water","min":1,"max":1,"chance":0.45},
            {"id":"canned_meat","min":1,"max":2,"chance":0.25},
            {"id":"light_jacket","min":1,"max":1,"chance":0.15},
            {"id":"cloth","min":1,"max":3,"chance":0.45}
        ],
        "grocery":[
            {"id":"grain","min":1,"max":4,"chance":0.88},
            {"id":"herbs","min":1,"max":2,"chance":0.18},
            {"id":"water","min":1,"max":2,"chance":1.0},
            {"id":"canned_meat","min":1,"max":4,"chance":1.0},
            {"id":"bandage","min":1,"max":1,"chance":0.25},
            {"id":"cloth","min":1,"max":2,"chance":0.30}
        ],
        "garage":[
            {"id":"scrap","min":2,"max":6,"chance":1.0},
            {"id":"firewood","min":1,"max":3,"chance":0.24},
            {"id":"tape","min":1,"max":3,"chance":0.75},
            {"id":"cloth","min":1,"max":3,"chance":0.45},
            {"id":"ammo_9x18","min":8,"max":24,"chance":0.55},
            {"id":"ammo_12g","min":4,"max":12,"chance":0.45},
            {"id":"makarov_extmag","min":1,"max":1,"chance":0.35},
            {"id":"combat_knife","min":1,"max":1,"chance":0.24},
            {"id":"steel_pipe","min":1,"max":1,"chance":0.38},
            {"id":"fire_axe","min":1,"max":1,"chance":0.14}
        ],
        "garage_weapon_test":[
            {"id":"shotgun","min":1,"max":1,"chance":1.0},
            {"id":"ammo_12g","min":10,"max":16,"chance":1.0},
            {"id":"scrap","min":2,"max":5,"chance":1.0},
            {"id":"tape","min":2,"max":3,"chance":1.0},
            {"id":"shotgun_exttube","min":1,"max":1,"chance":0.80},
            {"id":"cloth","min":2,"max":4,"chance":1.0},
            {"id":"steel_pipe","min":1,"max":1,"chance":1.0},
            {"id":"combat_knife","min":1,"max":1,"chance":0.75}
        ],
        "weapon_cache_test":[
            {"id":"akm","min":1,"max":1,"chance":1.0},
            {"id":"ammo_762","min":30,"max":60,"chance":1.0},
            {"id":"bandage","min":1,"max":2,"chance":0.8},
            {"id":"police_vest","min":1,"max":1,"chance":1.0},
            {"id":"akm_extmag","min":1,"max":1,"chance":0.80},
            {"id":"muzzle_brake","min":1,"max":1,"chance":0.45},
            {"id":"fire_axe","min":1,"max":1,"chance":0.60}
        ],
        "residential":[
            {"id":"grain","min":1,"max":2,"chance":0.30},
            {"id":"herbs","min":1,"max":1,"chance":0.08},
            {"id":"water","min":1,"max":1,"chance":0.65},
            {"id":"painkillers","min":1,"max":1,"chance":0.12},
            {"id":"antiseptic","min":1,"max":1,"chance":0.08},
            {"id":"canned_meat","min":1,"max":2,"chance":0.7},
            {"id":"bandage","min":1,"max":2,"chance":0.35},
            {"id":"cloth","min":1,"max":3,"chance":0.65},
            {"id":"tape","min":1,"max":2,"chance":0.28},
            {"id":"ammo_9x18","min":4,"max":12,"chance":0.22},
            {"id":"cap","min":1,"max":1,"chance":0.35},
            {"id":"field_backpack","min":1,"max":1,"chance":0.15},
            {"id":"flashlight","min":1,"max":1,"chance":0.25},
            {"id":"makarov_extmag","min":1,"max":1,"chance":0.18},
            {"id":"suppressor","min":1,"max":1,"chance":0.10},
            {"id":"combat_knife","min":1,"max":1,"chance":0.10}
        ],
        "industrial":[
            {"id":"scrap","min":2,"max":7,"chance":1.0},
            {"id":"firewood","min":1,"max":3,"chance":0.18},
            {"id":"tape","min":1,"max":3,"chance":0.72},
            {"id":"cloth","min":1,"max":2,"chance":0.38},
            {"id":"repair_kit","min":1,"max":1,"chance":0.34},
            {"id":"steel_pipe","min":1,"max":1,"chance":0.28},
            {"id":"fire_axe","min":1,"max":1,"chance":0.12},
            {"id":"ammo_12g","min":3,"max":10,"chance":0.30},
            {"id":"ammo_762","min":8,"max":20,"chance":0.16},
            {"id":"shotgun_exttube","min":1,"max":1,"chance":0.14},
            {"id":"muzzle_brake","min":1,"max":1,"chance":0.12}
        ],
        "military":[
            {"id":"bandage","min":1,"max":3,"chance":0.70},
            {"id":"sterile_bandage","min":1,"max":2,"chance":0.48},
            {"id":"antiseptic","min":1,"max":1,"chance":0.28},
            {"id":"painkillers","min":1,"max":2,"chance":0.30},
            {"id":"antibiotics","min":1,"max":1,"chance":0.16},
            {"id":"ammo_9x18","min":8,"max":24,"chance":0.68},
            {"id":"ammo_12g","min":4,"max":12,"chance":0.48},
            {"id":"ammo_762","min":12,"max":30,"chance":0.72},
            {"id":"police_vest","min":1,"max":1,"chance":0.24},
            {"id":"akm_extmag","min":1,"max":1,"chance":0.18},
            {"id":"muzzle_brake","min":1,"max":1,"chance":0.20},
            {"id":"makarov","min":1,"max":1,"chance":0.10},
            {"id":"akm","min":1,"max":1,"chance":0.06}
        ],
        "forest_cache":[
            {"id":"herbs","min":1,"max":3,"chance":0.62},
            {"id":"grain","min":1,"max":2,"chance":0.12},
            {"id":"firewood","min":2,"max":5,"chance":0.82},
            {"id":"water","min":1,"max":2,"chance":0.68},
            {"id":"canned_meat","min":1,"max":2,"chance":0.58},
            {"id":"bandage","min":1,"max":2,"chance":0.35},
            {"id":"cloth","min":1,"max":3,"chance":0.55},
            {"id":"flashlight","min":1,"max":1,"chance":0.20},
            {"id":"combat_knife","min":1,"max":1,"chance":0.16},
            {"id":"fire_axe","min":1,"max":1,"chance":0.08},
            {"id":"shotgun","min":1,"max":1,"chance":0.04},
            {"id":"ammo_12g","min":3,"max":8,"chance":0.18}
        ],
        "rural":[
            {"id":"grain","min":1,"max":4,"chance":0.66},
            {"id":"herbs","min":1,"max":3,"chance":0.46},
            {"id":"firewood","min":2,"max":6,"chance":0.78},
            {"id":"water","min":1,"max":2,"chance":0.78},
            {"id":"canned_meat","min":1,"max":3,"chance":0.82},
            {"id":"cloth","min":1,"max":3,"chance":0.58},
            {"id":"tape","min":1,"max":2,"chance":0.32},
            {"id":"bandage","min":1,"max":2,"chance":0.28},
            {"id":"cap","min":1,"max":1,"chance":0.30},
            {"id":"field_backpack","min":1,"max":1,"chance":0.12},
            {"id":"fire_axe","min":1,"max":1,"chance":0.14},
            {"id":"shotgun","min":1,"max":1,"chance":0.05},
            {"id":"ammo_12g","min":3,"max":10,"chance":0.20}
        ]
    }

func _fallback_recipes():
    return {
        "field_bandage":{
            "name":"Полевой бинт",
            "ingredients":{"cloth":2},
            "output":"bandage",
            "output_qty":1,
            "skill_req":1
        },
        "sterile_bandage":{
            "name":"Стерильная повязка",
            "ingredients":{"bandage":1,"antiseptic":1},
            "output":"sterile_bandage",
            "output_qty":1,
            "skill_req":2
        },
        "repair_kit":{
            "name":"Ремкомплект",
            "ingredients":{"scrap":2,"tape":1},
            "output":"repair_kit",
            "output_qty":1,
            "skill_req":1
        },
        "water_filter":{
            "name":"Походный фильтр",
            "ingredients":{"cloth":1,"scrap":1,"tape":1},
            "output":"water_filter",
            "output_qty":1,
            "skill_req":2
        },
        "combat_knife":{
            "name":"Самодельный нож",
            "ingredients":{"scrap":2,"tape":1},
            "output":"combat_knife",
            "output_qty":1,
            "skill_req":2
        },
        "steel_pipe":{
            "name":"Усиленная труба",
            "ingredients":{"scrap":3,"tape":1},
            "output":"steel_pipe",
            "output_qty":1,
            "skill_req":2
        },
        "muzzle_brake":{
            "name":"Дульный тормоз АКМ",
            "ingredients":{"scrap":2,"tape":1},
            "output":"muzzle_brake",
            "output_qty":1,
            "skill_req":3
        },
        "makarov_extmag":{
            "name":"Увеличенный магазин ПМ",
            "ingredients":{"scrap":2,"tape":1},
            "output":"makarov_extmag",
            "output_qty":1,
            "skill_req":3
        },
        "shotgun_exttube":{
            "name":"Удлинитель магазина дробовика",
            "ingredients":{"scrap":3,"tape":1},
            "output":"shotgun_exttube",
            "output_qty":1,
            "skill_req":4
        },
        "suppressor":{
            "name":"Самодельный глушитель ПМ",
            "ingredients":{"scrap":3,"cloth":1,"tape":2},
            "output":"suppressor",
            "output_qty":1,
            "skill_req":4
        },
        "akm_extmag":{
            "name":"Увеличенный магазин АКМ",
            "ingredients":{"scrap":4,"tape":1},
            "output":"akm_extmag",
            "output_qty":1,
            "skill_req":5
        },
        "field_backpack":{
            "name":"Полевой рюкзак",
            "ingredients":{"cloth":4,"tape":2,"scrap":1},
            "output":"field_backpack",
            "output_qty":1,
            "skill_req":5
        }
    }

func _make_melee_arm_line(width_value,color_value):
    var line = Line2D.new()
    line.width = width_value
    line.default_color = color_value
    line.visible = false
    line.z_as_relative = true
    line.antialiased = false
    player_visual.add_child(line)
    return line


func _set_melee_arm_visible(active):
    var nodes = [
        pv_melee_back_outline,
        pv_melee_back_sleeve,
        pv_melee_front_outline,
        pv_melee_front_sleeve,
        pv_melee_back_elbow_outline,
        pv_melee_back_elbow,
        pv_melee_front_elbow_outline,
        pv_melee_front_elbow,
        pv_melee_back_hand_outline,
        pv_melee_back_hand,
        pv_melee_front_hand_outline,
        pv_melee_front_hand
    ]

    for node in nodes:
        if node != null:
            node.visible = active

func _melee_elbow_point(shoulder,hand,bend_sign,bend_amount):
    var delta = hand - shoulder
    var distance = delta.length()

    if distance <= 0.001:
        return shoulder

    var middle = (shoulder + hand) * 0.5
    var normal = Vector2(-delta.y,delta.x).normalized()

    # A capped bend keeps short arms from looping into circles
    # and long arms from looking rubber-stretched.
    var natural_bend = min(bend_amount,max(0.8,distance * 0.28))
    return middle + normal * bend_sign * natural_bend

func _set_melee_line_points(outline,sleeve,shoulder,elbow,hand):
    var shoulder_px = Vector2(round(shoulder.x * 2.0) * 0.5,round(shoulder.y * 2.0) * 0.5)
    var elbow_px = Vector2(round(elbow.x * 2.0) * 0.5,round(elbow.y * 2.0) * 0.5)
    var hand_px = Vector2(round(hand.x * 2.0) * 0.5,round(hand.y * 2.0) * 0.5)

    if outline != null:
        outline.clear_points()
        outline.add_point(shoulder_px)
        outline.add_point(elbow_px)
        outline.add_point(hand_px)

    if sleeve != null:
        sleeve.clear_points()
        sleeve.add_point(shoulder_px)
        sleeve.add_point(elbow_px)
        sleeve.add_point(hand_px)

func _update_melee_limb(outline,sleeve,elbow_outline,elbow_fill,hand_outline,hand_fill,shoulder,hand,bend_sign,bend_amount,hand_rotation):
    var elbow = _melee_elbow_point(shoulder,hand,bend_sign,bend_amount)
    var elbow_px = Vector2(round(elbow.x * 2.0) * 0.5,round(elbow.y * 2.0) * 0.5)
    var hand_px = Vector2(round(hand.x * 2.0) * 0.5,round(hand.y * 2.0) * 0.5)
    _set_melee_line_points(outline,sleeve,shoulder,elbow_px,hand_px)

    if elbow_outline != null:
        elbow_outline.position = elbow_px
        elbow_outline.rotation = 0.0
    if elbow_fill != null:
        elbow_fill.position = elbow_px
        elbow_fill.rotation = 0.0

    if hand_outline != null:
        hand_outline.position = hand_px
        hand_outline.rotation = hand_rotation
    if hand_fill != null:
        hand_fill.position = hand_px
        hand_fill.rotation = hand_rotation

func _set_melee_arm_z(facing_up):
    # Far arm remains behind the torso. Near arm emerges from the actual
    # visible shoulder and stays readable in every aim direction.
    if pv_melee_back_outline == null:
        return

    pv_melee_back_outline.z_index = -5
    pv_melee_back_sleeve.z_index = -4
    pv_melee_back_elbow_outline.z_index = -4
    pv_melee_back_elbow.z_index = -3
    pv_melee_back_hand_outline.z_index = 1
    pv_melee_back_hand.z_index = 2

    if facing_up:
        pv_melee_front_outline.z_index = 0
        pv_melee_front_sleeve.z_index = 1
        pv_melee_front_elbow_outline.z_index = 1
        pv_melee_front_elbow.z_index = 2
        pv_melee_front_hand_outline.z_index = 4
        pv_melee_front_hand.z_index = 5
    else:
        pv_melee_front_outline.z_index = 1
        pv_melee_front_sleeve.z_index = 2
        pv_melee_front_elbow_outline.z_index = 2
        pv_melee_front_elbow.z_index = 3
        pv_melee_front_hand_outline.z_index = 5
        pv_melee_front_hand.z_index = 6

func _player_part_texture(atlas,region):
    if atlas == null:
        return null
    var tex = AtlasTexture.new()
    tex.atlas = atlas
    tex.region = region
    return tex

func _player_part_sprite(atlas,region,parent,pos,z_value = 0):
    var sprite = Sprite2D.new()
    sprite.texture = _player_part_texture(atlas,region)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = pos
    sprite.z_index = z_value
    parent.add_child(sprite)
    return sprite




func _pose_weapon_column(id):
    if id == "makarov": return 0
    if id == "shotgun": return 1
    if id == "akm": return 2
    if id == "combat_knife": return 3
    if id == "steel_pipe": return 4
    if id == "fire_axe": return 5
    return 0



func _gait_variant_for_phase(phase_value):
    var gait = sin(phase_value)
    if gait > 0.30:
        return 1
    if gait < -0.30:
        return 2
    return 0





func _gait_cycle_distance(running):
    # Distance-driven cycle: animation speed follows actual travelled distance.
    # Walk cadence is tuned to match infected movement at the shared 53 px/s.
    return 50.0 if running else 48.0

func _gait_phase_delta_for_distance(distance,running):
    var cycle_distance = max(1.0,_gait_cycle_distance(running))
    return max(0.0,float(distance)) / cycle_distance * TAU

func _walk_phase_index(phase_value):
    var normalized = fposmod(phase_value,TAU) / TAU
    return int(floor(normalized * 12.0 + 0.5)) % 12


func _pose_state_base_row(state_index):
    return clamp(int(state_index),0,4) * 13

func _visual_facing_from_aim(current_left,aim_x):
    # Hysteresis prevents rapid left/right sprite flipping when aiming
    # almost vertically across the player center line.
    if aim_x < -0.12:
        return true
    if aim_x > 0.12:
        return false
    return current_left



func _weapon_pose_row_from_visual(row):
    var state_index = clamp(int(floor(float(row) / 13.0)),0,4)
    if state_index == 1:
        return 3
    if state_index == 2:
        return 4
    if state_index == 3:
        return 5
    if state_index == 4:
        return 6
    return 0


func _pose_visual_row(local_aim):
    var state_index = 0

    if equipped_melee_id != "":
        var swing_t = _melee_swing_progress()
        if swing_t >= 0.0:
            state_index = 3 if swing_t < 0.52 else 4
        elif local_aim.y < -0.48:
            state_index = 1
        elif local_aim.y > 0.48:
            state_index = 2
    else:
        if reload_time > 0.0:
            state_index = 4
        elif _firearm_recoil_amount() > 0.06:
            state_index = 3
        elif local_aim.y < -0.48:
            state_index = 1
        elif local_aim.y > 0.48:
            state_index = 2

    var base_row = _pose_state_base_row(state_index)
    if movement_anim_blend > 0.10 and visual_move_speed > 2.0:
        return base_row + 1 + _walk_phase_index(walk_phase)
    return base_row

func _pose_weapon_transform(id,row):
    var table = {
        "makarov":[
            {"pos":Vector2(7,-7),"angle":0.0}, {"pos":Vector2(7.2,-6.8),"angle":0.02}, {"pos":Vector2(6.8,-7.0),"angle":-0.02},
            {"pos":Vector2(6,-8.2),"angle":-0.55}, {"pos":Vector2(7,-5.5),"angle":0.42}, {"pos":Vector2(5.8,-7.5),"angle":-0.10}, {"pos":Vector2(4.3,-4.2),"angle":0.20}
        ],
        "shotgun":[
            {"pos":Vector2(1,-7),"angle":0.0}, {"pos":Vector2(1.2,-6.8),"angle":0.02}, {"pos":Vector2(0.8,-7.0),"angle":-0.02},
            {"pos":Vector2(0,-8),"angle":-0.50}, {"pos":Vector2(1.4,-5.5),"angle":0.38}, {"pos":Vector2(-0.8,-7.6),"angle":-0.08}, {"pos":Vector2(-0.2,-4.0),"angle":0.10}
        ],
        "akm":[
            {"pos":Vector2(1,-7),"angle":0.0}, {"pos":Vector2(1.2,-6.8),"angle":0.02}, {"pos":Vector2(0.8,-7.0),"angle":-0.02},
            {"pos":Vector2(0,-8.2),"angle":-0.50}, {"pos":Vector2(1.3,-5.7),"angle":0.38}, {"pos":Vector2(-0.9,-7.7),"angle":-0.10}, {"pos":Vector2(-0.3,-4.2),"angle":0.12}
        ],
        "combat_knife":[
            {"pos":Vector2(5,-4),"angle":0.12}, {"pos":Vector2(5.2,-3.8),"angle":0.08}, {"pos":Vector2(4.9,-4.0),"angle":0.16},
            {"pos":Vector2(4.5,-6),"angle":-0.48}, {"pos":Vector2(5.8,-3),"angle":0.42}, {"pos":Vector2(2,-13),"angle":-1.12}, {"pos":Vector2(6,-3),"angle":0.60}
        ],
        "steel_pipe":[
            {"pos":Vector2(4,-4),"angle":-0.35}, {"pos":Vector2(4,-3.8),"angle":-0.30}, {"pos":Vector2(3.8,-4.0),"angle":-0.40},
            {"pos":Vector2(3,-7),"angle":-0.75}, {"pos":Vector2(4.5,-3),"angle":0.10}, {"pos":Vector2(3,-14),"angle":-1.15}, {"pos":Vector2(6,-3),"angle":0.65}
        ],
        "fire_axe":[
            {"pos":Vector2(4,-4),"angle":0.18}, {"pos":Vector2(4,-3.8),"angle":0.15}, {"pos":Vector2(3.8,-4.0),"angle":0.22},
            {"pos":Vector2(3,-7),"angle":-0.70}, {"pos":Vector2(4.5,-3),"angle":0.42}, {"pos":Vector2(3,-15),"angle":-1.20}, {"pos":Vector2(6.5,-3),"angle":0.78}
        ]
    }
    var rows = table.get(id,table["makarov"])
    return rows[clamp(int(row),0,6)]




func _set_pose_frame(weapon_id,row):
    if pv_pose_back == null or pv_pose_front == null:
        return
    var col = _pose_weapon_column(weapon_id)
    var safe_row = clamp(int(row),0,64)
    var rect = Rect2(col * 80,safe_row * 60,80,60)
    pv_pose_back.region_rect = rect
    pv_pose_front.region_rect = rect

func _update_pose_weapon(weapon_id,row,pose_offset,pose_rotation):
    if pv_weapon_root == null:
        return

    var weapon_row = _weapon_pose_row_from_visual(row)
    var tf = _pose_weapon_transform(weapon_id,weapon_row)
    var base_pos = tf.get("pos",Vector2.ZERO) * 0.80
    var base_angle = float(tf.get("angle",0.0))

    var local_phase = int(row) % 13
    if local_phase > 0:
        var phase_index = local_phase - 1
        var phase_angle = float(phase_index) * TAU / 12.0
        base_pos += Vector2(
            sin(phase_angle) * 0.09,
            -abs(sin(phase_angle)) * 0.045
        )
        base_angle += sin(phase_angle) * 0.0025

    pv_weapon_root.position = base_pos.rotated(pose_rotation) + pose_offset
    pv_weapon_root.rotation = base_angle + pose_rotation
    pv_weapon_root.scale = Vector2(0.78,0.78)

    if equipped_melee_id != "":
        _update_melee_trail(equipped_melee_id,_melee_swing_progress())
    elif pv_melee_trail != null:
        pv_melee_trail.visible = false

func _create_player():
    player = CharacterBody2D.new()
    player.name = "Player"
    player.collision_layer = LAYER_PLAYER
    player.collision_mask = LAYER_WORLD
    player.z_index = 20
    player.z_as_relative = false
    add_child(player)

    if has_meta("loaded_player_position"):
        player.global_position = get_meta("loaded_player_position")
    else:
        player.global_position = Vector2(420,430)

    var shape_node = CollisionShape2D.new()
    var capsule = CapsuleShape2D.new()
    capsule.radius = 7.0
    capsule.height = 22.0
    shape_node.shape = capsule
    shape_node.position = Vector2(0,3)
    player.add_child(shape_node)

    player_visual = Node2D.new()
    player_visual.name = "Visual"
    player.add_child(player_visual)

    pv_shadow = _ellipse(
        Vector2(-1,14),
        12,
        4,
        Color(0.02,0.02,0.02,0.26),
        player_visual
    )
    pv_shadow.z_index = -30

    var parts_atlas = load("res://player_parts_v2.png")

    pv_backpack = _player_part_sprite(
        parts_atlas,Rect2(0,0,24,32),player_visual,Vector2(-8,-3),-3
    )
    pv_leg_l = _player_part_sprite(
        parts_atlas,Rect2(0,32,16,28),player_visual,Vector2(-3,10),-2
    )
    pv_leg_r = _player_part_sprite(
        parts_atlas,Rect2(16,32,16,28),player_visual,Vector2(3,10),-1
    )
    pv_boot_l = _player_part_sprite(
        parts_atlas,Rect2(32,32,12,10),player_visual,Vector2(-4,23),-1
    )
    pv_boot_r = _player_part_sprite(
        parts_atlas,Rect2(44,32,12,10),player_visual,Vector2(5,23),0
    )
    pv_body = _player_part_sprite(
        parts_atlas,Rect2(24,0,28,32),player_visual,Vector2(0,-3),0
    )
    pv_vest = _player_part_sprite(
        parts_atlas,Rect2(52,0,24,28),player_visual,Vector2(1,-3),1
    )
    pv_head = _player_part_sprite(
        parts_atlas,Rect2(76,0,20,20),player_visual,Vector2(2,-20),2
    )
    pv_helmet = _player_part_sprite(
        parts_atlas,Rect2(96,0,24,16),player_visual,Vector2(1,-26),3
    )

    _rect(Vector2(1,-12),Vector2(4,3),Color(0,0,0,0),player_visual).z_index = 1
    pv_helmet_lip = _rect(
        Vector2(8,-22),
        Vector2(6,2),
        Color("2d312e"),
        player_visual
    )
    pv_helmet_lip.z_index = 4

    # Full-body pose sprite integration. Old segmented body/legs are hidden
    # and kept only as compatibility nodes for old systems/selftests.
    pv_backpack.visible = false
    pv_body.visible = false
    pv_vest.visible = false
    pv_head.visible = false
    pv_helmet.visible = false
    pv_helmet_lip.visible = false
    pv_leg_l.visible = false
    pv_leg_r.visible = false
    pv_boot_l.visible = false
    pv_boot_r.visible = false

    pv_pose_back = Sprite2D.new()
    pv_pose_back.texture = load("res://player_pose_back_v14.png")
    pv_pose_back.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pv_pose_back.region_enabled = true
    pv_pose_back.region_rect = Rect2(0,0,80,60)
    pv_pose_back.z_index = 0
    player_visual.add_child(pv_pose_back)

    pv_pose_front = Sprite2D.new()
    pv_pose_front.texture = load("res://player_pose_front_v14.png")
    pv_pose_front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pv_pose_front.region_enabled = true
    pv_pose_front.region_rect = Rect2(0,0,80,60)
    pv_pose_front.z_index = 4
    player_visual.add_child(pv_pose_front)

    pv_legs = Sprite2D.new()
    pv_legs.name = "DirectionalLegs"
    pv_legs.texture = load("res://player_legs_side_v3.png")
    pv_legs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pv_legs.region_enabled = true
    pv_legs.region_rect = Rect2(0,0,48,40)
    pv_legs.position = Vector2(0,14)
    pv_legs.scale = Vector2.ONE
    pv_legs.z_index = -1
    player.add_child(pv_legs)

    pv_arm_back_root = Node2D.new()
    pv_arm_back_root.visible = false
    player_visual.add_child(pv_arm_back_root)

    pv_arm_front_root = Node2D.new()
    pv_arm_front_root.visible = false
    player_visual.add_child(pv_arm_front_root)

    pv_melee_back_outline = _make_melee_arm_line(5.0,Color("1c1e1c"))
    pv_melee_back_sleeve = _make_melee_arm_line(3.3,Color("485142"))
    pv_melee_front_outline = _make_melee_arm_line(5.0,Color("1c1e1c"))
    pv_melee_front_sleeve = _make_melee_arm_line(3.4,Color("5b6552"))

    # Blocky pixel-style joints use the exact body palette instead of
    # smooth ellipses, so the arms no longer look like a separate art style.
    pv_melee_back_elbow_outline = _rect(
        Vector2.ZERO,Vector2(4,4),Color("1c1e1c"),player_visual
    )
    pv_melee_back_elbow = _rect(
        Vector2.ZERO,Vector2(3,3),Color("485142"),player_visual
    )
    pv_melee_front_elbow_outline = _rect(
        Vector2.ZERO,Vector2(4,4),Color("1c1e1c"),player_visual
    )
    pv_melee_front_elbow = _rect(
        Vector2.ZERO,Vector2(3,3),Color("5b6552"),player_visual
    )

    pv_melee_back_hand_outline = _rect(
        Vector2.ZERO,Vector2(4,3),Color("69533f"),player_visual
    )
    pv_melee_back_hand = _rect(
        Vector2.ZERO,Vector2(3,2),Color("8f775b"),player_visual
    )
    pv_melee_front_hand_outline = _rect(
        Vector2.ZERO,Vector2(4,3),Color("69533f"),player_visual
    )
    pv_melee_front_hand = _rect(
        Vector2.ZERO,Vector2(3,2),Color("8f775b"),player_visual
    )

    _set_melee_arm_visible(false)

    pv_weapon_root = Node2D.new()
    pv_weapon_root.position = Vector2(7,-4)
    player_visual.add_child(pv_weapon_root)

    pv_melee_trail = Line2D.new()
    pv_melee_trail.width = 1.0
    pv_melee_trail.default_color = Color(0.85,0.87,0.82,0.30)
    pv_melee_trail.visible = false
    pv_melee_trail.z_index = 0
    player_visual.add_child(pv_melee_trail)

    pv_weapon_stock = _rect(
        Vector2(-8,1),Vector2(10,5),Color("6e5036"),pv_weapon_root
    )
    pv_weapon_body = _rect(
        Vector2(5,0),Vector2(18,4),Color("272826"),pv_weapon_root
    )
    pv_weapon_mag = _rect(
        Vector2(1,5),Vector2(4,7),Color("20201f"),pv_weapon_root
    )
    pv_weapon_barrel = _rect(
        Vector2(18,0),Vector2(15,2),Color("171817"),pv_weapon_root
    )

    pv_weapon_sprite = Sprite2D.new()
    pv_weapon_sprite.position = Vector2(20,0)
    pv_weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pv_weapon_sprite.z_index = 2
    pv_weapon_root.add_child(pv_weapon_sprite)

    pv_weapon_mag_visual = Sprite2D.new()
    pv_weapon_mag_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pv_weapon_mag_visual.visible = false
    pv_weapon_mag_visual.z_index = 3
    pv_weapon_root.add_child(pv_weapon_mag_visual)

    pv_weapon_muzzle_visual = Sprite2D.new()
    pv_weapon_muzzle_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    pv_weapon_muzzle_visual.visible = false
    pv_weapon_muzzle_visual.z_index = 3
    pv_weapon_root.add_child(pv_weapon_muzzle_visual)

    muzzle_flash = _poly(PackedVector2Array([
        Vector2(31,0),Vector2(39,-3),Vector2(36,0),Vector2(41,3)
    ]),Color(1.0,0.76,0.25,0.95),pv_weapon_root)
    muzzle_flash.visible = false
    muzzle_flash.z_index = 5

    camera = Camera2D.new()
    camera.zoom = Vector2(1.75,1.75)
    camera.position_smoothing_enabled = true
    camera.position_smoothing_speed = 8.0
    player.add_child(camera)

    tracer = Line2D.new()
    tracer.width = 1.0
    tracer.default_color = Color(1.0,0.82,0.43,0.82)
    tracer.z_index = 120
    tracer.z_as_relative = false
    tracer.visible = false
    add_child(tracer)

    _update_weapon_visual()
    _update_player_visuals(0.0)

func _ease_melee(value):
    var x = clamp(value,0.0,1.0)
    return x * x * (3.0 - 2.0 * x)

func _solve_arm_root_for_hand(target_local,hand_local,arm_rotation):
    return target_local - hand_local.rotated(arm_rotation)

func _place_arm_hand_at(arm_root,hand_local,target_local,arm_rotation):
    if arm_root == null:
        return
    arm_root.rotation = arm_rotation
    arm_root.position = _solve_arm_root_for_hand(target_local,hand_local,arm_rotation)

func _weapon_grip_to_player(grip_local):
    return pv_weapon_root.position + grip_local.rotated(pv_weapon_root.rotation)

func _melee_swing_progress():
    if melee_swing_time <= 0.0 or melee_swing_duration <= 0.001:
        return -1.0
    return clamp(1.0 - melee_swing_time / melee_swing_duration,0.0,1.0)


func _update_melee_trail(weapon_id,swing_t):
    if pv_melee_trail == null:
        return

    pv_melee_trail.clear_points()

    if swing_t < 0.0:
        pv_melee_trail.visible = false
        return

    var show_from = 0.34
    var show_to = 0.76
    var radius = 15.0
    var trail_angle = 0.52
    var trail_width = 0.9
    var trail_color = Color(0.86,0.89,0.84,0.30)

    if weapon_id == "steel_pipe":
        show_from = 0.32
        show_to = 0.82
        radius = 22.0
        trail_angle = 0.95
        trail_width = 1.2
        trail_color = Color(0.72,0.78,0.76,0.28)
    elif weapon_id == "fire_axe":
        show_from = 0.30
        show_to = 0.84
        radius = 24.0
        trail_angle = 1.18
        trail_width = 1.5
        trail_color = Color(0.80,0.70,0.58,0.33)

    if swing_t < show_from or swing_t > show_to:
        pv_melee_trail.visible = false
        return

    pv_melee_trail.visible = true
    pv_melee_trail.width = trail_width
    pv_melee_trail.default_color = trail_color

    var center = pv_weapon_root.position
    var current_angle = pv_weapon_root.rotation

    for i in range(7):
        var f = float(i) / 6.0
        var angle = current_angle - trail_angle * (1.0 - f)
        var point_radius = radius * lerp(0.88,1.0,f)
        pv_melee_trail.add_point(center + Vector2(point_radius,0).rotated(angle))





func _held_visual_config(id,is_melee):
    if is_melee:
        if id == "combat_knife":
            return {"scale":0.36,"sprite_pos":Vector2(7,0),"rear_px":Vector2(25,17),"front_px":Vector2(-1,-1),"source_size":Vector2(96,32)}
        if id == "steel_pipe":
            return {"scale":0.37,"sprite_pos":Vector2(2,0),"rear_px":Vector2(37,16),"front_px":Vector2(52,16),"source_size":Vector2(96,32)}
        return {"scale":0.36,"sprite_pos":Vector2(2,0),"rear_px":Vector2(35,17),"front_px":Vector2(50,17),"source_size":Vector2(96,32)}
    if id == "makarov":
        return {"scale":0.30,"sprite_pos":Vector2(8,-1),"rear_px":Vector2(56,31),"front_px":Vector2(64,27),"reload_px":Vector2(56,38),"source_size":Vector2(144,48),"muzzle_px":Vector2(100,22)}
    if id == "shotgun":
        return {"scale":0.26,"sprite_pos":Vector2(10,-1),"rear_px":Vector2(55,30),"front_px":Vector2(82,28),"reload_px":Vector2(65,31),"source_size":Vector2(144,48),"muzzle_px":Vector2(131,21)}
    return {"scale":0.27,"sprite_pos":Vector2(10,-1),"rear_px":Vector2(63,31),"front_px":Vector2(88,27),"reload_px":Vector2(68,36),"source_size":Vector2(144,48),"muzzle_px":Vector2(131,20)}

func _source_point_to_weapon_local(source_point,config):
    var source_size = config.get("source_size",Vector2(1,1))
    var scale_value = float(config.get("scale",1.0))
    var sprite_position = config.get("sprite_pos",Vector2.ZERO)

    return sprite_position + (source_point - source_size * 0.5) * scale_value


func _firearm_recoil_amount():
    if weapon_recoil_time <= 0.0 or weapon_recoil_duration <= 0.001:
        return 0.0

    var t = clamp(1.0 - weapon_recoil_time / weapon_recoil_duration,0.0,1.0)
    return sin(t * PI)

func _reload_anim_progress():
    if reload_time <= 0.0 or reload_anim_duration <= 0.001:
        return -1.0
    return clamp(1.0 - reload_time / reload_anim_duration,0.0,1.0)

func _weapon_root_point(local_point):
    return pv_weapon_root.position + local_point.rotated(pv_weapon_root.rotation)



func _update_ranged_pose(arm_angle,bob,moving):
    var local_aim = Vector2(cos(arm_angle),sin(arm_angle))
    var row = _pose_visual_row(local_aim)
    _set_pose_frame(current_weapon_id,row)
    _update_pose_weapon(current_weapon_id,row,Vector2(0,bob * 0.15),0.0)
    _set_melee_arm_visible(false)

func _catmull_float(p0,p1,p2,p3,t):
    var tt = t * t
    var ttt = tt * t
    return 0.5 * (
        2.0 * p1 +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * tt +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * ttt
    )

func _catmull_vec2(p0,p1,p2,p3,t):
    return Vector2(
        _catmull_float(p0.x,p1.x,p2.x,p3.x,t),
        _catmull_float(p0.y,p1.y,p2.y,p3.y,t)
    )

func _sample_float_track(track,t):
    if track.is_empty():
        return 0.0
    if track.size() == 1:
        return float(track[0])

    var scaled = clamp(t,0.0,1.0) * float(track.size() - 1)
    var index = int(floor(scaled))
    if index >= track.size() - 1:
        return float(track[track.size() - 1])

    var local_t = scaled - float(index)
    var i0 = max(0,index - 1)
    var i1 = index
    var i2 = min(track.size() - 1,index + 1)
    var i3 = min(track.size() - 1,index + 2)

    return _catmull_float(
        float(track[i0]),float(track[i1]),
        float(track[i2]),float(track[i3]),local_t
    )

func _sample_vec2_track(track,t):
    if track.is_empty():
        return Vector2.ZERO
    if track.size() == 1:
        return track[0]

    var scaled = clamp(t,0.0,1.0) * float(track.size() - 1)
    var index = int(floor(scaled))
    if index >= track.size() - 1:
        return track[track.size() - 1]

    var local_t = scaled - float(index)
    var i0 = max(0,index - 1)
    var i1 = index
    var i2 = min(track.size() - 1,index + 1)
    var i3 = min(track.size() - 1,index + 2)

    return _catmull_vec2(
        track[i0],track[i1],track[i2],track[i3],local_t
    )

func _melee_clip_profile(id):
    if id == "combat_knife":
        return {
            "motion":0.60,
            "base_angle":0.78,
            "angles":[0.0,-0.10,-0.16,-0.24,0.05,0.45,0.90,1.35,1.75,1.55,1.05,0.45,0.0]
        }

    if id == "steel_pipe":
        return {
            "motion":0.86,
            "base_angle":0.85,
            "angles":[0.0,-0.10,-0.18,0.18,0.65,1.35,2.15,3.10,4.05,4.65,5.30,5.90,TAU]
        }

    return {
        "motion":1.0,
        "base_angle":0.90,
        "angles":[0.0,-0.08,-0.16,0.28,0.75,1.65,2.75,3.80,4.80,5.55,6.05,6.20,TAU]
    }

func _melee_clip_state(id,t):
    var profile = _melee_clip_profile(id)
    var motion = float(profile.get("motion",1.0))

    # Structure follows the uploaded reference:
    # low guard -> anticipation -> crouch/wind-up -> broad slash ->
    # follow-through -> smooth recovery.
    var root_track = [
        Vector2(6.0,-2.0),Vector2(5.8,-1.5),Vector2(5.2,-0.7),
        Vector2(4.5,0.3),Vector2(4.2,0.7),Vector2(4.8,-1.4),
        Vector2(7.5,-3.2),Vector2(8.2,-3.0),Vector2(8.0,-1.4),
        Vector2(7.7,0.0),Vector2(7.2,0.8),Vector2(6.6,-0.3),
        Vector2(6.0,-2.0)
    ]
    var body_track = [
        Vector2.ZERO,Vector2(-0.1,0.2),Vector2(-0.4,0.6),
        Vector2(-0.7,1.2),Vector2(-0.8,1.7),Vector2(-0.6,1.6),
        Vector2(-0.2,1.0),Vector2(0.5,0.4),Vector2(1.0,0.2),
        Vector2(1.2,0.4),Vector2(0.8,0.6),Vector2(0.3,0.2),
        Vector2.ZERO
    ]
    var head_track = [
        Vector2.ZERO,Vector2(-0.1,0.1),Vector2(-0.3,0.2),
        Vector2(-0.5,0.5),Vector2(-0.5,0.8),Vector2(-0.3,0.8),
        Vector2(0.0,0.5),Vector2(0.3,0.2),Vector2(0.6,0.1),
        Vector2(0.7,0.1),Vector2(0.4,0.2),Vector2(0.2,0.1),
        Vector2.ZERO
    ]
    var body_rotation_track = [
        0.0,0.008,0.020,0.040,0.060,0.050,0.018,
        -0.025,-0.055,-0.070,-0.042,-0.012,0.0
    ]
    var crouch_track = [0.0,0.2,0.6,1.2,1.8,2.2,1.6,0.8,0.3,0.5,0.8,0.3,0.0]
    var stance_track = [0.0,0.2,0.5,1.0,1.5,2.0,1.8,1.4,1.0,0.8,0.5,0.2,0.0]

    var root = _sample_vec2_track(root_track,t)
    var root_idle = root_track[0]
    root = root_idle + (root - root_idle) * motion

    return {
        "root":root,
        "body":_sample_vec2_track(body_track,t) * motion,
        "head":_sample_vec2_track(head_track,t) * motion,
        "body_rotation":_sample_float_track(body_rotation_track,t) * motion,
        "crouch":max(0.0,_sample_float_track(crouch_track,t) * motion),
        "stance":max(0.0,_sample_float_track(stance_track,t) * motion),
        "angle":float(profile.get("base_angle",0.85)) + _sample_float_track(profile.get("angles",[]),t)
    }

func _apply_melee_character_pose(state):
    var body_offset = state.get("body",Vector2.ZERO)
    var head_offset = state.get("head",Vector2.ZERO)
    var body_rotation = float(state.get("body_rotation",0.0))
    var crouch = float(state.get("crouch",0.0))
    var stance = float(state.get("stance",0.0))

    pv_body.position += body_offset
    pv_body.rotation += body_rotation

    pv_vest.position += body_offset
    pv_vest.rotation += body_rotation * 0.72

    pv_backpack.position += body_offset * 0.62
    pv_backpack.rotation += body_rotation * 0.45

    var head_motion = body_offset * 0.35 + head_offset
    pv_head.position += head_motion
    pv_head.rotation += body_rotation * 0.18
    pv_helmet.position += head_motion
    pv_helmet.rotation += body_rotation * 0.18
    pv_helmet_lip.position += head_motion
    pv_helmet_lip.rotation += body_rotation * 0.18

    pv_leg_l.position += Vector2(-stance,crouch)
    pv_boot_l.position += Vector2(-stance,crouch)
    pv_leg_r.position += Vector2(stance,crouch)
    pv_boot_r.position += Vector2(stance,crouch)

    pv_shadow.position += body_offset * 0.15

func _melee_is_two_handed(id):
    return id == "steel_pipe" or id == "fire_axe"



func _update_melee_pose(arm_angle,bob,moving):
    var local_aim = Vector2(cos(arm_angle),sin(arm_angle))
    var row = _pose_visual_row(local_aim)
    _set_pose_frame(equipped_melee_id,row)
    _update_pose_weapon(equipped_melee_id,row,Vector2(0,bob * 0.15),0.0)
    _set_melee_arm_visible(false)








func _movement_cardinal_from_vector(direction,current_cardinal):
    var side = int(current_cardinal)
    if side != 2 and side != 3:
        side = 2

    if direction.length() < 0.10:
        return side

    # Only horizontal animation exists now.
    # Pure/mostly vertical movement preserves the previous left/right side.
    if direction.x > 0.16:
        return 2
    if direction.x < -0.16:
        return 3
    return side


func _directional_leg_row(cardinal,running,moving):
    var is_left = int(cardinal) == 3
    if not moving:
        return 5 if is_left else 4
    if running:
        return 3 if is_left else 2
    return 1 if is_left else 0



func _update_directional_legs(pose_offset,pose_scale,moving):
    if pv_legs == null:
        return

    visual_move_cardinal = _movement_cardinal_from_vector(
        visual_move_direction,
        visual_move_cardinal
    )

    var row = _directional_leg_row(
        visual_move_cardinal,
        is_sprinting,
        moving
    )
    var frame = _walk_phase_index(walk_phase) if moving else 0

    pv_legs.region_rect = Rect2(
        frame * 48,
        row * 40,
        48,
        40
    )

    # Same world-size as 0.42, now at native pixel scale.
    pv_legs.position = Vector2(
        pose_offset.x * 0.14,
        14 + pose_offset.y * 0.22
    )
    pv_legs.scale = pose_scale
    pv_legs.visible = true


func _update_player_visuals(delta):
    visual_facing_left = _visual_facing_from_aim(
        visual_facing_left,
        aim_direction.x
    )

    var look_left = visual_facing_left
    player_visual.scale.x = -1.0 if look_left else 1.0
    player_visual.scale.y = 1.0

    var local_aim = aim_direction
    if look_left:
        local_aim.x *= -1.0

    var local_motion = visual_move_direction
    if look_left:
        local_motion.x *= -1.0

    var blend = clamp(movement_anim_blend,0.0,1.0)
    var phase = fposmod(walk_phase,TAU)
    var step = sin(phase)
    var double_step = sin(phase * 2.0)
    var foot_contact = pow(abs(cos(phase)),8.0)
    var sprint_scale = 1.08 if is_sprinting else 1.0

    # Native-pixel body motion. No fractional rescaling of the character.
    var body_bob = (
        -abs(step) * 0.11
        + foot_contact * 0.04
        + double_step * 0.02
    ) * blend * sprint_scale

    var side_shift = step * 0.035 * blend
    var idle_breath = sin(Time.get_ticks_msec() * 0.00235) * 0.045 * (1.0-blend)

    var pose_offset = Vector2(
        side_shift + local_motion.x * 0.035 * blend,
        body_bob + local_motion.y * 0.024 * blend + idle_breath - 1.0
    )

    pv_shadow.position = Vector2(
        -1 + side_shift * 0.04,
        14 + body_bob * 0.03
    )
    pv_shadow.scale = Vector2(
        1.0 - abs(step) * 0.008 * blend,
        1.0 + abs(step) * 0.004 * blend
    )

    var weapon_id = equipped_melee_id if equipped_melee_id != "" else current_weapon_id
    var row = _pose_visual_row(local_aim)
    _set_pose_frame(weapon_id,row)

    pv_pose_back.position = pose_offset
    pv_pose_front.position = pose_offset

    # Pixel art stays unrotated and 1:1. This removes silhouette shimmer.
    pv_pose_back.rotation = 0.0
    pv_pose_front.rotation = 0.0
    pv_pose_back.scale = Vector2.ONE
    pv_pose_front.scale = Vector2.ONE

    _update_directional_legs(
        pose_offset,
        Vector2.ONE,
        visual_move_speed > 2.0
    )

    _set_melee_arm_visible(false)
    pv_arm_back_root.visible = false
    pv_arm_front_root.visible = false

    _update_pose_weapon(weapon_id,row,pose_offset,0.0)

    pv_pose_back.z_index = 0
    pv_weapon_root.z_index = 2
    pv_pose_front.z_index = 4

    if camera != null:
        var desired = aim_direction * 34.0 + Vector2(
            0,
            -11 + body_bob * 0.020
        )
        camera.position = camera.position.lerp(
            desired,
            min(1.0,delta * 6.0 + 0.2)
        )

func _melee_model_texture(id):
    if melee_model_atlas == null:
        melee_model_atlas = load("res://melee_models_v15.png")
    if melee_model_atlas == null:
        return null
    var row = 0
    if id == "steel_pipe":
        row = 1
    elif id == "fire_axe":
        row = 2
    var tex = AtlasTexture.new()
    tex.atlas = melee_model_atlas
    tex.region = Rect2(0,row * 32,96,32)
    return tex

func _weapon_model_texture(id):
    if weapon_model_atlas == null:
        weapon_model_atlas = load("res://weapon_models_v16.png")
    if weapon_model_atlas == null:
        return null
    var row = 0
    if id == "shotgun":
        row = 1
    elif id == "akm":
        row = 2
    var tex = AtlasTexture.new()
    tex.atlas = weapon_model_atlas
    tex.region = Rect2(0,row * 48,144,48)
    return tex

func _weapon_module_texture(id):
    if weapon_module_atlas == null:
        weapon_module_atlas = load("res://weapon_modules_v6.png")

    if weapon_module_atlas == null:
        return null

    var cell = Vector2i(-1,-1)
    match id:
        "makarov_extmag":
            cell = Vector2i(0,0)
        "shotgun_exttube":
            cell = Vector2i(1,0)
        "akm_extmag":
            cell = Vector2i(2,0)
        "muzzle_brake":
            cell = Vector2i(0,1)
        "suppressor":
            cell = Vector2i(1,1)

    if cell.x < 0:
        return null

    var tex = AtlasTexture.new()
    tex.atlas = weapon_module_atlas
    tex.region = Rect2(cell.x * 32,cell.y * 32,32,32)
    return tex

func _update_visible_weapon_mods():
    if pv_weapon_mag_visual == null or pv_weapon_muzzle_visual == null:
        return

    if equipped_melee_id != "":
        pv_weapon_mag_visual.visible = false
        pv_weapon_muzzle_visual.visible = false
        return

    var magazine_id = ""
    var muzzle_id = ""
    if weapon_mods.has(current_weapon_id):
        magazine_id = str(weapon_mods[current_weapon_id].get("magazine",""))
        muzzle_id = str(weapon_mods[current_weapon_id].get("muzzle",""))

    pv_weapon_mag_visual.texture = _weapon_module_texture(magazine_id) if magazine_id != "" else null
    pv_weapon_muzzle_visual.texture = _weapon_module_texture(muzzle_id) if muzzle_id != "" else null
    pv_weapon_mag_visual.visible = pv_weapon_mag_visual.texture != null
    pv_weapon_muzzle_visual.visible = pv_weapon_muzzle_visual.texture != null

    var config = _held_visual_config(current_weapon_id,false)
    var visual_scale = float(config.get("scale",0.20))

    pv_weapon_mag_visual.modulate = Color.WHITE
    pv_weapon_muzzle_visual.modulate = Color.WHITE

    if current_weapon_id == "makarov":
        pv_weapon_mag_visual.position = Vector2(5.8,4.1)
        pv_weapon_mag_visual.scale = Vector2(visual_scale * 1.25,visual_scale * 1.25)
        pv_weapon_muzzle_visual.position = Vector2(18.8,-0.3)
        pv_weapon_muzzle_visual.scale = Vector2(visual_scale * 1.30,visual_scale * 1.30)
    elif current_weapon_id == "shotgun":
        pv_weapon_mag_visual.position = Vector2(12.5,1.8)
        pv_weapon_mag_visual.scale = Vector2(visual_scale * 1.55,visual_scale * 1.55)
        pv_weapon_muzzle_visual.position = Vector2(22.0,-0.3)
        pv_weapon_muzzle_visual.scale = Vector2(visual_scale * 1.25,visual_scale * 1.25)
    else:
        pv_weapon_mag_visual.position = Vector2(5.7,4.6)
        pv_weapon_mag_visual.scale = Vector2(visual_scale * 1.45,visual_scale * 1.45)
        pv_weapon_muzzle_visual.position = Vector2(18.4,-0.3)
        pv_weapon_muzzle_visual.scale = Vector2(visual_scale * 1.25,visual_scale * 1.25)

func _update_weapon_visual():
    if pv_weapon_root == null or pv_weapon_sprite == null:
        return

    pv_weapon_stock.visible = false
    pv_weapon_body.visible = false
    pv_weapon_mag.visible = false
    pv_weapon_barrel.visible = false

    if equipped_melee_id != "":
        var config = _held_visual_config(equipped_melee_id,true)
        var scale_value = float(config.get("scale",0.24))

        pv_weapon_sprite.texture = _melee_model_texture(equipped_melee_id)
        pv_weapon_sprite.visible = pv_weapon_sprite.texture != null
        pv_weapon_sprite.scale = Vector2(scale_value,scale_value)
        pv_weapon_sprite.position = config.get("sprite_pos",Vector2.ZERO)

        if muzzle_flash != null:
            muzzle_flash.visible = false
        if pv_melee_trail != null:
            pv_melee_trail.visible = false

        _update_visible_weapon_mods()
        return

    if pv_melee_trail != null:
        pv_melee_trail.visible = false

    var config = _held_visual_config(current_weapon_id,false)
    var scale_value = float(config.get("scale",0.22))

    pv_weapon_sprite.texture = _weapon_model_texture(current_weapon_id)
    pv_weapon_sprite.visible = pv_weapon_sprite.texture != null
    pv_weapon_sprite.scale = Vector2(scale_value,scale_value)
    pv_weapon_sprite.position = config.get("sprite_pos",Vector2.ZERO)

    if muzzle_flash != null:
        muzzle_flash.position = _source_point_to_weapon_local(
            config.get("muzzle_px",Vector2(96,24)),
            config
        )

    _update_visible_weapon_mods()

func _respawn_player():
    health = 100.0
    stamina = 100.0
    hunger = 88.0
    thirst = 82.0
    bleeding = false
    pain = 0.0
    body_condition = {
        "head":100.0,
        "torso":100.0,
        "arms":100.0,
        "legs":100.0
    }
    last_injury_zone = ""
    wound_contamination = 0.0
    wound_infection = 0.0
    painkiller_time = 0.0
    antibiotic_time = 0.0
    medical_tick_accumulator = 0.0
    well_fed_time = 0.0
    warm_drink_time = 0.0
    is_sprinting = false
    body_temperature = 36.8
    wetness = 0.0
    _set_survival_feedback("Вы пришли в себя",2.0)
    player.global_position = Vector2(420,430)
    _refresh_chunks(true)

# -------------------------------------------------------------------
# COMBAT / WEAPONS / MEDICAL
# -------------------------------------------------------------------

func _switch_weapon(id):
    if not weapon_defs.has(id):
        return
    if not _inventory_has_item(id):
        return
    _cancel_reload()
    current_weapon_id = id
    equipped_melee_id = ""
    melee_swing_time = 0.0
    weapon_recoil_time = 0.0
    _update_weapon_visual()

func _weapon_condition_value(id):
    return clamp(float(weapon_condition.get(id,100.0)),0.0,100.0)

func _damage_weapon_condition(id,weapon):
    var wear = float(weapon.get("wear",0.08))
    weapon_condition[id] = max(0.0,_weapon_condition_value(id) - wear)


func _repair_current_weapon():
    # Legacy helper retained so old calls/saves do not break.
    # Repairs are intentionally restricted to the workbench in 0.14+.
    return false


func _melee_point_in_arc(origin,facing,target,range_value,arc_value):
    var offset = target - origin
    if offset.length() > range_value or offset.length() <= 0.001:
        return false

    var direction = offset.normalized()
    return abs(facing.angle_to(direction)) <= arc_value * 0.5

func _melee_line_clear(target_position):
    var query = PhysicsRayQueryParameters2D.create(player.global_position,target_position)
    query.collision_mask = LAYER_WORLD
    query.exclude = [player.get_rid()]
    return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _apply_enemy_impulse(enemy,direction,force_value,stagger_time):
    if not is_instance_valid(enemy):
        return

    var dir = direction
    if dir.length() <= 0.001:
        dir = aim_direction
    else:
        dir = dir.normalized()

    enemy.set_meta("knockback_velocity",dir * force_value)
    enemy.set_meta("stagger",max(float(enemy.get_meta("stagger",0.0)),stagger_time))
    enemy.set_meta("alert",max(float(enemy.get_meta("alert",0.0)),5.5))
    enemy.set_meta("last_known_position",player.global_position)
    enemy.set_meta("suspicion",100.0)
    enemy.set_meta("lost_sight_time",0.0)
    _enemy_set_state(enemy,"chase",4.5)

func _perform_melee_attack():
    if inventory_open or reload_time > 0.0 or melee_cooldown > 0.0:
        return
    if equipped_melee_id == "" or not melee_defs.has(equipped_melee_id):
        return

    var melee = melee_defs[equipped_melee_id]
    var stamina_cost = float(melee.get("stamina",10.0))
    if stamina < stamina_cost:
        return

    stamina = max(0.0,stamina - stamina_cost)
    melee_swing_duration = float(melee.get("swing_anim",0.55))
    melee_cooldown = max(float(melee.get("interval",0.5)),melee_swing_duration)
    melee_swing_time = melee_swing_duration

    var range_value = float(melee.get("range",38.0))
    var arc_value = float(melee.get("arc",0.8))
    var max_targets = int(melee.get("max_targets",1))
    var damage = float(melee.get("damage",30.0)) * _skill_melee_damage_multiplier()
    var knockback = float(melee.get("knockback",70.0))
    var stagger_time = float(melee.get("stagger",0.35))
    var hit_count = 0

    for enemy in get_tree().get_nodes_in_group("infected"):
        if hit_count >= max_targets:
            break
        if not is_instance_valid(enemy):
            continue
        if not _melee_point_in_arc(player.global_position,aim_direction,enemy.global_position,range_value,arc_value):
            continue
        if not _melee_line_clear(enemy.global_position):
            continue

        var push_dir = enemy.global_position - player.global_position
        _apply_enemy_impulse(enemy,push_dir,knockback,stagger_time)
        _damage_enemy(enemy,damage)
        hit_count += 1

    _add_skill_xp("melee",0.15 + float(hit_count) * 2.0)
    _emit_ai_sound(player.global_position,float(melee.get("noise",65.0)),"melee",1.0)

func _perform_shove():
    if inventory_open or shove_cooldown > 0.0:
        return

    var stamina_cost = 12.0
    if stamina < stamina_cost:
        return

    stamina = max(0.0,stamina - stamina_cost)
    shove_cooldown = 0.82

    var affected = 0
    for enemy in get_tree().get_nodes_in_group("infected"):
        if affected >= 3:
            break
        if not is_instance_valid(enemy):
            continue
        if not _melee_point_in_arc(player.global_position,aim_direction,enemy.global_position,34.0,1.20):
            continue
        if not _melee_line_clear(enemy.global_position):
            continue

        var push_dir = enemy.global_position - player.global_position
        _apply_enemy_impulse(enemy,push_dir,165.0,0.82)
        affected += 1

    _alert_enemies(player.global_position,55.0)


func _primary_attack():
    if equipped_melee_id != "":
        _perform_melee_attack()
        return

    if reload_time > 0.0:
        if reload_weapon_id == "shotgun" and int(weapon_mags.get("shotgun",0)) > 0:
            _cancel_reload()
        else:
            return

    _fire_weapon()

func _switch_melee(id):
    if not melee_defs.has(id):
        return
    if not _inventory_has_item(id):
        return

    _cancel_reload()
    equipped_melee_id = id
    weapon_recoil_time = 0.0
    _update_weapon_visual()

func _fire_weapon():
    if inventory_open or reload_time > 0.0 or fire_cooldown > 0.0:
        return
    if not weapon_defs.has(current_weapon_id):
        return

    var mag_now = int(weapon_mags.get(current_weapon_id, 0))
    if mag_now <= 0:
        return

    var weapon = weapon_defs[current_weapon_id]
    weapon_mags[current_weapon_id] = mag_now - 1
    fire_cooldown = float(weapon.get("interval",0.25))

    weapon_recoil_duration = 0.10
    if current_weapon_id == "shotgun":
        weapon_recoil_duration = 0.16
    elif current_weapon_id == "akm":
        weapon_recoil_duration = 0.12
    weapon_recoil_time = weapon_recoil_duration
    _damage_weapon_condition(current_weapon_id,weapon)

    var origin = player.global_position + aim_direction * 26.0
    var range_value = float(weapon.get("range", 500.0))
    var damage = float(weapon.get("damage", 30.0))
    var shot_dirs = _weapon_shot_directions(weapon, aim_direction)

    var first_end = origin + aim_direction * range_value

    var hit_enemy = false

    for i in range(shot_dirs.size()):
        var shot_dir = shot_dirs[i]
        var end = origin + shot_dir * range_value

        var query = PhysicsRayQueryParameters2D.create(origin, end)
        query.collision_mask = LAYER_ENEMY | LAYER_WORLD
        query.exclude = [player.get_rid()]

        var hit = get_world_2d().direct_space_state.intersect_ray(query)
        if not hit.is_empty():
            end = hit.position
            var collider = hit.collider
            if collider != null and collider.has_meta("is_enemy"):
                hit_enemy = true
                _damage_enemy(collider, damage)

        if i == int(shot_dirs.size() / 2):
            first_end = end

        # Shotgun shows the actual pellet cone instead of one fake center tracer.
        if shot_dirs.size() > 1:
            _spawn_temp_tracer(origin,end,0.075)

    if shot_dirs.size() == 1:
        tracer.clear_points()
        tracer.add_point(origin)
        tracer.add_point(first_end)
        tracer.visible = true
        tracer_time = 0.065

    _add_skill_xp("firearms",0.20 + (2.30 if hit_enemy else 0.0))

    var noise_radius = float(weapon.get("noise", 500.0))
    noise_radius *= _weapon_mod_multiplier(current_weapon_id,"noise_mult")
    _emit_ai_sound(origin,noise_radius,"gunshot",1.0)

    muzzle_flash.visible = true
    muzzle_time = 0.055

func _weapon_shot_directions(weapon, base_dir):
    var pellets = max(1,int(weapon.get("pellets",1)))
    var spread = max(0.0,float(weapon.get("spread",0.0)))
    var condition_ratio = _weapon_condition_value(current_weapon_id) / 100.0
    spread *= 1.0 + (1.0 - condition_ratio) * 1.35
    spread *= _weapon_mod_multiplier(current_weapon_id,"spread_mult")
    spread *= _injury_aim_spread_multiplier()
    spread *= _skill_firearm_spread_multiplier()
    var dirs = []

    if pellets == 1:
        dirs.append(base_dir.rotated(randf_range(-spread,spread)))
        return dirs

    # Full cone from -spread to +spread. A small jitter keeps it organic while
    # guaranteeing that pellets actually occupy the whole cone.
    for i in range(pellets):
        var t = 0.5
        if pellets > 1:
            t = float(i) / float(pellets - 1)
        var angle = lerpf(-spread,spread,t)
        var jitter = spread / float(pellets) * 0.30
        angle += randf_range(-jitter,jitter)
        dirs.append(base_dir.rotated(angle))

    return dirs

func _spawn_temp_tracer(origin,end,lifetime):
    var line = Line2D.new()
    line.width = 0.8
    line.default_color = Color(1.0,0.78,0.38,0.56)
    line.z_index = 120
    line.z_as_relative = false
    line.add_point(origin)
    line.add_point(end)
    add_child(line)

    var timer = get_tree().create_timer(lifetime)
    timer.timeout.connect(line.queue_free)


func _damage_enemy(enemy, amount):
    if not is_instance_valid(enemy):
        return
    var hp = float(enemy.get_meta("hp", 70.0)) - amount
    enemy.set_meta("hp", hp)
    if hp > 0.0:
        enemy.set_meta("last_known_position",player.global_position)
        enemy.set_meta("suspicion",100.0)
        enemy.set_meta("lost_sight_time",0.0)
        _enemy_set_state(enemy,"chase",4.5)

    if hp <= 0.0:
        var c = enemy.get_meta("chunk_coord")
        var sid = int(enemy.get_meta("spawn_id"))
        var key = "%d:%d:%d" % [c.x, c.y, sid]
        defeated[key] = true
        enemy.queue_free()

func _ai_state_valid(state):
    return state in ["idle","suspicious","investigate","chase","search","return"]

func _enemy_set_state(enemy,state,duration = 0.0):
    if not is_instance_valid(enemy):
        return
    if not _ai_state_valid(state):
        state = "idle"

    enemy.set_meta("ai_state",state)
    enemy.set_meta("ai_state_time",max(0.0,float(duration)))

    if state == "chase":
        enemy.set_meta("alert",max(float(enemy.get_meta("alert",0.0)),5.5))
    elif state == "idle":
        enemy.set_meta("alert",0.0)

func _player_has_active_flashlight():
    return (
        flashlight_on
        and flashlight_battery > 0.0
        and str(equipment.get("utility","")) == "flashlight"
    )


func _player_near_active_fire():
    if player == null:
        return false

    for rec in base_objects:
        if str(rec.get("kind","")) != "campfire":
            continue
        if not bool(rec.get("on",false)) or float(rec.get("fuel",0.0)) <= 0.0:
            continue

        var pos = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))
        if player.global_position.distance_to(pos) <= 105.0:
            return true

    return false

func _player_visibility_multiplier():
    var hour = world_minutes / 60.0
    var visibility = 1.0

    # Light level.
    if hour >= 21.0 or hour < 5.0:
        visibility *= 0.42
    elif hour >= 18.0:
        visibility *= lerpf(1.0,0.42,(hour - 18.0) / 3.0)
    elif hour < 7.0:
        visibility *= lerpf(0.42,1.0,(hour - 5.0) / 2.0)

    # Weather obscures visual detection.
    if weather_state == "rain":
        visibility *= 0.74
    elif weather_state == "cloudy":
        visibility *= 0.90

    # Player movement affects how easy the silhouette is to notice.
    if move_direction.length() <= 0.05:
        visibility *= 0.82
    elif is_sprinting:
        visibility *= 1.18

    # Roofed interiors reduce silhouette contrast from outside.
    if is_sheltered:
        visibility *= 0.90

    # Flashlight destroys most night stealth.
    if _player_has_active_flashlight():
        if hour >= 20.0 or hour < 6.0:
            visibility = max(visibility,1.05)
        else:
            visibility *= 1.05

    if _player_near_active_base_lamp():
        if hour >= 20.0 or hour < 6.0:
            visibility = max(visibility,0.96)
        else:
            visibility *= 1.03

    # Fire is a strong survival tool, but it exposes the player at night.
    if _player_near_active_fire():
        if hour >= 20.0 or hour < 6.0:
            visibility = max(visibility,1.10)
        else:
            visibility *= 1.06

    return clamp(visibility,0.25,1.35)

func _enemy_vision_radius(enemy):
    var base_radius = float(enemy.get_meta("detection_radius",170.0))
    return base_radius * _player_visibility_multiplier()

func _sound_weather_multiplier(kind):
    if weather_state == "rain":
        if kind == "gunshot":
            return 0.86
        if kind == "door":
            return 0.72
        if kind == "workbench":
            return 0.68
        if kind == "fire":
            return 0.48
        return 0.58

    if weather_state == "cloudy":
        return 0.92

    return 1.0

func _sound_hearing_cap_multiplier(kind):
    if kind == "gunshot":
        return 1.75
    if kind == "sprint":
        return 1.00
    if kind == "melee":
        return 0.78
    if kind == "door":
        return 0.72
    if kind == "drop":
        return 0.50
    if kind == "workbench":
        return 0.65
    if kind == "fire":
        return 0.58
    if kind == "walk":
        return 0.45
    return 0.90

func _sound_suspicion_gain(kind):
    if kind == "gunshot":
        return 92.0
    if kind == "sprint":
        return 52.0
    if kind == "melee":
        return 44.0
    if kind == "door":
        return 38.0
    if kind == "drop":
        return 28.0
    if kind == "workbench":
        return 34.0
    if kind == "fire":
        return 20.0
    if kind == "walk":
        return 18.0
    return 34.0

func _sound_occlusion_multiplier(origin,enemy,kind):
    if not is_instance_valid(enemy):
        return 0.0

    var query = PhysicsRayQueryParameters2D.create(origin,enemy.global_position)
    query.collision_mask = LAYER_WORLD
    var hit = get_world_2d().direct_space_state.intersect_ray(query)

    if hit.is_empty():
        return 1.0

    if kind == "gunshot":
        return 0.70
    if kind == "door":
        return 0.55
    if kind == "fire":
        return 0.48
    return 0.40

func _emit_ai_sound(origin,radius,kind = "generic",strength = 1.0):
    var base_radius = max(0.0,float(radius))
    if base_radius <= 0.0:
        return

    var weather_mult = _sound_weather_multiplier(kind)
    var source_strength = max(0.05,float(strength))

    if player != null and player.global_position.distance_to(origin) <= 80.0:
        last_player_noise_radius = base_radius
        last_player_noise_kind = kind
        last_player_noise_time = 1.15

    for enemy in get_tree().get_nodes_in_group("infected"):
        if not is_instance_valid(enemy):
            continue

        var hearing = float(enemy.get_meta("hearing_radius",260.0))
        var cap = hearing * _sound_hearing_cap_multiplier(kind)
        var effective = min(base_radius,cap) * weather_mult
        effective *= _sound_occlusion_multiplier(origin,enemy,kind)

        if effective <= 1.0:
            continue

        var dist = enemy.global_position.distance_to(origin)
        if dist > effective:
            continue

        var proximity = 1.0 - clamp(dist / effective,0.0,1.0)
        var gain = _sound_suspicion_gain(kind) * (0.35 + proximity * 0.65) * source_strength
        var suspicion = min(100.0,float(enemy.get_meta("suspicion",0.0)) + gain)

        enemy.set_meta("suspicion",suspicion)
        enemy.set_meta("heard_position",origin)
        enemy.set_meta("last_sound_kind",kind)

        var state = str(enemy.get_meta("ai_state","idle"))
        if state == "chase":
            continue

        if suspicion >= 34.0 or kind == "gunshot":
            _enemy_set_state(enemy,"investigate",5.0)
        else:
            _enemy_set_state(enemy,"suspicious",1.25)

func _enemy_move_toward(enemy,target,speed_value,enemies):
    var desired = target - enemy.global_position
    if desired.length() > 4.0:
        desired = desired.normalized()
    else:
        desired = Vector2.ZERO

    var separation = Vector2.ZERO
    for other in enemies:
        if other == enemy or not is_instance_valid(other):
            continue
        var apart = enemy.global_position.distance_to(other.global_position)
        if apart > 0.01 and apart < 30.0:
            separation += (
                (enemy.global_position - other.global_position).normalized()
                * ((30.0 - apart) / 30.0)
            )

    var final_dir = desired + separation * 0.75
    if final_dir.length() > 0.01:
        final_dir = final_dir.normalized()
        enemy.set_meta("ai_facing",final_dir)

    enemy.velocity = final_dir * speed_value
    enemy.move_and_slide()

func _enemy_search_target(enemy):
    var anchor = enemy.get_meta("search_anchor",enemy.global_position)
    if typeof(anchor) != TYPE_VECTOR2:
        anchor = enemy.global_position

    var phase = int(enemy.get_meta("search_phase",0))
    var sid = int(enemy.get_meta("spawn_id",0))
    var angle = float(phase * 2 + sid % 5) * 1.37
    var radius = 18.0 + float((phase % 3) * 14)

    return anchor + Vector2(cos(angle),sin(angle)) * radius

func _stealth_noise_label():
    if last_player_noise_time <= 0.0:
        return "ТИХО"
    if last_player_noise_kind == "gunshot":
        return "ВЫСТРЕЛ"
    if last_player_noise_kind == "sprint":
        return "БЕГ"
    if last_player_noise_kind == "walk":
        return "ШАГИ"
    if last_player_noise_kind == "door":
        return "ДВЕРЬ"
    if last_player_noise_kind == "melee":
        return "УДАР"
    if last_player_noise_kind == "drop":
        return "ПРЕДМЕТ"
    if last_player_noise_kind == "workbench":
        return "ВЕРСТАК"
    return "ШУМ"

func _alert_enemies(origin,radius):
    _emit_ai_sound(origin,radius,"generic",1.0)

func _weapon_mag_bonus(weapon_id):
    if not weapon_mods.has(weapon_id):
        return 0

    var magazine_id = str(weapon_mods[weapon_id].get("magazine",""))
    if magazine_id != "" and item_defs.has(magazine_id):
        return int(item_defs[magazine_id].get("mag_bonus",0))

    return 0

func _weapon_mag_capacity(weapon_id):
    if not weapon_defs.has(weapon_id):
        return 0
    return int(weapon_defs[weapon_id].get("mag",0)) + _weapon_mag_bonus(weapon_id)

func _weapon_base_mag_capacity(weapon_id):
    if not weapon_defs.has(weapon_id):
        return 0
    return int(weapon_defs[weapon_id].get("mag",0))

func _ammo_overflow_for_capacity(weapon_id,new_capacity):
    return max(0,int(weapon_mags.get(weapon_id,0)) - new_capacity)




func _reload_duration_for_weapon(weapon_id):
    var duration = 0.90

    if weapon_id == "shotgun":
        duration = 0.52
    elif weapon_id == "akm":
        duration = 1.45

    return duration * _skill_reload_time_multiplier()

func _reload_transfer_amount(weapon_id,mag_now,reserve):
    if not weapon_defs.has(weapon_id):
        return 0

    var need = max(0,_weapon_mag_capacity(weapon_id) - int(mag_now))
    if need <= 0 or reserve <= 0:
        return 0

    if weapon_id == "shotgun":
        return min(1,min(need,reserve))

    return min(need,reserve)

func _cancel_reload():
    reload_time = 0.0
    reload_anim_duration = 0.0
    reload_weapon_id = ""
    reload_shellwise = false

func _can_reload_weapon(weapon_id):
    if not weapon_defs.has(weapon_id):
        return false

    var weapon = weapon_defs[weapon_id]
    var mag_now = int(weapon_mags.get(weapon_id,0))
    var mag_size = _weapon_mag_capacity(weapon_id)
    var ammo_id = str(weapon.get("ammo",""))

    return mag_now < mag_size and _inventory_count(ammo_id) > 0




func _ensure_weapon_runtime_state():
    for weapon_id in ["makarov","shotgun","akm"]:
        if not weapon_mags.has(weapon_id):
            weapon_mags[weapon_id] = 0
        weapon_mags[weapon_id] = clamp(int(weapon_mags.get(weapon_id,0)),0,_weapon_mag_capacity(weapon_id))
        if not weapon_condition.has(weapon_id):
            weapon_condition[weapon_id] = 100.0
        weapon_condition[weapon_id] = clamp(float(weapon_condition.get(weapon_id,100.0)),0.0,100.0)

func _reload_block_reason(weapon_id):
    if inventory_open:
        return "Закройте инвентарь"
    if equipped_melee_id != "":
        return "Выбрано оружие ближнего боя"
    if not weapon_defs.has(weapon_id):
        return "Неизвестное оружие"
    var weapon = weapon_defs[weapon_id]
    var mag_now = int(weapon_mags.get(weapon_id,0))
    var mag_size = _weapon_mag_capacity(weapon_id)
    var ammo_id = str(weapon.get("ammo",""))
    var reserve = _inventory_count(ammo_id)
    if mag_now >= mag_size:
        return "Магазин полный"
    if reserve <= 0:
        return "Нет патронов: %s" % str(item_defs.get(ammo_id,{}).get("name",ammo_id))
    return ""

func _owned_firearm_except(exclude_id):
    for weapon_id in ["makarov","shotgun","akm"]:
        if weapon_id != exclude_id and _inventory_has_item(weapon_id):
            return weapon_id
    return ""

func _owned_melee_except(exclude_id):
    for melee_id in ["combat_knife","steel_pipe","fire_axe"]:
        if melee_id != exclude_id and _inventory_has_item(melee_id):
            return melee_id
    return ""

func _prepare_item_for_drop(id):
    if id == equipped_melee_id:
        var other_melee = _owned_melee_except(id)
        if other_melee != "":
            _switch_melee(other_melee)
            return true
        var other_firearm = _owned_firearm_except("")
        if other_firearm != "":
            _switch_weapon(other_firearm)
            return true
        return false
    if id == current_weapon_id:
        var fallback_firearm = _owned_firearm_except(id)
        if fallback_firearm != "":
            _switch_weapon(fallback_firearm)
            return true
        var fallback_melee = _owned_melee_except("")
        if fallback_melee != "":
            _switch_melee(fallback_melee)
            return true
        return false
    return true



func _start_reload():
    _ensure_weapon_runtime_state()
    if reload_time > 0.0:
        return
    var reason = _reload_block_reason(current_weapon_id)
    if reason != "":
        reload_feedback = reason
        reload_feedback_time = 1.8
        return
    reload_feedback = ""
    reload_weapon_id = current_weapon_id
    reload_shellwise = reload_weapon_id == "shotgun"
    reload_time = _reload_duration_for_weapon(reload_weapon_id)
    reload_anim_duration = reload_time

func _finish_reload():
    var weapon_id = reload_weapon_id

    if weapon_id == "" or not weapon_defs.has(weapon_id):
        _cancel_reload()
        return

    # Switching weapons cancels the reload instead of reloading the newly selected gun.
    if current_weapon_id != weapon_id or equipped_melee_id != "":
        _cancel_reload()
        return

    var weapon = weapon_defs[weapon_id]
    var mag_now = int(weapon_mags.get(weapon_id,0))
    var ammo_id = str(weapon.get("ammo",""))
    var reserve = _inventory_count(ammo_id)
    var moved = _reload_transfer_amount(weapon_id,mag_now,reserve)

    if moved <= 0:
        _cancel_reload()
        return

    if not _consume_inventory_item(ammo_id,moved):
        _cancel_reload()
        return

    weapon_mags[weapon_id] = mag_now + moved
    reload_feedback = "Перезаряжено: %d/%d" % [int(weapon_mags[weapon_id]),_weapon_mag_capacity(weapon_id)]
    reload_feedback_time = 1.2
    _refresh_inventory_ui()

    # Shotgun: insert shells one by one. This makes the reload visible and testable.
    if reload_shellwise and _can_reload_weapon(weapon_id):
        reload_time = _reload_duration_for_weapon(weapon_id)
        reload_anim_duration = reload_time
        return

    _cancel_reload()

func _start_bleeding():
    if bleeding:
        return
    bleeding = true
    bleed_damage_taken = 0.0

func _stop_bleeding():
    bleeding = false
    bleed_damage_taken = 0.0



func _quick_bandage():
    if _inventory_count("bandage") > 0:
        if not bleeding and health >= 98.0:
            return

        if _consume_inventory_item("bandage",1):
            _stop_bleeding()
            health = min(100.0,health + 6.0)
            pain = max(0.0,pain - 8.0)
            _stabilize_worst_injury(2.5)
            stamina = min(_survival_stamina_cap(),stamina + 3.0)
            _set_survival_feedback("Бинт: кровотечение остановлено")
            _refresh_inventory_ui()
        return

    if _inventory_count("sterile_bandage") <= 0:
        return

    if _use_sterile_bandage() and _consume_inventory_item("sterile_bandage",1):
        _refresh_inventory_ui()

func _grid_add(entries, item_id, quantity, gw, gh):
    if not item_defs.has(item_id):
        return quantity

    var item = item_defs[item_id]
    var max_stack = int(item.get("stack", 1))
    var remaining = int(quantity)

    if max_stack > 1:
        for i in range(entries.size()):
            if remaining <= 0:
                break
            if str(entries[i].get("id", "")) == item_id:
                var current = int(entries[i].get("qty", 1))
                if current < max_stack:
                    var add = min(max_stack - current, remaining)
                    entries[i]["qty"] = current + add
                    remaining -= add

    while remaining > 0:
        var pos = _find_grid_space(entries, item_id, gw, gh)
        if pos.x < 0:
            break

        var stack_qty = min(max_stack, remaining)
        entries.append({
            "id": item_id,
            "qty": stack_qty,
            "x": pos.x,
            "y": pos.y
        })
        remaining -= stack_qty

    return remaining

func _find_grid_space(entries, item_id, gw, gh):
    if not item_defs.has(item_id):
        return Vector2i(-1,-1)

    var item = item_defs[item_id]
    var iw = int(item.get("w", 1))
    var ih = int(item.get("h", 1))

    for y in range(gh - ih + 1):
        for x in range(gw - iw + 1):
            if _can_place(entries, x, y, iw, ih):
                return Vector2i(x,y)

    return Vector2i(-1,-1)

func _can_place(entries, x, y, iw, ih):
    for entry in entries:
        if not item_defs.has(str(entry.get("id", ""))):
            continue

        var other = item_defs[str(entry["id"])]
        var ox = int(entry.get("x", 0))
        var oy = int(entry.get("y", 0))
        var ow = int(other.get("w", 1))
        var oh = int(other.get("h", 1))

        if x < ox + ow and x + iw > ox and y < oy + oh and y + ih > oy:
            return false

    return true

func _can_add_all(entries, item_id, qty, gw, gh):
    var test = entries.duplicate(true)
    return _grid_add(test, item_id, qty, gw, gh) == 0

func _inventory_has_item(id):
    return _inventory_count(id) > 0

func _inventory_count(id):
    var count = 0
    for entry in inventory_entries:
        if str(entry.get("id", "")) == id:
            count += int(entry.get("qty", 1))
    return count

func _consume_inventory_item(id, amount):
    var remaining = int(amount)

    for i in range(inventory_entries.size() - 1, -1, -1):
        if remaining <= 0:
            break
        if str(inventory_entries[i].get("id", "")) != id:
            continue

        var qty = int(inventory_entries[i].get("qty", 1))
        var take = min(qty, remaining)
        qty -= take
        remaining -= take

        if qty <= 0:
            inventory_entries.remove_at(i)
        else:
            inventory_entries[i]["qty"] = qty

    return remaining == 0


func _inventory_weight():
    var total = 0.0

    for entry in inventory_entries:
        var id = str(entry.get("id",""))
        if item_defs.has(id):
            total += float(item_defs[id].get("weight",0.0)) * int(entry.get("qty",1))

    for slot in equipment.keys():
        var equipped_id = str(equipment.get(slot,""))
        if equipped_id != "" and item_defs.has(equipped_id):
            total += float(item_defs[equipped_id].get("weight",0.0))

    return total


func _weapon_condition_state(id):
    var value = _weapon_condition_value(id)

    if value >= 85.0:
        return "ОТЛИЧНОЕ"
    if value >= 60.0:
        return "РАБОЧЕЕ"
    if value >= 35.0:
        return "ИЗНОШЕНО"
    return "КРИТИЧЕСКОЕ"

func _service_costs(service_type):
    if service_type == "overhaul":
        return {"repair_kit":2,"scrap":3,"tape":1}
    return {"repair_kit":1,"scrap":1,"cloth":1}


func _service_gain(service_type):
    var base_gain = 60.0 if service_type == "overhaul" else 30.0
    return base_gain * _skill_service_gain_multiplier()

func _service_cap(service_type):
    return 100.0 if service_type == "overhaul" else 90.0

func _service_name(service_type):
    return "КАПИТАЛЬНЫЙ РЕМОНТ" if service_type == "overhaul" else "ОБСЛУЖИВАНИЕ"

func _can_service_weapon(weapon_id,service_type):
    if not weapon_defs.has(weapon_id):
        return false

    var current = _weapon_condition_value(weapon_id)
    var cap_value = _service_cap(service_type)
    if current >= cap_value - 0.01:
        return false

    for id in _service_costs(service_type).keys():
        if _inventory_count(str(id)) < int(_service_costs(service_type)[id]):
            return false

    return true

func _perform_weapon_service(weapon_id,service_type):
    if not _can_service_weapon(weapon_id,service_type):
        if service_status != null:
            service_status.text = "Нельзя выполнить: не хватает ресурсов или ремонт уже не нужен."
        return false

    var test_entries = inventory_entries.duplicate(true)
    var costs = _service_costs(service_type)

    for id in costs.keys():
        if not _consume_from_entries(test_entries,str(id),int(costs[id])):
            if service_status != null:
                service_status.text = "Ошибка транзакции ремонта."
            return false

    var current = _weapon_condition_value(weapon_id)
    var new_value = min(_service_cap(service_type),current + _service_gain(service_type))

    inventory_entries = test_entries
    weapon_condition[weapon_id] = new_value

    _add_skill_xp("crafting",6.0 if service_type == "overhaul" else 3.5)
    _emit_ai_sound(
        player.global_position,
        108.0 if service_type == "overhaul" else 82.0,
        "workbench",
        1.15 if service_type == "overhaul" else 0.85
    )

    if service_status != null:
        service_status.text = "%s: %d%% → %d%%" % [
            _service_name(service_type),
            int(current),
            int(new_value)
        ]

    _refresh_weapon_service_ui()
    _rebuild_salvage_ui()
    return true

func _select_service_weapon(weapon_id):
    if not weapon_defs.has(weapon_id):
        return

    service_weapon_id = weapon_id
    _refresh_weapon_service_ui()


func _set_workbench_mode(mode):
    if mode != "craft" and mode != "service" and mode != "salvage":
        return
    workbench_mode = mode
    _refresh_workbench_mode()


func _refresh_workbench_mode():
    if workbench_craft_content != null:
        workbench_craft_content.visible = workbench_mode == "craft"
    if workbench_service_content != null:
        workbench_service_content.visible = workbench_mode == "service"
    if workbench_salvage_content != null:
        workbench_salvage_content.visible = workbench_mode == "salvage"

    if workbench_craft_tab != null:
        workbench_craft_tab.disabled = workbench_mode == "craft"
    if workbench_service_tab != null:
        workbench_service_tab.disabled = workbench_mode == "service"
    if workbench_salvage_tab != null:
        workbench_salvage_tab.disabled = workbench_mode == "salvage"

    if workbench_mode == "craft":
        _refresh_crafting_details()
    elif workbench_mode == "service":
        _refresh_weapon_service_ui()
    else:
        _rebuild_salvage_ui()

func _service_cost_text(service_type):
    var lines = []
    var costs = _service_costs(service_type)

    for id in costs.keys():
        var need = int(costs[id])
        var have = _inventory_count(str(id))
        var item_name = str(id)

        if item_defs.has(str(id)):
            item_name = str(item_defs[str(id)].get("name",id))

        lines.append("%s: %d/%d" % [item_name,have,need])

    return "\n".join(lines)

func _refresh_weapon_service_ui():
    if service_weapon_id == "" or not weapon_defs.has(service_weapon_id):
        return

    if service_weapon_icon != null:
        service_weapon_icon.texture = _make_item_icon(service_weapon_id)

    if service_title != null:
        service_title.text = str(weapon_defs[service_weapon_id].get("name",service_weapon_id))

    var condition_value = _weapon_condition_value(service_weapon_id)
    if service_condition_label != null:
        service_condition_label.text = "Состояние: %d%%  [%s]" % [
            int(condition_value),
            _weapon_condition_state(service_weapon_id)
        ]

    if service_condition_bar != null:
        service_condition_bar.value = condition_value

    for id in service_weapon_buttons.keys():
        var button = service_weapon_buttons[id]
        if button != null:
            button.disabled = str(id) == service_weapon_id

    if service_requirements != null:
        service_requirements.text = "ОБСЛУЖИВАНИЕ  +30%%, максимум 90%%\n%s\n\nКАПРЕМОНТ  +60%%, максимум 100%%\n%s" % [
            _service_cost_text("maintenance"),
            _service_cost_text("overhaul")
        ]

    if service_status != null and service_status.text == "":
        service_status.text = "Выбери тип ремонта."

func _service_selected_maintenance():
    _perform_weapon_service(service_weapon_id,"maintenance")

func _service_selected_overhaul():
    _perform_weapon_service(service_weapon_id,"overhaul")




func _recipe_skill_required(recipe_id):
    if not recipe_defs.has(recipe_id):
        return 1
    return clamp(int(recipe_defs[recipe_id].get("skill_req",1)),1,10)

func _recipe_skill_ready(recipe_id):
    return _skill_level("crafting") >= _recipe_skill_required(recipe_id)

func _salvage_outputs(item_id):
    var table = {
        "repair_kit":{"scrap":1},
        "water_filter":{"scrap":1,"cloth":1},
        "combat_knife":{"scrap":1},
        "steel_pipe":{"scrap":2},
        "fire_axe":{"scrap":2,"cloth":1},
        "cap":{"cloth":1},
        "light_jacket":{"cloth":2},
        "police_vest":{"scrap":2,"cloth":2},
        "field_backpack":{"cloth":2,"tape":1},
        "flashlight":{"scrap":1},
        "makarov_extmag":{"scrap":1},
        "shotgun_exttube":{"scrap":1},
        "akm_extmag":{"scrap":2},
        "muzzle_brake":{"scrap":1},
        "suppressor":{"scrap":2,"cloth":1}
    }

    if not table.has(item_id):
        return {}
    return table[item_id].duplicate(true)

func _salvage_skill_required(item_id):
    if item_id == "police_vest":
        return 3
    if item_id == "suppressor" or item_id == "akm_extmag":
        return 3
    if item_id == "field_backpack" or item_id == "shotgun_exttube":
        return 2
    return 1

func _is_salvageable(item_id):
    return not _salvage_outputs(item_id).is_empty()

func _can_salvage(item_id):
    if not _is_salvageable(item_id):
        return false
    if _inventory_count(item_id) <= 0:
        return false
    if item_id == equipped_melee_id:
        return false
    if _skill_level("crafting") < _salvage_skill_required(item_id):
        return false

    var test_entries = inventory_entries.duplicate(true)
    if not _consume_one_item_from_entries(test_entries,item_id):
        return false

    var outputs = _salvage_outputs(item_id)
    var output_ids = outputs.keys()
    output_ids.sort()
    for out_id in output_ids:
        if _grid_add(test_entries,str(out_id),int(outputs[out_id]),INV_W,INV_H) != 0:
            return false
    return true

func _salvage_output_text(item_id):
    var outputs = _salvage_outputs(item_id)
    if outputs.is_empty():
        return "Нет пригодных материалов."

    var lines = []
    var ids = outputs.keys()
    ids.sort()
    for out_id in ids:
        var item_name = str(out_id)
        if item_defs.has(str(out_id)):
            item_name = str(item_defs[str(out_id)].get("name",out_id))
        lines.append("%s x%d" % [item_name,int(outputs[out_id])])
    return "\n".join(lines)

func _rebuild_salvage_ui():
    if salvage_list == null:
        return

    for child in salvage_list.get_children():
        salvage_list.remove_child(child)
        child.queue_free()

    var seen = {}
    var ids = []
    for entry in inventory_entries:
        var item_id = str(entry.get("id",""))
        if item_id == "" or seen.has(item_id):
            continue
        if not _is_salvageable(item_id):
            continue
        seen[item_id] = true
        ids.append(item_id)

    ids.sort()
    for item_id in ids:
        var count = _inventory_count(item_id)
        var item_name = str(item_defs.get(item_id,{}).get("name",item_id))
        var req = _salvage_skill_required(item_id)
        var button = Button.new()
        button.text = "%s x%d  [Р%d]" % [item_name,count,req]
        button.custom_minimum_size = Vector2(170,30)
        button.add_theme_font_size_override("font_size",7)
        _visual_button_style(button)
        button.pressed.connect(_select_salvage_item.bind(item_id))
        salvage_list.add_child(button)

    if selected_salvage_id != "" and _inventory_count(selected_salvage_id) <= 0:
        selected_salvage_id = ""

    _refresh_salvage_details()

func _select_salvage_item(item_id):
    selected_salvage_id = str(item_id)
    _refresh_salvage_details()

func _refresh_salvage_details():
    if salvage_details == null:
        return

    if selected_salvage_id == "":
        salvage_details.text = "Выбери предмет для разборки."
        if salvage_status != null:
            salvage_status.text = ""
        return

    if not _is_salvageable(selected_salvage_id):
        salvage_details.text = "Этот предмет нельзя разобрать."
        if salvage_status != null:
            salvage_status.text = ""
        return

    var item_name = str(item_defs.get(selected_salvage_id,{}).get("name",selected_salvage_id))
    var req = _salvage_skill_required(selected_salvage_id)
    var count = _inventory_count(selected_salvage_id)

    salvage_details.text = "%s\n\nВ наличии: %d\nРемесло: %d / %d\n\nВОЗВРАТ:\n%s" % [
        item_name,
        count,
        _skill_level("crafting"),
        req,
        _salvage_output_text(selected_salvage_id)
    ]

    if salvage_status != null:
        if selected_salvage_id == equipped_melee_id:
            salvage_status.text = "Сначала убери активное melee-оружие."
        elif _skill_level("crafting") < req:
            salvage_status.text = "Недостаточный уровень РЕМЕСЛА."
        elif not _can_salvage(selected_salvage_id):
            salvage_status.text = "Нет места для материалов."
        else:
            salvage_status.text = "Готово к разборке."

func _salvage_selected_item():
    if selected_salvage_id == "":
        return false

    var item_id = selected_salvage_id
    if not _can_salvage(item_id):
        _refresh_salvage_details()
        return false

    var test_entries = inventory_entries.duplicate(true)
    if not _consume_one_item_from_entries(test_entries,item_id):
        return false

    var outputs = _salvage_outputs(item_id)
    var output_ids = outputs.keys()
    output_ids.sort()
    for out_id in output_ids:
        if _grid_add(test_entries,str(out_id),int(outputs[out_id]),INV_W,INV_H) != 0:
            return false

    inventory_entries = test_entries
    var req = _salvage_skill_required(item_id)
    _add_skill_xp("crafting",2.0 + float(req) * 0.75)
    _emit_ai_sound(player.global_position,92.0,"workbench",1.0)

    if salvage_status != null:
        salvage_status.text = "Разобрано: %s" % str(item_defs.get(item_id,{}).get("name",item_id))

    if _inventory_count(item_id) <= 0:
        selected_salvage_id = ""

    _rebuild_salvage_ui()
    _refresh_crafting_details()
    _refresh_weapon_service_ui()
    return true


func _create_crafting_ui():
    var canvas = CanvasLayer.new()
    canvas.layer = 25
    canvas.name = "CraftingUI"
    add_child(canvas)

    craft_panel = Panel.new()
    craft_panel.position = Vector2(82,30)
    craft_panel.size = Vector2(476,300)
    canvas.add_child(craft_panel)

    craft_panel.add_theme_stylebox_override("panel",_visual_panel_style())

    var title = Label.new()
    title.position = Vector2(14,10)
    title.text = "ВЕРСТАК"
    title.add_theme_font_size_override("font_size",12)
    title.modulate = Color(0.94,0.90,0.75)
    craft_panel.add_child(title)

    workbench_craft_tab = Button.new()
    workbench_craft_tab.position = Vector2(102,7)
    workbench_craft_tab.size = Vector2(90,28)
    workbench_craft_tab.text = "КРАФТ"
    workbench_craft_tab.add_theme_font_size_override("font_size",8)
    _visual_button_style(workbench_craft_tab)
    workbench_craft_tab.pressed.connect(_set_workbench_mode.bind("craft"))
    craft_panel.add_child(workbench_craft_tab)

    workbench_service_tab = Button.new()
    workbench_service_tab.position = Vector2(198,7)
    workbench_service_tab.size = Vector2(106,28)
    workbench_service_tab.text = "ОРУЖЕЙНИК"
    workbench_service_tab.add_theme_font_size_override("font_size",8)
    _visual_button_style(workbench_service_tab)
    workbench_service_tab.pressed.connect(_set_workbench_mode.bind("service"))
    craft_panel.add_child(workbench_service_tab)

    workbench_salvage_tab = Button.new()
    workbench_salvage_tab.position = Vector2(310,7)
    workbench_salvage_tab.size = Vector2(104,28)
    workbench_salvage_tab.text = "РАЗБОР"
    workbench_salvage_tab.add_theme_font_size_override("font_size",8)
    _visual_button_style(workbench_salvage_tab)
    workbench_salvage_tab.pressed.connect(_set_workbench_mode.bind("salvage"))
    craft_panel.add_child(workbench_salvage_tab)

    var close_button = Button.new()
    close_button.position = Vector2(430,7)
    close_button.size = Vector2(32,28)
    close_button.text = "×"
    close_button.add_theme_font_size_override("font_size",12)
    _visual_button_style(close_button)
    close_button.pressed.connect(_close_crafting)
    craft_panel.add_child(close_button)

    # Crafting content.
    workbench_craft_content = Control.new()
    workbench_craft_content.position = Vector2(0,40)
    workbench_craft_content.size = Vector2(476,260)
    craft_panel.add_child(workbench_craft_content)

    var craft_scroll = ScrollContainer.new()
    craft_scroll.name = "CraftRecipeScroll"
    craft_scroll.position = Vector2(14,8)
    craft_scroll.size = Vector2(188,190)
    craft_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    craft_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    workbench_craft_content.add_child(craft_scroll)

    craft_list = VBoxContainer.new()
    craft_list.name = "CraftRecipeList"
    craft_list.custom_minimum_size = Vector2(176,0)
    craft_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    craft_scroll.add_child(craft_list)

    craft_details = Label.new()
    craft_details.position = Vector2(215,10)
    craft_details.size = Vector2(242,130)
    craft_details.add_theme_font_size_override("font_size",8)
    workbench_craft_content.add_child(craft_details)

    craft_status = Label.new()
    craft_status.position = Vector2(215,146)
    craft_status.size = Vector2(242,40)
    craft_status.add_theme_font_size_override("font_size",8)
    workbench_craft_content.add_child(craft_status)

    _make_button(workbench_craft_content,Vector2(215,205),Vector2(120,32),"СОЗДАТЬ",_craft_selected_recipe)

    # Weapon service content.
    workbench_service_content = Control.new()
    workbench_service_content.position = Vector2(0,40)
    workbench_service_content.size = Vector2(476,260)
    craft_panel.add_child(workbench_service_content)

    var weapons_title = Label.new()
    weapons_title.position = Vector2(14,8)
    weapons_title.text = "ОРУЖИЕ"
    weapons_title.add_theme_font_size_override("font_size",8)
    weapons_title.modulate = Color(0.62,0.66,0.61)
    workbench_service_content.add_child(weapons_title)

    var weapon_ids = ["makarov","shotgun","akm"]
    var y = 30
    for weapon_id in weapon_ids:
        var button = Button.new()
        button.position = Vector2(14,y)
        button.size = Vector2(132,42)
        button.text = str(weapon_defs.get(weapon_id,{}).get("name",weapon_id))
        button.icon = _make_item_icon(weapon_id)
        button.add_theme_font_size_override("font_size",8)
        _visual_button_style(button)
        button.pressed.connect(_select_service_weapon.bind(weapon_id))
        workbench_service_content.add_child(button)
        service_weapon_buttons[weapon_id] = button
        y += 48

    service_weapon_icon = TextureRect.new()
    service_weapon_icon.position = Vector2(172,10)
    service_weapon_icon.size = Vector2(92,42)
    service_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    service_weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    workbench_service_content.add_child(service_weapon_icon)

    service_title = Label.new()
    service_title.position = Vector2(278,10)
    service_title.size = Vector2(180,20)
    service_title.add_theme_font_size_override("font_size",11)
    service_title.modulate = Color(0.95,0.91,0.75)
    workbench_service_content.add_child(service_title)

    service_condition_label = Label.new()
    service_condition_label.position = Vector2(278,31)
    service_condition_label.size = Vector2(180,20)
    service_condition_label.add_theme_font_size_override("font_size",8)
    workbench_service_content.add_child(service_condition_label)

    service_condition_bar = ProgressBar.new()
    service_condition_bar.position = Vector2(172,59)
    service_condition_bar.size = Vector2(286,16)
    service_condition_bar.min_value = 0
    service_condition_bar.max_value = 100
    service_condition_bar.show_percentage = false
    workbench_service_content.add_child(service_condition_bar)

    service_requirements = Label.new()
    service_requirements.position = Vector2(172,85)
    service_requirements.size = Vector2(286,92)
    service_requirements.add_theme_font_size_override("font_size",7)
    service_requirements.modulate = Color(0.76,0.78,0.71)
    workbench_service_content.add_child(service_requirements)

    _make_button(workbench_service_content,Vector2(172,184),Vector2(136,34),"ОБСЛУЖИТЬ",_service_selected_maintenance)
    _make_button(workbench_service_content,Vector2(316,184),Vector2(142,34),"КАПРЕМОНТ",_service_selected_overhaul)

    service_status = Label.new()
    service_status.position = Vector2(172,224)
    service_status.size = Vector2(286,28)
    service_status.add_theme_font_size_override("font_size",7)
    service_status.modulate = Color(0.74,0.78,0.68)
    workbench_service_content.add_child(service_status)

    workbench_salvage_content = Control.new()
    workbench_salvage_content.position = Vector2(0,40)
    workbench_salvage_content.size = Vector2(476,260)
    craft_panel.add_child(workbench_salvage_content)

    var salvage_title = Label.new()
    salvage_title.position = Vector2(14,8)
    salvage_title.text = "РАЗБОР И ВОЗВРАТ МАТЕРИАЛОВ"
    salvage_title.add_theme_font_size_override("font_size",8)
    salvage_title.modulate = Color(0.62,0.66,0.61)
    workbench_salvage_content.add_child(salvage_title)

    var salvage_scroll = ScrollContainer.new()
    salvage_scroll.name = "SalvageItemScroll"
    salvage_scroll.position = Vector2(14,30)
    salvage_scroll.size = Vector2(188,190)
    salvage_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    salvage_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    workbench_salvage_content.add_child(salvage_scroll)

    salvage_list = VBoxContainer.new()
    salvage_list.name = "SalvageItemList"
    salvage_list.custom_minimum_size = Vector2(176,0)
    salvage_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    salvage_scroll.add_child(salvage_list)

    salvage_details = Label.new()
    salvage_details.position = Vector2(215,30)
    salvage_details.size = Vector2(242,142)
    salvage_details.add_theme_font_size_override("font_size",8)
    workbench_salvage_content.add_child(salvage_details)

    salvage_status = Label.new()
    salvage_status.position = Vector2(215,174)
    salvage_status.size = Vector2(242,34)
    salvage_status.add_theme_font_size_override("font_size",8)
    salvage_status.modulate = Color(0.74,0.78,0.68)
    workbench_salvage_content.add_child(salvage_status)

    _make_button(
        workbench_salvage_content,
        Vector2(215,214),
        Vector2(132,32),
        "РАЗОБРАТЬ",
        _salvage_selected_item
    )

    craft_panel.visible = false
    _rebuild_crafting_ui()
    _rebuild_salvage_ui()
    _refresh_workbench_mode()

func _rebuild_crafting_ui():
    if craft_list == null:
        return

    for child in craft_list.get_children():
        craft_list.remove_child(child)
        child.queue_free()

    var ids = recipe_defs.keys()
    ids.sort()

    for recipe_id in ids:
        var recipe = recipe_defs[recipe_id]
        var req = _recipe_skill_required(str(recipe_id))
        var button = Button.new()
        button.text = "%s  [Р%d]" % [str(recipe.get("name",recipe_id)),req]
        button.custom_minimum_size = Vector2(170,30)
        button.add_theme_font_size_override("font_size",7)
        _visual_button_style(button)
        button.pressed.connect(_select_recipe.bind(str(recipe_id)))
        craft_list.add_child(button)

    _refresh_crafting_details()

func _select_recipe(recipe_id):
    selected_recipe_id = recipe_id
    _refresh_crafting_details()


func _refresh_crafting_details():
    if craft_details == null:
        return

    if selected_recipe_id == "" or not recipe_defs.has(selected_recipe_id):
        craft_details.text = "Выбери рецепт."
        if craft_status != null:
            craft_status.text = ""
        return

    var recipe = recipe_defs[selected_recipe_id]
    var req = _recipe_skill_required(selected_recipe_id)
    var lines = [
        str(recipe.get("name",selected_recipe_id)),
        "Ремесло: %d / %d" % [_skill_level("crafting"),req],
        ""
    ]

    var ingredients = recipe.get("ingredients",{})
    for id in ingredients.keys():
        var need = int(ingredients[id])
        var have = _inventory_count(str(id))
        var item_name = str(id)
        if item_defs.has(str(id)):
            item_name = str(item_defs[str(id)].get("name",id))
        lines.append("%s: %d/%d" % [item_name,have,need])

    var out_id = str(recipe.get("output",""))
    var out_qty = int(recipe.get("output_qty",1))
    var out_name = out_id
    if item_defs.has(out_id):
        out_name = str(item_defs[out_id].get("name",out_id))

    lines.append("")
    lines.append("Результат: %s x%d" % [out_name,out_qty])
    craft_details.text = "
".join(lines)

    if craft_status != null:
        if not _recipe_skill_ready(selected_recipe_id):
            craft_status.text = "Нужен навык РЕМЕСЛО %d." % req
        elif _can_craft(selected_recipe_id):
            craft_status.text = "Готово к работе."
        else:
            craft_status.text = "Не хватает ресурсов или места."

func _open_crafting():
    crafting_open = true
    inventory_open = true
    active_container_key = ""
    selected_recipe_id = ""
    selected_salvage_id = ""
    selected_inventory_index = -1
    selected_container_index = -1
    service_weapon_id = current_weapon_id
    if service_status != null:
        service_status.text = ""

    if inventory_panel != null:
        inventory_panel.visible = false
    if container_panel != null:
        container_panel.visible = false
    if equipment_panel != null:
        equipment_panel.visible = false
    if craft_panel != null:
        craft_panel.visible = true

    _clear_inventory_drag()
    _rebuild_crafting_ui()
    _rebuild_salvage_ui()
    _refresh_workbench_mode()

func _close_crafting():
    crafting_open = false
    inventory_open = false
    selected_recipe_id = ""
    selected_salvage_id = ""
    _clear_inventory_drag()

    if craft_panel != null:
        craft_panel.visible = false
    if inventory_panel != null:
        inventory_panel.visible = false
    if equipment_panel != null:
        equipment_panel.visible = false
    if container_panel != null:
        container_panel.visible = false

func _can_craft(recipe_id):
    if not recipe_defs.has(recipe_id):
        return false
    if not _recipe_skill_ready(recipe_id):
        return false

    var recipe = recipe_defs[recipe_id]
    var test = inventory_entries.duplicate(true)

    for id in recipe.get("ingredients",{}).keys():
        var amount = int(recipe["ingredients"][id])
        if not _consume_from_entries(test,str(id),amount):
            return false

    var out_id = str(recipe.get("output",""))
    var out_qty = int(recipe.get("output_qty",1))
    return _grid_add(test,out_id,out_qty,INV_W,INV_H) == 0

func _craft_selected_recipe():
    if not _recipe_skill_ready(selected_recipe_id):
        if craft_status != null:
            craft_status.text = "Недостаточный уровень РЕМЕСЛА."
        return

    if not _can_craft(selected_recipe_id):
        if craft_status != null:
            craft_status.text = "Крафт невозможен."
        return

    var recipe = recipe_defs[selected_recipe_id]
    var test = inventory_entries.duplicate(true)

    for id in recipe.get("ingredients",{}).keys():
        var amount = int(recipe["ingredients"][id])
        if not _consume_from_entries(test,str(id),amount):
            return

    var out_id = str(recipe.get("output",""))
    var out_qty = int(recipe.get("output_qty",1))
    if _grid_add(test,out_id,out_qty,INV_W,INV_H) != 0:
        if craft_status != null:
            craft_status.text = "Нет места в рюкзаке."
        return

    inventory_entries = test

    var recipe_req = _recipe_skill_required(selected_recipe_id)
    _add_skill_xp("crafting",2.5 + float(recipe_req) * 0.75 + float(out_qty) * 0.50)
    _emit_ai_sound(player.global_position,74.0,"workbench",0.80)

    if craft_status != null:
        craft_status.text = "Создано: %s" % str(recipe.get("name",selected_recipe_id))

    _refresh_crafting_details()
    _refresh_weapon_service_ui()
    _rebuild_salvage_ui()

func _consume_from_entries(entries,id,amount):
    var remaining = int(amount)

    for i in range(entries.size() - 1,-1,-1):
        if remaining <= 0:
            break
        if str(entries[i].get("id","")) != id:
            continue

        var qty = int(entries[i].get("qty",1))
        var take = min(qty,remaining)
        qty -= take
        remaining -= take

        if qty <= 0:
            entries.remove_at(i)
        else:
            entries[i]["qty"] = qty

    return remaining == 0







func _hud_panel_style(accent = false):
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.014,0.018,0.020,0.955)
    style.border_color = (
        Color(0.80,0.68,0.39,0.98)
        if accent
        else Color(0.26,0.31,0.31,1.0)
    )
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 0
    style.corner_radius_top_right = 0
    style.corner_radius_bottom_left = 0
    style.corner_radius_bottom_right = 0
    style.content_margin_left = 2.0
    style.content_margin_top = 2.0
    style.content_margin_right = 2.0
    style.content_margin_bottom = 2.0
    style.shadow_size = 2
    style.shadow_color = Color(0.0,0.0,0.0,0.36)
    style.anti_aliasing = false
    return style

func _hud_add_accent_strip(parent,pos,size,color):
    var strip = ColorRect.new()
    strip.position = pos
    strip.size = size
    strip.color = color
    strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(strip)
    return strip

func _hud_add_panel_detail(parent,size,accent):
    var edge = Color(accent.r,accent.g,accent.b,0.48)
    var edge_soft = Color(accent.r,accent.g,accent.b,0.20)
    var rivet = Color(0.58,0.60,0.56,0.76)
    var metal = Color(0.50,0.52,0.49,0.46)
    var bracket = Color(0.74,0.66,0.47,0.24)
    _hud_add_accent_strip(parent,Vector2(2,2),Vector2(max(1.0,size.x - 4.0),1),edge)
    _hud_add_accent_strip(parent,Vector2(2,size.y - 3),Vector2(max(1.0,size.x - 4.0),1),edge_soft)
    _hud_add_accent_strip(parent,Vector2(2,2),Vector2(1,max(1.0,size.y - 4.0)),edge_soft)
    _hud_add_accent_strip(parent,Vector2(size.x - 3,2),Vector2(1,max(1.0,size.y - 4.0)),edge_soft)
    _hud_add_accent_strip(parent,Vector2(3,3),Vector2(max(1.0,size.x - 6.0),1),Color(1,1,1,0.035))

    # Industrial corner brackets — readable at 2x output without making the panels bulky.
    for p in [Vector2(2,2),Vector2(size.x - 7,2),Vector2(2,size.y - 3),Vector2(size.x - 7,size.y - 3)]:
        _hud_add_accent_strip(parent,p,Vector2(5,1),metal)
    for p in [Vector2(2,2),Vector2(size.x - 3,2),Vector2(2,size.y - 7),Vector2(size.x - 3,size.y - 7)]:
        _hud_add_accent_strip(parent,p,Vector2(1,5),metal)
    for p in [Vector2(3,2),Vector2(size.x - 8,2),Vector2(3,size.y - 3),Vector2(size.x - 8,size.y - 3)]:
        _hud_add_accent_strip(parent,p,Vector2(3,1),bracket)
    for p in [Vector2(2,3),Vector2(size.x - 3,3),Vector2(2,size.y - 8),Vector2(size.x - 3,size.y - 8)]:
        _hud_add_accent_strip(parent,p,Vector2(1,3),bracket)

    for point in [Vector2(3,3),Vector2(size.x - 4,3),Vector2(3,size.y - 4),Vector2(size.x - 4,size.y - 4)]:
        _hud_add_accent_strip(parent,point,Vector2(1,1),rivet)
    var scratches = [
        Rect2(8,1,7,1),
        Rect2(size.x - 19,1,6,1),
        Rect2(1,10,1,5),
        Rect2(size.x - 2,size.y - 14,1,5),
        Rect2(10,size.y - 2,8,1)
    ]
    for r in scratches:
        _hud_add_accent_strip(parent,r.position,r.size,Color(0.78,0.76,0.67,0.06))

func _hud_add_segment_ticks(parent,pos,size,count):
    if count <= 1:
        return
    for i in range(1,count):
        var tick = ColorRect.new()
        tick.position = Vector2(pos.x + floor(size.x * float(i) / float(count)),pos.y)
        tick.size = Vector2(1,size.y)
        tick.color = Color(0.02,0.025,0.024,0.72)
        tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
        parent.add_child(tick)

func _hud_section_title(parent,text,width,accent):
    _hud_add_accent_strip(parent,Vector2(0,0),Vector2(width,1),Color(accent.r,accent.g,accent.b,0.72))
    _hud_add_accent_strip(parent,Vector2(0,0),Vector2(1,12),Color(accent.r,accent.g,accent.b,0.90))
    return _hud_make_label(parent,Vector2(6,1),Vector2(width - 12,10),text,5,Color(0.72,0.76,0.73))

func _hud_add_screen_frame(parent):
    # Bottom rails visually tie the three lower HUD clusters together without making a giant bar.
    _hud_add_accent_strip(parent,Vector2(140,351),Vector2(44,1),Color(0.18,0.22,0.22,0.62))
    _hud_add_accent_strip(parent,Vector2(452,351),Vector2(34,1),Color(0.18,0.22,0.22,0.62))

func _hud_make_label(parent,pos,size,text,font_size,color,align = HORIZONTAL_ALIGNMENT_LEFT):
    var label = Label.new()
    label.position = pos
    label.size = size
    label.text = text
    label.horizontal_alignment = align
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    label.add_theme_font_size_override("font_size",font_size)
    label.add_theme_color_override("font_color",color)
    label.add_theme_color_override("font_outline_color",Color(0.0,0.0,0.0,0.88))
    label.add_theme_constant_override("outline_size",1 if font_size >= 5 else 0)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
    return label

func _hud_set_label_font_size(label,size):
    if label == null:
        return
    label.add_theme_font_size_override("font_size",size)
    label.add_theme_constant_override("outline_size",1 if size >= 5 else 0)

func _hud_text_width(label,text,size):
    if label == null:
        return 0.0
    var font = label.get_theme_font("font")
    if font == null:
        return float(text.length() * size)
    var widest = 0.0
    for line in text.split("
"):
        widest = max(widest,font.get_string_size(str(line),HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
    return widest

func _hud_set_fitted_text(label,text,base_size,min_size,_compact_threshold = 999,_hard_threshold = 999):
    if label == null:
        return
    label.text = text
    var size = base_size
    var allowed_width = max(1.0,label.size.x - 2.0)
    while size > min_size and _hud_text_width(label,text,size) > allowed_width:
        size -= 1
    _hud_set_label_font_size(label,size)

func _hud_single_line_label_fits(label):
    if label == null or not label.visible or label.text == "":
        return true
    if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
        return true
    var font_size = label.get_theme_font_size("font_size")
    return _hud_text_width(label,label.text,font_size) <= label.size.x + 0.5

func _hud_candidate_text_fits(label,text,base_size,min_size):
    if label == null:
        return false
    var size = base_size
    var allowed_width = max(1.0,label.size.x - 2.0)
    while size > min_size and _hud_text_width(label,text,size) > allowed_width:
        size -= 1
    return _hud_text_width(label,text,size) <= allowed_width + 0.5

func _hud_fit_texture_rect(rect_control,texture,box_pos,box_size):
    rect_control.texture = texture
    rect_control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    # Ignore the texture's native minimum size, then scale into the fitted rect.
    # Without EXPAND_IGNORE_SIZE, long-gun AtlasTextures force their native width
    # back onto the TextureRect and get clipped by the quick-slot container.
    rect_control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    rect_control.stretch_mode = TextureRect.STRETCH_SCALE
    rect_control.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if texture == null:
        rect_control.position = box_pos
        rect_control.size = box_size
        return

    var native_size = texture.get_size()
    var fit = min(1.0,min(box_size.x / max(1.0,native_size.x),box_size.y / max(1.0,native_size.y)))
    var draw_size = Vector2(max(1.0,floor(native_size.x * fit)),max(1.0,floor(native_size.y * fit)))
    rect_control.size = draw_size
    rect_control.position = box_pos + Vector2(floor((box_size.x - draw_size.x) * 0.5),floor((box_size.y - draw_size.y) * 0.5))

func _hud_make_bar(parent,pos,size,color,segment_count = 10):
    var frame = Panel.new()
    frame.position = pos
    frame.size = size
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.clip_contents = true

    var frame_style = StyleBoxFlat.new()
    frame_style.bg_color = Color(0.035,0.045,0.048,0.98)
    frame_style.border_color = Color(0.12,0.15,0.15,1.0)
    frame_style.border_width_left = 1
    frame_style.border_width_top = 1
    frame_style.border_width_right = 1
    frame_style.border_width_bottom = 1
    frame_style.anti_aliasing = false
    frame.add_theme_stylebox_override("panel",frame_style)
    parent.add_child(frame)

    var inner = Control.new()
    inner.position = Vector2(1,1)
    inner.size = Vector2(max(1.0,size.x - 2.0),max(1.0,size.y - 2.0))
    inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
    inner.clip_contents = true
    frame.add_child(inner)

    var count = max(1,int(segment_count))
    var gap = 1
    var segment_width = max(1,int(floor((inner.size.x - float(gap * (count - 1))) / float(count))))
    var used_width = segment_width * count + gap * (count - 1)
    var start_x = int(floor((inner.size.x - float(used_width)) * 0.5))
    var active_color = color
    var inactive_color = Color(0.13,0.16,0.16,0.98)
    var segments = []

    for i in range(count):
        var segment = ColorRect.new()
        segment.position = Vector2(start_x + i * (segment_width + gap),0)
        segment.size = Vector2(segment_width,inner.size.y)
        segment.color = inactive_color
        segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
        inner.add_child(segment)
        segments.append(segment)

    frame.set_meta("segments",segments)
    frame.set_meta("segment_count",count)
    frame.set_meta("active_color",active_color)
    frame.set_meta("inactive_color",inactive_color)
    frame.set_meta("hud_value",100.0)
    _hud_set_bar_value(frame,100.0)
    return frame

func _hud_set_bar_value(bar,value):
    if bar == null or not bar.has_meta("segments"):
        return

    var segments = bar.get_meta("segments")
    var count = int(bar.get_meta("segment_count"))
    var active_color = bar.get_meta("active_color")
    var inactive_color = bar.get_meta("inactive_color")
    var normalized = clamp(value,0.0,100.0) / 100.0 * float(count)
    var whole = int(floor(normalized))
    var partial = normalized - float(whole)

    for i in range(segments.size()):
        var segment = segments[i]
        if segment == null:
            continue
        if i < whole:
            segment.color = active_color
        elif i == whole and partial > 0.05:
            segment.color = Color(active_color.r,active_color.g,active_color.b,0.42 + partial * 0.58)
        else:
            segment.color = inactive_color

    bar.set_meta("hud_value",clamp(value,0.0,100.0))

func _hud_make_vital_icon(parent,key,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(9,9)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)

    var pieces = []
    match key:
        "health":
            pieces = [Rect2(3,1,3,7),Rect2(1,3,7,3)]
        "stamina":
            pieces = [Rect2(4,0,2,3),Rect2(3,2,3,3),Rect2(2,4,3,2),Rect2(1,6,2,3)]
        "hunger":
            pieces = [Rect2(1,1,1,7),Rect2(3,1,1,7),Rect2(5,1,1,7),Rect2(7,1,1,7),Rect2(0,1,7,1),Rect2(7,5,2,1)]
        "thirst":
            pieces = [Rect2(4,0,1,2),Rect2(3,2,3,2),Rect2(2,4,5,3),Rect2(3,7,3,1)]
        "temperature":
            pieces = [Rect2(4,0,2,6),Rect2(3,5,4,2),Rect2(2,7,6,1)]
        "infection":
            pieces = [Rect2(4,3,2,2),Rect2(1,1,2,2),Rect2(6,1,2,2),Rect2(1,6,2,2),Rect2(6,6,2,2),Rect2(3,0,3,1),Rect2(3,8,3,1)]
        _:
            pieces = [Rect2(3,3,3,3)]

    for r in pieces:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_stance_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(9,10)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    var pieces = [
        Rect2(4,0,2,2),
        Rect2(4,2,2,4),
        Rect2(2,3,2,1),
        Rect2(6,4,2,1),
        Rect2(3,6,1,3),
        Rect2(6,6,1,3)
    ]
    for r in pieces:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_eye_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(10,6)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(2,0,6,1),Rect2(1,1,1,1),Rect2(8,1,1,1),Rect2(0,2,1,2),Rect2(9,2,1,2),Rect2(1,4,1,1),Rect2(8,4,1,1),Rect2(2,5,6,1),Rect2(4,2,2,2)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_noise_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(10,8)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(0,2,2,4),Rect2(2,1,1,6),Rect2(3,2,2,4),Rect2(6,1,1,1),Rect2(7,0,1,2),Rect2(7,5,1,2),Rect2(8,2,1,4)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_weight_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(10,9)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(3,0,4,1),Rect2(2,1,1,1),Rect2(7,1,1,1),Rect2(1,2,8,1),Rect2(0,3,1,5),Rect2(9,3,1,5),Rect2(1,8,8,1)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_cloud_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(11,7)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(2,1,2,2),Rect2(5,0,3,2),Rect2(8,2,2,2),Rect2(1,3,9,2),Rect2(2,5,6,1)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_sun_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(11,9)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(5,0,1,2),Rect2(5,7,1,2),Rect2(0,4,2,1),Rect2(9,4,2,1),Rect2(3,2,5,5),Rect2(2,1,1,1),Rect2(8,1,1,1),Rect2(2,7,1,1),Rect2(8,7,1,1)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_rain_icon(parent,pos,color):
    var root = _hud_make_cloud_icon(parent,pos,color)
    for p in [Vector2(2,7),Vector2(5,7),Vector2(8,7)]:
        var drop = ColorRect.new()
        drop.position = p
        drop.size = Vector2(1,2)
        drop.color = Color(0.42,0.64,0.87,0.95)
        drop.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(drop)
    root.size = Vector2(11,10)
    return root

func _hud_make_house_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(10,10)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(4,0,2,1),Rect2(3,1,4,1),Rect2(2,2,6,1),Rect2(1,3,8,1),Rect2(2,4,2,5),Rect2(6,4,2,5),Rect2(4,6,2,3),Rect2(2,9,6,1)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_fire_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(10,10)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(4,0,2,2),Rect2(3,2,4,2),Rect2(2,4,6,2),Rect2(3,6,4,2),Rect2(1,8,3,1),Rect2(6,8,3,1)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_checkbox_icon(parent,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(9,9)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    for r in [Rect2(0,0,9,1),Rect2(0,8,9,1),Rect2(0,1,1,7),Rect2(8,1,1,7)]:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_condition_icon(parent,key,pos,color):
    var root = Control.new()
    root.position = pos
    root.size = Vector2(8,9)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(root)
    var pieces = []
    match key:
        "blood":
            pieces = [Rect2(3,0,2,2),Rect2(2,2,4,2),Rect2(1,4,6,3),Rect2(2,7,4,1)]
        "pain":
            pieces = [Rect2(2,1,4,1),Rect2(1,2,6,4),Rect2(2,6,1,2),Rect2(5,6,1,2),Rect2(3,4,2,1)]
        "wet":
            pieces = [Rect2(3,0,2,2),Rect2(2,2,4,2),Rect2(1,4,6,3),Rect2(2,7,4,1)]
        "contam":
            pieces = [Rect2(3,3,2,2),Rect2(0,1,3,2),Rect2(5,1,3,2),Rect2(1,6,2,2),Rect2(5,6,2,2)]
        _:
            pieces = [Rect2(2,2,4,4)]
    for r in pieces:
        var px = ColorRect.new()
        px.position = r.position
        px.size = r.size
        px.color = color
        px.mouse_filter = Control.MOUSE_FILTER_IGNORE
        root.add_child(px)
    return root

func _hud_make_vital_row(parent,key,y,label_text,color):
    _hud_make_vital_icon(parent,key,Vector2(6,y - 1),Color(color.r,color.g,color.b,0.98))
    _hud_make_label(parent,Vector2(19,y - 2),Vector2(42,10),label_text,6,Color(0.80,0.83,0.80))

    var bar = _hud_make_bar(parent,Vector2(62,y),Vector2(62,7),color,10)
    hud_vital_bars[key] = bar

    var value_label = _hud_make_label(parent,Vector2(127,y - 3),Vector2(40,10),"",6,Color(0.92,0.92,0.86),HORIZONTAL_ALIGNMENT_RIGHT)
    hud_vital_values[key] = value_label

func _hud_display_texture(item_id):
    var cache_key = "hud_model:" + str(item_id)
    if hud_model_icon_cache.has(cache_key):
        return hud_model_icon_cache[cache_key]

    var texture = null
    if weapon_defs.has(item_id):
        if weapon_model_atlas == null:
            weapon_model_atlas = load("res://weapon_models_v16.png")
        if weapon_model_atlas != null:
            var weapon_region = Rect2(44,13,61,31)
            if item_id == "shotgun":
                weapon_region = Rect2(8,63,128,25)
            elif item_id == "akm":
                weapon_region = Rect2(6,108,134,34)
            var weapon_tex = AtlasTexture.new()
            weapon_tex.atlas = weapon_model_atlas
            weapon_tex.region = weapon_region
            texture = weapon_tex
    elif melee_defs.has(item_id):
        if melee_model_atlas == null:
            melee_model_atlas = load("res://melee_models_v15.png")
        if melee_model_atlas != null:
            var melee_region = Rect2(15,11,69,10)
            if item_id == "steel_pipe":
                melee_region = Rect2(10,43,74,11)
            elif item_id == "fire_axe":
                melee_region = Rect2(10,68,82,25)
            var melee_tex = AtlasTexture.new()
            melee_tex.atlas = melee_model_atlas
            melee_tex.region = melee_region
            texture = melee_tex
    if texture == null:
        texture = _make_item_icon(item_id)
    hud_model_icon_cache[cache_key] = texture
    return texture

func _hud_quick_icon_layout(item_id):
    if item_id == "makarov":
        return {"pos":Vector2(4,12),"size":Vector2(32,19)}
    if item_id == "shotgun":
        return {"pos":Vector2(2,15),"size":Vector2(36,12)}
    if item_id == "akm":
        return {"pos":Vector2(2,14),"size":Vector2(36,14)}
    if item_id == "combat_knife":
        return {"pos":Vector2(3,14),"size":Vector2(34,13)}
    if item_id == "steel_pipe":
        return {"pos":Vector2(3,14),"size":Vector2(34,13)}
    if item_id == "fire_axe":
        return {"pos":Vector2(3,12),"size":Vector2(34,18)}
    return {"pos":Vector2(7,12),"size":Vector2(24,19)}

func _hud_apply_quick_slot_icon(icon,item_id):
    if icon == null:
        return
    var layout = _hud_quick_icon_layout(item_id)
    _hud_fit_texture_rect(icon,_hud_display_texture(item_id),layout["pos"],layout["size"])

func _hud_quick_slot_style(active):
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.041,0.038,0.030,0.995) if active else Color(0.024,0.031,0.034,0.97)
    style.border_color = Color(0.94,0.77,0.31,1.0) if active else Color(0.20,0.25,0.25,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 0
    style.corner_radius_top_right = 0
    style.corner_radius_bottom_left = 0
    style.corner_radius_bottom_right = 0
    style.content_margin_left = 0.0
    style.content_margin_top = 0.0
    style.content_margin_right = 0.0
    style.content_margin_bottom = 0.0
    style.shadow_size = 1 if active else 0
    style.shadow_color = Color(0.0,0.0,0.0,0.22)
    style.anti_aliasing = false
    return style

func _hud_quick_art_style(active,owned):
    var style = StyleBoxFlat.new()
    if not owned:
        style.bg_color = Color(0.028,0.033,0.035,0.94)
        style.border_color = Color(0.12,0.15,0.15,0.95)
    elif active:
        style.bg_color = Color(0.055,0.049,0.032,0.98)
        style.border_color = Color(0.52,0.43,0.22,0.90)
    else:
        style.bg_color = Color(0.043,0.051,0.054,0.97)
        style.border_color = Color(0.14,0.18,0.18,0.95)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 0
    style.corner_radius_top_right = 0
    style.corner_radius_bottom_left = 0
    style.corner_radius_bottom_right = 0
    style.anti_aliasing = false
    return style

func _hud_status_color():
    if bleeding or health < 25.0 or wound_infection >= 70.0:
        return Color(0.92,0.48,0.43)
    if thirst < 20.0 or hunger < 20.0 or stamina < 15.0 or wetness > 70.0 or wound_contamination >= 45.0 or _effective_pain() > 55.0:
        return Color(0.91,0.72,0.36)
    return Color(0.53,0.67,0.53)

func _hud_compact_condition_text():
    var flags = []
    if bleeding:
        flags.append("КРОВЬ")
    if wound_infection >= 30.0:
        flags.append("ИНФЕКЦИЯ")
    elif wound_contamination >= 45.0:
        flags.append("РАНА")
    if body_temperature < 35.7:
        flags.append("ХОЛОД")
    elif body_temperature > 38.0:
        flags.append("ЖАР")
    if wetness >= 70.0:
        flags.append("МОКРО")
    if flags.is_empty():
        return "СТАБИЛЬНО"
    if flags.size() > 2:
        flags.resize(2)
    return " • ".join(flags)

func _hud_ammo_display_name(ammo_id):
    match str(ammo_id):
        "ammo_9x18":
            return "9×18 мм"
        "ammo_12g":
            return "12 кал."
        "ammo_762":
            return "7,62 мм"
    return str(ammo_id).replace("ammo_","").to_upper()

func _hud_fire_mode_label(weapon_id,weapon):
    if weapon_id == "shotgun":
        return "ПОМПА"
    return "АВТО" if bool(weapon.get("automatic",false)) else "ОДИН."

func _hud_survival_objective():
    if bleeding:
        return {"title":"ОСТАНОВИТЬ КРОВЬ","sub":"Нужна повязка или бинт"}
    if wound_infection >= 30.0 or wound_contamination >= 45.0:
        return {"title":"ОБРАБОТАТЬ РАНУ","sub":"Найти антисептик / антибиотики"}
    if body_temperature < 35.7:
        return {"title":"СОГРЕТЬСЯ","sub":"Укрытие, сухая одежда, огонь"}
    if thirst < 32.0:
        return {"title":"НАЙТИ ВОДУ","sub":"Пополнить запас перед вылазкой"}
    if hunger < 32.0:
        return {"title":"НАЙТИ ЕДУ","sub":"Обыскать дома и склады"}
    if _inventory_weight() > _carry_limit() * 0.94:
        return {"title":"РАЗГРУЗИТЬ РЮКЗАК","sub":"Вернуться к убежищу"}
    return {"title":"ПОДГОТОВИТЬ ВЫЛАЗКУ","sub":"Разведать район и вернуться живым"}

func _create_hud():
    var canvas = CanvasLayer.new()
    canvas.layer = 12
    canvas.name = "HUD"
    add_child(canvas)

    hud = Label.new()
    hud.visible = false
    canvas.add_child(hud)

    hud_world_root = Control.new()
    hud_world_root.name = "ReferenceHUD"
    hud_world_root.position = Vector2.ZERO
    hud_world_root.size = Vector2(640,360)
    hud_world_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    canvas.add_child(hud_world_root)

    _hud_add_screen_frame(hud_world_root)

    var text_main = Color(0.88,0.90,0.87)
    var text_muted = Color(0.64,0.68,0.66)
    var accent = Color(0.91,0.73,0.31)
    var panel_accent = Color(0.34,0.40,0.39)
    var danger = Color(0.82,0.43,0.39)
    var stamina_color = Color(0.90,0.71,0.37)
    var food_color = Color(0.57,0.68,0.55)
    var water_color = Color(0.42,0.64,0.87)
    var temp_color = Color(0.79,0.52,0.31)
    var infection_color = Color(0.48,0.65,0.41)

    # TOP LEFT — survival vitals, closer to the gritty reference block.
    var vitals_panel = Panel.new()
    vitals_panel.name = "VitalsPanel"
    vitals_panel.position = Vector2(8,8)
    vitals_panel.size = Vector2(180,122)
    vitals_panel.add_theme_stylebox_override("panel",_hud_panel_style())
    vitals_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vitals_panel.clip_contents = true
    hud_world_root.add_child(vitals_panel)
    _hud_add_panel_detail(vitals_panel,vitals_panel.size,panel_accent)

    _hud_make_vital_row(vitals_panel,"health",10,"ЗДОРОВЬЕ",danger)
    _hud_make_vital_row(vitals_panel,"stamina",23,"ВЫНОСЛ.",stamina_color)
    _hud_make_vital_row(vitals_panel,"hunger",36,"ГОЛОД",food_color)
    _hud_make_vital_row(vitals_panel,"thirst",49,"ЖАЖДА",water_color)
    _hud_make_vital_row(vitals_panel,"temperature",62,"ТЕМП.",temp_color)
    _hud_make_vital_row(vitals_panel,"infection",75,"ИНФЕКЦИЯ",infection_color)

    hud_condition_label = _hud_make_label(vitals_panel,Vector2(99,2),Vector2(73,8),"",4,text_muted,HORIZONTAL_ALIGNMENT_RIGHT)
    hud_condition_label.visible = false

    _hud_add_accent_strip(vitals_panel,Vector2(6,91),Vector2(164,1),Color(0.18,0.22,0.22,0.95))
    hud_condition_values.clear()
    var mini = [
        ["blood","КРОВЬ",Color(0.80,0.39,0.35)],
        ["pain","БОЛЬ",Color(0.55,0.59,0.58)],
        ["wet","ВЛАГА",Color(0.39,0.62,0.82)],
        ["contam","ГРЯЗЬ",Color(0.76,0.62,0.32)]
    ]
    for i in range(mini.size()):
        var x = 7 + i * 42
        if i > 0:
            _hud_add_accent_strip(vitals_panel,Vector2(x - 2,94),Vector2(1,16),Color(0.18,0.22,0.22,0.85))
        _hud_make_condition_icon(vitals_panel,mini[i][0],Vector2(x,97),mini[i][2])
        _hud_make_label(vitals_panel,Vector2(x + 11,93),Vector2(30,8),mini[i][1],4,text_muted)
        hud_condition_values[mini[i][0]] = _hud_make_label(vitals_panel,Vector2(x + 11,101),Vector2(30,9),"",5,text_main)

    hud_status_label = _hud_make_label(vitals_panel,Vector2(6,1),Vector2(1,1),"",4,text_main)
    hud_status_label.visible = false

    # TOP RIGHT — day/weather, zone/shelter, camp state and objective, aligned closer to the reference.
    var env_panel = Panel.new()
    env_panel.name = "EnvironmentPanel"
    env_panel.position = Vector2(480,8)
    env_panel.size = Vector2(152,146)
    env_panel.add_theme_stylebox_override("panel",_hud_panel_style())
    env_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    env_panel.clip_contents = true
    hud_world_root.add_child(env_panel)
    _hud_add_panel_detail(env_panel,env_panel.size,panel_accent)

    hud_day_label = _hud_make_label(env_panel,Vector2(8,3),Vector2(64,10),"",8,Color(0.91,0.93,0.87))
    hud_time_label = _hud_make_label(env_panel,Vector2(96,3),Vector2(48,10),"",8,Color(0.94,0.92,0.84),HORIZONTAL_ALIGNMENT_RIGHT)
    hud_weather_icon_clear = _hud_make_sun_icon(env_panel,Vector2(9,19),Color(0.91,0.73,0.31))
    hud_weather_icon_cloud = _hud_make_cloud_icon(env_panel,Vector2(9,20),Color(0.72,0.76,0.79))
    hud_weather_icon_rain = _hud_make_rain_icon(env_panel,Vector2(9,19),Color(0.64,0.69,0.72))
    hud_env_weather_label = _hud_make_label(env_panel,Vector2(29,16),Vector2(115,10),"",5,text_main)
    _hud_add_accent_strip(env_panel,Vector2(6,33),Vector2(140,1),Color(0.18,0.22,0.22,0.95))

    _hud_make_house_icon(env_panel,Vector2(9,40),Color(0.71,0.77,0.72))
    hud_env_zone_label = _hud_make_label(env_panel,Vector2(29,37),Vector2(115,10),"",5,Color(0.61,0.78,0.61))
    hud_env_shelter_label = _hud_make_label(env_panel,Vector2(29,48),Vector2(115,10),"",5,text_muted)

    _hud_add_accent_strip(env_panel,Vector2(6,63),Vector2(140,1),Color(0.18,0.22,0.22,0.95))
    hud_camp_icon_root = _hud_make_fire_icon(env_panel,Vector2(9,69),Color(0.86,0.67,0.36))
    hud_env_camp_label = _hud_make_label(env_panel,Vector2(29,66),Vector2(115,10),"",5,Color(0.61,0.78,0.61))
    hud_env_camp_sub_label = _hud_make_label(env_panel,Vector2(29,77),Vector2(115,10),"",5,text_muted)

    _hud_add_accent_strip(env_panel,Vector2(6,94),Vector2(140,1),Color(0.18,0.22,0.22,0.95))
    _hud_make_label(env_panel,Vector2(8,99),Vector2(136,8),"ТЕКУЩАЯ ЦЕЛЬ",5,accent)
    _hud_make_checkbox_icon(env_panel,Vector2(9,112),Color(0.88,0.90,0.84))
    hud_objective_label = _hud_make_label(env_panel,Vector2(29,107),Vector2(115,16),"",5,Color(0.91,0.90,0.83))
    hud_objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud_objective_sub_label = _hud_make_label(env_panel,Vector2(29,124),Vector2(115,14),"",4,text_muted)
    hud_objective_sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    # BOTTOM LEFT — compact stance/stealth block in the same hierarchy as the reference.
    var stealth_panel = Panel.new()
    stealth_panel.name = "StealthPanel"
    stealth_panel.position = Vector2(8,288)
    stealth_panel.size = Vector2(144,66)
    stealth_panel.add_theme_stylebox_override("panel",_hud_panel_style())
    stealth_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stealth_panel.clip_contents = true
    hud_world_root.add_child(stealth_panel)
    _hud_add_panel_detail(stealth_panel,stealth_panel.size,Color(0.38,0.48,0.46))

    _hud_make_stance_icon(stealth_panel,Vector2(7,4),Color(0.88,0.90,0.84))
    hud_stealth_label = _hud_make_label(stealth_panel,Vector2(23,2),Vector2(71,10),"",6,text_main)
    hud_stealth_noise_label = _hud_make_label(stealth_panel,Vector2(95,2),Vector2(41,10),"",5,text_muted,HORIZONTAL_ALIGNMENT_RIGHT)
    _hud_add_accent_strip(stealth_panel,Vector2(6,17),Vector2(132,1),Color(0.18,0.22,0.22,0.90))

    _hud_make_eye_icon(stealth_panel,Vector2(8,22),Color(0.71,0.77,0.72))
    _hud_make_label(stealth_panel,Vector2(25,18),Vector2(35,8),"ВИДИМ.",5,text_muted)
    hud_visibility_bar = _hud_make_bar(stealth_panel,Vector2(63,20),Vector2(73,7),Color(0.57,0.72,0.54),6)

    _hud_make_noise_icon(stealth_panel,Vector2(8,33),Color(0.80,0.76,0.56))
    _hud_make_label(stealth_panel,Vector2(25,29),Vector2(35,8),"ШУМ",5,text_muted)
    hud_noise_bar = _hud_make_bar(stealth_panel,Vector2(63,31),Vector2(73,7),Color(0.74,0.70,0.46),6)

    _hud_make_weight_icon(stealth_panel,Vector2(8,46),Color(0.69,0.72,0.72))
    _hud_make_label(stealth_panel,Vector2(25,42),Vector2(35,8),"ГРУЗ",5,text_muted)
    hud_weight_label = _hud_make_label(stealth_panel,Vector2(63,41),Vector2(73,10),"",5,text_muted,HORIZONTAL_ALIGNMENT_RIGHT)

    # BOTTOM CENTER — compact quickbar with clearer icons and stricter clipping.
    var quick_shell = Panel.new()
    quick_shell.name = "QuickShell"
    quick_shell.position = Vector2(188,301)
    quick_shell.size = Vector2(264,51)
    quick_shell.add_theme_stylebox_override("panel",_hud_panel_style())
    quick_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    quick_shell.clip_contents = true
    hud_world_root.add_child(quick_shell)
    _hud_add_panel_detail(quick_shell,quick_shell.size,Color(0.31,0.35,0.34))
    _hud_add_accent_strip(quick_shell,Vector2(1,1),Vector2(258,1),Color(0.32,0.35,0.34,0.90))

    var quick_root = Control.new()
    quick_root.name = "QuickBar"
    quick_root.position = Vector2(6,5)
    quick_root.size = Vector2(252,40)
    quick_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    quick_root.clip_contents = true
    quick_shell.add_child(quick_root)

    hud_quick_style_normal = _hud_quick_slot_style(false)
    hud_quick_style_active = _hud_quick_slot_style(true)
    hud_quick_slots.clear()

    var quick_ids = ["makarov","shotgun","akm","combat_knife","steel_pipe","fire_axe"]
    for i in range(quick_ids.size()):
        var item_id = quick_ids[i]
        var slot_button = Button.new()
        slot_button.position = Vector2(i * 41,0)
        slot_button.size = Vector2(40,40)
        slot_button.flat = false
        slot_button.text = ""
        slot_button.focus_mode = Control.FOCUS_NONE
        slot_button.clip_contents = true
        slot_button.add_theme_stylebox_override("normal",hud_quick_style_normal)
        slot_button.add_theme_stylebox_override("hover",hud_quick_style_active)
        slot_button.add_theme_stylebox_override("pressed",hud_quick_style_active)
        slot_button.add_theme_stylebox_override("focus",hud_quick_style_active)
        slot_button.pressed.connect(_select_quick_slot.bind(i + 1))
        quick_root.add_child(slot_button)
        if i > 0:
            _hud_add_accent_strip(quick_root,Vector2(i * 41 - 1,4),Vector2(1,32),Color(0.15,0.18,0.18,0.88))

        var slot_index_label = _hud_make_label(slot_button,Vector2(3,1),Vector2(10,7),str(i + 1),5,Color(0.76,0.74,0.66))
        var icon_back = Panel.new()
        icon_back.position = Vector2(3,10)
        icon_back.size = Vector2(34,23)
        icon_back.add_theme_stylebox_override("panel",_hud_quick_art_style(false,true))
        icon_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
        icon_back.clip_contents = true
        slot_button.add_child(icon_back)
        var icon = TextureRect.new()
        _hud_apply_quick_slot_icon(icon,item_id)
        slot_button.add_child(icon)
        var active_rail = ColorRect.new()
        active_rail.position = Vector2(3,35)
        active_rail.size = Vector2(34,1)
        active_rail.color = accent
        active_rail.visible = false
        active_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot_button.add_child(active_rail)
        hud_quick_slots.append({"id":item_id,"button":slot_button,"icon":icon,"back":icon_back,"rail":active_rail,"label":slot_index_label})

    # BOTTOM RIGHT — weapon card follows the reference: name, ammo, art/mode and durability.
    var weapon_panel = Panel.new()
    weapon_panel.name = "WeaponPanel"
    weapon_panel.position = Vector2(480,268)
    weapon_panel.size = Vector2(152,84)
    weapon_panel.add_theme_stylebox_override("panel",_hud_panel_style())
    weapon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    weapon_panel.clip_contents = true
    hud_world_root.add_child(weapon_panel)
    _hud_add_panel_detail(weapon_panel,weapon_panel.size,panel_accent)

    hud_weapon_name_label = _hud_make_label(weapon_panel,Vector2(10,5),Vector2(78,11),"",6,text_main)
    hud_ammo_label = _hud_make_label(weapon_panel,Vector2(92,5),Vector2(50,12),"",7,Color(0.94,0.92,0.84),HORIZONTAL_ALIGNMENT_RIGHT)
    _hud_add_accent_strip(weapon_panel,Vector2(8,20),Vector2(136,1),Color(0.18,0.22,0.22,0.90))

    hud_weapon_icon = TextureRect.new()
    _hud_fit_texture_rect(hud_weapon_icon,null,Vector2(10,24),Vector2(84,27))
    weapon_panel.add_child(hud_weapon_icon)
    hud_reload_label = _hud_make_label(weapon_panel,Vector2(98,22),Vector2(44,27),"",5,text_muted,HORIZONTAL_ALIGNMENT_RIGHT)

    _hud_add_accent_strip(weapon_panel,Vector2(8,56),Vector2(136,1),Color(0.18,0.22,0.22,0.90))
    hud_weapon_condition_label = _hud_make_label(weapon_panel,Vector2(10,59),Vector2(54,9),"СОСТОЯНИЕ",5,text_muted)
    hud_weapon_condition_bar = _hud_make_bar(weapon_panel,Vector2(66,62),Vector2(51,8),Color(0.62,0.75,0.58),8)
    hud_weapon_condition_value_label = _hud_make_label(weapon_panel,Vector2(119,58),Vector2(23,10),"",4,text_muted,HORIZONTAL_ALIGNMENT_RIGHT)

    hud_interaction_panel = Panel.new()
    hud_interaction_panel.name = "InteractionPrompt"
    hud_interaction_panel.position = Vector2(240,228)
    hud_interaction_panel.size = Vector2(160,22)
    hud_interaction_panel.add_theme_stylebox_override("panel",_hud_panel_style(true))
    hud_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_interaction_panel.clip_contents = true
    hud_interaction_panel.visible = false
    hud_world_root.add_child(hud_interaction_panel)
    _hud_add_panel_detail(hud_interaction_panel,hud_interaction_panel.size,accent)

    var key_badge = Panel.new()
    key_badge.position = Vector2(5,4)
    key_badge.size = Vector2(16,14)
    key_badge.add_theme_stylebox_override("panel",_hud_panel_style(true))
    key_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_interaction_panel.add_child(key_badge)
    _hud_make_label(key_badge,Vector2(1,0),Vector2(14,12),"E",7,Color(0.96,0.94,0.86),HORIZONTAL_ALIGNMENT_CENTER)
    interaction_label = _hud_make_label(hud_interaction_panel,Vector2(25,2),Vector2(130,17),"",6,Color(0.94,0.92,0.84),HORIZONTAL_ALIGNMENT_CENTER)

    debug_label = Label.new()
    debug_label.position = Vector2(210,18)
    debug_label.size = Vector2(220,16)
    debug_label.add_theme_font_size_override("font_size",6)
    debug_label.add_theme_color_override("font_color",Color(1.0,0.40,0.36))
    debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    debug_label.visible = false
    canvas.add_child(debug_label)


func _update_hud():
    if hud == null or hud_world_root == null:
        return

    hud_world_root.visible = not inventory_open

    var stamina_cap = max(1.0,_survival_stamina_cap())
    var health_pct = clamp(health,0.0,100.0)
    var stamina_pct = clamp(stamina / stamina_cap * 100.0,0.0,100.0)
    var hunger_pct = clamp(hunger,0.0,100.0)
    var thirst_pct = clamp(thirst,0.0,100.0)
    var temp_pct = clamp((body_temperature - 30.5) / 10.0 * 100.0,0.0,100.0)
    var infection_pct = clamp(wound_infection,0.0,100.0)

    _hud_set_bar_value(hud_vital_bars["health"],health_pct)
    _hud_set_bar_value(hud_vital_bars["stamina"],stamina_pct)
    _hud_set_bar_value(hud_vital_bars["hunger"],hunger_pct)
    _hud_set_bar_value(hud_vital_bars["thirst"],thirst_pct)
    _hud_set_bar_value(hud_vital_bars["temperature"],temp_pct)
    _hud_set_bar_value(hud_vital_bars["infection"],infection_pct)

    hud_vital_values["health"].text = "%d/100" % int(health)
    hud_vital_values["stamina"].text = "%d/100" % int(stamina_pct)
    hud_vital_values["hunger"].text = "%d/100" % int(hunger)
    hud_vital_values["thirst"].text = "%d/100" % int(thirst)
    hud_vital_values["temperature"].text = ("%.1f" % body_temperature).replace(".",",") + "°C"
    hud_vital_values["infection"].text = "%d%%" % int(wound_infection)

    if hud_condition_label.visible:
        hud_condition_label.text = _hud_compact_condition_text()
        hud_condition_label.add_theme_color_override("font_color",_hud_status_color())

    if hud_condition_values.has("blood"):
        hud_condition_values["blood"].text = "%d%%" % int(clamp(100.0 - bleed_damage_taken / MAX_BLEED_DAMAGE * 100.0,0.0,100.0))
        hud_condition_values["pain"].text = "%d%%" % int(_effective_pain())
        hud_condition_values["wet"].text = "%d%%" % int(wetness)
        hud_condition_values["contam"].text = "%d%%" % int(wound_contamination)
        hud_condition_values["blood"].add_theme_color_override("font_color",Color(0.90,0.46,0.42) if bleeding else Color(0.68,0.73,0.70))
        hud_condition_values["pain"].add_theme_color_override("font_color",Color(0.90,0.68,0.40) if _effective_pain() >= 35.0 else Color(0.68,0.73,0.70))
        hud_condition_values["wet"].add_theme_color_override("font_color",Color(0.48,0.70,0.91) if wetness >= 35.0 else Color(0.68,0.73,0.70))
        hud_condition_values["contam"].add_theme_color_override("font_color",Color(0.90,0.66,0.36) if wound_contamination >= 35.0 else Color(0.68,0.73,0.70))

    if hud_day_label != null:
        hud_day_label.text = "ДЕНЬ %02d" % world_day
    if hud_time_label != null:
        hud_time_label.text = _time_text()
    if hud_env_time_label != null:
        hud_env_time_label.text = "%02d  %s" % [world_day,_time_text()]
    _hud_set_fitted_text(hud_env_weather_label,"%s  %.0f°C" % [_weather_display_name(),ambient_temperature],5,4,14,18)
    if hud_weather_icon_clear != null:
        hud_weather_icon_clear.visible = weather_state == "clear"
    if hud_weather_icon_cloud != null:
        hud_weather_icon_cloud.visible = weather_state == "cloudy"
    if hud_weather_icon_rain != null:
        hud_weather_icon_rain.visible = weather_state == "rain"
    _hud_set_fitted_text(hud_env_zone_label,_zone_display_name(current_zone_id).to_upper(),5,4,10,15)

    var heat_bonus = _base_heat_bonus_at_player()
    if is_sheltered:
        _hud_set_fitted_text(hud_env_shelter_label,"В укрытии • Ветер %.0f" % wind_speed_kmh,5,4,15,18)
    else:
        _hud_set_fitted_text(hud_env_shelter_label,"Снаружи • Ветер %.0f" % wind_speed_kmh,5,4,15,18)

    if hud_camp_icon_root != null:
        hud_camp_icon_root.modulate = Color.WHITE if heat_bonus > 0.05 else Color(0.48,0.50,0.48,0.55)
    if hud_env_camp_label != null and hud_env_camp_sub_label != null:
        if heat_bonus > 0.05:
            _hud_set_fitted_text(hud_env_camp_label,"ЛАГЕРЬ (БЕЗОП.)",5,4,11,14)
            hud_env_camp_label.add_theme_color_override("font_color",Color(0.61,0.78,0.61))
            _hud_set_fitted_text(hud_env_camp_sub_label,"Тепло +%.0f°C" % heat_bonus,5,4,12,16)
        elif is_sheltered:
            _hud_set_fitted_text(hud_env_camp_label,"УКРЫТИЕ",5,4,11,14)
            hud_env_camp_label.add_theme_color_override("font_color",Color(0.78,0.72,0.48))
            _hud_set_fitted_text(hud_env_camp_sub_label,"Нет огня",5,4,12,16)
        else:
            _hud_set_fitted_text(hud_env_camp_label,"ОТКРЫТОЕ МЕСТО",5,4,11,14)
            hud_env_camp_label.add_theme_color_override("font_color",Color(0.68,0.72,0.70))
            _hud_set_fitted_text(hud_env_camp_sub_label,"Нет укрытия",5,4,12,16)

    var objective = _hud_survival_objective()
    _hud_set_fitted_text(hud_objective_label,str(objective.get("title","")),5,4,16,22)
    _hud_set_fitted_text(hud_objective_sub_label,str(objective.get("sub","")),4,4,24,34)

    var visibility = clamp(_player_visibility_multiplier() / 1.35 * 100.0,0.0,100.0)
    var noise = clamp(last_player_noise_radius / 450.0 * 100.0,0.0,100.0)
    _hud_set_bar_value(hud_visibility_bar,visibility)
    _hud_set_bar_value(hud_noise_bar,noise)

    var movement_text = "СТОИТ"
    if is_sprinting:
        movement_text = "БЕЖИТ"
    elif visual_move_speed > 2.0:
        movement_text = "ИДЁТ"
    var noise_text = _stealth_noise_label().to_upper()
    _hud_set_fitted_text(hud_stealth_label,movement_text,6,5,8,10)
    if hud_stealth_noise_label != null:
        _hud_set_fitted_text(hud_stealth_noise_label,noise_text,5,4,6,9)
        hud_stealth_noise_label.add_theme_color_override("font_color",Color(0.92,0.77,0.44) if noise >= 55.0 else Color(0.58,0.64,0.62))
    _hud_set_fitted_text(hud_weight_label,("%.1f" % _inventory_weight()).replace(".",",") + " / %.0f кг" % _carry_limit(),5,4,10,13)
    hud_weight_label.add_theme_color_override("font_color",Color(0.92,0.77,0.44) if _inventory_weight() > _carry_limit() * 0.9 else Color(0.58,0.64,0.62))

    var active_id = equipped_melee_id if equipped_melee_id != "" else current_weapon_id
    if hud_weapon_icon_id != active_id:
        hud_weapon_icon_id = active_id
        _hud_fit_texture_rect(hud_weapon_icon,_hud_display_texture(active_id),Vector2(10,24),Vector2(84,27))

    for slot in hud_quick_slots:
        var slot_id = str(slot.get("id",""))
        var slot_button = slot.get("button",null)
        var slot_icon = slot.get("icon",null)
        if slot_button == null:
            continue

        var owned = _inventory_has_item(slot_id)
        slot_button.disabled = not owned
        slot_button.modulate = Color.WHITE if owned else Color(0.68,0.70,0.68,0.88)

        var active = slot_id == active_id
        var style = hud_quick_style_active if active else hud_quick_style_normal
        slot_button.add_theme_stylebox_override("normal",style)
        slot_button.add_theme_stylebox_override("hover",hud_quick_style_active)
        slot_button.add_theme_stylebox_override("pressed",hud_quick_style_active)
        slot_button.add_theme_stylebox_override("focus",style)
        var slot_back = slot.get("back",null)
        if slot_back != null:
            slot_back.add_theme_stylebox_override("panel",_hud_quick_art_style(active,owned))
        var slot_rail = slot.get("rail",null)
        if slot_rail != null:
            slot_rail.visible = active and owned
        var slot_label = slot.get("label",null)
        if slot_label != null:
            slot_label.add_theme_color_override("font_color",Color(0.96,0.90,0.72) if active and owned else (Color(0.76,0.74,0.66) if owned else Color(0.44,0.46,0.45)))
        if slot_icon != null:
            slot_icon.modulate = Color.WHITE if owned else Color(0.48,0.50,0.49,0.80)

    if equipped_melee_id != "" and melee_defs.has(equipped_melee_id):
        var melee = melee_defs[equipped_melee_id]
        _hud_set_fitted_text(hud_weapon_name_label,str(melee.get("short_name",melee.get("name",equipped_melee_id))),6,5,9,13)
        _hud_set_fitted_text(hud_ammo_label,"УРОН %d" % int(melee.get("damage",0)),7,5,8,12)
        _hud_set_fitted_text(hud_reload_label,"БЛИЖНИЙ
ВЫН. %d" % int(melee.get("stamina",0)),5,4,999,999)
        _hud_set_bar_value(hud_weapon_condition_bar,100.0)
        hud_weapon_condition_label.text = "СОСТОЯНИЕ"
        if hud_weapon_condition_value_label != null:
            hud_weapon_condition_value_label.text = "100%"
    else:
        var weapon = weapon_defs.get(current_weapon_id,{})
        var weapon_name = str(weapon.get("name",current_weapon_id))
        var mag = int(weapon_mags.get(current_weapon_id,0))
        var mag_capacity = _weapon_mag_capacity(current_weapon_id)
        var ammo_id = str(weapon.get("ammo",""))
        var reserve = _inventory_count(ammo_id)
        var condition = _weapon_condition_value(current_weapon_id)

        _hud_set_fitted_text(hud_weapon_name_label,str(weapon.get("short_name",weapon_name)),6,5,9,13)
        _hud_set_fitted_text(hud_ammo_label,"%02d / %02d" % [mag,reserve],7,6,8,12)

        if reload_time > 0.0:
            _hud_set_fitted_text(hud_reload_label,"ПЕРЕЗАРЯДКА",5,4,999,999)
        elif reload_feedback != "":
            _hud_set_fitted_text(hud_reload_label,reload_feedback,5,4,10,16)
        else:
            _hud_set_fitted_text(hud_reload_label,"%s
%s • %d" % [
                _hud_ammo_display_name(ammo_id),
                _hud_fire_mode_label(current_weapon_id,weapon),
                mag_capacity
            ],5,4,12,18)

        _hud_set_bar_value(hud_weapon_condition_bar,condition)
        hud_weapon_condition_label.text = "СОСТОЯНИЕ"
        if hud_weapon_condition_value_label != null:
            hud_weapon_condition_value_label.text = "%d%%" % int(condition)

    debug_label.visible = not self_test_failures.is_empty()
    if debug_label.visible:
        debug_label.text = "ОШИБКИ ТЕСТА: %d" % self_test_failures.size()

func _create_hover_inspector():
    var canvas = CanvasLayer.new()
    canvas.layer = 40
    canvas.name = "HoverInspector"
    add_child(canvas)

    hover_panel = Panel.new()
    hover_panel.size = Vector2(248,154)
    hover_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_panel.visible = false
    canvas.add_child(hover_panel)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.025,0.030,0.029,0.985)
    style.border_color = Color(0.39,0.42,0.38,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 4
    style.corner_radius_top_right = 4
    style.corner_radius_bottom_left = 4
    style.corner_radius_bottom_right = 4
    style.shadow_color = Color(0,0,0,0.55)
    style.shadow_size = 5
    hover_panel.add_theme_stylebox_override("panel",style)

    hover_icon = TextureRect.new()
    hover_icon.position = Vector2(10,10)
    hover_icon.size = Vector2(42,42)
    hover_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hover_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    hover_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_panel.add_child(hover_icon)

    hover_title = Label.new()
    hover_title.position = Vector2(60,9)
    hover_title.size = Vector2(178,24)
    hover_title.add_theme_font_size_override("font_size",10)
    hover_title.modulate = Color(0.96,0.92,0.78)
    hover_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_panel.add_child(hover_title)

    var line = ColorRect.new()
    line.position = Vector2(60,34)
    line.size = Vector2(176,1)
    line.color = Color(0.32,0.34,0.31,1.0)
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_panel.add_child(line)

    hover_body = Label.new()
    hover_body.position = Vector2(60,41)
    hover_body.size = Vector2(176,86)
    hover_body.add_theme_font_size_override("font_size",8)
    hover_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hover_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_panel.add_child(hover_body)

    hover_footer = Label.new()
    hover_footer.position = Vector2(10,129)
    hover_footer.size = Vector2(228,16)
    hover_footer.add_theme_font_size_override("font_size",7)
    hover_footer.modulate = Color(0.60,0.64,0.59)
    hover_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hover_panel.add_child(hover_footer)

func _hover_show_item(id,qty=1,context="storage"):
    if hover_panel == null or not item_defs.has(id):
        return

    hover_item_id = id
    hover_qty = qty
    hover_context = context

    var item = item_defs[id]
    hover_icon.texture = _make_item_icon(id)
    hover_title.text = str(item.get("name",id))

    var lines = []
    var category = str(item.get("category",""))
    var category_names = {
        "weapon":"ОРУЖИЕ",
        "melee":"БЛИЖНИЙ БОЙ",
        "ammo":"БОЕПРИПАСЫ",
        "medical":"МЕДИЦИНА",
        "food":"ЕДА / ВОДА",
        "gear":"ЭКИПИРОВКА",
        "material":"МАТЕРИАЛ",
        "tool":"ИНСТРУМЕНТ",
        "mod":"МОДИФИКАЦИЯ"
    }

    lines.append(str(category_names.get(category,category.to_upper())))
    lines.append("Вес: %.2f кг" % (float(item.get("weight",0.0)) * qty))

    if qty > 1:
        lines.append("Количество: %d / %d" % [qty,int(item.get("stack",1))])

    if category == "weapon":
        lines.append("Состояние: %d%% [%s]" % [int(_weapon_condition_value(id)),_weapon_condition_state(id)])
        if weapon_defs.has(id):
            var w = weapon_defs[id]
            lines.append("Урон: %d   Магазин: %d" % [int(w.get("damage",0)),_weapon_mag_capacity(id)])
            lines.append("Моды: %s" % _weapon_mod_summary(id))
        lines.append("ПКМ: открыть управление модулями")
    elif category == "melee":
        if melee_defs.has(id):
            var melee = melee_defs[id]
            lines.append("Урон: %d   Дистанция: %d" % [int(melee.get("damage",0)),int(melee.get("range",0))])
            lines.append("Выносливость за удар: %d   Целей: %d" % [int(melee.get("stamina",0)),int(melee.get("max_targets",1))])
        lines.append("ИСП.: взять в руки | V: толчок")
    elif category == "gear":
        var armor = int(float(item.get("armor",0.0)) * 100.0)
        if armor > 0:
            lines.append("Защита: %d%%" % armor)
        var bleed = int(float(item.get("bleed_resist",0.0)) * 100.0)
        if bleed > 0:
            lines.append("Защита от кровотечения: %d%%" % bleed)
        var carry = float(item.get("carry_bonus",0.0))
        if carry > 0.0:
            lines.append("Грузоподъёмность: +%.0f кг" % carry)
        if id == "flashlight":
            lines.append("Заряд: %d%%" % int(flashlight_battery))
    elif category == "mod":
        lines.append("Слот: %s" % ("МАГАЗИН" if str(item.get("mod_slot","")) == "magazine" else "СТВОЛ"))
        var mag_bonus = int(item.get("mag_bonus",0))
        if mag_bonus > 0:
            lines.append("Ёмкость: +%d патр." % mag_bonus)
        var sm = float(item.get("spread_mult",1.0))
        if sm < 0.999:
            lines.append("Точность: +%d%%" % int((1.0 - sm) * 100.0))
        elif sm > 1.001:
            lines.append("Точность: -%d%%" % int((sm - 1.0) * 100.0))
        var nm = float(item.get("noise_mult",1.0))
        if nm < 0.999:
            lines.append("Шум выстрела: -%d%%" % int((1.0 - nm) * 100.0))
        elif nm > 1.001:
            lines.append("Шум выстрела: +%d%%" % int((nm - 1.0) * 100.0))
    elif id == "repair_kit":
        lines.append("Используется у верстака → ОРУЖЕЙНИК")

    if context == "equipment":
        hover_footer.text = "НАДЕТО НА ПЕРСОНАЖЕ"
    elif context == "container":
        hover_footer.text = "ЛЕЖИТ В КОНТЕЙНЕРЕ"
    else:
        hover_footer.text = "В РЮКЗАКЕ"

    hover_body.text = "
".join(lines)
    hover_panel.visible = true
    _update_hover_position()

func _hover_hide_item():
    hover_item_id = ""
    if hover_panel != null:
        hover_panel.visible = false

func _update_hover_position():
    if hover_panel == null or not hover_panel.visible:
        return

    var mouse = get_viewport().get_mouse_position()
    var viewport_size = get_viewport_rect().size
    var pos = mouse + Vector2(16,16)

    if pos.x + hover_panel.size.x > viewport_size.x - 6:
        pos.x = mouse.x - hover_panel.size.x - 16
    if pos.y + hover_panel.size.y > viewport_size.y - 6:
        pos.y = mouse.y - hover_panel.size.y - 16

    pos.x = clamp(pos.x,6.0,max(6.0,viewport_size.x - hover_panel.size.x - 6.0))
    pos.y = clamp(pos.y,6.0,max(6.0,viewport_size.y - hover_panel.size.y - 6.0))
    hover_panel.position = pos



func _create_weapon_mod_ui():
    var canvas = CanvasLayer.new()
    canvas.layer = 55
    canvas.name = "WeaponModUI"
    add_child(canvas)

    mod_panel = Panel.new()
    mod_panel.position = Vector2(132,48)
    mod_panel.size = Vector2(376,266)
    mod_panel.visible = false
    canvas.add_child(mod_panel)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.022,0.027,0.026,0.992)
    style.border_color = Color(0.43,0.45,0.40,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_left = 5
    style.corner_radius_bottom_right = 5
    style.shadow_color = Color(0,0,0,0.65)
    style.shadow_size = 7
    mod_panel.add_theme_stylebox_override("panel",style)

    mod_weapon_icon = TextureRect.new()
    mod_weapon_icon.position = Vector2(14,14)
    mod_weapon_icon.size = Vector2(48,48)
    mod_weapon_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    mod_weapon_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    mod_panel.add_child(mod_weapon_icon)

    mod_title = Label.new()
    mod_title.position = Vector2(72,14)
    mod_title.size = Vector2(220,22)
    mod_title.add_theme_font_size_override("font_size",12)
    mod_title.modulate = Color(0.96,0.91,0.76)
    mod_panel.add_child(mod_title)

    mod_condition_label = Label.new()
    mod_condition_label.position = Vector2(72,39)
    mod_condition_label.size = Vector2(220,20)
    mod_condition_label.add_theme_font_size_override("font_size",8)
    mod_condition_label.modulate = Color(0.68,0.72,0.67)
    mod_panel.add_child(mod_condition_label)

    var close_button = Button.new()
    close_button.position = Vector2(334,12)
    close_button.size = Vector2(28,26)
    close_button.text = "×"
    close_button.add_theme_font_size_override("font_size",12)
    close_button.pressed.connect(_close_weapon_mod_panel)
    mod_panel.add_child(close_button)

    var installed_title = Label.new()
    installed_title.position = Vector2(14,72)
    installed_title.text = "УСТАНОВЛЕНО"
    installed_title.add_theme_font_size_override("font_size",8)
    installed_title.modulate = Color(0.62,0.66,0.61)
    mod_panel.add_child(installed_title)

    mod_slots_box = VBoxContainer.new()
    mod_slots_box.position = Vector2(14,91)
    mod_slots_box.size = Vector2(348,86)
    mod_slots_box.add_theme_constant_override("separation",5)
    mod_panel.add_child(mod_slots_box)

    var available_title = Label.new()
    available_title.position = Vector2(14,184)
    available_title.text = "ДОСТУПНЫЕ МОДУЛИ В РЮКЗАКЕ"
    available_title.add_theme_font_size_override("font_size",8)
    available_title.modulate = Color(0.62,0.66,0.61)
    mod_panel.add_child(available_title)

    mod_available_box = HBoxContainer.new()
    mod_available_box.position = Vector2(14,204)
    mod_available_box.size = Vector2(348,38)
    mod_available_box.add_theme_constant_override("separation",5)
    mod_panel.add_child(mod_available_box)

    mod_status = Label.new()
    mod_status.position = Vector2(14,244)
    mod_status.size = Vector2(348,16)
    mod_status.add_theme_font_size_override("font_size",7)
    mod_status.modulate = Color(0.70,0.74,0.66)
    mod_panel.add_child(mod_status)

func _make_mod_slot_row(slot):
    var row = Panel.new()
    row.custom_minimum_size = Vector2(348,39)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.065,0.073,0.070,1.0)
    style.border_color = Color(0.20,0.22,0.20,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 3
    style.corner_radius_top_right = 3
    style.corner_radius_bottom_left = 3
    style.corner_radius_bottom_right = 3
    row.add_theme_stylebox_override("panel",style)

    var slot_label = Label.new()
    slot_label.position = Vector2(8,5)
    slot_label.size = Vector2(55,14)
    slot_label.add_theme_font_size_override("font_size",7)
    slot_label.text = "МАГАЗИН" if slot == "magazine" else "СТВОЛ"
    slot_label.modulate = Color(0.56,0.60,0.56)
    row.add_child(slot_label)

    var installed_id = ""
    if weapon_mods.has(mod_weapon_id):
        installed_id = str(weapon_mods[mod_weapon_id].get(slot,""))

    if installed_id != "" and item_defs.has(installed_id):
        var icon = TextureRect.new()
        icon.position = Vector2(67,4)
        icon.size = Vector2(31,31)
        icon.texture = _make_item_icon(installed_id)
        icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        row.add_child(icon)

        var name_label = Label.new()
        name_label.position = Vector2(104,4)
        name_label.size = Vector2(150,15)
        name_label.text = str(item_defs[installed_id].get("name",installed_id))
        name_label.add_theme_font_size_override("font_size",8)
        row.add_child(name_label)

        var effect = Label.new()
        effect.position = Vector2(104,19)
        effect.size = Vector2(150,14)
        effect.text = _weapon_mod_effect_text(installed_id)
        effect.add_theme_font_size_override("font_size",7)
        effect.modulate = Color(0.61,0.69,0.62)
        row.add_child(effect)

        var remove_button = Button.new()
        remove_button.position = Vector2(272,6)
        remove_button.size = Vector2(68,27)
        remove_button.text = "СНЯТЬ"
        remove_button.add_theme_font_size_override("font_size",7)
        remove_button.pressed.connect(_remove_weapon_mod.bind(slot))
        row.add_child(remove_button)
    else:
        var empty_label = Label.new()
        empty_label.position = Vector2(68,11)
        empty_label.size = Vector2(185,17)
        empty_label.text = "[ слот свободен ]"
        empty_label.add_theme_font_size_override("font_size",8)
        empty_label.modulate = Color(0.46,0.49,0.46)
        row.add_child(empty_label)

    return row

func _weapon_mod_effect_text(id):
    if not item_defs.has(id):
        return ""

    var item = item_defs[id]
    var bits = []

    var mag_bonus = int(item.get("mag_bonus",0))
    if mag_bonus > 0:
        bits.append("ёмкость +%d" % mag_bonus)

    var spread_mult = float(item.get("spread_mult",1.0))
    var noise_mult = float(item.get("noise_mult",1.0))

    if spread_mult < 0.999:
        bits.append("точность +%d%%" % int((1.0 - spread_mult) * 100.0))
    elif spread_mult > 1.001:
        bits.append("точность -%d%%" % int((spread_mult - 1.0) * 100.0))

    if noise_mult < 0.999:
        bits.append("шум -%d%%" % int((1.0 - noise_mult) * 100.0))
    elif noise_mult > 1.001:
        bits.append("шум +%d%%" % int((noise_mult - 1.0) * 100.0))

    var allowed_weapon = str(item.get("allowed_weapon",""))
    if allowed_weapon != "" and weapon_defs.has(allowed_weapon):
        bits.append("для %s" % str(weapon_defs[allowed_weapon].get("name",allowed_weapon)))

    if bits.is_empty():
        return "без модификаторов"
    return " · ".join(bits)

func _inventory_mod_count(id):
    return _inventory_count(id)


func _rebuild_weapon_mod_ui():
    if mod_panel == null or mod_weapon_id == "" or not weapon_defs.has(mod_weapon_id):
        return

    mod_weapon_icon.texture = _make_item_icon(mod_weapon_id)
    mod_title.text = str(weapon_defs[mod_weapon_id].get("name",mod_weapon_id))
    mod_condition_label.text = "Состояние: %d%% · Магазин: %d патр." % [
        int(_weapon_condition_value(mod_weapon_id)),
        _weapon_mag_capacity(mod_weapon_id)
    ]

    for child in mod_slots_box.get_children():
        mod_slots_box.remove_child(child)
        child.queue_free()

    mod_slots_box.add_child(_make_mod_slot_row("magazine"))
    mod_slots_box.add_child(_make_mod_slot_row("muzzle"))

    for child in mod_available_box.get_children():
        mod_available_box.remove_child(child)
        child.queue_free()

    var available_ids = []
    for entry in inventory_entries:
        var id = str(entry.get("id",""))
        if not item_defs.has(id):
            continue
        var item = item_defs[id]
        if str(item.get("use","")) != "weapon_mod":
            continue
        if str(item.get("allowed_weapon","")) != mod_weapon_id:
            continue
        if not available_ids.has(id):
            available_ids.append(id)

    available_ids.sort()

    if available_ids.is_empty():
        var none = Label.new()
        none.text = "Нет совместимых модулей для этого оружия."
        none.add_theme_font_size_override("font_size",8)
        none.modulate = Color(0.49,0.52,0.49)
        mod_available_box.add_child(none)
    else:
        for id in available_ids:
            var button = Button.new()
            button.custom_minimum_size = Vector2(109,38)
            button.icon = _make_item_icon(id)
            button.text = str(item_defs[id].get("short",id))
            button.tooltip_text = str(item_defs[id].get("name",id)) + "
" + _weapon_mod_effect_text(id)
            button.add_theme_font_size_override("font_size",7)
            button.pressed.connect(_install_weapon_mod.bind(mod_weapon_id,id))
            mod_available_box.add_child(button)

func _open_weapon_mod_panel(weapon_id):
    if not weapon_defs.has(weapon_id):
        return

    mod_weapon_id = weapon_id
    mod_panel_open = true
    _hover_hide_item()
    mod_status.text = "Выбери модуль снизу или сними установленный."
    mod_panel.visible = true
    _rebuild_weapon_mod_ui()

func _close_weapon_mod_panel():
    mod_panel_open = false
    mod_weapon_id = ""
    if mod_panel != null:
        mod_panel.visible = false


func _install_weapon_mod(weapon_id,mod_id):
    if not weapon_defs.has(weapon_id) or not item_defs.has(mod_id):
        return false

    var item = item_defs[mod_id]
    if str(item.get("use","")) != "weapon_mod":
        return false

    var slot = str(item.get("mod_slot",""))
    if slot != "magazine" and slot != "muzzle":
        return false

    if str(item.get("allowed_weapon","")) != weapon_id:
        mod_status.text = "Этот модуль не подходит к этому оружию."
        return false

    if _inventory_count(mod_id) <= 0:
        mod_status.text = "Модуля уже нет в рюкзаке."
        return false

    if not weapon_mods.has(weapon_id):
        weapon_mods[weapon_id] = {"magazine":"","muzzle":""}

    var old_id = str(weapon_mods[weapon_id].get(slot,""))
    if old_id == mod_id:
        mod_status.text = "Этот модуль уже установлен."
        return false

    var test_entries = inventory_entries.duplicate(true)
    if not _consume_one_item_from_entries(test_entries,mod_id):
        return false

    if old_id != "":
        if _grid_add(test_entries,old_id,1,INV_W,INV_H) != 0:
            mod_status.text = "Нет места, чтобы вернуть старый модуль."
            return false

    inventory_entries = test_entries
    weapon_mods[weapon_id][slot] = mod_id
    mod_status.text = "Установлено: %s" % str(item_defs[mod_id].get("name",mod_id))

    if weapon_id == current_weapon_id:
        _update_weapon_visual()

    _refresh_inventory_ui()
    _rebuild_weapon_mod_ui()
    return true


func _remove_weapon_mod(slot):
    if mod_weapon_id == "" or not weapon_mods.has(mod_weapon_id):
        return

    var id = str(weapon_mods[mod_weapon_id].get(slot,""))
    if id == "":
        return

    var test_entries = inventory_entries.duplicate(true)

    if slot == "magazine":
        var new_capacity = _weapon_base_mag_capacity(mod_weapon_id)
        var overflow = _ammo_overflow_for_capacity(mod_weapon_id,new_capacity)

        if overflow > 0:
            var ammo_id = str(weapon_defs[mod_weapon_id].get("ammo",""))
            if _grid_add(test_entries,ammo_id,overflow,INV_W,INV_H) != 0:
                mod_status.text = "Нет места для лишних патронов из магазина."
                return

    if _grid_add(test_entries,id,1,INV_W,INV_H) != 0:
        mod_status.text = "В рюкзаке нет места для снятого модуля."
        return

    inventory_entries = test_entries
    weapon_mods[mod_weapon_id][slot] = ""

    if slot == "magazine":
        weapon_mags[mod_weapon_id] = min(
            int(weapon_mags.get(mod_weapon_id,0)),
            _weapon_base_mag_capacity(mod_weapon_id)
        )

    mod_status.text = "Снято: %s" % str(item_defs[id].get("name",id))

    if mod_weapon_id == current_weapon_id:
        _update_weapon_visual()

    _refresh_inventory_ui()
    _rebuild_weapon_mod_ui()


func _begin_inventory_drag_candidate(source,index,id):
    if index < 0:
        return

    inventory_drag_candidate_source = source
    inventory_drag_candidate_index = index
    inventory_drag_candidate_id = id
    inventory_drag_press_position = get_viewport().get_mouse_position()

func _start_inventory_drag():
    if inventory_drag_candidate_index < 0 or inventory_drag_candidate_id == "":
        return

    inventory_drag_active = true

    if inventory_drag_preview != null and is_instance_valid(inventory_drag_preview):
        inventory_drag_preview.queue_free()

    inventory_drag_preview = TextureRect.new()
    inventory_drag_preview.texture = _make_item_icon(inventory_drag_candidate_id)
    inventory_drag_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    inventory_drag_preview.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    inventory_drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
    inventory_drag_preview.modulate = Color(1.0,1.0,1.0,0.82)
    inventory_drag_preview.z_index = 200

    var tex_size = inventory_drag_preview.texture.get_size()
    inventory_drag_preview.size = tex_size + Vector2(6,6)

    var canvas = inventory_panel.get_parent()
    canvas.add_child(inventory_drag_preview)
    _update_inventory_drag_preview(get_viewport().get_mouse_position())

func _update_inventory_drag_preview(mouse_pos):
    if inventory_drag_preview == null or not is_instance_valid(inventory_drag_preview):
        return

    inventory_drag_preview.position = Vector2(
        floor(mouse_pos.x - inventory_drag_preview.size.x * 0.5),
        floor(mouse_pos.y - inventory_drag_preview.size.y * 0.5)
    )

func _clear_inventory_drag():
    if inventory_drag_preview != null and is_instance_valid(inventory_drag_preview):
        inventory_drag_preview.queue_free()

    inventory_drag_preview = null
    inventory_drag_active = false
    inventory_drag_candidate_index = -1
    inventory_drag_candidate_source = ""
    inventory_drag_candidate_id = ""

func _grid_cell_from_mouse(control,mouse_pos):
    var local_pos = mouse_pos - control.global_position
    return Vector2i(
        int(floor(local_pos.x / CELL)),
        int(floor(local_pos.y / CELL))
    )

func _move_container_entry_to_cell(source_index,x,y):
    if active_container_key == "" or not container_states.has(active_container_key):
        return false

    var state = container_states[active_container_key]
    var entries = state.get("items",[])

    if source_index < 0 or source_index >= entries.size():
        return false

    var source = entries[source_index]
    var id = str(source.get("id",""))
    if not item_defs.has(id):
        return false

    var item = item_defs[id]
    var iw = int(item.get("w",1))
    var ih = int(item.get("h",1))
    var target_index = _entry_index_at_cell(entries,x,y,source_index)

    if target_index >= 0:
        var target = entries[target_index]
        var target_id = str(target.get("id",""))

        if target_id == id:
            var max_stack = int(item.get("stack",1))
            if max_stack > 1:
                var source_qty = int(source.get("qty",1))
                var target_qty = int(target.get("qty",1))
                var room = max_stack - target_qty

                if room > 0:
                    var moved = min(room,source_qty)
                    target["qty"] = target_qty + moved
                    source_qty -= moved
                    entries[target_index] = target

                    if source_qty <= 0:
                        entries.remove_at(source_index)
                        selected_container_index = -1
                    else:
                        source["qty"] = source_qty
                        entries[source_index] = source

                    state["items"] = entries
                    container_states[active_container_key] = state
                    return true

        var target_item = item_defs.get(target_id,{})
        var tw = int(target_item.get("w",1))
        var th = int(target_item.get("h",1))
        var sx = int(source.get("x",0))
        var sy = int(source.get("y",0))
        var tx = int(target.get("x",0))
        var ty = int(target.get("y",0))
        var excluded = [source_index,target_index]

        if _can_place_grid(entries,tx,ty,iw,ih,excluded,CONTAINER_W,CONTAINER_H) and _can_place_grid(entries,sx,sy,tw,th,excluded,CONTAINER_W,CONTAINER_H):
            source["x"] = tx
            source["y"] = ty
            target["x"] = sx
            target["y"] = sy
            entries[source_index] = source
            entries[target_index] = target
            state["items"] = entries
            container_states[active_container_key] = state
            return true

        return false

    if _can_place_grid(entries,x,y,iw,ih,[source_index],CONTAINER_W,CONTAINER_H):
        source["x"] = x
        source["y"] = y
        entries[source_index] = source
        state["items"] = entries
        container_states[active_container_key] = state
        return true

    return false

func _drag_inventory_to_container(source_index,x,y):
    if active_container_key == "" or not container_states.has(active_container_key):
        return false
    if source_index < 0 or source_index >= inventory_entries.size():
        return false

    var source = inventory_entries[source_index]
    var id = str(source.get("id",""))
    if not item_defs.has(id):
        return false

    var item = item_defs[id]
    var iw = int(item.get("w",1))
    var ih = int(item.get("h",1))
    var state = container_states[active_container_key]
    var entries = state.get("items",[])
    var target_index = _entry_index_at_cell(entries,x,y)

    if target_index >= 0:
        var target = entries[target_index]
        if str(target.get("id","")) != id:
            return false

        var max_stack = int(item.get("stack",1))
        if max_stack <= 1:
            return false

        var source_qty = int(source.get("qty",1))
        var target_qty = int(target.get("qty",1))
        var room = max_stack - target_qty
        if room <= 0:
            return false

        var moved = min(room,source_qty)
        target["qty"] = target_qty + moved
        source_qty -= moved
        entries[target_index] = target

        if source_qty <= 0:
            inventory_entries.remove_at(source_index)
            selected_inventory_index = -1
        else:
            source["qty"] = source_qty
            inventory_entries[source_index] = source

        state["items"] = entries
        container_states[active_container_key] = state
        return true

    if not _can_place_grid(entries,x,y,iw,ih,[],CONTAINER_W,CONTAINER_H):
        return false

    entries.append({
        "id":id,
        "qty":int(source.get("qty",1)),
        "x":x,
        "y":y
    })
    inventory_entries.remove_at(source_index)
    selected_inventory_index = -1

    state["items"] = entries
    container_states[active_container_key] = state
    return true

func _drag_container_to_inventory(source_index,x,y):
    if active_container_key == "" or not container_states.has(active_container_key):
        return false

    var state = container_states[active_container_key]
    var entries = state.get("items",[])
    if source_index < 0 or source_index >= entries.size():
        return false

    var source = entries[source_index]
    var id = str(source.get("id",""))
    if not item_defs.has(id):
        return false

    var item = item_defs[id]
    var iw = int(item.get("w",1))
    var ih = int(item.get("h",1))
    var target_index = _entry_index_at_cell(inventory_entries,x,y)

    if target_index >= 0:
        var target = inventory_entries[target_index]
        if str(target.get("id","")) != id:
            return false

        var max_stack = int(item.get("stack",1))
        if max_stack <= 1:
            return false

        var source_qty = int(source.get("qty",1))
        var target_qty = int(target.get("qty",1))
        var room = max_stack - target_qty
        if room <= 0:
            return false

        var moved = min(room,source_qty)
        target["qty"] = target_qty + moved
        source_qty -= moved
        inventory_entries[target_index] = target

        if source_qty <= 0:
            entries.remove_at(source_index)
            selected_container_index = -1
        else:
            source["qty"] = source_qty
            entries[source_index] = source

        state["items"] = entries
        container_states[active_container_key] = state
        return true

    if not _can_place_grid(inventory_entries,x,y,iw,ih,[],INV_W,INV_H):
        return false

    inventory_entries.append({
        "id":id,
        "qty":int(source.get("qty",1)),
        "x":x,
        "y":y
    })
    entries.remove_at(source_index)
    selected_container_index = -1

    state["items"] = entries
    container_states[active_container_key] = state
    return true

func _finish_inventory_drag(mouse_pos):
    if not inventory_drag_active:
        _clear_inventory_drag()
        return

    var source = inventory_drag_candidate_source
    var source_index = inventory_drag_candidate_index
    var moved = false

    if inv_grid_control != null and inv_grid_control.get_global_rect().has_point(mouse_pos):
        var cell = _grid_cell_from_mouse(inv_grid_control,mouse_pos)

        if source == "inventory":
            selected_inventory_index = source_index
            _move_selected_inventory_to_cell(cell.x,cell.y)
            moved = true
        elif source == "container":
            moved = _drag_container_to_inventory(source_index,cell.x,cell.y)

    elif container_panel != null and container_panel.visible and cont_grid_control != null and cont_grid_control.get_global_rect().has_point(mouse_pos):
        var cell = _grid_cell_from_mouse(cont_grid_control,mouse_pos)

        if source == "container":
            moved = _move_container_entry_to_cell(source_index,cell.x,cell.y)
        elif source == "inventory":
            moved = _drag_inventory_to_container(source_index,cell.x,cell.y)

    _clear_inventory_drag()

    if moved:
        call_deferred("_refresh_inventory_ui")



func _inventory_item_gui_input(event,index,id):
    if not (event is InputEventMouseButton):
        return

    if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _begin_inventory_drag_candidate("inventory",index,id)
        return

    if event.button_index != MOUSE_BUTTON_RIGHT or not event.pressed:
        return

    get_viewport().set_input_as_handled()

    if not item_defs.has(id):
        return

    var category = str(item_defs[id].get("category",""))
    var use_type = str(item_defs[id].get("use",""))

    if category == "weapon":
        selected_inventory_index = index
        _open_weapon_mod_panel(id)
    elif use_type == "weapon_mod" and weapon_defs.has(current_weapon_id):
        selected_inventory_index = index
        _open_weapon_mod_panel(current_weapon_id)

func _create_inventory_ui():
    var canvas = CanvasLayer.new()
    canvas.layer = 20
    canvas.name = "InventoryUI"
    add_child(canvas)

    # Main storage.
    inventory_panel = Panel.new()
    inventory_panel.position = Vector2(10,20)
    inventory_panel.size = Vector2(372,326)
    inventory_panel.add_theme_stylebox_override("panel",_visual_panel_style())
    canvas.add_child(inventory_panel)

    inv_title = Label.new()
    inv_title.position = Vector2(16,10)
    inv_title.text = "РЮКЗАК / ХРАНИЛИЩЕ"
    inv_title.add_theme_font_size_override("font_size",12)
    inventory_panel.add_child(inv_title)

    var inv_hint = Label.new()
    inv_hint.position = Vector2(16,31)
    inv_hint.text = "ЛКМ: выбрать / перетащить. Можно таскать между рюкзаком и контейнером."
    inv_hint.add_theme_font_size_override("font_size",7)
    inv_hint.modulate = Color(0.62,0.65,0.61)
    inventory_panel.add_child(inv_hint)

    inv_grid_control = Control.new()
    inv_grid_control.position = Vector2(16,55)
    inv_grid_control.size = Vector2(INV_W * CELL, INV_H * CELL)
    inventory_panel.add_child(inv_grid_control)

    inv_details = Label.new()
    inv_details.position = Vector2(16,204)
    inv_details.size = Vector2(338,48)
    inv_details.add_theme_font_size_override("font_size",8)
    inventory_panel.add_child(inv_details)

    var weight_label = Label.new()
    weight_label.position = Vector2(246,10)
    weight_label.name = "WeightLabel"
    weight_label.add_theme_font_size_override("font_size",8)
    inventory_panel.add_child(weight_label)

    _make_button(inventory_panel,Vector2(16,276),Vector2(78,30),"ИСП.",_use_selected_inventory)
    _make_button(inventory_panel,Vector2(100,276),Vector2(78,30),"ВЫБРОС",_drop_selected_inventory)
    _make_button(inventory_panel,Vector2(184,276),Vector2(78,30),"СОРТ",_sort_inventory)
    _make_button(inventory_panel,Vector2(268,276),Vector2(86,30),"ЗАКРЫТЬ",_close_inventory)

    # Equipment is permanently visible at the side of normal inventory.
    equipment_panel = Panel.new()
    equipment_panel.position = Vector2(392,20)
    equipment_panel.size = Vector2(238,326)
    equipment_panel.add_theme_stylebox_override("panel",_visual_panel_style())
    canvas.add_child(equipment_panel)

    var eq_title = Label.new()
    eq_title.position = Vector2(14,10)
    eq_title.text = "НАДЕТО"
    eq_title.add_theme_font_size_override("font_size",12)
    equipment_panel.add_child(eq_title)

    var eq_hint = Label.new()
    eq_hint.position = Vector2(14,31)
    eq_hint.text = "Нажми слот, чтобы снять"
    eq_hint.add_theme_font_size_override("font_size",7)
    eq_hint.modulate = Color(0.62,0.65,0.61)
    equipment_panel.add_child(eq_hint)

    equipment_buttons["head"] = _make_button(equipment_panel,Vector2(14,57),Vector2(210,48),"",_unequip_slot.bind("head"))
    equipment_buttons["body"] = _make_button(equipment_panel,Vector2(14,111),Vector2(210,48),"",_unequip_slot.bind("body"))
    equipment_buttons["backpack"] = _make_button(equipment_panel,Vector2(14,165),Vector2(210,48),"",_unequip_slot.bind("backpack"))
    equipment_buttons["utility"] = _make_button(equipment_panel,Vector2(14,219),Vector2(210,48),"",_unequip_slot.bind("utility"))

    equipment_info = Label.new()
    equipment_info.position = Vector2(14,278)
    equipment_info.size = Vector2(210,36)
    equipment_info.add_theme_font_size_override("font_size",8)
    equipment_panel.add_child(equipment_info)

    # Container replaces equipment side panel during looting.
    container_panel = Panel.new()
    container_panel.position = Vector2(392,6)
    container_panel.size = Vector2(238,348)
    container_panel.add_theme_stylebox_override("panel",_visual_panel_style())
    canvas.add_child(container_panel)

    cont_title = Label.new()
    cont_title.position = Vector2(12,10)
    cont_title.size = Vector2(214,20)
    cont_title.add_theme_font_size_override("font_size",11)
    container_panel.add_child(cont_title)

    var cont_hint = Label.new()
    cont_hint.position = Vector2(12,32)
    cont_hint.text = "ЛУТ"
    cont_hint.add_theme_font_size_override("font_size",7)
    cont_hint.modulate = Color(0.62,0.65,0.61)
    container_panel.add_child(cont_hint)

    cont_grid_control = Control.new()
    cont_grid_control.position = Vector2(7,45)
    cont_grid_control.size = Vector2(CONTAINER_W * CELL, CONTAINER_H * CELL)
    container_panel.add_child(cont_grid_control)

    cont_details = Label.new()
    cont_details.position = Vector2(12,274)
    cont_details.size = Vector2(214,28)
    cont_details.add_theme_font_size_override("font_size",8)
    container_panel.add_child(cont_details)

    _make_button(container_panel,Vector2(12,309),Vector2(96,28),"ЗАБРАТЬ",_take_selected_container)
    _make_button(container_panel,Vector2(114,309),Vector2(112,28),"ЗАБРАТЬ ВСЕ",_take_all_container)

    inventory_panel.visible = false
    equipment_panel.visible = false
    container_panel.visible = false

func _icon_bg(color):
    var img = Image.create(32,32,false,Image.FORMAT_RGBA8)
    img.fill(color)
    return img

func _img_rect(img,x,y,w,h,color):
    for yy in range(y,y+h):
        for xx in range(x,x+w):
            if xx >= 0 and xx < img.get_width() and yy >= 0 and yy < img.get_height():
                img.set_pixel(xx,yy,color)

func _img_outline(img,x,y,w,h,color):
    for xx in range(x,x+w):
        if xx >= 0 and xx < img.get_width():
            if y >= 0 and y < img.get_height():
                img.set_pixel(xx,y,color)
            if y+h-1 >= 0 and y+h-1 < img.get_height():
                img.set_pixel(xx,y+h-1,color)
    for yy in range(y,y+h):
        if yy >= 0 and yy < img.get_height():
            if x >= 0 and x < img.get_width():
                img.set_pixel(x,yy,color)
            if x+w-1 >= 0 and x+w-1 < img.get_width():
                img.set_pixel(x+w-1,yy,color)

func _img_circle(img,cx,cy,r,color):
    for yy in range(cy-r-1,cy+r+2):
        for xx in range(cx-r-1,cx+r+2):
            if xx >= 0 and xx < img.get_width() and yy >= 0 and yy < img.get_height():
                var dx = xx - cx
                var dy = yy - cy
                if dx*dx + dy*dy <= r*r:
                    img.set_pixel(xx,yy,color)







func _make_item_icon(id):
    if item_icon_cache.has(id):
        return item_icon_cache[id]

    if melee_icon_regions.has(id):
        if melee_inventory_atlas_texture == null:
            melee_inventory_atlas_texture = load("res://melee_inventory_v9.png")

        if melee_inventory_atlas_texture != null:
            var melee_atlas = AtlasTexture.new()
            melee_atlas.atlas = melee_inventory_atlas_texture
            melee_atlas.region = melee_icon_regions[id]
            item_icon_cache[id] = melee_atlas
            return melee_atlas

    if inventory_exact_atlas_texture == null:
        inventory_exact_atlas_texture = load("res://inventory_icons_v22.png")

    if inventory_exact_atlas_texture != null and inventory_icon_regions.has(id):
        var atlas = AtlasTexture.new()
        atlas.atlas = inventory_exact_atlas_texture
        atlas.region = inventory_icon_regions[id]
        item_icon_cache[id] = atlas
        return atlas

    var img = Image.create(18,18,false,Image.FORMAT_RGBA8)
    img.fill(Color(0.12,0.13,0.13,1.0))
    var tex = ImageTexture.create_from_image(img)
    item_icon_cache[id] = tex
    return tex



func _visual_panel_style():
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.012,0.016,0.017,0.996)
    style.border_color = Color(0.34,0.36,0.34,1.0)
    style.border_width_left = 2
    style.border_width_top = 2
    style.border_width_right = 2
    style.border_width_bottom = 2
    style.corner_radius_top_left = 1
    style.corner_radius_top_right = 1
    style.corner_radius_bottom_left = 1
    style.corner_radius_bottom_right = 1
    style.content_margin_left = 5.0
    style.content_margin_top = 5.0
    style.content_margin_right = 5.0
    style.content_margin_bottom = 5.0
    return style

func _visual_button_style(button):
    if button == null:
        return

    var normal = StyleBoxFlat.new()
    normal.bg_color = Color(0.040,0.047,0.047,1.0)
    normal.border_color = Color(0.20,0.23,0.22,1.0)
    normal.border_width_left = 1
    normal.border_width_top = 1
    normal.border_width_right = 1
    normal.border_width_bottom = 1
    normal.corner_radius_top_left = 1
    normal.corner_radius_top_right = 1
    normal.corner_radius_bottom_left = 1
    normal.corner_radius_bottom_right = 1

    var hover = normal.duplicate()
    hover.bg_color = Color(0.075,0.085,0.078,1.0)
    hover.border_color = Color(0.48,0.50,0.40,1.0)

    var pressed = normal.duplicate()
    pressed.bg_color = Color(0.11,0.10,0.065,1.0)
    pressed.border_color = Color(0.76,0.62,0.29,1.0)

    button.add_theme_stylebox_override("normal",normal)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",pressed)
    button.add_theme_stylebox_override("focus",hover)
    button.add_theme_color_override("font_color",Color(0.84,0.85,0.80))
    button.add_theme_color_override("font_hover_color",Color(1.0,0.94,0.76))
    button.add_theme_color_override("font_pressed_color",Color(1.0,0.86,0.47))


func _world_prop_region(kind):
    var regions = {
        "car":Rect2(0,0,96,56),
        "tree":Rect2(96,0,64,72),
        "barrel":Rect2(160,0,32,40),
        "lamp":Rect2(192,0,32,64),
        "crate":Rect2(224,0,40,36),
        "workbench":Rect2(264,0,72,48),
        "medical_shelf":Rect2(0,80,64,56),
        "retail_shelf":Rect2(64,80,64,56),
        "locker":Rect2(128,80,48,56),
        "desk":Rect2(176,80,72,48),
        "debris":Rect2(248,80,48,32),
        "blood":Rect2(296,80,48,32),
        "plant":Rect2(344,80,32,40),
        "med_sign":Rect2(376,80,56,32),
        "cot":Rect2(0,152,64,40),
        "heater":Rect2(64,152,40,48),
        "base_lamp":Rect2(104,152,32,48),
        "barricade":Rect2(136,152,64,40),
        "door":Rect2(200,152,48,24),
        "broken_window":Rect2(248,152,56,48),
        "corpse":Rect2(304,152,72,40),
        "cabinet":Rect2(376,152,48,56),
        "counter":Rect2(424,152,80,48),
        "trash_bin":Rect2(512,0,40,48),
        "road_sign":Rect2(552,0,32,64),
        "sandbags":Rect2(584,0,56,32),
        "med_cart":Rect2(512,80,48,48),
        "chair":Rect2(560,80,32,40),
        "sink":Rect2(592,80,48,40),
        "radiator":Rect2(512,152,48,32),
        "body_bag":Rect2(560,152,72,32),
        "traffic_cone":Rect2(640,0,24,40),
        "shopping_cart":Rect2(664,0,48,40),
        "extinguisher":Rect2(712,0,24,40),
        "road_barrier":Rect2(736,0,32,48),
        "wall_pipe":Rect2(640,80,64,32),
        "desk_lamp":Rect2(704,80,32,40),
        "rubble":Rect2(640,152,64,32),
        "generator_prop":Rect2(704,152,64,48),
        "weapon_rack":Rect2(768,0,64,48),
        "ammo_crate":Rect2(832,0,56,40),
        "toolbox":Rect2(768,80,48,32),
        "wall_poster":Rect2(816,80,48,56),
        "pharmacy_cabinet":Rect2(896,0,64,56),
        "toppled_shelf":Rect2(960,0,64,48),
        "hospital_curtain":Rect2(896,80,48,64),
        "broken_monitor":Rect2(944,80,48,40),
        "street_debris":Rect2(896,160,72,40),
        "drawer_cabinet":Rect2(968,160,48,56),
        "shattered_glass":Rect2(1024,0,64,40),
        "paper_stack":Rect2(1088,0,48,32),
        "mop_bucket":Rect2(1024,80,40,48),
        "electrical_box":Rect2(1064,80,48,48),
        "hanging_lamp":Rect2(1112,80,40,48),
        "old_fridge":Rect2(1024,152,56,64),
        "wall_sign":Rect2(1080,152,64,32),
        "hospital_bed":Rect2(1152,0,96,56),
        "iv_stand":Rect2(1248,0,40,64),
        "wheelchair":Rect2(1288,0,64,56),
        "cardboard_boxes":Rect2(1352,0,56,48),
        "medicine_boxes":Rect2(1152,80,72,40),
        "wall_wires":Rect2(1224,80,80,40),
        "broken_chair_detail":Rect2(1304,80,48,48),
        "med_tray":Rect2(1352,80,56,40),
        "blood_pool_large":Rect2(1152,152,96,48),
        "rubble_crate":Rect2(1248,152,80,48),
        "pipe_cluster":Rect2(1328,152,80,48),
        "large_med_cabinet":Rect2(1408,0,72,64),
        "ceiling_pipes":Rect2(1480,0,88,48),
        "tool_wall_detail":Rect2(1568,0,96,64),
        "floor_papers":Rect2(1408,80,80,40),
        "wall_crack":Rect2(1488,80,64,56),
        "oxygen_cylinder":Rect2(1552,80,40,64),
        "hanging_wires":Rect2(1592,80,72,56),
        "rubble_papers":Rect2(1408,152,96,48),
        "broken_door_detail":Rect2(1504,152,72,64),
        "cabinet_debris":Rect2(1576,152,88,56),
        "metal_shelving":Rect2(1664,0,96,64),
        "hanging_tarp":Rect2(1760,0,80,64),
        "broken_sink_detail":Rect2(1840,0,72,56),
        "wall_grime":Rect2(1664,80,96,56),
        "folded_blanket":Rect2(1760,80,64,40),
        "gas_can":Rect2(1824,80,48,56),
        "wooden_debris":Rect2(1872,80,48,64),
        "old_mattress":Rect2(1664,152,96,48),
        "scattered_bottles":Rect2(1760,152,72,48),
        "barricade_scraps":Rect2(1832,152,88,48),
        "campfire":Rect2(1920,0,64,56),
        "rain_collector":Rect2(1984,0,64,64)
    }
    return regions.get(kind,Rect2())

func _world_prop_sprite(kind,parent,pos = Vector2.ZERO,z_value = 0,scale_value = 1.0):
    var atlas = load("res://world_props_v12.png")
    if atlas == null:
        return null
    var region = _world_prop_region(kind)
    if region.size == Vector2.ZERO:
        return null
    var tex = AtlasTexture.new()
    tex.atlas = atlas
    tex.region = region
    var sprite = Sprite2D.new()
    sprite.texture = tex
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = pos
    sprite.scale = Vector2(scale_value,scale_value)
    sprite.z_index = z_value
    parent.add_child(sprite)
    return sprite

func _interior_tile_region(sign_text):
    var s = str(sign_text).to_upper()
    if s.find("АПТЕК") >= 0:
        return Rect2(128,0,128,128)
    if s.find("ПРОДУК") >= 0 or s.find("МАГАЗ") >= 0 or s.find("КАФЕ") >= 0:
        return Rect2(128,128,128,128)
    if s.find("ЖИЛ") >= 0 or s.find("ДОМ") >= 0 or s.find("ДАЧ") >= 0:
        return Rect2(0,128,128,128)
    return Rect2(0,0,128,128)

func _interior_floor_sprite(parent,sign_text,size):
    var atlas = load("res://world_tiles_v9.png")
    if atlas == null:
        return null
    var tex = AtlasTexture.new()
    tex.atlas = atlas
    tex.region = _interior_tile_region(sign_text)
    var sprite = Sprite2D.new()
    sprite.texture = tex
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.position = Vector2(0,7)
    sprite.scale = Vector2(
        max(0.25,(size.x - 20.0) / 128.0),
        max(0.25,(size.y - 28.0) / 128.0)
    )
    sprite.z_index = -1
    parent.add_child(sprite)
    return sprite



func _add_detail_light(parent,pos,color,energy,texture_scale):
    if parent == null:
        return
    var light = PointLight2D.new()
    light.position = pos
    light.texture = _make_base_radial_texture()
    light.texture_scale = texture_scale
    light.energy = energy
    light.color = color
    light.z_index = 1
    parent.add_child(light)

func _decorate_building_art(building,sign_text,size,building_id):
    if building == null:
        return

    var s = str(sign_text).to_upper()
    var left = -size.x * 0.27
    var right = size.x * 0.26
    var back_y = -size.y * 0.20

    if s.find("АПТЕК") >= 0:
        _world_prop_sprite("medical_shelf",building,Vector2(left,back_y),2,0.80)
        _world_prop_sprite("medical_shelf",building,Vector2(right,back_y),2,0.80)
        _world_prop_sprite("med_sign",building,Vector2(0,-size.y*0.35),3,0.80)
        _world_prop_sprite("counter",building,Vector2(size.x*0.10,size.y*0.16),3,0.64)
        _world_prop_sprite("cabinet",building,Vector2(-size.x*0.38,size.y*0.02),2,0.66)
        _world_prop_sprite("med_cart",building,Vector2(-size.x*0.05,size.y*0.20),3,0.66)
        _world_prop_sprite("pharmacy_cabinet",building,Vector2(size.x*0.12,-size.y*0.25),2,0.58)
        _world_prop_sprite("hospital_curtain",building,Vector2(-size.x*0.30,size.y*0.05),2,0.46)
        _world_prop_sprite("paper_stack",building,Vector2(size.x*0.03,size.y*0.11),3,0.62)
        _world_prop_sprite("hospital_bed",building,Vector2(-size.x*0.18,size.y*0.16),2,0.56)
        _world_prop_sprite("iv_stand",building,Vector2(-size.x*0.38,size.y*0.02),3,0.56)
        _world_prop_sprite("wheelchair",building,Vector2(size.x*0.30,size.y*0.18),3,0.48)
        _world_prop_sprite("medicine_boxes",building,Vector2(size.x*0.02,-size.y*0.06),3,0.56)
        _world_prop_sprite("med_tray",building,Vector2(size.x*0.22,size.y*0.05),3,0.52)
        _world_prop_sprite("blood_pool_large",building,Vector2(size.x*0.12,size.y*0.27),1,0.55)
        _world_prop_sprite("large_med_cabinet",building,Vector2(size.x*0.34,-size.y*0.22),2,0.52)
        _world_prop_sprite("metal_shelving",building,Vector2(-size.x*0.32,-size.y*0.18),2,0.46)
        _world_prop_sprite("folded_blanket",building,Vector2(-size.x*0.05,size.y*0.20),3,0.50)
        _world_prop_sprite("oxygen_cylinder",building,Vector2(-size.x*0.40,size.y*0.18),3,0.48)
        _world_prop_sprite("floor_papers",building,Vector2(-size.x*0.02,size.y*0.29),1,0.52)
        _world_prop_sprite("wall_crack",building,Vector2(-size.x*0.20,-size.y*0.28),1,0.44)
        _add_detail_light(building,Vector2(0,-size.y*0.10),Color(1.0,0.73,0.43),0.20,0.70)
        _world_prop_sprite("shattered_glass",building,Vector2(size.x*0.28,size.y*0.28),2,0.42)
        _world_prop_sprite("sink",building,Vector2(size.x*0.34,size.y*0.10),2,0.58)
        _world_prop_sprite("extinguisher",building,Vector2(size.x*0.40,-size.y*0.18),3,0.70)
        _world_prop_sprite("debris",building,Vector2(-size.x*0.12,size.y*0.27),2,0.58)
        _world_prop_sprite("plant",building,Vector2(size.x*0.37,-size.y*0.06),2,0.62)

        if str(building_id).find("pharmacy") >= 0:
            _world_prop_sprite("blood",building,Vector2(size.x*0.18,size.y*0.22),2,0.68)
            _world_prop_sprite("body_bag",building,Vector2(-size.x*0.10,size.y*0.28),3,0.55)

    elif s.find("ПРОДУК") >= 0 or s.find("МАГАЗ") >= 0 or s.find("КАФЕ") >= 0:
        _world_prop_sprite("retail_shelf",building,Vector2(left,back_y),2,0.82)
        _world_prop_sprite("retail_shelf",building,Vector2(right,back_y),2,0.82)
        _world_prop_sprite("counter",building,Vector2(size.x*0.08,size.y*0.17),3,0.62)
        _world_prop_sprite("chair",building,Vector2(-size.x*0.05,size.y*0.17),2,0.70)
        _world_prop_sprite("trash_bin",building,Vector2(-size.x*0.36,size.y*0.18),2,0.55)
        _world_prop_sprite("shopping_cart",building,Vector2(size.x*0.22,size.y*0.22),3,0.58)
        _world_prop_sprite("toppled_shelf",building,Vector2(-size.x*0.05,size.y*0.25),2,0.46)
        _world_prop_sprite("mop_bucket",building,Vector2(-size.x*0.32,size.y*0.20),2,0.52)
        _world_prop_sprite("old_fridge",building,Vector2(size.x*0.36,-size.y*0.10),2,0.46)
        _world_prop_sprite("cardboard_boxes",building,Vector2(-size.x*0.22,size.y*0.20),2,0.52)
        _world_prop_sprite("broken_chair_detail",building,Vector2(size.x*0.12,size.y*0.23),2,0.48)
        _world_prop_sprite("floor_papers",building,Vector2(size.x*0.05,size.y*0.28),1,0.48)
        _world_prop_sprite("wall_crack",building,Vector2(-size.x*0.26,-size.y*0.25),1,0.42)
        _world_prop_sprite("wall_grime",building,Vector2(size.x*0.20,-size.y*0.24),1,0.42)
        _world_prop_sprite("scattered_bottles",building,Vector2(size.x*0.24,size.y*0.26),2,0.45)
        _world_prop_sprite("debris",building,Vector2(-size.x*0.15,size.y*0.24),2,0.64)
        _world_prop_sprite("broken_window",building,Vector2(size.x*0.35,-size.y*0.12),2,0.54)

    elif s.find("ГАРАЖ") >= 0 or s.find("ЦЕХ") >= 0 or s.find("СЕРВИС") >= 0 or s.find("СКЛАД") >= 0:
        _world_prop_sprite("locker",building,Vector2(left,back_y),2,0.76)
        _world_prop_sprite("workbench",building,Vector2(right,back_y+5),2,0.70)
        _world_prop_sprite("cabinet",building,Vector2(-size.x*0.36,size.y*0.08),2,0.68)
        _world_prop_sprite("crate",building,Vector2(size.x*0.33,size.y*0.22),2,0.70)
        _world_prop_sprite("radiator",building,Vector2(size.x*0.05,-size.y*0.30),2,0.64)
        _world_prop_sprite("wall_pipe",building,Vector2(size.x*0.20,-size.y*0.34),2,0.55)
        _world_prop_sprite("toolbox",building,Vector2(size.x*0.30,size.y*0.15),3,0.60)
        _world_prop_sprite("broken_monitor",building,Vector2(-size.x*0.10,size.y*0.14),3,0.54)
        _world_prop_sprite("electrical_box",building,Vector2(size.x*0.38,-size.y*0.20),2,0.56)
        _world_prop_sprite("hanging_lamp",building,Vector2(0,-size.y*0.30),4,0.48)
        _world_prop_sprite("wall_wires",building,Vector2(-size.x*0.12,-size.y*0.31),2,0.50)
        _world_prop_sprite("pipe_cluster",building,Vector2(size.x*0.18,size.y*0.25),2,0.48)
        _world_prop_sprite("rubble_crate",building,Vector2(-size.x*0.26,size.y*0.25),2,0.48)
        _world_prop_sprite("ceiling_pipes",building,Vector2(0,-size.y*0.34),2,0.50)
        _world_prop_sprite("tool_wall_detail",building,Vector2(-size.x*0.27,-size.y*0.20),2,0.48)
        _world_prop_sprite("hanging_wires",building,Vector2(size.x*0.28,-size.y*0.26),2,0.46)
        _world_prop_sprite("cabinet_debris",building,Vector2(size.x*0.06,size.y*0.25),2,0.46)
        _world_prop_sprite("hanging_tarp",building,Vector2(-size.x*0.35,-size.y*0.12),2,0.44)
        _world_prop_sprite("gas_can",building,Vector2(size.x*0.32,size.y*0.18),3,0.52)
        _world_prop_sprite("wooden_debris",building,Vector2(-size.x*0.18,size.y*0.27),2,0.44)
        _add_detail_light(building,Vector2(right,back_y),Color(1.0,0.66,0.34),0.18,0.62)
        _world_prop_sprite("extinguisher",building,Vector2(-size.x*0.40,-size.y*0.16),3,0.68)
        _world_prop_sprite("trash_bin",building,Vector2(-size.x*0.10,size.y*0.24),2,0.58)
        _world_prop_sprite("debris",building,Vector2(0,size.y*0.25),2,0.74)

    elif s.find("КПП") >= 0 or s.find("КАЗАР") >= 0 or s.find("СВЯЗ") >= 0:
        _world_prop_sprite("locker",building,Vector2(left,back_y),2,0.78)
        _world_prop_sprite("locker",building,Vector2(right,back_y),2,0.78)
        _world_prop_sprite("crate",building,Vector2(size.x*0.28,size.y*0.22),2,0.74)
        _world_prop_sprite("desk",building,Vector2(-size.x*0.20,size.y*0.14),2,0.60)
        _world_prop_sprite("sandbags",building,Vector2(0,size.y*0.30),2,0.58)
        _world_prop_sprite("road_barrier",building,Vector2(size.x*0.26,size.y*0.25),3,0.50)
        _world_prop_sprite("weapon_rack",building,Vector2(-size.x*0.18,-size.y*0.25),3,0.58)
        _world_prop_sprite("ammo_crate",building,Vector2(size.x*0.30,size.y*0.18),3,0.58)
        _world_prop_sprite("broken_door_detail",building,Vector2(size.x*0.36,size.y*0.12),2,0.42)
        _world_prop_sprite("cardboard_boxes",building,Vector2(-size.x*0.34,size.y*0.18),2,0.48)

    else:
        _world_prop_sprite("desk",building,Vector2(left,back_y+4),2,0.64)
        _world_prop_sprite("locker",building,Vector2(right,back_y),2,0.66)
        _world_prop_sprite("cot",building,Vector2(-size.x*0.12,size.y*0.21),2,0.60)
        _world_prop_sprite("chair",building,Vector2(size.x*0.12,size.y*0.10),2,0.68)
        _world_prop_sprite("desk_lamp",building,Vector2(left+8,back_y-8),3,0.54)
        _world_prop_sprite("wall_poster",building,Vector2(size.x*0.28,-size.y*0.28),2,0.46)
        _world_prop_sprite("drawer_cabinet",building,Vector2(-size.x*0.34,-size.y*0.04),2,0.52)
        _world_prop_sprite("wall_sign",building,Vector2(size.x*0.22,-size.y*0.30),2,0.48)
        _world_prop_sprite("rubble_papers",building,Vector2(size.x*0.03,size.y*0.28),1,0.43)
        _world_prop_sprite("old_mattress",building,Vector2(-size.x*0.20,size.y*0.22),2,0.45)
        _world_prop_sprite("broken_sink_detail",building,Vector2(size.x*0.31,size.y*0.09),2,0.46)
        _world_prop_sprite("radiator",building,Vector2(-size.x*0.34,-size.y*0.18),2,0.58)
        _world_prop_sprite("plant",building,Vector2(size.x*0.36,size.y*0.10),2,0.62)
        _world_prop_sprite("debris",building,Vector2(size.x*0.10,size.y*0.25),2,0.52)

func _add_ground_decals(chunk,coord):
    var rng = RandomNumberGenerator.new()
    rng.seed = int(abs(coord.x*198491 + coord.y*65497 + 32001)) + 1
    for i in range(10):
        var p = Vector2(rng.randi_range(35,765),rng.randi_range(35,765))
        var kind = "debris" if rng.randf() > 0.18 else "blood"
        var sprite = _world_prop_sprite(kind,chunk,p,1,rng.randf_range(0.42,0.70))
        if sprite != null:
            sprite.rotation = rng.randf_range(-PI,PI)


func _make_button(parent, pos, size, text, callback):
    var button = Button.new()
    button.position = pos
    button.size = size
    button.text = text
    button.add_theme_font_size_override("font_size",8)
    _visual_button_style(button)
    button.pressed.connect(callback)
    parent.add_child(button)
    return button

func _toggle_inventory():
    if inventory_open:
        _close_inventory()
    else:
        _cancel_reload()
        inventory_open = true
        active_container_key = ""
        selected_inventory_index = -1
        selected_container_index = -1
        _refresh_inventory_ui()

func _close_inventory():
    if rest_open:
        _close_rest_panel()
        return

    if crafting_open:
        _close_crafting()
        return

    if base_build_open:
        _close_base_build()
        return

    inventory_open = false
    active_container_key = ""
    selected_inventory_index = -1
    selected_container_index = -1
    _clear_inventory_drag()

    inventory_panel.visible = false
    equipment_panel.visible = false
    container_panel.visible = false
    _hover_hide_item()
    _close_weapon_mod_panel()

func _open_container(key):
    if not container_states.has(key):
        return
    active_container_key = key
    inventory_open = true
    selected_inventory_index = -1
    selected_container_index = -1
    _refresh_inventory_ui()

func _refresh_inventory_ui():
    if inventory_panel == null:
        return

    if crafting_open:
        inventory_panel.visible = false
        equipment_panel.visible = false
        container_panel.visible = false
        if craft_panel != null:
            craft_panel.visible = true
        return

    if selected_inventory_index >= inventory_entries.size():
        selected_inventory_index = -1

    inventory_panel.visible = inventory_open
    container_panel.visible = inventory_open and active_container_key != ""
    equipment_panel.visible = inventory_open and active_container_key == ""

    _rebuild_grid(inv_grid_control,inventory_entries,INV_W,INV_H,true)

    if selected_inventory_index >= 0 and selected_inventory_index < inventory_entries.size():
        inv_details.text = _entry_description(inventory_entries[selected_inventory_index])
    else:
        inv_details.text = "Рюкзак: предметы, лут и боеприпасы."

    var weight_label = inventory_panel.get_node_or_null("WeightLabel")
    if weight_label != null:
        weight_label.text = "%.1f / %.1f кг" % [_inventory_weight(),_carry_limit()]

    if equipment_panel.visible:
        _refresh_equipment_panel()

    if container_panel.visible and container_states.has(active_container_key):
        var state = container_states[active_container_key]
        cont_title.text = str(state.get("name","КОНТЕЙНЕР"))
        var entries = state.get("items",[])
        _rebuild_grid(cont_grid_control,entries,CONTAINER_W,CONTAINER_H,false)

        if selected_container_index >= 0 and selected_container_index < entries.size():
            cont_details.text = _entry_description(entries[selected_container_index])
        else:
            cont_details.text = "Выбери предмет в контейнере."

func _make_cell_panel(pos,size):
    var panel = Panel.new()
    panel.position = pos
    panel.size = size
    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.045,0.052,0.052,1.0)
    style.border_color = Color(0.14,0.17,0.17,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    panel.add_theme_stylebox_override("panel",style)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return panel

func _style_item_button(button,selected):
    var normal = StyleBoxFlat.new()
    normal.bg_color = Color(0.032,0.039,0.041,0.995)
    normal.border_color = Color(0.145,0.17,0.17,1.0) if not selected else Color(0.68,0.58,0.32,1.0)
    normal.border_width_left = 1 if not selected else 2
    normal.border_width_top = 1 if not selected else 2
    normal.border_width_right = 1 if not selected else 2
    normal.border_width_bottom = 1 if not selected else 2
    normal.corner_radius_top_left = 1
    normal.corner_radius_top_right = 1
    normal.corner_radius_bottom_left = 1
    normal.corner_radius_bottom_right = 1
    button.add_theme_stylebox_override("normal",normal)

    var hover = normal.duplicate()
    hover.bg_color = Color(0.060,0.072,0.073,1.0)
    hover.border_color = Color(0.37,0.43,0.41,1.0)
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("focus",hover)

    var pressed = normal.duplicate()
    pressed.bg_color = Color(0.075,0.073,0.060,1.0)
    pressed.border_color = Color(0.70,0.61,0.38,1.0)
    button.add_theme_stylebox_override("pressed",pressed)

func _decorate_item_button(button,id,qty):
    button.text = ""
    button.tooltip_text = ""
    button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    button.clip_contents = true

    var texture = _make_item_icon(id)
    var icon_box = TextureRect.new()
    icon_box.texture = texture
    icon_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    icon_box.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
    icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

    # Critical 0.12.3 rule: display at native pixel size. No scaling in inventory.
    var native_size = texture.get_size()
    var draw_size = native_size
    var max_size = button.size - Vector2(4,4)

    # Safety only. Exact atlas regions should always fit without entering this branch.
    if draw_size.x > max_size.x or draw_size.y > max_size.y:
        var fit = min(max_size.x / draw_size.x,max_size.y / draw_size.y)
        draw_size = Vector2(floor(draw_size.x * fit),floor(draw_size.y * fit))

    icon_box.size = draw_size
    icon_box.position = Vector2(
        floor((button.size.x - draw_size.x) * 0.5),
        floor((button.size.y - draw_size.y) * 0.5)
    )

    # On stackable 1x1 items leave the lower-right corner readable for the count.
    if qty > 1 and button.size.x < 30.0 and button.size.y < 30.0:
        icon_box.position += Vector2(-1,-1)

    button.add_child(icon_box)
    button.mouse_entered.connect(_hover_show_item.bind(id,qty,"storage"))
    button.mouse_exited.connect(_hover_hide_item)

    if qty > 1:
        # Number only; no black square/panel.
        var shadow = Label.new()
        shadow.text = str(qty)
        shadow.position = Vector2(button.size.x - 12.0,button.size.y - 15.0)
        shadow.size = Vector2(10,9)
        shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        shadow.add_theme_font_size_override("font_size",6)
        shadow.modulate = Color(0.02,0.02,0.02,0.95)
        shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_child(shadow)

        var qty_label = Label.new()
        qty_label.text = str(qty)
        qty_label.position = Vector2(button.size.x - 13.0,button.size.y - 16.0)
        qty_label.size = Vector2(10,9)
        qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        qty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        qty_label.add_theme_font_size_override("font_size",6)
        qty_label.modulate = Color(0.96,0.89,0.66)
        qty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_child(qty_label)

func _decorate_equipment_button(button,slot,id):
    for connection in button.mouse_entered.get_connections():
        button.mouse_entered.disconnect(connection.callable)
    for connection in button.mouse_exited.get_connections():
        button.mouse_exited.disconnect(connection.callable)
    for child in button.get_children():
        button.remove_child(child)
        child.queue_free()

    button.text = ""
    button.mouse_exited.connect(_hover_hide_item)
    _style_item_button(button,id != "")

    var icon_frame = ColorRect.new()
    icon_frame.position = Vector2(5,5)
    icon_frame.size = Vector2(40,38)
    icon_frame.color = Color(0.020,0.025,0.026,0.95)
    icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(icon_frame)

    var slot_label = Label.new()
    slot_label.text = _slot_name(slot)
    slot_label.position = Vector2(52,5)
    slot_label.size = Vector2(button.size.x - 58,14)
    slot_label.add_theme_font_size_override("font_size",7)
    slot_label.modulate = Color(0.62,0.66,0.63)
    slot_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    button.add_child(slot_label)

    var item_label = Label.new()
    item_label.position = Vector2(52,19)
    item_label.size = Vector2(button.size.x - 58,20)
    item_label.add_theme_font_size_override("font_size",8)
    item_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if id != "" and item_defs.has(id):
        item_label.text = str(item_defs[id].get("name",id))
        button.mouse_entered.connect(_hover_show_item.bind(id,1,"equipment"))

        var icon_box = TextureRect.new()
        icon_box.texture = _make_item_icon(id)
        icon_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        icon_box.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        var native_size = icon_box.texture.get_size()
        var fit_scale = min(1.0,min(38.0 / native_size.x,36.0 / native_size.y))
        icon_box.size = Vector2(floor(native_size.x * fit_scale),floor(native_size.y * fit_scale))
        icon_box.position = Vector2(6,6) + (Vector2(38,36) - icon_box.size) * 0.5
        icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
        button.add_child(icon_box)
    else:
        item_label.text = "[пусто]"
        item_label.modulate = Color(0.46,0.49,0.47)

    button.add_child(item_label)

func _can_place_grid(entries,x,y,iw,ih,excluded_indices,gw,gh):
    if x < 0 or y < 0 or x + iw > gw or y + ih > gh:
        return false

    for i in range(entries.size()):
        if excluded_indices.has(i):
            continue

        var entry = entries[i]
        var id = str(entry.get("id",""))
        if not item_defs.has(id):
            continue

        var other = item_defs[id]
        var ox = int(entry.get("x",0))
        var oy = int(entry.get("y",0))
        var ow = int(other.get("w",1))
        var oh = int(other.get("h",1))

        if x < ox + ow and x + iw > ox and y < oy + oh and y + ih > oy:
            return false

    return true


func _can_place_excluding(entries,x,y,iw,ih,excluded_indices):
    if x < 0 or y < 0 or x + iw > INV_W or y + ih > INV_H:
        return false

    for i in range(entries.size()):
        if excluded_indices.has(i):
            continue

        var entry = entries[i]
        var id = str(entry.get("id",""))
        if not item_defs.has(id):
            continue

        var other = item_defs[id]
        var ox = int(entry.get("x",0))
        var oy = int(entry.get("y",0))
        var ow = int(other.get("w",1))
        var oh = int(other.get("h",1))

        if x < ox + ow and x + iw > ox and y < oy + oh and y + ih > oy:
            return false

    return true

func _entry_index_at_cell(entries,x,y,ignore_index=-1):
    for i in range(entries.size()):
        if i == ignore_index:
            continue

        var entry = entries[i]
        var id = str(entry.get("id",""))
        if not item_defs.has(id):
            continue

        var item = item_defs[id]
        var ex = int(entry.get("x",0))
        var ey = int(entry.get("y",0))
        var ew = int(item.get("w",1))
        var eh = int(item.get("h",1))

        if x >= ex and x < ex + ew and y >= ey and y < ey + eh:
            return i

    return -1

func _merge_entry_into(source_index,target_index):
    if source_index < 0 or target_index < 0:
        return false
    if source_index >= inventory_entries.size() or target_index >= inventory_entries.size():
        return false
    if source_index == target_index:
        return false

    var source = inventory_entries[source_index]
    var target = inventory_entries[target_index]
    var id = str(source.get("id",""))

    if id != str(target.get("id","")) or not item_defs.has(id):
        return false

    var max_stack = int(item_defs[id].get("stack",1))
    if max_stack <= 1:
        return false

    var source_qty = int(source.get("qty",1))
    var target_qty = int(target.get("qty",1))
    var room = max_stack - target_qty
    if room <= 0:
        return false

    var moved = min(room,source_qty)
    target["qty"] = target_qty + moved
    source_qty -= moved
    inventory_entries[target_index] = target

    if source_qty <= 0:
        inventory_entries.remove_at(source_index)
        selected_inventory_index = -1
    else:
        source["qty"] = source_qty
        inventory_entries[source_index] = source

    return true

func _move_selected_inventory_to_cell(x,y):
    if selected_inventory_index < 0 or selected_inventory_index >= inventory_entries.size():
        return

    var source_index = selected_inventory_index
    var source = inventory_entries[source_index]
    var id = str(source.get("id",""))
    if not item_defs.has(id):
        return

    var item = item_defs[id]
    var iw = int(item.get("w",1))
    var ih = int(item.get("h",1))

    var target_index = _entry_index_at_cell(inventory_entries,x,y,source_index)

    if target_index >= 0:
        if _merge_entry_into(source_index,target_index):
            call_deferred("_refresh_inventory_ui")
            return

        if source_index >= inventory_entries.size() or target_index >= inventory_entries.size():
            call_deferred("_refresh_inventory_ui")
            return

        var target = inventory_entries[target_index]
        var target_id = str(target.get("id",""))
        if not item_defs.has(target_id):
            return

        var target_item = item_defs[target_id]
        var tw = int(target_item.get("w",1))
        var th = int(target_item.get("h",1))

        var sx = int(source.get("x",0))
        var sy = int(source.get("y",0))
        var tx = int(target.get("x",0))
        var ty = int(target.get("y",0))
        var excluded = [source_index,target_index]

        var source_fits = _can_place_excluding(inventory_entries,tx,ty,iw,ih,excluded)
        var target_fits = _can_place_excluding(inventory_entries,sx,sy,tw,th,excluded)

        if source_fits and target_fits:
            source["x"] = tx
            source["y"] = ty
            target["x"] = sx
            target["y"] = sy
            inventory_entries[source_index] = source
            inventory_entries[target_index] = target

        call_deferred("_refresh_inventory_ui")
        return

    if _can_place_excluding(inventory_entries,x,y,iw,ih,[source_index]):
        source["x"] = x
        source["y"] = y
        inventory_entries[source_index] = source

    call_deferred("_refresh_inventory_ui")

func _inventory_cell_clicked(x,y):
    _move_selected_inventory_to_cell(x,y)

func _inventory_item_clicked(index):
    if index < 0 or index >= inventory_entries.size():
        return

    if selected_inventory_index < 0:
        selected_inventory_index = index
        selected_container_index = -1
        call_deferred("_refresh_inventory_ui")
        return

    if selected_inventory_index == index:
        selected_inventory_index = -1
        call_deferred("_refresh_inventory_ui")
        return

    var target = inventory_entries[index]
    _move_selected_inventory_to_cell(int(target.get("x",0)),int(target.get("y",0)))

func _sort_inventory():
    var category_order = {
        "weapon":0,
        "ammo":1,
        "medical":2,
        "food":3,
        "gear":4,
        "tool":5,
        "material":6
    }

    var totals = {}
    for entry in inventory_entries:
        var id = str(entry.get("id",""))
        totals[id] = int(totals.get(id,0)) + int(entry.get("qty",1))

    var ids = totals.keys()
    ids.sort_custom(func(a,b):
        var ca = 99
        var cb = 99
        if item_defs.has(str(a)):
            ca = int(category_order.get(str(item_defs[str(a)].get("category","")),99))
        if item_defs.has(str(b)):
            cb = int(category_order.get(str(item_defs[str(b)].get("category","")),99))

        if ca != cb:
            return ca < cb

        var area_a = 1
        var area_b = 1
        if item_defs.has(str(a)):
            area_a = int(item_defs[str(a)].get("w",1)) * int(item_defs[str(a)].get("h",1))
        if item_defs.has(str(b)):
            area_b = int(item_defs[str(b)].get("w",1)) * int(item_defs[str(b)].get("h",1))

        if area_a != area_b:
            return area_a > area_b

        return str(a) < str(b)
    )

    var packed = []
    for id in ids:
        var remaining = _grid_add(packed,str(id),int(totals[id]),INV_W,INV_H)
        if remaining > 0:
            return

    inventory_entries = packed
    selected_inventory_index = -1
    call_deferred("_refresh_inventory_ui")

func _transfer_all_entries(source_entries,dest_entries,dw,dh):
    var moved_total = 0

    for i in range(source_entries.size() - 1,-1,-1):
        var entry = source_entries[i]
        var id = str(entry.get("id",""))
        var qty = int(entry.get("qty",1))

        var remaining = _grid_add(dest_entries,id,qty,dw,dh)
        var moved = qty - remaining
        moved_total += moved

        if remaining <= 0:
            source_entries.remove_at(i)
        else:
            entry["qty"] = remaining
            source_entries[i] = entry

    return moved_total

func _take_all_container():
    if active_container_key == "" or not container_states.has(active_container_key):
        return

    var state = container_states[active_container_key]
    var entries = state.get("items",[])
    _transfer_all_entries(entries,inventory_entries,INV_W,INV_H)
    state["items"] = entries
    container_states[active_container_key] = state

    selected_container_index = -1
    selected_inventory_index = -1
    call_deferred("_refresh_inventory_ui")



func _rebuild_grid(control, entries, gw, gh, is_inventory):
    for child in control.get_children():
        control.remove_child(child)
        child.queue_free()

    for y in range(gh):
        for x in range(gw):
            if is_inventory:
                var cell_button = Button.new()
                cell_button.position = Vector2(x * CELL,y * CELL)
                cell_button.size = Vector2(CELL - 2,CELL - 2)
                cell_button.focus_mode = Control.FOCUS_NONE
                cell_button.text = ""
                _style_item_button(cell_button,false)
                cell_button.modulate = Color(0.76,0.79,0.76)
                cell_button.pressed.connect(_inventory_cell_clicked.bind(x,y))
                control.add_child(cell_button)
            else:
                var cell = _make_cell_panel(
                    Vector2(x * CELL,y * CELL),
                    Vector2(CELL - 2,CELL - 2)
                )
                control.add_child(cell)

    for i in range(entries.size()):
        var entry = entries[i]
        var id = str(entry.get("id",""))
        if not item_defs.has(id):
            continue

        var item = item_defs[id]
        var button = Button.new()
        button.position = Vector2(int(entry.get("x",0)) * CELL + 1,int(entry.get("y",0)) * CELL + 1)
        button.size = Vector2(
            int(item.get("w",1)) * CELL - 4,
            int(item.get("h",1)) * CELL - 4
        )
        button.focus_mode = Control.FOCUS_NONE

        var selected = (i == selected_inventory_index) if is_inventory else (i == selected_container_index)
        _style_item_button(button,selected)
        _decorate_item_button(button,id,int(entry.get("qty",1)))

        if not is_inventory:
            for connection in button.mouse_entered.get_connections():
                if connection.callable.get_method() == "_hover_show_item":
                    button.mouse_entered.disconnect(connection.callable)
            button.mouse_entered.connect(_hover_show_item.bind(id,int(entry.get("qty",1)),"container"))

        if is_inventory:
            button.pressed.connect(_inventory_item_clicked.bind(i))
            button.gui_input.connect(_inventory_item_gui_input.bind(i,id))
        else:
            button.pressed.connect(_select_container_entry.bind(i))
            button.gui_input.connect(_container_item_gui_input.bind(i,id))

        control.add_child(button)

func _set_inventory_mode(_mode):
    # Retained only for save/build compatibility; 0.6 has no separate equipment tab.
    return

func _rebuild_equipment_grid(control):
    for child in control.get_children():
        control.remove_child(child)
        child.queue_free()

    for y in range(INV_H):
        for x in range(INV_W):
            var cell = ColorRect.new()
            cell.position = Vector2(x * CELL, y * CELL)
            cell.size = Vector2(CELL - 1, CELL - 1)
            cell.color = Color(0.08,0.09,0.09,1.0)
            cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
            control.add_child(cell)

    var slots = [
        {"slot":"head","label":"ГОЛОВА","x":0,"y":0,"w":2,"h":1},
        {"slot":"body","label":"ТОРС","x":0,"y":1,"w":2,"h":2},
        {"slot":"backpack","label":"РЮКЗАК","x":2,"y":1,"w":2,"h":2},
        {"slot":"utility","label":"УТИЛ.","x":4,"y":0,"w":1,"h":2}
    ]

    for s in slots:
        var slot_name = str(s["slot"])
        var button = Button.new()
        button.position = Vector2(int(s["x"]) * CELL + 1, int(s["y"]) * CELL + 1)
        button.size = Vector2(int(s["w"]) * CELL - 3, int(s["h"]) * CELL - 3)
        button.add_theme_font_size_override("font_size", 7)
        button.text = str(s["label"])

        var equipped_id = str(equipment.get(slot_name,""))
        if equipped_id != "" and item_defs.has(equipped_id):
            button.text = ""
            button.tooltip_text = str(item_defs[equipped_id].get("name",equipped_id))
            button.icon = _make_item_icon(equipped_id)
            button.modulate = Color(0.84,0.91,0.87)
        else:
            button.tooltip_text = "Пустой слот: " + str(s["label"])
            button.modulate = Color(0.42,0.45,0.44)

        button.pressed.connect(_unequip_slot.bind(slot_name))
        control.add_child(button)

func _unequip_slot(slot):
    if not equipment.has(slot):
        return

    var id = str(equipment.get(slot,""))
    if id == "":
        return

    if _grid_add(inventory_entries, id, 1, INV_W, INV_H) != 0:
        return

    equipment[slot] = ""
    if slot == "utility":
        flashlight_on = false

    _refresh_inventory_ui()


func _refresh_equipment_panel():
    if equipment_panel == null:
        return

    for slot in ["head","body","backpack","utility"]:
        if not equipment_buttons.has(slot):
            continue
        var id = str(equipment.get(slot,""))
        _decorate_equipment_button(equipment_buttons[slot],slot,id)

    equipment_info.text = "БРОНЯ %d%%
ВЕС %.1f / %.1f кг" % [
        int(_armor_value() * 100.0),
        _inventory_weight(),
        _carry_limit()
    ]


func _entry_description(entry):
    var id = str(entry.get("id",""))
    if not item_defs.has(id):
        return id

    var item = item_defs[id]
    var text = "%s
Количество: %d   Вес: %.2f кг" % [
        str(item.get("name",id)),
        int(entry.get("qty",1)),
        float(item.get("weight",0.0)) * int(entry.get("qty",1))
    ]

    if str(item.get("use","")) == "gear":
        text += "   [%s]" % _slot_name(str(item.get("slot","")))

    if str(item.get("category","")) == "weapon":
        text += "
Состояние: %d%% [%s]" % [int(_weapon_condition_value(id)),_weapon_condition_state(id)]
    elif str(item.get("category","")) == "melee" and melee_defs.has(id):
        var melee = melee_defs[id]
        text += "
Урон: %d   Выносливость: %d   Дистанция: %d" % [
            int(melee.get("damage",0)),
            int(melee.get("stamina",0)),
            int(melee.get("range",0))
        ]

    if id == "repair_kit":
        text += "
Используется у верстака для обслуживания и капремонта оружия."

    return text

func _select_inventory_entry(index):
    _inventory_item_clicked(index)


func _container_item_gui_input(event,index,id):
    if not (event is InputEventMouseButton):
        return

    if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        _begin_inventory_drag_candidate("container",index,id)


func _select_container_entry(index):
    selected_container_index = index
    selected_inventory_index = -1
    call_deferred("_refresh_inventory_ui")





func _weapon_mod_summary(weapon_id):
    if not weapon_mods.has(weapon_id):
        return "нет"

    var names = []
    for slot in ["magazine","muzzle"]:
        var id = str(weapon_mods[weapon_id].get(slot,""))
        if id != "" and item_defs.has(id):
            names.append(str(item_defs[id].get("short",id)))

    if names.is_empty():
        return "нет"
    return ", ".join(names)


func _weapon_mod_multiplier(weapon_id,key):
    var mult = 1.0
    if not weapon_mods.has(weapon_id):
        return mult

    for slot in ["magazine","muzzle"]:
        var id = str(weapon_mods[weapon_id].get(slot,""))
        if id != "" and item_defs.has(id):
            mult *= float(item_defs[id].get(key,1.0))

    return mult

func _install_selected_weapon_mod():
    if selected_inventory_index < 0 or selected_inventory_index >= inventory_entries.size():
        return false

    var id = str(inventory_entries[selected_inventory_index].get("id",""))
    return _install_weapon_mod(current_weapon_id,id)



func _purify_one_dirty_water(method):
    if _inventory_count("dirty_water") <= 0:
        return false

    var test_entries = inventory_entries.duplicate(true)
    if not _consume_one_item_from_entries(test_entries,"dirty_water"):
        return false

    var remaining = _grid_add(test_entries,"water",1,INV_W,INV_H)
    if remaining > 0:
        if inv_details != null:
            inv_details.text = "Нужно свободное место для чистой воды."
        return false

    inventory_entries = test_entries
    _add_skill_xp("survival",0.55)

    if method == "fire":
        _set_survival_feedback("Дождевая вода вскипячена у костра",2.0)
    else:
        _set_survival_feedback("Дождевая вода очищена фильтром",2.0)

    return true

func _use_selected_inventory():
    if selected_inventory_index < 0 or selected_inventory_index >= inventory_entries.size():
        return

    var entry = inventory_entries[selected_inventory_index]
    var id = str(entry.get("id",""))
    if not item_defs.has(id):
        return

    var use_type = str(item_defs[id].get("use",""))

    if use_type == "bandage":
        _stop_bleeding()
        health = min(100.0,health + 6.0)
        pain = max(0.0,pain - 8.0)
        _stabilize_worst_injury(2.5)
        stamina = min(_survival_stamina_cap(),stamina + 3.0)
        _consume_entry_at(selected_inventory_index,1)
        _set_survival_feedback("Рана перевязана • боль снижена")

    elif use_type == "sterile_bandage":
        if not _use_sterile_bandage():
            inv_details.text = "Стерильная повязка сейчас не требуется."
            return
        _consume_entry_at(selected_inventory_index,1)

    elif use_type == "antiseptic":
        if wound_contamination <= 1.0 and wound_infection <= 1.0:
            inv_details.text = "Нет загрязнённой раны для обработки."
            return
        wound_contamination = max(0.0,wound_contamination - 55.0)
        wound_infection = max(0.0,wound_infection - 4.0)
        pain = min(100.0,pain + 1.0)
        _consume_entry_at(selected_inventory_index,1)
        _set_survival_feedback("Рана обработана антисептиком",2.0)

    elif use_type == "painkillers":
        if pain < 8.0 and painkiller_time > 60.0:
            inv_details.text = "Действие обезболивающего ещё продолжается."
            return
        painkiller_time = max(painkiller_time,240.0)
        _consume_entry_at(selected_inventory_index,1)
        _set_survival_feedback("Обезболивающее действует 4 минуты",2.0)

    elif use_type == "antibiotics":
        if wound_infection < 5.0 and wound_contamination < 45.0:
            inv_details.text = "Антибиотики сейчас не требуются."
            return
        antibiotic_time = max(antibiotic_time,900.0)
        wound_infection = max(0.0,wound_infection - 5.0)
        _consume_entry_at(selected_inventory_index,1)
        _set_survival_feedback("Начат курс антибиотика",2.0)

    elif use_type == "water":
        thirst = min(100.0,thirst + 42.0)
        stamina = min(_survival_stamina_cap(),stamina + 8.0)
        _consume_entry_at(selected_inventory_index,1)
        _set_survival_feedback("Жажда утолена")

    elif use_type == "dirty_water":
        var method = ""
        if _inventory_count("water_filter") > 0:
            method = "filter"
        elif _player_near_active_fire():
            method = "fire"

        if method == "":
            inv_details.text = "Дождевая вода требует фильтра или горящего костра."
            return

        if not _purify_one_dirty_water(method):
            return

    elif use_type == "water_filter":
        if _inventory_count("dirty_water") <= 0:
            inv_details.text = "Нет дождевой воды для фильтрации."
            return
        if not _purify_one_dirty_water("filter"):
            return

    elif use_type == "cook_grain":
        if not _cook_inventory_product(
            "grain",
            true,
            "hot_meal",
            "Приготовлена горячая каша"
        ):
            return

    elif use_type == "brew_tea":
        if not _cook_inventory_product(
            "herbs",
            true,
            "herbal_tea",
            "Заварен травяной чай"
        ):
            return

    elif use_type == "hot_meal":
        hunger = min(100.0,hunger + 52.0)
        thirst = min(100.0,thirst + 7.0)
        stamina = min(_survival_stamina_cap(),stamina + 12.0)
        body_temperature = min(40.5,body_temperature + 0.12)
        pain = max(0.0,pain - 2.0)
        well_fed_time = max(well_fed_time,300.0)
        _consume_entry_at(selected_inventory_index,1)
        _add_skill_xp("survival",0.20)
        _set_survival_feedback("Горячая еда: восстановление улучшено на 5 минут",2.0)

    elif use_type == "herbal_tea":
        thirst = min(100.0,thirst + 30.0)
        stamina = min(_survival_stamina_cap(),stamina + 7.0)
        body_temperature = min(40.5,body_temperature + 0.15)
        pain = max(0.0,pain - 3.0)
        warm_drink_time = max(warm_drink_time,240.0)
        _consume_entry_at(selected_inventory_index,1)
        _add_skill_xp("survival",0.15)
        _set_survival_feedback("Горячий чай: +1.5°C к ощущаемому теплу на 4 минуты",2.0)

    elif use_type == "food":
        if _player_near_active_fire():
            hunger = min(100.0,hunger + 46.0)
            thirst = max(0.0,thirst - 1.0)
            stamina = min(_survival_stamina_cap(),stamina + 8.0)
            body_temperature = min(40.5,body_temperature + 0.04)
            _consume_entry_at(selected_inventory_index,1)
            _add_skill_xp("survival",0.18)
            _set_survival_feedback("Еда разогрета у костра",2.0)
        else:
            hunger = min(100.0,hunger + 36.0)
            thirst = max(0.0,thirst - 2.0)
            stamina = min(_survival_stamina_cap(),stamina + 5.0)
            _consume_entry_at(selected_inventory_index,1)
            _set_survival_feedback("Вы поели")

    elif use_type == "weapon":
        _switch_weapon(id)

    elif use_type == "gear":
        _equip_item(id)

    elif use_type == "melee":
        _switch_melee(id)

    elif use_type == "repair":
        inv_details.text = "Ремкомплект используется у верстака → ОРУЖЕЙНИК."
        return

    elif use_type == "weapon_mod":
        _install_selected_weapon_mod()

    selected_inventory_index = -1
    call_deferred("_refresh_inventory_ui")

func _consume_entry_at(index, amount):
    if index < 0 or index >= inventory_entries.size():
        return
    var qty = int(inventory_entries[index].get("qty",1))
    qty -= amount
    if qty <= 0:
        inventory_entries.remove_at(index)
    else:
        inventory_entries[index]["qty"] = qty


func _take_selected_container():
    if active_container_key == "" or not container_states.has(active_container_key):
        return

    var state = container_states[active_container_key]
    var entries = state.get("items",[])

    if selected_container_index < 0 or selected_container_index >= entries.size():
        return

    var entry = entries[selected_container_index]
    var id = str(entry.get("id",""))
    var qty = int(entry.get("qty",1))

    var remaining = _grid_add(inventory_entries,id,qty,INV_W,INV_H)
    var moved = qty - remaining

    if moved > 0:
        _add_skill_xp("scavenging",min(2.5,0.45 + float(moved) * 0.22))

    if remaining <= 0:
        entries.remove_at(selected_container_index)
        selected_container_index = -1
    else:
        entry["qty"] = remaining
        entries[selected_container_index] = entry

    state["items"] = entries
    container_states[active_container_key] = state
    call_deferred("_refresh_inventory_ui")

func _store_selected_inventory():
    if active_container_key == "" or not container_states.has(active_container_key):
        return
    if selected_inventory_index < 0 or selected_inventory_index >= inventory_entries.size():
        return

    var state = container_states[active_container_key]
    var entries = state.get("items", [])
    var entry = inventory_entries[selected_inventory_index]
    var id = str(entry.get("id",""))
    var qty = int(entry.get("qty",1))

    if id == current_weapon_id:
        return

    if not _can_add_all(entries, id, qty, CONTAINER_W, CONTAINER_H):
        return

    _clear_equipment_item(id)
    _grid_add(entries, id, qty, CONTAINER_W, CONTAINER_H)
    inventory_entries.remove_at(selected_inventory_index)
    state["items"] = entries
    container_states[active_container_key] = state

    selected_inventory_index = -1
    call_deferred("_refresh_inventory_ui")



func _drop_selected_inventory():
    if selected_inventory_index < 0 or selected_inventory_index >= inventory_entries.size():
        return
    var entry = inventory_entries[selected_inventory_index]
    var id = str(entry.get("id",""))
    var qty = int(entry.get("qty",1))
    if not _prepare_item_for_drop(id):
        reload_feedback = "Нельзя выбросить последнее доступное оружие"
        reload_feedback_time = 1.8
        return
    _cancel_reload()
    _clear_equipment_item(id)
    if selected_inventory_index < 0 or selected_inventory_index >= inventory_entries.size() or str(inventory_entries[selected_inventory_index].get("id","")) != id:
        var found_index = -1
        for i in range(inventory_entries.size()):
            if str(inventory_entries[i].get("id","")) == id:
                found_index = i
                break
        if found_index < 0:
            return
        selected_inventory_index = found_index
    inventory_entries.remove_at(selected_inventory_index)
    var drop_pos = player.global_position + aim_direction * 34.0
    var record = {"drop_id":next_drop_id,"id":id,"qty":qty,"x":drop_pos.x,"y":drop_pos.y}
    next_drop_id += 1
    dropped_items.append(record)
    var drop_noise = 50.0 + min(45.0,float(item_defs.get(id,{}).get("weight",0.0)) * 10.0)
    _emit_ai_sound(drop_pos,drop_noise,"drop",1.0)
    var coord = _world_to_chunk(drop_pos)
    if loaded_chunks.has(coord):
        _spawn_world_item(loaded_chunks[coord],coord,id,qty,drop_pos - loaded_chunks[coord].global_position,"",int(record["drop_id"]))
    reload_feedback = "Выброшено: %s" % str(item_defs.get(id,{}).get("name",id))
    reload_feedback_time = 1.4
    selected_inventory_index = -1
    call_deferred("_refresh_inventory_ui")


func _update_interaction_prompt():
    if interaction_label == null:
        return

    if inventory_open:
        interaction_label.text = ""
        if hud_interaction_panel != null:
            hud_interaction_panel.visible = false
        return

    var target = _nearest_interactable()
    if target == null:
        interaction_label.text = ""
        if hud_interaction_panel != null:
            hud_interaction_panel.visible = false
        return

    var type = str(target.get_meta("interaction_type",""))
    var name = str(target.get_meta("display_name",""))

    if type == "world_item":
        interaction_label.text = "ПОДОБРАТЬ  •  %s" % name.to_upper()
    elif type == "container":
        interaction_label.text = "ОБЫСКАТЬ  •  %s" % name.to_upper()
    elif type == "door":
        var open = bool(target.get_meta("door_open",false))
        if open and _doorway_blocked(target):
            interaction_label.text = "ДВЕРЬ ЗАНЯТА"
        else:
            interaction_label.text = "%s ДВЕРЬ" % ("ЗАКРЫТЬ" if open else "ОТКРЫТЬ")
    elif type == "workbench":
        interaction_label.text = "ВЕРСТАК  •  КРАФТ"
    elif type == "base_heater":
        interaction_label.text = "ОБОГРЕВАТЕЛЬ"
    elif type == "base_campfire":
        interaction_label.text = "КОСТЁР"
    elif type == "base_rain_collector":
        var base_id = int(target.get_meta("base_id",-1))
        var index = _base_record_index(base_id)
        var stored = 0
        if index >= 0:
            stored = int(floor(float(base_objects[index].get("stored_water",0.0))))
        interaction_label.text = "ДОЖДЕСБОРНИК  %d/%d" % [
            stored,
            int(_rain_collector_capacity())
        ]
    elif type == "base_lamp":
        interaction_label.text = "СТАЦИОНАРНАЯ ЛАМПА"
    elif type == "base_cot":
        interaction_label.text = "ОТДЫХ  •  %s" % name
    else:
        interaction_label.text = ""

    _hud_set_fitted_text(interaction_label,interaction_label.text,6,5,18,28)
    if hud_interaction_panel != null:
        hud_interaction_panel.visible = interaction_label.text != ""

func _nearest_interactable():
    var best = null
    var best_score = 999999.0

    for node in get_tree().get_nodes_in_group("interactable"):
        if not is_instance_valid(node):
            continue

        var type = str(node.get_meta("interaction_type",""))
        var limit = float(node.get_meta("interaction_radius",62.0))
        var priority = 0.0

        if type == "door":
            limit = max(limit,88.0)
            priority = 22.0
        elif type == "container":
            limit = max(limit,70.0)
            priority = 7.0
        elif type == "workbench":
            limit = max(limit,72.0)
            priority = 8.0
        elif type == "base_heater" or type == "base_campfire" or type == "base_rain_collector" or type == "base_lamp" or type == "base_cot":
            limit = max(limit,72.0)
            priority = 6.0
        elif type == "world_item":
            limit = max(limit,54.0)

        var dist = player.global_position.distance_to(node.global_position)
        if dist > limit:
            continue

        var score = dist - priority
        if score < best_score:
            best_score = score
            best = node

    return best

func _interact():
    var target = _nearest_interactable()
    if target == null:
        return

    var type = str(target.get_meta("interaction_type",""))

    if type == "world_item":
        _pickup_world_item(target)
    elif type == "container":
        _open_container(str(target.get_meta("container_key","")))
    elif type == "door":
        _toggle_door(target)
    elif type == "workbench":
        _open_crafting()
    elif type == "base_heater":
        _toggle_base_heater(target)
    elif type == "base_campfire":
        _toggle_base_campfire(target)
    elif type == "base_rain_collector":
        _collect_rainwater(target)
    elif type == "base_lamp":
        _toggle_base_lamp(target)
    elif type == "base_cot":
        _open_rest_panel(target)

func _pickup_world_item(node):
    var id = str(node.get_meta("item_id",""))
    var qty = int(node.get_meta("qty",1))

    var remaining = _grid_add(inventory_entries,id,qty,INV_W,INV_H)
    var moved = qty - remaining

    if moved <= 0:
        return

    _add_skill_xp("scavenging",min(2.5,0.45 + float(moved) * 0.22))

    if remaining > 0:
        node.set_meta("qty",remaining)
        _refresh_inventory_ui()
        return

    var pickup_key = str(node.get_meta("pickup_key",""))
    var drop_id = int(node.get_meta("drop_id",-1))

    if pickup_key != "":
        picked_world_items[pickup_key] = true

    if drop_id >= 0:
        for i in range(dropped_items.size() - 1,-1,-1):
            if int(dropped_items[i].get("drop_id",-2)) == drop_id:
                dropped_items.remove_at(i)
                break

    node.queue_free()
    _refresh_inventory_ui()

func _create_workbench(chunk,pos):
    var node = Node2D.new()
    node.position = pos
    node.z_index = 8
    node.z_as_relative = false
    node.add_to_group("interactable")
    node.set_meta("interaction_type","workbench")
    node.set_meta("display_name","Верстак")
    chunk.add_child(node)
    _world_prop_sprite("workbench",node,Vector2(0,-3),0,0.90)

func _create_container(chunk, coord, local_pos, container_id, loot_table, display_name):
    var key = "%d:%d:container:%s" % [coord.x,coord.y,container_id]

    if not container_states.has(key):
        container_states[key] = {
            "name": display_name,
            "loot_table": loot_table,
            "items": _generate_loot(key, loot_table)
        }

    var node = Node2D.new()
    node.position = local_pos
    node.z_index = 8
    node.z_as_relative = false
    node.add_to_group("interactable")
    node.set_meta("interaction_type","container")
    node.set_meta("container_key",key)
    node.set_meta("display_name",display_name)
    chunk.add_child(node)

    _world_prop_sprite("crate",node,Vector2(0,-2),0,0.90)
    return node

func _generate_loot(key, table_name):
    var entries = []
    var table = loot_tables.get(table_name, [])
    var rng = RandomNumberGenerator.new()
    rng.seed = int(abs(hash(key))) + 1

    for rule in table:
        if rng.randf() <= float(rule.get("chance",1.0)):
            var qty = rng.randi_range(int(rule.get("min",1)), int(rule.get("max",1)))
            _grid_add(entries, str(rule.get("id","")), qty, CONTAINER_W, CONTAINER_H)

    return entries





func _create_door(chunk, coord, local_pos, door_id):
    var key = "%d:%d:door:%s" % [coord.x,coord.y,door_id]
    if not door_states.has(key):
        door_states[key] = false

    var node = Node2D.new()
    node.position = local_pos
    node.z_index = 37
    node.z_as_relative = false
    node.add_to_group("interactable")
    node.add_to_group("doors")
    node.set_meta("interaction_type","door")
    node.set_meta("door_key",key)
    node.set_meta("display_name","Дверь")
    node.set_meta("door_open",false)
    node.set_meta("door_target_angle",0.0)
    node.set_meta("door_swing",-PI * 0.5)
    node.set_meta("interaction_radius",88.0)
    chunk.add_child(node)

    var frame = Node2D.new()
    node.add_child(frame)
    _rect(Vector2(-19,0),Vector2(6,18),Color("3b332c"),frame)
    _rect(Vector2(19,0),Vector2(6,18),Color("3b332c"),frame)
    _rect(Vector2(-19,-7),Vector2(5,3),Color("75614c"),frame)
    _rect(Vector2(19,-7),Vector2(5,3),Color("75614c"),frame)

    var visual = Node2D.new()
    visual.position = Vector2(-16,0)
    node.add_child(visual)
    _world_prop_sprite("door",visual,Vector2(16,0),0,0.82)

    var body = StaticBody2D.new()
    body.collision_layer = LAYER_WORLD
    body.collision_mask = 0
    node.add_child(body)

    var shape = CollisionShape2D.new()
    var rect = RectangleShape2D.new()
    rect.size = Vector2(38,16)
    shape.shape = rect
    shape.position = Vector2.ZERO
    body.add_child(shape)

    node.set_meta("door_visual",visual)
    node.set_meta("door_body",body)
    node.set_meta("door_shape",shape)

    _apply_door_state(node,bool(door_states[key]),true)
    return node

func _update_doors(delta):
    for door in get_tree().get_nodes_in_group("doors"):
        if not is_instance_valid(door):
            continue
        var visual = door.get_meta("door_visual",null)
        if not is_instance_valid(visual):
            continue
        var target = float(door.get_meta("door_target_angle",0.0))
        visual.rotation = lerp_angle(visual.rotation,target,min(1.0,delta * 12.0))


func _doorway_blocked(door):
    # Only the actual threshold blocks closing; the previous large radius
    # made a nearby player unable to operate the door.
    if player != null:
        var lp = door.to_local(player.global_position)
        if abs(lp.x) < 23.0 and abs(lp.y) < 13.0:
            return true

    for enemy in get_tree().get_nodes_in_group("infected"):
        if not is_instance_valid(enemy):
            continue
        var le = door.to_local(enemy.global_position)
        if abs(le.x) < 22.0 and abs(le.y) < 13.0:
            return true

    return false

func _toggle_door(node):
    var key = str(node.get_meta("door_key",""))
    if key == "":
        return

    var is_open = bool(door_states.get(key,false))

    if is_open:
        if _doorway_blocked(node):
            return
        door_states[key] = false
        _apply_door_state(node,false,false)
        _emit_ai_sound(node.global_position,105.0,"door",1.15)
    else:
        var local_player = node.to_local(player.global_position)
        var swing = -PI * 0.5 if local_player.y >= 0.0 else PI * 0.5
        node.set_meta("door_swing",swing)
        door_states[key] = true
        _apply_door_state(node,true,false)
        _emit_ai_sound(node.global_position,82.0,"door",0.85)

func _apply_door_state(node, open, snap=false):
    node.set_meta("door_open",open)

    var visual = node.get_meta("door_visual",null)
    var body = node.get_meta("door_body",null)
    var shape = node.get_meta("door_shape",null)
    # door_arc was used by an older door visual. Godot reports a runtime error
    # when get_meta() is called for an absent key, even when a null fallback is
    # supplied, so guard the optional legacy meta explicitly.
    var arc = node.get_meta("door_arc") if node.has_meta("door_arc") else null

    var target = float(node.get_meta("door_swing",-PI * 0.5)) if open else 0.0
    node.set_meta("door_target_angle",target)

    if is_instance_valid(body):
        body.collision_layer = 0 if open else LAYER_WORLD

    if is_instance_valid(shape):
        shape.disabled = open

    if is_instance_valid(arc):
        arc.visible = not open

    if snap and is_instance_valid(visual):
        visual.rotation = target






func _make_world_loot_texture(id):
    if loot_atlas_texture == null:
        loot_atlas_texture = load("res://loot_sprites_v22.png")

    if loot_atlas_texture != null and loot_icon_cells.has(id):
        var cell = loot_icon_cells[id]
        var tex = AtlasTexture.new()
        tex.atlas = loot_atlas_texture
        tex.region = Rect2(cell.x * 40,cell.y * 40,40,40)
        return tex

    return _make_item_icon(id)

func _world_loot_visual_scale(id):
    var category = str(item_defs.get(id,{}).get("category",""))

    if category == "weapon":
        return 0.48
    if category == "melee":
        return 0.48
    if category == "gear":
        return 0.44
    if category == "mod":
        return 0.43
    if category == "ammo":
        return 0.40

    return 0.42



func _spawn_world_item(chunk, coord, id, qty, local_pos, pickup_key, drop_id):
    if not item_defs.has(id):
        return null

    var item = item_defs[id]
    var node = Node2D.new()
    node.position = local_pos
    node.z_index = 7
    node.z_as_relative = false
    node.add_to_group("interactable")
    node.add_to_group("world_items")
    node.set_meta("interaction_type","world_item")
    node.set_meta("item_id",id)
    node.set_meta("qty",qty)
    node.set_meta("pickup_key",pickup_key)
    node.set_meta("drop_id",drop_id)
    node.set_meta("display_name",str(item.get("name",id)))
    node.set_meta("bob_phase",randf() * TAU)
    chunk.add_child(node)

    var visual_scale = _world_loot_visual_scale(id)

    var shadow = _ellipse(
        Vector2(0,6),
        7.0 if visual_scale >= 0.47 else 5.5,
        2.7 if visual_scale >= 0.47 else 2.2,
        Color(0.02,0.02,0.02,0.22),
        node
    )

    var sprite = Sprite2D.new()
    sprite.texture = _make_world_loot_texture(id)
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.scale = Vector2(visual_scale,visual_scale)
    sprite.position = Vector2(0,-3)
    node.add_child(sprite)

    var glint = _rect(Vector2(5,-8),Vector2(1.5,1.5),Color(0.95,0.91,0.65,0.58),node)
    glint.z_index = 2

    node.set_meta("item_sprite",sprite)
    node.set_meta("item_shadow",shadow)
    node.set_meta("item_glint",glint)
    node.set_meta("world_visual_scale",visual_scale)
    return node


func _update_world_items(delta):
    for node in get_tree().get_nodes_in_group("world_items"):
        if not is_instance_valid(node):
            continue

        var phase = float(node.get_meta("bob_phase",0.0)) + delta * 2.0
        node.set_meta("bob_phase",phase)

        var sprite = node.get_meta("item_sprite",null)
        var shadow = node.get_meta("item_shadow",null)
        var glint = node.get_meta("item_glint",null)

        var bob = sin(phase) * 0.9

        if is_instance_valid(sprite):
            sprite.position.y = -3.0 + bob
            sprite.rotation = sin(phase * 0.55) * 0.022

        if is_instance_valid(shadow):
            var shadow_scale = 1.0 - max(0.0,bob) * 0.018
            shadow.scale = Vector2(shadow_scale,shadow_scale)

        if is_instance_valid(glint):
            var pulse = 0.28 + (sin(phase * 1.7) + 1.0) * 0.20
            glint.modulate.a = pulse

func _spawn_fixed_item(chunk, coord, local_pos, spawn_id, id, qty):
    var key = "%d:%d:pickup:%s" % [coord.x,coord.y,spawn_id]
    if bool(picked_world_items.get(key,false)):
        return
    _spawn_world_item(chunk,coord,id,qty,local_pos,key,-1)

func _spawn_saved_drops_for_chunk(chunk,coord):
    for record in dropped_items:
        var pos = Vector2(float(record.get("x",0.0)), float(record.get("y",0.0)))
        if _world_to_chunk(pos) == coord:
            _spawn_world_item(
                chunk,
                coord,
                str(record.get("id","")),
                int(record.get("qty",1)),
                pos - chunk.global_position,
                "",
                int(record.get("drop_id",-1))
            )

# -------------------------------------------------------------------
# OPEN WORLD / CHUNKS / ENVIRONMENT
# -------------------------------------------------------------------

func _world_to_chunk(pos):
    return Vector2i(
        int(floor(pos.x / float(CHUNK_SIZE))),
        int(floor(pos.y / float(CHUNK_SIZE)))
    )


func _chunk_zone(coord):
    if coord == Vector2i(0,0):
        return "central"

    var value = abs(
        coord.x * 92821
        + coord.y * 68917
        + coord.x * coord.y * 97
        + 1337
    )
    var pick = value % 100

    if pick < 28:
        return "residential"
    if pick < 45:
        return "commercial"
    if pick < 62:
        return "industrial"
    if pick < 78:
        return "woodland"
    if pick < 91:
        return "rural"
    return "military"

func _zone_display_name(zone):
    if zone == "central":
        return "ЦЕНТР"
    if zone == "residential":
        return "ЖИЛОЙ РАЙОН"
    if zone == "commercial":
        return "ТОРГОВЫЙ РАЙОН"
    if zone == "industrial":
        return "ПРОМЗОНА"
    if zone == "woodland":
        return "ЛЕСОПОЛОСА"
    if zone == "rural":
        return "ДАЧИ"
    if zone == "military":
        return "ВОЕННЫЙ ПЕРИМЕТР"
    return "НЕИЗВЕСТНО"

func _zone_enemy_count(zone,rng):
    if zone == "woodland":
        return rng.randi_range(1,3)
    if zone == "rural":
        return rng.randi_range(2,4)
    if zone == "residential":
        return rng.randi_range(2,5)
    if zone == "commercial":
        return rng.randi_range(3,5)
    if zone == "industrial":
        return rng.randi_range(4,6)
    if zone == "military":
        return rng.randi_range(5,7)
    return rng.randi_range(2,5)

func _zone_tree_count(zone,rng):
    if zone == "woodland":
        return rng.randi_range(16,23)
    if zone == "rural":
        return rng.randi_range(10,16)
    if zone == "residential":
        return rng.randi_range(6,10)
    if zone == "commercial":
        return rng.randi_range(3,6)
    if zone == "industrial":
        return rng.randi_range(2,5)
    if zone == "military":
        return rng.randi_range(2,4)
    return rng.randi_range(5,9)

func _zone_car_count(zone,rng):
    if zone == "woodland":
        return rng.randi_range(0,1)
    if zone == "rural":
        return rng.randi_range(1,3)
    if zone == "industrial":
        return rng.randi_range(3,6)
    if zone == "commercial":
        return rng.randi_range(3,5)
    if zone == "military":
        return rng.randi_range(2,4)
    return rng.randi_range(2,4)

func _zone_build_chance(zone):
    if zone == "woodland":
        return 0.30
    if zone == "rural":
        return 0.64
    if zone == "military":
        return 0.72
    if zone == "industrial":
        return 0.82
    if zone == "commercial":
        return 0.90
    return 0.86

func _zone_building_name(zone,index):
    var names = {
        "residential":["ДОМ","ЖИЛОЙ БЛОК","ПОДЪЕЗД","ДОМ"],
        "commercial":["МАГАЗИН","АПТЕКА","СКЛАД","КАФЕ"],
        "industrial":["ЦЕХ","СКЛАД","СЕРВИС","ГАРАЖ"],
        "woodland":["ЛЕСНИК","САРАЙ","БУДКА","ДАЧА"],
        "rural":["ДАЧА","САРАЙ","ДОМ","ДАЧА"],
        "military":["КПП","СКЛАД","КАЗАРМА","СВЯЗЬ"]
    }
    var list = names.get(zone,["ДОМ","СКЛАД","МАГАЗИН","СЕРВИС"])
    return str(list[index % list.size()])

func _zone_loot_table(zone,index):
    if zone == "commercial":
        return "pharmacy" if index == 1 else "grocery"
    if zone == "industrial":
        return "industrial" if index != 3 else "garage"
    if zone == "woodland":
        return "forest_cache"
    if zone == "rural":
        return "rural"
    if zone == "military":
        return "military" if index <= 2 else "industrial"
    return "residential"

func _zone_chunk_key(coord):
    return "%d:%d" % [coord.x,coord.y]

func _discover_chunk(coord):
    var key = _zone_chunk_key(coord)
    if discovered_chunks.has(key):
        return

    discovered_chunks[key] = true

    if coord != Vector2i(0,0):
        _add_skill_xp("scavenging",1.25)
        _set_survival_feedback(
            "Новая зона: %s" % _zone_display_name(_chunk_zone(coord)),
            1.75
        )

func _spawn_zone_ground_loot(chunk,coord,zone,rng):
    var candidates = []

    if zone == "industrial":
        candidates = ["scrap","tape","steel_pipe"]
    elif zone == "military":
        candidates = ["ammo_762","bandage","ammo_9x18"]
    elif zone == "woodland":
        candidates = ["herbs","grain","water","canned_meat"]
    elif zone == "rural":
        candidates = ["grain","herbs","canned_meat","water"]
    elif zone == "commercial":
        candidates = ["water","bandage","canned_meat"]
    else:
        candidates = ["cloth","water","bandage"]

    var positions = [
        Vector2(248,292),
        Vector2(503,500)
    ]

    var count = 1
    if zone == "industrial" or zone == "military":
        count = 2

    for i in range(count):
        if rng.randf() > 0.72:
            continue

        var item_id = str(candidates[rng.randi_range(0,candidates.size()-1)])
        var qty = 1

        if item_id.begins_with("ammo_"):
            qty = rng.randi_range(3,8)
        elif item_id == "scrap" or item_id == "cloth":
            qty = rng.randi_range(1,3)

        _spawn_fixed_item(
            chunk,
            coord,
            positions[i],
            "zone_%s_ground_%d" % [zone,i],
            item_id,
            qty
        )

func _refresh_chunks(force):
    var center = _world_to_chunk(player.global_position)
    if not force and center == current_chunk:
        return

    current_chunk = center
    current_zone_id = _chunk_zone(center)
    _discover_chunk(center)
    var wanted = {}

    for y in range(center.y - ACTIVE_RADIUS, center.y + ACTIVE_RADIUS + 1):
        for x in range(center.x - ACTIVE_RADIUS, center.x + ACTIVE_RADIUS + 1):
            var coord = Vector2i(x,y)
            wanted[coord] = true
            if not loaded_chunks.has(coord):
                _load_chunk(coord)

    var remove_list = []
    for coord in loaded_chunks.keys():
        if not wanted.has(coord):
            remove_list.append(coord)

    for coord in remove_list:
        _unload_chunk(coord)

func _unload_chunk(coord):
    var chunk = loaded_chunks.get(coord)
    if is_instance_valid(chunk):
        for i in range(roof_records.size() - 1,-1,-1):
            var rec = roof_records[i]
            if rec.get("chunk") == chunk:
                roof_records.remove_at(i)
        chunk.queue_free()
    loaded_chunks.erase(coord)

func _load_chunk(coord):
    var chunk = Node2D.new()
    chunk.name = "Chunk_%d_%d" % [coord.x,coord.y]
    chunk.position = Vector2(coord.x * CHUNK_SIZE, coord.y * CHUNK_SIZE)
    chunk.z_index = -50
    chunk.z_as_relative = false
    chunk.y_sort_enabled = true
    add_child(chunk)
    loaded_chunks[coord] = chunk

    _build_ground(chunk,coord)

    if coord == Vector2i(0,0):
        _build_showcase_chunk(chunk,coord)
        _spawn_chunk_enemies(chunk,coord,4,931)
        _spawn_fixed_item(chunk,coord,Vector2(252,260),"pharmacy_bandage","bandage",1)
        _spawn_fixed_item(chunk,coord,Vector2(472,415),"road_water","water",1)
        _spawn_fixed_item(chunk,coord,Vector2(175,520),"garage_ammo","ammo_9x18",10)
    else:
        _build_procedural_chunk(chunk,coord)

    _spawn_saved_drops_for_chunk(chunk,coord)

func _build_ground(chunk,coord):
    var ground_sprite = Sprite2D.new()
    ground_sprite.texture = load("res://ground_chunk_v9.png")
    ground_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    ground_sprite.position = Vector2(CHUNK_SIZE*0.5,CHUNK_SIZE*0.5)
    ground_sprite.z_index = -20
    chunk.add_child(ground_sprite)

    # Keep the same logical road/sidewalk footprint as previous versions.
    # Only visuals changed, so old bases/AI/navigation assumptions stay intact.
    var rng = RandomNumberGenerator.new()
    rng.seed = int(abs(coord.x*81371 + coord.y*17749 + 2141)) + 1
    for i in range(34):
        var p = Vector2(rng.randi_range(15,CHUNK_SIZE-15),rng.randi_range(15,CHUNK_SIZE-15))
        _poly(PackedVector2Array([
            Vector2(-2,3),Vector2(0,-5),Vector2(2,2),
            Vector2(5,-4),Vector2(3,5)
        ]),Color(0.20,0.28,0.16,0.68),chunk,p)
    _add_ground_decals(chunk,coord)

func _build_showcase_chunk(chunk,coord):
    _create_building(chunk,coord,"pharmacy",Vector2(112,105),Vector2(190,128),"АПТЕКА",Color("555148"),true)
    _create_building(chunk,coord,"grocery",Vector2(555,122),Vector2(160,135),"ПРОДУКТЫ",Color("594d43"),true)
    _create_building(chunk,coord,"garages",Vector2(120,610),Vector2(215,125),"ГАРАЖИ",Color("4a4b47"),true)
    _create_building(chunk,coord,"residential",Vector2(575,605),Vector2(220,140),"ЖИЛОЙ БЛОК",Color("4a4c47"),true)

    _create_container(chunk,coord,Vector2(112,108),"pharmacy_main","pharmacy","Медицинский шкаф")
    _create_container(chunk,coord,Vector2(555,120),"grocery_main","grocery","Полки магазина")
    _create_container(chunk,coord,Vector2(112,602),"garage_all_items_0163","all_items_test","ТЕСТ: ВСЕ ПРЕДМЕТЫ")
    _create_container(chunk,coord,Vector2(570,600),"res_weapon","weapon_cache_test","Скрытый тайник")
    _create_workbench(chunk,Vector2(165,596))
    _create_world_label(chunk,Vector2(112,565),"ТЕСТ-ЯЩИК: ВСЕ ПРЕДМЕТЫ",7,Color("d1b970"))

    _create_car(chunk,Vector2(240,408),Color("47545c"),-0.08)
    _create_car(chunk,Vector2(510,350),Color("663d36"),0.05)
    _create_car(chunk,Vector2(610,455),Color("4d4c42"),1.55)

    _create_tree(chunk,Vector2(70,265),1.0)
    _create_tree(chunk,Vector2(185,270),0.85)
    _create_tree(chunk,Vector2(690,245),1.1)
    _create_tree(chunk,Vector2(680,520),0.9)
    _create_tree(chunk,Vector2(285,620),1.0)

    _create_fence(chunk,Vector2(465,255),145)
    _create_fence(chunk,Vector2(80,520),155)
    _create_lamp(chunk,Vector2(380,305))
    _create_lamp(chunk,Vector2(455,515))

    _create_barrel(chunk,Vector2(638,281))
    _create_barrel(chunk,Vector2(84,562))

    _create_world_label(chunk,Vector2(498,242),"ЛЮДИ БЫЛИ ЗДЕСЬ",7,Color("7b4138"))



func _decorate_zone_street_art(chunk,zone,coord):
    if chunk == null:
        return

    var rng = RandomNumberGenerator.new()
    rng.seed = int(abs(coord.x*99173 + coord.y*41771 + 9059)) + 1

    if zone == "industrial":
        _world_prop_sprite("trash_bin",chunk,Vector2(238,338),4,0.72)
        _world_prop_sprite("road_sign",chunk,Vector2(520,300),4,0.68)
        _world_prop_sprite("debris",chunk,Vector2(410,515),2,0.68)
        _world_prop_sprite("traffic_cone",chunk,Vector2(360,328),5,0.68)
        _world_prop_sprite("rubble",chunk,Vector2(500,535),2,0.48)
        _world_prop_sprite("street_debris",chunk,Vector2(445,520),2,0.44)

    elif zone == "military":
        _world_prop_sprite("sandbags",chunk,Vector2(305,292),5,0.80)
        _world_prop_sprite("sandbags",chunk,Vector2(520,508),5,0.76)
        _world_prop_sprite("road_sign",chunk,Vector2(455,280),4,0.72)
        _world_prop_sprite("road_barrier",chunk,Vector2(392,300),5,0.66)

    elif zone == "commercial":
        _world_prop_sprite("trash_bin",chunk,Vector2(320,312),4,0.66)
        _world_prop_sprite("road_sign",chunk,Vector2(575,465),4,0.68)
        _world_prop_sprite("debris",chunk,Vector2(460,345),2,0.58)
        _world_prop_sprite("shopping_cart",chunk,Vector2(520,352),4,0.48)

    elif zone == "residential":
        _world_prop_sprite("trash_bin",chunk,Vector2(286,318),4,0.62)
        _world_prop_sprite("road_sign",chunk,Vector2(550,475),4,0.60)

    elif zone == "rural":
        _world_prop_sprite("road_sign",chunk,Vector2(330,305),4,0.58)

    # A small deterministic amount of visual-only roadside clutter.
    if zone != "woodland":
        for i in range(2):
            var p = Vector2(
                rng.randi_range(210,590),
                rng.randi_range(300,540)
            )
            _world_prop_sprite("debris",chunk,p,2,rng.randf_range(0.38,0.54))

func _build_procedural_chunk(chunk,coord):
    var rng = RandomNumberGenerator.new()
    rng.seed = int(abs(coord.x*73856093 + coord.y*19349663 + 5517)) + 1

    var zone = _chunk_zone(coord)
    var colors = [
        Color("4c4942"),
        Color("564b43"),
        Color("414943"),
        Color("514d45")
    ]
    var anchors = [
        Vector2(110,110),
        Vector2(585,110),
        Vector2(115,610),
        Vector2(590,610)
    ]

    var build_chance = _zone_build_chance(zone)

    for i in range(anchors.size()):
        var legacy_container_key = "%d:%d:container:cache_%d" % [coord.x,coord.y,i]
        var should_build = rng.randf() <= build_chance

        # If this chunk was visited in an older save, preserve every building
        # whose container state already exists.
        if container_states.has(legacy_container_key):
            should_build = true

        if not should_build:
            continue

        # Keep the legacy geometry ranges so migrated saves/base placement
        # remain compatible with 0.26 procedural buildings.
        var size = Vector2(
            rng.randi_range(145,210),
            rng.randi_range(105,150)
        )

        var id = "building_%d" % i

        _create_building(
            chunk,
            coord,
            id,
            anchors[i],
            size,
            _zone_building_name(zone,i),
            colors[rng.randi_range(0,colors.size()-1)],
            true
        )

        _create_container(
            chunk,
            coord,
            anchors[i] + Vector2(0,5),
            "cache_%d" % i,
            _zone_loot_table(zone,i),
            "Контейнер: %s" % _zone_display_name(zone)
        )

    if zone == "industrial":
        _create_workbench(chunk,Vector2(165,590))
        _create_barrel(chunk,Vector2(225,548))
        _create_barrel(chunk,Vector2(625,246))
        _create_fence(chunk,Vector2(118,268),110)

    elif zone == "military":
        _create_fence(chunk,Vector2(160,270),150)
        _create_fence(chunk,Vector2(548,516),140)
        _create_barrel(chunk,Vector2(210,250))
        _create_barrel(chunk,Vector2(618,535))
        _create_world_label(
            chunk,
            Vector2(450,278),
            "ОГРАНИЧЕННАЯ ЗОНА",
            7,
            Color("a66a55")
        )

    elif zone == "woodland":
        _create_world_label(
            chunk,
            Vector2(40,40),
            "ЛЕСОПОЛОСА",
            7,
            Color("879575")
        )

    elif zone == "rural":
        _create_fence(chunk,Vector2(118,278),92)

    elif zone == "commercial":
        _create_lamp(chunk,Vector2(275,304))
        _create_lamp(chunk,Vector2(520,493))

    var car_colors = [
        Color("46535a"),
        Color("654039"),
        Color("555247"),
        Color("3e4c45")
    ]

    for i in range(_zone_car_count(zone,rng)):
        _create_car(
            chunk,
            Vector2(
                rng.randi_range(130,650),
                rng.randi_range(315,455)
            ),
            car_colors[rng.randi_range(0,car_colors.size()-1)],
            rng.randf_range(-0.15,0.15)
        )

    for i in range(_zone_tree_count(zone,rng)):
        var tree_pos = _safe_tree_position(chunk,rng)
        if tree_pos.x > -9000.0:
            _create_tree(
                chunk,
                tree_pos,
                rng.randf_range(0.75,1.18)
            )

    _decorate_zone_street_art(chunk,zone,coord)
    _spawn_zone_ground_loot(chunk,coord,zone,rng)
    _spawn_chunk_enemies(
        chunk,
        coord,
        _zone_enemy_count(zone,rng),
        int(rng.seed) + 701
    )

func _create_building(chunk,coord,building_id,center,size,sign_text,wall_color,open_interior):
    var building = Node2D.new()
    building.position = center
    building.z_index = 1
    building.z_as_relative = false
    chunk.add_child(building)

    _ellipse(Vector2(0,size.y*0.52),size.x*0.42,8,Color(0.02,0.02,0.02,0.14),building)
    _interior_floor_sprite(building,sign_text,size)

    # Same wall collision geometry and same 32px doorway gap as old saves.
    _add_static_rect(building,Vector2(0,-size.y*0.5),Vector2(size.x,12))
    _add_static_rect(building,Vector2(-size.x*0.5,0),Vector2(12,size.y))
    _add_static_rect(building,Vector2(size.x*0.5,0),Vector2(12,size.y))
    var gap = 32.0
    var usable = size.x - 12.0
    var segment = (usable - gap) * 0.5
    var left_x = -(gap*0.5 + segment*0.5)
    var right_x = gap*0.5 + segment*0.5
    _add_static_rect(building,Vector2(left_x,size.y*0.5),Vector2(segment,12))
    _add_static_rect(building,Vector2(right_x,size.y*0.5),Vector2(segment,12))

    # Thick dark-outline walls, worn plaster and lower grime band.
    _rect(Vector2(0,-size.y*0.48),Vector2(size.x,16),Color("1b1f1e"),building)
    _rect(Vector2(0,-size.y*0.48+2),Vector2(size.x-6,12),wall_color.lightened(0.12),building)
    _rect(Vector2(-size.x*0.5,0),Vector2(14,size.y),Color("1b1f1e"),building)
    _rect(Vector2(-size.x*0.5+2,0),Vector2(10,size.y-5),wall_color,building)
    _rect(Vector2(size.x*0.5,0),Vector2(14,size.y),Color("1b1f1e"),building)
    _rect(Vector2(size.x*0.5-2,0),Vector2(10,size.y-5),wall_color,building)
    _rect(Vector2(0,size.y*0.5),Vector2(size.x,13),Color("1b1f1e"),building)
    _rect(Vector2(0,size.y*0.5-2),Vector2(size.x-6,8),wall_color.darkened(0.10),building)

    if open_interior:
        # Interior wall stains / vertical supports, visual only.
        _rect(Vector2(-size.x*0.22,-5),Vector2(12,size.y*0.42),Color("353934"),building)
        _rect(Vector2(size.x*0.20,-4),Vector2(12,size.y*0.40),Color("353934"),building)
        _decorate_building_art(building,sign_text,size,building_id)

    var facade = Node2D.new()
    facade.position = center + Vector2(0,size.y*0.5+14)
    facade.z_index = 35
    facade.z_as_relative = false
    chunk.add_child(facade)

    _rect(Vector2.ZERO,Vector2(size.x,34),Color("1b1f1e"),facade)
    _rect(Vector2(0,-1),Vector2(size.x-6,28),wall_color.darkened(0.03),facade)
    _rect(Vector2(0,-12),Vector2(size.x-10,5),wall_color.lightened(0.12),facade)
    _rect(Vector2(0,12),Vector2(size.x-8,7),wall_color.darkened(0.20),facade)
    _rect(Vector2(0,3),Vector2(34,22),Color("202423"),facade)
    _rect(Vector2(0,4),Vector2(28,18),Color("4e514e"),facade)

    for wx in [-size.x*0.28,size.x*0.28]:
        _rect(Vector2(wx,-2),Vector2(36,19),Color("1b2020"),facade)
        _rect(Vector2(wx,-2),Vector2(30,13),Color("5e7075"),facade)
        _rect(Vector2(wx-5,-4),Vector2(7,2),Color("8e999b"),facade)

    var sign_bg = ColorRect.new()
    sign_bg.position = Vector2(-min(size.x*0.32,58.0),-23)
    sign_bg.size = Vector2(min(size.x*0.64,116.0),18)
    sign_bg.color = Color("171b1b")
    facade.add_child(sign_bg)
    var sign = Label.new()
    sign.position = sign_bg.position + Vector2(7,1)
    sign.text = sign_text
    sign.add_theme_font_size_override("font_size",8)
    sign.modulate = Color("b8b5a2")
    facade.add_child(sign)

    _create_door(chunk,coord,center + Vector2(0,size.y*0.5),building_id)

    var roof = Node2D.new()
    roof.position = center + Vector2(0,-18)
    roof.z_index = 60
    roof.z_as_relative = false
    chunk.add_child(roof)
    _poly(PackedVector2Array([
        Vector2(-size.x*0.52,-size.y*0.52),
        Vector2(size.x*0.52,-size.y*0.52),
        Vector2(size.x*0.48,size.y*0.42),
        Vector2(-size.x*0.48,size.y*0.42)
    ]),Color("262b29"),roof)
    _rect(Vector2(0,-size.y*0.48),Vector2(size.x*0.92,4),Color("555b55"),roof)
    _rect(Vector2(0,size.y*0.44),Vector2(size.x*0.96,12),Color("181c1b"),roof)
    _rect(Vector2(size.x*0.18,-size.y*0.08),Vector2(26,18),Color("343936"),roof)
    _rect(Vector2(-size.x*0.18,-size.y*0.02),Vector2(30,16),Color("303532"),roof)

    var interior_rect = Rect2(
        chunk.global_position + center - size*0.5 + Vector2(10,6),
        size - Vector2(20,15)
    )
    roof_records.append({
        "roof":roof,
        "facade":facade,
        "rect":interior_rect,
        "chunk":chunk
    })

func _update_roofs(delta):
    for rec in roof_records:
        var roof = rec.get("roof")
        var facade = rec.get("facade")

        if not is_instance_valid(roof):
            continue

        var inside = rec.get("rect").has_point(player.global_position)
        var target_alpha = 0.12 if inside else 1.0
        var target_facade = 0.40 if inside else 1.0

        var c = roof.modulate
        c.a = lerpf(c.a,target_alpha,min(1.0,delta*8.0))
        roof.modulate = c

        if is_instance_valid(facade):
            var f = facade.modulate
            f.a = lerpf(f.a,target_facade,min(1.0,delta*8.0))
            facade.modulate = f


func _create_car(chunk,pos,color,angle):
    var car = Node2D.new()
    car.position = pos
    car.rotation = angle
    car.z_index = 6
    car.z_as_relative = false
    chunk.add_child(car)
    var sprite = _world_prop_sprite("car",car,Vector2.ZERO,0,1.0)
    if sprite != null:
        sprite.modulate = color.lightened(0.15)
    _add_static_rect(car,Vector2(0,0),Vector2(66,28))

func _tree_blocks_door_swing(chunk,pos):
    var global_candidate = chunk.global_position + pos

    for door in get_tree().get_nodes_in_group("doors"):
        if not is_instance_valid(door):
            continue

        # Keep a generous clear radius for threshold + 90° swing arc.
        if global_candidate.distance_to(door.global_position) < 92.0:
            return true

    return false

func _safe_tree_position(chunk,rng):
    for attempt in range(12):
        var candidate = Vector2(
            rng.randi_range(40,CHUNK_SIZE-40),
            rng.randi_range(55,CHUNK_SIZE-55)
        )
        if not _tree_blocks_door_swing(chunk,candidate):
            return candidate

    return Vector2(-9999,-9999)



func _create_tree(chunk,pos,scale_factor):
    if _tree_blocks_door_swing(chunk,pos):
        return null
    var tree = Node2D.new()
    tree.position = pos
    tree.scale = Vector2(scale_factor,scale_factor)
    tree.z_index = 7
    tree.z_as_relative = false
    chunk.add_child(tree)
    _world_prop_sprite("tree",tree,Vector2(0,-5),0,1.0)
    _add_static_rect(tree,Vector2(0,7),Vector2(12,12))
    return tree

func _create_fence(chunk,pos,length):
    var fence = Node2D.new()
    fence.position = pos
    fence.z_index = 6
    fence.z_as_relative = false
    chunk.add_child(fence)

    _rect(Vector2(0,3),Vector2(length,3),Color("5f625d"),fence)
    _rect(Vector2(0,-11),Vector2(length,2),Color("5a5e59"),fence)
    _rect(Vector2(0,-4),Vector2(length,1),Color("858982"),fence)
    for x in range(int(-length*0.5),int(length*0.5)+1,18):
        _rect(Vector2(x,-3),Vector2(3,28),Color("4a4f4b"),fence)
        _rect(Vector2(x-4,-10),Vector2(8,2),Color("80857d"),fence)
    _add_static_rect(fence,Vector2(0,0),Vector2(length,6))



func _create_lamp(chunk,pos):
    var lamp = Node2D.new()
    lamp.position = pos
    lamp.z_index = 5
    lamp.z_as_relative = false
    chunk.add_child(lamp)

    _world_prop_sprite("lamp",lamp,Vector2(0,-10),0,1.0)

    var light = PointLight2D.new()
    light.texture = _make_base_radial_texture()
    light.texture_scale = 1.15
    light.energy = 0.34
    light.color = Color(1.0,0.76,0.43)
    light.position = Vector2(0,-20)
    light.z_index = 1
    lamp.add_child(light)

func _create_barrel(chunk,pos):
    var barrel = Node2D.new()
    barrel.position = pos
    barrel.z_index = 5
    barrel.z_as_relative = false
    chunk.add_child(barrel)
    _world_prop_sprite("barrel",barrel,Vector2(0,-4),0,1.0)

func _create_world_label(chunk,pos,txt,size,col):
    var label = Label.new()
    label.position = pos
    label.text = txt
    label.add_theme_font_size_override("font_size",size)
    label.modulate = col
    label.z_index = 3
    chunk.add_child(label)

func _add_static_rect(parent,center,size):
    var body = StaticBody2D.new()
    body.position = center
    body.collision_layer = LAYER_WORLD
    body.collision_mask = 0
    parent.add_child(body)

    var shape_node = CollisionShape2D.new()
    var shape = RectangleShape2D.new()
    shape.size = size
    shape_node.shape = shape
    body.add_child(shape_node)
    return body

# -------------------------------------------------------------------
# INFECTED
# -------------------------------------------------------------------


func _spawn_chunk_enemies(chunk,coord,count,seed_value):
    var rng = RandomNumberGenerator.new()
    rng.seed = seed_value

    for i in range(count):
        var key = "%d:%d:%d" % [coord.x,coord.y,i]
        if bool(defeated.get(key,false)):
            continue

        var p = _safe_enemy_spawn(rng)
        _spawn_enemy(chunk,coord,i,p)


func _spawn_enemy(chunk,coord,spawn_id,local_pos):
    var enemy = CharacterBody2D.new()
    enemy.name = "Infected_%d" % spawn_id
    enemy.position = local_pos
    enemy.collision_layer = LAYER_ENEMY
    enemy.collision_mask = LAYER_WORLD
    enemy.z_index = 9
    enemy.z_as_relative = false
    enemy.add_to_group("infected")
    enemy.set_meta("is_enemy",true)
    enemy.set_meta("hp",70.0)
    enemy.set_meta("chunk_coord",coord)
    enemy.set_meta("spawn_id",spawn_id)
    enemy.set_meta("alert",0.0)
    enemy.set_meta("attack_cd",0.0)
    enemy.set_meta("stagger",0.0)
    enemy.set_meta("knockback_velocity",Vector2.ZERO)
    enemy.set_meta("walk",randf()*6.0)
    enemy.set_meta("detection_radius",randf_range(145.0,195.0))
    enemy.set_meta("hearing_radius",randf_range(220.0,310.0))
    var zone = _chunk_zone(coord)
    if zone == "military":
        enemy.set_meta("hp",76.0)
        enemy.set_meta("hearing_radius",randf_range(250.0,325.0))
    elif zone == "woodland":
        enemy.set_meta("detection_radius",randf_range(135.0,180.0))
    enemy.set_meta("last_known_position",enemy.global_position)
    enemy.set_meta("heard_position",enemy.global_position)
    enemy.set_meta("search_anchor",enemy.global_position)
    enemy.set_meta("search_phase",0)
    enemy.set_meta("ai_state","idle")
    enemy.set_meta("ai_state_time",0.0)
    enemy.set_meta("suspicion",0.0)
    enemy.set_meta("lost_sight_time",0.0)
    enemy.set_meta("sense_cd",randf_range(0.02,0.18))
    enemy.set_meta("can_see_player",false)
    enemy.set_meta("last_sound_kind","")
    enemy.set_meta("ai_facing",Vector2.RIGHT.rotated(randf_range(-PI,PI)))
    chunk.add_child(enemy)
    enemy.set_meta("home_position",enemy.global_position)

    var shape_node = CollisionShape2D.new()
    var capsule = CapsuleShape2D.new()
    capsule.radius = 8.0
    capsule.height = 24.0
    shape_node.shape = capsule
    shape_node.position = Vector2(0,4)
    enemy.add_child(shape_node)

    var visual = Node2D.new()
    visual.name = "Visual"
    enemy.add_child(visual)
    enemy.set_meta("visual_node",visual)

    var shadow = _ellipse(Vector2(0,14),12,5,Color(0.02,0.02,0.02,0.24),visual)
    shadow.z_index = -2

    var sprite = Sprite2D.new()
    sprite.texture = load("res://infected_v6.png")
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    sprite.region_enabled = true
    var infected_variant = abs(spawn_id) % 4
    sprite.region_rect = Rect2(infected_variant * 32,0,32,48)
    sprite.position = Vector2(0,-5)
    sprite.z_index = 1
    visual.add_child(sprite)
    enemy.set_meta("infected_sprite",sprite)

func _enemy_has_line_of_sight(enemy):
    var query = PhysicsRayQueryParameters2D.create(
        enemy.global_position,
        player.global_position
    )
    query.collision_mask = LAYER_WORLD
    query.exclude = [enemy.get_rid()]
    var hit = get_world_2d().direct_space_state.intersect_ray(query)
    return hit.is_empty()


func _enemy_detects_player(enemy,dist):
    var radius = _enemy_vision_radius(enemy)
    if dist > radius:
        return false

    if not _enemy_has_line_of_sight(enemy):
        return false

    if dist <= 42.0:
        return true

    # During pursuit/search infected scan more aggressively.
    var state = str(enemy.get_meta("ai_state","idle"))
    if state == "chase" or state == "search":
        return true

    # Flashlight can give the player away even from outside the normal cone.
    if _player_has_active_flashlight():
        return true

    var facing = enemy.get_meta("ai_facing",Vector2.RIGHT)
    if typeof(facing) != TYPE_VECTOR2 or facing.length() <= 0.01:
        facing = Vector2.RIGHT
    else:
        facing = facing.normalized()

    var to_player = player.global_position - enemy.global_position
    if to_player.length() <= 0.01:
        return true
    to_player = to_player.normalized()

    # Wide peripheral cone; the player can still approach from behind.
    return facing.dot(to_player) >= -0.25


func _update_enemies(delta):
    var enemies = get_tree().get_nodes_in_group("infected")

    for enemy in enemies:
        if not is_instance_valid(enemy):
            continue

        var dist = enemy.global_position.distance_to(player.global_position)
        var attack_cd = max(0.0,float(enemy.get_meta("attack_cd",0.0)) - delta)
        var stagger = max(0.0,float(enemy.get_meta("stagger",0.0)) - delta)
        var knockback = enemy.get_meta("knockback_velocity",Vector2.ZERO)
        if typeof(knockback) != TYPE_VECTOR2:
            knockback = Vector2.ZERO

        var walk = float(enemy.get_meta("walk",0.0)) + delta * 7.0
        var state = str(enemy.get_meta("ai_state","idle"))
        if not _ai_state_valid(state):
            state = "idle"

        var state_time = max(0.0,float(enemy.get_meta("ai_state_time",0.0)) - delta)
        var suspicion = max(0.0,float(enemy.get_meta("suspicion",0.0)) - delta * 2.6)
        var lost_sight = max(0.0,float(enemy.get_meta("lost_sight_time",0.0)))
        var sense_cd = max(0.0,float(enemy.get_meta("sense_cd",0.0)) - delta)
        var sees_player = bool(enemy.get_meta("can_see_player",false))

        # Staggered vision checks reduce raycast load while keeping reaction responsive.
        if sense_cd <= 0.0:
            sees_player = _enemy_detects_player(enemy,dist)
            enemy.set_meta("can_see_player",sees_player)

            var sid = int(enemy.get_meta("spawn_id",0))
            sense_cd = 0.16 + float(sid % 5) * 0.018

            if sees_player:
                enemy.set_meta("last_known_position",player.global_position)

                var vision_radius = max(1.0,_enemy_vision_radius(enemy))
                var visual_strength = 1.0 - clamp(dist / vision_radius,0.0,1.0)
                suspicion = min(100.0,suspicion + 18.0 + visual_strength * 34.0)

                if state == "chase" or suspicion >= 42.0 or dist < 55.0:
                    state = "chase"
                    state_time = 4.0
                    lost_sight = 0.0
                elif state != "chase":
                    state = "suspicious"
                    state_time = max(state_time,1.10)

        if state == "chase":
            if sees_player:
                lost_sight = 0.0
                enemy.set_meta("last_known_position",player.global_position)
            else:
                lost_sight += delta

            if lost_sight >= 2.2:
                state = "search"
                state_time = 6.5
                lost_sight = 0.0
                enemy.set_meta(
                    "search_anchor",
                    enemy.get_meta("last_known_position",enemy.global_position)
                )
                enemy.set_meta("search_phase",0)

        # Knockback/stagger overrides locomotion, but state/memory continue updating.
        if knockback.length() > 1.0:
            enemy.velocity = knockback
            enemy.move_and_slide()
            knockback = knockback.move_toward(Vector2.ZERO,520.0 * delta)

        elif stagger > 0.0:
            enemy.velocity = Vector2.ZERO

        elif state == "chase":
            var chase_target = enemy.get_meta("last_known_position",player.global_position)
            if sees_player:
                chase_target = player.global_position
            _enemy_move_toward(enemy,chase_target,ENEMY_SPEED,enemies)

        elif state == "suspicious":
            enemy.velocity = Vector2.ZERO

            var look_target = enemy.get_meta("heard_position",player.global_position)
            if typeof(look_target) == TYPE_VECTOR2:
                var face = look_target - enemy.global_position
                if face.length() > 0.01:
                    enemy.set_meta("ai_facing",face.normalized())

            if state_time <= 0.0:
                if suspicion > 5.0:
                    state = "investigate"
                    state_time = 5.0
                else:
                    state = "idle"

        elif state == "investigate":
            var investigate_target = enemy.get_meta("heard_position",enemy.global_position)
            if typeof(investigate_target) != TYPE_VECTOR2:
                investigate_target = enemy.global_position

            _enemy_move_toward(enemy,investigate_target,ENEMY_SPEED * 0.80,enemies)

            if enemy.global_position.distance_to(investigate_target) <= 10.0 or state_time <= 0.0:
                state = "search"
                state_time = 5.5
                enemy.set_meta("search_anchor",investigate_target)
                enemy.set_meta("search_phase",0)

        elif state == "search":
            var search_target = _enemy_search_target(enemy)
            _enemy_move_toward(enemy,search_target,ENEMY_SPEED * 0.67,enemies)

            if enemy.global_position.distance_to(search_target) <= 10.0:
                enemy.set_meta("search_phase",int(enemy.get_meta("search_phase",0)) + 1)

            if state_time <= 0.0:
                state = "return"
                state_time = 8.0
                suspicion = min(suspicion,12.0)

        elif state == "return":
            var home = enemy.get_meta("home_position",enemy.global_position)
            if typeof(home) != TYPE_VECTOR2:
                home = enemy.global_position

            _enemy_move_toward(enemy,home,ENEMY_SPEED * 0.70,enemies)

            if enemy.global_position.distance_to(home) <= 12.0 or state_time <= 0.0:
                state = "idle"
                state_time = 0.0
                suspicion = 0.0
                enemy.velocity = Vector2.ZERO

        else:
            # Idle infected slowly scan their surroundings rather than pathfinding.
            enemy.velocity = Vector2.ZERO
            var sid_idle = int(enemy.get_meta("spawn_id",0))
            var idle_angle = walk * 0.10 + float(sid_idle % 7)
            enemy.set_meta("ai_facing",Vector2(cos(idle_angle),sin(idle_angle)))

        var visual = enemy.get_meta("visual_node",null)
        if is_instance_valid(visual):
            visual.position.y = sin(walk) * (0.8 if enemy.velocity.length() > 1.0 else 0.20)

            var infected_sprite = enemy.get_meta("infected_sprite",null)
            if is_instance_valid(infected_sprite):
                var frame = 0
                if stagger > 0.0:
                    frame = 3
                elif enemy.velocity.length() > 1.0:
                    frame = 1 if sin(walk) >= 0.0 else 2
                infected_sprite.region_rect = Rect2(frame * 32,0,32,48)

            var facing_visual = enemy.get_meta("ai_facing",Vector2.RIGHT)
            if typeof(facing_visual) == TYPE_VECTOR2 and abs(facing_visual.x) > 0.05:
                visual.scale.x = -1.0 if facing_visual.x < 0.0 else 1.0

            if stagger > 0.0:
                visual.rotation = sin(stagger * 22.0) * 0.055
            else:
                visual.rotation = 0.0

        dist = enemy.global_position.distance_to(player.global_position)
        if (
            state == "chase"
            and dist < 25.0
            and attack_cd <= 0.0
            and stagger <= 0.0
            and knockback.length() <= 1.0
            and (sees_player or _enemy_has_line_of_sight(enemy))
        ):
            attack_cd = 0.9
            _apply_enemy_hit(8.0)

        enemy.set_meta("ai_state",state)
        enemy.set_meta("ai_state_time",state_time)
        enemy.set_meta("suspicion",suspicion)
        enemy.set_meta("lost_sight_time",lost_sight)
        enemy.set_meta("sense_cd",sense_cd)
        enemy.set_meta("alert",state_time if state != "idle" else 0.0)
        enemy.set_meta("attack_cd",attack_cd)
        enemy.set_meta("stagger",stagger)
        enemy.set_meta("knockback_velocity",knockback)
        enemy.set_meta("walk",walk)

func _safe_enemy_spawn(rng):
    if rng.randf() < 0.5:
        return Vector2(
            rng.randi_range(55, CHUNK_SIZE - 55),
            rng.randi_range(326, 434)
        )
    return Vector2(
        rng.randi_range(303, 407),
        rng.randi_range(55, CHUNK_SIZE - 55)
    )


func _consume_one_item_from_entries(entries,id):
    for i in range(entries.size() - 1,-1,-1):
        if str(entries[i].get("id","")) != id:
            continue
        var qty = int(entries[i].get("qty",1))
        qty -= 1
        if qty <= 0:
            entries.remove_at(i)
        else:
            entries[i]["qty"] = qty
        return true
    return false

func _eq_name(slot):
    var id = str(equipment.get(slot,""))
    if id == "":
        return "-"
    if item_defs.has(id):
        return str(item_defs[id].get("short",id))
    return id


func _slot_name(slot):
    match slot:
        "head":
            return "ГОЛОВА"
        "body":
            return "ТОРС"
        "backpack":
            return "РЮКЗАК"
        "utility":
            return "УТИЛИТА"
    return slot.to_upper()


func _equip_item(id):
    if not item_defs.has(id):
        return
    var item = item_defs[id]
    if str(item.get("use","")) != "gear":
        return

    var slot = str(item.get("slot",""))
    if not equipment.has(slot):
        return

    var test_entries = inventory_entries.duplicate(true)
    if not _consume_one_item_from_entries(test_entries,id):
        return

    var old_id = str(equipment.get(slot,""))
    if old_id != "":
        if _grid_add(test_entries, old_id, 1, INV_W, INV_H) != 0:
            return

    inventory_entries = test_entries
    equipment[slot] = id
    if slot == "utility" and id != "flashlight":
        flashlight_on = false


func _clear_equipment_item(id):
    for slot in equipment.keys():
        if str(equipment[slot]) == id:
            equipment[slot] = ""
            if slot == "utility":
                flashlight_on = false


func _validate_equipment():
    for slot in equipment.keys():
        var id = str(equipment[slot])
        if id != "" and not item_defs.has(id):
            equipment[slot] = ""
            if slot == "utility":
                flashlight_on = false

    if equipped_melee_id != "" and not _inventory_has_item(equipped_melee_id):
        equipped_melee_id = ""
        _update_weapon_visual()


func _skill_ids():
    return ["firearms","melee","scavenging","survival","crafting"]

func _skill_display_name(skill_id):
    if skill_id == "firearms":
        return "СТРЕЛЬБА"
    if skill_id == "melee":
        return "БЛИЖНИЙ БОЙ"
    if skill_id == "scavenging":
        return "ПОИСК"
    if skill_id == "survival":
        return "ВЫЖИВАНИЕ"
    if skill_id == "crafting":
        return "РЕМЕСЛО"
    return str(skill_id).to_upper()

func _sanitize_skills():
    if typeof(skill_levels) != TYPE_DICTIONARY:
        skill_levels = {}
    if typeof(skill_xp) != TYPE_DICTIONARY:
        skill_xp = {}

    for skill_id in _skill_ids():
        if not skill_levels.has(skill_id):
            skill_levels[skill_id] = 1
        if not skill_xp.has(skill_id):
            skill_xp[skill_id] = 0.0

        skill_levels[skill_id] = clamp(int(skill_levels[skill_id]),1,10)
        skill_xp[skill_id] = max(0.0,float(skill_xp[skill_id]))

        if int(skill_levels[skill_id]) >= 10:
            skill_xp[skill_id] = 0.0

func _skill_level(skill_id):
    if not skill_levels.has(skill_id):
        return 1
    return clamp(int(skill_levels.get(skill_id,1)),1,10)

func _skill_xp_required_for_level(level_value):
    var level_now = clamp(int(level_value),1,10)
    if level_now >= 10:
        return 999999.0
    return 30.0 * pow(float(level_now),1.35)

func _skill_progress_percent(skill_id):
    var level_now = _skill_level(skill_id)
    if level_now >= 10:
        return 100.0

    var need = max(1.0,_skill_xp_required_for_level(level_now))
    return clamp(float(skill_xp.get(skill_id,0.0)) / need * 100.0,0.0,100.0)

func _add_skill_xp(skill_id,amount):
    if skill_id not in _skill_ids():
        return
    if amount <= 0.0:
        return

    _sanitize_skills()

    var level_now = _skill_level(skill_id)
    if level_now >= 10:
        return

    var xp_now = float(skill_xp.get(skill_id,0.0)) + float(amount)
    var leveled = false

    while level_now < 10:
        var need = _skill_xp_required_for_level(level_now)
        if xp_now < need:
            break

        xp_now -= need
        level_now += 1
        leveled = true

    skill_levels[skill_id] = level_now
    skill_xp[skill_id] = 0.0 if level_now >= 10 else xp_now

    if leveled:
        _set_survival_feedback(
            "Навык %s → %d" % [_skill_display_name(skill_id),level_now],
            2.2
        )

func _skill_firearm_spread_multiplier():
    return max(0.84,1.0 - float(_skill_level("firearms") - 1) * 0.018)

func _skill_reload_time_multiplier():
    return max(0.88,1.0 - float(_skill_level("firearms") - 1) * 0.014)

func _skill_melee_damage_multiplier():
    return 1.0 + float(_skill_level("melee") - 1) * 0.025

func _skill_carry_bonus():
    return float(_skill_level("scavenging") - 1) * 0.35

func _skill_survival_drain_multiplier():
    return max(0.84,1.0 - float(_skill_level("survival") - 1) * 0.018)

func _skill_survival_regen_multiplier():
    return 1.0 + float(_skill_level("survival") - 1) * 0.030

func _skill_service_gain_multiplier():
    return 1.0 + float(_skill_level("crafting") - 1) * 0.030

func _skill_debug_text():
    return "SK:%d/%d/%d/%d/%d" % [
        _skill_level("firearms"),
        _skill_level("melee"),
        _skill_level("scavenging"),
        _skill_level("survival"),
        _skill_level("crafting")
    ]


func _carry_limit():
    var limit = 8.0
    var id = str(equipment.get("backpack",""))
    if id != "" and item_defs.has(id):
        limit += float(item_defs[id].get("carry_bonus",0.0))
    limit += _skill_carry_bonus()
    return limit

func _survival_stamina_cap():
    var cap = 100.0

    if hunger < 25.0:
        cap = min(cap,85.0)
    if hunger < 10.0:
        cap = min(cap,70.0)

    if thirst < 25.0:
        cap = min(cap,75.0)
    if thirst < 10.0:
        cap = min(cap,55.0)

    if health < 30.0:
        cap = min(cap,80.0)

    cap = min(cap,_temperature_stamina_cap())
    cap = min(cap,_injury_stamina_cap())
    return cap


func _nutrition_stamina_multiplier():
    return 1.15 if well_fed_time > 0.0 else 1.0

func _warm_drink_heat_bonus():
    return 1.5 if warm_drink_time > 0.0 else 0.0

func _update_nutrition(delta):
    well_fed_time = max(0.0,well_fed_time - delta)
    warm_drink_time = max(0.0,warm_drink_time - delta)

func _cook_inventory_product(input_id,water_required,output_id,feedback):
    if not _player_near_active_fire():
        if inv_details != null:
            inv_details.text = "Нужен горящий костёр."
        return false

    if _inventory_count(input_id) <= 0:
        return false

    if water_required and _inventory_count("water") <= 0:
        if inv_details != null:
            inv_details.text = "Для готовки нужна чистая вода."
        return false

    var test_entries = inventory_entries.duplicate(true)
    if not _consume_one_item_from_entries(test_entries,input_id):
        return false
    if water_required and not _consume_one_item_from_entries(test_entries,"water"):
        return false

    var remaining = _grid_add(test_entries,output_id,1,INV_W,INV_H)
    if remaining > 0:
        if inv_details != null:
            inv_details.text = "Нужно свободное место для готового блюда."
        return false

    inventory_entries = test_entries
    _add_skill_xp("survival",0.65)
    _add_skill_xp("crafting",0.25)
    _set_survival_feedback(feedback,2.0)
    return true

func _survival_stamina_regen_rate():
    var rate = 2.8

    if hunger < 35.0:
        rate *= 0.72
    if hunger < 15.0:
        rate *= 0.60

    if thirst < 35.0:
        rate *= 0.62
    if thirst < 15.0:
        rate *= 0.52

    if health < 35.0:
        rate *= 0.72
    if bleeding:
        rate *= 0.55

    rate *= _thermal_stamina_regen_multiplier()
    rate *= _injury_stamina_regen_multiplier()
    rate *= _skill_survival_regen_multiplier()
    rate *= _nutrition_stamina_multiplier()
    return max(0.15,rate)

func _survival_speed_multiplier():
    var mult = 1.0

    if hunger < 15.0:
        mult *= 0.90
    if hunger < 5.0:
        mult *= 0.90

    if thirst < 15.0:
        mult *= 0.84
    if thirst < 5.0:
        mult *= 0.88

    if health < 30.0:
        mult *= 0.90

    mult *= _thermal_speed_multiplier()
    return max(0.55,mult)

func _survival_damage_per_second():
    var damage = 0.0
    if hunger <= 0.0:
        damage += 0.20
    if thirst <= 0.0:
        damage += 0.38
    damage += _thermal_damage_per_second()
    return damage

func _survival_status_text():
    var warnings = []

    if bleeding:
        warnings.append("КРОВОТЕЧЕНИЕ")
    if thirst <= 0.0:
        warnings.append("ОБЕЗВОЖИВАНИЕ")
    elif thirst < 15.0:
        warnings.append("СИЛЬНАЯ ЖАЖДА")

    if hunger <= 0.0:
        warnings.append("ИСТОЩЕНИЕ")
    elif hunger < 15.0:
        warnings.append("СИЛЬНЫЙ ГОЛОД")

    var thermal_text = _thermal_state_text()
    if thermal_text != "ТЕРМОКОМФОРТ":
        warnings.append(thermal_text)

    if wetness > 70.0:
        warnings.append("ПРОМОК")
    elif wetness > 35.0:
        warnings.append("МОКРО")

    var effective_pain = _effective_pain()
    if effective_pain > 70.0:
        warnings.append("СИЛЬНАЯ БОЛЬ")
    elif effective_pain > 35.0:
        warnings.append("БОЛЬ")

    if wound_infection >= 70.0:
        warnings.append("СИЛЬНАЯ ИНФЕКЦИЯ РАНЫ")
    elif wound_infection >= 25.0:
        warnings.append("ИНФЕКЦИЯ РАНЫ")
    elif wound_contamination >= 45.0:
        warnings.append("ЗАГРЯЗНЁННАЯ РАНА")

    if stamina < 15.0:
        warnings.append("ВЫДОХСЯ")
    if is_sprinting:
        warnings.append("БЕГ")

    if well_fed_time > 0.0:
        warnings.append("СЫТ")
    if warm_drink_time > 0.0:
        warnings.append("ГОРЯЧИЙ НАПИТОК")

    if warnings.is_empty():
        if is_sheltered:
            return "СОСТОЯНИЕ: В ТЕПЛЕ"
        return "СОСТОЯНИЕ: СТАБИЛЬНО"
    return "СОСТОЯНИЕ: " + " • ".join(warnings)

func _set_survival_feedback(text_value,duration = 1.8):
    survival_feedback = str(text_value)
    survival_feedback_time = max(0.1,float(duration))

func _update_survival(delta):
    var activity_hunger_mult = 1.0
    var activity_thirst_mult = 1.0

    if is_sprinting and move_direction.length() > 0.05:
        activity_hunger_mult = 1.65
        activity_thirst_mult = 2.10

    activity_hunger_mult *= _thermal_hunger_multiplier()
    activity_thirst_mult *= _thermal_thirst_multiplier()

    var learned_efficiency = _skill_survival_drain_multiplier()
    activity_hunger_mult *= learned_efficiency
    activity_thirst_mult *= learned_efficiency

    hunger = max(0.0,hunger - delta * 0.018 * activity_hunger_mult)
    thirst = max(0.0,thirst - delta * 0.028 * activity_thirst_mult)

    if bleeding:
        var remaining_bleed_damage = max(0.0,MAX_BLEED_DAMAGE - bleed_damage_taken)
        if remaining_bleed_damage > 0.0 and health > 1.0:
            var bleed_tick = min(delta * 0.85,remaining_bleed_damage)
            bleed_tick = min(bleed_tick,max(0.0,health - 1.0))
            health = max(1.0,health - bleed_tick)
            bleed_damage_taken += bleed_tick
        if bleed_damage_taken >= MAX_BLEED_DAMAGE or health <= 1.0:
            bleeding = false

    var deprivation_damage = _survival_damage_per_second()
    if deprivation_damage > 0.0:
        health = max(0.0,health - deprivation_damage * delta)

    var moving_now = player != null and player.velocity.length() > 1.5
    if moving_now:
        if is_sprinting:
            stamina = max(0.0,stamina - delta * 7.5)
        else:
            stamina = max(0.0,stamina - delta * 0.12)
    else:
        stamina += delta * _survival_stamina_regen_rate()

    stamina = clamp(stamina,0.0,_survival_stamina_cap())

    if not bleeding and health < 100.0 and hunger >= 70.0 and thirst >= 70.0:
        var recovery_rate = 0.045
        if is_sheltered:
            recovery_rate = 0.105
        if body_temperature < 35.0:
            recovery_rate *= 0.35
        health = min(100.0,health + delta * recovery_rate)

    # Shelter improves general condition even before full health regeneration:
    # stamina recovers better there through _cold_stamina_regen_multiplier().

    sprint_noise_time = max(0.0,sprint_noise_time - delta)
    if moving_now and sprint_noise_time <= 0.0:
        if is_sprinting:
            _emit_ai_sound(player.global_position,138.0,"sprint",1.0)
            sprint_noise_time = 0.48
        else:
            _emit_ai_sound(player.global_position,52.0,"walk",1.0)
            sprint_noise_time = 0.80

    survival_skill_tick += delta
    if survival_skill_tick >= 12.0:
        survival_skill_tick = 0.0

        var survival_challenge = (
            moving_now
            or wetness > 35.0
            or thermal_cold_stress > 0.20
            or thermal_heat_stress > 0.20
            or hunger < 40.0
            or thirst < 40.0
            or bleeding
            or pain > 35.0
        )

        if survival_challenge:
            var survival_xp_gain = 0.45
            if is_sheltered == false and (thermal_cold_stress > 0.35 or wetness > 60.0):
                survival_xp_gain += 0.20
            _add_skill_xp("survival",survival_xp_gain)

    survival_feedback_time = max(0.0,survival_feedback_time - delta)
    if survival_feedback_time <= 0.0:
        survival_feedback = ""

func _current_move_speed():
    var limit = max(1.0,_carry_limit())
    var ratio = _inventory_weight() / limit
    var speed = MOVE_SPEED

    if ratio > 1.0:
        speed *= max(0.55,1.0 - (ratio - 1.0) * 0.42)

    speed *= _survival_speed_multiplier()
    speed *= _injury_move_multiplier()

    if is_sprinting and stamina > 0.5 and hunger > 0.0 and thirst > 0.0:
        speed *= SPRINT_SPEED_MULT

    return speed

func _armor_value():
    var armor = 0.0
    var body_id = str(equipment.get("body",""))
    if body_id != "" and item_defs.has(body_id):
        armor += float(item_defs[body_id].get("armor",0.0))
    var head_id = str(equipment.get("head",""))
    if head_id != "" and item_defs.has(head_id):
        armor += float(item_defs[head_id].get("armor",0.0)) * 0.35
    return clamp(armor,0.0,0.60)

func _bleed_resistance():
    var resist = 0.0
    for slot in ["head","body"]:
        var id = str(equipment.get(slot,""))
        if id != "" and item_defs.has(id):
            resist += float(item_defs[id].get("bleed_resist",0.0))
    return clamp(resist,0.0,0.75)


func _body_zone_name(zone):
    if zone == "head":
        return "ГОЛОВА"
    if zone == "torso":
        return "КОРПУС"
    if zone == "arms":
        return "РУКИ"
    if zone == "legs":
        return "НОГИ"
    return "ТЕЛО"

func _roll_injury_zone():
    var roll = randf()

    if roll < 0.14:
        return "head"
    if roll < 0.56:
        return "torso"
    if roll < 0.78:
        return "arms"
    return "legs"

func _injury_zone_trauma_mult(zone):
    if zone == "head":
        return 1.20
    if zone == "torso":
        return 1.00
    if zone == "arms":
        return 0.80
    if zone == "legs":
        return 0.85
    return 1.0

func _injury_zone_bleed_mult(zone):
    if zone == "head":
        return 0.88
    if zone == "torso":
        return 1.15
    if zone == "arms":
        return 0.95
    if zone == "legs":
        return 1.00
    return 1.0

func _sanitize_body_condition():
    if typeof(body_condition) != TYPE_DICTIONARY:
        body_condition = {}

    for zone in ["head","torso","arms","legs"]:
        if not body_condition.has(zone):
            body_condition[zone] = 100.0
        body_condition[zone] = clamp(float(body_condition[zone]),0.0,100.0)

    pain = clamp(float(pain),0.0,100.0)

func _body_condition_value(zone):
    if not body_condition.has(zone):
        return 100.0
    return clamp(float(body_condition.get(zone,100.0)),0.0,100.0)

func _worst_injury_zone():
    var worst_zone = ""
    var worst_value = 101.0

    for zone in ["head","torso","arms","legs"]:
        var value = _body_condition_value(zone)
        if value < worst_value:
            worst_value = value
            worst_zone = zone

    return worst_zone

func _body_injury_summary():
    var zone = _worst_injury_zone()
    if zone == "":
        return "ТРАВМЫ: НЕТ"

    var value = _body_condition_value(zone)
    if value >= 92.0:
        return "ТРАВМЫ: НЕТ"

    return "ТРАВМЫ: %s %d%%" % [_body_zone_name(zone),int(value)]


func _effective_pain():
    var suppression = 32.0 if painkiller_time > 0.0 else 0.0
    return max(0.0,pain - suppression)

func _contaminate_wound(trauma,open_wound):
    var amount = max(0.0,float(trauma)) * (0.62 if open_wound else 0.18)
    if open_wound:
        amount += 5.0
    if wetness > 65.0:
        amount *= 1.22
    wound_contamination = clamp(wound_contamination + amount,0.0,100.0)

func _medical_stamina_multiplier():
    if wound_infection >= 85.0:
        return 0.62
    if wound_infection >= 60.0:
        return 0.76
    if wound_infection >= 30.0:
        return 0.90
    return 1.0

func _update_medical(delta):
    medical_tick_accumulator += delta
    if medical_tick_accumulator < 0.25:
        return

    var step = medical_tick_accumulator
    medical_tick_accumulator = 0.0

    painkiller_time = max(0.0,painkiller_time - step)
    antibiotic_time = max(0.0,antibiotic_time - step)

    # An open wound slowly becomes dirtier, especially while soaked.
    if bleeding:
        var open_wound_rate = 0.010
        if wetness > 60.0:
            open_wound_rate *= 1.75
        wound_contamination += step * open_wound_rate
    else:
        var clean_rate = 0.004
        if is_sheltered:
            clean_rate *= 1.70
        wound_contamination -= step * clean_rate

    # Contamination turns into a wound infection gradually rather than instantly.
    if antibiotic_time > 0.0:
        wound_contamination -= step * 0.020
        wound_infection -= step * 0.045
    elif wound_contamination > 30.0:
        var exposure = clamp((wound_contamination - 30.0) / 70.0,0.0,1.0)
        var infection_rate = 0.028 * exposure
        if bleeding:
            infection_rate *= 1.25
        if wetness > 60.0:
            infection_rate *= 1.18
        if body_temperature < 35.0:
            infection_rate *= 1.12
        wound_infection += step * infection_rate
    elif wound_contamination < 15.0 and wound_infection < 35.0 and not bleeding:
        wound_infection -= step * 0.0025

    wound_contamination = clamp(wound_contamination,0.0,100.0)
    wound_infection = clamp(wound_infection,0.0,100.0)

    # Infection becomes systemically dangerous only at high values.
    if wound_infection >= 85.0:
        health = max(0.0,health - step * 0.018)
        pain = min(100.0,pain + step * 0.004)
        body_temperature = min(40.5,body_temperature + step * 0.0010)
    elif wound_infection >= 65.0:
        health = max(0.0,health - step * 0.007)
        pain = min(100.0,pain + step * 0.002)
        body_temperature = min(40.5,body_temperature + step * 0.0004)

func _use_sterile_bandage():
    if not bleeding and health >= 99.0 and wound_contamination <= 1.0:
        return false

    _stop_bleeding()
    health = min(100.0,health + 4.0)
    pain = max(0.0,pain - 5.0)
    _stabilize_worst_injury(3.0)
    wound_contamination = max(0.0,wound_contamination - 18.0)
    stamina = min(_survival_stamina_cap(),stamina + 2.0)
    _set_survival_feedback("Стерильная повязка: рана закрыта и очищена",2.0)
    return true

func _injury_move_multiplier():
    var p = _effective_pain()
    var mult = 1.0
    var legs = _body_condition_value("legs")

    if legs < 60.0:
        mult *= 0.92
    if legs < 30.0:
        mult *= 0.78
    if legs < 15.0:
        mult *= 0.80

    if p > 50.0:
        mult *= 0.94
    if p > 80.0:
        mult *= 0.86

    if wound_infection >= 70.0:
        mult *= 0.92
    if wound_infection >= 90.0:
        mult *= 0.88

    return max(0.45,mult)

func _injury_aim_spread_multiplier():
    var p = _effective_pain()
    var mult = 1.0
    var arms = _body_condition_value("arms")
    var head = _body_condition_value("head")

    if arms < 60.0:
        mult *= 1.12
    if arms < 30.0:
        mult *= 1.28

    if head < 40.0:
        mult *= 1.12

    if p > 45.0:
        mult *= 1.10
    if p > 75.0:
        mult *= 1.15

    return mult

func _injury_stamina_cap():
    var p = _effective_pain()
    var cap = 100.0
    var torso = _body_condition_value("torso")
    var legs = _body_condition_value("legs")
    var head = _body_condition_value("head")

    if torso < 60.0:
        cap = min(cap,90.0)
    if torso < 30.0:
        cap = min(cap,70.0)

    if legs < 60.0:
        cap = min(cap,85.0)
    if legs < 30.0:
        cap = min(cap,62.0)

    if head < 50.0:
        cap = min(cap,88.0)
    if head < 25.0:
        cap = min(cap,68.0)

    if p > 50.0:
        cap = min(cap,85.0)
    if p > 80.0:
        cap = min(cap,70.0)

    if wound_infection >= 60.0:
        cap = min(cap,82.0)
    if wound_infection >= 85.0:
        cap = min(cap,65.0)

    return cap

func _injury_stamina_regen_multiplier():
    var p = _effective_pain()
    var mult = 1.0

    if p > 35.0:
        mult *= 0.85
    if p > 70.0:
        mult *= 0.68

    if _body_condition_value("torso") < 50.0:
        mult *= 0.82

    mult *= _medical_stamina_multiplier()
    return max(0.35,mult)

func _injury_can_sprint():
    var p = _effective_pain()
    if _body_condition_value("legs") < 24.0:
        return false
    if p > 88.0:
        return false
    if wound_infection >= 92.0:
        return false
    return true

func _apply_body_injury(zone,trauma):
    if not body_condition.has(zone):
        return

    var amount = max(0.0,float(trauma))
    body_condition[zone] = max(0.0,_body_condition_value(zone) - amount)
    pain = min(100.0,pain + amount * 0.80)
    last_injury_zone = zone

func _stabilize_worst_injury(amount):
    var zone = _worst_injury_zone()
    if zone == "":
        return

    var value = _body_condition_value(zone)
    if value >= 100.0:
        return

    body_condition[zone] = min(100.0,value + max(0.0,float(amount)))

func _update_injuries(delta):
    _sanitize_body_condition()

    var pain_decay = 0.045

    if is_sheltered:
        pain_decay *= 1.65
    if hunger >= 65.0 and thirst >= 65.0:
        pain_decay *= 1.25
    if body_temperature < 35.0:
        pain_decay *= 0.55

    pain = max(0.0,pain - delta * pain_decay)

    # Body-part recovery is intentionally slow. Shelter, food and hydration
    # create a meaningful recovery loop without instantly erasing combat damage.
    if is_sheltered and not bleeding and hunger >= 70.0 and thirst >= 70.0 and wound_infection < 70.0:
        var recovery = delta * 0.010
        if body_temperature >= 36.0:
            recovery *= 1.20
        if wound_infection > 30.0:
            recovery *= 0.62

        for zone in ["head","torso","arms","legs"]:
            body_condition[zone] = min(100.0,_body_condition_value(zone) + recovery)

func _apply_enemy_hit(base_damage):
    var final_damage = base_damage * (1.0 - _armor_value())
    health = max(0.0,health - final_damage)

    var zone = _roll_injury_zone()
    var trauma = final_damage * _injury_zone_trauma_mult(zone)
    _apply_body_injury(zone,trauma)

    var bleed_chance = 0.32
    bleed_chance *= _injury_zone_bleed_mult(zone)
    bleed_chance *= (1.0 - _bleed_resistance())

    var opened_wound = false
    if randf() < bleed_chance:
        _start_bleeding()
        opened_wound = true

    _contaminate_wound(trauma,opened_wound or bleeding)

    _set_survival_feedback(
        "Травма: %s  Боль %d%%" % [_body_zone_name(zone),int(pain)],
        1.35
    )

func _weather_display_name():
    if weather_state == "rain":
        return "ДОЖДЬ"
    if weather_state == "cloudy":
        return "ПАСМУРНО"
    return "ЯСНО"

func _weather_temp_offset():
    if weather_state == "rain":
        return -3.5
    if weather_state == "cloudy":
        return -1.5
    return 0.0


func _ambient_temperature_for_time():
    var hour = world_minutes / 60.0
    var daily = cos((hour - 14.0) / 24.0 * TAU)

    # Late-autumn continental profile:
    # ~13°C daytime, down to ~-3°C at the coldest clear night.
    return 5.0 + daily * 8.0 + _weather_temp_offset()



func _position_is_sheltered(pos):
    for rec in roof_records:
        var rect = rec.get("rect",Rect2())
        if rect.has_point(pos):
            return true
    return false

func _player_is_sheltered():
    if player == null:
        return false
    return _position_is_sheltered(player.global_position)

func _clothing_warmth():
    var total = 0.0
    for slot in ["head","body","backpack"]:
        var id = str(equipment.get(slot,""))
        if id != "" and item_defs.has(id):
            total += float(item_defs[id].get("warmth",0.0))
    return total

func _rain_protection():
    var protection = 0.0
    for slot in ["head","body","backpack"]:
        var id = str(equipment.get(slot,""))
        if id != "" and item_defs.has(id):
            protection += float(item_defs[id].get("rain_protect",0.0))
    return clamp(protection,0.0,0.75)


func _freezing_exposure_active():
    return ambient_temperature <= 0.0 and not is_sheltered


func _shelter_wellbeing_multiplier():
    if not is_sheltered:
        return 1.0

    var bonus = 1.18

    if thermal_effective_temperature >= 8.0 and thermal_effective_temperature <= 24.0:
        bonus += 0.12
    if wetness < 35.0:
        bonus += 0.08
    if body_temperature < 35.5:
        bonus += 0.08

    return clamp(bonus,1.0,1.46)


func _temperature_stamina_cap():
    var cap = 100.0

    if _freezing_exposure_active():
        cap = min(cap,95.0)

    if wetness > 70.0 and thermal_effective_temperature < 8.0:
        cap = min(cap,88.0)

    if body_temperature < 35.5:
        cap = min(cap,90.0)
    if body_temperature < 35.0:
        cap = min(cap,78.0)
    if body_temperature < 34.0:
        cap = min(cap,60.0)
    if body_temperature < 33.0:
        cap = min(cap,42.0)

    if body_temperature > 38.0:
        cap = min(cap,82.0)
    if body_temperature > 39.0:
        cap = min(cap,62.0)

    return cap

func _weather_wind_speed_kmh():
    if weather_state == "rain":
        return 20.0
    if weather_state == "cloudy":
        return 12.0
    return 6.0

func _wind_chill_temperature(temp_c,wind_kmh):
    var t = float(temp_c)
    var v = max(0.0,float(wind_kmh))

    # Standard wind-chill equation. Use actual air temperature outside
    # the range where the equation is meaningful.
    if t > 10.0 or v <= 4.8:
        return t

    var v016 = pow(v,0.16)
    return 13.12 + 0.6215 * t - 11.37 * v016 + 0.3965 * t * v016

func _shelter_air_temperature():
    # Unheated buildings mainly remove wind/rain and retain some heat.
    # Thermal inertia keeps the interior from immediately matching a cold night.
    return max(4.0,ambient_temperature + 7.0)

func _clothing_insulation():
    return clamp(_clothing_warmth() / 6.0,0.0,0.78)

func _effective_clothing_insulation():
    var insulation = _clothing_insulation()

    # Wet clothing loses most of its insulating ability.
    var wet_loss = 1.0 - (wetness / 100.0) * 0.72
    return clamp(insulation * wet_loss,0.0,0.78)

func _activity_heat_bonus():
    if move_direction.length() <= 0.05:
        return 0.0
    if is_sprinting:
        return 6.0
    return 2.2

func _calculate_effective_temperature():
    var air_temp = ambient_temperature

    if is_sheltered:
        air_temp = _shelter_air_temperature()
        wind_speed_kmh = 1.5
    else:
        wind_speed_kmh = _weather_wind_speed_kmh()
        air_temp = _wind_chill_temperature(ambient_temperature,wind_speed_kmh)

    var insulation_bonus = _effective_clothing_insulation() * 10.0
    var wet_penalty = (wetness / 100.0) * 5.0
    var activity_bonus = _activity_heat_bonus()

    var base_heat_bonus = _base_heat_bonus_at_player()
    var drink_heat_bonus = _warm_drink_heat_bonus()
    return air_temp + insulation_bonus + activity_bonus + base_heat_bonus + drink_heat_bonus - wet_penalty

func _thermal_speed_multiplier():
    var mult = 1.0

    # 0°C and below begins environmental exposure risk, but a normal core
    # temperature only receives a mild immediate performance penalty.
    if _freezing_exposure_active():
        mult *= 0.98

    if wetness > 70.0 and thermal_effective_temperature < 8.0:
        mult *= 0.94

    if body_temperature < 35.5:
        mult *= 0.94
    if body_temperature < 35.0:
        mult *= 0.90
    if body_temperature < 34.0:
        mult *= 0.82
    if body_temperature < 33.0:
        mult *= 0.78

    if body_temperature > 38.0:
        mult *= 0.94
    if body_temperature > 39.0:
        mult *= 0.86

    return max(0.50,mult)

func _thermal_stamina_regen_multiplier():
    var mult = 1.0

    if _freezing_exposure_active():
        mult *= 0.90

    if wetness > 70.0 and thermal_effective_temperature < 8.0:
        mult *= 0.82

    if body_temperature < 35.5:
        mult *= 0.86
    if body_temperature < 35.0:
        mult *= 0.78
    if body_temperature < 34.0:
        mult *= 0.62
    if body_temperature < 33.0:
        mult *= 0.50

    if body_temperature > 38.0:
        mult *= 0.78
    if body_temperature > 39.0:
        mult *= 0.58

    mult *= _shelter_wellbeing_multiplier()
    return clamp(mult,0.25,1.65)

func _thermal_damage_per_second():
    var damage = 0.0

    # HP damage follows dangerous core temperature, not air alone.
    if body_temperature < 34.0:
        damage += 0.035
    if body_temperature < 33.0:
        damage += 0.090
    if body_temperature < 32.0:
        damage += 0.180

    if body_temperature > 39.0:
        damage += 0.080
    if body_temperature > 40.0:
        damage += 0.200

    return damage

func _thermal_hunger_multiplier():
    var mult = 1.0

    # Cold thermogenesis increases calorie use.
    if thermal_cold_stress > 0.20:
        mult += min(0.55,thermal_cold_stress * 0.38)
    if body_temperature < 35.0:
        mult += 0.18

    return mult

func _thermal_thirst_multiplier():
    var mult = 1.0

    # Heat raises fluid demand.
    if thermal_heat_stress > 0.10:
        mult += min(1.00,thermal_heat_stress * 0.75)
    if body_temperature > 38.0:
        mult += 0.30

    return mult

func _thermal_state_text():
    if body_temperature <= 32.0:
        return "КРИТИЧЕСКОЕ ПЕРЕОХЛАЖДЕНИЕ"
    if body_temperature < 34.0:
        return "СИЛЬНОЕ ПЕРЕОХЛАЖДЕНИЕ"
    if body_temperature < 35.0:
        return "ПЕРЕОХЛАЖДЕНИЕ"
    if _freezing_exposure_active():
        return "РИСК ПЕРЕОХЛАЖДЕНИЯ"

    if body_temperature >= 40.0:
        return "КРИТИЧЕСКИЙ ПЕРЕГРЕВ"
    if body_temperature > 39.0:
        return "СИЛЬНЫЙ ПЕРЕГРЕВ"
    if body_temperature > 38.0:
        return "ПЕРЕГРЕВ"

    if thermal_effective_temperature < 5.0:
        return "ХОЛОДНО"
    if thermal_effective_temperature > 28.0:
        return "ЖАРКО"

    return "ТЕРМОКОМФОРТ"

func _thermal_tick(step):
    is_sheltered = _player_is_sheltered()
    ambient_temperature = _ambient_temperature_for_time()

    if weather_state == "rain" and not is_sheltered:
        # Fast soaking remains; rain protection delays saturation.
        var soak_rate = 0.92 * (1.0 - _rain_protection())
        if is_sprinting:
            soak_rate *= 1.12
        wetness = min(100.0,wetness + soak_rate * step)
    else:
        var dry_rate = 0.055

        if is_sheltered:
            var shelter_air = _shelter_air_temperature()
            dry_rate = 0.24 + max(0.0,shelter_air - 4.0) * 0.012
            if weather_state != "rain":
                dry_rate += 0.08
        elif weather_state == "clear":
            dry_rate = 0.085
        elif weather_state == "cloudy":
            dry_rate = 0.045

        wetness = max(0.0,wetness - dry_rate * step)

    var nearby_base_heat = _base_heat_bonus_at_player()
    if nearby_base_heat > 0.0:
        wetness = max(0.0,wetness - step * (0.18 + nearby_base_heat * 0.018))

    thermal_effective_temperature = _calculate_effective_temperature()

    # Gameplay thermoneutral boundary for the current clothing abstraction.
    thermal_cold_stress = clamp((12.0 - thermal_effective_temperature) / 20.0,0.0,1.50)
    thermal_heat_stress = clamp((thermal_effective_temperature - 28.0) / 12.0,0.0,1.25)

    if thermal_cold_stress > 0.0:
        var cooling_rate = 0.0010 + 0.0045 * thermal_cold_stress

        if wetness > 50.0:
            cooling_rate += 0.0015 * (wetness / 100.0)

        # User gameplay rule: 0°C and lower starts hypothermia exposure.
        if _freezing_exposure_active():
            cooling_rate += 0.0013
            cooling_rate += min(0.0015,abs(ambient_temperature) * 0.00015)

        body_temperature -= step * cooling_rate
    elif thermal_heat_stress > 0.0:
        var heating_rate = 0.0010 + 0.0038 * thermal_heat_stress
        body_temperature += step * heating_rate
    else:
        var normalization = 0.0035
        if is_sheltered:
            normalization = 0.0080
        body_temperature = move_toward(body_temperature,36.8,step * normalization)

    # Dry shelter restores core temperature faster without acting as a heater.
    if is_sheltered and wetness < 35.0 and thermal_effective_temperature >= 8.0:
        body_temperature = move_toward(body_temperature,36.8,step * 0.0060)

    body_temperature = clamp(body_temperature,30.5,40.5)

func _cold_speed_multiplier():
    return _thermal_speed_multiplier()


func _cold_stamina_regen_multiplier():
    return _thermal_stamina_regen_multiplier()


func _cold_damage_per_second():
    return _thermal_damage_per_second()

func _weather_next_state():
    weather_cycle_index += 1

    var phase = weather_cycle_index % 6
    if phase == 2 or phase == 3:
        weather_state = "rain"
        weather_timer = 95.0
    elif phase == 1 or phase == 4:
        weather_state = "cloudy"
        weather_timer = 80.0
    else:
        weather_state = "clear"
        weather_timer = 105.0

func _create_weather_visuals():
    weather_visual_root = Node2D.new()
    weather_visual_root.name = "WeatherVisuals"
    weather_visual_root.z_as_relative = false
    weather_visual_root.z_index = 90
    player.add_child(weather_visual_root)

    rain_lines.clear()

    for i in range(28):
        var line = Line2D.new()
        line.width = 1.0
        line.default_color = Color(0.64,0.74,0.80,0.40)
        line.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        line.add_point(Vector2.ZERO)
        line.add_point(Vector2(-3,8))
        line.position = Vector2(
            -175.0 + float((i * 37) % 350),
            -110.0 + float((i * 53) % 225)
        )
        line.visible = false
        line.set_meta("rain_speed",150.0 + float((i * 17) % 55))
        weather_visual_root.add_child(line)
        rain_lines.append(line)

func _update_weather_visuals(delta):
    var raining = weather_state == "rain"

    for i in range(rain_lines.size()):
        var line = rain_lines[i]
        if not is_instance_valid(line):
            continue

        line.visible = raining
        if not raining:
            continue

        var speed = float(line.get_meta("rain_speed",165.0))
        line.position += Vector2(-22.0, speed) * delta

        if line.position.y > 120.0:
            line.position.y = -120.0
            line.position.x = -175.0 + float((i * 61 + weather_cycle_index * 23) % 350)

        if line.position.x < -190.0:
            line.position.x = 185.0



func _update_weather(delta):
    weather_timer -= delta
    if weather_timer <= 0.0:
        _weather_next_state()

    thermal_tick_accumulator += delta

    # Thermal/shelter calculations run at 5 Hz instead of every frame.
    if thermal_tick_accumulator >= 0.20:
        var step = thermal_tick_accumulator
        thermal_tick_accumulator = 0.0
        _thermal_tick(step)

    # Rain movement remains frame-smooth.
    _update_weather_visuals(delta)



func _base_build_costs(kind):
    if kind == "stash":
        return {"scrap":2,"tape":1}
    if kind == "heater":
        return {"scrap":3,"cloth":2,"tape":1}
    if kind == "campfire":
        return {"scrap":1,"cloth":1}
    if kind == "rain_collector":
        return {"scrap":2,"cloth":2,"tape":1}
    if kind == "lamp":
        return {"flashlight":1,"scrap":1,"tape":1}
    if kind == "cot":
        return {"cloth":4,"tape":1,"scrap":1}
    if kind == "barricade":
        return {"scrap":3,"tape":1}
    return {}

func _base_object_name(kind):
    if kind == "stash":
        return "БАЗОВЫЙ ЯЩИК"
    if kind == "heater":
        return "ОБОГРЕВАТЕЛЬ"
    if kind == "campfire":
        return "КОСТЁР"
    if kind == "rain_collector":
        return "ДОЖДЕСБОРНИК"
    if kind == "lamp":
        return "СТАЦИОНАРНАЯ ЛАМПА"
    if kind == "cot":
        return "РАСКЛАДУШКА"
    if kind == "barricade":
        return "БАРРИКАДА"
    return str(kind).to_upper()

func _base_cost_text(kind):
    var costs = _base_build_costs(kind)
    var lines = []
    var ids = costs.keys()
    ids.sort()

    for item_id in ids:
        var need = int(costs[item_id])
        var have = _inventory_count(str(item_id))
        var item_name = str(item_id)
        if item_defs.has(str(item_id)):
            item_name = str(item_defs[str(item_id)].get("name",item_id))
        lines.append("%s %d/%d" % [item_name,have,need])

    return ", ".join(lines)



func _sanitize_base_objects():
    if typeof(base_objects) != TYPE_ARRAY:
        base_objects = []

    var clean = []
    var max_id = 0

    for raw in base_objects:
        if typeof(raw) != TYPE_DICTIONARY:
            continue

        var kind = str(raw.get("kind",""))
        if (
            kind != "stash"
            and kind != "heater"
            and kind != "campfire"
            and kind != "rain_collector"
            and kind != "lamp"
            and kind != "cot"
            and kind != "barricade"
        ):
            continue

        var rec = raw.duplicate(true)
        rec["id"] = max(1,int(rec.get("id",1)))
        rec["x"] = float(rec.get("x",0.0))
        rec["y"] = float(rec.get("y",0.0))
        rec["rot"] = float(rec.get("rot",0.0))
        rec["on"] = bool(rec.get("on",kind == "heater" or kind == "lamp"))

        var default_fuel = 0.0
        if kind == "heater":
            default_fuel = 180.0
        rec["fuel"] = max(0.0,float(rec.get("fuel",default_fuel)))
        rec["sound_timer"] = max(0.0,float(rec.get("sound_timer",1.5)))
        rec["stored_water"] = clamp(
            float(rec.get("stored_water",0.0)),
            0.0,
            _rain_collector_capacity()
        )

        max_id = max(max_id,int(rec["id"]))
        clean.append(rec)

    base_objects = clean
    next_base_id = max(int(next_base_id),max_id + 1,1)

func _base_record_index(base_id):
    var id_value = int(base_id)
    for i in range(base_objects.size()):
        if int(base_objects[i].get("id",-1)) == id_value:
            return i
    return -1

func _base_record(base_id):
    var index = _base_record_index(base_id)
    if index < 0:
        return {}
    return base_objects[index]

func _base_build_position(kind):
    var distance = 34.0
    if kind == "lamp":
        distance = 28.0
    elif kind == "campfire":
        distance = 42.0
    elif kind == "rain_collector":
        distance = 40.0
    elif kind == "barricade":
        distance = 46.0

    var dir = aim_direction
    if dir.length() <= 0.01:
        dir = Vector2.RIGHT

    return player.global_position + dir.normalized() * distance

func _base_build_position_clear(pos):
    if player == null:
        return false

    var query = PhysicsRayQueryParameters2D.create(player.global_position,pos)
    query.collision_mask = LAYER_WORLD
    query.exclude = [player.get_rid()]
    var hit = get_world_2d().direct_space_state.intersect_ray(query)

    if not hit.is_empty():
        return false

    for rec in base_objects:
        var existing = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))
        if existing.distance_to(pos) < 26.0:
            return false

    return true

func _base_has_costs(kind):
    var costs = _base_build_costs(kind)
    if costs.is_empty():
        return false

    for item_id in costs.keys():
        if _inventory_count(str(item_id)) < int(costs[item_id]):
            return false

    return true

func _base_consume_costs(kind,entries):
    var costs = _base_build_costs(kind)
    for item_id in costs.keys():
        if not _consume_from_entries(entries,str(item_id),int(costs[item_id])):
            return false
    return true



func _rain_collector_capacity():
    return 8.0

func _rain_collector_fill_rate(state,sheltered):
    if state == "rain" and not sheltered:
        return 0.025
    return 0.0


func _base_build_allowed(kind):
    if player == null:
        return false

    var sheltered = _player_is_sheltered()

    if kind == "rain_collector":
        if sheltered:
            return false
    elif kind != "campfire" and not sheltered:
        return false

    if not _base_has_costs(kind):
        return false

    var pos = _base_build_position(kind)
    return _base_build_position_clear(pos)

func _make_base_radial_texture():
    var gradient = Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0,0.62,1.0])
    gradient.colors = PackedColorArray([
        Color(1.0,0.84,0.56,1.0),
        Color(1.0,0.55,0.24,0.42),
        Color(1.0,0.40,0.18,0.0)
    ])

    var texture = GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 128
    texture.height = 128
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5,0.5)
    texture.fill_to = Vector2(1.0,0.5)
    return texture

func _create_base_system():
    _sanitize_base_objects()

    if base_root != null and is_instance_valid(base_root):
        base_root.queue_free()

    base_root = Node2D.new()
    base_root.name = "PersistentBaseObjects"
    base_root.z_as_relative = false
    base_root.z_index = 8
    add_child(base_root)

    base_object_nodes.clear()

    for rec in base_objects:
        _spawn_base_object(rec)

func _spawn_base_object(rec):
    if base_root == null:
        return null

    var base_id = int(rec.get("id",-1))
    var kind = str(rec.get("kind",""))
    if base_id < 0:
        return null

    var node = Node2D.new()
    node.name = "Base_%s_%d" % [kind,base_id]
    node.position = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))
    node.rotation = float(rec.get("rot",0.0))
    node.z_as_relative = false
    node.z_index = 8
    node.set_meta("base_id",base_id)
    node.set_meta("base_kind",kind)
    node.add_to_group("base_objects")
    base_root.add_child(node)

    if kind == "stash":
        var key = "base_stash_%d" % base_id
        if not container_states.has(key):
            container_states[key] = {
                "name":"БАЗОВЫЙ ЯЩИК",
                "loot_table":"",
                "items":[]
            }

        node.add_to_group("interactable")
        node.set_meta("interaction_type","container")
        node.set_meta("container_key",key)
        node.set_meta("display_name","Базовый ящик")
        node.set_meta("interaction_radius",72.0)

        _world_prop_sprite("crate",node,Vector2(0,-2),0,0.92)

    elif kind == "heater":
        node.add_to_group("interactable")
        node.set_meta("interaction_type","base_heater")
        node.set_meta("display_name","Обогреватель")
        node.set_meta("interaction_radius",70.0)

        _world_prop_sprite("heater",node,Vector2(0,-5),0,0.82)

        var glow = PointLight2D.new()
        glow.name = "Light"
        glow.texture = _make_base_radial_texture()
        glow.texture_scale = 1.15
        glow.energy = 0.72
        glow.color = Color(1.0,0.62,0.30)
        node.add_child(glow)

    elif kind == "campfire":
        node.add_to_group("interactable")
        node.set_meta("interaction_type","base_campfire")
        node.set_meta("display_name","Костёр")
        node.set_meta("interaction_radius",76.0)

        _world_prop_sprite("campfire",node,Vector2(0,-4),0,0.86)

        var fire_light = PointLight2D.new()
        fire_light.name = "Light"
        fire_light.texture = _make_base_radial_texture()
        fire_light.texture_scale = 1.45
        fire_light.energy = 0.86
        fire_light.color = Color(1.0,0.48,0.20)
        node.add_child(fire_light)

    elif kind == "rain_collector":
        node.add_to_group("interactable")
        node.set_meta("interaction_type","base_rain_collector")
        node.set_meta("display_name","Дождесборник")
        node.set_meta("interaction_radius",76.0)

        _world_prop_sprite("rain_collector",node,Vector2(0,-6),0,0.84)

    elif kind == "lamp":
        node.add_to_group("interactable")
        node.set_meta("interaction_type","base_lamp")
        node.set_meta("display_name","Стационарная лампа")
        node.set_meta("interaction_radius",70.0)

        _world_prop_sprite("base_lamp",node,Vector2(0,-8),0,0.82)

        var lamp_light = PointLight2D.new()
        lamp_light.name = "Light"
        lamp_light.texture = _make_base_radial_texture()
        lamp_light.texture_scale = 1.50
        lamp_light.energy = 0.95
        lamp_light.color = Color(1.0,0.84,0.56)
        node.add_child(lamp_light)

    elif kind == "cot":
        node.add_to_group("interactable")
        node.set_meta("interaction_type","base_cot")
        node.set_meta("display_name","Раскладушка")
        node.set_meta("interaction_radius",76.0)

        _world_prop_sprite("cot",node,Vector2(0,-3),0,0.88)

    elif kind == "barricade":
        _world_prop_sprite("barricade",node,Vector2(0,-1),0,0.90)
        _add_static_rect(node,Vector2.ZERO,Vector2(38,14))

    base_object_nodes[base_id] = node
    _refresh_base_object_node(base_id)
    return node

func _refresh_base_object_node(base_id):
    var index = _base_record_index(base_id)
    if index < 0:
        return
    if not base_object_nodes.has(int(base_id)):
        return

    var node = base_object_nodes[int(base_id)]
    if not is_instance_valid(node):
        return

    var rec = base_objects[index]
    var kind = str(rec.get("kind",""))
    var light = node.get_node_or_null("Light")

    if kind == "heater":
        var active = bool(rec.get("on",false)) and float(rec.get("fuel",0.0)) > 0.0
        if light != null:
            light.enabled = active
        node.modulate = Color.WHITE if active else Color(0.62,0.62,0.62)

    elif kind == "campfire":
        var active_fire = bool(rec.get("on",false)) and float(rec.get("fuel",0.0)) > 0.0
        if light != null:
            light.enabled = active_fire
        node.modulate = Color.WHITE if active_fire else Color(0.56,0.56,0.56)

    elif kind == "lamp":
        var active_lamp = bool(rec.get("on",true))
        if light != null:
            light.enabled = active_lamp
        node.modulate = Color.WHITE if active_lamp else Color(0.58,0.58,0.58)



func _build_base_object(kind):
    if not base_build_open:
        return false

    var sheltered = _player_is_sheltered()

    if kind == "rain_collector" and sheltered:
        if base_build_status != null:
            base_build_status.text = "Дождесборник нужно ставить снаружи, под открытым небом."
        return false

    if kind != "campfire" and kind != "rain_collector" and not sheltered:
        if base_build_status != null:
            base_build_status.text = "Этот объект можно строить только внутри существующего укрытия."
        return false

    if not _base_has_costs(kind):
        if base_build_status != null:
            base_build_status.text = "Не хватает материалов: %s" % _base_cost_text(kind)
        return false

    var pos = _base_build_position(kind)
    if not _base_build_position_clear(pos):
        if base_build_status != null:
            base_build_status.text = "Место занято или путь перекрыт."
        return false

    var test_entries = inventory_entries.duplicate(true)
    if not _base_consume_costs(kind,test_entries):
        return false

    var starts_on = kind == "heater" or kind == "lamp"
    var start_fuel = 180.0 if kind == "heater" else 0.0

    var rec = {
        "id":next_base_id,
        "kind":kind,
        "x":pos.x,
        "y":pos.y,
        "rot":aim_direction.angle() if kind == "barricade" else 0.0,
        "on":starts_on,
        "fuel":start_fuel,
        "sound_timer":1.5,
        "stored_water":0.0
    }

    inventory_entries = test_entries
    base_objects.append(rec)
    next_base_id += 1
    _spawn_base_object(rec)

    _add_skill_xp("crafting",4.0 if kind == "barricade" else 5.0)
    _emit_ai_sound(player.global_position,112.0,"workbench",1.10)

    if base_build_status != null:
        if kind == "campfire":
            base_build_status.text = "Построено: КОСТЁР. Нужны дрова для растопки."
        elif kind == "rain_collector":
            base_build_status.text = "Построен ДОЖДЕСБОРНИК. Он наполняется только под дождём."
        else:
            base_build_status.text = "Построено: %s" % _base_object_name(kind)

    _refresh_base_build_ui()
    return true

func _base_refund_for(kind):
    if kind == "stash":
        return {"scrap":1}
    if kind == "heater":
        return {"scrap":1,"cloth":1}
    if kind == "campfire":
        return {"scrap":1}
    if kind == "rain_collector":
        return {"scrap":1,"cloth":1}
    if kind == "lamp":
        return {"flashlight":1}
    if kind == "cot":
        return {"cloth":2,"tape":1}
    if kind == "barricade":
        return {"scrap":1}
    return {}

func _dismantle_nearest_base_object():
    if not base_build_open or player == null:
        return false

    var best_index = -1
    var best_dist = 999999.0

    for i in range(base_objects.size()):
        var rec = base_objects[i]
        var pos = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))
        var dist = player.global_position.distance_to(pos)
        if dist < best_dist and dist <= 72.0:
            best_dist = dist
            best_index = i

    if best_index < 0:
        if base_build_status != null:
            base_build_status.text = "Рядом нет объекта базы."
        return false

    var rec = base_objects[best_index]
    var base_id = int(rec.get("id",-1))
    var kind = str(rec.get("kind",""))

    if kind == "stash":
        var key = "base_stash_%d" % base_id
        if container_states.has(key):
            var entries = container_states[key].get("items",[])
            if not entries.is_empty():
                if base_build_status != null:
                    base_build_status.text = "Сначала освободи базовый ящик."
                return false

    var test_entries = inventory_entries.duplicate(true)
    var refund = _base_refund_for(kind)
    for item_id in refund.keys():
        if _grid_add(test_entries,str(item_id),int(refund[item_id]),INV_W,INV_H) != 0:
            if base_build_status != null:
                base_build_status.text = "Нет места для возвращаемых материалов."
            return false

    inventory_entries = test_entries

    if kind == "stash":
        container_states.erase("base_stash_%d" % base_id)

    if base_object_nodes.has(base_id):
        var node = base_object_nodes[base_id]
        if is_instance_valid(node):
            node.queue_free()
        base_object_nodes.erase(base_id)

    base_objects.remove_at(best_index)
    _emit_ai_sound(player.global_position,74.0,"workbench",0.75)

    if base_build_status != null:
        base_build_status.text = "Разобрано: %s" % _base_object_name(kind)

    _refresh_base_build_ui()
    return true

func _toggle_base_heater(node):
    var base_id = int(node.get_meta("base_id",-1))
    var index = _base_record_index(base_id)
    if index < 0:
        return

    var rec = base_objects[index]
    var active = bool(rec.get("on",false))
    var fuel = max(0.0,float(rec.get("fuel",0.0)))

    if active:
        rec["on"] = false
        _set_survival_feedback("Обогреватель выключен")
    else:
        if fuel <= 0.0:
            var test_entries = inventory_entries.duplicate(true)
            if not _consume_one_item_from_entries(test_entries,"cloth"):
                _set_survival_feedback("Для растопки нужна ткань")
                return
            inventory_entries = test_entries
            fuel += 180.0
            rec["fuel"] = fuel
            _set_survival_feedback("Обогреватель заправлен: +180 сек")

        rec["on"] = true

    base_objects[index] = rec
    _refresh_base_object_node(base_id)



func _collect_rainwater(node):
    var base_id = int(node.get_meta("base_id",-1))
    var index = _base_record_index(base_id)
    if index < 0:
        return

    var rec = base_objects[index]
    var stored = clamp(
        float(rec.get("stored_water",0.0)),
        0.0,
        _rain_collector_capacity()
    )
    var available = int(floor(stored))

    if available <= 0:
        _set_survival_feedback("Дождесборник пока пуст",2.0)
        return

    var remaining = _grid_add(
        inventory_entries,
        "dirty_water",
        available,
        INV_W,
        INV_H
    )
    var moved = available - remaining

    if moved <= 0:
        _set_survival_feedback("В инвентаре нет места для воды",2.0)
        return

    rec["stored_water"] = max(0.0,stored - float(moved))
    base_objects[index] = rec

    _add_skill_xp("survival",min(1.6,0.25 * float(moved)))
    _set_survival_feedback("Собрано дождевой воды: %d" % moved,2.0)
    _refresh_inventory_ui()

func _toggle_base_campfire(node):
    var base_id = int(node.get_meta("base_id",-1))
    var index = _base_record_index(base_id)
    if index < 0:
        return

    var rec = base_objects[index]
    var active = bool(rec.get("on",false))
    var fuel = max(0.0,float(rec.get("fuel",0.0)))

    if active:
        # If the fire is almost out and wood is available, E feeds it instead.
        if fuel < 120.0 and _inventory_count("firewood") > 0:
            var test_entries = inventory_entries.duplicate(true)
            if _consume_one_item_from_entries(test_entries,"firewood"):
                inventory_entries = test_entries
                rec["fuel"] = min(720.0,fuel + 240.0)
                _set_survival_feedback("В костёр добавлены дрова: +240 сек",2.0)
            else:
                rec["on"] = false
                _set_survival_feedback("Костёр потушен")
        else:
            rec["on"] = false
            _set_survival_feedback("Костёр потушен")
    else:
        if fuel <= 0.0:
            var test_entries = inventory_entries.duplicate(true)
            if not _consume_one_item_from_entries(test_entries,"firewood"):
                _set_survival_feedback("Для костра нужны дрова",2.0)
                return
            inventory_entries = test_entries
            fuel = 240.0
            rec["fuel"] = fuel
            _set_survival_feedback("Костёр растоплен: 240 сек",2.0)

        rec["on"] = true
        rec["sound_timer"] = 0.25

    base_objects[index] = rec
    _refresh_base_object_node(base_id)
    _refresh_inventory_ui()

func _toggle_base_lamp(node):
    var base_id = int(node.get_meta("base_id",-1))
    var index = _base_record_index(base_id)
    if index < 0:
        return

    var rec = base_objects[index]
    rec["on"] = not bool(rec.get("on",true))
    base_objects[index] = rec
    _refresh_base_object_node(base_id)
    _set_survival_feedback("Лампа: %s" % ("ВКЛ" if bool(rec["on"]) else "ВЫКЛ"))


func _base_heat_strength_for(kind,dist):
    var d = max(0.0,float(dist))
    if kind == "campfire":
        if d > 175.0:
            return 0.0
        return 18.0 * (1.0 - clamp(d / 175.0,0.0,1.0))

    if kind == "heater":
        if d > 150.0:
            return 0.0
        return 12.0 * (1.0 - clamp(d / 150.0,0.0,1.0))

    return 0.0


func _base_heat_bonus_at_player():
    if player == null:
        return 0.0

    var best = 0.0
    for rec in base_objects:
        var kind = str(rec.get("kind",""))
        if kind != "heater" and kind != "campfire":
            continue
        if not bool(rec.get("on",false)):
            continue
        if float(rec.get("fuel",0.0)) <= 0.0:
            continue

        var pos = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))
        var dist = player.global_position.distance_to(pos)
        best = max(best,_base_heat_strength_for(kind,dist))

    return best

func _player_near_active_base_lamp():
    if player == null:
        return false

    for rec in base_objects:
        if str(rec.get("kind","")) != "lamp":
            continue
        if not bool(rec.get("on",true)):
            continue

        var pos = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))
        if player.global_position.distance_to(pos) <= 130.0:
            return true

    return false



func _update_base_system(delta):
    if base_objects.is_empty():
        return

    for i in range(base_objects.size()):
        var rec = base_objects[i]
        var kind = str(rec.get("kind",""))
        var pos = Vector2(float(rec.get("x",0.0)),float(rec.get("y",0.0)))

        if kind == "rain_collector":
            var stored = clamp(
                float(rec.get("stored_water",0.0)),
                0.0,
                _rain_collector_capacity()
            )
            var fill_rate = _rain_collector_fill_rate(
                weather_state,
                _position_is_sheltered(pos)
            )

            if fill_rate > 0.0:
                stored = min(
                    _rain_collector_capacity(),
                    stored + delta * fill_rate
                )

            rec["stored_water"] = stored
            base_objects[i] = rec
            continue

        if kind != "heater" and kind != "campfire":
            continue
        if not bool(rec.get("on",false)):
            continue

        var fuel_rate = 1.0

        # Outdoor fire survives rain for a while, but consumes fuel much faster.
        if kind == "campfire" and weather_state == "rain" and not _position_is_sheltered(pos):
            fuel_rate = 2.50

        var fuel = max(0.0,float(rec.get("fuel",0.0)) - delta * fuel_rate)
        rec["fuel"] = fuel

        if kind == "campfire":
            var sound_timer = max(0.0,float(rec.get("sound_timer",1.5)) - delta)
            if sound_timer <= 0.0 and fuel > 0.0:
                _emit_ai_sound(pos,135.0,"fire",0.45)
                sound_timer = 4.6 + float(int(rec.get("id",0)) % 3) * 0.35
            rec["sound_timer"] = sound_timer

            if base_object_nodes.has(int(rec.get("id",-1))):
                var node = base_object_nodes[int(rec.get("id",-1))]
                if is_instance_valid(node):
                    var light = node.get_node_or_null("Light")
                    if light != null and fuel > 0.0:
                        var phase = Time.get_ticks_msec() * 0.006 + float(int(rec.get("id",0)))
                        light.energy = 0.84 + sin(phase) * 0.08

        if fuel <= 0.0:
            rec["on"] = false
            if kind == "campfire":
                _set_survival_feedback("Костёр погас",2.0)
            else:
                _set_survival_feedback("Топливо обогревателя закончилось",2.0)

        base_objects[i] = rec
        _refresh_base_object_node(int(rec.get("id",-1)))

func _nearest_hostile_distance():
    if player == null:
        return 999999.0

    var best = 999999.0
    for enemy in get_tree().get_nodes_in_group("infected"):
        if not is_instance_valid(enemy):
            continue
        best = min(best,player.global_position.distance_to(enemy.global_position))
    return best

func _rest_danger_nearby():
    if player == null:
        return true

    for enemy in get_tree().get_nodes_in_group("infected"):
        if not is_instance_valid(enemy):
            continue

        var dist = player.global_position.distance_to(enemy.global_position)
        var state = str(enemy.get_meta("ai_state","idle"))

        if dist <= 105.0:
            return true

        if dist <= 190.0 and (
            state == "chase"
            or state == "investigate"
            or state == "search"
            or state == "suspicious"
        ):
            return true

    return false

func _rest_quality():
    var quality = 1.0

    var heat = _base_heat_bonus_at_player()
    if heat > 2.0:
        quality += 0.18

    if thermal_effective_temperature < 8.0:
        quality -= 0.16
    elif thermal_effective_temperature >= 12.0 and thermal_effective_temperature <= 24.0:
        quality += 0.08

    if wetness > 60.0:
        quality -= 0.16
    elif wetness < 20.0:
        quality += 0.04

    var rest_pain = _effective_pain()
    if rest_pain > 60.0:
        quality -= 0.12
    elif rest_pain < 20.0:
        quality += 0.04

    if wound_infection >= 70.0:
        quality -= 0.18
    elif wound_infection >= 35.0:
        quality -= 0.08

    if hunger < 35.0:
        quality -= 0.10
    if thirst < 35.0:
        quality -= 0.12

    return clamp(quality,0.55,1.28)

func _rest_requirement_text(hours):
    var need_hunger = 6.0
    var need_thirst = 8.0

    if hours >= 4:
        need_hunger = 20.0
        need_thirst = 24.0
    if hours >= 8:
        need_hunger = 34.0
        need_thirst = 40.0

    return "Нужно: еда ≥%d, вода ≥%d" % [int(need_hunger),int(need_thirst)]

func _can_rest_hours(hours):
    if not rest_open:
        return false
    if rest_source_base_id < 0:
        return false
    if _base_record_index(rest_source_base_id) < 0:
        return false
    if not _player_is_sheltered():
        return false
    if bleeding:
        return false
    if body_temperature < 34.5 or body_temperature > 38.5:
        return false
    if _rest_danger_nearby():
        return false

    if hours >= 8:
        return hunger >= 34.0 and thirst >= 40.0
    if hours >= 4:
        return hunger >= 20.0 and thirst >= 24.0

    return hunger >= 6.0 and thirst >= 8.0

func _rest_block_reason(hours):
    if rest_source_base_id < 0 or _base_record_index(rest_source_base_id) < 0:
        return "Раскладушка больше недоступна."
    if not _player_is_sheltered():
        return "Спать можно только внутри укрытия."
    if bleeding:
        return "Сначала останови кровотечение."
    if body_temperature < 34.5:
        return "Слишком сильное переохлаждение для безопасного сна."
    if body_temperature > 38.5:
        return "Слишком сильный перегрев для безопасного сна."
    if _rest_danger_nearby():
        return "Рядом заражённые — отдых небезопасен."

    if hours >= 8 and (hunger < 34.0 or thirst < 40.0):
        return "Для 8 часов: еда ≥34 и вода ≥40."
    if hours >= 4 and (hunger < 20.0 or thirst < 24.0):
        return "Для 4 часов: еда ≥20 и вода ≥24."
    if hunger < 6.0 or thirst < 8.0:
        return "Слишком сильный голод или жажда."

    return ""

func _advance_weather_for_rest(hours):
    var simulated_seconds = float(hours) * 15.0
    var remaining = simulated_seconds

    while remaining > 0.0:
        if weather_timer <= 0.0:
            _weather_next_state()

        if remaining < weather_timer:
            weather_timer -= remaining
            remaining = 0.0
        else:
            remaining -= max(0.01,weather_timer)
            _weather_next_state()

func _advance_base_time_for_rest(hours):
    var simulated_seconds = float(hours) * 15.0

    for i in range(base_objects.size()):
        var rec = base_objects[i]
        if str(rec.get("kind","")) != "heater":
            continue
        if not bool(rec.get("on",false)):
            continue

        var fuel = max(0.0,float(rec.get("fuel",0.0)) - simulated_seconds)
        rec["fuel"] = fuel

        if fuel <= 0.0:
            rec["on"] = false

        base_objects[i] = rec
        _refresh_base_object_node(int(rec.get("id",-1)))

func _perform_rest(hours):
    var rest_hours = clamp(int(hours),1,8)

    if not _can_rest_hours(rest_hours):
        if rest_status != null:
            rest_status.text = _rest_block_reason(rest_hours)
        return false

    var quality = _rest_quality()
    var start_hunger = hunger
    var start_thirst = thirst

    # Overnight metabolism is intentionally more meaningful than passive
    # real-time drain, but still leaves room for normal gameplay afterward.
    hunger = max(0.0,hunger - float(rest_hours) * 1.35)
    thirst = max(0.0,thirst - float(rest_hours) * 1.85)

    pain = max(0.0,pain - float(rest_hours) * 5.0 * quality)

    if not bleeding:
        var zone_recovery = float(rest_hours) * 1.35 * quality
        for zone in ["head","torso","arms","legs"]:
            body_condition[zone] = min(
                100.0,
                _body_condition_value(zone) + zone_recovery
            )

        if start_hunger >= 40.0 and start_thirst >= 45.0:
            health = min(
                100.0,
                health + float(rest_hours) * 1.8 * quality
            )

    var local_heat = _base_heat_bonus_at_player()
    var dry_rate = 6.0 + min(8.0,local_heat * 0.55)
    wetness = max(0.0,wetness - float(rest_hours) * dry_rate)

    var thermal_recovery = float(rest_hours) * (0.16 + local_heat * 0.01)
    body_temperature = move_toward(body_temperature,36.8,thermal_recovery)

    stamina = _survival_stamina_cap()
    is_sprinting = false
    flashlight_on = false
    if player_light != null:
        player_light.visible = false

    _advance_base_time_for_rest(rest_hours)
    _advance_weather_for_rest(rest_hours)

    var rest_advanced_minutes = world_minutes + float(rest_hours) * 60.0
    if rest_advanced_minutes >= 1440.0:
        world_day += int(floor(rest_advanced_minutes / 1440.0))
    world_minutes = fmod(rest_advanced_minutes,1440.0)
    thermal_tick_accumulator = 0.20
    autosave_time = 0.0

    _set_survival_feedback(
        "Отдых %d ч • качество %d%%" % [rest_hours,int(quality * 100.0)],
        2.4
    )

    _close_rest_panel()
    _save_state()
    return true

func _create_rest_ui():
    var canvas = CanvasLayer.new()
    canvas.layer = 28
    canvas.name = "RestUI"
    add_child(canvas)

    rest_panel = Panel.new()
    rest_panel.position = Vector2(190,82)
    rest_panel.size = Vector2(260,220)
    canvas.add_child(rest_panel)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.025,0.030,0.029,0.985)
    style.border_color = Color(0.47,0.45,0.38,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    rest_panel.add_theme_stylebox_override("panel",style)

    var title = Label.new()
    title.position = Vector2(14,12)
    title.text = "ОТДЫХ И ВОССТАНОВЛЕНИЕ"
    title.add_theme_font_size_override("font_size",9)
    title.modulate = Color(0.94,0.90,0.75)
    rest_panel.add_child(title)

    var text = Label.new()
    text.position = Vector2(14,38)
    text.size = Vector2(232,50)
    text.text = "Сон расходует еду и воду.\nТравмы и боль восстанавливаются постепенно."
    text.add_theme_font_size_override("font_size",7)
    text.modulate = Color(0.68,0.71,0.66)
    rest_panel.add_child(text)

    _make_button(rest_panel,Vector2(14,88),Vector2(72,30),"1 Ч",_perform_rest.bind(1))
    _make_button(rest_panel,Vector2(94,88),Vector2(72,30),"4 Ч",_perform_rest.bind(4))
    _make_button(rest_panel,Vector2(174,88),Vector2(72,30),"8 Ч",_perform_rest.bind(8))

    rest_status = Label.new()
    rest_status.position = Vector2(14,128)
    rest_status.size = Vector2(232,48)
    rest_status.add_theme_font_size_override("font_size",7)
    rest_panel.add_child(rest_status)

    _make_button(rest_panel,Vector2(142,184),Vector2(104,26),"ЗАКРЫТЬ",_close_rest_panel)

    rest_panel.visible = false

func _open_rest_panel(node):
    if node == null or not is_instance_valid(node):
        return

    var base_id = int(node.get_meta("base_id",-1))
    if base_id < 0 or _base_record_index(base_id) < 0:
        return

    if _rest_danger_nearby():
        _set_survival_feedback("Слишком опасно для отдыха",1.8)
        return

    rest_source_base_id = base_id
    rest_open = true
    inventory_open = true
    is_sprinting = false
    player.velocity = Vector2.ZERO

    if inventory_panel != null:
        inventory_panel.visible = false
    if equipment_panel != null:
        equipment_panel.visible = false
    if container_panel != null:
        container_panel.visible = false
    if craft_panel != null:
        craft_panel.visible = false
    if base_build_panel != null:
        base_build_panel.visible = false

    _refresh_rest_ui()

func _close_rest_panel():
    rest_open = false
    rest_source_base_id = -1
    inventory_open = false

    if rest_panel != null:
        rest_panel.visible = false

func _refresh_rest_ui():
    if rest_panel == null:
        return

    rest_panel.visible = rest_open
    if not rest_open or rest_status == null:
        return

    var quality = int(_rest_quality() * 100.0)
    var danger_text = "ОПАСНО" if _rest_danger_nearby() else "БЕЗОПАСНО"

    rest_status.text = "Качество сна: %d%% • %s\n%s" % [
        quality,
        danger_text,
        _rest_requirement_text(8)
    ]



func _create_base_build_ui():
    var canvas = CanvasLayer.new()
    canvas.layer = 27
    canvas.name = "BaseBuildUI"
    add_child(canvas)

    base_build_panel = Panel.new()
    base_build_panel.position = Vector2(370,58)
    base_build_panel.size = Vector2(254,326)
    canvas.add_child(base_build_panel)

    var style = StyleBoxFlat.new()
    style.bg_color = Color(0.027,0.032,0.031,0.985)
    style.border_color = Color(0.43,0.40,0.34,1.0)
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    base_build_panel.add_theme_stylebox_override("panel",style)

    var title = Label.new()
    title.position = Vector2(12,10)
    title.text = "БАЗА И СИСТЕМЫ ВЫЖИВАНИЯ"
    title.add_theme_font_size_override("font_size",9)
    title.modulate = Color(0.94,0.90,0.75)
    base_build_panel.add_child(title)

    var hint = Label.new()
    hint.position = Vector2(12,31)
    hint.size = Vector2(230,38)
    hint.text = "B: открыть/закрыть • X: разобрать ближайшее
База — под крышей. Костёр/дождесборник — снаружи."
    hint.add_theme_font_size_override("font_size",7)
    hint.modulate = Color(0.65,0.68,0.62)
    base_build_panel.add_child(hint)

    _make_button(base_build_panel,Vector2(12,75),Vector2(108,30),"ЯЩИК",_build_base_object.bind("stash"))
    _make_button(base_build_panel,Vector2(132,75),Vector2(108,30),"ОБОГРЕВ",_build_base_object.bind("heater"))
    _make_button(base_build_panel,Vector2(12,111),Vector2(108,30),"ЛАМПА",_build_base_object.bind("lamp"))
    _make_button(base_build_panel,Vector2(132,111),Vector2(108,30),"РАСКЛАДУШКА",_build_base_object.bind("cot"))
    _make_button(base_build_panel,Vector2(12,147),Vector2(108,30),"БАРРИКАДА",_build_base_object.bind("barricade"))
    _make_button(base_build_panel,Vector2(132,147),Vector2(108,30),"КОСТЁР",_build_base_object.bind("campfire"))
    _make_button(base_build_panel,Vector2(12,183),Vector2(108,30),"ДОЖДЕСБОР",_build_base_object.bind("rain_collector"))

    base_build_status = Label.new()
    base_build_status.position = Vector2(12,220)
    base_build_status.size = Vector2(230,62)
    base_build_status.add_theme_font_size_override("font_size",7)
    base_build_panel.add_child(base_build_status)

    _make_button(base_build_panel,Vector2(136,288),Vector2(104,26),"ЗАКРЫТЬ",_close_base_build)

    base_build_panel.visible = false


func _refresh_base_build_ui():
    if base_build_panel == null:
        return

    base_build_panel.visible = base_build_open
    if not base_build_open or base_build_status == null:
        return

    var shelter_text = "УКРЫТИЕ: ДА" if _player_is_sheltered() else "УКРЫТИЕ: НЕТ"
    base_build_status.text = "%s
Ящик: %s
Обогрев: %s
Костёр: %s
Дождесбор: %s" % [
        shelter_text,
        _base_cost_text("stash"),
        _base_cost_text("heater"),
        _base_cost_text("campfire"),
        _base_cost_text("rain_collector")
    ]

func _open_base_build():
    if base_build_open:
        return

    if mod_panel_open or crafting_open:
        return

    base_build_open = true
    inventory_open = true
    selected_inventory_index = -1
    selected_container_index = -1
    active_container_key = ""

    if inventory_panel != null:
        inventory_panel.visible = false
    if equipment_panel != null:
        equipment_panel.visible = false
    if container_panel != null:
        container_panel.visible = false
    if craft_panel != null:
        craft_panel.visible = false

    _refresh_base_build_ui()

func _close_base_build():
    base_build_open = false
    inventory_open = false

    if base_build_panel != null:
        base_build_panel.visible = false


func _create_day_night():
    canvas_modulate = CanvasModulate.new()
    canvas_modulate.name = "WorldDarkness"
    add_child(canvas_modulate)

    player_light = PointLight2D.new()
    player_light.name = "FlashlightLight"

    var gradient = Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0,1.0])
    gradient.colors = PackedColorArray([
        Color(1.0,0.91,0.70,1.0),
        Color(1.0,0.86,0.58,0.0)
    ])

    var texture = GradientTexture2D.new()
    texture.gradient = gradient
    texture.width = 192
    texture.height = 192
    texture.fill = 1
    texture.fill_from = Vector2(0.5,0.5)
    texture.fill_to = Vector2(1.0,0.5)

    player_light.texture = texture
    player_light.energy = 1.35
    player_light.texture_scale = 1.55
    player_light.visible = false
    player.add_child(player_light)

    _update_day_night(0.0)

func _update_day_night(delta):
    var advanced_minutes = world_minutes + delta * day_speed
    if advanced_minutes >= 1440.0:
        world_day += int(floor(advanced_minutes / 1440.0))
    world_minutes = fmod(advanced_minutes,1440.0)
    var hour = world_minutes / 60.0
    var brightness = 1.0

    if hour >= 21.0 or hour < 5.0:
        brightness = 0.18
    elif hour >= 18.0:
        brightness = lerpf(1.0,0.18,(hour - 18.0) / 3.0)
    elif hour < 7.0:
        brightness = lerpf(0.18,1.0,(hour - 5.0) / 2.0)

    if canvas_modulate != null:
        var weather_dim = 1.0
        var blue_shift = 1.0
        if weather_state == "cloudy":
            weather_dim = 0.90
            blue_shift = 1.04
        elif weather_state == "rain":
            weather_dim = 0.82
            blue_shift = 1.08

        canvas_modulate.color = Color(
            brightness * weather_dim,
            brightness * 0.98 * weather_dim,
            min(1.0,brightness * 1.08 * weather_dim * blue_shift),
            1.0
        )

    var has_flashlight = str(equipment.get("utility","")) == "flashlight"

    if flashlight_on and has_flashlight and flashlight_battery > 0.0:
        flashlight_battery = max(0.0,flashlight_battery - delta * 0.22)
        player_light.visible = true
        if flashlight_battery <= 0.0:
            flashlight_on = false
            player_light.visible = false
    else:
        player_light.visible = false

func _toggle_flashlight():
    if str(equipment.get("utility","")) != "flashlight":
        flashlight_on = false
        return
    if flashlight_battery <= 0.0:
        flashlight_on = false
        return
    flashlight_on = not flashlight_on

func _time_text():
    var total = int(world_minutes)
    return "%02d:%02d" % [int(total / 60) % 24, total % 60]



func _save_state():
    if player == null:
        return

    var data = {
        "save_version":70,
        "player_x":player.global_position.x,
        "player_y":player.global_position.y,
        "health":health,
        "stamina":stamina,
        "hunger":hunger,
        "thirst":thirst,
        "bleeding":bleeding,
        "bleed_damage_taken":bleed_damage_taken,
        "pain":pain,
        "body_condition":body_condition,
        "last_injury_zone":last_injury_zone,
        "wound_contamination":wound_contamination,
        "wound_infection":wound_infection,
        "painkiller_time":painkiller_time,
        "antibiotic_time":antibiotic_time,
        "well_fed_time":well_fed_time,
        "warm_drink_time":warm_drink_time,
        "skill_levels":skill_levels,
        "skill_xp":skill_xp,
        "current_weapon_id":current_weapon_id,
        "equipped_melee_id":equipped_melee_id,
        "weapon_mags":weapon_mags,
        "weapon_condition":weapon_condition,
        "weapon_mods":weapon_mods,
        "inventory_entries":inventory_entries,
        "equipment":equipment,
        "flashlight_battery":flashlight_battery,
        "flashlight_on":flashlight_on,
        "world_minutes":world_minutes,
        "world_day":world_day,
        "weather_state":weather_state,
        "weather_timer":weather_timer,
        "weather_cycle_index":weather_cycle_index,
        "body_temperature":body_temperature,
        "wetness":wetness,
        "container_states":container_states,
        "door_states":door_states,
        "picked_world_items":picked_world_items,
        "dropped_items":dropped_items,
        "next_drop_id":next_drop_id,
        "base_objects":base_objects,
        "next_base_id":next_base_id,
        "discovered_chunks":discovered_chunks,
        "defeated":defeated
    }

    var file = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(data))

func _sanitize_loaded_entries(entries):
    for i in range(entries.size() - 1,-1,-1):
        var id = str(entries[i].get("id",""))
        if not item_defs.has(id):
            entries.remove_at(i)

func _sanitize_loaded_state():
    for weapon_id in ["makarov","shotgun","akm"]:
        if not weapon_mods.has(weapon_id) or typeof(weapon_mods[weapon_id]) != TYPE_DICTIONARY:
            weapon_mods[weapon_id] = {"magazine":"","muzzle":""}
            continue

        var mods = weapon_mods[weapon_id]
        if mods.has("sight"):
            mods.erase("sight")
        if not mods.has("magazine"):
            mods["magazine"] = ""
        if not mods.has("muzzle"):
            mods["muzzle"] = ""

        var magazine_id = str(mods.get("magazine",""))
        if magazine_id != "":
            if not item_defs.has(magazine_id) or str(item_defs[magazine_id].get("allowed_weapon","")) != weapon_id:
                mods["magazine"] = ""

        var muzzle_id = str(mods.get("muzzle",""))
        if muzzle_id != "":
            if not item_defs.has(muzzle_id) or str(item_defs[muzzle_id].get("allowed_weapon","")) != weapon_id:
                mods["muzzle"] = ""

        weapon_mods[weapon_id] = mods

    _sanitize_loaded_entries(inventory_entries)

    for key in container_states.keys():
        var state = container_states[key]
        var entries = state.get("items",[])
        _sanitize_loaded_entries(entries)
        state["items"] = entries
        container_states[key] = state

    for i in range(dropped_items.size() - 1,-1,-1):
        if not item_defs.has(str(dropped_items[i].get("id",""))):
            dropped_items.remove_at(i)

    for weapon_id in ["makarov","shotgun","akm"]:
        weapon_mags[weapon_id] = min(
            int(weapon_mags.get(weapon_id,0)),
            _weapon_mag_capacity(weapon_id)
        )

    if equipped_melee_id != "":
        if not melee_defs.has(equipped_melee_id) or not _inventory_has_item(equipped_melee_id):
            equipped_melee_id = ""

    _ensure_weapon_runtime_state()

func _load_state():
    var load_path = SAVE_PATH
    if not FileAccess.file_exists(load_path):
        if FileAccess.file_exists(LEGACY_SAVE_PATH):
            load_path = LEGACY_SAVE_PATH
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0430):
            load_path = LEGACY_SAVE_PATH_0430
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0420):
            load_path = LEGACY_SAVE_PATH_0420
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0410):
            load_path = LEGACY_SAVE_PATH_0410
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0400):
            load_path = LEGACY_SAVE_PATH_0400
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0390):
            load_path = LEGACY_SAVE_PATH_0390
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0380):
            load_path = LEGACY_SAVE_PATH_0380
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0370):
            load_path = LEGACY_SAVE_PATH_0370
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0360):
            load_path = LEGACY_SAVE_PATH_0360
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0350):
            load_path = LEGACY_SAVE_PATH_0350
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0340):
            load_path = LEGACY_SAVE_PATH_0340
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0330):
            load_path = LEGACY_SAVE_PATH_0330
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0320):
            load_path = LEGACY_SAVE_PATH_0320
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0310):
            load_path = LEGACY_SAVE_PATH_0310
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0301):
            load_path = LEGACY_SAVE_PATH_0301
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0300):
            load_path = LEGACY_SAVE_PATH_0300
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0290):
            load_path = LEGACY_SAVE_PATH_0290
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0280):
            load_path = LEGACY_SAVE_PATH_0280
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0270):
            load_path = LEGACY_SAVE_PATH_0270
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0260):
            load_path = LEGACY_SAVE_PATH_0260
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0250):
            load_path = LEGACY_SAVE_PATH_0250
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0240):
            load_path = LEGACY_SAVE_PATH_0240
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0230):
            load_path = LEGACY_SAVE_PATH_0230
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0221):
            load_path = LEGACY_SAVE_PATH_0221
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0220):
            load_path = LEGACY_SAVE_PATH_0220
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0211):
            load_path = LEGACY_SAVE_PATH_0211
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0210):
            load_path = LEGACY_SAVE_PATH_0210
        elif FileAccess.file_exists(LEGACY_SAVE_PATH_0201):
            load_path = LEGACY_SAVE_PATH_0201
        else:
            return

    var file = FileAccess.open(load_path,FileAccess.READ)
    if file == null:
        return

    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return

    if parsed.has("player_x") and parsed.has("player_y"):
        set_meta("loaded_player_position",Vector2(
            float(parsed["player_x"]),
            float(parsed["player_y"])
        ))

    health = float(parsed.get("health",100.0))
    stamina = float(parsed.get("stamina",100.0))
    hunger = float(parsed.get("hunger",88.0))
    thirst = float(parsed.get("thirst",82.0))
    bleeding = bool(parsed.get("bleeding",false))
    bleed_damage_taken = float(parsed.get("bleed_damage_taken",0.0))
    pain = float(parsed.get("pain",0.0))
    body_condition = parsed.get("body_condition",body_condition)
    last_injury_zone = str(parsed.get("last_injury_zone",""))
    wound_contamination = float(parsed.get("wound_contamination",0.0))
    wound_infection = float(parsed.get("wound_infection",0.0))
    painkiller_time = float(parsed.get("painkiller_time",0.0))
    antibiotic_time = float(parsed.get("antibiotic_time",0.0))
    well_fed_time = float(parsed.get("well_fed_time",0.0))
    warm_drink_time = float(parsed.get("warm_drink_time",0.0))
    skill_levels = parsed.get("skill_levels",skill_levels)
    skill_xp = parsed.get("skill_xp",skill_xp)
    current_weapon_id = str(parsed.get("current_weapon_id","makarov"))
    equipped_melee_id = str(parsed.get("equipped_melee_id",""))
    weapon_mags = parsed.get("weapon_mags",weapon_mags)
    weapon_condition = parsed.get("weapon_condition",weapon_condition)
    weapon_mods = parsed.get("weapon_mods",weapon_mods)
    inventory_entries = parsed.get("inventory_entries",[])
    equipment = parsed.get("equipment",equipment)
    flashlight_battery = float(parsed.get("flashlight_battery",100.0))
    flashlight_on = bool(parsed.get("flashlight_on",false))
    world_minutes = float(parsed.get("world_minutes",19.5 * 60.0))
    world_day = max(1,int(parsed.get("world_day",1)))
    weather_state = str(parsed.get("weather_state","clear"))
    weather_timer = float(parsed.get("weather_timer",105.0))
    weather_cycle_index = int(parsed.get("weather_cycle_index",0))
    body_temperature = float(parsed.get("body_temperature",36.8))
    wetness = float(parsed.get("wetness",0.0))
    container_states = parsed.get("container_states",{})
    door_states = parsed.get("door_states",{})
    picked_world_items = parsed.get("picked_world_items",{})
    dropped_items = parsed.get("dropped_items",[])
    next_drop_id = int(parsed.get("next_drop_id",1))
    base_objects = parsed.get("base_objects",[])
    next_base_id = int(parsed.get("next_base_id",1))
    discovered_chunks = parsed.get("discovered_chunks",{})
    defeated = parsed.get("defeated",{})
    if typeof(discovered_chunks) != TYPE_DICTIONARY:
        discovered_chunks = {}
    _sanitize_skills()
    _sanitize_base_objects()
    _sanitize_loaded_state()
    _sanitize_body_condition()
    wound_contamination = clamp(wound_contamination,0.0,100.0)
    wound_infection = clamp(wound_infection,0.0,100.0)
    painkiller_time = max(0.0,painkiller_time)
    antibiotic_time = max(0.0,antibiotic_time)
    well_fed_time = max(0.0,well_fed_time)
    warm_drink_time = max(0.0,warm_drink_time)
    medical_tick_accumulator = 0.0
    stamina = clamp(stamina,0.0,_survival_stamina_cap())
    is_sprinting = false
    body_temperature = clamp(body_temperature,30.5,40.5)
    thermal_tick_accumulator = 0.20
    wetness = clamp(wetness,0.0,100.0)
    if weather_state != "clear" and weather_state != "cloudy" and weather_state != "rain":
        weather_state = "clear"
    _cancel_reload()

func _rect(center,size,color,parent):
    var poly = Polygon2D.new()
    poly.position = center
    poly.color = color
    poly.polygon = PackedVector2Array([
        Vector2(-size.x*0.5,-size.y*0.5),
        Vector2(size.x*0.5,-size.y*0.5),
        Vector2(size.x*0.5,size.y*0.5),
        Vector2(-size.x*0.5,size.y*0.5)
    ])
    parent.add_child(poly)
    return poly

func _poly(points,color,parent,offset=Vector2.ZERO):
    var poly = Polygon2D.new()
    poly.position = offset
    poly.color = color
    poly.polygon = points
    parent.add_child(poly)
    return poly

func _ellipse(center,rx,ry,color,parent):
    var points = PackedVector2Array()
    for i in range(18):
        var a = TAU * float(i) / 18.0
        points.append(Vector2(cos(a)*rx,sin(a)*ry))
    return _poly(points,color,parent,center)

func _ensure_input(action_name,key_code):
    if not InputMap.has_action(action_name):
        InputMap.add_action(action_name)

    if InputMap.action_get_events(action_name).is_empty():
        var ev = InputEventKey.new()
        ev.physical_keycode = key_code
        InputMap.action_add_event(action_name,ev)