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
const InputBindings = preload("res://world/input_bindings.gd")

const KIND_HINTS = {
    "runner": "Рывковый: быстрый и худой. Не убегайте по прямой — встретьте его толчком ({shove}).",
    "brute": "Тяжёлый: держит много попаданий и бьёт сильно. Держите дистанцию.",
    "screamer": "Крикун: его вопль зовёт всех вокруг. Убейте его раньше, чем он закричит.",
    "spitter": "Плевун: плюётся издалека. Уходите с места, куда он целится.",
    "carrier": "Носитель: после смерти оставляет облако заразы. Не добивайте вплотную.",
    "armored": "Бронированный: пули вязнут в бронежилете. Стреляйте в спину или бейте холодным оружием.",
}

# dev84: "first steps" - five short things a new survivor does in the start
# yard, shown as the current goal (the gold arrow points at the thing). Any
# order; walking off from the start area ends it, so it never holds anyone.
const STEPS = [
    {"id": "pickup", "title": "ПОДОБРАТЬ ВЕЩЬ", "sub": "{interact} — взять вещь с земли", "target": "world_item"},
    {"id": "drink", "title": "ПОПИТЬ ВОДЫ", "sub": "{inventory}, ПКМ по бутылке", "target": ""},
    {"id": "search", "title": "ОБЫСКАТЬ ЯЩИК", "sub": "{interact} у ящика, «Забрать всё»", "target": "container"},
    {"id": "fight", "title": "ОТБИТЬСЯ ОТ ЗАРАЖЁННОГО", "sub": "ЛКМ — огонь, {shove} — толчок", "target": "infected"},
    {"id": "map", "title": "ОТКРЫТЬ КАРТУ", "sub": "{region_map} — путь к Лазарету", "target": ""},
]
const STEPS_AREA = 2            # sectors from the start; beyond, the steps are over
const STEP_TARGET_RANGE = 640.0

var game = null
var enabled = false
var seen = {}
# every hint shown, to read again (Esc -> Советы)
var texts = {}
var steps_active = false
var steps_done = {}
var _thirst_seen = -1.0
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
    return {"enabled": enabled, "seen": seen.duplicate(), "texts": texts.duplicate(),
        "steps_active": steps_active, "steps_done": steps_done.duplicate()}


func load_state(raw) -> void:
    if typeof(raw) != TYPE_DICTIONARY:
        return
    enabled = bool(raw.get("enabled", false))
    seen = {}
    var raw_seen = raw.get("seen", {})
    if typeof(raw_seen) == TYPE_DICTIONARY:
        for k in raw_seen:
            seen[str(k)] = true
    texts = {}
    var raw_texts = raw.get("texts", {})
    if typeof(raw_texts) == TYPE_DICTIONARY:
        for k in raw_texts:
            texts[str(k)] = str(raw_texts[k])
    steps_active = bool(raw.get("steps_active", false))
    steps_done = {}
    var raw_done = raw.get("steps_done", {})
    if typeof(raw_done) == TYPE_DICTIONARY:
        for k in raw_done:
            steps_done[str(k)] = true


# --- first steps -------------------------------------------------------------
func step_done(id: String) -> void:
    if not steps_active or steps_done.has(id):
        return
    var step = {}
    for st in STEPS:
        if st["id"] == id:
            step = st
    if step.is_empty():
        return
    steps_done[id] = true
    if game != null and game.has_method("_set_survival_feedback"):
        game._set_survival_feedback("ГОТОВО: %s  •  %d из %d" % [step["title"], steps_done.size(), STEPS.size()], 2.2)
    if game != null and game.has_method("_play_ui_sfx"):
        game._play_ui_sfx("open")
    if steps_done.size() >= STEPS.size():
        finish_steps()


func finish_steps() -> void:
    if not steps_active:
        return
    steps_active = false
    hint("steps_done", "Основы освоены. Дальше — Лазарет, поселение выживших: золотая стрелка у персонажа ведёт туда, {region_map} — карта. Любой совет можно перечитать: Esc → Советы.")


