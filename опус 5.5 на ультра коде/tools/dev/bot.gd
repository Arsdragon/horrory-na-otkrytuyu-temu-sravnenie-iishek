extends Node
## Бот: проходит сюжет от двора до выбранной концовки, проверяя флаги. Запуск:
##   godot --headless --path . -- --bot [--ending=open_tap|valve|steam|last_steam] [--from=c06_service]
## Хозяйку отключает (no_monster), кроме сценарных сцен; бессмертие включено.

var m: Node
var fails := 0
var ending := "last_steam"
var from := "c01_yard"
var t0 := 0.0


func _ready() -> void:
	m = Game.main
	Game.bot = true
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--ending="):
			ending = s.substr(9)
		if s.begins_with("--from="):
			from = s.substr(7)
	t0 = Time.get_ticks_msec() / 1000.0
	_run()


func log_(t: String) -> void:
	print("[бот %5.1f] %s" % [Time.get_ticks_msec() / 1000.0 - t0, t])


func check(cond: bool, what: String) -> void:
	if cond:
		log_("  ок: " + what)
	else:
		fails += 1
		var p: Player = Game.world.player if Game.world else null
		log_("  ОШИБКА: %s  (точка %s, игрок %s, комната %s)" % [what, Game.checkpoint, p.global_position if p else Vector3.ZERO, p.current_room if p else ""])


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func wait_world() -> void:
	while Game.world == null or not Game.world.ready_done:
		await get_tree().process_frame
	await wait(0.3)


func pl() -> Player:
	return Game.world.player


func tp(p: Vector3, yaw_deg := 0.0, pitch_deg := 0.0) -> void:
	pl().global_position = p
	pl().velocity = Vector3.ZERO
	pl().set_look(deg_to_rad(yaw_deg), deg_to_rad(pitch_deg))
	await get_tree().physics_frame
	await get_tree().physics_frame
	await wait(0.2)


func wait_flag(f: String, timeout := 20.0) -> bool:
	var t := 0.0
	while not Game.flag(f) and t < timeout:
		await get_tree().process_frame
		t += get_process_delta_time()
	return Game.flag(f)


## Найти интерактивный предмет по подсказке (подстрока) и применить (долгие — сразу завершить).
func use(sub: String, near := Vector3.INF) -> bool:
	var best: Node = null
	var bd := 1e9
	for n in Game.world.find_children("*", "", true, false):
		if not n.has_method("get_prompt") or not n.has_method("use"):
			continue
		var pr := String(n.get_prompt(pl()))
		if pr.find(sub) < 0:
			continue
		var d := 0.0
		if near != Vector3.INF and n is Node3D:
			d = (n as Node3D).global_position.distance_to(near)
		if d < bd:
			bd = d
			best = n
	if best == null:
		log_("  нет предмета: " + sub)
		fails += 1
		return false
	if best is Node3D:
		var bp := (best as Node3D).global_position
		var fp := Vector3(bp.x, pl().global_position.y, bp.z)
		pl().global_position = pl().global_position.lerp(fp, 0.0)
	if "progress" in best and "hold" in best and float(best.hold) > 0.0:
		if best.has_method("blocked") and String(best.blocked()) != "":
			log_("  заблокировано: %s — %s" % [sub, best.blocked()])
			fails += 1
			return false
	best.use(pl())
	log_("  применил: " + String(best.get_prompt(pl())) if is_instance_valid(best) else "  применил: " + sub)
	await wait(0.3)
	return true


func close_note() -> void:
	await wait(0.2)
	if m.overlay:
		m._close_overlay()


