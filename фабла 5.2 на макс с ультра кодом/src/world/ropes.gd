class_name Ropes
extends Node3D
## Леера: столбы с флажками и трос между ними. Хранит отрезки для игрока (взяться, идти вдоль)
## и для существа (оно леер не трогает). Умеет делать разрывы и «дёргать» трос.

const POLE_H := 2.05
const ROPE_Y := 1.18
const SPAN := 5.6
const SAG := 0.15
const RED := Color(0.80, 0.06, 0.04)
const GREY := Color(0.34, 0.33, 0.32)
const FADED := Color(0.42, 0.2, 0.17)

var lines := {}        # id -> Dictionary (см. add_line)
var segs: Array = []   # отрезки между стоящими столбами: {a, b, line, s0, len}
var _rope_tex: Texture2D


func _ready() -> void:
	_rope_tex = Kit.tex("res://tex/rope")


## pts — ключевые точки ломаной (y игнорируется). old — старый перекошенный леер с выцветшими флажками.
func add_line(id: String, pts: Array, title := "", color := RED, old := false) -> void:
	var p := PackedVector3Array()
	for v in pts:
		var q: Vector3 = v
		p.append(Vector3(q.x, 0.0, q.z))
	lines[id] = {"pts": p, "title": title, "color": color, "old": old, "gaps": [], "node": null, "mat": null,
		"poles": PackedVector3Array(), "pole_s": PackedFloat32Array(), "length": 0.0, "hidden": false, "tug": 0.0}
	_layout(id)


func _layout(id: String) -> void:
	var L: Dictionary = lines[id]
	var pts: PackedVector3Array = L.pts
	var poles := PackedVector3Array()
	var pole_s := PackedFloat32Array()
	var s := 0.0
	poles.append(pts[0])
	pole_s.append(0.0)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ln := a.distance_to(b)
		var n := maxi(1, int(ceil(ln / SPAN - 0.15)))
		for k in range(1, n + 1):
			poles.append(a.lerp(b, float(k) / float(n)))
			pole_s.append(s + ln * float(k) / float(n))
		s += ln
	L.poles = poles
	L.pole_s = pole_s
	L.length = s


func length(id: String) -> float:
	return float(lines[id].length)


## Точка на леере в s метрах от начала (по земле).
func point_at(id: String, s: float) -> Vector3:
	var L: Dictionary = lines[id]
	var pts: PackedVector3Array = L.pts
	var acc := 0.0
	for i in pts.size() - 1:
		var ln := pts[i].distance_to(pts[i + 1])
		if s <= acc + ln or i == pts.size() - 2:
			return pts[i].lerp(pts[i + 1], clampf((s - acc) / maxf(ln, 0.001), 0.0, 1.0))
		acc += ln
	return pts[pts.size() - 1]


## Направление леера в точке s (в сторону роста s).
func dir_at(id: String, s: float) -> Vector3:
	var a := point_at(id, maxf(s - 0.5, 0.0))
	var b := point_at(id, minf(s + 0.5, length(id)))
	var d := b - a
	if d.length() < 0.001:
		return Vector3.FORWARD
	return d.normalized()


func set_gap(id: String, from_m: float, to_m: float) -> void:
	(lines[id].gaps as Array).append([from_m, to_m])
	rebuild()


func clear_gaps(id: String) -> void:
	(lines[id].gaps as Array).clear()
	rebuild()


func set_hidden(id: String, hidden: bool) -> void:
	if bool(lines[id].hidden) != hidden:
		lines[id].hidden = hidden
		rebuild()


func set_color(id: String, c: Color) -> void:
	lines[id].color = c
	rebuild()


func tug(id: String, strength: float) -> void:
	lines[id].tug = strength
	var m: ShaderMaterial = lines[id].mat
	if m != null:
		m.set_shader_parameter("tug", strength)


func _in_gap(L: Dictionary, s: float) -> bool:
	for g in L.gaps:
		if s > float(g[0]) and s < float(g[1]):
			return true
	return false


func build() -> void:
	rebuild()


func rebuild() -> void:
	segs.clear()
	for id in lines:
		var L: Dictionary = lines[id]
		if L.node != null and is_instance_valid(L.node):
			(L.node as Node3D).queue_free()
			L.node = null
		if bool(L.hidden):
			continue
		_build_line(String(id))


