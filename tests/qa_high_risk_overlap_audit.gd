extends SceneTree
# Overlap audit for High Risk sites: loads every sector and reports
#   * chain-link fences crossing buildings, doors, the PO-2 perimeter or set pieces,
#   * set pieces whose sprites overlap each other, a building footprint or a facade,
#   * fences that double the perimeter.
# Usage: godot --headless --path . --script tests/qa_high_risk_overlap_audit.gd
const Main = preload("res://main_script_mod.gd")
const RegionCatalog = preload("res://world/region_catalog.gd")
const PoiCatalog = preload("res://world/poi_catalog.gd")
const SITES = ["regional_clinical_complex_4","quarantine_center_12","reserve_arsenal_bastion","underground_object_vector"]

var issues := 0

func _initialize():
    call_deferred("run")

func report(msg:String):
    issues += 1
    print("OVERLAP ",msg)

var _used_cache = {}

func _used_rect(tex:Texture2D) -> Rect2:
    var key = str(tex.get_rid())
    if tex is AtlasTexture:
        key = str(tex.atlas.get_rid()) + str(tex.region)
    if _used_cache.has(key):
        return _used_cache[key]
    var img = tex.get_image()
    var r = Rect2(Vector2.ZERO,tex.get_size())
    if img != null:
        if img.is_compressed():
            img.decompress()
        r = Rect2(img.get_used_rect())
    _used_cache[key] = r
    return r

func _sprite_box(node:Node) -> Rect2:
    var box = Rect2()
    var first = true
    for s in node.find_children("*","Sprite2D",true,false):
        if not s.visible or s.texture == null:
            continue
        var full:Rect2 = s.get_rect()
        var used = _used_rect(s.texture)
        if used.size.x <= 0 or used.size.y <= 0:
            continue
        var ux = used.position.x
        if s.flip_h:
            ux = full.size.x - used.end.x
        var r = Rect2(full.position + Vector2(ux,used.position.y),used.size)
        var xf:Transform2D = s.global_transform
        var pts = [xf * r.position,xf * Vector2(r.end.x,r.position.y),xf * r.end,xf * Vector2(r.position.x,r.end.y)]
        for p in pts:
            if first:
                box = Rect2(p,Vector2.ZERO)
                first = false
            else:
                box = box.expand(p)
    return box

func _fence_box(f:Node2D) -> Rect2:
    var l = float(f.get_meta("fence_length",0.0))
    var vertical = abs(sin(f.global_rotation)) > 0.7
    var p = f.global_position
    return Rect2(p - Vector2(3,l * 0.5),Vector2(6,l)) if vertical else Rect2(p - Vector2(l * 0.5,3),Vector2(l,6))

func _inter_area(a:Rect2,b:Rect2) -> float:
    var i = a.intersection(b)
    return i.get_area() if a.intersects(b) else 0.0

