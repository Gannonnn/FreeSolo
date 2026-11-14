extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const LEFT := Climber.Limb.LEFT_HAND
const RIGHT := Climber.Limb.RIGHT_HAND

var wall: Wall
var climber: Climber
var left: Hold
var right: Hold


func before_each() -> void:
	wall = Fixtures.wall()
	left = Fixtures.hold(wall, &"jug", Vector2(2.2, 6.0))
	right = Fixtures.hold(wall, &"jug", Vector2(2.8, 6.0))
	climber = Fixtures.climber()
	Fixtures.hang(climber, wall, left, right)


func _rank(type: Difficulty.MoveType) -> int:
	match type:
		Difficulty.MoveType.STATIC:
			return 0
		Difficulty.MoveType.DEADPOINT:
			return 1
		Difficulty.MoveType.DYNO:
			return 2
	return 3


func test_hanging_puts_both_feet_on() -> void:
	assert_eq(climber.foot_count(), 2)


func test_close_hold_is_static_with_no_skill_check() -> void:
	var target := Fixtures.hold(wall, &"jug", Vector2(2.2, 5.75))
	var r := Difficulty.evaluate(climber, LEFT, target, wall)
	assert_eq(r.type, Difficulty.MoveType.STATIC)
	assert_eq(r.window, 1.0)
	assert_gt(r.stamina_cost, 0.0)


func test_move_type_escalates_with_distance() -> void:
	var seen: Array[int] = []
	var last := 0
	var y := 5.8
	while y > 3.0:
		var target := Fixtures.hold(wall, &"jug", Vector2(2.2, y))
		var rank := _rank(Difficulty.evaluate(climber, LEFT, target, wall).type)
		assert_true(rank >= last, "a farther hold is never an easier move type (y = %.2f)" % y)
		last = rank
		if not seen.has(rank):
			seen.append(rank)
		y -= 0.05
	assert_eq(seen, [0, 1, 2, 3], "static, deadpoint, dyno and out of reach all show up, in that order")


func test_same_inputs_give_the_same_result() -> void:
	var target := Fixtures.hold(wall, &"crimp", Vector2(2.3, 5.45), 15.0)
	var a := Difficulty.evaluate(climber, LEFT, target, wall)
	var b := Difficulty.evaluate(climber, LEFT, target, wall)
	assert_eq(a.type, b.type)
	assert_eq(a.stamina_cost, b.stamina_cost)
	assert_eq(a.window, b.window)
	assert_eq(a.excess, b.excess)


func test_worse_hold_costs_more_and_has_a_smaller_window() -> void:
	var probe := Fixtures.probe(wall, climber, LEFT, Difficulty.MoveType.DEADPOINT)
	assert_not_null(probe)
	var at := probe.position + Vector2(0.0, -0.03)
	var jug := Fixtures.hold(wall, &"jug", at)
	var crimp := Fixtures.hold(wall, &"crimp", at)
	var on_jug := Difficulty.evaluate(climber, LEFT, jug, wall)
	var on_crimp := Difficulty.evaluate(climber, LEFT, crimp, wall)
	assert_eq(on_jug.type, Difficulty.MoveType.DEADPOINT)
	assert_eq(on_crimp.type, Difficulty.MoveType.DEADPOINT)
	assert_gt(on_crimp.stamina_cost, on_jug.stamina_cost)
	assert_lt(on_crimp.window, on_jug.window)


func test_overhang_costs_more_and_drains_faster() -> void:
	var steep := Fixtures.wall(30.0)
	var steep_climber := Fixtures.climber()
	Fixtures.hang(steep_climber, steep, Fixtures.hold(steep, &"jug", Vector2(2.2, 6.0)), Fixtures.hold(steep, &"jug", Vector2(2.8, 6.0)))
	var flat_target := Fixtures.hold(wall, &"crimp", Vector2(2.2, 5.7))
	var steep_target := Fixtures.hold(steep, &"crimp", Vector2(2.2, 5.7))
	var flat := Difficulty.evaluate(climber, LEFT, flat_target, wall)
	var over := Difficulty.evaluate(steep_climber, LEFT, steep_target, steep)
	assert_eq(over.type, flat.type)
	assert_gt(over.stamina_cost, flat.stamina_cost)
	assert_gt(Difficulty.drain_per_second(steep_climber, steep), Difficulty.drain_per_second(climber, wall))


