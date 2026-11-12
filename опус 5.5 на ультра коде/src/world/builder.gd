class_name Builder
extends RefCounted
## Строит здание по Layout: полы, стены с проёмами, потолки, окна, двери, бассейн, лестницы, улица.

const T := 0.12   # толщина стены со стороны одной комнаты

var w: Node3D
var batch := Geo.Batch.new()
var rooms := {}   # id -> {def, rect: Rect2, y, h, node: Node3D, body: StaticBody3D}
var doors := {}   # id -> Door
var window_lights: Array = []


func build(world: Node3D) -> void:
	w = world
	var t := Time.get_ticks_msec()
	for id in Layout.ROOMS:
		_room(id)
	var t1 := Time.get_ticks_msec()
	for d in Layout.DOORS:
		_door(d)
	var t2 := Time.get_ticks_msec()
	for wd in Layout.WINDOWS:
		_window(wd)
	_pool()
	_lobby_stairs()
	var t3 := Time.get_ticks_msec()
	_exterior()
	print("    комнаты %d, двери %d, окна+бассейн %d, улица %d" % [t1 - t, t2 - t1, t3 - t2, Time.get_ticks_msec() - t3])


# ---------------------------------------------------------------- комнаты

func _room(id: String) -> void:
	var d: Dictionary = Layout.ROOMS[id]
	var r: Array = d["r"]
	var rect := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
	var y := float(d["y"])
	var h := float(d["h"])
	var node := Node3D.new()
	node.name = id
	w.add_child(node)
	var body := Geo.static_body(node, "col")
	var info := {"id": id, "def": d, "rect": rect, "y": y, "h": h, "node": node, "body": body}
	rooms[id] = info
	var lift := float(d.get("floor_lift", 0.0))
	var floor_mat := Mat.m(d["floor"], {"wet": 0.85 if d.get("wet", false) or d.has("water") else 0.0})
	# пол
	if d.get("stairs", false):
		_stairs_room(info)
	else:
		var holes: Array = []
		if id == "pool":
			holes.append(Layout.POOL_BASIN)
		if id == "lobby":
			holes.append(Layout.LOBBY_STAIRS)
		for fr in _rect_minus(rect, holes):
			var c := Vector3(fr.position.x + fr.size.x * 0.5, y + lift - 0.15, fr.position.y + fr.size.y * 0.5)
			var s := Vector3(fr.size.x, 0.3, fr.size.y)
			batch.box(floor_mat, c, s)
			Geo.col_box(body, c, s)
		if lift > 0.0:
			# порожек-пандус у дверей не нужен: поднимаем пол только внутри, у проёмов делаем скат
			pass
	# потолок
	var ceil_mat := Mat.m(d.get("ceil", "plaster"))
	var cc := Vector3(rect.get_center().x, y + h + 0.15, rect.get_center().y)
	batch.box(ceil_mat, cc, Vector3(rect.size.x, 0.3, rect.size.y))
	Geo.col_box(body, cc, Vector3(rect.size.x, 0.3, rect.size.y))
	# стены
	for side in ["n", "s", "w", "e"]:
		_wall_side(info, side)
	# плинтус-бордюр по низу мокрых помещений
	batch.commit(node, "shell")


func _rect_minus(r: Rect2, holes: Array) -> Array:
	var out := [r]
	for hole: Rect2 in holes:
		var nxt := []
		for a: Rect2 in out:
			if not a.intersects(hole):
				nxt.append(a)
				continue
			var i := a.intersection(hole)
			if i.position.y > a.position.y:
				nxt.append(Rect2(a.position.x, a.position.y, a.size.x, i.position.y - a.position.y))
			if i.end.y < a.end.y:
				nxt.append(Rect2(a.position.x, i.end.y, a.size.x, a.end.y - i.end.y))
			if i.position.x > a.position.x:
				nxt.append(Rect2(a.position.x, i.position.y, i.position.x - a.position.x, i.size.y))
			if i.end.x < a.end.x:
				nxt.append(Rect2(i.end.x, i.position.y, a.end.x - i.end.x, i.size.y))
		out = nxt
	return out


