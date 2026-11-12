extends SceneTree
func _init():
	for p in ["res://mdl/rb/hozyayka/hozyayka.fbx", "res://mdl/rb/anim/walk_injured.fbx"]:
		var ps = load(p)
		print("== ", p, " ", ps)
		if ps == null: continue
		var n = ps.instantiate()
		_dump(n, 0)
		var sk = _find(n, "Skeleton3D")
		if sk:
			print("bones: ", sk.get_bone_count())
			for i in sk.get_bone_count():
				if i < 200: print("  ", i, " ", sk.get_bone_name(i), " parent=", sk.get_bone_parent(i), " rest=", sk.get_bone_rest(i).origin)
		var ap = _find(n, "AnimationPlayer")
		if ap:
			for a in ap.get_animation_list():
				var an = ap.get_animation(a)
				print("anim ", a, " len=", an.length, " tracks=", an.get_track_count())
				for t in min(6, an.get_track_count()):
					print("   ", an.track_get_path(t), " type=", an.track_get_type(t))
	quit()
func _dump(n, d):
	if d < 4:
		var extra = ""
		if n is MeshInstance3D: extra = " mesh surfaces=%d aabb=%s skin=%s" % [n.mesh.get_surface_count(), n.get_aabb(), n.skin != null]
		print("  ".repeat(d), n.name, " <", n.get_class(), ">", extra)
		for c in n.get_children(): _dump(c, d+1)
func _find(n, cls):
	if n.get_class() == cls: return n
	for c in n.get_children():
		var r = _find(c, cls)
		if r: return r
	return null
