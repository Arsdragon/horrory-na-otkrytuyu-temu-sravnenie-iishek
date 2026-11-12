class_name PropsGround
## Обстановка первого этажа. Сюжетные предметы (ключи, телефон, записки-находки) ставит Scenario.


static func build(w: World) -> void:
	lobby(w)
	admin(w)
	men(w)
	pool(w)
	service(w)
	women(w)


static func _n(w: World, id: String) -> Node3D:
	return w.rooms[id]["node"]


static func _b(w: World, id: String) -> StaticBody3D:
	return w.rooms[id]["body"]


# ---------------------------------------------------------------- вестибюль

static func lobby(w: World) -> void:
	var n := _n(w, "lobby")
	var body := _b(w, "lobby")
	var b := Geo.Batch.new()
	var wood := Mat.m("planks_weather", {"tint": Color(0.7, 0.55, 0.4)})
	var glass := Mat.flat(Color(0.25, 0.3, 0.28, 0.35), 0.1)
	# касса: будка в северо-западном углу
	b.box(wood, Vector3(16.6, 0.55, 25.55), Vector3(3.2, 1.1, 0.08))
	b.box(glass, Vector3(16.6, 1.65, 25.55), Vector3(3.2, 1.1, 0.02))
	b.box(wood, Vector3(16.6, 2.4, 25.55), Vector3(3.2, 0.4, 0.08))
	b.box(wood, Vector3(18.15, 1.3, 25.0), Vector3(0.08, 2.6, 1.1))
	b.box(wood, Vector3(18.15, 2.4, 23.9), Vector3(0.08, 0.4, 1.1))
	b.box(wood, Vector3(16.6, 2.63, 24.4), Vector3(3.2, 0.06, 2.4))
	b.box(wood, Vector3(16.6, 0.85, 25.2), Vector3(3.0, 0.05, 0.6))
	b.box(wood, Vector3(16.6, 0.42, 25.42), Vector3(3.0, 0.84, 0.05))
	Geo.col_box(body, Vector3(16.6, 1.3, 25.55), Vector3(3.2, 2.6, 0.1))
	Geo.col_box(body, Vector3(18.15, 1.3, 25.0), Vector3(0.1, 2.6, 1.1))
	Geo.col_box(body, Vector3(16.6, 0.45, 25.2), Vector3(3.0, 0.9, 0.6))
	Props.picture(n, "res://tex/gen/sign_kassa.png", Vector3(16.6, 2.4, 25.6), Vector3(0, 0, 1), Vector2(0.9, 0.28))
	Props.picture(n, "res://tex/gen/prices.png", Vector3(18.2, 1.6, 24.4), Vector3(1, 0, 0), Vector2(0.5, 0.62))
	Props.model(n, "CashRegister_01", Vector3(17.5, 0.875, 25.15), PI)
	Props.model(n, "painted_wooden_chair_01", Vector3(16.6, 0.0, 24.3), 0.0)
	var lamp := Props.model(n, "vintage_oil_lamp", Vector3(15.6, 0.875, 25.15), 0.3)
	var fire := Items.Fire.new()
	fire.base = 1.1
	fire.omni_range = 7.0
	fire.light_color = Color(1.0, 0.68, 0.35)
	n.add_child(fire)
	fire.global_position = Vector3(15.6, 1.15, 25.0)
	w.set_meta("lobby_lamp", fire)
	# гардероб: стойка и вешалки у южной стены справа
	b.box(wood, Vector3(35.0, 0.55, 28.2), Vector3(3.2, 1.1, 0.5))
	Geo.col_box(body, Vector3(35.0, 0.55, 28.2), Vector3(3.2, 1.1, 0.5))
	var rail := Mat.flat(Color(0.35, 0.33, 0.3), 0.4, 0.8)
	b.cyl(rail, Vector3(33.5, 1.75, 29.4), Vector3(36.6, 1.75, 29.4), 0.02)
	for i in 9:
		var x := 33.7 + i * 0.34
		b.box(rail, Vector3(x, 1.68, 29.4), Vector3(0.01, 0.14, 0.01))
		if i in [1, 4, 5, 7]:
			var coat := Mat.m("cloth", {"tint": Color(0.25 + randf() * 0.1, 0.22, 0.2), "scale": 0.6})
			b.box(coat, Vector3(x, 1.1, 29.4), Vector3(0.38, 1.1, 0.16), Basis(Vector3.UP, randf_range(-0.2, 0.2)))
	Props.picture(n, "res://tex/gen/sign_garderob.png", Vector3(35.0, 2.6, 29.88), Vector3(0, 0, -1), Vector2(0.9, 0.25))
	# скамьи
	Props.model(n, "painted_wooden_bench", Vector3(25.5, 0, 23.5), PI, 1.0, true)
	Props.model(n, "painted_wooden_bench", Vector3(21.0, 0, 29.4), 0.0, 1.0, true)
	Props.model(n, "painted_wooden_bench", Vector3(30.5, 0, 29.4), 0.0, 1.0, true)
	# доска почёта
	var board := Mat.m("planks_dark", {"tint": Color(0.55, 0.2, 0.15)})
	b.box(board, Vector3(25.5, 1.95, 23.16), Vector3(2.6, 1.3, 0.06))
	Props.picture(n, "res://tex/gen/sign_bani.png", Vector3(25.5, 2.48, 23.2), Vector3(0, 0, 1), Vector2(1.2, 0.2), {"tint": Color(1.2, 1.0, 0.7)})
	var photos := ["honor_1", "honor_father", "honor_0", "honor_2"]
	for i in 4:
		Props.picture(n, "res://tex/gen/%s.png" % photos[i], Vector3(24.45 + i * 0.7, 1.8, 23.2), Vector3(0, 0, 1), Vector2(0.46, 0.6))
	# план эвакуации
	Props.picture(n, "res://tex/gen/evac_plan.png", Vector3(29.6, 1.6, 23.14), Vector3(0, 0, 1), Vector2(1.04, 0.64))
	# таблички над дверями отделений
	Props.picture(n, "res://tex/gen/sign_male.png", Vector3(14.14, 2.65, 26.5), Vector3(1, 0, 0), Vector2(0.9, 0.45))
	Props.picture(n, "res://tex/gen/sign_female.png", Vector3(37.86, 2.65, 26.5), Vector3(-1, 0, 0), Vector2(0.9, 0.45))
	Props.picture(n, "res://tex/gen/sign_rules_short.png", Vector3(37.86, 1.6, 24.4), Vector3(-1, 0, 0), Vector2(0.6, 0.3))
	Props.picture(n, "res://tex/gen/sign_water_save.png", Vector3(26.0, 2.3, 29.86), Vector3(0, 0, -1), Vector2(0.6, 0.35))
	# часы стоят на 23:40
	Props.model(n, "wall_clock", Vector3(21.5, 2.9, 23.16), PI, 1.0)
	# соль на порогах
	Props.salt(b, Vector3(14.35, 0, 26.5), false, 1.3)
	Props.salt(b, Vector3(37.65, 0, 26.5), false, 1.3)
	Props.salt(b, Vector3(20.0, 0, 23.3), true, 1.1)
	# мусор: опрокинутый стул, коробки
	Props.model(n, "cardboard_box_01", Vector3(36.8, 0, 24.0), 0.4)
	Props.model(n, "painted_wooden_chair_02", Vector3(29.0, 0, 26.0), 1.9)
	b.commit(n, "props")


