class_name Scenario
extends Node
## Сюжет: состояние мира по флагам, сюжетные предметы, триггеры, сценарные пугалки, концовки.

const Y := Layout.BASE_Y

var w: World
var triggers := {}
var chain: Node3D
var phone_snd: AudioStreamPlayer3D
var sheet_man: Node3D
var pool_barrier: StaticBody3D
var drain_target := -99.0
var drain_speed := 0.0
var overheat_t := -1.0
var gauge: Node3D
var alarm: AudioStreamPlayer
var encounter := false
var enc_noise := false
var lobby_time := 0.0
var meter_spin := 0.0
var sacrifice_armed := 0.0
var hair_grate: Node3D
var unclog_scare := false
var ghost_mirror: HozBody
var mirror_scare_t := -1.0
var hatch_u: Usable


func setup(world: World) -> void:
	w = world
	_doors()
	_lines()
	var cp: Array = Texts.CHECKPOINTS.get(Game.checkpoint, Texts.CHECKPOINTS["c01_yard"])
	w.spawn_pos = cp[1]
	w.spawn_yaw = cp[2]
	_prologue_objects()
	_ch1_objects()
	_ch2_objects()
	_ch3_objects()
	_ch4_objects()
	_triggers()


func start() -> void:
	if Game.flag("free_walk"):
		for id in w.doors:
			(w.doors[id] as Door).locked = false
		w.player.global_position = Vector3(26.0, 0.05, 28.0)
		w.player.set_look(0.0)
		Game.set_objective("Свободный обход: всё открыто. F1 — панель, F2 — полёт.")
		_ambience()
		return
	var obj := String(Game.getf("obj", ""))
	if obj != "":
		Game.set_objective(Texts.OBJECTIVES.get(obj, ""))
	if Game.checkpoint == "c01_yard" and not Game.flag("intro_done"):
		_intro()
	if Game.checkpoint == "c13_fire":
		_start_overheat(true)
	_ambience()


func obj(id: String) -> void:
	Game.set_flag("obj", id)
	Game.set_objective(Texts.OBJECTIVES[id])


func msg(id: String, delay := 0.0) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if Game.world != w:
		return
	Game.add_message(id)
	if not Game.mute_phone:
		Snd.play("phone_ping", -4.0)
		if w.player:
			w.noise(w.player.global_position, 12.0, "phone")


func cp(id: String) -> void:
	var order := Texts.CHECKPOINTS.keys()
	if order.find(id) <= order.find(Game.checkpoint):
		return
	Game.reach_checkpoint(id)
	if Game.main and Game.main.has_method("toast"):
		Game.main.toast("Сохранено")


func wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


# ---------------------------------------------------------------- двери, водопровод

func _door(id: String) -> Door:
	return w.doors.get(id)


func _doors() -> void:
	var d := _door("d_entrance")
	d.locked = true
	d.lock_text = "Заперто на цепь с замком."
	if Game.flag("chain_broken"):
		d.locked = false
	if Game.flag("entrance_jammed"):
		d.locked = true
		d.lock_text = "Не открывается. Заклинило — будто держат с той стороны."
	d.on_locked = func():
		if not Game.flag("chain_broken") and Game.has("crowbar"):
			Game.think("Цепь. Монтировкой сорву.", 2.5)
		else:
			Game.think(d.lock_text, 3.0)
	var f := _door("d_lobby_f")
	f.locked = true
	f.lock_text = "Заперто изнутри на засов."
	f.on_locked = func():
		if w.player.current_room == "f_lock":
			f.locked = false
			Snd.at("unlock", f.global_position + Vector3.UP, 0.0, 0.7)
			Game.think("Засов отодвинул. Теперь отсюда можно выйти в вестибюль.", 3.0)
			f.save_state()
		else:
			Game.think(f.lock_text, 3.0)
	var u := _door("d_m_util")
	u.locked = true
	u.key = "key_util"
	u.lock_text = "Подсобка. Заперто."
	var c := _door("d_code_m")
	c.locked = true
	c.code = "2112"
	c.lock_text = "Кнопочный кодовый замок. «Посторонним вход воспрещён»."
	c.on_open = func(): pass
	for pid in ["d_pump_pool", "d_pump_service"]:
		var p := _door(pid)
		p.locked = true
		p.key = "key_pump"
		p.lock_text = "Насосная. Заперто."
	var g := _door("d_grate")
	g.locked = true
	g.lock_text = "Решётка на висячем замке — замок с той стороны. Внизу горит топка."
	g.on_locked = func():
		if w.player.current_room == "b_stairs":
			g.locked = false
			Snd.at("unlock", g.global_position + Vector3.UP, 0.0, 0.8)
			Game.think("Замок изнутри открывается просто. Путь наверх свободен.", 3.0)
			g.save_state()
		else:
			Game.think(g.lock_text, 3.5)
			if not Game.flag("grate_seen"):
				Game.set_flag("grate_seen")
				obj("o_pumpkey")
	# полуоткрытые для атмосферы
	for oid in ["d_m_wash_b", "d_f_wash_a", "d_linen"]:
		var od := _door(oid)
		if Game.flags.get("door:" + oid) == null:
			od.set_open(0.3, true)
	for id in w.doors:
		(w.doors[id] as Door)._restore()


func _lines() -> void:
	for l in ["m_wash", "f_wash"]:
		if Game.flags.get("line:" + l) == null:
			Game.flags["line:" + l] = true


# ---------------------------------------------------------------- пролог

func _intro() -> void:
	Game.set_flag("intro_done")
	if Game.main and Game.main.has_method("fade_in"):
		Game.main.fade_in(3.0)
	Snd.play("van_door", -6.0)
	Game.show_hint("WASD — идти, мышь — смотреть, E — действие, F — фонарь, Tab — телефон, Shift — бежать, Ctrl — пригнуться", 9.0)
	await wait(2.5)
	Game.think("23:46. Коммунальная, 12.", 3.0)
	msg("m01")
	msg("m02", 4.0)
	await wait(6.0)
	obj("o_crowbar")
	msg("m03", 8.0)
	await wait(14.0)
	Game.add_message("r01")
	Game.think("Пар из вентиляции. Окна мыльной светятся… А снег у дверей нетронутый. Ни одного следа.", 5.0)


