extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")
const LEFT := Climber.Limb.LEFT_HAND
const RIGHT := Climber.Limb.RIGHT_HAND


func _basic_sim(seed_value: int = 1) -> ClimbSim:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return ClimbSim.new(TestWalls.basic(), Fixtures.climber(), rng)


func _run(sim: ClimbSim, seconds: float) -> void:
	for i: int in roundi(seconds / Tuning.STEP):
		sim.step(Tuning.STEP)


## Steps until the current move, deadpoint or dyno flight has finished.
func _settle(sim: ClimbSim) -> void:
	for i: int in 600:
		var state := sim.climber.state
		if state != Climber.State.MOVING and state != Climber.State.SKILL_CHECK:
			return
		sim.step(Tuning.STEP)


## Waits for the deadpoint needle to reach `share` of the way through the zone, then presses Space.
func _press_at(sim: ClimbSim, share: float) -> void:
	var check := sim.check
	var at := check.zone_start + check.zone_size * share
	var half_step := Tuning.STEP / check.duration * 0.5
	while sim.check == check and check.needle() + half_step < at:
		sim.step(Tuning.STEP)
	sim.queue_space_press()
	sim.step(Tuning.STEP)


## Holds Space until the dyno meter reaches `level`.
func _charge_to(sim: ClimbSim, level: float) -> void:
	var half_step := Tuning.STEP / sim.check.duration * 0.5
	while sim.check.meter() + half_step < level:
		sim.step(Tuning.STEP)


func test_starts_on_the_start_holds_with_feet_on() -> void:
	var sim := _basic_sim()
	assert_eq(sim.climber.contacts[LEFT], sim.wall.start_holds[0])
	assert_eq(sim.climber.contacts[RIGHT], sim.wall.start_holds[1])
	assert_eq(sim.climber.foot_count(), 2)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)


func test_hanging_drains_stamina() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var before := sim.climber.stamina
	_run(sim, 1.0)
	assert_lt(sim.climber.stamina, before)


func test_static_move_grabs_the_hold_and_costs_stamina() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var target := Fixtures.hold(sim.wall, &"jug", Vector2(2.2, 5.75))
	var r := Difficulty.evaluate(sim.climber, LEFT, target, sim.wall)
	assert_eq(r.type, Difficulty.MoveType.STATIC)
	var before := sim.climber.stamina
	watch_signals(sim)
	sim.queue_hand(LEFT, target)
	sim.step(Tuning.STEP)
	assert_eq(sim.climber.state, Climber.State.MOVING)
	_settle(sim)
	assert_eq(sim.climber.contacts[LEFT], target)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)
	assert_signal_emitted(sim, "grabbed")
	assert_true(sim.climber.stamina <= before - r.stamina_cost, "the move cost was paid")


func test_out_of_reach_click_does_nothing() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var far := Fixtures.hold(sim.wall, &"jug", Vector2(2.2, 3.0))
	watch_signals(sim)
	sim.queue_hand(LEFT, far)
	sim.step(Tuning.STEP)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)
	assert_signal_emitted(sim, "message")
	assert_eq(sim.climber.contacts[LEFT], sim.wall.start_holds[0])


func test_deadpoint_caught_in_the_zone_grabs_the_hold() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DEADPOINT)
	sim.queue_hand(LEFT, target)
	sim.step(Tuning.STEP)
	assert_eq(sim.climber.state, Climber.State.SKILL_CHECK)
	assert_eq(sim.check_target, target)
	watch_signals(sim)
	_press_at(sim, 0.6)
	assert_signal_emitted_with_parameters(sim, "skill_check_finished", [SkillCheck.Result.GOOD])
	_settle(sim)
	assert_eq(sim.climber.contacts[LEFT], target)


