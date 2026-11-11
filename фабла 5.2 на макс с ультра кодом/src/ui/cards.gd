class_name Cards
extends Control
## Полноэкранные карточки: вступление, название ночи, смерть, концовка. Поверх всего.

signal closed
signal chosen(what: String)

var _bg: ColorRect
var _box: VBoxContainer
var _skip := false
var _active := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new()
	_bg.color = Color(0, 0, 0, 0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)
	_box = Ui.vbox(14)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)
	visible = false


func _process(_dt: float) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_bg.size = size
	var w := minf(size.x * 0.72, 980.0)
	_box.size = Vector2(w, size.y)
	_box.position = Vector2((size.x - w) * 0.5, 0)


func _unhandled_input(e: InputEvent) -> void:
	if not _active:
		return
	if e.is_action_pressed("use") or e.is_action_pressed("breath") or e.is_action_pressed("pause"):
		_skip = true
		get_viewport().set_input_as_handled()


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func busy() -> bool:
	return _active


func _wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end and not _skip:
		await get_tree().process_frame


func _fade_bg(a: float, t: float) -> void:
	var tw := create_tween()
	tw.tween_property(_bg, "color:a", a, t)
	await tw.finished


## Строки появляются по одной, как на машинке. Потом ждём клавишу.
func lines(texts: Array, bg_alpha := 1.0, size := 30, hold := 2.2) -> void:
	_active = true
	_skip = false
	visible = true
	_clear()
	_bg.color.a = bg_alpha
	for t in texts:
		var l := Ui.label("", size, Color(0.86, 0.85, 0.8), "type")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_box.add_child(l)
		var s := String(t)
		for i in s.length():
			l.text = s.substr(0, i + 1)
			if s[i] != " " and i % 2 == 0:
				Snd.play("type", -16.0, randf_range(0.9, 1.1))
			if not _skip:
				await get_tree().create_timer(0.032, true).timeout
		l.text = s
		_skip = false
		await _wait(hold * 0.45)
		_skip = false
	await _wait(hold)
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.8)
	await tw.finished
	_clear()
	_box.modulate.a = 1.0
	_active = false
	closed.emit()


## Название ночи: крупно, с подзаголовком и датой.
func title(big: String, small: String, date: String) -> void:
	_active = true
	_skip = false
	visible = true
	_clear()
	_bg.color.a = 1.0
	var a := Ui.label(big, 64, Color(0.92, 0.9, 0.85), "head")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := Ui.label(small, 34, Ui.ACCENT, "head")
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var c := Ui.label(date, 22, Ui.DIM, "type")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in [a, b, c]:
		_box.add_child(l)
	_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 1.0, 1.0)
	await tw.finished
	await _wait(2.4)
	tw = create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 0.9)
	await tw.finished
	_clear()
	_box.modulate.a = 1.0
	_active = false
	closed.emit()


## Убрать чёрный фон (после карточки ночи мир проявляется).
func reveal(t := 1.6) -> void:
	await _fade_bg(0.0, t)
	if not _active:
		visible = false


func black(a := 1.0) -> void:
	visible = true
	_bg.color.a = a


## Смерть: заголовок, строка, выбор. Возвращает через сигнал chosen ("retry" | "menu").
func death(head: String, line: String, can_retry := true) -> void:
	_active = false
	visible = true
	_clear()
	_bg.color = Color(0, 0, 0, 1)
	mouse_filter = Control.MOUSE_FILTER_STOP
	await get_tree().create_timer(1.6, true).timeout
	var a := Ui.label(head, 58, Color(0.8, 0.14, 0.1), "head")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := Ui.label(line, 26, Color(0.75, 0.74, 0.7), "type")
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(a)
	_box.add_child(b)
	var sp := Control.new()
	sp.custom_minimum_size.y = 30
	_box.add_child(sp)
	_box.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_box, "modulate:a", 1.0, 1.4)
	await tw.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var row := Ui.hbox(30)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if can_retry:
		var r := Ui.button("С контрольной точки", func() -> void: _choose("retry"))
		row.add_child(r)
		r.grab_focus.call_deferred()
	row.add_child(Ui.button("В меню", func() -> void: _choose("menu")))
	_box.add_child(row)


func _choose(what: String) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear()
	chosen.emit(what)


## Концовка: название, строки, титры.
func ending(head: String, texts: Array, credits: String) -> void:
	_active = true
	_skip = false
	visible = true
	_clear()
	_bg.color = Color(0, 0, 0, 1)
	await get_tree().create_timer(1.5, true).timeout
	var a := Ui.label(head, 70, Color(0.92, 0.9, 0.85), "head")
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(a)
	a.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(a, "modulate:a", 1.0, 1.6)
	await tw.finished
	await _wait(1.2)
	_skip = false
	for t in texts:
		var l := Ui.label(String(t), 28, Color(0.8, 0.79, 0.75), "type")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.modulate.a = 0.0
		_box.add_child(l)
		tw = create_tween()
		tw.tween_property(l, "modulate:a", 1.0, 1.2)
		await tw.finished
		await _wait(2.6)
		_skip = false
	await _wait(3.0)
	_skip = false
	tw = create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 1.5)
	await tw.finished
	_clear()
	_box.modulate.a = 1.0
	var c := Ui.label(credits, 26, Color(0.7, 0.7, 0.68), "type")
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(c)
	_box.modulate.a = 0.0
	tw = create_tween()
	tw.tween_property(_box, "modulate:a", 1.0, 1.5)
	await tw.finished
	await _wait(7.0)
	tw = create_tween()
	tw.tween_property(_box, "modulate:a", 0.0, 1.5)
	await tw.finished
	_clear()
	_box.modulate.a = 1.0
	_active = false
	closed.emit()
