extends Node3D
## One night at relay station «Узел-9»: state, rules, event director.

const M = preload("res://src/monster.gd")
const W = preload("res://src/world.gd")
const HOUR_LEN := 150.0
const WINDOWS := [Vector3(-5, 0, -5.75), Vector3(0.5, 0, -5.75), Vector3(1, 0, 5.75), Vector3(-8.75, 0, 0)]
const SUBS := {
	"v_r_test": "Узел-9, я Байкал. Проверка связи. Как слышите? Приём.",
	"v_r_hour": "Узел-9, я Байкал. Плановая проверка. Подтвердите приём.",
	"v_r_ok": "Принял вас, Узел-9. До связи через час.",
	"v_r_end": "Узел-9, я Байкал. Смена выехала. Встречайте у ворот.",
	"v_r_lost": "Узел-9, не слышу вас. Узел-9, ответьте Байкалу.",
	"v_f_1": "Узел-9. Я Узел-9. Как слышите. Приём.",
	"v_f_2": "Узел-9, я Байкал. Откройте дверь. Приём.",
	"v_f_3": "Узел-9. Выйдите к мачте. Срочно. Приём.",
	"v_f_4": "Узел-9, я Байкал. Погасите свет. Как слышите.",
	"v_f_5": "Я слышу тебя. Ответь мне. Ответь.",
	"v_f_6": "Это сменщик. Я у двери. Открой.",
	"v_f_7": "Узел-9, я Байкал. Плановая проверка. Подтвердите. Подтвердите. Подтвердите.",
	"v_f_ans": "Принял. Узел-9. Принял. Теперь я знаю, где ты.",
	"v_f_door": "Открой. Здесь холодно.",
	"v_f_door2": "Это я. Твой сменщик. Открой дверь.",
	"v_f_your": "Байкал, я Узел-9. У меня всё в порядке. Смена не нужна.",
	"v_f_name": "Узел-9. Узел-9. Узел-9.",
}
const NOTES := {
	1: "ПАМЯТКА ДЕЖУРНОМУ\n(почерк Гринёва, поверх типографского бланка)\n\n1. «Байкал» вызывает ровно в начале часа. Только тогда.\n2. Отвечай, только если горит лампа НЕСУЩАЯ. Ровно горит, не мигает.\n3. Всё остальное — не «Байкал». Жми СБРОС и не слушай.\n4. Свет не гасить. Никогда.\n5. Дверь — на засов. Всегда. Вышел, вернулся — на засов.\n\nПропустишь два сеанса — станцию сочтут потерянной и вездеход развернут.",
	2: "Генератор жрёт четверть бака в час. Канистры в сарае ГСМ — на восток, вдоль фонарей. Одной хватает часа на два.\n\nЗаглохнет — дёргай стартёр, пока не схватит. С первого раза не схватывает никогда.\n\nИ не стой в темноте. Оно заходит только в темноту. Проверено.",
	3: "Третья ночь.\n\nСегодня в 02:17 меня вызвал «Байкал». Несущая не горела. Я ответил по привычке.\n\nЧерез минуту в дверь постучали. Три раза.\n\nЗдесь на двести километров никого нет.",
	4: "Оно боится света. Не лампы — луча. Фонарь в лицо: замирает, дёргается, потом уходит.\n\nНо батареи садятся быстро, когда светишь на него. А оно возвращается с другой стороны.\n\nСлушай рацию на поясе. Шипит — значит, рядом. Шипит громко — уже не оборачивайся, беги.\n\nЗапасные батареи — на складе, вторая полка.",
	5: "Оно учится.\n\nСначала просто шипело в эфире. Потом повторяло позывные. Вчера сказало «приём» голосом диспетчера. Сегодня — моим.\n\nЯ не выходил в эфир уже сутки. Значит, оно слушало не эфир.\n\nОно слушало у окна.",
	6: "Если свет погас, а оно уже внутри — в шкаф, и не дыши.\n\nОно не видит. Оно слушает. Встаёт перед дверцей и слушает.\n\nЯ досчитал до девяти.\n\nКогда дадут свет — оно уйдёт само. Дверь за ним закрой.",
	7: "Я понял, зачем ему голос. Ему нужна смена.\n\nКаждый ответ — приглашение. Если вездеход придёт раньше шести — это не вездеход. Если сменщик постучит — это не сменщик.\n\nОно говорит, пока говорит станция. Красный рубильник под пломбой, справа от пульта. Я не решился: без связи за мной никто не приедет.\n\nА к мачте я всё-таки схожу. Оно зовёт оттуда голосом Нины.\n\n— А. Гринёв, 13.01",
}

