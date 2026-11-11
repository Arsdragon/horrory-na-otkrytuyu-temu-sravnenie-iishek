extends CharacterBody3D
## Контролёр. WASD, Shift бег, Ctrl присед, F фонарь, E действие, Q задержать дыхание (в шкафу).

var game  # game.gd
var col: CollisionShape3D
var cam: Camera3D
var head: Node3D
var light: SpotLight3D
var ray: RayCast3D
var yaw := 0.0
var pitch := 0.0
var stamina := 1.0
var battery := 100.0
var breath := 1.0
var holding_breath := false
var light_on := false
var hidden := false
var hide_wardrobe: Node3D
var noclip := false
var god := false
var locked := false   # скример / финал
var crouch := false
var running := false
var _step_t := 0.0
var _step_i := 0
var _bob := 0.0
var _breath_t := 0.0
var _flicker := 0.0
var read_target: Node3D
var read_progress := 0.0

func setup(g) -> void:
	game = g
	var cs := CollisionShape3D.new()
	col = cs
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 72
	cam.near = 0.05
	cam.far = 60
	head.add_child(cam)
	light = SpotLight3D.new()
	light.spot_range = 15.0
	light.spot_angle = 26.0
	light.spot_attenuation = 1.2
	light.light_energy = 2.6
	light.light_color = Color(1.0, 0.93, 0.8)
	light.shadow_enabled = true
	light.position = Vector3(0.18, -0.2, 0)
	light.visible = false
	cam.add_child(light)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collision_mask = 3
	ray.exclude_parent = true
	cam.add_child(ray)
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.4

func _unhandled_input(e: InputEvent) -> void:
	if locked or game.paused: return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * G.sens
		pitch = clamp(pitch - e.relative.y * G.sens, -1.45, 1.45)
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_F: toggle_light()
			KEY_E: _use()
			KEY_V:
				if game.admin_on: set_noclip(not noclip)

func toggle_light() -> void:
	if battery <= 0 and not light_on: G.play2d("click", -6, 0.7); return
	light_on = not light_on
	light.visible = light_on
	G.play2d("click", -4)

func _use() -> void:
	if hidden:
		unhide()
		return
	var t := _look_target()
	if t == null: return
	match t.get_meta("kind"):
		"wardrobe": hide_in(t)
		"battery":
			battery = min(100.0, battery + 50.0)
			G.play2d("click", 0, 1.4)
			game.hud.toast("Батарейка «Крона» (+50%)")
			game.world.batteries.erase(t)
			t.queue_free()
		"note":
			G.play2d("page")
			game.read_note(t.get_meta("id"))
		"exit":
			game.try_exit()

func _look_target() -> Node3D:
	ray.force_raycast_update()
	if not ray.is_colliding(): return null
	var c := ray.get_collider() as Node3D
	if c and c.has_meta("kind"): return c
	return null

func hint_text() -> String:
	if hidden: return "[E] выйти из шкафа    [Q] задержать дыхание"
	var t := _look_target()
	if t == null: return ""
	match t.get_meta("kind"):
		"wardrobe": return "[E] спрятаться в шкаф"
		"battery": return "[E] взять батарейку"
		"note": return "[E] прочитать"
		"meter": return "" if t.get_meta("read") else "[удерживай E] снять показания"
		"exit": return "[E] дверь подъезда"
	return ""

func hide_in(w: Node3D) -> void:
	hidden = true
	hide_wardrobe = w
	G.play2d("creak", -4)
	game.make_noise(w.global_position, 3.0)
	var ins: Vector3 = w.get_meta("inside")
	global_position = ins - Vector3(0, 1.6, 0)
	yaw = w.get_meta("yaw")
	pitch = 0
	velocity = Vector3.ZERO
	col.disabled = true
	if light_on: toggle_light()
	game.on_player_hid(w)

func unhide() -> void:
	if not hidden: return
	var w := hide_wardrobe
	hidden = false
	hide_wardrobe = null
	holding_breath = false
	global_position = w.get_meta("front")
	col.disabled = noclip
	G.play2d("creak", -2, 1.1)
	game.make_noise(global_position, 4.0)

