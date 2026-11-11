extends Node
## Ход игры: меню, запуск этапов, контрольные точки, смерть, концовки, окна поверх игры, админ-режим.

const SAVE := "user://save.json"

var main: Node = null
var world: World = null
var player: Player = null
var entity: Entity = null
var director: Director = null
var hud: Hud = null
var cards: Cards = null
var note_view: NoteView = null
var notebook: Notebook = null
var radio_ui: RadioUi = null
var menus: Menus = null
var admin_panel: AdminPanel = null
var museum: Node3D = null

var admin := false          # сессия запущена из админ-режима
var god := false            # бессмертие
var no_cold := false        # холод не действует
var ai_off := false         # существо выключено
var flags := {}             # сюжетные флаги
var notes: Array = []       # найденные записки
var readings := {}          # ночь -> {t, w, s}
var objectives: Array = []  # [{id, text, done}]
var endings_seen: Array = []
var night := 1
var stage := ""
var in_game := false
var busy := false           # переход или катсцена: пауза недоступна
var dying := false
var ui_frame := -1          # кадр, в котором открылось окно (чтобы та же клавиша его не закрыла)
var _menu_cam: Camera3D = null
var _menu_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func flag(k: String) -> bool:
	return bool(flags.get(k, false))


func set_flag(k: String, v := true) -> void:
	flags[k] = v


# ------------------------------------------------------------------ запуск

func boot() -> void:
	hud = Hud.new()
	main.hud_layer.add_child(hud)
	hud.visible = false
	note_view = NoteView.new()
	notebook = Notebook.new()
	radio_ui = RadioUi.new()
	admin_panel = AdminPanel.new()
	menus = Menus.new()
	for c in [radio_ui, notebook, note_view, admin_panel, menus]:
		main.ui_layer.add_child(c)
	cards = Cards.new()
	main.top_layer.add_child(cards)
	_load_save()
	if Cfg.has_arg("stage"):
		admin = Cfg.has_arg("admin")
		start_stage(Cfg.arg("stage"))
	elif Cfg.has_arg("museum"):
		open_museum(Cfg.arg("museum", "figure"))
	elif Cfg.has_arg("place") or Cfg.has_arg("tour") or Cfg.has_arg("ent") or Cfg.has_arg("pos") or Cfg.has_arg("sandbox"):
		start_sandbox()
	else:
		show_menu(Cfg.arg("menu", "main"))


func _free_world() -> void:
	in_game = false
	director = null
	entity = null
	player = null
	world = null
	museum = null
	_menu_cam = null
	main.set_scene(null)
	main.reset_fx()
	Snd.stop_all(0.3)
	Snd.cut_oneshots()
	Snd.muffle(0.0, true)
	hud.clear_all()
	hud.set_static(0.0)
	for w in [note_view, notebook, radio_ui, admin_panel]:
		if w.is_open:
			w.close()
	get_tree().paused = false


func _make_world(place: String) -> void:
	world = World.new()
	world.name = "WorldScene"
	main.set_scene(world)
	player = world.spawn_player(place)
	entity = Entity.new()
	entity.name = "Entity"
	entity.world = world
	world.add_child(entity)
	hud.visible = true
	in_game = true
	dying = false


## Главное меню: за ним — живая станция в пурге.
func show_menu(screen := "main") -> void:
	busy = true
	_free_world()
	hud.visible = false
	world = World.new()
	world.name = "WorldScene"
	main.set_scene(world)
	world.weather.base = 0.62
	_menu_cam = Camera3D.new()
	_menu_cam.fov = 58.0
	world.add_child(_menu_cam)
	_menu_cam.global_position = Vector3(15.5, 1.75, 8.6)
	_menu_cam.look_at(Vector3(4.0, 1.5, 1.6))
	_menu_cam.make_current()
	world.weather.cam = _menu_cam
	Snd.loop("music", "music_menu", 0.55, 3.0, "Music")
	main.set_fade(Color(0, 0, 0, 1))
	cards.visible = false
	menus.open(screen)
	await get_tree().create_timer(0.4).timeout
	main.fade_to(Color(0, 0, 0, 0), 1.5)
	busy = false


