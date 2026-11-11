extends Node3D
## Builds the whole level from code: station building, yard, mast, fuel shed, forest.

const H := 2.8
const T := 0.2
const DOOR_POS := Vector3(8, 0, 0)
const SHED_POS := Vector3(38, 0, 14)
const MAST_POS := Vector3(-10, 0, -40)
const GATE_POS := Vector3(46, 0, 0)

var g: Node
var lights: Array = []          # powered lamps
var bulb_mat: StandardMaterial3D
var doors: Array = []
var front_door: Door
var lockers: Array = []         # {pos, face, front}
var notes_nodes: Dictionary = {}
var canisters: Array = []
var batteries: Array = []
var status_label: Label3D
var lamp_carrier: MeshInstance3D
var lamp_call: MeshInstance3D
var gen_label: Label3D
var gen_pos := Vector3(-6.3, 0.8, 3.6)
var console_pos := Vector3(-7.5, 1.1, -3.3)
var phone_pos := Vector3(2.2, 1.4, -0.85)
var beacon: OmniLight3D
var red_lamp: OmniLight3D
var truck: Node3D
var env: Environment
var snow: GPUParticles3D
var switch_lever: MeshInstance3D
var wallm: ShaderMaterial
var m_wood: Material
var m_metal: Material
var m_dark: Material
var m_paper: Material


func build(game: Node) -> void:
	g = game
	wallm = ShaderMaterial.new()
	wallm.shader = load("res://shaders/wall.gdshader")
	wallm.set_shader_parameter("plaster", load("res://assets/tex/plaster_d.jpg"))
	wallm.set_shader_parameter("planks", load("res://assets/tex/planks_d.jpg"))
	m_wood = B.tex("planks", 0.8, Color(0.5, 0.4, 0.3))
	m_metal = B.tex("rust", 0.6, Color(0.5, 0.52, 0.5), 0.6, 0.5)
	m_dark = B.col(Color(0.08, 0.09, 0.09), 0.7, 0.3)
	m_paper = B.col(Color(0.75, 0.72, 0.6), 0.95)
	bulb_mat = StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1, 0.85, 0.6)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1, 0.8, 0.5)
	bulb_mat.emission_energy_multiplier = 3.0
	_environment()
	_shell()
	_operator_room()
	_bunk_room()
	_store_room()
	_generator_room()
	_kitchen()
	_wash_room()
	_corridor()
	_yard()
	_mast()
	_shed()
	_forest()
	_truck()


# ------------------------------------------------------------------ helpers
func _seg(a: Vector2, dir: Vector2, s: float, e: float, y0: float, y1: float, mat: Material) -> void:
	if e - s < 0.01 or y1 - y0 < 0.01:
		return
	var c: Vector2 = a + dir * ((s + e) / 2.0)
	var size := Vector3(e - s, y1 - y0, T) if absf(dir.x) > 0.5 else Vector3(T, y1 - y0, e - s)
	B.box(self, Vector3(c.x, (y0 + y1) / 2.0, c.y), size, mat)


func wall(a: Vector2, b: Vector2, ops: Array = [], mat: Material = null, top: float = H) -> void:
	if mat == null:
		mat = wallm
	var length: float = a.distance_to(b)
	var dir: Vector2 = (b - a) / length
	ops.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var cur: float = 0.0
	for o in ops:
		var s: float = o[0] - o[1] / 2.0
		var e: float = o[0] + o[1] / 2.0
		_seg(a, dir, cur, s, 0, top, mat)
		_seg(a, dir, s, e, 0, o[2], mat)
		_seg(a, dir, s, e, o[3], top, mat)
		cur = e
	_seg(a, dir, cur, length, 0, top, mat)


func lamp(pos: Vector3, energy: float = 1.3, rng: float = 7.5, shadow: bool = false) -> OmniLight3D:
	B.cyl(self, pos + Vector3(0, 0.12, 0), 0.008, 0.26, m_dark)
	B.ball(self, pos, 0.055, bulb_mat)
	var l := B.omni(self, pos - Vector3(0, 0.1, 0), Color(1.0, 0.78, 0.5), energy, rng, shadow)
	lights.append(l)
	return l


func door(hinge: Vector3, yaw: float, open_angle: float, opened: bool, boltable: bool = false) -> Door:
	var d := Door.new()
	d.position = hinge
	d.rotation.y = yaw
	add_child(d)
	d.setup(0.93, 2.07, B.tex("planks", 1.0, Color(0.42, 0.36, 0.3)), boltable)
	d.open_angle = open_angle
	d.open = opened
	d.angle = open_angle if opened else 0.0
	doors.append(d)
	return d


func window(pos: Vector3, along_x: bool, w: float = 1.6) -> void:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.6, 0.75, 0.85, 0.16)
	glass.roughness = 0.15
	var sz := Vector3(w, 1.0, 0.02) if along_x else Vector3(0.02, 1.0, w)
	B.box(self, pos, sz, glass, true, 16)
	var fr := B.col(Color(0.55, 0.53, 0.45), 0.8)
	var bar_v := Vector3(0.05, 1.0, 0.07) if along_x else Vector3(0.07, 1.0, 0.05)
	var bar_h := Vector3(w, 0.05, 0.07) if along_x else Vector3(0.07, 0.05, w)
	B.box(self, pos, bar_v, fr, false)
	B.box(self, pos, bar_h, fr, false)
	var sill := Vector3(w + 0.1, 0.04, 0.3) if along_x else Vector3(0.3, 0.04, w + 0.1)
	B.box(self, pos - Vector3(0, 0.52, 0), sill, fr, false)


