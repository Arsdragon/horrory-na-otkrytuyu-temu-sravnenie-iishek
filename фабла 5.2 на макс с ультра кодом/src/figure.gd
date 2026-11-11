class_name Figure
extends Node3D
## Фигура в парке «аляска»: тело Отзыва и замёрзший Громов. Собрана из простых форм, суставы — узлы.
## wrong 0 — человек (унты, рукавицы), 1 — настоящее: длинные голые руки и ноги, маска лица в капюшоне.
## Смотрит по −Z. Если есть mdl/custom/otzyv.glb, части берутся оттуда (см. docs/PLAN.md, раздел 12).

var wrong := 0.0
var frozen := false          # замёрзшее тело: всё в инее
var jerk := true             # поза обновляется рывками, как в покадровой съёмке
var speed := 0.0             # текущая скорость ходьбы (задаёт хозяин)
var look_at_pos := Vector3.ZERO
var look_on := false
var reach := 0.0             # 0..1 руки тянутся вперёд
var eyes_always := 0.0       # глаза светятся без фонаря (музей, катсцены)
var pose_name := "stand"

var pelvis: Node3D
var spine: Node3D
var neck: Node3D
var head: Node3D
var mask: MeshInstance3D
var eyes: Array = []
var sh := {}       # "L"/"R" -> плечо
var el := {}
var wr := {}
var hip := {}
var kn := {}
var an := {}
var bare_arm := {}
var shin := {}
var mitt := {}
var claw := {}
var boot := {}
var foot := {}
var _phase := 0.0
var _hold := 0.0
var _t := 0.0
var _eye_mat: ShaderMaterial
var _built_wrong := -1.0
var _head_yaw := 0.0
var _head_pitch := 0.0


static func make(parent: Node, is_frozen := false) -> Figure:
	var f := Figure.new()
	f.frozen = is_frozen
	parent.add_child(f)
	return f


func _ready() -> void:
	_build()
	_apply_wrong()
	_pose(0.0, true)


func _m_parka() -> Material:
	if frozen:
		return Kit.mat("caban", 0.6, Color(0.62, 0.6, 0.62), 0.9)
	return Kit.mat("caban", 0.6, Color(0.42, 0.3, 0.24), 1.0)


func _m_fur() -> Material:
	return Kit.mat("fur", 0.3, Color(0.62, 0.64, 0.68) if frozen else Color(0.4, 0.38, 0.36), 1.0)


func _m_dark() -> Material:
	return Kit.flat(Color(0.2, 0.22, 0.26) if frozen else Color(0.035, 0.035, 0.04), 0.55)


func _m_pants() -> Material:
	return Kit.mat("caban", 0.5, Color(0.3, 0.32, 0.36) if frozen else Color(0.1, 0.1, 0.12), 1.0)


