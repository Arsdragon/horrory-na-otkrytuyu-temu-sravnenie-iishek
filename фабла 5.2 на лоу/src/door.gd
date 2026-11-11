class_name Door
extends Node3D
## Hinged door. Node origin = hinge, leaf extends along local +X.

var open: bool = false
var bolted: bool = false
var can_bolt: bool = false
var width: float = 0.9
var angle: float = 0.0
var open_angle: float = 1.75
var speed: float = 4.0
var leaf: Node3D
var title: String = "Дверь"


func setup(w: float, h: float, mat: Material, boltable: bool = false) -> void:
	width = w
	can_bolt = boltable
	leaf = Node3D.new()
	add_child(leaf)
	B.box(leaf, Vector3(w / 2.0, h / 2.0, 0), Vector3(w, h, 0.06), mat, true, 4)
	B.box(leaf, Vector3(w - 0.1, 1.0, 0.06), Vector3(0.04, 0.14, 0.06), B.col(Color(0.5, 0.45, 0.35), 0.4, 0.8), false)
	B.box(leaf, Vector3(w - 0.1, 1.0, -0.06), Vector3(0.04, 0.14, 0.06), B.col(Color(0.5, 0.45, 0.35), 0.4, 0.8), false)
	Act.make(leaf, Vector3(w / 2.0, h / 2.0, 0), Vector3(w, h, 0.16), _prompt, toggle)
	if boltable:
		var bm := B.box(leaf, Vector3(w - 0.2, 1.35, -0.07), Vector3(0.26, 0.07, 0.05), B.col(Color(0.25, 0.25, 0.27), 0.4, 0.9), false)
		bm.name = "Bolt"
		Act.make(leaf, Vector3(w - 0.2, 1.35, -0.09), Vector3(0.36, 0.2, 0.12), _bolt_prompt, toggle_bolt)


func _prompt() -> String:
	if bolted:
		return "Засов задвинут"
	return "[E] Закрыть" if open else "[E] Открыть"


func _bolt_prompt() -> String:
	if open:
		return ""
	return "[E] Отодвинуть засов" if bolted else "[E] Задвинуть засов"


func toggle() -> void:
	if bolted:
		Snd.play3d("bolt", global_position, -8.0, 12.0, 1.4)
		return
	set_open(not open)


func toggle_bolt() -> void:
	if open:
		return
	bolted = not bolted
	Snd.play3d("bolt", global_position, 0.0, 16.0)
	var b: Node3D = leaf.get_node("Bolt")
	b.position.x = width - (0.08 if bolted else 0.2)


func set_open(v: bool, slow: bool = false) -> void:
	if v == open:
		return
	open = v
	speed = 0.6 if slow else 4.0
	if v:
		Snd.play3d("creak" if slow else "door_open", center(), -2.0, 22.0)
	else:
		get_tree().create_timer(0.3).timeout.connect(func() -> void: Snd.play3d("door_close", center(), 0.0, 24.0))


func center() -> Vector3:
	return global_position + global_transform.basis.x * (width / 2.0) + Vector3(0, 1.0, 0)


func _process(dt: float) -> void:
	var target: float = open_angle if open else 0.0
	angle = move_toward(angle, target, dt * speed)
	leaf.rotation.y = angle