## Проёмы (двери, окна) на стороне комнаты: [центр вдоль стены, ширина, низ, верх]
func _openings(info: Dictionary, side: String) -> Array:
	var rect: Rect2 = info["rect"]
	var id: String = info["id"]
	var y: float = info["y"]
	var out := []
	for d in Layout.DOORS:
		if d[0] != id and d[1] != id:
			continue
		var p: Vector2 = d[2]
		var t := _on_side(rect, side, p)
		if is_nan(t):
			continue
		var other: String = d[1] if d[0] == id else d[0]
		var bottom := y
		if Layout.ROOMS.has(other):
			bottom = maxf(y, float(Layout.ROOMS[other]["y"]))
		if id == "b_stairs" and other == "service":
			bottom = 0.0
		out.append([t, float(d[3]), bottom, bottom + float(d[4])])
	for wd in Layout.WINDOWS:
		if wd[0] == id and wd[1] == side:
			out.append([float(wd[2]), float(wd[4]), y + float(wd[3]), y + float(wd[3]) + float(wd[5])])
	out.sort_custom(func(a, b): return a[0] < b[0])
	return out


func _on_side(rect: Rect2, side: String, p: Vector2) -> float:
	match side:
		"n":
			if absf(p.y - rect.position.y) < 0.01 and p.x > rect.position.x and p.x < rect.end.x:
				return p.x
		"s":
			if absf(p.y - rect.end.y) < 0.01 and p.x > rect.position.x and p.x < rect.end.x:
				return p.x
		"w":
			if absf(p.x - rect.position.x) < 0.01 and p.y > rect.position.y and p.y < rect.end.y:
				return p.y
		"e":
			if absf(p.x - rect.end.x) < 0.01 and p.y > rect.position.y and p.y < rect.end.y:
				return p.y
	return NAN


func _wall_side(info: Dictionary, side: String) -> void:
	var d: Dictionary = info["def"]
	var rect: Rect2 = info["rect"]
	var y: float = info["y"]
	var h: float = info["h"]
	var body: StaticBody3D = info["body"]
	var along_x := side == "n" or side == "s"
	var t0 := rect.position.x if along_x else rect.position.y
	var t1 := rect.end.x if along_x else rect.end.y
	var ops := _openings(info, side)
	var cursor := t0
	for o in ops:
		var oc: float = o[0]
		var ow: float = o[1]
		var a := oc - ow * 0.5
		var b := oc + ow * 0.5
		if a > cursor:
			_wall_piece(info, side, cursor, a, y, y + h)
		# над и под проёмом
		if o[3] < y + h - 0.01:
			_wall_piece(info, side, a, b, o[3], y + h)
		if o[2] > y + 0.01:
			_wall_piece(info, side, a, b, y, o[2])
		cursor = maxf(cursor, b)
	if cursor < t1:
		_wall_piece(info, side, cursor, t1, y, y + h)