func current_step() -> Dictionary:
    if not steps_active:
        return {}
    for st in STEPS:
        if not steps_done.has(st["id"]):
            return {"id": st["id"], "title": st["title"],
                "sub": "Шаг %d/%d • %s" % [steps_done.size() + 1, STEPS.size(), InputBindings.fill(st["sub"])],
                "target": st["target"]}
    return {}


func step_target():
    # where the gold arrow points for the current step (null: no arrow)
    var st = current_step()
    if st.is_empty() or game == null or game.player == null:
        return null
    var kind = str(st["target"])
    if kind == "":
        return null
    var group = "infected" if kind == "infected" else "interactable"
    var best = null
    var bd = STEP_TARGET_RANGE
    for n in get_tree().get_nodes_in_group(group):
        if not is_instance_valid(n) or not n.is_visible_in_tree():
            continue
        if group == "interactable" and str(n.get_meta("interaction_type", "")) != kind:
            continue
        if kind == "container" and game.has_method("_container_locked") and game._container_locked(str(n.get_meta("container_key", ""))):
            continue
        var d = n.global_position.distance_to(game.player.global_position)
        if d < bd:
            bd = d
            best = n
    return best.global_position if best != null else null


func _check_steps() -> void:
    if not steps_active or game.player_death_time > 0.0:
        return
    # drinking shows as thirst going up (a bottle, a flask, a pump)
    var th = float(game.thirst)
    if _thirst_seen >= 0.0 and th > _thirst_seen + 3.0:
        step_done("drink")
    _thirst_seen = th
    # walked off from the start area: the basics are his already
    var c = game._world_to_chunk(game.player.global_position)
    if max(abs(c.x), abs(c.y)) > STEPS_AREA:
        finish_steps()


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
        texts[entry["id"]] = InputBindings.fill(str(entry["text"]))
    _title.text = entry["title"]
    _title.add_theme_color_override("font_color", RED if entry["warn"] else GOLD)
    _text.text = InputBindings.fill(str(entry["text"]))
    (_panel.get_theme_stylebox("panel") as StyleBoxFlat).border_color = RED if entry["warn"] else GOLD
    _panel.set_meta("warn", entry["warn"])
    _panel.set_meta("id", entry["id"])
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
    # dev75: a card never sits over the map, the inventory or a menu - it waits
    # underneath and comes back after; and a warning whose danger has passed
    # (bandaged, drunk, a new survivor after a death) goes at once
    if _panel != null and _panel.visible and _menu_open():
        _panel.modulate.a = 0.0
        return
    if _panel != null and _panel.visible and bool(_panel.get_meta("warn", false)) and not _danger(str(_panel.get_meta("id", ""))):
        _time_left = min(_time_left, 0.35)
    while not _queue.is_empty() and bool(_queue[0]["warn"]) and not _danger(str(_queue[0]["id"])):
        _queue.pop_front()
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
    _check_steps()
    if enabled:
        _check_hints()


func _menu_open() -> bool:
    # dev85: and every other window - a card used to sit over the title of the
    # contract board, the trader, the workbench
    for flag in ["inventory_open", "region_map_open", "trader_open", "contract_open", "crafting_open", "base_build_open", "rest_open", "mod_panel_open"]:
        if bool(game.get(flag)):
            return true
    return get_tree().paused


func _danger(id: String) -> bool:
    if game.player_death_time > 0.0:
        return false
    match id:
        "thirst":
            return float(game.thirst) < 15.0
        "hunger":
            return float(game.hunger) < 10.0
        "health":
            return float(game.health) < 25.0
        "bleeding":
            return bool(game.bleeding)
        "fracture":
            return game.has_method("_broken_limb") and game._broken_limb() != ""
        "cold":
            return float(game.body_temperature) < 35.2
    return true


