@tool
class_name CastleMaterials
extends RefCounted
## Realistic material set for the castle, built on the procedural shaders in
## res://shaders/. All results are cached and shared. Colours stay within the
## black / bone / red language; the final palette grade does the rest.

const STONE_SHADER := preload("res://shaders/stone_masonry.gdshader")
const MARBLE_SHADER := preload("res://shaders/marble_floor.gdshader")
const WOOD_SHADER := preload("res://shaders/dark_wood.gdshader")
const GLASS_SHADER := preload("res://shaders/stained_glass.gdshader")
const CLOTH_SHADER := preload("res://shaders/cloth.gdshader")

static var _cache: Dictionary = {}


static func _shader(key: String, shader: Shader, params: Dictionary) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = shader
	for k: String in params:
		m.set_shader_parameter(k, params[k])
	_cache[key] = m
	return m


## Pale limestone ashlar (walls, piers).
static func stone() -> ShaderMaterial:
	return _shader("stone", STONE_SHADER, {})


## Darker, sootier stone for low passages and the gallery.
static func stone_dark() -> ShaderMaterial:
	return _shader("stone_dark", STONE_SHADER, {
		"stone_color": Color(0.24, 0.23, 0.22), "mortar_color": Color(0.09, 0.085, 0.08),
		"grime_strength": 0.6, "streak_strength": 0.45,
	})


## Smooth dressed stone for columns, mouldings and the vault (larger blocks).
static func stone_dressed() -> ShaderMaterial:
	return _shader("stone_dressed", STONE_SHADER, {
		"stone_color": Color(0.5, 0.48, 0.45), "block_size": Vector2(1.6, 0.7),
		"flag_size": Vector2(1.6, 1.0), "mortar_width": 0.008, "color_variation": 0.12,
		"roughness_base": 0.72, "grime_strength": 0.3, "streak_strength": 0.2,
	})


static func marble() -> ShaderMaterial:
	return _shader("marble", MARBLE_SHADER, {})


static func wood() -> ShaderMaterial:
	return _shader("wood", WOOD_SHADER, {})


## Walnut for held objects: object-space grain, finer planks, a waxed sheen.
static func wood_held() -> ShaderMaterial:
	return _shader("wood_held", WOOD_SHADER, {
		"object_space": true, "object_scale": 4.0, "plank_width": 10.0, "vertical_planks": false,
		"roughness_base": 0.34, "wood_light": Color(0.5, 0.31, 0.17), "wood_dark": Color(0.2, 0.11, 0.06),
	})


static func wood_horizontal() -> ShaderMaterial:
	return _shader("wood_h", WOOD_SHADER, {"vertical_planks": false, "plank_width": 0.28})


static func stained_glass() -> ShaderMaterial:
	return _shader("glass", GLASS_SHADER, {})


static func velvet(color: Color, anchor_y: float = 1.6, sway: float = 0.025) -> ShaderMaterial:
	return _shader("velvet_%s_%.2f_%.3f" % [color.to_html(), anchor_y, sway], CLOTH_SHADER, {
		"cloth_color": color, "anchor_y": anchor_y, "sway_amount": sway,
	})


static func iron() -> StandardMaterial3D:
	if _cache.has("iron"):
		return _cache["iron"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.09, 0.095)
	m.metallic = 0.85
	m.roughness = 0.55
	_cache["iron"] = m
	return m


static func brass() -> StandardMaterial3D:
	if _cache.has("brass"):
		return _cache["brass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.5, 0.3)
	m.metallic = 1.0
	m.roughness = 0.32
	_cache["brass"] = m
	return m


static func silver() -> StandardMaterial3D:
	if _cache.has("silver"):
		return _cache["silver"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.77, 0.75)
	m.metallic = 1.0
	m.roughness = 0.22
	_cache["silver"] = m
	return m


static func blued_steel() -> StandardMaterial3D:
	if _cache.has("blued"):
		return _cache["blued"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.37, 0.4)
	m.metallic = 0.6
	m.roughness = 0.32
	_cache["blued"] = m
	return m


## Glazed porcelain: the masks. Clear coat + a little subsurface + rim.
static func porcelain() -> StandardMaterial3D:
	if _cache.has("porcelain"):
		return _cache["porcelain"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.88, 0.84)
	m.roughness = 0.24
	m.clearcoat_enabled = true
	m.clearcoat = 0.9
	m.clearcoat_roughness = 0.08
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.18
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.4
	m.emission_enabled = true
	m.emission = Color(0.9, 0.88, 0.84)
	m.emission_energy_multiplier = 0.12
	_cache["porcelain"] = m
	return m


## Pale kid-leather gloves.
static func glove() -> StandardMaterial3D:
	if _cache.has("glove"):
		return _cache["glove"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.82, 0.8, 0.76)
	m.roughness = 0.6
	m.rim_enabled = true
	m.rim = 0.25
	_cache["glove"] = m
	return m


static func wax() -> StandardMaterial3D:
	if _cache.has("candle_wax"):
		return _cache["candle_wax"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.88, 0.82)
	m.roughness = 0.45
	m.subsurf_scatter_enabled = true
	m.subsurf_scatter_strength = 0.5
	_cache["candle_wax"] = m
	return m


static func flame() -> StandardMaterial3D:
	if _cache.has("flame"):
		return _cache["flame"]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.82, 0.55)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.5)
	m.emission_energy_multiplier = 3.0
	m.disable_receive_shadows = true
	_cache["flame"] = m
	return m


static func black_glass() -> StandardMaterial3D:
	if _cache.has("black_glass"):
		return _cache["black_glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.02, 0.02, 0.025)
	m.metallic = 0.2
	m.roughness = 0.05
	_cache["black_glass"] = m
	return m
