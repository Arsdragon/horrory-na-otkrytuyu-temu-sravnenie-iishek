class_name Nights
extends RefCounted
## Сценарии пяти ночей. Каждый этап — сопрограмма s_<id>; setup(id) ставит мир в состояние,
## с которого этап начинается (для контрольных точек и админ-режима).

const FY := 0.03
const DOOR_OUT := Vector3(5.7, 0, 1.6)

var d: Director
var p: Player:
	get:
		return d.p
var e: Entity:
	get:
		return d.e
var W: World:
	get:
		return d.world


func _init(dir: Director) -> void:
	d = dir


func run(id: String) -> void:
	if has_method("s_" + id):
		call("s_" + id)
	else:
		push_warning("нет этапа " + id)


# ------------------------------------------------------------------ состояние для входа в этап

func _fill(n: int) -> void:
	G.readings[n] = Director.READ[n].duplicate()


func _take_jerry(full: bool) -> void:
	p.carrying = "jerry"
	d.jerry_full = full
	(W.things["jerry"] as Node3D).visible = false
	(W.things["jerry_it"] as Interactable).enabled = false


func setup(id: String) -> void:
	match id:
		"n1_back":
			_fill(1)
			W.goto("meteo")
			p.yaw = PI
			p.set_lamp(true, true)
		"n1_radio":
			_fill(1)
			W.goto("main")
		"n2_depot":
			W.goto("shed_in")
			_take_jerry(false)
			p.set_lamp(true, true)
		"n2_gen":
			W.goto("depot_in")
			_take_jerry(true)
			p.set_lamp(true, true)
		"n2_site":
			W.set_power(true, true)
			W.stove_t = 0.0
			W.goto("shed_in")
			p.set_lamp(true, true)
		"n2_pass":
			W.set_power(true, true)
			_fill(2)
			W.goto("meteo")
			p.yaw = PI
			p.set_lamp(true, true)
		"n2_radio":
			W.set_power(true, true)
			_fill(2)
			W.goto("main")
		"n3_mast":
			W.goto("hub")
			d.has_cable = true
			(W.things["cable"] as Node3D).visible = false
			(W.things["cable_it"] as Interactable).enabled = false
			p.set_lamp(true, true)
		"n3_repaired":
			W.goto("hut_in")
			(W.things["feeder"] as Interactable).enabled = false
			p.set_lamp(true, true)
		"n3_radio":
			W.goto("main")
		"n4_balok":
			W.goto("balok")
			p.set_lamp(true, true)
		"n4_cellar":
			G.set_flag("nz_taken")
			G.set_flag("flares_known")
			p.flares = 4
			W.goto("cellar")
			p.set_lamp(true, true)
		"n4_flee":
			G.set_flag("nz_taken")
			G.set_flag("flares_known")
			p.flares = 4
			d.has_gun = true
			W.goto("balok_in")
			p.set_lamp(true, true)
		"n4_home":
			G.set_flag("flares_known")
			p.flares = 2
			d.has_gun = true
			W.goto("vest")
		"n4_siege":
			G.set_flag("flares_known")
			p.flares = 2
			d.has_gun = true
			W.goto("main")
			(W.doors["house"] as Door).set_barred(true, true)
		"n5_pad":
			W.goto("pad")
			p.set_lamp(true, true)
		"n5_final":
			W.goto("pad_in")
			for b in W.things["barrels"]:
				(b as Dictionary).lit = true
				((b as Dictionary).it as Interactable).enabled = false
			p.set_lamp(true, true)


# ------------------------------------------------------------------ общие куски

func _lie_down() -> void:
	p.set_mode("bed")
	p.set_lamp(false, true)
	p.pose(Vector3(4.4, 0.8, -0.55), 0.0, 22.0, Vector2(1.2, 0.6))


func _stand_up() -> void:
	p.set_mode("walk")
	p.teleport(Vector3(3.55, FY, -1.15), -90.0)
	Snd.play("bed_creak", -8.0)


## Начало ночи: чернота, карточка, герой лежит на койке, встаёт по E.
func _wake(n: int, intro := false, lying := true) -> void:
	d._baseline(n)
	G.busy = true
	if lying:
		_lie_down()
	G.cards.black(1.0)
	G.main.set_fade(Color(0, 0, 0, 0))
	if not d.fast:
		if intro:
			await G.cards.lines(T.INTRO, 1.0, 28, 1.5)
		var t: Array = T.NIGHTS[n]
		await G.cards.title(String(t[0]), String(t[1]), String(t[2]))
	G.busy = false
	await G.cards.reveal(0.2 if d.fast else 2.4)
	if lying:
		d.hud.hint("E — встать", 60.0)
		await d.until(func() -> bool: return Input.is_action_pressed("use") or Input.is_action_pressed("move_f") or d.acted.has("getup"))
		d.hud.hint("", 0.0)
		_stand_up()


## Лечь спать: night_events идут, пока лежишь; потом затемнение и следующий этап.
func _sleep_into(next_id: String, night_events: Callable) -> void:
	_lie_down()
	Snd.play("bed_creak", -6.0)
	d.allow.erase("bed")
	await d.sleep(3.0)
	await night_events.call()
	G.main.fade_to(Color(0, 0, 0, 1), 2.2)
	await d.sleep(2.4)
	G.cards.black(1.0)
	G.main.set_fade(Color(0, 0, 0, 0))
	d.go(next_id)


func _three_readings() -> void:
	await d.until(func() -> bool: return (G.readings.get(G.night, {}) as Dictionary).size() >= 3)