func note(id: int, pos: Vector3, yaw: float = 0.0, on_wall: bool = false) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	var size := Vector3(0.21, 0.29, 0.004) if on_wall else Vector3(0.21, 0.004, 0.29)
	B.box(n, Vector3.ZERO, size, m_paper, false)
	for i in 7:
		var ln := Vector3(0.16, 0.006, 0.0045) if on_wall else Vector3(0.16, 0.0045, 0.006)
		var off := Vector3(0, 0.1 - i * 0.032, 0) if on_wall else Vector3(0, 0, -0.1 + i * 0.032)
		B.box(n, off, ln, B.col(Color(0.12, 0.12, 0.2)), false)
	Act.make(n, Vector3.ZERO, Vector3(0.32, 0.32, 0.32), func() -> String: return "[E] Читать", func() -> void: g.read_note(id))
	notes_nodes[id] = n


func table(pos: Vector3, size: Vector3) -> void:
	B.box(self, pos + Vector3(0, size.y - 0.025, 0), Vector3(size.x, 0.05, size.z), m_wood)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			B.box(self, pos + Vector3(sx * (size.x / 2 - 0.05), size.y / 2, sz * (size.z / 2 - 0.05)), Vector3(0.06, size.y, 0.06), m_wood, false)


func stool(pos: Vector3) -> void:
	B.cyl(self, pos + Vector3(0, 0.45, 0), 0.17, 0.04, m_wood, false)
	B.cyl(self, pos + Vector3(0, 0.22, 0), 0.03, 0.44, m_dark, true)


func locker(pos: Vector3, face: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = atan2(-face.x, -face.z)   # local -Z = face
	add_child(n)
	var m := B.col(Color(0.2, 0.27, 0.25), 0.55, 0.6)
	B.box(n, Vector3(0, 0.98, 0), Vector3(0.62, 1.96, 0.55), m)
	B.box(n, Vector3(0, 1.0, -0.28), Vector3(0.56, 1.86, 0.012), B.col(Color(0.17, 0.23, 0.21), 0.5, 0.6), false)
	for i in 5:
		B.box(n, Vector3(0, 1.5 + i * 0.045, -0.29), Vector3(0.36, 0.012, 0.01), m_dark, false)
	B.box(n, Vector3(0.2, 1.05, -0.3), Vector3(0.03, 0.1, 0.03), B.col(Color(0.6, 0.6, 0.6), 0.3, 0.9), false)
	var idx: int = lockers.size()
	lockers.append({"pos": pos, "face": face, "front": pos + face * 0.85})
	Act.make(n, Vector3(0, 1.0, -0.25), Vector3(0.62, 1.9, 0.2), func() -> String: return "[E] Спрятаться в шкаф", func() -> void: g.player.hide_in(idx))


func bunk(pos: Vector3) -> void:
	var blanket := B.col(Color(0.22, 0.2, 0.3), 0.98)
	for y in [0.4, 1.45]:
		B.box(self, pos + Vector3(0, y, 0), Vector3(0.9, 0.06, 2.0), m_wood)
		B.box(self, pos + Vector3(0, y + 0.1, 0), Vector3(0.84, 0.14, 1.9), B.col(Color(0.5, 0.48, 0.4), 0.98), false)
		B.box(self, pos + Vector3(0, y + 0.19, 0.25), Vector3(0.86, 0.06, 1.3), blanket, false)
		B.box(self, pos + Vector3(0, y + 0.21, -0.75), Vector3(0.5, 0.1, 0.3), B.col(Color(0.6, 0.6, 0.55), 0.98), false)
	for sx in [-0.43, 0.43]:
		for sz in [-0.97, 0.97]:
			B.box(self, pos + Vector3(sx, 0.9, sz), Vector3(0.05, 1.8, 0.05), m_dark, false)


func shelf(pos: Vector3, along_x: bool, length: float) -> void:
	var seed_v: int = int(pos.x * 7 + pos.z * 13)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var d := 0.45
	for i in 4:
		var y: float = 0.25 + i * 0.5
		var sz := Vector3(length, 0.03, d) if along_x else Vector3(d, 0.03, length)
		B.box(self, pos + Vector3(0, y, 0), sz, m_wood, false)
		var k: float = -length / 2 + 0.25
		while k < length / 2 - 0.2:
			if rng.randf() < 0.7 and not (i == 1 and along_x):
				var bw: float = rng.randf_range(0.18, 0.38)
				var bh: float = rng.randf_range(0.12, 0.34)
				var c := Color.from_hsv(rng.randf_range(0.05, 0.14), 0.4, rng.randf_range(0.15, 0.4))
				var off := Vector3(k, y + bh / 2 + 0.015, 0) if along_x else Vector3(0, y + bh / 2 + 0.015, k)
				var bs := Vector3(bw, bh, 0.3) if along_x else Vector3(0.3, bh, bw)
				B.box(self, pos + off, bs, B.col(c, 0.9), false)
			k += 0.45
	var full := Vector3(length, 2.0, d) if along_x else Vector3(d, 2.0, length)
	var cs := B.box(self, pos + Vector3(0, 1.0, 0), full, m_dark, true)
	cs.mesh = null
	for e in [-1, 1]:
		var off2 := Vector3(e * length / 2, 1.0, 0) if along_x else Vector3(0, 1.0, e * length / 2)
		var us := Vector3(0.04, 2.0, d) if along_x else Vector3(d, 2.0, 0.04)
		B.box(self, pos + off2, us, m_dark, false)


# ------------------------------------------------------------------ environment
func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.015, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.5, 0.7)
	env.ambient_light_energy = 0.03
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.03, 0.037, 0.05)
	env.fog_density = 0.02
	env.fog_sky_affect = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.5, 0.6, 0.9)
	moon.light_energy = 0.035
	moon.rotation_degrees = Vector3(-55, 40, 0)
	moon.name = "Moon"
	add_child(moon)
	snow = GPUParticles3D.new()
	snow.amount = 1400
	snow.lifetime = 4.0
	snow.preprocess = 4.0
	snow.visibility_aabb = AABB(Vector3(-20, -10, -20), Vector3(40, 20, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 5, 16)
	pm.direction = Vector3(1, -0.35, 0.3)
	pm.spread = 12.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -1.0, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.5
	snow.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.05, 0.05)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/snow.gdshader")
	qm.material = sm
	snow.draw_pass_1 = qm
	add_child(snow)


