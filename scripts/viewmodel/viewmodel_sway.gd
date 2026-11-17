class_name ViewmodelSway
extends Node3D
## Gives both hands weight: lag behind mouse turns, bob with stride, dip into
## slides, settle on landing. Pure presentation; runs on real time.

@export var sway_amount: float = 0.0009
@export var sway_max: float = 0.06
@export var bob_amount: float = 0.012

var _player: Player
var _sway: Vector2 = Vector2.ZERO
var _bob_phase: float = 0.0
var _slide_blend: float = 0.0
var _land_kick: float = 0.0


func _ready() -> void:
	_player = owner as Player
	if _player != null:
		_player.landed.connect(_on_landed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel := (event as InputEventMouseMotion).relative
		_sway -= rel * sway_amount
		_sway = _sway.limit_length(sway_max)


func _process(delta: float) -> void:
	if _player == null:
		return
	_sway = _sway.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	var speed := _player.get_horizontal_speed()
	var grounded := _player.state == Player.MoveState.GROUND
	if grounded and speed > 0.5:
		_bob_phase += delta * (5.0 + speed * 0.55)
	var bob_k := clampf(speed / 11.0, 0.0, 1.3) if grounded else 0.0
	var bob := Vector3(cos(_bob_phase * 0.5) * bob_amount * bob_k, sin(_bob_phase) * bob_amount * 0.7 * bob_k, 0.0)
	_slide_blend = lerpf(_slide_blend, 1.0 if _player.is_sliding() else 0.0, 1.0 - exp(-10.0 * delta))
	_land_kick = lerpf(_land_kick, 0.0, 1.0 - exp(-8.0 * delta))
	position = Vector3(_sway.x, _sway.y - _land_kick * 0.05 - _slide_blend * 0.03, 0.0) + bob
	rotation = Vector3(-_sway.y * 1.5, _sway.x * 1.5, _slide_blend * deg_to_rad(-6.0))


func _on_landed(fall_speed: float) -> void:
	_land_kick = clampf(fall_speed / 18.0, 0.0, 1.0)
