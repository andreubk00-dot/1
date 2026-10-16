extends CanvasLayer
# dev68: a quiet moment that asks for a decision (the broadcast console on the
# «Вектор»). Same look as the ending screen: the world dims, the text rises,
# a few plain buttons. The game waits while it is open.

const INK = Color(0.88, 0.85, 0.72)
const DIM = Color(0.60, 0.62, 0.56)
const GOLD = Color(0.86, 0.66, 0.34)

var _shade: ColorRect = null
var _box: VBoxContainer = null
var _t = 0.0
var buttons = []          # for the tests


func _init():
    layer = 95
    name = "StoryDialog"
    process_mode = Node.PROCESS_MODE_ALWAYS


func open(kicker: String, title: String, body: String, options: Array) -> void:
    # options: [[label, Callable], ...]
    _shade = ColorRect.new()
    _shade.color = Color(0, 0, 0, 0)
    _shade.size = Vector2(640, 360)
    _shade.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(_shade)
    var center = CenterContainer.new()
    center.size = Vector2(640, 360)
    add_child(center)
    _box = VBoxContainer.new()
    _box.custom_minimum_size = Vector2(380, 0)
    _box.add_theme_constant_override("separation", 4)
    _box.modulate.a = 0.0
    center.add_child(_box)
    _box.add_child(_label(kicker, 6, DIM))
    _box.add_child(_label(title, 13, GOLD))
    var text = _label(body, 7, INK)
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.custom_minimum_size = Vector2(380, 0)
    _box.add_child(text)
    _box.add_child(_gap(6))
    var row = HBoxContainer.new()
    row.alignment = BoxContainer.ALIGNMENT_CENTER
    row.add_theme_constant_override("separation", 8)
    for opt in options:
        var action: Callable = opt[1]
        var b = Button.new()
        b.text = str(opt[0])
        b.custom_minimum_size = Vector2(118, 22)
        b.add_theme_font_size_override("font_size", 7)
        b.pressed.connect(func():
            close()
            action.call())
        row.add_child(b)
        buttons.append(b)
    _box.add_child(row)
    get_tree().paused = true


func close() -> void:
    get_tree().paused = false
    queue_free()


func _process(delta):
    _t += delta
    if _shade != null:
        _shade.color.a = clamp(_t / 0.8, 0.0, 0.82)
    if _box != null:
        _box.modulate.a = clamp((_t - 0.4) / 0.8, 0.0, 1.0)


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
