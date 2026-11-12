extends Node
func _ready() -> void:
	Game.main.start_checkpoint("c07_women", true)
	while Game.world == null or not Game.world.ready_done:
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	var w: World = Game.world
	for id in w.doors:
		(w.doors[id] as Door).set_open(1.0, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = 1 | 4
	for p in [Vector3(19, 0.9, 20), Vector3(24.5, 0.9, 20), Vector3(20, 0.9, 23), Vector3(48, 0.9, 9), Vector3(25.25, 0.9, 0), Vector3(16, -3.6, -16), Vector3(4, 0.9, 9)]:
		q.transform = Transform3D(Basis.IDENTITY, p)
		var hits := w.get_world_3d().direct_space_state.intersect_shape(q, 8)
		var names := []
		for h in hits:
			names.append(str((h["collider"] as Node).get_path()).replace("/root/Main/World/", ""))
		print("проём ", p, ": ", names)
	get_tree().quit()
