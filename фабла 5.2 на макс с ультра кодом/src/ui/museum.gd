class_name Museum
extends Node3D
## Музей (админ-режим): существо со всех сторон, все модели, записки, звуки и голоса, концовки.

const TABS := [["figure", "Существо"], ["models", "Модели"], ["notes", "Записки"], ["sounds", "Звуки и голоса"], ["endings", "Концовки"]]

var tab := "figure"
var cam: Camera3D
var pivot: Node3D
var subject: Node3D = null
var fig: Figure = null
var ui: Control
var side: VBoxContainer
var info: Label
var yaw := 0.6
var pitch := 0.12
var dist := 3.6
var target := Vector3(0, 1.1, 0)
var spin := true
var _drag := false
var _walk := false


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.018, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.4, 0.45, 0.55)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := SpotLight3D.new()
	key.position = Vector3(2.4, 3.2, 3.0)
	key.light_energy = 9.0
	key.spot_range = 12.0
	key.spot_angle = 38.0
	key.light_color = Color(1.0, 0.92, 0.8)
	key.shadow_enabled = true
	add_child(key)
	key.look_at(Vector3(0, 1.0, 0))
	var rim := OmniLight3D.new()
	rim.position = Vector3(-2.5, 2.4, -2.6)
	rim.light_energy = 2.2
	rim.omni_range = 9.0
	rim.light_color = Color(0.55, 0.7, 1.0)
	add_child(rim)
	var b := Batch.new()
	b.cyl(Vector3(0, -0.06, 0), 1.7, 0.12, Kit.mat("floorwood", 1.5, Color(0.5, 0.5, 0.5)), 28)
	b.box(Vector3(0, -0.2, 0), Vector3(30, 0.1, 30), Kit.flat(Color(0.03, 0.03, 0.035), 0.9), false)
	b.commit(self, "Stage")
	pivot = Node3D.new()
	add_child(pivot)
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.make_current()
	RenderingServer.global_shader_parameter_set("g_lamp_on", 0.0)
	RenderingServer.global_shader_parameter_set("g_gust", 0.0)
	RenderingServer.global_shader_parameter_set("g_clear", 1.0)
	_build_ui()


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("g_clear", 0.0)
	if ui != null and is_instance_valid(ui):
		ui.queue_free()


