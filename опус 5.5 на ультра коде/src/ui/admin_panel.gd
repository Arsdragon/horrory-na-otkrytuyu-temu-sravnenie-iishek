class_name AdminPanel
extends Control
## F1 в игре (только админ-режим): читы, Хозяйка, телепорт, события, переходы, концовки.


func _ready() -> void:
	theme = UI.get_theme()
	UI.full(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var p := PanelContainer.new()
	p.position = Vector2(20, 20)
	p.size = Vector2(560, 1000)
	add_child(p)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(530, 960)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	sc.add_child(v)
	v.add_child(UI.label("Админ-панель  (F1 — закрыть)", 26, UI.ACCENT))
	var w: World = Game.world
	var names := {"god": "Бессмертие", "deaf": "Хозяйка глухая", "no_monster": "Без Хозяйки", "fullbright": "Полный свет",
		"ai_debug": "Отладка ИИ (состояние, FPS)", "steam_off": "Убрать пар", "noclip": "Полёт (F2)"}
	for k in names:
		var key: String = k
		v.add_child(UI.toggle(names[key], bool(Game.cheats[key]), func(on: bool):
			Game.cheats[key] = on
			if key == "noclip":
				w.player.set_noclip(on)
			if key == "fullbright":
				w._apply_quality()))
	v.add_child(UI.slider("Скорость времени", 0.25, 3.0, 0.25, Engine.time_scale, func(x: float): Engine.time_scale = x))
	_section(v, "Хозяйка")
	var hoz: Hozyayka = w.monster
	v.add_child(UI.button("Вызвать рядом (из трапа, со стуком)", func(): w.director.spawn_near_player(4.0, 30.0, 2.0), 20))
	v.add_child(UI.button("Поставить в 4 м перед собой", func():
		var p0 := w.player.global_position + w.player.look_dir() * Vector3(1, 0, 1) * 4.0
		var map := w.get_world_3d().navigation_map
		hoz.emerge(NavigationServer3D.map_get_closest_point(map, p0), w.player.global_position, true), 20))
	v.add_child(UI.button("Встать за спину", func():
		hoz.visible = true
		hoz.body.model.position.y = 0.0
		hoz.body.set_clip(-1000.0)
		hoz.set_state(Hozyayka.S.ROAM)
		hoz.behind_cool = 0.0
		hoz.start_behind(), 20))
	v.add_child(UI.button("Бросок на игрока", func():
		if hoz.state != Hozyayka.S.GONE:
			hoz._go(w.player.global_position, Hozyayka.S.RUSH), 20))
	v.add_child(UI.button("Убрать (уйти в трап)", func(): hoz.vanish(), 20))
	_section(v, "Телепорт")
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	for id in w.rooms:
		var rid: String = id
		g.add_child(UI.button(w.room_name(rid), func():
			w.player.global_position = w.room_center(rid) + Vector3(0.5, 0.1, 0.5), 17))
	g.add_child(UI.button("Двор", func(): w.player.global_position = Vector3(26, 0.1, 40), 17))
	_section(v, "Предметы и двери")
	v.add_child(UI.button("Дать все предметы", func():
		for it in ["crowbar", "wrench", "key_util", "key_pump"]:
			Game.give(it, true)
		Game.set_flag("map"), 20))
	v.add_child(UI.button("Открыть все двери", func():
		for id in w.doors:
			(w.doors[id] as Door).locked = false, 20))
	v.add_child(UI.button("Батарейка 100%", func(): w.player.battery = 100.0, 20))
	_section(v, "Пугалки и события")
	var ev := [
		["Звонок мёртвого телефона", _ev_phone], ["Мокрые следы в вестибюле", _ev_steps],
		["Первая встреча в мыльной", _ev_encounter], ["Отражение в зеркале (жен. раздевальня)", _ev_mirror],
		["Затопление вестибюля", _ev_flood], ["Тень под водой бассейна", _ev_pool],
		["Силуэт в проёме", _ev_glimpse], ["Стук в трубах", _ev_knock], ["Крик в трубах", _ev_scream],
		["Воспоминание в бункере", _ev_memory], ["Перегрев котла (75 с)", _ev_overheat],
	]
	for e in ev:
		v.add_child(UI.button(String(e[0]), e[1], 19))
	_section(v, "Концовки (сразу)")
	for id in Texts.ENDINGS:
		var eid: String = id
		v.add_child(UI.button("«%s»" % Texts.ENDINGS[eid][0], func(): Game.main.ending(eid), 19))
	_section(v, "Перейти к точке")
	for id in Texts.CHECKPOINTS:
		var cid: String = id
		v.add_child(UI.button(String(Texts.CHECKPOINTS[cid][0]), func(): Game.main.start_checkpoint(cid, true), 18))


func _section(v: VBoxContainer, t: String) -> void:
	var l := UI.label(t, 22, UI.ACCENT)
	v.add_child(l)


func _sc() -> Scenario:
	return Game.world.scenario


func _ev_phone() -> void:
	Game.set_flag("phone_answered", false)
	Game.set_flag("phone_ringing", false)
	_sc()._ring_phone()


func _ev_steps() -> void:
	_sc()._footprints_scare()


func _ev_encounter() -> void:
	Game.set_flag("first_encounter", false)
	Game.set_flag("trig:enc", false)
	_sc()._prepare_encounter()
	Game.world.player.global_position = Vector3(6.5, 0.05, 19.4)
	Game.world.player.set_look(0.0)
	_sc()._first_encounter()


func _ev_mirror() -> void:
	Game.set_flag("mirror_scare", false)
	Game.world.player.global_position = Vector3(41.9, 0.05, 27.8)
	Game.world.player.set_look(PI)
	await get_tree().create_timer(0.6).timeout
	_sc()._mirror_scare(Game.world.get_meta("mirror_f_lock"))


func _ev_flood() -> void:
	Game.set_flag("lobby_flooded", false)
	_sc()._flood_lobby()


func _ev_pool() -> void:
	Game.world.player.global_position = Vector3(25, 0.05, 16)
	_sc()._pool_shape_scare()


func _ev_glimpse() -> void:
	Game.world.director.glimpse_t = 0.0


func _ev_knock() -> void:
	Snd.play("pipe_knock", 0.0, 1.0, "Amb")


func _ev_scream() -> void:
	Snd.play("hoz_scream", 4.0, 1.0, "Amb")


func _ev_memory() -> void:
	_sc()._memory()


func _ev_overheat() -> void:
	_sc()._start_overheat(false)
