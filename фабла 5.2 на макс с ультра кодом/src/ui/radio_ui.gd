class_name RadioUi
extends Control
## Радиостанция: шкала 3000–7000 кГц, настройка на слух, передача ключом.
## Диксон — 4620. На других частотах тоже кто-то есть.

signal closed
signal transmit

const F_MIN := 3000.0
const F_MAX := 7000.0
const DIKSON := 4620.0

var is_open := false
var freq := 3840.0
var can_send := false        # режиссёр разрешил передачу
var busy := false            # идёт сеанс связи — крутить и уходить нельзя
var decoded := ""            # расшифровка принимаемой морзянки
var extra_stations := 0      # 0 — только жужжалка и старый SOS; 1 — ещё «своё дыхание»; 2 — «открой»
var _vel := 0.0
var _last_tick := 0.0
var _num_t := 0.0
var _hint: Label
var _text: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint = Ui.label("", 20, Ui.DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hint)
	_text = Ui.label("", 26, Color(0.85, 0.95, 0.8), "type")
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_text)
	visible = false


func open() -> void:
	is_open = true
	visible = true
	decoded = ""
	Snd.play("radio_on", -4.0)
	Snd.loop("radio_static", "radio_static", 0.0, 0.4, "Sfx")
	Snd.loop("radio_whine", "radio_whine", 0.0, 0.2, "Sfx")
	Snd.loop("st_buzzer", "buzzer", 0.0, 0.2, "Sfx")
	Snd.loop("st_sos", "morse_tx_4", 0.0, 0.2, "Sfx")
	Snd.loop("st_self", "ent_near", 0.0, 0.2, "Sfx")
	Snd.loop("st_open", "gr_n3_f", 0.0, 0.2, "Sfx")


func close() -> void:
	if not is_open:
		return
	is_open = false
	visible = false
	Snd.play("radio_off", -4.0)
	for id in ["radio_static", "radio_whine", "st_buzzer", "st_sos", "st_self", "st_open"]:
		Snd.stop_loop(id, 0.25)
	closed.emit()


func tuned() -> bool:
	return absf(freq - DIKSON) < 14.0


func _stations() -> Array:
	var a := [[DIKSON, ""], [5900.0, "st_buzzer"], [3300.0, "st_sos"]]
	if extra_stations >= 1:
		a.append([6600.0, "st_self"])
	if extra_stations >= 2:
		a.append([4100.0, "st_open"])
	return a


func _unhandled_input(e: InputEvent) -> void:
	if not is_open:
		return
	if e is InputEventMouseButton and (e as InputEventMouseButton).pressed and not busy:
		var mb: InputEventMouseButton = e
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			freq = clampf(freq + 4.0, F_MIN, F_MAX)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			freq = clampf(freq - 4.0, F_MIN, F_MAX)
	if e.is_action_pressed("breath") and not busy:
		if tuned() and can_send:
			transmit.emit()
		elif tuned():
			G.hud.toast("Передавать пока нечего")
		else:
			G.hud.toast("Диксон не здесь. Ищи на слух")
		get_viewport().set_input_as_handled()
	elif (e.is_action_pressed("pause") or e.is_action_pressed("use")) and not busy:
		close()
		get_viewport().set_input_as_handled()


## Показать расшифровку: буквы появляются за время звучания морзянки.
func type_line(text: String, dur: float) -> void:
	decoded = ""
	var n := text.length()
	for i in n:
		decoded = text.substr(0, i + 1)
		await get_tree().create_timer(dur / float(maxi(n, 1))).timeout
	decoded = text


