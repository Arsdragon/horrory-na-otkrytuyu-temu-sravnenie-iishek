class_name Player
extends CharacterBody3D
## Наблюдатель: ходьба, налобный фонарь, хват за леер, тепло, выносливость, действия, фальшфейер.

signal stepped(pos: Vector3, yaw: float, left: bool, run: bool)
signal lamp_changed(on: bool)
signal grip_changed(on: bool)
signal flare_lit

const EYE := 1.62
const WALK_OUT := 2.5
const WALK_IN := 2.15
const RUN_K := 1.65
const REACH := 2.3
const LAMP_E := 13.0

var world: Node3D = null         # World
var head: Node3D
var cam: Camera3D
var lamp_pivot: Node3D
var lamp: SpotLight3D
var fill: OmniLight3D
var flare_light: OmniLight3D
var flare_halo: MeshInstance3D
var puff: GPUParticles3D
var hand: Node3D
var col: CollisionShape3D

var yaw := 0.0
var pitch := 0.0
var eye_h := EYE
var mode := "walk"               # walk | locked | bed | hide | dead | free
var look_base_yaw := 0.0         # для кровати и укрытия: вокруг чего можно вертеть головой
var look_lim := Vector2(1.2, 0.5)

var lamp_on := false
var lamp_dead_t := 0.0           # фонарь принудительно погашен на это время (существо)
var lamp_flicker := 0.0          # сек мигания
var lamp_locked := false         # сценарий запретил включать
var warmth := 100.0
var stamina := 100.0
var fear := 0.0                  # 0..1 — задают существо и события
var exhausted := false
var gripping := false
var grip_line := ""
var grip_side := 1.0
var near_rope := false
var carrying := ""               # "" | "jerry" | "wood"
var flares := 0
var flare_t := 0.0               # сколько ещё горит фальшфейер
var noise := 0                   # 0 тихо, 1 шаг, 2 бег
var still_t := 0.0
var speed_now := 0.0
var zone := {}                   # текущая зона мира
var breath_held := false
var breath := 100.0
var can_hold_breath := false
var focus: Interactable = null
var hold_it: Interactable = null
var control := true              # можно ли двигаться и смотреть (пауза, меню, записки)

var _bob := 0.0
var _step_acc := 0.0
var _left := false
var grip_s := 0.0                # где держимся: метры вдоль леера
var _grip_sign := 1.0
var _grip_moving := false
var _shake := 0.0
var _shake_t := 0.0
var _t := 0.0
var _puff_t := 2.0
var _look_tw: Tween
var _end_told := false
var _fov_kick := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.3
	col = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.76
	col.shape = cap
	col.position.y = 0.88
	add_child(col)
	head = Node3D.new()
	head.position.y = EYE
	add_child(head)
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 600.0
	cam.fov = Cfg.fov
	head.add_child(cam)
	cam.make_current()
	# фонарь на лбу: поворачивается за взглядом с небольшим отставанием
	lamp_pivot = Node3D.new()
	lamp_pivot.top_level = true
	add_child(lamp_pivot)
	lamp = SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.93, 0.8)
	lamp.light_energy = LAMP_E
	lamp.spot_range = 27.0
	lamp.spot_angle = 43.0
	lamp.spot_attenuation = 0.72
	lamp.spot_angle_attenuation = 0.5
	if ResourceLoader.exists("res://tex/cookie.png"):
		lamp.light_projector = load("res://tex/cookie.png")
	lamp.light_specular = 0.6
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.06
	lamp.shadow_normal_bias = 1.2
	lamp.position = Vector3(0.0, 0.09, -0.04)
	lamp.visible = false
	lamp_pivot.add_child(lamp)
	fill = OmniLight3D.new()
	fill.light_color = Color(1.0, 0.93, 0.8)
	fill.light_energy = 0.5
	fill.omni_range = 4.0
	fill.omni_attenuation = 1.6
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	fill.visible = false
	head.add_child(fill)
	# фальшфейер в левой руке
	flare_light = OmniLight3D.new()
	flare_light.light_color = Color(1.0, 0.14, 0.06)
	flare_light.light_energy = 0.0
	flare_light.omni_range = 17.0
	flare_light.omni_attenuation = 1.1
	flare_light.shadow_enabled = true
	flare_light.position = Vector3(-0.32, -0.3, -0.5)
	flare_light.visible = false
	head.add_child(flare_light)
	flare_halo = Kit.halo(head, Vector3(-0.3, -0.26, -0.55), Color(1.0, 0.25, 0.12), 0.34, 2.2)
	(flare_halo.material_override as ShaderMaterial).set_shader_parameter("near_fade", 0.01)
	flare_halo.visible = false
	_build_puff()
	_build_hand()
	Cfg.changed.connect(_on_cfg)