func test_great_catch_costs_less() -> void:
	var good := Fixtures.sim_on(Fixtures.wall(), 7)
	var great := Fixtures.sim_on(Fixtures.wall(), 7)
	var targets: Array[Hold] = []
	for sim: ClimbSim in [good, great]:
		var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DEADPOINT)
		targets.append(target)
		sim.queue_hand(LEFT, target)
		sim.step(Tuning.STEP)
	watch_signals(good)
	watch_signals(great)
	_press_at(good, 0.7)
	_press_at(great, 0.1)
	for sim: ClimbSim in [good, great]:
		while sim.time < 2.0:
			sim.step(Tuning.STEP)
	assert_signal_emitted_with_parameters(good, "skill_check_finished", [SkillCheck.Result.GOOD])
	assert_signal_emitted_with_parameters(great, "skill_check_finished", [SkillCheck.Result.GREAT])
	assert_eq(good.climber.contacts[LEFT], targets[0])
	assert_eq(great.climber.contacts[LEFT], targets[1])
	assert_gt(great.climber.stamina, good.climber.stamina)


func test_missed_deadpoint_costs_stamina_and_the_hand_goes_back() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var origin := sim.climber.contacts[LEFT]
	var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DEADPOINT)
	var r := Difficulty.evaluate(sim.climber, LEFT, target, sim.wall)
	var before := sim.climber.stamina
	sim.queue_hand(LEFT, target)
	sim.step(Tuning.STEP)
	sim.queue_space_press()
	sim.step(Tuning.STEP)
	_settle(sim)
	assert_eq(sim.climber.state, Climber.State.CLIMBING, "a missed deadpoint is not a fall")
	assert_eq(sim.climber.contacts[LEFT], origin)
	assert_true(sim.climber.stamina <= before - r.stamina_cost - Tuning.MISSED_DEADPOINT_PENALTY)


func test_deadpoint_with_no_press_misses() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var origin := sim.climber.contacts[LEFT]
	var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DEADPOINT)
	watch_signals(sim)
	sim.queue_hand(LEFT, target)
	_run(sim, 2.0)
	assert_signal_emitted_with_parameters(sim, "skill_check_finished", [SkillCheck.Result.MISS])
	assert_eq(sim.climber.contacts[LEFT], origin)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)


func test_dyno_released_in_the_band_is_caught_one_handed() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DYNO)
	var r := Difficulty.evaluate_dyno(sim.climber, target, sim.wall)
	sim.queue_space_press()
	sim.step(Tuning.STEP)
	assert_eq(sim.climber.state, Climber.State.DYNO_CHARGE)
	_charge_to(sim, r.power)
	sim.queue_space_release(target)
	sim.step(Tuning.STEP)
	_settle(sim)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)
	assert_eq(sim.climber.contacts[r.limb], target)
	assert_null(sim.climber.contacts[Climber.other_hand(r.limb)])


func test_missed_dyno_falls() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var near := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DYNO)
	var target := Fixtures.hold(sim.wall, &"jug", near.position + Vector2(0.0, -0.25))
	var r := Difficulty.evaluate_dyno(sim.climber, target, sim.wall)
	var low_charge := Tuning.DYNO_MIN_CHARGE + 0.03
	assert_lt(low_charge, r.power - r.window * 0.5, "the test charge is below the band")
	watch_signals(sim)
	sim.queue_space_press()
	sim.step(Tuning.STEP)
	_charge_to(sim, low_charge)
	sim.queue_space_release(target)
	_run(sim, 4.0)
	assert_signal_emitted(sim, "fell")
	assert_eq(sim.climber.state, Climber.State.FALLEN)


func test_tapping_space_does_not_dyno() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DYNO)
	sim.queue_space_press()
	sim.step(Tuning.STEP)
	sim.queue_space_release(target)
	sim.step(Tuning.STEP)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)
	assert_eq(sim.climber.hand_count(), 2)


func test_running_out_of_stamina_falls() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	watch_signals(sim)
	sim.climber.stamina = 0.05
	_run(sim, 4.0)
	assert_signal_emitted(sim, "fell")
	assert_eq(sim.climber.state, Climber.State.FALLEN)
	assert_true(sim.is_over())


