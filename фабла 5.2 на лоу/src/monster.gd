extends Node3D
## «Сменщик» — the thing that answers on the air. Procedural body, stop-motion movement.

enum S { GONE, WATCH, STALK, RETREAT, WAIT, VISIT, ASSAULT, HUNT, STUN, SEARCH, CHECK, FLEE, APPAR, SHOW }

const DOOR_OUT := Vector3(9.0, 0, 0)
const ROOMS := [Vector3(-5, 0, -3), Vector3(0.5, 0, -2.6), Vector3(5.5, 0, -2.6), Vector3(-4.6, 0, 2.6), Vector3(1, 0, 2.2), Vector3(6, 0, 2.6), Vector3(-6.5, 0, 0), Vector3(3, 0, 0)]

var g: Node
var p: Node
var st: int = S.GONE
var t: float = 0.0
var path: Array = []
var repath: float = 0.0
var last_known := Vector3.ZERO
var seen_recent: float = 0.0
var lit_t: float = 0.0
var immune: float = 0.0
var search_list: Array = []
var fail: float = 0.0
var self_opened: bool = false
var knocks: int = 0
var retreat_dir := Vector3.ZERO
var walk: float = 0.0
var moving: bool = false
var frozen: bool = false
var esp: bool = false

var rig: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var face_mat: ShaderMaterial
var breath_snd: AudioStreamPlayer3D
var _q: float = 0.0
var _twitch := Vector3.ZERO


func _ready() -> void:
	_build()
	vanish()


func _build() -> void:
	var cloth := B.col(Color(0.028, 0.03, 0.033), 1.0)
	var skin := B.col(Color(0.2, 0.2, 0.19), 0.7)
	rig = Node3D.new()
	add_child(rig)
	leg_l = _limb(Vector3(-0.12, 1.02, 0), 0.06, 1.02, cloth)
	leg_r = _limb(Vector3(0.12, 1.02, 0), 0.06, 1.02, cloth)
	B.cyl(rig, Vector3(0, 1.38, 0), 0.31, 1.2, cloth, false, 0.2)
	B.box(rig, Vector3(0, 1.97, 0), Vector3(0.64, 0.14, 0.26), cloth, false)
	arm_l = _limb(Vector3(-0.35, 1.98, 0), 0.042, 1.3, cloth)
	arm_r = _limb(Vector3(0.35, 1.98, 0), 0.042, 1.3, cloth)
	for a in [arm_l, arm_r]:
		for i in 4:
			var f := B.box(a, Vector3(-0.04 + i * 0.027, -1.44, 0), Vector3(0.014, 0.3, 0.014), skin, false)
			f.rotation.z = (i - 1.5) * 0.09
	B.cyl(rig, Vector3(0, 2.12, 0), 0.05, 0.28, skin)
	head = Node3D.new()
	head.position = Vector3(0, 2.3, 0)
	rig.add_child(head)
	B.ball(head, Vector3(0, 0, 0.02), 0.2, cloth, Vector3(1, 1.2, 1.1))
	var fm := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.3, 0.36)
	fm.mesh = qm
	face_mat = ShaderMaterial.new()
	face_mat.shader = load("res://shaders/face.gdshader")
	fm.material_override = face_mat
	fm.position = Vector3(0, -0.01, -0.175)
	fm.rotation.y = PI
	head.add_child(fm)
	breath_snd = AudioStreamPlayer3D.new()
	breath_snd.stream = Snd.streams.get("loop_breath_m")
	breath_snd.max_distance = 16.0
	breath_snd.unit_size = 3.0
	breath_snd.position.y = 2.0
	add_child(breath_snd)


func _limb(pivot: Vector3, r: float, length: float, mat: Material) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	rig.add_child(n)
	B.cyl(n, Vector3(0, -length / 2.0, 0), r, length, mat)
	return n


# ------------------------------------------------------------------ state changes
func head_pos() -> Vector3:
	return global_position + Vector3(0, 2.1, 0)


func active() -> bool:
	return st != S.GONE and st != S.WAIT and st != S.SHOW


func inside_building() -> bool:
	return absf(global_position.x) < 8.0 and absf(global_position.z) < 5.0


func place(pos: Vector3, state: int) -> void:
	global_position = Vector3(pos.x, 0, pos.z)
	visible = true
	st = state
	t = 0.0
	lit_t = 0.0
	path.clear()
	face_to(p.global_position, 1.0)
	if not breath_snd.playing:
		breath_snd.play()