func _on_cfg() -> void:
	cam.fov = Cfg.fov


## Рука в рукавице на тросе — видна, пока держишься.
func _build_hand() -> void:
	hand = Node3D.new()
	hand.top_level = true
	hand.visible = false
	add_child(hand)
	var cloth := Kit.mat("caban", 0.4, Color(0.2, 0.2, 0.24), 1.0)
	var sleeve := Kit.mat("caban", 0.5, Color(0.2, 0.26, 0.36), 1.0)
	var m := Kit.sphere_node(hand, Vector3(0, 0.0, 0), 1.0, cloth, Vector3(0.062, 0.05, 0.1), 10)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var th := Kit.sphere_node(hand, Vector3(0.0, -0.045, 0.02), 1.0, cloth, Vector3(0.03, 0.04, 0.05), 8)
	th.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var arm := Kit.capsule_node(hand, Vector3(0, -0.02, 0.36), 0.055, 0.62, sleeve)
	arm.rotation.x = deg_to_rad(90)
	arm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _update_hand() -> void:
	if not gripping or world == null or mode != "walk":
		hand.visible = false
		return
	var R: Ropes = world.ropes
	if not R.lines.has(grip_line):
		hand.visible = false
		return
	# хватаемся чуть впереди по ходу взгляда
	var dir := R.dir_at(grip_line, grip_s)
	var look := look_dir()
	look.y = 0.0
	var ahead := 0.42 if look.dot(dir) >= 0.0 else -0.42
	var s := clampf(grip_s + ahead, 0.0, R.length(grip_line))
	var hp := R.point_at(grip_line, s) + Vector3(0, Ropes.ROPE_Y - 0.1, 0)
	var shoulder := global_position + Vector3(0, 1.32, 0)
	var to := shoulder - hp
	if to.length() < 0.05:
		return
	hand.visible = true
	hand.global_transform = Transform3D(Basis.looking_at(-to.normalized(), Vector3.UP), hp)


func _build_puff() -> void:
	puff = GPUParticles3D.new()
	puff.amount = 10
	puff.lifetime = 1.4
	puff.one_shot = true
	puff.explosiveness = 0.75
	puff.emitting = false
	puff.local_coords = false
	puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -0.15, -1)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.15, 0)
	pm.damping_min = 0.6
	pm.damping_max = 0.9
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.25))
	sc.add_point(Vector2(1, 1.6))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.add_point(0.15, Color(1, 1, 1, 0.16))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	puff.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.28)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/shaders/flake.gdshader")
	sm.set_shader_parameter("tex", Kit.tex("res://tex/dot"))
	sm.set_shader_parameter("bright", 0.8)
	qm.material = sm
	puff.draw_pass_1 = qm
	puff.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	puff.position = Vector3(0, -0.12, -0.25)
	head.add_child(puff)


# ------------------------------------------------------------------ управление извне

func teleport(pos: Vector3, yaw_deg := 0.0) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	yaw = deg_to_rad(yaw_deg)
	pitch = 0.0
	release_grip(true)
	_apply_look()
	lamp_pivot.global_transform = cam.global_transform
	reset_physics_interpolation()


func set_mode(m: String) -> void:
	mode = m
	col.disabled = m == "free" or m == "bed" or m == "hide"
	if m == "walk":
		eye_h = EYE
	if m != "walk":
		release_grip(true)
		hold_it = null


## Поза для кровати и укрытия: точка глаз, направление взгляда и пределы поворота головы (радианы).
func pose(eye_pos: Vector3, yaw_deg: float, pitch_deg := 0.0, lim := Vector2(1.2, 0.5)) -> void:
	global_position = Vector3(eye_pos.x, 0.0, eye_pos.z)
	eye_h = eye_pos.y
	yaw = deg_to_rad(yaw_deg)
	pitch = deg_to_rad(pitch_deg)
	look_base_yaw = yaw
	look_lim = lim
	velocity = Vector3.ZERO
	_apply_look()


