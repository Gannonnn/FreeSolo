class_name BodySolver
extends RefCounted
## Places the climber's body (pelvis and torso lean) for a set of contacts, and plans the feet.


## A full body placement: which hold each limb is on, plus where the body sits.
class Pose:
	var contacts: Array[Hold]
	var pelvis: Vector2
	var lean: float


## Plans footholds for the given hands, then places the body. Doesn't change the climber.
## Feet are planned from where the body would hang on the hands alone, so the old feet can't hold
## the body down and the feet keep up with the hands.
static func settle(climber: Climber, wall: Wall, contacts: Array[Hold]) -> Pose:
	var pose := Pose.new()
	pose.contacts = contacts.duplicate()
	var hands_only: Array[Hold] = contacts.duplicate()
	hands_only[Climber.Limb.LEFT_FOOT] = null
	hands_only[Climber.Limb.RIGHT_FOOT] = null
	var hang_pelvis := pelvis_for(climber, hands_only, 0.0)
	var feet := FootPlanner.plan(climber, wall, pose.contacts, hang_pelvis, 0.0)
	pose.contacts[Climber.Limb.LEFT_FOOT] = feet[0]
	pose.contacts[Climber.Limb.RIGHT_FOOT] = feet[1]
	pose.lean = lean_for(pose.contacts)
	pose.pelvis = pelvis_for(climber, pose.contacts, pose.lean)
	return pose


static func apply(climber: Climber, pose: Pose) -> void:
	climber.contacts = pose.contacts.duplicate()
	climber.pelvis = pose.pelvis
	climber.lean = pose.lean


## Torso lean (radians) toward the hands when they're off to one side of the feet.
static func lean_for(contacts: Array[Hold]) -> float:
	var hand_sum := Vector2.ZERO
	var hands := 0
	for limb: Climber.Limb in Climber.HANDS:
		if contacts[limb] != null:
			hand_sum += contacts[limb].position
			hands += 1
	var foot_sum := Vector2.ZERO
	var feet := 0
	for limb: Climber.Limb in Climber.FEET:
		if contacts[limb] != null:
			foot_sum += contacts[limb].position
			feet += 1
	if hands == 0 or feet == 0:
		return 0.0
	var v := hand_sum / hands - foot_sum / feet
	return clampf(atan2(v.x, -v.y) * Tuning.LEAN_SHARE, -Tuning.LEAN_MAX, Tuning.LEAN_MAX)


## Hangs the body from the hands, then pulls it until every contact is within limb reach.
## During a knee-bar, `knee_limb`'s hip is kept within thigh length of `knee_at` instead.
static func pelvis_for(climber: Climber, contacts: Array[Hold], lean: float, knee_limb: int = -1, knee_at: Vector2 = Vector2.ZERO) -> Vector2:
	var body := climber.body
	var p := _hang_target(climber, contacts, lean)
	for i: int in Tuning.BODY_ITERATIONS:
		for limb: Climber.Limb in Climber.FEET:
			var foot := contacts[limb]
			if foot == null:
				continue
			var offset := climber.root_offset(limb, lean)
			if limb == knee_limb:
				p = keep_within(p, offset, knee_at, body.thigh)
			else:
				p = keep_within(p, offset, foot.position, body.leg_length())
				p = _keep_apart(p, offset, foot.position, body.leg_length() * Tuning.LEG_MIN_FOLD)
		for limb: Climber.Limb in Climber.HANDS:
			var hand := contacts[limb]
			if hand != null:
				p = keep_within(p, climber.root_offset(limb, lean), hand.position, body.arm_length())
	return p


## Moves pelvis `p` the least it takes for the joint at `p + offset` to be within `max_len` of `anchor`.
static func keep_within(p: Vector2, offset: Vector2, anchor: Vector2, max_len: float) -> Vector2:
	var v := p + offset - anchor
	var d := v.length()
	if d <= max_len:
		return p
	return p - v * ((d - max_len) / d)


static func _keep_apart(p: Vector2, offset: Vector2, anchor: Vector2, min_len: float) -> Vector2:
	var v := p + offset - anchor
	var d := v.length()
	if d >= min_len or d < 0.000001:
		return p
	return p + v * ((min_len - d) / d)


## Where the pelvis hangs with straight-ish arms, shifted toward the feet.
static func _hang_target(climber: Climber, contacts: Array[Hold], lean: float) -> Vector2:
	var body := climber.body
	var hand_sum := Vector2.ZERO
	var hands := 0
	for limb: Climber.Limb in Climber.HANDS:
		if contacts[limb] != null:
			hand_sum += contacts[limb].position
			hands += 1
	var foot_sum := Vector2.ZERO
	var feet := 0
	for limb: Climber.Limb in Climber.FEET:
		if contacts[limb] != null:
			foot_sum += contacts[limb].position
			feet += 1
	if hands == 0:
		if feet == 0:
			return climber.pelvis
		return foot_sum / feet + Vector2(0.0, -body.leg_length() * 0.9)
	var shoulders := hand_sum / hands + Vector2(0.0, Tuning.HANG_ARM_SHARE * body.arm_length())
	var target := shoulders - Vector2.UP.rotated(lean) * body.torso
	if feet > 0:
		target.x = lerpf(target.x, foot_sum.x / feet, Tuning.FEET_PULL_X)
	return target
