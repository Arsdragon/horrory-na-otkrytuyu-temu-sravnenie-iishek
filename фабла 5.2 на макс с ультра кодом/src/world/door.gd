class_name Door
extends Node3D
## Дверь на петлях. Узел стоит в точке петли; закрытое полотно идёт вдоль локальной оси +X.

signal toggled(is_open: bool)
signal tried_locked

var is_open := false
var locked := false               # не открывается (сюжет)
var locked_text := "Заперто"
var barred := false               # засов изнутри
var width := 0.9
var height := 2.0
var thick := 0.05
var open_angle := 100.0           # градусы; знак — в какую сторону распахивается
var snd_open := "door_open"
var snd_close := "door_close"
var leaf: Node3D
var body: StaticBody3D
var shape: CollisionShape3D
var it: Interactable
var bar_mesh: Node3D = null
var _tw: Tween


static func make(parent: Node, hinge: Vector3, yaw_deg: float, w: float, h: float, m: Material, angle := 100.0, th := 0.05) -> Door:
	var d := Door.new()
	d.width = w
	d.height = h
	d.thick = th
	d.open_angle = angle
	d.transform = Transform3D(Kit.yaw(yaw_deg), hinge)
	parent.add_child(d)
	d._build(m)
	return d


func _build(m: Material) -> void:
	leaf = Node3D.new()
	add_child(leaf)
	# полотно собираем пакетом, чтобы текстура лежала в метрах
	var b := Batch.new()
	b.box(Vector3(width * 0.5, height * 0.5, 0), Vector3(width, height, thick), m, false, Basis.IDENTITY, true)
	var dark := Kit.flat(Color(0.1, 0.09, 0.08), 0.6, 0.6)
	# поперечины и ручка
	b.box(Vector3(width * 0.5, height * 0.22, thick * 0.5 + 0.008), Vector3(width, 0.09, 0.016), m, false)
	b.box(Vector3(width * 0.5, height * 0.8, thick * 0.5 + 0.008), Vector3(width, 0.09, 0.016), m, false)
	b.box(Vector3(width - 0.1, height * 0.5, thick * 0.5 + 0.035), Vector3(0.03, 0.16, 0.05), dark, false)
	b.box(Vector3(width - 0.1, height * 0.5, -thick * 0.5 - 0.035), Vector3(0.03, 0.16, 0.05), dark, false)
	b.commit(leaf, "Leaf")
	body = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	shape = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(width, height, maxf(thick, 0.08))
	shape.shape = sh
	shape.position = Vector3(width * 0.5, height * 0.5, 0)
	body.add_child(shape)
	leaf.add_child(body)
	it = Interactable.make(leaf, Vector3(width * 0.5, height * 0.5, 0), Vector3(width, height, 0.3), "Открыть", _on_use)


func _on_use() -> void:
	if not is_open and (locked or barred):
		tried_locked.emit()
		Snd.play_at("door_locked", global_position + Vector3(0, 1, 0), self, -4.0)
		if G.hud != null:
			G.hud.toast("Засов задвинут" if barred else locked_text)
		return
	set_open(not is_open)


func set_open(v: bool, instant := false, silent := false) -> void:
	if v == is_open and not instant:
		return
	is_open = v
	it.prompt = "Закрыть" if v else "Открыть"
	if _tw != null and _tw.is_valid():
		_tw.kill()
	var target := deg_to_rad(open_angle) if v else 0.0
	if instant:
		leaf.rotation.y = target
		shape.disabled = v
	else:
		shape.disabled = true
		_tw = create_tween()
		_tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tw.tween_property(leaf, "rotation:y", target, 0.55 if v else 0.42)
		_tw.tween_callback(func() -> void: shape.disabled = is_open)
		if not silent:
			Snd.play_at(snd_open if v else snd_close, global_position + Vector3(0, 1, 0), self, -3.0)
	toggled.emit(v)


## Засов: брус поперёк двери с внутренней стороны (inner_side: +1 или −1 по локальной оси Z).
func add_bar(inner_side: float) -> void:
	bar_mesh = Node3D.new()
	add_child(bar_mesh)
	var wood := Kit.flat(Color(0.3, 0.22, 0.14), 0.85)
	var iron := Kit.flat(Color(0.12, 0.11, 0.1), 0.5, 0.7)
	Kit.box_node(bar_mesh, Vector3(width * 0.5, 1.05, inner_side * (thick * 0.5 + 0.06)), Vector3(width + 0.36, 0.1, 0.06), wood)
	Kit.box_node(bar_mesh, Vector3(-0.1, 1.05, inner_side * (thick * 0.5 + 0.05)), Vector3(0.05, 0.2, 0.1), iron)
	Kit.box_node(bar_mesh, Vector3(width + 0.1, 1.05, inner_side * (thick * 0.5 + 0.05)), Vector3(0.05, 0.2, 0.1), iron)
	bar_mesh.visible = barred


func set_barred(v: bool, silent := false) -> void:
	barred = v
	if bar_mesh != null:
		bar_mesh.visible = v
	if not silent:
		Snd.play_at("latch", global_position + Vector3(0, 1, 0), self, -2.0)
