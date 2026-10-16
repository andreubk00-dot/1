extends RefCounted
# 1.38-dev69: every gameplay key lives in the InputMap and can be rebound in
# Settings → Keys. Bindings are stored in user://settings.cfg (section
# "bindings") as codes: "k:<physical keycode>" for a key, "m:<button>" for an
# extra mouse button. Physical keycodes keep the layout out of it - W is the
# same key on a Russian keyboard.
#
# Fixed, never rebound: Esc (pause / back), left mouse (shoot / swing), right
# mouse (use an item), F10 (developer panel in -dev builds).

const ACTIONS = [
    # [action, label, default codes]
    ["move_up", "Вперёд", ["k:87"]],
    ["move_down", "Назад", ["k:83"]],
    ["move_left", "Влево", ["k:65"]],
    ["move_right", "Вправо", ["k:68"]],
    ["sprint", "Бег", ["k:4194325"]],
    ["crouch", "Присесть / красться", ["k:67"]],
    ["interact", "Взаимодействие", ["k:69"]],
    ["reload", "Перезарядка", ["k:82"]],
    ["shove", "Оттолкнуть", ["k:86"]],
    ["bandage", "Быстрая перевязка", ["k:72"]],
    ["flashlight", "Фонарь", ["k:70"]],
    ["inventory", "Инвентарь", ["k:4194306", "k:73"]],
    ["drop_item", "Выбросить предмет", ["k:81"]],
    ["region_map", "Карта региона", ["k:77"]],
    ["base_build", "Строительство", ["k:66"]],
    ["dismantle", "Разобрать постройку", ["k:88"]],
    ["quick_slot_1", "Быстрый слот 1", ["k:49"]],
    ["quick_slot_2", "Быстрый слот 2", ["k:50"]],
    ["quick_slot_3", "Быстрый слот 3", ["k:51"]],
    ["quick_slot_4", "Быстрый слот 4", ["k:52"]],
    ["quick_slot_5", "Быстрый слот 5", ["k:53"]],
    ["quick_slot_6", "Быстрый слот 6", ["k:54"]],
    ["rig_quick_1", "Карман разгрузки 1", ["k:55"]],
    ["rig_quick_2", "Карман разгрузки 2", ["k:56"]],
    ["quick_save", "Быстрое сохранение", ["k:4194336"]],
]

# keys and buttons the game keeps for itself
const RESERVED = ["k:4194305", "k:4194341", "m:1", "m:2", "m:4", "m:5", "m:6", "m:7"]
# mouse buttons a player may bind: middle and the two side buttons
const MOUSE_OK = [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]

const PRETTY = {
    "Shift": "Shift", "Ctrl": "Ctrl", "Alt": "Alt", "Tab": "Tab", "Space": "Пробел",
    "Enter": "Enter", "Backspace": "Backspace", "CapsLock": "Caps Lock",
    "Up": "↑", "Down": "↓", "Left": "←", "Right": "→", "Meta": "Win",
    "QuoteLeft": "`", "Minus": "-", "Equal": "=", "BracketLeft": "[", "BracketRight": "]",
    "Semicolon": ";", "Apostrophe": "'", "Comma": ",", "Period": ".", "Slash": "/", "BackSlash": "\\",
    "Delete": "Del", "Insert": "Ins", "PageUp": "PgUp", "PageDown": "PgDn", "Kp Enter": "Num Enter",
}
const SHORT = {
    "Shift": "SHF", "Ctrl": "CTL", "Alt": "ALT", "Tab": "TAB", "Пробел": "SPC",
    "Enter": "ENT", "Backspace": "BSP", "Caps Lock": "CPS", "Win": "WIN",
    "СКМ": "СКМ", "Мышь 4": "M4", "Мышь 5": "M5",
}


static func action_ids() -> Array:
    var out = []
    for row in ACTIONS:
        out.append(str(row[0]))
    return out


static func action_label(action: String) -> String:
    for row in ACTIONS:
        if row[0] == action:
            return str(row[1])
    return action


static func defaults() -> Dictionary:
    var out = {}
    for row in ACTIONS:
        out[str(row[0])] = (row[2] as Array).duplicate()
    return out


static func is_valid_code(code: String) -> bool:
    if code in RESERVED:
        return false
    if code.begins_with("k:"):
        return code.substr(2).is_valid_int() and int(code.substr(2)) > 0
    if code.begins_with("m:"):
        return code.substr(2).is_valid_int() and int(code.substr(2)) in MOUSE_OK
    return false


static func sanitize(raw) -> Dictionary:
    # a broken or hand-edited file never leaves the game unplayable: bad codes
    # are dropped, a code is used by one action only (first in the list wins),
    # an action left with nothing gets its default back if that is free
    var base = defaults()
    var src = raw if typeof(raw) == TYPE_DICTIONARY else {}
    var out = {}
    var used = {}
    for action in action_ids():
        var codes = []
        var given = src.get(action, base[action])
        if typeof(given) == TYPE_STRING:
            given = [given]
        if typeof(given) != TYPE_ARRAY:
            given = base[action]
        for c in given:
            var code = str(c)
            if is_valid_code(code) and not used.has(code) and codes.size() < 2:
                codes.append(code)
                used[code] = action
        out[action] = codes
    for action in action_ids():
        if (out[action] as Array).is_empty():
            for code in base[action]:
                if not used.has(code):
                    out[action].append(code)
                    used[code] = action
    return out


