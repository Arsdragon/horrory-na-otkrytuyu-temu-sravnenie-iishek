class_name Hud
extends CanvasLayer
## Игровой интерфейс: точка прицела, подсказка действия и полоска удержания, мысли героя,
## подсказки, задачи, уведомления телефона, дыхание, батарея, затемнение, пост-эффекты.

var post: ColorRect
var post_mat: ShaderMaterial
var dot: ColorRect
var prompt: Label
var hold_bar: ProgressBar
var hint: Label
var thought: Label
var objective: Label
var notif: Label
var toast_l: Label
var breath: ProgressBar
var battery_l: Label
var debug_l: Label
var fade: ColorRect
var hint_t := 0.0
var thought_t := 0.0
var obj_t := 0.0
var notif_t := 0.0
var toast_t := 0.0
var bat_t := 0.0
var behind := 0.0
var behind_target := 0.0
var memory := 0.0
var slats_kind := ""


func _ready() -> void:
	layer = 5
	var post_layer := CanvasLayer.new()
	post_layer.layer = 4
	add_child(post_layer)
	post = ColorRect.new()
	UI.full(post)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://src/fx/post.gdshader")
	post.material = post_mat
	post_layer.add_child(post)
	var root := Control.new()
	UI.full(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.get_theme()
	add_child(root)
	dot = ColorRect.new()
	dot.color = Color(1, 1, 1, 0.35)
	dot.size = Vector2(4, 4)
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.position = Vector2(-2, -2)
	root.add_child(dot)
	prompt = _center_label(root, 24, Vector2(0, 46), UI.TEXT)
	prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	prompt.add_theme_constant_override("outline_size", 6)
	hold_bar = ProgressBar.new()
	hold_bar.show_percentage = false
	hold_bar.custom_minimum_size = Vector2(200, 5)
	hold_bar.set_anchors_preset(Control.PRESET_CENTER)
	hold_bar.position = Vector2(-100, 82)
	hold_bar.size = Vector2(200, 5)
	var fg := StyleBoxFlat.new()
	fg.bg_color = UI.ACCENT
	var bgs := StyleBoxFlat.new()
	bgs.bg_color = Color(0, 0, 0, 0.5)
	hold_bar.add_theme_stylebox_override("fill", fg)
	hold_bar.add_theme_stylebox_override("background", bgs)
	hold_bar.visible = false
	root.add_child(hold_bar)
	breath = ProgressBar.new()
	breath.show_percentage = false
	breath.set_anchors_preset(Control.PRESET_CENTER)
	breath.position = Vector2(-60, 30)
	breath.size = Vector2(120, 3)
	var bfg := StyleBoxFlat.new()
	bfg.bg_color = Color(0.6, 0.75, 0.9)
	breath.add_theme_stylebox_override("fill", bfg)
	breath.add_theme_stylebox_override("background", bgs)
	breath.max_value = 12.0
	breath.visible = false
	root.add_child(breath)
	hint = Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-500, 40)
	hint.size = Vector2(1000, 60)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.9, 0.8, 0.65))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 6)
	root.add_child(hint)
	thought = Label.new()
	thought.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	thought.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thought.position = Vector2(-560, -150)
	thought.size = Vector2(1120, 90)
	thought.autowrap_mode = TextServer.AUTOWRAP_WORD
	thought.add_theme_font_override("font", UI.font("PTSerif-Italic.ttf"))
	thought.add_theme_font_size_override("font_size", 26)
	thought.add_theme_color_override("font_color", Color(0.92, 0.9, 0.85))
	thought.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	thought.add_theme_constant_override("outline_size", 7)
	root.add_child(thought)
	objective = UI.label("", 20, Color(0.85, 0.8, 0.7))
	objective.position = Vector2(40, 36)
	objective.size = Vector2(700, 80)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	objective.add_theme_constant_override("outline_size", 5)
	root.add_child(objective)
	notif = UI.label("", 20, UI.ACCENT)
	notif.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	notif.position = Vector2(-420, -70)
	notif.size = Vector2(380, 40)
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(notif)
	toast_l = UI.label("", 18, UI.DIM)
	toast_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	toast_l.position = Vector2(40, -60)
	root.add_child(toast_l)
	battery_l = UI.label("", 18, UI.DIM)
	battery_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	battery_l.position = Vector2(40, -90)
	root.add_child(battery_l)
	debug_l = UI.label("", 16, Color(0.6, 1, 0.6), "PTMono-Regular.ttf")
	debug_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_l.position = Vector2(-430, 20)
	debug_l.size = Vector2(410, 200)
	root.add_child(debug_l)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	UI.full(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)
	Game.hint.connect(show_hint)
	Game.thought.connect(show_thought)
	Game.objective_changed.connect(show_objective)
	Game.message_added.connect(func(_id: String): show_notif("✉ Сообщение — Tab"))
	Game.note_added.connect(func(id: String): show_notif("Записка: " + String(Texts.note(id).get("title", ""))))
	Game.item_changed.connect(func(id: String, have: bool):
		if have:
			show_notif(_item_name(id)))


