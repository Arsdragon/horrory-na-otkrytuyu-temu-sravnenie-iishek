class_name Entity
extends Node3D
## Отзыв. Идёт на свет и на шум. В луче фонаря замирает, в порыв и вне луча — приближается.
## Погашенный фонарь + неподвижность + рука на леере = проходит мимо. Огня не выносит.

signal passed            # прошло мимо спрятавшегося игрока и ушло
signal lost              # потеряло игрока и ушло
signal caught            # схватило
signal seen              # игрок впервые осветил его лучом

enum S { HIDDEN, WATCH, ACTIVE, PASS, LEAVE, SCRIPT }

var world: World
var fig: Figure
var state := S.HIDDEN
var level := 2                 # 2..5 — что оно умеет (номер ночи)
var known := Vector3.ZERO      # где, по его мнению, игрок
var aware := false
var lit_t := 0.0               # сколько секунд подряд стоит в луче
var lost_t := 0.0
var pass_to := Vector3.ZERO
var pass_wait := 0.0
var leave_dir := Vector3.ZERO
var lethal := true             # может ли убить (в обучающих сценах — да, но с форой)
var grace := 0.0               # фора: первые секунды не убивает
var move_speed := 0.0
var path: Array = []           # для сценариев: точки, по которым идти
var path_speed := 1.0
var seen_once := false
var near_snd: AudioStreamPlayer3D
var _step_acc := 0.0
var _left := false
var _croak_t := 6.0
var _obstacles: Array = []     # AABB построек: обходит
var _light: OmniLight3D = null
var _lt := 0.0


func _ready() -> void:
	fig = Figure.make(self)
	fig.look_on = true
	visible = false
	near_snd = Snd.emitter("ent_near", self, Vector3(0, 1.4, 0), -80.0, 16.0, 2.2)
	for b in [[Map.HOUSE_MIN, Map.HOUSE_MAX], [Map.SHED_MIN, Map.SHED_MAX], [Map.HUT_MIN, Map.HUT_MAX], [Vector3(-50.5, 0, -91), Vector3(-45.5, 2.2, -88)]]:
		var mn: Vector3 = b[0]
		var mx: Vector3 = b[1]
		_obstacles.append(AABB(mn - Vector3(0.9, 1, 0.9), (mx - mn) + Vector3(1.8, 3, 1.8)))


func speed_for_level() -> float:
	match level:
		2:
			return 1.5
		3:
			return 2.1
		4:
			return 2.5
		_:
			return 2.9


func freezes_in_light() -> bool:
	return level <= 4


# ------------------------------------------------------------------ команды режиссёра

func hide_now() -> void:
	state = S.HIDDEN
	visible = false
	aware = false
	if _light != null:
		_light.visible = false
	fig.speed = 0.0
	fig.reach = 0.0
	if near_snd.playing:
		near_snd.stop()


## Поставить неподвижную фигуру (наблюдает). Исчезает в ближайший порыв или когда её долго держат в луче.
func watch_at(pos: Vector3, wrong := 0.0) -> void:
	global_position = Vector3(pos.x, 0, pos.z)
	_face(G.player.global_position)
	fig.set_wrong(wrong)
	fig.speed = 0.0
	state = S.WATCH
	visible = true
	lit_t = 0.0


## Начать охоту из точки pos (обычно за пределом видимости).
func hunt_from(pos: Vector3, wrong := 0.4, knows := true) -> void:
	global_position = Vector3(pos.x, 0, pos.z)
	fig.set_wrong(wrong)
	state = S.ACTIVE
	visible = true
	aware = knows
	known = G.player.global_position
	lost_t = 0.0
	lit_t = 0.0
	grace = 1.5
	if not near_snd.playing:
		near_snd.play()


## Появиться за пределом видимости с наветренной стороны или за спиной игрока.
func hunt_near(dist := 24.0, wrong := 0.4) -> void:
	var p: Player = G.player
	var back := -p.look_dir()
	back.y = 0.0
	if back.length() < 0.1:
		back = Vector3.BACK
	var dir := back.normalized().rotated(Vector3.UP, randf_range(-0.9, 0.9))
	var pos := p.global_position + dir * dist
	for i in 6:
		if not world.is_indoors(pos) and not _inside_obstacle(pos):
			break
		dir = dir.rotated(Vector3.UP, 0.7)
		pos = p.global_position + dir * dist
	hunt_from(pos, wrong)


## Идти по точкам (сценарии в доме и у площадки). В конце — стоит.
func walk_path(points: Array, spd := 1.0, wrong := 1.0) -> void:
	path = points.duplicate()
	path_speed = spd
	fig.set_wrong(wrong)
	state = S.SCRIPT
	visible = true