func _wall_piece(info: Dictionary, side: String, ta: float, tb: float, ya: float, yb: float) -> void:
	if tb - ta < 0.005 or yb - ya < 0.005:
		return
	var d: Dictionary = info["def"]
	var rect: Rect2 = info["rect"]
	var y: float = info["y"]
	var body: StaticBody3D = info["body"]
	var low := float(d.get("low", 0.0))
	var mat_hi := Mat.m(d["wall"])
	var mat_lo := Mat.m(d.get("wall_low", d["wall"]))
	var split := y + low
	var parts := []
	if d.has("wall_low") and split > ya and split < yb:
		parts = [[ya, split, mat_lo], [split, yb, mat_hi]]
	elif d.has("wall_low") and yb <= split:
		parts = [[ya, yb, mat_lo]]
	else:
		parts = [[ya, yb, mat_hi]]
	for p in parts:
		var c := Vector3.ZERO
		var s := Vector3.ZERO
		var my: float = (p[0] + p[1]) * 0.5
		var sy: float = p[1] - p[0]
		match side:
			"n":
				c = Vector3((ta + tb) * 0.5, my, rect.position.y + T * 0.5)
				s = Vector3(tb - ta, sy, T)
			"s":
				c = Vector3((ta + tb) * 0.5, my, rect.end.y - T * 0.5)
				s = Vector3(tb - ta, sy, T)
			"w":
				c = Vector3(rect.position.x + T * 0.5, my, (ta + tb) * 0.5)
				s = Vector3(T, sy, tb - ta)
			"e":
				c = Vector3(rect.end.x - T * 0.5, my, (ta + tb) * 0.5)
				s = Vector3(T, sy, tb - ta)
		batch.box(p[2], c, s)
	var cc := Vector3.ZERO
	var ss := Vector3.ZERO
	match side:
		"n":
			cc = Vector3((ta + tb) * 0.5, (ya + yb) * 0.5, rect.position.y + T * 0.5)
			ss = Vector3(tb - ta, yb - ya, T)
		"s":
			cc = Vector3((ta + tb) * 0.5, (ya + yb) * 0.5, rect.end.y - T * 0.5)
			ss = Vector3(tb - ta, yb - ya, T)
		"w":
			cc = Vector3(rect.position.x + T * 0.5, (ya + yb) * 0.5, (ta + tb) * 0.5)
			ss = Vector3(T, yb - ya, tb - ta)
		"e":
			cc = Vector3(rect.end.x - T * 0.5, (ya + yb) * 0.5, (ta + tb) * 0.5)
			ss = Vector3(T, yb - ya, tb - ta)
	Geo.col_box(body, cc, ss)


## Лестница в подвал: ступени от z=0 (y=0) вниз на север до z=-7 (y=-4.5)
func _stairs_room(info: Dictionary) -> void:
	var rect: Rect2 = info["rect"]
	var body: StaticBody3D = info["body"]
	var mat := Mat.m("concrete")
	var n := 18
	var top_z := rect.end.y - 0.6      # верхняя площадка 0.6 м
	var bot_z := rect.position.y + 1.2 # нижняя площадка 1.2 м
	var run := (top_z - bot_z) / n
	var rise := 4.5 / n
	# верхняя площадка
	batch.box(mat, Vector3(rect.get_center().x, -0.15, (top_z + rect.end.y) * 0.5), Vector3(rect.size.x, 0.3, rect.end.y - top_z))
	Geo.col_box(body, Vector3(rect.get_center().x, -0.15, (top_z + rect.end.y) * 0.5), Vector3(rect.size.x, 0.3, rect.end.y - top_z))
	for i in n:
		var ztop := top_z - run * i
		var ytop := -rise * (i + 1)
		var c := Vector3(rect.get_center().x, (ytop + Layout.BASE_Y) * 0.5 - 0.0, ztop - run * 0.5)
		batch.box(mat, c, Vector3(rect.size.x, ytop - Layout.BASE_Y + 0.001, run))
	# нижняя площадка
	var lc := Vector3(rect.get_center().x, Layout.BASE_Y - 0.15, (rect.position.y + bot_z) * 0.5)
	batch.box(mat, lc, Vector3(rect.size.x, 0.3, bot_z - rect.position.y))
	Geo.col_box(body, lc, Vector3(rect.size.x, 0.3, bot_z - rect.position.y))
	# коллизия — одна выпуклая форма: верхняя площадка + пролёт (без стыка, чтобы навигация была сплошной)
	var cs := CollisionShape3D.new()
	var sh := ConvexPolygonShape3D.new()
	var pts := PackedVector3Array()
	for x in [rect.position.x, rect.end.x]:
		pts.append(Vector3(x, 0.0, rect.end.y))
		pts.append(Vector3(x, 0.0, top_z))
		pts.append(Vector3(x, Layout.BASE_Y, bot_z))
		pts.append(Vector3(x, Layout.BASE_Y - 0.3, bot_z))
		pts.append(Vector3(x, Layout.BASE_Y - 0.3, rect.end.y))
	sh.points = pts
	cs.shape = sh
	body.add_child(cs)
	# перила
	var rail := Mat.m("rust", {"metal": 0.6})
	for x in [rect.position.x + 0.2, rect.end.x - 0.2]:
		batch.cyl(rail, Vector3(x, 0.9, top_z), Vector3(x, Layout.BASE_Y + 0.9, bot_z), 0.025, 6)