func _build_line(id: String) -> void:
	var L: Dictionary = lines[id]
	var root := Node3D.new()
	root.name = "Line_" + id
	add_child(root)
	L.node = root
	var poles: PackedVector3Array = L.poles
	var pole_s: PackedFloat32Array = L.pole_s
	var old: bool = L.old
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var standing: Array = []    # индексы стоящих столбов
	var fallen: Array = []
	for i in poles.size():
		if _in_gap(L, pole_s[i]):
			fallen.append(i)
		else:
			standing.append(i)

	# столбы
	var wood := Kit.flat(Color(0.2, 0.165, 0.13), 0.92)
	var band := Kit.flat(Color(0.86, 0.86, 0.82), 0.5)
	var pm := BoxMesh.new()
	pm.size = Vector3(0.085, POLE_H + 0.5, 0.085)
	pm.material = wood
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = pm
	mm.instance_count = poles.size()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.095, 0.14, 0.095)
	bm.material = band
	var mmb := MultiMesh.new()
	mmb.transform_format = MultiMesh.TRANSFORM_3D
	mmb.mesh = bm
	mmb.instance_count = standing.size()
	var tops := {}      # индекс столба -> точка крепления троса (верх с учётом наклона)
	var bi := 0
	for i in poles.size():
		var p := poles[i]
		var t: Transform3D
		if i in fallen:
			# упавший столб лежит в снегу
			var b := Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(80.0, 88.0)))
			t = Transform3D(b, p + Vector3(rng.randf_range(-0.6, 0.6), 0.06, rng.randf_range(-0.6, 0.6)))
		else:
			var tilt := Basis.IDENTITY
			if old:
				tilt = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(2.0, 13.0)))
			else:
				tilt = Basis(Vector3.UP, rng.randf_range(0.0, TAU)) * Basis(Vector3.RIGHT, deg_to_rad(rng.randf_range(0.0, 2.5)))
			t = Transform3D(tilt, p) * Transform3D(Basis.IDENTITY, Vector3(0, (POLE_H - 0.5) * 0.5, 0))
			tops[i] = p + tilt * Vector3(0, ROPE_Y, 0)
			mmb.set_instance_transform(bi, Transform3D(tilt, p) * Transform3D(Basis.IDENTITY, Vector3(0, POLE_H - 0.12, 0)))
			bi += 1
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	root.add_child(mmi)
	var mmbi := MultiMeshInstance3D.new()
	mmbi.multimesh = mmb
	mmbi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmbi)

	# флажки (вытянуты по ветру)
	var fm := PlaneMesh.new()
	fm.size = Vector2(0.44, 0.27)
	fm.subdivide_width = 5
	fm.orientation = PlaneMesh.FACE_Z
	fm.center_offset = Vector3(0.22, 0.0, 0.0)
	var fmat := ShaderMaterial.new()
	fmat.shader = load("res://src/shaders/flag.gdshader")
	fm.material = fmat
	var flags: Array = []
	for i in standing:
		if old and rng.randf() < 0.45:
			continue
		flags.append(i)
	var mmf := MultiMesh.new()
	mmf.transform_format = MultiMesh.TRANSFORM_3D
	mmf.use_colors = true
	mmf.mesh = fm
	mmf.instance_count = flags.size()
	var wd := Weather.WIND_DIR
	var fb := Basis(wd, Vector3.UP, wd.cross(Vector3.UP).normalized())
	var col: Color = L.color
	for k in flags.size():
		var i: int = flags[k]
		var top: Vector3 = tops[i]
		var up := (top - poles[i]).normalized()
		mmf.set_instance_transform(k, Transform3D(fb, poles[i] + up * (POLE_H - 0.36) + wd * 0.05))
		var c := col
		if old:
			c = col.lerp(Color(0.3, 0.27, 0.25), rng.randf_range(0.2, 0.6))
		mmf.set_instance_color(k, c)
	var mmfi := MultiMeshInstance3D.new()
	mmfi.multimesh = mmf
	mmfi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmfi)

	# трос
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any := false
	for k in standing.size() - 1:
		var i0: int = standing[k]
		var i1: int = standing[k + 1]
		if i1 != i0 + 1:
			# разрыв: концы троса свисают в снег
			_loose_end(st, tops[i0], (poles[i1] - poles[i0]).normalized(), rng)
			_loose_end(st, tops[i1], (poles[i0] - poles[i1]).normalized(), rng)
			any = true
			continue
		_span(st, tops[i0], tops[i1])
		any = true
		segs.append({"a": poles[i0], "b": poles[i1], "line": id, "s0": pole_s[i0], "len": poles[i0].distance_to(poles[i1])})
	if any:
		st.generate_tangents()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var rm := ShaderMaterial.new()
		rm.shader = load("res://src/shaders/rope.gdshader")
		rm.set_shader_parameter("tex", _rope_tex)
		rm.set_shader_parameter("tug", float(L.tug))
		mi.material_override = rm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		L.mat = rm


func _span(st: SurfaceTool, a: Vector3, b: Vector3) -> void:
	var n := 6
	var prev := a
	var prev_k := 0.0
	var acc := 0.0
	for i in range(1, n + 1):
		var t := float(i) / float(n)
		var k := 4.0 * t * (1.0 - t)
		var p := a.lerp(b, t) - Vector3(0, SAG * k, 0)
		_tube(st, prev, p, prev_k, k, acc)
		acc += prev.distance_to(p)
		prev = p
		prev_k = k


