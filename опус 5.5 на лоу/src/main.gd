extends Node
## Главное меню, переключение между игрой и галереей; режимы --bot и --shot для проверки.

var current: Node
var menu: CanvasLayer

func _ready() -> void:
	if G.args.has("bot"):
		_bot()
		return
	if G.args.has("stairs"):
		start_game(false)
		var g = current
		g._event_t = 99999.0
		await get_tree().create_timer(0.3).timeout
		g.player.global_position = Vector3(20, 12.1, 6)
		var e = g.entity
		e.global_position = Vector3(10, 0.1, 6)
		e._go(Vector3(15, 6, 6), e.S.INVESTIGATE)
		for i in 40:
			await get_tree().create_timer(0.5).timeout
			print("BOT t=%.1f pos=%s st=%s wp=%d/%d tgt=%s" % [i * 0.5, e.global_position, e.state_name(), e.path_i, e.path.size(), e.path[e.path_i] if e.path_i < e.path.size() else Vector3.ZERO])
		get_tree().quit()
		return
	var mode: String = G.args.get("mode", "menu")
	if mode == "game": start_game(G.args.has("admin"))
	elif mode == "gallery": show_gallery()
	else: show_menu()
	if G.args.has("shot"):
		await get_tree().create_timer(float(G.args.get("wait", 3))).timeout
		G.shot_and_quit(get_viewport(), G.args["shot"])

func _clear() -> void:
	get_tree().paused = false
	if current: current.queue_free(); current = null
	if menu: menu.queue_free(); menu = null

func start_game(admin := false) -> void:
	_clear()
	current = preload("res://src/game.gd").new()
	add_child(current)
	current.start(admin)
	if G.args.has("view"): _view(G.args["view"])

func show_gallery() -> void:
	_clear()
	current = preload("res://src/gallery.gd").new()
	add_child(current)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func show_menu() -> void:
	_clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu = CanvasLayer.new()
	add_child(menu)
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.012)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(bg)
	var tex := TextureRect.new()
	tex.texture = load("res://tex/wall.png")
	tex.stretch_mode = TextureRect.STRETCH_TILE
	tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	tex.modulate = Color(0.12, 0.11, 0.1)
	menu.add_child(tex)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.add_theme_constant_override("separation", 12)
	menu.add_child(v)
	var t := Label.new()
	t.text = "П О В Е Р К А"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color(0.75, 0.68, 0.55))
	v.add_child(t)
	var st := Label.new()
	st.text = "дом №7 · посёлок Торфяной · 1994"
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.add_theme_color_override("font_color", Color(0.5, 0.2, 0.18))
	v.add_child(st)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 30); v.add_child(sp)
	for item in [["Начать обход", func(): start_game(false)], ["Админ-режим", func(): start_game(true)],
			["Галерея (Жилец, звуки, записки)", func(): show_gallery()], ["Выход", func(): get_tree().quit()]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(380, 50)
		b.add_theme_font_size_override("font_size", 21)
		b.pressed.connect(item[1])
		v.add_child(b)
	var l1 := Label.new(); l1.text = "Громкость"; v.add_child(l1)
	var s2 := HSlider.new(); s2.min_value = 0; s2.max_value = 1; s2.step = 0.01; s2.value = G.volume
	s2.value_changed.connect(func(x): G.volume = x; G.save_settings())
	v.add_child(s2)
	var l2 := Label.new(); l2.text = "Чувствительность мыши"; v.add_child(l2)
	var s1 := HSlider.new(); s1.min_value = 0.0005; s1.max_value = 0.006; s1.step = 0.0001; s1.value = G.sens
	s1.value_changed.connect(func(x): G.sens = x; G.save_settings())
	v.add_child(s1)
	var hint := Label.new()
	hint.text = "Играйте в наушниках и в темноте."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.45, 0.42, 0.38))
	v.add_child(hint)
	var hum := AudioStreamPlayer.new()
	hum.stream = G.snd("drone", true)
	hum.volume_db = -10
	menu.add_child(hum)
	hum.play()

