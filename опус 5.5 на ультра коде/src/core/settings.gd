extends Node
## Настройки игрока. Хранятся в user://settings.cfg (%APPDATA%\TretiyPar).

signal changed

const PATH := "user://settings.cfg"

var mouse_sens := 0.22
var invert_y := false
var fov := 72.0
var vol_master := 0.9
var vol_music := 0.8
var vol_sfx := 1.0
var vol_voice := 1.0
var brightness := 1.0      # 0.6 .. 1.6
var quality := 1           # 0 низкое, 1 среднее, 2 высокое
var fullscreen := true
var vsync := true
var hints := true
var head_bob := true

const KEYS := ["mouse_sens", "invert_y", "fov", "vol_master", "vol_music", "vol_sfx", "vol_voice",
	"brightness", "quality", "fullscreen", "vsync", "hints", "head_bob"]


func _ready() -> void:
	load_cfg()
	apply()


func load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in KEYS:
		if cf.has_section_key("s", k):
			set(k, cf.get_value("s", k))


func save_cfg() -> void:
	var cf := ConfigFile.new()
	for k in KEYS:
		cf.set_value("s", k, get(k))
	cf.save(PATH)


func apply() -> void:
	if not DisplayServer.get_name().begins_with("headless"):
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if "--windowed" in OS.get_cmdline_user_args() or "--shot" in " ".join(OS.get_cmdline_user_args()):
			want = DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	_bus("Master", vol_master)
	_bus("Music", vol_music)
	_bus("SFX", vol_sfx)
	_bus("Amb", vol_sfx)
	_bus("Voice", vol_voice)
	changed.emit()


func _bus(name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(name)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
