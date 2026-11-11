class_name Menus
extends Control
## Главное меню, пауза, настройки, админ-режим (этапы, песочница, музей).

var screen := ""
var _dim: ColorRect
var _root: Control
var _back_to := "main"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	visible = false


func is_open() -> bool:
	return screen != ""


func close_all() -> void:
	screen = ""
	visible = false
	_clear()


func _clear() -> void:
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func open(name_: String) -> void:
	_clear()
	screen = name_
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	match name_:
		"main":
			_dim.color = Color(0, 0, 0, 0.25)
			_main()
		"pause":
			_dim.color = Color(0, 0, 0, 0.6)
			_pause()
		"settings":
			_dim.color = Color(0, 0, 0, 0.7)
			_settings()
		"admin":
			_dim.color = Color(0, 0, 0, 0.55)
			_admin()
		"stages":
			_dim.color = Color(0, 0, 0, 0.7)
			_stages()


func _process(_dt: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_dim.size = size
	if _root != null:
		_root.size = size


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e.is_action_pressed("pause"):
		match screen:
			"pause":
				G.resume()
			"settings":
				open(_back_to)
			"admin":
				open("main")
			"stages":
				open("admin")
		get_viewport().set_input_as_handled()


func _column(x: float, y: float) -> VBoxContainer:
	var v := Ui.vbox(4)
	v.position = Vector2(x, y)
	_root.add_child(v)
	return v


func _title(v: VBoxContainer) -> void:
	var t := Ui.label("ЛЕЕР", 150, Color(0.93, 0.91, 0.86), "head")
	v.add_child(t)
	var s := Ui.label("Полярная станция «Тихая».  В пургу сигналов не подавать.", 22, Color(0.75, 0.2, 0.15), "type")
	v.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size.y = 46
	v.add_child(sp)


func _main() -> void:
	var v := _column(96, 70)
	_title(v)
	var first: Button = null
	if G.has_save():
		var nm := String(Director.TITLES.get(G.stage, ""))
		var n := int(G.stage.substr(1, 1)) if G.stage.length() > 1 else 1
		first = Ui.button("Продолжить — ночь %d: %s" % [n, nm.to_lower()], func() -> void: G.continue_game(), 30, 520)
		v.add_child(first)
	var ng := Ui.button("Новая игра", func() -> void: G.new_game(), 30, 520)
	v.add_child(ng)
	if first == null:
		first = ng
	v.add_child(Ui.button("Настройки", func() -> void: _to_settings("main"), 30, 520))
	v.add_child(Ui.button("Админ-режим: просмотр всего содержимого", func() -> void: open("admin"), 30, 520))
	v.add_child(Ui.button("Выход", func() -> void: get_tree().quit(), 30, 520))
	first.grab_focus.call_deferred()
	var foot := Ui.label("WASD — идти · F — фонарь · ПКМ — леер · E — действие · Tab — блокнот", 18, Ui.DIM)
	foot.position = Vector2(100, 650)
	_root.add_child(foot)


func _pause() -> void:
	var p := Ui.panel()
	_root.add_child(p)
	var v := Ui.vbox(6)
	p.add_child(v)
	v.add_child(Ui.label("ПАУЗА", 44, Ui.TEXT, "head"))
	var b := Ui.button("Продолжить", func() -> void: G.resume(), 28, 380)
	v.add_child(b)
	v.add_child(Ui.button("Настройки", func() -> void: _to_settings("pause"), 28, 380))
	if G.admin:
		v.add_child(Ui.button("Админ-панель (F1)", _open_panel, 28, 380))
	if G.stage != "" and G.stage != "sandbox":
		v.add_child(Ui.button("С контрольной точки", _retry, 28, 380))
	v.add_child(Ui.button("В меню", _to_menu, 28, 380))
	p.position = Vector2(120, 180)
	b.grab_focus.call_deferred()


func _settings() -> void:
	var p := Ui.panel()
	_root.add_child(p)
	p.position = Vector2(110, 60)
	var v := Ui.vbox(9)
	p.add_child(v)
	v.add_child(Ui.label("НАСТРОЙКИ", 40, Ui.TEXT, "head"))
	v.add_child(Ui.slider("Чувствительность мыши", 0.2, 3.0, 0.05, Cfg.sens, func(x: float) -> void: _cfg("sens", x)))
	v.add_child(Ui.slider("Поле зрения", 55.0, 95.0, 1.0, Cfg.fov, func(x: float) -> void: _cfg("fov", x), "%.0f°"))
	v.add_child(Ui.slider("Общая громкость", 0.0, 1.0, 0.05, Cfg.vol_master, func(x: float) -> void: _cfg("vol_master", x)))
	v.add_child(Ui.slider("Звуки", 0.0, 1.0, 0.05, Cfg.vol_sfx, func(x: float) -> void: _cfg("vol_sfx", x)))
	v.add_child(Ui.slider("Ветер и музыка", 0.0, 1.0, 0.05, Cfg.vol_amb, func(x: float) -> void: _cfg("vol_amb", x)))
	v.add_child(Ui.slider("Голоса", 0.0, 1.0, 0.05, Cfg.vol_voice, func(x: float) -> void: _cfg("vol_voice", x)))
	v.add_child(Ui.slider("Чёткость: 0 — 360, 1 — 480, 2 — 540, 3 — 720 строк", 0.0, 3.0, 1.0, float(Cfg.RES_LIST.find(Cfg.res)), func(x: float) -> void: _cfg("res", int(Cfg.RES_LIST[int(x)])), "%.0f"))
	v.add_child(Ui.slider("Зерно плёнки", 0.0, 1.5, 0.05, Cfg.grain, func(x: float) -> void: _cfg("grain", x)))
	v.add_child(Ui.check("На весь экран", Cfg.fullscreen, func(x: bool) -> void: _cfg("fullscreen", x)))
	v.add_child(Ui.check("Качание головы при ходьбе", Cfg.head_bob, func(x: bool) -> void: _cfg("head_bob", x)))
	v.add_child(Ui.check("Субтитры", Cfg.subtitles, func(x: bool) -> void: _cfg("subtitles", x)))
	v.add_child(Ui.check("Инверсия мыши по вертикали", Cfg.invert_y, func(x: bool) -> void: _cfg("invert_y", x)))
	v.add_child(Ui.check("Админ-панель по F1 и в обычной игре", Cfg.admin_key, func(x: bool) -> void: _cfg("admin_key", x)))
	var b := Ui.button("Назад", func() -> void: open(_back_to), 28, 300)
	v.add_child(b)
	b.grab_focus.call_deferred()


func _admin() -> void:
	var v := _column(96, 70)
	v.add_child(Ui.label("АДМИН-РЕЖИМ", 64, Ui.TEXT, "head"))
	var s := Ui.label("Просмотр всего содержимого игры. Прогресс обычной игры не трогается.", 20, Ui.DIM)
	v.add_child(s)
	var sp := Control.new()
	sp.custom_minimum_size.y = 26
	v.add_child(sp)
	var b := Ui.button("Этапы — любая ночь с любого места", func() -> void: open("stages"), 28, 620)
	v.add_child(b)
	v.add_child(Ui.button("Песочница — свободная станция с админ-панелью", func() -> void: G.start_sandbox(), 28, 620))
	v.add_child(Ui.button("Музей: существо", func() -> void: G.open_museum("figure"), 28, 620))
	v.add_child(Ui.button("Музей: модели", func() -> void: G.open_museum("models"), 28, 620))
	v.add_child(Ui.button("Музей: записки", func() -> void: G.open_museum("notes"), 28, 620))
	v.add_child(Ui.button("Музей: звуки и голоса", func() -> void: G.open_museum("sounds"), 28, 620))
	v.add_child(Ui.button("Музей: концовки", func() -> void: G.open_museum("endings"), 28, 620))
	v.add_child(Ui.button("Назад", func() -> void: open("main"), 28, 620))
	var tip := Ui.label("В игре: F1 — админ-панель (телепорты, существо, события, свет, погода), F2 — свободная камера.", 18, Ui.DIM)
	tip.position = Vector2(100, 650)
	_root.add_child(tip)
	b.grab_focus.call_deferred()


func _stages() -> void:
	var p := Ui.panel()
	_root.add_child(p)
	p.position = Vector2(80, 40)
	var v := Ui.vbox(6)
	p.add_child(v)
	v.add_child(Ui.label("ЭТАПЫ", 40, Ui.TEXT, "head"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(760, 520)
	v.add_child(sc)
	var list := Ui.vbox(1)
	sc.add_child(list)
	var last := 0
	var first: Button = null
	for id in Director.ORDER:
		var n := int(String(id).substr(1, 1))
		if n != last:
			last = n
			var nd: Array = T.NIGHTS[n]
			list.add_child(Ui.label("%s — %s" % [nd[0], nd[1]], 22, Ui.ACCENT, "head"))
		var sid := String(id)
		var b := Ui.button("     " + String(Director.TITLES[id]), func() -> void: _start(sid), 22, 720)
		list.add_child(b)
		if first == null:
			first = b
	v.add_child(Ui.button("Назад", func() -> void: open("admin"), 26, 300))
	first.grab_focus.call_deferred()


func _to_settings(from: String) -> void:
	_back_to = from
	open("settings")


func _cfg(prop: String, value: Variant) -> void:
	Cfg.set(prop, value)
	Cfg.apply()
	Cfg.save_cfg()


func _open_panel() -> void:
	G.resume()
	G.admin_panel.open()


func _retry() -> void:
	G.resume()
	G.start_stage(G.stage)


func _to_menu() -> void:
	get_tree().paused = false
	G.show_menu("admin" if G.admin else "main")


func _start(sid: String) -> void:
	G.admin = true
	G.god = false
	G.no_cold = false
	G.ai_off = false
	G.start_stage(sid)
