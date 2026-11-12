extends Node3D
# Тестовая сцена: Хозяйка на свету, скриншоты с разных сторон и в разных анимациях.
var body: HozBody
var cam: Camera3D

func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.05, 0.06)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.5, 0.55)
	e.ambient_light_energy = 0.4
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(10, 10)
	fl.mesh = pm
	fl.material_override = Mat.m("tile_floor", {"wet": 0.8})
	add_child(fl)
	var l := OmniLight3D.new()
	l.position = Vector3(1.5, 2.5, -2.0)
	l.light_energy = 3.0
	l.omni_range = 9.0
	l.shadow_enabled = true
	add_child(l)
	var l2 := SpotLight3D.new()
	l2.position = Vector3(0, 1.6, -3.0)
	l2.light_energy = 4.0
	l2.spot_range = 8
	add_child(l2)
	l2.look_at(Vector3(0, 1.3, 0))
	body = HozBody.new()
	add_child(body)
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	_run()

func _shot(name: String, cpos: Vector3, look: Vector3, anim: String, rig := {}) -> void:
	body.play(anim, 0.0)
	for k in rig:
		body.rig.set(k, rig[k])
	cam.global_position = cpos
	cam.look_at(look)
	for i in 40:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/hoz_%s.png" % name)

func _run() -> void:
	await get_tree().process_frame
	await _shot("front", Vector3(0, 1.5, -3.2), Vector3(0, 1.2, 0), "idle")
	await _shot("side", Vector3(3.2, 1.5, 0), Vector3(0, 1.2, 0), "walk")
	await _shot("back", Vector3(0, 1.6, 3.2), Vector3(0, 1.2, 0), "look")
	await _shot("crouch", Vector3(1.5, 1.2, -2.5), Vector3(0, 0.7, 0), "crouch")
	body.play("idle", 0.0)
	body.set_part(1.0)
	for i in 10:
		await get_tree().process_frame
	var hp := body.head_pos()
	await _shot("face", hp + Vector3(0.1, -0.05, -0.6), hp, "idle", {"jaw": 1.0, "stoop": 0.3})
	var h := HozHand.new()
	cam.add_child(h)
	body.visible = false
	cam.global_position = Vector3(0, 1.6, 2.0)
	cam.look_at(Vector3(0, 1.4, -3.0))
	for i in 20:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/hoz_hand.png")
	get_tree().quit()
