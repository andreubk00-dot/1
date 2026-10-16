extends CanvasLayer
# Title screen, pause menu and settings for OSTATOK.
#
# mode "title": shown when the game is launched as the main scene - continue
#               the saved run, start a new one, settings, quit.
# mode "pause": Esc during play - resume, settings, save, save and quit.
# The game tree is paused while the menu is up; this layer keeps running.

signal closed

const SETTINGS_PATH = "user://settings.cfg"
const BG = Color(0.035, 0.045, 0.045, 0.96)
const EDGE = Color(0.30, 0.33, 0.29)
const INK = Color(0.86, 0.82, 0.68)
const DIM = Color(0.58, 0.62, 0.58)
const ACCENT = Color(0.86, 0.66, 0.34)

var game = null
var mode = "pause"
var has_save = false
var _root = null
var _main_box = null
var _settings_box = null
var _confirm_box = null
var _sliders = {}
var _checks = {}
var _cycles = {}
var _tab = "sound"
var _tab_buttons = {}
var _key_buttons = {}
var _capturing = ""
var _key_status: Label = null
var _settings_content: VBoxContainer = null

const InputBindings = preload("res://world/input_bindings.gd")

const RESOLUTIONS = ["960x540", "1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const FPS_CAPS = [30, 60, 90, 120, 144, 0]
const UI_SCALES = [0.8, 0.9, 1.0, 1.1]
const DEFAULTS = {
    "master": 0.85, "music": 0.7, "sfx": 0.9, "ambience": 0.8,
    "fullscreen": false, "resolution": "1280x720", "pixel_perfect": false,
    "vsync": true, "max_fps": 0, "ui_scale": 1.0,
    "camera_shake": true, "hud_autohide": true, "objective_pointer": true,
}
static var _applied_window = ""


static func load_settings() -> Dictionary:
    var out = DEFAULTS.duplicate()
    var cfg = ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        for k in out.keys():
            out[k] = cfg.get_value("settings", k, out[k])
    return sanitize_settings(out)


static func sanitize_settings(raw: Dictionary) -> Dictionary:
    var out = DEFAULTS.duplicate()
    for k in ["master", "music", "sfx", "ambience"]:
        var v = raw.get(k, out[k])
        out[k] = clamp(float(v), 0.0, 1.0) if (v is float or v is int) else out[k]
    for k in ["fullscreen", "pixel_perfect", "vsync", "camera_shake", "hud_autohide", "objective_pointer"]:
        var v = raw.get(k, out[k])
        out[k] = bool(v) if (v is bool or v is int) else out[k]
    var res = str(raw.get("resolution", out["resolution"]))
    out["resolution"] = res if res in RESOLUTIONS else DEFAULTS["resolution"]
    var fps = raw.get("max_fps", 0)
    out["max_fps"] = int(fps) if ((fps is int or fps is float) and int(fps) in FPS_CAPS) else 0
    var ui = raw.get("ui_scale", 1.0)
    out["ui_scale"] = 1.0
    if ui is float or ui is int:
        for opt in UI_SCALES:
            if abs(float(ui) - opt) < 0.001:
                out["ui_scale"] = opt
    return out


static func save_settings(s: Dictionary) -> void:
    var cfg = ConfigFile.new()
    cfg.load(SETTINGS_PATH)    # keep the other sections (key bindings)
    for k in s.keys():
        cfg.set_value("settings", k, s[k])
    cfg.save(SETTINGS_PATH)


static func load_bindings() -> Dictionary:
    var cfg = ConfigFile.new()
    var raw = {}
    if cfg.load(SETTINGS_PATH) == OK and cfg.has_section("bindings"):
        for action in cfg.get_section_keys("bindings"):
            raw[action] = cfg.get_value("bindings", action, [])
    return InputBindings.sanitize(raw)


static func save_bindings(map: Dictionary) -> void:
    var cfg = ConfigFile.new()
    cfg.load(SETTINGS_PATH)
    if cfg.has_section("bindings"):
        cfg.erase_section("bindings")
    var clean = InputBindings.sanitize(map)
    for action in clean.keys():
        cfg.set_value("bindings", action, clean[action])
    cfg.save(SETTINGS_PATH)


static func ensure_buses() -> void:
    # UI has its own bus so menu clicks stay clear while the world is muffled
    for name in ["Music", "SFX", "Ambience", "UI"]:
        if AudioServer.get_bus_index(name) < 0:
            AudioServer.add_bus()
            var i = AudioServer.bus_count - 1
            AudioServer.set_bus_name(i, name)
            AudioServer.set_bus_send(i, "Master")


static func resolution_size(res: String) -> Vector2i:
    var parts = res.split("x")
    if parts.size() != 2:
        return Vector2i(1280, 720)
    return Vector2i(int(parts[0]), int(parts[1]))


static func resolutions_for_screen() -> Array:
    # window sizes that fit the screen this window is on; 960x540 always does
    var out = []
    var usable = Vector2i(100000, 100000)
    if DisplayServer.get_name() != "headless":
        usable = DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
    for r in RESOLUTIONS:
        var sz = resolution_size(r)
        if r == RESOLUTIONS[0] or (sz.x <= usable.x and sz.y <= usable.y):
            out.append(r)
    return out


static func apply_settings(raw: Dictionary) -> void:
    var s = sanitize_settings(raw)
    ensure_buses()
    var vol = {"Master": s["master"], "Music": s["music"], "SFX": s["sfx"], "Ambience": s["ambience"], "UI": s["sfx"]}
    for bus in vol.keys():
        var i = AudioServer.get_bus_index(bus)
        if i >= 0:
            var v = clamp(float(vol[bus]), 0.0, 1.0)
            AudioServer.set_bus_volume_db(i, linear_to_db(max(v, 0.0001)))
            AudioServer.set_bus_mute(i, v <= 0.001)
    Engine.max_fps = int(s["max_fps"])
    var tree = Engine.get_main_loop() as SceneTree
    if tree != null and tree.root != null:
        tree.root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if bool(s["pixel_perfect"]) else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
    if DisplayServer.get_name() == "headless":
        return
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(s["vsync"]) else DisplayServer.VSYNC_DISABLED)
    var want = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(s["fullscreen"]) else DisplayServer.WINDOW_MODE_WINDOWED
    var was = DisplayServer.window_get_mode()
    var key = "%s|%s" % [want, s["resolution"]]
    var windowed_now = was == DisplayServer.WINDOW_MODE_WINDOWED or was == DisplayServer.WINDOW_MODE_MAXIMIZED
    if want == DisplayServer.WINDOW_MODE_FULLSCREEN and was != want and was != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
        DisplayServer.window_set_mode(want)
    elif want == DisplayServer.WINDOW_MODE_WINDOWED and not windowed_now:
        DisplayServer.window_set_mode(want)
    if want == DisplayServer.WINDOW_MODE_WINDOWED and _applied_window != key:
        if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED:
            DisplayServer.window_set_mode(want)
        # size and centre the window only when the choice changes, so a
        # window the player dragged is not snapped back on every slider move
        var screen = DisplayServer.window_get_current_screen()
        var usable = DisplayServer.screen_get_usable_rect(screen)
        var size = resolution_size(str(s["resolution"]))
        size = Vector2i(min(size.x, usable.size.x), min(size.y, usable.size.y))
        DisplayServer.window_set_size(size)
        DisplayServer.window_set_position(usable.position + (usable.size - size) / 2)
    _applied_window = key


