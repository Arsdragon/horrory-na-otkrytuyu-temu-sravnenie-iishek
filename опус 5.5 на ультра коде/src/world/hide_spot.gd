class_name HideSpot
extends StaticBody3D
## Где спрятаться: служебный шкафчик (видно в щели) или под нижним полком парилки.
## Если Хозяйка слышала, как ты прятался, — она вскроет именно это место.

var kind := "locker"
var door_pivot: Node3D
var inside := false
var face_yaw := 0.0
var slats: MeshInstance3D


static func make_locker(parent: Node3D, pos: Vector3, yaw: float) -> HideSpot:
	var h := HideSpot.new()
	h.kind = "locker"
	h.collision_layer = 1 | 8
	h.collision_mask = 0
	parent.add_child(h)
	h.global_position = pos
	h.rotation.y = yaw
	h.face_yaw = yaw
	h._build_locker()
	return h


static func make_bench(parent: Node3D, pos: Vector3, yaw: float) -> HideSpot:
	var h := HideSpot.new()
	h.kind = "bench"
	h.collision_layer = 8
	h.collision_mask = 0
	parent.add_child(h)
	h.global_position = pos
	h.rotation.y = yaw
	h.face_yaw = yaw
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.6, 0.35, 0.6)
	cs.shape = sh
	cs.position = Vector3(0, 0.2, 0)
	h.add_child(cs)
	return h


func _build_locker() -> void:
	var mat := Mat.m("metal_green", {"metal": 0.4, "tint": Color(0.75, 0.82, 0.78), "scale": 1.2})
	var dark := Mat.flat(Color(0.03, 0.03, 0.03), 0.9)
	var b := Geo.Batch.new()
	var W := 0.62
	var D := 0.55
	var H := 1.95
	# корпус (открыт спереди: перед — -Z)
	b.box(mat, Vector3(0, H * 0.5, D * 0.5 - 0.01), Vector3(W, H, 0.02))
	b.box(mat, Vector3(-W * 0.5, H * 0.5, 0), Vector3(0.02, H, D))
	b.box(mat, Vector3(W * 0.5, H * 0.5, 0), Vector3(0.02, H, D))
	b.box(mat, Vector3(0, H, 0), Vector3(W, 0.02, D))
	b.box(mat, Vector3(0, 0.05, 0), Vector3(W, 0.1, D))
	b.box(dark, Vector3(0, H * 0.5, D * 0.5 - 0.03), Vector3(W - 0.05, H - 0.1, 0.01))
	b.commit(self, "locker")
	for cs_def in [[Vector3(0, H * 0.5, D * 0.5 - 0.01), Vector3(W, H, 0.04)], [Vector3(-W * 0.5, H * 0.5, 0), Vector3(0.04, H, D)],
			[Vector3(W * 0.5, H * 0.5, 0), Vector3(0.04, H, D)]]:
		Geo.col_box(self, cs_def[0], cs_def[1])
	# дверца на петлях слева, с прорезями
	door_pivot = Node3D.new()
	door_pivot.position = Vector3(-W * 0.5, 0, -D * 0.5)
	add_child(door_pivot)
	var db := Geo.Batch.new()
	db.box(mat, Vector3(W * 0.5, H * 0.5 + 0.05, 0), Vector3(W - 0.02, H - 0.1, 0.02))
	for i in 5:
		db.box(dark, Vector3(W * 0.5, 1.45 + i * 0.045, -0.011), Vector3(W * 0.6, 0.018, 0.005))
	db.box(Mat.flat(Color(0.5, 0.5, 0.45), 0.4, 0.9), Vector3(W - 0.08, 1.05, -0.02), Vector3(0.03, 0.12, 0.02))
	db.commit(door_pivot, "door")
	var body := StaticBody3D.new()
	body.collision_layer = 8
	door_pivot.add_child(body)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(W, H, 0.05)
	cs.shape = sh
	cs.position = Vector3(W * 0.5, H * 0.5, 0)
	body.add_child(cs)
	body.set_meta("usable", self)


func get_prompt(_p: Node) -> String:
	if inside:
		return "Вылезти" if kind == "bench" else "Выйти из шкафчика"
	return "Залезть под полок" if kind == "bench" else "Спрятаться в шкафчик"


func eye_height() -> float:
	return 0.35 if kind == "bench" else 1.55


func use(p: Node) -> void:
	var pl := p as Player
	if inside:
		inside = false
		_door(true)
		var out := global_position + global_transform.basis * Vector3(0, 0.05, -0.75 if kind == "locker" else -0.8)
		pl.unhide(out)
		await get_tree().create_timer(0.35).timeout
		_door(false)
		return
	inside = true
	_door(true)
	await get_tree().create_timer(0.25).timeout
	var pos := global_position + global_transform.basis * Vector3(0, 0.05, 0.02)
	if kind == "bench":
		pos = global_position + Vector3(0, -0.4, 0)
	pl.hide_in(self, pos, face_yaw + PI)
	pl.set_look(face_yaw + PI, deg_to_rad(-8) if kind == "bench" else 0.0)
	_door(false)
	if Game.main and Game.main.has_method("set_slats"):
		Game.main.set_slats(kind)


func _door(open: bool) -> void:
	if door_pivot == null:
		return
	var t := create_tween()
	t.tween_property(door_pivot, "rotation:y", deg_to_rad(-100) if open else 0.0, 0.25)
	Snd.at("locker_open" if open else "locker_close", global_position + Vector3.UP, -4.0, randf_range(0.9, 1.1))


## Хозяйка вскрывает укрытие.
func monster_open(m: Node) -> void:
	_door(true)
	Snd.at("locker_rip", global_position + Vector3.UP, 4.0)
	if inside and Game.player and Game.player.hidden_in == self:
		await get_tree().create_timer(0.3).timeout
		if m.has_method("kill"):
			inside = false
			Game.player.unhide(global_position + global_transform.basis * Vector3(0, 0.05, -0.6))
			m.kill()
	else:
		await get_tree().create_timer(1.2).timeout
		_door(false)