var main: Node
var world: Node3D
var player: CharacterBody3D
var monster: Node3D
var hud: CanvasLayer
var running: bool = false
var admin: bool = false

var hour: float = 0.0
var fuel: float = 44.0
var stalled: bool = false
var suppress_t: float = 0.0
var antenna_ok: bool = true
var transmitter: bool = true
var strikes: int = 0
var missed: int = 0
var answered: int = 0
var notes_read: Dictionary = {}
var cans_used: int = 0
var bats_taken: int = 0
var start_tries: int = 0

var rcall: Dictionary = {}
var real_due: float = 0.0
var events: Array = []
var flicker_t: float = 0.0
var _flick_k: float = 1.0
var _flick_q: float = 0.0
var fear: float = 0.0
var fear_add: float = 0.0
var glitch: float = 0.0
var fade: float = 1.0
var fade_to: float = 0.0
var dark_t: float = 0.0
var outside_t: float = 0.0
var phone_ring: float = 0.0
var dawn: bool = false
var dawn_k: float = 0.0
var next_cp: int = 1
var time_frozen: bool = false
var time_scale: float = 1.0
var fullbright: bool = false
var auto_events: bool = true
var gen_snd: AudioStreamPlayer3D
var truck_snd: AudioStreamPlayer3D
var astar := AStar3D.new()
var nav_pts: Array = []
var _ui_q: float = 0.0
var boot: Dictionary = {}


func _ready() -> void:
	world = W.new()
	add_child(world)
	world.build(self)
	player = load("res://src/player.gd").new()
	player.g = self
	add_child(player)
	player.global_position = Vector3(-6.3, 0.05, -3.0)
	player.rotation.y = PI / 2
	player.sens = main.sens
	monster = M.new()
	monster.g = self
	monster.p = player
	add_child(monster)
	hud = load("res://src/hud.gd").new()
	hud.g = self
	add_child(hud)
	gen_snd = AudioStreamPlayer3D.new()
	gen_snd.stream = Snd.streams.get("loop_gen")
	gen_snd.max_distance = 26.0
	gen_snd.unit_size = 4.0
	gen_snd.volume_db = -4.0
	add_child(gen_snd)
	gen_snd.global_position = world.gen_pos
	_schedule()
	_apply_boot()
	if admin:
		var a: CanvasLayer = load("res://src/admin.gd").new()
		a.g = self
		add_child(a)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_build_nav()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	running = true
	if boot.is_empty():
		hud.say("14 января 1987 г.  Радиорелейная станция «Узел-9».\nДо жилья 212 км. Вездеход вернётся в 06:00.", 7.0)
		hud.sub("Прочти памятку на столе.  [E] — действие,  [F] — фонарь,  [Tab] — задачи", 9.0)


func _apply_boot() -> void:
	if boot.is_empty():
		return
	hour = boot.hour
	fuel = boot.fuel
	antenna_ok = boot.antenna_ok
	transmitter = boot.transmitter
	strikes = boot.strikes
	missed = boot.missed
	answered = boot.answered
	for n in boot.notes:
		notes_read[int(n)] = true
	player.battery = boot.battery
	player.spare = boot.spare
	cans_used = boot.cans_used
	bats_taken = boot.bats_taken
	for i in mini(cans_used, world.canisters.size()):
		world.canisters[i].queue_free()
	for i in mini(bats_taken, world.batteries.size()):
		world.batteries[i].queue_free()
	next_cp = int(hour) + 1
	world.front_door.toggle_bolt()
	for e in events:
		if e.t < hour + 0.004:
			e.done = true
	if not transmitter:
		world.switch_lever.position.y = 1.28


func snapshot() -> Dictionary:
	return {"hour": floorf(hour), "fuel": maxf(fuel, 20.0), "antenna_ok": antenna_ok, "transmitter": transmitter, "strikes": strikes, "missed": missed, "answered": answered, "notes": notes_read.keys(), "battery": maxf(player.battery, 40.0), "spare": player.spare, "cans_used": cans_used, "bats_taken": bats_taken}


# ------------------------------------------------------------------ queries
func lit() -> bool:
	return not stalled and fuel > 0.0 and suppress_t <= 0.0


func aggression() -> float:
	return floorf(hour) + strikes * 1.0 + (1.0 if not lit() else 0.0)