## Плавно повернуть голову к точке (катсцены).
func look_to(target: Vector3, time := 0.6) -> void:
	var d := target - cam.global_position
	var ty := atan2(-d.x, -d.z)
	var tp := atan2(d.y, Vector2(d.x, d.z).length())
	ty = yaw + wrapf(ty - yaw, -PI, PI)
	if _look_tw != null and _look_tw.is_valid():
		_look_tw.kill()
	_look_tw = create_tween().set_parallel(true)
	_look_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_look_tw.tween_property(self, "yaw", ty, time)
	_look_tw.tween_property(self, "pitch", clampf(tp, -1.4, 1.4), time)


func shake(amount: float, time := 0.4) -> void:
	_shake = maxf(_shake, amount)
	_shake_t = maxf(_shake_t, time)


func set_lamp(on: bool, silent := false) -> void:
	if on and lamp_locked:
		return
	if lamp_on == on:
		return
	lamp_on = on
	if not silent:
		Snd.play("lamp_on" if on else "lamp_off", -6.0)
	lamp_changed.emit(on)


## Существо гасит фонарь на t секунд.
func kill_lamp(t: float) -> void:
	lamp_dead_t = maxf(lamp_dead_t, t)
	Snd.play("lamp_flicker", -4.0)


func lamp_shining() -> bool:
	return lamp_on and lamp_dead_t <= 0.0


func look_dir() -> Vector3:
	return -cam.global_transform.basis.z


func eye_pos() -> Vector3:
	return cam.global_position


## Попадает ли точка в луч фонаря (для существа: «в луче — замирает»).
func lit_by_lamp(p: Vector3, max_dist: float) -> bool:
	if not lamp_shining():
		return false
	var d := p - cam.global_position
	var dist := d.length()
	if dist > max_dist or dist < 0.01:
		return false
	return (d / dist).dot(-lamp_pivot.global_transform.basis.z) > 0.86


func light_flare() -> bool:
	if flares <= 0 or flare_t > 0.0:
		return false
	flares -= 1
	flare_t = 32.0
	Snd.play("flare_ignite", -2.0)
	Snd.loop("flare", "flare_burn", 0.8, 0.3, "Sfx")
	flare_lit.emit()
	return true


func release_grip(silent := false) -> void:
	if not gripping:
		return
	gripping = false
	_grip_moving = false
	if not silent:
		Snd.play("rope_release", -10.0)
	grip_changed.emit(false)


func try_grip() -> void:
	if world == null:
		return
	# на развязке берёмся за тот трос, вдоль которого смотрим
	var cands: Array = world.ropes.near_all(global_position, 1.75)
	if cands.is_empty():
		return
	var look := look_dir()
	look.y = 0.0
	look = look.normalized() if look.length() > 0.05 else Vector3.FORWARD
	var n: Dictionary = cands[0]
	var best := -9.0
	for c in cands:
		var cd: Dictionary = c
		var score := absf(look.dot(cd.dir)) - float(cd.d) * 0.35
		if score > best:
			best = score
			n = cd
	gripping = true
	grip_line = String(n.line)
	grip_s = float(n.s)
	var dir: Vector3 = n.dir
	var perp := dir.cross(Vector3.UP).normalized()
	var p: Vector3 = n.p
	grip_side = 1.0 if (global_position - p).dot(perp) >= 0.0 else -1.0
	_grip_moving = false
	_end_told = false
	Snd.play("rope_grab", -8.0)
	grip_changed.emit(true)


# ------------------------------------------------------------------ ввод

func _unhandled_input(e: InputEvent) -> void:
	if not control or mode == "locked" or mode == "dead":
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mm: InputEventMouseMotion = e
		var k := 0.0022 * Cfg.sens
		yaw -= mm.relative.x * k
		pitch -= mm.relative.y * k * (-1.0 if Cfg.invert_y else 1.0)
		if mode == "bed" or mode == "hide":
			yaw = clampf(yaw, look_base_yaw - look_lim.x, look_base_yaw + look_lim.x)
			pitch = clampf(pitch, -look_lim.y, look_lim.y)
		else:
			pitch = clampf(pitch, -1.45, 1.45)
	if mode == "free":
		return
	if e.is_action_pressed("lamp") and mode != "bed":
		if lamp_locked:
			if G.hud != null:
				G.hud.toast("Фонарь не включается")
		else:
			set_lamp(not lamp_on)
	if mode != "walk":
		return
	if e.is_action_pressed("grip"):
		if gripping:
			release_grip()
		else:
			try_grip()
	if e.is_action_pressed("flare"):
		if flares > 0 and flare_t <= 0.0:
			light_flare()
		elif flares <= 0 and G.hud != null and G.flag("flares_known"):
			G.hud.toast("Фальшфейеров нет")
	if e.is_action_pressed("use"):
		_try_use()


