extends Node
## Настройки игрока (user://settings.cfg), раскладка управления и аргументы запуска.

signal changed

const PATH := "user://settings.cfg"
const RES_LIST := [360, 480, 540, 720]

var sens := 1.0            # чувствительность мыши
var invert_y := false
var fov := 72.0
var vol_master := 0.9
var vol_sfx := 1.0
var vol_amb := 1.0
var vol_voice := 1.0
var res := 540             # высота 3D-кадра
var grain := 1.0           # сила зерна и «плёнки» 0..1.5
var fullscreen := true
var head_bob := true
var subtitles := true
var admin_key := false     # F1 открывает админ-панель и в обычной игре

## Отладочные аргументы командной строки после «--»: --key=value
var args := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_setup_input()
	load_cfg()
	apply()


func arg(key: String, def := "") -> String:
	return String(args.get(key, def))


func has_arg(key: String) -> bool:
	return args.has(key)


func argf(key: String, def := 0.0) -> float:
	if not args.has(key):
		return def
	return float(String(args[key]))


## Автоматический запуск (снимки, тесты, бот): не трогаем настройки и сохранения игрока.
func testing() -> bool:
	return has_arg("shot") or has_arg("test") or has_arg("bot") or has_arg("tour")


func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	sens = float(c.get_value("game", "sens", sens))
	invert_y = bool(c.get_value("game", "invert_y", invert_y))
	fov = float(c.get_value("game", "fov", fov))
	head_bob = bool(c.get_value("game", "head_bob", head_bob))
	subtitles = bool(c.get_value("game", "subtitles", subtitles))
	admin_key = bool(c.get_value("game", "admin_key", admin_key))
	vol_master = float(c.get_value("audio", "master", vol_master))
	vol_sfx = float(c.get_value("audio", "sfx", vol_sfx))
	vol_amb = float(c.get_value("audio", "amb", vol_amb))
	vol_voice = float(c.get_value("audio", "voice", vol_voice))
	res = int(c.get_value("video", "res", res))
	grain = float(c.get_value("video", "grain", grain))
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))
	if not res in RES_LIST:
		res = 540


func save_cfg() -> void:
	if testing():
		return
	var c := ConfigFile.new()
	c.set_value("game", "sens", sens)
	c.set_value("game", "invert_y", invert_y)
	c.set_value("game", "fov", fov)
	c.set_value("game", "head_bob", head_bob)
	c.set_value("game", "subtitles", subtitles)
	c.set_value("game", "admin_key", admin_key)
	c.set_value("audio", "master", vol_master)
	c.set_value("audio", "sfx", vol_sfx)
	c.set_value("audio", "amb", vol_amb)
	c.set_value("audio", "voice", vol_voice)
	c.set_value("video", "res", res)
	c.set_value("video", "grain", grain)
	c.set_value("video", "fullscreen", fullscreen)
	c.save(PATH)


func apply() -> void:
	if not testing():
		if fullscreen:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	changed.emit()


## Размер 3D-кадра под соотношение сторон окна (ширина чётная).
func frame_size(win: Vector2) -> Vector2i:
	var h := res
	var asp := 16.0 / 9.0
	if win.y > 1.0:
		asp = clampf(win.x / win.y, 1.25, 2.4)
	var w := int(round(h * asp))
	w += w % 2
	return Vector2i(w, h)


func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)


func _mouse(action: String, button: MouseButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var m := InputEventMouseButton.new()
	m.button_index = button
	InputMap.action_add_event(action, m)


func _setup_input() -> void:
	_key("move_f", [KEY_W, KEY_UP])
	_key("move_b", [KEY_S, KEY_DOWN])
	_key("move_l", [KEY_A, KEY_LEFT])
	_key("move_r", [KEY_D, KEY_RIGHT])
	_key("run", [KEY_SHIFT])
	_key("use", [KEY_E])
	_mouse("use", MOUSE_BUTTON_LEFT)
	_key("lamp", [KEY_F])
	_key("grip", [KEY_Q])
	_mouse("grip", MOUSE_BUTTON_RIGHT)
	_key("flare", [KEY_G])
	_key("notebook", [KEY_TAB])
	_key("breath", [KEY_SPACE])
	_key("walkie", [KEY_R])
	_key("pause", [KEY_ESCAPE])
	_key("admin", [KEY_F1])
	_key("freecam", [KEY_F2])
	_key("fly_up", [KEY_SPACE])
	_key("fly_down", [KEY_CTRL])
