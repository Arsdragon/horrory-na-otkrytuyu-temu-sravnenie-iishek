class_name PropsBase
## Обстановка подвала (котельная, коллектор, сруб…) и двора.

const Y := Layout.BASE_Y


static func build(w: World) -> void:
	collector(w)
	boiler(w)
	stoker(w)
	meter(w)
	coal(w)
	banya(w)


static func _n(w: World, id: String) -> Node3D:
	return w.rooms[id]["node"]


static func _b(w: World, id: String) -> StaticBody3D:
	return w.rooms[id]["body"]


## Сухой поддон / мостки: ходить тихо.
static func pallet(w: World, b: Geo.Batch, body: StaticBody3D, rect: Rect2) -> void:
	var wood := Mat.m("planks_weather", {"tint": Color(0.5, 0.42, 0.33), "wet": 0.3})
	var h := 0.15
	var c := Vector3(rect.get_center().x, Y + h * 0.5, rect.get_center().y)
	# доски поперёк
	var along_x := rect.size.x > rect.size.y
	var n := int((rect.size.x if along_x else rect.size.y) / 0.16)
	for i in n:
		var t := -0.5 + (i + 0.5) / n
		var p := c + (Vector3(t * rect.size.x, h * 0.5 - 0.015, 0) if along_x else Vector3(0, h * 0.5 - 0.015, t * rect.size.y))
		b.box(wood, p, Vector3(0.13, 0.03, rect.size.y) if along_x else Vector3(rect.size.x, 0.03, 0.13))
	b.box(Mat.m("planks_dark"), c + Vector3(0, -0.02, 0), Vector3(rect.size.x * 0.9, h - 0.04, rect.size.y * 0.9))
	Geo.col_box(body, c, Vector3(rect.size.x, h, rect.size.y))
	w.dry_rects.append({"rect": rect, "y": Y + h})


# ---------------------------------------------------------------- коллектор — её логово

static func collector(w: World) -> void:
	var n := _n(w, "collector")
	var b := Geo.Batch.new()
	var rust := Mat.m("rust", {"metal": 0.5})
	b.cyl(rust, Vector3(30.25, Y + 1.6, -6.9), Vector3(30.25, Y + 1.6, 11.9), 0.09, 10)
	b.cyl(rust, Vector3(31.8, Y + 0.3, -6.9), Vector3(31.8, Y + 0.3, 11.9), 0.06, 10)
	# волосы свисают с потолка гуще к середине
	for i in 22:
		var z := randf_range(-5.0, 10.5)
		var dens := 1.0 - absf(z - 3.0) / 8.0
		if randf() > dens + 0.2:
			continue
		Props.hair_clump(n, Vector3(randf_range(30.3, 31.7), Y + 1.98, z), randf_range(0.6, 1.5), true)
	for i in 8:
		Props.hair_clump(n, Vector3(randf_range(30.3, 31.7), Y + 0.16, randf_range(1.0, 5.0)), randf_range(0.5, 1.0), false)
	# вещи пропавших: серая куртка, ушанка, отцовские сапоги
	var cloth := Mat.m("cloth", {"tint": Color(0.35, 0.35, 0.33), "wet": 0.6})
	b.box(cloth, Vector3(30.6, Y + 0.1, 2.5), Vector3(0.6, 0.12, 0.5), Basis(Vector3.UP, 0.4))
	b.box(Mat.m("cloth", {"tint": Color(0.3, 0.25, 0.2)}), Vector3(31.5, Y + 0.12, 4.2), Vector3(0.3, 0.15, 0.3))
	Props.model(n, "rubber_boots", Vector3(31.3, Y, 3.2), 1.2)
	Props.drain(w, b, Vector3(31.0, Y, 8.0), "collector")
	Props.drain(w, b, Vector3(31.0, Y, -3.0), "collector")
	# лестница к люку в дне бассейна
	var lad := Mat.m("rust", {"metal": 0.6})
	for dx in [-0.22, 0.22]:
		b.cyl(lad, Vector3(31.0 + dx, Y, 11.85), Vector3(31.0 + dx, Y + 2.0, 11.85), 0.02, 6)
	for k in 6:
		b.cyl(lad, Vector3(30.78, Y + 0.3 + k * 0.3, 11.85), Vector3(31.22, Y + 0.3 + k * 0.3, 11.85), 0.015, 6)
	b.commit(n, "props")


