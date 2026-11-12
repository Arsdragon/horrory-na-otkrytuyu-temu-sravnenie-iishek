class_name UI
## Общий стиль интерфейса: шрифты, цвета, кнопки, панели.

const ACCENT := Color(0.86, 0.55, 0.3)
const TEXT := Color(0.86, 0.84, 0.8)
const DIM := Color(0.55, 0.54, 0.52)
const BG := Color(0.03, 0.03, 0.035, 0.92)

static var _fonts := {}
static var theme: Theme


static func font(name: String) -> Font:
	if not _fonts.has(name):
		_fonts[name] = load("res://fonts/%s" % name)
	return _fonts[name]


static func get_theme() -> Theme:
	if theme:
		return theme
	theme = Theme.new()
	theme.default_font = font("PTSans-Regular.ttf")
	theme.default_font_size = 22
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0, 0, 0, 0)
	btn.content_margin_left = 14
	btn.content_margin_right = 14
	btn.content_margin_top = 6
	btn.content_margin_bottom = 6
	var hov := btn.duplicate() as StyleBoxFlat
	hov.bg_color = Color(0.86, 0.55, 0.3, 0.12)
	hov.border_width_left = 3
	hov.border_color = ACCENT
	theme.set_stylebox("normal", "Button", btn)
	theme.set_stylebox("hover", "Button", hov)
	theme.set_stylebox("pressed", "Button", hov)
	theme.set_stylebox("focus", "Button", hov)
	theme.set_stylebox("disabled", "Button", btn)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", ACCENT)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", ACCENT)
	theme.set_color("font_disabled_color", "Button", Color(0.35, 0.35, 0.35))
	theme.set_color("font_color", "Label", TEXT)
	var panel := StyleBoxFlat.new()
	panel.bg_color = BG
	panel.border_color = Color(0.3, 0.27, 0.24)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(18)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0.25, 0.24, 0.23)
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	theme.set_stylebox("slider", "HSlider", sl)
	var gr := StyleBoxFlat.new()
	gr.bg_color = ACCENT
	gr.content_margin_top = 3
	gr.content_margin_bottom = 3
	theme.set_stylebox("grabber_area", "HSlider", gr)
	theme.set_stylebox("grabber_area_highlight", "HSlider", gr)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0.2, 0.19, 0.18)
	theme.set_stylebox("scroll", "VScrollBar", sc)
	var sg := StyleBoxFlat.new()
	sg.bg_color = Color(0.45, 0.42, 0.38)
	theme.set_stylebox("grabber", "VScrollBar", sg)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sg)
	return theme


static func label(text: String, size := 22, col := TEXT, fnt := "PTSans-Regular.ttf") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(fnt))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


static func button(text: String, fn: Callable, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		Snd.play("ui_click", -10.0)
		fn.call())
	b.mouse_entered.connect(func(): Snd.play("ui_hover", -18.0))
	return b


static func full(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func dim_bg(alpha := 0.85) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, alpha)
	full(r)
	return r


## Ползунок с подписью; возвращает HBox.
static func slider(text: String, minv: float, maxv: float, step: float, value: float, fn: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(text, 20, DIM)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(320, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := label(str(snappedf(value, step)), 18, TEXT)
	v.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(x: float):
		v.text = str(snappedf(x, step))
		fn.call(x))
	h.add_child(s)
	h.add_child(v)
	return h


static func toggle(text: String, value: bool, fn: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_size_override("font_size", 20)
	c.add_theme_color_override("font_color", DIM)
	c.toggled.connect(func(v: bool): fn.call(v))
	return c


static func option(text: String, items: Array, idx: int, fn: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := label(text, 20, DIM)
	l.custom_minimum_size = Vector2(300, 0)
	h.add_child(l)
	var o := OptionButton.new()
	for it in items:
		o.add_item(String(it))
	o.selected = idx
	o.add_theme_font_size_override("font_size", 20)
	o.item_selected.connect(func(i: int): fn.call(i))
	h.add_child(o)
	return h
