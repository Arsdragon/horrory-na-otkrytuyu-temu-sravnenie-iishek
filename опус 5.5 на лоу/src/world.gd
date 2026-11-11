extends Node3D
## Строит пятиэтажку кодом. Этаж L: пол на y=3L. Коридор x 0..24, z 5..7. Квартиры: юг z 0..5, север z 7..12,
## по две с каждой стороны (x 0..12 и 12..24). Подъезд x -4..0: площадка z 5..7, марши-пандусы z 7..11, полуплощадка z 11..12.

const LEVELS := 5
const H := 3.0
const NOTES := [
	["Записка на холодильнике, кв. 3", "Валера, не включай свет в коридоре. Оно идёт на свет. Я в шкафу у мамы. Не стучи, я не открою.\n— Н."],
	["Тетрадный лист, кв. 8", "Седьмой день. Вода из крана идёт тёплая и пахнет торфом. Ночью кто-то ходит по потолку — шаркает, как дед в тапках. Дед умер в мае."],
	["Объявление в подъезде", "ЖИЛЬЦЫ! Кто брал ключ от подвала — верните. Из подвала дует. Не спускайтесь туда после пожара.\nДомком."],
	["Детский рисунок, кв. 12", "(Высокий дядя в халате, голова висит. Подпись карандашом:) ДЯДЯ БЕЗ ЛИЦА СЛЫШИТ КОГДА ДЫШИШЬ"],
	["Квитанция с припиской, кв. 15", "Расход за октябрь: 0 кВт·ч. На обороте: «Если сидеть тихо — он стоит у шкафа и ждёт. Долго. Потом уходит. Не выходи сразу»."],
	["Последняя страница журнала, кв. 19", "Он не злой. Он жилец. Он ищет, кто ещё не спит. Все уже легли в шкафы. Я тоже лягу. Пусть контролёр закроет нам счёт."],
]

var meters: Array = []      # StaticBody3D, meta kind=meter
var wardrobes: Array = []
var batteries: Array = []
var notes: Array = []
var glass: Array = []       # Vector3
var bulbs: Array = []       # [OmniLight3D, base_energy, level, stair:bool]
var exit_door: Node3D
var astar := AStar3D.new()
var _wp := 0
var _rng := RandomNumberGenerator.new()
var m_wall; var m_floor; var m_ceil; var m_conc; var m_wood; var m_dark

func build(seed_val := 1994) -> void:
	_rng.seed = seed_val
	m_wall = G.mat("wall", 0.33)
	m_floor = G.mat("floor", 0.5)
	m_ceil = G.mat("ceiling", 0.4)
	m_conc = G.mat("concrete", 0.4)
	m_wood = G.mat("wood", 0.6)
	m_dark = G.mat("wood", 0.6, Color(0.35, 0.3, 0.28))
	for L in LEVELS:
		_level(L)
	box(Vector3(10, LEVELS * H + 0.1, 6), Vector3(28.4, 0.2, 12.4), m_ceil)  # крыша
	box(Vector3(-2, -0.1, 8.5), Vector3(4, 0.2, 7), m_conc)  # пол подъезда 1 эт.
	exit_door = box(Vector3(24, 1.05, 6), Vector3(0.15, 2.1, 1.6), G.mat("wood", 0.6, Color(0.4, 0.35, 0.3)))
	exit_door.set_meta("kind", "exit")
	_place_items()
	_waypoints()

# ---------------------------------------------------------------- геометрия
func box(pos: Vector3, size: Vector3, m: Material, col := true, rot := Vector3.ZERO, layer := 1) -> Node3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	if not col:
		mi.position = pos
		mi.rotation = rot
		add_child(mi)
		return mi
	var sb := StaticBody3D.new()
	sb.collision_layer = layer
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.add_child(mi)
	sb.position = pos
	sb.rotation = rot
	add_child(sb)
	return sb

func wall_x(x1: float, x2: float, z: float, y0: float, gaps: Array, m: Material) -> void:
	var cur := x1
	for g in gaps:
		if g[0] > cur: box(Vector3((cur + g[0]) / 2, y0 + H / 2, z), Vector3(g[0] - cur, H, 0.2), m)
		box(Vector3((g[0] + g[1]) / 2, y0 + 2.55, z), Vector3(g[1] - g[0], 0.9, 0.2), m)
		cur = g[1]
	if x2 > cur: box(Vector3((cur + x2) / 2, y0 + H / 2, z), Vector3(x2 - cur, H, 0.2), m)

