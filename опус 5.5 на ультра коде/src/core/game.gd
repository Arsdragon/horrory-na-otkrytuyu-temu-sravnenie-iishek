extends Node
## Глобальное состояние прохождения: флаги, предметы, записки, сообщения, контрольные точки, сохранение.

signal flag_changed(name: String, value: Variant)
signal item_changed(id: String, have: bool)
signal note_added(id: String)
signal message_added(id: String)
signal objective_changed(text: String)
signal hint(text: String, secs: float)
signal thought(text: String, secs: float)

const SAVE_PATH := "user://save.json"

var admin := false
var cheats := {
	"god": false, "deaf": false, "noclip": false, "fullbright": false,
	"ai_debug": false, "no_monster": false, "steam_off": false,
}
var flags := {}
var items := {}
var notes: Array = []
var messages: Array = []
var objective := ""
var checkpoint := "c01_yard"
var snapshot := {}
var endings_seen: Array = []
var deaths := 0
var play_time := 0.0
var mute_phone := false
var bot := false

var world: Node = null
var player: Node = null
var monster: Node = null
var main: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load_meta()
	bot = "--bot" in OS.get_cmdline_user_args()


func _setup_input() -> void:
	var keys := {
		"move_f": [KEY_W, KEY_UP], "move_b": [KEY_S, KEY_DOWN], "move_l": [KEY_A, KEY_LEFT], "move_r": [KEY_D, KEY_RIGHT],
		"run": [KEY_SHIFT], "crouch": [KEY_CTRL, KEY_C], "use": [KEY_E], "flashlight": [KEY_F],
		"phone": [KEY_TAB], "breath": [KEY_SPACE], "pause": [KEY_ESCAPE], "admin": [KEY_F1], "fly": [KEY_F2],
		"drop": [KEY_G], "fly_up": [KEY_Q], "fly_down": [KEY_Z],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	for a in ["click", "use"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("click", lmb)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	if not InputMap.has_action("alt"):
		InputMap.add_action("alt")
	InputMap.action_add_event("alt", rmb)


func _process(delta: float) -> void:
	if world and not get_tree().paused:
		play_time += delta


# ---------- флаги и предметы ----------

func flag(name: String) -> bool:
	return bool(flags.get(name, false))


func getf(name: String, def: Variant = 0) -> Variant:
	return flags.get(name, def)


func set_flag(name: String, value: Variant = true) -> void:
	if flags.get(name) == value:
		return
	flags[name] = value
	flag_changed.emit(name, value)


func has(id: String) -> bool:
	return items.has(id)


func give(id: String, silent := false) -> void:
	if items.has(id):
		return
	items[id] = true
	item_changed.emit(id, true)
	if not silent:
		Snd.play("pickup", -4.0)


func take(id: String) -> void:
	if items.erase(id):
		item_changed.emit(id, false)


func add_note(id: String) -> void:
	if id in notes:
		return
	notes.append(id)
	note_added.emit(id)


func add_message(id: String) -> void:
	if id in messages:
		return
	messages.append(id)
	message_added.emit(id)


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


func show_hint(text: String, secs := 5.0) -> void:
	hint.emit(text, secs)


func think(text: String, secs := 4.0) -> void:
	thought.emit(text, secs)


# ---------- контрольные точки ----------

func reset_progress() -> void:
	flags = {}
	items = {}
	notes = []
	messages = []
	objective = ""
	checkpoint = "c01_yard"
	snapshot = {}
	play_time = 0.0
	mute_phone = false


func make_snapshot() -> Dictionary:
	return {
		"checkpoint": checkpoint, "flags": flags.duplicate(true), "items": items.duplicate(),
		"notes": notes.duplicate(), "messages": messages.duplicate(), "objective": objective,
		"mute": mute_phone, "time": play_time,
	}


func restore_snapshot(s: Dictionary) -> void:
	checkpoint = String(s.get("checkpoint", "c01_yard"))
	flags = (s.get("flags", {}) as Dictionary).duplicate(true)
	items = (s.get("items", {}) as Dictionary).duplicate()
	notes = (s.get("notes", []) as Array).duplicate()
	messages = (s.get("messages", []) as Array).duplicate()
	objective = String(s.get("objective", ""))
	mute_phone = bool(s.get("mute", false))
	play_time = float(s.get("time", 0.0))


func reach_checkpoint(id: String) -> void:
	checkpoint = id
	snapshot = make_snapshot()
	if not admin and not bot:
		save_game()


func has_save() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var d: Variant = _read_json()
	return d is Dictionary and (d as Dictionary).has("progress")


func save_game() -> void:
	var d := {"progress": snapshot, "endings": endings_seen, "deaths": deaths}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "  "))


func clear_save() -> void:
	var d := {"endings": endings_seen, "deaths": deaths}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "  "))


func load_save() -> bool:
	var d: Variant = _read_json()
	if not (d is Dictionary) or not (d as Dictionary).has("progress"):
		return false
	snapshot = (d as Dictionary)["progress"]
	restore_snapshot(snapshot)
	return true


func _read_json() -> Variant:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _load_meta() -> void:
	var d: Variant = _read_json()
	if d is Dictionary:
		endings_seen = (d as Dictionary).get("endings", [])
		deaths = int((d as Dictionary).get("deaths", 0))


func ending_seen(id: String) -> void:
	if not id in endings_seen:
		endings_seen.append(id)
	if not admin and not bot:
		clear_save()
