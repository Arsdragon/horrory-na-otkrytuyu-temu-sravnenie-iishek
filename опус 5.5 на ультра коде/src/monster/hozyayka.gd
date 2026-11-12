class_name Hozyayka
extends Node3D
## Хозяйка: слепая, слышит. Вода — её уши. Выходит из трапов, бросается на звук, ищет на ощупь,
## моется под открытой водой, встаёт «за спину». Касание — смерть.

signal state_changed(s: int)

enum S { GONE, EMERGE, ROAM, INVESTIGATE, RUSH, SEARCH, WASH, BEHIND, SUBMERGE, SCRIPT, KILL }
const NAMES := ["нет", "выходит", "бродит", "идёт на звук", "бросок", "ищет", "моется", "за спиной", "уходит", "сценарий", "убивает"]

const WALK_SPEED := 1.25
const FAST_SPEED := 2.1
const RUSH_SPEED := 4.2
const TOUCH := 0.95

var body: HozBody
var state := S.GONE
var state_t := 0.0
var path := PackedVector3Array()
var path_i := 0
var target := Vector3.ZERO
var speed := 0.0
var cur_speed := 0.0
var active_t := 0.0
var active_max := 90.0
var search_t := 0.0
var search_pt := Vector3.ZERO
var grope_t := 0.0
var heard_hide: Node = null
var heard_hide_t := -99.0
var wash_tap: Node = null
var drain := Vector3.ZERO
var behind_ang := 0.0
var behind_room := ""
var behind_still := 0.0
var behind_cool := 0.0
var behind_count := 0
var kill_cb: Callable
var aggression := 1.0
var snd_breath: AudioStreamPlayer3D
var snd_nails: AudioStreamPlayer3D
var step_t := 0.0
var whisper_t := 8.0
var hand: Node3D
var no_kill := false
var last_heard := Vector3.ZERO
var last_heard_t := -99.0
var stuck_t := 0.0
var _last_pos := Vector3.ZERO
var repath_t := 0.0


func _ready() -> void:
	body = HozBody.new()
	add_child(body)
	visible = false
	snd_breath = Snd.attach("loop_hoz_breath", self, -80.0, 14.0)
	snd_nails = Snd.attach("loop_nails", self, -80.0, 22.0)
	if snd_breath:
		snd_breath.position.y = 2.0
	if snd_nails:
		snd_nails.position.y = 0.2


func is_active() -> bool:
	return state != S.GONE and state != S.SUBMERGE


func set_state(s: int) -> void:
	if state == s:
		return
	state = s
	state_t = 0.0
	state_changed.emit(s)


func state_name() -> String:
	return NAMES[state]


# ---------------------------------------------------------------- появление и уход

## Выйти из трапа в точке p (поверхность пола).
func emerge(p: Vector3, face: Vector3 = Vector3.ZERO, quick := false) -> void:
	if Game.cheats.get("no_monster", false):
		return
	drain = p
	global_position = p
	if face != Vector3.ZERO:
		_face(face, 1.0)
	visible = true
	set_state(S.EMERGE)
	active_t = 0.0
	body.floor_y = p.y
	body.play("crouch", 0.0)
	body.rig.crawl = 0.6
	body.model.position.y = -2.6 if not quick else 0.0
	body.set_clip(p.y - 0.02)
	Snd.at("drain_gurgle", p, 4.0, 1.0, 25.0)
	Snd.at("hair_wet", p, 0.0, 1.0, 12.0)


func submerge() -> void:
	if state == S.GONE or state == S.SUBMERGE:
		return
	set_state(S.SUBMERGE)
	path = PackedVector3Array()
	Snd.at("drain_gurgle", global_position, 2.0, 0.8, 25.0)


func vanish() -> void:
	set_state(S.GONE)
	visible = false
	path = PackedVector3Array()
	_release_behind()


func set_scripted(on: bool) -> void:
	if on:
		set_state(S.SCRIPT)
		visible = true
	else:
		set_state(S.ROAM)


# ---------------------------------------------------------------- слух

