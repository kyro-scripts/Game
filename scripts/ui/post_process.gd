class_name PostProcess
extends CanvasLayer
## Drives the palette grade shader from game state. Sits above the viewmodel
## layer so the hands are graded too, and below the HUD.

const SHADER := preload("res://shaders/palette_post.gdshader")

var _material: ShaderMaterial
var _damage: float = 0.0


func _ready() -> void:
	layer = 2
	var rect := ColorRect.new()
	rect.name = "Grade"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	rect.material = _material
	add_child(rect)
	Events.player_damaged.connect(_on_player_damaged)


func _process(delta: float) -> void:
	var world := TimeDirector.get_scale(TimeDirector.Channel.WORLD)
	var borrow := clampf((1.0 - world) / 0.65, 0.0, 1.0)
	var debt := 0.0
	if TimeDirector.has_modifier(&"time_debt"):
		debt = 0.6 + 0.4 * sin(TimeDirector.real_time * 9.0)
	var low := 0.0
	if RunManager.is_low_time():
		low = 0.5 + 0.5 * sin(TimeDirector.real_time * TAU)
	_damage = maxf(_damage - delta * 2.5, 0.0)
	_material.set_shader_parameter(&"borrow", borrow)
	_material.set_shader_parameter(&"debt", debt)
	_material.set_shader_parameter(&"low_time", low)
	_material.set_shader_parameter(&"damage", _damage)
	_material.set_shader_parameter(&"time_seed", fmod(TimeDirector.real_time * 37.0, 100.0))


func _on_player_damaged(amount: float, _source: Node) -> void:
	_damage = clampf(_damage + amount / 30.0, 0.0, 1.0)
