extends SceneTree
# dev69: settings. Every gameplay key is an InputMap action and can be rebound
# in Settings → Keys: a taken key swaps with its owner, reserved keys refuse,
# bindings survive a restart and a corrupted file; hints and the HUD print the
# bound key. Screen: window mode, window size, FPS cap, vsync, crisp pixels,
# HUD scale (the HUD blocks never overlap or leave the screen). Every action
# still does its job after rebinding, and the settings file keeps both parts.
const Main = preload("res://main_script_mod.gd")
const PauseMenu = preload("res://world/pause_menu.gd")
const InputBindings = preload("res://world/input_bindings.gd")

var checks := 0
var failures := 0

func check(ok: bool, msg: String) -> void:
    checks += 1
    if not ok:
        failures += 1
        printerr("FAIL: ", msg)

func _initialize():
    call_deferred("run")

func frames(n: int) -> void:
    for i in range(n):
        await physics_frame

func key_event(code: int, pressed: bool = true) -> InputEventKey:
    var e = InputEventKey.new()
    e.physical_keycode = code
    e.pressed = pressed
    return e

func send(game, ev: InputEvent) -> void:
    game._unhandled_input(ev)

func run():
    # --- the catalogue -----------------------------------------------------
    var ids = InputBindings.action_ids()
    var defaults = InputBindings.defaults()
    var seen_codes = {}
    for id in ids:
        check(InputBindings.action_label(id) != id, "action without a name: " + id)
        for code in defaults[id]:
            check(InputBindings.is_valid_code(code), "default key not bindable: %s %s" % [id, code])
            check(not seen_codes.has(code), "two actions share a default key: %s / %s" % [id, seen_codes.get(code, "")])
            seen_codes[code] = id
    for must in ["interact", "inventory", "flashlight", "bandage", "shove", "drop_item", "dismantle", "quick_save", "base_build", "region_map", "reload", "sprint", "crouch"]:
        check(must in ids, "not rebindable: " + must)
    check(InputBindings.code_label("k:%d" % KEY_E) == "E" and InputBindings.code_label("k:%d" % KEY_SPACE) == "Пробел", "key names unreadable")
    check(InputBindings.code_label("m:%d" % MOUSE_BUTTON_XBUTTON1) == "Мышь 4", "mouse button name")
    check(InputBindings.code_label("k:%d" % KEY_KP_1) == "Num 1", "numpad name")

    # --- sanitize: bad files never break the controls ------------------------
    var junk = InputBindings.sanitize({"interact": ["k:%d" % KEY_ESCAPE], "flashlight": "k:%d" % KEY_E, "reload": 42, "shove": ["m:1", "zzz"], "move_up": ["k:%d" % KEY_S]})
    check(junk["interact"] == ["k:%d" % KEY_E] or junk["flashlight"] == ["k:%d" % KEY_E], "a corrupted file lost E")
    var used = {}
    var dup = false
    for id in ids:
        for c in junk[id]:
            if used.has(c):
                dup = true
            used[c] = id
    check(not dup, "a corrupted file left one key on two actions")
    check(junk["reload"] == ["k:%d" % KEY_R] and junk["shove"] == ["k:%d" % KEY_V], "bad entries did not fall back to defaults")
    check(InputBindings.sanitize("garbage") == defaults, "garbage file is not the defaults")

    # --- rebind / swap / reserved ---------------------------------------------
    var m = InputBindings.defaults()
    var r = InputBindings.rebind(m, "flashlight", "k:%d" % KEY_E)
    check(r["ok"] and r["swapped"] == "interact", "taking E did not swap with interact")
    check(r["map"]["flashlight"] == ["k:%d" % KEY_E] and r["map"]["interact"] == ["k:%d" % KEY_F], "the swap did not trade keys")
    for code in ["k:%d" % KEY_ESCAPE, "k:%d" % KEY_F10, "m:%d" % MOUSE_BUTTON_LEFT, "m:%d" % MOUSE_BUTTON_RIGHT, "m:%d" % MOUSE_BUTTON_WHEEL_UP]:
        var rr = InputBindings.rebind(m, "shove", code)
        check(not rr["ok"] and rr["reason"] == "reserved", "a reserved key was bound: " + code)
    var rm = InputBindings.rebind(m, "shove", "m:%d" % MOUSE_BUTTON_XBUTTON1)
    check(rm["ok"] and rm["map"]["shove"] == ["m:%d" % MOUSE_BUTTON_XBUTTON1] and rm["swapped"] == "", "side mouse button not bindable")
    var ri = InputBindings.rebind(m, "region_map", "k:%d" % KEY_I)
    check(ri["ok"] and ri["swapped"] == "inventory" and ri["map"]["inventory"] == ["k:%d" % KEY_M], "taking I from inventory went wrong: " + str(ri["map"]["inventory"]))

    # --- the game: every action works after rebinding -------------------------
    var game = Main.new()
    root.add_child(game)
    await frames(8)
    game.developer_invulnerable = true
    check(InputBindings.current() == defaults, "a new game does not start on the default keys")
    check(game.hud_interaction_key_label.visible, "the drawn E is gone on default keys")

    # flashlight on G
    game.equipment["utility"] = "flashlight"
    game.flashlight_battery = 100.0
    var map = InputBindings.rebind(InputBindings.current(), "flashlight", "k:%d" % KEY_G)["map"]
    InputBindings.apply(map)
    var lamp = game.flashlight_on
    send(game, key_event(KEY_F))
    check(game.flashlight_on == lamp, "the old flashlight key still works")
    send(game, key_event(KEY_G))
    check(game.flashlight_on != lamp, "the flashlight does not answer its new key")
    send(game, key_event(KEY_G, false))
    send(game, key_event(KEY_G))
    check(game.flashlight_on == lamp, "the flashlight does not toggle back")

    # inventory on Z (Tab and I free now)
    InputBindings.apply(InputBindings.rebind(InputBindings.current(), "inventory", "k:%d" % KEY_Z)["map"])
    send(game, key_event(KEY_TAB))
    check(not game.inventory_open, "Tab opens the inventory after it was moved")
    send(game, key_event(KEY_Z))
    check(game.inventory_open, "the inventory does not open on its new key")
    send(game, key_event(KEY_ESCAPE))
    check(not game.inventory_open, "Esc does not close the inventory")
    check(game.pause_menu == null or not game.pause_menu.visible, "closing the inventory opened the pause")

    # quick slot 2 on the side mouse button; the digit 2 no longer selects it
    InputBindings.apply(InputBindings.rebind(InputBindings.current(), "quick_slot_2", "m:%d" % MOUSE_BUTTON_XBUTTON2)["map"])
    var mb = InputEventMouseButton.new()
    mb.button_index = MOUSE_BUTTON_XBUTTON2
    mb.pressed = true
    check(InputBindings.pressed(mb, "quick_slot_2"), "the side button does not press quick slot 2")
    check(not InputBindings.pressed(key_event(KEY_2), "quick_slot_2"), "the digit still presses a moved quick slot")
    # logical-key fallback: an event with no physical code
    var logical = InputEventKey.new()
    logical.keycode = KEY_3
    logical.pressed = true
    check(InputBindings.pressed(logical, "quick_slot_3"), "logical-key fallback lost")
    check(not InputBindings.pressed(logical, "quick_slot_2"), "logical-key fallback hit the wrong slot")
    # echo never repeats an action
    var echo = key_event(KEY_G)
    echo.echo = true
    check(not InputBindings.pressed(echo, "flashlight"), "a held key repeats the action")

    # bandage, shove, interact, save, map, build, dismantle reach their handlers
    for pair in [["bandage", KEY_J], ["shove", KEY_K], ["quick_save", KEY_F6], ["region_map", KEY_N], ["base_build", KEY_U]]:
        InputBindings.apply(InputBindings.rebind(InputBindings.current(), pair[0], "k:%d" % pair[1])["map"])
        check(InputBindings.pressed(key_event(pair[1]), pair[0]), "%s does not answer its new key" % pair[0])
    send(game, key_event(KEY_N))
    check(game.region_map_open, "the map does not open on its new key")
    send(game, key_event(KEY_ESCAPE))
    check(not game.region_map_open, "Esc does not close the map")
    send(game, key_event(KEY_U))
    check(game.base_build_open, "building does not open on its new key")
    send(game, key_event(KEY_U))
    check(not game.base_build_open, "building does not close on its key")
    # movement on the arrows
    for pair in [["move_up", KEY_UP], ["move_down", KEY_DOWN], ["move_left", KEY_LEFT], ["move_right", KEY_RIGHT]]:
        InputBindings.apply(InputBindings.rebind(InputBindings.current(), pair[0], "k:%d" % pair[1])["map"])
    check(InputMap.event_is_action(key_event(KEY_RIGHT), "move_right") and not InputMap.event_is_action(key_event(KEY_D), "move_right"), "movement does not follow the new keys")
    Input.parse_input_event(key_event(KEY_RIGHT))
    Input.flush_buffered_events()
    await frames(2)
    var v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
    check(v.x > 0.5, "the survivor does not walk on the new keys: " + str(v))
    Input.parse_input_event(key_event(KEY_RIGHT, false))
    Input.flush_buffered_events()
    await frames(2)

    # hints and the HUD print the bound key
    InputBindings.apply(InputBindings.rebind(InputBindings.current(), "interact", "k:%d" % KEY_SPACE)["map"])
    game._on_bindings_changed()
    check(InputBindings.fill("{interact} — подобрать") == "Пробел — подобрать", "hints print the old key")
    var badge_text = game.hud_interaction_key_badge.get_node_or_null("InteractionKeyText")
    check(badge_text != null and badge_text.visible and badge_text.text == "SPC" and not game.hud_interaction_key_label.visible, "the prompt badge shows the old key")
    check(game._home_defense_hint_text().begins_with("Пробел"), "the home hint prints the old key")
    check(game.hud_quick_slots[1]["button"].get_node("QuickKeyText").visible and game.hud_quick_slots[1]["button"].get_node("QuickKeyText").text == "M5", "the moved quick slot still shows its digit")
    check(not game.hud_quick_slots[0]["button"].get_node("QuickKeyText").visible and game.hud_quick_slots[0]["label"].visible, "an unmoved slot lost its digit")
    check(game._quick_slot_keys_text().find("Мышь 5") >= 0, "the inventory note prints the old slot keys")
    var sub = str(game._hud_survival_objective().get("sub", ""))
    check(sub.find("M —") < 0 and sub.find("M →") < 0, "the objective still says M: " + sub)
    for text in [game.field_hints.KIND_HINTS["runner"]]:
        check(InputBindings.fill(text).find("{") < 0, "a hint token left unfilled")

    # --- the menu: capture, swap message, reserved, reset, persistence -------
    game._open_menu("pause")
    await process_frame
    var menu = game.pause_menu
    menu._open_controls()
    await process_frame
    check(menu._settings_box.visible and menu._tab == "keys" and menu._key_buttons.size() == ids.size(), "Controls does not open the key list")
    menu._key_buttons["crouch"].emit_signal("pressed")
    check(menu._capturing == "crouch", "clicking a key does not wait for a new one")
    var esc = key_event(KEY_ESCAPE)
    menu._input(esc)
    check(menu._capturing == "" and InputBindings.current()["crouch"] == ["k:%d" % KEY_C], "Esc does not cancel the capture")
    check(menu._settings_box.visible, "Esc during the capture left the settings")
    menu._key_buttons["crouch"].emit_signal("pressed")
    var rmb = InputEventMouseButton.new()
    rmb.button_index = MOUSE_BUTTON_RIGHT
    rmb.pressed = true
    menu._input(rmb)
    check(menu._capturing == "crouch" and menu._key_status.text.find("игра держит") >= 0, "a reserved button was taken or not explained")
    menu._input(key_event(KEY_R))
    check(InputBindings.current()["crouch"] == ["k:%d" % KEY_R] and InputBindings.current()["reload"] == ["k:%d" % KEY_C], "the menu did not swap the keys")
    check(menu._key_status.text.find("Перезарядка") >= 0, "the swap is not explained: " + menu._key_status.text)
    check(menu._key_buttons["reload"].text == "C" and menu._key_buttons["crouch"].text == "R", "the key list shows stale keys")
    # survives a restart
    var saved = PauseMenu.load_bindings()
    check(saved["crouch"] == ["k:%d" % KEY_R] and saved["interact"] == ["k:%d" % KEY_SPACE] and saved["quick_slot_2"] == ["m:%d" % MOUSE_BUTTON_XBUTTON2], "bindings not saved")
    InputBindings.apply(InputBindings.defaults())
    InputBindings.apply(PauseMenu.load_bindings())
    check(InputBindings.current()["crouch"] == ["k:%d" % KEY_R], "bindings not restored")
    # settings and bindings live in one file and do not erase each other
    var s = PauseMenu.load_settings()
    s["music"] = 0.35
    PauseMenu.save_settings(s)
    check(PauseMenu.load_bindings()["crouch"] == ["k:%d" % KEY_R], "saving settings erased the keys")
    PauseMenu.save_bindings(InputBindings.current())
    check(abs(float(PauseMenu.load_settings()["music"]) - 0.35) < 0.001, "saving keys erased the settings")
    # reset
    menu._reset_bindings()
    check(InputBindings.current() == defaults and PauseMenu.load_bindings() == defaults, "reset does not restore the defaults")
    check(game.hud_interaction_key_label.visible, "reset did not bring the drawn E back")

    # --- screen settings -------------------------------------------------------
    menu._select_tab("display")
    await process_frame
    for k in ["fullscreen", "resolution", "max_fps", "ui_scale"]:
        check(menu._cycles.has(k), "no screen option: " + k)
    for k in ["vsync", "pixel_perfect"]:
        check(menu._checks.has(k), "no screen switch: " + k)
    while float(menu._cycles["ui_scale"]["values"][menu._cycles["ui_scale"]["index"]]) != 0.8:
        menu._step_cycle("ui_scale", 1)
    check(abs(game.hud_ui_scale - 0.8) < 0.001 and abs(float(PauseMenu.load_settings()["ui_scale"]) - 0.8) < 0.001, "HUD scale not applied or not saved")
    while int(menu._cycles["max_fps"]["values"][menu._cycles["max_fps"]["index"]]) != 60:
        menu._step_cycle("max_fps", 1)
    check(Engine.max_fps == 60 and int(PauseMenu.load_settings()["max_fps"]) == 60, "FPS cap not applied or not saved")
    menu._checks["pixel_perfect"].button_pressed = true
    check(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_INTEGER and bool(PauseMenu.load_settings()["pixel_perfect"]), "crisp pixels not applied")
    menu._checks["pixel_perfect"].button_pressed = false
    check(root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "crisp pixels do not switch off")
    menu._step_cycle("resolution", 1)
    check(str(PauseMenu.load_settings()["resolution"]) != "1280x720", "window size not saved")
    # the other tabs kept their values through all that
    check(abs(float(PauseMenu.load_settings()["music"]) - 0.35) < 0.001, "the display tab reset the sound")
    menu._select_tab("sound")
    await process_frame
    check(abs(menu._sliders["music"].value - 35.0) < 0.5, "the sound tab does not show the saved volume")
    menu._select_tab("game")
    await process_frame
    check(menu._checks.has("camera_shake") and menu._checks.has("hud_autohide") and menu._checks.has("field_hints"), "game switches missing")
    Engine.max_fps = 0

    # a broken settings file falls back to safe values
    var bad = PauseMenu.sanitize_settings({"master": "loud", "max_fps": 7, "ui_scale": 3.0, "resolution": "99x99", "vsync": "yes", "fullscreen": 1})
    check(bad["master"] == 0.85 and bad["max_fps"] == 0 and bad["ui_scale"] == 1.0 and bad["resolution"] == "1280x720" and bad["vsync"] == true and bad["fullscreen"] == true, "a broken settings file is not cleaned: " + str(bad))

    # --- HUD scale: no block overlaps another or leaves the screen ---------------
    var names = ["VitalsPanel", "EnvironmentPanel", "StealthPanel", "QuickShell", "WeaponPanel"]
    for sc in PauseMenu.UI_SCALES:
        game._apply_ui_scale(sc)
        await process_frame
        var rects = {}
        for n in names + ["InteractionPrompt", "SurvivalFeedback", "RigQuickPockets"]:
            var p = game.hud_world_root.get_node(n)
            var rect = p.get_global_rect()
            rects[n] = rect
            check(rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= 640.0 and rect.end.y <= 360.0, "%s leaves the screen at %d%%: %s" % [n, int(sc * 100), rect])
            check(abs(rect.size.x - p.size.x * sc) < 0.01, "%s not scaled at %d%%" % [n, int(sc * 100)])
        for i in range(names.size()):
            for j in range(i + 1, names.size()):
                check(not rects[names[i]].intersects(rects[names[j]]), "%s overlaps %s at %d%%" % [names[i], names[j], int(sc * 100)])
        check(not rects["RigQuickPockets"].intersects(rects["QuickShell"]), "the rig strip overlaps the bar at %d%%" % int(sc * 100))
        # each corner block stays in its corner
        check(abs(rects["VitalsPanel"].position.x - 8.0) < 0.01 and abs(rects["VitalsPanel"].position.y - 8.0) < 0.01, "vitals left the corner")
        check(abs(rects["EnvironmentPanel"].end.x - 632.0) < 0.01, "the environment block left the corner")
        check(abs(rects["WeaponPanel"].end.y - 352.0) < 0.01, "the weapon block left the bottom")
    # the feedback line grows from the middle when its text changes
    game._apply_ui_scale(1.1)
    game._set_survival_feedback("Очень длинное сообщение для проверки, что панель остаётся по центру экрана", 3.0)
    game._update_hud()
    await process_frame
    var fb = game.hud_world_root.get_node("SurvivalFeedback").get_global_rect()
    # dev75: its centre is the middle of the gap between the side panels
    check(abs((fb.position.x + fb.size.x * 0.5) - game.FEEDBACK_CENTER_X) < 1.0, "the feedback line drifted off centre: " + str(fb))
    game._apply_ui_scale(1.0)

    menu.close()
    await process_frame
    check(not game.get_tree().paused, "closing the menu left the world paused")

    print("SETTINGS dev69: ", checks, " checks, ", failures, " failures")
    quit(1 if failures else 0)
