extends Node
## Глобальное: настройки, звуки, аргументы запуска.

var sens := 0.0025
var volume := 0.8
var args := {}
var _snd := {}
var _mats := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		var s: String = a.trim_prefix("--")
		var i := s.find("=")
		if i < 0: args[s] = true
		else: args[s.substr(0, i)] = s.substr(i + 1)
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		sens = cf.get_value("s", "sens", sens)
		volume = cf.get_value("s", "volume", volume)
	apply_volume()

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("s", "sens", sens)
	cf.set_value("s", "volume", volume)
	cf.save("user://settings.cfg")
	apply_volume()

func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(max(volume, 0.001)))

func log(msg: String) -> void:
	print("LOG ", msg)

func snd(name: String, loop := false) -> AudioStream:
	var key := name + ("_L" if loop else "")
	if not _snd.has(key):
		var st: AudioStreamWAV = load("res://snd/%s.wav" % name)
		if loop:
			st = st.duplicate()
			st.loop_mode = AudioStreamWAV.LOOP_FORWARD
			st.loop_begin = 0
			st.loop_end = int(st.get_length() * st.mix_rate)
		_snd[key] = st
	return _snd[key]

func play2d(name: String, db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = snd(name)
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p

func play3d(parent: Node, pos: Vector3, name: String, db := 0.0, unit := 3.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = snd(name)
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 60.0
	p.pitch_scale = pitch
	p.attenuation_filter_cutoff_hz = 2500.0
	p.attenuation_filter_db = -18.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p

func mat(tex: String, scale := 1.0, tint := Color.WHITE, rough := 0.95) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [tex, scale, tint]
	if _mats.has(key): return _mats[key]
	var m := StandardMaterial3D.new()
	if tex != "":
		m.albedo_texture = load("res://tex/%s.png" % tex)
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
	m.albedo_color = tint
	m.roughness = rough
	_mats[key] = m
	return m

func shot_and_quit(vp: Viewport, path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(path)
	print("SHOT ", path)
	get_tree().quit()
