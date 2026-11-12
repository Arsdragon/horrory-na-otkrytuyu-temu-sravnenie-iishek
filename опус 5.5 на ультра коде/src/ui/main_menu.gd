class_name MainMenu
extends Control
## Главное меню: фон (кадр бани), пар, название, кнопки.

var buttons: VBoxContainer
var sub: Control = null
var steam: Array = []


func _ready() -> void:
	theme = UI.get_theme()
	UI.full(self)
	var bg := ColorRect.new()
	bg.color = Color(0.015, 0.015, 0.02)
	UI.full(bg)
	add_child(bg)
	if ResourceLoader.exists("res://tex/ui/menu_bg.png"):
		var tr := TextureRect.new()
		tr.texture = load("res://tex/ui/menu_bg.png")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		UI.full(tr)
		tr.modulate = Color(0.75, 0.72, 0.7)
		add_child(tr)
		var tw := tr.create_tween().set_loops()
		tw.tween_property(tr, "scale", Vector2(1.04, 1.04), 18.0)
		tw.tween_property(tr, "scale", Vector2(1.0, 1.0), 18.0)
	# клубы пара
	for i in 7:
		var s := TextureRect.new()
		s.texture = load("res://tex/ui/steam_puff.png")
		s.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s.size = Vector2(700, 700)
		s.modulate = Color(1, 1, 1, 0.05)
		s.position = Vector2(randf_range(-300, 1500), randf_range(200, 900))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		steam.append(s)
	var grad := ColorRect.new()
	grad.color = Color(0, 0, 0, 0.55)
	grad.size = Vector2(760, 2000)
	add_child(grad)
	var title := UI.label("ТРЕТИЙ ПАР", 92, Color(0.88, 0.84, 0.78), "RuslanDisplay.ttf")
	title.position = Vector2(110, 110)
	add_child(title)
	var subt := UI.label("Баня № 3. Ночь на 22 декабря.", 26, UI.DIM, "PTSerif-Italic.ttf")
	subt.position = Vector2(116, 230)
	add_child(subt)
	buttons = VBoxContainer.new()
	buttons.position = Vector2(100, 340)
	buttons.add_theme_constant_override("separation", 4)
	add_child(buttons)
	_main_buttons()
	var hint := UI.label("Играть лучше в наушниках и в темноте.", 18, UI.DIM)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.position = Vector2(110, -60)
	add_child(hint)
	var ver := UI.label("v" + String(ProjectSettings.get_setting("application/config/version")), 16, Color(0.35, 0.35, 0.35))
	ver.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ver.position = Vector2(-90, -40)
	add_child(ver)


func _main_buttons() -> void:
	for c in buttons.get_children():
		c.queue_free()
	var m = Game.main
	if Game.has_save():
		buttons.add_child(UI.button("Продолжить", func(): m.continue_game(), 32))
	buttons.add_child(UI.button("Новая игра", func(): m.new_game(), 32))
	buttons.add_child(UI.button("Админ-режим", func(): m.open_admin_menu(), 32))
	buttons.add_child(UI.button("Настройки", _settings, 32))
	buttons.add_child(UI.button("Концовки", _endings, 32))
	buttons.add_child(UI.button("Об игре", _about, 32))
	buttons.add_child(UI.button("Выход", func(): get_tree().quit(), 32))


func _sub(c: Control) -> void:
	if sub:
		sub.queue_free()
	sub = c
	add_child(c)


func _settings() -> void:
	_sub(Screens.settings(func():
		sub.queue_free()
		sub = null))


func _endings() -> void:
	var c := Control.new()
	UI.full(c)
	c.add_child(UI.dim_bg(0.92))
	var v := VBoxContainer.new()
	v.position = Vector2(120, 140)
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	v.add_child(UI.label("Концовки", 44, UI.ACCENT, "PTSerif-Regular.ttf"))
	var i := 1
	for id in ["open_tap", "valve", "steam", "last_steam"]:
		var seen: bool = id in Game.endings_seen
		v.add_child(UI.label("%d. %s" % [i, ("«%s»" % Texts.ENDINGS[id][0]) if seen else "???"], 28, UI.TEXT if seen else UI.DIM))
		i += 1
	v.add_child(UI.label("Смертей: %d" % Game.deaths, 20, UI.DIM))
	v.add_child(UI.button("Назад", func():
		sub.queue_free()
		sub = null))
	_sub(c)


func _about() -> void:
	var c := Control.new()
	UI.full(c)
	c.add_child(UI.dim_bg(0.92))
	var v := VBoxContainer.new()
	v.position = Vector2(120, 120)
	v.add_theme_constant_override("separation", 12)
	c.add_child(v)
	v.add_child(UI.label("Об игре", 44, UI.ACCENT, "PTSerif-Regular.ttf"))
	var t := UI.label("«Третий пар» — хоррор от первого лица.\nПо старому поверью, первый пар — людям, второй — духу, третий — банной нечисти. Кто моется в третий пар, того она «моет».\n\nУправление: WASD, мышь; Shift — бег; Ctrl/C — пригнуться; E/ЛКМ — действие (долгие — держать); F — фонарь; Tab — телефон; Пробел — не дышать; ЛКМ с шайкой — бросить, G — положить; Esc — пауза.\n\nТекстуры: ambientCG, Poly Haven (CC0). Модели: Poly Haven (CC0), Microsoft Rocketbox (MIT). Шрифты: ParaType PT, Ruslan Display, Caveat, Marck Script, Neucha, Oswald (OFL). Звук, голоса, здание, записки — сделаны для игры.\nПолный список — CREDITS.txt.", 21, UI.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size = Vector2(1100, 0)
	v.add_child(t)
	v.add_child(UI.button("Назад", func():
		sub.queue_free()
		sub = null))
	_sub(c)


func _process(delta: float) -> void:
	for i in steam.size():
		var s: TextureRect = steam[i]
		s.position += Vector2(8.0 + i, -10.0 - i * 2.0) * delta
		s.modulate.a = 0.04 + 0.03 * sin(Time.get_ticks_msec() / 3000.0 + i)
		if s.position.y < -700:
			s.position = Vector2(randf_range(-300, 1500), 1000)
