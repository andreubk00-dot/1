extends CanvasLayer
# A readable conversation card in the lower safe area, separate from transient
# action toasts. Long quest text is scrollable instead of clipped to two lines.
var game

static func show_line(g,speaker:String,role:String,line:String):
    var old = g.get_node_or_null("NpcChat")
    if old != null:
        g.remove_child(old)
        old.queue_free()
    var chat = new()
    chat.name = "NpcChat"
    chat.layer = 32
    chat.game = g
    g.add_child(chat)
    var panel = PanelContainer.new()
    panel.position = Vector2(168,214)
    panel.size = Vector2(304,82)
    panel.custom_minimum_size = panel.size
    panel.add_theme_stylebox_override("panel",g._hud_panel_style(true))
    chat.add_child(panel)
    var margin = MarginContainer.new()
    for side in ["left","right","top","bottom"]:
        margin.add_theme_constant_override("margin_"+side,7)
    panel.add_child(margin)
    var column = VBoxContainer.new()
    margin.add_child(column)
    var title = Label.new()
    title.text = speaker+" · "+role
    title.add_theme_font_size_override("font_size",7)
    title.add_theme_color_override("font_color",Color("d5bc7e"))
    column.add_child(title)
    var scroll = ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(286,43)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    column.add_child(scroll)
    var text = Label.new()
    text.text = line
    text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    text.add_theme_font_size_override("font_size",7)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(text)
    var close = Button.new()
    close.text = "Закончить разговор"
    close.add_theme_font_size_override("font_size",6)
    close.pressed.connect(chat.queue_free)
    column.add_child(close)
    chat.set_meta("speaker",speaker)
    chat.set_meta("line",line)

func _process(_delta):
    if game == null or game.inventory_open or game.region_map_open:
        queue_free()

func _unhandled_input(event):
    if event.is_action_pressed("ui_cancel"):
        get_viewport().set_input_as_handled()
        queue_free()