# ------------------------------------------------------------------ building
func _shell() -> void:
	var door_op := [0, 0.95, 0, 2.1]
	var win := [0, 1.6, 1.0, 2.0]
	# floor / ceiling / roof
	B.box(self, Vector3(0, -0.03, 0), Vector3(16.3, 0.1, 10.3), B.tex("floor", 0.45, Color(0.55, 0.48, 0.42)))
	B.box(self, Vector3(0, H + 0.1, 0), Vector3(16.4, 0.2, 10.4), wallm)
	B.box(self, Vector3(0, H + 0.26, 0), Vector3(17.6, 0.12, 11.6), B.tex("iron", 0.5, Color(0.3, 0.32, 0.35), 0.6, 0.4))
	B.box(self, Vector3(0, H + 0.45, 0), Vector3(17.2, 0.3, 11.2), B.tex("snow", 0.2, Color(0.75, 0.8, 0.9)), false)
	# outer walls
	wall(Vector2(-8.1, -5), Vector2(8.1, -5), [[3.1, 1.6, 1.0, 2.0], [8.6, 1.6, 1.0, 2.0]])
	wall(Vector2(-8.1, 5), Vector2(8.1, 5), [[9.1, 1.6, 1.0, 2.0]])
	wall(Vector2(-8, -5), Vector2(-8, 5), [[5, 1.0, 1.0, 2.0]])
	wall(Vector2(8, -5), Vector2(8, 5), [[5, 1.0, 0, 2.1]])
	window(Vector3(-5, 1.5, -5), true)
	window(Vector3(0.5, 1.5, -5), true)
	window(Vector3(1, 1.5, 5), true)
	window(Vector3(-8, 1.5, 0), false, 1.0)
	# corridor walls with doorways (distance measured from x = -8)
	wall(Vector2(-8, -1), Vector2(8, -1), [[4, 0.95, 0, 2.1], [8.5, 0.95, 0, 2.1], [13.5, 0.95, 0, 2.1]])
	wall(Vector2(-8, 1), Vector2(8, 1), [[3, 0.95, 0, 2.1], [9, 0.95, 0, 2.1], [14, 0.95, 0, 2.1]])
	# partitions
	wall(Vector2(-2, -5), Vector2(-2, -1))
	wall(Vector2(3, -5), Vector2(3, -1))
	wall(Vector2(-2, 1), Vector2(-2, 5))
	wall(Vector2(4, 1), Vector2(4, 5))
	# doors: north rooms open inwards (-Z), south rooms inwards (+Z)
	door(Vector3(-4.465, 0, -1), 0, 1.75, true).title = "op"
	door(Vector3(0.035, 0, -1), 0, 1.75, false).title = "bunk"
	door(Vector3(5.035, 0, -1), 0, 1.75, false).title = "store"
	door(Vector3(-5.465, 0, 1), 0, -1.75, false).title = "gen"
	door(Vector3(0.535, 0, 1), 0, -1.75, true).title = "kit"
	door(Vector3(5.535, 0, 1), 0, -1.75, false).title = "wash"
	front_door = door(Vector3(8, 0, 0.465), PI / 2, -1.75, false, true)
	front_door.title = "front"
	# porch
	B.box(self, Vector3(8.9, -0.02, 0), Vector3(1.6, 0.1, 1.8), m_wood)
	var pl := lamp(Vector3(8.5, 2.45, 0), 1.0, 7.0)
	pl.light_color = Color(1.0, 0.7, 0.4)


