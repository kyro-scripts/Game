class_name UnseenShifter
extends Node3D
## Moves only when nobody is looking. After the player has not seen it for a
## while (and is not close), it relocates to another spot and turns to face
## them. Never moves while on screen.

@export var spots: PackedVector3Array = PackedVector3Array()
@export var unseen_seconds: float = 3.0
@export var min_player_distance: float = 12.0

var _unseen: float = 0.0
var _index: int = 0


func _process(delta: float) -> void:
	if spots.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var seen := cam.is_position_in_frustum(global_position + Vector3.UP * 0.6)
	if seen:
		_unseen = 0.0
		return
	_unseen += TimeDirector.scaled(TimeDirector.Channel.WORLD, delta)
	if _unseen < unseen_seconds:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var options: Array[int] = []
	for i in spots.size():
		if i == _index:
			continue
		if spots[i].distance_to(player.global_position) < min_player_distance:
			continue
		if cam.is_position_in_frustum(spots[i] + Vector3.UP * 0.6):
			continue
		options.append(i)
	if options.is_empty():
		return
	_index = options[randi() % options.size()]
	global_position = spots[_index]
	var to := player.global_position - global_position
	rotation.y = atan2(to.x, to.z)
	_unseen = 0.0
	Events.atmosphere_event.emit(&"shift")
