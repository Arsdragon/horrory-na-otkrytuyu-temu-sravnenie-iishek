extends CharacterBody3D
## Жилец. Слышит шум, видит только свет фонаря и того, кто совсем рядом.

enum S { PATROL, INVESTIGATE, CHASE, SEARCH, WARDROBE, IDLE }
const NAMES := ["обход", "идёт на звук", "погоня", "ищет", "у шкафа", "стоит"]

var game
var model
var state := S.PATROL
var path := PackedVector3Array()
var path_i := 0
var target := Vector3.ZERO
var last_seen := Vector3.ZERO
var lost_t := 0.0
var search_t := 0.0
var idle_t := 0.0
var step_t := 0.0
var groan_t := 8.0
var repath_t := 0.0
var saw_hide := false
var wardrobe: Node3D
var wardrobe_t := 0.0
var frozen := false
var hear_mult := 1.0
var speed_mult := 1.0
var stuck_t := 0.0
var _last_pos := Vector3.ZERO
var _wp_t := 0.0
var seen_flag := false   # видит игрока прямо сейчас

func setup(g) -> void:
	game = g
	collision_layer = 4
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.9
	cs.shape = cap
	cs.position.y = 0.95
	add_child(cs)
	model = preload("res://src/zhilets_model.gd").new()
	add_child(model)
	floor_max_angle = deg_to_rad(50)
	floor_snap_length = 0.5

func state_name() -> String:
	return NAMES[state]

func hear(pos: Vector3, radius: float) -> void:
	if frozen or state == S.CHASE or state == S.WARDROBE: return
	var d := pos.distance_to(global_position)
	var dy: float = abs(pos.y - global_position.y)
	var r := radius * hear_mult
	if dy > 2.0: r *= 0.45  # через перекрытие хуже
	if d < r:
		if state != S.INVESTIGATE: G.log("Жилец услышал шум (%.1f м)" % d)
		_go(pos, S.INVESTIGATE)

func _go(pos: Vector3, st: int) -> void:
	state = st
	target = pos
	path = game.world.path(global_position, pos)
	path_i = 0
	repath_t = 0.6

func _physics_process(dt: float) -> void:
	if game.paused or frozen:
		model.speed = 0
		return
	var pl = game.player
	seen_flag = _can_see(pl)
	match state:
		S.PATROL:
			if seen_flag: _start_chase()
			elif _follow(1.35 * speed_mult, dt):
				if randf() < 0.3: state = S.IDLE; idle_t = randf_range(2, 6)
				else: _go(_pick_patrol(), S.PATROL)
		S.IDLE:
			model.speed = 0
			idle_t -= dt
			if seen_flag: _start_chase()
			elif idle_t <= 0: _go(_pick_patrol(), S.PATROL)
			_stand(dt)
		S.INVESTIGATE:
			if seen_flag: _start_chase()
			elif _follow(2.5 * speed_mult, dt):
				state = S.SEARCH; search_t = randf_range(5, 9)
		S.SEARCH:
			if seen_flag: _start_chase()
			else:
				search_t -= dt
				if _follow(1.2 * speed_mult, dt):
					var p := target + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
					path = game.world.path(global_position, p); path_i = 0
				if search_t <= 0: _go(_pick_patrol(), S.PATROL)
		S.CHASE:
			_chase(dt)
		S.WARDROBE:
			_at_wardrobe(dt)
	# звуки
	var v := Vector2(velocity.x, velocity.z).length()
	if v > 0.3:
		step_t -= dt * v
		if step_t <= 0:
			step_t = 1.5
			G.play3d(game, global_position, "estep%d" % randi_range(0, 2), 2.0 if state == S.CHASE else -2.0, 4.0, randf_range(0.8, 1.0))
	groan_t -= dt
	if groan_t <= 0:
		groan_t = randf_range(10, 22) if state != S.CHASE else randf_range(3, 6)
		G.play3d(game, global_position + Vector3(0, 2, 0), "groan" if randf() < 0.7 else "whisper", 0.0, 3.0, randf_range(0.7, 1.0))
	# застрял — на новый маршрут
	if global_position.distance_to(_last_pos) < 0.02 and state in [S.PATROL, S.INVESTIGATE, S.SEARCH]:
		stuck_t += dt
		if stuck_t > 2.5: stuck_t = 0; _go(_pick_patrol(), S.PATROL)
	else: stuck_t = 0
	_last_pos = global_position

func _pick_patrol() -> Vector3:
	# чаще бродит там, где игрок (на его этаже и соседних)
	var pl = game.player
	for i in 8:
		var p: Vector3 = game.world.random_point()
		if abs(p.y - pl.global_position.y) < 4.0 or randf() < 0.25: return p
	return game.world.random_point()

