class_name Geo
## Построение геометрии: пакет мешей (один MeshInstance на материал), коллизии, примитивы.


class Batch:
	var tools := {}      # Material -> SurfaceTool
	var order: Array = []

	func _st(mat: Material) -> SurfaceTool:
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
			order.append(mat)
		return tools[mat]

	func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
		var st := _st(mat)
		var verts := [a, b, c]
		var uvs := [ua, ub, uc]
		if (b - a).cross(c - a).dot(n) > 0.0:
			verts = [a, c, b]
			uvs = [ua, uc, ub]
		for i in 3:
			st.set_normal(n)
			st.set_uv(uvs[i])
			st.add_vertex(verts[i])

	## Четырёхугольник a-b-c-d (по кругу), n — куда смотрит лицевая сторона.
	func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv := Rect2(0, 0, 1, 1)) -> void:
		var u0 := uv.position
		var u1 := uv.position + Vector2(uv.size.x, 0)
		var u2 := uv.position + uv.size
		var u3 := uv.position + Vector2(0, uv.size.y)
		tri(mat, a, b, c, n, u0, u1, u2)
		tri(mat, a, c, d, n, u0, u2, u3)

	## Коробка по центру и размеру; xf — дополнительный поворот вокруг центра.
	## unit_uv: каждая грань 0..1 (для табличек), иначе UV в метрах.
	func box(mat: Material, center: Vector3, size: Vector3, xf := Basis.IDENTITY, unit_uv := false, skip := []) -> void:
		var h := size * 0.5
		var faces := [
			[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0), h.x, h.z, h.y],
			[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0), h.x, h.z, h.y],
			[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1), h.y, h.x, h.z],
			[Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1), h.y, h.x, h.z],
			[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0), h.z, h.x, h.y],
			[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0), h.z, h.x, h.y],
		]
		for fi in 6:
			if fi in skip:
				continue
			var f: Array = faces[fi]
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var dn: float = f[3]
			var du: float = f[4]
			var dv: float = f[5]
			var c := n * dn
			var pa := c - u * du - v * dv
			var pb := c + u * du - v * dv
			var pc := c + u * du + v * dv
			var pd := c - u * du + v * dv
			var uv := Rect2(0, 1, 1, -1) if unit_uv else Rect2(0, 0, du * 2.0, dv * 2.0)
			quad(mat, center + xf * pa, center + xf * pb, center + xf * pc, center + xf * pd, (xf * n).normalized(), uv)

	## Цилиндр (труба) между точками a и b.
	func cyl(mat: Material, a: Vector3, b: Vector3, r: float, segs := 10, caps := false) -> void:
		var axis := b - a
		var len := axis.length()
		if len < 0.001:
			return
		var w := axis / len
		var t := Vector3.UP if absf(w.y) < 0.9 else Vector3.RIGHT
		var u := w.cross(t).normalized()
		var v := w.cross(u).normalized()
		for i in segs:
			var a0 := TAU * i / segs
			var a1 := TAU * (i + 1) / segs
			var n0 := u * cos(a0) + v * sin(a0)
			var n1 := u * cos(a1) + v * sin(a1)
			var st := _st(mat)
			var pts := [a + n0 * r, a + n1 * r, b + n1 * r, b + n0 * r]
			var nrm := [n0, n1, n1, n0]
			var uvs := [Vector2(float(i) / segs, 0), Vector2(float(i + 1) / segs, 0), Vector2(float(i + 1) / segs, len), Vector2(float(i) / segs, len)]
			var order := [0, 1, 2, 0, 2, 3]
			if (pts[1] - pts[0]).cross(pts[2] - pts[0]).dot(n0 + n1) > 0.0:
				order = [0, 2, 1, 0, 3, 2]
			for k in order:
				st.set_normal(nrm[k])
				st.set_uv(uvs[k])
				st.add_vertex(pts[k])
			if caps:
				tri(mat, a, a + n0 * r, a + n1 * r, -w, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
				tri(mat, b, b + n0 * r, b + n1 * r, w, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)

	func commit(parent: Node3D, name := "geo", shadows := true) -> Array:
		var out := []
		for mat in order:
			var st: SurfaceTool = tools[mat]
			var tri := mat is BaseMaterial3D and (mat as BaseMaterial3D).uv1_triplanar
			if not tri:
				st.generate_tangents()
			var mi := MeshInstance3D.new()
			mi.name = name
			mi.mesh = st.commit()
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			out.append(mi)
		tools.clear()
		order.clear()
		return out


## Коллизионная коробка в теле body.
static func col_box(body: CollisionObject3D, center: Vector3, size: Vector3, xf := Basis.IDENTITY) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	cs.transform = Transform3D(xf, center)
	body.add_child(cs)
	return cs


static func static_body(parent: Node, name := "col", layer := 1) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = name
	b.collision_layer = layer
	b.collision_mask = 0
	parent.add_child(b)
	return b


## Отдельный меш-ящик (для подвижных вещей).
static func mesh_box(parent: Node3D, size: Vector3, mat: Material, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func mesh_cyl(parent: Node3D, r: float, h: float, mat: Material, pos := Vector3.ZERO, segs := 16, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label3d(parent: Node3D, text: String, pos: Vector3, size := 0.05, col := Color(0.1, 0.1, 0.1), font_path := "res://fonts/PTSansNarrow-Bold.ttf") -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.pixel_size = size / 32.0
	l.font_size = 64
	l.modulate = col
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	var f: Font = load(font_path) if ResourceLoader.exists(font_path) else null
	if f:
		l.font = f
	parent.add_child(l)
	return l