# ---------------------------------------------------------------- котельная

static func boiler(w: World) -> void:
	var n := _n(w, "boiler")
	var body := _b(w, "boiler")
	var b := Geo.Batch.new()
	var steel := Mat.m("rust_paint", {"metal": 0.5, "tint": Color(0.45, 0.42, 0.4)})
	var brick := Mat.m("brick_red", {"tint": Color(0.45, 0.35, 0.3)})
	var rust := Mat.m("rust", {"metal": 0.5})
	for bx in [20.0, 27.0]:
		# кирпичная топка-основание и лежачий барабан котла
		b.box(brick, Vector3(bx, Y + 0.7, -14.0), Vector3(2.6, 1.4, 5.0))
		b.cyl(steel, Vector3(bx, Y + 2.3, -16.2), Vector3(bx, Y + 2.3, -11.6), 1.05, 18, true)
		for k in 5:
			var z := -16.0 + k * 1.1
			b.cyl(rust, Vector3(bx, Y + 2.3, z), Vector3(bx, Y + 2.3, z + 0.06), 1.08, 18)
		Geo.col_box(body, Vector3(bx, Y + 1.7, -14.0), Vector3(2.6, 3.4, 5.0))
		# дверцы топки с огнём
		b.box(Mat.flat(Color(0.1, 0.09, 0.08), 0.5, 0.8), Vector3(bx, Y + 0.7, -11.47), Vector3(0.8, 0.6, 0.05))
		b.box(Mat.flat(Color(0.6, 0.18, 0.03), 0.6, 0.0, {"emission": Color(1.0, 0.42, 0.1), "emission_energy": 3.0}), Vector3(bx, Y + 0.62, -11.44), Vector3(0.6, 0.12, 0.02))
		var f := Items.Fire.new()
		f.base = 4.5
		f.omni_range = 12.0
		n.add_child(f)
		f.global_position = Vector3(bx, Y + 0.9, -10.9)
		# труба к борову
		Props.pipe(b, [Vector3(bx, Y + 3.3, -15.0), Vector3(bx, Y + 3.9, -15.0), Vector3(bx, Y + 3.9, -17.5)], 0.25, rust)
		# манометр
		b.cyl(Mat.flat(Color(0.8, 0.78, 0.7), 0.4), Vector3(bx + 1.1, Y + 2.4, -11.9), Vector3(bx + 1.14, Y + 2.4, -11.9), 0.12, 16, true)
	# уголь у топок, тачка, лопаты
	b.box(Mat.m("coal"), Vector3(23.5, Y + 0.25, -9.6), Vector3(2.2, 0.5, 1.6), Basis(Vector3.UP, 0.2))
	Geo.col_box(body, Vector3(23.5, Y + 0.2, -9.6), Vector3(2.0, 0.4, 1.4))
	Props.model(n, "rusted_spade_01", Vector3(22.4, Y, -9.2), 1.1)
	Props.model(n, "rusted_spade_01", Vector3(28.6, Y, -10.4), -0.6)
	Props.model(n, "metal_stool_01", Vector3(29.5, Y, -9.0), 0.4)
	# трубы по потолку
	b.cyl(rust, Vector3(16.2, Y + 3.8, -8.0), Vector3(31.8, Y + 3.8, -8.0), 0.12, 10)
	b.cyl(rust, Vector3(16.2, Y + 3.5, -17.5), Vector3(31.8, Y + 3.5, -17.5), 0.1, 10)
	# сухие мостки: от лестницы к комнатам
	pallet(w, b, body, Rect2(24.5, -10.0, 1.5, 2.9))   # низ лестницы
	pallet(w, b, body, Rect2(16.2, -11.6, 8.3, 1.2))   # к истопнику
	pallet(w, b, body, Rect2(16.2, -16.6, 1.2, 5.0))   # к водомеру
	pallet(w, b, body, Rect2(25.9, -8.9, 5.9, 1.4))    # к коллектору и срубу
	pallet(w, b, body, Rect2(30.6, -15.2, 1.2, 6.3))   # к бункеру
	Props.drain(w, b, Vector3(18.0, Y, -8.0), "boiler")
	Props.drain(w, b, Vector3(30.5, Y, -17.0), "boiler")
	Props.drain(w, b, Vector3(23.5, Y, -16.8), "boiler")
	b.commit(n, "props")


