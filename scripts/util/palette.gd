@tool
class_name Palette
extends RefCounted
## The locked colour language: near-black, dirty off-white, violent red.
## Every placeholder material is created here so the whole prototype can be
## re-graded from one file. Materials are cached and shared.

const BLACK := Color(0.018, 0.017, 0.02)
const CHARCOAL := Color(0.055, 0.052, 0.058)
const ASH := Color(0.16, 0.155, 0.16)
const BONE := Color(0.86, 0.84, 0.79)
const PAPER := Color(0.93, 0.91, 0.86)
const RED := Color(0.62, 0.03, 0.025)
const RED_HOT := Color(0.95, 0.06, 0.04)
const WAX := Color(0.88, 0.85, 0.80)

## Render layer used for first-person viewmodel meshes (layer 20).
const VIEWMODEL_LAYER := 1 << 19

static var _cache: Dictionary = {}


static func lit(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "lit_%s_%.2f_%.2f" % [color.to_html(), roughness, metallic]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	_cache[key] = m
	return m


static func emissive(color: Color, energy: float = 1.0) -> StandardMaterial3D:
	var key := "emi_%s_%.2f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.6
	_cache[key] = m
	return m


static func unshaded(color: Color, transparent: bool = false) -> StandardMaterial3D:
	var key := "uns_%s_%s" % [color.to_html(), transparent]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_receive_shadows = true
	_cache[key] = m
	return m


## Pale, slightly waxy skin for masks and faces: at first glance human.
static func wax() -> StandardMaterial3D:
	if _cache.has("wax"):
		return _cache["wax"]
	var m := StandardMaterial3D.new()
	m.albedo_color = WAX
	m.roughness = 0.32
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.25
	# Faint self-illumination so pale faces read out of black rooms.
	m.emission_enabled = true
	m.emission = WAX
	m.emission_energy_multiplier = 0.22
	_cache["wax"] = m
	return m


## A fresh (un-cached) copy of a material, for per-instance flashes/tints.
static func unique(material: StandardMaterial3D) -> StandardMaterial3D:
	return material.duplicate() as StandardMaterial3D


# --- Tiny mesh helpers used by code-built placeholders ----------------------

static func box(size: Vector3, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material
	return mi


static func sphere(radius: float, material: Material, segments: int = 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments >> 1, 4)
	mi.mesh = mesh
	mi.material_override = material
	return mi


static func cylinder(radius: float, height: float, material: Material, segments: int = 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = material
	return mi


static func capsule(radius: float, height: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = material
	return mi


## Put a mesh tree on the viewmodel render layer only, with no shadows.
static func to_viewmodel_layer(node: Node) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = VIEWMODEL_LAYER
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		to_viewmodel_layer(child)