func _prologue_objects() -> void:
	var ext: Node3D = w.get_node("yard")
	# монтировка в кузове фургона
	if not Game.has("crowbar"):
		var u := Items.pickup(ext, Vector3(31.4, 0.75, 44.0), "item", "crowbar", "Взять монтировку", null, func():
			Game.think("Монтировка. Пригодится.", 2.0)
			obj("o_enter"))
		Props.model(u, "crowbar_01", Vector3(31.4, 0.62, 44.0), 0.3)
	# телефонограмма на сиденье
	if not "telegram" in Game.notes:
		var vis2 := Items.paper_visual("res://tex/gen/note_telegram.png", Vector2(0.21, 0.28))
		Items.pickup(ext, Vector3(32.75, 0.62, 44.15), "note", "telegram", "Прочитать телефонограмму", vis2)
	# цепь на двери
	if not Game.flag("chain_broken"):
		chain = Node3D.new()
		ext.add_child(chain)
		chain.global_position = Vector3(26.0, 1.1, 30.42)
		var m := Mat.flat(Color(0.3, 0.28, 0.26), 0.5, 0.9)
		for i in 9:
			var link := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.018
			tm.outer_radius = 0.032
			link.mesh = tm
			link.material_override = m
			link.position = Vector3(-0.32 + i * 0.08, sin(i * 0.4) * 0.03, 0.02)
			link.rotation = Vector3(PI * 0.5 if i % 2 == 0 else 0.0, 0, PI * 0.5)
			chain.add_child(link)
		Geo.mesh_box(chain, Vector3(0.07, 0.09, 0.03), Mat.flat(Color(0.5, 0.45, 0.3), 0.4, 0.9), Vector3(0.05, -0.08, 0.04))
		var u2 := Usable.make(ext, Vector3(26.0, 1.1, 30.6), Vector3(1.0, 0.6, 0.3), "Сорвать цепь монтировкой", func():
			Snd.at("chain_break", Vector3(26, 1.1, 30.5), 2.0)
			chain.queue_free()
			Game.set_flag("chain_broken")
			_door("d_entrance").locked = false
			_door("d_entrance").save_state()
			Game.think("Готово.", 1.5), 2.5)
		u2.once = true
		u2.hold_sound = "loop_pry"
		u2.cond = func(): return "" if Game.has("crowbar") else "Цепь с замком. Нужна монтировка — в фургоне."
		u2.prompt_fn = func(): return "Сорвать цепь монтировкой" if Game.has("crowbar") else "Цепь с замком"


# ---------------------------------------------------------------- глава 1

func _ch1_objects() -> void:
	var lob: Node3D = w.rooms["lobby"]["node"]
	# правила на стене у мужского отделения
	var rb := Props.picture(lob, "res://tex/gen/rules.png", Vector3(14.13, 1.6, 28.8), Vector3(1, 0, 0), Vector2(0.62, 0.82))
	var ru := Usable.make(lob, Vector3(14.2, 1.6, 28.8), Vector3(0.1, 0.8, 0.62), "Прочитать правила", func():
		Game.add_note("rules")
		Game.main.show_note("rules"))
	# план эвакуации
	var pu := Usable.make(lob, Vector3(29.6, 1.6, 23.2), Vector3(1.0, 0.6, 0.1), "Сфотографировать план эвакуации", func():
		Snd.play("camera_shutter", -2.0)
		Game.set_flag("map")
		Game.show_hint("План сохранён в телефоне: Tab → «План»", 4.0)
		if String(Game.getf("obj", "")) in ["o_way", "o_enter", ""]:
			obj("o_util"))
	pu.prompt_fn = func(): return "" if Game.flag("map") else "Сфотографировать план эвакуации"
	# доска почёта: фото отца
	var hu := Usable.make(lob, Vector3(24.45 + 0.7, 1.8, 23.22), Vector3(0.5, 0.6, 0.1), "Доска почёта", func():
		Game.set_flag("honor_seen")
		Game.think("«Ковалёв Николай Андреевич, истопник». Отец. Я его таким и не помню.", 5.0))
	hu.prompt_fn = func(): return "Посмотреть на фото" if not Game.flag("honor_seen") else ""
	# затопленная лестница
	Usable.make(lob, Vector3(34.5, 0.6, 26.2), Vector3(3.0, 1.0, 0.3), "Лестница в подвал", func():
		Game.think("Подвал под вестибюлем затоплен. Вода тёплая, над ней пар. Туда не пройти.", 4.0))
	# телефон в кассе
	var phone := Node3D.new()
	lob.add_child(phone)
	phone.global_position = Vector3(16.2, 0.875, 25.15)
	var pm := Mat.flat(Color(0.12, 0.1, 0.09), 0.4, 0.2)
	Geo.mesh_box(phone, Vector3(0.22, 0.09, 0.2), pm, Vector3(0, 0.045, 0))
	Geo.mesh_box(phone, Vector3(0.24, 0.05, 0.06), pm, Vector3(0, 0.11, 0))
	Geo.mesh_cyl(phone, 0.06, 0.01, Mat.flat(Color(0.7, 0.7, 0.65), 0.4, 0.6), Vector3(0, 0.095, 0.05)).rotation.x = 0.3
	var phu := Usable.make(lob, Vector3(16.2, 1.0, 25.15), Vector3(0.4, 0.3, 0.4), "Снять трубку", _answer_phone)
	phu.prompt_fn = func(): return "Снять трубку" if Game.flag("phone_ringing") else ("" if Game.flag("phone_answered") else "Телефон. Гудка нет")
	phu.cond = func(): return "" if Game.flag("phone_ringing") else "Мёртвая линия. Ни гудка."
	# кабинет: ключница, бумаги на столе
	var off: Node3D = w.rooms["office"]["node"]
	if not Game.has("key_util") and not Game.flag("took:key_util"):
		Items.pickup(off, Vector3(16.25, 1.58, 18.52), "item", "key_util", "Взять ключ «Подсобка муж. отд.»", Items.key_visual(), func():
			Game.think("Ключ от подсобки мужского отделения. Остальные крючки пустые… кроме «Тех. коридор» — нет ключа.", 4.0)
			obj("o_util2"))
	for n in [["complaints", Vector3(18.6, 0.92, 17.75)], ["order", Vector3(19.4, 0.92, 17.8)], ["clip_1979", Vector3(20.1, 0.92, 17.7)]]:
		if not n[0] in Game.notes:
			Items.pickup(off, n[1], "note", n[0], "Прочитать: " + Texts.note(n[0])["title"], Items.paper_visual("res://tex/gen/note_%s.png" % n[0]))
	# батарейки по зданию
	var bats := [["bat1", "linen", Vector3(23.4, 1.03, 17.45)], ["bat2", "buffet", Vector3(34.6, 1.14, 17.5)],
		["bat3", "m_util", Vector3(0.45, 1.38, 28.5)], ["bat4", "f_attend", Vector3(50.0, 0.78, 25.2)],
		["bat5", "stoker", Vector3(13.8, Y + 0.78, -8.8)], ["bat6", "pump", Vector3(37.4, 0.1, 5.6)]]
	for bt in bats:
		Items.pickup(w.rooms[bt[1]]["node"], bt[2], "battery", bt[0], "Взять батарейки", Items.battery_visual())


func _answer_phone() -> void:
	Game.set_flag("phone_ringing", false)
	Game.set_flag("phone_answered")
	if phone_snd:
		phone_snd.queue_free()
	Snd.play("phone_pickup", -2.0)
	w.player.input_lock = true
	await wait(0.6)
	var p := Snd.play("phone_call", 0.0, 1.0, "Voice")
	Game.think("…капает вода. Кто-то дышит в трубку. Совсем близко.", 4.0)
	await wait(5.5)
	Game.think("«…пар… готов…»", 3.0)
	await wait(3.0)
	Snd.play("phone_hangup", -2.0)
	w.player.input_lock = false
	Game.think("Гудки. Линия мёртвая уже двадцать лет.", 3.0)
	msg("m04", 7.0)
	# следы появляются после звонка
	_footprints_scare()


func _footprints_scare() -> void:
	await wait(4.0)
	if Game.world != w:
		return
	Game.set_flag("footprints")
	var lob: Node3D = w.rooms["lobby"]["node"]
	Props.footprints(lob, Vector3(26.0, 0, 29.6), Vector3(14.6, 0, 26.5), "lobby")
	Snd.at("hoz_step", Vector3(10.0, 0.3, 25.0), -8.0, 0.9, 25.0)


