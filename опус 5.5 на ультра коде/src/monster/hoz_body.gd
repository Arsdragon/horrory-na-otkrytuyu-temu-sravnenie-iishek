class_name HozBody
extends Node3D
## Внешность Хозяйки: тело Rocketbox (или mdl/custom/hozyayka.glb), серая мокрая кожа, волосы до пола,
## когти, анимации. Смотрит вдоль -Z.

const SCALE := 1.36
const CUSTOM := "res://mdl/custom/hozyayka.glb"
const ANIMS := {
	"walk": "walk_injured", "walk2": "walk_bruised", "stagger": "walk_drunk", "run": "run_injured",
	"idle": "idle_breathe", "look": "look_around", "crouch": "crouch_idle", "crouch_in": "crouch_in",
}
const MODEL_YAW := PI   # поворот модели, чтобы смотрела вдоль -Z

static var _lib: AnimationLibrary = null

var model: Node3D
var skel: Skeleton3D
var anim: AnimationPlayer
var rig: HozRig
var hair: MeshInstance3D
var hair_mat: ShaderMaterial
var head_idx := -1
var custom := false
var cur := ""
var floor_y := 0.0
var _last_pos := Vector3.ZERO
var skin_mat: StandardMaterial3D
var claws: Array = []
var own_hair := false


func _ready() -> void:
	if ResourceLoader.exists(CUSTOM):
		_load_custom()
	else:
		_load_rocketbox()
	_make_hair()
	if own_hair:
		hair.visible = false
	_last_pos = global_position


func _load_rocketbox() -> void:
	var ps: PackedScene = load("res://mdl/rb/hozyayka/hozyayka.fbx")
	model = ps.instantiate()
	model.scale = Vector3.ONE * SCALE
	model.rotation.y = MODEL_YAW
	add_child(model)
	skel = model.get_node("Skeleton3D")
	anim = model.get_node("AnimationPlayer")
	var mi: MeshInstance3D = skel.get_child(0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	skin_mat = _skin("res://tex/gen/hoz_body.png")
	mi.set_surface_override_material(0, skin_mat)
	mi.set_surface_override_material(1, _skin("res://tex/gen/hoz_head.png"))
	var hide_mat := StandardMaterial3D.new()
	hide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hide_mat.albedo_color = Color(0, 0, 0, 0)
	mi.set_surface_override_material(2, hide_mat)
	if _lib == null:
		_lib = _build_lib()
	if anim.has_animation_library(""):
		anim.remove_animation_library("")
	anim.add_animation_library("", _lib.duplicate())
	rig = HozRig.new()
	skel.add_child(rig)
	head_idx = skel.find_bone("Bip01 Head")
	_make_claws()
	play("idle")


func _load_custom() -> void:
	custom = true
	var ps: PackedScene = load(CUSTOM)
	model = ps.instantiate()
	model.rotation.y = MODEL_YAW
	add_child(model)
	skel = _find(model, "Skeleton3D") as Skeleton3D
	anim = _find(model, "AnimationPlayer") as AnimationPlayer
	rig = HozRig.new()
	if skel:
		for nm in ["head", "Head", "Bip01 Head", "mixamorig:Head"]:
			head_idx = skel.find_bone(nm)
			if head_idx >= 0:
				break
		skel.add_child(rig)
	else:
		add_child(rig)
	# свои волосы в модели — процедурные не нужны
	own_hair = model.find_child("*hair*", true, false) != null or model.find_child("*Hair*", true, false) != null
	if anim:
		for a in anim.get_animation_list():
			var an := anim.get_animation(a)
			if a != "crouch_in":
				an.loop_mode = Animation.LOOP_LINEAR
	play("idle")


func _find(n: Node, cls: String) -> Node:
	if n.get_class() == cls:
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r:
			return r
	return null


func _skin(path: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(path)
	m.roughness = 0.78
	m.metallic_specular = 0.35
	m.clearcoat_enabled = true
	m.clearcoat = 0.22
	m.clearcoat_roughness = 0.5
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.3
	m.normal_enabled = true
	m.normal_scale = 1.8
	m.normal_texture = load("res://mdl/rb/hozyayka/body_normal.png" if "body" in path else "res://mdl/rb/hozyayka/head_normal.png")
	return m


static func _build_lib() -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	for key in ANIMS:
		var path := "res://mdl/rb/anim/%s.fbx" % ANIMS[key]
		if not ResourceLoader.exists(path):
			continue
		var sc: Node = (load(path) as PackedScene).instantiate()
		var ap: AnimationPlayer = sc.get_node("AnimationPlayer")
		var names := ap.get_animation_list()
		if names.is_empty():
			sc.free()
			continue
		var a: Animation = ap.get_animation(names[0]).duplicate(true)
		for t in range(a.get_track_count() - 1, -1, -1):
			var p := str(a.track_get_path(t))
			if "Footsteps" in p or "Helper" in p:
				a.remove_track(t)
				continue
			# корневая кость: убираем смещение по горизонтали (ходьба на месте)
			if p.ends_with(":Bip01") and a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var k0: Vector3 = a.track_get_key_value(t, 0)
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, Vector3(k0.x, v.y, k0.z))
		a.loop_mode = Animation.LOOP_NONE if key == "crouch_in" else Animation.LOOP_LINEAR
		lib.add_animation(key, a)
		sc.free()
	return lib


func play(name: String, blend := 0.35, speed := 1.0) -> void:
	if anim == null:
		return
	var n := name
	if custom and not anim.has_animation(n):
		for alt in [n, "walk", "idle"]:
			if anim.has_animation(alt):
				n = alt
				break
	if not anim.has_animation(n):
		return
	if cur != n:
		anim.play(n, blend)
		cur = n
	anim.speed_scale = speed


func _make_claws() -> void:
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.09, 0.08, 0.05)
	cm.roughness = 0.25
	cm.metallic_specular = 0.8
	for side in ["L", "R"]:
		for f in ["02", "12", "22", "32", "42"]:
			var bi := skel.find_bone("Bip01 %s Finger%s" % [side, f])
			if bi < 0:
				continue
			var ba := BoneAttachment3D.new()
			ba.bone_idx = bi
			skel.add_child(ba)
			var mi := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.0
			cyl.bottom_radius = 0.0065
			cyl.height = 0.075
			cyl.radial_segments = 5
			cyl.rings = 1
			mi.mesh = cyl
			mi.material_override = cm
			mi.rotation = Vector3(0, 0, -PI * 0.5)
			mi.position = Vector3(0.045, 0, 0)
			ba.add_child(mi)
			claws.append(mi)