func _operator_room() -> void:
	lamp(Vector3(-5, 2.5, -3), 1.5, 8.0, true)
	# console desk along west wall
	B.box(self, Vector3(-7.5, 0.375, -3.3), Vector3(0.8, 0.75, 2.4), m_metal)
	B.box(self, Vector3(-7.75, 1.1, -3.3), Vector3(0.3, 0.7, 2.2), B.col(Color(0.23, 0.26, 0.24), 0.5, 0.5))
	var px := -7.595
	var yaw := PI / 2
	B.text(self, Vector3(px, 1.38, -3.3), "Р-409  «УЗЕЛ-9»", 0.0016, Color(0.8, 0.8, 0.7), yaw)
	lamp_carrier = B.ball(self, Vector3(px, 1.2, -4.1), 0.035, B.col(Color(0.05, 0.12, 0.05)))
	B.text(self, Vector3(px, 1.12, -4.1), "НЕСУЩАЯ", 0.0011, Color(0.8, 0.8, 0.7), yaw)
	lamp_call = B.ball(self, Vector3(px, 1.2, -3.75), 0.035, B.col(Color(0.12, 0.04, 0.04)))
	B.text(self, Vector3(px, 1.12, -3.75), "ВЫЗОВ", 0.0011, Color(0.8, 0.8, 0.7), yaw)
	B.box(self, Vector3(px - 0.005, 1.05, -2.95), Vector3(0.01, 0.4, 0.75), B.col(Color(0.01, 0.03, 0.02), 0.2))
	status_label = B.text(self, Vector3(px + 0.005, 1.05, -2.95), "", 0.0013, Color(0.4, 1.0, 0.5), yaw, false)
	# speaker grille + dials
	B.cyl(self, Vector3(px, 0.92, -3.92), 0.11, 0.02, m_dark).rotation.z = PI / 2
	for i in 3:
		B.cyl(self, Vector3(px, 0.86, -2.35 - i * 0.12), 0.03, 0.03, m_dark).rotation.z = PI / 2
	# buttons
	var gb := B.cyl(self, Vector3(-7.3, 0.77, -3.75), 0.05, 0.04, B.col(Color(0.1, 0.5, 0.15), 0.4, 0.0, 0.3))
	B.text(self, Vector3(-7.18, 0.756, -3.75), "ОТВЕТ", 0.0011, Color(0.8, 0.8, 0.7), yaw).rotation.x = -PI / 2
	Act.make(gb, Vector3.ZERO, Vector3(0.24, 0.2, 0.24), func() -> String: return "[E] ОТВЕТИТЬ на вызов", func() -> void: g.answer_call())
	var rb := B.cyl(self, Vector3(-7.3, 0.77, -3.35), 0.05, 0.04, B.col(Color(0.5, 0.08, 0.08), 0.4, 0.0, 0.3))
	B.text(self, Vector3(-7.18, 0.756, -3.35), "СБРОС", 0.0011, Color(0.8, 0.8, 0.7), yaw).rotation.x = -PI / 2
	Act.make(rb, Vector3.ZERO, Vector3(0.24, 0.2, 0.24), func() -> String: return "[E] СБРОС вызова", func() -> void: g.reject_call())
	# microphone, headphones, mug
	B.cyl(self, Vector3(-7.45, 0.85, -3.55), 0.012, 0.2, m_dark)
	B.ball(self, Vector3(-7.45, 0.97, -3.55), 0.035, m_dark)
	B.cyl(self, Vector3(-7.25, 0.8, -4.2), 0.04, 0.09, B.col(Color(0.7, 0.7, 0.65), 0.4))
	note(1, Vector3(-7.3, 0.757, -2.7), 0.3)
	# master switch (secret ending)
	B.box(self, Vector3(-7.86, 1.35, -1.75), Vector3(0.08, 0.34, 0.24), B.col(Color(0.3, 0.3, 0.3), 0.5, 0.6), false)
	switch_lever = B.box(self, Vector3(-7.8, 1.42, -1.75), Vector3(0.05, 0.16, 0.05), B.col(Color(0.7, 0.05, 0.05), 0.4), false)
	B.text(self, Vector3(-7.895, 1.62, -1.75), "ПЕРЕДАТЧИК\nНЕ ОТКЛЮЧАТЬ", 0.0012, Color(0.6, 0.1, 0.1), yaw)
	Act.make(self, Vector3(-7.8, 1.38, -1.75), Vector3(0.2, 0.4, 0.3), func() -> String: return g.switch_prompt(), func() -> void: g.kill_transmitter(), 2.5)
	stool(Vector3(-6.75, 0, -2.3))
	# cabinet + map
	B.box(self, Vector3(-2.4, 1.0, -4.2), Vector3(0.5, 2.0, 1.2), m_wood)
	B.box(self, Vector3(-5.5, 1.75, -1.11), Vector3(1.5, 1.0, 0.01), B.col(Color(0.45, 0.47, 0.38), 0.95), false)
	B.text(self, Vector3(-5.5, 2.15, -1.12), "СХЕМА РРЛ «БАЙКАЛ — УЗЕЛ-9»", 0.0014, Color(0.1, 0.1, 0.1), PI)
	for i in 5:
		B.box(self, Vector3(-6.1 + i * 0.3, 1.7 + sin(i * 2.0) * 0.2, -1.118), Vector3(0.3, 0.008, 0.004), B.col(Color(0.5, 0.1, 0.1)), false)
	# rules sheet above desk
	B.box(self, Vector3(-7.895, 1.9, -3.3), Vector3(0.005, 0.5, 0.8), m_paper, false)
	B.text(self, Vector3(-7.89, 1.9, -3.3), "1. БАЙКАЛ ЗОВЁТ РОВНО В НАЧАЛЕ ЧАСА\n2. ОТВЕЧАЙ, ЕСЛИ ГОРИТ НЕСУЩАЯ\n3. ИНАЧЕ — СБРОС\n4. СВЕТ НЕ ГАСИТЬ\n5. ДВЕРЬ — НА ЗАСОВ", 0.0011, Color(0.1, 0.1, 0.25), yaw)


