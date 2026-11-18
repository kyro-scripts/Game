shader_type spatial;
// Ashlar masonry in world space: running-bond blocks with recessed mortar,
// chipped edges, per-block tone, surface pitting, damp grime near the floor
// and vertical water streaks. Horizontal faces switch to large flagstones.

#include "res://shaders/common.gdshaderinc"

uniform vec3 stone_color : source_color = vec3(0.44, 0.42, 0.40);
uniform vec3 mortar_color : source_color = vec3(0.25, 0.24, 0.225);
uniform vec2 block_size = vec2(0.92, 0.42);
uniform vec2 flag_size = vec2(1.2, 0.8);
uniform float mortar_width = 0.011;
uniform float color_variation = 0.12;
uniform float roughness_base = 0.84;
uniform float normal_strength = 1.0;
uniform float floor_y = 0.0;
uniform float grime_height = 1.4;
uniform float grime_strength = 0.5;
uniform float streak_strength = 0.35;

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// x = stone height 0 (mortar) .. 1 (face), y = block id, z = distance to edge (m)
vec3 blocks(vec2 uv, vec2 size) {
	// Each course gets its own block length and joint offset, like real ashlar.
	float row = floor(uv.y / size.y);
	float row_len = mix(0.7, 1.45, hash12(vec2(row, 7.0)));
	vec2 bsize = vec2(size.x * row_len, size.y);
	vec2 s = vec2(uv.x / bsize.x + hash12(vec2(row, 1.0)), uv.y / size.y);
	vec2 cell = floor(s);
	vec2 f = fract(s);
	vec2 d = min(f, 1.0 - f) * bsize;
	float edge = min(d.x, d.y);
	float id = hash12(cell + vec2(17.0, 3.0));
	float chip = fbm3(uv * 11.0 + id * 13.0) * 0.016;
	float h = smoothstep(mortar_width * 0.5, mortar_width * 0.5 + 0.018 + chip, edge);
	return vec3(h, id, edge);
}

float surface(vec2 uv, vec2 size) {
	vec3 b = blocks(uv, size);
	float pit = fbm3(uv * 7.0 + b.y * 31.0);
	// Blocks sit a few millimetres proud of one another.
	return b.x * (0.62 + 0.25 * pit + 0.13 * b.y);
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	vec3 t;
	vec3 bt;
	int axis;
	vec2 uv = dominant_plane(v_wpos, n, t, bt, axis);
	vec2 size = axis == 1 ? flag_size : block_size;
	vec3 b = blocks(uv, size);

	// Normal from the height field (finite differences, 2 cm relief).
	float e = 0.004;
	float h0 = surface(uv, size);
	float hx = surface(uv + vec2(e, 0.0), size);
	float hy = surface(uv + vec2(0.0, e), size);
	vec2 grad = vec2(hx - h0, hy - h0) / e;
	vec3 pn = normalize(n - 0.02 * normal_strength * (t * grad.x + bt * grad.y));

	float tone = 1.0 + (b.y - 0.5) * color_variation * 2.0;
	float detail = fbm5(uv * 2.4 + b.y * 5.0);
	vec3 col = stone_color * tone * (0.84 + 0.3 * detail);
	col = mix(mortar_color, col, smoothstep(0.0, 0.7, b.x));

	float above = v_wpos.y - floor_y;
	float grime = (1.0 - smoothstep(0.0, grime_height, above)) * grime_strength;
	float streak = 0.0;
	if (axis != 1) {
		streak = smoothstep(0.58, 0.9, fbm3(vec2(uv.x * 1.6, v_wpos.y * 0.12) * 1.9)) * streak_strength;
	}
	float blotch = smoothstep(0.55, 0.8, fbm3(uv * 0.35 + 3.0)) * 0.25;
	col *= 1.0 - clamp(grime + streak + blotch, 0.0, 0.85);

	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base + (detail - 0.5) * 0.25 + (1.0 - b.x) * 0.1 - grime * 0.15, 0.05, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
	AO = mix(0.62, 1.0, b.x);
	AO_LIGHT_AFFECT = 0.25;
}