func hear(p: Vector3, r: float, kind: String, in_water: bool) -> void:
	if state in [S.GONE, S.EMERGE, S.SUBMERGE, S.SCRIPT, S.KILL, S.BEHIND]:
		return
	if kind == "water":
		return
	var d := _path_len(global_position, p)
	if in_water:
		d *= 0.6
	if d > r * aggression:
		return
	last_heard = p
	last_heard_t = Game.world.time
	if kind == "hide":
		heard_hide = _hide_near(p)
		heard_hide_t = Game.world.time
	var loud := r - d
	if state == S.WASH and kind == "step" and loud < 4.0:
		return
	if kind in ["throw", "slam", "work", "scream"] or loud > 6.0 or (in_water and loud > 2.0):
		_go(p, S.RUSH)
	else:
		_go(p, S.INVESTIGATE)


## Позвали водой: открыли кран/душ.
func lure(tap: Node) -> void:
	if state in [S.GONE, S.EMERGE, S.SUBMERGE, S.SCRIPT, S.KILL, S.BEHIND, S.RUSH]:
		return
	wash_tap = tap
	_go((tap as Node3D).global_position, S.INVESTIGATE)
	target = _wash_point(tap)
	_repath()


func _wash_point(tap: Node) -> Vector3:
	if tap.has_method("wash_point"):
		return tap.wash_point()
	return (tap as Node3D).global_position


func _hide_near(p: Vector3) -> Node:
	var best: Node = null
	var bd := 2.0
	for h in Game.world.hides:
		var dd: float = (h as Node3D).global_position.distance_to(p)
		if dd < bd:
			bd = dd
			best = h
	return best


func _go(p: Vector3, s: int) -> void:
	target = p
	set_state(s)
	_repath()


func _path_len(a: Vector3, b: Vector3) -> float:
	var map := get_world_3d().navigation_map
	var pth := NavigationServer3D.map_get_path(map, a, b, true)
	if pth.size() < 2:
		return a.distance_to(b) * 1.5
	var l := 0.0
	for i in range(1, pth.size()):
		l += pth[i - 1].distance_to(pth[i])
	l += pth[pth.size() - 1].distance_to(b)
	return l


func _repath() -> void:
	var map := get_world_3d().navigation_map
	path = NavigationServer3D.map_get_path(map, global_position, target, true)
	path_i = 1 if path.size() > 1 else 0
	repath_t = 1.5
	# соль: обрезаем путь у порога безопасной комнаты
	for i in path.size():
		if Game.world.is_safe(path[i]):
			path.resize(maxi(1, i))
			break


# ---------------------------------------------------------------- кадр

func _physics_process(delta: float) -> void:
	if state == S.GONE:
		return
	state_t += delta
	if is_active():
		active_t += delta
	behind_cool = maxf(0.0, behind_cool - delta)
	var pl: Player = Game.player
	match state:
		S.EMERGE:
			_do_emerge(delta)
		S.SUBMERGE:
			_do_submerge(delta)
		S.ROAM:
			_do_roam(delta)
		S.INVESTIGATE:
			speed = FAST_SPEED if wash_tap == null else WALK_SPEED * 1.3
			if _follow(delta):
				if wash_tap and is_instance_valid(wash_tap) and wash_tap.is_running():
					set_state(S.WASH)
				else:
					_start_search(target)
		S.RUSH:
			speed = RUSH_SPEED
			if _follow(delta):
				_start_search(target)
		S.SEARCH:
			_do_search(delta)
		S.WASH:
			_do_wash(delta)
		S.BEHIND:
			_do_behind(delta)
		S.SCRIPT:
			pass
	if state in [S.ROAM, S.INVESTIGATE, S.RUSH, S.SEARCH, S.WASH] and pl and not pl.dead:
		_check_touch(pl)
	_animate(delta)
	_sounds(delta)


func _do_emerge(delta: float) -> void:
	var dur := 3.0
	var k := clampf(state_t / dur, 0.0, 1.0)
	body.model.position.y = lerpf(body.model.position.y, 0.0, clampf(delta * 1.8, 0.0, 1.0)) if k < 1.0 else 0.0
	body.rig.crawl = lerpf(0.6, 0.0, k)
	if k >= 1.0:
		body.model.position.y = 0.0
		body.set_clip(-1000.0)
		set_state(S.ROAM)
		_pick_roam()