func _ring_phone() -> void:
	if Game.flag("phone_answered") or Game.flag("phone_ringing"):
		return
	Game.set_flag("phone_ringing")
	var lob: Node3D = w.rooms["lobby"]["node"]
	var n := Node3D.new()
	lob.add_child(n)
	n.global_position = Vector3(16.2, 1.0, 25.15)
	phone_snd = Snd.attach("loop_phone_ring", n, 2.0, 40.0)
	Game.show_hint("Звонит телефон в кассе.", 3.0)


# ---------------------------------------------------------------- глава 2

func _ch2_objects() -> void:
	var ml: Node3D = w.rooms["m_lock"]["node"]
	# фигура под простынёй на скамье
	if not Game.flag("first_encounter"):
		sheet_man = _make_sheet_man(ml, Vector3(8.7, 0.0, 27.05), PI)
	else:
		var sheet := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(1.4, 1.1)
		sheet.mesh = pm
		sheet.material_override = Mat.picture("res://tex/gen/sheet.png")
		ml.add_child(sheet)
		sheet.global_position = Vector3(8.4, 0.02, 27.6)
		sheet.rotation.y = 0.4
	# ящик отца в подсобке
	var ut: Node3D = w.rooms["m_util"]["node"]
	Props.model(ut, "metal_toolbox", Vector3(2.2, 0.83, 29.6), PI)
	var tb := Usable.make(ut, Vector3(2.2, 0.95, 29.6), Vector3(0.6, 0.3, 0.35), "Открыть ящик с инструментом", func():
		Snd.at("toolbox", Vector3(2.2, 0.95, 29.6), -2.0)
		Game.give("wrench")
		Game.set_flag("wrench_taken")
		Game.add_note("father_note")
		Game.main.show_note("father_note")
		obj("o_code")
		cp("c05_code"))
	tb.once = true
	if Game.flag("wrench_taken"):
		tb.queue_free()
	# вентиль горячей воды на раковины раздевальни
	var v := Items.valve(ut, Vector3(0.32, 1.3, 27.6), -PI * 0.5, 0.11, "Открыть горячую воду: «Раздевальня»", 3.0, func():
		Game.set_flag("line:m_lock", true)
		Game.set_flag("lockhot_open")
		Snd.play("pipe_bang", 0.0, 1.0, "Amb")
		Game.think("Трубы загудели. В раздевальне пошла вода.", 3.0)
		for t in w.taps:
			if t.line == "m_lock":
				t.set_running(true)
		w.noise(Vector3(8, 1, 29), 20.0, "work"), Callable(), 12.0)
	v.cond = func(): return "" if Game.has("wrench") else "Вентиль прикипел намертво. Нужен газовый ключ."
	v.prompt_fn = func(): return "" if Game.flag("lockhot_open") else "Открыть горячую воду: «Раздевальня»"
	v.once = true
	if Game.flag("lockhot_open"):
		v.collision_layer = 0
	# мыльная: свечи на средней лавке
	var mw: Node3D = w.rooms["m_wash"]["node"]
	for i in 4:
		Items.candle(mw, Vector3(7.0 + randf_range(-0.15, 0.15), 0.51, 12.6 + i * 0.5))
	# шкафчик хлопает сам — внутри «подарок»
	var gift := Usable.make(ml, Vector3(10.8, 1.1, 29.4), Vector3(0.5, 0.6, 0.3), "Заглянуть в шкафчик", func():
		Game.think("Сложенное полотенце и кусок мыла. Свежий, мокрый. Будто приготовили. Для гостя.", 4.0))
	gift.once = true


