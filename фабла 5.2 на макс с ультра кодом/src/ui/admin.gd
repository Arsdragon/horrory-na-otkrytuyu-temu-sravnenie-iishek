class_name AdminPanel
extends Control
## Админ-панель в игре (F1): телепорты, режимы, существо, события, предметы, этапы.

const PLACES := [["hub", "Развязка лееров"], ["door_out", "Крыльцо"], ["main", "Кают-компания"], ["radio", "Радиорубка"], ["bed", "Спальня"],
	["store", "Кладовая"], ["vest", "Тамбур"], ["shed_in", "Дизельная"], ["meteo", "Метеоплощадка"], ["booth", "Будка"], ["depot_in", "Склад ГСМ"],
	["mast", "Мачта"], ["hut_in", "Фидерная будка"], ["pad_in", "Вертолётная площадка"], ["balok", "Старый балок, вход"], ["balok_in", "Старый балок"],
	["cellar", "Ледник"], ["cellar_end", "Ледник: скважина"], ["rope_a", "На леере «А»"], ["house_out", "Вид на дом"]]

var is_open := false
var _panel: PanelContainer
var _fps: Label
var _stage: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func open() -> void:
	if G.world == null or G.player == null:
		return
	is_open = true
	visible = true
	_build()


func close() -> void:
	is_open = false
	visible = false
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _head(v: VBoxContainer, text: String) -> void:
	var sp := Control.new()
	sp.custom_minimum_size.y = 8
	v.add_child(sp)
	v.add_child(Ui.label(text, 20, Ui.ACCENT, "head"))


func _grid(v: VBoxContainer, cols: int) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 0)
	v.add_child(g)
	return g


func _build() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = Ui.panel(Color(0.02, 0.025, 0.03, 0.92))
	add_child(_panel)
	var outer := Ui.vbox(4)
	_panel.add_child(outer)
	var top := Ui.hbox(20)
	outer.add_child(top)
	top.add_child(Ui.label("АДМИН-ПАНЕЛЬ", 26, Ui.TEXT, "head"))
	_fps = Ui.label("", 18, Ui.DIM)
	top.add_child(_fps)
	_stage = Ui.label("", 18, Ui.DIM)
	outer.add_child(_stage)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(560, 560)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var v := Ui.vbox(2)
	sc.add_child(v)
	var W: World = G.world
	var P: Player = G.player
	var D: Director = G.director

	_head(v, "ТЕЛЕПОРТ")
	var g := _grid(v, 2)
	for e in PLACES:
		var key := String(e[0])
		if W.places.has(key):
			g.add_child(Ui.button(String(e[1]), func() -> void: _tp(key), 18, 270))

	_head(v, "РЕЖИМЫ")
	v.add_child(Ui.check("Бессмертие", G.god, func(x: bool) -> void: G.god = x))
	v.add_child(Ui.check("Холод не действует", G.no_cold, func(x: bool) -> void: G.no_cold = x))
	v.add_child(Ui.check("Существо выключено", G.ai_off, func(x: bool) -> void: _ai_off(x)))
	v.add_child(Ui.check("Полный свет", W.weather.bright > 0.5, func(x: bool) -> void: W.weather.bright = 1.0 if x else 0.0))
	v.add_child(Ui.check("Убрать пургу", W.weather.clear > 0.5, func(x: bool) -> void: W.weather.clear = 1.0 if x else 0.0))
	v.add_child(Ui.check("Дизель работает", W.gen_on, func(x: bool) -> void: W.set_power(x)))
	v.add_child(Ui.check("Печь топится", W.stove_t > 0.0, func(x: bool) -> void: W.stove_t = 3600.0 if x else 0.0))
	v.add_child(Ui.check("Свободная камера (F2)", P.mode == "free", func(_x: bool) -> void: G.toggle_freecam()))
	v.add_child(Ui.slider("Сила пурги", 0.0, 1.0, 0.05, W.weather.base, func(x: float) -> void: W.weather.base = x, "%.2f", 250.0, 190.0))

	_head(v, "СУЩЕСТВО")
	g = _grid(v, 2)
	g.add_child(Ui.button("Поставить: человек", func() -> void: _put(0.0, 0.0), 18, 270))
	g.add_child(Ui.button("Поставить: настоящее", func() -> void: _put(1.0, 0.0), 18, 270))
	g.add_child(Ui.button("Настоящее, тянет руки", func() -> void: _put(1.0, 0.8), 18, 270))
	g.add_child(Ui.button("Убрать", func() -> void: G.entity.hide_now(), 18, 270))
	v.add_child(Ui.slider("Чему оно научилось (ночь)", 2.0, 5.0, 1.0, float(G.entity.level), func(x: float) -> void: G.entity.level = int(x), "%.0f", 250.0, 190.0))

	_head(v, "СОБЫТИЯ")
	g = _grid(v, 2)
	for id in Director.EVENTS:
		var eid := String(id)
		g.add_child(Ui.button(String(Director.EVENTS[id]), func() -> void: _event(eid), 17, 270))

	_head(v, "ПРЕДМЕТЫ")
	g = _grid(v, 2)
	g.add_child(Ui.button("+3 фальшфейера", func() -> void: _flares(), 18, 270))
	g.add_child(Ui.button("Согреться", func() -> void: P.warmth = 100.0, 18, 270))
	g.add_child(Ui.button("Полная канистра в руки", func() -> void: _jerry(), 18, 270))
	g.add_child(Ui.button("Дрова в руки", func() -> void: P.carrying = "wood", 18, 270))

	_head(v, "ЗАПИСКИ И ОКНА")
	g = _grid(v, 2)
	g.add_child(Ui.button("Блокнот", func() -> void: _notebook(), 18, 270))
	g.add_child(Ui.button("Радио", func() -> void: _radio(), 18, 270))
	g.add_child(Ui.button("Найти все записки", func() -> void: _all_notes(), 18, 270))

	if D != null and D.stage != "sandbox":
		_head(v, "ЭТАП")
		g = _grid(v, 2)
		g.add_child(Ui.button("← предыдущий", func() -> void: _shift(-1), 18, 270))
		g.add_child(Ui.button("следующий →", func() -> void: _shift(1), 18, 270))
		g.add_child(Ui.button("Начать этап заново", func() -> void: _shift(0), 18, 270))
	v.add_child(Ui.button("Закрыть (F1)", func() -> void: close(), 20, 270))


