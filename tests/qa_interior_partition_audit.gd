extends SceneTree
# Audit of building interiors across the world:
#  - partitions (interior static walls) that stick out of the building shell
#    or run into an outer wall at an angle that leaves a sliver,
#  - furniture standing on a partition or in a doorway gap,
#  - floor that cannot be reached from the front door (flood fill on a 2 px
#    grid with the player's 7 px clearance; walls block, and so does the
#    footprint of every standing piece of furniture).
# headless: godot --headless --script tests/qa_interior_partition_audit.gd -- [--qa-radius=8]
const Main = preload("res://main_script_mod.gd")
const CELL = 2.0
const CLEAR = 7.0
var radius = 8

func _initialize():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-radius="):
			radius = int(arg.trim_prefix("--qa-radius="))
	call_deferred("run")

func _shell(size:Vector2) -> Rect2:
	return Rect2(-size * 0.5,size)

func _static_rects(building) -> Array:
	var out = []
	for c in building.get_children():
		if c is StaticBody2D and not c.is_queued_for_deletion():
			for sh in c.get_children():
				if sh is CollisionShape2D and sh.shape is RectangleShape2D:
					var sz = sh.shape.size
					out.append(Rect2(c.position + sh.position - sz * 0.5,sz))
	return out

func _is_outer(r:Rect2,size:Vector2) -> bool:
	var h = size * 0.5
	return abs(r.get_center().y + h.y) < 2.0 or abs(r.get_center().y - h.y) < 2.0 or abs(r.get_center().x + h.x) < 2.0 or abs(r.get_center().x - h.x) < 2.0

func _prop_feet(building) -> Array:
	# the floor footprint of standing furniture: lower part of the drawn rect
	var out = []
	for c in building.get_children():
		if not (c is Sprite2D) or c.texture == null or c.is_queued_for_deletion():
			continue
		if not (c.is_in_group("interior_depth_props") or c.has_meta("interior_fill")):
			continue
		var r = c.get_rect()
		r = Rect2(r.position * c.scale,r.size * c.scale)
		r.position += c.position
		var foot = Rect2(r.position.x + r.size.x * 0.12,r.position.y + r.size.y * 0.55,r.size.x * 0.76,r.size.y * 0.40)
		out.append([foot,c])
	return out

func _reach(size:Vector2,door_x:float,walls:Array,props:Array) -> Dictionary:
	var h = size * 0.5
	var inner = Rect2(-h + Vector2(6,6),size - Vector2(12,12))
	var nx = int(inner.size.x / CELL)
	var ny = int(inner.size.y / CELL)
	var blocked = PackedByteArray()
	blocked.resize(nx * ny)
	var grown = []
	for w in walls:
		grown.append(w.grow(CLEAR))
	for p in props:
		grown.append(p[0].grow(CLEAR - 4.0))
	for j in range(ny):
		for i in range(nx):
			var pt = inner.position + Vector2(i + 0.5,j + 0.5) * CELL
			for g in grown:
				if g.has_point(pt):
					blocked[j * nx + i] = 1
					break
	# start just inside the door
	var si = int((door_x - inner.position.x) / CELL)
	var sj = ny - 1 - int(10.0 / CELL)
	var seen = PackedByteArray()
	seen.resize(nx * ny)
	var queue = []
	for dj in range(0,8):
		for di in range(-4,5):
			var ii = si + di
			var jj = sj - dj
			if ii >= 0 and ii < nx and jj >= 0 and jj < ny and blocked[jj * nx + ii] == 0:
				queue.append(Vector2i(ii,jj))
				seen[jj * nx + ii] = 1
	var head = 0
	while head < queue.size():
		var c = queue[head]
		head += 1
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n = c + d
			if n.x < 0 or n.y < 0 or n.x >= nx or n.y >= ny:
				continue
			var k = n.y * nx + n.x
			if blocked[k] == 1 or seen[k] == 1:
				continue
			seen[k] = 1
			queue.append(n)
	var free = 0
	var unreached = 0
	var where = Vector2.ZERO
	for k in range(nx * ny):
		if blocked[k] == 0:
			free += 1
			if seen[k] == 0:
				unreached += 1
				where += inner.position + Vector2(k % nx + 0.5,k / nx + 0.5) * CELL
	if unreached > 0:
		where /= float(unreached)
	return {"free":free,"unreached":unreached,"start_ok":queue.size() > 0,"where":where}

