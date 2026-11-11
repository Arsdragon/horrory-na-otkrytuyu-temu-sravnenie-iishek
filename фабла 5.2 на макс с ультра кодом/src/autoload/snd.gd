extends Node
## Звук: шины, загрузка сгенерированных звуков (res://snd, res://voice), разовые звуки и петли.
## Звуки с суффиксом _N (step_snow_1, step_snow_2…) — варианты одного звука: play("step_snow") берёт случайный.

var streams := {}      # имя -> AudioStream
var groups := {}       # префикс -> Array[String]
var loops := {}        # id -> {p, v, target, speed, kill}
var _last_pick := {}   # префикс -> последний выбранный вариант (чтобы не повторять подряд)
var _lp: AudioEffectLowPassFilter
var _wind_lp: AudioEffectLowPassFilter
var _reverb: AudioEffectReverb
var _muffle := 0.0
var _muffle_target := 0.0
var _indoor := 0.0
var _indoor_target := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_dir("res://snd/")
	_load_dir("res://voice/")
	Cfg.changed.connect(_apply_volumes)
	_apply_volumes()


func _add_bus(b: String, send: String) -> int:
	var i := AudioServer.get_bus_index(b)
	if i == -1:
		AudioServer.add_bus()
		i = AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b)
	AudioServer.set_bus_send(i, send)
	return i


func _setup_buses() -> void:
	_add_bus("Sfx", "Master")
	_add_bus("Amb", "Master")
	_add_bus("Voice", "Master")
	var wi := _add_bus("World", "Sfx")
	var wn := _add_bus("Wind", "Amb")
	_add_bus("Music", "Amb")
	_reverb = AudioEffectReverb.new()
	_reverb.room_size = 0.3
	_reverb.damping = 0.7
	_reverb.wet = 0.0
	_reverb.dry = 1.0
	_reverb.spread = 0.8
	AudioServer.add_bus_effect(wi, _reverb)
	_wind_lp = AudioEffectLowPassFilter.new()
	_wind_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(wn, _wind_lp)
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(0, _lp)
	var lim := AudioEffectHardLimiter.new()
	AudioServer.add_bus_effect(0, lim)


