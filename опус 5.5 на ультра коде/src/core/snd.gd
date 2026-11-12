extends Node
## Звук: банк звуков (snd/*.ogg), 2D и 3D проигрывание, петли, музыка, реверберация по помещению.
## Варианты одного звука называются name_1, name_2 … — play("name") берёт случайный.
## Файлы с префиксом loop_ зацикливаются.

const DIR := "res://snd/"

var _bank := {}      # базовое имя -> Array[String] путей
var _cache := {}     # путь -> AudioStream
var reverb: AudioEffectReverb
var lowpass: AudioEffectLowPassFilter
var _mus_a: AudioStreamPlayer
var _mus_b: AudioStreamPlayer
var music_name := ""
var _reverb_target := Vector2(0.5, 0.2)
var _muffle_target := 20000.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	_scan()
	Settings.apply()
	_mus_a = AudioStreamPlayer.new()
	_mus_b = AudioStreamPlayer.new()
	for p in [_mus_a, _mus_b]:
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)


func _make_buses() -> void:
	for b in ["Music", "SFX", "Amb", "Voice"]:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Amb"), "Master")
	AudioServer.set_bus_send(AudioServer.get_bus_index("Voice"), "SFX")
	var sfx := AudioServer.get_bus_index("SFX")
	reverb = AudioEffectReverb.new()
	reverb.room_size = 0.5
	reverb.damping = 0.35
	reverb.wet = 0.2
	reverb.dry = 1.0
	reverb.spread = 1.0
	reverb.predelay_msec = 25.0
	reverb.hipass = 0.15
	AudioServer.add_bus_effect(sfx, reverb)
	lowpass = AudioEffectLowPassFilter.new()
	lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(sfx, lowpass)
	var amb := AudioServer.get_bus_index("Amb")
	var lp2 := AudioEffectLowPassFilter.new()
	lp2.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(amb, lp2)


func _scan() -> void:
	_bank.clear()
	for f in DirAccess.get_files_at(DIR):
		var n := f.replace(".import", "").replace(".remap", "")
		if not (n.ends_with(".ogg") or n.ends_with(".wav")):
			continue
		var path := DIR + n
		var base := n.get_basename()
		var parts := base.rsplit("_", true, 1)
		var key := base
		if parts.size() == 2 and parts[1].is_valid_int():
			key = parts[0]
		if not _bank.has(key):
			_bank[key] = []
		if not path in _bank[key]:
			_bank[key].append(path)
		if key != base:
			_bank[base] = [path]


func has(name: String) -> bool:
	return _bank.has(name)


func names() -> Array:
	var a := _bank.keys()
	a.sort()
	return a


func stream(name: String) -> AudioStream:
	if not _bank.has(name):
		push_warning("нет звука " + name)
		return null
	var list: Array = _bank[name]
	var path: String = list[randi() % list.size()]
	if not _cache.has(path):
		var s: AudioStream = load(path)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = name.begins_with("loop_")
		elif s is AudioStreamWAV and name.begins_with("loop_"):
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)
		_cache[path] = s
	return _cache[path]


func play(name: String, db := 0.0, pitch := 1.0, bus := "SFX") -> AudioStreamPlayer:
	var s := stream(name)
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	if not name.begins_with("loop_"):
		p.finished.connect(p.queue_free)
	return p


func _root3d() -> Node:
	if Game.world and is_instance_valid(Game.world):
		return Game.world
	return get_tree().current_scene


func at(name: String, pos: Vector3, db := 0.0, pitch := 1.0, dist := 25.0, bus := "SFX") -> AudioStreamPlayer3D:
	var s := stream(name)
	var root := _root3d()
	if s == null or root == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.pitch_scale = pitch
	p.bus = bus
	p.max_distance = dist
	p.unit_size = clampf(dist / 6.0, 2.0, 8.0)
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -12.0
	root.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Звук, привязанный к узлу (двигается вместе с ним). Петли живут, пока их не удалят.
func attach(name: String, node: Node3D, db := 0.0, dist := 20.0, bus := "SFX", pitch := 1.0) -> AudioStreamPlayer3D:
	var s := stream(name)
	if s == null or node == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = db
	p.bus = bus
	p.pitch_scale = pitch
	p.max_distance = dist
	p.unit_size = clampf(dist / 6.0, 1.5, 8.0)
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -12.0
	node.add_child(p)
	p.play()
	if not name.begins_with("loop_"):
		p.finished.connect(p.queue_free)
	return p


func music(name: String, db := -6.0, fade := 2.5) -> void:
	if name == music_name:
		return
	music_name = name
	var old := _mus_a if _mus_a.playing else _mus_b
	var nw := _mus_b if old == _mus_a else _mus_a
	if old.playing:
		var t := create_tween()
		t.tween_property(old, "volume_db", -80.0, fade)
		t.tween_callback(old.stop)
	if name != "":
		var s := stream(name)
		if s:
			nw.stream = s
			nw.volume_db = -60.0
			nw.play()
			var t2 := create_tween()
			t2.tween_property(nw, "volume_db", db, fade)


func stop_all_3d() -> void:
	music("")


## Размер и «мокрость» эха текущего помещения (вызывает игрок при смене комнаты).
func set_room(size: float, wet: float) -> void:
	_reverb_target = Vector2(size, wet)


## Приглушить мир (шкафчик, вода над головой, смерть).
func muffle(on: bool, cutoff := 700.0) -> void:
	_muffle_target = cutoff if on else 20000.0


func _process(delta: float) -> void:
	if reverb:
		reverb.room_size = lerpf(reverb.room_size, _reverb_target.x, delta * 2.0)
		reverb.wet = lerpf(reverb.wet, _reverb_target.y, delta * 2.0)
	if lowpass:
		lowpass.cutoff_hz = exp(lerpf(log(lowpass.cutoff_hz), log(_muffle_target), clampf(delta * 6.0, 0.0, 1.0)))
		var amb := AudioServer.get_bus_index("Amb")
		var lp := AudioServer.get_bus_effect(amb, 0) as AudioEffectLowPassFilter
		if lp:
			lp.cutoff_hz = lowpass.cutoff_hz
