class_name Kit
extends RefCounted
## Строительный набор: материалы, отдельные меши, свет, модели Poly Haven, надписи.

static var _mats := {}
static var _texs := {}
static var _scenes := {}
static var _fonts := {}
static var _bounds := {}


static func tex(path_no_ext: String) -> Texture2D:
	if _texs.has(path_no_ext):
		return _texs[path_no_ext]
	var t: Texture2D = null
	for ext in [".jpg", ".png"]:
		if ResourceLoader.exists(path_no_ext + ext):
			t = load(path_no_ext + ext)
			break
	_texs[path_no_ext] = t
	return t


## PBR-материал из tex/<key>_d, _n, _r. meters — сколько метров занимает один повтор текстуры.
static func mat(key: String, meters := 2.0, tint := Color.WHITE, rough_mul := 1.0) -> StandardMaterial3D:
	var id := "%s|%s|%s|%s" % [key, meters, tint, rough_mul]
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	var base := "res://tex/" + key
	var d := tex(base + "_d")
	if d == null:
		d = tex(base)
	m.albedo_texture = d
	m.albedo_color = tint
	var n := tex(base + "_n")
	if n != null:
		m.normal_enabled = true
		m.normal_texture = n
	var r := tex(base + "_r")
	if r != null:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.roughness = rough_mul
	m.metallic_specular = 0.3
	m.uv1_scale = Vector3(1.0 / meters, 1.0 / meters, 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[id] = m
	return m


## Однотонный материал.
static func flat(c: Color, rough := 0.85, metal := 0.0, emis := Color(0, 0, 0), emis_energy := 1.0) -> StandardMaterial3D:
	var id := "flat|%s|%s|%s|%s|%s" % [c, rough, metal, emis, emis_energy]
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.metallic_specular = 0.3
	if emis != Color(0, 0, 0):
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = emis_energy
	if c.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[id] = m
	return m


## Материал с одной текстурой (альфа по желанию): таблички, бумага, стекло.
static func img(path_no_ext: String, alpha := false, unshaded := false, meters := 0.0) -> StandardMaterial3D:
	var id := "img|%s|%s|%s|%s" % [path_no_ext, alpha, unshaded, meters]
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(path_no_ext)
	m.roughness = 0.9
	m.metallic_specular = 0.2
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if meters > 0.0:
		m.uv1_scale = Vector3(1.0 / meters, 1.0 / meters, 1.0)
	_mats[id] = m
	return m


static func yaw(deg: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(deg))


## Отдельная коробка-узел (для подвижных частей). UV стандартные, поэтому для неё лучше однотонные материалы.
static func box_node(parent: Node, pos: Vector3, size: Vector3, m: Material, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl_node(parent: Node, pos: Vector3, r: float, h: float, m: Material, sides := 12, r_top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func sphere_node(parent: Node, pos: Vector3, r: float, m: Material, squash := Vector3.ONE, segs := 14) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = segs
	sm.rings = maxi(segs / 2, 4)
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func capsule_node(parent: Node, pos: Vector3, r: float, h: float, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = maxf(h, r * 2.0)
	cm.radial_segments = 10
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Плоскость лицом по +Z (для табличек, бумаг, стёкол).
static func quad_node(parent: Node, pos: Vector3, size: Vector2, m: Material, rot := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = m
	mi.transform = Transform3D(rot, pos)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Тело вращения: профиль — точки (радиус, высота) снизу вверх.
static func lathe(profile: PackedVector2Array, sides := 14, arc := TAU) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var closed := arc >= TAU - 0.001
	var cols := sides + 1
	for j in profile.size():
		for i in cols:
			var a := arc * float(i) / float(sides)
			var p := profile[j]
			# нормаль по соседним точкам профиля
			var pa := profile[maxi(j - 1, 0)]
			var pb := profile[mini(j + 1, profile.size() - 1)]
			var t := (pb - pa).normalized()
			var n2 := Vector2(t.y, -t.x)
			st.set_normal(Vector3(cos(a) * n2.x, n2.y, sin(a) * n2.x).normalized())
			st.set_uv(Vector2(float(i) / float(sides) * 2.0, float(j) / float(profile.size() - 1)))
			st.add_vertex(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
	for j in profile.size() - 1:
		for i in sides:
			var a0 := j * cols + i
			var a1 := j * cols + i + 1
			var b0 := (j + 1) * cols + i
			var b1 := (j + 1) * cols + i + 1
			st.add_index(a0)
			st.add_index(b1)
			st.add_index(b0)
			st.add_index(a0)
			st.add_index(a1)
			st.add_index(b1)
	st.generate_tangents()
	var _unused := closed
	return st.commit()


static func mesh_node(parent: Node, mesh: Mesh, pos: Vector3, m: Material, rot := Basis.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.transform = Transform3D(rot, pos)
	parent.add_child(mi)
	return mi


static func font(family: String) -> Font:
	if _fonts.has(family):
		return _fonts[family]
	var f := SystemFont.new()
	match family:
		"hand":
			f.font_names = PackedStringArray(["Segoe Print", "Segoe Script", "Comic Sans MS"])
		"mono":
			f.font_names = PackedStringArray(["Consolas", "Courier New", "Lucida Console"])
		"type":
			f.font_names = PackedStringArray(["Courier New", "Consolas"])
			f.font_weight = 700
		"head":
			f.font_names = PackedStringArray(["Bahnschrift", "Arial Narrow", "Arial"])
			f.font_weight = 600
			f.font_stretch = 80
		_:
			f.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	f.allow_system_fallback = true
	_fonts[family] = f
	return f


## Надпись в мире (таблички, бумаги). size — высота строчной буквы примерно в метрах.
static func label(parent: Node, pos: Vector3, text: String, size := 0.08, color := Color(0.08, 0.08, 0.08), family := "head", rot := Basis.IDENTITY, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font(family)
	l.font_size = 64
	l.pixel_size = size / 48.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = true
	l.double_sided = false
	l.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.width = width / l.pixel_size
	l.transform = Transform3D(rot, pos)
	parent.add_child(l)
	return l


static func omni(parent: Node, pos: Vector3, color: Color, energy: float, rng: float, shadow := false, fade_at := 45.0) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	l.light_specular = 0.3
	l.distance_fade_enabled = true
	l.distance_fade_begin = fade_at
	l.distance_fade_length = 10.0
	l.position = pos
	parent.add_child(l)
	return l


## Модель Poly Haven по короткому имени (mdl/<имя>/m.gltf). Возвращает null, если модели нет.
static func model(short: String) -> Node3D:
	if not _scenes.has(short):
		var p := "res://mdl/%s/m.gltf" % short
		_scenes[short] = load(p) if ResourceLoader.exists(p) else null
	var ps: PackedScene = _scenes[short]
	if ps == null:
		return null
	return ps.instantiate() as Node3D


## Поставить модель: pos — точка на полу, yaw в градусах. solid — добавить коллизию по габаритам.
static func place(parent: Node, short: String, pos: Vector3, yaw_deg := 0.0, scl := 1.0, solid := false, shadows := true) -> Node3D:
	var n := model(short)
	if n == null:
		return null
	n.transform = Transform3D(yaw(yaw_deg).scaled(Vector3.ONE * scl), pos)
	parent.add_child(n)
	for mi in meshes(n):
		var m3: MeshInstance3D = mi
		m3.lod_bias = 0.45
		m3.visibility_range_end = 38.0
		if not shadows:
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if solid:
		var bb := bounds(n)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bb.size
		cs.shape = sh
		cs.position = bb.position + bb.size * 0.5
		body.add_child(cs)
		n.add_child(body)
	return n


## Поставить модель низом-центром в точку pos (модели Poly Haven бывают со сдвинутым началом координат).
## scl — число или Vector3. Возвращает узел-обёртку, внутри которого сама модель.
static func put(parent: Node, short: String, pos: Vector3, yaw_deg := 0.0, scl: Variant = 1.0, solid := false, shadows := true) -> Node3D:
	var n := model(short)
	if n == null:
		return null
	if not _bounds.has(short):
		_bounds[short] = bounds(n)
	var bb: AABB = _bounds[short]
	var sv := Vector3.ONE
	if scl is Vector3:
		sv = scl
	else:
		sv = Vector3.ONE * float(scl)
	var holder := Node3D.new()
	holder.transform = Transform3D(yaw(yaw_deg), pos)
	parent.add_child(holder)
	n.scale = sv
	n.position = -Vector3((bb.position.x + bb.size.x * 0.5) * sv.x, bb.position.y * sv.y, (bb.position.z + bb.size.z * 0.5) * sv.z)
	holder.add_child(n)
	for mi in meshes(n):
		var m3: MeshInstance3D = mi
		m3.lod_bias = 0.45
		m3.visibility_range_end = 38.0
		if not shadows:
			m3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = bb.size * sv
		cs.shape = sh
		cs.position = Vector3(0, bb.size.y * sv.y * 0.5, 0)
		body.add_child(cs)
		holder.add_child(body)
	return holder


## Сделать модель легче для слабой видеокарты: раньше переключать уровни детализации.
static func lighten(n: Node, bias := 0.5) -> void:
	if n == null:
		return
	for mi in meshes(n):
		(mi as MeshInstance3D).lod_bias = bias


static func meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D:
		out.append(n)
	for c in n.get_children():
		out.append_array(meshes(c))
	return out


## Габариты модели в её собственных координатах (до поворота и масштаба узла).
static func bounds(n: Node3D) -> AABB:
	var first := true
	var bb := AABB()
	var inv := n.global_transform.affine_inverse() if n.is_inside_tree() else Transform3D.IDENTITY
	for mi in meshes(n):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var t: Transform3D = (inv * m.global_transform) if n.is_inside_tree() else _rel(m, n)
		var a := t * m.mesh.get_aabb()
		if first:
			bb = a
			first = false
		else:
			bb = bb.merge(a)
	return bb


static func _rel(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Ореол огня, видимый сквозь пургу (свой шейдер без тумана).
static func halo(parent: Node, pos: Vector3, color: Color, size: float, power := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	mi.mesh = qm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/shaders/halo.gdshader")
	sm.set_shader_parameter("tex", tex("res://tex/halo"))
	sm.set_shader_parameter("color", color)
	sm.set_shader_parameter("power", power)
	mi.material_override = sm
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = size
	parent.add_child(mi)
	return mi
