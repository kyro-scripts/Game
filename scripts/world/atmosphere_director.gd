class_name AtmosphereDirector
extends Node
## Slow, sparse, unexplained events. Not jumpscares: things that happen at
## the edge of attention and are never explained.
##
## Every 18–42 world-seconds one event is chosen (weighted, with cooldowns):
##   guest       the Red Death stands far away down a sightline
##   light_dies  a nearby light goes out for a moment, with a relay click
##   sound       whisper / distant slam / drone / a wrong note / breathing,
##               from an ambiguous direction, quiet
##   door_red    the light under a fake door turns red for a few seconds
##   silence     every distant clock stops at once
## The level provides markers (group "guest_sighting"), lights (group
## "atmo_light"), fake doors (group "fake_door") and clocks ("distant_clock").

@export var min_interval: float = 18.0
@export var max_interval: float = 42.0
@export var first_delay: float = 14.0

const SOUNDS: Array[StringName] = [&"whisper", &"distant_slam", &"drone_swell", &"wrong_note", &"breath"]

var guest: GuestInRed

var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var _last: Dictionary = {}  # kind -> world_time of last use
var _dark_lights: Array[Dictionary] = []  # {light, energy, until}


func _ready() -> void:
	_rng.seed = RunManager.run_seed if RunManager.run_seed != 0 else 1
	_timer = first_delay
	guest = GuestInRed.new()
	guest.name = "GuestInRed"
	add_child(guest)
	guest.vanished.connect(_on_guest_vanished)


func _process(delta: float) -> void:
	var dt := TimeDirector.scaled(TimeDirector.Channel.WORLD, delta)
	_restore_lights()
	if not RunManager.active:
		return
	_timer -= dt
	if _timer <= 0.0:
		_timer = _rng.randf_range(min_interval, max_interval)
		trigger(_choose())


## Force an event (debug menu). Returns true if it could happen here.
func trigger(kind: StringName) -> bool:
	var ok := false
	match kind:
		&"guest":
			ok = _sighting()
		&"light_dies":
			ok = _light_dies()
		&"sound":
			ok = _sound()
		&"door_red":
			ok = _door_red()
		&"silence":
			ok = _silence()
	if ok:
		_last[kind] = TimeDirector.world_time
		Events.atmosphere_event.emit(kind)
	return ok


## All lights near the player cut out for a blink.
func blink(seconds: float = 0.12) -> void:
	var player := _player()
	if player == null:
		return
	for l in get_tree().get_nodes_in_group(&"atmo_light"):
		var light := l as Light3D
		if light != null and light.global_position.distance_to(player.global_position) < 35.0:
			_darken(light, seconds)


func _choose() -> StringName:
	var weights := {&"guest": 0.22, &"light_dies": 0.26, &"sound": 0.34, &"door_red": 0.08, &"silence": 0.1}
	var cooldowns := {&"guest": 55.0, &"door_red": 40.0, &"silence": 30.0}
	var total := 0.0
	var pool: Array[StringName] = []
	for k: StringName in weights:
		var since: float = TimeDirector.world_time - float(_last.get(k, -1000.0))
		if since < float(cooldowns.get(k, 0.0)):
			continue
		pool.append(k)
		total += float(weights[k])
	var r := _rng.randf() * total
	for k in pool:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return &"sound"


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _sighting() -> bool:
	var player := _player()
	if player == null or guest.showing:
		return false
	var eye := player.get_eye_position()
	var fwd := -player.camera.global_basis.z
	var best: Node3D = null
	var best_score := -INF
	for m in get_tree().get_nodes_in_group(&"guest_sighting"):
		var marker := m as Node3D
		var to := marker.global_position + Vector3.UP * 2.0 - eye
		var dist := to.length()
		if dist < 22.0 or dist > 90.0:
			continue
		var facing := fwd.dot(to / dist)
		if facing < 0.35:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, marker.global_position + Vector3.UP * 2.2, Player.LAYER_WORLD)
		if not player.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			continue
		var score := facing - dist * 0.004 + _rng.randf() * 0.2
		if score > best_score:
			best_score = score
			best = marker
	if best == null:
		return false
	guest.appear(best.global_position, player.global_position)
	for c in get_tree().get_nodes_in_group(&"distant_clock"):
		(c as DistantClock).silence(6.0)
	return true


func _light_dies() -> bool:
	var player := _player()
	if player == null:
		return false
	var candidates: Array[Light3D] = []
	for l in get_tree().get_nodes_in_group(&"atmo_light"):
		var light := l as Light3D
		if light != null and light.visible and light.global_position.distance_to(player.global_position) < 26.0:
			candidates.append(light)
	if candidates.is_empty():
		return false
	var light := candidates[_rng.randi() % candidates.size()]
	_darken(light, _rng.randf_range(0.7, 1.8))
	AudioDirector.play(&"light_click", light.global_position, -10.0, 1.0)
	return true


func _sound() -> bool:
	var player := _player()
	if player == null:
		return false
	var kind := SOUNDS[_rng.randi() % SOUNDS.size()]
	var a := _rng.randf() * TAU
	var at := player.global_position + Vector3(cos(a), 0.0, sin(a)) * _rng.randf_range(9.0, 22.0) + Vector3.UP * _rng.randf_range(0.5, 4.0)
	AudioDirector.play(kind, at, -9.0, _rng.randf_range(0.92, 1.05), AudioDirector.BUS_WORLD, 0.0)
	return true


func _door_red() -> bool:
	var doors := get_tree().get_nodes_in_group(&"fake_door")
	if doors.is_empty():
		return false
	var door := doors[_rng.randi() % doors.size()] as Node3D
	var mat := door.get_meta(&"sliver") as StandardMaterial3D
	if mat == null:
		return false
	mat.albedo_color = Palette.RED_HOT
	mat.emission = Palette.RED_HOT
	get_tree().create_timer(_rng.randf_range(2.5, 4.0), false).timeout.connect(func() -> void:
		mat.albedo_color = Color(0.95, 0.94, 0.9)
		mat.emission = Color(0.95, 0.94, 0.9)
	)
	return true


func _silence() -> bool:
	var clocks := get_tree().get_nodes_in_group(&"distant_clock")
	if clocks.is_empty():
		return false
	for c in clocks:
		(c as DistantClock).silence(4.5)
	return true


func _darken(light: Light3D, seconds: float) -> void:
	for entry in _dark_lights:
		if entry["light"] == light:
			entry["until"] = maxf(float(entry["until"]), TimeDirector.real_time + seconds)
			return
	_dark_lights.append({"light": light, "energy": light.light_energy, "until": TimeDirector.real_time + seconds,
			"flicker": light is FlickerLight})
	if light is FlickerLight:
		(light as FlickerLight).set_process(false)
	light.light_energy = 0.0


func _restore_lights() -> void:
	var keep: Array[Dictionary] = []
	for entry in _dark_lights:
		var light: Variant = entry["light"]
		if not is_instance_valid(light):
			continue
		if TimeDirector.real_time >= float(entry["until"]):
			var l := light as Light3D
			l.light_energy = float(entry["energy"])
			if bool(entry["flicker"]):
				l.set_process(true)
		else:
			keep.append(entry)
	_dark_lights = keep


func _on_guest_vanished() -> void:
	blink(0.14)
	AudioDirector.play(&"light_click", null, -14.0, 0.8, AudioDirector.BUS_WORLD)
