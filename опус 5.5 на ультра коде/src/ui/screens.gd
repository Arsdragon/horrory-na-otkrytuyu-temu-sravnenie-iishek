class_name Screens
## Экраны поверх игры: записка, кодовый замок, пауза, настройки, смерть, концовка.


## Записка: бумага слева, текст справа.
static func note(id: String, on_close: Callable) -> Control:
	var root := Control.new()
	root.theme = UI.get_theme()
	UI.full(root)
	root.add_child(UI.dim_bg(0.88))
	var n := Texts.note(id)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_CENTER)
	h.position = Vector2(-700, -380)
	h.size = Vector2(1400, 760)
	h.add_theme_constant_override("separation", 40)
	root.add_child(h)
	var tex_path := "res://tex/gen/note_%s.png" % id
	if id == "rules":
		tex_path = "res://tex/gen/rules.png"
	elif id == "child_drawing":
		tex_path = "res://tex/gen/child_drawing.png"
	elif id == "old_photo":
		tex_path = "res://tex/gen/old_photo.png"
	if ResourceLoader.exists(tex_path):
		var tr := TextureRect.new()
		tr.texture = load(tex_path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(520, 700)
		h.add_child(tr)
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(760, 700)
	v.add_child(UI.label(String(n.get("title", "")), 34, UI.ACCENT, "PTSerif-Regular.ttf"))
	v.add_child(UI.label(String(n.get("where", "")), 18, UI.DIM))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var t := UI.label(String(n.get("text", "")), 24, UI.TEXT, "PTSerif-Regular.ttf")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size = Vector2(740, 0)
	sc.add_child(t)
	v.add_child(sc)
	v.add_child(UI.button("Закрыть  [E / Esc]", on_close, 22))
	h.add_child(v)
	Snd.play("paper", -6.0)
	return root


## Кнопочный кодовый замок.
static func codepad(on_ok: Callable, on_close: Callable) -> Control:
	var root := Control.new()
	root.theme = UI.get_theme()
	UI.full(root)
	root.add_child(UI.dim_bg(0.6))
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.position = Vector2(-170, -260)
	p.size = Vector2(340, 520)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(UI.label("Кодовый замок", 24, UI.ACCENT))
	var disp := UI.label("____", 44, Color(0.6, 0.9, 0.6), "PTMono-Regular.ttf")
	disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(disp)
	var entered := [""]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var upd := func():
		disp.text = (entered[0] + "____").substr(0, 4)
	for k in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "С", "0", "OK"]:
		var key: String = k
		var b := Button.new()
		b.text = key
		b.custom_minimum_size = Vector2(90, 64)
		b.add_theme_font_size_override("font_size", 28)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.25, 0.23)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate() as StyleBoxFlat
		sh.bg_color = Color(0.4, 0.38, 0.33)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(func():
			Snd.play("keypad", -6.0, randf_range(0.95, 1.05))
			if key == "С":
				entered[0] = ""
			elif key == "OK":
				on_ok.call(entered[0])
				entered[0] = ""
			elif entered[0].length() < 4:
				entered[0] += key
			upd.call())
		grid.add_child(b)
	v.add_child(UI.button("Отойти  [Esc]", on_close, 20))
	root.set_meta("entered", entered)
	return root


## Пауза.
static func pause(on_resume: Callable, on_settings: Callable, on_menu: Callable) -> Control:
	var root := Control.new()
	root.theme = UI.get_theme()
	UI.full(root)
	root.add_child(UI.dim_bg(0.75))
	var v := VBoxContainer.new()
	v.position = Vector2(120, 260)
	v.add_theme_constant_override("separation", 6)
	root.add_child(v)
	v.add_child(UI.label("Пауза", 48, UI.ACCENT, "PTSerif-Regular.ttf"))
	v.add_child(UI.button("Продолжить", on_resume))
	v.add_child(UI.button("Настройки", on_settings))
	v.add_child(UI.button("В главное меню", on_menu))
	var hint := UI.label("Управление: WASD — идти, Shift — бежать, Ctrl/C — пригнуться, E/ЛКМ — действие (долгие — держать),\nF — фонарь, Tab — телефон, Пробел — не дышать, ЛКМ с шайкой — бросить, G — положить.", 18, UI.DIM)
	hint.position = Vector2(120, 760)
	root.add_child(hint)
	return root


