extends Control
# A schematic of known geography, not a navigation mesh or a second world model.
signal sector_selected(coord)
signal map_panned(offset)
signal zoom_changed
const ZOOMS = [18.0,28.0,44.0,64.0]
const INK = Color("34392f")
const PAPER = Color("b5b19a")
const FOG = Color("9c9884")
const BUILDING = Color("6e6a58")
const ROADS = {"city":Color("d9d3b9"),"rural":Color("c4b48e"),"woodland":Color("b7a780"),
    "military":Color("cfcbb8"),"industrial":Color("cfcbb8")}
const ZONES = {"central":Color("a3a08c"),"residential":Color("a7ab99"),
    "commercial":Color("b5ab88"),"industrial":Color("a39883"),
    "woodland":Color("869780"),"rural":Color("a6af8a"),"military":Color("aa9582")}
const SHORT_NAMES = {"old_center":"ЦЕНТР","panel_west":"ЖИЛМАССИВ",
    "market_east":"ТОРГОВЫЙ РЯД","south_residential":"ЮЖНЫЙ РАЙОН",
    "industrial_belt":"ПРОМЗОНА","rail_corridor":"Ж/Д КОРИДОР",
    "dacha_west":"ДАЧИ / СНТ","north_woodland":"ЛЕСОПОЛОСА",
    "military_northeast":"ВОЕННЫЙ ПЕРИМЕТР",
    "outer_residential":"ОКРАИНЫ","outer_industrial":"ПРОМ. ОКРАИНА",
    "outer_rural":"ПРИГОРОД","outer_woodland":"ЛЕСНАЯ ОКРАИНА"}
var zoom_index = 1
var center = Vector2i.ZERO
var data = {}
var cells = {}
var dragging = false
var drag_distance = Vector2.ZERO
var label_boxes = []

func _ready():
    clip_contents = true
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_default_cursor_shape = Control.CURSOR_CROSS

func step():
    return ZOOMS[zoom_index]
func project(coord):
    return size * 0.5 + (Vector2(coord)-Vector2(center)) * step()
func unproject(point):
    var value = (point-size*0.5)/step()+Vector2(center)
    return Vector2i(floor(value.x+0.5),floor(value.y+0.5))
func contains_sector(coord):
    return Rect2(Vector2.ZERO,size).has_point(project(coord))
func visible_radius():
    return Vector2i(ceil(size.x/step()/2.0)+1,ceil(size.y/step()/2.0)+1)
func configure(snapshot):
    data = snapshot
    center = snapshot.get("center",Vector2i.ZERO)
    cells = snapshot.get("cells",{})
    queue_redraw()
func set_zoom(index):
    var next = clampi(index,0,ZOOMS.size()-1)
    if next == zoom_index:
        return
    zoom_index = next
    zoom_changed.emit()
func _gui_input(event):
    if event is InputEventMouseButton:
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            set_zoom(zoom_index+1)
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            set_zoom(zoom_index-1)
        elif event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_MIDDLE:
            dragging = event.pressed
            drag_distance = Vector2.ZERO
        elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
            sector_selected.emit(unproject(event.position))
        accept_event()
    elif event is InputEventMouseMotion and dragging:
        if not (event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE)):
            dragging = false
            return
        drag_distance += event.relative
        var offset = Vector2i(int(drag_distance.x/step()),int(drag_distance.y/step()))
        if offset != Vector2i.ZERO:
            drag_distance -= Vector2(offset)*step()
            map_panned.emit(-offset)
        accept_event()
func _get_tooltip(at_position):
    return str(cells.get(unproject(at_position),{}).get("tooltip","Неизведанная территория"))
func _known(coord):
    return bool(cells.get(coord,{}).get("known",false))
func _text(pos,text,font_size=7,color=INK):
    draw_string(get_theme_default_font(),pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
func _label(pos,text,color=INK,important=false):
    var font = get_theme_default_font()
    var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x + 6.0
    var box = Rect2(pos-Vector2(3,8),Vector2(width,12))
    if not Rect2(Vector2(4,4),size-Vector2(8,8)).encloses(box):
        return false
    if not important:
        for used in label_boxes:
            if box.intersects(used):
                return false
    label_boxes.append(box.grow(2))
    draw_rect(box,Color(PAPER,0.90))
    _text(pos,text,7,color)
    return true
func _symbol(pos,kind,color):
    draw_circle(pos,5.0,PAPER)
    if kind == "home":
        draw_polyline(PackedVector2Array([pos+Vector2(-4,0),pos+Vector2(0,-4),pos+Vector2(4,0)]),color,1.5)
        draw_rect(Rect2(pos+Vector2(-3,0),Vector2(6,4)),color,false,1.3)
    elif kind == "danger":
        draw_polyline(PackedVector2Array([pos+Vector2(0,-5),pos+Vector2(5,4),pos+Vector2(-5,4),pos+Vector2(0,-5)]),color,1.3)
        _text(pos+Vector2(-1.5,3),"!",7,color)
    elif kind == "water":
        draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-5),pos+Vector2(3,1),pos+Vector2(0,4),pos+Vector2(-3,1)]),color)
    elif kind == "medical":
        draw_line(pos-Vector2(3,0),pos+Vector2(3,0),color,2)
        draw_line(pos-Vector2(0,3),pos+Vector2(0,3),color,2)
    elif kind == "target":
        draw_circle(pos,4,color,false,1.4)
        draw_line(pos-Vector2(6,0),pos+Vector2(6,0),color,1)
        draw_line(pos-Vector2(0,6),pos+Vector2(0,6),color,1)
    else:
        draw_rect(Rect2(pos-Vector2(3,3),Vector2(6,6)),color,false,1.4)
        if kind == "note":
            draw_line(pos-Vector2(2,0),pos+Vector2(2,0),color,1)