func _build() -> void:
	var parka := _m_parka()
	var fur := _m_fur()
	var dark := _m_dark()
	var pants := _m_pants()
	pelvis = Node3D.new()
	add_child(pelvis)
	spine = Node3D.new()
	pelvis.add_child(spine)
	# парка: тело вращения от подола до ворота
	var prof := PackedVector2Array([Vector2(0.0, -0.4), Vector2(0.3, -0.4), Vector2(0.32, -0.28), Vector2(0.3, -0.08), Vector2(0.28, 0.1),
		Vector2(0.27, 0.24), Vector2(0.24, 0.34), Vector2(0.15, 0.41), Vector2(0.1, 0.46), Vector2(0.0, 0.46)])
	var tm := Kit.mesh_node(spine, Kit.lathe(prof, 14), Vector3.ZERO, parka)
	tm.scale = Vector3(1.0, 1.0, 0.78)
	# рваный подол
	for i in 7:
		var a := TAU * float(i) / 7.0 + 0.3
		var st := Kit.box_node(spine, Vector3(cos(a) * 0.29, -0.46 - 0.03 * float(i % 3), sin(a) * 0.23), Vector3(0.1, 0.16 + 0.05 * float(i % 2), 0.012), parka, false)
		st.rotation.y = -a + PI * 0.5
	neck = Node3D.new()
	neck.position = Vector3(0, 0.43, 0)
	spine.add_child(neck)
	head = Node3D.new()
	head.position = Vector3(0, 0.13, 0)
	neck.add_child(head)
	# капюшон, опушка, чернота внутри
	Kit.sphere_node(head, Vector3(0, 0.02, 0.04), 0.2, parka, Vector3(1.0, 1.12, 1.0), 14)
	var tor := TorusMesh.new()
	tor.inner_radius = 0.115
	tor.outer_radius = 0.19
	tor.rings = 16
	tor.ring_segments = 8
	var fr := Kit.mesh_node(head, tor, Vector3(0, 0.01, -0.15), fur, Basis(Vector3.RIGHT, deg_to_rad(90)))
	fr.scale = Vector3(1.0, 1.0, 1.2)
	var void_m := StandardMaterial3D.new()
	void_m.albedo_color = Color(0, 0, 0)
	void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Kit.sphere_node(head, Vector3(0, 0.01, -0.12), 0.13, void_m, Vector3(1.0, 1.2, 0.45), 12).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# маска лица
	mask = MeshInstance3D.new()
	mask.mesh = _mask_mesh()
	var mm := StandardMaterial3D.new()
	mm.vertex_color_use_as_albedo = true
	mm.albedo_color = Color(0.74, 0.8, 0.88) if not frozen else Color(0.8, 0.86, 0.95)
	mm.roughness = 0.45
	mm.metallic_specular = 0.6
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mask.material_override = mm
	mask.position = Vector3(0, 0.0, -0.1)
	mask.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.add_child(mask)
	# глаза: два блика
	_eye_mat = ShaderMaterial.new()
	_eye_mat.shader = load("res://src/shaders/eyes.gdshader")
	_eye_mat.set_shader_parameter("tex", Kit.tex("res://tex/eye"))
	_eye_mat.set_shader_parameter("power", 5.0)
	for sx in [-0.038, 0.038]:
		var q := QuadMesh.new()
		q.size = Vector2(0.05, 0.05)
		var e := MeshInstance3D.new()
		e.mesh = q
		e.material_override = _eye_mat
		e.position = Vector3(sx, 0.035, -0.225)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		e.extra_cull_margin = 3.0
		e.set_instance_shader_parameter("eye_side", signf(sx))
		head.add_child(e)
		eyes.append(e)
	if frozen:
		for e in eyes:
			(e as MeshInstance3D).visible = false
	# руки
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var s := Node3D.new()
		s.position = Vector3(sx * 0.27, 0.3, 0)
		spine.add_child(s)
		sh[side] = s
		Kit.capsule_node(s, Vector3(0, -0.2, 0), 0.09, 0.5, parka)
		var e := Node3D.new()
		e.position = Vector3(0, -0.42, 0)
		s.add_child(e)
		el[side] = e
		Kit.capsule_node(e, Vector3(0, -0.17, 0), 0.08, 0.42, parka)
		var ba := Kit.capsule_node(e, Vector3(0, -0.5, 0), 0.03, 0.5, dark)
		bare_arm[side] = ba
		var w := Node3D.new()
		e.add_child(w)
		wr[side] = w
		mitt[side] = Kit.sphere_node(w, Vector3(0, -0.07, 0), 1.0, pants, Vector3(0.06, 0.1, 0.045), 8)
		var c := Node3D.new()
		w.add_child(c)
		claw[side] = c
		Kit.box_node(c, Vector3(0, -0.05, 0), Vector3(0.075, 0.1, 0.025), dark)
		for fi in 4:
			var fx := (float(fi) - 1.5) * 0.02
			var f1 := Node3D.new()
			f1.position = Vector3(fx, -0.1, 0)
			f1.rotation = Vector3(deg_to_rad(8.0 + fi * 3.0), 0, deg_to_rad((float(fi) - 1.5) * 5.0 * -sx))
			c.add_child(f1)
			Kit.capsule_node(f1, Vector3(0, -0.055, 0), 0.008, 0.11, dark)
			var f2 := Node3D.new()
			f2.position = Vector3(0, -0.11, 0)
			f2.rotation.x = deg_to_rad(16.0)
			f1.add_child(f2)
			Kit.capsule_node(f2, Vector3(0, -0.05, 0), 0.006, 0.1, dark)
		var th := Node3D.new()
		th.position = Vector3(-sx * 0.04, -0.04, 0)
		th.rotation.z = deg_to_rad(-55.0 * sx)
		c.add_child(th)
		Kit.capsule_node(th, Vector3(0, -0.05, 0), 0.008, 0.1, dark)
	# ноги
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var h := Node3D.new()
		h.position = Vector3(sx * 0.11, -0.25, 0)
		pelvis.add_child(h)
		hip[side] = h
		Kit.capsule_node(h, Vector3(0, -0.22, 0), 0.085, 0.5, pants)
		var k := Node3D.new()
		k.position = Vector3(0, -0.45, 0)
		h.add_child(k)
		kn[side] = k
		shin[side] = Kit.capsule_node(k, Vector3(0, -0.25, 0), 0.05, 0.54, dark)
		var a := Node3D.new()
		k.add_child(a)
		an[side] = a
		# унт: высокий меховой сапог
		var bt := Node3D.new()
		a.add_child(bt)
		boot[side] = bt
		Kit.capsule_node(bt, Vector3(0, 0.16, 0), 0.085, 0.36, fur)
		Kit.sphere_node(bt, Vector3(0, 0.03, -0.06), 1.0, pants, Vector3(0.075, 0.05, 0.15), 8)
		# голая узкая стопа
		var ft := Node3D.new()
		a.add_child(ft)
		foot[side] = ft
		Kit.sphere_node(ft, Vector3(0, 0.03, -0.1), 1.0, dark, Vector3(0.04, 0.03, 0.17), 8)
		for ti in 4:
			Kit.capsule_node(ft, Vector3((float(ti) - 1.5) * 0.017, 0.015, -0.3), 0.007, 0.09, dark).rotation.x = deg_to_rad(90)
	_try_custom()