func _make_sheet_man(parent: Node3D, pos: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	root.rotation.y = yaw
	var ps: PackedScene = load("res://mdl/rb/man/man.fbx")
	var m: Node3D = ps.instantiate()
	root.add_child(m)
	m.rotation.y = HozBody.MODEL_YAW
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://tex/gen/sheet.png")
	mat.roughness = 0.95
	mat.grow = true
	mat.grow_amount = 0.035
	var sk: Skeleton3D = m.get_node("Skeleton3D")
	for c in sk.get_children():
		if c is MeshInstance3D:
			for s in (c as MeshInstance3D).mesh.get_surface_count():
				(c as MeshInstance3D).set_surface_override_material(s, mat)
	var ap: AnimationPlayer = m.get_node("AnimationPlayer")
	var sit: Node = (load("res://mdl/rb/anim/m_sit.fbx") as PackedScene).instantiate()
	var a: Animation = (sit.get_node("AnimationPlayer") as AnimationPlayer).get_animation((sit.get_node("AnimationPlayer") as AnimationPlayer).get_animation_list()[0]).duplicate(true)
	sit.free()
	for t in range(a.get_track_count() - 1, -1, -1):
		if "Footsteps" in str(a.track_get_path(t)) or "Helper" in str(a.track_get_path(t)):
			a.remove_track(t)
	var lib := AnimationLibrary.new()
	lib.add_animation("sit", a)
	if ap.has_animation_library(""):
		ap.remove_animation_library("")
	ap.add_animation_library("", lib)
	ap.play("sit")
	ap.advance(0.0)
	ap.active = false
	var hi := sk.find_bone("Bip01 Head")
	sk.set_bone_pose_rotation(hi, sk.get_bone_pose_rotation(hi) * Quaternion(Vector3(0, 0, 1), 0.5))
	root.set_meta("sk", sk)
	return root


func _first_encounter() -> void:
	if Game.flag("first_encounter") or encounter:
		return
	encounter = true
	var hoz: Hozyayka = w.monster
	var pl := w.player
	Game.set_flag("dir_hold")
	# сцена уже готова: души шумят, пар, она сидит и моет волосы
	hoz.visible = true
	hoz.set_state(Hozyayka.S.SCRIPT)
	hoz.global_position = Vector3(5.6, 0.0, 14.0)
	hoz.rotation.y = 0.0
	hoz.body.play("crouch", 0.0)
	hoz.body.rig.crawl = 0.3
	hoz.body.floor_y = 0.0
	var wash := Snd.attach("loop_hoz_wash", hoz, 0.0, 16.0)
	Game.show_hint("Не шуми.", 3.0)
	enc_noise = false
	var cb := func(p: Vector3, r: float, kind: String):
		if kind in ["step", "door", "throw", "breath", "work"] and r >= 4.0 and p.distance_to(hoz.global_position) < r + 2.0:
			enc_noise = true
	w.noise_made.connect(cb)
	# ждём, пока игрок подойдёт или пройдёт время
	var t := 0.0
	while t < 6.0 and pl.global_position.distance_to(hoz.global_position) > 5.5 and not enc_noise:
		await get_tree().process_frame
		t += get_process_delta_time()
	# телефон звякает — она замирает
	Game.add_message("m05")
	Snd.play("phone_ping", -2.0)
	if wash:
		wash.queue_free()
	await wait(0.5)
	hoz.body.play("look", 0.4, 0.6)
	hoz.body.rig.twitch = 0.8
	Snd.at("hoz_sniff", hoz.global_position + Vector3.UP * 1.5, 2.0, 1.0, 16.0)
	Game.show_hint("Замри. Не двигайся. Можно только пригнуться (Ctrl).", 5.0)
	await wait(2.5)
	enc_noise = false
	# встаёт и идёт мимо игрока к дальнему трапу
	hoz.body.rig.crawl = 0.0
	var pp := Vector3(pl.global_position.x, 0.0, minf(pl.global_position.z, 18.7))
	var side := Vector3(1.2, 0, 0) if pp.x < 7.0 else Vector3(-1.2, 0, 0)
	var waypoints := [Vector3(5.6, 0, 18.6), pp + side + Vector3(0, 0, -0.4), Vector3(8.75, 0, 18.6), Vector3(8.75, 0, 10.6), Vector3(12.0, 0, 10.0)]
	for wp in waypoints:
		while hoz.global_position.distance_to(wp) > 0.3:
			if enc_noise and not Game.cheats.get("god", false):
				w.noise_made.disconnect(cb)
				encounter = false
				Game.set_flag("dir_hold", false)
				Game.set_flag("death_hint", 0)
				hoz.set_state(Hozyayka.S.RUSH)
				hoz.kill()
				return
			var dir: Vector3 = wp - hoz.global_position
			dir.y = 0
			var step := minf(dir.length(), 1.0 * get_process_delta_time())
			hoz.global_position += dir.normalized() * step
			hoz._face(wp, get_process_delta_time() * 3.0)
			hoz.body.play("walk", 0.5, 0.9)
			if hoz.global_position.distance_to(pl.global_position) < 2.5 and randf() < 0.01:
				Snd.at("hoz_sniff", hoz.global_position + Vector3.UP * 2.0, 0.0, 0.9, 10.0)
			await get_tree().process_frame
	w.noise_made.disconnect(cb)
	# уходит в трап
	hoz.set_state(Hozyayka.S.EMERGE)
	hoz.submerge()
	await wait(3.5)
	hoz.vanish()
	for tp in w.taps:
		if tp.line == "m_shower":
			tp.set_running(false, true)
	Game.set_flag("line:m_shower", false)
	Snd.play("pipe_knock", -6.0, 0.8, "Amb")
	Game.set_flag("first_encounter")
	Game.set_flag("danger", 1)
	Game.set_flag("dir_hold", false)
	encounter = false
	if sheet_man:
		sheet_man.queue_free()
	await wait(2.0)
	Game.think("Что… это было.", 3.0)
	await wait(3.0)
	Game.show_hint("Она слепая и идёт на звук. В телефоне (Tab) можно включить «Без звука».", 6.0)
	cp("c04_mwash")
	msg("m06", 25.0)


func _prepare_encounter() -> void:
	if Game.flag("first_encounter") or Game.flag("enc_prepared"):
		return
	Game.set_flag("enc_prepared")
	Game.flags["line:m_shower"] = true
	for t in w.taps:
		if t.line == "m_shower":
			t.set_running(true, true)
	w.add_steam("m_wash", 0.3)
	w.add_steam("m_shower", 0.5)


func _behind_tutorial() -> void:
	if Game.flag("behind_tutorial"):
		return
	Game.set_flag("behind_tutorial")
	var hoz: Hozyayka = w.monster
	if hoz.state != Hozyayka.S.GONE:
		return
	hoz.visible = true
	hoz.set_state(Hozyayka.S.ROAM)
	hoz.body.model.position.y = 0.0
	hoz.body.set_clip(-1000.0)
	Snd.play("pipe_knock", -8.0, 1.0, "Amb")
	await wait(1.0)
	hoz.start_behind()


# ---------------------------------------------------------------- глава 3

func _ch3_objects() -> void:
	# гребёнки душевых в техническом коридоре — можно увести её водой
	var sv: Node3D = w.rooms["service"]["node"]
	for d in [["m_shower", Vector3(9.4, 1.3, 2.86), "Души мужского отделения"], ["f_shower", Vector3(42.6, 1.3, 2.86), "Души женского отделения"]]:
		var line: String = d[0]
		var u := Items.valve(sv, d[1], 0.0, 0.1, "", 1.2, func():
			var on := not bool(Game.getf("line:" + line, false))
			Game.set_flag("line:" + line, on)
			for t in w.taps:
				if t.line == line:
					t.set_running(on)
			Snd.play("pipe_bang", -4.0, 1.1, "Amb"), Callable(), 8.0)
		u.prompt_fn = func(): return ("Перекрыть: " if Game.getf("line:" + line, false) else "Открыть: ") + String(d[2])
	# тетрадь банщицы и ключ от насосной
	var at: Node3D = w.rooms["f_attend"]["node"]
	if not "attend_notebook" in Game.notes:
		Items.pickup(at, Vector3(49.6, 0.9, 24.95), "note", "attend_notebook", "Прочитать тетрадь банщицы", Items.paper_visual("res://tex/gen/note_attend_notebook.png"))
	if not Game.has("key_pump") and not Game.flag("took:key_pump"):
		Items.pickup(at, Vector3(50.2, 0.9, 25.1), "item", "key_pump", "Взять ключ «Насосная»", Items.key_visual(), func():
			Game.set_flag("pump_key")
			obj("o_drain")
			_flood_lobby())
	# вентиль спуска бассейна
	var pm: Node3D = w.rooms["pump"]["node"]
	var dv := Items.valve(pm, Vector3(37.84, 1.25, 4.3), PI * 0.5, 0.18, "Открыть спуск бассейна", 4.0, func():
		Game.set_flag("pool_draining")
		Snd.play("pipe_bang", 0.0, 0.9, "Amb")
		Game.think("Пошла. Слышно, как уходит вода.", 3.0)
		drain_target = Layout.POOL_SHALLOW
		drain_speed = 0.03
		_pool_shape_scare(), Callable(), 12.0)
	dv.cond = func(): return "" if Game.has("wrench") else "Не провернуть руками."
	dv.prompt_fn = func(): return "" if Game.flag("pool_draining") or Game.flag("pool_drained") else "Открыть спуск бассейна"
	# барьер вокруг полной чаши
	pool_barrier = StaticBody3D.new()
	w.add_child(pool_barrier)
	var b := Layout.POOL_BASIN
	for e in [[Vector3(b.get_center().x, 0.6, b.position.y), Vector3(b.size.x, 1.2, 0.1)], [Vector3(b.get_center().x, 0.6, b.end.y), Vector3(b.size.x, 1.2, 0.1)],
			[Vector3(b.position.x, 0.6, b.get_center().y), Vector3(0.1, 1.2, b.size.y)], [Vector3(b.end.x, 0.6, b.get_center().y), Vector3(0.1, 1.2, b.size.y)]]:
		Geo.col_box(pool_barrier, e[0], e[1])
	_update_pool_barrier()
	# решётка слива (забита волосами)
	var pl_node: Node3D = w.rooms["pool"]["node"]
	var gu := Usable.make(pl_node, Vector3(32.2, Layout.POOL_DEEP + 0.25, 11.5), Vector3(0.7, 0.5, 0.7), "Вытащить волосы из решётки", func():
		_unclogged(), 6.0)
	gu.cond = func(): return "" if Game.flag("pool_clogged") else "Решётка слива. Под водой."
	gu.prompt_fn = func(): return "Вытащить волосы из решётки" if Game.flag("pool_clogged") and not Game.flag("pool_drained") else ""
	gu.hold_sound = "loop_hair_pull"
	gu.set_meta("unclog", true)
	# лесенка из глубокой части
	var lad := Mat.m("rust", {"metal": 0.8, "tint": Color(1.2, 1.2, 1.2)})
	var lb := Geo.Batch.new()
	for dz in [-0.25, 0.25]:
		lb.cyl(lad, Vector3(32.95, Layout.POOL_DEEP, 13.6 + dz), Vector3(32.95, 0.9, 13.6 + dz), 0.022, 6)
		lb.cyl(lad, Vector3(32.95, 0.9, 13.6 + dz), Vector3(33.4, 0.9, 13.6 + dz), 0.022, 6)
	for k in 7:
		lb.cyl(lad, Vector3(32.92, Layout.POOL_DEEP + 0.3 + k * 0.3, 13.35), Vector3(32.92, Layout.POOL_DEEP + 0.3 + k * 0.3, 13.85), 0.016, 6)
	lb.commit(pl_node, "ladder")
	var lu := Usable.make(pl_node, Vector3(32.8, Layout.POOL_DEEP + 1.0, 13.6), Vector3(0.4, 1.4, 0.8), "Вылезти по лесенке", func():
		_climb(Vector3(33.6, 0.05, 13.6), -PI * 0.5))
	lu.prompt_fn = func(): return "Вылезти по лесенке" if w.player.global_position.y < -0.5 else ""
	# люк в дне
	var hatch := Node3D.new()
	pl_node.add_child(hatch)
	hatch.global_position = Vector3(30.5, Layout.POOL_DEEP + 0.01, 11.5)
	var hm := Mat.m("rust", {"metal": 0.6})
	var hmi := Geo.mesh_box(hatch, Vector3(0.8, 0.04, 0.8), hm, Vector3(0, 0.02, 0))
	hmi.name = "lid"
	if Game.flag("hatch_open"):
		hmi.position = Vector3(0.75, 0.02, 0)
	var hu := Usable.make(pl_node, Vector3(30.5, Layout.POOL_DEEP + 0.2, 11.5), Vector3(0.9, 0.4, 0.9), "Вскрыть люк монтировкой", func():
		if not Game.flag("hatch_open"):
			Game.set_flag("hatch_open")
			Snd.at("hatch_open", hatch.global_position, 2.0)
			var t := create_tween()
			t.tween_property(hmi, "position:x", 0.75, 0.6)
			hatch_u.hold = 0.0
			hatch_u.used = false
		else:
			_descend(), 2.5)
	hatch_u = hu
	hu.hold_sound = "loop_pry"
	hu.hold_noise = 8.0
	hu.cond = func(): return "" if Game.flag("pool_drained") else "Люк под водой."
	hu.prompt_fn = func():
		if not Game.flag("pool_drained"):
			return ""
		return "Вскрыть люк монтировкой" if not Game.flag("hatch_open") else "Спуститься в коллектор"
	# фиксируем «удержание» только для вскрытия
	hu.set_meta("hatch", true)
	if Game.flag("hatch_open"):
		hu.hold = 0.0


func _update_pool_barrier() -> void:
	if pool_barrier:
		pool_barrier.collision_layer = 1 if w.pool_level > -1.0 else 0


func _flood_lobby() -> void:
	if Game.flag("lobby_flooded"):
		return
	await wait(6.0)
	if Game.world != w:
		return
	Game.set_flag("lobby_flooded")
	Game.set_flag("salt_gone_lobby")
	Snd.play("water_gush", 0.0, 1.0, "Amb")
	Game.think("Где-то хлынула вода. Со стороны вестибюля… Подвал под ним переполнился. Соль на порогах смоет.", 5.0)
	_apply_flood()
	msg("m07", 4.0)


func _apply_flood() -> void:
	var r: Rect2 = w.rooms["lobby"]["rect"]
	var mat := w._water_mat(0.4, 0.45)
	var p := w._water_plane("lobby_flood", r.grow(-0.15), 0.035, mat)
	(w.waters["lobby_stairs"] as MeshInstance3D).global_position.y = 0.02
	w.drains.append({"pos": Vector3(34.5, 0.0, 24.6), "room": "lobby"})


func _pool_shape_scare() -> void:
	# что-то тёмное проплывает под чёрной водой
	await wait(5.0)
	if w.player.current_room != "pool":
		return
	var shape := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.8, 2.4)
	shape.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0, 0, 0, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shape.material_override = m
	w.add_child(shape)
	shape.global_position = Vector3(20.5, w.pool_level - 0.25, 9.5)
	shape.rotation.y = -0.6
	Snd.at("water_swirl", Vector3(26, w.pool_level, 11.5), 0.0, 0.8, 20.0)
	var t := create_tween()
	t.tween_property(shape, "global_position", Vector3(31.0, w.pool_level - 0.35, 13.5), 4.0)
	t.tween_callback(shape.queue_free)


