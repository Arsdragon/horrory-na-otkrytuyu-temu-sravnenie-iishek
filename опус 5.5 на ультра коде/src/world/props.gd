class_name Props
## Мебель и предметы: общие помощники. Сами комнаты — PropsGround (первый этаж) и PropsBase (подвал, улица).

static var _models := {}


static func furnish(w: Node3D) -> void:
	PropsGround.build(w)
	PropsBase.build(w)
	PropsBase.exterior(w)


## Угол поворота (rotation.y), чтобы «перед» (-Z) смотрел в направлении dir.
static func yaw_to(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


## Модель Poly Haven (CC0) из mdl/ph/<id>.
static func model(parent: Node3D, id: String, pos: Vector3, yaw := 0.0, sc := 1.0, solid := false) -> Node3D:
	var path := "res://mdl/ph/%s/%s.gltf" % [id, id]
	if not _models.has(path):
		_models[path] = load(path) if ResourceLoader.exists(path) else null
	var ps: PackedScene = _models[path]
	if ps == null:
		return Node3D.new()
	var n: Node3D = ps.instantiate()
	parent.add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * sc
	if solid:
		# коробка по габаритам модели в её собственных осях
		var inv := n.global_transform.affine_inverse()
		var la := AABB()
		var first := true
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var mi := c as MeshInstance3D
			var a := inv * (mi.global_transform * mi.get_aabb())
			la = a if first else la.merge(a)
			first = false
		if not first and la.size.length() > 0.01:
			var bd := StaticBody3D.new()
			bd.collision_layer = 1
			n.add_child(bd)
			var cs := CollisionShape3D.new()
			var sh := BoxShape3D.new()
			sh.size = la.size
			cs.shape = sh
			cs.position = la.get_center()
			bd.add_child(cs)
	return n


static func _aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for c in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		var a := mi.global_transform * mi.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out


## Картинка на стене (табличка, плакат, фото). normal — куда смотрит лицо.
static func picture(parent: Node3D, tex: String, pos: Vector3, normal: Vector3, size: Vector2, opts := {}) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = Mat.picture(tex, opts)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = pos + normal * 0.012
	mi.rotation.y = yaw_to(-normal)
	return mi


## Трап (сливная решётка в полу) — отсюда она выходит.
static func drain(w: World, b: Geo.Batch, pos: Vector3, room: String, register := true) -> void:
	var grate := Mat.m("grate", {"metal": 0.6, "scale": 0.4})
	b.box(grate, pos + Vector3(0, 0.005, 0), Vector3(0.28, 0.012, 0.28))
	b.box(Mat.flat(Color(0.02, 0.02, 0.02), 0.9), pos + Vector3(0, 0.002, 0), Vector3(0.32, 0.006, 0.32))
	if register:
		w.drains.append({"pos": pos, "room": room})


## Соль на пороге: белая полоса.
static func salt(b: Geo.Batch, center: Vector3, along_x: bool, length: float) -> void:
	var m := Mat.flat(Color(0.86, 0.85, 0.82), 0.95)
	var n := int(length / 0.08)
	for i in n:
		var t := -length * 0.5 + (i + 0.5) * length / n
		var off := Vector3(t, 0.006, randf_range(-0.04, 0.04)) if along_x else Vector3(randf_range(-0.04, 0.04), 0.006, t)
		var s := Vector3(0.09, 0.012, randf_range(0.06, 0.12)) if along_x else Vector3(randf_range(0.06, 0.12), 0.012, 0.09)
		b.box(m, center + off, s)


## Деревянная скамья (простая).
static func bench(b: Geo.Batch, body: StaticBody3D, pos: Vector3, length: float, along_x: bool, back := false, mat: Material = null) -> void:
	var m := mat if mat else Mat.m("planks_weather", {"tint": Color(0.85, 0.75, 0.6), "scale": 1.2})
	var leg := Mat.flat(Color(0.18, 0.2, 0.18), 0.6, 0.6)
	var sz := Vector3(length, 0.05, 0.42) if along_x else Vector3(0.42, 0.05, length)
	b.box(m, pos + Vector3(0, 0.45, 0), sz)
	var n := maxi(2, int(length / 1.5) + 1)
	for i in n:
		var t := -length * 0.5 + 0.1 + i * (length - 0.2) / (n - 1)
		var lp := pos + (Vector3(t, 0.22, 0) if along_x else Vector3(0, 0.22, t))
		b.box(leg, lp, Vector3(0.05, 0.44, 0.38) if along_x else Vector3(0.38, 0.44, 0.05))
	if back:
		var bp := pos + (Vector3(0, 0.95, 0.2) if along_x else Vector3(0.2, 0.95, 0))
		b.box(m, bp, Vector3(length, 0.9, 0.04) if along_x else Vector3(0.04, 0.9, length))
	if body:
		Geo.col_box(body, pos + Vector3(0, 0.25, 0), Vector3(sz.x, 0.5, sz.z))


## Ряд декоративных шкафчиков вдоль стены. normal — куда смотрят дверцы.
static func lockers(b: Geo.Batch, body: StaticBody3D, start: Vector3, count: int, dir: Vector3, normal: Vector3, tint := Color(0.75, 0.82, 0.78)) -> void:
	var m := Mat.m("metal_green", {"metal": 0.4, "tint": tint, "scale": 1.2})
	var dark := Mat.flat(Color(0.05, 0.05, 0.05), 0.8)
	var W := 0.45
	for i in count:
		var c := start + dir * (W * (i + 0.5))
		var size := Vector3(W - 0.01, 1.85, 0.5) if absf(dir.x) > 0.5 else Vector3(0.5, 1.85, W - 0.01)
		b.box(m, c + Vector3(0, 0.925, 0), size)
		for k in 4:
			b.box(dark, c + normal * 0.252 + Vector3(0, 1.45 + k * 0.04, 0), Vector3(W * 0.5, 0.012, 0.004) if absf(dir.x) > 0.5 else Vector3(0.004, 0.012, W * 0.5))
		b.box(Mat.flat(Color(0.5, 0.5, 0.45), 0.4, 0.9), c + normal * 0.255 + dir * (W * 0.35) + Vector3(0, 1.0, 0), Vector3(0.02, 0.08, 0.02))
	if body:
		var total := W * count
		var cc := start + dir * total * 0.5 + Vector3(0, 0.925, 0)
		Geo.col_box(body, cc, Vector3(total, 1.85, 0.5) if absf(dir.x) > 0.5 else Vector3(0.5, 1.85, total))


## Каменная (кафельная) лавка мыльной.
static func stone_bench(b: Geo.Batch, body: StaticBody3D, pos: Vector3, length: float, along_x: bool) -> void:
	var top := Mat.m("tile_dark", {"wet": 0.7, "scale": 1.0, "tint": Color(1.1, 1.1, 1.1)})
	var side := Mat.m("tile_wall", {"wet": 0.4})
	var sz := Vector3(length, 0.5, 0.6) if along_x else Vector3(0.6, 0.5, length)
	b.box(side, pos + Vector3(0, 0.22, 0), sz - Vector3(0.06, 0.06, 0.06))
	b.box(top, pos + Vector3(0, 0.48, 0), Vector3(sz.x, 0.06, sz.z))
	if body:
		Geo.col_box(body, pos + Vector3(0, 0.25, 0), sz)


## Металлический стеллаж: стойки и полки. along_x — длинная сторона вдоль x.
static func shelves(b: Geo.Batch, body: StaticBody3D, pos: Vector3, length: float, depth: float, height: float, levels: int, along_x := true) -> void:
	var m := Mat.m("metal_green", {"metal": 0.5, "tint": Color(0.55, 0.58, 0.55), "scale": 1.0})
	var lx := length if along_x else depth
	var lz := depth if along_x else length
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			b.box(m, pos + Vector3(sx * (lx - 0.04), height * 0.5, sz * (lz - 0.04)), Vector3(0.04, height, 0.04))
	for i in levels:
		var y := 0.12 + i * (height - 0.2) / maxf(1.0, levels - 1)
		b.box(m, pos + Vector3(0, y, 0), Vector3(lx, 0.025, lz))
	if body:
		Geo.col_box(body, pos + Vector3(0, height * 0.5, 0), Vector3(lx, height, lz))


## Труба вдоль пути.
static func pipe(b: Geo.Batch, pts: Array, r: float, mat: Material = null) -> void:
	var m := mat if mat else Mat.m("rust", {"metal": 0.5, "scale": 1.0})
	for i in range(1, pts.size()):
		b.cyl(m, pts[i - 1], pts[i], r, 10)
	for i in range(1, pts.size() - 1):
		b.box(m, pts[i], Vector3.ONE * r * 2.3)


## Кран на стене + полочка. Возвращает Tap.
static func wall_tap(w: World, room: String, pos: Vector3, normal: Vector3, line: String) -> Tap:
	var y0: float = w.rooms[room]["y"]
	return Tap.make(w.rooms[room]["node"], pos, yaw_to(normal), false, line, room, y0)


static func shower(w: World, room: String, pos: Vector3, normal: Vector3, line: String) -> Tap:
	var y0: float = w.rooms[room]["y"]
	return Tap.make(w.rooms[room]["node"], pos, yaw_to(normal), true, line, room, y0)


## Мокрые босые следы (декали).
static func footprints(parent: Node3D, from: Vector3, to: Vector3, tag := "") -> Node3D:
	var n := Node3D.new()
	n.name = "footprints_" + tag
	parent.add_child(n)
	var d := to - from
	d.y = 0
	var len := d.length()
	var dir := d.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	var steps := int(len / 0.62)
	var tex: Texture2D = Mat.tex("res://tex/gen/footprint.png")
	for i in steps:
		var dc := Decal.new()
		dc.size = Vector3(0.16, 0.2, 0.34)
		dc.texture_albedo = tex
		dc.modulate = Color(0.25, 0.27, 0.28, 0.85)
		dc.albedo_mix = 0.9
		dc.cull_mask = 1
		n.add_child(dc)
		var lr := 1.0 if i % 2 == 0 else -1.0
		dc.global_position = from + dir * (0.3 + i * 0.62) + side * lr * 0.12 + Vector3(0, 0.05, 0)
		dc.rotation.y = yaw_to(dir) + PI
		dc.scale.x = lr
	return n


## Комок волос (свисает с потолка или лежит).
static func hair_clump(parent: Node3D, pos: Vector3, length := 1.0, hanging := true) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = Mat.tex("res://tex/ui/hair.png")
	m.albedo_color = Color(0.25, 0.23, 0.22)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.25
	for k in 3:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.35, length)
		mi.mesh = qm
		mi.material_override = m
		parent.add_child(mi)
		if hanging:
			mi.global_position = pos - Vector3(0, length * 0.5, 0)
			mi.rotation.y = k * PI / 3.0
		else:
			mi.global_position = pos + Vector3(0, 0.01 + k * 0.003, 0)
			mi.rotation = Vector3(-PI * 0.5, k * 1.1, 0)


## Надпись-подсказка рядом с предметом, читаемая записка на стене.
static func wall_note(parent: Node3D, id: String, pos: Vector3, normal: Vector3, size := Vector2(0.3, 0.4), label := "Прочитать") -> Usable:
	picture(parent, "res://tex/gen/note_%s.png" % id, pos, normal, size)
	var u := Usable.make(parent, pos + normal * 0.05, Vector3(size.x, size.y, 0.1), label, func():
		Game.add_note(id)
		if Game.main and Game.main.has_method("show_note"):
			Game.main.show_note(id))
	u.rotation.y = yaw_to(-normal)
	return u
