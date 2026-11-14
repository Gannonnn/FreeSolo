class_name RouteFinder
extends RefCounted
## A careful test climber that plays a real ClimbSim. Before each move it hangs for a moment, like
## a player looking for the next hold. It rests whenever it's low and a rest is in reach, takes the
## static move that gains the most height, deadpoints only when no static move gains any (always
## catching them), and never dynos. WallGen uses it to prove a wall can be climbed, passing
## callbacks that add a hold or a rest wherever it gets stuck.

## Moves before giving up.
const MAX_MOVES: int = 500
## Meters around each shoulder searched for the next hold.
const SEARCH_RADIUS: float = 1.6
## A move must raise the moving hand at least this many meters.
const MIN_GAIN: float = 0.1
## Score bonus per point of grip on the target, so the climber prefers good holds a little.
const GRIP_PREFERENCE: float = 0.1
## Seconds spent on one rest before giving up on reaching its ceiling.
const MAX_REST_TIME: float = 30.0


class Result:
	var topped_out: bool = false
	## Why the climb stopped short, else "".
	var failure: String = ""
	## Holds the hands used, in order, starting with the two start holds.
	var holds: Array[Hold] = []
	## Footholds stood on, each listed once.
	var feet: Array[Hold] = []
	var moves: int = 0
	var deadpoints: int = 0
	var rests: int = 0
	## Holds and rests the callbacks added along the way.
	var repairs: int = 0
	## Sim seconds the climb took.
	var seconds: float = 0.0
	## Lowest stamina share seen after a move.
	var lowest_stamina: float = 1.0
	## Meters above the ground the highest hand hold sits.
	var high_point: float = 0.0

	func summary() -> String:
		var outcome := "topped out" if topped_out else failure
		return "%s: %d moves (%d deadpoints), %d rests, %d repairs, lowest stamina %d%%, high point %.1f m, %.0f s" % [
			outcome, moves, deadpoints, rests, repairs, roundi(lowest_stamina * 100.0), high_point, seconds]


## Climbs `wall` with `climber`. `add_hold` and `add_rest` take the ClimbSim and return true if
## they changed the wall; leave them empty to climb the wall as it is.
static func climb(wall: Wall, climber: Climber, rng: RandomNumberGenerator, add_hold: Callable = Callable(), add_rest: Callable = Callable()) -> Result:
	var result := Result.new()
	var sim := ClimbSim.new(wall, climber, rng)
	result.holds.append_array(wall.start_holds)
	_note_feet(sim, result)
	for i: int in MAX_MOVES:
		_run(sim, Tuning.GUIDE_THINK_TIME)
		if sim.climber.state != Climber.State.CLIMBING:
			result.failure = "pumped out"
			break
		if sim.climber.stamina < sim.climber.max_stamina * Tuning.GUIDE_REST_BELOW:
			if sim.usable_rest() == null and add_rest.is_valid() and add_rest.call(sim):
				result.repairs += 1
			if sim.usable_rest() != null:
				_rest(sim)
				result.rests += 1
		var next := best_move(sim)
		if next.is_empty() and add_hold.is_valid() and add_hold.call(sim):
			result.repairs += 1
			next = best_move(sim)
		if next.is_empty():
			result.failure = "stuck"
			break
		var limb: Climber.Limb = next[0]
		var hold: Hold = next[1]
		sim.queue_hand(limb, hold)
		sim.step(Tuning.STEP)
		if sim.climber.state == Climber.State.SKILL_CHECK:
			result.deadpoints += 1
			_catch(sim)
		_settle(sim)
		var state := sim.climber.state
		if state == Climber.State.FALLING or state == Climber.State.FALLEN:
			result.failure = "fell"
			break
		result.moves += 1
		result.holds.append(hold)
		_note_feet(sim, result)
		result.lowest_stamina = minf(result.lowest_stamina, sim.climber.stamina / sim.climber.max_stamina)
		result.high_point = maxf(result.high_point, wall.ground_y() - hold.position.y)
		if state == Climber.State.TOPPED_OUT:
			result.topped_out = true
			break
	if not result.topped_out and result.failure == "":
		result.failure = "too many moves"
	result.seconds = sim.time
	return result


## [limb, hold] for the static move that raises the highest hand the most (ties go to the lower
## hand catching up, then to better holds), else the same for deadpoints. Empty if neither gains
## height.
static func best_move(sim: ClimbSim) -> Array:
	var c := sim.climber
	if c.hand_count() < 2:
		return []
	var top_y := minf(c.contacts[Climber.Limb.LEFT_HAND].position.y, c.contacts[Climber.Limb.RIGHT_HAND].position.y)
	for wanted: Difficulty.MoveType in [Difficulty.MoveType.STATIC, Difficulty.MoveType.DEADPOINT]:
		var best: Array = []
		var best_score := -INF
		for limb: Climber.Limb in Climber.HANDS:
			var from_y := c.contacts[limb].position.y
			for hold: Hold in sim.wall.holds_near(c.root_position(limb), SEARCH_RADIUS):
				if not hold.is_handhold() or from_y - hold.position.y < MIN_GAIN:
					continue
				var r := Difficulty.evaluate(c, limb, hold, sim.wall)
				if r.type != wanted:
					continue
				var score := (top_y - hold.position.y) + 0.5 * (from_y - top_y) + GRIP_PREFERENCE * r.grip - 0.01 * r.stamina_cost
				if score > best_score:
					best = [limb, hold]
					best_score = score
		if not best.is_empty():
			return best
	return []


static func _run(sim: ClimbSim, seconds: float) -> void:
	for i: int in roundi(seconds / Tuning.STEP):
		sim.step(Tuning.STEP)


## Steps until the current move, deadpoint or catch has finished.
static func _settle(sim: ClimbSim) -> void:
	for i: int in 600:
		var state := sim.climber.state
		if state != Climber.State.MOVING and state != Climber.State.SKILL_CHECK:
			return
		sim.step(Tuning.STEP)


## Presses Space when the deadpoint needle is 40% of the way through the zone.
static func _catch(sim: ClimbSim) -> void:
	var check := sim.check
	var at := check.zone_start + check.zone_size * 0.4
	var half_step := Tuning.STEP / check.duration * 0.5
	while sim.check == check and check.needle() + half_step < at:
		sim.step(Tuning.STEP)
	sim.queue_space_press()
	sim.step(Tuning.STEP)


## Rests until the rest's ceiling, then leaves it and lets the body settle.
static func _rest(sim: ClimbSim) -> void:
	sim.queue_rest()
	sim.step(Tuning.STEP)
	if sim.rest == null:
		return
	var target := sim.rest.ceiling() * sim.climber.max_stamina - 0.5
	var waited := 0.0
	while sim.climber.state == Climber.State.RESTING and sim.climber.stamina < target and waited < MAX_REST_TIME:
		sim.step(Tuning.STEP)
		waited += Tuning.STEP
	if sim.climber.state == Climber.State.RESTING:
		sim.queue_rest()
		sim.step(Tuning.STEP)
	_run(sim, Tuning.REST_SETTLE_TIME + 0.05)


static func _note_feet(sim: ClimbSim, result: Result) -> void:
	for foot: Climber.Limb in Climber.FEET:
		var hold := sim.climber.contacts[foot]
		if hold != null and not result.feet.has(hold):
			result.feet.append(hold)
