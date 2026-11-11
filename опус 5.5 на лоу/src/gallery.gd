extends Node3D
## Галерея: Жилец на вращающемся постаменте, все звуки, все записки, текстуры.

var model
var pivot: Node3D
var cam: Camera3D
var dist := 3.6
var note_l: Label
var lit: OmniLight3D

func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.02, 0.025)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.ambient_light_energy = 0.15
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	var floor := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 1.2; pm.bottom_radius = 1.3; pm.height = 0.2
	floor.mesh = pm; floor.position.y = -0.1
	floor.material_override = G.mat("concrete", 1.0)
	add_child(floor)
	pivot = Node3D.new(); add_child(pivot)
	model = preload("res://src/zhilets_model.gd").new()
	pivot.add_child(model)
	lit = OmniLight3D.new(); lit.position = Vector3(1.5, 2.5, 2); lit.light_energy = 1.6; lit.omni_range = 8
	lit.light_color = Color(1, 0.85, 0.7); lit.shadow_enabled = true
	add_child(lit)
	var rim := SpotLight3D.new(); rim.position = Vector3(-1.5, 3, -2); rim.light_energy = 2.0; rim.spot_range = 8
	rim.light_color = Color(0.5, 0.6, 1.0); add_child(rim); rim.look_at(Vector3(0, 1.2, 0))
	cam = Camera3D.new(); add_child(cam)
	_ui()

func _ui() -> void:
	var cl := CanvasLayer.new(); add_child(cl)
	var v := VBoxContainer.new()
	v.position = Vector2(16, 16)
	cl.add_child(v)
	var t := Label.new(); t.text = "ГАЛЕРЕЯ — Жилец"; t.add_theme_font_size_override("font_size", 26); v.add_child(t)
	var d := Label.new()
	d.text = "Рост ~2,3 м, сутулится. Халат в клетку, руки до колен.\nВместо лица — впадина. Голова висит у груди и дёргается.\nСлышит шум, видит только свет и тех, кто вплотную.\nКолесо мыши — приблизить. ЛКМ+тянуть — вращать."
	v.add_child(d)
	var h := HBoxContainer.new(); v.add_child(h)
	for x in [["Шаг", func(): model.speed = 0.4 if model.speed == 0 else 0.0], ["Бег", func(): model.speed = 1.0; model.lean = 1.0],
			["Поднять лицо", func(): model.face_up = 1.0 - model.face_up], ["Свет вкл/выкл", func(): lit.visible = not lit.visible]]:
		var b := Button.new(); b.text = x[0]; b.pressed.connect(x[1]); h.add_child(b)
	var l2 := Label.new(); l2.text = "Звуки:"; v.add_child(l2)
	var g := GridContainer.new(); g.columns = 6; v.add_child(g)
	for s in ["drone", "heart", "step0", "estep0", "estep1", "estep2", "groan", "whisper", "scream", "knock", "slam", "creak",
			"phone", "glass", "breath", "gasp", "stinger", "radio", "buzz", "page", "click", "done"]:
		var b := Button.new(); b.text = s; b.pressed.connect(func(): G.play2d(s)); g.add_child(b)
	var l3 := Label.new(); l3.text = "Записки:"; v.add_child(l3)
	var h2 := HBoxContainer.new(); v.add_child(h2)
	var notes = preload("res://src/world.gd").NOTES
	for i in notes.size():
		var b := Button.new(); b.text = str(i + 1)
		b.pressed.connect(func(): note_l.text = notes[i][0] + "\n\n" + notes[i][1])
		h2.add_child(b)
	note_l = Label.new(); note_l.custom_minimum_size = Vector2(480, 0); note_l.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(note_l)
	var tx := HBoxContainer.new(); v.add_child(tx)
	for n in ["wall", "floor", "concrete", "wood", "ceiling", "skin", "robe"]:
		var r := TextureRect.new(); r.texture = load("res://tex/%s.png" % n)
		r.custom_minimum_size = Vector2(56, 56); r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.tooltip_text = n
		tx.add_child(r)
	var back := Button.new(); back.text = "← В меню"; back.pressed.connect(func(): get_parent().show_menu()); v.add_child(back)

var _drag := false
var _yaw := 0.0
func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT: _drag = e.pressed
		if e.button_index == MOUSE_BUTTON_WHEEL_UP: dist = max(0.8, dist - 0.2)
		if e.button_index == MOUSE_BUTTON_WHEEL_DOWN: dist = min(7.0, dist + 0.2)
	if e is InputEventMouseMotion and _drag:
		_yaw -= e.relative.x * 0.01
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_parent().show_menu()

func _process(dt: float) -> void:
	if not _drag: _yaw += dt * 0.3
	pivot.rotation.y = _yaw
	var tgt := Vector3(0, 1.3 if dist > 1.5 else 1.9, 0)
	cam.position = Vector3(1.6, 1.6, dist)
	cam.look_at(tgt)