func _unclogged() -> void:
	Game.set_flag("pool_clogged", false)
	Game.set_flag("pool_drained")
	Snd.play("drain_whoosh", 2.0, 1.0, "Amb")
	drain_target = Layout.POOL_DEEP - 0.05
	drain_speed = 0.25
	if hair_grate:
		hair_grate.queue_free()
	Game.think("Пошла! Скорее наверх, по лесенке.", 3.0)
	obj("o_hatch")


func _climb(to: Vector3, yaw: float) -> void:
	var pl := w.player
	pl.input_lock = true
	Snd.play("ladder", -2.0)
	var t := create_tween()
	t.tween_property(pl, "global_position", to + Vector3(0, 0.3, 0), 1.2).set_trans(Tween.TRANS_SINE)
	await t.finished
	pl.set_look(yaw, 0.0)
	pl.input_lock = false
	if Game.flag("pool_drained") and not Game.flag("cp9"):
		Game.set_flag("cp9")
		cp("c09_drained")


func _descend() -> void:
	var pl := w.player
	pl.input_lock = true
	if Game.main and Game.main.has_method("fade_out"):
		Game.main.fade_out(0.8)
	Snd.play("ladder", -2.0)
	await wait(1.0)
	pl.global_position = Vector3(31.0, Y + 0.1, 11.0)
	pl.set_look(0.0, 0.0)
	await wait(0.4)
	if Game.main and Game.main.has_method("fade_in"):
		Game.main.fade_in(1.2)
	pl.input_lock = false
	Game.set_flag("in_basement")
	Game.set_flag("danger", 3)
	obj("o_valve")
	cp("c10_collector")
	Game.think("Коллектор. Воды по щиколотку. Тут всё в волосах.", 4.0)
	msg("m09", 30.0)


# ---------------------------------------------------------------- глава 4