func _do_submerge(delta: float) -> void:
	body.play("crouch", 0.4)
	body.rig.crawl = minf(0.6, body.rig.crawl + delta * 0.4)
	body.set_clip(global_position.y - 0.02)
	body.model.position.y -= delta * 1.1
	if body.model.position.y < -2.7:
		vanish()


func _pick_roam() -> void:
	var pl: Player = Game.player
	var w: World = Game.world
	var p := global_position
	# бродит в сторону игрока, но не прямо к нему
	if pl and randf() < 0.65 * aggression:
		p = pl.global_position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6))
	else:
		var keys := w.rooms.keys()
		var rid: String = keys[randi() % keys.size()]
		p = w.room_center(rid)
	var map := get_world_3d().navigation_map
	target = NavigationServer3D.map_get_closest_point(map, p)
	_repath()


func _do_roam(delta: float) -> void:
	speed = WALK_SPEED
	if _follow(delta) or state_t > 25.0:
		state_t = 0.0
		if randf() < 0.4:
			_start_search(global_position, 4.0)
		else:
			_pick_roam()


func _start_search(p: Vector3, secs := -1.0) -> void:
	set_state(S.SEARCH)
	search_pt = p
	search_t = secs if secs > 0.0 else randf_range(8.0, 14.0) * (0.8 + aggression * 0.3)
	grope_t = 1.0
	path = PackedVector3Array()
	Snd.at("hoz_sniff", global_position + Vector3.UP * 2.0, 0.0, randf_range(0.9, 1.1), 14.0)
	# слышала, как прятался — идёт к шкафчику
	if heard_hide and is_instance_valid(heard_hide) and Game.world.time - heard_hide_t < 8.0:
		target = (heard_hide as Node3D).global_position
		_repath()


func _do_search(delta: float) -> void:
	speed = WALK_SPEED * 0.7
	search_t -= delta
	if heard_hide and is_instance_valid(heard_hide) and Game.world.time - heard_hide_t < 8.0:
		if _follow(delta) or global_position.distance_to((heard_hide as Node3D).global_position) < 1.3:
			var h := heard_hide
			heard_hide = null
			if h.has_method("monster_open"):
				h.monster_open(self)
		return
	if path.size() > 0 and path_i < path.size():
		_follow(delta)
	else:
		grope_t -= delta
		if grope_t <= 0.0:
			grope_t = randf_range(1.5, 3.0)
			var map := get_world_3d().navigation_map
			target = NavigationServer3D.map_get_closest_point(map, search_pt + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
			_repath()
			if randf() < 0.4:
				Snd.at("hoz_sniff", global_position + Vector3.UP * 2.0, -2.0, randf_range(0.85, 1.1), 14.0)
	if search_t <= 0.0:
		set_state(S.ROAM)
		_pick_roam()


func _do_wash(delta: float) -> void:
	speed = 0.0
	if wash_tap == null or not is_instance_valid(wash_tap):
		set_state(S.ROAM)
		return
	var tp := (wash_tap as Node3D).global_position
	_face(tp, delta * 3.0)
	if state_t > randf_range(18.0, 26.0) or not wash_tap.is_running():
		if wash_tap.is_running():
			wash_tap.set_running(false, true)
		wash_tap = null
		if randf() < 0.5:
			submerge()
		else:
			set_state(S.ROAM)
			_pick_roam()


## Идёт по пути. true — дошла.
func _follow(delta: float) -> bool:
	repath_t -= delta
	if repath_t <= 0.0 and state == S.RUSH:
		_repath()
	if path.size() == 0 or path_i >= path.size():
		return true
	var p := path[path_i]
	var to := p - global_position
	to.y = 0
	if to.length() < 0.25:
		path_i += 1
		if path_i >= path.size():
			return true
		return false
	cur_speed = move_toward(cur_speed, speed, delta * 6.0)
	var step := to.normalized() * cur_speed * delta
	if step.length() > to.length():
		step = to
	var np := global_position + step
	np.y = lerpf(global_position.y, p.y, clampf(delta * 8.0, 0.0, 1.0))
	if Game.world.is_safe(np):
		path = PackedVector3Array()
		return true
	global_position = np
	_face(global_position + to, delta * (8.0 if state == S.RUSH else 4.0))
	body.floor_y = global_position.y
	# двери
	for d: Door in Game.world.doors.values():
		if d.center().distance_to(global_position + Vector3.UP) < 1.5:
			d.monster_pass(global_position)
	# застряла
	if global_position.distance_to(_last_pos) < 0.01 * cur_speed:
		stuck_t += delta
		if stuck_t > 2.0:
			stuck_t = 0.0
			path_i += 1
	else:
		stuck_t = 0.0
	_last_pos = global_position
	return false


func _face(p: Vector3, k: float) -> void:
	var d := p - global_position
	d.y = 0
	if d.length() < 0.01:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(k, 0.0, 1.0))