func _center_label(root: Control, size: int, off: Vector2, col: Color) -> Label:
	var l := Label.new()
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(-400, off.y)
	l.size = Vector2(800, 34)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	root.add_child(l)
	return l


static func _item_name(id: String) -> String:
	return {"crowbar": "Монтировка", "wrench": "Газовый ключ", "key_util": "Ключ от подсобки", "key_pump": "Ключ от насосной",
		"mitten": "Детская варежка"}.get(id, id)


func connect_player(p: Player) -> void:
	p.prompt_changed.connect(func(t: String, h: float):
		prompt.text = ("[E]  " + t) if t != "" else ""
		hold_bar.visible = t != "" and h >= 0.0
		if h >= 0.0:
			hold_bar.value = h * 100.0)
	p.battery_changed.connect(func(v: float):
		if v < 25.0:
			bat_t = 2.0
			battery_l.text = "Фонарь: %d%%" % int(v))


func show_hint(t: String, secs := 5.0) -> void:
	if not Settings.hints and not t.begins_with("Код"):
		return
	hint.text = t
	hint_t = secs


func show_thought(t: String, secs := 4.0) -> void:
	thought.text = t
	thought_t = secs


func show_objective(t: String) -> void:
	if t == "":
		return
	objective.text = "Задача: " + t
	obj_t = 7.0
	Snd.play("objective", -10.0)


func show_notif(t: String) -> void:
	notif.text = t
	notif_t = 4.0


func toast(t: String) -> void:
	toast_l.text = t
	toast_t = 2.5


func fade_to(a: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, secs)


func _process(delta: float) -> void:
	hint_t -= delta
	thought_t -= delta
	obj_t -= delta
	notif_t -= delta
	toast_t -= delta
	bat_t -= delta
	hint.modulate.a = clampf(hint_t, 0.0, 1.0)
	thought.modulate.a = clampf(thought_t * 1.5, 0.0, 1.0)
	objective.modulate.a = clampf(obj_t, 0.0, 1.0)
	notif.modulate.a = clampf(notif_t, 0.0, 1.0)
	toast_l.modulate.a = clampf(toast_t, 0.0, 1.0)
	battery_l.modulate.a = clampf(bat_t, 0.0, 1.0)
	var p: Player = Game.player
	var fear := 0.0
	if p:
		fear = p.fear
		breath.visible = p.holding_breath or p.breath < 11.9
		breath.value = p.breath
		dot.visible = not p.hidden_in and not p.input_lock
		if Input.is_action_just_pressed("flashlight"):
			bat_t = 2.0
			battery_l.text = "Фонарь: %d%%" % int(p.battery)
	behind = lerpf(behind, behind_target, delta * 3.0)
	memory = maxf(0.0, memory - delta * 0.25)
	post_mat.set_shader_parameter("fear", fear)
	post_mat.set_shader_parameter("behind", behind)
	post_mat.set_shader_parameter("memory", memory)
	post_mat.set_shader_parameter("time_s", Time.get_ticks_msec() / 1000.0)
	var sl := 1.0 if p and p.hidden_in and slats_kind == "locker" else 0.0
	post_mat.set_shader_parameter("slats", sl)
	if Game.cheats.get("ai_debug", false) and Game.monster:
		var m: Hozyayka = Game.monster
		var dist := m.global_position.distance_to(p.global_position) if p else 0.0
		debug_l.text = "Хозяйка: %s\nдистанция %.1f м\nактивна %.0f с\nагрессия %.1f\nопасность %d\nкомната: %s\nшум/вода: %.2f\nFPS %d" % [
			m.state_name(), dist, m.active_t, m.aggression, int(Game.getf("danger", 0)),
			Game.world.room_name(p.current_room) if Game.world and p else "", p.water if p else 0.0, Engine.get_frames_per_second()]
	else:
		debug_l.text = ""