func wall_z(z1: float, z2: float, x: float, y0: float, gaps: Array, m: Material) -> void:
	var cur := z1
	for g in gaps:
		if g[0] > cur: box(Vector3(x, y0 + H / 2, (cur + g[0]) / 2), Vector3(0.2, H, g[0] - cur), m)
		box(Vector3(x, y0 + 2.55, (g[0] + g[1]) / 2), Vector3(0.2, 0.9, g[1] - g[0]), m)
		cur = g[1]
	if z2 > cur: box(Vector3(x, y0 + H / 2, (cur + z2) / 2), Vector3(0.2, H, z2 - cur), m)

func _level(L: int) -> void:
	var y0 := L * H
	box(Vector3(12, y0 - 0.05, 6), Vector3(24, 0.1, 12), m_floor)
	if L > 0: box(Vector3(12, y0 - 0.16, 6), Vector3(24, 0.12, 12), m_ceil, false)
	# коридор
	var doors := [[9.0, 10.2], [21.0, 22.2]]
	wall_x(0, 24, 5, y0, doors, m_wall)
	wall_x(0, 24, 7, y0, doors, m_wall)
	# стены квартир
	for z in [[0.0, 5.0, [[1.0, 2.2]]], [7.0, 12.0, [[9.8, 11.0]]]]:
		wall_z(z[0], z[1], 12, y0, [], m_wall)
		wall_z(z[0], z[1], 6, y0, z[2], m_wall)
		wall_z(z[0], z[1], 18, y0, z[2], m_wall)
		wall_z(z[0], z[1], 0, y0, [], m_wall)
	wall_x(-4, 24, 0, y0, [], m_wall)
	wall_x(-4, 24, 12, y0, [], m_wall)
	wall_z(0, 12, -4, y0, [], m_conc)
	if L == 0: wall_z(0, 12, 24, y0, [[5.2, 6.8]], m_wall)
	else: wall_z(0, 12, 24, y0, [], m_wall)
	# подъезд
	wall_x(-4, 0, 5, y0, [], m_conc)
	box(Vector3(-2, y0 - 0.1, 6), Vector3(4, 0.2, 2), m_conc)  # площадка
	box(Vector3(-2, y0 + H / 2, 9), Vector3(0.15, H, 4), m_conc)  # стенка между маршами
	if L < LEVELS - 1:
		var ang := atan2(1.5, 4.0)
		var ln := sqrt(16.0 + 2.25)
		box(Vector3(-3, y0 + 0.75 - 0.1, 9), Vector3(2, 0.2, ln), m_conc, true, Vector3(-ang, 0, 0))
		box(Vector3(-2, y0 + 1.5 - 0.1, 11.5), Vector3(4, 0.2, 1.0), m_conc)
		box(Vector3(-1, y0 + 2.25 - 0.1, 9), Vector3(2, 0.2, ln), m_conc, true, Vector3(ang, 0, 0))
	else:
		box(Vector3(-3, y0 + 1, 7.2), Vector3(2, 2, 0.2), m_conc)  # тупик наверху
	# окна (лунный свет сквозь мутное стекло)
	var win := StandardMaterial3D.new()
	win.albedo_color = Color(0.05, 0.06, 0.08)
	win.emission_enabled = true
	win.emission = Color(0.25, 0.32, 0.45)
	win.emission_energy_multiplier = 0.25
	for wx in [3.0, 9.0, 15.0, 21.0]:
		box(Vector3(wx, y0 + 1.6, 0.11), Vector3(1.3, 1.4, 0.02), win, false)
		box(Vector3(wx, y0 + 1.6, 11.89), Vector3(1.3, 1.4, 0.02), win, false)
	box(Vector3(-2, y0 + 2.3, 11.89), Vector3(1.0, 0.8, 0.02), win, false)
	# лампочки: подъезд и коридор
	_bulb(Vector3(-2, y0 + 2.7, 6), L, true)
	if L % 2 == 0: _bulb(Vector3(16, y0 + 2.7, 6), L, false)
	# квартиры
	for side in [0, 1]:
		for ax in [0.0, 12.0]:
			_apartment(L, ax, side)
	# хлам в коридоре
	for i in 3:
		var p := Vector3(_rng.randf_range(2, 22), y0, _rng.randf_range(5.6, 6.4))
		if _rng.randf() < 0.55:
			_glass(p)
		else:  # ящик у стены, не на пути
			var cz := 5.32 if _rng.randf() < 0.5 else 6.68
			box(Vector3(p.x, y0 + 0.2, cz), Vector3(0.5, 0.4, 0.4), G.mat("wood", 0.6, Color(0.5, 0.45, 0.35)), true, Vector3(0, _rng.randf_range(-0.3, 0.3), 0))

