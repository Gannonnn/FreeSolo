class_name Difficulty
extends RefCounted
## The move difficulty model, the most important function in the game.
## Pure and deterministic. The boss AI will call evaluate() thousands of times, so keep it cheap.

enum MoveType { IMPOSSIBLE, STATIC, DEADPOINT, DYNO }

## Wall angle (radians) treated as "fully steep" when scaling angle effects: 45°.
const STEEP_REFERENCE: float = PI / 4.0
## Meters. reach_pelvis() converges to exactly static reach, which float error can overshoot.
const REACH_EPSILON: float = 0.001


## Whether `limb` (a hand) can move to `target` from where the climber is now, how, and at what cost.
## Reads body position, feet, stats and fatigue from the climber, hold type and rotation from the
## target, and the wall angle at the target from the wall.
static func evaluate(climber: Climber, limb: Climber.Limb, target: Hold, wall: Wall) -> MoveResult:
	var r := MoveResult.new()
	r.limb = limb
	r.reason = _blocked_reason(climber, limb, target)
	if r.reason != "":
		return r
	var arm := climber.body.arm_length()
	var reach := arm * Tuning.STATIC_EXTENSION
	var shoulder := reach_pelvis(climber, limb, target.position) + climber.root_offset(limb, climber.lean)
	var dist := shoulder.distance_to(target.position)
	r.excess = maxf(0.0, dist - reach)
	if r.excess <= REACH_EPSILON:
		r.excess = 0.0
	r.reach_ratio = dist / arm
	var dp_extra := deadpoint_extra(climber.stats)
	var jump := dyno_jump(climber, target.position - shoulder)
	if r.excess <= 0.0:
		r.type = MoveType.STATIC
	elif r.excess <= dp_extra:
		r.type = MoveType.DEADPOINT
	elif r.excess <= jump:
		r.type = MoveType.DYNO
	else:
		r.reason = "out of reach"
		return r
	_price(r, climber, target, wall, shoulder, dp_extra, jump)
	return r


## A dyno toward `target`. Both hands let go; the one that ends up nearer the hold catches it.
static func evaluate_dyno(climber: Climber, target: Hold, wall: Wall) -> MoveResult:
	var r := MoveResult.new()
	if target == null or not target.is_handhold():
		r.reason = "not a handhold"
		return r
	if climber.hand_count() == 0:
		r.reason = "no hands on"
		return r
	for hand: Climber.Limb in Climber.HANDS:
		if climber.contacts[hand] == target:
			r.reason = "already holding it"
			return r
	var arm := climber.body.arm_length()
	var reach := arm * Tuning.STATIC_EXTENSION
	var best_excess := INF
	var best_shoulder := Vector2.ZERO
	for hand: Climber.Limb in Climber.HANDS:
		var shoulder := reach_pelvis(climber, hand, target.position) + climber.root_offset(hand, climber.lean)
		var excess := maxf(0.0, shoulder.distance_to(target.position) - reach)
		if excess < best_excess:
			best_excess = excess
			best_shoulder = shoulder
			r.limb = hand
	var jump := dyno_jump(climber, target.position - best_shoulder)
	r.excess = best_excess
	r.reach_ratio = (best_excess + reach) / arm
	if best_excess > jump:
		r.reason = "too far to dyno"
		return r
	r.type = MoveType.DYNO
	r.power = lerpf(Tuning.DYNO_POWER_MIN, 1.0, best_excess / jump)
	_price(r, climber, target, wall, best_shoulder, deadpoint_extra(climber.stats), jump)
	return r


## Stamina lost per second just hanging in the current position.
static func drain_per_second(climber: Climber, wall: Wall) -> float:
	var hands := climber.hand_count()
	if hands == 0:
		return 0.0
	var stats := climber.stats
	var angle := wall.angle_at(climber.pelvis)
	var per_hand_load := (1.0 - foot_share(climber, angle)) / hands
	var drain := 0.0
	for hand: Climber.Limb in Climber.HANDS:
		var hold := climber.contacts[hand]
		if hold == null:
			continue
		var grip := effective_grip(hold, climber.root_position(hand), stats)
		var poor := Tuning.HANG_DRAIN_POOR * (1.0 - grip) * (1.0 - grip)
		poor /= 1.0 + Tuning.FINGERS_DRAIN_PER_LEVEL * stats.fingers * hold.type.finger_load
		drain += per_hand_load * (Tuning.HANG_DRAIN_BASE + poor)
	return drain * _angle_drain_factor(angle, stats.core)