# ---------------------------------------------------------------- бассейн

func _pool() -> void:
	var info: Dictionary = rooms["pool"]
	var node: Node3D = info["node"]
	var body: StaticBody3D = info["body"]
	var b := Layout.POOL_BASIN
	var tile := Mat.m("tile_pool", {"wet": 0.6})
	var edge := Mat.m("tile_wall", {"tint": Color(0.85, 0.85, 0.8)})
	var x0 := b.position.x
	var x1 := b.end.x
	var z0 := b.position.y
	var z1 := b.end.y
	var sh := Layout.POOL_SHALLOW
	var dp := Layout.POOL_DEEP
	var s0 := Layout.POOL_SLOPE.x
	var s1 := Layout.POOL_SLOPE.y
	# дно: мелкая часть, скат, глубокая
	_floor_piece(body, tile, Rect2(x0, z0, s0 - x0, b.size.y), sh)
	_floor_piece(body, tile, Rect2(s1, z0, x1 - s1, b.size.y), dp)
	var sl := Vector3(s1 - s0, dp - sh, 0)
	var ang := atan2(-(dp - sh), s1 - s0)
	var slen := sqrt(sl.x * sl.x + sl.y * sl.y)
	var sc := Vector3((s0 + s1) * 0.5, (sh + dp) * 0.5 - 0.15, (z0 + z1) * 0.5)
	batch.box(tile, sc, Vector3(slen, 0.3, b.size.y), Basis(Vector3.BACK, -ang))
	Geo.col_box(body, sc, Vector3(slen, 0.3, b.size.y), Basis(Vector3.BACK, -ang))
	# стенки чаши (внутренние грани, от дна до пола зала)
	var walls := [
		[Vector3((x0 + x1) * 0.5, 0, z0 - 0.15), Vector3(b.size.x + 0.3, 0, 0.3)],
		[Vector3((x0 + x1) * 0.5, 0, z1 + 0.15), Vector3(b.size.x + 0.3, 0, 0.3)],
		[Vector3(x0 - 0.15, 0, (z0 + z1) * 0.5), Vector3(0.3, 0, b.size.y)],
		[Vector3(x1 + 0.15, 0, (z0 + z1) * 0.5), Vector3(0.3, 0, b.size.y)],
	]
	for wl in walls:
		var c: Vector3 = wl[0]
		var s: Vector3 = wl[1]
		var top := 0.0
		var bot := dp - 0.3
		c.y = (top + bot) * 0.5
		s.y = top - bot
		batch.box(tile, c, s)
		Geo.col_box(body, c, s)
	# бортик
	for e in [[Vector3((x0 + x1) * 0.5, 0.05, z0 - 0.25), Vector3(b.size.x + 1.0, 0.1, 0.5)],
			[Vector3((x0 + x1) * 0.5, 0.05, z1 + 0.25), Vector3(b.size.x + 1.0, 0.1, 0.5)],
			[Vector3(x0 - 0.25, 0.05, (z0 + z1) * 0.5), Vector3(0.5, 0.1, b.size.y)],
			[Vector3(x1 + 0.25, 0.05, (z0 + z1) * 0.5), Vector3(0.5, 0.1, b.size.y)]]:
		batch.box(edge, e[0], e[1])
	# ступени в мелкую часть (западный край, у северной стенки)
	var steps := 5
	for i in steps:
		var yy := -(i + 1) * (-sh) / steps
		var c := Vector3(x0 + 0.35 + i * 0.35, (yy + sh) * 0.5, z0 + 0.7)
		batch.box(tile, c, Vector3(0.35, yy - sh, 1.4))
	var sang := atan2(-sh, steps * 0.35)
	var sc2 := Vector3(x0 + steps * 0.35 * 0.5 + 0.2, sh * 0.5 - 0.1, z0 + 0.7)
	Geo.col_box(body, sc2, Vector3(sqrt(pow(steps * 0.35, 2) + sh * sh), 0.2, 1.4), Basis(Vector3.BACK, -sang))
	# поручни лесенки
	var rail := Mat.m("rust", {"metal": 0.8, "tint": Color(1.2, 1.2, 1.2)})
	for zz in [z0 + 0.05, z0 + 1.35]:
		batch.cyl(rail, Vector3(x0 - 0.3, 0.9, zz), Vector3(x0 + 0.1, 0.9, zz), 0.022, 6)
		batch.cyl(rail, Vector3(x0 + 0.1, 0.9, zz), Vector3(x0 + 0.6, -0.4, zz), 0.022, 6)
		batch.cyl(rail, Vector3(x0 - 0.3, 0.0, zz), Vector3(x0 - 0.3, 0.9, zz), 0.022, 6)
	batch.commit(node, "basin")