# ---------------------------------------------------------------- снимки для проверки
func _view(name: String) -> void:
	await get_tree().process_frame
	var g = current
	var p = g.player
	match name:
		"corridor":
			p.global_position = Vector3(1, 3.05, 6); p.yaw = -PI / 2; p.toggle_light()
			g.entity.global_position = Vector3(11, 3.05, 6); g.entity.frozen = true
		"entity":
			p.global_position = Vector3(3, 0.05, 6); p.yaw = -PI / 2; p.toggle_light(); p.pitch = 0.1
			g.entity.global_position = Vector3(6.5, 0.05, 6); g.entity.rotation.y = -PI / 2; g.entity.frozen = true
		"stairs":
			p.global_position = Vector3(-2, 0.05, 5.6); p.yaw = PI; p.pitch = 0.25; p.toggle_light()
			g.entity.frozen = true
		"room":
			p.global_position = Vector3(9.6, 0.05, 4.4); p.yaw = 0.3; p.toggle_light(); g.entity.frozen = true
		"wardrobe":
			g.entity.global_position = Vector3(2.5, 0.05, 2.4); g.entity.frozen = true
			p.hide_in(g.world.wardrobes[0])
		"scare":
			p.global_position = Vector3(5, 0.05, 6); p.yaw = -PI / 2
			await get_tree().create_timer(0.5).timeout
			g.jumpscare()
		"bright":
			g.admin._bright(true); p.global_position = Vector3(14, 0.05, 6); p.yaw = -PI / 2; g.entity.frozen = true

# ---------------------------------------------------------------- бот: проходит игру сам
func _bot() -> void:
	start_game(false)
	var g = current
	await get_tree().create_timer(0.5).timeout
	var p = g.player
	var e = g.entity
	g._event_t = 99999.0
	print("BOT start, meters=", g.world.meters.size(), " wardrobes=", g.world.wardrobes.size(), " waypoints=", g.world.astar.get_point_count())
	# 1) путь с 1 на 5 этаж существует
	var path: PackedVector3Array = g.world.path(Vector3(23, 0, 6), Vector3(3, 12, 9.4))
	print("BOT path 1->5 points=", path.size(), " ok=", path.size() > 10)
	# 2) Жилец слышит бег и идёт на звук
	e.global_position = Vector3(12, 0.1, 6)
	p.global_position = Vector3(20, 0.1, 6)
	g.make_noise(p.global_position, 16)
	print("BOT hear state=", e.state_name())
	await get_tree().create_timer(2.0).timeout
	print("BOT entity moved to x=%.1f (from 12)" % e.global_position.x)
	# 3) Жилец доходит по лестнице до 3 этажа
	e._go(Vector3(15, 6, 6), e.S.INVESTIGATE)
	p.god = true
	var t := 0.0
	while t < 40.0 and g.world.level_of(e.global_position) < 2:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	print("BOT entity pos ", e.global_position, " state ", e.state_name(), " path ", e.path_i, "/", e.path.size(), " frozen ", e.frozen)
	print("BOT entity climbed to floor ", g.world.level_of(e.global_position) + 1, " in ", t, " s")
	# 4) шкаф: спрятаться и выйти
	var w = g.world.wardrobes[3]
	p.global_position = w.get_meta("front")
	p.hide_in(w)
	print("BOT hidden=", p.hidden)
	p.unhide()
	print("BOT unhidden=", not p.hidden)
	# 5) свет и обнаружение
	e.frozen = false
	e.state = e.S.PATROL
	e.global_position = Vector3(6, 0.1, 6); e.rotation.y = PI / 2
	p.global_position = Vector3(12, 0.1, 6); p.yaw = PI / 2
	p.light_on = true; p.light.visible = true
	await get_tree().physics_frame
	p.light.light_energy = 2.6
	var q := PhysicsRayQueryParameters3D.create(e.global_position + Vector3(0, 1.8, 0), p.cam.global_position, 1, [p.get_rid(), e.get_rid()])
	print("BOT ray ", e.get_world_3d().direct_space_state.intersect_ray(q), " energy ", p.light.light_energy, " cam ", p.cam.global_position)
	print("BOT sees lit player=", e._can_see(p), " entity at ", e.global_position)
	p.light_on = false; p.light.visible = false
	print("BOT sees dark player at 6m=", e._can_see(p))
	# 6) все счётчики через взгляд + удержание E недоступно в headless — читаем напрямую
	e.frozen = true
	for m in g.world.meters:
		g.meter_read(m)
	print("BOT read=", g.read_count, " phase=", g.phase, " exit_open=", g.exit_open)
	g.try_exit()
	print("BOT over=", g.over)
	# 7) смерть
	start_game(false)
	g = current
	await get_tree().create_timer(0.3).timeout
	g.entity.global_position = g.player.global_position + Vector3(0.6, 0, 0)
	g.entity._start_chase()
	await get_tree().create_timer(2.5).timeout
	print("BOT death over=", g.over)
	print("BOT DONE")
	get_tree().quit()
