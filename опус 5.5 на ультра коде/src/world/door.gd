class_name Door
extends Node3D
## Дверь на петлях. Состояния: открыта/закрыта, заперта (ключ, код, засов, заклинило).
## Хозяйка открывает незапертые двери и проходит сквозь запертые.

signal opened(by_monster: bool)

var id := ""
var kind := "wood"
var room_a := ""
var room_b := ""
var width := 1.0
var height := 2.1
var along_x := true
var leaves: Array = []      # [{pivot: Node3D, body: AnimatableBody3D, sign: float}]
var amount := 0.0
var target := 0.0
var swing := 1.0
var locked := false
var key := ""               # предмет-ключ
var code := ""              # кодовый замок
var lock_text := "Заперто."
var unlock_text := ""
var on_locked: Callable     # вызывается, когда игрок дёргает запертую дверь
var on_open: Callable
var max_angle := 100.0
var creak := "door_wood"
var slam_next := false
var last_by_monster := 0.0


func setup(pos: Vector3, ax: bool, w: float, h: float) -> void:
	along_x = ax
	width = w
	height = h
	position = pos
	if not along_x:
		rotation.y = PI * 0.5
	match kind:
		"wood":
			_leaf(-w * 0.5, w - 0.04, 1.0, _mat_wood())
		"wood2", "entrance":
			_leaf(-w * 0.5, w * 0.5 - 0.03, 1.0, _mat_wood())
			_leaf(w * 0.5, w * 0.5 - 0.03, -1.0, _mat_wood())
		"steel":
			_leaf(-w * 0.5, w - 0.04, 1.0, Mat.m("metal_green", {"metal": 0.3, "tint": Color(0.7, 0.75, 0.7)}))
			creak = "door_steel"
		"grate":
			_leaf(-w * 0.5, w - 0.04, 1.0, null)
			creak = "door_grate"
	_restore()


func _mat_wood() -> Material:
	if kind == "entrance":
		return Mat.m("planks_dark", {"tint": Color(0.75, 0.6, 0.5)})
	if room_a.ends_with("steam") or room_b.ends_with("steam") or room_b == "banya":
		return Mat.m("planks_dark", {"tint": Color(0.8, 0.65, 0.5)})
	return Mat.m("planks_weather", {"tint": Color(0.9, 0.88, 0.8)})


func _leaf(hinge_x: float, lw: float, sgn: float, mat: Material) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(hinge_x, 0, 0)
	add_child(pivot)
	var body := AnimatableBody3D.new()
	body.collision_layer = 4  # слой «двери»
	body.collision_mask = 0
	body.sync_to_physics = false
	pivot.add_child(body)
	body.set_meta("door", self)
	var th := 0.05
	var cx := sgn * (lw * 0.5 + 0.02)
	var h := height - 0.03
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(lw, h, th)
	cs.shape = sh
	cs.position = Vector3(cx, h * 0.5, 0)
	body.add_child(cs)
	var b := Geo.Batch.new()
	if kind == "grate":
		var bar := Mat.m("rust", {"metal": 0.7})
		var x0 := cx - lw * 0.5
		var x1 := cx + lw * 0.5
		b.box(bar, Vector3(cx, 0.05, 0), Vector3(lw, 0.05, 0.04))
		b.box(bar, Vector3(cx, h - 0.03, 0), Vector3(lw, 0.05, 0.04))
		b.box(bar, Vector3(cx, h * 0.5, 0), Vector3(lw, 0.04, 0.03))
		var n := int(lw / 0.12)
		for i in n + 1:
			var xx := lerpf(x0 + 0.02, x1 - 0.02, float(i) / n)
			b.cyl(bar, Vector3(xx, 0.03, 0), Vector3(xx, h - 0.03, 0), 0.012, 6)
		# висячий замок
		b.box(Mat.m("rust", {"metal": 0.8, "tint": Color(0.6, 0.6, 0.6)}), Vector3(x1 - 0.12, 1.05, -0.06), Vector3(0.07, 0.09, 0.03))
	else:
		b.box(mat, Vector3(cx, h * 0.5, 0), Vector3(lw, h, th))
		# филёнки
		var panel := mat
		if kind != "steel":
			b.box(panel, Vector3(cx, h * 0.72, 0), Vector3(lw * 0.7, h * 0.32, th + 0.02))
			b.box(panel, Vector3(cx, h * 0.27, 0), Vector3(lw * 0.7, h * 0.32, th + 0.02))
		# окошко в двери парилки / входа
		if room_a.ends_with("steam") or room_b.ends_with("steam") or kind == "entrance":
			var glass := Mat.flat(Color(0.12, 0.1, 0.08, 0.92), 0.15)
			b.box(glass, Vector3(cx, h * 0.72, 0), Vector3(lw * 0.45, 0.32 if kind != "entrance" else 0.6, th + 0.03))
		# ручка
		var hx := cx + sgn * (lw * 0.5 - 0.09)
		var hm := Mat.flat(Color(0.35, 0.33, 0.3), 0.4, 0.8)
		for zz in [-0.06, 0.06]:
			b.box(hm, Vector3(hx, 1.0, zz), Vector3(0.12, 0.025, 0.025))
		if kind == "steel":
			# кнопочный кодовый замок
			b.box(Mat.flat(Color(0.5, 0.5, 0.48), 0.35, 0.9), Vector3(hx, 1.25, 0.045), Vector3(0.08, 0.16, 0.025))
			b.box(Mat.flat(Color(0.5, 0.5, 0.48), 0.35, 0.9), Vector3(hx, 1.25, -0.045), Vector3(0.08, 0.16, 0.025))
	b.commit(body, "leaf")
	leaves.append({"pivot": pivot, "body": body, "sign": sgn})


