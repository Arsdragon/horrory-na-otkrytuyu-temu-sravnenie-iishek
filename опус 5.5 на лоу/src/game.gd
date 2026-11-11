extends Node3D
## Партия: дом, контролёр, Жилец, события, фазы, смерть и финал.

signal finished(result)

var world
var player
var entity
var hud
var admin
var env: Environment
var paused := false
var admin_on := false
var admin_invisible := false
var admin_ignore := false
var admin_fast := false
var show_debug := false
var read_count := 0
var phase := 0
var over := false
var exit_open := false
var drone: AudioStreamPlayer
var heart: AudioStreamPlayer
var _heart_t := 0.0
var _event_t := 25.0
var _bulb_t := 0.0
var _noise_vis: Array = []
var notes_read := {}
var start_time := 0.0

func start(with_admin := false) -> void:
	admin_on = with_admin
	start_time = Time.get_ticks_msec() / 1000.0
	_environment()
	world = preload("res://src/world.gd").new()
	add_child(world)
	world.build(int(G.args.get("seed", 1994)))
	player = preload("res://src/player.gd").new()
	add_child(player)
	player.setup(self)
	player.global_position = Vector3(22.5, 0.05, 6)
	player.yaw = PI / 2
	entity = preload("res://src/entity.gd").new()
	add_child(entity)
	entity.setup(self)
	entity.global_position = Vector3(6, 9.05, 2.5)   # 4 этаж
	hud = preload("res://src/hud.gd").new()
	add_child(hud)
	hud.setup(self)
	admin = preload("res://src/admin.gd").new()
	add_child(admin)
	admin.setup(self)
	drone = AudioStreamPlayer.new()
	drone.stream = G.snd("drone", true)
	drone.volume_db = -6
	add_child(drone)
	drone.play()
	heart = AudioStreamPlayer.new()
	heart.stream = G.snd("heart")
	add_child(heart)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not G.args.has("bot") and not G.args.has("shot") and not G.args.has("stairs"):
		hud.intro()
	if admin_on: admin.toggle(true)

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.55)
	env.ambient_light_energy = 0.06
	env.fog_enabled = true
	env.fog_light_color = Color(0.02, 0.02, 0.025)
	env.fog_density = 0.04
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.65
	env.adjustment_contrast = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

# ------------------------------------------------------------ шум и события
func make_noise(pos: Vector3, radius: float) -> void:
	if over: return
	entity.hear(pos, radius)
	if show_debug: _show_noise(pos, radius)
	# дыхание в шкафу рядом с Жильцом
	if player.hidden and pos.distance_to(player.global_position) < 2.5 and entity.global_position.distance_to(pos) < radius * entity.hear_mult:
		if entity.state != entity.S.WARDROBE:
			G.log("Жилец услышал дыхание в шкафу")
			entity.check_wardrobe(player.hide_wardrobe)