func _physics_process(dt: float) -> void:
	if game.paused: return
	head.rotation = Vector3(pitch, 0, 0)
	rotation.y = yaw
	_update_light(dt)
	if locked: return
	if hidden:
		_hidden_tick(dt)
		return
	# чтение счётчика
	var t := _look_target()
	if Input.is_key_pressed(KEY_E) and t and t.get_meta("kind") == "meter" and not t.get_meta("read"):
		if read_target != t: read_target = t; read_progress = 0.0
		read_progress += dt / 2.5
		if read_progress >= 1.0:
			read_progress = 0.0
			game.meter_read(t)
	else:
		read_progress = 0.0
		read_target = null
	var input := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	crouch = Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_C)
	running = Input.is_key_pressed(KEY_SHIFT) and not crouch and input.length() > 0 and stamina > 0.05
	if noclip:
		var spd := 12.0 if Input.is_key_pressed(KEY_SHIFT) else 5.0
		var dir := cam.global_transform.basis * Vector3(input.x, 0, input.y)
		if Input.is_key_pressed(KEY_SPACE): dir.y += 1
		if Input.is_key_pressed(KEY_CTRL): dir.y -= 1
		global_position += dir.normalized() * spd * dt if dir.length() > 0.01 else Vector3.ZERO
		return
	var speed := 2.6
	if crouch: speed = 1.3
	elif running: speed = 5.2 if not game.admin_fast else 9.0
	if running: stamina = max(0.0, stamina - dt / 6.0)
	else: stamina = min(1.0, stamina + dt / (9.0 if input.length() > 0 else 5.0))
	var wish := (transform.basis * Vector3(input.x, 0, input.y)).normalized() * speed
	velocity.x = move_toward(velocity.x, wish.x, 30 * dt)
	velocity.z = move_toward(velocity.z, wish.z, 30 * dt)
	if not is_on_floor(): velocity.y -= 18.0 * dt
	else: velocity.y = -0.5
	move_and_slide()
	# камера: присед и покачивание
	var hv := Vector2(velocity.x, velocity.z).length()
	var target_h := 1.0 if crouch else 1.6
	_bob += dt * hv * 2.2
	head.position.y = lerp(head.position.y, target_h + sin(_bob) * 0.035 * min(hv, 3.0) / 3.0, 10 * dt)
	head.position.x = cos(_bob * 0.5) * 0.02 * min(hv, 3.0) / 3.0
	# шаги = шум
	if hv > 0.5 and is_on_floor():
		_step_t -= dt * hv
		if _step_t <= 0:
			_step_t = 1.7
			_footstep()
	# одышка после бега
	if stamina < 0.3:
		_breath_t -= dt
		if _breath_t <= 0:
			_breath_t = 2.4
			G.play2d("breath", -8)
			game.make_noise(global_position, 4.0)

func _footstep() -> void:
	var r := 2.0 if crouch else (16.0 if running else 7.0)
	var name := "step%d" % (_step_i % 4)
	_step_i += 1
	var db := -14.0 if crouch else (-2.0 if running else -8.0)
	if game.on_glass(global_position) and not crouch:
		G.play2d("glass", -2, randf_range(0.9, 1.1))
		r = max(r, 12.0)
	G.play2d(name, db, randf_range(0.9, 1.1))
	game.make_noise(global_position, r)

func _hidden_tick(dt: float) -> void:
	holding_breath = Input.is_key_pressed(KEY_Q) and breath > 0.0
	if holding_breath:
		breath = max(0.0, breath - dt / 7.0)
		if breath <= 0.0:
			G.play2d("gasp", 0)
			game.make_noise(global_position, 8.0)
			breath = 0.0
	else:
		breath = min(1.0, breath + dt / 5.0)
		_breath_t -= dt
		if _breath_t <= 0:
			_breath_t = 3.0
			G.play2d("breath", -16)
			game.make_noise(global_position + Vector3(0, 1, 0), 3.5)

func _update_light(dt: float) -> void:
	if light_on:
		battery = max(0.0, battery - dt * 0.55)
		if battery <= 0:
			light_on = false
			light.visible = false
			game.hud.toast("Фонарь сел")
	var base: float = 2.6 * clamp(battery / 25.0, 0.25, 1.0)
	var d: float = game.entity_dist()
	_flicker -= dt
	if d < 11.0 and light_on and _flicker <= 0:
		_flicker = randf_range(0.04, 0.4) * (d / 11.0 + 0.2)
		light.light_energy = base * (0.05 if randf() < 0.45 else 1.0)
	elif d >= 11.0:
		light.light_energy = base

func set_noclip(on: bool) -> void:
	noclip = on
	col.disabled = on or hidden
	velocity = Vector3.ZERO
	game.hud.toast("Полёт: " + ("вкл" if on else "выкл"))