## Маска: сплюснутая сфера с вдавленными глазницами и раскрытым ртом.
func _mask_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := 20
	var rows := 14
	var pts: Array = []
	var cls: Array = []
	for j in rows + 1:
		for i in cols + 1:
			var u := float(i) / float(cols)
			var v := float(j) / float(rows)
			var th := (u - 0.5) * PI                      # от −90° до 90°: только передняя половина
			var ph := (v - 0.5) * PI
			var d := Vector3(sin(th) * cos(ph), -sin(ph), -cos(th) * cos(ph))
			var p := Vector3(d.x * 0.085, d.y * 0.125, d.z * 0.055)
			var dark := 0.0
			# глазницы
			for ex in [-0.036, 0.036]:
				var q := Vector2(p.x - ex, p.y - 0.032)
				var k := exp(-q.length_squared() / (0.019 * 0.019))
				p.z += 0.03 * k
				dark = maxf(dark, k)
			# рот: высокий провал
			var qm := Vector2(p.x / 0.03, (p.y + 0.062) / 0.05)
			var km := exp(-qm.length_squared())
			p.z += 0.04 * km
			dark = maxf(dark, km)
			# скулы и переносица наружу
			p.z -= 0.008 * exp(-Vector2(p.x, p.y + 0.005).length_squared() / (0.016 * 0.016))
			pts.append(p)
			var c := lerpf(1.0, 0.03, clampf(dark * 1.3, 0.0, 1.0))
			cls.append(Color(c, c, c))
	for j in rows + 1:
		for i in cols + 1:
			var idx := j * (cols + 1) + i
			var p: Vector3 = pts[idx]
			var px: Vector3 = pts[j * (cols + 1) + mini(i + 1, cols)]
			var pm: Vector3 = pts[j * (cols + 1) + maxi(i - 1, 0)]
			var py: Vector3 = pts[mini(j + 1, rows) * (cols + 1) + i]
			var pn: Vector3 = pts[maxi(j - 1, 0) * (cols + 1) + i]
			var n := (px - pm).cross(py - pn).normalized()
			if n.z > 0.0:
				n = -n
			st.set_normal(n)
			st.set_color(cls[idx])
			st.set_uv(Vector2(float(i) / cols, float(j) / rows))
			st.add_vertex(p)
	for j in rows:
		for i in cols:
			var a := j * (cols + 1) + i
			var b := a + 1
			var c := a + cols + 1
			var d := c + 1
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	return st.commit()


