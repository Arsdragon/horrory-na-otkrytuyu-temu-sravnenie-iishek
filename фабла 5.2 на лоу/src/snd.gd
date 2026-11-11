extends Node
## Audio autoload: one-shots (2D/3D) and named volume-controlled loops.

var streams: Dictionary = {}
var loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for f in DirAccess.get_files_at("res://assets/snd"):
		var n: String = f.replace(".import", "")
		if not n.ends_with(".wav"):
			continue
		var key: String = n.get_basename()
		if streams.has(key):
			continue
		var s: AudioStreamWAV = load("res://assets/snd/" + n)
		if s == null:
			continue
		if key.begins_with("loop_"):
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = 0
			s.loop_end = int(s.get_length() * s.mix_rate) - 1
		streams[key] = s


func play(name: String, db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	if not streams.has(name):
		return null
	var p := AudioStreamPlayer.new()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


func play3d(name: String, pos: Vector3, db: float = 0.0, max_dist: float = 30.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	if not streams.has(name):
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[name]
	p.volume_db = db
	p.pitch_scale = pitch
	p.max_distance = max_dist
	p.unit_size = max_dist / 4.0
	p.attenuation_filter_cutoff_hz = 9000.0
	add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Sets a named 2D loop to linear volume v (0 = silent, paused).
func loop(key: String, v: float, pitch: float = 1.0) -> void:
	var p: AudioStreamPlayer = loops.get(key)
	if p == null:
		if v <= 0.001 or not streams.has(key):
			return
		p = AudioStreamPlayer.new()
		p.stream = streams[key]
		add_child(p)
		p.play()
		loops[key] = p
	p.stream_paused = v <= 0.001
	p.volume_db = linear_to_db(max(v, 0.0001))
	p.pitch_scale = pitch


func stop_all() -> void:
	for c in get_children():
		c.queue_free()
	loops.clear()