func _floor_piece(body: StaticBody3D, mat: Material, r: Rect2, y: float) -> void:
	var c := Vector3(r.get_center().x, y - 0.15, r.get_center().y)
	var s := Vector3(r.size.x, 0.3, r.size.y)
	batch.box(mat, c, s)
	Geo.col_box(body, c, s)


# ---------------------------------------------------------------- затопленная лестница в вестибюле

func _lobby_stairs() -> void:
	var info: Dictionary = rooms["lobby"]
	var node: Node3D = info["node"]
	var body: StaticBody3D = info["body"]
	var r := Layout.LOBBY_STAIRS
	var mat := Mat.m("terracotta", {"wet": 0.7})
	var wall := Mat.m("tile_dark", {"wet": 0.5})
	# ступени уходят вниз на север
	var n := 10
	for i in n:
		var ztop := r.end.y - i * 0.3
		var ytop := -(i + 1) * 0.22
		batch.box(mat, Vector3(r.get_center().x, (ytop - 3.0) * 0.5, ztop - 0.15), Vector3(r.size.x, ytop + 3.0, 0.3))
	# стенки колодца
	for wl in [[Vector3(r.position.x - 0.1, -1.5, r.get_center().y), Vector3(0.2, 3.0, r.size.y)],
			[Vector3(r.end.x + 0.1, -1.5, r.get_center().y), Vector3(0.2, 3.0, r.size.y)],
			[Vector3(r.get_center().x, -1.5, r.position.y - 0.1), Vector3(r.size.x + 0.4, 3.0, 0.2)]]:
		batch.box(wall, wl[0], wl[1])
	# перила с трёх сторон
	var rail := Mat.m("rust", {"metal": 0.6})
	var y := 0.95
	batch.cyl(rail, Vector3(r.position.x, y, r.end.y), Vector3(r.position.x, y, r.position.y), 0.025, 6)
	batch.cyl(rail, Vector3(r.end.x, y, r.end.y), Vector3(r.end.x, y, r.position.y), 0.025, 6)
	batch.cyl(rail, Vector3(r.position.x, y, r.position.y), Vector3(r.end.x, y, r.position.y), 0.025, 6)
	for zz in [r.position.y, r.get_center().y, r.end.y]:
		for xx in [r.position.x, r.end.x]:
			batch.cyl(rail, Vector3(xx, 0.0, zz), Vector3(xx, y, zz), 0.02, 6)
	batch.commit(node, "stairs")
	# коллизия: ограждение и невидимая стена у воды
	Geo.col_box(body, Vector3(r.position.x, 0.5, r.get_center().y), Vector3(0.1, 1.0, r.size.y))
	Geo.col_box(body, Vector3(r.end.x, 0.5, r.get_center().y), Vector3(0.1, 1.0, r.size.y))
	Geo.col_box(body, Vector3(r.get_center().x, 0.5, r.position.y), Vector3(r.size.x, 1.0, 0.1))
	Geo.col_box(body, Vector3(r.get_center().x, 0.5, r.end.y - 0.2), Vector3(r.size.x, 1.0, 0.1))


# ---------------------------------------------------------------- окна