func _ch4_objects() -> void:
	var col: Node3D = w.rooms["collector"]["node"]
	var bu := Usable.make(col, Vector3(31.3, Y + 0.25, 3.2), Vector3(0.6, 0.5, 0.6), "Сапоги", func():
		Game.set_flag("boots_seen")
		Game.think("Резиновые сапоги. Сорок четвёртый, левый подклеен. Отцовские. Он в них на смену ходил.", 5.0))
	bu.prompt_fn = func(): return "" if Game.flag("boots_seen") else "Сапоги"
	# котельная
	var bo: Node3D = w.rooms["boiler"]["node"]
	Props.wall_note(bo, "mitrich", Vector3(29.0, Y + 1.5, -17.86), Vector3(0, 0, 1), Vector2(0.4, 0.3))
	# истопник
	var st: Node3D = w.rooms["stoker"]["node"]
	if not "logbook" in Game.notes:
		Items.pickup(st, Vector3(13.6, Y + 0.92, -8.7), "note", "logbook", "Прочитать журнал истопника", Items.paper_visual("res://tex/gen/note_logbook.png", Vector2(0.3, 0.22)), func():
			Game.set_flag("logbook"))
	var le := Usable.make(st, Vector3(13.2, Y + 0.92, -8.55), Vector3(0.3, 0.2, 0.3), "Вложенный листок", func():
		Game.set_flag("last_entry")
		Game.add_note("last_entry")
		Game.main.show_note("last_entry")
		Game.set_objective(Texts.OBJECTIVES[String(Game.getf("obj", "o_valve"))] + "\n" + Texts.OBJECTIVES["o_fire"]))
	le.cond = func(): return "" if Game.flag("logbook") else "Сначала журнал."
	le.prompt_fn = func(): return "" if Game.flag("last_entry") else ("Последняя запись в журнале" if Game.flag("logbook") else "")
	Props.wall_note(st, "child_drawing", Vector3(10.13, Y + 1.5, -10.0), Vector3(1, 0, 0), Vector2(0.5, 0.4), "Посмотреть рисунок")
	Props.picture(st, "res://tex/gen/child_drawing.png", Vector3(10.13, Y + 1.5, -10.0), Vector3(1, 0, 0), Vector2(0.5, 0.4))
	Props.wall_note(st, "clip_1996", Vector3(10.13, Y + 1.5, -11.2), Vector3(1, 0, 0), Vector2(0.28, 0.37))
	# варежка в бункере
	var co: Node3D = w.rooms["coal"]["node"]
	var mit := Node3D.new()
	Geo.mesh_box(mit, Vector3(0.09, 0.03, 0.12), Mat.flat(Color(0.6, 0.06, 0.05), 0.9), Vector3(0, -0.13, 0))
	Items.pickup(co, Vector3(37.3, Y + 0.3, -11.6), "item", "mitten", "Детская варежка", mit, _memory)
	# задвижка №1
	var me: Node3D = w.rooms["meter"]["node"]
	var vv := Items.valve(me, Vector3(12.0, Y + 1.82, -17.2), 0.0, 0.22, "Закрывать задвижку № 1", 4.0, _valve_step, Callable(), 14.0)
	vv.rotation = Vector3(-PI * 0.5, 0, 0)
	vv.cond = func(): return "" if Game.has("wrench") else "Закисла. Руками не провернуть."
	vv.prompt_fn = func():
		var s := int(Game.getf("valve_stage", 0))
		return "" if s >= 3 else "Закрывать задвижку № 1 (%d/3)" % (s + 1)
	if not "telegram" in Game.notes:
		Items.pickup(me, Vector3(14.2, Y + 1.25, -17.2), "note", "telegram", "Телефонограмма", Items.paper_visual("res://tex/gen/note_telegram.png"))
	# котёл: клапан, шибер, топка
	var sv := Items.valve(bo, Vector3(18.6, Y + 1.6, -12.4), PI * 0.5, 0.13, "Перекрыть предохранительный клапан", 3.0, func():
		Game.set_flag("safety_closed")
		Snd.play("pipe_bang", -2.0, 0.8, "Amb")
		Game.think("Клапан перекрыт. Давлению теперь некуда деваться.", 3.0)
		_check_overheat(), Callable(), 10.0)
	sv.prompt_fn = func(): return "" if Game.flag("safety_closed") else "Перекрыть предохранительный клапан"
	var dm := Usable.make(bo, Vector3(23.5, Y + 2.2, -17.7), Vector3(0.6, 0.6, 0.3), "Открыть шибер", func():
		Game.set_flag("damper_open")
		Snd.at("damper", Vector3(23.5, Y + 2.2, -17.7), 0.0)
		Game.think("Шибер настежь. Тяга загудела.", 2.5)
		_check_overheat())
	dm.prompt_fn = func(): return "" if Game.flag("damper_open") else "Открыть шибер"
	var b2 := Geo.Batch.new()
	b2.box(Mat.m("rust", {"metal": 0.6}), Vector3(23.5, Y + 2.2, -17.8), Vector3(0.5, 0.06, 0.12))
	b2.box(Mat.flat(Color(0.2, 0.2, 0.2), 0.5, 0.8), Vector3(23.5, Y + 2.0, -17.75), Vector3(0.04, 0.4, 0.04))
	b2.commit(bo, "damper")
	var fu := Usable.make(bo, Vector3(20.0, Y + 0.7, -11.2), Vector3(0.9, 0.7, 0.4), "Подкинуть угля в топку", func():
		Game.set_flag("coal_added", int(Game.getf("coal_added", 0)) + 1)
		Snd.at("coal_shovel", Vector3(20, Y + 0.7, -11.2), 0.0)
		_check_overheat(), 2.0)
	fu.hold_sound = "loop_shovel"
	fu.hold_noise = 8.0
	fu.prompt_fn = func():
		var c := int(Game.getf("coal_added", 0))
		return "" if c >= 3 else "Подкинуть угля в топку (%d/3)" % (c + 1)
	# манометр котла: стрелка
	gauge = Node3D.new()
	bo.add_child(gauge)
	gauge.global_position = Vector3(21.15, Y + 2.4, -11.9)
	var needle := Geo.mesh_box(gauge, Vector3(0.012, 0.1, 0.01), Mat.flat(Color(0.8, 0.05, 0.05), 0.4), Vector3(0, 0.04, 0))
	gauge.rotation.z = 0.8
	# люк углеподачи
	var ch := Usable.make(co, Vector3(35.0, Y + 3.0, -17.5), Vector3(1.4, 1.0, 0.8), "", _chute, 3.0)
	ch.hold_noise = 10.0
	ch.prompt_fn = func():
		if not Game.flag("chute_dug"):
			return "Отгрести уголь от люка"
		if not Game.flag("chute_open"):
			return "Вскрыть люк монтировкой"
		return "Вылезти наружу"
	ch.hold_sound = "loop_shovel"
	# сруб: верхний полок
	var ba: Node3D = w.rooms["banya"]["node"]
	Items.pickup(ba, Vector3(33.2, Y + 1.6, -5.2), "note", "old_photo", "Старая фотография", null)
	Props.picture(ba, "res://tex/gen/old_photo.png", Vector3(33.2, Y + 1.6, -5.14), Vector3(0, 0, -1), Vector2(0.36, 0.28))
	var pu := Usable.make(ba, Vector3(35.0, Y + 1.1, -5.5), Vector3(4.0, 0.4, 0.5), "Сесть на верхний полок", _sacrifice)
	pu.prompt_fn = func():
		if not Game.flag("last_entry"):
			return ""
		return "Точно? Нажми ещё раз" if sacrifice_armed > 0.0 else "Сесть на верхний полок"


func _memory() -> void:
	Game.set_flag("mitten_memory")
	w.player.input_lock = true
	if Game.main and Game.main.has_method("flash_memory"):
		Game.main.flash_memory()
	Snd.play("memory", 0.0, 1.0, "Voice")
	await wait(1.0)
	Game.think("…уголь колется. Темно. Папа сказал сидеть тихо, что бы ни услышал.", 4.5)
	await wait(4.5)
	Game.think("Сверху, по крышке бункера, кто-то водит ногтями. Долго. До утра.", 4.5)
	await wait(4.5)
	w.player.input_lock = false
	Game.think("Я помню. Я сидел здесь.", 3.0)


