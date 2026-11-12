class_name World
extends Node3D
## Мир: строит баню, окружение, воду, пар, навигацию; создаёт игрока, Хозяйку, сценарий.
## Отвечает на вопросы «где я», «какой пол», «сколько воды», разносит шум.

signal noise_made(pos: Vector3, radius: float, kind: String)

static var nav_cache: NavigationMesh = null

var builder: Builder
var rooms := {}
var doors := {}
var env: Environment
var world_env: WorldEnvironment
var player: Player
var monster: Node = null
var director: Node = null
var scenario: Node = null
var nav: NavigationRegion3D
var waters := {}            # имя -> MeshInstance3D
var pool_level := -0.25
var drains: Array = []      # [{pos: Vector3, room: String}] — откуда она выходит
var taps: Array = []        # краны/души (узлы Tap)
var hides: Array = []       # шкафчики и полки
var dry_rects: Array = []   # [{rect: Rect2, y}] — сухие мостки в подвале
var steam := {}             # комната -> 0..1
var steam_vol := {}         # комната -> FogVolume
var steam_fx := {}          # комната -> GPUParticles3D
var noise_log: Array = []   # для отладки [{pos, r, t}]
var water_noise_tex: NoiseTexture2D
var moon: DirectionalLight3D
var spawn_pos := Vector3(26, 0.05, 44)
var spawn_yaw := 0.0
var ready_done := false
var time := 0.0


func _ready() -> void:
	Game.world = self
	build()


func build() -> void:
	var t0 := Time.get_ticks_msec()
	seed(1961)
	builder = Builder.new()
	builder.build(self)
	rooms = builder.rooms
	doors = builder.doors
	for id in rooms:
		(rooms[id]["node"] as Node3D).add_to_group("nav_src")
	var t1 := Time.get_ticks_msec()
	_environment()
	_waters()
	Props.furnish(self)
	var t2 := Time.get_ticks_msec()
	_nav()
	var t3 := Time.get_ticks_msec()
	print("  здание %d мс, предметы %d мс, навигация %d мс" % [t1 - t0, t2 - t1, t3 - t2])
	scenario = Scenario.new()
	scenario.name = "Scenario"
	add_child(scenario)
	scenario.setup(self)
	_spawn_player()
	_spawn_monster()
	scenario.start()
	ready_done = true
	print("мир построен за %d мс" % (Time.get_ticks_msec() - t0))


# ---------------------------------------------------------------- окружение

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.008, 0.01, 0.016)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.45)
	env.ambient_light_energy = 0.07
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.055, 0.065)
	env.fog_density = 0.018
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.08
	_apply_quality()
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.95)
	moon.light_energy = 0.35
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	moon.rotation = Vector3(deg_to_rad(-32), deg_to_rad(25), 0)
	moon.visible = false
	add_child(moon)
	Settings.changed.connect(_apply_quality)


func _apply_quality() -> void:
	if env == null:
		return
	var q := Settings.quality
	env.volumetric_fog_enabled = q >= 1
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.85, 0.85, 0.85)
	env.volumetric_fog_emission = Color(0, 0, 0)
	env.volumetric_fog_length = 32.0
	env.volumetric_fog_detail_spread = 2.0
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = 0.15
	env.volumetric_fog_temporal_reprojection_enabled = true
	env.ssao_enabled = q >= 2
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssil_enabled = false
	env.sdfgi_enabled = false
	env.adjustment_brightness = Settings.brightness * (1.6 if Game.cheats.get("fullbright", false) else 1.0)
	env.ambient_light_energy = 0.07 * Settings.brightness * (12.0 if Game.cheats.get("fullbright", false) else 1.0)
	RenderingServer.environment_set_volumetric_fog_volume_size(64 if q >= 2 else 48, 48 if q >= 2 else 32)
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2 if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.67 if q == 0 else (0.85 if q == 1 else 1.0)
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q >= 1 else Viewport.SCREEN_SPACE_AA_DISABLED
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q < 2 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_LOW if q < 2 else RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM)


# ---------------------------------------------------------------- вода

func _water_mat(murk: float, alpha := 0.55) -> ShaderMaterial:
	if water_noise_tex == null:
		water_noise_tex = NoiseTexture2D.new()
		water_noise_tex.seamless = true
		water_noise_tex.width = 256
		water_noise_tex.height = 256
		var fn := FastNoiseLite.new()
		fn.frequency = 0.02
		water_noise_tex.noise = fn
	var m := ShaderMaterial.new()
	m.shader = load("res://src/fx/water.gdshader")
	m.set_shader_parameter("murk", murk)
	m.set_shader_parameter("alpha_shallow", alpha)
	m.set_shader_parameter("noise_tex", water_noise_tex)
	return m