func test_kneebar_refills_to_80_percent() -> void:
	var w := Fixtures.wall()
	var foot := Fixtures.hold(w, &"foot_chip", Vector2(2.62, 7.3))
	w.add_rest(RestSpot.kneebar(Vector2(2.62, 6.86), foot))
	var sim := Fixtures.sim_on(w)
	assert_not_null(sim.usable_rest())
	sim.climber.stamina = 20.0
	sim.queue_rest()
	_run(sim, 10.0)
	assert_eq(sim.climber.state, Climber.State.RESTING)
	assert_almost_eq(sim.climber.stamina, sim.climber.max_stamina * Tuning.KNEEBAR_CEILING, 0.01)


func test_kneebar_that_does_not_fit_the_shin_is_not_usable() -> void:
	var w := Fixtures.wall()
	var foot := Fixtures.hold(w, &"foot_chip", Vector2(2.62, 7.6))
	w.add_rest(RestSpot.kneebar(Vector2(2.62, 6.86), foot))
	var sim := Fixtures.sim_on(w)
	assert_null(sim.usable_rest())


func test_ledge_refills_to_full() -> void:
	var w := Fixtures.wall()
	var ledge := Fixtures.hold(w, &"ledge", Vector2(2.5, 7.45))
	w.add_rest(RestSpot.ledge(ledge))
	var sim := Fixtures.sim_on(w)
	sim.climber.stamina = 20.0
	sim.queue_rest()
	_run(sim, 10.0)
	assert_eq(sim.climber.state, Climber.State.RESTING)
	assert_almost_eq(sim.climber.stamina, sim.climber.max_stamina, 0.01)


func test_jugs_do_not_refill() -> void:
	var sim := Fixtures.sim_on(Fixtures.wall())
	watch_signals(sim)
	sim.climber.stamina = 50.0
	sim.queue_rest()
	_run(sim, 2.0)
	assert_signal_emitted(sim, "message")
	assert_eq(sim.climber.state, Climber.State.CLIMBING)
	assert_lt(sim.climber.stamina, 50.0)


func test_a_move_ends_the_rest() -> void:
	var w := Fixtures.wall()
	var ledge := Fixtures.hold(w, &"ledge", Vector2(2.5, 7.45))
	w.add_rest(RestSpot.ledge(ledge))
	var sim := Fixtures.sim_on(w)
	sim.queue_rest()
	_run(sim, 1.0)
	var target := Fixtures.hold(w, &"jug", Vector2(2.2, 5.8))
	sim.queue_hand(LEFT, target)
	sim.step(Tuning.STEP)
	_settle(sim)
	assert_null(sim.rest)
	assert_eq(sim.climber.contacts[LEFT], target)


func test_both_hands_above_the_top_line_tops_out() -> void:
	var w := Fixtures.wall()
	w.top_out_y = 5.85
	var sim := Fixtures.sim_on(w)
	var left := Fixtures.hold(w, &"jug", Vector2(2.2, 5.8))
	var right := Fixtures.hold(w, &"jug", Vector2(2.8, 5.8))
	watch_signals(sim)
	sim.queue_hand(LEFT, left)
	sim.step(Tuning.STEP)
	_settle(sim)
	assert_eq(sim.climber.state, Climber.State.CLIMBING)
	sim.queue_hand(RIGHT, right)
	sim.step(Tuning.STEP)
	_settle(sim)
	assert_eq(sim.climber.state, Climber.State.TOPPED_OUT)
	assert_signal_emitted(sim, "topped_out")