func _check_warnings() -> void:
    if game.player_death_time > 0.0:
        return
    if float(game.thirst) < 15.0:
        warn("thirst", "ОБЕЗВОЖИВАНИЕ", "Вы умираете от жажды. Выпейте воду немедленно ({inventory} → ПКМ по воде).")
    if float(game.hunger) < 10.0:
        warn("hunger", "ИСТОЩЕНИЕ", "Организм на пределе. Срочно съешьте что-нибудь.")
    if float(game.health) < 25.0:
        warn("health", "КРИТИЧЕСКОЕ СОСТОЯНИЕ", "Уйдите от заражённых и перевяжитесь ({bandage}). Отдых восстановит силы.")
    if bool(game.bleeding):
        warn("bleeding", "КРОВОТЕЧЕНИЕ", "Вы теряете кровь. {bandage} — быстрая перевязка.")
    if game.has_method("_broken_limb") and game._broken_limb() != "":
        warn("fracture", "ПЕРЕЛОМ", "Наложите шину ({inventory} → шина) или соберите её в поле: дрова или металлолом + изолента или ткань.")
    if float(game.body_temperature) < 35.2:
        warn("cold", "ПЕРЕОХЛАЖДЕНИЕ", "Зайдите в здание, разведите огонь, смените мокрую одежду.")


func _check_hints() -> void:
    if _age > 1.5:
        hint("move", "{move_up} {move_left} {move_down} {move_right} — идти, {sprint} — бег, {crouch} — красться. Все клавиши: Esc → Управление.")
        # the goal comes straight after the controls: it is what a new
        # survivor needs next, before the first door or the first infected
        hint("goal", "Текущая цель — справа вверху; золотая стрелка у персонажа показывает, куда идти. {region_map} — карта.")
        hint("vitals", "Слева вверху — ваше состояние: здоровье, силы, голод, жажда, тепло. Если что-то станет опасным, здесь появится красное предупреждение.")
    if not seen.has("move"):
        return
    var near = game._nearest_interactable() if game.has_method("_nearest_interactable") else null
    if near != null:
        hint("interact", "{interact} — подобрать, обыскать, открыть дверь. Подсказка появляется у предмета.")
    var items = game.inventory_entries.size()
    if _items_seen >= 0 and items > _items_seen:
        hint("inventory", "{inventory} — инвентарь. ПКМ по предмету — использовать: пить, есть, перевязать.")
    _items_seen = items
    for e in get_tree().get_nodes_in_group("infected"):
        if is_instance_valid(e) and e.global_position.distance_to(game.player.global_position) < 260.0:
            hint("infected", "Заражённый! ЛКМ — выстрел или удар, {shove} — оттолкнуть, {reload} — перезарядка. Шум и свет зовут других.")
            var kind = str(e.get_meta("infected_kind", "normal"))
            if KIND_HINTS.has(kind):
                hint("kind_" + kind, KIND_HINTS[kind])
    if float(game.health) < 75.0 or bool(game.bleeding):
        hint("hurt", "Ранены. {bandage} — быстрая перевязка; кровотечение нельзя оставлять.")
    var hour = int(float(game.world_minutes) / 60.0) % 24
    if hour >= 20 or hour < 6:
        hint("dark", "Темно. {flashlight} — фонарь: светит далеко, но и вас видно издалека.")
    for m in get_tree().get_nodes_in_group("marauders"):
        if is_instance_valid(m) and m.global_position.distance_to(game.player.global_position) < 300.0:
            hint("marauders", "Мародёры: люди с оружием. Одни стреляют сразу, другие предупреждают — не целься в них, и разойдётесь. С тел можно снять оружие и патроны.")
            break
    for pump in get_tree().get_nodes_in_group("water_pumps"):
        if is_instance_valid(pump) and pump.global_position.distance_to(game.player.global_position) < 140.0:
            hint("pump", "Колонка: {interact} — напиться вдоволь и наполнить флягу или канистру. Её отметят на карте.")
            break
    if float(game.thirst) < 45.0:
        hint("thirst", "Хочется пить: {inventory} → ПКМ по воде. Воду ищите на кухнях и в магазинах.")
    if float(game.hunger) < 45.0:
        hint("food", "Голод: еда бывает в шкафах, холодильниках и у торговцев.")
    if float(game.body_temperature) < 36.0:
        hint("cold", "Холодно. Внутри зданий теплее; {base_build} — строительство: костёр.")
    if float(game.fatigue) > 60.0:
        hint("rest", "Усталость растёт. Отдыхайте в укрытии — у кровати или спального места.")
