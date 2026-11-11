shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;
// Снежинка пурги: светится только в настоящем свете (фонарь, лампы), без учёта нормали.

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform float bright = 1.0;
varying float fade;

void vertex() {
	vec3 vp = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	fade = smoothstep(0.2, 1.1, -vp.z) * COLOR.a;
}

void fragment() {
	ALBEDO = vec3(0.92, 0.95, 1.0) * bright;
	ALPHA = texture(tex, UV).a * fade;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * 0.3;
}