func new_game() -> void:
	notes.clear()
	readings.clear()
	flags.clear()
	objectives.clear()
	admin = false
	god = false
	no_cold = false
	ai_off = false
	start_stage("n1_wake")


func continue_game() -> void:
	admin = false
	god = false
	no_cold = false
	ai_off = false
	start_stage(stage if stage != "" else "n1_wake")


## Запустить этап с нуля: строит мир и ставит его в нужное состояние.
func start_stage(id: String) -> void:
	busy = true
	menus.close_all()
	main.set_fade(Color(0, 0, 0, 1))
	_free_world()
	await get_tree().process_frame
	stage = id
	objectives.clear()
	_make_world("bed")
	director = Director.new()
	director.name = "Director"
	director.world = world
	world.add_child(director)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	director.begin(id)
	_apply_debug_args()
	busy = false


func start_sandbox() -> void:
	busy = true
	menus.close_all()
	_free_world()
	admin = true
	no_cold = true
	god = true
	ai_off = true
	stage = ""
	objectives.clear()
	_make_world(Cfg.arg("place", "hub"))
	player.flares = 3
	set_flag("flares_known")
	director = Director.new()
	director.name = "Director"
	director.world = world
	world.add_child(director)
	director.begin("sandbox")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	main.set_fade(Color(0, 0, 0, 0))
	_apply_debug_args()
	busy = false


func open_museum(tab := "figure") -> void:
	busy = true
	menus.close_all()
	_free_world()
	hud.visible = false
	admin = true
	var m := Museum.new()
	m.name = "Museum"
	museum = m
	main.set_scene(m)
	m.open_tab(tab)
	main.set_fade(Color(0, 0, 0, 0))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	busy = false


# ------------------------------------------------------------------ сохранение

func _load_save() -> void:
	if not FileAccess.file_exists(SAVE):
		return
	var f := FileAccess.open(SAVE, FileAccess.READ)
	if f == null:
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return
	var dd: Dictionary = d
	stage = String(dd.get("stage", ""))
	notes = Array(dd.get("notes", []))
	flags = Dictionary(dd.get("flags", {}))
	endings_seen = Array(dd.get("endings", []))
	readings.clear()
	var rr: Dictionary = dd.get("readings", {})
	for k in rr:
		readings[int(String(k))] = rr[k]


func has_save() -> bool:
	return stage != "" and stage != "sandbox"


func save_game() -> void:
	if Cfg.testing() or admin:
		return
	var rr := {}
	for k in readings:
		rr[str(k)] = readings[k]
	var d := {"stage": stage, "notes": notes, "flags": flags, "readings": rr, "endings": endings_seen, "version": 1}
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


## Режиссёр дошёл до контрольной точки.
func checkpoint(id: String) -> void:
	stage = id
	save_game()
	print("LOG checkpoint ", id)


# ------------------------------------------------------------------ задачи, записки

func set_obj(id: String) -> void:
	for o in objectives:
		if String((o as Dictionary).id) == id:
			return
	var text := String(T.OBJ.get(id, id))
	objectives.append({"id": id, "text": text, "done": false})
	hud.objective(text)


func done_obj(id: String) -> void:
	for o in objectives:
		var od: Dictionary = o
		if String(od.id) == id and not bool(od.done):
			od.done = true
			Snd.play("tick", -8.0)


func act(id: String) -> void:
	if director != null and is_instance_valid(director):
		director.act(id)


func read(id: String) -> void:
	if not T.NOTES.has(id):
		return
	if not id in notes:
		notes.append(id)
	var args: Array = []
	if id == "j1":
		var r: Dictionary = readings.get(1, {})
		args = [String(r.get("t", "—")), String(r.get("w", "—")), String(r.get("s", "—"))]
	if notebook.is_open:
		notebook.close()
	note_view.open(id, args)
	ui_frame = Engine.get_process_frames()
	if director != null and is_instance_valid(director):
		director.act("read_" + id)


