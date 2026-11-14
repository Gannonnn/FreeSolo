extends GutTest


func test_joint_keeps_both_bone_lengths() -> void:
	var root := Vector2(0.0, 0.0)
	var target := Vector2(0.3, -0.4)
	var joint := IK.solve(root, target, 0.3, 0.35, 1.0, 0.0)
	assert_almost_eq(root.distance_to(joint), 0.3, 0.0001)
	assert_almost_eq(joint.distance_to(target), 0.35, 0.0001)


func test_out_of_reach_target_straightens_the_limb() -> void:
	var joint := IK.solve(Vector2.ZERO, Vector2(2.0, 0.0), 0.3, 0.35, 1.0, 0.0)
	assert_almost_eq(joint.x, 0.3, 0.001)
	assert_almost_eq(joint.y, 0.0, 0.001)


func test_joint_bends_outward_by_side() -> void:
	var left := IK.solve(Vector2.ZERO, Vector2(0.0, -0.5), 0.3, 0.35, -1.0, 0.0)
	var right := IK.solve(Vector2.ZERO, Vector2(0.0, -0.5), 0.3, 0.35, 1.0, 0.0)
	assert_lt(left.x, 0.0)
	assert_gt(right.x, 0.0)


func test_droop_picks_the_lower_joint() -> void:
	var low := IK.solve(Vector2.ZERO, Vector2(0.5, 0.0), 0.3, 0.35, 0.0, 1.0)
	var high := IK.solve(Vector2.ZERO, Vector2(0.5, 0.0), 0.3, 0.35, 0.0, -1.0)
	assert_gt(low.y, 0.0)
	assert_lt(high.y, 0.0)


func test_reach_point_stops_at_the_limb_length() -> void:
	assert_eq(IK.reach_point(Vector2.ZERO, Vector2(0.2, 0.0), 0.5), Vector2(0.2, 0.0))
	assert_almost_eq(IK.reach_point(Vector2.ZERO, Vector2(2.0, 0.0), 0.5).x, 0.5, 0.0001)