func vanish() -> void:
	st = S.GONE
	visible = false
	global_position = Vector3(0, -60, 0)
	if breath_snd != null:
		breath_snd.stop()


func begin_stalk() -> void:
	var back: Vector3 = -p.look_dir()
	back.y = 0
	for i in 12:
		var d: Vector3 = back.normalized().rotated(Vector3.UP, randf_range(-1.3, 1.3))
		var pos: Vector3 = p.global_position + d * randf_range(21.0, 26.0)
		pos.x = clampf(pos.x, -31, 45)
		pos.z = clampf(pos.z, -51, 27)
		if absf(pos.x) < 10 and absf(pos.z) < 7:
			continue
		if pos.distance_to(p.global_position) < 15:
			continue
		place(pos, S.STALK)
		return
	place(p.global_position + Vector3(-22, 0, 0), S.STALK)


func begin_visit() -> void:
	place(DOOR_OUT, S.VISIT)
	rotation.y = PI / 2
	self_opened = false
	knocks = 0


func begin_assault() -> void:
	place(DOOR_OUT, S.ASSAULT)
	rotation.y = PI / 2
	knocks = 0


func begin_hunt() -> void:
	if st == S.GONE or st == S.WAIT:
		place(DOOR_OUT, S.HUNT)
	st = S.HUNT
	t = 0.0
	immune = 0.0
	last_known = g.world.lockers[p.hidden].front if p.hidden >= 0 else p.global_position
	Snd.play3d("croak", head_pos(), 2.0, 30.0, 0.8)
	g.on_hunt_started()


func begin_search() -> void:
	st = S.SEARCH
	t = 0.0
	search_list = ROOMS.duplicate()
	search_list.shuffle()
	search_list.resize(3)
	if p.hidden >= 0 and randf() < 0.75:
		var lp: Vector3 = g.world.lockers[p.hidden].front
		search_list.insert(randi_range(0, 1), lp)


func flee() -> void:
	if st == S.GONE:
		return
	if not inside_building():
		vanish()
		return
	st = S.FLEE
	path.clear()
	Snd.play3d("croak", head_pos(), 3.0, 30.0, 1.3)


func watch(pos: Vector3, dur: float) -> void:
	place(pos, S.WATCH)
	t = -dur


func appear(pos: Vector3, dur: float) -> void:
	place(pos, S.APPAR)
	t = -dur


# ------------------------------------------------------------------ helpers
func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func face_to(target: Vector3, k: float) -> void:
	var to: Vector3 = target - global_position
	if Vector2(to.x, to.z).length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(k, 0, 1))


func step_to(dt: float, target: Vector3, sp: float) -> void:
	var to: Vector3 = target - global_position
	to.y = 0
	var d: float = to.length()
	if d < 0.01:
		return
	global_position += to / d * minf(d, sp * dt)
	global_position.y = 0
	face_to(target, dt * 8.0)
	walk += sp * dt
	moving = true


func advance(dt: float, target: Vector3, sp: float) -> bool:
	repath -= dt
	if repath <= 0.0 or path.is_empty():
		path = g.nav_path(global_position, target)
		repath = 0.35
	if path.is_empty():
		return true
	var nxt: Vector3 = path[0]
	if flat_dist(nxt, global_position) < 0.25:
		path.pop_front()
		return path.is_empty()
	step_to(dt, nxt, sp)
	for d in g.world.doors:
		if not d.open and flat_dist(d.center(), global_position) < 1.3:
			d.bolted = false
			d.set_open(true)
	return false


func can_see() -> bool:
	if p.hidden >= 0 or p.noclip:
		return false
	var d: float = global_position.distance_to(p.global_position)
	var maxd: float = 17.0 if p.flash_on else 10.0
	return d < maxd and g.los(head_pos(), p.eye(), true)


func try_kill(reach: float = 1.15) -> bool:
	if p.hidden < 0 and flat_dist(global_position, p.global_position) < reach and absf(p.global_position.y) < 1.5 and g.los(global_position + Vector3(0, 1.3, 0), p.eye()):
		g.kill("monster")
		return true
	return false