func run():
    var game = Main.new()
    root.add_child(game)
    for i in range(4):
        await process_frame
    for poi_id in SITES:
        var poi = RegionCatalog.poi_by_id(poi_id)
        var anchor:Vector2i = poi.get("coord",Vector2i.ZERO)
        var fp = PoiCatalog.footprint(poi_id)
        game.player.global_position = Vector2(anchor) * 768.0 + Vector2(384,384)
        for i in range(20):
            await process_frame
        for o in fp:
            if not game.loaded_chunks.has(anchor + o):
                game._load_chunk(anchor + o)
        for i in range(4):
            await process_frame
        for o in fp:
            var chunk = game.loaded_chunks.get(anchor + o)
            if chunk == null:
                continue
            var tag = "%s %d,%d" % [poi_id,o.x,o.y]
            var buildings = []
            var fences = []
            var pieces = []
            var perim = []
            for child in chunk.get_children():
                if child.has_meta("world_building"):
                    var sz:Vector2 = child.get_meta("building_size",Vector2.ZERO)
                    var fh = float(child.get_meta("facade_height",0.0))
                    var foot = Rect2(child.global_position - sz * 0.5,sz)
                    # the facade stands on the south edge and rises fh above it on screen
                    var facade = Rect2(foot.position.x,foot.end.y - fh,sz.x,fh + 10.0)
                    buildings.append({"id":str(child.get_meta("building_id","")),"foot":foot,"facade":facade,
                        "door":child.global_position + Vector2(float(child.get_meta("door_local_x",0.0)),sz.y * 0.5)})
                elif bool(child.get_meta("world_fence",false)):
                    fences.append(child)
                elif child.has_meta("settlement_piece_kind") or child.is_in_group("poi_set_pieces"):
                    pieces.append(child)
                elif child.has_meta("high_risk_perimeter"):
                    perim.append(child)
            var perim_lines = []
            for p in perim:
                for side in p.get_meta("high_risk_perimeter",[]):
                    var base = chunk.global_position
                    match str(side):
                        "n": perim_lines.append(Rect2(base + Vector2(0,0),Vector2(768,40)))
                        "s": perim_lines.append(Rect2(base + Vector2(0,724),Vector2(768,44)))
                        "w": perim_lines.append(Rect2(base + Vector2(0,0),Vector2(40,768)))
                        "e": perim_lines.append(Rect2(base + Vector2(728,0),Vector2(40,768)))
            for f in fences:
                var fb = _fence_box(f)
                var fl = "fence@(%d,%d) len %d" % [int(f.position.x),int(f.position.y),int(f.get_meta("fence_length",0.0))]
                for b in buildings:
                    if fb.intersects(b["foot"].grow(-2)):
                        report("%s: %s crosses building %s" % [tag,fl,b["id"]])
                    elif fb.intersects(b["facade"]):
                        report("%s: %s runs in front of / through facade of %s" % [tag,fl,b["id"]])
                    if fb.grow(36).has_point(b["door"]):
                        report("%s: %s blocks door of %s" % [tag,fl,b["id"]])
                for pl in perim_lines:
                    if _inter_area(fb,pl) > fb.get_area() * 0.4:
                        report("%s: %s doubles the PO-2 perimeter" % [tag,fl])
                for p in pieces:
                    var pb = _sprite_box(p)
                    var pfoot = Rect2(pb.position.x,pb.end.y - clamp(pb.size.y * 0.45,16.0,46.0),pb.size.x,clamp(pb.size.y * 0.45,16.0,46.0))
                    if pb.get_area() > 0 and (fb.intersects(pfoot) or (pb.size.y < 70.0 and fb.intersects(pb))):
                        report("%s: %s cuts through piece %s" % [tag,fl,str(p.get_meta("settlement_piece_kind",p.name))])
            for i in range(pieces.size()):
                var a = pieces[i]
                var ab = _sprite_box(a)
                if ab.get_area() <= 0:
                    continue
                var ak = str(a.get_meta("settlement_piece_kind",a.get_meta("poi_piece_kind",a.name)))
                # same footing as the game's placement check (lowest 45 % of the art, 16..46 px)
                var gh = clamp(ab.size.y * 0.45,16.0,46.0)
                var ground = Rect2(ab.position.x,ab.end.y - gh,ab.size.x,gh)
                for b in buildings:
                    if ground.intersects(b["foot"].grow(-4)):
                        report("%s: piece %s stands inside building %s" % [tag,ak,b["id"]])
                    if ground.grow(14).has_point(b["door"]):
                        report("%s: piece %s blocks door of %s" % [tag,ak,b["id"]])
                for j in range(i + 1,pieces.size()):
                    var c = pieces[j]
                    var cb = _sprite_box(c)
                    if cb.get_area() <= 0:
                        continue
                    var af = Rect2(ab.position.x,ab.end.y - clamp(ab.size.y * 0.45,16.0,46.0),ab.size.x,clamp(ab.size.y * 0.45,16.0,46.0))
                    var cf = Rect2(cb.position.x,cb.end.y - clamp(cb.size.y * 0.45,16.0,46.0),cb.size.x,clamp(cb.size.y * 0.45,16.0,46.0))
                    var ov = _inter_area(af,cf)
                    if ov > min(af.get_area(),cf.get_area()) * 0.15:
                        var ck = str(c.get_meta("settlement_piece_kind",c.get_meta("poi_piece_kind",c.name)))
                        report("%s: piece %s overlaps piece %s (%d%%)" % [tag,ak,ck,int(100.0 * ov / min(af.get_area(),cf.get_area()))])
            print("AUDIT ",tag," buildings=",buildings.size()," fences=",fences.size()," pieces=",pieces.size()," skipped=",chunk.get_meta("high_risk_pieces_skipped",[]))
    print("HIGH RISK OVERLAP AUDIT: ",issues," issues")
    quit(0)
