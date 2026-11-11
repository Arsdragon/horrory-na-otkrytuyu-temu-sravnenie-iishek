class_name Prints
extends MultiMeshInstance3D
## Следы на снегу: кольцевой буфер. Свои следы заметает за пару минут, чужие — так же.

const MAX := 320
const LIFE := 140.0

var _n := 0
var _age := PackedFloat32Array()
var _kind := PackedFloat32Array()
var _t := 0.0


func _ready() -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(0.15, 0.34)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/shaders/prints.gdshader")
	sm.set_shader_parameter("tex", Kit.tex("res://tex/foot"))
	sm.set_shader_parameter("tex_bare", Kit.tex("res://tex/footbare"))
	pm.material = sm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = pm
	mm.instance_count = MAX
	mm.visible_instance_count = MAX
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-500, -1, -500), Vector3(1000, 2, 1000))
	_age.resize(MAX)
	_kind.resize(MAX)
	for i in MAX:
		_age[i] = -1.0
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(0, -50, 0)))
		mm.set_instance_color(i, Color(0, 0, 0, 0))


## kind: 0 — унт, 1 — босая стопа существа. scale — длина следа относительно обычной.
func add(pos: Vector3, yaw: float, left: bool, kind := 0, scale_k := 1.0) -> void:
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(scale_k, 1.0, scale_k))
	var off := Basis(Vector3.UP, yaw) * Vector3(-0.11 if left else 0.11, 0, 0)
	multimesh.set_instance_transform(_n, Transform3D(b, Vector3(pos.x, 0.014 + 0.0004 * float(_n % 7), pos.z) + off))
	_age[_n] = 0.0
	_kind[_n] = float(kind)
	multimesh.set_instance_color(_n, Color(float(kind), 0, 0, 1.0))
	_n = (_n + 1) % MAX


## Цепочка следов от a к b (чужие следы поперёк леера).
func trail(a: Vector3, b: Vector3, kind := 0, stride := 0.8, scale_k := 1.0) -> void:
	var d := b - a
	var ln := d.length()
	var n := int(ln / stride)
	var yaw := atan2(-d.x, -d.z)
	for i in n:
		add(a + d * (float(i) / float(maxi(n, 1))), yaw, i % 2 == 0, kind, scale_k)


func clear() -> void:
	for i in MAX:
		_age[i] = -1.0
		multimesh.set_instance_color(i, Color(0, 0, 0, 0))


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	for i in MAX:
		if _age[i] < 0.0:
			continue
		_age[i] += _t
		var a := clampf(1.0 - _age[i] / LIFE, 0.0, 1.0)
		if a <= 0.0:
			_age[i] = -1.0
		multimesh.set_instance_color(i, Color(_kind[i], 0, 0, pow(a, 0.6)))
	_t = 0.0
