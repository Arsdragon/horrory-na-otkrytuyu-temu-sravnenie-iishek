class_name Notebook
extends Control
## Блокнот (Tab): задачи, показания, записки, схема станции.

signal closed

const TABS := ["Задачи", "Показания", "Записки", "Схема"]

var is_open := false
var tab := 0
var _dim: ColorRect
var _panel: PanelContainer
var _tabs: HBoxContainer
var _body: VBoxContainer
var _map: TextureRect
var _foot: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	_panel = Ui.panel(Color(0.05, 0.05, 0.055, 0.95))
	add_child(_panel)
	var v := Ui.vbox(14)
	_panel.add_child(v)
	_tabs = Ui.hbox(4)
	v.add_child(_tabs)
	for i in TABS.size():
		var idx := i
		_tabs.add_child(Ui.button(TABS[i], func() -> void: show_tab(idx), 24))
	_body = Ui.vbox(8)
	_body.custom_minimum_size = Vector2(760, 470)
	v.add_child(_body)
	_foot = Ui.label("A / D — страницы · Tab — закрыть", 18, Ui.DIM)
	v.add_child(_foot)
	visible = false


func open(at_tab := -1) -> void:
	if at_tab >= 0:
		tab = at_tab
	is_open = true
	visible = true
	Snd.play("page", -6.0)
	show_tab(tab)


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Snd.play("page", -9.0, 1.2)
	closed.emit()


func _unhandled_input(e: InputEvent) -> void:
	if not is_open:
		return
	if e.is_action_pressed("move_l"):
		show_tab(posmod(tab - 1, TABS.size()))
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("move_r"):
		show_tab(posmod(tab + 1, TABS.size()))
		get_viewport().set_input_as_handled()


func show_tab(i: int) -> void:
	tab = i
	for c in _body.get_children():
		c.queue_free()
	for k in _tabs.get_child_count():
		var b: Button = _tabs.get_child(k)
		b.add_theme_color_override("font_color", Color(1, 1, 1) if k == i else Color(0.55, 0.55, 0.55))
	match i:
		0:
			_page_tasks()
		1:
			_page_readings()
		2:
			_page_notes()
		3:
			_page_map()


func _page_tasks() -> void:
	var nd: Array = T.NIGHTS.get(G.night, ["", "", ""])
	_body.add_child(Ui.label("%s. %s" % [nd[0], nd[1]], 26, Ui.ACCENT, "head"))
	if G.objectives.is_empty():
		_body.add_child(Ui.label("Задач нет.", 22, Ui.DIM))
	for o in G.objectives:
		var od: Dictionary = o
		var l := Ui.label(("✓  " if bool(od.done) else "—  ") + String(od.text), 22, Ui.DIM if bool(od.done) else Ui.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 740
		_body.add_child(l)
	var sp := Control.new()
	sp.custom_minimum_size.y = 16
	_body.add_child(sp)
	var tip := Ui.label("Ветер всегда с норд-веста. В пургу — только по лееру (ПКМ). В луче оно стоит. Огня не выносит.", 19, Ui.DIM)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.custom_minimum_size.x = 740
	if G.flag("rules_known"):
		_body.add_child(tip)


func _page_readings() -> void:
	_body.add_child(Ui.label("Журнал наблюдений, срок 21:00", 26, Ui.ACCENT, "head"))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 44)
	g.add_theme_constant_override("v_separation", 8)
	for h in ["Дата", "t°, °C", "Ветер, м/с", "Снег, см"]:
		g.add_child(Ui.label(h, 20, Ui.DIM))
	for n in [1, 2, 3, 4, 5]:
		var r: Dictionary = G.readings.get(n, {})
		if r.is_empty():
			continue
		g.add_child(Ui.label("%d января" % (15 + n), 22))
		g.add_child(Ui.label(String(r.get("t", "—")), 22, Ui.TEXT, "hand"))
		g.add_child(Ui.label(String(r.get("w", "—")), 22, Ui.TEXT, "hand"))
		g.add_child(Ui.label(String(r.get("s", "—")), 22, Ui.TEXT, "hand"))
	_body.add_child(g)
	if G.readings.is_empty():
		_body.add_child(Ui.label("Пока пусто.", 22, Ui.DIM))


func _page_notes() -> void:
	_body.add_child(Ui.label("Записки", 26, Ui.ACCENT, "head"))
	if G.notes.is_empty():
		_body.add_child(Ui.label("Пока ничего не найдено.", 22, Ui.DIM))
		return
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(750, 410)
	_body.add_child(sc)
	var v := Ui.vbox(2)
	sc.add_child(v)
	for id in G.notes:
		if not T.NOTES.has(id):
			continue
		var nid := String(id)
		v.add_child(Ui.button(String(T.NOTES[id].title), func() -> void: G.read(nid), 22, 720))


func _page_map() -> void:
	_map = TextureRect.new()
	_map.texture = Kit.tex("res://tex/map")
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map.custom_minimum_size = Vector2(760, 470)
	_body.add_child(_map)


func _process(_dt: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_dim.size = size
	var ps := _panel.get_combined_minimum_size()
	_panel.size = ps
	_panel.position = (size - ps) * 0.5
