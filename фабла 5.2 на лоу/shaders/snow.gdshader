shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	if (abs(wpos.x) < 8.2 && abs(wpos.z) < 5.2 && wpos.y < 3.1) {
		VERTEX = vec3(0.0);
	} else {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	}
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = vec3(0.5, 0.55, 0.62) * smoothstep(1.0, 0.2, d) * 0.5;
}
