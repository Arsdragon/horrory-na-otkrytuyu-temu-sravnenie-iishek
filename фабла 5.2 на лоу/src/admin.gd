extends CanvasLayer
## Admin mode: F1 opens a panel to inspect all content (events, creature, endings, notes).

const M = preload("res://src/monster.gd")
var g: Node
var panel: Panel
var info: Label
var grid: VBoxContainer


func _ready() -> void:
	layer = 20
	info = Label.new()
	info.position = Vector2(24, 150)
	info.add_theme_font_size_override("font_size", 14)
	info.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	info.add_theme_color_override("font_outline_color", Color.BLACK)
	info.add_theme_constant_override("outline_size", 4)
	add_child(info)
	panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.04, 0.93)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -560
	add_child(panel)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 12
	sc.offset_top = 12
	sc.offset_right = -12
	sc.offset_bottom = -12
	panel.add_child(sc)
	grid = VBoxContainer.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid)
	panel.visible = false
	var p: Node = g.player
	var mo: Node = g.monster
	_section("АДМИН-РЕЖИМ  (F1 — закрыть)", [])
	_section("Режимы", [
		["Бессмертие", func() -> void: p.god = not p.god],
		["Полёт сквозь стены", func() -> void: p.noclip = not p.noclip],
		["Яркий свет", func() -> void: g.fullbright = not g.fullbright],
		["Стоп времени", func() -> void: g.time_frozen = not g.time_frozen],
		["Скорость ×1 / ×6", func() -> void: g.time_scale = 6.0 if g.time_scale < 2.0 else 1.0],
		["Авто-события", func() -> void: g.auto_events = not g.auto_events],
	])
	var hours: Array = []
	for h in 6:
		hours.append(["%02d:00" % h, func() -> void: _set_hour(float(h))])
	hours.append(["05:55", func() -> void: _set_hour(5.92)])
	_section("Время", hours)
	_section("Станция", [
		["Заглушить генератор", func() -> void: g.ev_stall()],
		["Запустить генератор", func() -> void:
			g.stalled = false
			g.suppress_t = 0.0
			g.fuel = maxf(g.fuel, 30.0)],
		["Топливо 100%", func() -> void: g.fuel = 100.0],
		["Топливо 3%", func() -> void: g.fuel = 3.0],
		["Обрыв антенны", func() -> void: g.ev_antenna()],
		["Починить антенну", func() -> void: g.antenna_ok = true],
		["Фонарь 100% +3 батареи", func() -> void:
			p.battery = 100.0
			p.spare = 3],
		["Дать канистру", func() -> void: p.carrying = true],
	])
	_section("Телепорт", [
		["Пульт", func() -> void: _tp(Vector3(-6.3, 0.05, -3))],
		["Генератор", func() -> void: _tp(Vector3(-5, 0.05, 2.4))],
		["Коридор", func() -> void: _tp(Vector3(0, 0.05, 0))],
		["Вход", func() -> void: _tp(Vector3(6.5, 0.05, 0))],
		["Склад", func() -> void: _tp(Vector3(5.5, 0.05, -2.2))],
		["Шкафы", func() -> void: _tp(Vector3(5, 0.05, 3))],
		["Сарай ГСМ", func() -> void: _tp(Vector3(34, 0.05, 14))],
		["Мачта", func() -> void: _tp(Vector3(-7, 0.05, -36))],
		["Ворота", func() -> void: _tp(Vector3(38, 0.05, 0))],
	])
	var ev: Array = [
		["Силуэт в окне", func() -> void: g.ev_window(-1)],
		["Телефон", func() -> void: g.ev_phone()],
		["Стук в дверь (визит)", func() -> void: mo.begin_visit()],
		["Фигура в коридоре", func() -> void: g.ev_appar()],
		["Шаги на крыше", func() -> void: g.ev_sound("roofsteps", Vector3(-3, 3.2, -3))],
		["Стук по стеклу", func() -> void: g.ev_sound("glass_tap", Vector3(1, 1.5, 5))],
		["Дверь спальни", func() -> void: g.ev_bunk_door()],
		["Мигание света", func() -> void: g.flicker(2.0)],
		["Вызов «Байкала»", func() -> void: g.start_call(true, "v_r_hour", 1)],
	]
	for i in range(1, 8):
		ev.append(["Ложный вызов %d" % i, func() -> void: g.start_call(false, "v_f_%d" % i, 2 if i == 7 else 0)])
	_section("События", ev)
	_section("Существо", [
		["Поставить перед собой", func() -> void:
			var f: Vector3 = p.look_dir()
			f.y = 0
			mo.place(p.global_position + f.normalized() * 3.5, M.S.SHOW)],
		["Подсветить лицо", func() -> void: mo.esp = not mo.esp],
		["Охота (в здании)", func() -> void:
			g.suppress(45.0)
			mo.vanish()
			mo.begin_hunt()],
		["Преследование (улица)", func() -> void: mo.begin_stalk()],
		["Штурм двери (нужна тьма)", func() -> void: mo.begin_assault()],
		["Убрать", func() -> void: mo.vanish()],
	])
	_section("Концовки", [
		["Рассвет (играбельно)", func() -> void:
			g.hour = 6.0
			g.start_dawn()],
		["«Рассвет»", func() -> void: g.main.show_ending("dawn", g.stats())],
		["«Потерянная станция»", func() -> void: g.main.show_ending("forgotten", g.stats())],
		["«Смена не нужна»", func() -> void: g._finish("replaced")],
		["«Тишина»", func() -> void: g.main.show_ending("silence", g.stats())],
		["Смерть: существо", func() -> void:
			p.god = false
			g.kill("monster")],
		["Смерть: холод", func() -> void:
			p.god = false
			g.kill("cold")],
	])
	var notes: Array = []
	for i in range(1, 8):
		notes.append(["Записка %d" % i, func() -> void:
			_toggle()
			g.read_note(i)])
	_section("Записки Гринёва", notes)


