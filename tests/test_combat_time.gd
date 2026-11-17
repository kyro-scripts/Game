extends RefCounted
## Phase B success criteria, verified:
##   shoot enemy, kill enemy, gain timer seconds, activate Borrow Time,
##   clearly slow world, return to normal, experience Time Debt.

const TestRunner := preload("res://tests/test_runner.gd")
const WALKER := preload("res://scenes/enemies/dummy_walker.tscn")
const TURRET := preload("res://scenes/enemies/dummy_turret.tscn")
const PROJECTILE := preload("res://scenes/enemies/projectile.tscn")


func _static_walker(t: TestRunner, at: Vector3) -> DummyWalker:
	var w := WALKER.instantiate() as DummyWalker
	w.pursue = false
	t.arena.add_child(w)
	w.global_position = at
	return w


## Aim the player camera at a world point.
func _aim_at(t: TestRunner, point: Vector3) -> void:
	var eye := t.player.get_eye_position()
	var d := point - eye
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	t.player.set_look(yaw, pitch)


func _fire_once(t: TestRunner) -> void:
	t.player.weapon.trigger()
	await t.seconds(t.player.weapon.data.fire_interval + 0.05)


func test_body_shots_kill_and_grant_time(t: TestRunner) -> void:
	var w := _static_walker(t, Vector3(0.0, 0.0, -7.0))
	await t.physics(4)
	_aim_at(t, w.global_position + Vector3.UP * 0.9)
	await t.physics(1)
	var reward := w.data.time_reward
	var hits := [0, 0]  # [hits, kills]
	var on_hit := func(killed: bool, _h: bool) -> void:
		hits[0] += 1
		if killed:
			hits[1] += 1
	t.player.weapon.hit_confirmed.connect(on_hit)
	var kills_signal := [0]
	var granted := [0.0]
	var on_kill := func(_e: Node3D, _i: Dictionary) -> void: kills_signal[0] += 1
	var on_time := func(s: float, _r: StringName) -> void: granted[0] += s
	Events.enemy_killed.connect(on_kill)
	Events.time_granted.connect(on_time)
	var shots := int(ceil(w.data.max_health / t.player.weapon.data.damage))
	for i in shots:
		await _fire_once(t)
	Events.enemy_killed.disconnect(on_kill)
	Events.time_granted.disconnect(on_time)
	t.check(hits[0] == shots, "every body shot registered a hit (%d/%d)" % [hits[0], shots])
	t.check(hits[1] == 1, "the final shot reported a kill")
	t.check(kills_signal[0] == 1, "enemy_killed emitted once")
	t.check_near(granted[0], reward, 0.01, "kill granted the enemy's time reward")
	t.check(int(RunManager.stats["kills"]) == 1, "RunManager counted the kill")


func test_headshots_need_fewer_shots(t: TestRunner) -> void:
	var w := _static_walker(t, Vector3(0.0, 0.0, -7.0))
	await t.physics(4)
	var head := w.get_node(^"HeadHurtbox/CollisionShape3D") as Node3D
	_aim_at(t, head.global_position)
	var died := [false]
	w.died.connect(func(_e: EnemyBase) -> void: died[0] = true)
	await _fire_once(t)
	t.check(not died[0], "one headshot does not kill")
	await _fire_once(t)
	t.check(died[0], "two headshots kill (headshot multiplier)")


func test_missed_shots_hit_world(t: TestRunner) -> void:
	t.add_static_box(Vector3(0.0, 2.0, -20.0), Vector3(10.0, 4.0, 1.0))
	await t.physics(2)
	var hits := [0]
	t.player.weapon.hit_confirmed.connect(func(_k: bool, _h: bool) -> void: hits[0] += 1)
	await _fire_once(t)
	t.check(hits[0] == 0, "shooting a wall confirms no hit")
	t.check(int(RunManager.stats["shots_fired"]) == 1, "shot counted")


