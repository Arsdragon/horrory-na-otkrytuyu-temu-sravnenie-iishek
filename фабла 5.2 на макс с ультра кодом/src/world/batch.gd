class_name Batch
extends RefCounted
## Пакетная сборка неподвижной геометрии: все коробки и цилиндры одного материала сливаются в одну поверхность,
## коллизии — в одно тело. UV считаются в метрах (плотность текстуры везде одинакова).

var _tools := {}          # Material -> SurfaceTool
var _order: Array = []    # порядок материалов
var _shapes: Array = []   # [Transform3D, Shape3D]
var origin := Transform3D.IDENTITY   # преобразование, в котором задаются следующие детали


func _tool(m: Material) -> SurfaceTool:
	if not _tools.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[m] = st
		_order.append(m)
	return _tools[m]


func _v(st: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2) -> void:
	st.set_normal(n)
	st.set_uv(uv)
	st.add_vertex(p)


## Четырёхугольник p0..p3 по кругу, нормаль n. UV — проекция на оси u, v (в метрах).
func quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, n: Vector3, m: Material, u: Vector3, v: Vector3, uvrot := false) -> void:
	var st := _tool(m)
	var pts := [origin * p0, origin * p1, origin * p2, origin * p3]
	var nn := (origin.basis * n).normalized()
	var uu := origin.basis * u
	var vv := origin.basis * v
	if ((pts[2] - pts[0]) as Vector3).cross(pts[1] - pts[0]).dot(nn) < 0.0:
		var t: Vector3 = pts[1]
		pts[1] = pts[3]
		pts[3] = t
	var uvs: Array = []
	for p in pts:
		var pv: Vector3 = p
		var a := pv.dot(uu)
		var b := pv.dot(vv)
		uvs.append(Vector2(b, a) if uvrot else Vector2(a, b))
	for i in [0, 1, 2, 0, 2, 3]:
		_v(st, pts[i], nn, uvs[i])


## Треугольник (щипцы крыши). UV — проекция на оси u, v в метрах.
func tri(p0: Vector3, p1: Vector3, p2: Vector3, n: Vector3, m: Material, u: Vector3, v: Vector3) -> void:
	var st := _tool(m)
	var pts := [origin * p0, origin * p1, origin * p2]
	var nn := (origin.basis * n).normalized()
	var uu := origin.basis * u
	var vv := origin.basis * v
	if ((pts[2] - pts[0]) as Vector3).cross(pts[1] - pts[0]).dot(nn) < 0.0:
		var t: Vector3 = pts[1]
		pts[1] = pts[2]
		pts[2] = t
	for p in pts:
		var pv: Vector3 = p
		_v(st, pv, nn, Vector2(pv.dot(uu), pv.dot(vv)))


## Коробка: центр pos, размер size, поворот rot. sides — битовая маска граней (+X -X +Y -Y +Z -Z), по умолчанию все.
func box(pos: Vector3, size: Vector3, m: Material, collide := true, rot := Basis.IDENTITY, uvrot := false, sides := 63) -> void:
	var h := size * 0.5
	var ax := rot.x
	var ay := rot.y
	var az := rot.z
	var c := pos
	if sides & 1:
		_face(c + ax * h.x, -az, -ay, h.z, h.y, ax, m, uvrot)
	if sides & 2:
		_face(c - ax * h.x, az, -ay, h.z, h.y, -ax, m, uvrot)
	if sides & 4:
		_face(c + ay * h.y, ax, az, h.x, h.z, ay, m, uvrot)
	if sides & 8:
		_face(c - ay * h.y, ax, -az, h.x, h.z, -ay, m, uvrot)
	if sides & 16:
		_face(c + az * h.z, ax, -ay, h.x, h.y, az, m, uvrot)
	if sides & 32:
		_face(c - az * h.z, -ax, -ay, h.x, h.y, -az, m, uvrot)
	if collide:
		solid(pos, size, rot)


func _face(c: Vector3, u: Vector3, v: Vector3, hu: float, hv: float, n: Vector3, m: Material, uvrot: bool) -> void:
	quad(c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv, n, m, u, v, uvrot)


## Только коллизия (невидимая стенка, упрощённый объём сложной модели).
func solid(pos: Vector3, size: Vector3, rot := Basis.IDENTITY) -> void:
	var sh := BoxShape3D.new()
	sh.size = size
	_shapes.append([origin * Transform3D(rot, pos), sh])