func _can_see(pl) -> bool:
	if game.admin_invisible or pl.god and game.admin_on and game.admin_ignore: return false
	if pl.hidden: return false
	var eye := global_position + Vector3(0, 1.8, 0)
	var pe: Vector3 = pl.cam.global_position
	var d := eye.distance_to(pe)
	if d > 18.0: return false
	var lit: bool = pl.light_on and pl.light.light_energy > 0.5
	var close := d < (3.5 if not pl.crouch else 2.2)
	if not lit and not close: return false
	if lit and not close:
		# видит, если игрок в поле «зрения» или светит прямо на него
		var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
		var to_p := (pe - eye).normalized()
		var cam_fwd: Vector3 = -pl.cam.global_transform.basis.z
		var shine := cam_fwd.dot((eye - pe).normalized()) > 0.9
		if fwd.dot(to_p) < -0.1 and not shine: return false
		if d > 16.0: return false
	var q := PhysicsRayQueryParameters3D.create(eye, pe, 1, [pl.get_rid(), get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return hit.is_empty()

func _start_chase() -> void:
	if state != S.CHASE:
		G.log("Жилец заметил игрока — погоня")
		game.on_chase_start()
	state = S.CHASE
	lost_t = 0
	last_seen = game.player.global_position

func _chase(dt: float) -> void:
	var pl = game.player
	model.lean = lerp(model.lean, 1.0, dt * 3)
	if pl.hidden:
		if saw_hide:
			wardrobe = pl.hide_wardrobe
			_go(wardrobe.get_meta("front"), S.WARDROBE)
			state = S.WARDROBE
			wardrobe_t = 0
			return
	if seen_flag:
		lost_t = 0
		last_seen = pl.global_position
	else:
		lost_t += dt
	var spd := 4.4 * speed_mult
	var d := global_position.distance_to(pl.global_position)
	if seen_flag and abs(pl.global_position.y - global_position.y) < 1.2:
		_move_dir(pl.global_position - global_position, spd, dt)
	else:
		repath_t -= dt
		if repath_t <= 0 or path_i >= path.size():
			path = game.world.path(global_position, last_seen); path_i = 0; repath_t = 0.5
		if _follow(spd, dt) and not seen_flag:
			lost_t = 99
	if d < 1.15 and not pl.hidden and abs(pl.global_position.y - global_position.y) < 1.5:
		game.kill()
		return
	if lost_t > 4.0:
		G.log("Жилец потерял игрока")
		model.lean = 0
		state = S.SEARCH
		search_t = 10
		target = last_seen
		game.on_chase_end()

func _at_wardrobe(dt: float) -> void:
	var pl = game.player
	if _follow(3.0, dt):
		_stand(dt)
		var w := wardrobe
		var to: Vector3 = w.global_position - global_position
		rotation.y = lerp_angle(rotation.y, atan2(to.x, to.z), dt * 4)
		wardrobe_t += dt
		if pl.hidden and pl.hide_wardrobe == w and wardrobe_t > 1.6 and saw_hide:
			game.kill(true)
			return
		if wardrobe_t > randf_range(9, 13) or not pl.hidden:
			saw_hide = false
			if not pl.hidden: _start_chase()
			else: _go(_pick_patrol(), S.PATROL)
	model.lean = lerp(model.lean, 0.3, dt * 2)

func check_wardrobe(w: Node3D) -> void:
	# услышал что-то из шкафа (дыхание) рядом
	wardrobe = w
	saw_hide = true
	state = S.WARDROBE
	wardrobe_t = 0
	path = game.world.path(global_position, w.get_meta("front")); path_i = 0

func _follow(spd: float, dt: float) -> bool:
	if path_i >= path.size():
		_stand(dt)
		return true
	var p := path[path_i]
	var to := p - global_position
	to.y = 0
	_wp_t += dt
	if to.length() < 0.35 or _wp_t > 7.0:
		_wp_t = 0.0
		path_i += 1
		return path_i >= path.size()
	_move_dir(to, spd, dt)
	return false

func _move_dir(to: Vector3, spd: float, dt: float) -> void:
	to.y = 0
	var dir := to.normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	velocity.y = velocity.y - 18 * dt if not is_on_floor() else -0.5
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), dt * 8)
	move_and_slide()
	model.speed = clamp(spd / 4.5, 0.0, 1.0)

func _stand(dt: float) -> void:
	velocity.x = 0; velocity.z = 0
	velocity.y = velocity.y - 18 * dt if not is_on_floor() else -0.5
	move_and_slide()
	model.speed = 0
