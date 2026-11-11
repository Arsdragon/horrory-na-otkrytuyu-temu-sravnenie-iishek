shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float fear = 0.0;
uniform float glitch = 0.0;
uniform float cold = 0.0;
uniform float dark = 0.0;
uniform float slits = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = floor(TIME * 24.0);
	if (glitch > 0.01) {
		float row = floor(uv.y * 90.0);
		float j = step(1.0 - glitch * 0.35, hash(vec2(row, t)));
		uv.x += j * (hash(vec2(row, t + 3.0)) - 0.5) * 0.12 * glitch;
	}
	vec2 c = uv - 0.5;
	float ab = (0.0015 + 0.006 * fear + 0.02 * glitch) * dot(c, c) * 4.0;
	vec3 col;
	col.r = texture(screen, uv + c * ab).r;
	col.g = texture(screen, uv).g;
	col.b = texture(screen, uv - c * ab).b;
	float g = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(col, vec3(g), 0.25 + 0.3 * fear);
	float n = hash(uv * vec2(1280.0, 720.0) + t) - 0.5;
	col += n * (0.055 + 0.05 * fear + 0.5 * glitch);
	float v = smoothstep(0.25, 0.95, length(c) * (1.15 + 0.45 * fear));
	col *= 1.0 - v * 0.9;
	float fr = smoothstep(0.55 - 0.45 * cold, 0.95, length(c) + 0.1 * hash(floor(uv * 60.0))) * cold;
	col = mix(col, vec3(0.75, 0.85, 0.95), fr * 0.75);
	if (slits > 0.5) {
		float s = step(0.5, fract(uv.y * 9.0)) * step(0.3, uv.y) * step(uv.y, 0.75) * step(0.2, uv.x) * step(uv.x, 0.8);
		col *= mix(0.0, 1.0, s);
	}
	col *= 1.0 - dark;
	COLOR = vec4(col, 1.0);
}
