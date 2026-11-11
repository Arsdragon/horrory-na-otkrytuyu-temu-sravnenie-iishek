shader_type canvas_item;
// «Плёнка»: зерно, виньетка, изморозь от холода, помехи рядом с существом, страх.

uniform vec2 src_size = vec2(960.0, 540.0);
uniform float grain = 1.0;          // сила зерна
uniform float cold = 0.0;           // 0..1 изморозь от краёв
uniform float fear = 0.0;           // 0..1 сужение поля зрения, обесцвечивание
uniform float interference = 0.0;   // 0..1 помехи (существо рядом)
uniform float flash = 0.0;          // белая вспышка
uniform float dark = 0.0;           // затемнение (моргание, обморок)
uniform float blur = 0.0;           // 0..1 расфокус (замерзание)
uniform float pulse = 0.0;          // удар сердца 0..1
uniform float red = 0.0;            // красный оттенок (фальшфейер в руке не нужен — это смерть)
uniform sampler2D frost_tex : repeat_disable, filter_linear;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float tb = floor(t * 24.0);
	// помехи: строки рвутся в стороны
	if (interference > 0.001) {
		float line = floor(uv.y * src_size.y * 0.5);
		float n = hash(vec2(line, tb + 0.5));
		float band = step(1.0 - interference * 0.35, hash(vec2(floor(uv.y * 14.0), floor(t * 9.0))));
		uv.x += (n - 0.5) * interference * 0.012 + band * (n - 0.5) * interference * 0.06;
	}
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.0, 0.82));
	// изморозь растёт от краёв: в текстуре записано, когда иней дойдёт до каждой точки
	vec4 fr = texture(frost_tex, UV);
	float frost = smoothstep(fr.r - 0.05, fr.r + 0.12, cold * 1.08) * step(0.002, cold);
	uv += (fr.g - fr.b) * 0.012 * frost;
	// хроматическая аберрация
	float ca = 0.0012 + fear * 0.0025 + interference * 0.004 + blur * 0.002;
	vec2 dir = c * ca * 2.0;
	vec3 col;
	col.r = texture(TEXTURE, uv + dir).r;
	col.g = texture(TEXTURE, uv).g;
	col.b = texture(TEXTURE, uv - dir).b;
	if (blur > 0.001) {
		vec2 px = blur * 3.0 / src_size;
		vec3 b = texture(TEXTURE, uv + vec2(px.x, px.y)).rgb + texture(TEXTURE, uv + vec2(-px.x, px.y)).rgb
			+ texture(TEXTURE, uv + vec2(px.x, -px.y)).rgb + texture(TEXTURE, uv + vec2(-px.x, -px.y)).rgb;
		col = mix(col, b * 0.25, clamp(blur * 1.2, 0.0, 1.0));
	}
	// холодные тени, чуть обесцветить
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l), 0.12 + fear * 0.35);
	col += vec3(-0.004, 0.0, 0.008) * (1.0 - l);
	// изморозь
	vec3 ice = mix(vec3(0.50, 0.62, 0.78), vec3(0.92, 0.96, 1.0), fr.g);
	col = mix(col, ice * (0.10 + l * 0.75 + fr.g * 0.22), frost * (0.5 + 0.45 * fr.g));
	// виньетка и пульс страха
	float vg = smoothstep(1.12 - fear * 0.32 - pulse * fear * 0.08, 0.46 - fear * 0.2, r);
	col *= mix(1.0, vg, 0.7);
	col = mix(col, col * vec3(1.25, 0.25, 0.2) + vec3(0.12, 0.0, 0.0), red);
	// зерно: сильнее в тенях
	float g = hash(floor(uv * src_size) + vec2(tb * 17.0, tb * 31.0)) - 0.5;
	col += g * (0.035 + 0.06 * (1.0 - l)) * grain;
	if (interference > 0.001) {
		float sn = hash(floor(uv * src_size * 0.5) + tb * 3.0);
		col = mix(col, vec3(sn), interference * 0.18);
	}
	col = mix(col, vec3(1.0), flash);
	col *= 1.0 - dark;
	COLOR = vec4(col, 1.0);
}