func _tp(key: String) -> void:
	if G.player.mode == "free":
		G.toggle_freecam()
	G.world.goto(key)
	close()


func _ai_off(x: bool) -> void:
	G.ai_off = x
	if x and G.entity != null:
		G.entity.hide_now()
		if G.director != null:
			G.director.clear_lure()


func _put(wrong: float, reach: float) -> void:
	var p := G.player
	var fwd := Basis(Vector3.UP, p.yaw) * Vector3.FORWARD
	var pos := p.global_position + fwd * 3.2
	pos.y = p.global_position.y
	G.entity.show_pose(pos, rad_to_deg(p.yaw) + 180.0, wrong, reach)
	G.entity.fig.look_on = true
	close()


func _event(id: String) -> void:
	if G.director != null:
		close()
		G.director.ev(id)


func _flares() -> void:
	G.player.flares += 3
	G.set_flag("flares_known")


func _jerry() -> void:
	G.player.carrying = "jerry"
	if G.director != null:
		G.director.jerry_full = true


func _notebook() -> void:
	close()
	G.notebook.open()


func _radio() -> void:
	close()
	G.radio_ui.can_send = false
	G.radio_ui.open()
	G.ui_frame = Engine.get_process_frames()


func _all_notes() -> void:
	for id in T.NOTES:
		if not id in G.notes:
			G.notes.append(id)
	G.hud.toast("Все записки — в блокноте")


func _shift(k: int) -> void:
	var i := Director.ORDER.find(G.stage)
	if i < 0:
		return
	i = clampi(i + k, 0, Director.ORDER.size() - 1)
	close()
	G.start_stage(String(Director.ORDER[i]))


func _process(_dt: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	if _panel != null:
		_panel.position = Vector2(24, 24)
	if _fps != null:
		_fps.text = "%d к/с" % int(Engine.get_frames_per_second())
	if _stage != null and G.director != null:
		var st := G.director.stage
		_stage.text = "Этап: %s — %s" % [st, String(Director.TITLES.get(st, "песочница"))]
