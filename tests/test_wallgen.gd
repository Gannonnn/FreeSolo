extends GutTest
## The wall generator: same seed, same wall; every wall can be climbed; holds and rests make sense.

const Fixtures := preload("res://tests/fixtures.gd")

var _wall: Wall


func before_all() -> void:
	var started := Time.get_ticks_msec()
	_wall = WallGen.generate(_spec(), 11)
	gut.p("generated a %.0f m wall with %d holds and %d rests in %d ms" % [
		_wall.size.y, _wall.holds.size(), _wall.rests.size(), Time.get_ticks_msec() - started])


func _spec(rock_id: StringName = &"granite") -> WallSpec:
	var spec := Catalog.wall_spec(&"crag_1").duplicate() as WallSpec
	spec.rock = Catalog.rock(rock_id)
	return spec


## Everything gameplay can see about a wall, as text.
func _signature(w: Wall) -> String:
	var parts := PackedStringArray()
	parts.append("size %s top %.3f start %d %d" % [w.size, w.top_out_y, w.start_holds[0].id, w.start_holds[1].id])
	parts.append("angles %d outline %d %d" % [str(w.angle_grid).hash(), str(w.face_left).hash(), str(w.face_right).hash()])
	for hold: Hold in w.holds:
		parts.append("%s %.4f %.4f %.4f" % [hold.type.id, hold.position.x, hold.position.y, hold.rotation])
	for spot: RestSpot in w.rests:
		parts.append("rest %d %.4f %.4f %d" % [spot.kind, spot.position.x, spot.position.y, spot.foot_hold.id])
	for f: RockFeature in w.features:
		parts.append("feature %d %d %.4f %.4f %.4f" % [f.kind, f.points.size(), f.width, f.points[0].x, f.points[0].y])
	var guide := PackedStringArray()
	for hold: Hold in w.guide:
		guide.append(str(hold.id))
	parts.append("guide " + " ".join(guide))
	return "\n".join(parts)


func test_same_seed_makes_the_same_wall() -> void:
	var again := WallGen.generate(_spec(), 11)
	assert_eq(_signature(again), _signature(_wall))


func test_different_seeds_make_different_walls() -> void:
	var other := WallGen.generate(_spec(), 12)
	assert_ne(_signature(other), _signature(_wall))


func test_generated_walls_can_be_topped_out_by_the_default_climber() -> void:
	for seed_value: int in [3, 11, 27]:
		var w := _wall if seed_value == 11 else WallGen.generate(_spec(), seed_value)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var result := RouteFinder.climb(w, Fixtures.climber(), rng)
		gut.p("seed %d: %s" % [seed_value, result.summary()])
		assert_true(result.topped_out, "seed %d: %s" % [seed_value, result.summary()])


func test_limestone_walls_can_be_topped_out_too() -> void:
	var w := WallGen.generate(_spec(&"limestone"), 5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var result := RouteFinder.climb(w, Fixtures.climber(), rng)
	gut.p("limestone seed 5: %s" % result.summary())
	assert_true(result.topped_out, result.summary())
	assert_gt(w.guide.size(), int(w.size.y), "the generator recorded its proven line")


func test_the_guide_line_starts_on_the_start_holds_and_ends_at_the_top() -> void:
	assert_gt(_wall.guide.size(), int(_wall.size.y))
	assert_eq(_wall.guide[0], _wall.start_holds[0])
	assert_eq(_wall.guide[1], _wall.start_holds[1])
	assert_true(_wall.guide[_wall.guide.size() - 1].position.y <= _wall.top_out_y)


func test_holds_stay_on_the_face() -> void:
	for hold: Hold in _wall.holds:
		assert_true(_wall.contains(hold.position), "%s at %s is off the face" % [hold.type.id, hold.position])


func test_rests_fit_the_default_climber() -> void:
	var body := Fixtures.climber().body
	assert_gt(_wall.rests.size(), 0)
	for spot: RestSpot in _wall.rests:
		assert_true(spot.fits(body), "%s at %s" % [spot.display_name(), spot.position])


func test_steep_rock_gets_bigger_holds() -> void:
	var steep := []
	var gentle := []
	for hold: Hold in _wall.holds:
		if not hold.is_handhold() or hold.type.id == &"ledge":
			continue
		var angle := rad_to_deg(_wall.angle_at(hold.position))
		if angle > 12.0:
			steep.append(hold.type.grip)
		elif angle < -8.0:
			gentle.append(hold.type.grip)
	if steep.is_empty() or gentle.is_empty():
		pass_test("this wall has no steep or no slab rock to compare")
		return
	var steep_mean: float = steep.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / steep.size()
	var gentle_mean: float = gentle.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / gentle.size()
	assert_gt(steep_mean, gentle_mean)


func test_rock_has_a_variety_of_natural_holds() -> void:
	var kinds := {}
	for hold: Hold in _wall.holds:
		if hold.is_handhold():
			kinds[hold.type.id] = true
	assert_gte(kinds.size(), 8, str(kinds.keys()))


func test_hold_types_are_sane() -> void:
	var ids := {}
	for path: String in Catalog.HOLD_TYPE_PATHS:
		var t := load(path) as HoldType
		assert_not_null(t, path)
		assert_false(ids.has(t.id), "duplicate id " + t.id)
		ids[t.id] = true
		assert_gt(t.radius, 0.0, path)
		if t.grip < Tuning.MIN_HAND_GRIP:
			assert_gt(t.foot_quality, 0.0, "%s is neither a handhold nor a foothold" % t.id)
	for id: StringName in [&"foot_chip", &"smear", &"ground"]:
		assert_lt(Catalog.hold_type(id).grip, Tuning.MIN_HAND_GRIP, "%s is foot-only" % id)
	for rock_path: String in Catalog.ROCK_PATHS:
		var rock := load(rock_path) as RockType
		assert_eq(rock.hold_ids.size(), rock.hold_weights.size(), rock_path)
		assert_eq(rock.rail_ids.size(), rock.rail_weights.size(), rock_path)
		for id: StringName in rock.hold_ids:
			assert_true(ids.has(id), "%s uses unknown hold %s" % [rock_path, id])