func _bunk_room() -> void:
	lamp(Vector3(0.5, 2.5, -3), 0.9, 6.5)
	bunk(Vector3(-1.45, 0, -3.3))
	bunk(Vector3(2.45, 0, -3.6))
	table(Vector3(0.5, 0, -4.45), Vector3(1.0, 0.72, 0.6))
	note(3, Vector3(0.6, 0.725, -4.4), -0.4)
	B.cyl(self, Vector3(0.2, 0.78, -4.5), 0.04, 0.12, B.col(Color(0.3, 0.5, 0.3), 0.3))
	locker(Vector3(2.65, 0, -1.5), Vector3(-1, 0, 0))
	# boots, coat on the wall
	B.box(self, Vector3(-1.6, 0.12, -1.4), Vector3(0.12, 0.24, 0.28), m_dark, false)
	B.box(self, Vector3(-1.4, 0.12, -1.45), Vector3(0.12, 0.24, 0.28), m_dark, false)
	B.box(self, Vector3(-1.86, 1.3, -1.6), Vector3(0.12, 0.9, 0.5), B.col(Color(0.2, 0.22, 0.16), 0.98), false)


func _store_room() -> void:
	lamp(Vector3(5.5, 2.5, -3), 0.8, 6.0)
	shelf(Vector3(5.5, 0, -4.65), true, 4.0)
	shelf(Vector3(7.65, 0, -2.6), false, 2.4)
	B.box(self, Vector3(3.6, 0.3, -3.8), Vector3(0.7, 0.6, 0.7), m_wood)
	B.box(self, Vector3(3.65, 0.85, -3.85), Vector3(0.55, 0.5, 0.55), m_wood)
	B.box(self, Vector3(3.6, 0.25, -2.6), Vector3(0.6, 0.5, 0.9), m_wood)
	note(5, Vector3(3.6, 0.505, -2.6), 0.2)
	for i in 3:
		var p := Vector3(4.3 + i * 0.5, 0.82, -4.6)
		var b := B.box(self, p, Vector3(0.14, 0.09, 0.09), B.col(Color(0.75, 0.55, 0.1), 0.4, 0.3), false)
		var a := Act.make(b, Vector3.ZERO, Vector3(0.3, 0.3, 0.3), func() -> String: return "[E] Взять батарею", func() -> void: g.take_battery(b))
		a.name = "A"
		batteries.append(b)


func _generator_room() -> void:
	lamp(Vector3(-5, 2.5, 3), 0.9, 6.5)
	red_lamp = B.omni(self, Vector3(-7.7, 2.3, 1.3), Color(1, 0.08, 0.05), 0.0, 5.0)
	B.box(self, Vector3(-7.8, 2.3, 1.3), Vector3(0.1, 0.1, 0.1), B.col(Color(0.6, 0.05, 0.05), 0.3, 0.0, 1.5), false)
	var p := Vector3(-6.3, 0, 3.6)
	B.box(self, p + Vector3(0, 0.12, 0), Vector3(1.7, 0.24, 0.95), m_dark)
	B.box(self, p + Vector3(-0.35, 0.6, 0), Vector3(0.8, 0.7, 0.75), m_metal)
	var c := B.cyl(self, p + Vector3(0.45, 0.6, 0), 0.32, 0.7, B.tex("rust", 0.8, Color(0.25, 0.35, 0.3), 0.5, 0.6), true)
	c.rotation.z = PI / 2
	B.box(self, p + Vector3(-0.35, 1.08, 0), Vector3(0.6, 0.26, 0.5), B.col(Color(0.5, 0.1, 0.08), 0.5, 0.4))
	B.cyl(self, p + Vector3(-0.35, 1.25, 0.1), 0.05, 0.06, m_dark)
	B.cyl(self, p + Vector3(-0.9, 1.5, 0.6), 0.05, 2.6, m_dark).rotation.x = 0.0
	gen_label = B.text(self, p + Vector3(-0.35, 1.08, -0.255), "", 0.0016, Color(1, 0.85, 0.3), PI, false)
	Act.make(self, p + Vector3(0, 0.7, 0), Vector3(1.8, 1.4, 1.05), func() -> String: return g.gen_prompt(), func() -> void: g.gen_use(), 3.0)
	for i in 2:
		B.cyl(self, Vector3(-2.6 - i * 0.7, 0.45, 4.4), 0.3, 0.9, B.tex("rust", 0.7, Color(0.3, 0.3, 0.45), 0.5, 0.5), true)
	B.box(self, Vector3(-7.6, 0.4, 1.6), Vector3(0.6, 0.8, 0.8), m_wood)
	note(2, Vector3(-4.2, 1.5, 1.105), 0, true)


func _kitchen() -> void:
	lamp(Vector3(1, 2.5, 3), 1.0, 6.5)
	table(Vector3(1, 0, 3.4), Vector3(1.3, 0.74, 0.8))
	stool(Vector3(0.2, 0, 3.2))
	stool(Vector3(1.4, 0, 2.7))
	note(4, Vector3(1.2, 0.745, 3.45), 0.5)
	B.cyl(self, Vector3(0.7, 0.79, 3.5), 0.04, 0.09, B.col(Color(0.8, 0.8, 0.75), 0.4))
	B.box(self, Vector3(-1.5, 0.45, 4.5), Vector3(0.8, 0.9, 0.7), m_dark)
	B.cyl(self, Vector3(-1.5, 1.85, 4.6), 0.07, 1.9, m_dark)
	B.cyl(self, Vector3(-1.4, 0.98, 4.4), 0.1, 0.16, B.col(Color(0.3, 0.35, 0.5), 0.4, 0.3))
	var fire := B.omni(self, Vector3(-1.5, 0.45, 4.0), Color(1, 0.4, 0.1), 0.35, 2.5)
	fire.name = "Fire"
	B.box(self, Vector3(-1.5, 0.45, 4.14), Vector3(0.3, 0.2, 0.02), B.col(Color(1, 0.35, 0.05), 0.5, 0.0, 2.0), false)
	B.box(self, Vector3(3.65, 1.0, 3.2), Vector3(0.5, 2.0, 1.4), m_wood)
	B.box(self, Vector3(3.0, 0.45, 4.6), Vector3(1.0, 0.9, 0.6), m_wood)


