shader_type spatial;
render_mode cull_disabled;
// Heavy velvet for robes and drapes: deep albedo, sheen at grazing angles,
// a slow sway that follows WORLD time (so it hangs still in Borrow Time).

#include "res://shaders/common.gdshaderinc"

global uniform float world_time;
uniform vec3 cloth_color : source_color = vec3(0.05, 0.045, 0.05);
uniform float sheen = 0.55;
uniform float sway_amount = 0.025;
uniform float sway_speed = 0.8;
uniform float anchor_y = 1.6;
uniform float roughness_base = 0.92;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float hang = clamp((anchor_y - VERTEX.y) / max(anchor_y, 0.01), 0.0, 1.0);
	float phase = world_time * sway_speed + wp.x * 0.7 + wp.z * 0.5;
	VERTEX.x += sin(phase) * sway_amount * hang;
	VERTEX.z += cos(phase * 0.83 + 1.3) * sway_amount * hang;
}

void fragment() {
	float nap = fbm3(UV * vec2(40.0, 6.0));
	ALBEDO = cloth_color * (0.85 + 0.3 * nap);
	ROUGHNESS = roughness_base;
	RIM = sheen;
	RIM_TINT = 0.5;
	SPECULAR = 0.2;
}
