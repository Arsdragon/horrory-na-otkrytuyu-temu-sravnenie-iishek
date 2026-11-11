class_name Ui
extends RefCounted
## Заготовки интерфейса: подписи, кнопки, панели — в одном стиле.

const TEXT := Color(0.9, 0.88, 0.83)
const DIM := Color(0.6, 0.62, 0.66)
const ACCENT := Color(0.86, 0.2, 0.14)


static func label(text: String, size := 24, color := TEXT, family := "ui") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Kit.font(family))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _flat(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	return sb


static func button(text: String, cb: Callable, size := 26, min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", Kit.font("ui"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color(0.78, 0.77, 0.73))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", ACCENT)
	b.add_theme_stylebox_override("normal", _flat(Color(0, 0, 0, 0.0)))
	b.add_theme_stylebox_override("hover", _flat(Color(0.75, 0.12, 0.08, 0.35)))
	b.add_theme_stylebox_override("focus", _flat(Color(0.75, 0.12, 0.08, 0.35)))
	b.add_theme_stylebox_override("pressed", _flat(Color(0.75, 0.12, 0.08, 0.55)))
	if min_w > 0.0:
		b.custom_minimum_size.x = min_w
	b.pressed.connect(func() -> void:
		Snd.play("ui_ok", -8.0)
		cb.call())
	b.mouse_entered.connect(func() -> void:
		Snd.play("ui_move", -12.0)
		b.grab_focus())
	return b


static func panel(c := Color(0.02, 0.025, 0.03, 0.82)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 18
	sb.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", sb)
	return p


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## Строка настройки: подпись, ползунок, значение.
static func slider(text: String, from: float, to: float, step: float, value: float, on_change: Callable, fmt := "%.2f", label_w := 300.0, slider_w := 280.0) -> HBoxContainer:
	var h := hbox(14)
	var l := label(text, 22)
	l.custom_minimum_size.x = label_w
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = from
	s.max_value = to
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(slider_w, 26)
	h.add_child(s)
	var v := label(fmt % value, 22, DIM)
	v.custom_minimum_size.x = 80
	h.add_child(v)
	s.value_changed.connect(func(x: float) -> void:
		v.text = fmt % x
		on_change.call(x))
	return h


static func check(text: String, value: bool, on_change: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = value
	c.add_theme_font_override("font", Kit.font("ui"))
	c.add_theme_font_size_override("font_size", 22)
	c.add_theme_color_override("font_color", TEXT)
	c.toggled.connect(func(x: bool) -> void:
		Snd.play("ui_move", -10.0)
		on_change.call(x))
	return c