# ---------------------------------------------------------------- комната истопника

static func stoker(w: World) -> void:
	var n := _n(w, "stoker")
	var body := _b(w, "stoker")
	var b := Geo.Batch.new()
	Props.model(n, "old_bed_frame", Vector3(11.0, Y, -12.2), 0.0, 0.9, true)
	b.box(Mat.m("cloth", {"tint": Color(0.4, 0.38, 0.32)}), Vector3(11.0, Y + 0.52, -12.2), Vector3(0.85, 0.12, 1.9))
	Props.model(n, "painted_wooden_table", Vector3(13.5, Y, -8.7), 0.0, 1.0, true)
	Props.model(n, "wooden_stool_01", Vector3(13.5, Y, -9.5), 0.3)
	Props.model(n, "vintage_radio_transceiver", Vector3(15.4, Y, -9.0), -PI * 0.5)
	Props.model(n, "alarm_clock_01", Vector3(14.2, Y + 0.78, -8.55), 2.5)
	Items.candle(n, Vector3(12.9, Y + 0.78, -8.6))
	Props.picture(n, "res://tex/gen/calendar.png", Vector3(13.0, Y + 1.7, -13.86), Vector3(0, 0, 1), Vector2(0.32, 0.45))
	# шкаф с отцовским ватником
	b.box(Mat.m("planks_weather", {"tint": Color(0.55, 0.5, 0.42)}), Vector3(15.5, Y + 0.95, -13.4), Vector3(0.6, 1.9, 0.8))
	Geo.col_box(body, Vector3(15.5, Y + 0.95, -13.4), Vector3(0.6, 1.9, 0.8))
	Props.salt(b, Vector3(15.75, Y, -11.0), false, 1.0)
	b.commit(n, "props")


# ---------------------------------------------------------------- водомерный узел

static func meter(w: World) -> void:
	var n := _n(w, "meter")
	var body := _b(w, "meter")
	var b := Geo.Batch.new()
	var pipe := Mat.m("rust_paint", {"metal": 0.5, "tint": Color(0.35, 0.4, 0.5)})
	# ввод из стены → задвижка → водомер → в котельную
	var PZ := -17.2
	b.cyl(pipe, Vector3(10.1, Y + 0.9, PZ), Vector3(15.9, Y + 0.9, PZ), 0.16, 14)
	b.cyl(pipe, Vector3(15.9, Y + 0.9, PZ), Vector3(15.9, Y + 2.8, PZ), 0.16, 14)
	# корпус задвижки
	var body_m := Mat.m("rust", {"metal": 0.6, "tint": Color(0.7, 0.55, 0.5)})
	b.box(body_m, Vector3(12.0, Y + 0.95, PZ), Vector3(0.5, 0.6, 0.55))
	b.cyl(body_m, Vector3(12.0, Y + 1.25, PZ), Vector3(12.0, Y + 1.75, PZ), 0.07, 10)
	# водомер
	b.box(Mat.flat(Color(0.25, 0.3, 0.38), 0.4, 0.6), Vector3(14.2, Y + 0.95, PZ), Vector3(0.45, 0.42, 0.42))
	b.cyl(Mat.flat(Color(0.85, 0.85, 0.8), 0.3), Vector3(14.2, Y + 1.16, PZ), Vector3(14.2, Y + 1.18, PZ), 0.14, 18, true)
	Geo.col_box(body, Vector3(13.0, Y + 0.9, PZ), Vector3(5.8, 0.6, 0.6))
	Props.picture(n, "res://tex/gen/sign_vvod.png", Vector3(12.0, Y + 2.1, -17.86), Vector3(0, 0, 1), Vector2(0.6, 0.3))
	b.commit(n, "props")
	# стрелка водомера крутится
	var hand := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.004, 0.11)
	hand.mesh = bm
	hand.material_override = Mat.flat(Color(0.7, 0.05, 0.05), 0.5)
	n.add_child(hand)
	hand.global_position = Vector3(14.2, Y + 1.19, -17.2)
	w.set_meta("meter_hand", hand)