# ------------------------------------------------------------------ окна и ввод

func overlay() -> String:
	if note_view != null and note_view.is_open:
		return "note"
	if notebook != null and notebook.is_open:
		return "notebook"
	if radio_ui != null and radio_ui.is_open:
		return "radio"
	if admin_panel != null and admin_panel.is_open:
		return "admin"
	if menus != null and menus.is_open():
		return "menu"
	return ""


func _process(dt: float) -> void:
	if _menu_cam != null and is_instance_valid(_menu_cam):
		_menu_t += dt
		_menu_cam.global_position = Vector3(15.5 + sin(_menu_t * 0.11) * 0.5, 1.75 + sin(_menu_t * 0.23) * 0.05, 8.6 + cos(_menu_t * 0.09) * 0.4)
		_menu_cam.look_at(Vector3(4.0, 1.5, 1.6))
	if not in_game or player == null or not is_instance_valid(player):
		return
	var ov := overlay()
	player.control = ov == "" and not busy
	var want_mouse := ov == "notebook" or ov == "admin" or ov == "menu" or (cards != null and cards.mouse_filter == Control.MOUSE_FILTER_STOP)
	var mm := Input.MOUSE_MODE_VISIBLE if want_mouse else Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode != mm:
		Input.mouse_mode = mm


func _unhandled_input(e: InputEvent) -> void:
	if museum != null and e.is_action_pressed("pause"):
		show_menu("admin")
		return
	if not in_game or dying:
		return
	var same_frame := Engine.get_process_frames() == ui_frame
	var ov := overlay()
	if e.is_action_pressed("pause"):
		if ov == "note":
			note_view.close()
		elif ov == "notebook":
			notebook.close()
		elif ov == "admin":
			admin_panel.close()
		elif ov == "" and not busy and not cards.busy():
			menus.open("pause")
			get_tree().paused = true
		get_viewport().set_input_as_handled()
	elif (e.is_action_pressed("use") or e.is_action_pressed("breath")) and ov == "note" and not same_frame:
		note_view.close()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("notebook"):
		if ov == "notebook":
			notebook.close()
		elif ov == "" and not busy and player.mode != "dead":
			notebook.open()
			ui_frame = Engine.get_process_frames()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("admin") and (admin or Cfg.admin_key):
		if ov == "admin":
			admin_panel.close()
		elif ov == "":
			admin_panel.open()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("freecam") and (admin or Cfg.admin_key) and ov == "":
		toggle_freecam()


func resume() -> void:
	get_tree().paused = false
	menus.close_all()


func toggle_freecam() -> void:
	if player == null:
		return
	if player.mode == "free":
		player.set_mode("walk")
		player.global_position.y = 0.0
		hud.toast("Свободная камера выключена")
	elif player.mode == "walk":
		player.set_mode("free")
		hud.toast("Свободная камера: WASD, Пробел/Ctrl, Shift — быстрее")


# ------------------------------------------------------------------ смерть и концовки

func die(kind: String) -> void:
	if dying or god or not in_game:
		return
	dying = true
	busy = true
	print("LOG death ", kind)
	if Cfg.has_arg("bot"):
		print("BOT DIED ", kind, " at ", stage)
		get_tree().quit()
		return
	for w in [note_view, notebook, radio_ui, admin_panel]:
		if w.is_open:
			w.close()
	player.control = false
	if kind == "taken":
		await _kill_scene()
	elif kind == "freeze":
		player.set_mode("dead")
		Snd.play("freeze_tone", -2.0)
		Snd.muffle(0.8)
		main.fade_to(Color(0.92, 0.95, 1.0, 1.0), 3.2)
		await get_tree().create_timer(4.0).timeout
	else:
		player.set_mode("dead")
		main.set_fade(Color(0, 0, 0, 1))
		Snd.play("death_hit", 0.0)
		await get_tree().create_timer(1.0).timeout
	Snd.stop_all(0.4)
	var dd: Array = T.DEATH.get(kind, T.DEATH["taken"])
	cards.death(String(dd[0]), String(dd[1]))
	var what: String = await cards.chosen
	main.set_fade(Color(0, 0, 0, 1))
	cards.black(0.0)
	cards.visible = false
	Snd.muffle(0.0, true)
	if what == "retry":
		start_stage(stage)
	else:
		show_menu()


