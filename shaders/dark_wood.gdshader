shader_type spatial;
// Dark oak planks in world space: plank seams, long grain, growth rings,
// worn, slightly oily sheen. Planks run along `grain_axis`.

#include "res://shaders/common.gdshaderinc"

uniform vec3 wood_light : source_color = vec3(0.24, 0.15, 0.09);
uniform vec3 wood_dark : source_color = vec3(0.07, 0.045, 0.03);
uniform float plank_width = 0.19;
uniform bool vertical_planks = true;
uniform float roughness_base = 0.62;
// Object space for held / moving props (world space would make grain swim).
uniform bool object_space = false;
uniform float object_scale = 1.0;

varying vec3 v_wpos;
varying vec3 v_wnrm;

void vertex() {
	if (object_space) {
		v_wpos = VERTEX * object_scale;
		v_wnrm = NORMAL;
	} else {
		v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		v_wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	}
}

void fragment() {
	vec3 n = normalize(v_wnrm);
	vec3 t;
	vec3 bt;
	int axis;
	vec2 uv = dominant_plane(v_wpos, n, t, bt, axis);
	// along = grain direction, across = plank index direction
	vec2 g = vertical_planks ? vec2(uv.x, uv.y) : vec2(uv.y, uv.x);
	float plank = floor(g.x / plank_width);
	float id = hash12(vec2(plank, 3.0));
	float across = fract(g.x / plank_width);
	float seam = 1.0 - smoothstep(0.0, 0.035, min(across, 1.0 - across));
	vec2 gp = vec2(g.x * 38.0, g.y * 1.6 + id * 40.0);
	float grain = fbm5(gp);
	float rings = abs(sin((g.x * 60.0 + fbm3(vec2(g.x * 4.0, g.y * 0.9 + id * 9.0)) * 6.0)));
	rings = smoothstep(0.75, 1.0, rings);
	vec3 col = mix(wood_dark, wood_light, clamp(grain * 0.9 + id * 0.25 - rings * 0.25, 0.0, 1.0));
	col *= 1.0 - seam * 0.75;
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base + (grain - 0.5) * 0.3 + seam * 0.3, 0.1, 1.0);
	float e = 0.002;
	float h0 = grain - seam;
	float hx = fbm5(gp + vec2(e * 38.0, 0.0)) - seam;
	vec3 pn = normalize(n - 0.6 * (vertical_planks ? t : bt) * (hx - h0));
	if (object_space) {
		pn = (MODEL_MATRIX * vec4(pn, 0.0)).xyz;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(pn, 0.0)).xyz);
}
