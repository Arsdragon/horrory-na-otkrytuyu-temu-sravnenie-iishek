class_name Hud
extends Control
## Интерфейс в игре: прицел, подсказка действия, субтитры, мысли, задачи, тепло, выносливость, значки.

var prompt_text := ""
var prompt_progress := 0.0
var prompt_blocked := false
var _prompt: Label
var _toast: Label
var _sub: Label
var _hint: Label
var _obj: Label
var _toast_t := 0.0
var _sub_t := 0.0
var _hint_t := 0.0
var _obj_t := 0.0
var _icons := {}
var _warm_show := 0.0
var _stam_show := 0.0
var _static_lvl := 0.0
var show_all := true


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt = _label(22, Color(0.95, 0.93, 0.88), "ui")
	_toast = _label(22, Color(0.9, 0.88, 0.82), "ui")
	_sub = _label(26, Color(0.96, 0.95, 0.9), "ui")
	_hint = _label(21, Color(0.82, 0.86, 0.9), "ui")
	_obj = _label(21, Color(0.93, 0.9, 0.8), "ui")
	_obj.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for k in ["rope", "lamp", "flare", "cold", "can", "wood"]:
		_icons[k] = Kit.tex("res://tex/ico_" + k)
	for l in [_toast, _sub, _hint, _obj]:
		(l as Label).modulate.a = 0.0


func _label(size: int, col: Color, family: String) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Kit.font(family))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func set_prompt(text: String, progress: float, blocked: bool) -> void:
	prompt_text = text
	prompt_progress = progress
	prompt_blocked = blocked


func toast(text: String, dur := 2.4) -> void:
	_toast.text = text
	_toast_t = dur


## Реплика с голосом: «Диксон: …»
func subtitle(who: String, text: String, dur := 4.0) -> void:
	if not Cfg.subtitles:
		return
	_sub.text = (who + ":  " if who != "" else "") + text
	_sub.add_theme_color_override("font_color", Color(0.96, 0.95, 0.9))
	_sub_t = dur


## Мысль героя — тем же местом, но приглушённо.
func think(text: String, dur := 3.6) -> void:
	_sub.text = "— " + text
	_sub.add_theme_color_override("font_color", Color(0.74, 0.78, 0.84))
	_sub_t = dur


func hint(text: String, dur := 7.0) -> void:
	_hint.text = text
	_hint_t = dur


func objective(text: String) -> void:
	_obj.text = "ЗАДАЧА\n" + text
	_obj_t = 7.0
	Snd.play("pencil", -14.0)


func clear_all() -> void:
	_toast_t = 0.0
	_sub_t = 0.0
	_hint_t = 0.0
	_obj_t = 0.0
	prompt_text = ""


func _fade(l: Label, t: float, dt: float) -> void:
	var tgt := 1.0 if t > 0.0 else 0.0
	l.modulate.a = move_toward(l.modulate.a, tgt, dt * (5.0 if tgt > 0.5 else 2.5))


func _process(dt: float) -> void:
	# размер задаём явно: якоря у корневого Control под CanvasLayer не срабатывают
	position = Vector2.ZERO
	size = get_viewport_rect().size
	var sz := size
	_toast_t -= dt
	_sub_t -= dt
	_hint_t -= dt
	_obj_t -= dt
	_fade(_toast, _toast_t, dt)
	_fade(_sub, _sub_t, dt)
	_fade(_hint, _hint_t, dt)
	_fade(_obj, _obj_t, dt)
	var w := minf(sz.x * 0.7, 900.0)
	_prompt.size = Vector2(w, 34)
	_prompt.position = Vector2((sz.x - w) * 0.5, sz.y * 0.5 + 46)
	_toast.size = Vector2(w, 34)
	_toast.position = Vector2((sz.x - w) * 0.5, sz.y * 0.5 + 100)
	_sub.size = Vector2(w, 80)
	_sub.position = Vector2((sz.x - w) * 0.5, sz.y - 150)
	_hint.size = Vector2(w, 60)
	_hint.position = Vector2((sz.x - w) * 0.5, 54)
	_obj.size = Vector2(430, 110)
	_obj.position = Vector2(34, 30)
	var p := prompt_text
	if p != "":
		p = ("E — " + p) if not prompt_blocked else p
	_prompt.text = p
	_prompt.add_theme_color_override("font_color", Color(0.75, 0.5, 0.45) if prompt_blocked else Color(0.95, 0.93, 0.88))
	_prompt.visible = show_all
	var pl: Player = G.player
	if pl != null and is_instance_valid(pl):
		var out := float(pl.zone.get("shelter", 0.0)) < 0.5
		_warm_show = move_toward(_warm_show, 1.0 if (pl.warmth < 85.0 or out) else 0.0, dt * 2.0)
		_stam_show = move_toward(_stam_show, 1.0 if pl.stamina < 99.0 else 0.0, dt * 3.0)
	queue_redraw()


func set_static(level: float) -> void:
	_static_lvl = level


