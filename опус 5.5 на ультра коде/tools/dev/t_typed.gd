extends SceneTree
var w: Node = null
func _init():
	var n: Node = Node.new()
	n.set_meta("x", 1)
	var ok = true
	if false:
		n.foo()
		print(n.bar)
		n.bar += 1.0
		w.noise(Vector3.ZERO)
	var d := {"a": 1.0}
	var v: float = d["a"]
	print("compiled ok ", v)
	quit()