static func event_from_code(code: String) -> InputEvent:
    if code.begins_with("k:"):
        var k = InputEventKey.new()
        k.physical_keycode = int(code.substr(2))
        return k
    if code.begins_with("m:"):
        var m = InputEventMouseButton.new()
        m.button_index = int(code.substr(2))
        return m
    return null


static func code_for_event(event: InputEvent) -> String:
    # what a pressed key or button would be stored as; "" if it cannot be bound
    if event is InputEventKey:
        var key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
        if key == 0:
            return ""
        return "k:%d" % int(key)
    if event is InputEventMouseButton:
        return "m:%d" % int(event.button_index)
    return ""


static func apply(map: Dictionary) -> void:
    var clean = sanitize(map)
    for action in action_ids():
        if not InputMap.has_action(action):
            InputMap.add_action(action)
        InputMap.action_erase_events(action)
        for code in clean[action]:
            var ev = event_from_code(code)
            if ev != null:
                InputMap.action_add_event(action, ev)


static func current() -> Dictionary:
    # the live map, read back from the InputMap
    var out = {}
    for action in action_ids():
        out[action] = codes_of(action)
    return out


static func owner_of(map: Dictionary, code: String) -> String:
    for action in action_ids():
        if code in map.get(action, []):
            return action
    return ""


static func rebind(map: Dictionary, action: String, code: String) -> Dictionary:
    # {"ok", "map", "swapped": the action that gave the key up, "reason"}
    var out = {"ok": false, "map": map.duplicate(true), "swapped": "", "reason": ""}
    if not action in action_ids():
        out["reason"] = "unknown"
        return out
    if code in RESERVED:
        out["reason"] = "reserved"
        return out
    if not is_valid_code(code):
        out["reason"] = "invalid"
        return out
    var m = sanitize(map)
    var old: Array = (m[action] as Array).duplicate()
    var other = owner_of(m, code)
    if other == action:
        m[action] = [code]
        out["ok"] = true
        out["map"] = m
        return out
    if other != "":
        # the two actions trade keys, so nothing is left unreachable
        var give = []
        for c in old:
            if c != code:
                give.append(c)
                break
        m[other] = give
        out["swapped"] = other
    m[action] = [code]
    out["ok"] = true
    out["map"] = m
    return out


static func code_label(code: String) -> String:
    if code.begins_with("m:"):
        match int(code.substr(2)):
            MOUSE_BUTTON_MIDDLE:
                return "СКМ"
            MOUSE_BUTTON_XBUTTON1:
                return "Мышь 4"
            MOUSE_BUTTON_XBUTTON2:
                return "Мышь 5"
        return "Мышь"
    if code.begins_with("k:"):
        var name = OS.get_keycode_string(int(code.substr(2)))
        if name == "":
            return "?"
        if name.begins_with("Kp "):
            return "Num " + name.substr(3)
        return str(PRETTY.get(name, name))
    return "—"


static func codes_of(action: String) -> Array:
    var out = []
    if InputMap.has_action(action):
        for ev in InputMap.action_get_events(action):
            var c = code_for_event(ev)
            if c != "":
                out.append(c)
    return out


static func key(action: String) -> String:
    # the first key of an action, as hints and prompts print it ("E", "Tab")
    var codes = codes_of(action)
    if codes.is_empty():
        return "—"
    return code_label(str(codes[0]))


static func keys(action: String) -> String:
    var codes = codes_of(action)
    if codes.is_empty():
        return "—"
    var names = []
    for c in codes:
        names.append(code_label(str(c)))
    return " / ".join(names)


static func short_key(action: String) -> String:
    # three characters at most, for the small key badge in the HUD
    var name = key(action)
    if SHORT.has(name):
        return str(SHORT[name])
    if name.begins_with("Num "):
        return ("N" + name.substr(4)).substr(0, 3).to_upper()
    return name.substr(0, 3).to_upper()


static func pressed(event: InputEvent, action: String) -> bool:
    # an action press; keys that arrive without a physical code (some remote
    # desktops, injected input) fall back to the logical key
    if event.is_action_pressed(action):
        return true
    if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == 0 and event.keycode != 0:
        return ("k:%d" % int(event.keycode)) in codes_of(action)
    return false


static func fill(text: String) -> String:
    # "{interact} — подобрать" -> "E — подобрать", with the player's keys
    if text.find("{") < 0:
        return text
    for action in action_ids():
        var token = "{%s}" % action
        if text.find(token) >= 0:
            text = text.replace(token, key(action))
    return text
