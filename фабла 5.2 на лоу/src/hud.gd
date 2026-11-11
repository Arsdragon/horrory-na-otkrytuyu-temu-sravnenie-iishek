extends CanvasLayer
## HUD, subtitles, note reader, pause menu and the full-screen post-process.

var g: Node
var root: Control
var post_mat: ShaderMaterial
var prompt_l: Label
var say_l: Label
var sub_l: Label
var obj_l: Label
var clock_l: Label
var stat_l: Label
var hold_bar: ProgressBar
var stam_bar: ProgressBar
var cold_bar: ProgressBar
var breath_bar: ProgressBar
var note_panel: Panel
var note_l: Label
var pause_panel: Panel
var say_t: float = 0.0
var sub_t: float = 0.0
var show_obj: bool = true


func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pl := CanvasLayer.new()
	pl.layer = 1
	add_child(pl)
	var pr := ColorRect.new()
	pr.set_anchors_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	pr.material = post_mat
	pl.add_child(pr)
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.45)
	dot.size = Vector2(3, 3)
	_place(dot, 0.5, 0.5, Vector2(-1.5, -1.5), Vector2(3, 3))
	prompt_l = _label(18, Color(0.95, 0.92, 0.8), 0.5, 0.56, 700)
	say_l = _label(22, Color(0.9, 0.9, 0.88), 0.5, 0.2, 1000)
	sub_l = _label(22, Color(1.0, 0.92, 0.6), 0.5, 0.8, 1000)
	clock_l = _label(26, Color(0.75, 0.85, 0.75, 0.8), 0.0, 0.0, 200)
	clock_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	clock_l.offset_left = 24
	clock_l.offset_right = 224
	clock_l.offset_top = 16
	obj_l = _label(16, Color(0.8, 0.8, 0.75, 0.75), 0.0, 0.0, 520)
	obj_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	obj_l.offset_left = 24
	obj_l.offset_right = 544
	obj_l.offset_top = 54
	stat_l = _label(16, Color(0.8, 0.8, 0.75, 0.8), 0.0, 1.0, 520)
	stat_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	stat_l.offset_left = 24
	stat_l.offset_right = 544
	stat_l.offset_top = -44
	hold_bar = _bar(Color(0.9, 0.85, 0.6), 0.5, 0.61, 220)
	stam_bar = _bar(Color(0.7, 0.8, 0.7), 0.5, 0.93, 260)
	cold_bar = _bar(Color(0.5, 0.75, 1.0), 0.5, 0.955, 260)
	breath_bar = _bar(Color(0.9, 0.9, 0.9), 0.5, 0.9, 260)
	# note reader
	note_panel = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.72, 0.69, 0.56)
	sb.border_color = Color(0.3, 0.27, 0.2)
	sb.set_border_width_all(2)
	sb.shadow_size = 30
	sb.shadow_color = Color(0, 0, 0, 0.8)
	note_panel.add_theme_stylebox_override("panel", sb)
	_place(note_panel, 0.5, 0.5, Vector2(-330, -300), Vector2(660, 600))
	note_l = Label.new()
	note_l.add_theme_font_size_override("font_size", 20)
	note_l.add_theme_color_override("font_color", Color(0.08, 0.08, 0.2))
	note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_l.position = Vector2(40, 34)
	note_l.size = Vector2(580, 500)
	note_panel.add_child(note_l)
	var close_l := Label.new()
	close_l.text = "[E] — закрыть"
	close_l.add_theme_color_override("font_color", Color(0.3, 0.27, 0.2))
	close_l.position = Vector2(40, 556)
	note_panel.add_child(close_l)
	note_panel.visible = false
	# pause
	pause_panel = Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0, 0, 0.85)
	pause_panel.add_theme_stylebox_override("panel", ps)
	pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(pause_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	pause_panel.add_child(vb)
	vb.set_anchors_preset(Control.PRESET_CENTER)
	vb.offset_left = -160
	vb.offset_right = 160
	vb.offset_top = -120
	var tl := Label.new()
	tl.text = "ПАУЗА"
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.add_theme_font_size_override("font_size", 34)
	vb.add_child(tl)
	_button(vb, "Продолжить", toggle_pause)
	_button(vb, "Выйти в меню", func() -> void:
		get_tree().paused = false
		g.main.to_menu())
	var help := Label.new()
	help.text = "WASD — ходьба   Shift — бег   E — действие   F — фонарь   R — батарея\nTab — задачи   Пробел — задержать дыхание (в шкафу)" + ("\nF1 — админ-панель" if g.admin else "")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vb.add_child(help)
	pause_panel.visible = false


func _place(c: Control, ax: float, ay: float, off: Vector2, size: Vector2) -> void:
	root.add_child(c)
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + size.x
	c.offset_bottom = off.y + size.y
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE if not c is Panel else Control.MOUSE_FILTER_STOP


func _label(fs: int, c: Color, ax: float, ay: float, w: float) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(l, ax, ay, Vector2(-w / 2, 0), Vector2(w, 30))
	l.grow_vertical = Control.GROW_DIRECTION_END
	return l


func _bar(c: Color, ax: float, ay: float, w: float) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = c
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	_place(b, ax, ay, Vector2(-w / 2, 0), Vector2(w, 6))
	b.visible = false
	return b


func _button(parent: Node, text: String, fn: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 20)
	b.custom_minimum_size = Vector2(320, 44)
	b.pressed.connect(fn)
	parent.add_child(b)
	return b


func say(text: String, dur: float = 3.0) -> void:
	say_l.text = text
	say_t = dur


func sub(text: String, dur: float = 4.0) -> void:
	sub_l.text = text
	sub_t = dur


func show_note(text: String) -> void:
	note_l.text = text
	note_panel.visible = true
	g.player.control = false


func post(fear: float, glitch: float, cold: float, dark: float, slits: bool) -> void:
	post_mat.set_shader_parameter("fear", fear)
	post_mat.set_shader_parameter("glitch", glitch)
	post_mat.set_shader_parameter("cold", cold)
	post_mat.set_shader_parameter("dark", dark)
	post_mat.set_shader_parameter("slits", 1.0 if slits else 0.0)


func toggle_pause() -> void:
	if not g.running:
		return
	var p: bool = not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("pause"):
		if note_panel.visible:
			_close_note()
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("use") and note_panel.visible:
		_close_note()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("tasks"):
		show_obj = not show_obj


func _close_note() -> void:
	note_panel.visible = false
	g.player.control = true


func _process(dt: float) -> void:
	if get_tree().paused:
		return
	say_t -= dt
	sub_t -= dt
	say_l.modulate.a = clampf(say_t, 0.0, 1.0)
	sub_l.modulate.a = clampf(sub_t, 0.0, 1.0)
	var p: Node = g.player
	var live: bool = g.running and p.alive
	root.visible = live or say_t > 0.0
	clock_l.text = g.clock()
	obj_l.text = g.objective() if show_obj else ""
	var a: Act = p.cur_act
	prompt_l.text = a.prompt() if a != null and live else ""
	if p.hidden >= 0:
		prompt_l.text = "[E] Выйти    [Пробел] Не дышать"
	hold_bar.visible = a != null and a.hold > 0.0 and p.hold_t > 0.0
	if hold_bar.visible:
		hold_bar.value = p.hold_t / a.hold * 100.0
	stam_bar.visible = p.stamina < 99.0
	stam_bar.value = p.stamina
	cold_bar.visible = p.cold > 3.0
	cold_bar.value = p.cold
	breath_bar.visible = p.hidden >= 0
	breath_bar.value = p.breath
	var s: String = "Фонарь %d%%" % int(p.battery)
	if p.spare > 0:
		s += "   Батареи: %d" % p.spare
	if p.carrying:
		s += "   [ Канистра ]"
	if p.cold > 35.0:
		s += "   ХОЛОД"
	stat_l.text = s