func _bulb(p: Vector3, L: int, stair: bool) -> void:
	var o := OmniLight3D.new()
	o.position = p
	o.light_color = Color(1.0, 0.75, 0.45)
	o.light_energy = 0.6 if stair else 0.4
	o.omni_range = 6.5
	o.omni_attenuation = 1.4
	add_child(o)
	var bm := SphereMesh.new()
	bm.radius = 0.06; bm.height = 0.12
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	var em := StandardMaterial3D.new()
	em.emission_enabled = true
	em.emission = Color(1, 0.8, 0.5)
	em.emission_energy_multiplier = 3.0
	mi.material_override = em
	o.add_child(mi)
	bulbs.append([o, o.light_energy, L, stair, mi])

func _glass(p: Vector3) -> void:
	glass.append(p)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.6, 0.7, 0.7, 0.7)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.metallic = 0.6
	gm.roughness = 0.1
	for i in 7:
		box(p + Vector3(_rng.randf_range(-0.5, 0.5), 0.01, _rng.randf_range(-0.4, 0.4)),
			Vector3(_rng.randf_range(0.05, 0.18), 0.01, _rng.randf_range(0.05, 0.15)), gm, false, Vector3(0, _rng.randf() * 3, 0))

var _apts: Array = []   # [L, ax, side, front_center, back_center, meter_pos, wall_dir]

func _apartment(L: int, ax: float, side: int) -> void:
	var y0 := L * H
	var outer_z := 0.0 if side == 0 else 12.0
	var dz := 1.0 if side == 0 else -1.0  # направление от внешней стены внутрь
	# шкаф (укрытие) в дальней комнате у внешней стены
	var wpos := Vector3(ax + 2.5, y0, outer_z + dz * 0.42)
	_wardrobe(wpos, dz)
	# кровать
	box(Vector3(ax + 1.0, y0 + 0.25, outer_z + dz * 3.4), Vector3(1.0, 0.5, 2.0), G.mat("robe", 1.0, Color(0.6, 0.6, 0.6)))
	# стол, стул
	box(Vector3(ax + 9.5, y0 + 0.38, outer_z + dz * 1.0), Vector3(1.2, 0.76, 0.8), m_wood)
	box(Vector3(ax + 8.6, y0 + 0.23, outer_z + dz * 1.6), Vector3(0.45, 0.46, 0.45), m_dark, true, Vector3(0, _rng.randf_range(-0.6, 0.6), 0))
	# телевизор / тумба
	if _rng.randf() < 0.6:
		box(Vector3(ax + 7.0, y0 + 0.35, outer_z + dz * 0.4), Vector3(0.9, 0.7, 0.5), m_dark)
		var tv := box(Vector3(ax + 7.0, y0 + 0.95, outer_z + dz * 0.45), Vector3(0.6, 0.5, 0.45), G.mat("", 1, Color(0.12, 0.12, 0.12)))
		tv.rotation.y = 0
	# опрокинутый стул
	if _rng.randf() < 0.5:
		box(Vector3(ax + 4.0, y0 + 0.22, outer_z + dz * 2.5), Vector3(0.45, 0.45, 0.45), m_dark, true, Vector3(PI / 2, _rng.randf() * 3, 0))
	var front := Vector3(ax + 9.0, y0, 2.5 if side == 0 else 9.5)
	var back := Vector3(ax + 3.0, y0, 2.5 if side == 0 else 9.5)
	# место для щитка: на стене коридора изнутри, слева от двери
	var mz := 4.88 if side == 0 else 7.12
	var meter := Vector3(ax + 7.6, y0 + 1.5, mz)
	_apts.append([L, ax, side, front, back, meter, -dz])

func _wardrobe(p: Vector3, dz: float) -> void:
	var w := box(p + Vector3(0, 1.05, 0), Vector3(1.2, 2.1, 0.62), m_wood)
	w.set_meta("kind", "wardrobe")
	w.set_meta("inside", p + Vector3(0, 1.45, 0))
	w.set_meta("front", p + Vector3(0, 0, dz * 1.0))
	w.set_meta("yaw", 0.0 if dz < 0 else PI)
	# щель между створками
	box(p + Vector3(0, 1.05, dz * 0.315), Vector3(0.02, 2.0, 0.01), G.mat("", 1, Color(0, 0, 0)), false)
	box(p + Vector3(0.08, 1.1, dz * 0.33), Vector3(0.03, 0.15, 0.03), G.mat("", 1, Color(0.6, 0.55, 0.3), 0.3), false)
	wardrobes.append(w)