## Свет в руке: оно светит «таким же фонарём» (сцена в доме). Белый, дышит.
func carry_light(on: bool) -> void:
	if _light == null:
		_light = OmniLight3D.new()
		_light.light_color = Color(0.85, 0.92, 1.0)
		_light.omni_range = 5.5
		_light.omni_attenuation = 1.3
		_light.shadow_enabled = true
		_light.position = Vector3(0.25, 1.15, -0.35)
		add_child(_light)
	_light.visible = on


func leave() -> void:
	if state == S.HIDDEN:
		return
	var p: Player = G.player
	leave_dir = (global_position - p.global_position)
	leave_dir.y = 0.0
	leave_dir = leave_dir.normalized() if leave_dir.length() > 0.1 else Vector3.FORWARD
	state = S.LEAVE


func dist_to_player() -> float:
	var p: Player = G.player
	return Vector2(global_position.x - p.global_position.x, global_position.z - p.global_position.z).length()


# ------------------------------------------------------------------ кадр

func _face(target: Vector3, k := 1.0) -> void:
	var d := target - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(k, 0.0, 1.0))


func _inside_obstacle(p: Vector3) -> bool:
	for o in _obstacles:
		if (o as AABB).has_point(Vector3(p.x, 0.5, p.z)):
			return true
	return false