## Share of body weight the feet take off the hands right now.
static func foot_share(climber: Climber, angle: float) -> float:
	var share := 0.0
	for foot: Climber.Limb in Climber.FEET:
		var hold := climber.contacts[foot]
		if hold != null:
			share += hold.type.foot_quality * Tuning.FOOT_SHARE_PER_FOOT
	share *= 1.0 + Tuning.FOOTWORK_SHARE_PER_LEVEL * climber.stats.footwork
	var steep := _steepness(angle)
	if steep < 0.0:
		share *= 1.0 - Tuning.SLAB_FOOT_BONUS * steep
	else:
		var loss := maxf(0.0, Tuning.OVERHANG_FOOT_LOSS - Tuning.CORE_FOOT_KEEP_PER_LEVEL * climber.stats.core)
		share *= maxf(0.05, 1.0 - steep * loss)
	return clampf(share, 0.0, Tuning.FOOT_SHARE_MAX)


## Grip on `hold` when the arm pulls toward `shoulder`, after rotation and the fingers stat.
static func effective_grip(hold: Hold, shoulder: Vector2, stats: Stats) -> float:
	var off_axis := acos(clampf(pull_alignment(hold, shoulder), -1.0, 1.0))
	var falloff := 1.0
	if off_axis > hold.type.direction_tolerance:
		falloff = maxf(0.0, 1.0 - (off_axis - hold.type.direction_tolerance) / Tuning.GRIP_FALLOFF)
	var finger_bonus := 1.0 + Tuning.FINGERS_GRIP_PER_LEVEL * stats.fingers * hold.type.finger_load
	return clampf(hold.type.grip * falloff * finger_bonus, 0.0, 1.0)


## 1 when the arm pulls straight against the hold's facing, -1 when it pulls the opposite way.
static func pull_alignment(hold: Hold, shoulder: Vector2) -> float:
	var pull := shoulder - hold.position
	if pull.length_squared() < 0.000001:
		return 1.0
	return pull.normalized().dot(-hold.facing())


static func deadpoint_extra(stats: Stats) -> float:
	return Tuning.DEADPOINT_EXTRA + Tuning.DEADPOINT_EXTRA_PER_POWER * stats.power


## How far past static a dyno can go. `toward` is shoulder → target; sideways jumps reach farther.
static func dyno_jump(climber: Climber, toward: Vector2 = Vector2.ZERO) -> float:
	var jump := Tuning.DYNO_JUMP + Tuning.DYNO_JUMP_PER_POWER * climber.stats.power
	if climber.foot_count() == 0:
		jump *= Tuning.DYNO_NO_FEET
	var length := toward.length()
	if length > 0.001:
		var sideways := absf(toward.x) / length
		jump *= 1.0 + Tuning.DYNO_HORIZONTAL_EXTRA * sideways * sideways
	return jump


## The pelvis position that brings `limb`'s shoulder closest to `point` while every other contact
## stays within reach. With no feet on, the supporting arm can only lock off so far.
static func reach_pelvis(climber: Climber, limb: Climber.Limb, point: Vector2) -> Vector2:
	var body := climber.body
	var arm := body.arm_length()
	var reach := arm * Tuning.STATIC_EXTENSION
	var lean := climber.lean
	var shoulder_offset := climber.root_offset(limb, lean)
	var other := Climber.other_hand(limb)
	var other_hold := climber.contacts[other]
	var highest := -INF
	if climber.foot_count() == 0 and other_hold != null:
		var lockoff := minf(Tuning.LOCKOFF_BASE + Tuning.LOCKOFF_PER_POWER * climber.stats.power, Tuning.LOCKOFF_MAX)
		highest = other_hold.position.y + arm * (1.0 - lockoff) - climber.root_offset(other, lean).y
	var p := climber.pelvis
	for i: int in Tuning.REACH_ITERATIONS:
		var to_point := point - (p + shoulder_offset)
		var d := to_point.length()
		if d > reach:
			p += to_point * ((d - reach) / d)
		if p.y < highest:
			p.y = highest
		for support: Climber.Limb in Climber.LIMBS:
			var hold := climber.contacts[support]
			if support == limb or hold == null:
				continue
			var max_len := arm if Climber.is_hand(support) else body.leg_length() * Tuning.FOOT_REACH
			p = BodySolver.keep_within(p, climber.root_offset(support, lean), hold.position, max_len)
	return p


