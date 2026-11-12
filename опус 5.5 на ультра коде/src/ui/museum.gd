class_name Museum
extends Node3D
## Музей админ-режима: Хозяйка на подставке (анимации, сутулость, челюсть, волосы, свет), рука,
## фигура под простынёй, предметы, все записки, все сообщения, все звуки.

var body: HozBody
var cam: Camera3D
var pivot: Node3D
var dist := 3.4
var orbit := Vector2(0.4, 0.15)
var dragging := false
var ui: Control
var right_box: VBoxContainer
var showcase: Node3D
var lamp: SpotLight3D
var hand: HozHand


func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.02, 0.02, 0.025)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.4, 0.42, 0.48)
	e.ambient_light_energy = 0.25
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	var b := Geo.Batch.new()
	b.box(Mat.m("tile_floor", {"wet": 0.8}), Vector3(0, -0.15, 0), Vector3(14, 0.3, 14))
	b.box(Mat.m("tile_wall"), Vector3(0, 2.5, -5), Vector3(14, 5, 0.2))
	b.box(Mat.m("concrete"), Vector3(0, 0.1, 0), Vector3(1.6, 0.2, 1.6))
	b.commit(self, "room")
	lamp = SpotLight3D.new()
	lamp.position = Vector3(0, 4.5, 2.5)
	lamp.light_energy = 5.0
	lamp.spot_range = 10.0
	lamp.spot_angle = 35.0
	lamp.shadow_enabled = true
	add_child(lamp)
	lamp.look_at(Vector3(0, 1.0, 0))
	var fill := OmniLight3D.new()
	fill.position = Vector3(-2.5, 1.5, 1.5)
	fill.light_color = Color(1.0, 0.5, 0.2)
	fill.light_energy = 1.2
	fill.omni_range = 6.0
	add_child(fill)
	showcase = Node3D.new()
	add_child(showcase)
	body = HozBody.new()
	showcase.add_child(body)
	body.position = Vector3(0, 0.2, 0)
	body.floor_y = 0.2
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.3, 0)
	add_child(pivot)
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 55
	pivot.add_child(cam)
	_ui()
	Snd.music("mus_tension", -10.0, 2.0)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.theme = UI.get_theme()
	UI.full(ui)
	ui.mouse_filter = Control.MOUSE_FILTER_PASS
	layer.add_child(ui)
	var left := PanelContainer.new()
	left.position = Vector2(20, 20)
	left.size = Vector2(380, 1000)
	ui.add_child(left)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(350, 960)
	left.add_child(sc)
	var v := VBoxContainer.new()
	sc.add_child(v)
	v.add_child(UI.label("Музей", 34, UI.ACCENT, "PTSerif-Regular.ttf"))
	v.add_child(UI.label("ЛКМ + мышь — вращать, колесо — приблизить", 15, UI.DIM))
	v.add_child(UI.label("Анимации", 20, UI.ACCENT))
	for a in [["idle", "Стоит, дышит"], ["walk", "Ходьба (хромая)"], ["walk2", "Ходьба 2"], ["stagger", "Шатается"], ["run", "Бросок"], ["look", "Ищет, прислушивается"], ["crouch", "Сидит, моет волосы"], ["crouch_in", "Садится"]]:
		var an: String = a[0]
		v.add_child(UI.button(String(a[1]), func(): body.play(an, 0.3), 19))
	v.add_child(UI.label("Надстройка", 20, UI.ACCENT))
	v.add_child(UI.slider("Сутулость", 0, 1, 0.05, 0.5, func(x): body.rig.stoop = x))
	v.add_child(UI.slider("Челюсть", 0, 1, 0.05, 0.0, func(x): body.rig.jaw = x))
	v.add_child(UI.slider("Тянется руками", 0, 1, 0.05, 0.0, func(x): body.rig.reach = x))
	v.add_child(UI.slider("Пригнулась", 0, 1, 0.05, 0.0, func(x): body.rig.crawl = x))
	v.add_child(UI.slider("Дёрганья", 0, 1, 0.05, 0.35, func(x): body.rig.twitch = x))
	v.add_child(UI.slider("Волосы расступились", 0, 1, 0.05, 0.0, func(x): body.set_part(x)))
	v.add_child(UI.toggle("Тёплый свет вместо белого", false, func(on: bool):
		lamp.light_color = Color(1.0, 0.55, 0.25) if on else Color(1, 1, 1)))
	v.add_child(UI.label("Ещё", 20, UI.ACCENT))
	v.add_child(UI.button("Рука на плече", _show_hand, 19))
	v.add_child(UI.button("Хозяйка", func(): _show_only(body), 19))
	v.add_child(UI.button("Выход в админ-меню", func():
		Snd.music("", 0.0, 1.0)
		var m = Game.main
		queue_free()
		m.open_admin_menu(), 19))
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-520, 20)
	right.size = Vector2(500, 1000)
	ui.add_child(right)
	var tabs := VBoxContainer.new()
	right.add_child(tabs)
	var th := HBoxContainer.new()
	tabs.add_child(th)
	th.add_child(UI.button("Записки", _list_notes, 19))
	th.add_child(UI.button("Сообщения", _list_msgs, 19))
	th.add_child(UI.button("Звуки", _list_sounds, 19))
	var sc2 := ScrollContainer.new()
	sc2.custom_minimum_size = Vector2(470, 900)
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc2)
	right_box = VBoxContainer.new()
	sc2.add_child(right_box)
	_list_notes()