# ------------------------------------------------------------------ main loop
func _physics_process(dt: float) -> void:
	if st == S.GONE or not g.running:
		return
	t += dt
	immune = maxf(0.0, immune - dt)
	seen_recent = maxf(0.0, seen_recent - dt)
	moving = false
	frozen = false
	var aggr: float = g.aggression()
	match st:
		S.WAIT:
			if t > 0.0:
				if p.outside():
					begin_stalk()
				else:
					vanish()
		S.WATCH, S.APPAR:
			face_to(p.global_position, dt * 2.0)
			if st == S.WATCH and p.sees(head_pos(), 0.9):
				seen_recent += dt * 2.0
				if seen_recent > 0.9:
					g.flicker(0.7)
					Snd.play("swell", -8.0)
					g.fear_kick(0.6)
					vanish()
					return
			if t > 0.0:
				vanish()
		S.STALK:
			_stalk(dt, aggr)
		S.RETREAT:
			global_position += retreat_dir * 10.0 * dt
			walk += 10.0 * dt
			moving = true
			if t > 1.5:
				visible = false
				breath_snd.stop()
				st = S.WAIT
				t = -maxf(2.5, 9.0 - aggr * 1.2)
		S.VISIT:
			_visit(dt)
		S.ASSAULT:
			_assault(dt)
		S.HUNT:
			_hunt(dt, aggr)
		S.STUN:
			frozen = true
			if t > 2.5:
				st = S.HUNT
				immune = 7.0
		S.SEARCH:
			_search(dt)
		S.CHECK:
			_check(dt)
		S.FLEE:
			if advance(dt, Vector3(12, 0, 0), 7.5):
				vanish()
		S.SHOW:
			face_to(p.global_position, dt * 3.0)
	_animate(dt)


func _stalk(dt: float, aggr: float) -> void:
	if not p.outside():
		face_to(p.global_position, dt)
		if t > 5.0:
			vanish()
		return
	t = 0.0
	if p.lights(head_pos()):
		frozen = true
		lit_t += dt
		p.lit_drain = 2.2
		face_to(p.global_position, dt * 5.0)
		if lit_t > 1.3:
			lit_t = 0.0
			Snd.play3d("croak", head_pos(), 4.0, 40.0)
			retreat_dir = (global_position - p.global_position)
			retreat_dir.y = 0
			retreat_dir = retreat_dir.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
			st = S.RETREAT
			t = 0.0
		return
	lit_t = maxf(0.0, lit_t - dt * 0.4)
	var sp: float = minf(3.6, 1.8 + 0.3 * aggr)
	if not p.sees(head_pos(), 0.5):
		sp *= 1.45
	if g.los(global_position + Vector3(0, 0.9, 0), p.global_position + Vector3(0, 0.9, 0)):
		step_to(dt, p.global_position, sp)
	else:
		advance(dt, p.global_position, sp)
	try_kill()


func _visit(dt: float) -> void:
	var d: Door = g.world.front_door
	if not g.lit():
		begin_assault()
		return
	if knocks == 0 and t > 0.3:
		knocks = 1
		Snd.play3d("knock", d.center(), 4.0, 40.0)
	if knocks == 1 and t > 3.4:
		knocks = 2
		g.voice("v_f_door" if randf() < 0.5 else "v_f_door2", d.center(), "", 30.0)
	if d.open and not self_opened:
		if flat_dist(p.global_position, d.center()) < 5.0:
			g.kill("monster")
		else:
			g.suppress(40.0)
			begin_hunt()
		return
	if self_opened:
		if not d.open:
			self_opened = false
			t = 9.0
		elif t > 12.5:
			g.suppress(40.0)
			begin_hunt()
		return
	if knocks == 2 and t > 7.5:
		knocks = 3
		if not d.bolted:
			d.set_open(true, true)
			self_opened = true
			g.hud.say("Дверь!", 2.0)
			return
		Snd.play3d("knock_slow", d.center(), 4.0, 40.0)
	if knocks == 3 and t > 13.0:
		knocks = 4
		Snd.play3d("bang", d.center(), 6.0, 40.0)
		p.shake = 0.5
	if t > 17.0:
		vanish()


func _assault(dt: float) -> void:
	var d: Door = g.world.front_door
	if g.lit():
		vanish()
		return
	if d.open:
		begin_hunt()
		return
	if not d.bolted:
		if t > 2.5:
			d.set_open(true, true)
			begin_hunt()
		return
	if t > 2.4 * (knocks + 1):
		knocks += 1
		Snd.play3d("bang", d.center(), 7.0, 45.0, randf_range(0.85, 1.05))
		if flat_dist(p.global_position, d.center()) < 9.0:
			p.shake = 0.6
		if knocks >= 8:
			d.bolted = false
			d.set_open(true)
			Snd.play3d("bang3", d.center(), 8.0, 45.0)
			begin_hunt()


