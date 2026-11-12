class_name Player
extends CharacterBody3D
## Игрок: ходьба/бег/присед, выносливость, дыхание, шаги и шум, фонарь, взаимодействие, прятки, бросок.

signal prompt_changed(text: String, hold: float)
signal battery_changed(v: float)

const WALK := 2.3
const RUN := 4.6
const CROUCH := 1.15
const EYE := 1.62
const EYE_CROUCH := 1.0
const GRAV := 18.0

var cam: Camera3D
var head: Node3D
var light: SpotLight3D
var light_glow: OmniLight3D
var ray: RayCast3D
var shape: CollisionShape3D
var yaw := 0.0
var pitch := 0.0
var crouching := false
var running := false
var stamina := 100.0
var stamina_lock := 0.0
var breath := 12.0
var holding_breath := false
var battery := 100.0
var flash_on := false
var flicker := 0.0
var flicker_force := 0.0
var step_dist := 0.0
var bob := 0.0
var eye := EYE
var input_lock := false          # кат-сцены, телефон, смерть
var look_lock := false
var hidden_in: Node = null       # шкафчик / полок
var hide_yaw := 0.0
var grabbed := false             # Хозяйка за спиной
var fear := 0.0
var shake := 0.0
var current_room := ""
var surface := "tile"
var water := 0.0
var hold_target: Node = null
var hold_time := 0.0
var held_item: RigidBody3D = null
var breath_snd: AudioStreamPlayer
var heart_snd: AudioStreamPlayer
var breath_timer := 0.0
var noclip := false
var speed_mult := 1.0
var _focus: Node = null
var _last_prompt := ""
var dead := false
var auto_move := Vector3.ZERO     # для теста «пешком»: направление движения вместо клавиш


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_max_angle = deg_to_rad(60)
	floor_snap_length = 0.35
	safe_margin = 0.02
	shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	add_child(shape)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.current = true
	cam.near = 0.05
	cam.far = 120.0
	cam.fov = Settings.fov
	cam.cull_mask = 0xFFFFF & ~Mirror.GHOST_LAYER
	head.add_child(cam)
	light = SpotLight3D.new()
	light.light_color = Color(1.0, 0.93, 0.8)
	light.light_energy = 3.2
	light.spot_range = 20.0
	light.spot_angle = 27.0
	light.spot_angle_attenuation = 0.9
	light.spot_attenuation = 1.1
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.0
	light.light_specular = 0.6
	var cookie: Texture2D = Mat.tex("res://tex/ui/flash_cookie.png")
	if cookie:
		light.light_projector = cookie
	light.position = Vector3(0.18, -0.2, 0.0)
	light.visible = false
	head.add_child(light)
	light_glow = OmniLight3D.new()
	light_glow.light_color = Color(1.0, 0.9, 0.75)
	light_glow.light_energy = 0.08
	light_glow.omni_range = 3.0
	light_glow.visible = false
	light_glow.shadow_enabled = false
	head.add_child(light_glow)
	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -2.3)
	ray.collision_mask = 1 | 4 | 8
	ray.collide_with_areas = false
	cam.add_child(ray)
	breath_snd = AudioStreamPlayer.new()
	breath_snd.bus = "SFX"
	breath_snd.stream = Snd.stream("loop_breath_heavy")
	breath_snd.volume_db = -80
	add_child(breath_snd)
	heart_snd = AudioStreamPlayer.new()
	heart_snd.bus = "SFX"
	heart_snd.stream = Snd.stream("loop_heartbeat")
	heart_snd.volume_db = -80
	add_child(heart_snd)
	if breath_snd.stream:
		breath_snd.play()
	if heart_snd.stream:
		heart_snd.play()
	Settings.changed.connect(func(): cam.fov = Settings.fov)
	battery = float(Game.getf("battery", 100.0))
	flash_on = bool(Game.getf("flash_on", false))
	light.visible = flash_on
	light_glow.visible = flash_on