func _wash_room() -> void:
	lamp(Vector3(6, 2.5, 3), 0.8, 6.0)
	locker(Vector3(4.6, 0, 4.6), Vector3(0, 0, -1))
	locker(Vector3(5.3, 0, 4.6), Vector3(0, 0, -1))
	B.box(self, Vector3(7.65, 0.8, 3.0), Vector3(0.5, 0.2, 0.7), B.col(Color(0.7, 0.72, 0.7), 0.3))
	B.cyl(self, Vector3(7.75, 1.05, 3.0), 0.015, 0.3, B.col(Color(0.6, 0.6, 0.6), 0.3, 0.9))
	B.box(self, Vector3(6.8, 0.22, 4.6), Vector3(1.4, 0.06, 0.4), m_wood)
	B.box(self, Vector3(6.8, 0.1, 4.6), Vector3(1.2, 0.2, 0.3), m_dark, true)
	note(6, Vector3(6.9, 0.255, 4.6), -0.3)
	B.cyl(self, Vector3(7.5, 0.2, 1.6), 0.18, 0.4, B.col(Color(0.4, 0.42, 0.4), 0.4, 0.7), true)


func _corridor() -> void:
	lamp(Vector3(-4, 2.55, 0), 1.0, 7.0)
	lamp(Vector3(4, 2.55, 0), 1.0, 7.0, true)
	# phone
	B.box(self, phone_pos + Vector3(0, 0, -0.02), Vector3(0.2, 0.28, 0.08), m_dark, false)
	B.box(self, phone_pos + Vector3(0, 0.1, 0.04), Vector3(0.24, 0.06, 0.06), m_dark, false)
	B.cyl(self, phone_pos + Vector3(0, -0.03, 0.03), 0.05, 0.01, B.col(Color(0.6, 0.6, 0.55), 0.4)).rotation.x = PI / 2
	Act.make(self, phone_pos, Vector3(0.3, 0.4, 0.2), func() -> String: return g.phone_prompt(), func() -> void: g.phone_use())
	# coat hooks and parka near entrance
	B.box(self, Vector3(7.0, 1.7, 0.88), Vector3(0.9, 0.06, 0.03), m_wood, false)
	B.box(self, Vector3(6.8, 1.25, 0.82), Vector3(0.45, 0.9, 0.12), B.col(Color(0.18, 0.2, 0.15), 0.98), false)
	B.box(self, Vector3(7.25, 0.12, 0.75), Vector3(0.12, 0.24, 0.28), m_dark, false)
	# rug + notice board + extinguisher
	B.box(self, Vector3(6.6, 0.025, 0), Vector3(1.6, 0.012, 0.9), B.col(Color(0.25, 0.1, 0.08), 0.98), false)
	B.box(self, Vector3(-1.2, 1.55, 0.885), Vector3(0.9, 0.6, 0.02), m_wood, false)
	B.text(self, Vector3(-1.2, 1.72, 0.87), "ГРАФИК ДЕЖУРСТВ", 0.0013, Color(0.1, 0.1, 0.1), PI)
	B.text(self, Vector3(-1.2, 1.5, 0.87), "ГРИНЁВ А. П.  — 9.01 – 14.01\n————————  — 14.01 – ...", 0.001, Color(0.15, 0.1, 0.1), PI)
	B.cyl(self, Vector3(3.2, 0.5, 0.85), 0.07, 0.45, B.col(Color(0.6, 0.06, 0.05), 0.4, 0.3))


# ------------------------------------------------------------------ outside
func post(pos: Vector3) -> void:
	B.cyl(self, pos + Vector3(0, 1.5, 0), 0.05, 3.0, m_dark, true)
	B.ball(self, pos + Vector3(0, 3.0, 0), 0.07, bulb_mat)
	var l := B.omni(self, pos + Vector3(0, 2.9, 0), Color(1.0, 0.7, 0.4), 1.1, 8.0)
	lights.append(l)