## Сеанс связи: герой стучит ключом, потом идёт steps (сопрограмма с ответами).
func _radio_session(tx_snd: String, steps: Callable) -> void:
	var r := G.radio_ui
	r.can_send = true
	d.acted.erase("tx")
	await d.until(func() -> bool: return d.acted.has("tx"))
	r.busy = true
	r.can_send = false
	var dur := Snd.length(tx_snd)
	Snd.play(tx_snd, -4.0)
	await d.sleep(dur + 0.8)
	await steps.call()
	r.busy = false
	await d.sleep(0.6)
	if r.is_open:
		r.close()


func _morse_in(snd: String, text: String) -> void:
	var dur := Snd.length(snd)
	Snd.play(snd, -2.0)
	await G.radio_ui.type_line(text, maxf(dur, 2.0))
	await d.sleep(1.6)


func _door_knock(snd: String, vol := 4.0) -> void:
	Snd.play_at(snd, Vector3(5.25, 1.3, 1.6), W, vol, 1.0, 45.0, 9.0)


# ================================================================== НОЧЬ 1

func s_n1_wake() -> void:
	await _wake(1, true)
	d.think("wake1")
	d.hint("move", 8.0)
	d.obj("n1_read")
	await d.sleep(9.0)
	d.hint("notebook", 6.0)
	await d.until(func() -> bool: return d.outdoors())
	if not p.lamp_on:
		d.hint("lamp", 8.0)
	await d.until(func() -> bool: return p.near_rope or p.gripping or d.dist2(p.global_position, Map.HUB) > 14.0)
	d.hint("grip", 12.0)
	# первый порыв — метрах в двадцати от дома
	await d.until(func() -> bool: return p.global_position.z < -16.0 or d.dist2(p.global_position, Map.HUB) > 26.0)
	d.w.force_gust(0.95, 5.5)
	d.hint("gust", 7.0)
	await d.until(func() -> bool: return (G.readings.get(1, {}) as Dictionary).size() >= 1)
	await d.sleep(2.0)
	d.ev("far_bang")
	await _three_readings()
	d.done("n1_read")
	d.go("n1_back")


func s_n1_back() -> void:
	d.obj("n1_home")
	await d.until(func() -> bool: return p.global_position.z > -34.0 or d.in_house())
	d.ev("echo_steps")
	await d.until(func() -> bool: return p.global_position.z > -13.0 or d.in_house())
	# чужие следы поперёк леера, уходят в темноту
	W.prints.trail(Vector3(15.0, 0, -9.5), Vector3(-2.0, 0, -6.0), 0, 0.84, 1.1)
	await d.until(func() -> bool: return d.in_house())
	d.done("n1_home")
	d.go("n1_radio")


func s_n1_radio() -> void:
	d.obj("n1_radio")
	await _radio_session("morse_tx_1", func() -> void:
		await d.say("dx_n1_a")
		await d.say("dx_n1_b")
		Snd.play("morse_tx_3", -6.0)
		await d.sleep(2.6)
		await d.say("dx_n1_c")
		await d.say("dx_n1_d"))
	d.done("n1_radio")
	d.obj("n1_stove")
	await d.until(func() -> bool: return d.acted.has("stoked"))
	d.done("n1_stove")
	d.obj("n1_sleep")
	d.allow["bed"] = true
	await d.wait_act("sleep")
	d.done("n1_sleep")
	await _sleep_into("n2_wake", func() -> void:
		await d.sleep(3.5)
		_door_knock("knock_1")
		await d.sleep(6.5)
		_door_knock("knock_1", 5.0)
		await d.sleep(4.0))


# ================================================================== НОЧЬ 2

func s_n2_wake() -> void:
	await _wake(2)
	d.think("gen_dead")
	d.obj("n2_gen")
	await d.sleep(6.0)
	if not p.lamp_on:
		d.hint("lamp", 6.0)
	await d.until(func() -> bool: return d.acted.has("jerry_taken") or d.acted.has("gen_tried"))
	d.done("n2_gen")
	d.obj("n2_fuel")
	await d.until(func() -> bool: return d.acted.has("jerry_taken"))
	d.go("n2_depot")


func s_n2_depot() -> void:
	d.obj("n2_fuel")
	await d.until(func() -> bool: return d.acted.has("pumped"))
	d.done("n2_fuel")
	# обернёшься — на леере, между тобой и домом, стоит человек
	var s := d.rope_s("C", 12.0)
	if s < 0.0:
		s = 54.0
	var pos := W.ropes.point_at("C", maxf(s - 10.5, 2.0))
	if not G.ai_off:
		e.seen_once = false
		e.watch_at(pos, 0.0)
		var t0 := d.clock
		await d.until(func() -> bool: return e.seen_once or d.clock - t0 > 14.0 or e.state == Entity.S.HIDDEN)
		if e.seen_once:
			Snd.play("sting_low", -2.0)
			d.think("figure")
			await d.sleep(2.6)
		if e.state != Entity.S.HIDDEN:
			d.w.force_gust(1.0, 4.5)
			await d.until(func() -> bool: return e.state == Entity.S.HIDDEN)
		await d.sleep(1.5)
		Snd.play("walkie_click", -2.0)
	d.go("n2_gen")