func set_look(y: float, p := 0.0) -> void:
	yaw = y
	pitch = p
	rotation.y = yaw
	head.rotation.x = pitch


func _unhandled_input(e: InputEvent) -> void:
	if dead:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not look_lock:
		var s := Settings.mouse_sens * 0.01
		yaw -= e.relative.x * s
		pitch -= e.relative.y * s * (-1.0 if Settings.invert_y else 1.0)
		pitch = clampf(pitch, deg_to_rad(-85), deg_to_rad(85))
		if hidden_in:
			yaw = clampf(yaw, hide_yaw - deg_to_rad(55), hide_yaw + deg_to_rad(55))
			pitch = clampf(pitch, deg_to_rad(-30), deg_to_rad(25))
	if input_lock:
		return
	if e.is_action_pressed("flashlight"):
		toggle_light()
	if e.is_action_pressed("click") and held_item:
		throw_item()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("drop") and held_item:
		drop_item()


func toggle_light(force := -1) -> void:
	var want := not flash_on if force < 0 else force == 1
	if want and battery <= 0.0:
		Snd.play("flash_click", -10.0, 0.8)
		Game.think("Батарейка села.", 2.0)
		return
	flash_on = want
	light.visible = flash_on
	light_glow.visible = flash_on
	Snd.play("flash_click", -8.0, randf_range(0.95, 1.05))
	Game.set_flag("flash_on", flash_on)


func add_battery(v: float) -> void:
	battery = minf(100.0, battery + v)
	battery_changed.emit(battery)


## Кратковременное мигание фонаря (Хозяйка рядом, пугалка)
func flick(secs := 1.0) -> void:
	flicker_force = maxf(flicker_force, secs)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_update_env(delta)
	if noclip:
		_fly(delta)
	elif hidden_in:
		velocity = Vector3.ZERO
	else:
		_move(delta)
	rotation.y = yaw
	head.rotation.x = pitch
	_stamina(delta)
	_flashlight(delta)
	_camera(delta)
	_interact(delta)
	_audio(delta)


func _update_env(_delta: float) -> void:
	if Game.world == null:
		return
	var room: String = Game.world.room_at(global_position + Vector3.UP * 0.5)
	if room != current_room:
		current_room = room
		Game.world.player_room_changed(room)
	surface = Game.world.surface_at(global_position, room)
	water = Game.world.water_depth(global_position, room)


func _move(delta: float) -> void:
	var inp := Vector2.ZERO
	if not input_lock:
		inp = Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var want_crouch := not input_lock and Input.is_action_pressed("crouch")
	if auto_move != Vector3.ZERO:
		want_crouch = auto_move.y < 0.0
	if want_crouch != crouching:
		if not want_crouch and _blocked_above():
			want_crouch = true
		crouching = want_crouch
		(shape.shape as CapsuleShape3D).height = 1.1 if crouching else 1.75
		shape.position.y = 0.55 if crouching else 0.875
	running = not input_lock and Input.is_action_pressed("run") and inp.y < 0.1 and inp.length() > 0.1 \
		and not crouching and stamina > 0.0 and stamina_lock <= 0.0 and not grabbed and hidden_in == null
	var spd := CROUCH if crouching else (RUN if running else WALK)
	if water > 0.35:
		spd *= 0.62
	elif water > 0.08:
		spd *= 0.85
	if grabbed:
		spd = minf(spd, 1.4)
	spd *= speed_mult
	var dir := (transform.basis * Vector3(inp.x, 0, inp.y))
	if auto_move != Vector3.ZERO:
		dir = Vector3(auto_move.x, 0, auto_move.z)
	dir.y = 0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var hv := Vector3(velocity.x, 0, velocity.z)
	var accel := 10.0 if is_on_floor() else 3.0
	hv = hv.lerp(dir * spd, clampf(accel * delta, 0.0, 1.0))
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAV * delta
	move_and_slide()
	_step_up(dir)
	# шаги
	var moved := Vector2(hv.x, hv.z).length() * delta
	if is_on_floor() and moved > 0.0005:
		step_dist += moved
		var stride := 0.62 if crouching else (0.95 if running else 0.78)
		if step_dist >= stride:
			step_dist = 0.0
			_footstep()
		bob += moved * (9.0 if running else 7.0)
	else:
		step_dist = maxf(0.0, step_dist - delta)


