class_name ViewmodelRenderer
extends CanvasLayer
## Renders the first-person hands (render layer 20) through a second camera in
## a transparent SubViewport layered over the world view. Benefits:
##  * hands never clip into walls,
##  * hands keep a fixed FOV while the world FOV widens with speed.
## The SubViewport shares the world, so castle lights still light the hands.

var _source: Camera3D
var _viewport: SubViewport
var _camera: Camera3D


func setup(source: Camera3D) -> void:
	_source = source


func get_camera() -> Camera3D:
	return _camera


func _ready() -> void:
	layer = 1
	process_priority = 100  # after the player camera applies shake/roll
	var container := SubViewportContainer.new()
	container.name = "ViewmodelContainer"
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.name = "ViewmodelViewport"
	_viewport.transparent_bg = true
	_viewport.handle_input_locally = false
	_viewport.gui_disable_input = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	container.add_child(_viewport)

	_camera = Camera3D.new()
	_camera.name = "ViewmodelCamera"
	_camera.cull_mask = Palette.VIEWMODEL_LAYER
	_camera.near = 0.01
	_camera.far = 10.0
	_camera.fov = GameState.viewmodel_fov
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.55, 0.58)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# A dim gradient sky that is never drawn (clear background) but gives
	# silver, brass and glass something to reflect.
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.31, 0.3)
	sky_mat.sky_horizon_color = Color(0.55, 0.53, 0.5)
	sky_mat.ground_horizon_color = Color(0.22, 0.2, 0.19)
	sky_mat.ground_bottom_color = Color(0.03, 0.03, 0.03)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_camera.environment = env
	_viewport.add_child(_camera)
	_camera.current = true


func _process(_delta: float) -> void:
	if _source == null or not is_instance_valid(_source):
		return
	_camera.global_transform = _source.global_transform
	_camera.h_offset = _source.h_offset
	_camera.v_offset = _source.v_offset
	_camera.fov = GameState.viewmodel_fov
