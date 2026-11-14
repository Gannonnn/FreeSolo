class_name ClimbSim
extends RefCounted
## Runs one climber on one wall in fixed steps. Inputs are queued and applied at the start of
## the next step, and signals report what happened.

signal grabbed(limb: Climber.Limb, hold: Hold)
signal skill_check_started(check: SkillCheck)
signal skill_check_finished(result: SkillCheck.Result)
signal rest_started(spot: RestSpot)
signal rest_ended
signal fell
signal topped_out
signal message(text: String)

enum InputKind { HAND, SPACE_PRESS, SPACE_RELEASE, REST }


class QueuedInput:
	var kind: InputKind
	var limb: Climber.Limb
	var hold: Hold

	func _init(input_kind: InputKind, input_limb: Climber.Limb, input_hold: Hold) -> void:
		kind = input_kind
		limb = input_limb
		hold = input_hold


## A hand move in progress: a static reach, a deadpoint, or a dyno flight.
class Move:
	var limb: Climber.Limb
	var target: Hold
	## Where the hand was before; it goes back here on a missed deadpoint.
	var origin: Hold
	var result: MoveResult
	## The pose the move ends in.
	var pose: BodySolver.Pose
	## A missed dyno: fall when the flight ends.
	var falls: bool = false


## Smoothly blends the body and limbs from one pose to another.
class Transition:
	var duration: float
	var elapsed: float = 0.0
	var pelvis_from: Vector2
	var pelvis_to: Vector2
	var lean_from: float
	var lean_to: float
	var limbs_from: PackedVector2Array
	var limbs_to: PackedVector2Array

	func weight() -> float:
		var t := clampf(elapsed / duration, 0.0, 1.0)
		return t * t * (3.0 - 2.0 * t)


var wall: Wall
var climber: Climber
var rng: RandomNumberGenerator
var time: float = 0.0
## The active deadpoint dial or dyno meter, else null.
var check: SkillCheck
## The hold the active deadpoint is aiming for, else null.
var check_target: Hold
## The rest spot in use, else null.
var rest: RestSpot
## The foot whose knee is jammed in the active knee-bar, or -1.
var knee_limb: int = -1
## Where each hand and foot is right now, in meters, including moves in progress. Indexed by Limb.
var limb_pos: PackedVector2Array = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])

var _queue: Array[QueuedInput] = []
var _move: Move
var _transition: Transition
var _fall_velocity: Vector2 = Vector2.ZERO


func _init(on_wall: Wall, who: Climber, run_rng: RandomNumberGenerator) -> void:
	wall = on_wall
	climber = who
	rng = run_rng
	_place_at_start()


func queue_hand(limb: Climber.Limb, hold: Hold) -> void:
	_queue.append(QueuedInput.new(InputKind.HAND, limb, hold))


## Space pressed: catches an active deadpoint, otherwise starts charging a dyno.
func queue_space_press() -> void:
	_queue.append(QueuedInput.new(InputKind.SPACE_PRESS, Climber.Limb.LEFT_HAND, null))


## Space released: launches a charging dyno at `target`.
func queue_space_release(target: Hold) -> void:
	_queue.append(QueuedInput.new(InputKind.SPACE_RELEASE, Climber.Limb.LEFT_HAND, target))


## Starts resting at a usable rest spot, or stops resting.
func queue_rest() -> void:
	_queue.append(QueuedInput.new(InputKind.REST, Climber.Limb.LEFT_HAND, null))


func step(dt: float) -> void:
	time += dt
	_apply_inputs()
	if _transition != null:
		_advance_transition(dt)
	match climber.state:
		Climber.State.SKILL_CHECK:
			check.elapsed += dt
			if check.is_past_zone():
				_resolve_deadpoint(SkillCheck.Result.MISS)
		Climber.State.DYNO_CHARGE:
			check.elapsed += dt
		Climber.State.FALLING:
			_advance_fall(dt)
	_update_stamina(dt)
	if _transition == null and climber.state != Climber.State.SKILL_CHECK:
		_place_limbs()


func is_over() -> bool:
	return climber.state == Climber.State.FALLEN or climber.state == Climber.State.TOPPED_OUT


## The nearest rest spot the climber could use from where they are, or null.
func usable_rest() -> RestSpot:
	var best: RestSpot = null
	var best_dist := INF
	for spot: RestSpot in wall.rests:
		if not spot.fits(climber.body):
			continue
		var d := _rest_distance(spot)
		if d < best_dist:
			best = spot
			best_dist = d
	return best


