extends CanvasLayer
## Интерфейс: подсказки, полоски, записки, шкаф, пауза, вступление, концовки.

var game
var fear := 0.0
var objective_override := ""
var hint: Label
var objective: Label
var toast_l: Label
var sub_l: Label
var bars: Control
var bat_bar: ProgressBar
var sta_bar: ProgressBar
var br_bar: ProgressBar
var read_bar: ProgressBar
var cross: ColorRect
var slit: Control
var vign: ColorRect
var flash_r: ColorRect
var note_p: Panel
var note_t: Label
var pause_p: Control
var end_p: Control
var end_t: Label
var intro_p: Control
var _toast_t := 0.0
var _sub_t := 0.0
var _shake := 0.0
var note_open := false

const VIGN := """
shader_type canvas_item;
uniform float fear = 0.0;
uniform float hidden = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void fragment(){
	vec2 uv = UV - 0.5;
	float r = length(uv * vec2(1.6, 1.0));
	float v = smoothstep(0.45 - fear * 0.15, 1.0, r);
	float grain = h(UV * 900.0 + vec2(TIME * 37.0, TIME * 91.0)) - 0.5;
	vec3 col = mix(vec3(0.0), vec3(0.22, 0.0, 0.0), fear * fear * 0.7);
	float a = v * (0.75 + fear * 0.25) + abs(grain) * (0.07 + fear * 0.1);
	float slit = 1.0 - smoothstep(0.035, 0.06, abs(uv.x)) * 1.0;
	a = mix(a, max(a, 1.0 - slit * (1.0 - smoothstep(0.3, 0.45, abs(uv.y)))), hidden);
	COLOR = vec4(col, clamp(a, 0.0, 1.0));
}
"""

