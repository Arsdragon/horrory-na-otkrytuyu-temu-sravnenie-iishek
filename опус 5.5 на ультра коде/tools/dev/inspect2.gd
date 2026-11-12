extends SceneTree
func _init():
	for p in ["res://mdl/rb/anim/walk_injured.fbx", "res://mdl/rb/anim/crouch_idle.fbx", "res://mdl/rb/anim/m_sit.fbx"]:
		var n = load(p).instantiate()
		var ap = n.get_node("AnimationPlayer")
		for a in ap.get_animation_list():
			var an = ap.get_animation(a)
			var types = {}
			for t in an.get_track_count():
				var k = str(an.track_get_type(t))
				types[k] = types.get(k, 0) + 1
			print(p, " anim ", a, " len=", an.length, " loop=", an.loop_mode, " types=", types)
			for t in an.get_track_count():
				var path = str(an.track_get_path(t))
				if "Pelvis" in path or path.ends_with(":Bip01") or "Footsteps" in path:
					print("   ", path, " type=", an.track_get_type(t), " keys=", an.track_get_key_count(t))
	var av = load("res://mdl/rb/hozyayka/hozyayka.fbx").instantiate()
	var mi = av.get_node("Skeleton3D").get_child(0)
	for s in mi.mesh.get_surface_count():
		var m = mi.mesh.surface_get_material(s)
		print("surface ", s, " mat=", m, " name=", m.resource_name if m else "")
		if m is StandardMaterial3D: print("   tex ", m.albedo_texture, " transp=", m.transparency)
	quit()
