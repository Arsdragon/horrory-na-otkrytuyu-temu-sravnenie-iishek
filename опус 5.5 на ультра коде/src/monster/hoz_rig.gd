class_name HozRig
extends SkeletonModifier3D
## Процедурная надстройка над анимацией: вытянутые руки, пальцы и шея, сутулость, наклон головы,
## дёрганья, открытая челюсть, «тянется руками».

var stoop := 0.5        # 0..1 — сгорбленность
var head_tilt := 0.35   # рад — голова набок
var jaw := 0.0          # 0..1
var reach := 0.0        # 0..1 — руки вперёд
var twitch := 0.0       # 0..1 — сила дёрганий
var crawl := 0.0        # 0..1 — низко пригнулась
var _tw := Vector3.ZERO
var _tw_t := 0.0
var _ids := {}
var _rest := {}

const LONG := {
	"Bip01 L Forearm": 1.45, "Bip01 R Forearm": 1.45,
	"Bip01 L Hand": 1.6, "Bip01 R Hand": 1.6,
	"Bip01 Head": 1.35,
	"Bip01 L Calf": 1.1, "Bip01 R Calf": 1.1,
	"Bip01 L Foot": 1.08, "Bip01 R Foot": 1.08,
}
const FINGER_LONG := 2.1


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in sk.get_bone_count():
		var n := sk.get_bone_name(i)
		_ids[n] = i
		_rest[i] = sk.get_bone_rest(i)


func _b(name: String) -> int:
	return int(_ids.get(name, -1))


func _rot(sk: Skeleton3D, name: String, axis: Vector3, ang: float) -> void:
	var i := _b(name)
	if i < 0 or absf(ang) < 0.0001:
		return
	sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i) * Quaternion(axis, ang))


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or _ids.is_empty():
		return
	# удлинение: сдвигаем дочерние кости дальше от родителя
	for n in LONG:
		var i := _b(n)
		if i >= 0:
			sk.set_bone_pose_position(i, (_rest[i] as Transform3D).origin * float(LONG[n]))
	for side in ["L", "R"]:
		for f in ["0", "1", "2", "3", "4"]:
			for seg in ["1", "2"]:
				var i := _b("Bip01 %s Finger%s%s" % [side, f, seg])
				if i >= 0:
					sk.set_bone_pose_position(i, (_rest[i] as Transform3D).origin * FINGER_LONG)
	# дёрганья
	_tw_t -= get_process_delta_time() if is_inside_tree() else 0.016
	if _tw_t <= 0.0:
		_tw_t = randf_range(0.08, 0.9) / maxf(0.2, twitch + 0.2)
		_tw = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * twitch * 0.35
	# сутулость: позвоночник вперёд (ось Z у Bip01 — сгибание вперёд/назад)
	var s := stoop + crawl * 0.6
	_rot(sk, "Bip01 Spine", Vector3(0, 0, 1), s * 0.22)
	_rot(sk, "Bip01 Spine1", Vector3(0, 0, 1), s * 0.30)
	_rot(sk, "Bip01 Spine2", Vector3(0, 0, 1), s * 0.30)
	_rot(sk, "Bip01 Neck", Vector3(0, 0, 1), -s * 0.35 + _tw.y * 0.5)
	_rot(sk, "Bip01 Head", Vector3(0, 1, 0), head_tilt + _tw.x)
	_rot(sk, "Bip01 Head", Vector3(1, 0, 0), _tw.y * 0.5)
	_rot(sk, "Bip01 Head", Vector3(0, 0, 1), -s * 0.25 + _tw.z * 0.4)
	_rot(sk, "Bip01 MJaw", Vector3(0, 0, 1), -jaw * 0.38)
	_rot(sk, "jaw", Vector3(1, 0, 0), jaw * 0.8)
	# руки висят ниже и чуть вперёд, при reach — тянутся
	for side in ["L", "R"]:
		var sg := 1.0 if side == "L" else -1.0
		_rot(sk, "Bip01 %s UpperArm" % side, Vector3(0, 1, 0), sg * reach * -0.9)
		_rot(sk, "Bip01 %s Forearm" % side, Vector3(0, 0, 1), -reach * 0.4 - 0.15)
		for f in ["1", "2", "3", "4"]:
			_rot(sk, "Bip01 %s Finger%s" % [side, f], Vector3(0, 0, 1), 0.25 + reach * 0.3)
			_rot(sk, "Bip01 %s Finger%s1" % [side, f], Vector3(0, 0, 1), 0.3 + _tw.x * 0.5)
	if crawl > 0.01:
		_rot(sk, "Bip01 L Thigh", Vector3(0, 0, 1), crawl * 0.9)
		_rot(sk, "Bip01 R Thigh", Vector3(0, 0, 1), crawl * 0.9)
		_rot(sk, "Bip01 L Calf", Vector3(0, 0, 1), -crawl * 1.4)
		_rot(sk, "Bip01 R Calf", Vector3(0, 0, 1), -crawl * 1.4)