## Цилиндр вдоль оси Y базиса rot: центр pos, радиус r (r_top — для конуса), высота h.
func cyl(pos: Vector3, r: float, h: float, m: Material, sides := 10, collide := false, rot := Basis.IDENTITY, caps := true, r_top := -1.0) -> void:
	var st := _tool(m)
	var rt := r if r_top < 0.0 else r_top
	var T := origin * Transform3D(rot, pos)
	var ring_b: Array = []
	var ring_t: Array = []
	var norms: Array = []
	for i in sides + 1:
		var a := TAU * float(i) / float(sides)
		var d := Vector3(cos(a), 0.0, sin(a))
		ring_b.append(T * (d * r + Vector3(0, -h * 0.5, 0)))
		ring_t.append(T * (d * rt + Vector3(0, h * 0.5, 0)))
		var slope := (r - rt) / maxf(h, 0.0001)
		norms.append((T.basis * Vector3(d.x, slope, d.z)).normalized())
	var circ := TAU * maxf(r, rt)
	for i in sides:
		var u0 := circ * float(i) / float(sides)
		var u1 := circ * float(i + 1) / float(sides)
		var b0: Vector3 = ring_b[i]
		var b1: Vector3 = ring_b[i + 1]
		var t0: Vector3 = ring_t[i]
		var t1: Vector3 = ring_t[i + 1]
		var n0: Vector3 = norms[i]
		var n1: Vector3 = norms[i + 1]
		# снаружи по часовой стрелке
		_v(st, b0, n0, Vector2(u0, h))
		_v(st, t0, n0, Vector2(u0, 0))
		_v(st, t1, n1, Vector2(u1, 0))
		_v(st, b0, n0, Vector2(u0, h))
		_v(st, t1, n1, Vector2(u1, 0))
		_v(st, b1, n1, Vector2(u1, h))
	if caps:
		var up := (T.basis * Vector3.UP).normalized()
		var ct := T * Vector3(0, h * 0.5, 0)
		var cb := T * Vector3(0, -h * 0.5, 0)
		for i in sides:
			var t0: Vector3 = ring_t[i]
			var t1: Vector3 = ring_t[i + 1]
			var b0: Vector3 = ring_b[i]
			var b1: Vector3 = ring_b[i + 1]
			if rt > 0.0005:
				_v(st, ct, up, Vector2(0.5, 0.5) * rt)
				_v(st, t1, up, Vector2(0.5 + cos(TAU * float(i + 1) / sides) * 0.5, 0.5 + sin(TAU * float(i + 1) / sides) * 0.5) * rt)
				_v(st, t0, up, Vector2(0.5 + cos(TAU * float(i) / sides) * 0.5, 0.5 + sin(TAU * float(i) / sides) * 0.5) * rt)
			_v(st, cb, -up, Vector2(0.5, 0.5) * r)
			_v(st, b0, -up, Vector2(0.5 + cos(TAU * float(i) / sides) * 0.5, 0.5 + sin(TAU * float(i) / sides) * 0.5) * r)
			_v(st, b1, -up, Vector2(0.5 + cos(TAU * float(i + 1) / sides) * 0.5, 0.5 + sin(TAU * float(i + 1) / sides) * 0.5) * r)
	if collide:
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r, rt)
		sh.height = h
		_shapes.append([T, sh])


## Балка между двумя точками (стропила, растяжки, трубы): квадратное сечение th.
func beam(a: Vector3, b: Vector3, th: float, m: Material, collide := false, th2 := -1.0) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.001:
		return
	var y := d / ln
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	box((a + b) * 0.5, Vector3(th, ln, th if th2 < 0.0 else th2), m, collide, Basis(x, y, z))


## Труба между двумя точками (круглое сечение).
func pipe(a: Vector3, b: Vector3, r: float, m: Material, sides := 8, collide := false) -> void:
	var d := b - a
	var ln := d.length()
	if ln < 0.001:
		return
	var y := d / ln
	var x := y.cross(Vector3.UP)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y).normalized()
	cyl((a + b) * 0.5, r, ln, m, sides, collide, Basis(x, y, z))


## Собрать меш и тело. Возвращает узел-родитель (Node3D) с MeshInstance3D и StaticBody3D внутри.
func commit(parent: Node3D, node_name := "Batch", shadows := true, layer := 1) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	parent.add_child(root)
	if not _order.is_empty():
		var mesh := ArrayMesh.new()
		for m in _order:
			var st: SurfaceTool = _tools[m]
			st.generate_tangents()
			st.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, m)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		root.add_child(mi)
	if not _shapes.is_empty():
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = layer
		body.collision_mask = 0
		root.add_child(body)
		for s in _shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[1]
			cs.transform = s[0]
			body.add_child(cs)
	_tools.clear()
	_order.clear()
	_shapes.clear()
	return root