func _window(wd: Array) -> void:
	var id: String = wd[0]
	var side: String = wd[1]
	var info: Dictionary = rooms[id]
	var rect: Rect2 = info["rect"]
	var y: float = info["y"]
	var t: float = wd[2]
	var bottom: float = y + float(wd[3])
	var ww: float = wd[4]
	var wh: float = wd[5]
	var node: Node3D = info["node"]
	var south := side == "s"
	var col := Color(1.0, 0.72, 0.45) if south else Color(0.55, 0.66, 0.95)
	var glass := Mat.flat(col.darkened(0.55), 0.3, 0.0, {"emission": col, "emission_energy": 0.25})
	var frame := Mat.m("planks_weather", {"tint": Color(0.75, 0.75, 0.7)})
	var pos := Vector3.ZERO
	var size := Vector3.ZERO
	var inward := Vector3.ZERO
	match side:
		"n":
			pos = Vector3(t, bottom + wh * 0.5, rect.position.y + 0.05)
			size = Vector3(ww, wh, 0.04)
			inward = Vector3(0, 0, 1)
		"s":
			pos = Vector3(t, bottom + wh * 0.5, rect.end.y - 0.05)
			size = Vector3(ww, wh, 0.04)
			inward = Vector3(0, 0, -1)
		"w":
			pos = Vector3(rect.position.x + 0.05, bottom + wh * 0.5, t)
			size = Vector3(0.04, wh, ww)
			inward = Vector3(1, 0, 0)
		"e":
			pos = Vector3(rect.end.x - 0.05, bottom + wh * 0.5, t)
			size = Vector3(0.04, wh, ww)
			inward = Vector3(-1, 0, 0)
	batch.box(glass, pos, size)
	# переплёт
	var cross_a := Vector3(size.x if size.x > 0.1 else 0.06, 0.05, size.z if size.z > 0.1 else 0.06)
	batch.box(frame, pos + inward * 0.02, cross_a)
	var cross_b := Vector3(0.05 if size.x > 0.1 else 0.06, wh, 0.05 if size.z > 0.1 else 0.06)
	batch.box(frame, pos + inward * 0.02, cross_b)
	# подоконник
	var sill := Vector3(size.x + (0.1 if size.x > 0.1 else 0.25), 0.05, size.z + (0.1 if size.z > 0.1 else 0.25))
	batch.box(frame, Vector3(pos.x, bottom - 0.03, pos.z) + inward * 0.12, sill)
	batch.commit(node, "window")
	# лунный свет из окна
	var sl := SpotLight3D.new()
	sl.light_color = col
	sl.light_energy = 0.9 if south else 0.7
	sl.spot_range = 9.0
	sl.spot_angle = 55.0
	sl.spot_attenuation = 1.2
	sl.shadow_enabled = false
	sl.light_specular = 0.3
	node.add_child(sl)
	sl.global_position = pos + inward * 0.3 + Vector3.UP * 0.2
	sl.look_at(sl.global_position + inward + Vector3.DOWN * 0.7)
	window_lights.append(sl)


# ---------------------------------------------------------------- двери

func _door(d: Array) -> void:
	var kind: String = d[5]
	if kind == "":
		return
	var p: Vector2 = d[2]
	var width: float = d[3]
	var height: float = d[4]
	var a: String = d[0]
	var bottom := 0.0
	if Layout.ROOMS.has(a):
		bottom = float(Layout.ROOMS[a]["y"])
	if Layout.ROOMS.has(d[1]):
		bottom = maxf(bottom, float(Layout.ROOMS[d[1]]["y"]))
	if a == "service" and d[1] == "b_stairs":
		bottom = 0.0
	# ось стены: проём на линии z (север/юг) — дверь вдоль x
	var ra: Array = Layout.ROOMS[a]["r"]
	var along_x := absf(p.y - float(ra[1])) < 0.01 or absf(p.y - float(ra[3])) < 0.01
	var door := Door.new()
	door.name = d[6]
	door.id = d[6]
	door.kind = kind
	door.room_a = a
	door.room_b = d[1]
	w.add_child(door)
	door.setup(Vector3(p.x, bottom, p.y), along_x, width, height)
	doors[door.id] = door
	# наличники
	var trim := Mat.m("planks_weather", {"tint": Color(0.6, 0.55, 0.5)})
	if kind == "steel" or kind == "grate":
		trim = Mat.m("rust", {"metal": 0.4})
	var node: Node3D = rooms[a]["node"]
	for sgn in [-1.0, 1.0]:
		var off := Vector3(0, 0, sgn * (T + 0.015)) if along_x else Vector3(sgn * (T + 0.015), 0, 0)
		var c := Vector3(p.x, bottom, p.y) + off
		var hw := width * 0.5 + 0.04
		if along_x:
			batch.box(trim, c + Vector3(-hw, height * 0.5, 0), Vector3(0.08, height, 0.03))
			batch.box(trim, c + Vector3(hw, height * 0.5, 0), Vector3(0.08, height, 0.03))
			batch.box(trim, c + Vector3(0, height + 0.04, 0), Vector3(width + 0.16, 0.08, 0.03))
		else:
			batch.box(trim, c + Vector3(0, height * 0.5, -hw), Vector3(0.03, height, 0.08))
			batch.box(trim, c + Vector3(0, height * 0.5, hw), Vector3(0.03, height, 0.08))
			batch.box(trim, c + Vector3(0, height + 0.04, 0), Vector3(0.03, 0.08, width + 0.16))
	batch.commit(node, "trim")


