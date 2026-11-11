extends Node
## Dev only: `-- --tour` saves screenshots of key places, `-- --bot` fast-forwards a night.

const M = preload("res://src/monster.gd")
var main: Node
var args: PackedStringArray
var g: Node


func _ready() -> void:
	AudioServer.set_bus_mute(0, true)
	main.data.admin = false
	main.start_game({})
	g = main.game
	await get_tree().create_timer(1.5).timeout
	if args.has("--tour"):
		await _tour()
	if args.has("--ui"):
		await _ui()
	if args.has("--bot"):
		await _bot()
	get_tree().quit()


func _shot(name: String, pos: Vector3, yaw_deg: float, pitch_deg: float = 0.0, wait: float = 0.7) -> void:
	var p: Node = g.player
	p.global_position = pos
	p.rotation.y = deg_to_rad(yaw_deg)
	p.pitch = deg_to_rad(pitch_deg)
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name)
	print("shot ", name)


func _tour() -> void:
	var p: Node = g.player
	var mo: Node = g.monster
	p.god = true
	g.time_frozen = true
	g.auto_events = false
	g.fade = 0.0
	await _shot("01_console", Vector3(-6.2, 0.05, -3.3), 90, -8)
	g.start_call(true, "v_r_hour", 1)
	await _shot("02_console_call", Vector3(-6.6, 0.05, -3.5), 90, -12, 1.0)
	g.rcall = {}
	await _shot("03_operator", Vector3(-2.6, 0.05, -1.6), 60)
	await _shot("04_corridor", Vector3(7.2, 0.05, 0), 90)
	await _shot("05_bunk", Vector3(0.5, 0.05, -1.5), 0)
	await _shot("06_kitchen", Vector3(1, 0.05, 1.5), 180)
	await _shot("07_generator", Vector3(-4.2, 0.05, 1.8), 125)
	await _shot("08_store", Vector3(5.5, 0.05, -1.6), 0)
	await _shot("09_wash", Vector3(6.2, 0.05, 1.7), 150)
	mo.watch(g.WINDOWS[0], 99.0)
	await _shot("10_window", Vector3(-4.4, 0.05, -2.6), 15, 0)
	mo.vanish()
	mo.place(Vector3(-3, 0, 0), M.S.SHOW)
	await _shot("11_monster_lit", Vector3(1.5, 0.05, 0), 90, 5)
	g.ev_stall()
	p.flash_on = true
	await _shot("12_monster_dark", Vector3(0.6, 0.05, 0), 90, 8, 1.0)
	p.flash_on = false
	await _shot("13_monster_nolight", Vector3(-0.8, 0.05, 0), 90, 12, 0.6)
	g.stalled = false
	mo.vanish()
	await _shot("14_outside_door", Vector3(16, 0.05, 2), 80, 0, 1.5)
	await _shot("15_shed", Vector3(33, 0.05, 13.5), -95, 0)
	await _shot("16_mast", Vector3(-5, 0.05, -34), 45, 10)
	p.flash_on = true
	mo.place(Vector3(-12, 0, -33), M.S.SHOW)
	await _shot("17_stalker", Vector3(-4, 0.05, -34), 95, 4)
	mo.vanish()
	p.flash_on = false
	g.fullbright = true
	await _shot("18_overview", Vector3(24, 14, 22), 40, -30, 1.5)
	await _shot("19_interior_bright", Vector3(7.2, 0.05, 0), 90, 0, 1.0)
	g.fullbright = false


