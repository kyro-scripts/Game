shader_type spatial;
render_mode cull_disabled;
// Heavy cloth for robes and drapes: deep albedo with rough painted streaks,
// a faint pale fresnel edge so dark figures stay readable against black, and
// a slow sway that follows WORLD time (it hangs still in Borrow Time).

#include "res://shaders/common.gdshaderinc"

global uniform float world_time;
uniform vec3 cloth_color : source_color = vec3(0.05, 0.045, 0.05);
uniform float sheen = 0.55;
uniform float sway_amount = 0.025;
uniform float sway_speed = 0.8;
uniform float anchor_y = 1.6;
uniform float roughness_base = 0.92;
uniform float paint_streaks = 0.0;
uniform vec3 rim_color : source_color = vec3(0.85, 0.84, 0.82);
uniform float rim_light = 0.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float hang = clamp((anchor_y - VERTEX.y) / max(anchor_y, 0.01), 0.0, 1.0);
	float phase = world_time * sway_speed + wp.x * 0.7 + wp.z * 0.5;
	VERTEX.x += sin(phase) * sway_amount * hang;
	VERTEX.z += cos(phase * 0.83 + 1.3) * sway_amount * hang;
}

void fragment() {
	float nap = fbm3(UV * vec2(40.0, 6.0));
	// Rough painted streaks running down the cloth (the reference's brushwork).
	float streak = fbm3(vec2(atan(v_local.z, v_local.x) * 6.0, v_local.y * 1.3));
	vec3 col = cloth_color * (0.85 + 0.3 * nap);
	col *= mix(1.0, 0.55 + 0.9 * streak, paint_streaks);
	ALBEDO = col;
	ROUGHNESS = roughness_base;
	RIM = sheen;
	RIM_TINT = 0.5;
	SPECULAR = 0.2;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * fres * rim_light;
}