func _move(dir: Vector3, spd: float, dt: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.001:
		move_speed = 0.0
		return
	dir = dir.normalized()
	var np := global_position + dir * spd * dt
	if state != S.SCRIPT and _inside_obstacle(np):
		# скользит вдоль стены: пробуем по одной оси
		var nx := global_position + Vector3(dir.x, 0, 0) * spd * dt
		var nz := global_position + Vector3(0, 0, dir.z) * spd * dt
		if not _inside_obstacle(nx):
			np = nx + Vector3(0, 0, signf(dir.z) * 0.2 * spd * dt)
		elif not _inside_obstacle(nz):
			np = nz + Vector3(signf(dir.x) * 0.2 * spd * dt, 0, 0)
		else:
			np = global_position
	var moved := (np - global_position).length()
	global_position = Vector3(np.x, global_position.y if state == S.SCRIPT else 0.0, np.z)
	move_speed = moved / maxf(dt, 0.0001)
	_face(global_position + dir, dt * 5.0)
	_step_acc += moved
	var stride := lerpf(0.8, 1.15, fig.wrong)
	if _step_acc >= stride:
		_step_acc = 0.0
		_left = not _left
		var indoors := world.is_indoors(global_position)
		Snd.play_at("ent_wood" if indoors else "ent_step", global_position + Vector3(0, 0.1, 0), world, -3.0, randf_range(0.92, 1.05), 26.0, 3.0)
		if not indoors:
			world.prints.add(global_position, rotation.y, _left, 1 if fig.wrong > 0.5 else 0, 1.15)


func _physics_process(dt: float) -> void:
	if state == S.HIDDEN or G.player == null or world == null:
		return
	var p: Player = G.player
	var d := dist_to_player()
	fig.look_at_pos = p.eye_pos()
	var hp := fig.head_pos()
	var in_beam := p.lit_by_lamp(hp, world.weather.vis * 0.95 + 1.0)
	if in_beam and not seen_once:
		seen_once = true
		seen.emit()
	grace = maxf(0.0, grace - dt)
	move_speed = 0.0

	match state:
		S.WATCH:
			_face(p.global_position, dt * 0.6)
			if in_beam:
				lit_t += dt
			# растворяется в порыв, либо если долго держать в луче, либо если подойти вплотную
			if (world.weather.gust > 0.6 and d > 3.0) or lit_t > 5.0 or d < 3.5:
				if world.weather.gust < 0.6:
					world.weather.force_gust(0.95, 3.0)
				else:
					hide_now()
					lost.emit()
		S.ACTIVE:
			_ai_active(p, d, in_beam, dt)
		S.PASS:
			_ai_pass(p, d, dt)
		S.LEAVE:
			_move(leave_dir, speed_for_level() + 0.6, dt)
			if d > world.weather.vis + 6.0 or d > 40.0:
				hide_now()
				lost.emit()
		S.SCRIPT:
			if not path.is_empty():
				var tgt: Vector3 = path[0]
				var to := tgt - global_position
				to.y = 0.0
				if to.length() < 0.15:
					path.pop_front()
				else:
					_move(to, path_speed, dt)

	fig.speed = move_speed
	if _light != null and _light.visible:
		_lt += dt
		_light.light_energy = 1.1 * (0.55 + 0.45 * sin(_lt * 1.35)) + 0.25
	# звук близости и помехи на рации
	var near := clampf(1.0 - d / 14.0, 0.0, 1.0)
	near_snd.volume_db = lerpf(-40.0, -4.0, near) if state != S.WATCH else -60.0
	if state == S.ACTIVE or state == S.PASS:
		_croak_t -= dt
		if _croak_t <= 0.0 and d < 12.0:
			_croak_t = randf_range(5.0, 11.0)
			Snd.play_at("ent_croak", hp, world, -6.0, randf_range(0.9, 1.05), 22.0, 2.6)


func _ai_active(p: Player, d: float, in_beam: bool, dt: float) -> void:
	var w := world.weather
	var fire := p.flare_t > 0.0
	var indoors := world.is_indoors(p.global_position)
	# что оно знает о том, где игрок
	if p.lamp_shining() and d < 36.0 and not indoors:
		known = p.global_position
		aware = true
		lost_t = 0.0
	elif p.noise >= 2 and d < 13.0:
		known = p.global_position
		aware = true
		lost_t = 0.0
	elif p.noise == 1 and d < 5.5:
		known = p.global_position
		aware = true
		lost_t = 0.0
	elif fire and d < 30.0:
		known = p.global_position
		aware = true
		lost_t = 0.0
	else:
		lost_t += dt
	# игрок ушёл в дом и закрылся — уходит
	if indoors:
		lost_t += dt * 2.0
		if lost_t > 6.0:
			leave()
		return
	# огонь: держится на краю света
	if fire and d < 11.5:
		var away := global_position - p.global_position
		_move(away, 2.6, dt)
		_face(p.global_position, dt * 3.0)
		fig.reach = move_toward(fig.reach, 0.0, dt * 2.0)
		return
	# спрятался: темно, неподвижен, рука на леере (до четвёртой ночи хватает просто замереть)
	var hidden := (not p.lamp_shining()) and p.still_t > 0.7 and (p.gripping or level <= 3) and not fire
	if hidden and d < 9.0:
		_start_pass(p)
		return
	# луч держит его на месте
	if in_beam and freezes_in_light() and w.gust < 0.6:
		lit_t += dt
		fig.reach = move_toward(fig.reach, 0.0, dt)
		if level >= 4 and lit_t > 2.6:
			# научилось гасить фонарь
			p.kill_lamp(1.7)
			lit_t = 0.0
		return
	lit_t = maxf(0.0, lit_t - dt * 0.5)
	if not aware or lost_t > 24.0:
		leave()
		return
	var to := known - global_position
	to.y = 0.0
	if to.length() > 0.6:
		var spd := speed_for_level()
		if w.gust > 0.5:
			spd *= 1.25
		_move(to, spd, dt)
	else:
		# дошло до места, где он был, и не нашло
		lost_t += dt * 3.0
	fig.reach = move_toward(fig.reach, 1.0 if d < 3.2 else 0.0, dt * 2.0)
	if d < 1.25 and lethal and grace <= 0.0 and not G.god:
		_catch()


func _start_pass(p: Player) -> void:
	state = S.PASS
	# точка по ту сторону игрока, со смещением вбок на метр с небольшим: пройдёт рядом
	var to := p.global_position - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.1 else Vector3.FORWARD
	var side := dir.cross(Vector3.UP).normalized()
	if p.gripping:
		# с той стороны, где нет троса
		var n: Dictionary = world.ropes.nearest(p.global_position, 3.0)
		if not n.is_empty():
			var rp: Vector3 = n.p
			if (rp - p.global_position).dot(side) > 0.0:
				side = -side
	pass_to = p.global_position + side * 1.25 + dir * 9.0
	known = p.global_position + side * 1.25
	pass_wait = randf_range(2.5, 4.5)
	fig.reach = 0.0


func _ai_pass(p: Player, d: float, dt: float) -> void:
	# игрок выдал себя — рывок
	var betrayed := p.lamp_shining() or p.noise >= 1 or (level >= 4 and not p.gripping)
	if betrayed and d < 7.0 and p.flare_t <= 0.0:
		state = S.ACTIVE
		known = p.global_position
		aware = true
		lost_t = 0.0
		grace = 0.25 if d < 2.5 else 0.6
		if d < 2.4 and lethal and not G.god:
			_catch()
		return
	var to_known := known - global_position
	to_known.y = 0.0
	if to_known.length() > 0.5 and pass_wait > 0.0:
		_move(to_known, 1.05, dt)
	elif pass_wait > 0.0:
		# стоит рядом, «слушает»
		pass_wait -= dt
		_face(p.global_position, dt * 1.2)
	else:
		var to := pass_to - global_position
		to.y = 0.0
		_move(to, 1.25, dt)
		if to.length() < 1.0 or d > world.weather.vis + 5.0:
			hide_now()
			passed.emit()


func _catch() -> void:
	if state == S.HIDDEN:
		return
	state = S.SCRIPT
	path.clear()
	caught.emit()


## Для записи и музея: поставить в позу.
func show_pose(pos: Vector3, yaw_deg: float, wrong := 1.0, reach_k := 0.0) -> void:
	global_position = pos
	rotation.y = deg_to_rad(yaw_deg)
	fig.set_wrong(wrong)
	fig.reach = reach_k
	fig.speed = 0.0
	state = S.SCRIPT
	path.clear()
	visible = true
