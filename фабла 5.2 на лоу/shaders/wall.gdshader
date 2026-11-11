shader_type spatial;
uniform sampler2D plaster : source_color, repeat_enable;
uniform sampler2D planks : source_color, repeat_enable;
uniform vec3 paint : source_color = vec3(0.16, 0.27, 0.2);
varying vec3 wp;
varying vec3 wn;

vec3 tri(sampler2D t, float s) {
	vec3 b = abs(wn);
	b /= (b.x + b.y + b.z);
	return texture(t, wp.zy * s).rgb * b.x + texture(t, wp.xz * s).rgb * b.y + texture(t, wp.xy * s).rgb * b.z;
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	bool outside = abs(wp.x) > 8.02 || abs(wp.z) > 5.02 || wp.y > 2.83;
	if (outside) {
		ALBEDO = tri(planks, 0.45) * vec3(0.33, 0.3, 0.27);
		ROUGHNESS = 0.95;
	} else {
		vec3 p = tri(plaster, 0.4);
		float l = dot(p, vec3(0.33));
		vec3 white = vec3(0.62, 0.6, 0.52) * (0.55 + 0.6 * l);
		vec3 green = paint * (0.5 + 1.1 * l);
		float k = smoothstep(1.44, 1.46, wp.y);
		vec3 c = mix(green, white, k);
		c *= 1.0 - 0.6 * smoothstep(0.012, 0.0, abs(wp.y - 1.47) - 0.012);
		c *= 0.55 + 0.45 * smoothstep(0.0, 0.5, wp.y);
		c *= 1.0 - 0.35 * smoothstep(2.3, 2.8, wp.y) * step(wp.y, 2.79);
		ALBEDO = c;
		ROUGHNESS = mix(0.45, 0.95, k);
	}
}