func _init():
    layer = 80
    process_mode = Node.PROCESS_MODE_ALWAYS


func open(menu_mode: String) -> void:
    mode = menu_mode
    has_save = game != null and game.has_method("_menu_has_save") and game._menu_has_save()
    if _root == null:
        _build()
    _rebuild_main()
    # the title covers the world more than the pause does
    _root.get_child(0).color = Color(0.0, 0.0, 0.0, 0.86 if mode == "title" else 0.62)
    _show(_main_box)
    visible = true
    get_tree().paused = true


func close() -> void:
    _end_capture("")
    visible = false
    get_tree().paused = false
    emit_signal("closed")


func _unhandled_input(event):
    if not visible:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        if _settings_box.visible or _confirm_box.visible:
            _back_from_settings()
        elif mode == "pause":
            close()


# --- layout ---------------------------------------------------------------
func _panel_style() -> StyleBoxFlat:
    var st = StyleBoxFlat.new()
    st.bg_color = BG
    st.border_color = EDGE
    st.set_border_width_all(2)
    st.set_content_margin_all(14)
    return st


func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
    var st = StyleBoxFlat.new()
    st.bg_color = fill
    st.border_color = edge
    st.set_border_width_all(1)
    st.set_content_margin_all(4)
    return st


func _px_icon(w: int, h: int, fill: Color, edge: Color, mark: bool = false) -> ImageTexture:
    # small square pixel icons for the slider knob and the check boxes
    var img = Image.create(w, h, false, Image.FORMAT_RGBA8)
    img.fill(edge)
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            img.set_pixel(x, y, fill)
    if mark:
        for i in range(w - 4):
            var x = 2 + i
            var y = h - 3 - abs(i - 2) if i >= 2 else h - 3 - (2 - i)
            img.set_pixel(x, clamp(y, 2, h - 3), ACCENT)
            img.set_pixel(x, clamp(y - 1, 2, h - 3), ACCENT)
    return ImageTexture.create_from_image(img)


