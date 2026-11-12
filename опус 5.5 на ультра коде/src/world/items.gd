class_name Items
## Подбираемые и бросаемые вещи, вентили, зеркала, свет огня.


## Шайка (жестяной таз): взять E, бросить ЛКМ — громкий звон уводит Хозяйку.
class Basin:
	extends RigidBody3D
	var flying := false
	var cool := 0.0

	func _ready() -> void:
		mass = 0.6
		collision_layer = 1 << 5
		collision_mask = 1 | 4
		contact_monitor = true
		max_contacts_reported = 2
		continuous_cd = true
		body_entered.connect(_hit)
		var mat := Mat.flat(Color(0.55, 0.56, 0.55), 0.35, 0.85)
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.2
		cm.bottom_radius = 0.15
		cm.height = 0.12
		cm.radial_segments = 16
		mi.mesh = cm
		mi.material_override = mat
		add_child(mi)
		for s in [-1.0, 1.0]:
			Geo.mesh_box(self, Vector3(0.06, 0.02, 0.03), mat, Vector3(s * 0.21, 0.04, 0))
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = 0.19
		sh.height = 0.12
		cs.shape = sh
		add_child(cs)
		var u := StaticBody3D.new()
		u.collision_layer = 8
		add_child(u)
		var cs2 := CollisionShape3D.new()
		var sh2 := BoxShape3D.new()
		sh2.size = Vector3(0.45, 0.2, 0.45)
		cs2.shape = sh2
		u.add_child(cs2)
		u.set_meta("usable", self)

	func get_prompt(_p: Node) -> String:
		if Game.player and Game.player.held_item == self:
			return ""
		return "Взять шайку"

	func use(p: Node) -> void:
		(p as Player).pick_item(self)

	func thrown() -> void:
		flying = true

	func _process(delta: float) -> void:
		cool = maxf(0.0, cool - delta)

	func _hit(_b: Node) -> void:
		if cool > 0.0:
			return
		var v := linear_velocity.length()
		if v < 1.0:
			return
		cool = 0.25
		Snd.at("basin_clang", global_position, clampf(-14.0 + v * 2.0, -12.0, 4.0), randf_range(0.9, 1.1), 30.0)
		if flying and Game.world:
			Game.world.noise(global_position, 22.0, "throw")
		flying = false


## Предмет на полу/столе: E — забрать. kind: item / note / battery / photo
static func pickup(parent: Node3D, pos: Vector3, kind: String, id: String, label: String, visual: Node3D = null, after: Callable = Callable()) -> Usable:
	var u := Usable.make(parent, pos, Vector3(0.4, 0.3, 0.4), label, Callable())
	u.once = true
	if visual:
		u.add_child(visual)
	u.on_use = func():
		match kind:
			"item":
				Game.give(id)
			"note":
				Game.add_note(id)
				if Game.main and Game.main.has_method("show_note"):
					Game.main.show_note(id)
			"battery":
				if Game.player:
					Game.player.add_battery(55.0)
				Snd.play("battery", -4.0)
				Game.think("Батарейки. Фонарь ещё поживёт.", 2.5)
		Game.set_flag("took:" + id)
		if after.is_valid():
			after.call()
		u.queue_free()
	if Game.flag("took:" + id):
		u.queue_free()
	return u


## Бумага/записка, лежащая плоско.
static func paper_visual(tex_path: String, size := Vector2(0.21, 0.28)) -> Node3D:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	mi.material_override = Mat.picture(tex_path, {"rough": 0.9})
	mi.rotation.x = -PI * 0.5
	mi.position.y = -0.14
	return mi


static func battery_visual() -> Node3D:
	var n := Node3D.new()
	var m := Mat.flat(Color(0.15, 0.3, 0.6), 0.5, 0.2)
	var m2 := Mat.flat(Color(0.7, 0.7, 0.68), 0.3, 0.9)
	for i in 2:
		var c := Geo.mesh_cyl(n, 0.017, 0.06, m, Vector3(i * 0.04 - 0.02, -0.12, 0))
		c.rotation.z = PI * 0.5
		var cap := Geo.mesh_cyl(n, 0.008, 0.008, m2, Vector3(i * 0.04 - 0.02 + 0.033, -0.12, 0))
		cap.rotation.z = PI * 0.5
	return n