# ---------------------------------------------------------------- угольный бункер

static func coal(w: World) -> void:
	var n := _n(w, "coal")
	var body := _b(w, "coal")
	var b := Geo.Batch.new()
	var cm := Mat.m("coal", {"scale": 1.0})
	# куча угля поднимается к люку у северной стены
	var ramp_len := 5.4
	var rise := 2.7
	var ang := atan2(rise, ramp_len)
	var mid := Vector3(35.0, Y + rise * 0.5 - 0.1, -14.6)
	var basis := Basis(Vector3.RIGHT, ang)
	b.box(cm, mid, Vector3(4.0, 0.4, sqrt(ramp_len * ramp_len + rise * rise)), basis)
	Geo.col_box(body, mid, Vector3(4.0, 0.4, sqrt(ramp_len * ramp_len + rise * rise)), basis)
	b.box(cm, Vector3(35.0, Y + rise * 0.5 - 0.3, -16.0), Vector3(4.0, rise - 0.6, 2.5))
	b.box(cm, Vector3(35.0, Y + rise - 0.2, -17.5), Vector3(4.0, 0.4, 0.8))
	Geo.col_box(body, Vector3(35.0, Y + rise - 0.2, -17.5), Vector3(4.0, 0.4, 0.8))
	for i in 10:
		b.box(cm, Vector3(randf_range(33, 37.6), Y + 0.15, randf_range(-12.8, -11.4)), Vector3(randf_range(0.4, 0.9), 0.3, randf_range(0.4, 0.8)), Basis(Vector3.UP, randf() * 3.0))
	# люк углеподачи в стене под потолком
	var hatch := Mat.m("rust", {"metal": 0.6})
	b.box(hatch, Vector3(35.0, Y + 3.45, -17.85), Vector3(1.2, 1.0, 0.06))
	b.box(Mat.flat(Color(0.08, 0.08, 0.08), 0.6, 0.7), Vector3(35.0, Y + 3.45, -17.8), Vector3(1.0, 0.8, 0.04))
	Props.model(n, "rusted_spade_01", Vector3(33.0, Y, -12.3), 2.4)
	b.commit(n, "props")


# ---------------------------------------------------------------- сруб: старая чёрная баня

static func banya(w: World) -> void:
	var n := _n(w, "banya")
	var body := _b(w, "banya")
	var b := Geo.Batch.new()
	var soot := Mat.m("planks_dark", {"tint": Color(0.35, 0.3, 0.27)})
	# полок у южной стены, два яруса
	b.box(soot, Vector3(35.0, Y + 0.45, -5.6), Vector3(5.6, 0.07, 0.8))
	b.box(soot, Vector3(35.0, Y + 0.95, -5.45), Vector3(5.6, 0.07, 0.5))
	b.box(soot, Vector3(35.0, Y + 0.22, -5.95), Vector3(5.6, 0.45, 0.05))
	Geo.col_box(body, Vector3(35.0, Y + 0.25, -5.6), Vector3(5.6, 0.5, 0.8))
	# каменка-каменица в углу: груда чёрных камней
	var stone := Mat.flat(Color(0.1, 0.09, 0.085), 0.8)
	var ember := Mat.flat(Color(0.3, 0.06, 0.02), 0.6, 0.0, {"emission": Color(0.9, 0.18, 0.05), "emission_energy": 1.4})
	for i in 40:
		var r := randf_range(0.0, 0.65)
		var a := randf() * TAU
		var h := (0.65 - r) * 1.2
		var p := Vector3(36.8 + cos(a) * r, Y + randf() * h + 0.1, -10.0 + sin(a) * r)
		b.box(ember if randf() < 0.15 else stone, p, Vector3.ONE * randf_range(0.15, 0.3), Basis.from_euler(Vector3(randf(), randf(), randf())))
	Geo.col_box(body, Vector3(36.8, Y + 0.45, -10.0), Vector3(1.3, 0.9, 1.3))
	var glow := Items.Fire.new()
	glow.base = 0.7
	glow.omni_range = 4.0
	glow.light_color = Color(1.0, 0.25, 0.08)
	n.add_child(glow)
	glow.global_position = Vector3(36.6, Y + 1.0, -9.6)
	# сухие веники, ведро, ковш
	for i in 4:
		b.box(Mat.m("planks_weather", {"tint": Color(0.35, 0.33, 0.2)}), Vector3(32.3, Y + 1.7, -9.5 + i * 0.6), Vector3(0.15, 0.55, 0.3))
	Props.model(n, "wooden_bucket_01", Vector3(33.0, Y, -10.2), 0.4)
	b.commit(n, "props")
	# волосы на полке
	for i in 5:
		Props.hair_clump(n, Vector3(randf_range(33.0, 37.0), Y + 0.99, -5.4), randf_range(0.5, 0.9), false)
	Props.hair_clump(n, Vector3(35.0, Y + 2.38, -8.0), 1.6, true)