func s_n2_gen() -> void:
	d.obj("n2_refuel")
	# на полпути — огонь в стороне от леера. Дом в другой стороне
	await d.until(func() -> bool:
		var s := d.rope_s("C", 30.0)
		return (s >= 0.0 and s < 32.0) or d.zone_id() == "shed")
	if d.zone_id() != "shed" and not G.ai_off:
		var s2 := maxf(d.rope_s("C", 30.0), 8.0)
		d.make_lure(W.ropes.point_at("C", maxf(s2 - 9.0, 6.0)) + Vector3(2.0, 0, -18.0))
	await d.until(func() -> bool: return d.acted.has("gen_running"))
	d.clear_lure()
	d.done("n2_refuel")
	d.go("n2_site")


func s_n2_site() -> void:
	d.obj("n2_read")
	await _three_readings()
	d.done("n2_read")
	d.go("n2_pass")


func s_n2_pass() -> void:
	d.obj("n2_home")
	G.set_flag("rules_known")
	await d.until(func() -> bool:
		var s := d.rope_s("A", 8.0)
		return (s >= 0.0 and s < 41.0) or d.in_house())
	if not d.in_house() and not G.ai_off:
		# глаза впереди на леере. В луче стоит; порыв — пойдёт
		var s := maxf(d.rope_s("A", 8.0), 20.0)
		e.level = 2
		e.seen_once = false
		e.hunt_from(W.ropes.point_at("A", maxf(s - 17.0, 3.0)) + Vector3(0.9, 0, 0), 0.3)
		e.grace = 6.0
		await d.sleep(1.0)
		d.hint("hold_light", 5.0)
		await d.sleep(4.5)
		d.w.force_gust(1.0, 10.0)
		d.hint("hide", 10.0)
		await d.until(func() -> bool: return e.state == Entity.S.HIDDEN)
		await d.sleep(2.0)
		d.think("not_gromov")
	await d.until(func() -> bool: return d.in_house())
	d.done("n2_home")
	d.go("n2_radio")


func s_n2_radio() -> void:
	d.obj("n2_radio")
	await _radio_session("morse_tx_2", func() -> void:
		await d.say("dx_n2_a")
		await d.say("dx_n2_b")
		Snd.play("morse_tx_3", -6.0)
		await d.sleep(2.6)
		await d.say("dx_n2_c")
		await d.sleep(2.2)
		Snd.play("squelch", -4.0)
		await d.say("dx_n2_d")
		Snd.play("sting_low", -6.0)
		await d.sleep(1.5))
	d.done("n2_radio")
	d.obj("n2_sleep")
	d.allow["bed"] = true
	await d.wait_act("sleep")
	d.done("n2_sleep")
	await _sleep_into("n3_wake", func() -> void:
		# кто-то обходит дом
		await d.sleep(2.0)
		for i in 9:
			var a := PI * 0.25 + float(i) * 0.3
			Snd.play_at("ent_step", Vector3(cos(a) * 7.5, 0.2, -sin(a) * 5.5), W, 4.0, 0.95, 40.0, 7.0)
			await d.sleep(0.95)
		await d.sleep(1.5)
		Snd.play_at("scratch", Vector3(3.4, 1.4, -3.4), W, 5.0, 1.0, 30.0, 6.0)
		await d.sleep(4.5))


# ================================================================== НОЧЬ 3

func s_n3_wake() -> void:
	await _wake(3)
	# радио в рубке работает само: голос повторяет вчерашнее
	d.think("radio_self")
	d.obj("n3_radio0")
	var t_next := 0.0
	while d.zone_id() != "radio":
		if d.clock >= t_next:
			t_next = d.clock + 10.5
			Snd.play_at("dx_n3_a", Vector3(-4.58, 1.0, -1.82), W, 3.0, 1.0, 28.0, 5.0)
		await d.tick
	Snd.cut_oneshots()
	Snd.play("squelch", -2.0)
	d.done("n3_radio0")
	await d.sleep(2.5)
	d.hud.think("Диксон молчит. В эфире одни помехи.")
	await d.sleep(3.0)
	d.obj("n3_cable")
	d.allow["cable"] = true
	await d.until(func() -> bool: return d.acted.has("cable_taken"))
	d.done("n3_cable")
	d.go("n3_mast")


func s_n3_mast() -> void:
	d.obj("n3_mast")
	d.allow["cable"] = true
	# по дороге кто-то дёргает леер с дальнего конца
	await d.until(func() -> bool:
		var s := d.rope_s("D", 6.0)
		return s > 44.0 or d.zone_id() == "hut")
	if d.zone_id() != "hut":
		d.ev("rope_tug")
	await d.until(func() -> bool: return d.zone_id() == "hut")
	var it: Interactable = W.things["feeder"]
	var hut_door := Vector3(-78.0, 1.0, 13.5)
	# ремонт: спиной к двери. Снаружи подходят, стучат, обходят будку
	var stage_k := 0
	while not d.acted.has("repaired"):
		var pr := it.progress
		if stage_k == 0 and pr > 0.18:
			stage_k = 1
			for i in 4:
				Snd.play_at("ent_step", hut_door + Vector3(9.0 - i * 2.2, -0.8, 0.6), W, 2.0, 0.95, 40.0, 6.0)
				await d.sleep(0.9)
		elif stage_k == 1 and pr > 0.42:
			stage_k = 2
			Snd.play_at("knock_2", hut_door, W, 5.0, 1.0, 30.0, 7.0)
		elif stage_k == 2 and pr > 0.66:
			stage_k = 3
			Snd.play_at("scratch", Vector3(-80.8, 1.2, 13.0), W, 5.0, 1.0, 20.0, 5.0)
			p.lamp_flicker = 1.5
			Snd.play("lamp_flicker", -6.0)
		elif stage_k == 3 and pr > 0.88:
			stage_k = 4
			Snd.play_at("ent_croak", hut_door, W, 0.0, 0.9, 20.0, 4.0)
		await d.tick
	d.done("n3_mast")
	await d.sleep(1.0)
	# вокруг будки — босые следы. И леер перерезан
	W.prints.trail(Vector3(-76.8, 0, 13.0), Vector3(-77.4, 0, 16.6), 1, 0.95, 1.2)
	W.prints.trail(Vector3(-77.4, 0, 16.6), Vector3(-72.0, 0, 24.0), 1, 1.0, 1.2)
	d.go("n3_repaired")


