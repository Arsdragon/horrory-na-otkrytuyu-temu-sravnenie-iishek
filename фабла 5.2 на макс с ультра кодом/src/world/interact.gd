class_name Interactable
extends Area3D
## Предмет, с которым можно что-то сделать: игрок смотрит на него с 2,3 м и жмёт E (или держит).

var prompt := ""              # «Открыть», «Снять показания»…
var hold := 0.0               # сколько секунд держать (0 — сразу)
var enabled := true
var need_light := false       # нужен включённый фонарь
var keep_progress := false    # прогресс удержания не сбрасывается, если отвлёкся
var progress := 0.0           # 0..1
var look_lock := true         # при удержании нельзя отворачиваться
var on_use := Callable()      # ()
var on_hold := Callable()     # (active: bool) — начало и конец удержания
var cond := Callable()        # () -> String: "" — можно, иначе причина


static func make(parent: Node, pos: Vector3, size: Vector3, prompt_text: String, use: Callable, hold_time := 0.0) -> Interactable:
	var it := Interactable.new()
	it.prompt = prompt_text
	it.on_use = use
	it.hold = hold_time
	it.collision_layer = 2
	it.collision_mask = 0
	it.monitoring = false
	it.monitorable = true
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	it.add_child(cs)
	it.position = pos
	parent.add_child(it)
	return it


## Причина, по которой сейчас нельзя ("" — можно).
func blocked(lamp_on: bool) -> String:
	if need_light and not lamp_on:
		return "Нужен свет"
	if cond.is_valid():
		return String(cond.call())
	return ""


func use() -> void:
	if on_use.is_valid():
		on_use.call()
