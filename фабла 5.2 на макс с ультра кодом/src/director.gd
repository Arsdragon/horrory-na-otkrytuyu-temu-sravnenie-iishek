class_name Director
extends Node
## Режиссёр: состояние мира по этапам, действия игрока с предметами, события страха.
## Сценарии ночей лежат в nights.gd и идут сопрограммами; все ожидания — через tick, поэтому
## при перезапуске мира (узел удаляется) они просто перестают продолжаться.

signal tick

## Точки входа по порядку. С любой можно начать (контрольные точки и админ-режим).
const ORDER := ["n1_wake", "n1_back", "n1_radio", "n2_wake", "n2_depot", "n2_gen", "n2_site", "n2_pass", "n2_radio",
	"n3_wake", "n3_mast", "n3_repaired", "n3_radio", "n3_night", "n4_wake", "n4_balok", "n4_cellar", "n4_flee", "n4_home", "n4_siege",
	"n5_wake", "n5_pad", "n5_final"]
const TITLES := {"n1_wake": "Пробуждение, срок 21:00", "n1_back": "Обратно с площадки", "n1_radio": "Сводка, печь, сон и стук",
	"n2_wake": "Дизель встал", "n2_depot": "Склад ГСМ: насос и фигура", "n2_gen": "Назад с соляркой, чужой огонь", "n2_site": "Срок: рукавица и записка",
	"n2_pass": "Первая встреча: проход мимо", "n2_radio": "Сводка: «зачем погасили фонарь?»", "n3_wake": "Радио работает само",
	"n3_mast": "К мачте, ремонт фидера", "n3_repaired": "Перерезанный леер, два огня", "n3_radio": "Настоящий Диксон", "n3_night": "Ночной визит: «Открой»",
	"n4_wake": "Парка на крючке, дневник", "n4_balok": "Старый балок", "n4_cellar": "Ледник. Громов", "n4_flee": "Бегство домой",
	"n4_home": "Засов и радио", "n4_siege": "Оно входит в дом", "n5_wake": "Утро. Дверь настежь", "n5_pad": "Три огня", "n5_final": "Два борта"}
const EVENTS := {"far_bang": "Далёкий удар железа", "echo_steps": "Шаги-эхо за спиной", "lamp_flicker": "Мигание фонаря", "walkie_click": "Щелчки рации",
	"figure_far": "Фигура на леере", "prints_cross": "Чужие следы", "rope_tug": "Кто-то дёргает леер", "false_light": "Чужой огонь",
	"false_voice": "Чужой голос", "knock": "Стук в дверь", "knock_hard": "Удары в дверь", "window_tap": "Стук в окно", "scratch": "Скребёт по стене",
	"radio_self": "Радио включается само", "blackout": "Дизель глохнет", "power_on": "Дизель заводится", "gust": "Порыв ветра",
	"hunt": "Охота (подходит издалека)", "pass_by": "Проход мимо (встань у леера и погаси фонарь)", "kill": "Смерть: оно схватило", "freeze": "Смерть: замёрз",
	"house_creak": "Скрип дома", "cut_rope": "Перерезать леер «Г»", "parka": "Парка Громова на крючке", "heli": "Вертолёт садится"}

const READ := {1: {"t": "−31,2", "w": "18", "s": "74"}, 2: {"t": "−33,4", "w": "22", "s": "76"}, 3: {"t": "−34,0", "w": "25", "s": "79"},
	4: {"t": "−36,1", "w": "27", "s": "81"}, 5: {"t": "−37,5", "w": "30", "s": "84"}}

var world: World
var p: Player
var e: Entity
var w: Weather
var hud: Hud
var nights: Nights
var bot: Bot
var stage := ""
var clock := 0.0
var acted := {}
var allow := {}            # что сейчас можно: bed, hide, radio, cable, nstand, hatch, ladder, gun, barrels, heli
var pulls := 0
var jerry_full := false
var has_cable := false
var has_gun := false
var stalker := false       # существо само приходит, пока игрок на улице
var stalk_cd := 30.0
var walkie_on := true
var lure: Node3D = null
var lure_pos := Vector3.ZERO
var lure_armed := false
var gromov: Figure = null
var heli: Node3D = null
var fast := false          # автотест: без долгих заставок
var _creak_t := 25.0
var _pump_t := 0.0
var _pumping := false
var _pouring := false
var _static := 0.0
var _fear := 0.0
var _radio_t := 0.0