func _draw():
    draw_rect(Rect2(Vector2.ZERO,size),FOG)
    label_boxes.clear()
    var groups = {}
    var s = step()
    # unexplored land: faint diagonal hatching, never real geography
    for i in range(-int(size.y),int(size.x),9):
        draw_line(Vector2(i,size.y),Vector2(i+size.y,0),Color(INK,0.05),1.0)
    # pass 1 - blocks: the land between the streets, by zone
    for coord in cells:
        if not _known(coord):
            continue
        var cell = cells[coord]
        var zone = str(cell.get("zone","residential"))
        var district = str(cell.get("district",""))
        var p = project(coord)
        var rect = Rect2(p-Vector2.ONE*s*0.5,Vector2.ONE*s)
        draw_rect(rect,ZONES.get(zone,PAPER))
        if not groups.has(district):
            groups[district] = []
        groups[district].append(coord)
        var seed_value = absi(coord.x*92821+coord.y*68917)
        if zone == "woodland":
            for i in range(int(3 + s / 10.0)):
                var t = p + Vector2(float((seed_value+i*37)%97)/97.0-0.5,float((seed_value+i*53)%89)/89.0-0.5)*s*0.9
                draw_polyline(PackedVector2Array([t+Vector2(-2,2),t+Vector2(0,-2),t+Vector2(2,2)]),Color("687860"),0.8)
    # pass 2 - streets: every sector is built on one crossroads (the ground art)
    for coord in cells:
        if not _known(coord):
            continue
        var p = project(coord)
        var ground = str(cells[coord].get("ground","city"))
        var road_w = max(2.0,s * (0.25 if ground == "city" else 0.18))
        var col = ROADS.get(ground,ROADS["city"])
        for dir in [Vector2.RIGHT,Vector2.DOWN]:
            var half = Vector2(dir.x,dir.y) * s * 0.5
            var across = Vector2(dir.y,dir.x) * road_w * 0.5
            draw_colored_polygon(PackedVector2Array([p-half-across,p+half-across,p+half+across,p-half+across]),col)
    # curbs only where a street meets a block (drawn after every street fill)
    for coord in cells:
        if not _known(coord) or s < 24.0:
            continue
        var p = project(coord)
        var ground = str(cells[coord].get("ground","city"))
        var road_w = max(2.0,s * (0.25 if ground == "city" else 0.18))
        var edge = Color(INK,0.38)
        for sign_value in [-1.0,1.0]:
            var o = road_w * 0.5 * sign_value
            draw_line(p+Vector2(-s*0.5,o),p+Vector2(-road_w*0.5,o),edge,0.7)
            draw_line(p+Vector2(road_w*0.5,o),p+Vector2(s*0.5,o),edge,0.7)
            draw_line(p+Vector2(o,-s*0.5),p+Vector2(o,-road_w*0.5),edge,0.7)
            draw_line(p+Vector2(o,road_w*0.5),p+Vector2(o,s*0.5),edge,0.7)
    # pass 3 - buildings that were actually seen
    for coord in cells:
        if not _known(coord):
            continue
        var blocks = cells[coord].get("blocks",[])
        if blocks.is_empty():
            continue
        var origin = project(coord) - Vector2.ONE * s * 0.5
        var k = s / 96.0
        for r in blocks:
            var rr = Rect2(origin + Vector2(r[0],r[1]) * k,Vector2(r[2],r[3]) * k)
            if rr.size.x < 1.0 or rr.size.y < 1.0:
                continue
            draw_rect(rr,BUILDING)
            if s >= 24.0:
                draw_rect(rr,Color(INK,0.75),false,0.8)
        # district boundaries only, not a sector grid
    for coord in cells:
        if not _known(coord):
            continue
        var p = project(coord)
        var district = str(cells[coord].get("district",""))
        for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
            var other = cells.get(coord+direction,{})
            if bool(other.get("known",false)) and str(other.get("district","")) != district:
                var start = p+Vector2(s*0.5,-s*0.5) if direction == Vector2i.RIGHT else p+Vector2(-s*0.5,s*0.5)
                var end = start+Vector2(0,s) if direction == Vector2i.RIGHT else start+Vector2(s,0)
                draw_dashed_line(start,end,Color(INK,0.42),0.7,2.0)
    # edge of the explored land
    for coord in cells:
        if not _known(coord):
            continue
        var p = project(coord)
        for d in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
            if _known(coord + d):
                continue
            var a = p + (Vector2(d) * 0.5 + Vector2(d.y,d.x) * 0.5) * s
            var b = p + (Vector2(d) * 0.5 - Vector2(d.y,d.x) * 0.5) * s
            draw_line(a,b,Color(INK,0.55),1.0)
    # persistent logistics links: muted, no arrowheads
    for link in data.get("established_routes",[]):
        if typeof(link) != TYPE_DICTIONARY:
            continue
        var from_coord = link.get("from",Vector2i(999999,999999))
        var to_coord = link.get("to",Vector2i(999999,999999))
        if from_coord.x >= 900000 or to_coord.x >= 900000:
            continue
        if not contains_sector(from_coord) and not contains_sector(to_coord):
            continue
        var a = project(from_coord)
        var b = project(to_coord)
        draw_dashed_line(a,b,Color("6f6b4f"),0.9,5.0)
        draw_circle(a,2.0,Color("6f6b4f"))
        draw_circle(b,2.0,Color("6f6b4f"))
    # the current objective: a pencil line from the player to the system mark
    if data.has("player"):
        for mark in data.get("markers",[]):
            if bool(mark.get("system",false)):
                draw_dashed_line(project(data["player"]),project(mark["coord"]),Color("385b66",0.8),1.2,4.0)
    var route = data.get("route",[])
    for i in range(1,route.size()):
        draw_dashed_line(project(route[i-1]),project(route[i]),Color("854d36"),1.6,3.0)
    for poi in data.get("pois",[]):
        var p = project(poi["coord"])
        if not Rect2(Vector2.ZERO,size).has_point(p):
            continue
        _symbol(p,str(poi.get("symbol","cache")),Color("4b5142"))
        _label(p+Vector2(7,-6),str(poi["name"]))
    for mark in data.get("markers",[]):
        var p = project(mark["coord"])
        if contains_sector(mark["coord"]):
            var color = Color("884632") if mark["kind"] == "danger" else Color("385b66")
            _symbol(p,mark["kind"],color)
            if str(mark.get("label","")) != "":
                var text = str(mark["label"])
                var width = get_theme_default_font().get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
                for offset in [Vector2(7,10),Vector2(7,-8),Vector2(-width-7,10),Vector2(7,21)]:
                    if _label(p+offset,text,color):
                        break
    if data.has("home"):
        var p = project(data["home"])
        _symbol(p,"home",Color("385b66"))
        _label(p+Vector2(7,0),"ДОМ",Color("385b66"),true)
    if data.has("target"):
        _symbol(project(data["target"]),"target",Color("854d36"))
    if data.has("selected"):
        var p = project(data["selected"])
        draw_rect(Rect2(p-Vector2.ONE*s*0.5,Vector2.ONE*s),Color("854d36"),false,1.2)
    if data.has("player"):
        var p = project(data["player"]) + Vector2(data.get("player_offset",Vector2.ZERO)) * s
        draw_circle(p,4.0,PAPER)
        draw_circle(p,3.0,Color("b0412e"))
    for district in groups:
        if not SHORT_NAMES.has(district) or groups[district].size() < 2:
            continue
        var coordinates = groups[district]
        var midpoint = Vector2.ZERO
        for coord in coordinates:
            midpoint += project(coord)
        midpoint /= coordinates.size()
        # Pick an actual known piece of this district, not a centroid in its neighbour.
        var anchor = project(coordinates[0])
        for coord in coordinates:
            if project(coord).distance_squared_to(midpoint) < anchor.distance_squared_to(midpoint):
                anchor = project(coord)
        var title = str(SHORT_NAMES[district])
        var width = get_theme_default_font().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,7).x
        for offset in [Vector2(-width*0.5,6),Vector2(-width*0.5,16),Vector2(-width*0.5,-12)]:
            if _label(anchor+offset,title,Color("484c3d")):
                break
    # north arrow and scale only
    _text(Vector2(9,14),"С",8)
    draw_line(Vector2(12,19),Vector2(12,32),INK,1)
    draw_colored_polygon(PackedVector2Array([Vector2(12,17),Vector2(9,23),Vector2(15,23)]),INK)
    draw_line(Vector2(10,size.y-9),Vector2(10+s,size.y-9),INK,1.5)
    _text(Vector2(14+s,size.y-6),"1 сектор",6)
    draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("777963"),false,1)
