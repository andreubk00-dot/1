extends Control
# A schematic of known geography, not a navigation mesh or a second world model.
signal sector_selected(coord)
signal map_panned(offset)
signal zoom_changed
const ZOOMS = [18.0,25.0,34.0]
const INK = Color("34392f")
const PAPER = Color("b5b19a")
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
var zoom_index = 0
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
    draw_rect(Rect2(Vector2.ZERO,size),PAPER)
    label_boxes.clear()
    var groups = {}
    # Adjacent sectors share the same fill, with NO cell frames or buttons.
    for coord in cells:
        if not _known(coord):
            continue
        var cell = cells[coord]
        var zone = str(cell.get("zone","residential"))
        var district = str(cell.get("district",""))
        var p = project(coord)
        var rect = Rect2(p-Vector2.ONE*step()*0.5,Vector2.ONE*step())
        draw_rect(rect,ZONES.get(zone,PAPER))
        if not groups.has(district):
            groups[district] = []
        groups[district].append(coord)
        # Sparse land-use hatching; these are map conventions, not building footprints.
        var seed_value = absi(coord.x*92821+coord.y*68917)
        if zone == "woodland":
            for i in range(3):
                var t = p + Vector2(float((seed_value+i*7)%11)-5,float((seed_value+i*3)%9)-4)*step()/18.0
                draw_polyline(PackedVector2Array([t+Vector2(-2,2),t+Vector2(0,-2),t+Vector2(2,2)]),Color("687860"),0.7)
        elif zone == "industrial" or zone == "military":
            draw_line(rect.position+Vector2(3,step()-3),rect.position+Vector2(step()-3,3),Color(INK,0.13),0.6)
        # District boundaries only, not a sector grid.
        for direction in [Vector2i.RIGHT,Vector2i.DOWN]:
            var other = cells.get(coord+direction,{})
            if bool(other.get("known",false)) and str(other.get("district","")) != district:
                var start = p+Vector2(step()*0.5,-step()*0.5) if direction == Vector2i.RIGHT else p+Vector2(-step()*0.5,step()*0.5)
                var end = start+Vector2(0,step()) if direction == Vector2i.RIGHT else start+Vector2(step(),0)
                draw_dashed_line(start,end,Color(INK,0.42),0.7,2.0)
        # The world has a road cross in each chunk. Generalize minor streets at
        # overview scale, then show them when zoomed in; never reveal unseen roads.
        if coord.y == 0 or zoom_index > 0:
            draw_line(p-Vector2(step()*0.5,0),p+Vector2(step()*0.5,0),Color("c9c4ab"),2.7 if coord.y == 0 else 1.0)
            if coord.y == 0:
                draw_line(p-Vector2(step()*0.5,0),p+Vector2(step()*0.5,0),Color(INK,0.40),0.6)
        if coord.x == 0 or zoom_index > 0:
            draw_line(p-Vector2(0,step()*0.5),p+Vector2(0,step()*0.5),Color("c9c4ab"),2.7 if coord.x == 0 else 1.0)
        if district == "rail_corridor":
            draw_line(p-Vector2(step()*0.5,3),p+Vector2(step()*0.5,3),INK,1)
            for x in range(-int(step()*0.5),int(step()*0.5),4):
                draw_line(p+Vector2(x,1),p+Vector2(x,5),INK,0.8)
    # Paper grain and fold lines are stable while panning; no flickering randomness.
    for i in range(170):
        var p = Vector2((i*97+13)%int(max(1,size.x)),(i*43+19)%int(max(1,size.y)))
        draw_line(p,p+Vector2(1,0),Color(INK,0.10),0.5)
    for f in [0.33,0.67]:
        draw_line(Vector2(size.x*f,0),Vector2(size.x*f,size.y),Color(INK,0.08),1)
        draw_line(Vector2(size.x*f+1,0),Vector2(size.x*f+1,size.y),Color(1,1,0.8,0.10),1)
    # Persistent logistics links are map memory, not navigation paths. They are
    # deliberately thinner/more muted than the active expedition route and have
    # no arrowheads or intermediate waypoints.
    for link in data.get("established_routes",[]):
        if typeof(link) != TYPE_DICTIONARY:
            continue
        var from_coord = link.get("from",Vector2i(999999,999999))
        var to_coord = link.get("to",Vector2i(999999,999999))
        if from_coord.x >= 900000 or to_coord.x >= 900000:
            continue
        # Do not let an off-screen straight segment masquerade as surveyed road
        # geometry through unknown territory. A link is drawn only near an endpoint.
        if not contains_sector(from_coord) and not contains_sector(to_coord):
            continue
        var a = project(from_coord)
        var b = project(to_coord)
        draw_dashed_line(a,b,Color("6f6b4f"),0.9,5.0)
        draw_circle(a,2.0,Color("6f6b4f"))
        draw_circle(b,2.0,Color("6f6b4f"))
    var route = data.get("route",[])
    for i in range(1,route.size()):
        draw_dashed_line(project(route[i-1]),project(route[i]),Color("854d36"),1.3,3.0)
    # POI labels reserve space before district labels. Only discovered anchors arrive here.
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
        draw_arc(p,7.0,0,TAU,24,Color("854d36"),1.1)
    if data.has("player"):
        var p = project(data["player"])
        draw_circle(p,3.0,Color("283f48"))
        draw_circle(p,5.0,PAPER,false,1)
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
    # Cartographic furniture.
    _text(Vector2(9,14),"С",8)
    draw_line(Vector2(12,19),Vector2(12,32),INK,1)
    draw_colored_polygon(PackedVector2Array([Vector2(12,17),Vector2(9,23),Vector2(15,23)]),INK)
    draw_line(Vector2(10,size.y-13),Vector2(10+step()*2,size.y-13),INK,1.5)
    _text(Vector2(10,size.y-3),"2 СЕКТОРА",6)
    _text(Vector2(size.x-114,size.y-5),"СХЕМА / ПРОХОД НЕ ПРОВЕРЕН",6,Color("656652"))
    if not _known(unproject(Vector2(26,55))):
        _text(Vector2(10,49),"НЕТ ПОЛЕВЫХ",6,Color("777963"))
        _text(Vector2(10,58),"ОТМЕТОК",6,Color("777963"))
    for inset in range(4):
        draw_rect(Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2),Color(INK,0.08),false,1)
    draw_rect(Rect2(Vector2.ONE,size-Vector2.ONE*2),Color("777963"),false,1)
