shader_type spatial;
// Rough, imperfect painted surface in world space: thick brush strokes
// whose direction drifts across the wall, dry-brush highlights, thin spots
// where the darker ground shows through, drips, rare irregular cracks and
// patches of wet sheen. No repeating bricks. Minimal but hand-made.

#include "res://shaders/common.gdshaderinc"

uniform vec3 paint_color : source_color = vec3(0.1, 0.097, 0.1);
uniform vec3 ground_color : source_color = vec3(0.018, 0.018, 0.02);
uniform float stroke_scale = 1.0;
uniform float stroke_contrast = 0.55;
uniform float roughness_base = 0.84;
uniform float gloss_amount = 0.35;
uniform float floor_y = 0.0;
uniform float grime_height = 1.2;
uniform float crack_amount = 0.6;
uniform float drip_amount = 0.5;
uniform float normal_strength = 1.0;

varying vec3 v_wpos;
varying vec3 v_wnrm;

float stroke_layer(vec2 uv, float angle, float seed) {
	vec2 dir = vec2(cos(angle), sin(angle));
	vec2 p = vec2(dot(uv, dir), dot(uv, vec2(-dir.y, dir.x))) / stroke_scale;
	float body = fbm3(vec2(p.x * 0.9, p.y * 9.0) + seed);
	float bristle = vnoise(vec2(p.x * 2.5, p.y * 70.0) + seed * 3.0);
	return body * 0.78 + bristle * 0.22;
}

float strokes(vec2 uv) {
	// Two stroke directions blended by a slow field: no visible patch seams.
	float a = stroke_layer(uv, 0.35, 1.0);
	float b = stroke_layer(uv, -0.9, 7.0);
	float m = smoothstep(0.35, 0.65, fbm3(uv * 0.22 + 4.0));
	return mix(a, b, m);
}

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

	float s = strokes(uv);
	float e = 0.006;
	float sx = strokes(uv + vec2(e, 0.0));
	float sy = strokes(uv + vec2(0.0, e));
	vec2 grad = vec2(sx - s, sy - s) / e;
	vec3 pn = normalize(n - 0.004 * normal_strength * (t * grad.x + bt * grad.y));

	float cover = smoothstep(0.25, 0.75, s);
	vec3 col = mix(ground_color, paint_color, mix(1.0 - stroke_contrast, 1.0, cover));
	col += paint_color * pow(clamp(s, 0.0, 1.0), 6.0) * 0.6;  // dry-brush ridges

	// Drips and damp grime.
	float drip = 0.0;
	if (axis != 1) {
		drip = smoothstep(0.62, 0.92, fbm3(vec2(uv.x * 2.2, v_wpos.y * 0.07))) * drip_amount;
	}
	float above = v_wpos.y - floor_y;
	float grime = (1.0 - smoothstep(0.0, grime_height, above)) * 0.45;
	col *= 1.0 - clamp(drip * 0.6 + grime, 0.0, 0.8);

	// Rare irregular cracks (never a grid).
	float cx = uv.x / 6.5;
	float cell = floor(cx + 0.5);
	float wobble = (fbm3(vec2(cell * 3.1, uv.y * 0.35)) - 0.5) * 1.4;
	float lx = (cx - cell) * 6.5 + wobble;
	float crack = (1.0 - smoothstep(0.003, 0.011, abs(lx))) * step(0.55, hash12(vec2(cell, 2.0)))
			* smoothstep(0.3, 0.6, fbm3(vec2(cell, uv.y * 0.5)));
	col *= 1.0 - crack * crack_amount;

	float wet = smoothstep(0.55, 0.8, fbm3(uv * 0.4 + 9.0)) * gloss_amount;
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base - wet - (s - 0.5) * 0.15 + crack * 0.2, 0.12, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
}