func _section(title: String, items: Array) -> void:
	var l := Label.new()
	l.text = title
	l.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	grid.add_child(l)
	var fl := HFlowContainer.new()
	grid.add_child(fl)
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(it[1])
		fl.add_child(b)


func _set_hour(h: float) -> void:
	g.hour = h
	g.next_cp = int(h) + 1
	g.real_due = 0.0
	for e in g.events:
		e.done = e.t < h - 0.001


func _tp(pos: Vector3) -> void:
	if g.player.hidden >= 0:
		g.player.unhide()
	g.player.global_position = pos
	g.player.velocity = Vector3.ZERO


func _toggle() -> void:
	panel.visible = not panel.visible
	g.player.control = not panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if panel.visible else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("admin") and g.running:
		_toggle()


func _process(_dt: float) -> void:
	var p: Node = g.player
	var mo: Node = g.monster
	var flags: Array = []
	if p.god:
		flags.append("БЕССМЕРТИЕ")
	if p.noclip:
		flags.append("ПОЛЁТ")
	if g.time_frozen:
		flags.append("ВРЕМЯ СТОИТ")
	if g.time_scale > 1.0:
		flags.append("×6")
	if not g.auto_events:
		flags.append("СОБЫТИЯ ВЫКЛ")
	info.text = "ADMIN [F1]  %s\nсущество: %s  %.1f м\nсвет: %s  топливо %d%%  антенна: %s\nложных ответов %d  пропусков %d  записок %d/7\nпозиция %.1f, %.1f" % [
		" ".join(flags), M.S.keys()[mo.st], mo.global_position.distance_to(p.global_position) if mo.st != M.S.GONE else 0.0,
		"да" if g.lit() else "НЕТ", int(g.fuel), "ок" if g.antenna_ok else "обрыв", g.strikes, g.missed, g.notes_read.size(), p.global_position.x, p.global_position.z]