func _style_slider(sl: HSlider) -> void:
    var track = StyleBoxFlat.new()
    track.bg_color = Color(0.06, 0.07, 0.07)
    track.border_color = Color(0.22, 0.24, 0.21)
    track.set_border_width_all(1)
    track.content_margin_top = 3
    track.content_margin_bottom = 3
    var filled = StyleBoxFlat.new()
    filled.bg_color = Color(0.46, 0.38, 0.22)
    filled.content_margin_top = 3
    filled.content_margin_bottom = 3
    sl.add_theme_stylebox_override("slider", track)
    sl.add_theme_stylebox_override("grabber_area", filled)
    sl.add_theme_stylebox_override("grabber_area_highlight", filled)
    var knob = _px_icon(6, 12, Color(0.80, 0.74, 0.58), Color(0.12, 0.11, 0.09))
    sl.add_theme_icon_override("grabber", knob)
    sl.add_theme_icon_override("grabber_highlight", _px_icon(6, 12, ACCENT, Color(0.12, 0.11, 0.09)))


func _style_check(cb: CheckBox) -> void:
    var off = _px_icon(10, 10, Color(0.06, 0.07, 0.07), Color(0.32, 0.34, 0.30))
    var on = _px_icon(10, 10, Color(0.06, 0.07, 0.07), Color(0.32, 0.34, 0.30), true)
    cb.add_theme_icon_override("unchecked", off)
    cb.add_theme_icon_override("checked", on)
    cb.add_theme_color_override("font_color", INK)
    cb.add_theme_color_override("font_hover_color", ACCENT)
    cb.add_theme_color_override("font_pressed_color", INK)


func _label(text: String, size: int, col: Color) -> Label:
    var l = Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", col)
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    return l


func _button(text: String, cb: Callable) -> Button:
    var b = Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(150, 20)
    b.add_theme_font_size_override("font_size", 8)
    b.add_theme_color_override("font_color", INK)
    b.add_theme_color_override("font_hover_color", ACCENT)
    b.add_theme_stylebox_override("normal", _button_style(Color(0.07, 0.08, 0.08), Color(0.22, 0.24, 0.21)))
    b.add_theme_stylebox_override("hover", _button_style(Color(0.10, 0.11, 0.10), ACCENT))
    b.add_theme_stylebox_override("pressed", _button_style(Color(0.13, 0.13, 0.11), ACCENT))
    b.add_theme_stylebox_override("focus", _button_style(Color(0.10, 0.11, 0.10), ACCENT))
    b.pressed.connect(_click)
    b.pressed.connect(cb)
    return b


var _click_player: AudioStreamPlayer = null