func _restore() -> void:
	var st: Variant = Game.flags.get("door:" + id)
	if st == null:
		return
	match String(st):
		"open":
			locked = false
			set_open(1.0, true)
		"unlocked":
			locked = false
		"locked":
			locked = true


func save_state() -> void:
	Game.set_flag("door:" + id, "open" if target > 0.5 else ("locked" if locked else "unlocked"))


func is_open() -> bool:
	return amount > 0.45


func get_prompt(_p: Node) -> String:
	if target > 0.5:
		return "Закрыть"
	if locked:
		if key != "" and Game.has(key):
			return "Отпереть"
		if code != "":
			return "Набрать код"
		return "Открыть"
	return "Открыть"


func use(p: Node) -> void:
	if target > 0.5:
		set_open(0.0)
		save_state()
		return
	if locked:
		if key != "" and Game.has(key):
			locked = false
			Snd.at("unlock", global_position + Vector3.UP, -2.0)
			if unlock_text != "":
				Game.think(unlock_text)
		elif code != "":
			if Game.main and Game.main.has_method("open_code"):
				Game.main.open_code(self)
			return
		else:
			Snd.at("door_locked", global_position + Vector3.UP, -4.0, randf_range(0.9, 1.1))
			if on_locked.is_valid():
				on_locked.call()
			else:
				Game.think(lock_text, 3.0)
			return
	_swing_from(p.global_position if p is Node3D else global_position)
	set_open(1.0)
	save_state()
	if on_open.is_valid():
		on_open.call()


func code_ok() -> void:
	locked = false
	code = ""
	Snd.at("unlock", global_position + Vector3.UP, 0.0)
	save_state()


func _swing_from(from: Vector3) -> void:
	var local := to_local(from)
	swing = -1.0 if local.z > 0.0 else 1.0


func set_open(v: float, silent := false, by_monster := false) -> void:
	var was := target
	target = v
	if silent:
		amount = v
		_apply()
		return
	if v > was:
		Snd.at(creak if not by_monster else creak + "_slow", global_position + Vector3.UP * 1.2, 2.0 if by_monster else -3.0, randf_range(0.85, 1.05))
		if Game.world and not by_monster:
			Game.world.noise(global_position, 7.0, "door")
		opened.emit(by_monster)
	elif v < was:
		var slam := slam_next
		slam_next = false
		Snd.at("door_slam" if slam else creak + "_close", global_position + Vector3.UP * 1.2, 4.0 if slam else -4.0, randf_range(0.9, 1.05))
		if Game.world and slam:
			Game.world.noise(global_position, 15.0, "door")


## Хозяйка у двери: открывает, если не заперта.
func monster_pass(from: Vector3) -> void:
	if locked or target > 0.5:
		return
	if Time.get_ticks_msec() / 1000.0 - last_by_monster < 2.0:
		return
	last_by_monster = Time.get_ticks_msec() / 1000.0
	_swing_from(from)
	set_open(1.0, false, true)
	save_state()


func slam() -> void:
	slam_next = true
	set_open(0.0)
	save_state()


func _physics_process(delta: float) -> void:
	if absf(amount - target) < 0.001:
		return
	var speed := 1.6 if not slam_next else 4.0
	amount = move_toward(amount, target, delta * speed)
	_apply()


func _apply() -> void:
	var e := ease(amount, -1.8)
	for l in leaves:
		var pv: Node3D = l["pivot"]
		pv.rotation.y = deg_to_rad(max_angle) * e * float(l["sign"]) * swing * -1.0


## Центр проёма в мировых координатах.
func center() -> Vector3:
	return global_position + Vector3.UP * 1.0


## Нормаль проёма (в сторону room_b не гарантируется) — горизонтальная ось через проём.
func through_axis() -> Vector3:
	return global_transform.basis.z.normalized()