## Оно схватило: фонарь гаснет, лицо в упор, крик, темнота.
func _kill_scene() -> void:
	player.set_mode("locked")
	Snd.play("sting_screech", -2.0)
	player.lamp_flicker = 0.4
	var fwd := player.look_dir()
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	await get_tree().create_timer(0.35).timeout
	if entity != null and is_instance_valid(entity):
		var pos := player.global_position + fwd * 0.82
		entity.show_pose(pos, rad_to_deg(player.yaw) + 180.0, 1.0, 1.0)
		entity.fig.eyes_always = 1.0
		entity.fig.jerk = false
		player.pitch = 0.12
	player.lamp_dead_t = 0.0
	player.lamp_locked = false
	player.set_lamp(true, true)
	player.shake(1.2, 0.7)
	main.burst(1.0)
	main.flash = 0.5
	Snd.play("ent_scream", 3.0)
	await get_tree().create_timer(0.55).timeout
	Snd.play("death_hit", 2.0)
	main.set_fade(Color(0, 0, 0, 1))
	player.set_mode("dead")
	Snd.muffle(1.0)
	await get_tree().create_timer(1.6).timeout


func ending(id: String) -> void:
	if dying:
		return
	dying = true
	busy = true
	print("LOG ending ", id)
	if Cfg.has_arg("bot"):
		print("BOT DONE ending ", id)
		get_tree().quit()
		return
	if not id in endings_seen:
		endings_seen.append(id)
	if not admin:
		var keep := stage
		save_game()
		stage = keep
	for w in [note_view, notebook, radio_ui, admin_panel]:
		if w.is_open:
			w.close()
	if player != null:
		player.control = false
	main.fade_to(Color(0, 0, 0, 1), 1.5)
	await get_tree().create_timer(1.6).timeout
	Snd.stop_all(1.0)
	Snd.muffle(0.0, true)
	hud.visible = false
	Snd.loop("music", "music_end", 0.6, 2.0, "Music")
	var ed: Dictionary = T.ENDINGS[id]
	await cards.ending(String(ed.title), ed.lines, T.CREDITS)
	cards.visible = false
	show_menu("admin" if admin else "main")


# ------------------------------------------------------------------ отладка