static func key_visual() -> Node3D:
	var n := Node3D.new()
	var m := Mat.flat(Color(0.55, 0.48, 0.3), 0.35, 0.9)
	Geo.mesh_box(n, Vector3(0.06, 0.004, 0.025), m, Vector3(0, -0.14, 0))
	Geo.mesh_cyl(n, 0.018, 0.005, m, Vector3(-0.045, -0.14, 0))
	var tag := Geo.mesh_box(n, Vector3(0.05, 0.003, 0.03), Mat.flat(Color(0.7, 0.2, 0.15), 0.8), Vector3(-0.09, -0.142, 0.01))
	tag.rotation.y = 0.4
	return n


## Вентиль: держать E, колесо крутится, скрип; done — по завершении.
static func valve(parent: Node3D, pos: Vector3, normal_yaw: float, radius: float, label: String, hold: float, done: Callable, cond := Callable(), noise_r := 10.0) -> Usable:
	var u := Usable.make(parent, pos, Vector3(radius * 2.2, radius * 2.2, 0.3), label, done, hold)
	u.rotation.y = normal_yaw
	u.cond = cond
	u.hold_sound = "loop_valve"
	u.hold_noise = noise_r
	var wheel := Node3D.new()
	u.add_child(wheel)
	var m := Mat.flat(Color(0.45, 0.12, 0.08), 0.6, 0.4)
	var tor := TorusMesh.new()
	tor.inner_radius = radius - 0.025
	tor.outer_radius = radius
	tor.rings = 24
	tor.ring_segments = 8
	var tm := MeshInstance3D.new()
	tm.mesh = tor
	tm.material_override = m
	tm.rotation.x = PI * 0.5
	wheel.add_child(tm)
	for a in 3:
		var sp := Geo.mesh_box(wheel, Vector3(radius * 2.0, 0.025, 0.02), m, Vector3.ZERO)
		sp.rotation.z = a * PI / 3.0
	Geo.mesh_cyl(wheel, 0.03, 0.12, Mat.flat(Color(0.3, 0.3, 0.3), 0.5, 0.8), Vector3(0, 0, 0.06)).rotation.x = PI * 0.5
	u.spin = wheel
	return u


## Огонь в топке: оранжевый мерцающий свет.
class Fire:
	extends OmniLight3D
	var base := 2.0
	var t := 0.0

	func _ready() -> void:
		light_color = Color(1.0, 0.45, 0.15)
		omni_range = 6.0
		omni_attenuation = 1.4
		light_energy = base
		shadow_enabled = false

	func _process(delta: float) -> void:
		t += delta
		light_energy = base * (0.75 + 0.15 * sin(t * 9.0) + 0.1 * sin(t * 23.0 + 1.3) + randf() * 0.08)


## Свеча: маленький огонёк и тёплый свет.
static func candle(parent: Node3D, pos: Vector3, lit := true) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	n.global_position = pos
	var wax := Mat.flat(Color(0.85, 0.8, 0.68), 0.6)
	Geo.mesh_cyl(n, 0.018, 0.12 + randf() * 0.06, wax, Vector3(0, 0.07, 0), 8)
	if lit:
		var fl := Mat.flat(Color(1, 0.7, 0.3), 0.5, 0.0, {"emission": Color(1.0, 0.6, 0.2), "emission_energy": 6.0, "unshaded": true})
		var f := Geo.mesh_cyl(n, 0.006, 0.03, fl, Vector3(0, 0.17, 0), 6, 0.0)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var l := Fire.new()
		l.base = 0.45
		l.omni_range = 3.5
		l.light_color = Color(1.0, 0.62, 0.3)
		l.position = Vector3(0, 0.25, 0)
		n.add_child(l)
	return n