## Замена частей своей моделью из Blender: объекты с именами суставов (см. план, раздел 12).
func _try_custom() -> void:
	var path := "res://mdl/custom/otzyv.glb"
	if not ResourceLoader.exists(path):
		return
	var ps: PackedScene = load(path)
	if ps == null:
		return
	var src: Node3D = ps.instantiate()
	var slots := {"torso": spine, "hood": head, "head": head, "arm_upper_L": sh["L"], "arm_upper_R": sh["R"], "arm_lower_L": el["L"], "arm_lower_R": el["R"],
		"hand_L": wr["L"], "hand_R": wr["R"], "leg_upper_L": hip["L"], "leg_upper_R": hip["R"], "leg_lower_L": kn["L"], "leg_lower_R": kn["R"],
		"foot_L": an["L"], "foot_R": an["R"]}
	var found := 0
	for nm in slots:
		var part := src.find_child(String(nm), true, false)
		if part == null or not (part is Node3D):
			continue
		var slot: Node3D = slots[nm]
		for c in slot.get_children():
			if c is MeshInstance3D:
				(c as MeshInstance3D).visible = false
		part.get_parent().remove_child(part)
		slot.add_child(part)
		(part as Node3D).transform = Transform3D.IDENTITY
		found += 1
	src.queue_free()
	print("LOG custom figure parts: ", found)


func set_wrong(v: float) -> void:
	wrong = clampf(v, 0.0, 1.0)
	_apply_wrong()


func _apply_wrong() -> void:
	if is_equal_approx(_built_wrong, wrong) or pelvis == null:
		return
	_built_wrong = wrong
	var w := wrong
	var ext := 0.36 * w                       # насколько голая рука длиннее рукава
	var leg := 1.0 + 0.5 * w
	for side in ["L", "R"]:
		var ba: MeshInstance3D = bare_arm[side]
		ba.visible = w > 0.05
		ba.scale = Vector3(1, maxf(ext / 0.5 + 0.3, 0.01), 1)
		ba.position = Vector3(0, -0.32 - ext * 0.5, 0)
		(wr[side] as Node3D).position = Vector3(0, -0.4 - ext, 0)
		(mitt[side] as Node3D).visible = w < 0.5
		(claw[side] as Node3D).visible = w >= 0.5
		(claw[side] as Node3D).scale = Vector3.ONE * (1.0 + 0.5 * w)
		var sn: MeshInstance3D = shin[side]
		sn.scale = Vector3(1.0 - 0.3 * w, leg, 1.0 - 0.3 * w)
		sn.position = Vector3(0, -0.25 * leg, 0)
		(an[side] as Node3D).position = Vector3(0, -0.5 * leg, 0)
		(boot[side] as Node3D).visible = w < 0.5
		(foot[side] as Node3D).visible = w >= 0.5
	mask.visible = w > 0.15 and not frozen
	mask.scale = Vector3.ONE * lerpf(0.75, 1.12, w)
	mask.position = Vector3(0, 0.0, lerpf(-0.125, -0.15, w))
	for e in eyes:
		var em: MeshInstance3D = e
		em.position.y = lerpf(0.035, 0.03, w)


## Высота таза над землёй для текущей «неправильности».
func hip_height() -> float:
	return 0.25 + 0.45 + 0.5 * (1.0 + 0.5 * wrong) + 0.03


func height() -> float:
	return hip_height() + 0.8


func head_pos() -> Vector3:
	return head.global_position


