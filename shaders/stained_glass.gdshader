shader_type spatial;
render_mode unshaded, cull_disabled;
// Scarlet lancet glass: diamond quarries held in black lead, each pane a
// slightly different red, a few pale. It is the only source of colour in
// Poe's black chamber. Pattern is in object-space metres (mesh XY plane).

#include "res://shaders/common.gdshaderinc"

global uniform float world_time;
uniform vec3 glass_color : source_color = vec3(0.85, 0.04, 0.03);
uniform vec3 pale_color : source_color = vec3(0.9, 0.82, 0.78);
uniform float energy = 3.0;
uniform float quarry_size = 0.17;

varying vec2 v_local;

void vertex() {
	v_local = VERTEX.xy;
}

void fragment() {
	vec2 uv = v_local;
	vec2 r = vec2(uv.x + uv.y, uv.y - uv.x) / quarry_size;
	vec2 cell = floor(r);
	vec2 f = fract(r);
	float lead = 1.0 - smoothstep(0.035, 0.075, min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y)));
	float id = hash12(cell);
	vec3 pane = mix(glass_color * (0.5 + 0.65 * id), pale_color * vec3(1.0, 0.55, 0.5), step(0.975, id));
	float streak = fbm3(uv * vec2(3.0, 0.6) + id) * 0.35 + 0.75;
	float flicker = 0.92 + 0.08 * sin(world_time * 1.3 + id * 6.0);
	ALBEDO = pane * streak * flicker * energy * (1.0 - lead);
}
