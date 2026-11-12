extends Node
## Главный узел: меню, запуск/перезапуск мира с точки, экраны поверх игры, смерть и испуг, концовки,
## админ-режим. Аргументы для проверок: --tour, --hoztest, --bot, --cp=<точка>, --shot=<имя>.

var world: World
var hud: Hud
var ui_layer: CanvasLayer
var overlay: Control = null        # открытый экран (записка, код, пауза…)
var phone: Phone = null
var menu: Control = null
var admin_panel: Control = null
var code_door: Door = null
var dying := false
var args: Array = []
var last_cp_admin := false
var started := false
var prewarming := false


func _ready() -> void:
	Game.main = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	args = OS.get_cmdline_user_args()
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	if "--hoztest" in args:
		add_child(load("res://tools/dev/hoz_test.gd").new())
		return
	if "--tour" in args:
		_tour()
		return
	if "--bot" in args:
		add_child(load("res://tools/dev/bot.gd").new())
		return
	if "--navdbg" in args:
		Game.bot = true
		add_child(load("res://tools/dev/nav_dbg.gd").new())
		return
	if "--aitest" in args:
		Game.bot = true
		add_child(load("res://tools/dev/ai_test.gd").new())
		return
	for a in args:
		if String(a).begins_with("--cp="):
			Game.admin = "--admin" in args
			start_checkpoint(String(a).substr(5), true)
			Game.admin = "--admin" in args
			_dev_shot()
			return
		if String(a) == "--museum":
			open_museum()
			return
		if String(a) == "--menushot":
			show_menu()
			await get_tree().create_timer(3.0).timeout
			get_viewport().get_texture().get_image().save_png("res://shots/ui_menu.png")
			get_tree().quit()
			return
		if String(a).begins_with("--endshot="):
			show_ending_screen(String(a).substr(10))
			await get_tree().create_timer(16.0).timeout
			get_viewport().get_texture().get_image().save_png("res://shots/ui_ending.png")
			get_tree().quit()
			return
	show_menu()


# ---------------------------------------------------------------- меню

func show_menu() -> void:
	_clear_world()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game.admin = false
	for k in Game.cheats:
		Game.cheats[k] = false
	menu = MainMenu.new()
	ui_layer.add_child(menu)
	Snd.music("mus_menu", -6.0, 2.0)


func _close_menu() -> void:
	if menu:
		menu.queue_free()
		menu = null


func new_game() -> void:
	Game.reset_progress()
	Game.admin = false
	start_checkpoint("c01_yard", false, true)


func continue_game() -> void:
	if Game.load_save():
		_start_world()


## Старт с точки. admin — подставить всё, что сделано к этой точке.
func start_checkpoint(id: String, admin: bool, fresh := false) -> void:
	if admin or fresh:
		Game.reset_progress()
		Game.admin = admin
		var ids := Texts.CHECKPOINTS.keys()
		for cid in ids:
			var st: Dictionary = Texts.CP_STATE.get(cid, {})
			for k in st.get("flags", {}):
				Game.flags[k] = st["flags"][k]
			for it in st.get("items", []):
				Game.items[it] = true
			for n in st.get("notes", []):
				if not n in Game.notes:
					Game.notes.append(n)
			for m in st.get("msgs", []):
				if not m in Game.messages:
					Game.messages.append(m)
			if cid == id:
				break
		Game.checkpoint = id
		if id != "c01_yard":
			Game.flags["intro_done"] = true
		for k in Game.flags.keys():
			if String(k).begins_with("trig:"):
				Game.flags.erase(k)
		Game.snapshot = Game.make_snapshot()
		if not admin:
			Game.save_game()
	_start_world()


func _start_world() -> void:
	_close_menu()
	_clear_world()
	dying = false
	Snd.music("", 0.0, 1.0)
	var loading := _loading()
	await get_tree().process_frame
	await get_tree().process_frame
	world = World.new()
	world.name = "World"
	add_child(world)
	hud = Hud.new()
	add_child(hud)
	hud.connect_player(world.player)
	await _prewarm()
	loading.queue_free()
	started = true
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Game.checkpoint != "c01_yard" or Game.flag("intro_done"):
		hud.fade.color.a = 1.0
		hud.fade_to(0.0, 1.2)
	if Game.admin:
		hud.toast("Админ-режим: F1 — панель, F2 — полёт")