func _build_ui() -> void:
	ui = Control.new()
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	G.main.ui_layer.add_child(ui)
	var top := Ui.hbox(4)
	top.position = Vector2(24, 16)
	ui.add_child(top)
	for t in TABS:
		var key := String(t[0])
		top.add_child(Ui.button(String(t[1]), func() -> void: open_tab(key), 24))
	top.add_child(Ui.button("← Назад в меню", func() -> void: G.show_menu("admin"), 24))
	var p := Ui.panel(Color(0.02, 0.025, 0.03, 0.85))
	p.position = Vector2(24, 76)
	ui.add_child(p)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(430, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	side = Ui.vbox(2)
	sc.add_child(side)
	info = Ui.label("", 22, Ui.TEXT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.position = Vector2(500, 600)
	info.size = Vector2(740, 100)
	ui.add_child(info)


func _clear_subject() -> void:
	if subject != null and is_instance_valid(subject):
		subject.queue_free()
	subject = null
	fig = null


func open_tab(t: String) -> void:
	tab = t
	for c in side.get_children():
		c.queue_free()
	info.text = ""
	match t:
		"figure":
			_tab_figure(false)
		"models":
			_tab_models()
		"notes":
			_tab_notes()
		"sounds":
			_tab_sounds()
		"endings":
			_tab_endings()


func _tab_figure(frozen: bool) -> void:
	_clear_subject()
	fig = Figure.make(pivot, frozen)
	subject = fig
	fig.rotation.y = PI
	fig.set_wrong(0.0 if frozen else 1.0)
	fig.eyes_always = 0.0 if frozen else 1.0
	_walk = false
	if frozen:
		fig.jerk = false
		fig.set_pose("sit")
	target = Vector3(0, 0.6 if frozen else 1.2, 0)
	dist = 3.4 if frozen else 4.0
	for c in side.get_children():
		c.queue_free()
	side.add_child(Ui.label("ОТЗЫВ" if not frozen else "ГРОМОВ", 30, Ui.ACCENT, "head"))
	var d := Ui.label("Оно отвечает на любой сигнал — светом на свет, стуком на стук, голосом на голос. Чем дольше учится, тем меньше похоже на человека." if not frozen
		else "Николай Петрович Громов, начальник станции. Ушёл 14 января. Сидит в леднике у скважины № 3.", 19, Ui.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 410
	side.add_child(d)
	if not frozen:
		side.add_child(Ui.slider("Неправильность", 0.0, 1.0, 0.05, 1.0, func(x: float) -> void: fig.set_wrong(x), "%.2f", 170.0, 150.0))
		side.add_child(Ui.slider("Тянет руки", 0.0, 1.0, 0.05, 0.0, func(x: float) -> void: fig.reach = x, "%.2f", 170.0, 150.0))
		side.add_child(Ui.check("Идёт", false, func(x: bool) -> void: _set_walk(x)))
		side.add_child(Ui.check("Движется рывками", true, func(x: bool) -> void: fig.jerk = x))
		side.add_child(Ui.check("Глаза светятся", true, func(x: bool) -> void: fig.eyes_always = 1.0 if x else 0.0))
		side.add_child(Ui.check("Смотрит в камеру", false, func(x: bool) -> void: fig.look_on = x))
		side.add_child(Ui.button("Лицо крупно", func() -> void: _face_close(), 22, 400))
		side.add_child(Ui.button("Показать Громова в леднике", func() -> void: _tab_figure(true), 22, 400))
	else:
		side.add_child(Ui.button("Показать Отзыв", func() -> void: _tab_figure(false), 22, 400))
	side.add_child(Ui.check("Вращать площадку", spin, func(x: bool) -> void: spin = x))


func _set_walk(x: bool) -> void:
	_walk = x
	if fig != null:
		fig.speed = 1.6 if x else 0.0


func _face_close() -> void:
	spin = false
	pivot.rotation.y = 0.0
	yaw = 0.0
	pitch = 0.02
	dist = 0.75
	target = fig.head_pos() if fig != null else Vector3(0, 1.9, 0)


func _tab_models() -> void:
	_clear_subject()
	side.add_child(Ui.label("МОДЕЛИ", 30, Ui.ACCENT, "head"))
	var d := Ui.label("Модели CC0 с Poly Haven. Постройки, приборы, леера и существо собраны кодом.", 18, Ui.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 410
	side.add_child(d)
	var names: PackedStringArray = ResourceLoader.list_directory("res://mdl/")
	var first := ""
	for nm in names:
		var s := String(nm).trim_suffix("/")
		if not ResourceLoader.exists("res://mdl/%s/m.gltf" % s):
			continue
		if first == "":
			first = s
		side.add_child(Ui.button(s, func() -> void: _show_model(s), 19, 400))
	if first != "":
		_show_model(first)


func _show_model(short: String) -> void:
	_clear_subject()
	var n := Kit.put(pivot, short, Vector3.ZERO)
	if n == null:
		return
	subject = n
	for mi in Kit.meshes(n):
		(mi as MeshInstance3D).lod_bias = 4.0
		(mi as MeshInstance3D).visibility_range_end = 0.0
	var bb: AABB = Kit._bounds.get(short, AABB(Vector3.ZERO, Vector3.ONE))
	var r := maxf(bb.size.length(), 0.2)
	target = Vector3(0, bb.size.y * 0.5, 0)
	dist = clampf(r * 1.5, 0.5, 9.0)
	info.text = "%s — %.2f × %.2f × %.2f м" % [short, bb.size.x, bb.size.y, bb.size.z]


func _tab_notes() -> void:
	_clear_subject()
	side.add_child(Ui.label("ЗАПИСКИ", 30, Ui.ACCENT, "head"))
	for id in T.NOTES:
		var nid := String(id)
		side.add_child(Ui.button(String(T.NOTES[id].title), func() -> void: _note(nid), 19, 400))


func _note(id: String) -> void:
	var args: Array = ["−31,2", "18", "74"] if id == "j1" else []
	G.note_view.open(id, args)
	G.ui_frame = Engine.get_process_frames()


func _tab_sounds() -> void:
	_clear_subject()
	side.add_child(Ui.label("ГОЛОСА", 30, Ui.ACCENT, "head"))
	for k in T.VOICE:
		var key := String(k)
		var txt := String(T.VOICE[k])
		side.add_child(Ui.button(key + "  —  " + txt.left(34), func() -> void: _voice(key), 17, 400))
	side.add_child(Ui.label("ЗВУКИ", 30, Ui.ACCENT, "head"))
	side.add_child(Ui.button("■ Остановить всё", func() -> void: _stop_sounds(), 19, 400))
	var g := GridContainer.new()
	g.columns = 2
	side.add_child(g)
	for nm in Snd.names():
		var s := String(nm)
		if T.VOICE.has(s):
			continue
		g.add_child(Ui.button(s, func() -> void: _sound(s), 16, 198))


func _voice(key: String) -> void:
	Snd.cut_oneshots()
	Snd.voice(key)
	info.text = String(T.VOICE[key])


func _sound(nm: String) -> void:
	Snd.play(nm)
	info.text = "%s — %.1f с" % [nm, Snd.length(nm)]


func _stop_sounds() -> void:
	Snd.cut_oneshots()
	Snd.stop_all(0.2)


func _tab_endings() -> void:
	_clear_subject()
	side.add_child(Ui.label("КОНЦОВКИ", 30, Ui.ACCENT, "head"))
	for id in T.ENDINGS:
		var eid := String(id)
		var seen := eid in G.endings_seen
		side.add_child(Ui.button(String(T.ENDINGS[id].title) + ("   ✓ получена" if seen else ""), func() -> void: _ending(eid), 22, 400))
	side.add_child(Ui.label("СМЕРТИ", 30, Ui.ACCENT, "head"))
	for id in T.DEATH:
		var did := String(id)
		side.add_child(Ui.button(String(T.DEATH[id][0]), func() -> void: _death(did), 22, 400))
	var d := Ui.label("Сцены концовок целиком — в «Этапах»: ночь 3 «Ночной визит» (Гость), ночь 5 «Два борта» (Борт и Отзыв).", 18, Ui.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 410
	side.add_child(d)


func _ending(id: String) -> void:
	ui.visible = false
	Snd.loop("music", "music_end", 0.6, 2.0, "Music")
	var ed: Dictionary = T.ENDINGS[id]
	await G.cards.ending(String(ed.title), ed.lines, T.CREDITS)
	G.cards.visible = false
	Snd.stop_loop("music", 1.0)
	if is_instance_valid(ui):
		ui.visible = true


func _death(id: String) -> void:
	ui.visible = false
	var dd: Array = T.DEATH[id]
	G.cards.death(String(dd[0]), String(dd[1]), false)
	await G.cards.chosen
	G.cards.visible = false
	if is_instance_valid(ui):
		ui.visible = true


func _unhandled_input(e: InputEvent) -> void:
	if G.note_view.is_open:
		if (e.is_action_pressed("use") or e.is_action_pressed("pause") or e.is_action_pressed("breath")) and Engine.get_process_frames() != G.ui_frame:
			G.note_view.close()
			get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton:
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			dist = maxf(0.35, dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			dist = minf(14.0, dist * 1.1)
	elif e is InputEventMouseMotion and _drag:
		var mm: InputEventMouseMotion = e
		yaw -= mm.relative.x * 0.008
		pitch = clampf(pitch + mm.relative.y * 0.006, -0.4, 1.3)


func _process(dt: float) -> void:
	if spin and not _drag:
		pivot.rotation.y += dt * 0.35
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	cam.global_position = target + off
	cam.look_at(target)
	# панель слева закрывает треть экрана — сдвигаем предмет вправо
	cam.h_offset = -dist * 0.3
	if fig != null and is_instance_valid(fig):
		fig.look_at_pos = cam.global_position
	if ui != null:
		ui.position = Vector2.ZERO
		ui.size = G.main.get_viewport().get_visible_rect().size