func s_n3_repaired() -> void:
	d.obj("n3_home")
	W.ropes.clear_gaps("D")
	W.ropes.set_gap("D", 34.0, 60.0)
	var a := W.ropes.point_at("D", 60.0)
	await d.until(func() -> bool: return d.dist2(p.global_position, a) < 5.0 or d.in_house())
	if not d.in_house():
		d.think("cut")
		await d.sleep(3.0)
		# два огня: окно радиорубки (жёлтое, ровное) и чужой — белый, дышит, чуть севернее
		if not G.ai_off:
			d.make_lure(a + Vector3(21.0, 0, -19.0))
		d.think("two_lights")
		await d.until(func() -> bool: return d.dist2(p.global_position, a) > 6.0 or d.in_house())
		if not G.ai_off and d.lure != null:
			await d.say("gr_lure_b", "Рация", -1.0)
	await d.until(func() -> bool:
		var s := d.rope_s("D", 2.5)
		return (s >= 0.0 and s < 34.0) or d.in_house())
	d.clear_lure()
	await d.until(func() -> bool: return d.in_house())
	d.done("n3_home")
	d.go("n3_radio")


func s_n3_radio() -> void:
	d.obj("n3_radio")
	await _radio_session("morse_tx_3", func() -> void:
		await _morse_in("morse_rx_1", "ТИХАЯ ЗПТ Я ДИКСОН ТЧК ПОЧЕМУ МОЛЧАЛИ С 14 ЯНВАРЯ ВПР")
		Snd.play("morse_tx_2", -6.0)
		await d.sleep(3.0)
		await _morse_in("morse_rx_2", "КАКИЕ СВОДКИ ВПР МЫ НИЧЕГО НЕ ПОЛУЧАЛИ ТЧК ГОЛОСОМ НЕ РАБОТАЕМ СО 2 ЯНВАРЯ ТЧК ТОЛЬКО КЛЮЧОМ")
		Snd.play("sting_low", -2.0)
		d.think("voice_fake")
		await d.sleep(4.0)
		await _morse_in("morse_rx_3", "БОРТ 20 ЯНВАРЯ ЕСЛИ СТИХНЕТ ТЧК ОБОЗНАЧЬТЕ ПЛОЩАДКУ ОГНЕМ ТЧК ДЕРЖИТЕСЬ")
		G.radio_ui.decoded = "")
	G.set_flag("truth_known")
	d.done("n3_radio")
	d.obj("n3_sleep")
	d.allow["bed"] = true
	await d.wait_act("sleep")
	d.done("n3_sleep")
	await _sleep_into("n3_night", func() -> void:
		await d.sleep(2.0))


func s_n3_night() -> void:
	d._baseline(3)
	W.set_power(true, true)
	_lie_down()
	G.cards.black(1.0)
	G.main.set_fade(Color(0, 0, 0, 0))
	if not d.fast:
		await G.cards.lines(["03:10"], 1.0, 44, 0.8)
	_door_knock("knock_2", 6.0)
	await G.cards.reveal(0.2 if d.fast else 1.5)
	d.obj("n3_wait")
	d.hud.hint("E — встать", 20.0)
	var door: Door = W.doors["house"]
	if not G.ai_off:
		e.show_pose(Vector3(6.25, 0, 1.6), 90.0, 0.35)
		e.fig.look_on = true
	# можно лежать, можно встать и подойти к двери. Открыть — нельзя
	var plan := [[5.0, "gr_n3_a"], [11.0, "gr_n3_b"], [18.0, "knock_1"], [25.0, "gr_n3_c"], [36.0, "knock_hard"], [44.0, "gr_n3_d"],
		[56.0, "gr_n3_e"], [66.0, "door_bang"], [69.0, "gr_n3_f"], [78.0, "door_bang"]]
	var t0 := d.clock
	var k := 0
	var up := false
	while d.clock - t0 < 92.0:
		if not up and (Input.is_action_pressed("use") or Input.is_action_pressed("move_f") or d.acted.has("getup")):
			up = true
			d.hud.hint("", 0.0)
			_stand_up()
		if k < plan.size() and d.clock - t0 >= float(plan[k][0]):
			var what := String(plan[k][1])
			k += 1
			if what.begins_with("gr_"):
				d.say(what, "Рация")
			else:
				_door_knock(what, 6.0)
				if what == "door_bang":
					p.shake(0.35, 0.3)
		if door.is_open and not G.god:
			# открыл
			if not "gost" in G.endings_seen:
				G.endings_seen.append("gost")
			Snd.play("sting_hit", 0.0)
			G.die("door")
			return
		await d.tick
	e.hide_now()
	for i in 5:
		Snd.play_at("ent_step", Vector3(7.0 + i * 1.6, 0.1, 2.0 + i), W, 3.0, 0.95, 40.0, 7.0)
		await d.sleep(0.9)
	d.done("n3_wait")
	await d.sleep(3.0)
	G.main.fade_to(Color(0, 0, 0, 1), 2.0)
	await d.sleep(2.2)
	G.cards.black(1.0)
	G.main.set_fade(Color(0, 0, 0, 0))
	d.go("n4_wake")