# ---------------------------------------------------------------- коридор персонала и комнаты

static func admin(w: World) -> void:
	var n := _n(w, "admin")
	var b := Geo.Batch.new()
	Props.model(n, "painted_wooden_bench", Vector3(30.0, 0, 22.6), 0.0, 1.0, true)
	Props.picture(n, "res://tex/gen/sign_water_save.png", Vector3(23.0, 1.7, 22.86), Vector3(0, 0, -1), Vector2(0.55, 0.32))
	Props.picture(n, "res://tex/gen/sign_bufet.png", Vector3(34.0, 2.35, 20.14), Vector3(0, 0, 1), Vector2(0.6, 0.17))
	# огнетушитель
	var red := Mat.flat(Color(0.55, 0.06, 0.04), 0.5, 0.3)
	b.cyl(red, Vector3(16.6, 0.0, 22.6), Vector3(16.6, 0.6, 22.6), 0.09, 12, true)
	b.commit(n, "props")

	# кабинет заведующей
	var o := _n(w, "office")
	var ob := _b(w, "office")
	var ob2 := Geo.Batch.new()
	Props.model(o, "metal_office_desk", Vector3(19.0, 0, 17.75), PI, 1.0, true)
	Props.model(o, "painted_wooden_chair_02", Vector3(19.0, 0, 17.2), PI)
	Props.model(o, "painted_wooden_cabinet", Vector3(21.4, 0, 18.4), -PI * 0.5, 1.0, true)
	Props.model(o, "desk_lamp_arm_01", Vector3(19.7, 0.76, 17.6), 2.4)
	Props.picture(o, "res://tex/gen/calendar.png", Vector3(21.86, 1.6, 19.3), Vector3(-1, 0, 0), Vector2(0.32, 0.45))
	# ключница на западной стене
	var kb := Mat.m("planks_dark", {"tint": Color(0.6, 0.45, 0.3)})
	ob2.box(kb, Vector3(16.15, 1.55, 18.6), Vector3(0.04, 0.5, 0.7))
	var hook := Mat.flat(Color(0.5, 0.45, 0.3), 0.4, 0.9)
	for r in 2:
		for c in 4:
			var hp := Vector3(16.19, 1.7 - r * 0.25, 18.35 + c * 0.17)
			ob2.box(hook, hp, Vector3(0.03, 0.01, 0.01))
			if not (r == 0 and c == 1) and not (r == 1 and c == 3):
				ob2.box(hook, hp + Vector3(0.02, -0.06, 0), Vector3(0.004, 0.07, 0.025))
				ob2.box(Mat.flat(Color(0.75, 0.7, 0.55), 0.8), hp + Vector3(0.02, -0.12, 0), Vector3(0.005, 0.04, 0.03))
	# сейф
	ob2.box(Mat.flat(Color(0.2, 0.25, 0.22), 0.5, 0.6), Vector3(16.5, 0.4, 19.6), Vector3(0.5, 0.8, 0.5))
	Geo.col_box(ob, Vector3(16.5, 0.4, 19.6), Vector3(0.5, 0.8, 0.5))
	ob2.commit(o, "props")

	# бельевая
	var l := _n(w, "linen")
	var lb := Geo.Batch.new()
	Props.shelves(lb, _b(w, "linen"), Vector3(23.4, 0, 17.45), 1.6, 0.5, 1.9, 4, true)
	Props.shelves(lb, _b(w, "linen"), Vector3(25.6, 0, 17.45), 1.6, 0.5, 1.9, 4, true)
	var towel := Mat.m("terry", {"tint": Color(0.85, 0.82, 0.75)})
	for sx in [23.4, 25.6]:
		for lvl in [0.45, 0.95, 1.45]:
			for k in 3:
				lb.box(towel, Vector3(sx - 0.35 + k * 0.35, lvl + 0.08, 17.45), Vector3(0.3, 0.14, 0.35))
	var cart := Mat.flat(Color(0.4, 0.42, 0.4), 0.5, 0.7)
	lb.box(cart, Vector3(25.8, 0.55, 19.2), Vector3(0.9, 0.5, 0.55))
	lb.box(Mat.m("cloth", {"tint": Color(0.75, 0.72, 0.65)}), Vector3(25.8, 0.85, 19.2), Vector3(0.85, 0.2, 0.5))
	lb.commit(l, "props")

	# парикмахерская
	var p := _n(w, "barber")
	var pb := Geo.Batch.new()
	Props.model(p, "BarberShopChair_01", Vector3(31.0, 0, 18.1), 0.0, 1.0, true)
	var dark_glass := Mat.flat(Color(0.06, 0.07, 0.07), 0.05, 0.9)
	pb.box(dark_glass, Vector3(31.0, 1.55, 17.15), Vector3(1.2, 0.9, 0.02))
	pb.box(Mat.m("tile_wall"), Vector3(31.0, 0.8, 17.3), Vector3(1.6, 0.06, 0.3))
	pb.commit(p, "props")
	# срезанные волосы на полу — слишком много и слишком длинные
	for i in 6:
		Props.hair_clump(p, Vector3(30.6 + randf_range(-0.8, 0.8), 0.0, 18.6 + randf_range(-0.5, 0.8)), randf_range(0.4, 0.9), false)

	# буфет
	var f := _n(w, "buffet")
	var fb := Geo.Batch.new()
	var wood := Mat.m("planks_weather", {"tint": Color(0.65, 0.5, 0.38)})
	fb.box(wood, Vector3(34.0, 0.5, 17.5), Vector3(3.6, 1.0, 0.6))
	Geo.col_box(_b(w, "buffet"), Vector3(34.0, 0.5, 17.5), Vector3(3.6, 1.0, 0.6))
	fb.commit(f, "props")
	Props.model(f, "tea_set_01", Vector3(33.3, 1.0, 17.5), 0.3)
	Props.model(f, "vintage_electric_kettle", Vector3(34.8, 1.0, 17.45), 2.0)
	Props.model(f, "WoodenTable_01", Vector3(35.15, 0, 18.85), PI * 0.5, 1.0, true)
	Props.model(f, "painted_wooden_chair_01", Vector3(34.5, 0, 19.0), -PI * 0.5)


