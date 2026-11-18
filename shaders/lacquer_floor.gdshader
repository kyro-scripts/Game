shader_type spatial;
// Black lacquered floor: almost a mirror, so isolated lights double in it.
// Long brush marks, scuffed worn paths and dull patches. Optional warped
// checkerboard whose tiles are not quite the same size (an inconsistency).

#include "res://shaders/common.gdshaderinc"

uniform vec3 base_color : source_color = vec3(0.07, 0.068, 0.072);
uniform vec3 tile_color : source_color = vec3(0.55, 0.54, 0.52);
uniform float roughness_min = 0.1;
uniform float roughness_max = 0.42;
uniform bool checker = false;
uniform float tile_size = 1.7;
uniform float tile_warp = 0.0;

varying vec3 v_wpos;

void vertex() {
	v_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = v_wpos.xz;
	float marks = fbm3(vec2(uv.x * 0.6, uv.y * 7.0));
	float scuff = smoothstep(0.5, 0.9, fbm5(uv * 1.3 + 2.0));
	float dull = smoothstep(0.45, 0.75, fbm3(uv * 0.12 + 5.0));
	vec3 col = base_color * (0.8 + 0.4 * marks);
	if (checker) {
		// Warp grows with distance from the origin: tiles slowly swell and drift.
		vec2 w = uv + vec2(fbm3(uv * 0.05), fbm3(uv * 0.05 + 3.0)) * tile_warp * length(uv) * 0.02;
		vec2 c = floor(w / tile_size);
		float white = mod(c.x + c.y, 2.0);
		col = mix(col, tile_color * (0.85 + 0.15 * marks), white);
	}
	ALBEDO = col;
	ROUGHNESS = clamp(mix(roughness_min, roughness_max, max(scuff * 0.7, dull * 0.6)) + marks * 0.05, 0.02, 1.0);
	SPECULAR = 0.6;
}