func _bar(pos: Vector2, w: float, v: float, col: Color, alpha: float) -> void:
	if alpha <= 0.01:
		return
	draw_rect(Rect2(pos, Vector2(w, 5)), Color(0, 0, 0, 0.5 * alpha))
	draw_rect(Rect2(pos, Vector2(w * clampf(v, 0.0, 1.0), 5)), Color(col.r, col.g, col.b, alpha))


func _icon(key: String, pos: Vector2, s: float, col: Color) -> void:
	var t: Texture2D = _icons.get(key)
	if t != null:
		draw_texture_rect(t, Rect2(pos, Vector2(s, s)), false, col)


func _draw() -> void:
	if not show_all:
		return
	var sz := size
	var c := sz * 0.5
	var pl: Player = G.player
	if pl == null or not is_instance_valid(pl) or pl.mode == "dead":
		return
	# прицел
	var foc := prompt_text != ""
	draw_circle(c, 3.6 if foc else 2.0, Color(0, 0, 0, 0.45))
	draw_circle(c, 2.4 if foc else 1.2, Color(1, 1, 1, 0.85 if foc else 0.45))
	# удержание
	if prompt_progress > 0.001:
		var bw := 220.0
		draw_rect(Rect2(c + Vector2(-bw * 0.5, 86), Vector2(bw, 6)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(c + Vector2(-bw * 0.5, 86), Vector2(bw * clampf(prompt_progress, 0.0, 1.0), 6)), Color(0.95, 0.9, 0.75, 0.95))
	# тепло и выносливость
	var x0 := 36.0
	var y0 := sz.y - 46.0
	if _warm_show > 0.01:
		var k := pl.warmth / 100.0
		var col := Color(0.75, 0.86, 1.0).lerp(Color(1.0, 0.35, 0.3), clampf((0.3 - k) / 0.3, 0.0, 1.0))
		_icon("cold", Vector2(x0, y0 - 14), 26, Color(col.r, col.g, col.b, _warm_show * 0.9))
		_bar(Vector2(x0 + 34, y0 - 3), 190, k, col, _warm_show * 0.9)
	if _stam_show > 0.01:
		_bar(Vector2(x0 + 34, y0 + 9), 190, pl.stamina / 100.0, Color(0.9, 0.85, 0.6) if not pl.exhausted else Color(0.8, 0.4, 0.3), _stam_show * 0.8)
	# леер
	if pl.gripping:
		_icon("rope", Vector2(c.x - 22, sz.y - 86), 44, Color(1, 0.95, 0.8, 0.95))
	elif pl.near_rope and pl.mode == "walk":
		_icon("rope", Vector2(c.x - 18, sz.y - 82), 36, Color(1, 1, 1, 0.42 + 0.15 * sin(Time.get_ticks_msec() * 0.006)))
	# дыхание в укрытии
	if pl.can_hold_breath:
		var bw2 := 260.0
		draw_rect(Rect2(Vector2(c.x - bw2 * 0.5, sz.y - 110), Vector2(bw2, 7)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(Vector2(c.x - bw2 * 0.5, sz.y - 110), Vector2(bw2 * pl.breath / 100.0, 7)), Color(0.7, 0.85, 1.0, 0.9) if pl.breath_held else Color(0.6, 0.6, 0.6, 0.6))
	# справа внизу: фонарь, фальшфейеры, ноша
	var rx := sz.x - 70.0
	var ry := sz.y - 66.0
	_icon("lamp", Vector2(rx, ry), 34, Color(1.0, 0.92, 0.7, 0.95) if pl.lamp_shining() else Color(1, 1, 1, 0.25))
	if pl.flares > 0 or pl.flare_t > 0.0:
		rx -= 52.0
		_icon("flare", Vector2(rx, ry), 34, Color(1.0, 0.35, 0.25, 0.95) if pl.flare_t > 0.0 else Color(1, 1, 1, 0.6))
		draw_string(Kit.font("ui"), Vector2(rx + 30, ry + 34), str(pl.flares), HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))
	if pl.carrying == "jerry":
		rx -= 52.0
		_icon("can", Vector2(rx, ry), 34, Color(1, 1, 1, 0.8))
	elif pl.carrying == "wood":
		rx -= 52.0
		_icon("wood", Vector2(rx, ry), 34, Color(1, 1, 1, 0.8))
	# рация шипит: столбики помех
	if _static_lvl > 0.03:
		var bx := sz.x - 70.0
		var by := 46.0
		for i in 5:
			var h := 6.0 + 22.0 * clampf(_static_lvl * (0.6 + 0.6 * randf()), 0.0, 1.0) * float(i + 1) / 5.0
			draw_rect(Rect2(Vector2(bx + i * 8.0, by + 28 - h), Vector2(5, h)), Color(0.9, 0.3, 0.25, 0.3 + 0.6 * _static_lvl))
		draw_string(Kit.font("ui"), Vector2(bx - 62, by + 26), "РАЦИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.9, 0.5, 0.45, 0.4 + 0.5 * _static_lvl))