# ---------------------------------------------------------------- касание и «за спиной»

func _check_touch(pl: Player) -> void:
	if pl.hidden_in or pl.noclip:
		return
	var d := pl.global_position - global_position
	var dy := absf(d.y)
	d.y = 0
	var dist := d.length()
	if dy > 1.6:
		return
	var reach := TOUCH
	var fwd := -global_transform.basis.z
	if state in [S.SEARCH, S.RUSH] and dist < 1.7 and fwd.dot(d.normalized()) > 0.75:
		reach = 1.7
	if dist > reach:
		return
	if Game.world.is_safe(pl.global_position):
		return
	# игрок смотрит в другую сторону — она встаёт за спину
	var look := pl.look_dir()
	look.y = 0
	var to_her := -d.normalized()
	var facing_away := look.normalized().dot(to_her) < -0.3
	if facing_away and state != S.RUSH and behind_cool <= 0.0 and not Game.flag("no_behind"):
		start_behind()
	else:
		kill()


func start_behind() -> void:
	var pl: Player = Game.player
	set_state(S.BEHIND)
	behind_count += 1
	behind_room = pl.current_room
	behind_still = 0.0
	behind_ang = pl.yaw + PI
	pl.grabbed = true
	path = PackedVector3Array()
	body.play("idle", 0.3)
	body.rig.reach = 0.0
	_show_hand(true)
	Snd.play("hoz_behind", 0.0)
	pl.shake = 0.6
	if Game.main and Game.main.has_method("on_behind"):
		Game.main.on_behind(true)
	if not Game.flag("behind_hint"):
		Game.set_flag("behind_hint")
		Game.show_hint("Не оборачивайся. Не стой. Иди через порог в другую комнату.", 8.0)


func _do_behind(delta: float) -> void:
	var pl: Player = Game.player
	if pl == null or pl.dead:
		return
	# держится за спиной, догоняя поворот камеры не быстрее 70°/с
	var want := pl.yaw + PI
	var diff := angle_difference(behind_ang, want)
	behind_ang += clampf(diff, -deg_to_rad(70) * delta, deg_to_rad(70) * delta)
	# направление от игрока к ней: «вперёд» для угла behind_ang
	global_position = pl.global_position + Vector3(-sin(behind_ang), 0, -cos(behind_ang)) * 0.55
	body.floor_y = global_position.y
	_face(pl.global_position, 1.0)
	# увидел её — конец
	var to_her := global_position + Vector3.UP * 1.9 - pl.eye_pos()
	if pl.look_dir().normalized().dot(to_her.normalized()) > cos(deg_to_rad(52)):
		_release_behind()
		kill()
		return
	if pl.is_moving():
		behind_still = 0.0
	else:
		behind_still += delta
	if behind_still > 4.0 or state_t > 22.0:
		_release_behind()
		kill()
		return
	if pl.current_room != behind_room and pl.current_room != "":
		_release_behind()
		Snd.play("hoz_release", -2.0)
		behind_cool = 40.0
		Game.set_flag("behind_survived", int(Game.getf("behind_survived", 0)) + 1)
		submerge()
		body.model.position.y = -2.7
		vanish()


