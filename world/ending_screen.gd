extends CanvasLayer
# The end of the crisis season: the screen fades to black and the region's
# fate is read out - the outcome, each settlement, what the survivor did.
# The world goes on afterwards (sandbox), or the player returns to the menu.

const FactionCatalog = preload("res://world/faction_catalog.gd")
const RegionalEndgame = preload("res://world/regional_endgame.gd")
const INK = Color(0.88, 0.85, 0.72)
const DIM = Color(0.60, 0.62, 0.56)
const GOLD = Color(0.86, 0.66, 0.34)
const CATEGORY_COLOR = {
    "secure": Color(0.56, 0.74, 0.50), "strained": Color(0.86, 0.74, 0.40),
    "scarred": Color(0.86, 0.52, 0.34), "critical": Color(0.84, 0.32, 0.28),
}

var game = null
var _shade: ColorRect = null
var _box: VBoxContainer = null
var _t = 0.0


func _init():
    layer = 85
    name = "EndingScreen"
    process_mode = Node.PROCESS_MODE_ALWAYS


func show_outcome(outcome: Dictionary, definition: Dictionary, stats: Dictionary) -> void:
    _shade = ColorRect.new()
    _shade.color = Color(0, 0, 0, 0)
    _shade.size = Vector2(640, 360)
    _shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_shade)
    var center = CenterContainer.new()
    center.size = Vector2(640, 360)
    add_child(center)
    _box = VBoxContainer.new()
    _box.custom_minimum_size = Vector2(400, 0)
    _box.add_theme_constant_override("separation", 3)
    _box.modulate.a = 0.0
    center.add_child(_box)
    _box.add_child(_label("ИТОГ РЕГИОНА • ДЕНЬ %d" % int(stats.get("day", 1)), 7, DIM))
    _box.add_child(_label(str(definition.get("title", "СЕЗОН ЗАВЕРШЁН")), 16, GOLD))
    var text = _label(str(definition.get("text", "")), 7, INK)
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.custom_minimum_size = Vector2(400, 0)
    _box.add_child(text)
    _box.add_child(_gap(6))
    var rows = outcome.get("factions", {})
    if typeof(rows) == TYPE_DICTIONARY:
        for faction_id in FactionCatalog.ids():
            var row = rows.get(str(faction_id), {})
            if typeof(row) != TYPE_DICTIONARY:
                continue
            var category = str(row.get("category", "critical"))
            var line = HBoxContainer.new()
            line.alignment = BoxContainer.ALIGNMENT_CENTER
            var name_label = _label(str(FactionCatalog.faction(str(faction_id)).get("name", faction_id)), 7, INK)
            name_label.custom_minimum_size = Vector2(170, 0)
            name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            line.add_child(name_label)
            line.add_child(_label("  —  ", 7, DIM))
            var state_label = _label(RegionalEndgame.faction_outcome_label(category), 7, CATEGORY_COLOR.get(category, INK))
            state_label.custom_minimum_size = Vector2(170, 0)
            state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
            line.add_child(state_label)
            _box.add_child(line)
    _box.add_child(_gap(6))
    _box.add_child(_label("Прожито дней: %d   •   Изучено секторов: %d   •   Заражённых упокоено: %d" % [
        int(stats.get("day", 1)), int(stats.get("sectors", 0)), int(stats.get("kills", 0))], 6, DIM))
    _box.add_child(_gap(8))
    var buttons = HBoxContainer.new()
    buttons.alignment = BoxContainer.ALIGNMENT_CENTER
    buttons.add_theme_constant_override("separation", 10)
    buttons.add_child(_button("ПРОДОЛЖИТЬ ВЫЖИВАТЬ", _continue))
    buttons.add_child(_button("В ГЛАВНОЕ МЕНЮ", _to_menu))
    _box.add_child(buttons)
    get_tree().paused = true


func _process(delta):
    _t += delta
    if _shade != null:
        _shade.color.a = clamp(_t / 2.0, 0.0, 0.95)
    if _box != null:
        _box.modulate.a = clamp((_t - 1.4) / 1.6, 0.0, 1.0)


func _label(text: String, size: int, color: Color) -> Label:
    var l = Label.new()
    l.text = text
    l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    l.add_theme_font_size_override("font_size", size)
    l.add_theme_color_override("font_color", color)
    return l


func _gap(h: int) -> Control:
    var c = Control.new()
    c.custom_minimum_size = Vector2(0, h)
    return c


func _button(text: String, action: Callable) -> Button:
    var b = Button.new()
    b.text = text
    b.custom_minimum_size = Vector2(150, 22)
    b.add_theme_font_size_override("font_size", 7)
    b.pressed.connect(action)
    return b


func _continue() -> void:
    get_tree().paused = false
    queue_free()


func _to_menu() -> void:
    get_tree().paused = false
    if game != null and game.has_method("_save_state"):
        game._save_state()
    queue_free()
    if game != null and game.has_method("_open_menu"):
        game._open_menu("title")