func _click() -> void:
    if _click_player == null:
        _click_player = AudioStreamPlayer.new()
        _click_player.bus = "UI"
        _click_player.volume_db = -17.0
        if ResourceLoader.exists("res://audio/ui/ui_confirm.wav"):
            _click_player.stream = load("res://audio/ui/ui_confirm.wav")
        add_child(_click_player)
    if _click_player.stream != null:
        _click_player.pitch_scale = randf_range(0.97, 1.03)
        _click_player.play()


func _build() -> void:
    _root = Control.new()
    _root.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_root)
    var shade = ColorRect.new()
    shade.color = Color(0.0, 0.0, 0.0, 0.62)
    shade.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.add_child(shade)
    _main_box = _box()
    _settings_box = _box()
    _confirm_box = _box()
    _build_settings()


func _box() -> PanelContainer:
    var center = CenterContainer.new()
    center.set_anchors_preset(Control.PRESET_FULL_RECT)
    _root.add_child(center)
    var p = PanelContainer.new()
    p.add_theme_stylebox_override("panel", _panel_style())
    center.add_child(p)
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 6)
    p.add_child(v)
    p.set_meta("vbox", v)
    p.set_meta("center", center)
    return p


func _clear(p: PanelContainer) -> VBoxContainer:
    var v: VBoxContainer = p.get_meta("vbox")
    for c in v.get_children():
        c.queue_free()
    return v


func _show(p: PanelContainer) -> void:
    for b in [_main_box, _settings_box, _confirm_box]:
        b.get_meta("center").visible = b == p
        b.visible = b == p


func _rebuild_main() -> void:
    var v = _clear(_main_box)
    v.add_child(_label("ОСТАТОК", 16, INK))
    v.add_child(_label("выживание после конца" if mode == "title" else "пауза", 6, DIM))
    var gap = Control.new()
    gap.custom_minimum_size = Vector2(0, 4)
    v.add_child(gap)
    if mode == "title":
        if has_save:
            v.add_child(_button("ПРОДОЛЖИТЬ", close))
        v.add_child(_button("НОВАЯ ИГРА", _ask_new_game if has_save else _start_new_game))
        v.add_child(_button("НАСТРОЙКИ", _open_settings))
        v.add_child(_button("УПРАВЛЕНИЕ", _open_controls))
        v.add_child(_button("ВЫХОД", _quit))
    else:
        v.add_child(_button("ПРОДОЛЖИТЬ", close))
        v.add_child(_button("НАСТРОЙКИ", _open_settings))
        v.add_child(_button("УПРАВЛЕНИЕ", _open_controls))
        v.add_child(_button("СОХРАНИТЬ", _save))
        v.add_child(_button("СОХРАНИТЬ И ВЫЙТИ", _save_and_quit))
    v.add_child(_label("Esc — назад" if mode == "pause" else "", 5, DIM))


func _build_settings() -> void:
    var v = _clear(_settings_box)
    v.add_child(_label("НАСТРОЙКИ", 12, INK))
    var tabs = HBoxContainer.new()
    tabs.alignment = BoxContainer.ALIGNMENT_CENTER
    tabs.add_theme_constant_override("separation", 4)
    _tab_buttons.clear()
    for pair in [["sound", "ЗВУК"], ["display", "ЭКРАН"], ["game", "ИГРА"], ["keys", "КЛАВИШИ"]]:
        var id = pair[0]
        var b = _button(pair[1], func(): _select_tab(id))
        b.custom_minimum_size = Vector2(70, 16)
        b.add_theme_font_size_override("font_size", 7)
        tabs.add_child(b)
        _tab_buttons[id] = b
    v.add_child(tabs)
    _settings_content = VBoxContainer.new()
    _settings_content.custom_minimum_size = Vector2(320, 200)
    _settings_content.add_theme_constant_override("separation", 5)
    v.add_child(_settings_content)
    v.add_child(_button("НАЗАД", _back_from_settings))
    _select_tab(_tab)


