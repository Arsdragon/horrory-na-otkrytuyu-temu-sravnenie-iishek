extends Node
## App root: menu, settings, save file, death / ending cards, starting the night.

const SAVE := "user://save.json"
const ENDINGS := {
	"dawn": ["РАССВЕТ", "В 06:14 вездеход забрал оператора с «Узла-9».\nВ кузове уже сидел сменщик — молчаливый, в глубоком капюшоне.\nВы не стали спрашивать, почему он ни разу не обернулся.\n\nСтанция продолжает выходить в эфир."],
	"forgotten": ["ПОТЕРЯННАЯ СТАНЦИЯ", "Два пропущенных сеанса. По инструкции станция считается потерянной,\nвыезд смены отменяется до весны.\n\nЧасы на пульте показали 06:00. Потом — 00:00.\nТоплива осталось на одну ночь."],
	"replaced": ["СМЕНА НЕ НУЖНА", "В 06:00 «Байкал» вызвал «Узел-9».\nЕму ответили вашим голосом — чётко, по форме.\nВы в это время стояли у пульта и молчали.\n\nВездеход развернули. Вы слишком часто отвечали не тому."],
	"silence": ["ТИШИНА", "Вы сорвали пломбу. Передатчик умолк — и что-то за окном\nумолкло вместе с ним, на полуслове, вашим голосом.\n\nБез связи за вами никто не приехал.\nНа рассвете вы встали на лыжи Гринёва. 212 километров.\nЗато в полной тишине."],
}

var game: Node
var ui: CanvasLayer
var data: Dictionary = {"checkpoint": null, "endings": [], "admin": false, "sens": 0.0022, "vol": 0.9, "scale": 1.0, "fs": true}
var sens: float = 0.0022
var testing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_actions()
	_load()
	ui = CanvasLayer.new()
	ui.layer = 50
	add_child(ui)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		testing = true
		var t: Node = load("res://src/devtest.gd").new()
		t.main = self
		t.args = args
		add_child(t)
		return
	_apply_settings()
	show_menu()


func _actions() -> void:
	var keys := {"move_f": KEY_W, "move_b": KEY_S, "move_l": KEY_A, "move_r": KEY_D, "sprint": KEY_SHIFT, "use": KEY_E, "flash": KEY_F,
		"reload": KEY_R, "breath": KEY_SPACE, "admin": KEY_F1, "pause": KEY_ESCAPE, "tasks": KEY_TAB}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		var e := InputEventKey.new()
		e.physical_keycode = keys[a]
		InputMap.action_add_event(a, e)


func _load() -> void:
	if FileAccess.file_exists(SAVE):
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if d is Dictionary:
			for k in d:
				data[k] = d[k]
	sens = data.sens


func _save() -> void:
	if testing:
		return
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


func _apply_settings() -> void:
	sens = data.sens
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, data.vol)))
	get_viewport().scaling_3d_scale = data.scale
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if data.fs else DisplayServer.WINDOW_MODE_WINDOWED)
	if game != null:
		game.player.sens = sens


func save_checkpoint(cp: Dictionary) -> void:
	data.checkpoint = cp
	_save()


# ------------------------------------------------------------------ flow
func start_game(boot: Dictionary) -> void:
	_clear_ui()
	if game != null:
		game.queue_free()
	Snd.stop_all()
	get_tree().paused = false
	game = load("res://src/game.gd").new()
	game.main = self
	game.boot = boot
	game.admin = data.admin
	add_child(game)


func to_menu() -> void:
	if game != null:
		game.queue_free()
		game = null
	Snd.stop_all()
	get_tree().paused = false
	show_menu()


func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()