func _bot() -> void:
	var p: Node = g.player
	var mo: Node = g.monster
	p.god = true
	g.fade = 0.0
	# --- nav sanity
	var path: Array = g.nav_path(Vector3(9, 0, 0), Vector3(-5, 0, -3))
	print("nav door->operator: ", path.size(), " pts ", path)
	print("nav door->mast: ", g.nav_path(Vector3(9, 0, 0), Vector3(-8, 0, -37)).size())
	# --- blackout: assault -> hunt -> restore -> flee
	g.ev_stall()
	var t: float = 0.0
	var seen: Dictionary = {}
	while t < 60.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
		seen[M.S.keys()[mo.st]] = true
		if mo.st == M.S.HUNT or mo.st == M.S.SEARCH:
			if t > 40.0:
				break
	print("blackout states: ", seen.keys(), " monster at ", mo.global_position, " door open ", g.world.front_door.open)
	g.stalled = false
	await get_tree().create_timer(6.0).timeout
	print("after power: ", M.S.keys()[mo.st])
	# --- hiding
	p.god = false
	p.hide_in(1)
	g.suppress(70.0)
	mo.vanish()
	mo.begin_hunt()
	Input.action_press("breath")
	var seen2: Dictionary = {}
	for i in 120:
		await get_tree().create_timer(0.5).timeout
		seen2[M.S.keys()[mo.st]] = true
		if i % 6 == 0:
			print("  hide ", i, " ", M.S.keys()[mo.st], " ", mo.global_position, " path ", mo.path, " lit ", g.lit())
		if mo.st == M.S.CHECK:
			Input.action_press("breath")
		elif p.breath < 30.0:
			Input.action_release("breath")
		if not g.running:
			break
	Input.action_release("breath")
	print("hide test: states ", seen2.keys(), " alive=", p.alive, " breath=", p.breath)
	if not g.running:
		print("BOT: died in locker")
		return
	p.unhide()
	p.god = true
	mo.vanish()
	g.suppress_t = 0.0
	# --- stalker
	p.global_position = Vector3(20, 0.05, 6)
	g.hour = 2.0
	await get_tree().create_timer(9.0).timeout
	print("outside: ", M.S.keys()[mo.st], " dist ", mo.global_position.distance_to(p.global_position))
	p.global_position = Vector3(-6.3, 0.05, -3)
	await get_tree().create_timer(7.0).timeout
	# --- fast night
	g.time_scale = 40.0
	g.fuel = 100.0
	var last: int = -1
	while g.running and not g.dawn and g.hour < 6.0:
		await get_tree().create_timer(0.1).timeout
		g.fuel = 100.0
		g.antenna_ok = true
		if not g.rcall.is_empty():
			if g.rcall.real:
				g.answer_call()
			else:
				g.reject_call()
		if int(g.hour) != last:
			last = int(g.hour)
			print("hour ", last, " answered ", g.answered, " missed ", g.missed, " monster ", M.S.keys()[mo.st])
	await get_tree().create_timer(1.0).timeout
	print("END: dawn=", g.dawn, " answered=", g.answered, " missed=", g.missed, " strikes=", g.strikes)


func _snap(name: String, wait: float = 0.6) -> void:
	await get_tree().create_timer(wait).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots"))
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % name)
	print("shot ", name)


func _ui() -> void:
	var p: Node = g.player
	var mo: Node = g.monster
	p.god = true
	g.time_frozen = true
	g.auto_events = false
	g.fade = 0.0
	mo.watch(g.WINDOWS[0], 99.0)
	await _shot("20_window2", Vector3(-4.6, 0.05, -2.8), 10, 0)
	mo.vanish()
	g.read_note(7)
	await _snap("21_note")
	g.hud._close_note()
	var a: Node = load("res://src/admin.gd").new()
	a.g = g
	g.add_child(a)
	a._toggle()
	await _snap("22_admin")
	a._toggle()
	p.hide_in(0)
	await _snap("23_locker")
	p.unhide()
	p.god = false
	p.global_position = Vector3(0, 0.05, 0)
	g.kill("monster")
	await _snap("24_jumpscare", 0.35)
	await _snap("25_death", 1.6)
	main.show_ending("replaced", {"answered": 3, "missed": 1, "strikes": 2, "notes": 5})
	await _snap("26_ending")
	main.show_menu()
	await _snap("27_menu")
	main.show_settings()
	await _snap("28_settings")
