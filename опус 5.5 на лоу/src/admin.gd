extends CanvasLayer
## Админ-панель (F1): просмотр контента и отладка.

var game
var visible_panel := false
var panel: PanelContainer
var info: Label
var dbg: Node3D

func setup(g) -> void:
	game = g
	layer = 10
	panel = PanelContainer.new()
	panel.position = Vector2(12, 90)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.05, 0.07, 0.88)
	sb.border_color = Color(0.6, 0.2, 0.2)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(330, 600)
	panel.add_child(sc)
	var v := VBoxContainer.new()
	sc.add_child(v)
	var t := Label.new(); t.text = "АДМИН-РЕЖИМ  (F1 — скрыть)"; t.add_theme_color_override("font_color", Color(1, 0.5, 0.4))
	v.add_child(t)
	info = Label.new(); info.add_theme_font_size_override("font_size", 13); v.add_child(info)
	_chk(v, "Полёт сквозь стены (V)", func(on): game.player.set_noclip(on), func(): return game.player.noclip)
	_chk(v, "Бессмертие", func(on): game.player.god = on, func(): return game.player.god)
	_chk(v, "Жилец заморожен", func(on): game.entity.frozen = on, func(): return game.entity.frozen)
	_chk(v, "Жилец не видит игрока", func(on): game.admin_invisible = on, func(): return game.admin_invisible)
	_chk(v, "Быстрый бег", func(on): game.admin_fast = on, func(): return game.admin_fast)
	_chk(v, "Маршруты и волны шума", func(on): _debug(on), func(): return game.show_debug)
	_chk(v, "Полный свет (без тьмы и тумана)", func(on): _bright(on), func(): return game.env.ambient_light_energy > 0.5)
	_chk(v, "Бесконечный фонарь", func(on): set_meta("inf", on), func(): return has_meta("inf") and get_meta("inf"))
	var h := HBoxContainer.new(); v.add_child(h)
	var l := Label.new(); l.text = "Этаж:"; h.add_child(l)
	for i in 5:
		var b := Button.new(); b.text = str(i + 1); h.add_child(b)
		b.pressed.connect(func(): _tp(Vector3(0.8, i * 3.0 + 0.1, 6)))
	_btn(v, "Телепорт к Жильцу", func(): _tp(game.entity.global_position + Vector3(2, 0.1, 0)))
	_btn(v, "Жилец ко мне (за спину)", func(): _summon())
	_btn(v, "Жилец: погоня", func(): game.entity._start_chase())
	_btn(v, "Жилец: на обход", func(): game.entity._go(game.entity._pick_patrol(), game.entity.S.PATROL))
	_btn(v, "Телепорт к непроверенному счётчику", func(): _tp_meter())
	_btn(v, "+1 показание", func(): _read_one())
	_btn(v, "Все 10 показаний", func(): for i in 10: _read_one())
	_btn(v, "Фаза 1 (свет гаснет)", func(): game.set_phase(1))
	_btn(v, "Фаза 2 (Жилец злее)", func(): game.set_phase(2))
	_btn(v, "Показать скример", func(): _scare())
	_btn(v, "Концовка: победа", func(): game.finish_win())
	_btn(v, "Концовка: смерть", func(): var gd = game.player.god; game.player.god = false; game.kill(); game.player.god = gd)
	_btn(v, "Событие: телефон", func(): game._event_t = 0)
	var l2 := Label.new(); l2.text = "Звуки:"; v.add_child(l2)
	var grid := GridContainer.new(); grid.columns = 3; v.add_child(grid)
	for s in ["drone", "heart", "estep0", "estep2", "groan", "whisper", "scream", "knock", "slam", "creak", "phone", "glass", "breath", "gasp", "stinger", "radio", "buzz", "page"]:
		var b := Button.new(); b.text = s; b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): G.play2d(s))
		grid.add_child(b)
	_btn(v, "Все записки (по очереди)", func(): _notes())
	panel.visible = false

var _checks := []
func _chk(v: Control, text: String, set_cb: Callable, get_cb: Callable) -> void:
	var c := CheckBox.new()
	c.text = text
	c.toggled.connect(set_cb)
	v.add_child(c)
	_checks.append([c, get_cb])

func _btn(v: Control, text: String, cb: Callable) -> void:
	var b := Button.new(); b.text = text; b.pressed.connect(cb); v.add_child(b)