## Outline of where `limb` can reach right now, `extra` meters past static. For the debug overlay.
static func reach_envelope(climber: Climber, limb: Climber.Limb, extra: float, segments: int) -> PackedVector2Array:
	var outline := PackedVector2Array()
	var reach := climber.body.arm_length() * Tuning.STATIC_EXTENSION + extra
	var center := climber.root_position(limb)
	for i: int in segments:
		var far := center + Vector2.RIGHT.rotated(TAU * i / segments) * 5.0
		var shoulder := reach_pelvis(climber, limb, far) + climber.root_offset(limb, climber.lean)
		outline.append(shoulder + (far - shoulder).normalized() * reach)
	return outline


static func _blocked_reason(climber: Climber, limb: Climber.Limb, target: Hold) -> String:
	if not Climber.is_hand(limb):
		return "feet place themselves"
	if target == null:
		return "no hold"
	if not target.is_handhold():
		return "foothold only"
	var current := climber.contacts[limb]
	if current == target:
		return "already on it"
	var other := climber.contacts[Climber.other_hand(limb)]
	if other == target and not target.type.matchable:
		return "other hand is on it"
	if current != null and other == null:
		return "grab with your free hand first"
	if not target.type.matchable:
		for foot: Climber.Limb in Climber.FEET:
			if climber.contacts[foot] == target:
				return "a foot is on it"
	return ""


static func _price(r: MoveResult, climber: Climber, target: Hold, wall: Wall, shoulder: Vector2, dp_extra: float, jump: float) -> void:
	var stats := climber.stats
	r.grip = effective_grip(target, shoulder, stats)
	r.pull_alignment = pull_alignment(target, shoulder)
	var current := climber.contacts[r.limb]
	var start := current.position if current != null else shoulder
	var cost := Tuning.MOVE_COST_BASE + Tuning.MOVE_COST_PER_METER * start.distance_to(target.position)
	match r.type:
		MoveType.STATIC:
			cost *= Tuning.MOVE_COST_STATIC / (1.0 + Tuning.FOOTWORK_STATIC_DISCOUNT * stats.footwork)
		MoveType.DEADPOINT:
			cost *= Tuning.MOVE_COST_DEADPOINT / (1.0 + Tuning.POWER_BIG_MOVE_DISCOUNT * stats.power)
		_:
			cost *= Tuning.MOVE_COST_DYNO / (1.0 + Tuning.POWER_BIG_MOVE_DISCOUNT * stats.power)
	cost *= 1.0 + Tuning.MOVE_COST_POOR_TARGET * (1.0 - r.grip)
	var overhang := maxf(0.0, _steepness(wall.angle_at(target.position)))
	cost *= 1.0 + overhang * maxf(0.0, Tuning.MOVE_COST_OVERHANG - Tuning.CORE_ANGLE_PER_LEVEL * stats.core)
	match climber.foot_count():
		0:
			cost *= 1.0 + Tuning.MOVE_COST_NO_FEET
		1:
			cost *= 1.0 + Tuning.MOVE_COST_NO_FEET * 0.5
	cost *= 1.0 + Tuning.MOVE_COST_FATIGUE * climber.fatigue()
	r.stamina_cost = cost
	r.window = _window(r, climber, dp_extra, jump)


static func _window(r: MoveResult, climber: Climber, dp_extra: float, jump: float) -> float:
	if r.type == MoveType.STATIC:
		return 1.0
	var base := Tuning.DEADPOINT_WINDOW
	var margin := 1.0 - r.excess / dp_extra
	if r.type == MoveType.DYNO:
		base = Tuning.DYNO_WINDOW
		margin = 1.0 - r.excess / jump
	var w := base * (0.4 + 0.6 * clampf(margin, 0.0, 1.0)) * (0.4 + 0.6 * r.grip)
	w *= 1.0 + Tuning.WINDOW_POWER_PER_LEVEL * climber.stats.power
	w *= 1.0 - Tuning.WINDOW_FATIGUE * climber.fatigue()
	return clampf(w, Tuning.WINDOW_MIN, Tuning.WINDOW_MAX)


## Wall angle scaled so 45° overhang = 1 and 45° slab = -1.
static func _steepness(angle: float) -> float:
	return clampf(angle / STEEP_REFERENCE, -1.0, 2.0)


static func _angle_drain_factor(angle: float, core: int) -> float:
	var steep := _steepness(angle)
	if steep < 0.0:
		return 1.0 + Tuning.SLAB_DRAIN_RELIEF * steep
	return 1.0 + steep * maxf(0.0, Tuning.OVERHANG_DRAIN - Tuning.CORE_ANGLE_PER_LEVEL * core)