# ================================================================== НОЧЬ 4

func s_n4_wake() -> void:
	await _wake(4)
	d.allow["nstand"] = true
	d.think("drawer")
	d.obj("n4_diary")
	var told := false
	while not d.acted.has("read_gr6"):
		if not told and d.zone_id() == "vest":
			told = true
			d.think("parka")
			Snd.play("sting_low", -8.0)
		await d.tick
	d.done("n4_diary")
	await d.until(func() -> bool: return not G.note_view.is_open)
	d.obj("n4_old")
	# по дороге туда фальшфейеров ещё нет — оно ведёт себя как на третью ночь; гасить фонарь научится после ледника
	e.level = 3
	d.stalker = true
	d.stalk_cd = 55.0
	told = false
	while d.zone_id() != "balok":
		if not told and d.zone_id() == "vest":
			told = true
			d.think("parka")
		await d.tick
	d.go("n4_balok")


func s_n4_balok() -> void:
	d.stalker = false
	if e.state != Entity.S.HIDDEN:
		e.leave()
	d.done("n4_old")
	d.obj("n4_stove")
	d.obj("n4_gun")
	d.allow["hatch"] = true
	await d.wait_act("hatch_open")
	Snd.play("hatch_open", 0.0)
	G.busy = true
	G.main.fade_to(Color(0, 0, 0, 1), 1.0)
	await d.sleep(1.4)
	for i in 3:
		Snd.play("ladder", -2.0)
		await d.sleep(0.55)
	W.goto("cellar")
	G.main.fade_to(Color(0, 0, 0, 0), 1.2)
	G.busy = false
	d.go("n4_cellar")


func s_n4_cellar() -> void:
	d.obj("n4_gun")
	d.allow["gun"] = true
	d.allow["ladder"] = true
	Snd.loop("cellar", "cellar_loop", 0.7, 2.0, "Amb")
	Snd.set_reverb(0.85, 0.45)
	var spot: Vector3 = (W.things["gromov_spot"] as Array)[0]
	var cracked := false
	var told := false
	while not d.acted.has("gun_taken"):
		if not cracked and d.dist2(p.global_position, spot) < 10.0:
			cracked = true
			Snd.play_at("ice_crack", p.global_position + Vector3(0, 1.8, -3.0), W, 0.0)
		if not told and d.dist2(p.global_position, spot) < 4.2:
			told = true
			d.think("gromov_body")
		if d.acted.has("climb"):
			d.acted.erase("climb")
			await _climb_out()
			await d.until(func() -> bool: return d.acted.has("hatch_open") or d.zone_id() == "cellar")
			if d.acted.has("hatch_open"):
				d.acted.erase("hatch_open")
				W.goto("cellar")
		await d.tick
	# взял ракетницу — фонарь гаснет. Когда свет возвращается, у стены никого
	d.has_gun = true
	(W.things["flaregun"] as Interactable).enabled = false
	Snd.play("pickup", -2.0)
	d.hud.toast("Ракетница, три ракеты")
	await d.sleep(1.2)
	p.kill_lamp(1.8)
	Snd.play("sting_hit", 1.0)
	await d.sleep(0.5)
	d.gromov.visible = false
	Snd.play_at("hatch_slam", Nights_cellar(Vector3(0, 2.4, -0.4)), W, 6.0, 1.0, 60.0, 12.0)
	await d.sleep(1.8)
	d.think("gone")
	d.done("n4_gun")
	d.obj("n4_flee")
	# стоит отойти от скважины — оно идёт следом по ходу
	var cz := BuildSites.CELLAR.z
	await d.until(func() -> bool: return p.global_position.z - cz < 12.6 or d.acted.has("climb"))
	if not G.ai_off and not d.acted.has("climb"):
		Snd.play_at("ent_croak", Nights_cellar(Vector3(1.75, 1.4, 15.5)), W, 2.0, 0.85, 40.0, 8.0)
		e.global_position = Nights_cellar(Vector3(1.75, FY, 15.6))
		e.walk_path([Nights_cellar(Vector3(1.75, FY, 8.2)), Nights_cellar(Vector3(0.25, FY, 6.8)), Nights_cellar(Vector3(0.25, FY, 1.6)),
			Nights_cellar(Vector3(0.0, FY, 0.0))], 1.15, 1.0)
		e.fig.look_on = true
		if not e.near_snd.playing:
			e.near_snd.play()
	while not d.acted.has("climb"):
		if e.state == Entity.S.SCRIPT and e.visible and e.dist_to_player() < 1.3 and absf(e.global_position.y - p.global_position.y) < 1.0 and not G.god:
			G.die("taken")
			return
		await d.tick
	await _climb_out()
	d.go("n4_flee")


static func Nights_cellar(local: Vector3) -> Vector3:
	return BuildSites.CELLAR + local


func _climb_out() -> void:
	G.busy = true
	G.main.fade_to(Color(0, 0, 0, 1), 0.6)
	await d.sleep(0.7)
	for i in 3:
		Snd.play("ladder", -2.0)
		await d.sleep(0.45)
	e.hide_now()
	Snd.stop_loop("cellar", 1.0)
	Snd.set_reverb(0.3, 0.0)
	W.goto("balok_in")
	p.yaw = deg_to_rad(-90.0)
	G.main.fade_to(Color(0, 0, 0, 0), 0.8)
	G.busy = false