# ---------------------------------------------------------------- мужское отделение

static func men(w: World) -> void:
	_locker_room(w, "m_lock", false)
	_wash(w, "m_wash", false)
	_steam(w, "m_steam", false)
	_showers(w, "m_shower", false)
	# ожидальня
	var n := _n(w, "m_wait")
	Props.model(n, "painted_wooden_chair_01", Vector3(0.5, 0, 21.0), -PI * 0.5)
	Props.model(n, "painted_wooden_chair_01", Vector3(0.5, 0, 21.8), -PI * 0.5)
	Props.model(n, "painted_wooden_chair_02", Vector3(0.5, 0, 24.9), -PI * 0.5)
	Props.model(n, "metal_trash_can", Vector3(3.5, 0, 25.6), 0.0)
	Props.picture(n, "res://tex/gen/sign_wash_feet.png", Vector3(3.86, 1.7, 21.0), Vector3(-1, 0, 0), Vector2(0.6, 0.3))
	# подсобка
	var u := _n(w, "m_util")
	var ub := _b(w, "m_util")
	var shb := Geo.Batch.new()
	Props.shelves(shb, ub, Vector3(0.45, 0, 28.6), 1.5, 0.5, 1.9, 4, false)
	shb.commit(u, "shelves")
	Props.model(u, "wooden_bucket_01", Vector3(3.2, 0, 29.4), 0.0)
	Props.model(u, "wooden_broom", Vector3(3.7, 0, 27.0), 0.5)
	Props.model(u, "metal_jug", Vector3(0.45, 0.95, 28.2), 0.0)
	Props.model(u, "cleaner_tin_01", Vector3(0.45, 0.45, 28.9), 0.0)
	var ubb := Geo.Batch.new()
	# стол под ящик с инструментом
	ubb.box(Mat.m("planks_weather", {"tint": Color(0.6, 0.5, 0.4)}), Vector3(2.2, 0.8, 29.6), Vector3(1.4, 0.05, 0.5))
	ubb.box(Mat.flat(Color(0.2, 0.2, 0.2), 0.6, 0.7), Vector3(2.2, 0.4, 29.6), Vector3(1.3, 0.8, 0.45))
	Geo.col_box(ub, Vector3(2.2, 0.42, 29.6), Vector3(1.4, 0.84, 0.5))
	# гребёнка на западной стене
	var rust := Mat.m("rust", {"metal": 0.5})
	Props.pipe(ubb, [Vector3(0.2, 0.0, 27.0), Vector3(0.2, 1.3, 27.0), Vector3(0.2, 1.3, 28.6), Vector3(0.2, 3.0, 28.6)], 0.045, rust)
	Props.pipe(ubb, [Vector3(0.2, 1.3, 27.6), Vector3(0.2, 2.9, 27.6)], 0.03, rust)
	Props.pipe(ubb, [Vector3(0.2, 1.3, 28.1), Vector3(0.2, 2.9, 28.1)], 0.03, rust)
	ubb.commit(u, "props")


