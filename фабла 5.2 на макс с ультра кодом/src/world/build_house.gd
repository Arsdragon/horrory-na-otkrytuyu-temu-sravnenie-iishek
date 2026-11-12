class_name BuildHouse
extends RefCounted
## Жилой дом станции: 10×6,4 м. Тамбур (ю-в), спальня (с-в), кают-компания (середина),
## радиорубка (с-з), кладовая (ю-з). Дверь наружу — в восточной стене.

const FY := 0.03       # верх пола
const H := 2.5         # высота потолка


static func build(w: World) -> void:
	var root := Node3D.new()
	root.name = "House"
	w.add_child(root)
	var b := Batch.new()
	_shell(w, root, b)
	_main_room(w, root, b)
	_radio_room(w, root, b)
	_bunk_room(w, root, b)
	_store_room(w, root, b)
	_vestibule(w, root, b)
	_outside(w, root, b)
	b.commit(root, "Static")
	w.add_zone("vest", Vector3(2.0, -1, 0.0), Vector3(5.12, H, 3.3), "wood", 0.8, 0.6)
	w.add_zone("bunk", Vector3(2.0, -1, -3.3), Vector3(5.1, H, 0.0), "wood", 1.0, 0.0)
	w.add_zone("radio", Vector3(-5.1, -1, -3.3), Vector3(-2.0, H, 0.0), "wood", 1.0, 0.0)
	w.add_zone("store", Vector3(-5.1, -1, 0.0), Vector3(-2.0, H, 3.3), "wood", 1.0, 0.2)
	w.add_zone("house", Vector3(-2.0, -1, -3.3), Vector3(2.0, H, 3.3), "wood", 1.0, 0.0)
	w.places["bed"] = [Vector3(3.5, FY, -1.2), -90.0]
	w.places["main"] = [Vector3(0.0, FY, -1.4), 180.0]
	w.places["radio"] = [Vector3(-3.3, FY, -1.3), 90.0]
	w.places["store"] = [Vector3(-3.4, FY, 1.6), 90.0]
	w.places["vest"] = [Vector3(3.3, FY, 1.6), -90.0]
	w.places["door_out"] = [Vector3(6.4, 0, 1.6), 90.0]