func _loose_end(st: SurfaceTool, top: Vector3, dir: Vector3, rng: RandomNumberGenerator) -> void:
	var side := dir.cross(Vector3.UP).normalized() * rng.randf_range(-0.4, 0.4)
	var mid := top + dir * 0.5 + side * 0.5 - Vector3(0, top.y * 0.55, 0)
	var end := Vector3(top.x, 0.03, top.z) + dir * rng.randf_range(1.2, 2.0) + side
	_tube(st, top, mid, 0.0, 0.6, 0.0)
	_tube(st, mid, end, 0.6, 0.0, 0.7)


func _tube(st: SurfaceTool, a: Vector3, b: Vector3, ka: float, kb: float, v0: float) -> void:
	var r := 0.012
	var d := b - a
	var ln := d.length()
	if ln < 0.0001:
		return
	var y := d / ln
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	var offs := [x * r, z * r, -x * r, -z * r]
	for i in 4:
		var o0: Vector3 = offs[i]
		var o1: Vector3 = offs[(i + 1) % 4]
		var nrm := (o0 + o1).normalized()
		var u0 := float(i) * 0.25
		var u1 := float(i + 1) * 0.25
		var va := v0 * 8.0
		var vb := (v0 + ln) * 8.0
		var quad := [[a + o0, ka, Vector2(u0, va)], [b + o0, kb, Vector2(u0, vb)], [b + o1, kb, Vector2(u1, vb)], [a + o1, ka, Vector2(u1, va)]]
		var order := [0, 1, 2, 0, 2, 3]
		var p0: Vector3 = quad[0][0]
		var p1: Vector3 = quad[1][0]
		var p2: Vector3 = quad[2][0]
		if (p2 - p0).cross(p1 - p0).dot(nrm) < 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for j in order:
			var q: Array = quad[j]
			st.set_normal(nrm)
			st.set_color(Color(float(q[1]), 0, 0))
			st.set_uv(q[2])
			st.add_vertex(q[0])


## Ближайшая точка леера к pos (по земле). Возвращает {} или {d, p, dir, line, s, seg}.
func nearest(pos: Vector3, max_d := 3.0, prefer := "") -> Dictionary:
	var best := {}
	var best_d := max_d
	var p2 := Vector2(pos.x, pos.z)
	for i in segs.size():
		var sg: Dictionary = segs[i]
		var a: Vector3 = sg.a
		var b: Vector3 = sg.b
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var ab := b2 - a2
		var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var c := a2 + ab * t
		var d := p2.distance_to(c)
		if prefer != "" and String(sg.line) == prefer:
			d -= 0.35
		if d < best_d:
			best_d = d
			best = {"d": maxf(d, 0.0), "p": Vector3(c.x, 0.0, c.y), "dir": Vector3(ab.x, 0.0, ab.y).normalized(),
				"line": sg.line, "s": float(sg.s0) + float(sg.len) * t, "seg": i, "t": t}
	return best


## Есть ли трос в точке s этого леера (не разрыв и не за концом).
func s_ok(id: String, s: float) -> bool:
	for sg in segs:
		var d: Dictionary = sg
		if String(d.line) == id and s >= float(d.s0) - 0.02 and s <= float(d.s0) + float(d.len) + 0.02:
			return true
	return false


## Ближайшие точки на каждом леере рядом с pos (для развязок: игрок выбирает трос, вдоль которого смотрит).
func near_all(pos: Vector3, max_d := 1.75) -> Array:
	var out: Array = []
	for id in lines:
		if bool(lines[id].hidden):
			continue
		var best := {}
		var best_d := max_d
		var p2 := Vector2(pos.x, pos.z)
		for i in segs.size():
			var sg: Dictionary = segs[i]
			if String(sg.line) != String(id):
				continue
			var a: Vector3 = sg.a
			var b: Vector3 = sg.b
			var a2 := Vector2(a.x, a.z)
			var ab := Vector2(b.x, b.z) - a2
			var t := clampf((p2 - a2).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
			var c := a2 + ab * t
			var d := p2.distance_to(c)
			if d < best_d:
				best_d = d
				best = {"d": d, "p": Vector3(c.x, 0.0, c.y), "dir": Vector3(ab.x, 0.0, ab.y).normalized(), "line": String(id),
					"s": float(sg.s0) + float(sg.len) * t, "seg": i, "t": t}
		if not best.is_empty():
			out.append(best)
	return out


## Табличка-указатель на столбе: текст с обеих сторон.
func add_sign(pos: Vector3, yaw_deg: float, text: String, height := 1.62) -> void:
	var n := Node3D.new()
	n.transform = Transform3D(Kit.yaw(yaw_deg), pos + Vector3(0, height, 0))
	add_child(n)
	var board := Kit.flat(Color(0.72, 0.7, 0.62), 0.85)
	var w := maxf(0.5, 0.062 * text.length() + 0.16)
	Kit.box_node(n, Vector3.ZERO, Vector3(w, 0.2, 0.025), board, false)
	Kit.label(n, Vector3(0, 0, 0.014), text, 0.085, Color(0.07, 0.06, 0.05), "head")
	Kit.label(n, Vector3(0, 0, -0.014), text, 0.085, Color(0.07, 0.06, 0.05), "head", Kit.yaw(180))