func _yard() -> void:
	B.box(self, Vector3(0, -0.5, 0), Vector3(400, 1, 400), B.tex("snow", 0.12, Color(0.62, 0.68, 0.8)))
	# lamp line to the shed and to the mast
	for i in 4:
		post(Vector3(9.5, 0, 1.5).lerp(SHED_POS + Vector3(-3, 0, -1), (i + 1) / 5.0) + Vector3(0, 0, 1.2))
	post(Vector3(10.5, 0, -6.5))
	for i in 5:
		post(Vector3(8.5, 0, -7.5).lerp(MAST_POS + Vector3(2, 0, 3), (i + 1) / 5.5) + Vector3(1.2, 0, 0))
	# fence
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := CylinderMesh.new()
	pm.top_radius = 0.04
	pm.bottom_radius = 0.04
	pm.height = 2.2
	pm.radial_segments = 6
	pm.material = m_dark
	mm.mesh = pm
	var pts: Array = []
	var x0 := -32.0
	var x1 := 46.0
	var z0 := -52.0
	var z1 := 28.0
	var x := x0
	while x <= x1:
		pts.append(Vector3(x, 1.1, z0))
		pts.append(Vector3(x, 1.1, z1))
		x += 3.0
	var z := z0
	while z <= z1:
		pts.append(Vector3(x0, 1.1, z))
		if absf(z) > 3.0:
			pts.append(Vector3(x1, 1.1, z))
		z += 3.0
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	add_child(mi)
	for y in [0.7, 1.4, 2.1]:
		B.box(self, Vector3((x0 + x1) / 2, y, z0), Vector3(x1 - x0, 0.015, 0.015), m_dark, false)
		B.box(self, Vector3((x0 + x1) / 2, y, z1), Vector3(x1 - x0, 0.015, 0.015), m_dark, false)
		B.box(self, Vector3(x0, y, (z0 + z1) / 2), Vector3(0.015, 0.015, z1 - z0), m_dark, false)
		B.box(self, Vector3(x1, y, (z0 - 3) / 2), Vector3(0.015, 0.015, -z0 - 3), m_dark, false)
		B.box(self, Vector3(x1, y, (z1 + 3) / 2), Vector3(0.015, 0.015, z1 - 3), m_dark, false)
	# invisible bounds
	for b in [[Vector3(x0 - 1, 2, 0), Vector3(1, 6, 120)], [Vector3(x1 + 9, 2, 0), Vector3(1, 6, 120)], [Vector3(0, 2, z0 - 1), Vector3(120, 6, 1)], [Vector3(0, 2, z1 + 1), Vector3(120, 6, 1)]]:
		B.box(self, b[0], b[1], m_dark).mesh = null
	B.box(self, Vector3(x1, 2, -27.5), Vector3(0.5, 6, 49), m_dark).mesh = null
	B.box(self, Vector3(x1, 2, 15.5), Vector3(0.5, 6, 25), m_dark).mesh = null
	# snow drifts
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var sm := B.tex("snow", 0.2, Color(0.65, 0.7, 0.82))
	for i in 46:
		var p := Vector3(rng.randf_range(x0, x1), -0.15, rng.randf_range(z0, z1))
		if absf(p.x) < 11 and absf(p.z) < 8:
			p.z = 6.2 if p.z > 0 else -6.2
		if p.distance_to(SHED_POS) < 5 or p.distance_to(MAST_POS) < 4 or (p.x > 8 and absf(p.z) < 2.5):
			continue
		B.ball(self, p, 1.0, sm, Vector3(rng.randf_range(1.2, 3.5), rng.randf_range(0.35, 0.7), rng.randf_range(1.2, 3.0)))
	# barrels & junk near the building
	for q in [Vector3(9.2, 0.45, 4.0), Vector3(9.9, 0.45, 4.3), Vector3(-9.0, 0.45, -3.5)]:
		B.cyl(self, q, 0.3, 0.9, B.tex("rust", 0.7, Color(0.35, 0.3, 0.3), 0.6, 0.5), true)
	B.box(self, Vector3(-9.2, 0.4, 3), Vector3(1.2, 0.8, 2.4), m_wood)


func _mast() -> void:
	var p := MAST_POS
	var m := B.col(Color(0.35, 0.1, 0.08), 0.6, 0.6)
	var hgt := 22.0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var leg := B.cyl(self, p + Vector3(sx * 0.55, hgt / 2, sz * 0.55), 0.05, hgt, m, false)
			leg.rotation = Vector3(sz * -0.04, 0, sx * 0.04)
	for i in 11:
		var y: float = 1.0 + i * 2.0
		var w: float = lerpf(1.9, 0.5, y / hgt)
		for a in 4:
			var bar := B.box(self, p + Vector3(0, y, 0), Vector3(w, 0.04, 0.04), m, false)
			bar.rotation.y = a * PI / 2
			bar.position += Vector3(0, 0, w / 2).rotated(Vector3.UP, a * PI / 2)
			var diag := B.box(self, p + Vector3(0, y + 1.0, 0), Vector3(w * 1.1, 0.03, 0.03), m, false)
			diag.rotation = Vector3(0, a * PI / 2, 0.85 * (1 if (i + a) % 2 == 0 else -1))
			diag.position += Vector3(0, 0, w / 2).rotated(Vector3.UP, a * PI / 2)
	B.box(self, p + Vector3(0, 1.2, 0), Vector3(1.5, 2.4, 1.5), m_dark).mesh = null
	beacon = B.omni(self, p + Vector3(0, hgt + 0.3, 0), Color(1, 0.05, 0.02), 6.0, 40.0)
	B.ball(self, p + Vector3(0, hgt + 0.3, 0), 0.2, B.col(Color(1, 0.05, 0.02), 0.3, 0.0, 6.0)).name = "BeaconBulb"
	# breaker box
	B.cyl(self, p + Vector3(1.6, 0.7, 1.2), 0.04, 1.4, m_dark, true)
	B.box(self, p + Vector3(1.6, 1.3, 1.2), Vector3(0.45, 0.55, 0.22), B.col(Color(0.3, 0.32, 0.3), 0.5, 0.6))
	B.text(self, p + Vector3(1.6, 1.42, 1.32), "ЩИТ АФУ", 0.0016, Color(0.8, 0.75, 0.3))
	Act.make(self, p + Vector3(1.6, 1.3, 1.25), Vector3(0.6, 0.7, 0.4), func() -> String: return g.mast_prompt(), func() -> void: g.mast_use(), 3.0)