static func _locker_room(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var x0 := r.position.x
	var x1 := r.end.x
	var b := Geo.Batch.new()
	var tint := Color(0.85, 0.75, 0.78) if female else Color(0.75, 0.82, 0.78)
	# шкафчики вдоль южной стены (оставляем место для раковин и окна)
	Props.lockers(b, body, Vector3(x0 + 0.3, 0, 29.6), 6, Vector3(1, 0, 0), Vector3(0, 0, -1), tint)
	Props.lockers(b, body, Vector3(x1 - 0.3 - 0.45 * 4, 0, 29.6), 4, Vector3(1, 0, 0), Vector3(0, 0, -1), tint)
	# ряды скамей со спинками
	var wood := Mat.m("planks_weather", {"tint": Color(0.8, 0.68, 0.5), "scale": 1.2})
	Props.bench(b, body, Vector3((x0 + x1) * 0.5, 0, 23.4), 6.5, true, true, wood)
	Props.bench(b, body, Vector3((x0 + x1) * 0.5 - (0.6 if not female else -0.6), 0, 26.6), 5.0, true, true, wood)
	# крючки и полотенца на спинках
	var hook := Mat.flat(Color(0.4, 0.38, 0.33), 0.5, 0.8)
	for i in 10:
		var x := (x0 + x1) * 0.5 - 3.0 + i * 0.65
		b.box(hook, Vector3(x, 1.35, 23.62), Vector3(0.02, 0.02, 0.08))
		if randf() < 0.35:
			b.box(Mat.m("terry", {"tint": Color(0.8, 0.75 + randf() * 0.1, 0.7)}), Vector3(x, 1.0, 23.66), Vector3(0.3, 0.7, 0.03))
	# служебные шкафчики-укрытия
	var hx := x1 - 0.5 if not female else x0 + 0.5
	w.hides.append(HideSpot.make_locker(n, Vector3(hx, 0, 21.1), PI * 0.5 if not female else -PI * 0.5))
	w.hides.append(HideSpot.make_locker(n, Vector3((x0 + x1) * 0.5 + 1.8, 0, 29.55), 0.0))
	# раковины и зеркала у южной стены (между шкафчиками)
	var sink_x := [x0 + 3.4, x0 + 4.4] if not female else [x0 + 3.4, x0 + 4.4]
	var tile := Mat.m("tile_wall")
	for sx in sink_x:
		b.box(Mat.flat(Color(0.82, 0.82, 0.78), 0.25), Vector3(sx, 0.82, 29.62), Vector3(0.5, 0.12, 0.4))
		b.box(tile, Vector3(sx, 0.4, 29.75), Vector3(0.12, 0.8, 0.1))
		var t := Props.wall_tap(w, id, Vector3(sx, 1.02, 29.86), Vector3(0, 0, -1), id)
		w.taps.append(t)
	var mirror := Mirror.make(n, Vector3((sink_x[0] + sink_x[1]) * 0.5, 1.6, 29.87), PI, Vector2(1.3, 0.8), id,
		"res://tex/gen/mirror_code.png" if not female else "res://tex/gen/mirror_word.png")
	w.set_meta("mirror_" + id, mirror)
	# весы, телевизор
	b.box(Mat.flat(Color(0.75, 0.75, 0.72), 0.3, 0.6), Vector3(x0 + 0.6, 0.05, 20.6), Vector3(0.45, 0.1, 0.45))
	b.box(Mat.flat(Color(0.75, 0.75, 0.72), 0.3, 0.6), Vector3(x0 + 0.6, 0.8, 20.3), Vector3(0.06, 1.5, 0.06))
	b.box(Mat.flat(Color(0.75, 0.75, 0.72), 0.3, 0.6), Vector3(x0 + 0.6, 1.55, 20.38), Vector3(0.3, 0.25, 0.08))
	Props.model(n, "Television_01", Vector3(x1 - 0.4 if not female else x0 + 0.4, 2.35, 22.0), -PI * 0.5 if not female else PI * 0.5, 0.9)
	b.box(hook, Vector3(x1 - 0.2 if not female else x0 + 0.2, 2.3, 22.0), Vector3(0.3, 0.04, 0.3))
	Props.picture(n, "res://tex/gen/sign_rules_short.png", Vector3(x0 + 0.14, 1.9, 27.5), Vector3(1, 0, 0), Vector2(0.6, 0.3))
	if female:
		# валенки Сомовой под скамьёй
		var felt := Mat.m("cloth", {"tint": Color(0.3, 0.28, 0.26)})
		b.box(felt, Vector3(42.0, 0.15, 26.85), Vector3(0.1, 0.3, 0.12))
		b.box(felt, Vector3(42.2, 0.15, 26.8), Vector3(0.1, 0.3, 0.12))
	b.commit(n, "props")


static func _wash(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var x0 := r.position.x
	var x1 := r.end.x
	var b := Geo.Batch.new()
	for k in 3:
		var bx := x0 + 3.5 + k * 3.5
		Props.stone_bench(b, body, Vector3(bx, 0, 14.8), 6.6, false)
	# краны вдоль обеих длинных стен
	var line := id
	for wall in [x0 + 0.13, x1 - 0.13]:
		var nrm := Vector3(1, 0, 0) if wall < (x0 + x1) * 0.5 else Vector3(-1, 0, 0)
		var ledge := Mat.m("tile_dark", {"wet": 0.7})
		b.box(ledge, Vector3(wall + nrm.x * 0.15, 0.72, 14.8), Vector3(0.3, 0.06, 8.6))
		for i in 6:
			var z := 11.0 + i * 1.5
			if absf(z - 13.0) < 1.0 and ((not female and wall > (x0 + x1) * 0.5) or (female and wall < (x0 + x1) * 0.5)):
				continue
			var t := Props.wall_tap(w, id, Vector3(wall, 1.0, z), nrm, line)
			w.taps.append(t)
	# шайки
	for i in 5:
		var basin := Items.Basin.new()
		n.add_child(basin)
		basin.global_position = Vector3(x0 + 3.5 + (i % 3) * 3.5, 0.6, 12.0 + i * 1.3)
	# трапы
	Props.drain(w, b, Vector3(x0 + 2.0, 0, 10.0), id)
	Props.drain(w, b, Vector3(x1 - 2.0, 0, 10.0), id)
	Props.drain(w, b, Vector3((x0 + x1) * 0.5, 0, 19.0), id)
	Props.picture(n, "res://tex/gen/sign_wet.png", Vector3((x0 + x1) * 0.5, 1.8, 19.86), Vector3(0, 0, -1), Vector2(0.55, 0.28))
	if female:
		# детская ванночка и ком волос у трапа
		b.box(Mat.flat(Color(0.75, 0.75, 0.7), 0.3, 0.6), Vector3(x1 - 2.0, 0.55, 18.5), Vector3(0.8, 0.12, 0.45))
		Props.hair_clump(n, Vector3(x1 - 2.0, 0.0, 10.4), 0.6, false)
		Props.hair_clump(n, Vector3(x1 - 2.3, 0.0, 10.2), 0.4, false)
	b.commit(n, "props")


static func _steam(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var b := Geo.Batch.new()
	var wood := Mat.m("planks_dark", {"tint": Color(0.9, 0.75, 0.55)})
	# полки ступенями вдоль боковой стены
	var wall_x := r.position.x if not female else r.end.x
	var s := 1.0 if not female else -1.0
	var tiers := [[0.45, 2.0], [0.9, 1.35], [1.35, 0.75]]
	for t in tiers:
		var depth: float = t[1]
		var cx := wall_x + s * (0.12 + depth * 0.5)
		b.box(wood, Vector3(cx, t[0], 6.0), Vector3(depth, 0.06, 5.2))
		b.box(wood, Vector3(wall_x + s * (0.12 + depth), t[0] * 0.5, 6.0), Vector3(0.05, t[0], 5.2))
		Geo.col_box(body, Vector3(cx, t[0] * 0.5, 6.0), Vector3(depth, t[0], 5.2))
	# каменка у северной стены
	var stove_x := r.position.x + 4.6 if not female else r.end.x - 4.6
	var brick := Mat.m("brick_red", {"tint": Color(0.6, 0.45, 0.4), "scale": 1.0})
	b.box(brick, Vector3(stove_x, 0.55, 3.62), Vector3(1.3, 1.1, 0.9))
	Geo.col_box(body, Vector3(stove_x, 0.55, 3.62), Vector3(1.3, 1.1, 0.9))
	var stone := Mat.flat(Color(0.25, 0.2, 0.18), 0.7)
	var hot := Mat.flat(Color(0.4, 0.12, 0.05), 0.6, 0.0, {"emission": Color(1.0, 0.3, 0.08), "emission_energy": 1.2})
	for i in 14:
		var p := Vector3(stove_x + randf_range(-0.5, 0.5), 1.15 + randf() * 0.15, 3.62 + randf_range(-0.35, 0.35))
		b.box(hot if randf() < 0.3 else stone, p, Vector3.ONE * randf_range(0.12, 0.22), Basis.from_euler(Vector3(randf(), randf(), randf())))
	var glow := Items.Fire.new()
	glow.base = 1.3
	glow.omni_range = 5.0
	glow.light_color = Color(1.0, 0.35, 0.1)
	n.add_child(glow)
	glow.global_position = Vector3(stove_x, 1.5, 3.9)
	# веники, ведро
	Props.model(n, "wooden_bucket_02", Vector3(stove_x + 1.0, 0, 4.4), 0.0)
	for i in 3:
		b.box(Mat.m("planks_weather", {"tint": Color(0.4, 0.45, 0.25)}), Vector3(r.end.x - 0.2 if not female else r.position.x + 0.2, 1.7, 5.0 + i * 0.5), Vector3(0.12, 0.6, 0.25))
	Props.drain(w, b, Vector3((r.position.x + r.end.x) * 0.5 + s * 1.5, 0, 7.6), id)
	b.commit(n, "props")
	# укрытие под нижним полком
	var hs := HideSpot.make_bench(n, Vector3(wall_x + s * 0.9, 0, 7.0), PI * 0.5 if not female else -PI * 0.5)
	w.hides.append(hs)
	w.add_steam(id, 0.35)


static func _showers(w: World, id: String, female: bool) -> void:
	var n := _n(w, id)
	var body := _b(w, id)
	var r: Rect2 = w.rooms[id]["rect"]
	var b := Geo.Batch.new()
	var tile := Mat.m("tile_wall", {"wet": 0.5})
	for side in [0, 1]:
		var wx := r.position.x + 0.13 if side == 0 else r.end.x - 0.13
		var nrm := Vector3(1, 0, 0) if side == 0 else Vector3(-1, 0, 0)
		for i in 3:
			var z := 4.0 + i * 1.5
			var t := Props.shower(w, id, Vector3(wx, 1.25, z), nrm, id)
			w.taps.append(t)
			# перегородки
			var pz := z + 0.75
			if i < 2:
				b.box(tile, Vector3(wx + nrm.x * 0.6, 0.95, pz), Vector3(1.2, 1.9, 0.08))
				Geo.col_box(body, Vector3(wx + nrm.x * 0.6, 0.95, pz), Vector3(1.2, 1.9, 0.08))
	Props.drain(w, b, Vector3(r.get_center().x - 1.6, 0, 8.3), id)
	Props.drain(w, b, Vector3(r.get_center().x + 1.6, 0, 4.0), id)
	b.commit(n, "props")


# ---------------------------------------------------------------- бассейн

static func pool(w: World) -> void:
	var n := _n(w, "pool")
	var body := _b(w, "pool")
	var b := Geo.Batch.new()
	Props.picture(n, "res://tex/gen/mosaic.png", Vector3(26.0, 3.0, 6.12), Vector3(0, 0, 1), Vector2(8.0, 4.0), {"rough": 0.4})
	Props.bench(b, body, Vector3(20.0, 0, 16.5), 5.0, true, false)
	Props.bench(b, body, Vector3(32.0, 0, 16.5), 5.0, true, false)
	# вышка спасателя
	var wood := Mat.m("planks_weather", {"tint": Color(0.75, 0.7, 0.6)})
	for dx in [-0.35, 0.35]:
		for dz in [-0.3, 0.3]:
			b.box(wood, Vector3(35.5 + dx, 0.9, 15.2 + dz), Vector3(0.06, 1.8, 0.06))
	b.box(wood, Vector3(35.5, 1.8, 15.2), Vector3(0.8, 0.06, 0.7))
	b.box(wood, Vector3(35.5, 2.2, 15.5), Vector3(0.8, 0.8, 0.05))
	Geo.col_box(body, Vector3(35.5, 0.9, 15.2), Vector3(0.8, 1.8, 0.7))
	# световой фонарь в потолке и лунный луч
	var sky := Mat.flat(Color(0.12, 0.14, 0.2), 0.2, 0.0, {"emission": Color(0.45, 0.55, 0.85), "emission_energy": 0.6})
	b.box(sky, Vector3(26.0, 4.97, 11.5), Vector3(6.0, 0.03, 3.0))
	var frame := Mat.m("rust", {"metal": 0.5})
	for i in 5:
		b.box(frame, Vector3(23.0 + i * 1.5, 4.95, 11.5), Vector3(0.05, 0.06, 3.0))
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 2.2
	moon.spot_range = 12.0
	moon.spot_angle = 22.0
	moon.light_volumetric_fog_energy = 2.5
	moon.shadow_enabled = false
	n.add_child(moon)
	moon.global_position = Vector3(26.0, 4.9, 11.5)
	moon.rotation = Vector3(-PI * 0.5 + 0.15, 0, 0.1)
	Props.drain(w, b, Vector3(15.5, 0, 7.2), "pool")
	Props.drain(w, b, Vector3(36.5, 0, 7.2), "pool")
	Props.drain(w, b, Vector3(26.0, 0, 16.3), "pool")
	# решётка слива в глубокой части и люк
	b.box(Mat.m("grate", {"metal": 0.6, "scale": 0.4}), Vector3(32.2, Layout.POOL_DEEP + 0.01, 11.5), Vector3(0.5, 0.02, 0.5))
	b.commit(n, "props")


# ---------------------------------------------------------------- технический коридор, насосная

static func service(w: World) -> void:
	var n := _n(w, "service")
	var body := _b(w, "service")
	var b := Geo.Batch.new()
	var rust := Mat.m("rust", {"metal": 0.5})
	var insul := Mat.m("cloth", {"tint": Color(0.55, 0.52, 0.45), "scale": 0.8})
	# магистрали под потолком и у пола
	b.cyl(insul, Vector3(0.2, 2.55, 0.35), Vector3(51.8, 2.55, 0.35), 0.13, 10)
	b.cyl(rust, Vector3(0.2, 2.2, 0.32), Vector3(51.8, 2.2, 0.32), 0.07, 10)
	b.cyl(rust, Vector3(0.2, 0.35, 2.7), Vector3(51.8, 0.35, 2.7), 0.06, 10)
	for x in range(2, 52, 4):
		b.box(rust, Vector3(x, 2.4, 0.3), Vector3(0.06, 0.45, 0.25))
	# топки каменок со стороны коридора
	for sx in [4.6, 47.4]:
		var brick := Mat.m("brick_red", {"tint": Color(0.5, 0.4, 0.35)})
		b.box(brick, Vector3(sx, 0.75, 2.75), Vector3(1.4, 1.5, 0.3))
		b.box(Mat.flat(Color(0.12, 0.1, 0.09), 0.5, 0.8), Vector3(sx, 0.6, 2.58), Vector3(0.5, 0.42, 0.05))
		b.box(Mat.flat(Color(0.5, 0.15, 0.03), 0.6, 0.0, {"emission": Color(1.0, 0.4, 0.1), "emission_energy": 2.5}), Vector3(sx, 0.58, 2.57), Vector3(0.36, 0.08, 0.02))
		var f := Items.Fire.new()
		f.base = 1.6
		f.omni_range = 5.5
		n.add_child(f)
		f.global_position = Vector3(sx, 0.7, 2.2)
		# уголь у топки, лопата
		b.box(Mat.m("coal"), Vector3(sx + 1.2, 0.12, 2.3), Vector3(0.9, 0.25, 0.8), Basis(Vector3.UP, 0.3))
		Props.model(n, "rusted_spade_01", Vector3(sx - 1.0, 0.0, 2.7), 0.2)
	Props.picture(n, "res://tex/gen/sign_tech.png", Vector3(11.0, 2.4, 2.86), Vector3(0, 0, -1), Vector2(0.7, 0.35))
	Props.picture(n, "res://tex/gen/sign_kotelnaya.png", Vector3(23.8, 2.0, 0.14), Vector3(0, 0, 1), Vector2(0.7, 0.2))
	Props.picture(n, "res://tex/gen/sign_pump.png", Vector3(34.0, 2.35, 2.86), Vector3(0, 0, -1), Vector2(0.6, 0.17))
	Props.model(n, "wooden_ladder", Vector3(20.0, 0, 0.35), 0.0)
	Props.model(n, "wooden_crate_01", Vector3(38.0, 0, 0.6), 0.5, 1.0, true)
	Props.drain(w, b, Vector3(16.0, 0, 1.5), "service")
	Props.drain(w, b, Vector3(36.0, 0, 1.5), "service")
	b.commit(n, "props")
	# отсвет топки внизу лестницы
	var glow := Items.Fire.new()
	glow.base = 2.2
	glow.omni_range = 7.0
	n.add_child(glow)
	glow.global_position = Vector3(25.25, -3.8, -6.0)
	# ниша у лестницы: склад
	var sw := _n(w, "stairwell")
	Props.model(sw, "wooden_crate_02", Vector3(24.0, 0, 5.3), 0.2, 1.0, true)
	Props.model(sw, "wooden_crate_01", Vector3(27.0, 0, 5.2), -0.3, 1.0, true)
	Props.model(sw, "cement_bag", Vector3(25.5, 0, 5.4), 0.0)
	# насосная
	var p := _n(w, "pump")
	var pb := Geo.Batch.new()
	var motor := Mat.m("rust_paint", {"metal": 0.4, "tint": Color(0.5, 0.6, 0.55)})
	for px in [31.4, 32.9]:
		pb.cyl(motor, Vector3(px - 0.4, 0.45, 4.6), Vector3(px + 0.4, 0.45, 4.6), 0.3, 14, true)
		pb.box(motor, Vector3(px, 0.15, 4.6), Vector3(1.0, 0.3, 0.6))
		Geo.col_box(_b(w, "pump"), Vector3(px, 0.45, 4.6), Vector3(1.0, 0.9, 0.7))
	Props.pipe(pb, [Vector3(31.2, 0.45, 4.6), Vector3(30.6, 0.45, 4.6), Vector3(30.6, 2.6, 4.6)], 0.08, rust)
	Props.pipe(pb, [Vector3(36.7, 0.0, 3.4), Vector3(36.7, 2.8, 3.4)], 0.12, rust)
	pb.commit(p, "props")
	Props.picture(p, "res://tex/gen/sign_wet.png", Vector3(37.86, 1.9, 4.6), Vector3(-1, 0, 0), Vector2(0.5, 0.25))


# ---------------------------------------------------------------- женское отделение

static func women(w: World) -> void:
	_locker_room(w, "f_lock", true)
	_wash(w, "f_wash", true)
	_steam(w, "f_steam", true)
	_showers(w, "f_shower", true)
	# сушуарная: кресла с колпаками
	var d := _n(w, "f_dry")
	var b := Geo.Batch.new()
	var shell := Mat.flat(Color(0.75, 0.72, 0.62), 0.35, 0.2)
	for i in 3:
		var z := 20.7 + i * 1.1
		Props.model(d, "painted_wooden_chair_02", Vector3(51.4, 0, z), -PI * 0.5)
		b.cyl(Mat.flat(Color(0.4, 0.4, 0.38), 0.4, 0.8), Vector3(51.75, 0, z), Vector3(51.75, 1.35, z), 0.025, 8)
		b.box(shell, Vector3(51.55, 1.42, z), Vector3(0.42, 0.32, 0.42))
		b.box(Mat.flat(Color(0.05, 0.05, 0.05), 0.8), Vector3(51.5, 1.29, z), Vector3(0.36, 0.05, 0.36))
	b.commit(d, "props")
	# комната банщицы
	var a := _n(w, "f_attend")
	var ab := Geo.Batch.new()
	Props.model(a, "old_bed_frame", Vector3(51.0, 0, 28.6), -PI * 0.5, 0.9, true)
	ab.box(Mat.m("cloth", {"tint": Color(0.6, 0.55, 0.5)}), Vector3(51.0, 0.52, 28.6), Vector3(0.85, 0.12, 1.9))
	Props.model(a, "painted_wooden_table", Vector3(49.8, 0, 25.0), 0.0, 1.0, true)
	Props.model(a, "painted_wooden_chair_01", Vector3(49.8, 0, 25.7), PI)
	Props.model(a, "vintage_electric_kettle", Vector3(50.4, 0.78, 24.85), 1.0)
	Props.model(a, "vintage_radio_transceiver", Vector3(51.6, 0, 25.0), -PI * 0.5)
	Props.salt(ab, Vector3(48.32, 0, 27.0), false, 1.0)
	ab.commit(a, "props")
