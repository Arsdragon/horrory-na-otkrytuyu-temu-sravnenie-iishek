class_name Weather
extends Node3D
## Пурга: туман, снежные частицы вокруг камеры, порывы ветра, звук ветра.
## Ветер всегда дует с северо-запада на юго-восток — по нему можно ориентироваться.

signal gust_started(strength: float)
signal gust_ended

const WIND_DIR := Vector3(0.7071, 0.0, 0.7071)     # куда дует: +X восток, +Z юг

var env: Environment
var flakes: GPUParticles3D
var drift: GPUParticles3D
var base := 0.55          # сила пурги 0..1 — задаёт режиссёр
var gust := 0.0           # текущий порыв 0..1
var auto_gusts := true
var gust_min := 18.0
var gust_max := 38.0
var clear := 0.0          # админ: убрать пургу 0..1
var bright := 0.0         # админ: полный свет 0..1
var indoor := 0.0         # 0 — на улице, 1 — в помещении
var vis := 14.0           # текущая дальность видимости, м
var lamp_on := false
var fire_light := 0.0     # фальшфейер/костры подсвечивают туман красным 0..1
var cam: Node3D = null

var _t_next := 12.0
var _g_phase := 0         # 0 нет, 1 нарастает, 2 держится, 3 спадает
var _g_time := 0.0
var _g_hold := 4.0
var _g_peak := 0.8
var _vis_s := 14.0
var _fog_col := Color(0.012, 0.015, 0.02)


func _ready() -> void:
	_build_env()
	_build_particles()
	_t_next = randf_range(8.0, 16.0)
	if Snd.streams.has("wind_low"):
		Snd.loop("wind_low", "wind_low", 0.0, 2.0, "Wind")
		Snd.loop("wind_howl", "wind_howl", 0.0, 2.0, "Wind")
		Snd.loop("wind_whistle", "wind_whistle", 0.0, 2.0, "Wind")
		Snd.loop("snow_hiss", "snow_hiss", 0.0, 2.0, "Wind")


func _exit_tree() -> void:
	for id in ["wind_low", "wind_howl", "wind_whistle", "snow_hiss"]:
		Snd.stop_loop(id, 0.6)
	RenderingServer.global_shader_parameter_set("g_gust", 0.0)
	RenderingServer.global_shader_parameter_set("g_clear", 0.0)


func _build_env() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.0, 0.0, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.42, 0.6)
	env.ambient_light_energy = 0.11
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = _fog_col
	env.fog_light_energy = 1.0
	env.fog_sun_scatter = 0.0
	env.fog_density = 1.0
	env.fog_sky_affect = 1.0
	env.fog_depth_curve = 0.75
	env.fog_depth_begin = 1.0
	env.fog_depth_end = 14.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.9
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _flake_mat(bright_k: float) -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = load("res://src/shaders/flake.gdshader")
	sm.set_shader_parameter("tex", Kit.tex("res://tex/flake"))
	sm.set_shader_parameter("bright", bright_k)
	return sm


func _build_particles() -> void:
	# основной слой: косые штрихи снега вокруг камеры
	flakes = GPUParticles3D.new()
	flakes.amount = 4200
	flakes.lifetime = 1.1
	flakes.preprocess = 1.1
	flakes.local_coords = false
	flakes.fixed_fps = 0
	flakes.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	flakes.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 20, 80))
	flakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9.0, 3.2, 9.0)
	pm.direction = Vector3(WIND_DIR.x, -0.12, WIND_DIR.z).normalized()
	pm.spread = 7.0
	pm.initial_velocity_min = 9.0
	pm.initial_velocity_max = 15.0
	pm.gravity = Vector3(0, -0.8, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 1.6
	pm.turbulence_noise_scale = 2.4
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.18
	pm.scale_min = 0.6
	pm.scale_max = 1.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0))
	grad.add_point(0.15, Color(1, 1, 1, 1))
	grad.add_point(0.8, Color(1, 1, 1, 1))
	grad.set_color(grad.get_point_count() - 1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	flakes.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.022, 0.2)
	qm.material = _flake_mat(1.0)
	flakes.draw_pass_1 = qm
	add_child(flakes)

	# позёмка: длинные быстрые штрихи у самой земли
	drift = GPUParticles3D.new()
	drift.amount = 2200
	drift.lifetime = 0.9
	drift.preprocess = 0.9
	drift.local_coords = false
	drift.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	drift.visibility_aabb = AABB(Vector3(-40, -10, -40), Vector3(80, 20, 80))
	drift.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var dm := ParticleProcessMaterial.new()
	dm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dm.emission_box_extents = Vector3(11.0, 0.22, 11.0)
	dm.direction = WIND_DIR
	dm.spread = 4.0
	dm.initial_velocity_min = 13.0
	dm.initial_velocity_max = 20.0
	dm.gravity = Vector3(0, -0.2, 0)
	dm.scale_min = 0.7
	dm.scale_max = 1.6
	dm.color_ramp = gt
	drift.process_material = dm
	var qd := QuadMesh.new()
	qd.size = Vector2(0.03, 0.55)
	qd.material = _flake_mat(0.8)
	drift.draw_pass_1 = qd
	add_child(drift)