func clock() -> String:
	var m: int = int(clampf(hour, 0, 6) * 60.0)
	return "%02d:%02d" % [m / 60, m % 60]


func los(a: Vector3, b: Vector3, doors: bool = false) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1 | (4 if doors else 0))
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func objective() -> String:
	var o: Array = []
	if dawn:
		return "• Иди к воротам. Вездеход ждёт."
	if not rcall.is_empty():
		o.append("• Вызов на пульте: ОТВЕТ или СБРОС")
	if stalled and fuel <= 0.0:
		o.append("• Бак пуст: принеси канистру из сарая ГСМ")
	elif stalled:
		o.append("• Генератор заглох: дёрни стартёр")
	elif fuel < 25.0:
		o.append("• Мало топлива (%d%%): канистры в сарае ГСМ" % int(fuel))
	if not antenna_ok:
		o.append("• Обрыв антенны: рубильник в щите у мачты")
	if suppress_t > 0.0:
		o.append("• Оно внутри. Прячься.")
	if not notes_read.has(1):
		o.append("• Прочти памятку на пульте")
	if o.is_empty():
		o.append("• Жди сеанса связи в %02d:00" % (int(hour) + 1) if hour < 5.0 else "• Продержись до 06:00")
	return "\n".join(o)


# ------------------------------------------------------------------ navigation
func _build_nav() -> void:
	nav_pts = M.ROOMS.duplicate()
	for x in [-4.0, 0.5, 5.5]:
		nav_pts.append(Vector3(x, 0, -0.55))
		nav_pts.append(Vector3(x, 0, -1.6))
	for x in [-5.0, 1.0, 6.0]:
		nav_pts.append(Vector3(x, 0, 0.55))
		nav_pts.append(Vector3(x, 0, 1.6))
	for x in [-7.0, -2.0, 0.75, 5.75, 7.3]:
		nav_pts.append(Vector3(x, 0, 0))
	nav_pts.append_array([Vector3(9, 0, 0), Vector3(10.6, 0, 0), Vector3(11, 0, 7.5), Vector3(11, 0, -7.5), Vector3(-11, 0, 7.5), Vector3(-11, 0, -7.5),
		Vector3(20, 0, 6), Vector3(34.6, 0, 14), Vector3(37, 0, 14), Vector3(-7, 0, -36), Vector3(0, 0, -20), Vector3(14, 0, -20), Vector3(-20, 0, -20),
		Vector3(-20, 0, 10), Vector3(25, 0, -15), Vector3(25, 0, 22), Vector3(42, 0, 0), Vector3(0, 0, 16)])
	for i in nav_pts.size():
		astar.add_point(i, nav_pts[i])
	for i in nav_pts.size():
		for j in range(i + 1, nav_pts.size()):
			if nav_pts[i].distance_to(nav_pts[j]) < 32.0 and nav_clear(nav_pts[i], nav_pts[j]):
				astar.connect_points(i, j)


