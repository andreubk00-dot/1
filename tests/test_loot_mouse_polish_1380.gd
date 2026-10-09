extends SceneTree

const Harness = preload("res://tests/rest_harness.gd")
var checks := 0
var failures := 0

func check(ok:bool,description:String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ",description)

func _initialize() -> void:
    call_deferred("run")

func run() -> void:
    var game = Harness.new()
    root.add_child(game)
    await process_frame

    # Aim/firing must not trigger from UI click or exceed existing weapon rules.
    game.current_weapon_id = "makarov"
    game.equipped_melee_id = ""
    game.inventory_open = false
    game.rest_open = false
    game.crafting_open = false
    game.base_build_open = false
    game.mod_panel_open = false
    game.trader_open = false
    game.contract_open = false
    game.region_map_open = false
    game.developer_panel_open = false
    check(game._can_hold_fire_from_pointer(true),"Mouse hold should work for semi-auto firearm")
    check(not game._can_hold_fire_from_pointer(false),"Release must stop hold-to-fire")
    game.inventory_open = true
    check(not game._can_hold_fire_from_pointer(true),"Inventory must block mouse fire")
    game.inventory_open = false
    game.rest_open = true
    check(not game._can_hold_fire_from_pointer(true),"Rest screen must block mouse fire")
    game.rest_open = false
    game.region_map_open = true
    check(not game._can_hold_fire_from_pointer(true),"Map must block mouse fire")
    game.region_map_open = false
    game.equipped_melee_id = "combat_knife"
    check(not game._can_hold_fire_from_pointer(true),"Held LMB must not auto-repeat melee")
    game.equipped_melee_id = ""
    game.current_weapon_id = "missing_weapon"
    check(not game._can_hold_fire_from_pointer(true),"Unknown weapon must not shoot")
    game.current_weapon_id = "makarov"

    # Visual-only pickup feedback must use the actual inventory atlas.
    game._create_hud()
    check(game.hud_pickup_panel != null,"Centered loot panel missing")
    check(game.hud_pickup_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
        "Loot overlay must not intercept aim/click")
    check(game.hud_pickup_panel.position == Vector2(140,130),"Loot cards not screen-centered")
    var before = game.inventory_entries.duplicate(true)
    game._show_pickup_reveal("bandage",2)
    check(game.hud_pickup_panel.visible,"First pickup should show loot cards")
    check(game.hud_pickup_panel.size.x == 121.0,"Single item should not have a wide empty popup")
    check(game.hud_pickup_panel.position.x == (640.0 - 121.0) * 0.5,"Single item not centered")
    check(game.hud_pickup_items.get_child_count() == 1,"First pickup card missing")
    var first_card = game.hud_pickup_items.get_child(0)
    var first_content = first_card.get_child(0)
    var first_icon = first_content.get_child(0) as TextureRect
    check(first_icon != null and first_icon.texture == game._make_item_icon("bandage"),
        "Loot card must reuse canonical item icon")
    game._show_pickup_reveal("makarov",1)
    game._show_pickup_reveal("akm",1)
    check(game.hud_pickup_items.get_child_count() == 3,
        "Multiple pickups must show three icon cards")
    check(game.hud_pickup_panel.size.x == 345.0,"Three-item popup should fit exact width")
    game._show_pickup_reveal("water_clean",1)
    check(game.hud_pickup_items.get_child_count() == 3,
        "Loot overlay must cap visual cards to three")
    check(game.hud_pickup_timer == 2.0,"New pickup must refresh display timer")
    check(game.inventory_entries == before,"Loot display must never grant items")
    game._show_pickup_reveal("unknown_nonexistent_item",1)
    check(game.hud_pickup_items.get_child_count() == 3,
        "Unknown item should not create an empty reward")
    game.hud_pickup_panel.visible = false

    var exit_code := 1 if failures > 0 else 0
    game.free()
    await process_frame
    print("OSTATOK LOOT / MOUSE: ",checks," checks, ",failures," failures")
    quit(exit_code)
