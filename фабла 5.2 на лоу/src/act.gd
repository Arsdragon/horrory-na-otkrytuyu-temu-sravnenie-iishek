class_name Act
extends StaticBody3D
## An interactable volume: the player's ray hits it (layer 2), shows prompt, calls use.

var prompt_fn: Callable
var use_fn: Callable
var hold: float = 0.0


static func make(parent: Node, pos: Vector3, size: Vector3, prompt: Callable, use: Callable, hold_time: float = 0.0) -> Act:
	var a := Act.new()
	a.collision_layer = 2
	a.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	a.position = pos
	a.prompt_fn = prompt
	a.use_fn = use
	a.hold = hold_time
	parent.add_child(a)
	return a


func prompt() -> String:
	return str(prompt_fn.call())
