extends Node3D
## Модель Жильца. Если есть res://models/zhilets.glb — берётся она, иначе собирается из примитивов.
## Процедурная анимация: шаг, размах рук, рывки головы.

var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var torso: Node3D
var custom := false
var walk := 0.0      # фаза шага
var speed := 0.0     # 0..1 для анимации
var lean := 0.0
var face_up := 0.0   # 1 = поднял «лицо» (скример)
var _twitch_t := 0.0
var _twitch := Vector3.ZERO

func _ready() -> void:
	if ResourceLoader.exists("res://models/zhilets.glb"):
		var sc: PackedScene = load("res://models/zhilets.glb")
		add_child(sc.instantiate())
		custom = true
		return
	var skin := G.mat("skin", 2.0, Color(0.75, 0.72, 0.72), 0.5)
	skin.uv1_world_triplanar = false
	var robe := G.mat("robe", 2.0, Color(0.8, 0.8, 0.8), 1.0)
	robe.uv1_world_triplanar = false
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0, 0, 0)
	black.roughness = 1.0
	torso = Node3D.new(); torso.position.y = 1.15; add_child(torso)
	leg_l = _limb(self, Vector3(-0.11, 1.15, 0), 0.055, 1.15, skin)
	leg_r = _limb(self, Vector3(0.11, 1.15, 0), 0.055, 1.15, skin)
	# халат: конус от плеч до колен
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.19; cyl.bottom_radius = 0.34; cyl.height = 1.05
	_mesh(torso, cyl, robe, Vector3(0, 0.25, 0))
	var chest := CapsuleMesh.new(); chest.radius = 0.16; chest.height = 0.6
	_mesh(torso, chest, robe, Vector3(0, 0.7, 0.02))
	# шея согнута вперёд — голова висит у груди
	var neck := Node3D.new(); neck.position = Vector3(0, 0.92, 0.05); torso.add_child(neck)
	var nm := CapsuleMesh.new(); nm.radius = 0.045; nm.height = 0.3
	_mesh(neck, nm, skin, Vector3(0, 0.05, 0.08), Vector3(1.0, 0, 0))
	head = Node3D.new(); head.position = Vector3(0, 0.05, 0.2); neck.add_child(head)
	var hm := SphereMesh.new(); hm.radius = 0.14; hm.height = 0.34
	_mesh(head, hm, skin, Vector3.ZERO)
	# «лицо» — впадина
	var hole := SphereMesh.new(); hole.radius = 0.1; hole.height = 0.2
	_mesh(head, hole, black, Vector3(0, -0.01, 0.085), Vector3.ZERO, Vector3(1.05, 1.45, 0.75))
	var jaw := SphereMesh.new(); jaw.radius = 0.06; jaw.height = 0.12
	_mesh(head, jaw, black, Vector3(0, -0.17, 0.08), Vector3.ZERO, Vector3(0.75, 2.2, 0.6))
	var gum := StandardMaterial3D.new(); gum.albedo_color = Color(0.25, 0.02, 0.03); gum.roughness = 0.3
	for i in 7:  # зубы по краю впадины
		var tm := CylinderMesh.new(); tm.top_radius = 0.0; tm.bottom_radius = 0.008; tm.height = 0.04
		var a := -0.9 + i * 0.3
		_mesh(head, tm, G.mat("", 1, Color(0.8, 0.78, 0.65), 0.4), Vector3(sin(a) * 0.08, -0.04 - cos(a) * 0.12, 0.12), Vector3(0, 0, PI + a))
	var inner := SphereMesh.new(); inner.radius = 0.05; inner.height = 0.1
	_mesh(head, inner, gum, Vector3(0, -0.05, 0.05))
	# руки до колен, длинные пальцы
	arm_l = _limb(torso, Vector3(-0.24, 0.85, 0), 0.04, 1.25, skin)
	arm_r = _limb(torso, Vector3(0.24, 0.85, 0), 0.04, 1.25, skin)
	for arm in [arm_l, arm_r]:
		for i in 4:
			var f := CapsuleMesh.new(); f.radius = 0.012; f.height = 0.22
			_mesh(arm, f, skin, Vector3((i - 1.5) * 0.022, -1.33, 0.01), Vector3(0.15 * (i - 1.5), 0, 0.1 * (i - 1.5)))

func _limb(parent: Node3D, pivot: Vector3, r: float, ln: float, m: Material) -> Node3D:
	var p := Node3D.new()
	p.position = pivot
	parent.add_child(p)
	var c := CapsuleMesh.new(); c.radius = r; c.height = ln
	_mesh(p, c, m, Vector3(0, -ln / 2, 0))
	return p

func _mesh(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _process(dt: float) -> void:
	if custom or head == null: return
	walk += dt * (1.5 + speed * 5.0) * (1.0 if speed > 0.05 else 0.0)
	var sw := sin(walk) * (0.25 + speed * 0.35)
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	arm_l.rotation.x = -sw * 0.6 - lean * 0.5
	arm_r.rotation.x = sw * 0.6 - lean * 0.5
	arm_l.rotation.z = -0.08
	arm_r.rotation.z = 0.08
	torso.rotation.x = 0.25 + lean * 0.35
	torso.position.y = 1.15 + abs(cos(walk)) * 0.03
	_twitch_t -= dt
	if _twitch_t <= 0:
		_twitch_t = randf_range(0.15, 2.5)
		_twitch = Vector3(randf_range(-0.3, 0.3), randf_range(-0.6, 0.6), randf_range(-0.7, 0.7)) if randf() < 0.5 else Vector3.ZERO
	var target := (_twitch + Vector3(0.7, 0, 0)).lerp(Vector3(-0.35, 0, 0), face_up)
	head.rotation = head.rotation.lerp(target, min(1.0, dt * (30.0 if face_up < 0.5 else 12.0)))
