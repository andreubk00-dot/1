extends CanvasLayer
# First-run hints and life-threat warnings, one short card at the top centre.
# Hints run only in a game started from the menu (saved with it); warnings
# about dying of thirst, hunger or wounds are always on.

const HINT_TIME = 8.5
const WARN_TIME = 5.0
const WARN_REPEAT = 40.0
const INK = Color(0.88, 0.85, 0.72)
const GOLD = Color(0.86, 0.66, 0.34)
const RED = Color(0.92, 0.36, 0.28)

const KIND_HINTS = {
    "runner": "Рывковый: быстрый и худой. Не убегайте по прямой — встретьте его толчком (V).",
    "brute": "Тяжёлый: держит много попаданий и бьёт сильно. Держите дистанцию.",
    "screamer": "Крикун: его вопль зовёт всех вокруг. Убейте его раньше, чем он закричит.",
    "spitter": "Плевун: плюётся издалека. Уходите с места, куда он целится.",
    "carrier": "Носитель: после смерти оставляет облако заразы. Не добивайте вплотную.",
    "armored": "Бронированный: пули вязнут в бронежилете. Стреляйте в спину или бейте холодным оружием.",
}

var game = null
var enabled = false
var seen = {}
var _queue = []
var _panel: PanelContainer = null
var _title: Label = null
var _text: Label = null
var _time_left = 0.0
var _age = 0.0
var _check = 0.0
var _warn_next = {}
var _items_seen = -1


func _init():
    layer = 31
    name = "FieldHints"


func state() -> Dictionary:
    return {"enabled": enabled, "seen": seen.duplicate()}


func load_state(raw) -> void:
    if typeof(raw) != TYPE_DICTIONARY:
        return
    enabled = bool(raw.get("enabled", false))
    seen = {}
    var raw_seen = raw.get("seen", {})
    if typeof(raw_seen) == TYPE_DICTIONARY:
        for k in raw_seen:
            seen[str(k)] = true


func _build() -> void:
    _panel = PanelContainer.new()
    var st = StyleBoxFlat.new()
    st.bg_color = Color(0.05, 0.055, 0.05, 0.92)
    st.border_color = GOLD
    st.set_border_width_all(1)
    st.content_margin_left = 8
    st.content_margin_right = 8
    st.content_margin_top = 4
    st.content_margin_bottom = 5
    _panel.add_theme_stylebox_override("panel", st)
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var v = VBoxContainer.new()
    v.add_theme_constant_override("separation", 1)
    v.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(v)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 6)
    _title.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(_title)
    _text = Label.new()
    _text.add_theme_font_size_override("font_size", 6)
    _text.add_theme_color_override("font_color", INK)
    _text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _text.custom_minimum_size = Vector2(236, 0)
    _text.mouse_filter = Control.MOUSE_FILTER_IGNORE
    v.add_child(_text)
    add_child(_panel)
    _panel.visible = false


func hint(id: String, text: String) -> void:
    # a first-run hint: shown once per game, never while another one is up
    if not enabled or seen.has(id):
        return
    for q in _queue:
        if q["id"] == id:
            return
    _queue.append({"id": id, "title": "СОВЕТ", "text": text, "warn": false})


func warn(id: String, title: String, text: String) -> void:
    var now = Time.get_ticks_msec() / 1000.0
    if now < float(_warn_next.get(id, 0.0)):
        return
    _warn_next[id] = now + WARN_REPEAT
    # a warning jumps the queue and replaces a hint on screen
    _queue.push_front({"id": id, "title": title, "text": text, "warn": true})
    if _panel != null and _panel.visible and not bool(_panel.get_meta("warn", false)):
        _time_left = 0.0


