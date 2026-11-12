shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// Зеркало: отражение из SubViewport, запотевание и надпись пальцем (видна в пару).

uniform sampler2D refl : source_color, filter_linear;
uniform sampler2D writing : hint_default_transparent, filter_linear_mipmap;
uniform bool has_writing = false;
uniform float fog = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 r = texture(refl, uv).rgb;
	// старая амальгама: пятна по краям
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float spots = smoothstep(0.0, 0.12, edge) * (0.85 + 0.15 * hash(floor(UV * 60.0)));
	float w = has_writing ? texture(writing, UV).a : 0.0;
	float f = clamp(fog * (1.0 - w * 0.9), 0.0, 1.0);
	ALBEDO = vec3(0.42, 0.43, 0.42) * f;
	ROUGHNESS = mix(0.08, 0.7, f);
	SPECULAR = 0.5;
	EMISSION = r * spots * (1.0 - f * 0.92) * 0.95;
}