static func _shell(w: World, root: Node3D, b: Batch) -> void:
	var ext := Kit.mat("sidegreen", 2.2)
	var inn := Kit.mat("wallpaint", 2.0, Color(0.86, 0.86, 0.8))
	var flo := Kit.mat("floorwood", 2.0)
	var cei := Kit.mat("ceilwood", 2.2, Color(0.5, 0.48, 0.43))
	b.box(Vector3(0, FY - 0.115, 0), Vector3(10.2, 0.23, 6.6), flo)
	b.box(Vector3(0, H + 0.06, 0), Vector3(10.2, 0.12, 6.6), cei)
	# наружные стены: снаружи вагонка, внутри крашеные доски
	Walls.wall_x(b, -3.2, -5.1, 5.1, 0, H, 0.2, ext, inn, [[0.0, 1.0, 1.0, 1.9], [3.4, 0.8, 1.05, 1.85]], false, true)
	Walls.wall_x(b, 3.2, -5.1, 5.1, 0, H, 0.2, inn, ext, [[0.0, 1.0, 1.0, 1.9]], true, false)
	Walls.wall_z(b, -5.0, -3.1, 3.1, 0, H, 0.2, ext, inn, [[-1.6, 0.9, 1.0, 1.9]], false, true)
	Walls.wall_z(b, 5.0, -3.1, 3.1, 0, H, 0.2, inn, ext, [[1.6, 0.95, 0.0, 2.0], [2.62, 0.42, 1.25, 1.68]], true, false)
	# перегородки
	Walls.wall_z(b, -2.0, -3.1, 3.1, 0, H, 0.12, inn, inn, [[-1.6, 0.86, 0.0, 1.99], [1.6, 0.86, 0.0, 1.99]], true, true)
	Walls.wall_z(b, 2.0, -3.1, 3.1, 0, H, 0.12, inn, inn, [[-1.6, 0.86, 0.0, 1.99], [1.6, 0.86, 0.0, 1.99]], true, true)
	Walls.wall_x(b, 0.0, -4.9, -2.06, 0, H, 0.12, inn, inn, [], true, true)
	Walls.wall_x(b, 0.0, 2.06, 4.9, 0, H, 0.12, inn, inn, [], true, true)
	# окна
	for e in [[Vector3(0, 1.45, -3.2), "x", 1.0, 0.9, Vector3(0, 0, -1)], [Vector3(3.4, 1.45, -3.2), "x", 0.8, 0.8, Vector3(0, 0, -1)],
			[Vector3(0, 1.45, 3.2), "x", 1.0, 0.9, Vector3(0, 0, 1)], [Vector3(-5.0, 1.45, -1.6), "z", 0.9, 0.9, Vector3(-1, 0, 0)],
			[Vector3(5.0, 1.465, 2.62), "z", 0.42, 0.43, Vector3(1, 0, 0)]]:
		var gm := Walls.window(root, b, e[0], String(e[1]), float(e[2]), float(e[3]), 0.2, e[4])
		w.reg_glow(gm)
		# окно видно издалека: по нему находят дом, когда леера нет
		var wc: Vector3 = e[0]
		var wo: Vector3 = e[4]
		var wh := Kit.halo(root, wc + wo * 0.25, Color(1.0, 0.72, 0.36), 1.1, 1.2)
		(wh.material_override as ShaderMaterial).set_shader_parameter("vis_scale", 1.8)
		(wh.material_override as ShaderMaterial).set_shader_parameter("face", wo)
		w.reg_halo(wh)
	# крыша: два ската, снег, щипцы, труба
	var roof := Kit.mat("corrug", 2.0, Color(0.7, 0.72, 0.75))
	var snow := Kit.mat("snowcrust", 3.0, Color(0.92, 0.95, 1.0))
	var a := deg_to_rad(18.43)
	for sgn in [-1.0, 1.0]:
		var rot := Basis(Vector3.RIGHT, sgn * a)
		var c := Vector3(0, 3.225, sgn * 1.875)
		b.box(c, Vector3(11.0, 0.07, 3.98), roof, false, rot)
		b.box(c + rot * Vector3(0, 0.13, 0.12), Vector3(10.9, 0.2, 3.7), snow, false, rot)
	for x in [-5.1, 5.1]:
		b.tri(Vector3(x, H, -3.3), Vector3(x, H, 3.3), Vector3(x, 3.6, 0), Vector3(signf(x), 0, 0), ext, Vector3(0, 0, 1), Vector3(0, -1, 0))
	var rust := Kit.mat("metalrust", 1.0, Color(0.5, 0.45, 0.42))
	b.cyl(Vector3(-1.5, 2.7, 0), 0.075, 3.6, rust, 10, false)
	b.cyl(Vector3(-1.5, 4.56, 0), 0.13, 0.1, rust, 10, false)
	# двери
	var dm := Kit.mat("plankold", 1.6)
	var out := Door.make(root, Vector3(5.0, FY, 1.125), -90.0, 0.95, 1.97, dm, -100.0, 0.06)
	out.add_bar(1.0)
	w.doors["house"] = out
	var bar := Interactable.make(root, Vector3(4.82, 1.05, 2.3), Vector3(0.22, 0.4, 0.3), "Задвинуть засов", func() -> void: G.act("bar"))
	w.things["bar"] = bar
	var dmi := Kit.mat("wallblue", 1.6, Color(0.85, 0.85, 0.85))
	var d_bunk := Door.make(root, Vector3(2.0, FY, -2.03), -90.0, 0.86, 1.96, dmi, 96.0, 0.04)
	var d_vest := Door.make(root, Vector3(2.0, FY, 1.17), -90.0, 0.86, 1.96, dmi, 96.0, 0.04)
	var d_radio := Door.make(root, Vector3(-2.0, FY, -2.03), -90.0, 0.86, 1.96, dmi, -96.0, 0.04)
	var d_store := Door.make(root, Vector3(-2.0, FY, 1.17), -90.0, 0.86, 1.96, dmi, -96.0, 0.04)
	w.doors["bunk"] = d_bunk
	w.doors["vest"] = d_vest
	w.doors["radio"] = d_radio
	w.doors["store"] = d_store
	d_bunk.set_open(true, true)
	d_radio.set_open(true, true)
	d_store.set_open(true, true)