func begin(id: String) -> void:
	p = G.player
	e = G.entity
	w = world.weather
	hud = G.hud
	stage = id
	fast = (Cfg.has_arg("fast") or Cfg.has_arg("bot") or Cfg.has_arg("shot") or Cfg.has_arg("tour")) and not Cfg.has_arg("nofast")
	e.caught.connect(func() -> void: G.die("taken"))
	w.gust_started.connect(_on_gust)
	G.radio_ui.transmit.connect(_on_tx)
	G.radio_ui.closed.connect(_on_radio_closed)
	nights = Nights.new(self)
	if id == "sandbox":
		G.night = 2
		_baseline(2)
		world.set_power(true, true)
		world.stove_t = 99999.0
		p.set_lamp(false, true)
		G.cards.visible = false
		return
	G.night = int(id.substr(1, 1))
	_grant_past(G.night)
	_baseline(G.night)
	nights.setup(id)
	# этапы посреди ночи начинаются сразу в мире: проявляем кадр (пробуждения делают это сами, через карточку ночи)
	if not id.ends_with("_wake") and id != "n3_night":
		G.cards.visible = false
		G.main.fade_to(Color(0, 0, 0, 0), 1.2)
	nights.run(id)
	if Cfg.has_arg("bot"):
		bot = Bot.new(self)
		bot.run(id)


## Перейти к следующему этапу без перестройки мира (обычный ход игры).
func go(next_id: String) -> void:
	stage = next_id
	G.night = int(next_id.substr(1, 1))
	G.checkpoint(next_id)
	nights.run(next_id)


# ------------------------------------------------------------------ ожидания

func _process(dt: float) -> void:
	clock += dt
	_ambient(dt)
	tick.emit()


func sleep(t: float) -> void:
	var end := clock + t
	while clock < end:
		await tick


func until(cond: Callable) -> void:
	while not bool(cond.call()):
		await tick


func wait_act(id: String) -> void:
	acted.erase(id)
	while not acted.has(id):
		await tick