func _run() -> void:
	m.start_checkpoint(from, from != "c01_yard", from == "c01_yard")
	Game.admin = false
	await wait_world()
	Game.cheats["god"] = true
	Game.cheats["no_monster"] = true
	log_("старт с точки " + from + ", концовка " + ending)
	if from == "c01_yard":
		await prologue()
		await ch1()
		await ch2()
	if from in ["c01_yard", "c06_service"]:
		await ch3()
	await ch4()
	await finale()
	log_("ГОТОВО. Ошибок: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func prologue() -> void:
	log_("== пролог")
	await tp(Vector3(31.4, 0.05, 45.0), 0)
	await use("монтировку")
	check(Game.has("crowbar"), "монтировка")
	await use("телефонограмму")
	await close_note()
	check("telegram" in Game.notes, "телефонограмма прочитана")
	await tp(Vector3(26, 0.05, 31.6), 0)
	await use("Сорвать цепь")
	check(Game.flag("chain_broken"), "цепь сорвана")
	await use("Открыть", Vector3(26, 1, 30))
	await wait(1.0)
	await tp(Vector3(26, 0.05, 28.0), 0)
	check(Game.flag("inside"), "в бане")
	check(Game.checkpoint == "c02_lobby", "точка c02")


func ch1() -> void:
	log_("== глава 1")
	await tp(Vector3(26, 0.05, 25.0), 0)
	await wait(1.0)
	check(Game.flag("entrance_jammed"), "вход заклинило")
	await tp(Vector3(29.6, 0.05, 24.2), 0)
	await use("Сфотографировать")
	check(Game.flag("map"), "план сфотографирован")
	await tp(Vector3(15.2, 0.05, 28.8), -90)
	await use("Прочитать правила")
	await close_note()
	await tp(Vector3(19, 0.05, 22), 180)
	await use("Открыть", Vector3(19, 1, 20))
	await tp(Vector3(17.2, 0.05, 18.5), 90)
	await use("ключ «Подсобка")
	check(Game.has("key_util"), "ключ от подсобки")
	for n in ["Книга", "Приказ", "Несчастный"]:
		await use(n)
		await close_note()
	var ok := await wait_flag("phone_ringing", 40.0)
	check(ok, "телефон зазвонил")
	await tp(Vector3(16.6, 0.05, 24.4), 180)
	await use("Снять трубку")
	await wait(9.0)
	check(Game.flag("phone_answered"), "трубку сняли")
	await wait(5.0)
	check(Game.flag("footprints"), "следы появились")


func ch2() -> void:
	log_("== глава 2")
	await tp(Vector3(12.8, 0.05, 26.5), 90)
	check(Game.checkpoint == "c03_mlock", "точка c03")
	check(Game.flag("enc_prepared"), "души включены для встречи")
	# первая встреча: стоим неподвижно
	Game.cheats["no_monster"] = false
	await tp(Vector3(6.5, 0.05, 19.4), 0)
	pl().crouching = true
	var ok := await wait_flag("first_encounter", 45.0)
	check(ok, "первая встреча пройдена (стоя тихо)")
	Game.cheats["no_monster"] = true
	check(int(Game.getf("danger", 0)) == 1, "опасность 1")
	# подсобка
	await tp(Vector3(2.0, 0.05, 24.6), 180)
	await use("Отпереть")
	await tp(Vector3(2.2, 0.05, 28.6), 180)
	await use("ящик")
	await close_note()
	check(Game.has("wrench"), "газовый ключ")
	await tp(Vector3(1.0, 0.05, 27.6), -90)
	await use("горячую воду")
	check(Game.flag("lockhot_open"), "горячая вода в раздевальню")
	await wait(12.0)
	await tp(Vector3(7.9, 0.05, 28.0), 180)
	ok = await wait_flag("code_seen", 25.0)
	check(ok, "код увиден на зеркале")
	# дверь с кодом
	await tp(Vector3(11.0, 0.05, 4.2), 0)
	var d: Door = Game.world.doors["d_code_m"]
	d.code_ok()
	d.use(pl())
	await wait(1.0)
	check(not d.locked, "кодовая дверь открыта")
	await tp(Vector3(11.0, 0.05, 1.5), -90)
	check(Game.checkpoint == "c06_service", "точка c06")


func ch3() -> void:
	log_("== глава 3")
	await tp(Vector3(25.3, 0.05, 1.0), 0)
	await use("Открыть", Vector3(25.25, 1, 0))
	check(Game.flag("grate_seen"), "решётка заперта, новая цель")
	await tp(Vector3(41.0, 0.05, 2.0), 180)
	await use("Открыть", Vector3(41, 1, 3))
	await tp(Vector3(41.0, 0.05, 5.0), 180)
	check(Game.checkpoint == "c07_women", "точка c07")
	check(int(Game.getf("danger", 0)) >= 2, "опасность 2")
	await tp(Vector3(41.9, 0.05, 27.8), 180)
	await wait(1.0)
	check(Game.flag("mirror_scare"), "отражение в зеркале")
	await wait(2.0)
	await tp(Vector3(46.5, 0.05, 27.0), -90)
	await use("Открыть", Vector3(48, 1, 27))
	await tp(Vector3(49.8, 0.05, 25.8), 0)
	await use("тетрадь")
	await close_note()
	await use("Насосная")
	check(Game.has("key_pump"), "ключ от насосной")
	var ok := await wait_flag("lobby_flooded", 12.0)
	check(ok, "вестибюль затоплен")
	await tp(Vector3(34.0, 0.05, 1.5), 180)
	await use("Отпереть", Vector3(34, 1, 3))
	await tp(Vector3(36.5, 0.05, 4.4), -90)
	await use("спуск бассейна")
	check(Game.flag("pool_draining"), "слив открыт")
	Engine.time_scale = 8.0
	ok = await wait_flag("pool_clogged", 60.0)
	Engine.time_scale = 1.0
	check(ok, "слив забился")
	await tp(Vector3(31.8, Layout.POOL_DEEP + 0.05, 11.5), 90)
	await use("Вытащить волосы")
	await wait(4.0)
	check(Game.flag("pool_drained"), "бассейн спущен")
	await use("Вскрыть люк")
	check(Game.flag("hatch_open"), "люк открыт")
	await use("Спуститься")
	await wait(3.0)
	check(Game.flag("in_basement"), "спустился в коллектор")
	check(Game.checkpoint == "c10_collector", "точка c10")


func ch4() -> void:
	log_("== глава 4")
	await tp(Vector3(31.0, -4.45, 3.8), 0)
	await use("Сапоги")
	check(Game.flag("boots_seen"), "сапоги отца")
	await tp(Vector3(25.25, -4.3, -8.5), 0)
	check(Game.checkpoint == "c11_boiler", "точка c11")
	await tp(Vector3(17.0, -4.3, -11.0), -90)
	await use("Открыть", Vector3(16, -3.5, -11))
	await tp(Vector3(13.6, -4.4, -9.6), 0)
	await use("журнал")
	await close_note()
	await use("Последняя запись")
	await close_note()
	check(Game.flag("last_entry"), "последняя запись отца")
	await tp(Vector3(36.5, -4.4, -12.0), 0)
	await use("варежка")
	await wait(12.0)
	check(Game.flag("mitten_memory"), "воспоминание")
	await tp(Vector3(17.0, -4.3, -16.0), -90)
	await use("Открыть", Vector3(16, -3.5, -16))
	await tp(Vector3(12.0, -4.4, -16.2), 0)
	if ending != "open_tap":
		for i in 3:
			await use("Закрывать задвижку")
			await wait(1.5)
		check(Game.flag("valve_closed"), "задвижка закрыта")
		await wait(2.0)
		check(Game.checkpoint == "c12_valve", "точка c12")


func finale() -> void:
	log_("== финал: " + ending)
	if ending == "steam":
		await tp(Vector3(33.0, -4.4, -8.0), -90)
		await use("Открыть", Vector3(32, -3.5, -8))
		await tp(Vector3(35.0, -4.4, -6.6), 180)
		await use("Сесть на верхний полок")
		await use("Точно")
	else:
		if ending == "last_steam":
			await tp(Vector3(19.4, -4.3, -12.4), -90)
			await use("предохранительный клапан")
			await tp(Vector3(23.5, -4.3, -16.8), 0)
			await use("шибер")
			await tp(Vector3(20.0, -4.3, -10.4), 0)
			for i in 3:
				await use("Подкинуть угля")
			check(Game.flag("overheat"), "котёл перегревается")
		await tp(Vector3(35.0, -2.0, -16.6), 0)
		var hatch := Vector3(35.0, -1.5, -17.5)
		await use("Отгрести", hatch)
		await use("Вскрыть люк", hatch)
		await use("Вылезти наружу", hatch)
	await wait(4.0)
	check(ending in Game.endings_seen, "концовка «%s» открыта" % ending)