func run():
	var game = Main.new()
	root.add_child(game)
	for i in range(4):
		await process_frame
	var seen_ids = {}
	var buildings = 0
	var issues = 0
	for cy in range(-radius,radius + 1):
		for cx in range(-radius,radius + 1):
			var c = Vector2i(cx,cy)
			if not game.loaded_chunks.has(c):
				game._load_chunk(c)
			var ch = game.loaded_chunks[c]
			for b in ch.get_children():
				if not b.has_meta("world_building"):
					continue
				var bid = "%s:%s" % [str(c),str(b.get_meta("building_id",""))]
				if seen_ids.has(bid):
					continue
				seen_ids[bid] = true
				var size:Vector2 = b.get_meta("building_size",Vector2.ZERO)
				if size == Vector2.ZERO:
					continue
				buildings += 1
				var tag = "%s %s [%s] %s" % [str(c),str(b.get_meta("building_id","")),str(b.get_meta("authored_layout",b.get_meta("world_archetype",""))),str(size)]
				var shell = _shell(size)
				var all_walls = _static_rects(b)
				var parts = []
				for w in all_walls:
					if not _is_outer(w,size):
						parts.append(w)
				# 1. partitions out of the shell
				for w in parts:
					if not shell.grow(1.0).encloses(w):
						print("ISSUE ",tag," partition outside the shell ",w)
						issues += 1
				# 1b. every partition end meets a wall (outer or partition) or a
				#     doorway; partitions meet in T-joints, never cross
				var gaps = b.get_meta("partition_gaps",[])
				for w in parts:
					var horiz = w.size.x >= w.size.y
					var ends = [Vector2(w.position.x - 3.0,w.get_center().y),Vector2(w.end.x + 3.0,w.get_center().y)] if horiz else [Vector2(w.get_center().x,w.position.y - 3.0),Vector2(w.get_center().x,w.end.y + 3.0)]
					for e in ends:
						# outer walls are drawn thicker than they collide: their inner
						# faces sit 14 px in at the sides, 16 at the back
						var hs = size * 0.5
						var attached = e.x <= -hs.x + 15.0 or e.x >= hs.x - 15.0 or e.y <= -hs.y + 17.0 or e.y >= hs.y - 7.0
						for o in all_walls:
							if o != w and o.grow(4.0).has_point(e):
								attached = true
						for g in gaps:
							if g.has_point(e):
								attached = true
						if not attached:
							print("ISSUE ",tag," free partition end at ",e.round())
							issues += 1
				for i in range(parts.size()):
					for j in range(i + 1,parts.size()):
						var a = parts[i]
						var c2 = parts[j]
						var ov = a.intersection(c2)
						if ov.size.x <= 0.0 or ov.size.y <= 0.0:
							continue
						# a cross: the overlap sits clear of both walls' ends
						var a_mid = ov.position.x - a.position.x > 4.0 and a.end.x - ov.end.x > 4.0 if a.size.x >= a.size.y else ov.position.y - a.position.y > 4.0 and a.end.y - ov.end.y > 4.0
						var c_mid = ov.position.x - c2.position.x > 4.0 and c2.end.x - ov.end.x > 4.0 if c2.size.x >= c2.size.y else ov.position.y - c2.position.y > 4.0 and c2.end.y - ov.end.y > 4.0
						if a_mid and c_mid:
							print("ISSUE ",tag," partitions cross at ",ov.get_center().round())
							issues += 1
				# 2. furniture on partitions
				var props = _prop_feet(b)
				for p in props:
					for w in parts:
						if p[0].intersects(w.grow(1.0)):
							print("ISSUE ",tag," furniture on a partition: ",p[1].get_meta("interior_fill","layout")," at ",p[1].position," wall ",w)
							issues += 1
							break
				# 2b. furniture in a doorway between rooms or in the entrance hall
				for p in props:
					for g in b.get_meta("partition_gaps",[]) + b.get_meta("keep_clear",[]):
						if p[0].intersects(g):
							print("ISSUE ",tag," furniture in a passage at ",p[1].position)
							issues += 1
							break
				# 3. reachability
				var door_x = float(b.get_meta("door_local_x",0.0))
				var r = _reach(size,door_x,all_walls,props)
				if not r["start_ok"]:
					print("ISSUE ",tag," doorway blocked inside")
					issues += 1
				elif r["unreached"] * CELL * CELL > 1500.0:
					print("ISSUE ",tag," unreachable floor ",int(r["unreached"] * CELL * CELL)," px2 of ",int(r["free"] * CELL * CELL)," around ",r["where"].round())
					issues += 1
			if game.loaded_chunks.size() > 16:
				for k in game.loaded_chunks.keys():
					if k != c:
						game._unload_chunk(k)
	print("AUDIT buildings=",buildings," issues=",issues)
	quit()