## Запустить порыв вручную (сценарий): сила 0..1, сколько держится.
func force_gust(strength := 0.9, hold := 5.0) -> void:
	_g_phase = 1
	_g_time = 0.0
	_g_peak = strength
	_g_hold = hold
	gust_started.emit(strength)


func in_gust() -> bool:
	return gust > 0.45


## Сила ветра для игрока и существа 0..1.3
func intensity() -> float:
	return clampf(base + gust * 0.55, 0.0, 1.3)


func _process(dt: float) -> void:
	# расписание порывов
	if _g_phase == 0:
		if auto_gusts and base > 0.2:
			_t_next -= dt
			if _t_next <= 0.0:
				force_gust(randf_range(0.7, 1.0), randf_range(3.0, 6.5))
	elif _g_phase == 1:
		_g_time += dt
		gust = minf(_g_peak, gust + dt * 0.75)
		if gust >= _g_peak - 0.001:
			_g_phase = 2
			_g_time = 0.0
	elif _g_phase == 2:
		_g_time += dt
		gust = _g_peak * (0.9 + 0.1 * sin(_g_time * 5.0))
		if _g_time >= _g_hold:
			_g_phase = 3
	else:
		gust = maxf(0.0, gust - dt * 0.42)
		if gust <= 0.0:
			_g_phase = 0
			_t_next = randf_range(gust_min, gust_max)
			gust_ended.emit()

	var I := intensity()
	var out := 1.0 - indoor
	# видимость
	var target := lerpf(26.0, 10.0, clampf(base, 0.0, 1.0)) * lerpf(1.0, 0.3, gust)
	target = lerpf(target, 260.0, clear)
	_vis_s = lerpf(_vis_s, target, clampf(dt * 2.2, 0.0, 1.0))
	vis = _vis_s
	env.fog_depth_end = lerpf(vis, 60.0, indoor * (1.0 - clear))
	env.fog_depth_begin = lerpf(vis * 0.08, 8.0, indoor)
	# цвет тумана: чёрно-синий; фонарь даёт молочную засветку, огонь — красную
	var c := _fog_col
	if lamp_on:
		c = c.lerp(Color(0.05, 0.056, 0.066), 0.55 + 0.45 * I)
	c = c.lerp(Color(0.16, 0.035, 0.02), clampf(fire_light, 0.0, 1.0) * 0.8)
	c = c.lerp(Color(0.02, 0.03, 0.05), clear)
	c = c.lerp(Color(0.0, 0.0, 0.0), indoor)
	env.fog_light_color = env.fog_light_color.lerp(c, clampf(dt * 5.0, 0.0, 1.0))
	env.ambient_light_energy = lerpf(0.11, 0.9, bright) + clear * 0.08
	env.ambient_light_color = Color(0.32, 0.42, 0.6).lerp(Color(1, 1, 1), bright)

	# частицы едут за камерой, чуть с наветренной стороны
	if cam != null and is_instance_valid(cam):
		var cp := cam.global_position
		flakes.global_position = cp - WIND_DIR * 5.0 + Vector3(0, 0.6, 0)
		drift.global_position = Vector3(cp.x, 0.2, cp.z) - WIND_DIR * 7.0
	var dens := clampf(lerpf(0.25, 1.0, I), 0.0, 1.0) * out * (1.0 - clear * 0.92)
	flakes.amount_ratio = dens
	drift.amount_ratio = clampf(I, 0.0, 1.0) * out * (1.0 - clear * 0.8)
	flakes.speed_scale = lerpf(0.75, 1.5, clampf(I, 0.0, 1.0))
	drift.speed_scale = lerpf(0.7, 1.5, clampf(I, 0.0, 1.0))
	flakes.emitting = dens > 0.01
	drift.emitting = out > 0.05

	RenderingServer.global_shader_parameter_set("g_wind", Vector4(WIND_DIR.x, WIND_DIR.z, clampf(base, 0.0, 1.0), 0.0))
	RenderingServer.global_shader_parameter_set("g_gust", gust)
	RenderingServer.global_shader_parameter_set("g_clear", clear)

	# звук: низ постоянно, вой и свист — с порывом
	var q := 1.0 - clear * 0.85
	Snd.loop_vol("wind_low", clampf(0.35 + base * 0.5 + gust * 0.25, 0.0, 1.0) * q, 0.4)
	Snd.loop_vol("wind_howl", clampf(base * 0.45 + gust * 0.75, 0.0, 1.0) * q, 0.4)
	Snd.loop_vol("wind_whistle", clampf((base - 0.3) * 0.4 + gust * 0.6, 0.0, 1.0) * q, 0.4)
	Snd.loop_vol("snow_hiss", clampf(0.2 + I * 0.5, 0.0, 1.0) * out * q, 0.3)