func _hunt(dt: float, aggr: float) -> void:
	var see: bool = can_see()
	if see:
		last_known = p.global_position
		seen_recent = 1.2
	elif p.noise_t > 0.0 and p.hidden < 0 and global_position.distance_to(p.global_position) < 14.0:
		last_known = p.global_position
	if p.hidden >= 0 and seen_recent > 0.0:
		# it saw the player climb in
		seen_recent = 5.0
		var lp: Vector3 = g.world.lockers[p.hidden].front
		if advance(dt, lp, 4.5) or flat_dist(global_position, lp) < 0.5:
			g.kill("monster")
		return
	if see and immune <= 0.0 and p.lights(head_pos()):
		frozen = true
		lit_t += dt
		p.lit_drain = 4.0
		if lit_t > 0.9:
			lit_t = 0.0
			st = S.STUN
			t = 0.0
			Snd.play3d("croak", head_pos(), 4.0, 30.0, 1.2)
		return
	if try_kill():
		return
	var sp: float = minf(4.6, 3.5 + 0.2 * aggr)
	if see and g.los(global_position + Vector3(0, 0.9, 0), p.global_position + Vector3(0, 0.9, 0)):
		step_to(dt, p.global_position, sp)
	elif advance(dt, last_known, sp) and not see:
		begin_search()


func _search(dt: float) -> void:
	if can_see() or (p.noise_t > 0.0 and p.hidden < 0 and global_position.distance_to(p.global_position) < 12.0):
		st = S.HUNT
		last_known = p.global_position
		Snd.play3d("croak", head_pos(), 2.0, 30.0)
		return
	if try_kill():
		return
	if search_list.is_empty():
		begin_search()
		return
	var tgt: Vector3 = search_list[0]
	if t < 0.0:
		rotation.y += dt * 1.6 * sin(t * 3.0)
		return
	if advance(dt, tgt, 2.3):
		search_list.pop_front()
		t = -randf_range(1.5, 3.0)
		if p.hidden >= 0 and flat_dist(global_position, g.world.lockers[p.hidden].front) < 0.8:
			st = S.CHECK
			t = 0.0
			fail = 0.0


func _check(dt: float) -> void:
	if p.hidden < 0:
		st = S.HUNT
		last_known = p.global_position
		return
	face_to(g.world.lockers[p.hidden].pos, dt * 3.0)
	frozen = t > 1.0 and t < 4.0
	if not p.holding_breath:
		fail += dt
	if fail > 1.4:
		g.kill("monster")
		return
	if t > 5.0:
		st = S.SEARCH
		t = 0.0


# ------------------------------------------------------------------ look
func _animate(dt: float) -> void:
	_q += dt
	if _q < 0.1:
		return
	_q = 0.0
	var indoors: bool = inside_building()
	rig.rotation.x = -0.2 if indoors else -0.05
	rig.scale = Vector3.ONE * (0.93 if indoors else 1.0)
	rig.position.y = 0.0
	if st == S.WATCH:
		# stoops to the window so the face is level with the glass
		rig.position.y = -0.62
		rig.rotation.x = -0.12
	var sw: float = sin(walk * 3.2) * (0.5 if moving else 0.0)
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	arm_l.rotation.x = -sw * 0.5 + 0.08
	arm_r.rotation.x = sw * 0.5 + 0.08
	arm_l.rotation.z = -0.06
	arm_r.rotation.z = 0.06
	if randf() < 0.18:
		_twitch = Vector3(randf_range(-0.3, 0.3), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6))
	elif randf() < 0.3:
		_twitch = Vector3.ZERO
	if frozen:
		_twitch = Vector3(randf_range(-0.5, 0.5), randf_range(-0.9, 0.9), randf_range(-0.9, 0.9))
		arm_l.rotation.z = -randf_range(0.0, 0.5)
		arm_r.rotation.z = randf_range(0.0, 0.5)
	if st == S.CHECK:
		_twitch = Vector3(0.35, 0, 0.5)
	head.rotation = _twitch
	face_mat.set_shader_parameter("power", 2.5 if esp else (1.6 if frozen or st == S.WATCH else 0.9))
