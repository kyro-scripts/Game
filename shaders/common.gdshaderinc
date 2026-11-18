// Shared noise helpers for the castle's procedural materials.
// Value noise + fbm are cheap and tile-free; all inputs are world-space metres.

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm3(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v / 0.875;
}

float fbm5(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.01 + vec2(5.3, 1.1);
		a *= 0.5;
	}
	return v / 0.96875;
}

// Pick the projection plane from the dominant world normal axis. Castle
// geometry is mostly axis-aligned, so a hard switch beats blending.
vec2 dominant_plane(vec3 p, vec3 n, out vec3 t, out vec3 b, out int axis) {
	vec3 an = abs(n);
	if (an.y >= an.x && an.y >= an.z) {
		t = vec3(1.0, 0.0, 0.0);
		b = vec3(0.0, 0.0, 1.0);
		axis = 1;
		return p.xz;
	} else if (an.x >= an.z) {
		t = vec3(0.0, 0.0, 1.0);
		b = vec3(0.0, 1.0, 0.0);
		axis = 0;
		return vec2(p.z, p.y);
	}
	t = vec3(1.0, 0.0, 0.0);
	b = vec3(0.0, 1.0, 0.0);
	axis = 2;
	return vec2(p.x, p.y);
}
