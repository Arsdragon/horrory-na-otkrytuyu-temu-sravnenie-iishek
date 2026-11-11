shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
// Флажок на столбе леера: полощется по ветру. Цвет — из экземпляра MultiMesh.

global uniform vec4 g_wind;
global uniform float g_gust;
varying vec3 col;

void vertex() {
	float k = UV.x;
	vec3 wp = MODEL_MATRIX[3].xyz;
	float ph = wp.x * 1.7 + wp.z * 2.3;
	float sp = 9.0 + g_gust * 9.0;
	float amp = (0.025 + 0.05 * g_wind.z + 0.06 * g_gust) * k;
	VERTEX.z += sin(TIME * sp + k * 7.0 + ph) * amp;
	VERTEX.y += sin(TIME * sp * 1.3 + k * 5.0 + ph) * amp * 0.5 - k * k * 0.03;
	col = COLOR.rgb;
}

void fragment() {
	ALBEDO = col * (0.8 + 0.2 * sin(UV.x * 40.0));
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
}