func setup(g) -> void:
	game = g
	layer = 5
	vign = ColorRect.new()
	vign.set_anchors_preset(Control.PRESET_FULL_RECT)
	vign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new(); sh.code = VIGN
	sm.shader = sh
	vign.material = sm
	add_child(vign)
	cross = ColorRect.new()
	cross.color = Color(1, 1, 1, 0.35)
	cross.size = Vector2(4, 4)
	add_child(cross)
	_place(cross, 0.5, 0.5, -2, -2, 2, 2)
	hint = _label(20, Color(0.85, 0.82, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	_place(hint, 0.5, 0.5, -400, 40, 400, 70)
	objective = _label(17, Color(0.75, 0.72, 0.6))
	objective.position = Vector2(24, 18); objective.size = Vector2(700, 60)
	toast_l = _label(19, Color(0.9, 0.88, 0.75), HORIZONTAL_ALIGNMENT_CENTER)
	_place(toast_l, 0.5, 0.0, -450, 70, 450, 140)
	toast_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub_l = _label(21, Color(0.95, 0.9, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	_place(sub_l, 0.5, 1.0, -520, -170, 520, -70)
	sub_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	bars = VBoxContainer.new()
	add_child(bars)
	_place(bars, 0.0, 1.0, 24, -130, 260, -20)
	bat_bar = _bar("Фонарь", Color(0.9, 0.8, 0.4))
	sta_bar = _bar("Дыхание бега", Color(0.6, 0.7, 0.8))
	br_bar = _bar("Задержка дыхания", Color(0.5, 0.6, 0.9))
	read_bar = ProgressBar.new()
	read_bar.show_percentage = false
	read_bar.max_value = 1.0
	add_child(read_bar)
	_place(read_bar, 0.5, 0.5, -120, 80, 120, 90)
	flash_r = ColorRect.new()
	flash_r.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_r.color = Color(1, 1, 1, 0)
	flash_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash_r)
	_note_panel()
	_pause_panel()
	_end_panel()

func _place(c: Control, ax: float, ay: float, l: float, t: float, r: float, b: float) -> void:
	c.anchor_left = ax; c.anchor_right = ax; c.anchor_top = ay; c.anchor_bottom = ay
	c.offset_left = l; c.offset_top = t; c.offset_right = r; c.offset_bottom = b

func _label(sz: int, c: Color, al := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", c)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = al
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _bar(title: String, c: Color) -> ProgressBar:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", Color(0.7, 0.68, 0.6))
	bars.add_child(l)
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(200, 8)
	b.show_percentage = false
	b.max_value = 1.0
	var sb := StyleBoxFlat.new(); sb.bg_color = c.darkened(0.2)
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0, 0, 0, 0.5)
	b.add_theme_stylebox_override("fill", sb)
	b.add_theme_stylebox_override("background", bg)
	bars.add_child(b)
	b.set_meta("label", l)
	return b

func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _center_box(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 12)
	parent.add_child(v)
	return v

func _note_panel() -> void:
	note_p = Panel.new()
	_place(note_p, 0.5, 0.5, -300, -220, 300, 220)
	var sb := StyleBoxTexture.new()
	sb.texture = load("res://tex/paper.png")
	sb.modulate_color = Color(0.85, 0.82, 0.72)
	note_p.add_theme_stylebox_override("panel", sb)
	note_t = Label.new()
	note_t.position = Vector2(36, 30); note_t.size = Vector2(528, 380)
	note_t.autowrap_mode = TextServer.AUTOWRAP_WORD
	note_t.add_theme_font_size_override("font_size", 21)
	note_t.add_theme_color_override("font_color", Color(0.15, 0.12, 0.2))
	note_p.add_child(note_t)
	note_p.visible = false
	add_child(note_p)

func show_note(title: String, text: String) -> void:
	note_t.text = title + "\n\n" + text + "\n\n\n[E / Esc] закрыть"
	note_p.visible = true
	note_open = true

func _pause_panel() -> void:
	pause_p = ColorRect.new()
	(pause_p as ColorRect).color = Color(0, 0, 0, 0.82)
	pause_p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := _center_box(pause_p)
	var t := Label.new(); t.text = "ПАУЗА"; t.add_theme_font_size_override("font_size", 40)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_btn(v, "Продолжить", func(): toggle_pause())
	var l1 := Label.new(); l1.text = "Чувствительность мыши"; v.add_child(l1)
	var s1 := HSlider.new(); s1.min_value = 0.0005; s1.max_value = 0.006; s1.step = 0.0001; s1.value = G.sens
	s1.value_changed.connect(func(x): G.sens = x; G.save_settings())
	v.add_child(s1)
	var l2 := Label.new(); l2.text = "Громкость"; v.add_child(l2)
	var s2 := HSlider.new(); s2.min_value = 0; s2.max_value = 1; s2.step = 0.01; s2.value = G.volume
	s2.value_changed.connect(func(x): G.volume = x; G.save_settings())
	v.add_child(s2)
	_btn(v, "В главное меню", func(): game.get_parent().show_menu())
	pause_p.visible = false
	add_child(pause_p)

func toggle_pause() -> void:
	if note_open: _close_note(); return
	pause_p.visible = not pause_p.visible
	game.set_paused(pause_p.visible)

func _end_panel() -> void:
	end_p = ColorRect.new()
	(end_p as ColorRect).color = Color(0, 0, 0, 0)
	end_p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := _center_box(end_p)
	end_t = Label.new()
	end_t.custom_minimum_size = Vector2(820, 0)
	end_t.autowrap_mode = TextServer.AUTOWRAP_WORD
	end_t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_t.add_theme_font_size_override("font_size", 22)
	end_t.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	v.add_child(end_t)
	var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 20); v.add_child(sp)
	var b1 := _btn(v, "Ещё раз", func(): game.get_parent().start_game(game.admin_on))
	var b2 := _btn(v, "В главное меню", func(): game.get_parent().show_menu())
	b1.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end_p.visible = false
	add_child(end_p)

func end_screen(win: bool, text: String) -> void:
	end_p.visible = true
	end_t.text = text
	(end_p as ColorRect).color = Color(0, 0, 0, 0.0)
	end_t.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(end_p, "color", Color(0.0, 0.0, 0.0, 1.0) if win else Color(0.08, 0.0, 0.0, 1.0), 1.5 if win else 0.2)
	tw.tween_property(end_t, "modulate:a", 1.0, 1.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func intro() -> void:
	intro_p = ColorRect.new()
	(intro_p as ColorRect).color = Color(0, 0, 0, 1)
	intro_p.set_anchors_preset(Control.PRESET_FULL_RECT)
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	l.text = "Посёлок Торфяной. 14 ноября 1994 года, 23:40.\n\nДом №7 расселён после подземных пожаров. Но счётчики в нём крутятся.\n\nЗадание: снять показания 10 приборов учёта на пяти этажах.\nДверь подъезда за вами заперли снаружи — откроют, когда передадите все показания по рации.\n\nВ доме тихо. Старайтесь, чтобы так и оставалось.\n\n\nWASD — идти · Shift — бег · Ctrl — присесть · F — фонарь · E — действие\nQ — задержать дыхание в шкафу · F1 — админ-панель · Esc — пауза\n\n(любая клавиша)"
	intro_p.add_child(l)
	add_child(intro_p)
	game.paused = true
	set_meta("intro", true)

func _input(e: InputEvent) -> void:
	if has_meta("intro") and (e is InputEventKey or e is InputEventMouseButton) and e.pressed:
		remove_meta("intro")
		game.paused = false
		var tw := create_tween()
		tw.tween_property(intro_p, "modulate:a", 0.0, 2.0)
		tw.tween_callback(intro_p.queue_free)
		get_viewport().set_input_as_handled()
		G.play2d("slam", -6, 0.7)
		return
	if note_open and e is InputEventKey and e.pressed and not e.echo and e.keycode in [KEY_E, KEY_ESCAPE]:
		_close_note()
		get_viewport().set_input_as_handled()

func _close_note() -> void:
	note_open = false
	note_p.visible = false

func toast(t: String) -> void:
	toast_l.text = t
	_toast_t = 4.0

func subtitle(t: String, dur := 5.0) -> void:
	sub_l.text = t
	_sub_t = dur

func shake(a: float) -> void:
	_shake = max(_shake, a)

func flash() -> void:
	flash_r.color = Color(1, 1, 1, 0.9)
	var tw := create_tween()
	tw.tween_property(flash_r, "color", Color(1, 1, 1, 0), 0.25)
	tw.tween_property(flash_r, "color", Color(1, 1, 1, 0.5), 0.05)
	tw.tween_property(flash_r, "color", Color(1, 1, 1, 0), 0.4)

func _process(dt: float) -> void:
	if game == null or game.player == null: return
	var p = game.player
	_toast_t -= dt
	toast_l.modulate.a = clamp(_toast_t, 0.0, 1.0)
	_sub_t -= dt
	sub_l.modulate.a = clamp(_sub_t, 0.0, 1.0)
	hint.text = p.hint_text() if not game.over else ""
	if objective_override != "": objective.text = objective_override + "\nПоказаний: %d/10" % game.read_count
	else: objective.text = "Снять показания счётчиков: %d/10   (этаж %d)" % [game.read_count, game.world.level_of(p.global_position) + 1]
	bat_bar.value = p.battery / 100.0
	sta_bar.value = p.stamina
	br_bar.value = p.breath
	br_bar.visible = p.hidden
	br_bar.get_meta("label").visible = p.hidden
	read_bar.visible = p.read_progress > 0
	read_bar.value = p.read_progress
	cross.visible = not p.hidden and not game.over
	bars.visible = not game.over
	var m: ShaderMaterial = vign.material
	m.set_shader_parameter("fear", fear)
	m.set_shader_parameter("hidden", 1.0 if p.hidden else 0.0)
	_shake = max(0.0, _shake - dt)
	var s: float = _shake * 0.06 + fear * 0.004
	p.cam.h_offset = randf_range(-s, s)
	p.cam.v_offset = randf_range(-s, s)
