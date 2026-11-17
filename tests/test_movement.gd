extends RefCounted
## Phase A success criteria, verified physically:
##   run, jump, preserve speed with skilful timing, slide, exit slide smoothly,
##   breach a door without losing all momentum.

const TestRunner := preload("res://tests/test_runner.gd")
const DOOR_SCENE := preload("res://scenes/world/breachable_door.tscn")


func _speed(t: TestRunner) -> float:
	return t.player.get_horizontal_speed()


func _run_up(t: TestRunner, seconds: float = 0.8) -> void:
	Input.action_press(&"move_forward")
	await t.seconds(seconds)


func test_run_reaches_max_speed_quickly(t: TestRunner) -> void:
	var tuning := t.player.tuning
	Input.action_press(&"move_forward")
	await t.seconds(0.25)
	t.check_ge(_speed(t), tuning.ground_max_speed * 0.9, "reaches 90% of top speed within 0.25 s")
	await t.seconds(0.5)
	t.check_near(_speed(t), tuning.ground_max_speed, 0.05, "settles at ground_max_speed")
	t.check(t.player.state == Player.MoveState.GROUND, "is grounded while running")
	t.check(t.player.global_position.z < -5.0, "moved forward (-Z)")


func test_stops_crisply(t: TestRunner) -> void:
	await _run_up(t)
	Input.action_release(&"move_forward")
	await t.seconds(0.4)
	t.check_le(_speed(t), 0.2, "stops within 0.4 s of releasing input")


func test_jump_height_and_landing(t: TestRunner) -> void:
	var start_y := t.player.global_position.y
	t.player.queue_jump()
	var peak := start_y
	for i in 120:
		await t.physics(1)
		peak = maxf(peak, t.player.global_position.y)
	var tuning := t.player.tuning
	var expected := tuning.jump_velocity * tuning.jump_velocity / (2.0 * tuning.gravity)
	t.check_near(peak - start_y, expected, 0.12, "jump apex matches v^2/2g")
	t.check(t.player.state == Player.MoveState.GROUND, "lands again")


## Jump the instant we touch down, as a skilled player would (jump buffer).
func _hop_chain(t: TestRunner, hops: int) -> Array[float]:
	var speeds: Array[float] = []
	t.player.queue_jump()
	await t.physics(2)
	for i in hops:
		var landed := await t.until(func() -> bool: return t.player.state != Player.MoveState.AIR, 2.0)
		if not landed:
			break
		speeds.append(_speed(t))
		t.player.queue_jump()
		await t.physics(2)
	return speeds


func test_bunny_hop_preserves_and_builds_speed(t: TestRunner) -> void:
	await _run_up(t)
	var base := _speed(t)
	var speeds := await _hop_chain(t, 8)
	t.check(speeds.size() == 8, "completed 8 hops")
	var final := _speed(t)
	t.check_ge(final, base + 3.0, "8 clean hops build speed via hop bonus")
	var monotonic := true
	for i in range(1, speeds.size()):
		if speeds[i] < speeds[i - 1] - 0.05:
			monotonic = false
	t.check(monotonic, "speed never drops between clean hops %s" % [speeds])
	# Stop hopping: excess momentum should bleed back toward run speed.
	await t.until(func() -> bool: return t.player.state == Player.MoveState.GROUND, 2.0)
	await t.seconds(1.2)
	t.check_le(_speed(t), t.player.tuning.ground_max_speed + 0.3, "over-speed bleeds off once you stop hopping")


func test_late_hops_do_not_build_speed(t: TestRunner) -> void:
	await _run_up(t)
	var base := _speed(t)
	t.player.queue_jump()
	await t.physics(2)
	for i in 4:
		await t.until(func() -> bool: return t.player.state == Player.MoveState.GROUND, 2.0)
		await t.seconds(0.35)  # sloppy: well outside the landing grace window
		t.player.queue_jump()
		await t.physics(2)
	t.check_le(_speed(t), base + 0.3, "late jumps earn no chain bonus")


func test_air_strafe_turn_keeps_speed(t: TestRunner) -> void:
	await _run_up(t)
	var speeds := await _hop_chain(t, 3)
	t.check(speeds.size() == 3, "built some speed")
	t.player.queue_jump()
	await t.physics(4)
	var before := _speed(t)
	var dir_before := Vector2(t.player.velocity.x, t.player.velocity.z).normalized()
	# Strafe right while turning the view right, as in an air-strafe.
	Input.action_release(&"move_forward")
	Input.action_press(&"move_right")
	for i in 50:
		t.player.set_look(t.player.rotation.y - deg_to_rad(1.2), 0.0)
		await t.physics(1)
	Input.action_release(&"move_right")
	var after := _speed(t)
	var dir_after := Vector2(t.player.velocity.x, t.player.velocity.z).normalized()
	var turned := rad_to_deg(absf(dir_before.angle_to(dir_after)))
	t.check_ge(turned, 20.0, "air-strafing curves the path")
	t.check_ge(after, before - 0.2, "air-strafing does not lose speed")