func _apply_debug_args() -> void:
	if Cfg.has_arg("pos"):
		var a := Cfg.arg("pos").split(",")
		player.teleport(Vector3(float(a[0]), float(a[1]), float(a[2])), Cfg.argf("yaw", 0.0))
	elif Cfg.has_arg("yaw"):
		player.yaw = deg_to_rad(Cfg.argf("yaw", 0.0))
	if Cfg.has_arg("pitch"):
		player.pitch = deg_to_rad(Cfg.argf("pitch", 0.0))
	player._apply_look()
	if Cfg.arg("lamp", "0") == "1":
		player.set_lamp(true, true)
	if Cfg.has_arg("base"):
		world.weather.base = Cfg.argf("base", 0.55)
	if Cfg.has_arg("clear"):
		world.weather.clear = Cfg.argf("clear", 0.0)
	if Cfg.has_arg("bright"):
		world.weather.bright = Cfg.argf("bright", 0.0)
	if Cfg.has_arg("gust"):
		world.weather.auto_gusts = false
		world.weather.force_gust(Cfg.argf("gust", 0.9), 60.0)
	if Cfg.has_arg("nogust"):
		world.weather.auto_gusts = false
	if Cfg.has_arg("flare"):
		player.flares = 3
		player.light_flare()
	if Cfg.has_arg("nopower"):
		world.set_power(false, true)
	if Cfg.has_arg("grip"):
		player.try_grip()
	if Cfg.has_arg("cold"):
		player.warmth = Cfg.argf("cold", 20.0)
	if Cfg.has_arg("nocold"):
		no_cold = true
	if Cfg.has_arg("god"):
		god = true
	if Cfg.has_arg("ent"):
		# --ent=дистанция,неправильность[,руки]: поставить существо перед игроком
		var e := Cfg.arg("ent").split(",")
		var fwd := Basis(Vector3.UP, player.yaw) * Vector3.FORWARD
		var pos := player.global_position + fwd * float(e[0])
		entity.show_pose(pos, rad_to_deg(player.yaw) + 180.0, float(e[1]) if e.size() > 1 else 1.0, float(e[2]) if e.size() > 2 else 0.0)
	if Cfg.has_arg("griptest"):
		_griptest.call_deferred()
	if Cfg.has_arg("eyes"):
		entity.fig.eyes_always = Cfg.argf("eyes", 1.0)
	if Cfg.has_arg("hunt"):
		ai_off = false
		entity.level = int(Cfg.argf("hunt", 3.0))
		entity.hunt_near(14.0, 0.6)
	if Cfg.has_arg("ev") and director != null:
		# --ev=событие[,событие]: вызвать события режиссёра
		for evn in Cfg.arg("ev").split(","):
			director.ev(String(evn))
	if Cfg.has_arg("hideview"):
		# вид из-под койки: оно стоит рядом
		player.set_mode("hide")
		player.pose(Vector3(4.42, 0.2, -1.2), 90.0, 0.0, Vector2(0.75, 0.22))
		entity.show_pose(Vector3(3.5, 0.03, -1.25), -90.0, 1.0, 0.0)
		entity.carry_light(true)
		world.set_power(false, true)
	if Cfg.has_arg("note"):
		read(Cfg.arg("note"))
	if Cfg.has_arg("notebook"):
		notebook.open(int(Cfg.argf("notebook", 0.0)))
	if Cfg.has_arg("radio"):
		radio_ui.open()
	if Cfg.has_arg("panel"):
		admin_panel.open()
	if Cfg.has_arg("tour"):
		_tour.call_deferred()


## Обойти места и снять по кадру: --tour=<папка> [--only=a,b,c] (кадры: <папка>/<место>.png)
func _tour() -> void:
	var dir := Cfg.arg("tour")
	DirAccess.make_dir_recursive_absolute(dir)
	var names: Array = world.places.keys()
	if Cfg.has_arg("only"):
		names = Array(Cfg.arg("only").split(","))
	await get_tree().create_timer(2.5).timeout
	for nm in names:
		if not world.places.has(nm):
			continue
		world.goto(String(nm))
		if Cfg.has_arg("pitch"):
			player.pitch = deg_to_rad(Cfg.argf("pitch", 0.0))
		await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		main.screenshot(dir + "/" + String(nm) + ".png")
		print("SHOT ", nm, " fps=", Engine.get_frames_per_second())
	get_tree().quit()


## Проверка хвата: взяться за леер у развязки, глядя на север, и идти вперёд; печатает путь.
func _griptest() -> void:
	await get_tree().create_timer(1.0).timeout
	player.teleport(Map.HUB + Vector3(0.5, 0, -0.6), 0.0)
	await get_tree().create_timer(0.3).timeout
	player.try_grip()
	print("GRIP line=", player.grip_line, " on=", player.gripping)
	Input.action_press("move_f")
	for i in 16:
		await get_tree().create_timer(2.0).timeout
		var n: Dictionary = world.ropes.nearest(player.global_position, 4.0)
		print("GRIP t=%d pos=(%.1f, %.1f) line=%s s=%.1f d=%.2f grip=%s" % [i * 2 + 2, player.global_position.x, player.global_position.z,
			String(n.get("line", "-")), float(n.get("s", -1.0)), float(n.get("d", -1.0)), str(player.gripping)])
	Input.action_release("move_f")
	Input.action_press("move_b")
	await get_tree().create_timer(4.0).timeout
	print("GRIP back pos=(%.1f, %.1f)" % [player.global_position.x, player.global_position.z])
	Input.action_release("move_b")
	get_tree().quit()
