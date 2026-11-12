class_name AdminMenu
extends Control
## Админ-режим (просмотр содержимого): старт с любой точки, свободный обход, музей, концовки.

var free_walk_monster := false
var fullbright := false


func _ready() -> void:
	theme = UI.get_theme()
	UI.full(self)
	add_child(UI.dim_bg(1.0))
	var root := HBoxContainer.new()
	root.position = Vector2(80, 70)
	root.add_theme_constant_override("separation", 80)
	add_child(root)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	root.add_child(left)
	left.add_child(UI.label("Админ-режим", 46, UI.ACCENT, "PTSerif-Regular.ttf"))
	left.add_child(UI.label("Главы и контрольные точки (прогресс игры не меняется)", 18, UI.DIM))
	var m = Game.main
	for id in Texts.CHECKPOINTS:
		var cid: String = id
		left.add_child(UI.button(String(Texts.CHECKPOINTS[cid][0]), func(): m.start_checkpoint(cid, true), 22))
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	root.add_child(right)
	right.add_child(UI.label("Просмотр", 30, UI.ACCENT, "PTSerif-Regular.ttf"))
	right.add_child(UI.toggle("Хозяйка в свободном обходе", false, func(v: bool): free_walk_monster = v))
	right.add_child(UI.toggle("Полный свет", false, func(v: bool): fullbright = v))
	right.add_child(UI.button("Свободный обход всей бани", _free_walk, 26))
	right.add_child(UI.button("Музей: Хозяйка, предметы, записки, звуки", func(): m.open_museum(), 26))
	right.add_child(UI.label("Концовки", 24, UI.DIM))
	for id in Texts.ENDINGS:
		var eid: String = id
		right.add_child(UI.button("«%s»" % Texts.ENDINGS[eid][0], func(): m.show_ending_screen(eid), 22))
	var info := UI.label("В игре: F1 — панель админа (бессмертие, телепорт, вызвать Хозяйку, события…), F2 — полёт.", 18, UI.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(620, 0)
	right.add_child(info)
	right.add_child(UI.button("Назад", func(): m.show_menu(), 26))


func _free_walk() -> void:
	var m = Game.main
	m.start_checkpoint("c12_valve", true)
	Game.flags["free_walk"] = true
	Game.cheats["no_monster"] = not free_walk_monster
	Game.cheats["fullbright"] = fullbright
	Game.cheats["god"] = true