func test_slab_drains_slower() -> void:
	var slab := Fixtures.wall(-15.0)
	var slab_climber := Fixtures.climber()
	Fixtures.hang(slab_climber, slab, Fixtures.hold(slab, &"jug", Vector2(2.2, 6.0)), Fixtures.hold(slab, &"jug", Vector2(2.8, 6.0)))
	assert_lt(Difficulty.drain_per_second(slab_climber, slab), Difficulty.drain_per_second(climber, wall))


func test_hold_rotation_changes_grip() -> void:
	var upright := Fixtures.hold(wall, &"crimp", Vector2(2.2, 5.65), 0.0)
	var upside_down := Fixtures.hold(wall, &"crimp", Vector2(2.25, 5.65), 180.0)
	var good := Difficulty.evaluate(climber, LEFT, upright, wall)
	var bad := Difficulty.evaluate(climber, LEFT, upside_down, wall)
	assert_gt(good.pull_alignment, 0.5)
	assert_lt(bad.pull_alignment, -0.5)
	assert_gt(good.grip, bad.grip)
	assert_lt(good.stamina_cost, bad.stamina_cost)


func test_power_turns_a_dyno_into_a_deadpoint() -> void:
	var weak_stats := Stats.uniform(3)
	weak_stats.power = 0
	var strong_stats := Stats.uniform(3)
	strong_stats.power = 10
	var weak := Fixtures.climber_from(weak_stats)
	var strong := Fixtures.climber_from(strong_stats)
	Fixtures.hang(weak, wall, left, right)
	Fixtures.hang(strong, wall, left, right)
	var found := false
	var y := 5.8
	while y > 4.0 and not found:
		var target := Fixtures.hold(wall, &"jug", Vector2(2.2, y))
		var weak_type := Difficulty.evaluate(weak, LEFT, target, wall).type
		var strong_type := Difficulty.evaluate(strong, LEFT, target, wall).type
		found = weak_type == Difficulty.MoveType.DYNO and strong_type == Difficulty.MoveType.DEADPOINT
		y -= 0.02
	assert_true(found, "some hold is a dyno at power 0 but a deadpoint at power 10")


func test_feet_take_weight_off_the_hands() -> void:
	var legless := Fixtures.climber()
	legless.rules.append(Relic.Rule.NO_FEET)
	Fixtures.hang(legless, wall, left, right)
	assert_eq(legless.foot_count(), 0)
	assert_gt(Difficulty.drain_per_second(legless, wall), Difficulty.drain_per_second(climber, wall))


func test_jugs_drain_less_than_crimps() -> void:
	var on_crimps := Fixtures.climber()
	var crimp_left := Fixtures.hold(wall, &"crimp", Vector2(2.2, 6.3))
	var crimp_right := Fixtures.hold(wall, &"crimp", Vector2(2.8, 6.3))
	Fixtures.hang(on_crimps, wall, crimp_left, crimp_right)
	assert_lt(Difficulty.drain_per_second(climber, wall), Difficulty.drain_per_second(on_crimps, wall))


