shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float power = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float t = floor(TIME * 18.0);
	float n = hash(floor(UV * 46.0) + t);
	float rings = 0.5 + 0.5 * sin(r * 34.0 - TIME * 3.0);
	float hole = smoothstep(0.34, 0.1, r);
	float v = n * (0.35 + 0.65 * rings) * smoothstep(1.0, 0.75, r);
	v = mix(v, 0.0, hole * 0.92);
	ALBEDO = vec3(v) * vec3(0.8, 0.9, 1.0) * power;
	ALPHA = smoothstep(1.0, 0.9, r);
}
