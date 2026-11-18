@tool
class_name MeshKit
extends RefCounted
## Procedural mesh builders for the castle's placeholder-free look: lathes
## (columns, candles, watch cases, robes), sweeps (mouldings, ribs, vaults),
## gothic arch outlines and a sculpted porcelain mask.
##
## All builders return an ArrayMesh with normals and UVs, generated once and
## cached by the caller where it matters.


# --- Lathe (surface of revolution) ---------------------------------------------------

## Revolve a profile of (radius, height) points around the Y axis.
## `radial_noise` (optional) receives (angle, height) and returns a radius
## multiplier, used for cloth folds.
static func lathe(profile: PackedVector2Array, segments: int = 24, smooth: bool = true,
		radial_noise: Callable = Callable(), cap_ends: bool = false,
		arc_start: float = 0.0, arc_end: float = TAU) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not smooth:
		st.set_smooth_group(-1)
	var rings := profile.size()
	# Cumulative length along the profile for V coordinates.
	var lengths := PackedFloat32Array([0.0])
	for i in range(1, rings):
		lengths.append(lengths[i - 1] + profile[i].distance_to(profile[i - 1]))
	var total := maxf(lengths[rings - 1], 0.0001)
	var grid: Array[PackedVector3Array] = []
	for i in rings:
		var row := PackedVector3Array()
		for s in segments + 1:
			var a := lerpf(arc_start, arc_end, float(s) / segments)
			var r := profile[i].x
			if radial_noise.is_valid():
				r *= float(radial_noise.call(a, profile[i].y))
			row.append(Vector3(cos(a) * r, profile[i].y, sin(a) * r))
		grid.append(row)
	for i in rings - 1:
		for s in segments:
			var u0 := float(s) / segments
			var u1 := float(s + 1) / segments
			var v0 := lengths[i] / total
			var v1 := lengths[i + 1] / total
			var a := grid[i][s]
			var b := grid[i][s + 1]
			var c := grid[i + 1][s + 1]
			var d := grid[i + 1][s]
			var mid := (a + b + c + d) * 0.25
			var outward := Vector3(mid.x, 0.0, mid.z)
			if outward.length_squared() < 1e-10:
				outward = Vector3.UP if profile[i + 1].y >= profile[i].y else Vector3.DOWN
			_quad(st, a, b, c, d, Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1), outward)
	if cap_ends:
		for end in [0, rings - 1]:
			var y := profile[end].y
			var center := Vector3(0.0, y, 0.0)
			for s in segments:
				var p0 := grid[end][s]
				var p1 := grid[end][s + 1]
				_tri(st, center, p0, p1, Vector3.DOWN if end == 0 else Vector3.UP)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Sweep (extrude a 2D profile along a path) ----------------------------------------

