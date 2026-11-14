class_name FootPlanner
extends RefCounted
## Picks a foothold for each foot after every hand move.


## Returns [left foot hold, right foot hold]. Either can be null (that foot stays off).
static func plan(climber: Climber, wall: Wall, contacts: Array[Hold], pelvis: Vector2, lean: float) -> Array[Hold]:
	var result: Array[Hold] = [null, null]
	if climber.has_rule(Relic.Rule.NO_FEET):
		return result
	var left := _best(climber, wall, contacts, Climber.Limb.LEFT_FOOT, pelvis, lean, null)
	var right := _best(climber, wall, contacts, Climber.Limb.RIGHT_FOOT, pelvis, lean, null)
	if left != null and left == right and not left.type.matchable:
		var left_score := _score(climber, contacts, Climber.Limb.LEFT_FOOT, left, pelvis, lean)
		var right_score := _score(climber, contacts, Climber.Limb.RIGHT_FOOT, right, pelvis, lean)
		if left_score >= right_score:
			right = _best(climber, wall, contacts, Climber.Limb.RIGHT_FOOT, pelvis, lean, left)
		else:
			left = _best(climber, wall, contacts, Climber.Limb.LEFT_FOOT, pelvis, lean, right)
	result[0] = left
	result[1] = right
	return result


static func _best(climber: Climber, wall: Wall, contacts: Array[Hold], limb: Climber.Limb, pelvis: Vector2, lean: float, exclude: Hold) -> Hold:
	var hip := pelvis + climber.root_offset(limb, lean)
	var reach := climber.body.leg_length() * Tuning.FOOT_REACH
	var min_quality := maxf(0.01, Tuning.FOOT_MIN_QUALITY - Tuning.FOOT_MIN_QUALITY_PER_LEVEL * climber.stats.footwork)
	var left_hand := contacts[Climber.Limb.LEFT_HAND]
	var right_hand := contacts[Climber.Limb.RIGHT_HAND]
	var best: Hold = null
	var best_score := -INF
	for hold: Hold in wall.holds_near(hip, reach):
		if hold == exclude or hold.type.foot_quality < min_quality:
			continue
		if hold.position.y < pelvis.y - Tuning.FOOT_HIGH_STEP:
			continue
		if not hold.type.matchable and (hold == left_hand or hold == right_hand):
			continue
		var score := _score(climber, contacts, limb, hold, pelvis, lean)
		if score > best_score:
			best = hold
			best_score = score
	return best


static func _score(climber: Climber, contacts: Array[Hold], limb: Climber.Limb, hold: Hold, pelvis: Vector2, lean: float) -> float:
	var hip := pelvis + climber.root_offset(limb, lean)
	var side := Climber.side_sign(limb)
	var ideal := hip + Vector2(side * Tuning.FOOT_IDEAL_SPREAD, climber.body.leg_length() * Tuning.FOOT_IDEAL_DROP)
	var offset := hold.position - ideal
	if offset.y > 0.0:
		offset.y *= Tuning.FOOT_SCORE_LOW_WEIGHT
	var score := hold.type.foot_quality * Tuning.FOOT_SCORE_QUALITY - offset.length() * Tuning.FOOT_SCORE_DISTANCE
	if contacts[limb] == hold:
		score += Tuning.FOOT_SCORE_KEEP
	return score