## Подъём на невысокую ступеньку (поддон, порожек) до 0.3 м.
func _step_up(dir: Vector3) -> void:
	if dir.length() < 0.1 or not is_on_floor() or not is_on_wall():
		return
	var fwd := dir.normalized() * 0.25
	var up := Vector3.UP * 0.32
	if test_move(global_transform, up):
		return
	var raised := global_transform.translated(up)
	if test_move(raised, fwd):
		return
	var col := KinematicCollision3D.new()
	var moved := raised.translated(fwd)
	if test_move(moved, Vector3.DOWN * 0.34, col):
		var drop := col.get_travel().y
		global_position += up + fwd * 0.4 + Vector3(0, drop, 0)


func _blocked_above() -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.UP * 1.85, 1)
	q.exclude = [get_rid()]
	return not space.intersect_ray(q).is_empty()


func _fly(delta: float) -> void:
	var inp := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var dir := cam.global_transform.basis * Vector3(inp.x, 0, inp.y)
	if Input.is_action_pressed("fly_up"):
		dir.y += 1.0
	if Input.is_action_pressed("fly_down"):
		dir.y -= 1.0
	var spd := 12.0 if Input.is_action_pressed("run") else 5.0
	global_position += dir * spd * delta
	velocity = Vector3.ZERO


func set_noclip(on: bool) -> void:
	noclip = on
	collision_mask = 0 if on else (1 | 4)


## Шаг: звук по поверхности + шум для Хозяйки.
func _footstep() -> void:
	var gait := "crouch" if crouching else ("run" if running else "walk")
	var snd := "step_" + surface
	var wet: bool = Game.world.is_wet(global_position, current_room) if Game.world else false
	if water > 0.08:
		snd = "step_water"
	elif wet and surface == "tile":
		snd = "step_tile_wet"
	var db: float = {"crouch": -16.0, "walk": -8.0, "run": -2.0}[gait]
	Snd.play(snd, db, randf_range(0.92, 1.08))
	if Game.world:
		var r := float({"crouch": 1.5, "walk": 6.0, "run": 14.0}[gait])
		if water > 0.08:
			r *= 3.0
		elif wet:
			r *= 1.7
		Game.world.noise(global_position, r, "step", water > 0.08)


func _stamina(delta: float) -> void:
	if running:
		stamina = maxf(0.0, stamina - 16.0 * delta)
		if stamina <= 0.0:
			stamina_lock = 2.5
	else:
		stamina_lock = maxf(0.0, stamina_lock - delta)
		stamina = minf(100.0, stamina + (14.0 if crouching or velocity.length() < 0.2 else 9.0) * delta)
	# задержка дыхания
	var want_hold := Input.is_action_pressed("breath") and not input_lock and breath > 0.0
	if want_hold and not holding_breath:
		holding_breath = true
		Snd.play("breath_in", -10.0)
	elif holding_breath and (not want_hold or breath <= 0.0):
		holding_breath = false
		var gasp := breath <= 0.0
		Snd.play("breath_gasp" if gasp else "breath_out", -2.0 if gasp else -8.0)
		if Game.world:
			Game.world.noise(global_position, 8.0 if gasp else 3.0, "breath")
		if gasp:
			stamina = minf(stamina, 25.0)
	if holding_breath:
		breath = maxf(0.0, breath - delta)
	else:
		breath = minf(12.0, breath + delta * 1.5)
	# одышка шумит
	breath_timer -= delta
	if breath_timer <= 0.0:
		breath_timer = 1.2
		if stamina < 40.0 and not holding_breath and Game.world:
			Game.world.noise(global_position, 4.0, "breath")