func _apply_inputs() -> void:
	var pending: Array[QueuedInput] = _queue.duplicate()
	_queue.clear()
	for input: QueuedInput in pending:
		if climber.state == Climber.State.MOVING:
			if input.kind == InputKind.HAND:
				_queue.clear()
				_queue.append(input)
			continue
		match input.kind:
			InputKind.HAND:
				_try_hand(input.limb, input.hold)
			InputKind.SPACE_PRESS:
				_space_press()
			InputKind.SPACE_RELEASE:
				_space_release(input.hold)
			InputKind.REST:
				_toggle_rest()


func _can_act() -> bool:
	return climber.state == Climber.State.CLIMBING or climber.state == Climber.State.RESTING


func _place_at_start() -> void:
	var start: Array[Hold] = [null, null, null, null]
	start[Climber.Limb.LEFT_HAND] = wall.start_holds[0]
	start[Climber.Limb.RIGHT_HAND] = wall.start_holds[1]
	BodySolver.apply(climber, BodySolver.settle(climber, wall, start))
	climber.state = Climber.State.CLIMBING
	_place_limbs()


func _try_hand(limb: Climber.Limb, hold: Hold) -> void:
	if not _can_act():
		return
	var r := Difficulty.evaluate(climber, limb, hold, wall)
	match r.type:
		Difficulty.MoveType.STATIC:
			_begin_static(r, hold)
		Difficulty.MoveType.DEADPOINT:
			_begin_deadpoint(r, hold)
		Difficulty.MoveType.DYNO:
			message.emit("Too far: hold Space to dyno")
		_:
			message.emit(r.reason.capitalize())


func _new_move(r: MoveResult, target: Hold) -> Move:
	var move := Move.new()
	move.limb = r.limb
	move.target = target
	move.origin = climber.contacts[r.limb]
	move.result = r
	return move


func _begin_static(r: MoveResult, hold: Hold) -> void:
	_end_rest(false)
	var move := _new_move(r, hold)
	var after: Array[Hold] = climber.contacts.duplicate()
	after[r.limb] = hold
	move.pose = BodySolver.settle(climber, wall, after)
	climber.stamina -= r.stamina_cost
	climber.contacts[r.limb] = null
	_move = move
	var travel := limb_pos[r.limb].distance_to(hold.position)
	_transition_to(move.pose, Tuning.STATIC_MOVE_TIME + Tuning.STATIC_MOVE_TIME_PER_METER * travel)
	climber.state = Climber.State.MOVING


func _begin_deadpoint(r: MoveResult, hold: Hold) -> void:
	_end_rest(false)
	_move = _new_move(r, hold)
	check = SkillCheck.deadpoint(r.window, rng)
	check_target = hold
	var lunge := BodySolver.Pose.new()
	lunge.pelvis = Difficulty.reach_pelvis(climber, r.limb, hold.position)
	lunge.lean = climber.lean
	climber.contacts[r.limb] = null
	lunge.contacts = climber.contacts.duplicate()
	var shoulder := lunge.pelvis + climber.root_offset(r.limb, climber.lean)
	var hand_end := IK.reach_point(shoulder, hold.position, climber.body.arm_length())
	_transition_to(lunge, check.zone_start * check.duration, r.limb, hand_end)
	climber.state = Climber.State.SKILL_CHECK
	skill_check_started.emit(check)


func _resolve_deadpoint(result: SkillCheck.Result) -> void:
	var move := _move
	check = null
	check_target = null
	skill_check_finished.emit(result)
	var after: Array[Hold] = climber.contacts.duplicate()
	if result == SkillCheck.Result.MISS:
		climber.stamina -= move.result.stamina_cost + Tuning.MISSED_DEADPOINT_PENALTY
		after[move.limb] = move.origin
		message.emit("Missed the deadpoint")
	else:
		var cost := move.result.stamina_cost
		if result == SkillCheck.Result.GREAT:
			cost *= Tuning.GREAT_COST
			message.emit("Great catch!")
		climber.stamina -= cost
		after[move.limb] = move.target
	move.pose = BodySolver.settle(climber, wall, after)
	_transition_to(move.pose, Tuning.CATCH_TIME)
	climber.state = Climber.State.MOVING


func _space_press() -> void:
	match climber.state:
		Climber.State.SKILL_CHECK:
			_resolve_deadpoint(check.judge_dial())
		Climber.State.CLIMBING, Climber.State.RESTING:
			if climber.hand_count() == 0:
				return
			_end_rest(false)
			check = SkillCheck.dyno_meter()
			climber.state = Climber.State.DYNO_CHARGE


