class_name Tap
extends StaticBody3D
## Кран или душ. Открытая вода шумит и зовёт Хозяйку («кто-то моется»), горячая даёт пар.
## line — линия водопровода: если линия перекрыта (вентиль), кран сухой.

var line := ""
var shower := false
var hot := true
var room := ""
var running := false
var lure_t := 0.0
var blip_t := 0.0
var stream_mi: MeshInstance3D
var splash: GPUParticles3D
var snd: AudioStreamPlayer3D
var outlet := Vector3.ZERO     # откуда течёт (локально)
var floor_y := 0.0
var player_usable := true


static func make(parent: Node3D, pos: Vector3, yaw: float, is_shower: bool, line_id: String, room_id: String, floor_h: float) -> Tap:
	var t := Tap.new()
	t.shower = is_shower
	t.line = line_id
	t.room = room_id
	t.floor_y = floor_h
	t.collision_layer = 8
	t.collision_mask = 0
	parent.add_child(t)
	t.global_position = pos
	t.rotation.y = yaw
	t._build()
	return t


func _build() -> void:
	var metal := Mat.flat(Color(0.55, 0.55, 0.52), 0.3, 0.9)
	var rust := Mat.m("rust", {"metal": 0.5, "uv": true})
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.35, 0.3, 0.3)
	cs.shape = sh
	add_child(cs)
	if shower:
		# лейка под потолком, труба по стене
		var pipe := Geo.mesh_cyl(self, 0.016, 1.0, metal, Vector3(0, 0.5, 0.0))
		var arm := Geo.mesh_cyl(self, 0.014, 0.35, metal, Vector3(0, 1.0, -0.17))
		arm.rotation.x = PI * 0.5
		var head := Geo.mesh_cyl(self, 0.07, 0.04, metal, Vector3(0, 0.98, -0.34), 12, 0.03)
		outlet = Vector3(0, 0.95, -0.34)
		# смеситель
		Geo.mesh_box(self, Vector3(0.22, 0.06, 0.06), metal, Vector3(0, 0.0, -0.03))
		for x in [-0.09, 0.09]:
			Geo.mesh_cyl(self, 0.025, 0.04, rust, Vector3(x, 0.0, -0.07)).rotation.x = PI * 0.5
		cs.position = Vector3(0, 0.0, -0.1)
		head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# настенный кран с длинным носиком (как в мыльной)
		Geo.mesh_box(self, Vector3(0.18, 0.05, 0.05), metal, Vector3(0, 0, -0.025))
		var spout := Geo.mesh_cyl(self, 0.012, 0.2, metal, Vector3(0, -0.02, -0.12))
		spout.rotation.x = PI * 0.5
		Geo.mesh_cyl(self, 0.012, 0.06, metal, Vector3(0, -0.05, -0.22))
		for x in [-0.07, 0.07]:
			var hnd := Geo.mesh_cyl(self, 0.022, 0.03, rust if x < 0 else metal, Vector3(x, 0.035, -0.04))
		outlet = Vector3(0, -0.08, -0.22)
	# струя
	stream_mi = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.012 if not shower else 0.05
	cm.bottom_radius = 0.02 if not shower else 0.16
	cm.height = 1.0
	cm.radial_segments = 8
	stream_mi.mesh = cm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.75, 0.8, 0.85, 0.28)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.05
	wm.metallic_specular = 1.0
	wm.emission_enabled = true
	wm.emission = Color(0.1, 0.1, 0.12)
	stream_mi.material_override = wm
	stream_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream_mi)
	var top := to_global(outlet).y
	var len := maxf(0.2, top - floor_y)
	stream_mi.scale = Vector3(1, len, 1)
	stream_mi.position = outlet + Vector3(0, -len * 0.5, 0)
	stream_mi.visible = false
	running = bool(Game.getf("tap:" + _key(), false))
	if running:
		set_running(true, true)


func _key() -> String:
	return "%s_%d_%d" % [line, int(global_position.x * 10), int(global_position.z * 10)]


func line_open() -> bool:
	if line == "":
		return true
	return bool(Game.getf("line:" + line, false))


func is_running() -> bool:
	return running


func wash_point() -> Vector3:
	var p := to_global(outlet + Vector3(0, 0, -0.55))
	p.y = floor_y
	return p


func get_prompt(_p: Node) -> String:
	if not player_usable:
		return ""
	return ("Закрыть душ" if shower else "Закрыть кран") if running else ("Открыть душ" if shower else "Открыть кран")


func use(_p: Node) -> void:
	if running:
		set_running(false)
		return
	if not line_open():
		Snd.at("tap_dry", global_position, -4.0)
		Game.think("Сухо. Линия перекрыта.", 2.5)
		return
	set_running(true)


func set_running(on: bool, silent := false, by_monster := false) -> void:
	if on == running and not silent:
		return
	running = on
	Game.set_flag("tap:" + _key(), on)
	stream_mi.visible = on
	if on:
		if not silent:
			Snd.at("tap_open", global_position, -2.0)
		if snd == null:
			snd = Snd.attach("loop_shower" if shower else "loop_tap", self, -2.0 if shower else -5.0, 24.0)
			if snd:
				snd.position = outlet
		lure_t = 0.0
	else:
		if not silent:
			Snd.at("tap_close", global_position, -4.0 if not by_monster else 0.0)
		if snd:
			snd.queue_free()
			snd = null


## Короткий самопроизвольный «плевок» воды (пугалка).
func blip(secs: float) -> void:
	if running:
		return
	blip_t = secs
	stream_mi.visible = true
	Snd.at("tap_spit", global_position, 0.0)


func _physics_process(delta: float) -> void:
	if blip_t > 0.0:
		blip_t -= delta
		if blip_t <= 0.0 and not running:
			stream_mi.visible = false
	if not running:
		return
	if line != "" and not line_open():
		set_running(false, false)
		return
	stream_mi.scale.x = 1.0 + sin(Time.get_ticks_msec() * 0.03) * 0.08
	lure_t -= delta
	if lure_t <= 0.0:
		lure_t = 2.0
		if Game.world:
			var m: Hozyayka = Game.world.monster
			if m and m.is_active() and m.wash_tap != self:
				m.lure(self)
			Game.world.noise(global_position, 25.0, "water")
			if hot:
				Game.world.add_steam(room, 0.12 if shower else 0.06)