func s_n4_flee() -> void:
	d.obj("n4_flee")
	e.level = 4
	Snd.stop_loop("cellar", 1.0)
	Snd.set_reverb(0.3, 0.0)
	d.gromov.visible = false
	await d.until(func() -> bool: return d.outdoors() or d.in_house())
	await d.sleep(4.0)
	if not d.in_house():
		d.say("gr_n4_a", "Рация")
		if not G.ai_off:
			e.hunt_near(22.0, 0.75)
		if p.flares > 0:
			d.hint("flare", 8.0)
	d.stalker = true
	d.stalk_cd = 24.0
	await d.until(func() -> bool: return d.in_house())
	d.stalker = false
	d.go("n4_home")


func s_n4_home() -> void:
	d.stalker = false
	(W.things["gromov_parka"] as Node3D).visible = false
	d.done("n4_flee")
	d.obj("n4_bar")
	var door: Door = W.doors["house"]
	await d.until(func() -> bool: return door.barred and not door.is_open)
	d.done("n4_bar")
	if e.state != Entity.S.HIDDEN:
		e.leave()
	d.obj("n4_radio")
	await _radio_session("morse_tx_4", func() -> void:
		await _morse_in("morse_rx_4", "ПОНЯЛ ВАС ТЧК БОРТ ВЫЛЕТАЕТ В 06 00 ТЧК ПЛОЩАДКУ ОБОЗНАЧЬТЕ ТРЕМЯ ОГНЯМИ ТЧК ДЕРЖИТЕСЬ")
		G.radio_ui.decoded = "")
	d.done("n4_radio")
	d.go("n4_siege")


func s_n4_siege() -> void:
	d.obj("n4_wait")
	var door: Door = W.doors["house"]
	await d.sleep(9.0)
	d.ev("blackout")
	await d.sleep(3.0)
	d.think("gen_dead")
	await d.sleep(7.0)
	_door_knock("knock_2", 6.0)
	await d.sleep(9.0)
	_door_knock("door_bang", 7.0)
	p.shake(0.3, 0.3)
	await d.sleep(6.0)
	# обходит дом, скребёт по стенам
	for i in 4:
		var a := -0.4 + float(i) * 1.5
		Snd.play_at("scratch", Vector3(cos(a) * 5.4, 1.3, sin(a) * 3.5), W, 5.0, 1.0, 26.0, 5.0)
		await d.sleep(3.2)
	Snd.play_at("knock_window", Vector3(0, 1.5, -3.3), W, 4.0, 1.0, 26.0, 5.0)
	# за северным окном — лицо. Смотрит, пока на него смотрят
	if not G.ai_off:
		e.show_pose(Vector3(0.0, 0, -3.72), 180.0, 0.0, 0.0)
		e.fig.set_wrong(0.25)
		e.fig.look_on = true
		e.fig.eyes_always = 1.0
	await d.sleep(6.5)
	if not G.ai_off:
		e.fig.eyes_always = 0.0
		e.hide_now()
	# печь гаснет, лампа гаснет
	W.stove_t = 0.0
	W.lantern_on = false
	Snd.play("gust", -4.0)
	await d.sleep(3.0)
	await d.say("gr_n4_b", "Рация")
	Snd.play_at("door_break", Vector3(5.1, 1.2, 1.6), W, 8.0, 1.0, 40.0, 9.0)
	p.shake(0.6, 0.5)
	door.set_barred(false, true)
	door.locked = false
	door.set_open(true, false, true)
	d.done("n4_wait")
	d.obj("n4_hide")
	d.allow["hide"] = true
	d._bed_prompt()
	# оно входит. Под койку — секунд двадцать
	if not G.ai_off:
		e.global_position = Vector3(6.4, 0, 1.6)
		e.walk_path([Vector3(3.6, FY, 1.6), Vector3(2.3, FY, 1.6), Vector3(0.9, FY, 1.4), Vector3(0.7, FY, -1.3), Vector3(1.6, FY, -1.6)], 0.62, 1.0)
		e.fig.look_on = false
		e.carry_light(true)
		if not e.near_snd.playing:
			e.near_snd.play()
	var t0 := d.clock
	d.acted.erase("hide")
	while not d.acted.has("hide"):
		var seen := not G.ai_off and e.visible and e.dist_to_player() < 1.7
		if (d.clock - t0 > 34.0 or seen) and not G.god:
			G.die("taken")
			return
		await d.tick
	# под койкой
	d.done("n4_hide")
	d.allow.erase("hide")
	p.set_mode("hide")
	p.set_lamp(false, true)
	p.lamp_locked = true
	p.pose(Vector3(4.42, 0.2, -1.2), 90.0, 0.0, Vector2(0.75, 0.22))
	p.can_hold_breath = true
	Snd.play("cloth", -4.0)
	d.hint("breath", 9.0)
	if not G.ai_off:
		e.walk_path([Vector3(1.6, FY, -1.6), Vector3(2.7, FY, -1.6), Vector3(3.55, FY, -1.25)], 0.55, 1.0)
		d.say("gr_n4_c", "Рация", -3.0)
		await d.until(func() -> bool: return e.path.is_empty())
		# стоит у койки: не дышать
		var ok1: bool = await _hold_breath(5.5)
		if not ok1:
			return
		e.walk_path([Vector3(3.3, FY, -1.9)], 0.4, 1.0)
		await d.sleep(4.5)
		# рация зашипела — выключить
		d.walkie_on = true
		Snd.loop("walkie", "walkie_static", 0.6, 0.2, "Sfx")
		d.hint("walkie", 4.0)
		var tw := d.clock
		var off := false
		while d.clock - tw < 3.6:
			if Input.is_action_just_pressed("walkie") or d.acted.has("walkie_off"):
				off = true
				break
			await d.tick
		Snd.stop_loop("walkie", 0.1)
		d.walkie_on = false
		if not off and not G.god:
			G.die("taken")
			return
		Snd.play("switch", -6.0)
		e.walk_path([Vector3(3.55, FY, -1.25)], 0.5, 1.0)
		await d.until(func() -> bool: return e.path.is_empty())
		e.fig.reach = 0.6
		d.say("gr_n4_d", "Рация", -4.0)
		var ok2: bool = await _hold_breath(6.0)
		if not ok2:
			return
		e.fig.reach = 0.0
		e.walk_path([Vector3(2.7, FY, -1.6), Vector3(0.7, FY, -1.3), Vector3(0.9, FY, 1.4), Vector3(3.6, FY, 1.6), Vector3(7.0, 0, 1.6)], 0.8, 1.0)
		await d.until(func() -> bool: return e.path.is_empty())
		e.hide_now()
	else:
		await d.sleep(3.0)
	p.can_hold_breath = false
	p.lamp_locked = false
	d.walkie_on = true
	await d.sleep(4.0)
	G.main.fade_to(Color(0, 0, 0, 1), 2.5)
	await d.sleep(2.8)
	G.cards.black(1.0)
	G.main.set_fade(Color(0, 0, 0, 0))
	d.go("n5_wake")