func _water_plane(name: String, rect: Rect2, y: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = "water_" + name
	var pm := PlaneMesh.new()
	pm.size = rect.size
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = Vector3(rect.get_center().x, y, rect.get_center().y)
	waters[name] = mi
	return mi


func _waters() -> void:
	for id in rooms:
		var d: Dictionary = rooms[id]["def"]
		if d.has("water"):
			var r: Rect2 = rooms[id]["rect"]
			_water_plane(id, r.grow(-0.1), float(d["y"]) + float(d["water"]), _water_mat(0.35, 0.5))
	pool_level = float(Game.getf("pool_level", -0.25))
	_water_plane("pool", Layout.POOL_BASIN, pool_level, _water_mat(1.0, 0.9))
	_water_plane("lobby_stairs", Layout.LOBBY_STAIRS, float(Game.getf("lobby_water", -0.9)), _water_mat(1.0, 0.95))


func set_pool_level(y: float) -> void:
	pool_level = y
	(waters["pool"] as MeshInstance3D).global_position.y = y
	(waters["pool"] as MeshInstance3D).visible = y > Layout.POOL_DEEP + 0.02


# ---------------------------------------------------------------- навигация

func _nav() -> void:
	nav = NavigationRegion3D.new()
	nav.name = "Nav"
	add_child(nav)
	var map := get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, 0.1)
	NavigationServer3D.map_set_cell_height(map, 0.05)
	if nav_cache:
		nav.navigation_mesh = nav_cache
		return
	var nm := NavigationMesh.new()
	nm.cell_size = 0.1
	nm.cell_height = 0.05
	nm.agent_radius = 0.2
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 48.0
	nm.region_min_size = 4.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = "nav_src"
	nm.filter_baking_aabb = AABB(Vector3(-1, -5, -19), Vector3(54, 11, 50))
	nav.navigation_mesh = nm
	nav.bake_navigation_mesh(false)
	nav_cache = nav.navigation_mesh
	print("  навмеш: полигонов ", nav_cache.get_polygon_count(), ", вершин ", nav_cache.get_vertices().size())


# ---------------------------------------------------------------- игрок и Хозяйка

func _spawn_player() -> void:
	player = Player.new()
	player.name = "Player"
	player.position = spawn_pos
	add_child(player)
	player.global_position = spawn_pos
	player.set_look(spawn_yaw)
	Game.player = player


func _spawn_monster() -> void:
	monster = Hozyayka.new()
	monster.name = "Hozyayka"
	add_child(monster)
	Game.monster = monster
	director = Director.new()
	director.name = "Director"
	add_child(director)
	director.setup(self)


# ---------------------------------------------------------------- запросы

func room_at(p: Vector3) -> String:
	for id in rooms:
		var r: Rect2 = rooms[id]["rect"]
		var y: float = rooms[id]["y"]
		var h: float = rooms[id]["h"]
		if p.x >= r.position.x and p.x <= r.end.x and p.z >= r.position.y and p.z <= r.end.y and p.y >= y - 2.6 and p.y <= y + h:
			if id == "b_stairs" and p.y > 0.2 and p.z > -0.1:
				continue
			return id
	return "outside"


func room_name(id: String) -> String:
	if rooms.has(id):
		return String(rooms[id]["def"]["name"])
	return "Двор"


func surface_at(p: Vector3, room := "") -> String:
	if room == "":
		room = room_at(p)
	if room == "outside":
		if p.x > 23.9 and p.x < 28.1 and p.z > 30.3 and p.z < 32.5:
			return "concrete"
		return "snow"
	var d: Dictionary = rooms[room]["def"]
	if room == "pool" and Layout.POOL_BASIN.has_point(Vector2(p.x, p.z)):
		return "tile"
	for dr in dry_rects:
		if (dr["rect"] as Rect2).has_point(Vector2(p.x, p.z)) and p.y >= float(dr["y"]) - 0.05:
			return "wood"
	var f: String = d["floor"]
	if f.begins_with("tile") or f == "terracotta":
		return "tile"
	if f.begins_with("planks") or f == "logs":
		return "wood"
	if f == "linoleum":
		return "lino"
	if f == "coal":
		return "coal"
	if f == "snow":
		return "snow"
	return "concrete"


func is_wet(p: Vector3, room := "") -> bool:
	if room == "":
		room = room_at(p)
	if not rooms.has(room):
		return false
	var d: Dictionary = rooms[room]["def"]
	if room == "lobby" and Game.flag("lobby_flooded"):
		return true
	if d.has("water"):
		return water_depth(p, room) > 0.0
	return bool(d.get("wet", false))


func water_depth(p: Vector3, room := "") -> float:
	if room == "":
		room = room_at(p)
	if room == "pool" and Layout.POOL_BASIN.has_point(Vector2(p.x, p.z)):
		return maxf(0.0, pool_level - p.y)
	for dr in dry_rects:
		if (dr["rect"] as Rect2).has_point(Vector2(p.x, p.z)) and p.y >= float(dr["y"]) - 0.05:
			return 0.0
	if rooms.has(room):
		var d: Dictionary = rooms[room]["def"]
		if d.has("water"):
			var lvl := float(d["y"]) + float(d["water"])
			if Game.flag("valve_closed"):
				lvl -= 0.06
			return maxf(0.0, lvl - p.y)
	if room == "lobby" and Game.flag("lobby_flooded"):
		return 0.04
	return 0.0


func is_safe(p: Vector3) -> bool:
	var room := room_at(p)
	if not rooms.has(room):
		return false
	if not rooms[room]["def"].get("safe", false):
		return false
	if Game.flag("salt_gone_" + room):
		return false
	return true