func _screen(noise: float = 0.07) -> VBoxContainer:
	_clear_ui()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amt = 0.07;\nfloat h(vec2 p){return fract(sin(dot(p,vec2(12.9898,78.233)))*43758.5453);}\nvoid fragment(){float t=floor(TIME*20.0);float n=h(floor(UV*vec2(320.0,180.0))+t);float band=smoothstep(0.02,0.0,abs(fract(UV.y*1.0-TIME*0.07)-0.5)-0.03);float v=1.0-length(UV-0.5)*1.3;COLOR=vec4(vec3(n*amt*(1.0+band*2.0))*max(v,0.0),1.0);}"
	sm.shader = sh
	sm.set_shader_parameter("amt", noise)
	bg.material = sm
	ui.add_child(bg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	bg.add_child(vb)
	return vb


func _text(parent: Node, s: String, fs: int, c: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	parent.add_child(l)
	return l


func _btn(parent: Node, s: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = s
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(380, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


func show_menu() -> void:
	var vb := _screen(0.1)
	Snd.loop("loop_static", 0.05)
	Snd.loop("loop_drone", 0.25)
	_text(vb, "П О М Е Х И", 78, Color(0.85, 0.87, 0.85))
	_text(vb, "радиорелейная станция «Узел-9»  ·  14 января 1987", 18, Color(0.5, 0.55, 0.5))
	_text(vb, " ", 20, Color.WHITE)
	_btn(vb, "Новая смена", func() -> void:
		data.checkpoint = null
		_save()
		start_game({}))
	var cp: Variant = data.checkpoint
	if cp is Dictionary:
		_btn(vb, "Продолжить с %02d:00" % int(cp.hour), func() -> void: start_game(cp))
	_btn(vb, "Админ-режим: %s" % ("ВКЛ" if data.admin else "выкл"), func() -> void:
		data.admin = not data.admin
		_save()
		show_menu())
	_btn(vb, "Настройки", show_settings)
	_btn(vb, "Концовки: %d из 4" % data.endings.size(), show_endings)
	_btn(vb, "Выход", func() -> void: get_tree().quit())
	_text(vb, "Играйте в наушниках и в темноте." + ("\nАдмин-режим: F1 в игре — панель просмотра контента." if data.admin else ""), 15, Color(0.4, 0.42, 0.4))


func show_settings() -> void:
	var vb := _screen()
	_text(vb, "НАСТРОЙКИ", 40, Color(0.85, 0.87, 0.85))
	_slider(vb, "Чувствительность мыши", "sens", 0.0008, 0.005)
	_slider(vb, "Громкость", "vol", 0.0, 1.0)
	_slider(vb, "Масштаб 3D-рендера (ниже — быстрее)", "scale", 0.5, 1.0)
	_btn(vb, "Полный экран: %s" % ("да" if data.fs else "нет"), func() -> void:
		data.fs = not data.fs
		_apply_settings()
		_save()
		show_settings())
	_btn(vb, "Назад", show_menu)


func _slider(parent: Node, title: String, key: String, lo: float, hi: float) -> void:
	_text(parent, title, 17, Color(0.7, 0.7, 0.68))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = (hi - lo) / 100.0
	s.value = data[key]
	s.custom_minimum_size = Vector2(380, 24)
	s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(func(v: float) -> void:
		data[key] = v
		_apply_settings()
		_save())
	parent.add_child(s)


func show_endings() -> void:
	var vb := _screen()
	_text(vb, "КОНЦОВКИ", 40, Color(0.85, 0.87, 0.85))
	for id in ENDINGS:
		var got: bool = data.endings.has(id)
		_text(vb, ENDINGS[id][0] if got else "— не открыта —", 24, Color(0.85, 0.8, 0.6) if got else Color(0.35, 0.35, 0.35))
		if got:
			_text(vb, ENDINGS[id][1], 15, Color(0.6, 0.6, 0.58))
	_btn(vb, "Назад", show_menu)


func show_death(cause: String) -> void:
	Snd.stop_all()
	if game != null:
		game.queue_free()
		game = null
	var vb := _screen(0.25 if cause == "monster" else 0.04)
	if cause == "monster":
		_text(vb, "ОНО НАШЛО СМЕНУ", 56, Color(0.7, 0.1, 0.08))
		_text(vb, "Утром «Байкалу» ответят с «Узла-9». Голос будет знакомый.", 18, Color(0.6, 0.6, 0.58))
		Snd.loop("loop_static", 0.3)
	else:
		_text(vb, "ВЫ ЗАМЁРЗЛИ", 56, Color(0.6, 0.75, 0.9))
		_text(vb, "Минус сорок один. До двери оставалось совсем немного.", 18, Color(0.6, 0.6, 0.58))
		Snd.loop("loop_wind", 0.4)
	_text(vb, " ", 20, Color.WHITE)
	var cp: Variant = data.checkpoint
	if cp is Dictionary:
		_btn(vb, "Вернуться в %02d:00" % int(cp.hour), func() -> void: start_game(cp))
	_btn(vb, "Начать смену заново", func() -> void: start_game({}))
	_btn(vb, "В меню", to_menu)


func show_ending(id: String, st: Dictionary) -> void:
	Snd.stop_all()
	if game != null:
		game.queue_free()
		game = null
	if not data.endings.has(id):
		data.endings.append(id)
	data.checkpoint = null
	_save()
	var vb := _screen(0.05)
	Snd.loop("loop_wind_in", 0.4)
	if id == "replaced":
		Snd.loop("loop_static", 0.15)
	_text(vb, "концовка", 16, Color(0.45, 0.45, 0.45))
	_text(vb, ENDINGS[id][0], 56, Color(0.85, 0.8, 0.6))
	_text(vb, ENDINGS[id][1], 19, Color(0.72, 0.72, 0.7))
	_text(vb, "\nСеансов принято: %d    Пропущено: %d    Ответов не тому: %d    Записок Гринёва: %d из 7" % [st.answered, st.missed, st.strikes, st.notes], 15, Color(0.5, 0.5, 0.48))
	_text(vb, " ", 12, Color.WHITE)
	_btn(vb, "В меню", to_menu)