func _flashlight(delta: float) -> void:
	if flash_on:
		battery = maxf(0.0, battery - delta * (100.0 / 1260.0))
		if battery <= 0.0:
			flash_on = false
			light.visible = false
			light_glow.visible = false
			Snd.play("flash_click", -10.0, 0.7)
			Game.think("Фонарь погас. Батарейка всё.", 3.0)
		battery_changed.emit(battery)
	flicker_force = maxf(0.0, flicker_force - delta)
	var e := 3.2 * clampf(0.35 + battery / 60.0, 0.35, 1.0)
	if Game.cheats.get("fullbright", false):
		e = 3.2
	if flicker_force > 0.0 or (battery < 15.0 and randf() < 0.02):
		flicker = randf()
	else:
		flicker = lerpf(flicker, 1.0, delta * 20.0)
	light.light_energy = e * (flicker if flicker < 0.6 else 1.0) * (0.0 if flicker < 0.25 else 1.0)
	# фонарь чуть отстаёт от взгляда — живее
	var tgt := Basis.IDENTITY
	light.basis = light.basis.slerp(tgt, clampf(delta * 14.0, 0.0, 1.0))


func _camera(delta: float) -> void:
	var tgt_eye := EYE_CROUCH if crouching else EYE
	if hidden_in and hidden_in.has_method("eye_height"):
		tgt_eye = hidden_in.eye_height()
	eye = lerpf(eye, tgt_eye, clampf(delta * 8.0, 0.0, 1.0))
	var by := 0.0
	var bx := 0.0
	if Settings.head_bob and is_on_floor() and not hidden_in:
		var amp := 0.05 if running else 0.025
		by = sin(bob * 2.0) * amp
		bx = cos(bob) * amp * 0.6
	shake = maxf(0.0, shake - delta * 1.5)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.04
	head.position = Vector3(bx, eye + by, 0) + sh
	cam.rotation.z = lerpf(cam.rotation.z, -Input.get_axis("move_l", "move_r") * 0.012 if not input_lock else 0.0, delta * 5.0)


func _interact(delta: float) -> void:
	if input_lock or noclip:
		_set_prompt("", 0.0)
		return
	var target: Node = null
	if hidden_in:
		target = hidden_in
	elif ray.is_colliding():
		target = _usable_of(ray.get_collider())
	var text := ""
	if target and target.has_method("get_prompt"):
		text = String(target.get_prompt(self))
	if text == "":
		target = null
	_focus = target
	var hold := 0.0
	if target and "hold" in target:
		hold = float(target.hold)
	var pressed := Input.is_action_pressed("use") or (Input.is_action_pressed("click") and held_item == null)
	if target and hold > 0.0:
		if pressed:
			if hold_target != target:
				hold_target = target
				_hold_start(target)
			var why := ""
			if target.has_method("blocked"):
				why = target.blocked()
			if why != "":
				if Input.is_action_just_pressed("use") or Input.is_action_just_pressed("click"):
					Game.think(why, 3.0)
				hold_target = null
			else:
				target.progress += delta
				if "hold_noise" in target and float(target.hold_noise) > 0.0 and Game.world:
					hold_time += delta
					if hold_time > 0.8:
						hold_time = 0.0
						Game.world.noise(global_position, float(target.hold_noise), "work")
				if target.progress >= hold:
					target.progress = 0.0
					_hold_stop()
					target.use(self)
		else:
			if hold_target:
				_hold_stop()
		var p := float(target.progress) / hold if target else 0.0
		_set_prompt(text, clampf(p, 0.0, 1.0) if target else 0.0)
		return
	if hold_target:
		_hold_stop()
	_set_prompt(text, -1.0)
	if target and (Input.is_action_just_pressed("use") or (Input.is_action_just_pressed("click") and held_item == null)):
		target.use(self)


var _hold_snd: AudioStreamPlayer3D