## Оно стоит рядом t секунд. Выдохнул дольше чем на секунду — нашло. Возвращает false, если герой погиб.
func _hold_breath(t: float) -> bool:
	var t0 := d.clock
	var bad := 0.0
	var last := d.clock
	while d.clock - t0 < t:
		var dt := d.clock - last
		last = d.clock
		if not p.breath_held and not d.acted.has("bot_breath"):
			bad += dt
		else:
			bad = maxf(0.0, bad - dt * 0.5)
		if bad > 1.3 and not G.god:
			G.die("taken")
			return false
		await d.tick
	return true


# ================================================================== НОЧЬ 5

func s_n5_wake() -> void:
	await _wake(5, false, false)
	p.set_mode("walk")
	p.teleport(Vector3(3.4, FY, -1.3), 180.0)
	d.has_gun = true
	d.walkie_on = true
	d.think("door_open")
	d.obj("n5_pad")
	d.stalker = true
	d.stalk_cd = 26.0
	e.level = 5
	var fork := W.ropes.point_at("E", 38.0)
	var trap := Vector3(-20.0, 0, 66.0)
	var told := false
	while d.dist2(p.global_position, Map.PAD) > 13.0:
		if not told and d.dist2(p.global_position, fork) < 4.5:
			told = true
			d.think("fork")
		# серые флажки ведут в никуда
		if d.dist2(p.global_position, trap) < 7.0 and not G.god and not G.ai_off:
			e.hide_now()
			G.die("lure")
			return
		await d.tick
	d.go("n5_pad")


func s_n5_pad() -> void:
	d.done("n5_pad")
	d.obj("n5_fires")
	d.allow["barrels"] = true
	d.stalker = true
	e.level = 5
	d.stalk_cd = minf(d.stalk_cd, 12.0)
	if p.flares > 0:
		d.hint("flare", 7.0)
	await d.until(func() -> bool: return W.barrels_lit() >= 3)
	d.done("n5_fires")
	d.go("n5_final")


func s_n5_final() -> void:
	d.obj("n5_signal")
	d.stalker = false
	if e.state != Entity.S.HIDDEN:
		e.leave()
	var pad := Map.PAD
	# гул винтов издалека
	var far := Snd.emitter("heli_loop", W, pad + Vector3(60, 40, 90), -6.0, 400.0, 60.0)
	far.play()
	await d.sleep(9.0)
	# чужой «борт»: белый дышащий огонь на земле к западу и голос
	var fake := pad + Vector3(-46.0, 0, 6.0)
	if not G.ai_off:
		d.make_lure(fake, false)
	await d.say("dx_n5_a", "Рация")
	d.think("voice_fake")
	await d.sleep(2.0)
	d.hud.hint("G — выстрелить из ракетницы", 12.0)
	var fired := false
	var t_voice := d.clock + 9.0
	while not fired:
		if (Input.is_action_just_pressed("flare") or d.acted.has("bot_fire")) and d.dist2(p.global_position, pad) < 16.0:
			fired = true
		if d.clock > t_voice and not G.ai_off:
			t_voice = d.clock + 14.0
			d.say("dx_n5_b", "Рация")
		if d.dist2(p.global_position, fake) < 9.0 and not G.god and not G.ai_off:
			far.stop()
			G.ending("otzyv")
			return
		await d.tick
	d.hud.hint("", 0.0)
	Snd.play("flaregun", 2.0)
	p.shake(0.5, 0.3)
	var star := Kit.halo(W, p.global_position + Vector3(0, 3, 0), Color(1.0, 0.15, 0.1), 5.0, 3.0)
	(star.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 6.0)
	var tw := d.create_tween()
	tw.tween_property(star, "position:y", 70.0, 2.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "position:y", 30.0, 9.0)
	tw.tween_callback(star.queue_free)
	d.w.fire_light = 1.0
	d.done("n5_signal")
	d.clear_lure()
	far.stop()
	far.queue_free()
	# садится не на голову: если стоишь в центре площадки — в семи метрах от тебя
	var spot := pad
	if d.dist2(p.global_position, pad) < 7.0:
		var away := pad - p.global_position
		away.y = 0.0
		away = away.normalized() if away.length() > 0.3 else Vector3(0, 0, 1)
		spot = p.global_position + away * 7.5
		spot.y = 0.0
	await heli_land(spot)
	d.obj("n5_board")
	d.allow["heli"] = true
	await d.wait_act("board")
	d.done("n5_board")
	G.busy = true
	p.control = false
	await d.say("dx_n5_c", "Рация")
	G.main.fade_to(Color(0, 0, 0, 1), 2.5)
	await d.sleep(3.2)
	Snd.stop_all(2.0)
	await d.sleep(2.0)
	await d.say("dx_end", "В наушниках пилота")
	await d.sleep(1.0)
	G.busy = false
	G.ending("bort")


