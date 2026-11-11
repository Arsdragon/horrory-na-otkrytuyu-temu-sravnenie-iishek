shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Блеск глаз: загорается, только когда на них смотрит луч фонаря. Видно дальше, чем само существо.

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float power = 1.0;
uniform float always = 0.0;        // музей и катсцены: светить без фонаря
instance uniform float eye_side = 1.0;   // −1 левый, +1 правый: издалека глаза чуть разъезжаются, чтобы читались как пара
global uniform vec3 g_lamp_pos;
global uniform vec3 g_lamp_dir;
global uniform float g_lamp_on;
global uniform float g_gust;
global uniform float g_clear;
varying float k;

void vertex() {
	vec3 wp = MODEL_MATRIX[3].xyz;
	vec3 to = wp - g_lamp_pos;
	float d = length(to);
	vec3 n = to / max(d, 0.001);
	float cone = smoothstep(0.78, 0.96, dot(n, normalize(g_lamp_dir)));
	float range = mix(mix(36.0, 13.0, g_gust), 120.0, g_clear);
	float fall = clamp(1.0 - d / range, 0.0, 1.0);
	vec3 fwd = -normalize(MODEL_MATRIX[2].xyz);
	float facing = smoothstep(0.1, 0.6, dot(fwd, -n));
	k = max(g_lamp_on * cone * fall * facing, always * facing);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// дальше трёх метров блик растёт вместе с расстоянием: на экране он остаётся заметной точкой
	VERTEX *= 1.0 + max(d - 3.0, 0.0) * 0.8;
	VERTEX.x += eye_side * max(d - 6.0, 0.0) * 0.014;
}

void fragment() {
	ALBEDO = vec3(0.72, 1.0, 0.86) * power;
	ALPHA = texture(tex, UV).r * k;
}