func _show_noise(pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = r; sm.height = r * 2
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.3, 0.2, 0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	add_child(mi)
	mi.global_position = pos
	get_tree().create_timer(0.5).timeout.connect(mi.queue_free)

func on_glass(p: Vector3) -> bool:
	for g in world.glass:
		if abs(g.y - p.y) < 1.0 and Vector2(g.x - p.x, g.z - p.z).length() < 0.75: return true
	return false

func entity_dist() -> float:
	if entity == null: return 99.0
	return entity.global_position.distance_to(player.global_position)

func on_player_hid(w: Node3D) -> void:
	entity.saw_hide = entity.state == entity.S.CHASE and entity.seen_flag
	if entity.saw_hide: G.log("Жилец видел, как игрок залез в шкаф")

func on_chase_start() -> void:
	G.play2d("stinger", -4, 1.3)
	hud.shake(0.3)

func on_chase_end() -> void:
	pass

func _process(dt: float) -> void:
	if paused or over: return
	var d := entity_dist()
	# сердцебиение и тревога
	var fear: float = clamp(1.0 - (d - 2.0) / 14.0, 0.0, 1.0)
	if entity.state == entity.S.CHASE: fear = max(fear, 0.8)
	_heart_t -= dt
	if fear > 0.15 and _heart_t <= 0:
		_heart_t = lerp(1.2, 0.42, fear)
		heart.volume_db = lerp(-22.0, 2.0, fear)
		heart.play()
	drone.volume_db = lerp(-6.0, -20.0, fear)
	hud.fear = fear
	_random_events(dt)
	_bulbs(dt)

func _random_events(dt: float) -> void:
	_event_t -= dt
	if _event_t > 0: return
	_event_t = randf_range(22, 45)
	var pp: Vector3 = player.global_position
	var k := randi() % 5
	match k:
		0:  # стук в стену рядом
			G.play3d(self, pp + Vector3(randf_range(-4, 4), 0.5, randf_range(-3, 3)), "knock", -2, 3)
		1:  # телефон в квартире — Жилец идёт туда
			var p: Vector3 = world.random_point()
			G.play3d(self, p + Vector3(0, 1, 0), "phone", 0, 6)
			make_noise(p, 30)
		2:  # хлопок двери этажом выше/ниже
			G.play3d(self, pp + Vector3(randf_range(-8, 8), [-3.0, 3.0].pick_random(), 0), "slam", 4, 8)
		3:  # шёпот за спиной
			var back: Vector3 = player.cam.global_transform.basis.z
			G.play3d(self, player.cam.global_position + back * 1.2, "whisper", -8, 2)
		4:  # гудение проводки
			G.play3d(self, pp + Vector3(0, 2.5, 0), "buzz", -6, 3)

func _bulbs(dt: float) -> void:
	_bulb_t -= dt
	if _bulb_t > 0: return
	_bulb_t = 0.06
	for b in world.bulbs:
		var o: OmniLight3D = b[0]
		if not o.visible: continue
		var near: bool = entity.global_position.distance_to(o.global_position) < 6.0
		var r := randf()
		if near: o.light_energy = b[1] * (0.0 if r < 0.5 else randf())
		elif r < 0.02: o.light_energy = 0.0
		else: o.light_energy = b[1]
		b[4].visible = o.light_energy > 0.05

# ------------------------------------------------------------ счётчики, фазы
func meter_read(m: Node3D) -> void:
	m.set_meta("read", true)
	(m.get_meta("lamp") as OmniLight3D).light_color = Color(0.2, 1, 0.3)
	read_count += 1
	G.play2d("done")
	var val := "%05d" % randi_range(1000, 99999)
	hud.toast("Счётчик %d/10: %s кВт·ч — записано" % [read_count, val])
	G.log("Показание %d/10" % read_count)
	make_noise(m.global_position, 2.5)
	if read_count == 4 and phase < 1: set_phase(1)
	if read_count == 7 and phase < 2: set_phase(2)
	if read_count >= 10: _all_read()

func set_phase(p: int) -> void:
	phase = p
	if p >= 1:
		for b in world.bulbs:
			if b[3]: b[0].visible = false; b[4].visible = false
		G.play2d("buzz", 0, 0.6)
		G.play2d("stinger", -2)
		hud.toast("В подъезде погас свет.")
	if p >= 2:
		entity.speed_mult = 1.18
		entity.hear_mult = 1.35
		G.play3d(self, entity.global_position, "groan", 8, 10, 0.6)
		hud.toast("Где-то в доме кто-то глухо воет. Он стал внимательнее.")
	G.log("Фаза %d" % p)

func _all_read() -> void:
	exit_open = true
	G.play2d("radio", 0)
	hud.subtitle("Рация: «…Ракитин, приняли десять. Выход открыт, спускайся. …Погоди. А кто тогда сейчас на одиннадцатом счётчике?..»", 8.0)
	world.exit_door.get_child(1).material_override = G.mat("wood", 0.6, Color(0.2, 0.5, 0.25))
	hud.objective_override = "Спустись к двери подъезда на 1 этаже"
	# Жилец сразу идёт к выходу
	entity._go(Vector3(20, 0, 6), entity.S.INVESTIGATE)

func try_exit() -> void:
	if not exit_open:
		G.play2d("knock", -4, 1.3)
		hud.toast("Заперто снаружи. Откроют, когда передашь все 10 показаний (%d/10)." % read_count)
		return
	finish_win()

func finish_win() -> void:
	if over: return
	over = true
	player.locked = true
	G.log("ФИНАЛ")
	drone.stop()
	G.play2d("slam", 0, 0.8)
	var t := int(Time.get_ticks_msec() / 1000.0 - start_time)
	hud.end_screen(true, "Утром дом №7 опечатали.\n\nВ акте поверки указано: расход воды — 0, расход электроэнергии — 0, жильцов — 1.\n\nВы так и не вспомнили, кто ответил вам по рации.\n\nВремя: %d:%02d   Записок прочитано: %d/6" % [t / 60, t % 60, notes_read.size()])
	finished.emit("win")

func read_note(id: int) -> void:
	notes_read[id] = true
	hud.show_note(world.NOTES[id][0], world.NOTES[id][1])

# ------------------------------------------------------------ смерть
func kill(from_wardrobe := false) -> void:
	if over: return
	if player.god:
		hud.toast("(бессмертие) Жилец схватил бы вас")
		entity.state = entity.S.SEARCH
		entity.search_t = 3
		entity.global_position += (entity.global_position - player.global_position).normalized() * 3
		return
	over = true
	G.log("СМЕРТЬ")
	jumpscare()
	await get_tree().create_timer(1.5).timeout
	hud.end_screen(false, "АКТ О НЕДОПУСКЕ\n\nКонтролёр Ракитин Е. В. доступ к приборам учёта в доме №7 не обеспечил.\nМесто нахождения контролёра: не установлено.\n\nСнято показаний: %d/10" % read_count)
	finished.emit("dead")

func jumpscare() -> void:
	player.locked = true
	if player.hidden: player.unhide(); player.locked = true
	entity.frozen = true
	var cam: Camera3D = player.cam
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0
	fwd = fwd.normalized()
	entity.global_position = cam.global_position + fwd * 0.75 - Vector3(0, 1.95, 0)
	entity.rotation.y = atan2(-fwd.x, -fwd.z)
	entity.model.face_up = 1.0
	entity.model.head.rotation = Vector3(-0.35, 0, 0.3)
	var hp: Vector3 = entity.model.head.global_position
	entity.global_position += cam.global_position + fwd * 0.62 - hp
	player.pitch = 0.05
	if not player.light_on: player.toggle_light()
	player.light.light_energy = 3.0
	drone.stop()
	G.play2d("scream", 4)
	hud.shake(1.4)
	hud.flash()

func set_paused(p: bool) -> void:
	paused = p
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if p else Input.MOUSE_MODE_CAPTURED

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.keycode == KEY_ESCAPE and not over:
			if admin.visible_panel: admin.toggle(false)
			else: hud.toggle_pause()
		elif e.keycode == KEY_F1:
			admin.toggle(not admin.visible_panel)
	if e is InputEventMouseButton and e.pressed and not paused and not over and not admin.visible_panel:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
