extends SceneTree
## Габариты всех моделей mdl/*/m.gltf: размер, положение низа и центра, число треугольников.
##   godot --headless --path . --script tools/dev/aabb.gd

func _init() -> void:
	var names: PackedStringArray = DirAccess.get_directories_at("res://mdl")
	for nm in names:
		var p := "res://mdl/%s/m.gltf" % nm
		if not ResourceLoader.exists(p):
			continue
		var ps: PackedScene = load(p)
		var n: Node3D = ps.instantiate()
		var bb := AABB()
		var first := true
		var tris := 0
		var parts := 0
		for mi in _meshes(n):
			var m: MeshInstance3D = mi
			var t := _rel(m, n)
			var a := t * m.mesh.get_aabb()
			bb = a if first else bb.merge(a)
			first = false
			parts += 1
			for s in m.mesh.get_surface_count():
				var arr := m.mesh.surface_get_arrays(s)
				var idx: Variant = arr[Mesh.ARRAY_INDEX]
				if idx != null and (idx as PackedInt32Array).size() > 0:
					tris += (idx as PackedInt32Array).size() / 3
				else:
					tris += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		print("AABB %s size=(%.2f, %.2f, %.2f) min=(%.2f, %.2f, %.2f) parts=%d tris=%d" % [nm, bb.size.x, bb.size.y, bb.size.z, bb.position.x, bb.position.y, bb.position.z, parts, tris])
		n.free()
	quit()


func _meshes(n: Node) -> Array:
	var out: Array = []
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out.append(n)
	for c in n.get_children():
		out.append_array(_meshes(c))
	return out


func _rel(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = node
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t