## Sweep a closed 2D profile (x = sideways, y = up) along a 3D polyline.
## Used for mouldings, vault ribs and arch frames.
static func sweep(profile: PackedVector2Array, path: PackedVector3Array, up_hint: Vector3 = Vector3.UP,
		closed_profile: bool = true, smooth: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if not smooth:
		st.set_smooth_group(-1)
	var n := path.size()
	var pc := profile.size()
	var centroid := Vector2.ZERO
	for p in profile:
		centroid += p
	centroid /= pc
	var frames: Array[PackedVector3Array] = []
	var centres := PackedVector3Array()  # profile centroid in 3D, per frame
	var vs := PackedFloat32Array()
	var along := 0.0
	for i in n:
		var t: Vector3
		if i == 0:
			t = path[1] - path[0]
		elif i == n - 1:
			t = path[n - 1] - path[n - 2]
		else:
			t = path[i + 1] - path[i - 1]
		t = t.normalized()
		var up := up_hint
		if absf(t.dot(up)) > 0.98:
			up = Vector3.FORWARD
		var side := t.cross(up).normalized()
		var real_up := side.cross(t).normalized()
		var ring := PackedVector3Array()
		for p in profile:
			ring.append(path[i] + side * p.x + real_up * p.y)
		frames.append(ring)
		centres.append(path[i] + side * centroid.x + real_up * centroid.y)
		if i > 0:
			along += path[i].distance_to(path[i - 1])
		vs.append(along)
	var edges := pc if closed_profile else pc - 1
	for i in n - 1:
		var centre := (centres[i] + centres[i + 1]) * 0.5
		for k in edges:
			var k2 := (k + 1) % pc
			var a := frames[i][k]
			var b := frames[i][k2]
			var c := frames[i + 1][k2]
			var d := frames[i + 1][k]
			var outward := (a + b + c + d) * 0.25 - centre
			var u0 := float(k) / pc
			var u1 := float(k + 1) / pc
			_quad(st, a, b, c, d, Vector2(vs[i], u0), Vector2(vs[i], u1), Vector2(vs[i + 1], u1), Vector2(vs[i + 1], u0), outward)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## A straight sweep along +X of the given length (mouldings along a wall).
static func straight_moulding(profile: PackedVector2Array, length: float) -> ArrayMesh:
	return sweep(profile, PackedVector3Array([Vector3(-length * 0.5, 0, 0), Vector3(length * 0.5, 0, 0)]), Vector3.UP)


# --- Gothic arches ----------------------------------------------------------------------

## Pointed (two-centred) arch curve from the left springing point to the right,
## in the XY plane. `width` = span, `rise` = apex height above the springing.
static func pointed_arch_curve(width: float, rise: float, segments: int = 12) -> PackedVector2Array:
	# Each side is an arc centred on the opposite side of the span such that
	# it passes through the springing point and the apex.
	var half := width * 0.5
	# Centre offset c (from the middle, on the opposite side) satisfies:
	# radius = half + c, and (c)^2 + rise^2 = radius^2.
	var c := (rise * rise - half * half) / (2.0 * half)
	var radius := half + c
	var pts := PackedVector2Array()
	# Left arc: centre at (+c, 0), from angle PI to the apex angle.
	var apex_angle := atan2(rise, -c)
	for i in segments + 1:
		var a := lerpf(PI, apex_angle, float(i) / segments)
		pts.append(Vector2(c + cos(a) * radius, sin(a) * radius))
	# Right arc mirrors the left (skip the duplicated apex).
	for i in range(segments - 1, -1, -1):
		var p := pts[i]
		pts.append(Vector2(-p.x, p.y))
	return pts


## Outline polygon of a pointed-arch opening (flat bottom), for CSGPolygon3D.
static func pointed_arch_opening(width: float, spring_height: float, rise: float, segments: int = 12) -> PackedVector2Array:
	# Bottom-right corner, then the arch from its right springing point over
	# the apex to the left springing point, then bottom-left. No duplicates.
	var pts := PackedVector2Array()
	pts.append(Vector2(width * 0.5, 0.0))
	var curve := pointed_arch_curve(width, rise, segments)
	for i in range(curve.size() - 1, -1, -1):
		var p := curve[i]
		pts.append(Vector2(p.x, p.y + spring_height))
	pts.append(Vector2(-width * 0.5, 0.0))
	return pts


## 3D path for an arch (or a vault rib) across the X axis at depth z.
static func arch_path(width: float, spring_height: float, rise: float, z: float, segments: int = 12) -> PackedVector3Array:
	var out := PackedVector3Array()
	var curve := pointed_arch_curve(width, rise, segments)
	for p in curve:
		out.append(Vector3(p.x, p.y + spring_height, z))
	return out


## The inner surface of a pointed barrel vault running along -Z.
static func pointed_vault(width: float, spring_height: float, rise: float, length: float, segments: int = 14) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curve := pointed_arch_curve(width, rise, segments)
	var steps := maxi(int(length / 2.0), 1)
	for j in steps:
		var z0 := -length * float(j) / steps
		var z1 := -length * float(j + 1) / steps
		for i in curve.size() - 1:
			var p0 := curve[i]
			var p1 := curve[i + 1]
			var a := Vector3(p0.x, p0.y + spring_height, z0)
			var b := Vector3(p1.x, p1.y + spring_height, z0)
			var c := Vector3(p1.x, p1.y + spring_height, z1)
			var d := Vector3(p0.x, p0.y + spring_height, z1)
			var mid := (a + b) * 0.5
			var inward := Vector3(-mid.x, spring_height - mid.y, 0.0)
			if inward.length_squared() < 1e-8:
				inward = Vector3.DOWN
			_quad(st, a, b, c, d, Vector2(z0, i), Vector2(z0, i + 1), Vector2(z1, i + 1), Vector2(z1, i), inward)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


## Rectangle profile centred on the path (for ribs, frames, beams).
static func rect_profile(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
			Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])