func set_pose(p: String) -> void:
	pose_name = p
	_pose(0.0, true)


func _process(dt: float) -> void:
	_t += dt
	_apply_wrong()
	_eye_mat.set_shader_parameter("always", eyes_always)
	if speed > 0.05:
		_phase += dt * speed / lerpf(0.78, 1.15, wrong)
	_hold -= dt
	if jerk and _hold > 0.0:
		return
	_hold = 0.09 if jerk else 0.0
	_pose(dt, false)


func _pose(_dt: float, instant: bool) -> void:
	if pelvis == null:
		return
	var w := wrong
	var hh := hip_height()
	if pose_name == "sit":
		# сидит у стены, ноги вытянуты, голова на груди, руки на коленях
		pelvis.position = Vector3(0, 0.34, 0)
		spine.rotation = Vector3(deg_to_rad(-12), 0, deg_to_rad(4))
		neck.rotation = Vector3(deg_to_rad(38), deg_to_rad(8), 0)
		for side in ["L", "R"]:
			var sx := -1.0 if side == "L" else 1.0
			(hip[side] as Node3D).rotation = Vector3(deg_to_rad(86), 0, deg_to_rad(6.0 * sx))
			(kn[side] as Node3D).rotation = Vector3(deg_to_rad(-6), 0, 0)
			(an[side] as Node3D).rotation = Vector3(deg_to_rad(-70), 0, 0)
			(sh[side] as Node3D).rotation = Vector3(deg_to_rad(38), 0, deg_to_rad(-9.0 * sx))
			(el[side] as Node3D).rotation = Vector3(deg_to_rad(42), 0, deg_to_rad(14.0 * sx))
		return
	var moving := speed > 0.05
	var ph := _phase * TAU
	var sway := sin(_t * 0.7) * 0.012
	var bob := (absf(sin(ph)) * 0.035 if moving else 0.0)
	pelvis.position = Vector3(sway, hh - bob - 0.05 * w, 0)
	# сутулость: чем «неправильнее», тем сильнее наклон вперёд
	spine.rotation = Vector3(deg_to_rad(4.0 + 13.0 * w + 6.0 * reach), sin(ph) * 0.06 if moving else 0.0, sway * 1.5)
	# голова следит за целью
	var ty := 0.0
	var tp := deg_to_rad(-4.0 - 10.0 * w)
	if look_on:
		var local := to_local(look_at_pos) - (pelvis.position + Vector3(0, 0.56, 0))
		ty = clampf(atan2(-local.x, -local.z), -1.25, 1.25)
		tp = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6) - spine.rotation.x
	var k := 1.0 if instant else 0.35
	_head_yaw = lerp_angle(_head_yaw, ty, k)
	_head_pitch = lerpf(_head_pitch, tp, k)
	neck.rotation = Vector3(_head_pitch, _head_yaw, sin(_t * 0.31) * 0.05 * w)
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var sph := ph + (0.0 if side == "L" else PI)
		var swing := sin(sph) * (0.5 if moving else 0.0)
		var lift := maxf(0.0, cos(sph)) * (0.75 if moving else 0.0)
		(hip[side] as Node3D).rotation = Vector3(swing - 0.05, 0, deg_to_rad(2.0 * sx))
		(kn[side] as Node3D).rotation = Vector3(-lift - 0.06 - 0.12 * w, 0, 0)
		(an[side] as Node3D).rotation = Vector3(-swing * 0.3 + lift * 0.4, 0, 0)
		var arm_sw := -sin(sph) * (0.22 if moving else 0.0) + sin(_t * 0.5 + sx) * 0.02
		var r := reach
		(sh[side] as Node3D).rotation = Vector3(arm_sw + deg_to_rad(4.0 + 78.0 * r), 0, deg_to_rad((-5.0 + 3.0 * r) * sx))
		(el[side] as Node3D).rotation = Vector3(deg_to_rad(6.0 + 10.0 * w + 14.0 * r), 0, 0)
		(wr[side] as Node3D).rotation = Vector3(deg_to_rad(-8.0 * r), 0, 0)