func room_rect(id: String) -> Rect2:
	return rooms[id]["rect"]


func room_center(id: String) -> Vector3:
	var r: Rect2 = rooms[id]["rect"]
	return Vector3(r.get_center().x, float(rooms[id]["y"]) + 0.05, r.get_center().y)


# ---------------------------------------------------------------- шум

## Любой звук, который может услышать Хозяйка.
func noise(pos: Vector3, radius: float, kind := "", in_water := false) -> void:
	if Game.cheats.get("deaf", false):
		return
	noise_log.append({"pos": pos, "r": radius, "t": time})
	if noise_log.size() > 30:
		noise_log.pop_front()
	noise_made.emit(pos, radius, kind)
	if monster and monster.has_method("hear"):
		monster.hear(pos, radius, kind, in_water)
	if director:
		director.on_noise(pos, radius, kind)


# ---------------------------------------------------------------- пар

func add_steam(room: String, amount: float) -> void:
	steam[room] = clampf(float(steam.get(room, 0.0)) + amount, 0.0, 1.0)


func steam_at(room: String) -> float:
	return float(steam.get(room, 0.0))


func _make_steam(room: String) -> void:
	if steam_vol.has(room) or not rooms.has(room):
		return
	var r: Rect2 = rooms[room]["rect"]
	var y: float = rooms[room]["y"]
	var h: float = rooms[room]["h"]
	var fv := FogVolume.new()
	fv.size = Vector3(r.size.x - 0.2, h, r.size.y - 0.2)
	fv.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	var fm := FogMaterial.new()
	fm.density = 0.0
	fm.albedo = Color(0.9, 0.9, 0.88)
	fm.edge_fade = 0.6
	fv.material = fm
	add_child(fv)
	fv.global_position = Vector3(r.get_center().x, y + h * 0.5, r.get_center().y)
	steam_vol[room] = fv
	var pr := GPUParticles3D.new()
	pr.amount = 70
	pr.lifetime = 7.0
	pr.preprocess = 4.0
	pr.visibility_aabb = AABB(Vector3(-r.size.x * 0.5, -1, -r.size.y * 0.5), Vector3(r.size.x, h + 2, r.size.y))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(r.size.x * 0.45, 0.5, r.size.y * 0.45)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0, 0.03, 0)
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	var curve := CurveTexture.new()
	var c := Curve.new()
	c.add_point(Vector2(0, 0))
	c.add_point(Vector2(0.3, 1))
	c.add_point(Vector2(1, 0))
	curve.curve = c
	pm.alpha_curve = curve
	pr.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(1.6, 1.6)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = Mat.tex("res://tex/ui/steam_puff.png")
	sm.albedo_color = Color(0.85, 0.85, 0.85, 0.0)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.proximity_fade_enabled = true
	sm.proximity_fade_distance = 1.0
	sm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	sm.distance_fade_min_distance = 0.2
	sm.distance_fade_max_distance = 1.4
	qm.material = sm
	pr.draw_pass_1 = qm
	add_child(pr)
	pr.global_position = Vector3(r.get_center().x, y + 0.6, r.get_center().y)
	pr.emitting = false
	steam_fx[room] = pr


func _update_steam(delta: float) -> void:
	for room in steam.keys():
		var v: float = steam[room]
		if Game.cheats.get("steam_off", false):
			v = 0.0
		if v > 0.01 and not steam_vol.has(room):
			_make_steam(room)
		if steam_vol.has(room):
			var fv: FogVolume = steam_vol[room]
			(fv.material as FogMaterial).density = v * 0.14
			var pr: GPUParticles3D = steam_fx[room]
			pr.emitting = v > 0.08
			var sm := (pr.draw_pass_1 as QuadMesh).material as StandardMaterial3D
			sm.albedo_color.a = clampf(v * 0.3, 0.0, 0.3)
		# пар оседает, если его не подпитывают
		steam[room] = maxf(0.0, v - delta * 0.012)


# ---------------------------------------------------------------- кадр

func _process(delta: float) -> void:
	time += delta
	_update_steam(delta)
	if player:
		_player_fog()


## Туман гуще, когда игрок в пару (на низком качестве объёмного тумана нет).
func _player_fog() -> void:
	var s := steam_at(player.current_room)
	env.fog_density = lerpf(env.fog_density, 0.018 + s * 0.07, 0.05)
	env.fog_light_color = Color(0.05, 0.055, 0.065).lerp(Color(0.12, 0.115, 0.11), s)


func player_room_changed(room: String) -> void:
	if moon:
		moon.visible = room == "outside"
	if Game.main and Game.main.get("prewarming"):
		return
	if rooms.has(room):
		var rv: Array = rooms[room]["def"].get("reverb", [0.5, 0.2])
		Snd.set_room(float(rv[0]), float(rv[1]))
	else:
		Snd.set_room(0.1, 0.02)
	if scenario and scenario.has_method("on_room"):
		scenario.on_room(room)


func free_world() -> void:
	Game.world = null
	Game.player = null
	Game.monster = null
	queue_free()