## Extrude a simple polygon (no holes) along Z by `depth`, centred.
static func extrude_polygon(points: PackedVector2Array, depth: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var hz := depth * 0.5
	var tris := Geometry2D.triangulate_polygon(points)
	for i in range(0, tris.size(), 3):
		var p0 := points[tris[i]]
		var p1 := points[tris[i + 1]]
		var p2 := points[tris[i + 2]]
		_tri(st, Vector3(p0.x, p0.y, hz), Vector3(p1.x, p1.y, hz), Vector3(p2.x, p2.y, hz), Vector3.BACK)
		_tri(st, Vector3(p0.x, p0.y, -hz), Vector3(p1.x, p1.y, -hz), Vector3(p2.x, p2.y, -hz), Vector3.FORWARD)
	var ccw := not Geometry2D.is_polygon_clockwise(points)
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var e := b - a
		# Outward edge normal for the polygon's orientation (Y up).
		var out2 := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x)
		_quad(st, Vector3(a.x, a.y, hz), Vector3(b.x, b.y, hz), Vector3(b.x, b.y, -hz), Vector3(a.x, a.y, -hz),
				Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1), Vector3(out2.x, out2.y, 0.0))
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Cloth -------------------------------------------------------------------------------

## A hanging curtain in the XY plane (top edge at y = 0, hanging to -height),
## with folds that deepen toward the hem. Faces +Z (use a cull-disabled material).
static func curtain(width: float, height: float, folds: float = 6.0, depth: float = 0.08, seed: float = 0.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := int(folds * 8.0)
	var ny := 14
	var grid: Array[PackedVector3Array] = []
	for j in ny + 1:
		var v := float(j) / ny
		var row := PackedVector3Array()
		for i in nx + 1:
			var u := float(i) / nx
			var x := (u - 0.5) * width
			var fold := sin(u * folds * TAU + seed) + 0.35 * sin(u * folds * 2.3 * TAU + seed * 2.0)
			var z := fold * depth * (0.45 + 0.55 * v)
			var y := -v * height - (0.04 * sin(u * 9.0 + seed) * v)
			row.append(Vector3(x * (1.0 - 0.06 * v * absf(u - 0.5)), y, z))
		grid.append(row)
	for j in ny:
		for i in nx:
			_quad(st, grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i],
					Vector2(float(i) / nx, float(j) / ny), Vector2(float(i + 1) / nx, float(j) / ny),
					Vector2(float(i + 1) / nx, float(j + 1) / ny), Vector2(float(i) / nx, float(j + 1) / ny), Vector3.BACK)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


# --- Porcelain mask ---------------------------------------------------------------------

## A sculpted face: a deformed sphere with brow, sockets, nose, cheekbones,
## lips and chin. `smile` 0..1 lifts the mouth corners; `open` 0..1 parts the
## lips. Faces +Z. Roughly 0.24 m tall. Symmetry is deliberately perfect.
static func mask_mesh(smile: float = 1.0, open: float = 0.0, rings: int = 28, segments: int = 36) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid: Array[PackedVector3Array] = []
	for i in rings + 1:
		var v := float(i) / rings  # 0 top .. 1 bottom
		var phi := v * PI
		var row := PackedVector3Array()
		for s in segments + 1:
			var theta := float(s) / segments * TAU
			var p := Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
			row.append(_sculpt(p, smile, open))
		grid.append(row)
	for i in rings:
		for s in segments:
			var uv0 := Vector2(float(s) / segments, float(i) / rings)
			var uv1 := Vector2(float(s + 1) / segments, float(i + 1) / rings)
			var a := grid[i][s]
			var b := grid[i + 1][s]
			var c := grid[i + 1][s + 1]
			var d := grid[i][s + 1]
			_quad(st, a, b, c, d, uv0, Vector2(uv0.x, uv1.y), uv1, Vector2(uv1.x, uv0.y), (a + b + c + d) * 0.25)
	st.generate_normals()
	st.generate_tangents()
	return st.commit()


