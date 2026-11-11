shader_type spatial;
render_mode cull_back, diffuse_lambert_wrap;
// Снежная земля: мировые UV (земля бесконечная и едет за игроком), позёмка вдоль ветра, искры наста.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float tile = 2.6;
uniform vec3 tint : source_color = vec3(0.9, 0.93, 1.0);
global uniform vec4 g_wind;
global uniform float g_gust;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / tile;
	vec2 uv2 = uv * 0.37 + vec2(0.31, 0.17);
	float macro = texture(noise_tex, wpos.xz * 0.011).r;
	vec3 alb = mix(texture(albedo_tex, uv).rgb, texture(albedo_tex, uv2).rgb, 0.45);
	alb = mix(vec3(0.80, 0.83, 0.88), alb, 0.42);
	alb *= mix(0.84, 1.04, macro);
	vec2 wd = normalize(g_wind.xy + vec2(0.0001));
	vec2 q = vec2(dot(wpos.xz, wd), dot(wpos.xz, vec2(-wd.y, wd.x)));
	float t = TIME * (4.5 + g_gust * 7.0);
	float s1 = texture(noise_tex, vec2((q.x - t) * 0.035, q.y * 0.31)).g;
	float s2 = texture(noise_tex, vec2((q.x - t * 1.7) * 0.052, q.y * 0.55 + 0.4)).g;
	float drift = smoothstep(0.50, 0.78, s1 * 0.6 + s2 * 0.5) * (0.25 + g_wind.z * 0.5 + g_gust * 0.5);
	ALBEDO = alb * tint * 0.9 + vec3(drift * 0.22);
	vec3 n = mix(texture(normal_tex, uv).rgb, texture(normal_tex, uv2).rgb, 0.45);
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 1.3 * (1.0 - drift * 0.7);
	float sp = texture(noise_tex, wpos.xz * 2.3).b * texture(noise_tex, wpos.zx * 3.1 + 0.37).b;
	float glint = smoothstep(0.62, 0.8, sp);
	ROUGHNESS = mix(0.9, 0.22, glint);
	SPECULAR = mix(0.2, 0.9, glint);
}
