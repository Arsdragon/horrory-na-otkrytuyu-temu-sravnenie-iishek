shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled, diffuse_lambert_wrap;
// Следы на снегу: вмятина темнее и синее, вал по краю светлее. Цвет экземпляра: r — вид (0 унт, 1 босой), a — свежесть.

uniform sampler2D tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D tex_bare : filter_linear_mipmap, repeat_disable;
varying float fresh;
varying float kind;

void vertex() {
	fresh = COLOR.a;
	kind = COLOR.r;
}

void fragment() {
	vec4 t = mix(texture(tex, UV), texture(tex_bare, UV), step(0.5, kind));
	float depth = t.a;
	float rim = t.r;
	ALBEDO = mix(vec3(0.36, 0.42, 0.53), vec3(0.95), rim * (1.0 - depth));
	ALPHA = clamp(depth * 0.8 + rim * 0.45, 0.0, 1.0) * fresh;
	ROUGHNESS = 0.92;
	SPECULAR = 0.1;
}