static func _gauss(d2: float, sigma: float) -> float:
	return exp(-d2 / (2.0 * sigma * sigma))


## Displace a unit-sphere point into a face. Units: metres after scaling.
static func _sculpt(p: Vector3, smile: float, open: float) -> Vector3:
	# Base: an egg, narrower at the chin, flatter at the back.
	var q := Vector3(p.x * 0.078, p.y * 0.118, p.z * 0.095)
	if p.y < 0.0:
		q.x *= 1.0 + p.y * 0.28  # taper toward the jaw
		q.z *= 1.0 + p.y * 0.1
	if p.z < 0.0:
		q.z *= 0.82
	var front := clampf(p.z, 0.0, 1.0)
	if front <= 0.0:
		return q
	var x := p.x
	var y := p.y
	var ax := absf(x)
	var dz := 0.0
	# Brow ridge.
	dz += 0.006 * _gauss((y - 0.32) * (y - 0.32) * 4.0 + x * x * 0.6, 0.35)
	# Eye sockets: a little too far apart, perfectly level.
	dz -= 0.011 * _gauss((ax - 0.36) * (ax - 0.36) + (y - 0.17) * (y - 0.17) * 1.6, 0.12)
	# Nose bridge and tip.
	dz += 0.018 * _gauss(x * x * 18.0 + (y - 0.02) * (y - 0.02) * 1.2, 0.18) * smoothstep(0.32, 0.0, y + 0.1)
	dz += 0.01 * _gauss(x * x * 10.0 + (y + 0.08) * (y + 0.08) * 12.0, 0.15)
	# Cheekbones, high and smooth.
	dz += 0.006 * _gauss((ax - 0.42) * (ax - 0.42) * 2.0 + (y + 0.02) * (y + 0.02) * 3.0, 0.2)
	# Mouth: lips, with corners lifted by `smile` (a fraction too wide).
	var corner_lift := smile * 0.09 * (ax / 0.34) * (ax / 0.34)
	var my := y + 0.4 - corner_lift
	dz += 0.005 * _gauss(x * x * 2.2 + (my - 0.035) * (my - 0.035) * 60.0, 0.12)  # upper lip
	dz += 0.006 * _gauss(x * x * 2.6 + (my + 0.035) * (my + 0.035) * 60.0, 0.12)  # lower lip
	dz -= (0.004 + open * 0.016) * _gauss(x * x * (2.4 - open * 1.2) + my * my * (220.0 - open * 170.0), 0.11)
	# Chin.
	dz += 0.007 * _gauss(x * x * 3.0 + (y + 0.66) * (y + 0.66) * 6.0, 0.2)
	return q + Vector3(0.0, 0.0, dz * front)


# --- Almost-human face -------------------------------------------------------------------
# A head that is trying to be human and getting it slightly wrong. All
# proportions are in unit-sphere front coordinates (x, y in -1..1).

const FACE_EYE_X := 0.44        # too far apart (human ~0.33)
const FACE_EYE_Y := -0.08       # too low (human ~+0.05)
const FACE_MOUTH_Y := -0.44     # too close to the nose
const FACE_MOUTH_W := 0.47      # too wide
const FACE_SCALE := Vector3(0.074, 0.122, 0.096)


## Head mesh with vertex-colour shading. smile 0..1 lifts the corners too
## sharply; open 0..1 drops the jaw further than a jaw should go.
static func face_mesh(smile: float = 1.0, open: float = 0.0, rings: int = 34, segments: int = 44) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pos: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for i in rings + 1:
		var phi := float(i) / rings * PI
		var prow := PackedVector3Array()
		var crow := PackedColorArray()
		for sgi in segments + 1:
			# Offset by PI so the mesh seam runs down the back of the head.
			var theta := float(sgi) / segments * TAU + PI
			var p := Vector3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
			prow.append(_face_shape(p, smile, open))
			crow.append(_face_paint(p, smile, open))
		pos.append(prow)
		cols.append(crow)
	for i in rings:
		for sgi in segments:
			var a := pos[i][sgi]
			var b := pos[i + 1][sgi]
			var c := pos[i + 1][sgi + 1]
			var d := pos[i][sgi + 1]
			var facing := (a + b + c + d) * 0.25
			_tri_col(st, a, b, c, cols[i][sgi], cols[i + 1][sgi], cols[i + 1][sgi + 1], facing)
			_tri_col(st, a, c, d, cols[i][sgi], cols[i + 1][sgi + 1], cols[i][sgi + 1], facing)
	st.generate_normals()
	return st.commit()