## Вертолёт заходит с юго-востока и садится в точку pad. Винты разгоняют пургу.
func heli_land(pad: Vector3) -> void:
	if d.heli != null and is_instance_valid(d.heli):
		d.heli.queue_free()
	var h := Node3D.new()
	W.add_child(h)
	d.heli = h
	var olive := Kit.flat(Color(0.2, 0.24, 0.18), 0.7, 0.2)
	var dark := Kit.flat(Color(0.03, 0.035, 0.04), 0.3, 0.3)
	Kit.sphere_node(h, Vector3(0, 2.0, 0), 1.0, olive, Vector3(1.25, 1.3, 4.3), 14)
	Kit.sphere_node(h, Vector3(0, 2.05, -3.3), 1.0, dark, Vector3(1.0, 0.9, 1.3), 10)
	var boom := Kit.cyl_node(h, Vector3(0, 2.5, 6.2), 0.42, 6.0, olive, 8, 0.16)
	boom.rotation.x = deg_to_rad(90)
	Kit.box_node(h, Vector3(0, 3.5, 9.0), Vector3(0.1, 2.0, 0.8), olive)
	Kit.cyl_node(h, Vector3(0, 3.55, 0), 0.3, 0.5, dark, 8)
	for wp in [Vector3(-1.5, 0.3, 0.8), Vector3(1.5, 0.3, 0.8), Vector3(0, 0.3, -3.0)]:
		var wh := Kit.cyl_node(h, wp, 0.3, 0.2, dark, 10)
		wh.rotation.z = deg_to_rad(90)
		Kit.box_node(h, wp + Vector3(0, 0.6, 0), Vector3(0.08, 1.0, 0.08), dark)
	var disc := StandardMaterial3D.new()
	disc.albedo_color = Color(0.05, 0.05, 0.05, 0.16)
	disc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rotor := Kit.cyl_node(h, Vector3(0, 3.85, 0), 10.6, 0.03, disc, 24)
	rotor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 5:
		var bl := Kit.box_node(rotor, Vector3.ZERO, Vector3(21.0, 0.03, 0.5), dark, false)
		bl.rotation.y = deg_to_rad(i * 36.0)
	var search := Kit.halo(h, Vector3(0, 1.3, -3.6), Color(1.0, 0.97, 0.9), 3.0, 3.0)
	(search.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 4.0)
	var red := Kit.halo(h, Vector3(0, 4.6, 9.0), Color(1.0, 0.1, 0.05), 1.6, 2.4)
	(red.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 4.0)
	Kit.omni(h, Vector3(0, 1.0, -3.0), Color(1.0, 0.97, 0.9), 4.0, 30.0, true, 400.0)
	Kit.omni(h, Vector3(1.6, 2.0, 0.5), Color(1.0, 0.8, 0.5), 1.2, 6.0, false, 200.0)
	var snd := Snd.emitter("heli_loop", h, Vector3(0, 3, 0), 4.0, 500.0, 40.0)
	snd.play()
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.4, 3.0, 8.0)
	cs.shape = sh
	cs.position = Vector3(0, 1.5, 0)
	body.add_child(cs)
	h.add_child(body)
	Interactable.make(h, Vector3(1.4, 1.5, 0.3), Vector3(0.8, 2.2, 2.2), "В вертолёт", func() -> void: G.act("heli_door"))
	h.rotation.y = deg_to_rad(-30.0)
	var start := pad + Vector3(46, 44, 70)
	h.global_position = start
	var t0 := d.clock
	var dur := 3.0 if d.fast else 15.0
	while d.clock - t0 < dur:
		var k := (d.clock - t0) / dur
		var ks := 1.0 - pow(1.0 - k, 2.2)
		h.global_position = start.lerp(pad, ks)
		rotor.rotate_y(0.45)
		red.visible = fmod(d.clock, 1.2) < 0.5
		d.w.clear = move_toward(d.w.clear, 0.55 * clampf(k * 1.6 - 0.4, 0.0, 1.0), 0.01)
		await d.tick
	h.global_position = pad
	p.shake(0.3, 0.6)
	# винты крутятся, пока ждут
	_spin(rotor, red)


func _spin(rotor: Node3D, red: Node3D) -> void:
	while is_instance_valid(rotor) and rotor.is_inside_tree():
		rotor.rotate_y(0.45)
		red.visible = fmod(d.clock, 1.2) < 0.5
		await d.tick