func _shed() -> void:
	var p := SHED_POS
	var pm := B.tex("planks", 0.6, Color(0.3, 0.27, 0.24))
	wall(Vector2(p.x - 2, p.z - 1.7), Vector2(p.x + 2, p.z - 1.7), [], pm, 2.4)
	wall(Vector2(p.x - 2, p.z + 1.7), Vector2(p.x + 2, p.z + 1.7), [], pm, 2.4)
	wall(Vector2(p.x + 2, p.z - 1.7), Vector2(p.x + 2, p.z + 1.7), [], pm, 2.4)
	wall(Vector2(p.x - 2, p.z - 1.7), Vector2(p.x - 2, p.z + 1.7), [[1.7, 1.1, 0, 2.05]], pm, 2.4)
	B.box(self, p + Vector3(0, 2.5, 0), Vector3(4.8, 0.14, 4.2), B.tex("iron", 0.5, Color(0.3, 0.3, 0.33), 0.6, 0.4))
	B.box(self, p + Vector3(0, 0.02, 0), Vector3(4, 0.06, 3.4), m_wood, false)
	var l := lamp(p + Vector3(0, 2.2, 0), 0.6, 5.0)
	l.light_color = Color(1, 0.6, 0.3)
	B.text(self, p + Vector3(-2.115, 2.2, 0), "ГСМ", 0.004, Color(0.6, 0.12, 0.1), -PI / 2)
	for i in 3:
		var c := Node3D.new()
		c.position = p + Vector3(1.2, 0.05, -1.1 + i * 0.5)
		add_child(c)
		B.box(c, Vector3(0, 0.22, 0), Vector3(0.36, 0.44, 0.16), B.col(Color(0.45, 0.07, 0.05), 0.5, 0.4), false)
		B.box(c, Vector3(0, 0.48, 0), Vector3(0.14, 0.05, 0.05), m_dark, false)
		Act.make(c, Vector3(0, 0.25, 0), Vector3(0.45, 0.6, 0.35), func() -> String: return g.canister_prompt(), func() -> void: g.take_canister(c))
		canisters.append(c)
	B.cyl(self, p + Vector3(1.3, 0.45, 1.1), 0.3, 0.9, B.tex("rust", 0.7, Color(0.3, 0.3, 0.3), 0.6, 0.5), true)
	note(7, p + Vector3(1.3, 0.905, 1.1), 0.6)
	B.box(self, p + Vector3(-0.2, 0.3, 1.2), Vector3(0.9, 0.6, 0.6), m_wood)


func _forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var trunks := MultiMesh.new()
	var crowns := MultiMesh.new()
	trunks.transform_format = MultiMesh.TRANSFORM_3D
	crowns.transform_format = MultiMesh.TRANSFORM_3D
	var tm := CylinderMesh.new()
	tm.top_radius = 0.08
	tm.bottom_radius = 0.2
	tm.height = 9.0
	tm.radial_segments = 6
	tm.material = B.tex("bark", 0.5, Color(0.35, 0.3, 0.28))
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 1.5
	cm.height = 6.5
	cm.radial_segments = 7
	cm.material = B.col(Color(0.02, 0.045, 0.035), 1.0)
	trunks.mesh = tm
	crowns.mesh = cm
	var pts: Array = []
	for i in 900:
		var p := Vector3(rng.randf_range(-70, 86), 0, rng.randf_range(-90, 66))
		if p.x > -34 and p.x < 48 and p.z > -54 and p.z < 30:
			continue
		if p.x > 46 and absf(p.z) < 5:
			continue
		pts.append(p)
	trunks.instance_count = pts.size()
	crowns.instance_count = pts.size()
	for i in pts.size():
		var s: float = rng.randf_range(0.8, 1.6)
		var bs := Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s))
		trunks.set_instance_transform(i, Transform3D(bs, pts[i] + Vector3(0, 4.5 * s, 0)))
		crowns.set_instance_transform(i, Transform3D(bs, pts[i] + Vector3(0, 6.5 * s, 0)))
	for mm in [trunks, crowns]:
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		add_child(mi)


func _truck() -> void:
	truck = Node3D.new()
	truck.position = GATE_POS + Vector3(4, 0, 0)
	truck.visible = false
	add_child(truck)
	var m := B.col(Color(0.2, 0.25, 0.18), 0.7, 0.3)
	B.box(truck, Vector3(0, 1.3, 0), Vector3(2.2, 1.6, 2.4), m, false)
	B.box(truck, Vector3(3.2, 1.5, 0), Vector3(4.2, 2.0, 2.5), B.col(Color(0.16, 0.18, 0.14), 0.9), false)
	for sx in [-0.6, 2.2, 4.4]:
		for sz in [-1.2, 1.2]:
			B.cyl(truck, Vector3(sx, 0.5, sz), 0.5, 0.35, m_dark).rotation.x = PI / 2
	for sz in [-0.8, 0.8]:
		var sl := SpotLight3D.new()
		sl.position = Vector3(-1.15, 1.1, sz)
		sl.rotation.y = PI / 2
		sl.light_energy = 14.0
		sl.spot_range = 60.0
		sl.spot_angle = 28.0
		sl.light_color = Color(1, 0.9, 0.7)
		truck.add_child(sl)
		B.ball(truck, Vector3(-1.12, 1.1, sz), 0.12, B.col(Color(1, 0.9, 0.7), 0.3, 0.0, 8.0))