func dist2(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func near(pos: Vector3, r: float) -> void:
	while dist2(p.global_position, pos) > r:
		await tick


func zone_id() -> String:
	return String(p.zone.get("id", ""))


func in_house() -> bool:
	return zone_id() in ["house", "radio", "bunk", "store", "vest"]


func outdoors() -> bool:
	return zone_id() == ""


## Положение игрока вдоль леера (метры от начала) или −1, если он далеко от этого леера.
func rope_s(line: String, max_d := 4.0) -> float:
	var n: Dictionary = world.ropes.nearest(p.global_position, max_d, line)
	if n.is_empty() or String(n.line) != line:
		return -1.0
	return float(n.s)


# ------------------------------------------------------------------ речь и подсказки

func say(key: String, who := "Диксон", vol := 0.0) -> void:
	var dur := Snd.voice(key, vol)
	if dur <= 0.0:
		dur = 2.5
	hud.subtitle(who, String(T.VOICE.get(key, key)), dur + 0.6)
	await sleep(dur + 0.25)


func think(key: String) -> void:
	hud.think(String(T.THINK.get(key, key)))


func hint(key: String, dur := 7.0) -> void:
	hud.hint(String(T.HINT.get(key, key)), dur)


func obj(id: String) -> void:
	G.set_obj(id)


func done(id: String) -> void:
	G.done_obj(id)


# ------------------------------------------------------------------ состояние мира по ночам

func _grant_past(night: int) -> void:
	for n in range(1, night):
		if not G.readings.has(n) and n <= 2:
			G.readings[n] = READ[n].duplicate()
	if night >= 3 or stage in ["n2_pass", "n2_radio"]:
		G.set_flag("rules_known")
	var seen := {2: ["memo", "gr1", "gr2"], 3: ["gr3"], 4: ["gr4"], 5: ["gr6", "log61a", "log61b", "gr7"]}
	if G.admin:
		for n in seen:
			if night >= int(n):
				for id in seen[n]:
					if not id in G.notes:
						G.notes.append(id)


func _baseline(night: int) -> void:
	e.level = clampi(night, 2, 5)
	e.hide_now()
	stalker = false
	w.base = [0.5, 0.5, 0.58, 0.64, 0.7, 0.8][night]
	w.gust_min = [20.0, 22.0, 18.0, 15.0, 13.0, 10.0][night]
	w.gust_max = [40.0, 42.0, 36.0, 30.0, 26.0, 20.0][night]
	world.set_power(night != 2 and night != 5, true)
	world.gen_fuel = 0.0 if night == 2 else 70.0
	world.stove_t = 0.0 if (night == 2 or night == 5) else 700.0
	world.lantern_on = false
	G.radio_ui.extra_stations = 0 if night < 3 else (1 if night == 3 else 2)
	G.radio_ui.can_send = false
	# двери
	var bd: Door = world.doors["balok"]
	bd.locked = night < 4
	bd.locked_text = "Дверь примёрзла"
	if night >= 4:
		bd.set_open(true, true)
	(world.doors["house"] as Door).set_open(night == 5, true)
	# на вторую ночь дверь дизельной распахнута, хотя её закрывали
	(world.doors["shed"] as Door).set_open(night == 2, true)
	# на койке Громова кто-то лежал; на стекле радиорубки — ладонь
	(world.things["gromov_bed"] as Node3D).visible = night < 3
	(world.things["gromov_bed_used"] as Node3D).visible = night >= 3
	(world.things["handprint"] as Node3D).visible = night >= 3
	# рукавица и записка в будке — со второй ночи
	var mit: Node3D = world.things["mitten"]
	mit.visible = night >= 2
	var n3: Interactable = world.things["note_gr3"]
	n3.enabled = night >= 2
	(n3.get_meta("mesh") as Node3D).visible = night >= 2
	# записка у пирамиды и дневник — всегда; парка Громова — на четвёртую ночь
	(world.things["gromov_parka"] as Node3D).visible = night == 4
	# ложная ветка леера «Д» — только на пятую ночь
	if world.ropes.lines.has("X"):
		world.ropes.set_hidden("X", night != 5)
	# тело Громова в леднике
	if gromov == null:
		var spot: Array = world.things["gromov_spot"]
		gromov = Figure.make(world, true)
		gromov.global_position = spot[0]
		gromov.rotation.y = deg_to_rad(float(spot[1]))
		gromov.jerk = false
		gromov.set_pose("sit")
	gromov.visible = true
	p.flares = 0
	p.carrying = ""
	p.warmth = 100.0
	jerry_full = night != 2
	has_cable = false
	has_gun = night >= 5
	if night >= 5:
		p.flares = 4
		G.set_flag("flares_known")
	_bed_prompt()


func _bed_prompt() -> void:
	var it: Interactable = world.things["bed"]
	it.prompt = "Спрятаться под койкой" if allow.get("hide", false) else "Лечь спать"


# ------------------------------------------------------------------ действия игрока

func act(id: String) -> void:
	acted[id] = true
	if id.begins_with("barrel_"):
		_act_barrel(int(id.substr(7)))
		return
	match id:
		"bar":
			var d: Door = world.doors["house"]
			if d.is_open:
				hud.toast("Сначала закрой дверь")
			else:
				d.set_barred(not d.barred)
				(world.things["bar"] as Interactable).prompt = "Отодвинуть засов" if d.barred else "Задвинуть засов"
				if d.barred:
					acted["barred"] = true
		"lantern":
			world.lantern_on = not world.lantern_on
			Snd.play_at("match" if world.lantern_on else "switch", Vector3(0.62, 0.9, 0.3), world, -4.0)
			(world.things["lantern_it"] as Interactable).prompt = "Погасить лампу" if world.lantern_on else "Зажечь лампу"
		"woodbox", "woodpile":
			if p.carrying != "":
				hud.toast("Руки заняты")
			else:
				p.carrying = "wood"
				Snd.play("wood_put", -6.0)
				hud.toast("Охапка дров")
		"stove":
			if p.carrying == "wood":
				p.carrying = ""
				world.stove_t = maxf(world.stove_t, 0.0) + 900.0
				Snd.play_at("stove_door", Vector3(-1.5, 0.5, 0), world, -3.0)
				Snd.play("wood_put", -8.0)
				acted["stoked"] = true
			elif world.stove_t > 60.0:
				hud.toast("Печь топится")
			else:
				think("no_wood")
		"balok_stove":
			if world.balok_stove_t > 0.0:
				hud.toast("Печь топится")
			else:
				world.balok_stove_t = 600.0
				Snd.play_at("match", Vector3(-49.9, 0.5, -90.4), world, -2.0)
				done("n4_stove")
		"jerry":
			if p.carrying != "":
				hud.toast("Руки заняты")
			else:
				p.carrying = "jerry"
				(world.things["jerry"] as Node3D).visible = false
				(world.things["jerry_it"] as Interactable).enabled = false
				Snd.play("can_clank", -5.0)
				if not jerry_full:
					think("can_empty")
				acted["jerry_taken"] = true
		"pump_on":
			_pumping = p.carrying == "jerry" and not jerry_full
			_pump_t = 0.0
			if p.carrying != "jerry":
				think("need_can")
		"pump_off":
			_pumping = false
		"pump":
			_pumping = false
			if p.carrying != "jerry":
				acted.erase("pump")
			elif jerry_full:
				hud.toast("Канистра полная")
			else:
				jerry_full = true
				Snd.play("can_clank", -4.0)
				hud.toast("Канистра полная")
				acted["pumped"] = true
		"gen_fuel":
			if p.carrying == "jerry" and jerry_full:
				jerry_full = false
				p.carrying = ""
				world.gen_fuel = 100.0
				(world.things["jerry"] as Node3D).visible = true
				(world.things["jerry_it"] as Interactable).enabled = true
				Snd.play_at("fuel_pour", world.things["gen_pos"], world, -2.0)
				hud.toast("Бак залит")
				acted["fueled"] = true
			elif p.carrying == "jerry":
				think("can_empty")
			elif world.gen_fuel > 50.0:
				hud.toast("Бак полон")
			else:
				think("need_can")
		"gen_start":
			_act_gen_start()
		"radio":
			if not world.gen_on:
				hud.toast("Нет питания")
			else:
				p.look_to(Vector3(-4.6, 1.0, -1.7), 0.5)
				G.radio_ui.open()
				G.ui_frame = Engine.get_process_frames()
				hint("radio", 8.0)
		"bed":
			if allow.get("hide", false):
				acted["hide"] = true
			elif allow.get("bed", false):
				acted["sleep"] = true
			else:
				think("sleep_early")
		"journal":
			G.read("j%d" % clampi(G.night, 1, 5))
		"wallmap":
			G.notebook.open(3)
			G.ui_frame = Engine.get_process_frames()
		"nstand":
			if allow.get("nstand", false):
				G.read("gr6")
			else:
				hud.toast("Заперто")
		"cable":
			if allow.get("cable", false):
				has_cable = true
				(world.things["cable"] as Node3D).visible = false
				(world.things["cable_it"] as Interactable).enabled = false
				Snd.play("pickup", -4.0)
				hud.toast("Запасной кабель")
				acted["cable_taken"] = true
			else:
				think("not_now")
		"feeder_on":
			if not has_cable:
				think("need_cable")
			acted["repairing"] = true
		"feeder_off":
			acted.erase("repairing")
		"feeder":
			if has_cable:
				has_cable = false
				Snd.play("switch", -3.0)
				hud.toast("Фидер подключён")
				(world.things["feeder"] as Interactable).enabled = false
				acted["repaired"] = true
		"read_t", "read_w", "read_s":
			var k := id.substr(5)
			var r: Dictionary = G.readings.get(G.night, {})
			var vals: Dictionary = READ[clampi(G.night, 1, 5)]
			r[k] = vals[k]
			G.readings[G.night] = r
			Snd.play("pencil", -6.0)
			var names := {"t": "Термометр: %s °C", "w": "Ветер: %s м/с", "s": "Снег: %s см"}
			hud.toast(String(names[k]) % String(vals[k]), 3.0)
		"booth_open":
			var bd: Node3D = world.things["booth_door"]
			Snd.play_at("booth_door", bd.global_position, world, -4.0)
			create_tween().tween_property(bd, "rotation:y", -1.9, 0.5)
		"booth_close":
			create_tween().tween_property(world.things["booth_door"], "rotation:y", 0.0, 0.4)
		"nz":
			if G.flag("nz_taken"):
				hud.toast("Пусто")
			else:
				G.set_flag("nz_taken")
				G.set_flag("flares_known")
				p.flares += 4
				Snd.play("pickup", -3.0)
				hud.toast("Фальшфейеры: 4")
				hint("flare", 8.0)
		"hatch":
			if allow.get("hatch", false):
				acted["hatch_open"] = true
			else:
				hud.toast("Примёрз. Не открыть")
		"ladder_up":
			if allow.get("ladder", true):
				acted["climb"] = true
		"flaregun":
			if allow.get("gun", false) and not has_gun:
				acted["gun_taken"] = true
			else:
				acted.erase("flaregun")
		"heli_door":
			acted["board"] = true


func _act_gen_start() -> void:
	var pos: Vector3 = world.things["gen_pos"]
	if world.gen_on:
		hud.toast("Дизель работает")
		return
	if world.gen_fuel <= 0.0:
		Snd.play_at("gen_pull", pos, world, -2.0)
		think("tank_empty")
		acted["gen_tried"] = true
		return
	pulls += 1
	if pulls < 3:
		Snd.play_at("gen_pull", pos, world, -1.0)
		return
	pulls = 0
	Snd.play_at("gen_start", pos, world, 0.0)
	(world.things["gen_start"] as Interactable).enabled = false
	await sleep(2.6)
	world.set_power(true)
	(world.things["gen_start"] as Interactable).enabled = true
	acted["gen_running"] = true


func _act_barrel(i: int) -> void:
	var barrels: Array = world.things["barrels"]
	var bd: Dictionary = barrels[i]
	if bool(bd.lit):
		return
	if not allow.get("barrels", false):
		think("not_now")
		return
	bd.lit = true
	(bd.it as Interactable).enabled = false
	Snd.play_at("ignite", bd.pos, world, 2.0)
	acted["barrel_lit"] = true


# ------------------------------------------------------------------ фон: рация, страх, скрипы, насос, охота

func _on_gust(_s: float) -> void:
	if outdoors():
		Snd.play("gust", -6.0, randf_range(0.9, 1.1), "Wind")


func _on_tx() -> void:
	acted["tx"] = true


func _exit_tree() -> void:
	if G.radio_ui != null:
		if G.radio_ui.transmit.is_connected(_on_tx):
			G.radio_ui.transmit.disconnect(_on_tx)
		if G.radio_ui.closed.is_connected(_on_radio_closed):
			G.radio_ui.closed.disconnect(_on_radio_closed)
		G.radio_ui.busy = false
	Engine.time_scale = 1.0


func _on_radio_closed() -> void:
	acted["radio_closed"] = true


func _ambient(dt: float) -> void:
	if p == null or not is_instance_valid(p) or p.mode == "dead":
		return
	# близость существа: помехи на рации, страх, рябь
	var lvl := 0.0
	var fear := 0.0
	if e.state != Entity.S.HIDDEN and e.visible:
		var d := e.dist_to_player()
		if e.state == Entity.S.WATCH:
			lvl = clampf(1.0 - d / 16.0, 0.0, 0.5)
			fear = 0.35 if e.seen_once else 0.0
		else:
			lvl = clampf(1.0 - d / 22.0, 0.0, 1.0)
			fear = clampf(1.0 - d / 18.0, 0.0, 1.0)
	if not walkie_on:
		lvl = 0.0
	_static = move_toward(_static, lvl, dt * 1.2)
	_fear = move_toward(_fear, fear, dt * 0.6)
	p.fear = _fear
	hud.set_static(_static if walkie_on else 0.0)
	if G.main != null:
		G.main.interference = _static * 0.3
	if _static > 0.02:
		Snd.loop("walkie", "walkie_static", _static * 0.55, 0.3, "Sfx")
	else:
		Snd.loop_vol("walkie", 0.0, 0.5)
	# гул напряжения
	if Snd.streams.has("drone_dread"):
		Snd.loop("dread", "drone_dread", clampf(0.18 + _fear * 0.6, 0.0, 0.8) if not in_house() or _fear > 0.1 else 0.1, 3.0, "Music")
		Snd.loop("tension", "drone_tension", clampf(_fear * 0.7 - 0.2, 0.0, 0.5), 2.0, "Music")
	# дом скрипит
	_creak_t -= dt
	if _creak_t <= 0.0:
		_creak_t = randf_range(18.0, 46.0)
		if in_house():
			var a := randf() * TAU
			Snd.play_at("house_creak", p.global_position + Vector3(cos(a) * 3.0, 2.0, sin(a) * 3.0), world, -10.0, randf_range(0.85, 1.1), 14.0, 2.0)
		elif outdoors() and randf() < 0.25:
			ev("far_bang")
	# насос: ход поршня раз в секунду с небольшим
	if _pumping:
		_pump_t -= dt
		if _pump_t <= 0.0:
			_pump_t = 1.15
			Snd.play_at("pump", world.things["pump_pos"], world, -2.0, randf_range(0.95, 1.05))
	# чужой огонь: подошёл — оно там
	if lure != null and lure_armed and dist2(p.global_position, lure_pos) < 7.5:
		_spring_lure()
	# свободная охота: приходит само, пока игрок на улице
	if stalker and not G.ai_off and e.state == Entity.S.HIDDEN and outdoors():
		stalk_cd -= dt
		if stalk_cd <= 0.0 and world.fire_dist(p.global_position) > 10.0:
			stalk_cd = randf_range(34.0, 58.0) if e.level < 5 else randf_range(22.0, 36.0)
			e.hunt_near(26.0, [0.0, 0.0, 0.2, 0.45, 0.75, 1.0][e.level])
	# огонь бочек отгоняет
	if e.state == Entity.S.ACTIVE and world.fire_dist(e.global_position) < 8.5:
		e.leave()
		stalk_cd = minf(stalk_cd, 14.0)


# ------------------------------------------------------------------ чужой огонь

func make_lure(pos: Vector3, armed := true) -> void:
	clear_lure()
	lure = Node3D.new()
	world.add_child(lure)
	lure.global_position = Vector3(pos.x, 2.0, pos.z)
	var h := Kit.halo(lure, Vector3.ZERO, Color(0.92, 0.95, 1.0), 1.5, 1.7)
	var sm: ShaderMaterial = h.material_override
	sm.set_shader_parameter("breathe", 1.0)
	sm.set_shader_parameter("vis_scale", 1.7)
	Kit.omni(lure, Vector3(0, -0.2, 0), Color(0.9, 0.95, 1.0), 1.0, 6.0, false, 90.0)
	lure_pos = Vector3(pos.x, 0, pos.z)
	lure_armed = armed


func clear_lure() -> void:
	if lure != null and is_instance_valid(lure):
		lure.queue_free()
	lure = null
	lure_armed = false


func _spring_lure() -> void:
	var pos := lure_pos
	clear_lure()
	Snd.play("sting_hit", -1.0)
	if G.ai_off:
		return
	e.hunt_from(pos, 0.7)
	e.grace = 0.8
	acted["lure_sprung"] = true


# ------------------------------------------------------------------ события (их же вызывает админ-панель)

func ev(id: String) -> void:
	var pp := p.global_position
	var back := -p.look_dir()
	back.y = 0.0
	back = back.normalized() if back.length() > 0.1 else Vector3.BACK
	match id:
		"far_bang":
			var a := randf() * TAU
			Snd.play_at("metal_bang_far", pp + Vector3(cos(a), 0.1, sin(a)) * 28.0, world, -4.0, randf_range(0.85, 1.05), 90.0, 12.0)
		"echo_steps":
			_echo_steps(back)
		"lamp_flicker":
			p.lamp_flicker = 1.2
			Snd.play("lamp_flicker", -6.0)
		"walkie_click":
			Snd.play("walkie_click", -3.0)
			hud.set_static(0.6)
		"figure_far":
			var fwd := -back
			var pos := pp + fwd * minf(w.vis * 0.85, 11.0)
			var n: Dictionary = world.ropes.nearest(pos, 6.0)
			if not n.is_empty():
				pos = n.p
			e.watch_at(pos, 0.0)
		"prints_cross":
			var side := back.cross(Vector3.UP).normalized()
			world.prints.trail(pp - back * 5.0 + side * 6.0, pp - back * 5.0 - side * 7.0, 0, 0.82, 1.1)
		"rope_tug":
			var n2: Dictionary = world.ropes.nearest(pp, 30.0)
			if not n2.is_empty():
				var line := String(n2.line)
				world.ropes.tug(line, 1.0)
				Snd.play_at("rope_tug", n2.p + Vector3(0, 1.2, 0), world, 0.0, 1.0, 40.0, 5.0)
				get_tree().create_timer(2.2).timeout.connect(func() -> void: world.ropes.tug(line, 0.0))
		"false_light":
			var side2 := back.cross(Vector3.UP).normalized()
			make_lure(pp - back * 12.0 + side2 * 16.0)
		"false_voice":
			say("gr_lure_a", "Рация", -2.0)
		"knock":
			Snd.play_at("knock", Vector3(5.2, 1.3, 1.6), world, 4.0, 1.0, 40.0, 8.0)
		"knock_hard":
			Snd.play_at("knock_hard", Vector3(5.2, 1.3, 1.6), world, 6.0, 1.0, 45.0, 9.0)
		"window_tap":
			Snd.play_at("knock_window", Vector3(0, 1.5, -3.3), world, 2.0, 1.0, 30.0, 6.0)
		"scratch":
			Snd.play_at("scratch", Vector3(-5.2, 1.2, -1.0), world, 2.0, 1.0, 30.0, 6.0)
		"radio_self":
			Snd.play_at("dx_n3_a", Vector3(-4.58, 1.0, -1.82), world, 2.0, 1.0, 26.0, 5.0)
		"blackout":
			if world.gen_on:
				Snd.play_at("gen_stop", world.things["gen_pos"], world, 0.0, 1.0, 60.0, 6.0)
				world.set_power(false)
		"power_on":
			world.set_power(true)
		"gust":
			w.force_gust(1.0, 6.0)
		"hunt":
			e.hunt_near(22.0, [0.0, 0.0, 0.2, 0.45, 0.75, 1.0][clampi(e.level, 2, 5)])
		"pass_by":
			e.level = maxi(e.level, 2)
			e.hunt_near(16.0, 0.4)
			w.force_gust(1.0, 9.0)
			hint("hide", 9.0)
		"kill":
			var was := G.god
			G.god = false
			G.die("taken")
			G.god = was
		"freeze":
			var was2 := G.god
			G.god = false
			G.die("freeze")
			G.god = was2
		"house_creak":
			Snd.play_at("house_creak", pp + Vector3(2, 2, 1), world, -4.0)
		"cut_rope":
			world.ropes.clear_gaps("D")
			world.ropes.set_gap("D", 34.0, 60.0)
		"parka":
			var gp: Node3D = world.things["gromov_parka"]
			gp.visible = not gp.visible
		"heli":
			nights.heli_land(Map.PAD)


func _echo_steps(back: Vector3) -> void:
	# шаги за спиной: идут, пока идёшь, и делают ещё два, когда остановился
	for i in 14:
		await sleep(0.62)
		if p == null or not is_instance_valid(p):
			return
		var behind := -p.look_dir()
		behind.y = 0.0
		Snd.play_at("ent_step", p.global_position + behind.normalized() * 6.5, world, -7.0, 1.08, 20.0, 3.0)
		if p.noise == 0 and i > 3:
			await sleep(0.7)
			Snd.play_at("ent_step", p.global_position + behind.normalized() * 5.5, world, -8.0, 1.05, 20.0, 3.0)
			return
	var _b := back