func _release_behind() -> void:
	var pl: Player = Game.player
	if pl:
		pl.grabbed = false
	_show_hand(false)
	if Game.main and Game.main.has_method("on_behind"):
		Game.main.on_behind(false)


func _show_hand(on: bool) -> void:
	var pl: Player = Game.player
	if on:
		if hand == null:
			hand = HozHand.new()
		if hand.get_parent() == null and pl:
			pl.cam.add_child(hand)
		hand.visible = true
	elif hand:
		hand.visible = false


func kill() -> void:
	if state == S.KILL:
		return
	if Game.cheats.get("god", false) or no_kill:
		_start_search(global_position, 3.0)
		return
	set_state(S.KILL)
	path = PackedVector3Array()
	if Game.main and Game.main.has_method("player_killed"):
		Game.main.player_killed(self)


# ---------------------------------------------------------------- анимация и звук

func _animate(delta: float) -> void:
	var moving := path.size() > 0 and path_i < path.size() and cur_speed > 0.1
	match state:
		S.EMERGE, S.SUBMERGE:
			pass
		S.WASH:
			body.play("crouch", 0.6)
			body.rig.crawl = move_toward(body.rig.crawl, 0.3, delta)
		S.BEHIND:
			body.play("idle", 0.3, 0.6)
		S.SCRIPT, S.KILL:
			pass
		_:
			body.rig.crawl = move_toward(body.rig.crawl, 0.0, delta)
			if moving:
				if cur_speed > 3.0:
					body.play("run", 0.25, cur_speed / 3.4)
				else:
					body.play("walk", 0.4, cur_speed / 1.0)
			else:
				body.play("look" if state == S.SEARCH else "idle", 0.5, 0.8)
	var tgt_stoop := 0.7 if state == S.RUSH else 0.5
	if state == S.SEARCH:
		tgt_stoop = 0.75
	body.rig.stoop = move_toward(body.rig.stoop, tgt_stoop, delta)
	body.rig.reach = move_toward(body.rig.reach, 0.8 if state == S.SEARCH or state == S.RUSH else 0.0, delta * 2.0)
	body.rig.twitch = 0.7 if state in [S.SEARCH, S.BEHIND] else 0.35


func _sounds(delta: float) -> void:
	var pl: Player = Game.player
	var dist := 99.0
	if pl:
		dist = global_position.distance_to(pl.global_position)
	if snd_breath:
		var bv := -6.0 if state in [S.SEARCH, S.BEHIND, S.WASH] else -12.0
		if state == S.RUSH:
			bv = -2.0
		snd_breath.volume_db = lerpf(snd_breath.volume_db, bv if is_active() else -80.0, delta * 3.0)
	if snd_nails:
		var nv := -80.0
		if is_active() and cur_speed > 0.2 and path.size() > 0:
			nv = 2.0 if state == S.RUSH else -8.0
		snd_nails.volume_db = lerpf(snd_nails.volume_db, nv, delta * 6.0)
		snd_nails.pitch_scale = 1.0 + (0.5 if state == S.RUSH else 0.0)
	# шлепки мокрых ступней
	if is_active() and cur_speed > 0.2 and path.size() > 0:
		step_t -= delta * cur_speed
		if step_t <= 0.0:
			step_t = 0.75
			Snd.at("hoz_step", global_position, -2.0 if state == S.RUSH else -6.0, randf_range(0.85, 1.1), 18.0)
	# шёпот
	if is_active() and state != S.KILL:
		whisper_t -= delta
		if whisper_t <= 0.0:
			whisper_t = randf_range(10.0, 22.0)
			if dist < 16.0:
				Snd.at("hoz_whisper", global_position + Vector3.UP * 2.0, -4.0, randf_range(0.92, 1.02), 16.0, "Voice")
	# страх игрока и мигание фонаря
	if pl:
		var f := 0.0
		if is_active():
			f = clampf(1.0 - (dist - 1.5) / 12.0, 0.0, 1.0)
			if state == S.RUSH:
				f = maxf(f, 0.6)
			if state == S.BEHIND:
				f = 1.0
			if dist < 8.0 and randf() < delta * 0.8:
				pl.flick(0.25)
		pl.fear = lerpf(pl.fear, f, delta * 2.0)