func test_fingers_help_on_crimps() -> void:
	var weak_stats := Stats.uniform(3)
	weak_stats.fingers = 0
	var strong_stats := Stats.uniform(3)
	strong_stats.fingers = 10
	var weak := Fixtures.climber_from(weak_stats)
	var strong := Fixtures.climber_from(strong_stats)
	var crimp_left := Fixtures.hold(wall, &"crimp", Vector2(2.2, 6.3))
	var crimp_right := Fixtures.hold(wall, &"crimp", Vector2(2.8, 6.3))
	Fixtures.hang(weak, wall, crimp_left, crimp_right)
	Fixtures.hang(strong, wall, crimp_left, crimp_right)
	assert_gt(Difficulty.drain_per_second(weak, wall), Difficulty.drain_per_second(strong, wall))


func test_fatigue_makes_moves_cost_more_with_smaller_windows() -> void:
	var probe := Fixtures.probe(wall, climber, LEFT, Difficulty.MoveType.DEADPOINT)
	var fresh := Difficulty.evaluate(climber, LEFT, probe, wall)
	climber.stamina = climber.max_stamina * 0.2
	var tired := Difficulty.evaluate(climber, LEFT, probe, wall)
	assert_gt(tired.stamina_cost, fresh.stamina_cost)
	assert_lt(tired.window, fresh.window)


func test_blocked_moves_say_why() -> void:
	var crimp := Fixtures.hold(wall, &"crimp", Vector2(2.8, 6.3))
	Fixtures.hang(climber, wall, left, crimp)
	assert_eq(Difficulty.evaluate(climber, LEFT, crimp, wall).reason, "other hand is on it")
	assert_eq(Difficulty.evaluate(climber, LEFT, left, wall).reason, "already on it")
	var chip := Fixtures.hold(wall, &"foot_chip", Vector2(2.2, 5.8))
	assert_eq(Difficulty.evaluate(climber, LEFT, chip, wall).reason, "foothold only")
	assert_false(Difficulty.evaluate(climber, LEFT, null, wall).is_possible())


func test_jugs_can_be_matched() -> void:
	var r := Difficulty.evaluate(climber, LEFT, right, wall)
	assert_true(r.is_possible())


func test_dyno_is_caught_by_the_nearer_hand() -> void:
	var probe := Fixtures.probe(wall, climber, RIGHT, Difficulty.MoveType.DYNO)
	assert_not_null(probe)
	var r := Difficulty.evaluate_dyno(climber, probe, wall)
	assert_true(r.is_possible())
	assert_eq(r.limb, RIGHT)
	assert_between(r.power, Tuning.DYNO_POWER_MIN, 1.0)


func test_dyno_power_grows_with_distance() -> void:
	var near := Fixtures.probe(wall, climber, LEFT, Difficulty.MoveType.DYNO)
	var far := Fixtures.hold(wall, &"jug", near.position + Vector2(0.0, -0.2))
	var near_power := Difficulty.evaluate_dyno(climber, near, wall).power
	var far_dyno := Difficulty.evaluate_dyno(climber, far, wall)
	assert_true(far_dyno.is_possible())
	assert_gt(far_dyno.power, near_power)


func test_too_far_to_dyno() -> void:
	var target := Fixtures.hold(wall, &"jug", Vector2(2.2, 3.5))
	assert_eq(Difficulty.evaluate_dyno(climber, target, wall).reason, "too far to dyno")
	assert_eq(Difficulty.evaluate(climber, LEFT, target, wall).type, Difficulty.MoveType.IMPOSSIBLE)


func test_no_feet_cuts_dyno_range() -> void:
	var legless := Fixtures.climber()
	legless.rules.append(Relic.Rule.NO_FEET)
	Fixtures.hang(legless, wall, left, right)
	assert_lt(Difficulty.dyno_jump(legless), Difficulty.dyno_jump(climber))


func test_horizontal_dynos_reach_farther() -> void:
	var up := Difficulty.dyno_jump(climber, Vector2(0.0, -1.0))
	var side := Difficulty.dyno_jump(climber, Vector2(1.0, 0.0))
	assert_gt(side, up)
	assert_almost_eq(side / up, 1.0 + Tuning.DYNO_HORIZONTAL_EXTRA, 0.001)