## Эхо помещения для звуков мира: размер 0..1, доля 0..1
func set_reverb(room: float, wet: float) -> void:
	_reverb.room_size = room
	_reverb.wet = wet


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(Cfg.vol_master, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sfx"), linear_to_db(maxf(Cfg.vol_sfx, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), linear_to_db(maxf(Cfg.vol_amb, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(Cfg.vol_voice, 0.0001)))


func _load_dir(dir: String) -> void:
	var files: PackedStringArray = ResourceLoader.list_directory(dir)
	for f in files:
		var fn := String(f)
		if fn.ends_with(".import") or fn.ends_with(".remap"):
			fn = fn.get_basename()
		if not (fn.ends_with(".ogg") or fn.ends_with(".wav")):
			continue
		var nm := fn.get_basename()
		if streams.has(nm):
			continue
		var st: AudioStream = load(dir + fn)
		if st == null:
			continue
		streams[nm] = st
		var base := nm
		var us := nm.rfind("_")
		if us > 0 and nm.substr(us + 1).is_valid_int():
			base = nm.substr(0, us)
		if not groups.has(base):
			groups[base] = []
		(groups[base] as Array).append(nm)


func _set_loop(st: AudioStream) -> void:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func has(snd: String) -> bool:
	return streams.has(snd) or groups.has(snd)


func names() -> Array:
	var a := streams.keys()
	a.sort()
	return a


func get_stream(snd: String) -> AudioStream:
	if groups.has(snd) and not streams.has(snd):
		var g: Array = groups[snd]
		var pick: String = g[randi() % g.size()]
		if g.size() > 1 and _last_pick.get(snd, "") == pick:
			pick = g[(g.find(pick) + 1 + randi() % (g.size() - 1)) % g.size()]
		_last_pick[snd] = pick
		return streams[pick]
	return streams.get(snd)


func length(snd: String) -> float:
	var st := get_stream(snd)
	if st == null:
		return 0.0
	return st.get_length()


## Реплика с голосом (voice/<ключ>.ogg). Возвращает длительность в секундах (0 — файла нет).
func voice(key: String, vol_db := 0.0) -> float:
	var st: AudioStream = streams.get(key)
	if st == null:
		return 0.0
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = vol_db
	p.bus = "Voice"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return st.get_length()


## Оборвать все разовые звуки (смена сцены, смерть).
func cut_oneshots() -> void:
	for c in get_children():
		var known := false
		for id in loops:
			if loops[id].p == c:
				known = true
				break
		if not known and (c is AudioStreamPlayer):
			c.queue_free()


## Неместный (2D) звук
func play(snd: String, vol_db := 0.0, pitch := 1.0, bus := "Sfx") -> AudioStreamPlayer:
	var st := get_stream(snd)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.bus = bus
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Звук в точке мира. parent — узел мира, чтобы звук удалялся вместе со сценой.
func play_at(snd: String, pos: Vector3, parent: Node, vol_db := 0.0, pitch := 1.0, max_dist := 60.0, unit := 4.0, bus := "World") -> AudioStreamPlayer3D:
	var st := get_stream(snd)
	if st == null or parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.max_distance = max_dist
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 5000.0
	p.attenuation_filter_db = -20.0
	parent.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p


## Постоянный звук в точке (дизель, печь, часы). Возвращает игрок, громкость меняется снаружи.
func emitter(snd: String, parent: Node3D, pos: Vector3, vol_db := 0.0, max_dist := 40.0, unit := 3.0, bus := "World") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var est: AudioStream = streams.get(snd)
	if est != null:
		est = est.duplicate()
		_set_loop(est)
	p.stream = est
	p.volume_db = vol_db
	p.unit_size = unit
	p.max_distance = max_dist
	p.bus = bus
	p.attenuation_filter_cutoff_hz = 5000.0
	p.attenuation_filter_db = -20.0
	parent.add_child(p)
	p.position = pos
	return p


## Зацикленный фоновый звук с плавной громкостью. vol — линейная 0..1
func loop(id: String, snd: String, vol := 1.0, fade := 1.5, bus := "Amb", pitch := 1.0) -> void:
	var L: Dictionary = loops.get(id, {})
	if L.is_empty() or String(L.get("snd", "")) != snd:
		if not L.is_empty():
			(L.p as AudioStreamPlayer).queue_free()
			loops.erase(id)
		var st: AudioStream = streams.get(snd)
		if st == null:
			return
		st = st.duplicate()
		_set_loop(st)
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = bus
		p.volume_db = -60.0
		p.pitch_scale = pitch
		add_child(p)
		p.play()
		L = {"p": p, "v": 0.0, "target": vol, "speed": 1.0 / maxf(fade, 0.01), "kill": false, "snd": snd}
		loops[id] = L
	else:
		L.target = vol
		L.speed = 1.0 / maxf(fade, 0.01)
		L.kill = false
		(L.p as AudioStreamPlayer).pitch_scale = pitch


func loop_vol(id: String, vol: float, fade := 0.5) -> void:
	if loops.has(id):
		var L: Dictionary = loops[id]
		L.target = vol
		L.speed = 1.0 / maxf(fade, 0.01)


func loop_pitch(id: String, pitch: float) -> void:
	if loops.has(id):
		(loops[id].p as AudioStreamPlayer).pitch_scale = pitch


func stop_loop(id: String, fade := 1.0) -> void:
	if loops.has(id):
		var L: Dictionary = loops[id]
		L.target = 0.0
		L.speed = 1.0 / maxf(fade, 0.01)
		L.kill = true


func stop_all(fade := 0.5) -> void:
	for id in loops.keys():
		stop_loop(id, fade)


## Приглушить весь звук (обморок, смерть). 0 — нет, 1 — сильно
func muffle(amount: float, instant := false) -> void:
	_muffle_target = clampf(amount, 0.0, 1.0)
	if instant:
		_muffle = _muffle_target


## Ветер снаружи слышен из помещения глухо. 0 — на улице, 1 — в доме за закрытой дверью
func set_indoor(amount: float, instant := false) -> void:
	_indoor_target = clampf(amount, 0.0, 1.0)
	if instant:
		_indoor = _indoor_target


func _process(dt: float) -> void:
	for id in loops.keys():
		var L: Dictionary = loops[id]
		var p: AudioStreamPlayer = L.p
		var v: float = L.v
		var tgt: float = L.target
		v = move_toward(v, tgt, float(L.speed) * dt)
		L.v = v
		p.volume_db = linear_to_db(maxf(v, 0.0001))
		if v <= 0.0001 and bool(L.kill):
			p.queue_free()
			loops.erase(id)
	_muffle = move_toward(_muffle, _muffle_target, dt * 1.5)
	_lp.cutoff_hz = lerpf(20000.0, 350.0, pow(_muffle, 0.5))
	_indoor = move_toward(_indoor, _indoor_target, dt * 2.5)
	_wind_lp.cutoff_hz = lerpf(20000.0, 420.0, pow(_indoor, 0.4))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Wind"), lerpf(0.0, -7.0, _indoor))
