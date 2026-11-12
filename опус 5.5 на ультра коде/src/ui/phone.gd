class_name Phone
extends Control
## Телефон (Tab): сообщения диспетчера, задача и вещи, записки, фото плана с отметкой «вы здесь», беззвучный режим.

signal closed

var tab := "msg"
var content: VBoxContainer
var scroll: ScrollContainer
var clock: Label
var plan_tex: TextureRect
var plan_dot: ColorRect
var tabs_box: HBoxContainer


func _ready() -> void:
	theme = UI.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := UI.dim_bg(0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var body := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.055)
	sb.set_corner_radius_all(28)
	sb.border_color = Color(0.2, 0.2, 0.22)
	sb.set_border_width_all(3)
	body.add_theme_stylebox_override("panel", sb)
	body.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	body.position = Vector2(-560, -380)
	body.size = Vector2(470, 760)
	add_child(body)
	var screen := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0.08, 0.1, 0.12)
	ss.set_corner_radius_all(14)
	screen.add_theme_stylebox_override("panel", ss)
	screen.position = Vector2(18, 40)
	screen.size = Vector2(434, 680)
	body.add_child(screen)
	var v := VBoxContainer.new()
	v.position = Vector2(12, 8)
	v.size = Vector2(410, 664)
	screen.add_child(v)
	var top := HBoxContainer.new()
	clock = UI.label("", 18, UI.DIM)
	top.add_child(clock)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(UI.label("▂▄▆  37%", 16, UI.DIM))
	v.add_child(top)
	tabs_box = HBoxContainer.new()
	v.add_child(tabs_box)
	for t in [["msg", "Сообщения"], ["obj", "Задача"], ["notes", "Записки"], ["plan", "План"], ["set", "Звук"]]:
		var b := UI.button(String(t[1]), func():
			tab = String(t[0])
			refresh(), 17)
		tabs_box.add_child(b)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)
	v.add_child(UI.label("Tab — убрать телефон", 15, UI.DIM))
	refresh()


func refresh() -> void:
	for c in content.get_children():
		c.queue_free()
	var mins := int(Game.play_time / 60.0)
	clock.text = "%02d:%02d" % [(23 + (46 + mins) / 60) % 24, (46 + mins) % 60]
	match tab:
		"msg":
			if Game.messages.is_empty():
				content.add_child(UI.label("Нет сообщений", 18, UI.DIM))
			for id in Game.messages:
				var m: Array = Texts.MESSAGES[id]
				var mine := String(m[0]) == "Я"
				var pc := PanelContainer.new()
				var st := StyleBoxFlat.new()
				st.bg_color = Color(0.2, 0.28, 0.2) if mine else (Color(0.25, 0.08, 0.08) if String(m[0]) == "2-14-03" else Color(0.16, 0.17, 0.2))
				st.set_corner_radius_all(10)
				st.set_content_margin_all(10)
				pc.add_theme_stylebox_override("panel", st)
				var vb := VBoxContainer.new()
				vb.add_child(UI.label("%s   %s" % [m[0], m[1]], 14, UI.DIM))
				var t := UI.label(String(m[2]), 18)
				t.autowrap_mode = TextServer.AUTOWRAP_WORD
				t.custom_minimum_size = Vector2(330, 0)
				vb.add_child(t)
				pc.add_child(vb)
				pc.size_flags_horizontal = Control.SIZE_SHRINK_END if mine else Control.SIZE_SHRINK_BEGIN
				content.add_child(pc)
			await get_tree().process_frame
			scroll.scroll_vertical = 100000
		"obj":
			var o := UI.label("Задача:\n" + (Game.objective if Game.objective != "" else "—"), 19)
			o.autowrap_mode = TextServer.AUTOWRAP_WORD
			o.custom_minimum_size = Vector2(390, 0)
			content.add_child(o)
			content.add_child(UI.label("С собой:", 18, UI.DIM))
			var have := ["Фонарь (батарея %d%%)" % int(Game.player.battery if Game.player else 100)]
			for id in Game.items:
				have.append(Hud._item_name(id))
			for h in have:
				content.add_child(UI.label("• " + h, 18))
		"notes":
			if Game.notes.is_empty():
				content.add_child(UI.label("Ничего не найдено", 18, UI.DIM))
			for id in Game.notes:
				var nid: String = id
				content.add_child(UI.button(String(Texts.note(nid)["title"]), func():
					if Game.main:
						Game.main.show_note(nid), 19))
		"plan":
			if not Game.flag("map"):
				var l := UI.label("Фото нет. План эвакуации висит в вестибюле.", 18, UI.DIM)
				l.autowrap_mode = TextServer.AUTOWRAP_WORD
				l.custom_minimum_size = Vector2(390, 0)
				content.add_child(l)
			else:
				var holder := Control.new()
				holder.custom_minimum_size = Vector2(400, 246)
				content.add_child(holder)
				plan_tex = TextureRect.new()
				plan_tex.texture = load("res://tex/gen/evac_plan.png")
				plan_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				plan_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
				plan_tex.size = Vector2(400, 246)
				holder.add_child(plan_tex)
				plan_dot = ColorRect.new()
				plan_dot.color = Color(1, 0.1, 0.1)
				plan_dot.size = Vector2(8, 8)
				holder.add_child(plan_dot)
				var under := UI.label("", 16, UI.DIM)
				under.autowrap_mode = TextServer.AUTOWRAP_WORD
				under.custom_minimum_size = Vector2(390, 0)
				content.add_child(under)
				if Game.player:
					var p: Vector3 = Game.player.global_position
					var k := 400.0 / 1040.0
					plan_dot.position = Vector2((40 + p.x * 18.5) * k - 4, (70 + p.z * 18.5) * k - 4)
					plan_dot.visible = p.y > -1.5 and p.z > 0.0 and p.z < 30.5
					under.text = "Вы: " + Game.world.room_name(Game.player.current_room) + ("" if plan_dot.visible else "  (этого места на плане нет)")
		"set":
			content.add_child(UI.toggle("Без звука", Game.mute_phone, func(v: bool):
				Game.mute_phone = v
				Game.set_flag("phone_mute", v)))
			var l2 := UI.label("Сигнал сообщения слышно в тишине бани. Она — тоже слышит.", 16, UI.DIM)
			l2.autowrap_mode = TextServer.AUTOWRAP_WORD
			l2.custom_minimum_size = Vector2(390, 0)
			content.add_child(l2)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("phone") or e.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		closed.emit()