func _valve_step() -> void:
	var s := int(Game.getf("valve_stage", 0)) + 1
	Game.set_flag("valve_stage", s)
	Snd.play("valve_creak_big", 0.0, 0.9 + s * 0.05, "Amb")
	if s < 3:
		Game.think(["Пошла… туго. Ещё.", "Ещё немного."][s - 1], 2.0)
		return
	Game.set_flag("valve_closed")
	Snd.play("pipe_groan", 2.0, 1.0, "Amb")
	await wait(1.0)
	Snd.play("hoz_scream", 4.0, 1.0, "Amb")
	if w.player:
		w.player.shake = 1.0
	Game.think("Закрыл. Счётчик встал. …Она кричит в трубах.", 4.0)
	obj("o_exit")
	if Game.flag("last_entry"):
		Game.set_objective(Texts.OBJECTIVES["o_exit"] + "\n" + Texts.OBJECTIVES["o_fire"])
	cp("c12_valve")
	msg("m10", 6.0)
	msg("m11", 14.0)
	# она в ярости и идёт к нему
	await wait(5.0)
	var hoz: Hozyayka = w.monster
	if hoz.state == Hozyayka.S.GONE:
		w.director.spawn_near_player(7.0, 22.0, 2.0)
	hoz.aggression = 1.5


func _check_overheat() -> void:
	if Game.flag("safety_closed") and Game.flag("damper_open") and int(Game.getf("coal_added", 0)) >= 3 and not Game.flag("overheat"):
		_start_overheat(false)


func _start_overheat(restored: bool) -> void:
	Game.set_flag("overheat")
	overheat_t = 75.0
	if not restored:
		cp("c13_fire")
	obj("o_run")
	alarm = Snd.play("loop_boiler_whistle", -6.0, 1.0, "Amb")
	Game.think("Манометр за красной чертой. Сейчас рванёт. К люку!", 4.0)
	Game.set_flag("music_lock")
	Snd.music("mus_chase", -4.0, 1.0)
	var hoz: Hozyayka = w.monster
	hoz.aggression = 1.5
	if hoz.state == Hozyayka.S.GONE:
		w.director.spawn_near_player(6.0, 20.0, 1.5)


func _chute() -> void:
	if not Game.flag("chute_dug"):
		Game.set_flag("chute_dug")
		Game.think("Уголь отгрёб. Люк на засове снаружи? Нет — просто прикипел.", 3.0)
		return
	if not Game.flag("chute_open"):
		if not Game.has("crowbar"):
			Game.think("Нужна монтировка.", 2.0)
			return
		Game.set_flag("chute_open")
		Snd.at("hatch_open", Vector3(35, Y + 3.4, -17.8), 4.0)
		Game.think("Открыл! Снаружи снег и холод.", 2.5)
		return
	# выход
	var id := "open_tap"
	if Game.flag("valve_closed"):
		id = "last_steam" if Game.flag("overheat") else "valve"
	_finish(id)


func _sacrifice() -> void:
	if sacrifice_armed <= 0.0:
		sacrifice_armed = 3.0
		return
	_finish("steam")


func _finish(id: String) -> void:
	overheat_t = -1.0
	if alarm:
		alarm.queue_free()
	if Game.main and Game.main.has_method("ending"):
		Game.main.ending(id)


# ---------------------------------------------------------------- триггеры

func _trigger(id: String, rect: AABB, fn: Callable, once := true) -> void:
	if once and Game.flag("trig:" + id):
		return
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = rect.size
	cs.shape = sh
	a.add_child(cs)
	w.add_child(a)
	a.global_position = rect.get_center()
	a.body_entered.connect(func(b: Node3D):
		if not (b is Player):
			return
		if Game.main and Game.main.get("prewarming"):
			return
		if once:
			if Game.flag("trig:" + id):
				return
			Game.set_flag("trig:" + id)
		if Game.bot:
			print("  [триггер] ", id)
		fn.call())
	triggers[id] = a


func _triggers() -> void:
	# вход в вестибюль
	_trigger("enter_lobby", AABB(Vector3(24.5, 0, 26.5), Vector3(3.0, 2.0, 3.0)), func():
		Game.set_flag("inside")
		cp("c02_lobby")
		obj("o_way")
		Game.think("Тепло. Влажно, как в парной. Кто-то топит котёл.", 4.0))
	_trigger("jam_entrance", AABB(Vector3(22.0, 0, 23.5), Vector3(8.0, 2.0, 3.5)), func():
		var d := _door("d_entrance")
		d.slam()
		d.locked = true
		d.lock_text = "Не открывается. Заклинило — будто держат с той стороны."
		Game.set_flag("entrance_jammed")
		d.save_state()
		w.player.shake = 0.5
		await wait(1.2)
		Game.think("Дверь… Сквозняк? Не открывается.", 3.0))
	# следы в вестибюле: подсказка
	_trigger("footprints_look", AABB(Vector3(14.6, 0, 25.5), Vector3(5.0, 2.0, 2.5)), func():
		if Game.flag("footprints"):
			Game.think("Следы босые. Мокрые, ещё не высохли. Пальцы длинные — слишком длинные.", 4.0), false)
	# мужская раздевальня
	_trigger("enter_mlock", AABB(Vector3(4.2, 0, 20.2), Vector3(9.6, 2.5, 9.6)), func():
		if Game.has("key_util"):
			cp("c03_mlock")
		_prepare_encounter())
	# простыня: голова поворачивается
	_trigger("sheet_near", AABB(Vector3(6.8, 0, 25.5), Vector3(4.0, 2.0, 3.5)), func():
		if sheet_man and is_instance_valid(sheet_man):
			Snd.at("cloth_rustle", sheet_man.global_position + Vector3.UP, -4.0)
			var sk: Skeleton3D = sheet_man.get_meta("sk")
			var hi := sk.find_bone("Bip01 Head")
			var q0 := sk.get_bone_pose_rotation(hi)
			var q1 := q0 * Quaternion(Vector3(1, 0, 0), -0.9) * Quaternion(Vector3(0, 0, 1), -0.4)
			var tw := create_tween()
			tw.tween_method(func(v: float): sk.set_bone_pose_rotation(hi, q0.slerp(q1, v)), 0.0, 1.0, 2.5).set_trans(Tween.TRANS_SINE))
	# первая встреча: вход в мыльную
	_trigger("enc", AABB(Vector3(0.2, 0, 17.0), Vector3(13.6, 3.0, 2.8)), func():
		if not Game.flag("first_encounter"):
			_prepare_encounter()
			_first_encounter(), false)
	# «за спиной» — обучение: после кода, по дороге к душевой
	_trigger("behind", AABB(Vector3(8.5, 0, 9.4), Vector3(5.0, 3.0, 4.0)), func():
		if Game.flag("code_seen") and not Game.flag("behind_tutorial"):
			_behind_tutorial(), false)
	# технический коридор
	_trigger("service", AABB(Vector3(0.2, 0, 0.2), Vector3(51.6, 2.5, 2.6)), func():
		cp("c06_service")
		if String(Game.getf("obj", "")) in ["o_code2", "o_code"]:
			obj("o_service")
		Game.think("Технический коридор. Топки каменок горят. Кто-то их топит прямо сейчас.", 4.0))
	# женское отделение
	_trigger("women", AABB(Vector3(38.2, 0, 3.2), Vector3(13.6, 3.0, 16.6)), func():
		Game.set_flag("danger", maxi(2, int(Game.getf("danger", 0))))
		if not Game.flag("grate_seen"):
			Game.set_flag("grate_seen")
			obj("o_pumpkey")
		cp("c07_women"))
	# насосная
	_trigger("pump", AABB(Vector3(30.2, 0, 3.2), Vector3(7.6, 2.5, 2.6)), func():
		cp("c08_pump"))
	# котельная
	_trigger("boiler", AABB(Vector3(16.2, Y, -18.0), Vector3(15.6, 3.5, 10.8)), func():
		Game.set_flag("boiler_seen")
		cp("c11_boiler")
		Snd.at("coal_shovel", Vector3(20, Y + 0.7, -11.0), 4.0)
		await wait(1.5)
		Snd.at("furnace_slam", Vector3(20, Y + 0.7, -11.3), 4.0)
		Game.think("Топка… захлопнулась. Здесь никого нет. Тут никого не должно быть.", 4.0))