func _process(dt: float) -> void:
	if not visible:
		return
	position = Vector2.ZERO
	size = get_viewport_rect().size
	# настройка: чем дольше держишь, тем быстрее
	var ax := 0.0
	if not busy:
		ax = Input.get_axis("move_l", "move_r")
	if absf(ax) > 0.1:
		_vel = move_toward(_vel, ax * 520.0, dt * 420.0)
	else:
		_vel = move_toward(_vel, 0.0, dt * 2400.0)
	freq = clampf(freq + _vel * dt, F_MIN, F_MAX)
	if absf(freq - _last_tick) > 25.0:
		_last_tick = freq
		Snd.play("tune_tick", -14.0, randf_range(0.9, 1.1))
	# сигнал ближайшей станции
	var best := 9999.0
	for st in _stations():
		var off := absf(freq - float(st[0]))
		best = minf(best, off)
		var id := String(st[1])
		if id != "":
			Snd.loop_vol(id, clampf(1.0 - off / 45.0, 0.0, 1.0) * 0.55, 0.1)
	var sig := clampf(1.0 - best / 60.0, 0.0, 1.0)
	Snd.loop_vol("radio_static", 0.5 * (1.0 - sig * 0.75), 0.1)
	var whine := clampf(1.0 - best / 70.0, 0.0, 1.0) * clampf(best / 6.0, 0.0, 1.0)
	Snd.loop_vol("radio_whine", whine * 0.22, 0.05)
	Snd.loop_pitch("radio_whine", clampf(0.25 + best / 28.0, 0.25, 3.0))
	# номерная станция иногда заговаривает
	if absf(freq - 5900.0) < 18.0 and not busy:
		_num_t += dt
		if _num_t > 4.0:
			_num_t = -22.0
			var key := "num_a" if randf() < 0.6 else "num_b"
			Snd.voice(key, -6.0)
			G.hud.subtitle("Эфир", String(T.VOICE[key]), 16.0)
	else:
		_num_t = minf(_num_t, 0.0) if _num_t < 0.0 else 0.0
	if busy:
		_hint.text = ""
	elif tuned():
		_hint.text = "Диксон, 4620 кГц.   " + ("Пробел — передать   " if can_send else "") + "E — встать"
	else:
		_hint.text = "A / D — настройка   ·   Пробел — передать   ·   E — встать"
	_hint.size = Vector2(size.x, 30)
	_hint.position = Vector2(0, size.y - 52)
	_text.text = decoded
	_text.size = Vector2(minf(size.x * 0.8, 1000.0), 90)
	_text.position = Vector2((size.x - _text.size.x) * 0.5, size.y - 330)
	queue_redraw()


func _draw() -> void:
	var w := minf(size.x * 0.74, 900.0)
	var x0 := (size.x - w) * 0.5
	var y0 := size.y - 220.0
	draw_rect(Rect2(x0 - 24, y0 - 34, w + 48, 140), Color(0.03, 0.035, 0.03, 0.9))
	draw_rect(Rect2(x0 - 24, y0 - 34, w + 48, 140), Color(0.55, 0.6, 0.45, 0.35), false, 2.0)
	draw_rect(Rect2(x0, y0, w, 56), Color(0.78, 0.74, 0.55, 0.92))
	var f := Kit.font("ui")
	var k := 0
	var fr := F_MIN
	while fr <= F_MAX + 0.1:
		var x := x0 + (fr - F_MIN) / (F_MAX - F_MIN) * w
		var big := k % 5 == 0
		draw_line(Vector2(x, y0 + 56), Vector2(x, y0 + (26.0 if big else 40.0)), Color(0.1, 0.1, 0.08), 2.0 if big else 1.0)
		if big:
			draw_string(f, Vector2(x - 20, y0 + 20), str(int(fr)), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.1, 0.08))
		fr += 100.0
		k += 1
	# карандашная отметка Громова на частоте Диксона
	var xd := x0 + (DIKSON - F_MIN) / (F_MAX - F_MIN) * w
	draw_line(Vector2(xd, y0 + 2), Vector2(xd, y0 + 12), Color(0.1, 0.15, 0.5), 2.0)
	var xn := x0 + (freq - F_MIN) / (F_MAX - F_MIN) * w
	draw_line(Vector2(xn, y0 - 6), Vector2(xn, y0 + 62), Color(0.8, 0.1, 0.06), 3.0)
	draw_string(f, Vector2(x0, y0 - 12), "ПРИЁМНИК  ·  кГц", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.7, 0.72, 0.6))
	draw_string(f, Vector2(x0 + w - 110, y0 - 12), "%4d кГц" % int(freq), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.9, 0.9, 0.8))
	# индикатор сигнала
	var best := 9999.0
	for st in _stations():
		best = minf(best, absf(freq - float(st[0])))
	var sig := clampf(1.0 - best / 60.0, 0.0, 1.0)
	draw_string(f, Vector2(x0, y0 + 88), "СИГНАЛ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.72, 0.6))
	draw_rect(Rect2(x0 + 80, y0 + 76, 240, 12), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(x0 + 80, y0 + 76, 240 * (sig * (0.85 + 0.15 * randf())), 12), Color(0.5, 0.9, 0.4, 0.9))