func _select_tab(id: String) -> void:
    _end_capture("")
    _tab = id
    for k in _tab_buttons.keys():
        var on = k == id
        _tab_buttons[k].add_theme_color_override("font_color", ACCENT if on else DIM)
        _tab_buttons[k].add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.11, 0.08) if on else Color(0.07, 0.08, 0.08), ACCENT if on else Color(0.22, 0.24, 0.21)))
    for c in _settings_content.get_children():
        _settings_content.remove_child(c)
        c.queue_free()
    _sliders.clear()
    _checks.clear()
    _cycles.clear()
    _key_buttons.clear()
    _key_status = null
    var s = load_settings()
    match id:
        "sound":
            _build_sound_tab(s)
        "display":
            _build_display_tab(s)
        "game":
            _build_game_tab(s)
        "keys":
            _build_keys_tab()


func _row_label(text: String, width: float = 120.0) -> Label:
    var l = Label.new()
    l.text = text
    l.custom_minimum_size = Vector2(width, 0)
    l.add_theme_font_size_override("font_size", 7)
    l.add_theme_color_override("font_color", INK)
    return l


func _build_sound_tab(s: Dictionary) -> void:
    for pair in [["master", "Общая громкость"], ["music", "Музыка"], ["sfx", "Эффекты"], ["ambience", "Окружение"]]:
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        row.add_child(_row_label(pair[1], 110))
        var sl = HSlider.new()
        sl.min_value = 0.0
        sl.max_value = 100.0
        sl.step = 5.0
        sl.custom_minimum_size = Vector2(140, 12)
        sl.value = float(s.get(pair[0], 0.8)) * 100.0
        _style_slider(sl)
        var val = Label.new()
        val.custom_minimum_size = Vector2(28, 0)
        val.add_theme_font_size_override("font_size", 7)
        val.add_theme_color_override("font_color", DIM)
        val.text = "%d%%" % int(sl.value)
        sl.value_changed.connect(func(x):
            val.text = "%d%%" % int(x)
            _apply_from_ui()
        )
        row.add_child(sl)
        row.add_child(val)
        _settings_content.add_child(row)
        _sliders[pair[0]] = sl


func _cycle(key: String, text: String, values: Array, labels: Array, current) -> void:
    var row = HBoxContainer.new()
    row.add_theme_constant_override("separation", 4)
    row.add_child(_row_label(text, 150))
    var idx = max(0, values.find(current))
    var val = Label.new()
    val.custom_minimum_size = Vector2(92, 0)
    val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    val.add_theme_font_size_override("font_size", 7)
    val.add_theme_color_override("font_color", ACCENT)
    var state = {"key": key, "values": values, "labels": labels, "index": idx, "label": val}
    _cycles[key] = state
    var prev = _button("<", func(): _step_cycle(key, -1))
    var next = _button(">", func(): _step_cycle(key, 1))
    for b in [prev, next]:
        b.custom_minimum_size = Vector2(14, 13)
        b.add_theme_font_size_override("font_size", 7)
    row.add_child(prev)
    row.add_child(val)
    row.add_child(next)
    _settings_content.add_child(row)
    val.text = str(labels[idx])


func _step_cycle(key: String, dir: int) -> void:
    var st = _cycles.get(key)
    if st == null:
        return
    st["index"] = posmod(int(st["index"]) + dir, st["values"].size())
    st["label"].text = str(st["labels"][st["index"]])
    _apply_from_ui()


func _check(key: String, text: String, on: bool) -> CheckBox:
    var cb = CheckBox.new()
    cb.text = text
    cb.add_theme_font_size_override("font_size", 7)
    cb.button_pressed = on
    _style_check(cb)
    cb.toggled.connect(func(_on): _apply_from_ui())
    _settings_content.add_child(cb)
    _checks[key] = cb
    return cb