func _try_use() -> void:
	if focus == null or not is_instance_valid(focus) or not focus.enabled:
		return
	var why := focus.blocked(lamp_shining())
	if why != "":
		if G.hud != null:
			G.hud.toast(why)
		return
	if focus.hold <= 0.0:
		focus.use()
	else:
		hold_it = focus
		if hold_it.on_hold.is_valid():
			hold_it.on_hold.call(true)


func _stop_hold(done: bool) -> void:
	if hold_it == null:
		return
	var it := hold_it
	hold_it = null
	if is_instance_valid(it):
		if it.on_hold.is_valid():
			it.on_hold.call(false)
		if done:
			it.progress = 0.0
			it.use()
		elif not it.keep_progress:
			it.progress = 0.0


# ------------------------------------------------------------------ кадр

func _apply_look() -> void:
	rotation.y = yaw
	head.rotation.x = pitch


func _process(dt: float) -> void:
	_t += dt
	_apply_look()
	# дрожь камеры и качание головы
	var sh := Vector3.ZERO
	if _shake_t > 0.0:
		_shake_t -= dt
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.02
		if _shake_t <= 0.0:
			_shake = 0.0
	var cold_k := clampf((30.0 - warmth) / 30.0, 0.0, 1.0)
	sh += Vector3(sin(_t * 31.0), sin(_t * 27.0 + 1.3), 0) * 0.0025 * cold_k
	var bob_y := 0.0
	var bob_x := 0.0
	if Cfg.head_bob and mode == "walk":
		bob_y = sin(_bob * TAU) * 0.035 * clampf(speed_now / 2.5, 0.0, 1.4)
		bob_x = sin(_bob * PI) * 0.018 * clampf(speed_now / 2.5, 0.0, 1.4)
	head.position = Vector3(bob_x, eye_h + bob_y, 0) + sh
	cam.rotation.z = sin(_t * 0.6) * 0.004 + fear * sin(_t * 9.0) * 0.004
	# поле зрения: шире на бегу, дышит от страха
	var run := noise >= 2
	_fov_kick = move_toward(_fov_kick, 5.0 if run else 0.0, dt * 14.0)
	cam.fov = Cfg.fov + _fov_kick - fear * 3.0

	# фонарь догоняет взгляд
	var target := cam.global_transform
	var q := lamp_pivot.global_transform.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), clampf(dt * 11.0, 0.0, 1.0))
	lamp_pivot.global_transform = Transform3D(Basis(q), target.origin)
	lamp_dead_t = maxf(0.0, lamp_dead_t - dt)
	lamp_flicker = maxf(0.0, lamp_flicker - dt)
	var shining := lamp_shining()
	var e := LAMP_E
	if lamp_flicker > 0.0:
		e *= 0.25 + 0.75 * float(randf() > 0.45)
	e *= 1.0 - cold_k * 0.25 * (0.5 + 0.5 * sin(_t * 17.0))
	lamp.visible = shining
	lamp.light_energy = e
	fill.visible = shining
	RenderingServer.global_shader_parameter_set("g_lamp_pos", cam.global_position)
	RenderingServer.global_shader_parameter_set("g_lamp_dir", -lamp_pivot.global_transform.basis.z)
	RenderingServer.global_shader_parameter_set("g_lamp_on", 1.0 if shining else 0.0)

	# фальшфейер
	if flare_t > 0.0:
		flare_t -= dt
		var k := clampf(flare_t / 3.0, 0.0, 1.0)
		flare_light.visible = true
		flare_halo.visible = true
		flare_light.light_energy = (3.6 + randf_range(-0.7, 0.7)) * k
		if flare_t <= 0.0:
			flare_light.visible = false
			flare_halo.visible = false
			Snd.stop_loop("flare", 0.4)

	# пар изо рта на холоде
	var cold_air := float(zone.get("cold_air", 1.0))
	_puff_t -= dt * (1.0 + (2.0 if run else 0.0) + fear)
	if _puff_t <= 0.0 and cold_air > 0.3 and mode != "dead" and not breath_held:
		_puff_t = 3.4
		puff.restart()
		puff.emitting = true

	_update_hand()
	# эффекты кадра
	if G.main != null:
		G.main.cold = clampf((50.0 - warmth) / 50.0, 0.0, 1.0)
		G.main.blur = clampf((13.0 - warmth) / 13.0, 0.0, 1.0) * 0.8
		G.main.fear = fear


