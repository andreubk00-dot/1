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
var _fullscreen = null
var _shake = null


static func load_settings() -> Dictionary:
    var out = {"master": 0.85, "music": 0.7, "sfx": 0.9, "ambience": 0.8, "fullscreen": false, "camera_shake": true}
    var cfg = ConfigFile.new()
    if cfg.load(SETTINGS_PATH) == OK:
        for k in out.keys():
            out[k] = cfg.get_value("settings", k, out[k])
    return out


static func save_settings(s: Dictionary) -> void:
    var cfg = ConfigFile.new()
    for k in s.keys():
        cfg.set_value("settings", k, s[k])
    cfg.save(SETTINGS_PATH)


static func ensure_buses() -> void:
    for name in ["Music", "SFX", "Ambience"]:
        if AudioServer.get_bus_index(name) < 0:
            AudioServer.add_bus()
            var i = AudioServer.bus_count - 1
            AudioServer.set_bus_name(i, name)
            AudioServer.set_bus_send(i, "Master")


static func apply_settings(s: Dictionary) -> void:
    ensure_buses()
    var vol = {"Master": s.get("master", 0.85), "Music": s.get("music", 0.7), "SFX": s.get("sfx", 0.9), "Ambience": s.get("ambience", 0.8)}
    for bus in vol.keys():
        var i = AudioServer.get_bus_index(bus)
        if i >= 0:
            var v = clamp(float(vol[bus]), 0.0, 1.0)
            AudioServer.set_bus_volume_db(i, linear_to_db(max(v, 0.0001)))
            AudioServer.set_bus_mute(i, v <= 0.001)
    if DisplayServer.get_name() != "headless":
        var want = DisplayServer.WINDOW_MODE_FULLSCREEN if bool(s.get("fullscreen", false)) else DisplayServer.WINDOW_MODE_WINDOWED
        if DisplayServer.window_get_mode() != want:
            DisplayServer.window_set_mode(want)


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
    visible = false
    get_tree().paused = false
    emit_signal("closed")


func _unhandled_input(event):
    if not visible:
        return
    if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
        get_viewport().set_input_as_handled()
        if _settings_box.visible or _confirm_box.visible:
            _show(_main_box)
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
    b.pressed.connect(cb)
    return b


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
    var s = load_settings()
    for pair in [["master", "Общая громкость"], ["music", "Музыка"], ["sfx", "Эффекты"], ["ambience", "Окружение"]]:
        var row = HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var l = Label.new()
        l.text = pair[1]
        l.custom_minimum_size = Vector2(96, 0)
        l.add_theme_font_size_override("font_size", 7)
        l.add_theme_color_override("font_color", INK)
        row.add_child(l)
        var sl = HSlider.new()
        sl.min_value = 0.0
        sl.max_value = 100.0
        sl.step = 5.0
        sl.custom_minimum_size = Vector2(110, 12)
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
        v.add_child(row)
        _sliders[pair[0]] = sl
    _fullscreen = CheckBox.new()
    _fullscreen.text = "Полный экран"
    _fullscreen.add_theme_font_size_override("font_size", 7)
    _fullscreen.button_pressed = bool(s.get("fullscreen", false))
    _style_check(_fullscreen)
    _fullscreen.toggled.connect(func(_on): _apply_from_ui())
    v.add_child(_fullscreen)
    _shake = CheckBox.new()
    _shake.text = "Тряска камеры при ударах"
    _shake.add_theme_font_size_override("font_size", 7)
    _shake.button_pressed = bool(s.get("camera_shake", true))
    _style_check(_shake)
    _shake.toggled.connect(func(_on): _apply_from_ui())
    v.add_child(_shake)
    if game != null and game.get("field_hints") != null:
        var hints = CheckBox.new()
        hints.text = "Подсказки для новичка"
        hints.add_theme_font_size_override("font_size", 7)
        hints.button_pressed = bool(game.field_hints.enabled)
        _style_check(hints)
        hints.toggled.connect(func(on): game.field_hints.enabled = on)
        v.add_child(hints)
    v.add_child(_button("НАЗАД", func(): _show(_main_box)))


func _apply_from_ui() -> void:
    var s = {}
    for k in _sliders.keys():
        s[k] = _sliders[k].value / 100.0
    s["fullscreen"] = _fullscreen.button_pressed
    s["camera_shake"] = _shake.button_pressed
    save_settings(s)
    apply_settings(s)
    if game != null:
        game.set_meta("settings", s)


# --- actions --------------------------------------------------------------
func _open_settings() -> void:
    _show(_settings_box)


const CONTROLS = [
    ["W A S D", "движение"], ["Shift", "бег"], ["C", "присесть / красться"],
    ["ЛКМ", "выстрел / удар"], ["R", "перезарядка"], ["V", "оттолкнуть"],
    ["E", "взаимодействие"], ["H", "быстрая перевязка"], ["F", "фонарь"],
    ["1 – 6", "быстрые слоты"], ["7, 8", "карманы разгрузки"],
    ["Tab / I", "инвентарь"], ["ПКМ", "использовать предмет"], ["Q", "выбросить предмет"],
    ["M", "карта региона"], ["B", "строительство (X — разобрать)"],
    ["F5", "быстрое сохранение"], ["Esc", "пауза / назад"],
]


func _open_controls() -> void:
    var v = _clear(_confirm_box)
    v.add_child(_label("УПРАВЛЕНИЕ", 11, INK))
    var grid = GridContainer.new()
    grid.columns = 4
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 1)
    for pair in CONTROLS:
        var k = Label.new()
        k.text = pair[0]
        k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        k.custom_minimum_size = Vector2(40, 0)
        k.add_theme_font_size_override("font_size", 6)
        k.add_theme_color_override("font_color", ACCENT)
        grid.add_child(k)
        var a = Label.new()
        a.text = pair[1]
        a.custom_minimum_size = Vector2(104, 0)
        a.add_theme_font_size_override("font_size", 6)
        a.add_theme_color_override("font_color", INK)
        grid.add_child(a)
    v.add_child(grid)
    v.add_child(_button("НАЗАД", func(): _show(_main_box)))
    _show(_confirm_box)


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
