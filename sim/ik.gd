class_name IK
extends RefCounted
## Two-bone inverse kinematics (law of cosines) for drawing arms and legs. Pure math.


## The middle joint (elbow or knee) of a two-bone limb reaching from `root` toward `target`.
## `side` is -1 for left limbs and +1 for right: the joint bends out toward that side.
## When the limb is close to horizontal, `droop` > 0 prefers the lower joint (elbows) and
## `droop` < 0 the higher one (knees). Out-of-reach targets get a straight limb pointing at them.
static func solve(root: Vector2, target: Vector2, upper: float, lower: float, side: float, droop: float) -> Vector2:
	var to_target := target - root
	var dist := to_target.length()
	if dist < 0.000001:
		return root + Vector2(side, 0.0) * upper
	var dir := to_target / dist
	var d := clampf(dist, absf(upper - lower) + 0.000001, upper + lower - 0.000001)
	# lower² = upper² + d² - 2·upper·d·cos(a), with a the angle at the root
	var cos_a := (upper * upper + d * d - lower * lower) / (2.0 * upper * d)
	var a := acos(clampf(cos_a, -1.0, 1.0))
	var clockwise := root + dir.rotated(a) * upper
	var counter := root + dir.rotated(-a) * upper
	var preference := (clockwise.x - counter.x) * side + (clockwise.y - counter.y) * droop
	return clockwise if preference >= 0.0 else counter


## Where a limb of total `length` gets to when aiming from `root` at `target`.
static func reach_point(root: Vector2, target: Vector2, length: float) -> Vector2:
	var to_target := target - root
	if to_target.length() <= length:
		return target
	return root + to_target.normalized() * length
