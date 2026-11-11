extends CharacterBody3D
## First-person controller: walk / sprint, flashlight, interaction, hiding, cold.

var g: Node
var cam: Camera3D
var torch: SpotLight3D
var ray: RayCast3D
var sens: float = 0.0022
var pitch: float = 0.0
var alive: bool = true
var control: bool = true
var noclip: bool = false
var god: bool = false

var flash_on: bool = false
var battery: float = 100.0
var spare: int = 0
var stamina: float = 100.0
var cold: float = 0.0          # 0 warm .. 100 frozen
var carrying: bool = false
var hidden: int = -1           # locker index
var breath: float = 100.0
var holding_breath: bool = false
var noise_t: float = 0.0       # > 0 while the player is loud
var cur_act: Act = null
var hold_t: float = 0.0
var step_acc: float = 0.0
var bob: float = 0.0
var shake: float = 0.0
var lit_drain: float = 0.0
var _hide_cd: float = 0.0


func _ready() -> void:
	collision_layer = 32
	collision_mask = 1 | 4 | 16
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	cam = Camera3D.new()
	cam.position.y = 1.62
	cam.fov = 72.0
	cam.near = 0.05
	cam.far = 160.0
	add_child(cam)
	cam.make_current()
	torch = SpotLight3D.new()
	torch.spot_range = 24.0
	torch.spot_angle = 26.0
	torch.spot_angle_attenuation = 0.7
	torch.light_energy = 0.0
	torch.light_color = Color(1.0, 0.95, 0.82)
	torch.shadow_enabled = true
	torch.shadow_bias = 0.06
	torch.position = Vector3(0.18, -0.15, -0.1)
	cam.add_child(torch)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collision_mask = 1 | 2 | 16
	cam.add_child(ray)
	var listener := AudioListener3D.new()
	cam.add_child(listener)
	listener.make_current()


func _unhandled_input(e: InputEvent) -> void:
	if not alive or not control:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation.y -= e.relative.x * sens
		pitch = clampf(pitch - e.relative.y * sens, -1.45, 1.45)
	if e.is_action_pressed("flash"):
		flash_on = not flash_on
		Snd.play("click", -6.0)
	if e.is_action_pressed("reload") and spare > 0 and battery < 60.0:
		spare -= 1
		battery = 100.0
		Snd.play("bolt", -8.0, 1.5)
		g.hud.say("Батарея заменена. Осталось: %d" % spare, 2.5)
	if e.is_action_pressed("use"):
		if hidden >= 0:
			if _hide_cd <= 0.0:
				unhide()
		elif cur_act != null and cur_act.hold <= 0.0:
			cur_act.use_fn.call()


func outside() -> bool:
	return absf(global_position.x) > 8.0 or absf(global_position.z) > 5.0


func eye() -> Vector3:
	return cam.global_position


func look_dir() -> Vector3:
	return -cam.global_transform.basis.z


## True when the flashlight beam is on the given point.
func lights(p: Vector3) -> bool:
	if not flash_on or battery <= 0.0:
		return false
	var to: Vector3 = p - eye()
	var d: float = to.length()
	if d > 21.0 or look_dir().dot(to / d) < 0.94:
		return false
	return g.los(eye(), p)


func sees(p: Vector3, cone: float = 0.8) -> bool:
	var to: Vector3 = p - eye()
	return look_dir().dot(to.normalized()) > cone and g.los(eye(), p)


func hide_in(idx: int) -> void:
	if hidden >= 0 or carrying:
		if carrying:
			g.hud.say("С канистрой в шкаф не влезть.", 2.0)
		return
	hidden = idx
	_hide_cd = 0.6
	var l: Dictionary = g.world.lockers[idx]
	global_position = l.pos
	var f: Vector3 = l.face
	rotation.y = atan2(-f.x, -f.z)
	pitch = 0.0
	velocity = Vector3.ZERO
	flash_on = false
	Snd.play("door_close", -6.0, 1.3)
	g.on_player_hid()


func unhide() -> void:
	var l: Dictionary = g.world.lockers[hidden]
	global_position = l.front
	hidden = -1
	holding_breath = false
	Snd.play("door_open", -8.0, 1.3)