func _build_display_tab(s: Dictionary) -> void:
    _cycle("fullscreen", "Режим", [false, true], ["Окно", "Полный экран"], bool(s["fullscreen"]))
    var res = resolutions_for_screen()
    if not str(s["resolution"]) in res:
        res.append(str(s["resolution"]))
    var res_labels = []
    for r in res:
        res_labels.append(str(r).replace("x", " × "))
    _cycle("resolution", "Размер окна", res, res_labels, str(s["resolution"]))
    var fps_labels = []
    for f in FPS_CAPS:
        fps_labels.append("без ограничения" if f == 0 else "%d" % f)
    _cycle("max_fps", "Ограничение кадров", FPS_CAPS, fps_labels, int(s["max_fps"]))
    var ui_labels = []
    for u in UI_SCALES:
        ui_labels.append("%d%%" % int(round(u * 100.0)))
    _cycle("ui_scale", "Масштаб HUD", UI_SCALES, ui_labels, float(s["ui_scale"]))
    _check("vsync", "Вертикальная синхронизация", bool(s["vsync"]))
    _check("pixel_perfect", "Чёткие пиксели (целый масштаб, с рамкой)", bool(s["pixel_perfect"]))
    _settings_content.add_child(_note("Размер окна действует в оконном режиме. Чёткие пиксели убирают\nразмытие на нестандартных экранах ценой чёрной рамки по краям."))


func _build_game_tab(s: Dictionary) -> void:
    _check("camera_shake", "Тряска камеры при ударах", bool(s["camera_shake"]))
    _check("hud_autohide", "Прятать панели HUD в покое", bool(s["hud_autohide"]))
    _check("objective_pointer", "Стрелка к текущей цели у персонажа", bool(s["objective_pointer"]))
    if game != null and game.get("field_hints") != null:
        var hints = CheckBox.new()
        hints.text = "Подсказки для новичка"
        hints.add_theme_font_size_override("font_size", 7)
        hints.button_pressed = bool(game.field_hints.enabled)
        _style_check(hints)
        hints.toggled.connect(func(on): game.field_hints.enabled = on)
        _settings_content.add_child(hints)
        _checks["field_hints"] = hints


func _note(text: String) -> Label:
    var l = Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", 6)
    l.add_theme_color_override("font_color", DIM)
    return l


func _build_keys_tab() -> void:
    var grid = GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 6)
    grid.add_theme_constant_override("v_separation", 1)
    var ids = InputBindings.action_ids()
    var half = int(ceil(ids.size() / 2.0))
    for i in range(half):
        for j in [i, i + half]:
            if j < ids.size():
                _key_row(grid, str(ids[j]))
            else:
                grid.add_child(Control.new())
                grid.add_child(Control.new())
    _settings_content.add_child(grid)
    _settings_content.add_child(_note("Esc — пауза / назад • ЛКМ — выстрел / удар • ПКМ — использовать предмет"))
    _key_status = _note("Нажмите на клавишу, чтобы назначить другую.")
    _key_status.add_theme_color_override("font_color", INK)
    _settings_content.add_child(_key_status)
    var reset = _button("СБРОСИТЬ КЛАВИШИ", _reset_bindings)
    reset.custom_minimum_size = Vector2(120, 12)
    reset.add_theme_font_size_override("font_size", 6)
    _compact(reset)
    _settings_content.add_child(reset)


func _key_row(grid: GridContainer, action: String) -> void:
    var l = Label.new()
    l.text = InputBindings.action_label(action)
    l.custom_minimum_size = Vector2(96, 0)
    l.add_theme_font_size_override("font_size", 6)
    l.add_theme_color_override("font_color", INK)
    grid.add_child(l)
    var b = _button(InputBindings.keys(action), func(): _begin_capture(action))
    b.custom_minimum_size = Vector2(58, 10)
    b.add_theme_font_size_override("font_size", 6)
    _compact(b)
    grid.add_child(b)
    _key_buttons[action] = b


func _compact(b: Button) -> void:
    # thin one-pixel padding so the full key list fits the 360 px screen
    for state in ["normal", "hover", "pressed", "focus"]:
        var st = (b.get_theme_stylebox(state) as StyleBoxFlat).duplicate()
        st.set_content_margin_all(1)
        b.add_theme_stylebox_override(state, st)


func _refresh_key_buttons() -> void:
    for action in _key_buttons.keys():
        _key_buttons[action].text = InputBindings.keys(action)
        _key_buttons[action].add_theme_color_override("font_color", ACCENT if action == _capturing else INK)
    if _capturing != "" and _key_buttons.has(_capturing):
        _key_buttons[_capturing].text = "..."