static func _main_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(0.0, H, -0.2), 1.5, 6.5)
	# печь-бочка у западной перегородки, между дверями
	var stove := Kit.put(root, "stove", Vector3(-1.52, FY, 0.0), 90.0, 1.0, true)
	b.box(Vector3(-1.5, FY + 0.01, 0.0), Vector3(0.9, 0.02, 1.0), Kit.mat("metalplate", 1.0, Color(0.5, 0.5, 0.5)), false)
	var fire := Kit.omni(root, Vector3(-1.05, 0.5, 0.0), Color(1.0, 0.45, 0.15), 0.0, 4.5, false, 30.0)
	fire.visible = false
	w.things["stove_light"] = fire
	w.things["stove"] = Interactable.make(root, Vector3(-1.5, 0.55, 0.0), Vector3(0.7, 0.95, 0.7), "Подбросить дров", func() -> void: G.act("stove"))
	w.things["stove_snd"] = Snd.emitter("fire_loop", root, Vector3(-1.4, 0.5, 0.0), -8.0, 9.0, 1.6)
	Kit.put(root, "kettle", Vector3(-1.52, FY + 0.87, 0.0), 30.0, 0.8, false, false)
	Props.logs(b, Vector3(-1.75, FY, 0.52), true, 3, 2, 0.4, 5)
	# стол и стулья
	Kit.put(root, "table", Vector3(0.78, FY, 0.9), 90.0, 0.72, true)
	Kit.put(root, "chair", Vector3(-0.02, FY, 0.55), -90.0, 0.75, true)
	# второй стул — у северного торца стола: у восточной стороны он перекрывал дверь из тамбура
	Kit.put(root, "chairw", Vector3(0.8, FY, -0.35), 0.0, 1.0, true)
	var ty := FY + 0.695
	var lant := Kit.put(root, "lantern", Vector3(0.62, ty, 0.3), 20.0, 1.0, false, false)
	w.things["lantern"] = lant
	var ll := Kit.omni(root, Vector3(0.62, ty + 0.22, 0.3), Color(1.0, 0.62, 0.25), 0.0, 5.0, true, 30.0)
	ll.visible = false
	w.things["lantern_light"] = ll
	w.things["lantern_it"] = Interactable.make(root, Vector3(0.62, ty + 0.15, 0.3), Vector3(0.22, 0.34, 0.22), "Зажечь лампу", func() -> void: G.act("lantern"))
	Kit.put(root, "journal", Vector3(0.82, ty, 0.82), 80.0, 1.0, false, false)
	w.things["journal"] = Interactable.make(root, Vector3(0.82, ty + 0.05, 0.82), Vector3(0.36, 0.14, 0.5), "Журнал станции", func() -> void: G.act("journal"))
	w.things["note_gr1"] = Props.paper(root, Vector3(0.56, ty + 0.004, 1.22), 25.0, "gr1", true, Vector2(0.17, 0.24), true)
	var chess := Kit.put(root, "chess", Vector3(0.9, ty, 1.52), 0.0, 0.52, false, false)
	Kit.lighten(chess, 0.35)
	w.things["chess"] = chess
	Kit.put(root, "thermos", Vector3(1.05, ty, 0.3), 0.0, 1.0, false, false)
	# буфет у северной стены, справа от окна
	Kit.put(root, "cabinet", Vector3(1.28, FY, -2.75), 0.0, 1.0, true)
	var cy := FY + 1.18
	Kit.put(root, "mclock", Vector3(1.3, cy, -2.8), 0.0, 1.0, false, false)
	w.things["clock_snd"] = Snd.emitter("clock_loop", root, Vector3(1.3, cy + 0.1, -2.8), -14.0, 7.0, 1.2)
	Kit.put(root, "pot", Vector3(0.88, cy, -2.74), 0.0, 1.0, false, false)
	for i in 3:
		Kit.put(root, "cans", Vector3(1.62 + i * 0.045, cy, -2.7 - i * 0.07), i * 40.0, 1.0, false, false)
	# стеллаж с книгами у южной стены, слева от окна
	Kit.put(root, "bookshelf", Vector3(-1.2, FY, 2.78), 180.0, 0.92, true)
	for sy in [0.52, 0.92, 1.3]:
		var bk := Kit.put(root, "books", Vector3(-1.35, FY + sy, 2.8), 180.0, 1.0, false, false)
		Kit.lighten(bk, 0.3)
	# на стенах: схема станции, календарь, памятка
	var mapq := Kit.quad_node(root, Vector3(1.1, 1.5, 3.094), Vector2(0.8, 0.8), Kit.img("res://tex/map"), Kit.yaw(180))
	w.things["wallmap"] = Interactable.make(root, Vector3(1.1, 1.5, 3.0), Vector3(0.9, 0.64, 0.2), "Схема станции", func() -> void: G.act("wallmap"))
	mapq.name = "WallMap"
	Kit.quad_node(root, Vector3(-0.95, 1.55, -3.094), Vector2(0.3, 0.42), Kit.img("res://tex/calendar"))
	var memo := Props.paper(root, Vector3(1.936, 1.5, 0.72), -90.0, "memo", false, Vector2(0.26, 0.36))
	w.things["note_memo"] = memo