func _hold_start(target: Node) -> void:
	if "hold_sound" in target and String(target.hold_sound) != "":
		_hold_snd = Snd.attach(String(target.hold_sound), target as Node3D, -2.0, 18.0)


func _hold_stop() -> void:
	hold_target = null
	if _hold_snd and is_instance_valid(_hold_snd):
		_hold_snd.queue_free()
	_hold_snd = null


func _usable_of(n: Object) -> Node:
	if n == null:
		return null
	if n is Node and (n as Node).has_meta("door"):
		return (n as Node).get_meta("door")
	if n is Node and (n as Node).has_meta("usable"):
		return (n as Node).get_meta("usable")
	var cur: Node = n as Node
	for i in 4:
		if cur == null:
			return null
		if cur.has_method("get_prompt"):
			return cur
		cur = cur.get_parent()
	return null


func _set_prompt(text: String, hold: float) -> void:
	var key := text + str(snappedf(hold, 0.02))
	if key == _last_prompt:
		return
	_last_prompt = key
	prompt_changed.emit(text, hold)


func _audio(delta: float) -> void:
	var exhausted := clampf((45.0 - stamina) / 45.0, 0.0, 1.0)
	if holding_breath:
		exhausted = 0.0
	if breath_snd.stream:
		breath_snd.volume_db = lerpf(breath_snd.volume_db, linear_to_db(maxf(exhausted * 0.5, 0.0001)), delta * 3.0)
	if heart_snd.stream:
		heart_snd.volume_db = lerpf(heart_snd.volume_db, linear_to_db(maxf(fear * 0.9, 0.0001)), delta * 2.0)
		heart_snd.pitch_scale = 0.85 + fear * 0.45


# ---------- предметы в руках ----------

func pick_item(body: RigidBody3D) -> void:
	if held_item:
		drop_item()
	held_item = body
	body.freeze = true
	body.collision_layer = 0
	body.reparent(cam)
	body.position = Vector3(0.28, -0.32, -0.55)
	body.rotation = Vector3(0.3, 0.4, 0)
	Snd.play("pickup_metal", -6.0)
	Game.show_hint("ЛКМ — бросить (шум уведёт её), G — положить", 4.0)


func throw_item() -> void:
	if held_item == null:
		return
	var b := held_item
	held_item = null
	var gp := b.global_transform
	b.reparent(Game.world)
	b.global_transform = gp
	b.freeze = false
	b.collision_layer = 1 << 5
	b.collision_mask = 1 | 4
	b.linear_velocity = -cam.global_transform.basis.z * 11.0 + Vector3.UP * 2.0 + velocity
	b.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-6, 6), randf_range(-6, 6))
	if b.has_method("thrown"):
		b.thrown()
	Snd.play("throw", -6.0)


func drop_item() -> void:
	if held_item == null:
		return
	var b := held_item
	held_item = null
	var gp := b.global_transform
	b.reparent(Game.world)
	b.global_transform = gp
	b.freeze = false
	b.collision_layer = 1 << 5
	b.collision_mask = 1 | 4
	b.linear_velocity = velocity


# ---------- прятки ----------

func hide_in(spot: Node, pos: Vector3, look_yaw: float) -> void:
	hidden_in = spot
	global_position = pos
	hide_yaw = look_yaw
	yaw = look_yaw
	pitch = 0.0
	velocity = Vector3.ZERO
	collision_layer = 0
	if held_item:
		drop_item()
	Snd.muffle(true, 1800.0)
	if Game.world:
		Game.world.noise(global_position, 5.0, "hide")


func unhide(out_pos: Vector3) -> void:
	hidden_in = null
	global_position = out_pos
	collision_layer = 2
	Snd.muffle(false)
	if Game.world:
		Game.world.noise(global_position, 5.0, "hide")


func is_moving() -> bool:
	return Vector2(velocity.x, velocity.z).length() > 0.4


func look_dir() -> Vector3:
	return -cam.global_transform.basis.z


func eye_pos() -> Vector3:
	return cam.global_position