func _show(entry: Dictionary) -> void:
    if _panel == null:
        _build()
    if not bool(entry["warn"]):
        seen[entry["id"]] = true
    _title.text = entry["title"]
    _title.add_theme_color_override("font_color", RED if entry["warn"] else GOLD)
    _text.text = entry["text"]
    (_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = RED if entry["warn"] else GOLD
    _panel.set_meta("warn", entry["warn"])
    _panel.reset_size()
    _panel.position = Vector2(round(320.0 - _panel.size.x * 0.5), 6)
    _panel.visible = true
    _time_left = WARN_TIME if entry["warn"] else HINT_TIME
    if game != null and game.has_method("_play_ui_sfx"):
        game._play_ui_sfx("open")


func update(delta: float) -> void:
    if game == null or game.player == null:
        return
    _age += delta
    if _panel != null and _panel.visible:
        _time_left -= delta
        var a = clamp(min(_time_left, HINT_TIME - _time_left + 0.35) / 0.35, 0.0, 1.0)
        _panel.modulate.a = a
        if _time_left <= 0.0:
            _panel.visible = false
    elif not _queue.is_empty() and not _menu_open():
        _show(_queue.pop_front())
    _check -= delta
    if _check > 0.0:
        return
    _check = 0.5
    _check_warnings()
    if enabled:
        _check_hints()


func _menu_open() -> bool:
    return bool(game.inventory_open) or bool(game.region_map_open) or bool(game.trader_open) or get_tree().paused


func _check_warnings() -> void:
    if float(game.thirst) < 15.0:
        warn("thirst", "ОБЕЗВОЖИВАНИЕ", "Вы умираете от жажды. Выпейте воду немедленно (Tab → ПКМ по воде).")
    if float(game.hunger) < 10.0:
        warn("hunger", "ИСТОЩЕНИЕ", "Организм на пределе. Срочно съешьте что-нибудь.")
    if float(game.health) < 25.0:
        warn("health", "КРИТИЧЕСКОЕ СОСТОЯНИЕ", "Уйдите от заражённых и перевяжитесь (H). Отдых восстановит силы.")
    if bool(game.bleeding):
        warn("bleeding", "КРОВОТЕЧЕНИЕ", "Вы теряете кровь. H — быстрая перевязка.")
    if float(game.body_temperature) < 35.2:
        warn("cold", "ПЕРЕОХЛАЖДЕНИЕ", "Зайдите в здание, разведите огонь, смените мокрую одежду.")


func _check_hints() -> void:
    if _age > 1.5:
        hint("move", "W A S D — идти, Shift — бег, C — красться. Все клавиши: Esc → Управление.")
    if not seen.has("move"):
        return
    if _age > 12.0:
        hint("goal", "Текущая цель — справа вверху. M — карта: цель отмечена пунктиром.")
    var near = game._nearest_interactable() if game.has_method("_nearest_interactable") else null
    if near != null:
        hint("interact", "E — подобрать, обыскать, открыть дверь. Подсказка появляется у предмета.")
    var items = game.inventory_entries.size()
    if _items_seen >= 0 and items > _items_seen:
        hint("inventory", "Tab — инвентарь. ПКМ по предмету — использовать: пить, есть, перевязать.")
    _items_seen = items
    for e in get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and e.global_position.distance_to(game.player.global_position) < 260.0:
            hint("infected", "Заражённый! ЛКМ — выстрел или удар, V — оттолкнуть, R — перезарядка. Шум и свет зовут других.")
            var kind = str(e.get_meta("infected_kind", "normal"))
            if KIND_HINTS.has(kind):
                hint("kind_" + kind, KIND_HINTS[kind])
    if float(game.health) < 75.0 or bool(game.bleeding):
        hint("hurt", "Ранены. H — быстрая перевязка; кровотечение нельзя оставлять.")
    var hour = int(float(game.world_minutes) / 60.0) % 24
    if hour >= 20 or hour < 6:
        hint("dark", "Темно. F — фонарь: светит далеко, но и вас видно издалека.")
    for pump in get_tree().get_nodes_in_group("water_pumps"):
        if is_instance_valid(pump) and pump.global_position.distance_to(game.player.global_position) < 140.0:
            hint("pump", "Колонка: E — напиться вдоволь и наполнить флягу или канистру. Её отметят на карте.")
            break
    if float(game.thirst) < 45.0:
        hint("thirst", "Хочется пить: Tab → ПКМ по воде. Воду ищите на кухнях и в магазинах.")
    if float(game.hunger) < 45.0:
        hint("food", "Голод: еда бывает в шкафах, холодильниках и у торговцев.")
    if float(game.body_temperature) < 36.0:
        hint("cold", "Холодно. Внутри зданий теплее; B — строительство: костёр.")
    if float(game.fatigue) > 60.0:
        hint("rest", "Усталость растёт. Отдыхайте в укрытии — у кровати или спального места.")