## World-space (head-local) point on the face surface at front coords (x, y).
static func face_point(x: float, y: float, smile: float = 1.0, open: float = 0.0) -> Vector3:
	var z := sqrt(maxf(1.0 - x * x - y * y, 0.0))
	return _face_shape(Vector3(x, y, z), smile, open)


## Mouth-line height (front coords) at horizontal position x for a smile.
static func face_mouth_y(x: float, smile: float) -> float:
	var k := clampf(absf(x) / FACE_MOUTH_W, 0.0, 1.2)
	return FACE_MOUTH_Y + smile * 0.17 * pow(k, 2.6)


static func _face_shape(p: Vector3, smile: float, open: float) -> Vector3:
	var q := Vector3(p.x * FACE_SCALE.x, p.y * FACE_SCALE.y, p.z * FACE_SCALE.z)
	if p.y < 0.0:
		q.x *= 1.0 + p.y * 0.34          # narrow, tapering jaw
		q.y *= 1.0 + 0.1 * smoothstep(-0.5, -1.0, p.y) + open * 0.18 * smoothstep(-0.35, -0.9, p.y)
	if p.z < 0.0:
		q.z *= 0.86
	var front := clampf(p.z, 0.0, 1.0)
	if front <= 0.0:
		return q
	var x := p.x
	var y := p.y
	var ax := absf(x)
	var dz := 0.0
	# Forehead: tall and a little too smooth.
	dz += 0.004 * _gauss(x * x * 0.5 + (y - 0.45) * (y - 0.45), 0.35)
	# Sockets.
	dz -= 0.013 * _gauss((ax - FACE_EYE_X) * (ax - FACE_EYE_X) + (y - FACE_EYE_Y) * (y - FACE_EYE_Y) * 1.5, 0.14)
	dz += 0.004 * _gauss((ax - FACE_EYE_X) * (ax - FACE_EYE_X) * 0.8 + (y - FACE_EYE_Y - 0.2) * (y - FACE_EYE_Y - 0.2) * 6.0, 0.15)
	# A short, narrow nose.
	var nose_top := FACE_EYE_Y + 0.02
	var nose_tip := FACE_EYE_Y - 0.24
	if y < nose_top and y > nose_tip - 0.08:
		var t := clampf((nose_top - y) / (nose_top - nose_tip), 0.0, 1.0)
		dz += 0.012 * t * _gauss(x * x * 30.0, 0.18)
	dz += 0.006 * _gauss(x * x * 14.0 + (y - nose_tip) * (y - nose_tip) * 20.0, 0.14)
	# High cheekbones, hollow beneath.
	dz += 0.005 * _gauss((ax - 0.5) * (ax - 0.5) * 2.0 + (y - FACE_EYE_Y + 0.08) * (y - FACE_EYE_Y + 0.08) * 4.0, 0.2)
	dz -= 0.006 * _gauss((ax - 0.52) * (ax - 0.52) * 2.5 + (y - FACE_MOUTH_Y - 0.1) * (y - FACE_MOUTH_Y - 0.1) * 5.0, 0.16)
	# Thin lips along a mouth line whose corners turn up too sharply.
	var my := y - face_mouth_y(x, smile)
	var inside := 1.0 - smoothstep(FACE_MOUTH_W * 0.9, FACE_MOUTH_W * 1.05, ax)
	dz += 0.0035 * _gauss(my * my * 260.0, 0.35) * inside
	var slit := (0.006 + open * 0.032) * _gauss(my * my * (300.0 - open * 270.0), 0.25) * inside
	dz -= slit
	# A long, pointed chin.
	dz += 0.008 * _gauss(x * x * 4.0 + (y + 0.82) * (y + 0.82) * 5.0, 0.2)
	return q + Vector3(0.0, 0.0, dz * front)