func _place_items() -> void:
	var idx := range(_apts.size())
	# по 2 счётчика на этаж
	for L in LEVELS:
		var on_level := idx.filter(func(i): return _apts[i][0] == L)
		on_level.shuffle()
		for k in 2:
			_meter(_apts[on_level[k]])
	# батарейки и записки
	var pool := idx.duplicate()
	pool.shuffle()
	for i in 7:
		var a = _apts[pool[i]]
		var p: Vector3 = a[4] + Vector3(_rng.randf_range(-1, 1), 0.06, _rng.randf_range(-1, 1))
		var b := box(p, Vector3(0.08, 0.12, 0.08), G.mat("", 1, Color(0.2, 0.5, 0.25), 0.4), true, Vector3.ZERO, 2)
		var em := StandardMaterial3D.new()
		em.albedo_color = Color(0.25, 0.7, 0.3)
		em.emission_enabled = true
		em.emission = Color(0.1, 0.4, 0.15)
		(b.get_child(1) as MeshInstance3D).material_override = em
		b.set_meta("kind", "battery")
		batteries.append(b)
	for i in NOTES.size():
		var n: Node3D
		if i == 2:
			n = box(Vector3(-2.5, 1.5, 5.12), Vector3(0.32, 0.42, 0.02), G.mat("paper", 1.0), true, Vector3.ZERO, 2)
		else:
			var a = _apts[pool[(i * 3 + 7) % pool.size()]]
			n = box(Vector3(a[1] + 9.5, a[0] * H + 0.765, 1.0 if a[2] == 0 else 11.0), Vector3(0.3, 0.01, 0.22),
				G.mat("paper", 1.0), true, Vector3(0, _rng.randf_range(-0.4, 0.4), 0), 2)
		n.set_meta("kind", "note")
		n.set_meta("id", i)
		notes.append(n)

func _meter(a: Array) -> void:
	var p: Vector3 = a[5]
	var d: float = a[6]
	var m := box(p + Vector3(0, 0, d * 0.09), Vector3(0.45, 0.6, 0.16), G.mat("concrete", 1.0, Color(0.5, 0.55, 0.5), 0.6), true, Vector3.ZERO, 3)
	m.set_meta("kind", "meter")
	m.set_meta("read", false)
	m.set_meta("level", a[0])
	# стеклянное окошко с цифрами
	var face := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.28, 0.12)
	face.mesh = qm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.85, 0.85, 0.75)
	fm.emission_enabled = true
	fm.emission = Color(0.15, 0.15, 0.1)
	face.material_override = fm
	face.position = Vector3(0, 0.1, d * 0.085)
	face.rotation.y = 0.0 if d > 0 else PI
	m.add_child(face)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1, 0.2, 0.1)
	lamp.light_energy = 0.25
	lamp.omni_range = 1.3
	lamp.position = Vector3(0.15, -0.15, d * 0.15)
	m.add_child(lamp)
	m.set_meta("lamp", lamp)
	meters.append(m)

# ---------------------------------------------------------------- граф для Жильца
func _p(v: Vector3) -> int:
	var id := _wp
	astar.add_point(id, v + Vector3(0, 0.1, 0))
	_wp += 1
	return id

func _waypoints() -> void:
	var land_a := []; var land_b := []
	for L in LEVELS:
		var y0 := L * H
		var xs := [0.6, 3.0, 6.0, 9.6, 12.0, 15.0, 18.0, 21.6, 23.2]
		var cor := []
		for x in xs: cor.append(_p(Vector3(x, y0, 6)))
		for i in range(1, cor.size()): astar.connect_points(cor[i - 1], cor[i])
		var land := _p(Vector3(-2, y0, 6))
		astar.connect_points(land, cor[0])
		var a := _p(Vector3(-3, y0, 6.4)); var b := _p(Vector3(-1, y0, 6.4))
		astar.connect_points(land, a); astar.connect_points(land, b)
		land_a.append(a); land_b.append(b)
		for side in [0, 1]:
			for k in 2:
				var ax := 12.0 * k
				var c: int = cor[3] if k == 0 else cor[7]
				var zf := 1.0 if side == 0 else -1.0
				var door := _p(Vector3(ax + 9.6, y0, 6 - zf * 1.5))
				var fr := _p(Vector3(ax + 9.0, y0, 6 - zf * 3.5))
				var gap := _p(Vector3(ax + 6.0, y0, 1.6 if side == 0 else 10.4))
				var bk := _p(Vector3(ax + 3.0, y0, 2.6 if side == 0 else 9.4))
				astar.connect_points(c, door); astar.connect_points(door, fr)
				astar.connect_points(fr, gap); astar.connect_points(gap, bk)
	for L in LEVELS - 1:
		var y0 := L * H
		var ha := _p(Vector3(-3, y0 + 1.5, 11.5)); var hb := _p(Vector3(-1, y0 + 1.5, 11.5))
		astar.connect_points(land_a[L], ha); astar.connect_points(ha, hb)
		astar.connect_points(hb, land_b[L + 1])

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	return astar.get_point_path(a, b)

func random_point() -> Vector3:
	return astar.get_point_position(_rng.randi_range(0, _wp - 1))

func level_of(p: Vector3) -> int:
	return clampi(int(floor((p.y + 0.5) / H)), 0, LEVELS - 1)
