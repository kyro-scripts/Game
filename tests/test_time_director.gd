extends RefCounted
## Unit-level checks for the TimeDirector channel/modifier model.

const TestRunner := preload("res://tests/test_runner.gd")


func test_modifiers_stack_and_world_children_follow(t: TestRunner) -> void:
	var C := TimeDirector.Channel
	t.check_near(TimeDirector.get_scale(C.WORLD), 1.0, 0.0001, "default world scale is 1")
	TimeDirector.set_modifier(&"a", {C.WORLD: 0.5})
	t.check_near(TimeDirector.get_scale(C.ENEMY), 0.5, 0.0001, "ENEMY follows WORLD")
	t.check_near(TimeDirector.get_scale(C.PROJECTILE), 0.5, 0.0001, "PROJECTILE follows WORLD")
	t.check_near(TimeDirector.get_scale(C.PLAYER), 1.0, 0.0001, "PLAYER is independent of WORLD")
	t.check_near(TimeDirector.get_scale(C.RUN_TIMER), 1.0, 0.0001, "RUN_TIMER is independent of WORLD")
	TimeDirector.set_modifier(&"b", {C.PROJECTILE: 0.5, C.RUN_TIMER: 2.0})
	t.check_near(TimeDirector.get_scale(C.PROJECTILE), 0.25, 0.0001, "modifiers multiply (0.5 world * 0.5 projectile)")
	t.check_near(TimeDirector.get_scale(C.RUN_TIMER), 2.0, 0.0001, "run timer modifier applies")
	TimeDirector.clear_modifier(&"a")
	t.check_near(TimeDirector.get_scale(C.ENEMY), 1.0, 0.0001, "clearing a modifier restores the channel")
	t.check_near(TimeDirector.get_scale(C.PROJECTILE), 0.5, 0.0001, "other modifiers persist")
	TimeDirector.reset()
	t.check_near(TimeDirector.get_scale(C.RUN_TIMER), 1.0, 0.0001, "reset clears everything")
	await t.physics(1)
