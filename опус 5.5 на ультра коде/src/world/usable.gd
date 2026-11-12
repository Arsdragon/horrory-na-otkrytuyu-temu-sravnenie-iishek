class_name Usable
extends StaticBody3D
## Универсальный предмет для взаимодействия: подсказка, мгновенное или долгое (удержание) действие.

var prompt := "Осмотреть"
var prompt_fn: Callable          # () -> String, если подсказка меняется
var on_use: Callable             # () -> void
var cond: Callable               # () -> String: "" можно, иначе текст отказа
var hold := 0.0                  # секунд удерживать E
var hold_sound := ""             # петля, пока держат
var hold_noise := 0.0            # радиус шума каждую секунду удержания
var once := false
var used := false
var tag := ""
var progress := 0.0              # для долгих действий (не сбрасывается)
var spin: Node3D = null          # колесо вентиля — крутится, пока держат
var _lp := 0.0


static func make(parent: Node, pos: Vector3, size: Vector3, text: String, fn: Callable, hold_secs := 0.0) -> Usable:
	var u := Usable.new()
	u.prompt = text
	u.on_use = fn
	u.hold = hold_secs
	u.collision_layer = 8
	u.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	u.add_child(cs)
	parent.add_child(u)
	u.global_position = pos
	return u


func get_prompt(_p: Node) -> String:
	if once and used:
		return ""
	if prompt_fn.is_valid():
		return String(prompt_fn.call())
	return prompt


func blocked() -> String:
	if cond.is_valid():
		return String(cond.call())
	return ""


func use(_p: Node) -> void:
	if once and used:
		return
	var why := blocked()
	if why != "":
		Game.think(why, 3.0)
		return
	used = true
	if on_use.is_valid():
		on_use.call()
	if once:
		collision_layer = 0


func _process(_d: float) -> void:
	if spin and not is_equal_approx(progress, _lp):
		spin.rotation.z += (progress - _lp) * 2.8
		_lp = progress
