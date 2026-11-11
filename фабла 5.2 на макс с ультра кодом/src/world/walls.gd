class_name Walls
extends RefCounted
## Стены с проёмами. Стена — два слоя по полтолщины: у каждой стороны свой материал.
## holes — проёмы [центр вдоль стены, ширина, низ, верх].


## Стена вдоль оси X в плоскости z. m_neg смотрит в −Z, m_pos — в +Z.
static func wall_x(b: Batch, z: float, x0: float, x1: float, y0: float, y1: float, th: float, m_neg: Material, m_pos: Material, holes: Array, rot_neg := false, rot_pos := false) -> void:
	for pc in _pieces(x0, x1, y0, y1, holes):
		var r: Rect2 = pc
		var cx := r.position.x + r.size.x * 0.5
		var cy := r.position.y + r.size.y * 0.5
		b.box(Vector3(cx, cy, z - th * 0.25), Vector3(r.size.x, r.size.y, th * 0.5), m_neg, false, Basis.IDENTITY, rot_neg)
		b.box(Vector3(cx, cy, z + th * 0.25), Vector3(r.size.x, r.size.y, th * 0.5), m_pos, false, Basis.IDENTITY, rot_pos)
		b.solid(Vector3(cx, cy, z), Vector3(r.size.x, r.size.y, th))


## Стена вдоль оси Z в плоскости x. m_neg смотрит в −X, m_pos — в +X.
static func wall_z(b: Batch, x: float, z0: float, z1: float, y0: float, y1: float, th: float, m_neg: Material, m_pos: Material, holes: Array, rot_neg := false, rot_pos := false) -> void:
	for pc in _pieces(z0, z1, y0, y1, holes):
		var r: Rect2 = pc
		var cz := r.position.x + r.size.x * 0.5
		var cy := r.position.y + r.size.y * 0.5
		b.box(Vector3(x - th * 0.25, cy, cz), Vector3(th * 0.5, r.size.y, r.size.x), m_neg, false, Basis.IDENTITY, rot_neg)
		b.box(Vector3(x + th * 0.25, cy, cz), Vector3(th * 0.5, r.size.y, r.size.x), m_pos, false, Basis.IDENTITY, rot_pos)
		b.solid(Vector3(x, cy, cz), Vector3(th, r.size.y, r.size.x))


## Разбивает стену на прямоугольники вокруг проёмов. Возвращает Rect2(вдоль, низ, длина, высота).
static func _pieces(a0: float, a1: float, y0: float, y1: float, holes: Array) -> Array:
	var out: Array = []
	var hs := holes.duplicate()
	hs.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var cur := a0
	for h in hs:
		var c := float(h[0])
		var w := float(h[1])
		var hb := float(h[2])
		var ht := float(h[3])
		var l := c - w * 0.5
		var r := c + w * 0.5
		if l > cur + 0.001:
			out.append(Rect2(cur, y0, l - cur, y1 - y0))
		if hb > y0 + 0.001:
			out.append(Rect2(l, y0, w, hb - y0))
		if ht < y1 - 0.001:
			out.append(Rect2(l, ht, w, y1 - ht))
		cur = r
	if a1 > cur + 0.001:
		out.append(Rect2(cur, y0, a1 - cur, y1 - y0))
	return out


## Окно в стене: рама, переплёт, замёрзшее стекло. along — "x" (стена вдоль X) или "z"; out_dir — наружу.
## Снаружи стекло светится тёплым (гаснет вместе с дизелем), изнутри — тёмное, в инее.
## Возвращает материал наружной стороны.
static func window(root: Node3D, b: Batch, c: Vector3, along: String, w: float, h: float, th: float, out_dir: Vector3) -> StandardMaterial3D:
	var wood := Kit.flat(Color(0.5, 0.48, 0.42), 0.8)
	var fr := 0.05
	var d := th + 0.04
	var ax := Vector3.RIGHT if along == "x" else Vector3.BACK
	var sz := func(len_along: float, hgt: float) -> Vector3:
		return Vector3(len_along, hgt, d) if along == "x" else Vector3(d, hgt, len_along)
	b.box(c + Vector3(0, h * 0.5 + fr * 0.5, 0), sz.call(w + fr * 2.0, fr), wood, false)
	b.box(c - Vector3(0, h * 0.5 + fr * 0.5, 0), sz.call(w + fr * 2.0, fr + 0.02), wood, false)
	b.box(c + ax * (w * 0.5 + fr * 0.5), sz.call(fr, h), wood, false)
	b.box(c - ax * (w * 0.5 + fr * 0.5), sz.call(fr, h), wood, false)
	var thin := Vector3(0.03, h, 0.04) if along == "x" else Vector3(0.04, h, 0.03)
	b.box(c, thin, wood, false)
	b.box(c + Vector3(0, h * 0.12, 0), (Vector3(w, 0.03, 0.04) if along == "x" else Vector3(0.04, 0.03, w)), wood, false)
	var tex := Kit.tex("res://tex/glassfrost")
	var inner := StandardMaterial3D.new()
	inner.albedo_texture = tex
	inner.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner.roughness = 0.35
	inner.metallic_specular = 0.5
	var outer := StandardMaterial3D.new()
	outer.albedo_texture = tex
	outer.albedo_color = Color(1.0, 0.86, 0.66)
	outer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	outer.roughness = 0.4
	outer.emission_enabled = true
	outer.emission = Color(1.0, 0.7, 0.36)
	outer.emission_energy_multiplier = 0.7
	# плоскость смотрит по +Z своего базиса: одну разворачиваем наружу, другую внутрь
	var o := out_dir.normalized()
	var rot_out := Basis.looking_at(-o, Vector3.UP)
	var rot_in := Basis.looking_at(o, Vector3.UP)
	Kit.quad_node(root, c + o * 0.01, Vector2(w, h), outer, rot_out)
	Kit.quad_node(root, c - o * 0.01, Vector2(w, h), inner, rot_in)
	b.solid(c, sz.call(w, h))
	return outer
