shader_type canvas_item;
// Пост-обработка: зерно плёнки, виньетка, страх (хроматическая аберрация, дрожь), «за спиной» (сужение и обесцвечивание),
// воспоминание (выбеленная сепия), щели шкафчика.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float fear = 0.0;
uniform float behind = 0.0;
uniform float memory = 0.0;
uniform float grain = 0.06;
uniform float slats = 0.0;
uniform float hurt = 0.0;
uniform float time_s = 0.0;

float rnd(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + time_s * 7.13) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float d = length(c);
	// дрожь от страха
	float wob = fear * fear * 0.003;
	uv += vec2(sin(time_s * 31.0 + uv.y * 40.0), cos(time_s * 27.0 + uv.x * 35.0)) * wob;
	float ab = (0.0015 + fear * 0.007 + behind * 0.006) * d * 2.0;
	vec3 col;
	col.r = texture(screen, uv + c * ab).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - c * ab).b;
	// «за спиной»: обесцвечивание и тьма по краям
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(lum) * vec3(0.9, 0.95, 1.0), behind * 0.75);
	// воспоминание: выбеленная сепия
	col = mix(col, vec3(lum * 1.4 + 0.15) * vec3(1.0, 0.92, 0.78), memory);
	// виньетка
	float vig = smoothstep(0.85 - fear * 0.25 - behind * 0.35, 0.25 - behind * 0.15, d);
	col *= mix(1.0, vig, 0.75);
	// краснота от вреда
	col = mix(col, col * vec3(1.3, 0.4, 0.35), hurt);
	// зерно
	float g = rnd(uv * 1000.0) - 0.5;
	col += g * (grain + fear * 0.08 + memory * 0.15);
	// щели шкафчика
	if (slats > 0.0) {
		float sl = step(0.5, fract(SCREEN_UV.y * 9.0)) * step(0.32, SCREEN_UV.y) * step(SCREEN_UV.y, 0.62);
		float mask = mix(1.0, sl, slats);
		col *= mix(0.05, 1.0, mask);
	}
	COLOR = vec4(col, 1.0);
}