# ---------------------------------------------------------------- улица

func _exterior() -> void:
	var ext := Node3D.new()
	ext.name = "exterior"
	w.add_child(ext)
	var body := Geo.static_body(ext, "col")
	var facade := Mat.m("facade", {"tint": Color(0.8, 0.72, 0.6)})
	var plinth := Mat.m("brick_red", {"tint": Color(0.7, 0.6, 0.55)})
	var roofm := Mat.m("concrete_dirty", {"tint": Color(0.5, 0.5, 0.5)})
	var snow := Mat.m("snow", {"tint": Color(0.75, 0.8, 0.9), "rough": 0.9})
	var X0 := -0.35
	var X1 := 52.35
	var Z0 := -0.35
	var Z1 := 30.35
	var H := 5.6
	# стены корпуса (снаружи)
	var walls := [
		# северная — с проёмом на лестницу в котельную (x 24.45..26.05)
		[Vector3((X0 + 24.45) * 0.5, H * 0.5, Z0 + 0.175), Vector3(24.45 - X0, H, 0.35)],
		[Vector3((26.05 + X1) * 0.5, H * 0.5, Z0 + 0.175), Vector3(X1 - 26.05, H, 0.35)],
		[Vector3(25.25, (2.2 + H) * 0.5, Z0 + 0.175), Vector3(1.6, H - 2.2, 0.35)],
		[Vector3(X0 + 0.175, H * 0.5, (Z0 + Z1) * 0.5), Vector3(0.35, H, Z1 - Z0)],
		[Vector3(X1 - 0.175, H * 0.5, (Z0 + Z1) * 0.5), Vector3(0.35, H, Z1 - Z0)],
	]
	# южная — с проёмом входа
	walls.append([Vector3((X0 + 25.1) * 0.5, H * 0.5, Z1 - 0.175), Vector3(25.1 - X0, H, 0.35)])
	walls.append([Vector3((26.9 + X1) * 0.5, H * 0.5, Z1 - 0.175), Vector3(X1 - 26.9, H, 0.35)])
	walls.append([Vector3(26, (2.4 + H) * 0.5, Z1 - 0.175), Vector3(1.8, H - 2.4, 0.35)])
	for wl in walls:
		batch.box(facade, wl[0], wl[1])
		Geo.col_box(body, wl[0], wl[1])
	# цоколь
	batch.box(plinth, Vector3((X0 + 25.1) * 0.5, 0.3, Z1 + 0.05), Vector3(25.1 - X0, 0.6, 0.12))
	batch.box(plinth, Vector3((26.9 + X1) * 0.5, 0.3, Z1 + 0.05), Vector3(X1 - 26.9, 0.6, 0.12))
	# крыша и парапет
	batch.box(roofm, Vector3((X0 + X1) * 0.5, H + 0.15, (Z0 + Z1) * 0.5), Vector3(X1 - X0 + 0.4, 0.3, Z1 - Z0 + 0.4))
	batch.box(snow, Vector3((X0 + X1) * 0.5, H + 0.33, (Z0 + Z1) * 0.5), Vector3(X1 - X0, 0.06, Z1 - Z0))
	batch.box(facade, Vector3((X0 + X1) * 0.5, H + 0.5, Z1 + 0.1), Vector3(X1 - X0 + 0.4, 0.7, 0.3))
	# карниз-фриз над входом и козырёк
	batch.box(facade, Vector3(26, 2.75, Z1 + 1.2), Vector3(4.0, 0.2, 2.4))
	batch.box(snow, Vector3(26, 2.88, Z1 + 1.2), Vector3(3.9, 0.06, 2.3))
	for xx in [24.3, 27.7]:
		batch.cyl(facade, Vector3(xx, 0, Z1 + 2.2), Vector3(xx, 2.65, Z1 + 2.2), 0.12, 10)
		Geo.col_box(body, Vector3(xx, 1.3, Z1 + 2.2), Vector3(0.25, 2.6, 0.25))
	# крыльцо
	batch.box(Mat.m("concrete"), Vector3(26, 0.075, Z1 + 1.2), Vector3(4.0, 0.15, 2.4))
	# труба котельной
	var chim := Mat.m("brick_dark", {"tint": Color(0.8, 0.7, 0.65)})
	batch.cyl(chim, Vector3(24, -1, -14), Vector3(24, 24, -14), 1.1, 14)
	batch.cyl(chim, Vector3(24, 24, -14), Vector3(24, 24.6, -14), 1.25, 14, true)
	# пристройка котельной (над подвалом)
	batch.box(facade, Vector3(24, 1.6, -9), Vector3(17, 3.2, 18))
	batch.box(roofm, Vector3(24, 3.3, -9), Vector3(17.4, 0.2, 18.4))
	# земля: снег перед баней и по бокам
	var grounds := [
		Rect2(-40, Z1, 132, 50), Rect2(-40, -40, 39.65, 70.35 + 0.0), Rect2(X1, -40, 40, 70.35),
	]
	for g: Rect2 in grounds:
		var c := Vector3(g.get_center().x, -0.25, g.get_center().y)
		batch.box(snow, c, Vector3(g.size.x, 0.5, g.size.y))
		Geo.col_box(body, c, Vector3(g.size.x, 0.5, g.size.y))
	# сугробы вдоль стены
	for i in 14:
		var xx := -1.0 + i * 4.0
		if absf(xx - 26) < 3.5:
			continue
		batch.box(snow, Vector3(xx, 0.15, Z1 + 0.5), Vector3(3.6, 0.3 + randf() * 0.15, 0.9), Basis(Vector3.UP, randf_range(-0.05, 0.05)))
	batch.commit(ext, "ext")
	# невидимые границы двора
	for b in [[Vector3(26, 2, 52), Vector3(80, 4, 1)], [Vector3(-8, 2, 40), Vector3(1, 4, 25)],
			[Vector3(60, 2, 40), Vector3(1, 4, 25)]]:
		Geo.col_box(body, b[0], b[1])
	# окна фасада (светятся изнутри)
	var win_warm := Mat.flat(Color(0.25, 0.12, 0.05), 0.4, 0.0, {"emission": Color(1.0, 0.45, 0.15), "emission_energy": 0.9})
	var win_dark := Mat.flat(Color(0.03, 0.035, 0.05), 0.15, 0.0)
	for wx in [19.0, 33.0]:
		batch.box(win_dark, Vector3(wx, 2.0, Z1 + 0.01), Vector3(2.2, 2.0, 0.04))
	for wx in [9.0, 43.0]:
		batch.box(win_dark, Vector3(wx, 2.3, Z1 + 0.01), Vector3(2.0, 1.4, 0.04))
	# боковые окна мыльных светятся оранжевым
	for wz in [12.0, 17.0]:
		batch.box(win_warm, Vector3(X0 - 0.01, 3.2, wz), Vector3(0.04, 1.6, 1.6))
		batch.box(win_warm, Vector3(X1 + 0.01, 3.2, wz), Vector3(0.04, 1.6, 1.6))
	batch.commit(ext, "ext_win")