func _physics_process(dt: float) -> void:
	if world != null:
		zone = world.zone_at(global_position)
	var shelter := float(zone.get("shelter", 0.0))
	if mode == "free":
		_free_move(dt)
		return
	_update_focus(dt)
	_update_vitals(dt, shelter)
	if mode != "walk" or not control:
		velocity = Vector3.ZERO
		speed_now = 0.0
		noise = 0
		still_t += dt
		return

	var iv := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var want_run := Input.is_action_pressed("run") and not exhausted and carrying != "jerry" and hold_it == null
	var base := lerpf(WALK_OUT, WALK_IN, shelter)
	base *= lerpf(1.0, 0.58, clampf((22.0 - warmth) / 22.0, 0.0, 1.0))
	if carrying == "jerry":
		base *= 0.86
	var gust := 0.0
	var wbase := 0.0
	if world != null:
		gust = world.weather.gust * (1.0 - shelter)
		wbase = world.weather.base * (1.0 - shelter)
	var running := false

	if hold_it != null:
		iv = Vector2.ZERO

	if gripping:
		running = _grip_move(dt, iv, base, want_run)
	else:
		var wish := (Basis(Vector3.UP, yaw) * Vector3(iv.x, 0, iv.y))
		if wish.length() > 1.0:
			wish = wish.normalized()
		running = want_run and iv.y < -0.3
		var sp := base * (RUN_K if running else 1.0)
		sp *= 1.0 - 0.33 * gust
		var tv := wish * sp
		# ветер сносит и разворачивает, если не держишься
		tv += Weather.WIND_DIR * (0.25 * wbase + 1.5 * gust)
		if gust > 0.4:
			yaw += (sin(_t * 0.9) + sin(_t * 2.3 + 1.7)) * 0.11 * gust * dt
		var acc := 11.0 if is_on_floor() else 3.0
		velocity.x = move_toward(velocity.x, tv.x, acc * dt * 2.0)
		velocity.z = move_toward(velocity.z, tv.z, acc * dt * 2.0)
		if not is_on_floor():
			velocity.y -= 14.0 * dt
		else:
			velocity.y = -0.5
		move_and_slide()

	var hv := Vector2(get_real_velocity().x, get_real_velocity().z).length()
	if not gripping:
		# ветровой снос не считается шагом
		hv = maxf(0.0, hv - (0.25 * wbase + 1.5 * gust)) if iv.length() < 0.1 else hv
	speed_now = hv
	var moving := hv > 0.4 and iv.length() > 0.1
	if moving:
		still_t = 0.0
		noise = 2 if running else 1
		var stride := 0.98 if running else 0.74
		_step_acc += hv * dt
		_bob += hv * dt / (stride * 2.0)
		if _step_acc >= stride:
			_step_acc = 0.0
			_left = not _left
			_footstep(running)
	else:
		still_t += dt
		noise = 0
		_bob = lerpf(_bob, roundf(_bob * 2.0) / 2.0, clampf(dt * 6.0, 0.0, 1.0))

	# выносливость
	if running and moving:
		stamina = maxf(0.0, stamina - 15.0 * dt)
		if stamina <= 0.0:
			exhausted = true
	else:
		stamina = minf(100.0, stamina + (10.0 if moving else 16.0) * dt)
		if exhausted and stamina > 30.0:
			exhausted = false

	# подсказка «взяться за леер»
	near_rope = false
	if world != null and not gripping:
		near_rope = not (world.ropes.nearest(global_position, 1.75) as Dictionary).is_empty()


func _grip_move(dt: float, iv: Vector2, base: float, want_run: bool) -> bool:
	# положение на леере — расстояние вдоль троса: углы огибаются плавно, а смотреть можно куда угодно
	var R: Ropes = world.ropes
	if not R.lines.has(grip_line) or not R.s_ok(grip_line, grip_s):
		release_grip()
		return false
	var dir := R.dir_at(grip_line, grip_s)
	var f := -iv.y
	var running := false
	if absf(f) > 0.1:
		if not _grip_moving:
			var look := look_dir()
			look.y = 0.0
			_grip_sign = 1.0 if look.dot(dir) >= 0.0 else -1.0
			_grip_moving = true
		running = want_run
		var sp := base * (1.3 if running else 0.94)
		var ns := grip_s + _grip_sign * signf(f) * sp * dt
		if R.s_ok(grip_line, ns):
			grip_s = ns
			_end_told = false
		elif not _end_told:
			_end_told = true
			if G.hud != null:
				G.hud.toast("Леер кончился")
	else:
		_grip_moving = false
	dir = R.dir_at(grip_line, grip_s)
	var rp := R.point_at(grip_line, grip_s)
	var perp := dir.cross(Vector3.UP).normalized()
	var tgt := rp + perp * grip_side * 0.52
	var to := tgt - global_position
	to.y = 0.0
	if to.length() > 2.6:
		release_grip()
		return false
	var v := to / maxf(dt, 0.001)
	var lim := base * 2.4
	if v.length() > lim:
		v = v.normalized() * lim
	velocity = Vector3(v.x, -0.5, v.z)
	move_and_slide()
	return running