# A simple, careful climber: take the static move that gains the most height, deadpoint only when
# no static move gains any, never dyno, and rest when a rest is in reach and stamina is low.
# Deadpoints are pressed `press_share` into the zone, or 0.6 s after the dial starts when
# `press_share` is negative (which hits or misses depending on where the seed put the zone).
func _auto_climb(sim: ClimbSim, press_share: float, trace: PackedStringArray) -> void:
	for move_count: int in 80:
		if sim.is_over() or sim.climber.state == Climber.State.FALLING:
			return
		var c := sim.climber
		if c.stamina < c.max_stamina * 0.5 and sim.usable_rest() != null:
			sim.queue_rest()
			_run(sim, 6.0)
			trace.append("rested to %.3f" % c.stamina)
		var next := _best_move(sim)
		if next.is_empty():
			trace.append("stuck at stamina %.3f" % c.stamina)
			return
		var limb: Climber.Limb = next[0]
		var hold: Hold = next[1]
		var planned := Difficulty.evaluate(c, limb, hold, sim.wall)
		sim.queue_hand(limb, hold)
		sim.step(Tuning.STEP)
		if c.state == Climber.State.SKILL_CHECK:
			if press_share >= 0.0:
				_press_at(sim, press_share)
			else:
				_run(sim, 0.6)
				if c.state == Climber.State.SKILL_CHECK:
					sim.queue_space_press()
					sim.step(Tuning.STEP)
		_settle(sim)
		var ids := PackedStringArray()
		for held: Hold in c.contacts:
			ids.append(str(held.id) if held != null else "-")
		var kind := "static" if planned.type == Difficulty.MoveType.STATIC else "deadpoint"
		trace.append("%d %s -> %d (%s, cost %.2f): holds %s, stamina %.3f at %.1f s" % [
			move_count, "L" if limb == LEFT else "R", hold.id, kind, planned.stamina_cost, " ".join(ids), c.stamina, sim.time])


## [limb, hold] for the static move that raises the highest hand the most (ties go to the lower
## hand catching up), else the same for deadpoints. Empty if neither gains height.
func _best_move(sim: ClimbSim) -> Array:
	var c := sim.climber
	if c.hand_count() < 2:
		return []
	var top_y := minf(c.contacts[LEFT].position.y, c.contacts[RIGHT].position.y)
	for wanted: Difficulty.MoveType in [Difficulty.MoveType.STATIC, Difficulty.MoveType.DEADPOINT]:
		var best: Array = []
		var best_score := -INF
		for limb: Climber.Limb in Climber.HANDS:
			var from_y := c.contacts[limb].position.y
			for hold: Hold in sim.wall.holds_near(c.root_position(limb), 1.6):
				if not hold.is_handhold() or from_y - hold.position.y < 0.1:
					continue
				var r := Difficulty.evaluate(c, limb, hold, sim.wall)
				if r.type != wanted:
					continue
				var score := (top_y - hold.position.y) + 0.5 * (from_y - top_y) - 0.01 * r.stamina_cost
				if score > best_score:
					best = [limb, hold]
					best_score = score
		if not best.is_empty():
			return best
	return []


func test_basic_wall_can_be_topped_out() -> void:
	var sim := _basic_sim()
	var trace := PackedStringArray()
	_auto_climb(sim, 0.5, trace)
	assert_eq(sim.climber.state, Climber.State.TOPPED_OUT, "\n".join(trace))


func test_same_seed_and_inputs_replay_exactly() -> void:
	var first := PackedStringArray()
	var second := PackedStringArray()
	_auto_climb(_basic_sim(42), -1.0, first)
	_auto_climb(_basic_sim(42), -1.0, second)
	assert_gt(first.size(), 3)
	assert_eq("\n".join(first), "\n".join(second))


func test_seed_decides_where_the_deadpoint_zone_is() -> void:
	var zones: Array[float] = []
	for seed_value: int in [1, 2]:
		var sim := Fixtures.sim_on(Fixtures.wall(), seed_value)
		var target := Fixtures.probe(sim.wall, sim.climber, LEFT, Difficulty.MoveType.DEADPOINT)
		sim.queue_hand(LEFT, target)
		sim.step(Tuning.STEP)
		zones.append(sim.check.zone_start)
	assert_ne(zones[0], zones[1])
	var again := Fixtures.sim_on(Fixtures.wall(), 1)
	var probe := Fixtures.probe(again.wall, again.climber, LEFT, Difficulty.MoveType.DEADPOINT)
	again.queue_hand(LEFT, probe)
	again.step(Tuning.STEP)
	assert_eq(again.check.zone_start, zones[0])