static func _radio_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(-3.4, H, -1.5), 1.0, 4.5)
	# стол радиста у западной стены, под окном
	Kit.put(root, "desk", Vector3(-4.5, FY, -1.6), 90.0, Vector3(0.85, 1.0, 0.78), true)
	var ty := FY + 0.79
	var radio := Kit.put(root, "radio", Vector3(-4.58, ty, -1.82), 90.0, 1.0, false, false)
	Kit.lighten(radio, 0.5)
	Kit.put(root, "rxpanel", Vector3(-4.66, ty, -1.05), 90.0, 1.0, false, false)
	Kit.put(root, "meter", Vector3(-4.62, ty, -0.62), 70.0, 1.0, false, false)
	var dl := Kit.put(root, "desklamp", Vector3(-4.72, ty, -2.42), 135.0, 0.7, false, false)
	Kit.lighten(dl, 0.4)
	var dll := Kit.omni(root, Vector3(-4.45, ty + 0.42, -2.2), Color(1.0, 0.82, 0.55), 0.7, 2.6, false, 30.0)
	w.reg_light(dll)
	# ключ Морзе: дощечка, рычаг, головка
	var brass := Kit.flat(Color(0.55, 0.45, 0.2), 0.4, 0.8)
	b.box(Vector3(-4.3, ty + 0.012, -1.45), Vector3(0.09, 0.024, 0.16), Kit.flat(Color(0.12, 0.1, 0.08), 0.6), false)
	b.box(Vector3(-4.3, ty + 0.045, -1.45), Vector3(0.016, 0.012, 0.14), brass, false)
	b.cyl(Vector3(-4.3, ty + 0.062, -1.39), 0.02, 0.014, Kit.flat(Color(0.05, 0.05, 0.05), 0.5), 10, false)
	w.things["radio"] = Interactable.make(root, Vector3(-4.5, ty + 0.25, -1.65), Vector3(0.7, 0.6, 1.1), "Сесть за радио", func() -> void: G.act("radio"))
	w.things["radio_snd"] = Snd.emitter("radio_static", root, Vector3(-4.58, ty + 0.2, -1.82), -80.0, 14.0, 1.5)
	Kit.put(root, "chairw", Vector3(-3.78, FY, -1.62), -90.0, 1.0, true)
	w.things["note_radiogram"] = Props.paper(root, Vector3(-4.28, ty + 0.004, -1.12), 80.0, "radiogram", true, Vector2(0.2, 0.15))
	w.things["note_gr2"] = Props.paper(root, Vector3(-4.3, ty + 0.004, -2.12), 100.0, "gr2", true, Vector2(0.17, 0.24), true)
	w.things["note_freq"] = Props.paper(root, Vector3(-4.894, 1.42, -0.62), 90.0, "freq", false, Vector2(0.22, 0.3))
	# отпечаток ладони на стекле изнутри (появляется на третью ночь)
	var hp := Kit.quad_node(root, Vector3(-4.975, 1.5, -1.38), Vector2(0.17, 0.23), Kit.img("res://tex/handprint", true), Kit.yaw(90))
	hp.visible = false
	w.things["handprint"] = hp
	# картотека сводок
	Kit.put(root, "drawers", Vector3(-3.0, FY, -2.84), 0.0, 1.0, true)
	Kit.put(root, "binoc", Vector3(-3.25, FY + 1.88, -2.84), 30.0, 1.0, false, false)