func test_borrow_time_slows_world_not_player_or_clock(t: TestRunner) -> void:
	var sw := t.player.stopwatch
	var C := TimeDirector.Channel
	Input.action_press(&"borrow_time")
	await t.seconds(0.3)
	t.check(sw.active, "Borrow Time active while held")
	t.check_near(TimeDirector.get_scale(C.WORLD), sw.borrow.world_scale, 0.01, "world slowed to world_scale")
	t.check_near(TimeDirector.get_scale(C.ENEMY), sw.borrow.world_scale, 0.01, "enemies slowed")
	t.check_near(TimeDirector.get_scale(C.PLAYER), sw.borrow.player_scale, 0.01, "player barely slowed")
	t.check_near(TimeDirector.get_scale(C.RUN_TIMER), 1.0, 0.001, "run timer NOT slowed")
	var before := RunManager.time_remaining
	await t.seconds(1.0)
	t.check_near(before - RunManager.time_remaining, 1.0, 0.05, "clock drains in real time while borrowing")
	Input.action_release(&"borrow_time")
	await t.seconds(0.3)
	t.check(not sw.active, "releasing ends Borrow Time")
	t.check_near(TimeDirector.get_scale(C.WORLD), 1.0, 0.001, "world returns to normal speed")


func test_projectiles_and_enemies_visibly_slow(t: TestRunner) -> void:
	# A projectile flying away from the player: compare distance per second.
	var p := PROJECTILE.instantiate() as Projectile
	p.velocity = Vector3(0.0, 0.0, -9.0)
	t.arena.add_child(p)
	p.global_position = Vector3(30.0, 1.5, 0.0)
	await t.physics(2)
	var z0 := p.global_position.z
	await t.seconds(0.5)
	var normal_rate := absf(p.global_position.z - z0) / 0.5
	Input.action_press(&"borrow_time")
	await t.seconds(0.25)
	z0 = p.global_position.z
	await t.seconds(0.5)
	var slow_rate := absf(p.global_position.z - z0) / 0.5
	Input.action_release(&"borrow_time")
	t.check_near(normal_rate, 9.0, 0.3, "projectile moves at full speed normally")
	t.check_near(slow_rate / normal_rate, t.player.stopwatch.borrow.world_scale, 0.05, "projectile slowed by world_scale")


func test_borrow_time_runs_out_and_charges_debt(t: TestRunner) -> void:
	var sw := t.player.stopwatch
	var C := TimeDirector.Channel
	var started_at := TimeDirector.real_time
	Input.action_press(&"borrow_time")
	await t.physics(2)
	var ended := await t.until(func() -> bool: return not sw.active, 5.0)
	var duration := TimeDirector.real_time - started_at
	t.check(ended, "Borrow Time ends by itself when charge runs out")
	t.check_near(duration, sw.borrow.max_duration, 0.12, "a full charge lasts max_duration real seconds")
	t.check_le(sw.charge, 0.01, "charge depleted")
	await t.physics(2)
	t.check(TimeDirector.has_modifier(&"time_debt"), "Time Debt applied after borrowing")
	t.check_near(TimeDirector.get_scale(C.RUN_TIMER), sw.borrow.debt_drain_multiplier, 0.001, "clock drains faster in debt")
	var before := RunManager.time_remaining
	await t.seconds(1.0)
	t.check_near(before - RunManager.time_remaining, sw.borrow.debt_drain_multiplier, 0.06, "1 s of debt costs debt_drain_multiplier seconds")
	t.check_near(sw.debt_remaining, sw.borrow.debt_max_duration - 1.0, 0.15, "full borrow = full debt duration")
	Input.action_release(&"borrow_time")
	var cleared := await t.until(func() -> bool: return not TimeDirector.has_modifier(&"time_debt"), sw.borrow.debt_max_duration + 0.5)
	t.check(cleared, "debt expires")
	t.check_near(TimeDirector.get_scale(C.RUN_TIMER), 1.0, 0.001, "clock back to normal after debt")


func test_borrow_needs_charge_and_recharges(t: TestRunner) -> void:
	var sw := t.player.stopwatch
	sw.charge = 0.1
	Input.action_press(&"borrow_time")
	await t.physics(4)
	t.check(not sw.active, "cannot borrow below min_charge_to_activate")
	Input.action_release(&"borrow_time")
	await t.seconds(sw.borrow.recharge_delay + sw.borrow.recharge_time * 0.3)
	t.check_ge(sw.charge, 0.3, "charge refills over time")
	Input.action_press(&"borrow_time")
	await t.physics(4)
	t.check(sw.active, "can borrow again once recharged")
	Input.action_release(&"borrow_time")
	await t.physics(2)