# ---------------------------------------------------------------- волосы

func _make_hair() -> void:
	hair = MeshInstance3D.new()
	hair.name = "hair"
	hair.top_level = true
	hair.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hair.mesh = _hair_mesh()
	hair_mat = ShaderMaterial.new()
	hair_mat.shader = load("res://src/fx/hair.gdshader")
	hair_mat.set_shader_parameter("strands", load("res://tex/ui/hair.png"))
	hair_mat.set_shader_parameter("move_dir", Vector3.ZERO)
	hair.material_override = hair_mat
	hair.extra_cull_margin = 2.0
	add_child(hair)


func _hair_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1961
	var n := 230
	var segs := 10
	for i in n:
		var a := rng.randf() * TAU
		var front := clampf(1.0 - absf(angle_difference(a, -PI * 0.5)) / 1.0, 0.0, 1.0)  # -Z — лицо
		var side := 0.0 if cos(a) < 0.0 else 1.0
		var L := rng.randf_range(1.9, 2.6)
		var w := rng.randf_range(0.06, 0.11)
		var phase := rng.randf()
		var elev := rng.randf_range(0.0, 1.45)
		var R := 0.165
		var spread := rng.randf_range(0.2, 0.34)
		if front > 0.5:
			elev = rng.randf_range(0.3, 1.3)
			spread = rng.randf_range(0.19, 0.24)
		var root := Vector3(cos(a) * cos(elev) * R, sin(elev) * R * 0.9 + 0.02, sin(a) * cos(elev) * R)
		var tang := Vector3(-sin(a), 0, cos(a))
		var prev_l := Vector3.ZERO
		var prev_r := Vector3.ZERO
		for k in segs + 1:
			var t := float(k) / segs
			var rr := lerpf(R * cos(elev), spread, smoothstep(0.0, 0.28, t))
			var drop := t * L
			var c := Vector3(cos(a) * rr, root.y - drop, sin(a) * rr)
			if k == 0:
				c = root
			c += Vector3(rng.randf_range(-0.012, 0.012), 0, rng.randf_range(-0.012, 0.012)) * t
			var l := c - tang * w * 0.5
			var r := c + tang * w * 0.5
			if k > 0:
				var col := Color(phase, front, side)
				var t0 := float(k - 1) / segs
				var nrm := Vector3(cos(a), 0.2, sin(a)).normalized()
				for v in [[prev_l, Vector2(0, t0)], [prev_r, Vector2(1, t0)], [r, Vector2(1, t)],
						[prev_l, Vector2(0, t0)], [r, Vector2(1, t)], [l, Vector2(0, t)]]:
					st.set_color(col)
					st.set_normal(nrm)
					st.set_uv(v[1])
					st.add_vertex(v[0])
			prev_l = l
			prev_r = r
	return st.commit()


func head_pos() -> Vector3:
	if custom and skel and head_idx >= 0:
		var hb := skel.global_transform * skel.get_bone_global_pose(head_idx)
		return hb.origin + Vector3.UP * 0.08 - global_transform.basis.z * 0.06
	if skel and head_idx >= 0:
		var le := skel.find_bone("Bip01 LEye")
		var re := skel.find_bone("Bip01 REye")
		if le >= 0 and re >= 0:
			var m := (skel.get_bone_global_pose(le).origin + skel.get_bone_global_pose(re).origin) * 0.5
			return skel.global_transform * m
		return skel.global_transform * skel.get_bone_global_pose(head_idx).origin
	return global_position + Vector3.UP * 2.1


## Центр макушки для волос: от глаз назад и вверх.
func hair_anchor() -> Vector3:
	var fwd := -global_transform.basis.z
	fwd.y = 0
	return head_pos() - fwd.normalized() * 0.07 + Vector3.UP * 0.06


func _process(delta: float) -> void:
	if hair == null:
		return
	hair.global_position = hair_anchor()
	hair.global_rotation = Vector3(0, global_rotation.y, 0)
	hair_mat.set_shader_parameter("floor_y", floor_y)
	var vel := (global_position - _last_pos) / maxf(delta, 0.001)
	_last_pos = global_position
	var local_v := hair.global_transform.basis.inverse() * vel
	var mv: Vector3 = hair_mat.get_shader_parameter("move_dir")
	hair_mat.set_shader_parameter("move_dir", mv.lerp(Vector3(local_v.x, 0, local_v.z), clampf(delta * 3.0, 0.0, 1.0)))


func set_part(v: float) -> void:
	hair_mat.set_shader_parameter("part", v)


func set_clip(y: float) -> void:
	hair_mat.set_shader_parameter("clip_y", y)