## Прогрев шейдеров под экраном загрузки: Хозяйка, волосы, вода, пар, зеркало — чтобы не было
## подвисания в момент первого появления.
func _prewarm() -> void:
	prewarming = true
	var pl := world.player
	var hoz: Hozyayka = world.monster
	var keep_pos := pl.global_position
	var keep_light := pl.flash_on
	pl.toggle_light(1)
	var spots := [Vector3(7.0, 0.05, 18.5), Vector3(26.0, 0.05, 16.3), Vector3(41.9, 0.05, 28.3), Vector3(25.25, -4.3, -9.0)]
	hoz.visible = true
	hoz.body.model.position.y = 0.0
	for sp in spots:
		pl.global_position = sp
		hoz.global_position = sp + (-pl.cam.global_transform.basis.z) * Vector3(1, 0, 1) * 1.6
		for i in 3:
			await get_tree().process_frame
	hoz.body.set_part(1.0)
	hoz.body.rig.jaw = 1.0
	for i in 3:
		await get_tree().process_frame
	hoz.body.set_part(0.0)
	hoz.body.rig.jaw = 0.0
	hoz.visible = false
	pl.global_position = keep_pos
	if not keep_light:
		pl.toggle_light(0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	prewarming = false


func _loading() -> Control:
	var c := Control.new()
	UI.full(c)
	c.add_child(UI.dim_bg(1.0))
	var l := UI.label("…", 40, UI.DIM, "PTSerif-Italic.ttf")
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.position = Vector2(-30, -20)
	c.add_child(l)
	ui_layer.add_child(c)
	return c


func _clear_world() -> void:
	_close_overlay()
	if phone:
		phone.queue_free()
		phone = null
	if admin_panel:
		admin_panel.queue_free()
		admin_panel = null
	if hud:
		hud.queue_free()
		hud = null
	if world:
		world.free_world()
		world = null
	for c in get_children():
		if c is Museum:
			c.queue_free()


func reload_checkpoint() -> void:
	Game.restore_snapshot(Game.snapshot)
	_start_world()


# ---------------------------------------------------------------- ввод

func _unhandled_input(e: InputEvent) -> void:
	if world == null or dying:
		return
	if e.is_action_pressed("pause"):
		if overlay:
			_close_overlay()
		elif phone == null:
			open_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("phone") and overlay == null and not world.player.hidden_in and phone == null:
		open_phone()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("use") and overlay and overlay.has_meta("note"):
		_close_overlay()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("admin") and Game.admin:
		toggle_admin_panel()
	elif e.is_action_pressed("fly") and Game.admin:
		Game.cheats["noclip"] = not Game.cheats["noclip"]
		world.player.set_noclip(Game.cheats["noclip"])
		hud.toast("Полёт: " + ("вкл (Q/Z — вверх/вниз)" if Game.cheats["noclip"] else "выкл"))


func _lock(on: bool) -> void:
	if world and world.player:
		world.player.input_lock = on
		world.player.look_lock = on
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED


func _show_overlay(c: Control, pause := false) -> void:
	_close_overlay()
	overlay = c
	ui_layer.add_child(c)
	_lock(true)
	get_tree().paused = pause


func _close_overlay() -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
		code_door = null
		get_tree().paused = false
		if world and not dying and admin_panel == null:
			_lock(false)


func show_note(id: String) -> void:
	var c := Screens.note(id, _close_overlay)
	c.set_meta("note", true)
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	_show_overlay(c, true)


func open_code(d: Door) -> void:
	var c := Screens.codepad(func(code: String):
		if code == d.code:
			var dd := d
			_close_overlay()
			dd.code_ok()
			dd.use(world.player)
			if Game.world:
				Game.world.noise(dd.global_position, 6.0, "door")
		else:
			Snd.play("keypad_err", -4.0)
			if Game.world:
				Game.world.noise(d.global_position, 5.0, "door"), _close_overlay)
	_show_overlay(c, false)
	code_door = d


func open_pause() -> void:
	var c := Screens.pause(_close_overlay, func():
		var s := Screens.settings(func(): open_pause())
		s.process_mode = Node.PROCESS_MODE_ALWAYS
		_show_overlay(s, true), func():
		_close_overlay()
		show_menu())
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	_show_overlay(c, true)


func open_phone() -> void:
	phone = Phone.new()
	ui_layer.add_child(phone)
	Snd.play("phone_open", -8.0)
	_lock(true)
	phone.closed.connect(func():
		phone.queue_free()
		phone = null
		_lock(false))


func toast(t: String) -> void:
	if hud:
		hud.toast(t)


func fade_in(secs: float) -> void:
	if hud:
		hud.fade.color.a = 1.0
		hud.fade_to(0.0, secs)


func fade_out(secs: float) -> void:
	if hud:
		hud.fade_to(1.0, secs)


func flash_memory() -> void:
	if hud:
		hud.memory = 1.0


func set_slats(kind: String) -> void:
	if hud:
		hud.slats_kind = kind


func on_behind(on: bool) -> void:
	if hud:
		hud.behind_target = 1.0 if on else 0.0


# ---------------------------------------------------------------- смерть

func player_killed(m: Node) -> void:
	if dying or world == null:
		return
	dying = true
	var pl := world.player
	pl.dead = true
	pl.input_lock = true
	_close_overlay()
	if phone:
		phone.queue_free()
		phone = null
	Game.deaths += 1
	var reason := ""
	if String(Game.getf("death_reason", "")) == "boom":
		reason = "Котёл рванул. Не успел."
		Game.flags.erase("death_reason")
		Snd.play("explosion", 6.0)
		hud.fade.color = Color(1, 0.8, 0.6, 1)
		await get_tree().create_timer(0.3).timeout
	elif m is Hozyayka:
		await _jumpscare(m)
		reason = Texts.DEATH_LINES[Game.deaths % Texts.DEATH_LINES.size()]
	Snd.music("", 0.0, 0.5)
	var d := Screens.death(reason, func():
		_close_overlay()
		reload_checkpoint(), func():
		_close_overlay()
		show_menu())
	d.process_mode = Node.PROCESS_MODE_ALWAYS
	_show_overlay(d, false)
	if Game.bot:
		await get_tree().create_timer(1.0).timeout
		reload_checkpoint()


## Испуг: камера разворачивается к ней, секунду она стоит в луче, потом лицо бросается вплотную,
## челюсть распахивается, волосы расходятся.
func _jumpscare(m: Hozyayka) -> void:
	var pl := world.player
	var cam := pl.cam
	var body := m.body
	m.set_state(Hozyayka.S.KILL)
	m.visible = true
	body.model.position.y = 0.0
	body.set_clip(-1000.0)
	m.path = PackedVector3Array()
	var fwd := pl.look_dir()
	fwd.y = 0
	fwd = fwd.normalized()
	var to_her := m.global_position - pl.global_position
	to_her.y = 0
	if to_her.length() < 0.8 or to_her.length() > 3.5:
		m.global_position = pl.global_position + fwd * 1.7
		to_her = fwd * 1.7
	m.rotation.y = Props.yaw_to(-to_her)
	body.play("idle", 0.0, 0.4)
	body.rig.stoop = 0.55
	body.rig.head_tilt = 0.55
	body.rig.twitch = 0.9
	body.rig.reach = 0.6
	body.set_part(0.35)
	var face_light := OmniLight3D.new()
	face_light.light_color = Color(0.75, 0.85, 0.8)
	face_light.light_energy = 0.55
	face_light.omni_range = 2.5
	face_light.shadow_enabled = false
	cam.add_child(face_light)
	face_light.position = Vector3(0.1, 0.15, -0.2)
	# поворот камеры к её лицу
	await get_tree().process_frame
	var hp := body.head_pos()
	var dir := hp - cam.global_position
	var yaw_t := Props.yaw_to(Vector3(dir.x, 0, dir.z))
	yaw_t = pl.rotation.y + angle_difference(pl.rotation.y, yaw_t)
	var pitch_t := atan2(dir.y, Vector2(dir.x, dir.z).length())
	var tw := create_tween().set_parallel(true)
	tw.tween_property(pl, "rotation:y", yaw_t, 0.16).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(pl.head, "rotation:x", pitch_t, 0.16).set_trans(Tween.TRANS_QUAD)
	Snd.play("sting_mirror", -2.0)
	await get_tree().create_timer(0.45).timeout
	# бросок: лицо — вплотную к камере
	Snd.play("jumpscare", 4.0)
	Snd.play("hoz_scream", 2.0, 1.1, "Voice")
	pl.shake = 2.0
	body.rig.twitch = 0.25
	var flat := cam.global_position - m.global_position
	flat.y = 0
	m.rotation.y = Props.yaw_to(flat)
	await get_tree().process_frame
	var cf := -cam.global_transform.basis.z
	var target := cam.global_position + cf * 0.55 - Vector3(0, 0.03, 0)
	var root_target := m.global_position + (target - body.head_pos())
	var tl := create_tween().set_parallel(true)
	tl.tween_property(m, "global_position", root_target, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tl.tween_property(body.rig, "jaw", 1.0, 0.3)
	var t := 0.0
	while t < 0.95:
		t += get_process_delta_time()
		cam.rotation.z = randf_range(-0.03, 0.03) * (1.0 - t)
		await get_tree().process_frame
	hud.fade.color = Color(0, 0, 0, 1)
	face_light.queue_free()
	Snd.play("thud_body", 0.0)
	await get_tree().create_timer(0.8).timeout


# ---------------------------------------------------------------- концовки

func ending(id: String) -> void:
	if world == null:
		return
	dying = true
	world.player.input_lock = true
	Game.ending_seen(id)
	hud.fade_to(1.0, 1.5)
	if id == "steam":
		Snd.play("steam_hiss", 0.0)
		Snd.play("hoz_whisper", 0.0, 0.9, "Voice")
	elif id == "last_steam":
		await get_tree().create_timer(1.6).timeout
		Snd.play("explosion", 4.0)
	await get_tree().create_timer(2.0).timeout
	if id == "last_steam":
		await _fire_scene()
	_clear_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Snd.music("mus_ending", -6.0, 3.0)
	var e := Screens.ending(id, func():
		_close_overlay()
		show_menu())
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = e
	ui_layer.add_child(e)


## Просмотр текста концовки из админ-режима.
func show_ending_screen(id: String) -> void:
	_close_menu()
	_clear_world()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Snd.music("mus_ending", -6.0, 2.0)
	var e := Screens.ending(id, func():
		_close_overlay()
		open_admin_menu())
	overlay = e
	ui_layer.add_child(e)


## Финальный кадр «Последнего пара»: баня горит в снегу.
func _fire_scene() -> void:
	var pl := world.player
	world.monster.vanish()
	pl.global_position = Vector3(31.0, 0.05, 47.5)
	pl.set_look(deg_to_rad(8), deg_to_rad(6))
	pl.toggle_light(0)
	var fire_root := Node3D.new()
	world.add_child(fire_root)
	for x in [5.0, 12.0, 19.0, 26.0, 33.0, 40.0, 47.0]:
		var f := GPUParticles3D.new()
		f.amount = 140
		f.lifetime = 2.2
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(3.0, 0.3, 6.0)
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 15.0
		pm.initial_velocity_min = 2.0
		pm.initial_velocity_max = 4.5
		pm.gravity = Vector3(0, 1.0, 0)
		pm.scale_min = 1.0
		pm.scale_max = 2.6
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
		g.set_color(1, Color(0.2, 0.05, 0.02, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		f.process_material = pm
		var qm := QuadMesh.new()
		qm.size = Vector2(1.2, 1.2)
		var sm := StandardMaterial3D.new()
		sm.albedo_texture = load("res://tex/ui/steam_puff.png")
		sm.vertex_color_use_as_albedo = true
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		qm.material = sm
		f.draw_pass_1 = qm
		fire_root.add_child(f)
		f.global_position = Vector3(x, 5.6, 15.0)
		var l := Items.Fire.new()
		l.base = 9.0
		l.omni_range = 26.0
		fire_root.add_child(l)
		l.global_position = Vector3(x, 8.0, 18.0)
	world.env.background_color = Color(0.05, 0.06, 0.1)
	Snd.play("loop_fire_big", 0.0, 1.0, "Amb")
	hud.fade_to(0.0, 2.5)
	await get_tree().create_timer(8.0).timeout
	hud.fade_to(1.0, 2.0)
	await get_tree().create_timer(2.2).timeout


# ---------------------------------------------------------------- админ

func toggle_admin_panel() -> void:
	if admin_panel:
		admin_panel.queue_free()
		admin_panel = null
		_lock(false)
		return
	admin_panel = AdminPanel.new()
	ui_layer.add_child(admin_panel)
	_lock(true)


func open_admin_menu() -> void:
	_close_menu()
	menu = AdminMenu.new()
	ui_layer.add_child(menu)


func open_museum() -> void:
	_close_menu()
	_clear_world()
	Game.admin = true
	var m := Museum.new()
	add_child(m)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ---------------------------------------------------------------- скриншоты

## Для проверок: --shot=имя [--wait=сек] [--pos=x,y,z] [--look=yaw,pitch] [--light] [--event=имя]
func _dev_shot() -> void:
	var name := ""
	var wait := 5.0
	for a in args:
		var s := String(a)
		if s.begins_with("--shot="):
			name = s.substr(7)
		elif s.begins_with("--wait="):
			wait = float(s.substr(7))
	if name == "":
		return
	while world == null or not started:
		await get_tree().process_frame
	if DisplayServer.window_get_size().x < 1000:
		DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.5).timeout
	for a in args:
		var s := String(a)
		if s.begins_with("--pos="):
			var v := s.substr(6).split(",")
			world.player.global_position = Vector3(float(v[0]), float(v[1]), float(v[2]))
		elif s.begins_with("--look="):
			var v2 := s.substr(7).split(",")
			world.player.set_look(deg_to_rad(float(v2[0])), deg_to_rad(float(v2[1])))
		elif s == "--light":
			world.player.toggle_light(1)
		elif s.begins_with("--event="):
			var ev := s.substr(8)
			if world.scenario.has_method(ev):
				world.scenario.call(ev)
		elif s == "--godmode":
			Game.cheats["god"] = true
		elif s == "--nomonster":
			Game.cheats["no_monster"] = true
	for a in args:
		var s := String(a)
		if s.begins_with("--ui="):
			match s.substr(5):
				"phone":
					open_phone()
				"note":
					show_note("last_entry")
				"panel":
					Game.admin = true
					toggle_admin_panel()
				"pause":
					open_pause()
				"code":
					open_code(world.doors["d_code_m"])
		elif s.begins_with("--kill="):
			await get_tree().create_timer(float(s.substr(7))).timeout
			var hoz: Hozyayka = world.monster
			var p0 := world.player.global_position + world.player.look_dir() * Vector3(1, 0, 1) * 2.0
			hoz.emerge(p0, world.player.global_position, true)
			hoz.set_state(Hozyayka.S.ROAM)
			hoz.kill()
		elif s.begins_with("--hoz="):
			var v3 := s.substr(6).split(",")
			var hoz2: Hozyayka = world.monster
			hoz2.emerge(Vector3(float(v3[0]), float(v3[1]), float(v3[2])), world.player.global_position, true)
			hoz2.set_state(Hozyayka.S.SEARCH)
			hoz2.search_t = 99.0
	if "--fps" in args:
		for i in int(wait):
			await get_tree().create_timer(1.0).timeout
			print("fps ", Engine.get_frames_per_second(), "  draw ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "  prims ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	else:
		await get_tree().create_timer(wait).timeout
	var burst := 1
	var gap := 0.1
	for a in args:
		if String(a).begins_with("--burst="):
			var bv := String(a).substr(8).split(",")
			burst = int(bv[0])
			gap = float(bv[1])
	for i in burst:
		var fn := name if burst == 1 else "%s_%d" % [name, i]
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % fn)
		if burst > 1:
			await get_tree().create_timer(gap).timeout
	print("shot ", name, " fps ", Engine.get_frames_per_second())
	get_tree().quit()

func _tour() -> void:
	var shots: Array = load("res://tools/dev/tour_points.gd").POINTS
	Game.reset_progress()
	world = World.new()
	add_child(world)
	world.player.input_lock = true
	world.player.toggle_light(1)
	for s in shots:
		world.player.global_position = s[1]
		world.player.set_look(deg_to_rad(s[2]), deg_to_rad(s[3]))
		for i in 25:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://shots/%s.png" % s[0])
		print("shot ", s[0])
	get_tree().quit()