func nav_clear(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	d.y = 0
	if d.length() < 0.05:
		return true
	var side: Vector3 = d.normalized().cross(Vector3.UP) * 0.27
	var up := Vector3(0, 0.5, 0)
	for o in [Vector3.ZERO, side, -side]:
		if not los(Vector3(a.x, 0, a.z) + up + o, Vector3(b.x, 0, b.z) + up + o):
			return false
	return true


func _nearest(p: Vector3) -> int:
	var best: int = -1
	var bd: float = 1e9
	var fall: int = 0
	var fd: float = 1e9
	for i in nav_pts.size():
		var d: float = nav_pts[i].distance_to(p)
		if d < fd:
			fd = d
			fall = i
		if d < bd and d < 34.0 and nav_clear(p, nav_pts[i]):
			bd = d
			best = i
	return best if best >= 0 else fall


func nav_path(a: Vector3, b: Vector3) -> Array:
	a.y = 0
	b.y = 0
	if nav_clear(a, b):
		return [b]
	var out: Array = []
	for id in astar.get_id_path(_nearest(a), _nearest(b)):
		out.append(nav_pts[id])
	out.append(b)
	# smoothing: skip leading waypoints when a later one is directly reachable
	while out.size() > 1 and (nav_clear(a, out[1]) or a.distance_to(out[0]) < 0.3):
		out.pop_front()
	return out


# ------------------------------------------------------------------ director
func _ev(t: float, fn: Callable) -> void:
	events.append({"t": t, "fn": fn, "done": false})


func _schedule() -> void:
	_ev(0.13, func() -> void: start_call(true, "v_r_test", 1))
	for h in range(1, 6):
		_ev(float(h), func() -> void: real_due = hour + 0.32)
	_ev(0.62, func() -> void: start_call(false, "v_f_1", 0))
	_ev(1.45, func() -> void: start_call(false, "v_f_2", 0))
	_ev(2.25, func() -> void: start_call(false, "v_f_3", 0))
	_ev(2.72, func() -> void: start_call(false, "v_f_5", 0))
	_ev(3.42, func() -> void: start_call(false, "v_f_4", 0))
	_ev(3.82, func() -> void: start_call(false, "v_f_7", 2))
	_ev(4.36, func() -> void: start_call(false, "v_f_6", 0))
	_ev(4.74, func() -> void: start_call(false, "v_f_name", 2))
	_ev(4.955, func() -> void: start_call(false, "v_f_7", 2, 5.0))
	_ev(5.33, func() -> void: start_call(false, "v_f_2", 2))
	_ev(5.62, func() -> void: start_call(false, "v_f_5", 0))
	_ev(1.62, ev_antenna)
	_ev(3.56, ev_antenna)
	_ev(4.58, ev_antenna)
	_ev(3.1, ev_stall)
	_ev(0.42, func() -> void: ev_sound("roofsteps", Vector3(-3, 3.2, -3)))
	_ev(0.82, func() -> void: ev_window(0))
	_ev(1.22, ev_phone)
	_ev(1.8, func() -> void: ev_sound("glass_tap", Vector3(1, 1.5, 5)))
	_ev(2.06, ev_visit)
	_ev(2.5, ev_appar)
	_ev(2.86, func() -> void: ev_window(-1))
	_ev(3.3, func() -> void: ev_sound("drag", Vector3(5.5, 3.1, -3)))
	_ev(3.66, ev_visit)
	_ev(4.12, func() -> void: ev_window(-1))
	_ev(4.25, ev_bunk_door)
	_ev(4.5, ev_visit)
	_ev(4.86, ev_appar)
	_ev(5.15, ev_phone)
	_ev(5.25, func() -> void: ev_window(-1))
	_ev(5.47, ev_visit)
	_ev(5.8, ev_appar)


func _retry(fn: Callable, delay_h: float = 0.05) -> void:
	_ev(hour + delay_h, fn)


func ev_antenna() -> void:
	if not antenna_ok:
		return
	antenna_ok = false
	Snd.play3d("flicker", world.console_pos, 0.0, 20.0)
	if not player.outside():
		hud.say("На пульте: АНТЕННА — ОБРЫВ", 4.0)


func ev_stall() -> void:
	if stalled or dawn:
		return
	stalled = true
	start_tries = 0
	Snd.play3d("gen_die", world.gen_pos, 6.0, 45.0)


func ev_sound(snd: String, pos: Vector3) -> void:
	Snd.play3d(snd, pos, 4.0, 30.0)
	fear_kick(0.3)


func ev_window(idx: int) -> void:
	if player.outside() or not lit() or monster.st != M.S.GONE:
		_retry(func() -> void: ev_window(idx))
		return
	if idx < 0:
		# the window closest to where the player looks
		var best: float = -2.0
		for i in WINDOWS.size():
			var d: float = player.look_dir().dot((WINDOWS[i] - player.global_position).normalized())
			if d > best and los(player.eye(), WINDOWS[i] + Vector3(0, 1.6, 0)):
				best = d
				idx = i
		if idx < 0:
			idx = randi() % WINDOWS.size()
	monster.watch(WINDOWS[idx], 30.0)
	Snd.play3d("glass_tap", WINDOWS[idx] + Vector3(0, 1.5, 0), 0.0, 25.0)


func ev_phone() -> void:
	phone_ring = 14.0


func ev_visit() -> void:
	if player.outside() or not lit() or monster.st != M.S.GONE or dawn:
		_retry(ev_visit, 0.08)
		return
	monster.begin_visit()


func ev_appar() -> void:
	if player.outside() or not lit() or monster.st != M.S.GONE:
		_retry(ev_appar)
		return
	# stand at the far end of the corridor from the player
	var x: float = -7.0 if player.global_position.x > 0 else 7.0
	monster.appear(Vector3(x, 0, 0), 1.1)
	flicker(1.3)
	Snd.play("swell", -6.0)
	fear_kick(0.8)


func ev_bunk_door() -> void:
	var d: Door = world.doors[1]
	d.set_open(not d.open, true)
	fear_kick(0.3)


# ------------------------------------------------------------------ radio
func start_call(real: bool, v: String, carrier: int, dur: float = 0.0) -> void:
	if not rcall.is_empty() or dawn:
		return
	if dur <= 0.0:
		dur = 27.0 if real else 19.0
	rcall = {"real": real, "v": v, "carrier": carrier, "t": dur}
	Snd.play3d("buzz", world.console_pos, 2.0, 30.0)
	get_tree().create_timer(1.3).timeout.connect(func() -> void:
		if not rcall.is_empty():
			voice(v, world.console_pos))


func voice(v: String, pos: Vector3, _sub: String = "", dist: float = 18.0) -> void:
	var pl: AudioStreamPlayer3D = Snd.play3d(v, pos, 3.0, dist)
	if pl != null and player.global_position.distance_to(pos) < dist and SUBS.has(v):
		hud.sub("«%s»" % SUBS[v], pl.stream.get_length() + 0.5)


func answer_call() -> void:
	Snd.play3d("click", world.console_pos, 0.0, 10.0)
	if rcall.is_empty():
		hud.say("В эфире тишина.", 2.0)
		return
	if rcall.real:
		answered += 1
		voice("v_r_ok", world.console_pos)
	else:
		strikes += 1
		voice("v_f_ans", world.console_pos)
		flicker(1.5)
		fear_kick(1.0)
		glitch = 0.7
		_ev(hour + 0.06, ev_visit)
	rcall = {}


func reject_call() -> void:
	Snd.play3d("click", world.console_pos, 0.0, 10.0)
	if rcall.is_empty():
		hud.say("В эфире тишина.", 2.0)
		return
	if rcall.real:
		missed += 1
		hud.say("Вы сбросили «Байкал». Сеанс пропущен (%d из 2 допустимых)." % missed, 5.0)
	else:
		hud.say("Сброс. Эфир чист.", 2.5)
	rcall = {}


func _radio(dt: float) -> void:
	if real_due > 0.0 and rcall.is_empty():
		if antenna_ok and transmitter and lit():
			start_call(true, "v_r_hour", 1)
			real_due = 0.0
		elif hour > real_due:
			real_due = 0.0
			missed += 1
			hud.say("Плановый сеанс не состоялся. Пропущено: %d из 2 допустимых." % missed, 5.0)
	if not rcall.is_empty():
		rcall.t -= dt
		if rcall.t <= 0.0:
			if rcall.real:
				missed += 1
				voice("v_r_lost", world.console_pos)
				hud.say("Сеанс пропущен (%d из 2 допустимых)." % missed, 5.0)
			rcall = {}
	if phone_ring > 0.0:
		var before: float = phone_ring
		phone_ring -= dt
		if int(before / 3.4) != int(phone_ring / 3.4) or before == 14.0:
			Snd.play3d("phone", world.phone_pos, 2.0, 26.0)


func phone_prompt() -> String:
	return "[E] Снять трубку" if phone_ring > 0.0 else "Телефон. Линии нет с ноября."


func phone_use() -> void:
	if phone_ring <= 0.0:
		return
	phone_ring = 0.0
	voice("v_f_5", world.phone_pos)
	fear_kick(0.7)
	glitch = 0.4


# ------------------------------------------------------------------ station actions
func hold_allowed(a: Act) -> bool:
	return a.prompt().begins_with("Удерживай")


func gen_prompt() -> String:
	if player.carrying:
		return "Удерживай [E] — залить канистру"
	if stalled and fuel > 0.0:
		return "Удерживай [E] — дёрнуть стартёр"
	if stalled:
		return "Бак пуст. Нужна канистра из сарая ГСМ."
	return "Генератор. Топливо: %d%%" % int(fuel)


func gen_use() -> void:
	if player.carrying:
		player.carrying = false
		fuel = minf(100.0, fuel + 55.0)
		Snd.play3d("pour", world.gen_pos, 2.0, 20.0)
		hud.say("Залито. Топливо: %d%%" % int(fuel), 3.0)
	elif stalled and fuel > 0.0:
		start_tries += 1
		if start_tries >= 2 and (randf() < 0.6 or start_tries >= 4):
			stalled = false
			Snd.play3d("gen_start", world.gen_pos, 4.0, 40.0)
			flicker(1.5)
		else:
			Snd.play3d("gen_pull", world.gen_pos, 4.0, 35.0)
			hud.say("Не схватил. Ещё раз.", 2.0)


func mast_prompt() -> String:
	return "Щит антенны: норма" if antenna_ok else "Удерживай [E] — включить рубильник антенны"


func mast_use() -> void:
	antenna_ok = true
	Snd.play3d("breaker", W.MAST_POS, 4.0, 30.0)
	hud.say("Антенна в норме. Возвращайся.", 3.0)


func canister_prompt() -> String:
	return "Руки заняты" if player.carrying else "[E] Взять канистру"


func take_canister(c: Node3D) -> void:
	if player.carrying:
		return
	player.carrying = true
	cans_used += 1
	c.queue_free()
	Snd.play("pickup")
	hud.say("Канистра. Неси к генератору.", 3.0)


func take_battery(b: Node3D) -> void:
	player.spare += 1
	bats_taken += 1
	b.queue_free()
	Snd.play("pickup")
	hud.say("Батарея для фонаря. [R] — заменить.", 3.0)


func read_note(id: int) -> void:
	notes_read[id] = true
	Snd.play("paper")
	hud.show_note(NOTES[id])


func switch_prompt() -> String:
	if not transmitter:
		return "Передатчик отключён."
	return "Удерживай [E] — сорвать пломбу и отключить передатчик"


func kill_transmitter() -> void:
	if not transmitter:
		return
	transmitter = false
	world.switch_lever.position.y = 1.28
	Snd.play3d("breaker", world.console_pos, 4.0, 30.0)
	rcall = {}
	if notes_read.size() >= 7:
		running = false
		monster.vanish()
		Snd.loop("loop_static", 0.0)
		Snd.loop("loop_drone", 0.0)
		Snd.loop("loop_tension", 0.0)
		fade_to = 1.0
		get_tree().create_timer(3.5).timeout.connect(func() -> void: main.show_ending("silence", stats()))
	else:
		hud.say("Передатчик отключён. «Байкал» вас больше не услышит.", 5.0)


# ------------------------------------------------------------------ fear / light
func flicker(d: float) -> void:
	flicker_t = maxf(flicker_t, d)
	if lit():
		Snd.play("flicker", -8.0)


func fear_kick(v: float) -> void:
	fear_add = maxf(fear_add, v)


func suppress(d: float) -> void:
	suppress_t = d
	Snd.play("flicker", -2.0)
	Snd.play("thud", -2.0)


func on_player_hid() -> void:
	pass


func on_hunt_started() -> void:
	fear_kick(1.0)


func _lights(dt: float) -> void:
	var on: bool = lit()
	flicker_t = maxf(0.0, flicker_t - dt)
	_flick_q -= dt
	if _flick_q <= 0.0:
		_flick_q = 0.05
		_flick_k = 1.0
		if flicker_t > 0.0 or (fuel < 9.0 and randf() < 0.12) or (monster.st == M.S.VISIT and randf() < 0.06):
			_flick_k = [0.0, 0.1, 0.5, 1.0].pick_random()
	var k: float = _flick_k if on else 0.0
	for l in world.lights:
		l.light_energy = l.get_meta("e") * k
	world.bulb_mat.emission_energy_multiplier = 3.0 * k
	world.red_lamp.light_energy = 0.0 if on else 0.5 + 0.5 * signf(sin(Time.get_ticks_msec() * 0.004))
	var bk: float = 1.0 if fmod(Time.get_ticks_msec() * 0.001, 2.0) < 1.0 else 0.08
	world.beacon.light_energy = 6.0 * bk
	# console
	var carrier_on: bool = false
	var call_on: bool = false
	if not rcall.is_empty():
		call_on = fmod(Time.get_ticks_msec() * 0.001, 0.6) < 0.3
		carrier_on = rcall.carrier == 1 or (rcall.carrier == 2 and randf() < 0.7)
	world.lamp_carrier.material_override = B.col(Color(0.1, 1.0, 0.2), 0.3, 0.0, 4.0) if carrier_on else B.col(Color(0.05, 0.12, 0.05))
	world.lamp_call.material_override = B.col(Color(1.0, 0.1, 0.05), 0.3, 0.0, 4.0) if call_on else B.col(Color(0.12, 0.04, 0.04))


func _atmosphere(dt: float) -> void:
	var out: bool = player.outside()
	var e: Environment = world.env
	var fog_t: float = 0.05 if out else 0.014
	var amb_t: float = 0.06 if out else 0.012
	if dawn:
		dawn_k = minf(1.0, dawn_k + dt / 40.0)
		fog_t = lerpf(fog_t, 0.012, dawn_k)
		amb_t = lerpf(amb_t, 0.9, dawn_k)
		e.fog_light_color = Color(0.03, 0.037, 0.05).lerp(Color(0.32, 0.3, 0.33), dawn_k)
		e.background_color = Color(0.012, 0.015, 0.022).lerp(Color(0.3, 0.28, 0.3), dawn_k)
	if fullbright:
		amb_t = 2.5
		fog_t = 0.002
	e.fog_density = lerpf(e.fog_density, fog_t, dt * 1.5)
	e.ambient_light_energy = lerpf(e.ambient_light_energy, amb_t, dt * 2.0)
	world.snow.global_position = player.global_position + Vector3(-8, 4, -2)
	# sound beds
	var o: float = 1.0 if out else 0.0
	Snd.loop("loop_wind", lerpf(0.0, 0.85, o) if out else (0.25 if world.front_door.open else 0.0))
	Snd.loop("loop_wind_in", 0.0 if out else 0.5)
	Snd.loop("loop_drone", 0.12 + 0.05 * hour + 0.25 * fear)
	var md: float = monster.global_position.distance_to(player.global_position) if monster.active() else 999.0
	var stat: float = clampf(1.0 - md / 24.0, 0.0, 1.0)
	Snd.loop("loop_static", stat * stat * 0.8 + (0.12 if not rcall.is_empty() and not out else 0.0), 1.0)
	var hunting: bool = monster.st in [M.S.HUNT, M.S.SEARCH, M.S.CHECK, M.S.STUN, M.S.ASSAULT]
	Snd.loop("loop_tension", (0.5 if hunting else 0.0) + (0.4 * stat if monster.st == M.S.STALK else 0.0))
	Snd.loop("loop_heart", clampf(1.2 - md / 9.0, 0.0, 1.0) if (hunting or monster.st == M.S.STALK) else 0.0, 1.0 + 0.4 * stat)
	var want_gen: bool = not stalled and fuel > 0.0
	if gen_snd.playing != want_gen:
		if want_gen:
			gen_snd.play()
		else:
			gen_snd.stop()
	# post fx
	var f: float = clampf(1.0 - md / 16.0, 0.0, 1.0) * 0.8 + (0.25 if hunting else 0.0)
	fear_add = maxf(0.0, fear_add - dt * 0.25)
	fear = lerpf(fear, clampf(f + fear_add, 0.0, 1.0), dt * 3.0)
	glitch = maxf(maxf(0.0, glitch - dt * 0.6), clampf(1.0 - md / 3.5, 0.0, 1.0) * 0.7)
	fade = move_toward(fade, fade_to, dt * 0.6)
	hud.post(fear, glitch, clampf((player.cold - 35.0) / 65.0, 0.0, 1.0), fade, player.hidden >= 0)


# ------------------------------------------------------------------ main loop
func _process(dt: float) -> void:
	_lights(dt)
	_atmosphere(dt)
	_ui_q -= dt
	if _ui_q <= 0.0:
		_ui_q = 0.25
		world.status_label.text = "ВРЕМЯ    %s\nТОПЛИВО  %d%%\nАНТЕННА  %s\nСЕАНСЫ   %d   ПРОПУСК %d" % [clock(), int(fuel), "НОРМА" if antenna_ok else "ОБРЫВ", answered, missed] if lit() else ""
		world.gen_label.text = "%d%%" % int(fuel)
	if not running:
		return
	if not time_frozen:
		if not dawn:
			hour += dt / HOUR_LEN * time_scale
		if not stalled:
			fuel = maxf(0.0, fuel - dt / HOUR_LEN * time_scale * 25.0)
			if fuel <= 0.0:
				stalled = true
				start_tries = 0
				Snd.play3d("gen_die", world.gen_pos, 6.0, 45.0)
	suppress_t = maxf(0.0, suppress_t - dt)
	_radio(dt)
	if auto_events:
		for e in events:
			if not e.done and hour >= e.t:
				e.done = true
				e.fn.call()
	_monster_rules(dt)
	if hour >= float(next_cp) and next_cp <= 5:
		if not monster.active() and lit():
			main.save_checkpoint(snapshot())
			hud.say("%02d:00.  Прогресс сохранён." % next_cp, 3.0)
		next_cp += 1
	if hour >= 6.0 and not dawn:
		_end_night()
	if dawn and player.global_position.distance_to(W.GATE_POS) < 7.0:
		running = false
		fade_to = 1.0
		get_tree().create_timer(2.5).timeout.connect(func() -> void: main.show_ending("dawn", stats()))


func _monster_rules(dt: float) -> void:
	if dawn:
		return
	var S: Dictionary = M.S
	var on: bool = lit()
	dark_t = 0.0 if on else dark_t + dt
	outside_t = outside_t + dt if player.outside() else 0.0
	if on and monster.st in [S.HUNT, S.STUN, S.SEARCH, S.CHECK]:
		monster.flee()
		hud.say("Свет. Оно уходит. Закрой за ним дверь.", 4.0)
	if not auto_events:
		return
	if not on and dark_t > maxf(6.0, 13.0 - aggression()) and monster.st in [S.GONE, S.WATCH] and not player.outside():
		monster.begin_assault()
	if player.outside() and monster.st == S.GONE and (hour >= 1.0 or strikes > 0 or not on):
		if outside_t > maxf(4.0, 13.0 - 2.0 * aggression()):
			monster.begin_stalk()


func _end_night() -> void:
	hour = 6.0
	if not transmitter or missed >= 2:
		_finish("forgotten")
	elif strikes >= 2:
		_finish("replaced")
	else:
		start_dawn()


func start_dawn() -> void:
	dawn = true
	rcall = {}
	monster.vanish()
	voice("v_r_end", world.console_pos, "", 60.0)
	hud.sub("«%s»" % SUBS["v_r_end"], 6.0)
	world.truck.visible = true
	Snd.play3d("horn", W.GATE_POS, 8.0, 120.0)
	truck_snd = AudioStreamPlayer3D.new()
	truck_snd.stream = Snd.streams.get("loop_truck")
	truck_snd.max_distance = 60.0
	truck_snd.unit_size = 8.0
	add_child(truck_snd)
	truck_snd.global_position = W.GATE_POS
	truck_snd.play()
	get_tree().create_timer(8.0).timeout.connect(func() -> void:
		if running:
			monster.place(Vector3(27, 0, -17), M.S.SHOW))


func _finish(id: String) -> void:
	running = false
	fade_to = 1.0
	if id == "replaced":
		Snd.play("knock", 0.0)
		get_tree().create_timer(2.0).timeout.connect(func() -> void: Snd.play("v_f_your", 0.0))
		get_tree().create_timer(8.5).timeout.connect(func() -> void: main.show_ending(id, stats()))
	else:
		get_tree().create_timer(3.5).timeout.connect(func() -> void: main.show_ending(id, stats()))


func stats() -> Dictionary:
	return {"answered": answered, "missed": missed, "strikes": strikes, "notes": notes_read.size(), "clock": clock()}


func kill(cause: String) -> void:
	if player.god or not player.alive or not running:
		return
	player.alive = false
	running = false
	if cause == "monster":
		var fwd: Vector3 = player.look_dir()
		fwd.y = 0
		fwd = fwd.normalized()
		if player.hidden >= 0:
			fwd = world.lockers[player.hidden].face
		monster.visible = true
		monster.st = M.S.SHOW
		monster.global_position = Vector3(player.global_position.x, 0, player.global_position.z) + fwd * 0.85
		monster.global_position.y = player.global_position.y - 0.5
		monster.rotation.y = atan2(fwd.x, fwd.z)
		monster.rig.rotation.x = -0.1
		monster.rig.position.y = 0.0
		monster.arm_l.rotation = Vector3(1.9, 0, 0.25)
		monster.arm_r.rotation = Vector3(1.9, 0, -0.25)
		monster.esp = true
		monster.face_mat.set_shader_parameter("power", 2.2)
		monster.head.look_at(player.eye())
		player.cam.look_at(monster.head.global_position)
		hud.say_t = 0.0
		hud.sub_t = 0.0
		player.torch.light_energy = 0.0
		var jl := B.omni(self, player.eye() + Vector3(0, 0.3, 0), Color(0.8, 0.9, 1.0), 1.2, 3.0)
		jl.name = "JumpLight"
		Snd.stop_all()
		Snd.play("scream", 3.0)
		Snd.play("stinger", 2.0)
		glitch = 1.0
		player.shake = 1.0
		get_tree().create_timer(1.25).timeout.connect(func() -> void:
			fade = 1.0
			fade_to = 1.0
			main.show_death(cause))
	else:
		Snd.play("freeze")
		fade_to = 1.0
		get_tree().create_timer(3.0).timeout.connect(func() -> void: main.show_death(cause))
