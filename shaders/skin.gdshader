shader_type spatial;
// Painted, waxy almost-skin. Features are painted here per pixel, in the same
// front coordinates MeshKit.face_mesh sculpts with, so they stay crisp at any
// distance: bruised sockets, thin eyebrows drawn too high, nostrils, a mouth
// line whose corners turn up too sharply, and in it a row of too many small
// teeth. A faint self-light keeps faces the brightest shapes in a dark room.

#include "res://shaders/common.gdshaderinc"

uniform vec3 skin_tint : source_color = vec3(0.86, 0.84, 0.8);
uniform float self_light = 0.16;
uniform float roughness_base = 0.5;
uniform vec3 flash_color : source_color = vec3(1.0, 1.0, 1.0);
uniform float flash = 0.0;
// Expression (set per mood by FaceRig).
uniform float smile = 1.0;
uniform float open = 0.0;
// Proportions (match MeshKit.FACE_* constants).
uniform vec3 face_scale = vec3(0.074, 0.122, 0.096);
uniform float eye_x = 0.44;
uniform float eye_y = -0.08;
uniform float mouth_y = -0.44;
uniform float mouth_w = 0.47;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	float uy = v_local.y / face_scale.y;
	float taper = uy < 0.0 ? (1.0 + uy * 0.34) : 1.0;
	float ux = v_local.x / (face_scale.x * taper);
	float ax = abs(ux);
	float front = smoothstep(0.15, 0.45, v_local.z / face_scale.z);

	float v = 1.0;
	vec3 paint = vec3(0.0);
	float paint_a = 0.0;

	// Eyebrows: thin arcs, far too high.
	float by = uy - (eye_y + 0.36 + 0.06 * (1.0 - (ax - eye_x) * (ax - eye_x) * 8.0));
	float brow = (1.0 - smoothstep(0.009, 0.022, abs(by))) * smoothstep(0.2, 0.26, ax) * (1.0 - smoothstep(0.6, 0.68, ax));
	v -= 0.55 * brow * front;

	// Nostrils.
	float nd = length(vec2((ax - 0.075) * 1.5, uy - (eye_y - 0.27)));
	v -= 0.6 * (1.0 - smoothstep(0.014, 0.03, nd)) * front;

	// Mouth.
	float k = clamp(ax / mouth_w, 0.0, 1.2);
	float line_y = mouth_y + smile * 0.17 * pow(k, 2.6);
	float my = uy - line_y;
	float inside = 1.0 - smoothstep(mouth_w * 0.9, mouth_w * 1.03, ax);
	float slit_h = 0.011 + open * 0.12;
	v -= 0.14 * (1.0 - smoothstep(0.03, 0.075, abs(my))) * inside * front;  // lips
	float slit = (1.0 - smoothstep(slit_h, slit_h + 0.008, abs(my))) * inside * front;
	// Teeth: small, even and too many, filling the whole slit when it smiles;
	// two rows when the jaw drops.
	float tooth_cols = step(0.16, fract(ux * 28.0));
	float teeth_band = open > 0.5
			? (step(slit_h - 0.045, abs(my)) * step(abs(my), slit_h - 0.006))
			: step(abs(my), slit_h * 0.75);
	float teeth = tooth_cols * teeth_band * smoothstep(mouth_w * 0.85, mouth_w * 0.6, ax);
	vec3 mouth_col = mix(vec3(0.04, 0.035, 0.035), vec3(0.8, 0.78, 0.72), teeth);
	paint = mouth_col;
	paint_a = slit;

	float blot = fbm3(v_local.xy * 90.0) * 0.12;
	vec3 base = COLOR.rgb * skin_tint * (0.94 + blot) * clamp(v, 0.05, 1.0);
	base = mix(base, paint, paint_a);
	base = mix(base, flash_color, flash);
	ALBEDO = base;
	EMISSION = base * self_light + flash_color * flash * 0.6;
	ROUGHNESS = mix(roughness_base, 0.25, paint_a * teeth);
	RIM = 0.35;
	RIM_TINT = 0.6;
	SSS_STRENGTH = 0.15;
}
