class_name HozHand
extends Node3D
## Пока она «за спиной»: через плечо в кадр свисают её мокрые пряди, внизу слева — кончики пальцев с ногтями.

var strands: Array = []
var fingers: Array = []
var t := 0.0


func _ready() -> void:
	var hm := StandardMaterial3D.new()
	hm.albedo_texture = load("res://tex/ui/hair.png")
	hm.albedo_color = Color(0.22, 0.2, 0.2)
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	hm.alpha_scissor_threshold = 0.35
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hm.roughness = 0.2
	hm.metallic_specular = 0.8
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var len := rng.randf_range(0.35, 0.75)
		qm.size = Vector2(rng.randf_range(0.03, 0.07), len)
		qm.center_offset = Vector3(0, -len * 0.5, 0)
		mi.mesh = qm
		mi.material_override = hm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(rng.randf_range(-0.36, -0.02), rng.randf_range(0.2, 0.3), rng.randf_range(-0.42, -0.24))
		mi.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.25, 0.1))
		mi.set_meta("ph", rng.randf() * TAU)
		mi.set_meta("rz", mi.rotation.z)
		add_child(mi)
		strands.append(mi)
	# своя модель кисти из Blender (mdl/custom/hozyayka_hand.glb) вместо кончиков пальцев
	if ResourceLoader.exists("res://mdl/custom/hozyayka_hand.glb"):
		var hand: Node3D = (load("res://mdl/custom/hozyayka_hand.glb") as PackedScene).instantiate()
		hand.position = Vector3(-0.2, -0.17, -0.3)
		hand.rotation = Vector3(0, PI, 0)
		add_child(hand)
		return
	# кончики пальцев на плече, внизу слева
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.48, 0.5, 0.47)
	skin.roughness = 0.3
	skin.clearcoat_enabled = true
	skin.clearcoat = 0.8
	var nail := StandardMaterial3D.new()
	nail.albedo_color = Color(0.05, 0.045, 0.03)
	nail.roughness = 0.15
	for i in 4:
		var root := Node3D.new()
		root.position = Vector3(-0.27 + i * 0.022, -0.19, -0.3 + i * 0.006)
		root.rotation = Vector3(deg_to_rad(-60), deg_to_rad(15), 0)
		add_child(root)
		Geo.mesh_cyl(root, 0.0065, 0.05, skin, Vector3(0, 0.025, 0), 6, 0.0055)
		var tip := Node3D.new()
		tip.position = Vector3(0, 0.05, 0)
		tip.rotation.x = deg_to_rad(55)
		root.add_child(tip)
		Geo.mesh_cyl(tip, 0.0055, 0.035, skin, Vector3(0, 0.017, 0), 6, 0.0045)
		Geo.mesh_cyl(tip, 0.004, 0.045, nail, Vector3(0, 0.055, 0.0), 5, 0.0)
		fingers.append(root)
	var l := OmniLight3D.new()
	l.light_color = Color(0.7, 0.75, 0.8)
	l.light_energy = 0.25
	l.omni_range = 0.6
	l.position = Vector3(-0.1, 0.1, -0.1)
	add_child(l)


func _process(delta: float) -> void:
	t += delta
	for s in strands:
		var mi: MeshInstance3D = s
		mi.rotation.z = float(mi.get_meta("rz")) + sin(t * 1.3 + float(mi.get_meta("ph"))) * 0.04
	for i in fingers.size():
		var f: Node3D = fingers[i]
		f.rotation.x = deg_to_rad(-60) + sin(t * 2.2 + i) * 0.05 - minf(t * 0.05, 0.3)