func toggle(on: bool) -> void:
	visible_panel = on
	panel.visible = on
	for c in _checks: c[0].set_pressed_no_signal(c[1].call())
	if game.over: return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if on else Input.MOUSE_MODE_CAPTURED

func _process(_dt: float) -> void:
	if has_meta("inf") and get_meta("inf"): game.player.battery = 100.0
	if not visible_panel: return
	var e = game.entity
	var p = game.player
	info.text = "Игрок: %s  этаж %d\nЖилец: %s, %.1f м, этаж %d\nвидит: %s  слух ×%.2f  скорость ×%.2f\nФаза %d   показаний %d/10   FPS %d" % [
		_v(p.global_position), game.world.level_of(p.global_position) + 1, e.state_name(), game.entity_dist(),
		game.world.level_of(e.global_position) + 1, "да" if e.seen_flag else "нет", e.hear_mult, e.speed_mult,
		game.phase, game.read_count, Engine.get_frames_per_second()]
	if dbg: _draw_path()

func _v(v: Vector3) -> String: return "(%.1f, %.1f, %.1f)" % [v.x, v.y, v.z]

func _tp(pos: Vector3) -> void:
	if game.player.hidden: game.player.unhide()
	game.player.global_position = pos
	game.player.velocity = Vector3.ZERO

func _summon() -> void:
	var p = game.player
	var back: Vector3 = p.global_transform.basis.z
	game.entity.global_position = p.global_position + back * 3.0 + Vector3(0, 0.1, 0)
	game.entity.state = game.entity.S.IDLE
	game.entity.idle_t = 3

func _tp_meter() -> void:
	for m in game.world.meters:
		if not m.get_meta("read"):
			var a: Vector3 = m.global_position
			var off := Vector3(0, 0, 0.9 if a.z < 6 else -0.9)
			_tp(Vector3(a.x, a.y - 1.45, a.z) - off)
			game.player.yaw = 0.0 if a.z < 6 else PI
			game.player.pitch = 0
			return

func _read_one() -> void:
	for m in game.world.meters:
		if not m.get_meta("read"):
			game.meter_read(m)
			return

func _scare() -> void:
	var gd = game.player.god
	game.jumpscare()
	await get_tree().create_timer(1.6).timeout
	game.player.locked = false
	game.entity.frozen = false
	game.entity.model.face_up = 0.0
	game.entity.global_position += Vector3(0, 0, 0)
	game.entity._go(game.entity._pick_patrol(), game.entity.S.PATROL)
	game.drone.play()
	toggle(true)

var _note_i := 0
func _notes() -> void:
	game.read_note(_note_i % 6)
	_note_i += 1

func _bright(on: bool) -> void:
	game.env.ambient_light_energy = 1.2 if on else 0.06
	game.env.fog_enabled = not on

var _mesh: ImmediateMesh
func _debug(on: bool) -> void:
	game.show_debug = on
	if not on:
		if dbg: dbg.queue_free(); dbg = null
		return
	dbg = Node3D.new()
	game.add_child(dbg)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.3, 1, 0.4)
	m.no_depth_test = true
	var a: AStar3D = game.world.astar
	for id in a.get_point_ids():
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new(); sm.radius = 0.08; sm.height = 0.16
		s.mesh = sm; s.material_override = m
		dbg.add_child(s)
		s.global_position = a.get_point_position(id)
	var lines := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES, m)
	for id in a.get_point_ids():
		for c in a.get_point_connections(id):
			if c > id:
				im.surface_add_vertex(a.get_point_position(id)); im.surface_add_vertex(a.get_point_position(c))
	im.surface_end()
	lines.mesh = im
	dbg.add_child(lines)
	var pm := MeshInstance3D.new()
	_mesh = ImmediateMesh.new()
	pm.mesh = _mesh
	dbg.add_child(pm)

func _draw_path() -> void:
	var e = game.entity
	_mesh.clear_surfaces()
	if e.path.size() == 0: return
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1, 0.2, 0.2)
	m.no_depth_test = true
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, m)
	_mesh.surface_add_vertex(e.global_position + Vector3(0, 0.3, 0))
	for i in range(e.path_i, e.path.size()):
		_mesh.surface_add_vertex(e.path[i] + Vector3(0, 0.2, 0))
	_mesh.surface_add_vertex(e.path[e.path.size() - 1] + Vector3(0, 0.25, 0))
	_mesh.surface_end()