static func _bunk_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(3.3, H, -1.4), 0.9, 4.5)
	# моя койка у восточной стены, головой на юг
	Kit.lighten(Kit.put(root, "bed", Vector3(4.4, FY, -1.15), 180.0, 1.0, true), 0.5)
	Props.bedding(root, Vector3(4.4, FY, -1.15), 180.0, false)
	w.things["bed"] = Interactable.make(root, Vector3(4.4, 0.6, -1.15), Vector3(0.95, 0.7, 1.9), "Лечь спать", func() -> void: G.act("bed"))
	# койка Громова у северной стены — заправлена
	Kit.lighten(Kit.put(root, "bed", Vector3(3.2, FY, -2.62), 90.0, 1.0, true), 0.5)
	w.things["gromov_bed"] = Props.bedding(root, Vector3(3.2, FY, -2.62), 90.0, true)
	# та же койка, но на ней кто-то лежал: одеяло сбито, на матрасе иней
	var used := Props.bedding(root, Vector3(3.2, FY, -2.62), 90.0, false)
	# иней на матрасе — по форме лежавшего тела
	var frost := Kit.flat(Color(0.82, 0.88, 0.95), 0.5)
	Kit.sphere_node(used, Vector3(-0.05, 0.485, -0.05), 1.0, frost, Vector3(0.24, 0.012, 0.74), 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.sphere_node(used, Vector3(-0.05, 0.5, -0.74), 1.0, frost, Vector3(0.12, 0.012, 0.13), 10).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	used.visible = false
	w.things["gromov_bed_used"] = used
	# тумбочка Громова
	Kit.put(root, "nstand", Vector3(2.36, FY, -0.4), 90.0, 1.0, true)
	Kit.put(root, "alarm", Vector3(2.34, FY + 0.62, -0.3), 110.0, 1.0, false, false)
	w.things["nstand"] = Interactable.make(root, Vector3(2.36, 0.4, -0.4), Vector3(0.55, 0.7, 0.55), "Тумбочка Громова", func() -> void: G.act("nstand"))
	Kit.put(root, "stool", Vector3(3.62, FY, -0.42), 0.0, 1.0, true)
	Kit.put(root, "sigflash", Vector3(3.62, FY + 0.58, -0.42), 40.0, 1.0, false, false)
	var pc := Kit.place(root, "postcards", Vector3(4.89, 1.55, -1.5), -90.0, 0.8, false, false)
	if pc != null:
		pc.position = Vector3(4.89 - 0.22 * 0.8, 1.55, -1.5 - 0.3)


static func _store_room(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(-3.4, H, 1.6), 0.7, 4.5)
	Kit.put(root, "rack", Vector3(-4.56, FY, 0.72), 90.0, 1.0, true)
	Kit.put(root, "rack", Vector3(-4.56, FY, 1.72), 90.0, 1.0, true)
	Kit.put(root, "shelves", Vector3(-3.3, FY, 2.8), 180.0, 0.1, true)
	Kit.put(root, "mcrate", Vector3(-2.9, FY, 0.42), 0.0, 1.0, true)
	Kit.put(root, "crate1", Vector3(-2.95, FY + 0.46, 0.42), 8.0, 1.0, false)
	Kit.put(root, "toolbox", Vector3(-4.55, FY + 0.98, 0.7), 80.0, 1.0, false, false)
	Kit.put(root, "medbox", Vector3(-4.55, FY + 1.42, 1.7), 90.0, 1.0, false, false)
	Kit.put(root, "gastank", Vector3(-4.6, FY, 2.72), 0.0, 1.0, true)
	for i in 4:
		Kit.put(root, "oiltin", Vector3(-4.56, FY + 0.5, 1.45 + i * 0.17), i * 25.0, 1.0, false, false)
	for i in 6:
		Kit.put(root, "cans", Vector3(-3.6 + (i % 3) * 0.2, FY + 1.02 + (i / 3) * 0.44, 2.78), i * 33.0, 1.3, false, false)
	Kit.put(root, "ammobox", Vector3(-3.0, FY + 0.56, 2.8), 90.0, 1.0, false, false)
	# моток запасного кабеля на стеллаже
	var cable := Node3D.new()
	cable.position = Vector3(-4.52, FY + 1.0, 1.72)
	root.add_child(cable)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.11
	tm.outer_radius = 0.17
	tm.rings = 14
	tm.ring_segments = 6
	Kit.mesh_node(cable, tm, Vector3.ZERO, Kit.flat(Color(0.04, 0.04, 0.04), 0.5))
	w.things["cable"] = cable
	w.things["cable_it"] = Interactable.make(root, Vector3(-4.52, FY + 1.05, 1.72), Vector3(0.45, 0.3, 0.45), "Взять кабель", func() -> void: G.act("cable"))
	# пирамида для карабина — пустая
	var wood := Kit.flat(Color(0.3, 0.22, 0.14), 0.85)
	b.box(Vector3(-2.5, 1.05, 0.085), Vector3(0.5, 0.06, 0.05), wood, false)
	b.box(Vector3(-2.5, 0.25, 0.1), Vector3(0.5, 0.08, 0.1), wood, false)
	w.things["note_gr5"] = Props.paper(root, Vector3(-2.5, 1.32, 0.066), 0.0, "gr5", false, Vector2(0.15, 0.1), true)


static func _vestibule(w: World, root: Node3D, b: Batch) -> void:
	Props.ceil_lamp(w, root, Vector3(3.4, H, 1.6), 0.55, 4.0)
	Kit.put(root, "bench", Vector3(3.3, FY, 2.82), 180.0, 1.0, true)
	Kit.put(root, "boots", Vector3(4.3, FY, 2.6), 170.0, 1.0, false, false)
	Kit.put(root, "broom", Vector3(4.78, FY + 0.12, 0.2), 0.0, 1.0, false, false)
	var sp := Kit.place(root, "spade", Vector3(4.55, FY + 0.5, 0.16), 0.0, 1.0, false, false)
	if sp != null:
		sp.rotation.x = deg_to_rad(8)
	# ящик с дровами
	Kit.put(root, "crate2", Vector3(2.42, FY, 2.38), 0.0, 1.0, true)
	Props.logs(b, Vector3(2.24, FY + 0.46, 2.0), false, 3, 2, 0.5, 9)
	Props.logs(b, Vector3(2.24, FY + 0.46, 2.6), false, 3, 2, 0.5, 11)
	w.things["woodbox"] = Interactable.make(root, Vector3(2.42, 0.6, 2.38), Vector3(0.6, 0.6, 1.25), "Взять дрова", func() -> void: G.act("woodbox"))
	# вешалка: доска с крючками на северной перегородке
	var wood := Kit.flat(Color(0.3, 0.22, 0.14), 0.85)
	b.box(Vector3(3.5, 1.78, 0.085), Vector3(1.9, 0.1, 0.03), wood, false)
	for i in 4:
		b.box(Vector3(2.8 + i * 0.47, 1.76, 0.12), Vector3(0.02, 0.02, 0.07), Kit.flat(Color(0.1, 0.1, 0.1), 0.5, 0.6), false)
	Props.parka(root, Vector3(2.8, 1.74, 0.1), 0.0, Color(0.16, 0.2, 0.3))
	var gp := Props.parka(root, Vector3(3.74, 1.74, 0.1), 0.0, Color(0.95, 0.42, 0.1))
	gp.visible = false
	w.things["gromov_parka"] = gp
	var br := Kit.place(root, "breaker", Vector3(4.89, 1.5, 0.55), -90.0, 1.0, false, false)
	w.things["breaker"] = br


static func _outside(w: World, root: Node3D, b: Batch) -> void:
	var wood := Kit.mat("plankgrey", 1.5)
	# крыльцо и навес
	b.box(Vector3(5.75, -0.02, 1.6), Vector3(1.3, 0.1, 1.6), wood)
	b.box(Vector3(5.7, 2.34, 1.6), Vector3(1.25, 0.06, 1.7), Kit.mat("corrug", 2.0, Color(0.7, 0.72, 0.75)), false, Basis(Vector3.BACK, deg_to_rad(-9)))
	b.box(Vector3(5.72, 2.47, 1.6), Vector3(1.2, 0.16, 1.6), Kit.mat("snowcrust", 3.0), false, Basis(Vector3.BACK, deg_to_rad(-9)))
	b.box(Vector3(6.28, 1.12, 0.84), Vector3(0.08, 2.24, 0.08), wood)
	b.box(Vector3(6.28, 1.12, 2.36), Vector3(0.08, 2.24, 0.08), wood)
	# лампа над дверью
	Kit.place(root, "walllamp", Vector3(5.1, 2.12, 1.6), 90.0, 1.0, false, false)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(1.0, 0.9, 0.7)
	gm.emission_enabled = true
	gm.emission = Color(1.0, 0.75, 0.42)
	gm.emission_energy_multiplier = 3.0
	Kit.sphere_node(root, Vector3(5.2, 2.12, 1.6), 0.05, gm, Vector3(1, 1.6, 1), 8).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	w.reg_glow(gm)
	var l := Kit.omni(root, Vector3(5.6, 2.1, 1.6), Color(1.0, 0.76, 0.42), 2.4, 7.5, false, 70.0)
	w.reg_light(l)
	var hl := Kit.halo(root, Vector3(5.3, 2.12, 1.6), Color(1.0, 0.72, 0.38), 1.4, 1.6)
	w.reg_halo(hl)
	w.things["porch_halo"] = hl
	# дровяник у восточной стены: навес и поленница
	b.box(Vector3(5.75, 1.7, -2.1), Vector3(1.3, 0.05, 2.0), Kit.mat("corrugrust", 2.0, Color(0.5, 0.48, 0.48)), false, Basis(Vector3.BACK, deg_to_rad(-10)))
	b.box(Vector3(5.75, 1.82, -2.1), Vector3(1.25, 0.16, 1.9), Kit.mat("snowcrust", 3.0), false, Basis(Vector3.BACK, deg_to_rad(-10)))
	b.box(Vector3(6.32, 0.8, -3.02), Vector3(0.08, 1.6, 0.08), wood)
	b.box(Vector3(6.32, 0.8, -1.18), Vector3(0.08, 1.6, 0.08), wood)
	Props.logs(b, Vector3(5.42, 0.0, -2.95), true, 12, 7, 0.55, 21)
	b.solid(Vector3(5.45, 0.5, -2.1), Vector3(0.6, 1.0, 1.7))
	b.cyl(Vector3(6.05, 0.2, -1.35), 0.2, 0.4, Kit.flat(Color(0.25, 0.19, 0.13), 0.9), 10, true)
	var axe := Kit.place(root, "axe", Vector3(6.05, 0.58, -1.35), 30.0, 1.0, false, false)
	if axe != null:
		axe.rotation.z = deg_to_rad(155)
	w.things["woodpile"] = Interactable.make(root, Vector3(5.5, 0.6, -2.1), Vector3(0.8, 1.2, 1.9), "Взять дрова", func() -> void: G.act("woodpile"))
	# лыжи у стены, бочка, сугробы
	b.box(Vector3(5.14, 0.95, 2.95), Vector3(0.02, 1.9, 0.09), Kit.flat(Color(0.5, 0.3, 0.12), 0.6), false, Basis(Vector3.BACK, deg_to_rad(4)))
	b.box(Vector3(5.17, 0.95, 3.08), Vector3(0.02, 1.9, 0.09), Kit.flat(Color(0.5, 0.3, 0.12), 0.6), false, Basis(Vector3.BACK, deg_to_rad(6)))
	Kit.put(root, "drumblue", Vector3(5.6, 0.0, 3.9), 20.0, 1.0, true)
	# сугробы намело к стенам снаружи (с наветренной, северо-западной стороны — выше)
	Props.drift_wall(root, Vector3(-5.11, -0.02, -0.8), Vector3(-1, 0, 0), Vector3(4.6, 1.1, 2.0))
	Props.drift_wall(root, Vector3(-2.4, -0.02, -3.31), Vector3(0, 0, -1), Vector3(4.8, 0.95, 1.8))
	Props.drift_wall(root, Vector3(2.9, -0.02, -3.31), Vector3(0, 0, -1), Vector3(3.6, 0.6, 1.3))
	Props.drift_wall(root, Vector3(-3.6, -0.02, 3.31), Vector3(0, 0, 1), Vector3(3.0, 0.4, 1.2))
	Props.drift_wall(root, Vector3(1.6, -0.02, 3.31), Vector3(0, 0, 1), Vector3(3.6, 0.3, 1.0))