static func _face_paint(p: Vector3, smile: float, open: float) -> Color:
	var v := 0.86
	var front := clampf(p.z, 0.0, 1.0)
	var mottled := (sin(p.x * 91.0 + p.y * 37.0) * sin(p.y * 53.0 - p.z * 29.0)) * 0.035
	v += mottled
	if front > 0.0:
		var x := p.x
		var y := p.y
		var ax := absf(x)
		# Bruised sockets and too-dark under-eyes.
		v -= 0.55 * _gauss((ax - FACE_EYE_X) * (ax - FACE_EYE_X) + (y - FACE_EYE_Y) * (y - FACE_EYE_Y) * 1.3, 0.13) * front
		v -= 0.12 * _gauss((ax - FACE_EYE_X) * (ax - FACE_EYE_X) * 1.5 + (y - FACE_EYE_Y + 0.14) * (y - FACE_EYE_Y + 0.14) * 9.0, 0.12) * front
		# Fine features (eyebrows, nostrils, mouth, teeth) are painted per
		# pixel in skin.gdshader; the mesh carries only broad shading.
	v = clampf(v, 0.04, 1.0)
	return Color(v, v * 0.985, v * 0.96)


static func _tri_col(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ca: Color, cb: Color, cc: Color, facing: Vector3) -> void:
	var n := (a - c).cross(a - b)
	if n.length_squared() < 1e-16:
		return
	if n.dot(facing) < 0.0:
		var tmp := b
		b = c
		c = tmp
		var tc := cb
		cb = cc
		cc = tc
	st.set_color(ca)
	st.add_vertex(a)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_color(cc)
	st.add_vertex(c)


# --- Graphic forms ----------------------------------------------------------------------

## A jagged, torn shape (like a black brushstroke) in the XY plane, extruded
## thinly. Deterministic for a given seed.
static func jagged_shard(width: float, height: float, seed: int, spikes: int = 14, depth: float = 0.03) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var pts := PackedVector2Array()
	for i in spikes:
		var a := float(i) / spikes * TAU
		var r := rng.randf_range(0.45, 1.0) if i % 2 == 0 else rng.randf_range(0.15, 0.55)
		pts.append(Vector2(cos(a) * width * 0.5 * r, sin(a) * height * 0.5 * r))
	return extrude_polygon(pts, depth)


## An irregular pointed opening: sides of unequal height, a lean, a skewed
## apex. For CSG cut-outs and frames.
static func irregular_arch_opening(width: float, spring: float, rise: float, lean: float, skew: float, segments: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var hw := width * 0.5
	pts.append(Vector2(hw, 0.0))
	var curve := pointed_arch_curve(width, rise, segments)
	for i in range(curve.size() - 1, -1, -1):
		var c := curve[i]
		var side_h := spring * (1.0 + skew * signf(c.x) * 0.5)
		var t := (c.y) / maxf(rise, 0.01)
		var apex_shift := skew * width * 0.3 * t
		pts.append(Vector2(c.x + lean * (c.y + side_h) * 0.12 + apex_shift, c.y + side_h))
	pts.append(Vector2(-hw, 0.0))
	return pts


# --- Internals --------------------------------------------------------------------------

## Emit a quad as two triangles whose front faces point along `facing`.
## Godot treats clockwise triangles as front faces; rather than reasoning about
## winding for every builder, each triangle is flipped if it faces away.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2, facing: Vector3) -> void:
	_tri_uv(st, a, b, c, ua, ub, uc, facing)
	_tri_uv(st, a, c, d, ua, uc, ud, facing)


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, facing: Vector3) -> void:
	_tri_uv(st, a, b, c, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), facing)


static func _tri_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, facing: Vector3) -> void:
	# Same convention as Plane(a, b, c): normal = (a - c) x (a - b).
	var n := (a - c).cross(a - b)
	if n.length_squared() < 1e-14:
		return  # degenerate
	if n.dot(facing) < 0.0:
		var tmp := b
		b = c
		c = tmp
		var tuv := ub
		ub = uc
		uc = tuv
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