func _set_key_status(text: String) -> void:
    if _key_status != null and text != "":
        _key_status.text = text


func _begin_capture(action: String) -> void:
    _capturing = action
    _refresh_key_buttons()
    _set_key_status("«%s»: нажмите клавишу или кнопку мыши. Esc — отмена." % InputBindings.action_label(action))


func _end_capture(message: String) -> void:
    _capturing = ""
    _refresh_key_buttons()
    _set_key_status(message)


func _input(event):
    if not visible or _capturing == "":
        return
    var key = event is InputEventKey and event.pressed and not event.echo
    var mouse = event is InputEventMouseButton and event.pressed
    if not (key or mouse):
        return
    get_viewport().set_input_as_handled()
    if key and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
        _end_capture("Отменено.")
        return
    if mouse and event.button_index == MOUSE_BUTTON_LEFT:
        _end_capture("Отменено.")
        return
    try_bind(_capturing, InputBindings.code_for_event(event))


func try_bind(action: String, code: String) -> bool:
    var res = InputBindings.rebind(InputBindings.current(), action, code)
    if not res["ok"]:
        _set_key_status("Эту клавишу игра держит за собой: Esc, F10, ЛКМ, ПКМ и колесо мыши." if res["reason"] == "reserved" else "Эту клавишу назначить нельзя.")
        return false
    InputBindings.apply(res["map"])
    save_bindings(InputBindings.current())
    var msg = "«%s» — %s." % [InputBindings.action_label(action), InputBindings.keys(action)]
    if res["swapped"] != "":
        msg += " «%s» теперь — %s." % [InputBindings.action_label(res["swapped"]), InputBindings.keys(res["swapped"])]
    _end_capture(msg)
    _bindings_changed()
    return true


func _reset_bindings() -> void:
    InputBindings.apply(InputBindings.defaults())
    save_bindings(InputBindings.current())
    _end_capture("Клавиши сброшены.")
    _bindings_changed()


func _bindings_changed() -> void:
    if game != null and game.has_method("_on_bindings_changed"):
        game._on_bindings_changed()


func _back_from_settings() -> void:
    _end_capture("")
    _show(_main_box)


func _apply_from_ui() -> void:
    var s = load_settings()
    for k in _sliders.keys():
        s[k] = _sliders[k].value / 100.0
    for k in _checks.keys():
        if k != "field_hints":
            s[k] = _checks[k].button_pressed
    for k in _cycles.keys():
        var st = _cycles[k]
        s[k] = st["values"][st["index"]]
    s = sanitize_settings(s)
    save_settings(s)
    apply_settings(s)
    if game != null:
        game.set_meta("settings", s)
        if game.has_method("_apply_ui_scale"):
            game._apply_ui_scale(float(s["ui_scale"]))


# --- actions --------------------------------------------------------------
func _open_settings(tab: String = "sound") -> void:
    _tab = tab
    _build_settings()
    _show(_settings_box)


func _open_controls() -> void:
    _open_settings("keys")


func _ask_new_game() -> void:
    var v = _clear(_confirm_box)
    v.add_child(_label("НАЧАТЬ ЗАНОВО?", 11, INK))
    v.add_child(_label("Текущее сохранение будет удалено.", 7, DIM))
    v.add_child(_button("ДА, НОВАЯ ИГРА", _start_new_game))
    v.add_child(_button("НЕТ", func(): _show(_main_box)))
    _show(_confirm_box)


func _start_new_game() -> void:
    if game != null and game.has_method("_menu_new_game"):
        game._menu_new_game()


func _save() -> void:
    if game != null:
        game._save_state()
    var v: VBoxContainer = _main_box.get_meta("vbox")
    var last = v.get_child(v.get_child_count() - 1)
    if last is Label:
        last.text = "Сохранено."


func _save_and_quit() -> void:
    if game != null:
        game._save_state()
    _quit()


func _quit() -> void:
    get_tree().quit()