func _clear_right() -> void:
	for c in right_box.get_children():
		c.queue_free()


func _list_notes() -> void:
	_clear_right()
	for id in Texts.all_notes():
		var nid: String = id
		right_box.add_child(UI.button(String(Texts.note(nid)["title"]), func(): _note(nid), 19))


func _note(id: String) -> void:
	var c := Screens.note(id, func(): pass)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(c)
	var btns := c.find_children("*", "Button", true, false)
	for bt in btns:
		(bt as Button).pressed.connect(func(): layer.queue_free())


func _list_msgs() -> void:
	_clear_right()
	for id in Texts.MESSAGES:
		var m: Array = Texts.MESSAGES[id]
		var l := UI.label("%s  %s\n%s" % [m[0], m[1], m[2]], 17)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(440, 0)
		right_box.add_child(l)


func _list_sounds() -> void:
	_clear_right()
	for n in Snd.names():
		var sn: String = n
		var b := UI.button(sn, func():
			var p := Snd.play(sn, 0.0, 1.0, "Voice" if sn.begins_with("hoz") or sn == "phone_call" or sn == "memory" else "SFX")
			if sn.begins_with("loop_") and p:
				get_tree().create_timer(5.0).timeout.connect(p.queue_free), 17)
		right_box.add_child(b)


func _show_hand() -> void:
	if hand == null:
		hand = HozHand.new()
		cam.add_child(hand)
	hand.visible = not hand.visible


func _show_only(n: Node3D) -> void:
	for c in showcase.get_children():
		(c as Node3D).visible = c == n


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			dist = maxf(0.6, dist - 0.2)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			dist = minf(7.0, dist + 0.2)
	elif e is InputEventMouseMotion and dragging:
		orbit.x -= (e as InputEventMouseMotion).relative.x * 0.008
		orbit.y = clampf(orbit.y + (e as InputEventMouseMotion).relative.y * 0.006, -0.6, 1.2)


func _process(_d: float) -> void:
	pivot.rotation = Vector3(-orbit.y, orbit.x, 0)
	cam.position = Vector3(0, 0, dist)
	var hp := body.head_pos()
	pivot.position = pivot.position.lerp(Vector3(0, clampf(hp.y - 0.6, 0.8, 2.2) if dist > 1.5 else hp.y, 0), 0.05)
