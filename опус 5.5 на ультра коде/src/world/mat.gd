class_name Mat
## Материалы: текстуры из tex/<имя>/ (albedo, normal, rough) с мировой трипланарной проекцией.

static var _cache := {}
static var _tex := {}

## метров на один повтор текстуры
const SIZE := {
	"tile_wall": 1.3, "tile_broken": 1.3, "tile_pool": 1.0, "tile_dark": 1.6, "tile_green": 1.0,
	"tile_floor": 1.4, "tile_floor2": 1.8, "terracotta": 2.4, "linoleum": 2.2, "paint_green": 2.5,
	"paint_blue": 2.5, "plaster": 3.0, "plaster_dmg": 2.6, "peeling": 2.5, "wallpaper": 2.0, "facade": 3.0,
	"concrete": 3.0, "concrete_dirty": 3.0, "brick_dark": 0.9, "brick_red": 1.2, "planks": 1.8,
	"planks_dark": 1.8, "planks_weather": 2.0, "logs": 1.6, "rust": 2.0, "metal_green": 1.6, "grate": 1.2,
	"rust_paint": 2.0, "snow": 3.0, "terry": 0.6, "coal": 1.2, "cloth": 1.0,
}


## приглушить слишком яркие краски
const TINTS := {
	"paint_blue": Color(0.42, 0.5, 0.58), "paint_green": Color(0.55, 0.62, 0.55), "tile_green": Color(0.6, 0.7, 0.62),
	"facade": Color(0.8, 0.72, 0.6), "terracotta": Color(0.75, 0.68, 0.62), "linoleum": Color(0.75, 0.7, 0.6),
}


static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]


## Основной материал. opts: tint (Color), wet (0..1), scale (метров на повтор), rough (множитель),
## emission (Color), emission_energy, uv (true = обычные UV вместо трипланара), cull_off, metal
static func m(name: String, opts := {}) -> StandardMaterial3D:
	var key := name + str(opts)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	var base := "res://tex/%s/" % name
	var alb := tex(base + "albedo.jpg")
	if alb:
		mat.albedo_texture = alb
	var nrm := tex(base + "normal.jpg")
	if nrm:
		mat.normal_enabled = true
		mat.normal_texture = nrm
		mat.normal_scale = float(opts.get("normal", 1.0))
	var rgh := tex(base + "rough.jpg")
	if rgh:
		mat.roughness_texture = rgh
	var wet := float(opts.get("wet", 0.0))
	mat.roughness = lerpf(1.0, 0.28, wet) * float(opts.get("rough", 1.0))
	var tint: Color = opts.get("tint", Color(1, 1, 1))
	if not opts.has("tint") and TINTS.has(name):
		tint = TINTS[name]
	mat.albedo_color = tint.darkened(wet * 0.25)
	if opts.has("metal"):
		mat.metallic = float(opts["metal"])
		mat.metallic_specular = 0.6
	if not bool(opts.get("uv", false)):
		var s := float(opts.get("scale", SIZE.get(name, 2.0)))
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 8.0
		mat.uv1_scale = Vector3.ONE / s
	if opts.has("emission"):
		mat.emission_enabled = true
		mat.emission = opts["emission"]
		mat.emission_energy_multiplier = float(opts.get("emission_energy", 1.0))
	if bool(opts.get("cull_off", false)):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


## Однотонный материал без текстуры.
static func flat(col: Color, rough := 0.8, metal := 0.0, opts := {}) -> StandardMaterial3D:
	var key := "flat" + str(col) + str(rough) + str(metal) + str(opts)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	mat.metallic = metal
	if opts.has("emission"):
		mat.emission_enabled = true
		mat.emission = opts["emission"]
		mat.emission_energy_multiplier = float(opts.get("emission_energy", 1.0))
	if col.a < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if bool(opts.get("unshaded", false)):
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if bool(opts.get("cull_off", false)):
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = mat
	return mat


## Материал с картинкой (табличка, записка, плакат) на обычных UV.
static func picture(path: String, opts := {}) -> StandardMaterial3D:
	var key := "pic" + path + str(opts)
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex(path)
	mat.roughness = float(opts.get("rough", 0.85))
	mat.albedo_color = opts.get("tint", Color(1, 1, 1))
	if bool(opts.get("alpha", false)):
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.4
	if opts.has("emission_energy"):
		mat.emission_enabled = true
		mat.emission_texture = mat.albedo_texture
		mat.emission_energy_multiplier = float(opts["emission_energy"])
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = mat
	return mat


static func clear() -> void:
	_cache.clear()