# ---------------------------------------------------------------- двор

static func exterior(w: World) -> void:
	var ext := Node3D.new()
	ext.name = "yard"
	w.add_child(ext)
	var body := Geo.static_body(ext, "col")
	var b := Geo.Batch.new()
	# вывеска
	Props.picture(ext, "res://tex/gen/sign_bani.png", Vector3(26.0, 3.6, 30.36), Vector3(0, 0, 1), Vector2(3.6, 0.9))
	Props.picture(ext, "res://tex/gen/sign_no3.png", Vector3(28.4, 1.9, 30.36), Vector3(0, 0, 1), Vector2(0.4, 0.4))
	Props.picture(ext, "res://tex/gen/sign_closed.png", Vector3(25.55, 1.45, 30.36), Vector3(0, 0, 1), Vector2(0.42, 0.33))
	# фонарный столб
	var pole := Mat.flat(Color(0.2, 0.2, 0.2), 0.6, 0.5)
	b.cyl(pole, Vector3(16.0, 0, 37.0), Vector3(16.0, 6.0, 37.0), 0.08, 8)
	b.cyl(pole, Vector3(16.0, 6.0, 37.0), Vector3(17.2, 6.2, 37.0), 0.05, 6)
	b.box(Mat.flat(Color(1, 0.7, 0.4), 0.5, 0.0, {"emission": Color(1, 0.6, 0.3), "emission_energy": 4.0}), Vector3(17.2, 6.1, 37.0), Vector3(0.35, 0.08, 0.2))
	Geo.col_box(body, Vector3(16.0, 3.0, 37.0), Vector3(0.2, 6.0, 0.2))
	var sl := SpotLight3D.new()
	sl.light_color = Color(1.0, 0.62, 0.32)
	sl.light_energy = 4.0
	sl.spot_range = 14.0
	sl.spot_angle = 50.0
	sl.shadow_enabled = true
	ext.add_child(sl)
	sl.global_position = Vector3(17.2, 6.0, 37.0)
	sl.rotation = Vector3(-PI * 0.5, 0, 0)
	# фургон «Водоканала»
	van(ext, body, b, Vector3(32.0, 0, 41.5), 0.25)
	# бетонный забор вокруг двора
	var fence := Mat.m("concrete", {"tint": Color(0.6, 0.6, 0.6)})
	for i in 20:
		var x := -6.0 + i * 3.4
		b.box(fence, Vector3(x, 1.1, 51.5), Vector3(3.3, 2.2, 0.15))
	for i in 6:
		b.box(fence, Vector3(-7.6, 1.1, 32.0 + i * 3.4), Vector3(0.15, 2.2, 3.3))
		b.box(fence, Vector3(59.6, 1.1, 32.0 + i * 3.4), Vector3(0.15, 2.2, 3.3))
	# голые деревья
	for tpos in [Vector3(4, 0, 44), Vector3(9, 0, 48), Vector3(46, 0, 46), Vector3(53, 0, 40), Vector3(-3, 0, 36)]:
		tree(b, tpos)
	b.commit(ext, "yard")
	# снегопад
	snow_fx(ext, Vector3(26, 10, 41))


