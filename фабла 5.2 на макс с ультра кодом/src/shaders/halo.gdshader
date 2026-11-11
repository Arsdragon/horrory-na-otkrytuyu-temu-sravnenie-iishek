shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Ореол огня: виден сквозь пургу дальше, чем сама геометрия. Дальность падает в порыв.

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float power = 1.0;
uniform float near_fade = 1.5;
uniform float vis_scale = 1.0;
uniform float breathe = 0.0;        // «дышащий» чужой огонь: 0 — ровный, 1 — пульсирует
uniform vec3 face = vec3(0.0);      // если задано — ореол виден только с этой стороны (окна: снаружи)
global uniform float g_gust;
global uniform float g_clear;
varying float dist;
varying float side;

void vertex() {
	vec3 to_cam = INV_VIEW_MATRIX[3].xyz - MODEL_MATRIX[3].xyz;
	side = (dot(face, face) < 0.0001) ? 1.0 : smoothstep(0.0, 0.35, dot(normalize(to_cam), normalize(face + vec3(0.00001))));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	dist = length((MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz);
	VERTEX *= 1.0 + dist * 0.04;
}

void fragment() {
	float a = texture(tex, UV).r;
	float range = mix(62.0, 20.0, g_gust) * vis_scale;
	range = mix(range, 500.0, g_clear);
	float f = clamp(1.0 - dist / range, 0.0, 1.0);
	f = f * f;
	float nf = clamp(dist / near_fade, 0.0, 1.0);
	float br = 1.0 - breathe * (0.5 + 0.5 * sin(TIME * 1.35)) * 0.75;
	ALBEDO = color.rgb * power * br;
	ALPHA = a * f * nf * side;
}