func _free_move(dt: float) -> void:
	var iv := Input.get_vector("move_l", "move_r", "move_f", "move_b")
	var up := Input.get_axis("fly_down", "fly_up")
	var b := cam.global_transform.basis
	var v := (b.x * iv.x + b.z * iv.y + Vector3.UP * up)
	var sp := 24.0 if Input.is_action_pressed("run") else 7.0
	global_position += v * sp * dt
	velocity = Vector3.ZERO
	noise = 0
	still_t += dt


func _footstep(running: bool) -> void:
	var surf := String(zone.get("surface", "snow"))
	var vol := -9.0 if not running else -5.0
	if gripping:
		vol -= 1.5
	Snd.play("step_" + surf, vol + randf_range(-1.5, 0.5), randf_range(0.93, 1.07))
	stepped.emit(global_position, yaw, _left, running)


func _update_focus(dt: float) -> void:
	focus = null
	if mode == "dead" or mode == "locked" or not control:
		if G.hud != null:
			G.hud.set_prompt("", 0.0, false)
		return
	var from := cam.global_position
	var to := from + look_dir() * REACH
	var qp := PhysicsRayQueryParameters3D.create(from, to, 3)
	qp.collide_with_areas = true
	qp.collide_with_bodies = true
	qp.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(qp)
	if not hit.is_empty():
		var c: Object = hit.collider
		if c is Interactable and (c as Interactable).enabled:
			focus = c
	# удержание
	if hold_it != null:
		var ok := is_instance_valid(hold_it) and hold_it.enabled and Input.is_action_pressed("use")
		if ok and hold_it.look_lock and focus != hold_it:
			ok = false
		if ok and hold_it.blocked(lamp_shining()) != "":
			ok = false
		if not ok:
			_stop_hold(false)
		else:
			hold_it.progress += dt / maxf(hold_it.hold, 0.05)
			if hold_it.progress >= 1.0:
				_stop_hold(true)
	if G.hud != null:
		if hold_it != null:
			G.hud.set_prompt(hold_it.prompt, hold_it.progress, false)
		elif focus != null:
			var why := focus.blocked(lamp_shining())
			var txt := focus.prompt
			if focus.hold > 0.0:
				txt += " (держать)"
			G.hud.set_prompt(txt if why == "" else focus.prompt + " — " + why.to_lower(), focus.progress if focus.keep_progress else 0.0, why != "")
		else:
			G.hud.set_prompt("", 0.0, false)


func _update_vitals(dt: float, _shelter: float) -> void:
	if world != null and mode != "dead":
		var rate: float = world.heat_rate(self)
		if G.no_cold and rate < 0.0:
			rate = 0.0
		warmth = clampf(warmth + rate * dt, 0.0, 100.0)
		if warmth <= 0.0 and not G.god:
			G.die("freeze")
	# задержка дыхания
	if can_hold_breath and Input.is_action_pressed("breath") and breath > 0.0:
		if not breath_held:
			breath_held = true
			Snd.play("breath_in", -8.0)
		breath = maxf(0.0, breath - 13.0 * dt)
	else:
		if breath_held:
			breath_held = false
			Snd.play("breath_out", -6.0)
		breath = minf(100.0, breath + 22.0 * dt)
	# звук дыхания и сердца
	var ex := clampf((60.0 - stamina) / 60.0, 0.0, 1.0)
	var cold_k := clampf((35.0 - warmth) / 35.0, 0.0, 1.0)
	if Snd.streams.has("breath_run"):
		Snd.loop("breath_run", "breath_run", 0.0 if breath_held else ex * 0.7, 0.6, "Sfx")
		Snd.loop("breath_cold", "breath_cold", 0.0 if breath_held else cold_k * 0.55, 1.0, "Sfx")
		Snd.loop("heart", "heartbeat", clampf(fear * 1.1 - 0.1, 0.0, 1.0), 0.8, "Sfx", 0.9 + fear * 0.5)