func test_slide_boost_friction_and_exit(t: TestRunner) -> void:
	var tuning := t.player.tuning
	await _run_up(t)
	var base := _speed(t)
	Input.action_press(&"slide")
	await t.physics(2)
	t.check(t.player.is_sliding(), "slide starts when pressed at speed")
	t.check_near(_speed(t), minf(base + tuning.slide_entry_boost, tuning.slide_boost_cap), 0.3, "slide entry boost applied")
	t.check(t.player.is_crouched(), "capsule lowered during slide")
	var cap := t.player.get_node(^"CollisionShape3D").shape as CapsuleShape3D
	t.check_near(cap.height, tuning.crouch_height, 0.01, "capsule height == crouch_height")
	var boosted := _speed(t)
	await t.seconds(1.0)
	t.check_near(_speed(t), boosted - tuning.slide_friction * 1.0, 0.4, "slide friction decelerates gently")
	Input.action_release(&"slide")
	await t.physics(2)
	t.check(not t.player.is_sliding(), "releasing slide ends it")
	t.check(not t.player.is_crouched(), "stands back up when unobstructed")
	t.check_ge(_speed(t), base, "exits slide with momentum above run speed")


func test_slide_jump_carries_momentum(t: TestRunner) -> void:
	await _run_up(t)
	Input.action_press(&"slide")
	await t.physics(3)
	var slide_speed := _speed(t)
	t.player.queue_jump()
	await t.physics(3)
	t.check(t.player.state == Player.MoveState.AIR, "can jump out of a slide")
	t.check_ge(_speed(t), slide_speed, "slide-jump keeps (and slightly adds to) slide speed")


func test_landing_while_holding_slide_enters_slide(t: TestRunner) -> void:
	await _run_up(t)
	t.player.queue_jump()
	await t.physics(4)
	var air_speed := _speed(t)
	Input.action_press(&"slide")
	var landed := await t.until(func() -> bool: return t.player.state != Player.MoveState.AIR, 2.0)
	t.check(landed, "landed")
	t.check(t.player.is_sliding(), "landing with slide held goes straight into a slide")
	t.check_ge(_speed(t), air_speed, "no speed lost on the landing-slide")


func test_cannot_stand_under_low_ceiling(t: TestRunner) -> void:
	# Low tunnel: 1.2 m clearance from z = -14 to z = -24.
	t.add_static_box(Vector3(0.0, 1.2 + 1.0, -19.0), Vector3(8.0, 2.0, 10.0))
	await _run_up(t, 0.6)
	Input.action_press(&"slide")
	await t.until(func() -> bool: return t.player.global_position.z < -17.0, 3.0)
	Input.action_release(&"slide")
	Input.action_release(&"move_forward")
	await t.physics(10)
	t.check(t.player.global_position.z < -14.5, "got under the low ceiling")
	t.check(t.player.is_crouched(), "stays crouched while the ceiling blocks standing")
	Input.action_press(&"move_forward")
	await t.until(func() -> bool: return t.player.global_position.z < -25.0, 6.0)
	await t.physics(6)
	t.check(not t.player.is_crouched(), "stands up after leaving the tunnel")


func test_fast_door_breach_keeps_momentum(t: TestRunner) -> void:
	var door := t.add_scene(DOOR_SCENE, Vector3(0.0, 0.0, -12.0)) as BreachableDoor
	var breach_events := [0]
	var on_breach := func(_d: Node3D, _s: float) -> void: breach_events[0] += 1
	Events.door_breached.connect(on_breach)
	await t.physics(2)
	Input.action_press(&"move_forward")
	var min_speed_after_contact := 999.0
	var contacted := false
	for i in 240:
		await t.physics(1)
		if t.player.global_position.z < -10.5:
			contacted = true
		if contacted:
			min_speed_after_contact = minf(min_speed_after_contact, _speed(t))
		if t.player.global_position.z < -16.0:
			break
	Events.door_breached.disconnect(on_breach)
	t.check(door.breached, "door bursts when hit at running speed")
	t.check(breach_events[0] == 1, "door_breached event emitted once")
	t.check(t.player.global_position.z < -15.0, "player carried on through the doorway")
	t.check_ge(min_speed_after_contact, t.player.tuning.ground_max_speed * 0.85, "momentum mostly preserved through the breach")


func test_slow_contact_creaks_door_open(t: TestRunner) -> void:
	var door := t.add_scene(DOOR_SCENE, Vector3(0.0, 0.0, -6.0)) as BreachableDoor
	var breach_events := [0]
	var on_breach := func(_d: Node3D, _s: float) -> void: breach_events[0] += 1
	Events.door_breached.connect(on_breach)
	Input.action_press(&"slide")  # crouch-walk: below breach speed
	Input.action_press(&"move_forward")
	await t.seconds(1.2)
	t.check(t.player.global_position.z > -6.0, "slow approach is blocked at first")
	var passed := await t.until(func() -> bool: return t.player.global_position.z < -7.5, 4.0)
	Events.door_breached.disconnect(on_breach)
	t.check(passed, "door creaks open and lets the player through eventually")
	t.check(breach_events[0] == 0, "a slow push is not counted as a breach")
	t.check(door.breached, "door no longer blocks")
