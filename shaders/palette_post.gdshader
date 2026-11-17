shader_type canvas_item;
// Full-screen grade that enforces the black / white / red palette.
// Everything that is not strongly red collapses to monochrome; red survives.
// Extra layers: Borrow Time (tight vignette, zoom smear, hotter reds),
// Time Debt / damage / low time (red edge pressure), film grain.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float red_keep : hint_range(0.0, 1.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.12;
uniform float vignette : hint_range(0.0, 1.0) = 0.5;
uniform float grain : hint_range(0.0, 0.2) = 0.035;
uniform float borrow : hint_range(0.0, 1.0) = 0.0;
uniform float debt : hint_range(0.0, 1.0) = 0.0;
uniform float damage : hint_range(0.0, 1.0) = 0.0;
uniform float low_time : hint_range(0.0, 1.0) = 0.0;
uniform float time_seed = 0.0;

float hash12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec3 grade(vec3 col) {
	float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
	float redness = clamp((col.r - max(col.g, col.b)) * 2.5, 0.0, 1.0) * red_keep;
	vec3 mono = vec3(luma);
	vec3 red = vec3(max(col.r, luma), luma * 0.12, luma * 0.1);
	return mix(mono, red, redness);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float r = length(c);

	vec3 col = textureLod(screen_texture, uv, 0.0).rgb;
	// Borrow Time: radial smear toward the centre, as if the frame is held.
	if (borrow > 0.001) {
		vec3 acc = col;
		for (int i = 1; i <= 4; i++) {
			float k = float(i) * 0.006 * borrow * r;
			acc += textureLod(screen_texture, uv - c * k * 4.0, 0.0).rgb;
		}
		col = acc / 5.0;
	}

	vec3 g = grade(col);
	float con = contrast + borrow * 0.25;
	g = (g - vec3(0.5)) * con + vec3(0.5);

	float vig_strength = vignette + borrow * 0.45;
	float v = smoothstep(0.95, 0.15, r * (1.0 + vig_strength));
	g *= mix(1.0, v, clamp(vig_strength, 0.0, 1.0));

	float edge = smoothstep(0.28, 0.78, r);
	float red_edge = clamp(debt * 0.45 + damage * 0.9 + low_time * 0.35, 0.0, 1.0);
	g = mix(g, vec3(0.5, 0.015, 0.015), edge * red_edge);

	float n = hash12(floor(uv * vec2(1600.0, 900.0)) + vec2(time_seed, time_seed * 1.7)) - 0.5;
	g += vec3(n * grain);

	COLOR = vec4(clamp(g, vec3(0.0), vec3(1.0)), 1.0);
}
