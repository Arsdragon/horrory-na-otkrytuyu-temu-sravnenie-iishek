class_name B
## Geometry / material helpers. Everything in the game is built from code.

static var mats: Dictionary = {}


static func tex(name: String, scale: float = 0.5, tint: Color = Color.WHITE, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var key: String = "%s|%s|%s|%s" % [name, scale, tint, metal]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/tex/%s_d.jpg" % name)
	m.normal_enabled = true
	m.normal_texture = load("res://assets/tex/%s_n.jpg" % name)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = metal
	mats[key] = m
	return m


static func col(c: Color, rough: float = 0.85, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var key: String = "c|%s|%s|%s|%s" % [c, rough, metal, emit]
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	mats[key] = m
	return m


static func _solid(mi: MeshInstance3D, shape: Shape3D, layer: int) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	sb.add_child(cs)
	mi.add_child(sb)


static func box(parent: Node, pos: Vector3, size: Vector3, mat: Material, solid: bool = true, layer: int = 1) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var sh := BoxShape3D.new()
		sh.size = size
		_solid(mi, sh, layer)
	return mi


static func cyl(parent: Node, pos: Vector3, r: float, h: float, mat: Material, solid: bool = false, r_top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r
	cm.top_radius = r if r_top < 0.0 else r_top
	cm.height = h
	cm.radial_segments = 12
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if solid:
		var sh := CylinderShape3D.new()
		sh.radius = r
		sh.height = h
		_solid(mi, sh, 1)
	return mi


static func ball(parent: Node, pos: Vector3, r: float, mat: Material, squash: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 14
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.scale = squash
	parent.add_child(mi)
	return mi


static func text(parent: Node, pos: Vector3, s: String, px: float = 0.004, c: Color = Color.WHITE, yaw: float = 0.0, lit: bool = true) -> Label3D:
	var l := Label3D.new()
	l.text = s
	l.font_size = 48
	l.pixel_size = px
	l.modulate = c
	l.outline_size = 0
	l.shaded = lit
	l.position = pos
	l.rotation.y = yaw
	parent.add_child(l)
	return l


static func omni(parent: Node, pos: Vector3, c: Color, energy: float, rng: float, shadow: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	l.shadow_bias = 0.08
	l.position = pos
	l.set_meta("e", energy)
	parent.add_child(l)
	return l