func _physics_process(dt: float) -> void:
	if not alive:
		return
	_hide_cd -= dt
	noise_t = maxf(0.0, noise_t - dt)
	cam.rotation.x = pitch + sin(bob * 2.0) * 0.004 + randf_range(-1, 1) * shake * 0.03
	cam.rotation.z = randf_range(-1, 1) * shake * 0.03
	cam.position.y = 1.62 + sin(bob * 2.0) * 0.022
	shake = maxf(0.0, shake - dt * 1.5)
	_flashlight(dt)
	if hidden >= 0:
		cam.position.y = 1.55
		holding_breath = control and Input.is_action_pressed("breath") and breath > 0.0
		breath = clampf(breath + (-12.0 if holding_breath else 9.0) * dt, 0.0, 100.0)
		cur_act = null
		return
	breath = minf(100.0, breath + 20.0 * dt)
	_move(dt)
	_interact(dt)
	_cold(dt)


func _move(dt: float) -> void:
	var iv := Vector2.ZERO
	if control:
		iv = Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var dir: Vector3 = (transform.basis * Vector3(iv.x, 0, iv.y)).normalized()
	if noclip:
		var up: float = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		var v: Vector3 = (cam.global_transform.basis * Vector3(iv.x, 0, iv.y)) + Vector3.UP * up
		global_position += v * dt * (18.0 if Input.is_action_pressed("sprint") else 7.0)
		return
	var out: bool = outside()
	var sprint: bool = control and Input.is_action_pressed("sprint") and iv.y < 0 and stamina > 1.0
	var sp: float = 2.9 if out else 3.3
	if sprint:
		sp = 4.7 if out else 5.4
		stamina -= dt * (16.0 if not carrying else 26.0)
		noise_t = 0.4
	else:
		stamina = minf(100.0, stamina + dt * 11.0)
	if carrying:
		sp *= 0.82
	sp *= 1.0 - 0.45 * clampf((cold - 60.0) / 40.0, 0.0, 1.0)
	var k: float = 10.0 if is_on_floor() else 2.0
	velocity.x = lerpf(velocity.x, dir.x * sp, dt * k)
	velocity.z = lerpf(velocity.z, dir.z * sp, dt * k)
	velocity.y = velocity.y - 18.0 * dt if not is_on_floor() else -0.5
	move_and_slide()
	var hv: float = Vector2(velocity.x, velocity.z).length()
	if hv > 0.5 and is_on_floor():
		bob += dt * hv * 2.2
		step_acc += dt * hv
		if step_acc > (1.55 if not sprint else 1.9):
			step_acc = 0.0
			var kind: String = "step_snow" if out else "step_wood"
			Snd.play("%s%d" % [kind, randi_range(1, 4)], -9.0 if not sprint else -4.0, randf_range(0.9, 1.1))


func _flashlight(dt: float) -> void:
	if flash_on and battery > 0.0:
		battery = maxf(0.0, battery - dt * (100.0 / 170.0) - lit_drain * dt)
		var e: float = 2.6
		if battery < 18.0:
			e *= 0.35 + 0.65 * float(randf() > 0.25) * (battery / 18.0 + 0.3)
		torch.light_energy = e
		if battery <= 0.0:
			Snd.play("click", -4.0, 0.7)
			g.hud.say("Фонарь сел." + (" [R] — сменить батарею" if spare > 0 else ""), 3.0)
	else:
		torch.light_energy = 0.0
	lit_drain = 0.0


func _interact(dt: float) -> void:
	var a: Act = null
	if control and ray.is_colliding():
		var c: Object = ray.get_collider()
		if c is Act and c.prompt() != "":
			a = c
	if a != cur_act:
		cur_act = a
		hold_t = 0.0
	if a != null and a.hold > 0.0:
		if Input.is_action_pressed("use"):
			if hold_t == 0.0 and not g.hold_allowed(a):
				return
			hold_t += dt
			noise_t = 0.3
			if hold_t >= a.hold:
				hold_t = -999.0
				a.use_fn.call()
		else:
			hold_t = 0.0


func _cold(dt: float) -> void:
	if god:
		cold = 0.0
		return
	if outside():
		cold += dt * (100.0 / 80.0)
	else:
		cold -= dt * (5.0 if g.lit() else 1.5)
	cold = clampf(cold, 0.0, 100.0)
	if cold >= 100.0:
		g.kill("cold")