func on_room(room: String) -> void:
	if room == "lobby" and not Game.flag("phone_answered"):
		lobby_time = 0.0


# ---------------------------------------------------------------- кадр

func _process(delta: float) -> void:
	if w == null or w.player == null:
		return
	var pl := w.player
	sacrifice_armed = maxf(0.0, sacrifice_armed - delta)
	# звонок телефона: после плана или через 35 с в вестибюле
	if Game.flag("inside") and not Game.flag("phone_answered") and not Game.flag("phone_ringing"):
		if pl.current_room in ["lobby", "admin", "office"]:
			lobby_time += delta
		if lobby_time > 35.0 or (Game.flag("map") and lobby_time > 8.0) or "complaints" in Game.notes:
			_ring_phone()
	# слив бассейна
	if drain_target > -50.0 and w.pool_level > drain_target:
		w.set_pool_level(maxf(drain_target, w.pool_level - drain_speed * delta))
		Game.flags["pool_level"] = w.pool_level
		if randf() < delta * 0.5:
			w.noise(Vector3(32.2, w.pool_level, 11.5), 22.0, "water")
		_update_pool_barrier()
		if w.pool_level <= drain_target + 0.001:
			if drain_target == Layout.POOL_SHALLOW and not Game.flag("pool_drained"):
				# слив встал: забит
				Game.set_flag("pool_clogged")
				Game.flags["pool_level"] = Layout.POOL_SHALLOW
				drain_target = -99.0
				Snd.play("drain_stop", 0.0, 1.0, "Amb")
				Game.think("Встала. Слив забит. Метр воды в глубокой части.", 3.5)
				obj("o_unclog")
				msg("m08", 3.0)
			else:
				drain_target = -99.0
				Game.flags["pool_level"] = w.pool_level
	# волосы из решётки при прочистке: что-то тянет с той стороны
	if Game.flag("pool_clogged") and not unclog_scare:
		var gu := _find_unclog()
		if gu and gu.progress > 4.0:
			unclog_scare = true
			Snd.play("hair_yank", 6.0)
			pl.shake = 1.2
			Game.think("Тянет обратно!", 1.5)
			var hoz: Hozyayka = w.monster
			if hoz.state == Hozyayka.S.GONE and not Game.cheats.get("no_monster", false):
				hoz.emerge(Vector3(21.0, Layout.POOL_SHALLOW, 11.5), pl.global_position, false)
	# код на запотевшем зеркале
	if not Game.flag("code_seen") and Game.flag("lockhot_open") and w.has_meta("mirror_m_lock"):
		var m: Mirror = w.get_meta("mirror_m_lock")
		var to := m.global_position - pl.eye_pos()
		if m.fog > 0.55 and to.length() < 4.0 and pl.look_dir().dot(to.normalized()) > 0.8:
			Game.set_flag("code_seen")
			Snd.play("sting_soft", -6.0)
			Game.think("На запотевшем зеркале проступило, пальцем: «21·12 техн.» — двадцать первое декабря.", 5.0)
			Game.show_hint("Код от технического коридора: 2112", 6.0)
			obj("o_code2")
	# зеркало в женской раздевальне: в отражении — она за спиной
	if not Game.flag("mirror_scare") and w.has_meta("mirror_f_lock") and pl.current_room == "f_lock":
		var fm: Mirror = w.get_meta("mirror_f_lock")
		var to2 := fm.global_position - pl.eye_pos()
		if to2.length() < 3.6 and pl.look_dir().dot(to2.normalized()) > 0.85:
			_mirror_scare(fm)
	if mirror_scare_t > 0.0:
		mirror_scare_t -= delta
		if mirror_scare_t <= 0.0 and ghost_mirror:
			ghost_mirror.queue_free()
			ghost_mirror = null
	# низкая дверь в сруб
	if not Game.flag("hint_banya") and pl.current_room == "boiler" and Vector2(pl.global_position.x - 31.4, pl.global_position.z + 8.0).length() < 1.6:
		Game.set_flag("hint_banya")
		Game.show_hint("Дверь в сруб низкая — пригнись (Ctrl), чтобы пройти.", 5.0)
	# водомер крутится, пока ввод открыт
	if w.has_meta("meter_hand") and not Game.flag("valve_closed"):
		(w.get_meta("meter_hand") as Node3D).rotation.y += delta * 6.0
	# котёл перегревается
	if overheat_t > 0.0:
		overheat_t -= delta
		if gauge:
			gauge.rotation.z = lerpf(0.8, -2.6, 1.0 - overheat_t / 75.0) + randf_range(-0.05, 0.05)
		if randf() < delta * 0.6:
			Snd.play("pipe_bang", -6.0, randf_range(0.8, 1.2), "Amb")
			pl.shake = maxf(pl.shake, 0.3)
		if overheat_t <= 0.0:
			overheat_t = -1.0
			if alarm:
				alarm.queue_free()
			if Game.main and Game.main.has_method("player_killed"):
				Game.set_flag("death_reason", "boom")
				Game.main.player_killed(null)


func _find_unclog() -> Usable:
	for c in w.rooms["pool"]["node"].get_children():
		if c is Usable and c.has_meta("unclog"):
			return c
	return null


func _mirror_scare(m: Mirror) -> void:
	Game.set_flag("mirror_scare")
	var pl := w.player
	ghost_mirror = HozBody.new()
	w.add_child(ghost_mirror)
	var back := -pl.look_dir()
	back.y = 0
	ghost_mirror.global_position = pl.global_position + back.normalized() * 1.1
	ghost_mirror.rotation.y = Props.yaw_to(-back)
	ghost_mirror.floor_y = pl.global_position.y
	ghost_mirror.play("idle", 0.0, 0.5)
	for c in ghost_mirror.find_children("*", "VisualInstance3D", true, false):
		(c as VisualInstance3D).layers = Mirror.GHOST_LAYER
	mirror_scare_t = 1.4
	Snd.play("sting_mirror", 0.0)
	await wait(1.4)
	m.force_fog = 1.0
	Snd.play("hoz_whisper", -4.0, 0.95, "Voice")
	await wait(4.0)
	m.force_fog = -1.0


func _ambience() -> void:
	var amb := Snd.play("loop_amb_building", -10.0, 1.0, "Amb")
	set_meta("amb", amb)
	var drips := Snd.play("loop_drips", -14.0, 1.0, "Amb")
	set_meta("drips", drips)


func _exit_tree() -> void:
	for k in ["amb", "drips"]:
		if has_meta(k):
			var p: Node = get_meta(k)
			if is_instance_valid(p):
				p.queue_free()
	if alarm and is_instance_valid(alarm):
		alarm.queue_free()
