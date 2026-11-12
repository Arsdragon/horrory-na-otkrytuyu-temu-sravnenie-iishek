shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_always, specular_schlick_ggx;
// Тёмная вода: бассейн, лужи подвала, затопленная лестница. murk — насколько мутная (1 = чёрная).

uniform vec3 deep_color : source_color = vec3(0.01, 0.012, 0.012);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.09, 0.07);
uniform float murk = 0.9;
uniform float alpha_shallow = 0.55;
uniform float wave_scale = 1.0;
uniform float wave_speed = 0.25;
uniform float ripple = 0.0;          // возмущение (кто-то идёт по воде)
uniform vec3 ripple_pos = vec3(0.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 wave_normal(vec2 p, float t) {
	float e = 0.08;
	float h0 = texture(noise_tex, p * 0.21 + vec2(t * 0.11, t * 0.07)).r + texture(noise_tex, p * 0.53 - vec2(t * 0.05, t * 0.13)).r * 0.5;
	float hx = texture(noise_tex, (p + vec2(e, 0.0)) * 0.21 + vec2(t * 0.11, t * 0.07)).r + texture(noise_tex, (p + vec2(e, 0.0)) * 0.53 - vec2(t * 0.05, t * 0.13)).r * 0.5;
	float hz = texture(noise_tex, (p + vec2(0.0, e)) * 0.21 + vec2(t * 0.11, t * 0.07)).r + texture(noise_tex, (p + vec2(0.0, e)) * 0.53 - vec2(t * 0.05, t * 0.13)).r * 0.5;
	return normalize(vec3((h0 - hx) * 2.0, 1.0, (h0 - hz) * 2.0));
}

void fragment() {
	float t = TIME * wave_speed;
	vec3 n = wave_normal(world_pos.xz * wave_scale, t);
	// кольца от шагов
	float d = distance(world_pos.xz, ripple_pos.xz);
	float ring = sin(d * 18.0 - TIME * 9.0) * exp(-d * 1.6) * ripple;
	n = normalize(n + vec3((world_pos.x - ripple_pos.x), 0.0, (world_pos.z - ripple_pos.z)) * ring * 0.6);
	vec3 nv = (VIEW_MATRIX * vec4(n, 0.0)).xyz;
	NORMAL = normalize(mix(NORMAL, nv, 0.6));
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	upos.xyz /= upos.w;
	float thick = clamp((VERTEX.z - upos.z) * 1.2, 0.0, 1.0);
	float m = clamp(mix(thick, 1.0, murk), 0.0, 1.0);
	ALBEDO = mix(shallow_color, deep_color, m);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.65;
	ALPHA = mix(alpha_shallow, 0.97, m);
}