func test_short_borrow_short_debt(t: TestRunner) -> void:
	var sw := t.player.stopwatch
	Input.action_press(&"borrow_time")
	await t.seconds(0.25)
	Input.action_release(&"borrow_time")
	await t.physics(2)
	var expected := lerpf(sw.borrow.debt_min_duration, sw.borrow.debt_max_duration, 0.25 / sw.borrow.max_duration)
	t.check_near(sw.debt_remaining, expected, 0.15, "debt scales with borrow length")


func test_kill_restores_borrow_charge(t: TestRunner) -> void:
	var sw := t.player.stopwatch
	sw.charge = 0.3
	var w := _static_walker(t, Vector3(0.0, 0.0, -7.0))
	await t.physics(4)
	w.take_damage(9999.0, {})
	await t.physics(2)
	t.check_near(sw.charge, 0.3 + sw.borrow.charge_per_kill, 0.02, "a kill refunds some charge")


func test_walker_chases_and_hits_player(t: TestRunner) -> void:
	var w := WALKER.instantiate() as DummyWalker
	t.arena.add_child(w)
	w.global_position = Vector3(0.0, 0.0, -12.0)
	var hurt := await t.until(func() -> bool: return t.player.health < t.player.max_health, 6.0)
	t.check(hurt, "pursuing walker reaches and damages the player")
	t.check_near(t.player.health, t.player.max_health - w.data.attack_damage, 0.01, "damage equals attack_damage")


func test_walker_is_slower_during_borrow(t: TestRunner) -> void:
	var w := WALKER.instantiate() as DummyWalker
	t.arena.add_child(w)
	w.global_position = Vector3(0.0, 0.0, -30.0)
	var chasing := await t.until(func() -> bool: return w.state == EnemyBase.State.CHASE, 3.0)
	t.check(chasing, "walker notices the player and starts chasing")
	await t.seconds(0.6)
	var z0 := w.global_position.z
	await t.seconds(0.5)
	var normal_rate := absf(w.global_position.z - z0) / 0.5
	Input.action_press(&"borrow_time")
	await t.seconds(0.25)
	z0 = w.global_position.z
	await t.seconds(0.5)
	var slow_rate := absf(w.global_position.z - z0) / 0.5
	Input.action_release(&"borrow_time")
	t.check_near(normal_rate, w.data.move_speed, 0.4, "walker chases at move_speed")
	t.check_near(slow_rate / maxf(normal_rate, 0.01), t.player.stopwatch.borrow.world_scale, 0.06, "walker slowed by world_scale")


func test_timer_running_out_ends_run(t: TestRunner) -> void:
	var results: Array[Dictionary] = []
	var on_end := func(r: Dictionary) -> void: results.append(r)
	Events.run_ended.connect(on_end)
	RunManager.time_remaining = 0.3
	await t.seconds(0.6)
	Events.run_ended.disconnect(on_end)
	t.check(results.size() == 1, "run_ended emitted once")
	t.check(results.size() == 1 and results[0]["reason"] == &"time", "reason is time")
	t.check(not RunManager.active, "run no longer active")


func test_death_ends_run(t: TestRunner) -> void:
	var results: Array[Dictionary] = []
	var on_end := func(r: Dictionary) -> void: results.append(r)
	Events.run_ended.connect(on_end)
	t.player.take_damage(9999.0, null)
	await t.physics(2)
	Events.run_ended.disconnect(on_end)
	t.check(not t.player.alive, "player died")
	t.check(results.size() == 1 and results[0]["reason"] == &"wounds", "run ended by wounds")


func test_god_mode_and_infinite_timer(t: TestRunner) -> void:
	GameState.god_mode = true
	GameState.infinite_timer = true
	t.player.take_damage(50.0, null)
	var before := RunManager.time_remaining
	await t.seconds(0.5)
	t.check_near(t.player.health, t.player.max_health, 0.01, "god mode ignores damage")
	t.check_near(RunManager.time_remaining, before, 0.0001, "infinite timer freezes the clock")