static func van(parent: Node3D, body: StaticBody3D, b: Geo.Batch, pos: Vector3, yaw: float) -> void:
	var paint := Mat.m("metal_green", {"tint": Color(1.1, 1.05, 0.8), "metal": 0.3, "scale": 2.0})
	var dark := Mat.flat(Color(0.03, 0.035, 0.04), 0.1, 0.6)
	var tire := Mat.flat(Color(0.05, 0.05, 0.05), 0.9)
	var xf := Basis(Vector3.UP, yaw)
	var parts := [
		[Vector3(0, 1.25, 0), Vector3(2.0, 1.6, 4.4), paint],
		[Vector3(0, 1.55, -2.25), Vector3(1.85, 0.75, 0.05), dark],
		[Vector3(1.01, 1.6, -1.3), Vector3(0.03, 0.55, 0.9), dark],
		[Vector3(-1.01, 1.6, -1.3), Vector3(0.03, 0.55, 0.9), dark],
		[Vector3(1.01, 1.6, 0.6), Vector3(0.03, 0.45, 1.6), dark],
		[Vector3(0, 2.1, 0), Vector3(1.9, 0.08, 4.2), paint],
		[Vector3(0, 0.55, -2.2), Vector3(2.0, 0.25, 0.1), Mat.flat(Color(0.2, 0.2, 0.2), 0.5, 0.6)],
	]
	for p in parts:
		b.box(p[2], pos + xf * p[0], p[1], xf)
	for wx in [-0.95, 0.95]:
		for wz in [-1.35, 1.35]:
			var c := pos + xf * Vector3(wx, 0.38, wz)
			b.cyl(tire, c - xf * Vector3(0.12, 0, 0), c + xf * Vector3(0.12, 0, 0), 0.38, 14, true)
	Geo.col_box(body, pos + xf * Vector3(0, 1.1, 0), Vector3(2.0, 2.2, 4.4), xf)
	var lbl := Geo.label3d(parent, "АВАРИЙНАЯ\nВОДОКАНАЛ", pos + xf * Vector3(1.03, 1.2, 0.4), 0.09, Color(0.6, 0.1, 0.08))
	lbl.rotation.y = yaw + PI * 0.5
	# фары горят: светят на баню
	for hx in [-0.65, 0.65]:
		var hp := pos + xf * Vector3(hx, 0.9, -2.22)
		b.box(Mat.flat(Color(1, 0.95, 0.8), 0.2, 0.0, {"emission": Color(1, 0.93, 0.75), "emission_energy": 6.0}), hp, Vector3(0.22, 0.16, 0.03), xf)
		var sp := SpotLight3D.new()
		sp.light_color = Color(1.0, 0.92, 0.75)
		sp.light_energy = 6.0
		sp.spot_range = 22.0
		sp.spot_angle = 24.0
		sp.shadow_enabled = hx < 0.0
		sp.light_volumetric_fog_energy = 1.5
		parent.add_child(sp)
		sp.global_position = hp + xf * Vector3(0, 0, -0.05)
		sp.global_rotation = Vector3(-0.07, yaw, 0)


static func tree(b: Geo.Batch, pos: Vector3) -> void:
	var bark := Mat.m("planks_dark", {"tint": Color(0.35, 0.33, 0.32)})
	var h := randf_range(5.0, 7.5)
	b.cyl(bark, pos, pos + Vector3(0, h, 0), 0.14, 7)
	for i in 7:
		var y := randf_range(h * 0.4, h * 0.95)
		var a := randf() * TAU
		var l := randf_range(1.0, 2.2)
		var s := pos + Vector3(0, y, 0)
		b.cyl(bark, s, s + Vector3(cos(a) * l, l * 0.6, sin(a) * l), 0.04, 5)


static func snow_fx(parent: Node3D, center: Vector3) -> void:
	var p := GPUParticles3D.new()
	p.amount = 900
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.visibility_aabb = AABB(Vector3(-40, -12, -25), Vector3(80, 24, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(34, 0.5, 16)
	pm.direction = Vector3(0.2, -1, 0)
	pm.spread = 15.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 1.4
	pm.gravity = Vector3(0, -0.3, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.4
	p.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.88, 0.95, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.material = m
	p.draw_pass_1 = qm
	parent.add_child(p)
	p.global_position = center