func _space_release(target: Hold) -> void:
	if climber.state != Climber.State.DYNO_CHARGE:
		return
	var charge := check.meter()
	check = null
	climber.state = Climber.State.CLIMBING
	if charge < Tuning.DYNO_MIN_CHARGE:
		return
	if target == null:
		message.emit("Point at a hold to dyno")
		return
	var r := Difficulty.evaluate_dyno(climber, target, wall)
	if not r.is_possible():
		message.emit(r.reason.capitalize())
		return
	var result := SkillCheck.judge_band(charge, r.power, r.window)
	skill_check_finished.emit(result)
	var move := _new_move(r, target)
	var cost := r.stamina_cost
	if result == SkillCheck.Result.GREAT:
		cost *= Tuning.GREAT_COST
	climber.stamina -= cost
	var hand_end := target.position
	if result == SkillCheck.Result.MISS:
		move.falls = true
		var flight := BodySolver.Pose.new()
		flight.contacts = [null, null, null, null]
		flight.pelvis = climber.pelvis.lerp(Difficulty.reach_pelvis(climber, r.limb, target.position), 0.6)
		flight.lean = climber.lean
		move.pose = flight
		var shoulder := flight.pelvis + climber.root_offset(r.limb, climber.lean)
		hand_end = IK.reach_point(shoulder, target.position, climber.body.arm_length() * 0.9)
		message.emit("Missed the dyno!")
	else:
		var after: Array[Hold] = [null, null, null, null]
		after[r.limb] = target
		move.pose = BodySolver.settle(climber, wall, after)
	var empty: Array[Hold] = [null, null, null, null]
	climber.contacts = empty
	_move = move
	_transition_to(move.pose, Tuning.DYNO_FLIGHT_TIME, r.limb, hand_end)
	climber.state = Climber.State.MOVING


func _toggle_rest() -> void:
	if climber.state == Climber.State.RESTING:
		_end_rest(true)
		return
	if climber.state != Climber.State.CLIMBING:
		return
	var spot := usable_rest()
	if spot == null:
		message.emit("No rest here. Find a knee-bar")
		return
	_begin_rest(spot)


## Distance from the nearest hip to the rest spot, or INF if it's out of reach.
func _rest_distance(spot: RestSpot) -> float:
	var best := INF
	for foot: Climber.Limb in Climber.FEET:
		var hip := climber.root_position(foot)
		if spot.kind == RestSpot.Kind.KNEEBAR:
			var d := hip.distance_to(spot.position)
			if d <= climber.body.thigh * Tuning.KNEEBAR_HIP_REACH:
				best = minf(best, d)
		else:
			var to_ledge := spot.foot_hold.position
			var d := hip.distance_to(to_ledge)
			if d <= climber.body.leg_length() * Tuning.FOOT_REACH and to_ledge.y >= climber.pelvis.y - Tuning.FOOT_HIGH_STEP:
				best = minf(best, d)
	return best


func _begin_rest(spot: RestSpot) -> void:
	rest = spot
	var pose := BodySolver.Pose.new()
	pose.contacts = climber.contacts.duplicate()
	if spot.kind == RestSpot.Kind.KNEEBAR:
		knee_limb = _nearest_foot(spot.position)
		var other_foot := Climber.Limb.RIGHT_FOOT if knee_limb == Climber.Limb.LEFT_FOOT else Climber.Limb.LEFT_FOOT
		if pose.contacts[other_foot] == spot.foot_hold:
			pose.contacts[other_foot] = null
		pose.contacts[knee_limb] = spot.foot_hold
	else:
		pose.contacts[Climber.Limb.LEFT_FOOT] = spot.foot_hold
		pose.contacts[Climber.Limb.RIGHT_FOOT] = spot.foot_hold
	pose.lean = BodySolver.lean_for(pose.contacts)
	pose.pelvis = BodySolver.pelvis_for(climber, pose.contacts, pose.lean, knee_limb, spot.position)
	climber.contacts = pose.contacts.duplicate()
	_transition_to(pose, Tuning.REST_SETTLE_TIME)
	climber.state = Climber.State.RESTING
	rest_started.emit(spot)


## Leaves a rest. With `repose`, the body settles back into a normal stance; otherwise the
## move that ended the rest does that.
func _end_rest(repose: bool) -> void:
	if climber.state != Climber.State.RESTING:
		return
	rest = null
	knee_limb = -1
	climber.state = Climber.State.CLIMBING
	rest_ended.emit()
	if repose:
		var pose := BodySolver.settle(climber, wall, climber.contacts)
		climber.contacts = pose.contacts.duplicate()
		_transition_to(pose, Tuning.REST_SETTLE_TIME)


