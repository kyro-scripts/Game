shader_type spatial;
// Black-and-white marble checkerboard in world XZ: veined stone, thin grout,
// polished (reflective) with scuffs and dull, dirty patches.

#include "res://shaders/common.gdshaderinc"

uniform float tile_size = 1.25;
uniform float grout_width = 0.006;
uniform vec3 white_marble : source_color = vec3(0.84, 0.83, 0.80);
uniform vec3 black_marble : source_color = vec3(0.03, 0.03, 0.034);
uniform vec3 grout_color : source_color = vec3(0.08, 0.08, 0.08);
uniform float vein_strength = 0.7;
uniform float roughness_polished = 0.14;
uniform float roughness_worn = 0.55;

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	vec3 t;
	vec3 bt;
	int axis;
	vec2 uv = dominant_plane(v_wpos, n, t, bt, axis);
	vec2 p = uv / tile_size;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float white = mod(cell.x + cell.y, 2.0);
	float id = hash12(cell + 7.0);

	// Veins: domain-warped bands folded into thin, branching lines.
	vec2 q = uv * 1.3 + id * 17.0;
	vec2 warp = vec2(fbm5(q), fbm5(q + vec2(5.2, 1.3)));
	float band = abs(sin((q.x * 0.8 + q.y * 0.5 + warp.x * 3.5 + warp.y * 1.5) * 2.4));
	float vein = pow(1.0 - band, 14.0) + pow(1.0 - abs(sin((q.y + warp.x * 5.0) * 3.1)), 30.0) * 0.6;
	float cloud = fbm5(q * 0.6 + warp * 1.8);

	vec3 base = mix(black_marble, white_marble, white);
	base *= 0.92 + 0.16 * cloud;
	vec3 vein_col = mix(vec3(0.13, 0.13, 0.13), vec3(0.42, 0.41, 0.40), white);
	vec3 col = mix(base, vein_col, clamp(vein * mix(0.45, 1.0, white) * vein_strength, 0.0, 1.0));

	vec2 d = min(f, 1.0 - f) * tile_size;
	float edge = min(d.x, d.y);
	float grout = 1.0 - smoothstep(grout_width * 0.5, grout_width * 0.5 + 0.004, edge);
	col = mix(col, grout_color, grout);

	float wear = smoothstep(0.45, 0.85, fbm3(uv * 0.45 + 11.0));
	float scuff = smoothstep(0.62, 0.95, fbm5(uv * 9.0 + id * 3.0)) * 0.6;
	col *= 1.0 - wear * 0.18;

	ALBEDO = col;
	ROUGHNESS = clamp(mix(roughness_polished, roughness_worn, max(wear * 0.8, scuff)) + grout * 0.5, 0.02, 1.0);
	SPECULAR = 0.6;
	// Slight dip at the grout lines.
	float e = 0.003;
	vec2 fx = fract((uv + vec2(e, 0.0)) / tile_size);
	vec2 fy = fract((uv + vec2(0.0, e)) / tile_size);
	float gx = 1.0 - smoothstep(grout_width * 0.5, grout_width * 0.5 + 0.004, min(min(fx.x, 1.0 - fx.x), min(fx.y, 1.0 - fx.y)) * tile_size);
	float gy = 1.0 - smoothstep(grout_width * 0.5, grout_width * 0.5 + 0.004, min(min(fy.x, 1.0 - fy.x), min(fy.y, 1.0 - fy.y)) * tile_size);
	vec2 grad = -vec2(gx - grout, gy - grout) / e;
	vec3 pn = normalize(n - 0.002 * (t * grad.x + bt * grad.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
}
