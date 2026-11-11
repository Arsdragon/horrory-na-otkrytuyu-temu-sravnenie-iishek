shader_type spatial;
render_mode cull_back;
// Трос леера: провисает, качается на ветру; tug — кто-то дёргает за дальний конец.

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tug = 0.0;
global uniform vec4 g_wind;
global uniform float g_gust;

void vertex() {
	float k = COLOR.r;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = wp.x * 0.35 + wp.z * 0.41;
	vec2 wd = normalize(g_wind.xy + vec2(0.0001));
	float sway = sin(TIME * 2.3 + ph) * 0.03 + sin(TIME * 7.1 + ph * 3.0) * 0.012 * (1.0 + g_gust * 2.5);
	float push = 0.06 * g_wind.z + 0.08 * g_gust + sway;
	VERTEX.x += wd.x * push * k;
	VERTEX.z += wd.y * push * k;
	VERTEX.y += sin(TIME * 21.0 + ph * 5.0) * 0.06 * tug * k;
}

void fragment() {
	ALBEDO = texture(tex, UV).rgb * 0.85;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
}
