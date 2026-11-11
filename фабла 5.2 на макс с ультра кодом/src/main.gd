extends Node
## Корень: 3D-мир рисуется в SubViewport (540 строк), затем «плёнка» растягивает его на экран.
## Сверху — чёткий интерфейс: HUD, меню, записки, титры.

const POST := preload("res://src/shaders/post.gdshader")

var vp: SubViewport
var screen: TextureRect
var post: ShaderMaterial
var hud_layer: CanvasLayer
var ui_layer: CanvasLayer
var top_layer: CanvasLayer
var fade: ColorRect
var scene: Node = null

# параметры кадра — их задают игра и события; сглаживаются здесь
var cold := 0.0
var fear := 0.0
var interference := 0.0
var flash := 0.0
var dark := 0.0
var blur := 0.0
var red := 0.0
var _fear_s := 0.0
var _int_s := 0.0
var _burst := 0.0
var _beat := 0.0
var _frames := 0
var _fps_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bl := CanvasLayer.new()
	bl.layer = -10
	add_child(bl)
	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.add_child(back)

	vp = SubViewport.new()
	vp.name = "World"
	vp.audio_listener_enable_3d = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = 2048
	vp.handle_input_locally = false
	add_child(vp)

	var sl := CanvasLayer.new()
	sl.layer = 0
	add_child(sl)
	screen = TextureRect.new()
	screen.texture = vp.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.stretch_mode = TextureRect.STRETCH_SCALE
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post = ShaderMaterial.new()
	post.shader = POST
	if ResourceLoader.exists("res://tex/frost.png"):
		post.set_shader_parameter("frost_tex", load("res://tex/frost.png"))
	screen.material = post
	sl.add_child(screen)

	hud_layer = CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	top_layer = CanvasLayer.new()
	top_layer.layer = 20
	add_child(top_layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_layer.add_child(fade)

	Cfg.changed.connect(_apply_cfg)
	get_viewport().size_changed.connect(_apply_cfg)
	_apply_cfg()
	G.main = self
	G.boot.call_deferred()
	if Cfg.has_arg("shot"):
		_auto_shot.call_deferred()


func _auto_shot() -> void:
	var w := Cfg.argf("wait", 3.0)
	await get_tree().create_timer(w).timeout
	var paths := Cfg.arg("shot").split(";")
	for i in paths.size():
		if i > 0:
			await get_tree().create_timer(Cfg.argf("every", 1.0)).timeout
		await RenderingServer.frame_post_draw
		screenshot(paths[i])
		print("SHOT ", paths[i], " fps=", Engine.get_frames_per_second())
	get_tree().quit()


func _apply_cfg() -> void:
	var win := Vector2(get_viewport().get_visible_rect().size)
	vp.size = Cfg.frame_size(win)
	post.set_shader_parameter("src_size", Vector2(vp.size))


func set_scene(n: Node) -> void:
	if scene != null and is_instance_valid(scene):
		vp.remove_child(scene)
		scene.queue_free()
	scene = n
	if n != null:
		vp.add_child(n)


func burst(amount := 1.0) -> void:
	_burst = maxf(_burst, amount)


func fade_to(c: Color, time: float) -> Tween:
	var tw := create_tween()
	tw.tween_property(fade, "color", c, time)
	return tw


func set_fade(c: Color) -> void:
	fade.color = c


func reset_fx() -> void:
	cold = 0.0
	fear = 0.0
	interference = 0.0
	flash = 0.0
	dark = 0.0
	blur = 0.0
	red = 0.0
	_burst = 0.0


func _process(dt: float) -> void:
	_burst = move_toward(_burst, 0.0, dt * 1.6)
	_fear_s = move_toward(_fear_s, fear, dt * 0.8)
	_int_s = move_toward(_int_s, maxf(interference, _burst), dt * 3.0)
	flash = move_toward(flash, 0.0, dt * 1.8)
	# удар сердца: частота растёт со страхом
	_beat = fmod(_beat + dt * (1.1 + _fear_s * 1.3), 1.0)
	var pulse := exp(-_beat * 9.0) + 0.6 * exp(-absf(_beat - 0.28) * 14.0)
	post.set_shader_parameter("grain", Cfg.grain)
	post.set_shader_parameter("cold", cold)
	post.set_shader_parameter("fear", _fear_s)
	post.set_shader_parameter("interference", _int_s)
	post.set_shader_parameter("flash", flash)
	post.set_shader_parameter("dark", dark)
	post.set_shader_parameter("blur", blur)
	post.set_shader_parameter("pulse", pulse)
	post.set_shader_parameter("red", red)
	if Cfg.has_arg("fps"):
		_frames += 1
		_fps_t += dt
		if _fps_t >= 2.0:
			var rid := vp.get_viewport_rid()
			var prims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			var draws := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME)
			var sprims := RenderingServer.viewport_get_render_info(rid, RenderingServer.VIEWPORT_RENDER_INFO_TYPE_SHADOW, RenderingServer.VIEWPORT_RENDER_INFO_PRIMITIVES_IN_FRAME)
			print("LOG fps=", snappedf(_frames / _fps_t, 0.1), " tris=", prims, " draws=", draws, " shadow_tris=", sprims)
			_frames = 0
			_fps_t = 0.0


func screenshot(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)


## 3D-мир живёт в SubViewport без контейнера — сам он ввод не получает, передаём вручную.
func _unhandled_input(e: InputEvent) -> void:
	if vp != null:
		vp.push_input(e)