## Настройки.
static func settings(on_back: Callable) -> Control:
	var root := Control.new()
	root.theme = UI.get_theme()
	UI.full(root)
	root.add_child(UI.dim_bg(0.9))
	var v := VBoxContainer.new()
	v.position = Vector2(120, 120)
	v.add_theme_constant_override("separation", 10)
	root.add_child(v)
	v.add_child(UI.label("Настройки", 44, UI.ACCENT, "PTSerif-Regular.ttf"))
	var s := Settings
	v.add_child(UI.slider("Чувствительность мыши", 0.05, 0.6, 0.01, s.mouse_sens, func(x): _apply_setting("mouse_sens", x)))
	v.add_child(UI.slider("Поле зрения", 60, 95, 1, s.fov, func(x): _apply_setting("fov", x)))
	v.add_child(UI.slider("Яркость", 0.6, 1.8, 0.05, s.brightness, func(x): _apply_setting("brightness", x)))
	v.add_child(UI.slider("Громкость: общая", 0, 1, 0.05, s.vol_master, func(x): _apply_setting("vol_master", x)))
	v.add_child(UI.slider("Громкость: музыка", 0, 1, 0.05, s.vol_music, func(x): _apply_setting("vol_music", x)))
	v.add_child(UI.slider("Громкость: звуки", 0, 1, 0.05, s.vol_sfx, func(x): _apply_setting("vol_sfx", x)))
	v.add_child(UI.slider("Громкость: голоса", 0, 1, 0.05, s.vol_voice, func(x): _apply_setting("vol_voice", x)))
	v.add_child(UI.option("Качество графики", ["Низкое (быстро)", "Среднее", "Высокое"], s.quality, func(i): _apply_setting("quality", i)))
	v.add_child(UI.toggle("Полный экран", s.fullscreen, func(b): _apply_setting("fullscreen", b)))
	v.add_child(UI.toggle("Вертикальная синхронизация", s.vsync, func(b): _apply_setting("vsync", b)))
	v.add_child(UI.toggle("Покачивание камеры", s.head_bob, func(b): _apply_setting("head_bob", b)))
	v.add_child(UI.toggle("Инвертировать мышь по вертикали", s.invert_y, func(b): _apply_setting("invert_y", b)))
	v.add_child(UI.toggle("Подсказки", s.hints, func(b): _apply_setting("hints", b)))
	v.add_child(UI.button("Назад", func():
		s.save_cfg()
		on_back.call()))
	return root


static func _apply_setting(k: String, v: Variant) -> void:
	Settings.set(k, v)
	Settings.apply()


## Смерть.
static func death(reason: String, on_retry: Callable, on_menu: Callable) -> Control:
	var root := Control.new()
	root.theme = UI.get_theme()
	UI.full(root)
	var bg := UI.dim_bg(1.0)
	root.add_child(bg)
	var t := UI.label("С ЛЁГКИМ ПАРОМ", 72, Color(0.75, 0.72, 0.68), "RuslanDisplay.ttf")
	t.set_anchors_preset(Control.PRESET_CENTER)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(-700, -140)
	t.size = Vector2(1400, 100)
	root.add_child(t)
	var r := UI.label(reason, 24, UI.DIM, "PTSerif-Italic.ttf")
	r.set_anchors_preset(Control.PRESET_CENTER)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r.autowrap_mode = TextServer.AUTOWRAP_WORD
	r.position = Vector2(-600, -10)
	r.size = Vector2(1200, 80)
	root.add_child(r)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_CENTER)
	h.position = Vector2(-220, 120)
	h.add_theme_constant_override("separation", 40)
	h.add_child(UI.button("Ещё раз", on_retry, 28))
	h.add_child(UI.button("В меню", on_menu, 28))
	root.add_child(h)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 1.5)
	return root


## Концовка: текст появляется по абзацам.
static func ending(id: String, on_done: Callable) -> Control:
	var root := Control.new()
	root.theme = UI.get_theme()
	UI.full(root)
	root.add_child(UI.dim_bg(1.0))
	var e: Array = Texts.ENDINGS[id]
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-620, -380)
	v.size = Vector2(1240, 760)
	v.add_theme_constant_override("separation", 22)
	root.add_child(v)
	var paras: Array = String(e[1]).split("\n\n")
	var labels := []
	for p in paras:
		var l := UI.label(String(p), 26, Color(0.85, 0.83, 0.79), "PTSerif-Regular.ttf")
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		l.custom_minimum_size = Vector2(1200, 0)
		l.modulate.a = 0.0
		v.add_child(l)
		labels.append(l)
	var title := UI.label("Концовка %d из 4: «%s»" % [["open_tap", "valve", "steam", "last_steam"].find(id) + 1, e[0]], 30, UI.ACCENT, "PTSerif-Regular.ttf")
	title.modulate.a = 0.0
	v.add_child(title)
	var btn := UI.button("Дальше", on_done, 24)
	btn.modulate.a = 0.0
	v.add_child(btn)
	var tw := root.create_tween()
	tw.tween_interval(1.5)
	for l in labels:
		tw.tween_property(l, "modulate:a", 1.0, 2.0)
		tw.tween_interval(String((l as Label).text).length() * 0.035 + 1.0)
	tw.tween_property(title, "modulate:a", 1.0, 1.5)
	tw.tween_property(btn, "modulate:a", 1.0, 1.0)
	return root
