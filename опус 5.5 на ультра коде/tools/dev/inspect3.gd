extends SceneTree
func _init():
	var root = Node3D.new()
	get_root().add_child(root)
	for id in DirAccess.get_directories_at("res://mdl/ph"):
		var path = "res://mdl/ph/%s/%s.gltf" % [id, id]
		if not ResourceLoader.exists(path):
			print(id, " НЕТ")
			continue
		var n = load(path).instantiate()
		root.add_child(n)
		var total = AABB()
		var cnt = 0
		for c in n.find_children("*", "MeshInstance3D", true, false):
			var a = c.global_transform * c.get_aabb()
			if cnt == 0: total = a
			else: total = total.merge(a)
			cnt += 1
		print("%-28s %s" % [id, str(total.size.snapped(Vector3(0.01, 0.01, 0.01)))])
		n.free()
	quit()
