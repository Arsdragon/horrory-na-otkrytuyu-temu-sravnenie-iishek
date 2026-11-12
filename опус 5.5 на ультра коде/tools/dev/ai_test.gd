extends Node
## Проверка ИИ Хозяйки (без окна):  godot --headless --path . -- --aitest
## 1) слышит шаги и доходит до игрока; 2) уходит мыться к открытому крану; 3) не находит тихо спрятавшегося;
## 4) находит того, кто шумно залез в шкафчик; 5) «за спиной» отпускает при переходе в другую комнату.

var fails := 0
var killed := false


func _ready() -> void:
	_run()


func log_(t: String) -> void:
	print("[ИИ] ", t)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	var m = Game.main
	m.start_checkpoint("c07_women", true)
	while Game.world == null or not Game.world.ready_done:
		await get_tree().process_frame
	await wait(0.5)
	var w: World = Game.world
	var pl := w.player
	var hoz: Hozyayka = w.monster
	Game.set_flag("dir_hold")   # режиссёр не мешает
	Game.main.set("dying", false)
	# перехватываем смерть
	hoz.no_kill = true
	var kills := [0]
	hoz.state_changed.connect(func(s: int):
		pass)
	# --- 1. слышит шаги
	log_("1. шаги: игрок в женской мыльной, она выходит из трапа в душевой")
	pl.global_position = Vector3(45.0, 0.05, 15.0)
	hoz.emerge(Vector3(41.0, 0.0, 8.3), Vector3.ZERO, true)
	await wait(1.0)
	hoz.set_state(Hozyayka.S.ROAM)
	var reached := false
	for i in 30:
		w.noise(pl.global_position, 10.0, "step")
		await wait(0.5)
		var d := hoz.global_position.distance_to(pl.global_position)
		if i % 4 == 0:
			log_("   %4.1f с: %s, до игрока %.1f м" % [i * 0.5, hoz.state_name(), d])
		if d < 1.8:
			reached = true
			break
	_check(reached, "дошла до шумящего игрока")
	# --- 2. кран уводит
	log_("2. кран в мужской мыльной уводит её")
	pl.global_position = Vector3(26.0, 0.05, 28.0)
	await wait(0.3)
	hoz.set_state(Hozyayka.S.ROAM)
	hoz.behind_cool = 99.0
	var tap: Tap = null
	for t in w.taps:
		if t.line == "m_wash":
			tap = t
			break
	tap.set_running(true)
	var washing := false
	for i in 80:
		await wait(0.5)
		if i % 8 == 0:
			log_("   %4.1f с: %s, до крана %.1f м" % [i * 0.5, hoz.state_name(), hoz.global_position.distance_to(tap.global_position)])
		if hoz.state == Hozyayka.S.WASH:
			washing = true
			break
	_check(washing, "пошла мыться к открытому крану")
	tap.set_running(false)
	# --- 3. тихо спрятался
	log_("3. игрок тихо в шкафчике, она ищет рядом")
	var locker: HideSpot = null
	for h in w.hides:
		if (h as HideSpot).kind == "locker" and w.room_at((h as Node3D).global_position) == "f_lock":
			locker = h
			break
	pl.hide_in(locker, locker.global_position + Vector3(0, 0.05, 0), 0.0)
	locker.inside = true
	hoz.heard_hide = null
	hoz.global_position = locker.global_position + Vector3(2.0, 0, -1.5)
	hoz._start_search(locker.global_position + Vector3(1.0, 0, -1.0), 6.0)
	hoz.heard_hide = null
	await wait(7.0)
	_check(pl.hidden_in == locker, "тихо спрятавшегося не нашла")
	# --- 4. шумно залез
	log_("4. шумно залез в шкафчик — она вскрывает")
	hoz.global_position = locker.global_position + Vector3(4.0, 0, -2.0)
	hoz.set_state(Hozyayka.S.ROAM)
	w.noise(locker.global_position, 8.0, "hide")
	var opened := false
	hoz.no_kill = true
	for i in 30:
		await wait(0.5)
		if pl.hidden_in == null:
			opened = true
			break
	_check(opened, "вскрыла шкафчик, где слышала игрока")
	if pl.hidden_in:
		pl.unhide(locker.global_position + Vector3(0, 0, -1))
	# --- 5. «за спиной»
	log_("5. «за спиной»: переход в другую комнату отпускает")
	pl.global_position = Vector3(45.0, 0.05, 19.0)
	pl.set_look(PI)
	await wait(0.3)
	hoz.visible = true
	hoz.set_state(Hozyayka.S.ROAM)
	hoz.behind_cool = 0.0
	hoz.start_behind()
	await wait(0.5)
	var behind_ok := hoz.state == Hozyayka.S.BEHIND and pl.grabbed
	pl.global_position = Vector3(45.5, 0.05, 21.0)
	await wait(1.0)
	_check(behind_ok and not pl.grabbed and hoz.state == Hozyayka.S.GONE, "отпустила за порогом")
	# --- 6. достижимость всех помещений по навигации (от вестибюля)
	log_("6. все помещения достижимы")
	var map := w.get_world_3d().navigation_map
	var from := w.room_center("lobby")
	var bad := []
	for id in w.rooms:
		var c := w.room_center(id)
		if id == "pool":
			c = Vector3(16.0, 0.05, 15.5)
		var cp := NavigationServer3D.map_get_closest_point(map, c)
		var pth := NavigationServer3D.map_get_path(map, from, cp, true)
		if pth.size() < 2 or pth[pth.size() - 1].distance_to(cp) > 0.6 or Vector2(cp.x, cp.z).distance_to(Vector2(c.x, c.z)) > 3.5:
			bad.append(id)
	_check(bad.is_empty(), "достижимы все (недостижимы: %s)" % str(bad))
	# --- 7. пешком: капсула игрока проходит через все двери, лестницу и мостки
	log_("7. пешком по всей бане")
	hoz.vanish()
	Game.cheats["no_monster"] = true
	for id in w.doors:
		var d: Door = w.doors[id]
		d.locked = false
		d.set_open(1.0, true)
		for l in d.leaves:
			(l["body"] as CollisionObject3D).collision_layer = 0
	if Game.world.scenario.pool_barrier:
		Game.world.scenario.pool_barrier.collision_layer = 0
	var route := [
		Vector3(26, 0.05, 40), Vector3(26, 0.05, 27), Vector3(10, 0.05, 26.5), Vector3(2, 0.05, 23), Vector3(2, 0.05, 28.5),
		Vector3(9, 0.05, 23), Vector3(6.5, 0.05, 18), Vector3(4, 0.05, 6), Vector3(6.5, 0.05, 12), Vector3(11, 0.05, 6),
		Vector3(11, 0.05, 1.5), Vector3(19, 0.05, 1.5), Vector3(19.5, 0.05, 21.5), Vector3(24.5, 0.05, 18.5), Vector3(34, 0.05, 18.5),
		Vector3(28.3, 0.05, 19.0), Vector3(19, 0.05, 18.8), Vector3(26, 0.05, 27), Vector3(43, 0.05, 26), Vector3(50, 0.05, 27),
		Vector3(50, 0.05, 22), Vector3(45, 0.05, 15), Vector3(48, 0.05, 6), Vector3(41, 0.05, 6), Vector3(41, 0.05, 1.5),
		Vector3(34, 0.05, 1.5), Vector3(34, 0.05, 4.5), Vector3(34, 0.05, 8), Vector3(16, 0.05, 15.5), Vector3(25.25, 0.05, 1.0),
		Vector3(25.25, -4.3, -9.5), Vector3(13, -4.3, -11), Vector3(13, -4.3, -15.5), Vector3(31, -4.3, -12), Vector3(35, -4.3, -13),
		Vector3(31, -4.3, -8.2), Vector3(35, -4.3, -8.5, ), Vector3(31, -4.3, -8.2), Vector3(31, -4.4, 5),
	]
	pl.global_position = route[0]
	await wait(0.5)
	var stuck_at := []
	for i in range(1, route.size()):
		var tgt: Vector3 = route[i]
		var pth := NavigationServer3D.map_get_path(map, pl.global_position, tgt, true)
		var ok := true
		for k in range(1, pth.size()):
			var wp: Vector3 = pth[k]
			var t := 0.0
			var best := 999.0
			var since := 0.0
			while Vector2(pl.global_position.x - wp.x, pl.global_position.z - wp.z).length() > 0.35:
				var dv := wp - pl.global_position
				dv.y = 0
				var low := w.room_at(pl.global_position + Vector3.UP) == "banya" or Vector2(pl.global_position.x - 32.0, pl.global_position.z + 8.0).length() < 1.3
				pl.auto_move = dv.normalized() * (1.0 if not low else 1.0)
				pl.auto_move.y = -1.0 if low else 0.0
				# как живой игрок: закрытую дверь рядом — открыть от себя; упёрся — шаг вбок
				for d2 in w.doors.values():
					var dr: Door = d2
					if dr.target < 0.5 and dr.center().distance_to(pl.global_position + Vector3.UP) < 1.6:
						dr.use(pl)
				if since > 1.0:
					var side := Vector3(-dv.z, 0, dv.x).normalized() * (1.0 if int(t * 2.0) % 2 == 0 else -1.0)
					pl.auto_move = (dv.normalized() * 0.3 + side).normalized()
					pl.auto_move.y = -1.0 if low else 0.0
				await get_tree().physics_frame
				var dd := Vector2(dv.x, dv.z).length()
				t += get_physics_process_delta_time()
				if dd < best - 0.05:
					best = dd
					since = 0.0
				else:
					since += get_physics_process_delta_time()
				if since > 4.0:
					ok = false
					break
			if not ok:
				break
		pl.auto_move = Vector3.ZERO
		if not ok:
			stuck_at.append("%d→%s застрял у %s (%s)" % [i, str(tgt), str(pl.global_position.snapped(Vector3(0.1, 0.1, 0.1))), w.room_name(pl.current_room)])
			pl.global_position = tgt
			await wait(0.3)
	for st in stuck_at:
		log_("   " + st)
	_check(stuck_at.is_empty(), "капсула игрока прошла весь маршрут")
	log_("ИТОГ: ошибок %d" % fails)
	get_tree().quit(fails)


func _check(c: bool, t: String) -> void:
	if c:
		log_("  ок: " + t)
	else:
		fails += 1
		log_("  ОШИБКА: " + t)