func _nearest_foot(point: Vector2) -> Climber.Limb:
	var left := climber.root_position(Climber.Limb.LEFT_FOOT).distance_to(point)
	var right := climber.root_position(Climber.Limb.RIGHT_FOOT).distance_to(point)
	return Climber.Limb.LEFT_FOOT if left <= right else Climber.Limb.RIGHT_FOOT


func _update_stamina(dt: float) -> void:
	match climber.state:
		Climber.State.FALLING, Climber.State.FALLEN, Climber.State.TOPPED_OUT:
			return
		Climber.State.RESTING:
			var ceiling := rest.ceiling() * climber.max_stamina
			if climber.stamina < ceiling:
				climber.stamina = minf(ceiling, climber.stamina + rest.rate(climber.stats) * dt)
			return
	climber.stamina -= Difficulty.drain_per_second(climber, wall) * dt
	if climber.stamina <= 0.0:
		climber.stamina = 0.0
		message.emit("Pumped out!")
		_start_fall(Vector2.ZERO)


func _start_fall(velocity: Vector2) -> void:
	var empty: Array[Hold] = [null, null, null, null]
	climber.contacts = empty
	check = null
	check_target = null
	rest = null
	knee_limb = -1
	_move = null
	_transition = null
	_fall_velocity = velocity
	climber.state = Climber.State.FALLING
	fell.emit()


func _advance_fall(dt: float) -> void:
	_fall_velocity.y += Tuning.GRAVITY * dt
	climber.pelvis += _fall_velocity * dt
	var standing := wall.ground_y() - climber.body.leg_length() * 0.9
	if climber.pelvis.y >= standing:
		climber.pelvis.y = standing
		climber.state = Climber.State.FALLEN


func _finish_move() -> void:
	var move := _move
	_move = null
	if move.falls:
		_start_fall((move.target.position - climber.pelvis).normalized() * 0.8)
		return
	BodySolver.apply(climber, move.pose)
	climber.state = Climber.State.CLIMBING
	var landed := climber.contacts[move.limb]
	if landed != null:
		grabbed.emit(move.limb, landed)
	_check_top_out()


func _check_top_out() -> void:
	for hand: Climber.Limb in Climber.HANDS:
		var hold := climber.contacts[hand]
		if hold == null or hold.position.y > wall.top_out_y:
			return
	climber.state = Climber.State.TOPPED_OUT
	topped_out.emit()


func _transition_to(pose: BodySolver.Pose, duration: float, override_limb: int = -1, override_at: Vector2 = Vector2.ZERO) -> void:
	var t := Transition.new()
	t.duration = maxf(duration, Tuning.STEP)
	t.pelvis_from = climber.pelvis
	t.lean_from = climber.lean
	t.limbs_from = limb_pos.duplicate()
	t.pelvis_to = pose.pelvis
	t.lean_to = pose.lean
	t.limbs_to = PackedVector2Array()
	for limb: Climber.Limb in Climber.LIMBS:
		t.limbs_to.append(_limb_end(limb, pose.contacts, pose.pelvis, pose.lean))
	if override_limb >= 0:
		t.limbs_to[override_limb] = override_at
	_transition = t


func _advance_transition(dt: float) -> void:
	var t := _transition
	t.elapsed += dt
	var w := t.weight()
	climber.pelvis = t.pelvis_from.lerp(t.pelvis_to, w)
	climber.lean = lerpf(t.lean_from, t.lean_to, w)
	for i: int in limb_pos.size():
		limb_pos[i] = t.limbs_from[i].lerp(t.limbs_to[i], w)
	if t.elapsed >= t.duration:
		_transition = null
		if climber.state == Climber.State.MOVING:
			_finish_move()


func _place_limbs() -> void:
	for limb: Climber.Limb in Climber.LIMBS:
		limb_pos[limb] = _limb_end(limb, climber.contacts, climber.pelvis, climber.lean)


## Where a hand or foot ends up: on its hold, or hanging loose from its shoulder or hip.
func _limb_end(limb: Climber.Limb, contacts: Array[Hold], pelvis: Vector2, lean: float) -> Vector2:
	var hold := contacts[limb]
	if hold != null:
		return hold.position
	var root := pelvis + climber.root_offset(limb, lean)
	var side := Climber.side_sign(limb)
	var falling := climber.state == Climber.State.FALLING
	if Climber.is_hand(limb):
		var arm_dir := Vector2(side * 0.5, -0.8) if falling else Vector2(side * 0.25, 0.95)
		return root + arm_dir.normalized() * climber.body.arm_length() * 0.95
	return root + Vector2(side * 0.15, 0.95).normalized() * climber.body.leg_length() * 0.95
