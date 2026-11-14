extends GutTest

const Fixtures := preload("res://tests/fixtures.gd")


func test_plus_adds_each_stat() -> void:
	var a := Stats.uniform(2)
	var b := Stats.new()
	b.power = 3
	b.fingers = -1
	var sum := a.plus(b)
	assert_eq(sum.power, 5)
	assert_eq(sum.fingers, 1)
	assert_eq(sum.core, 2)


func test_clamped_to_respects_caps() -> void:
	var capped := Stats.uniform(12).clamped_to(Stats.uniform(10))
	assert_eq(capped.endurance, 10)
	var floored := Stats.uniform(-2).clamped_to(Stats.uniform(10))
	assert_eq(floored.fingers, 0)


func test_get_level_reads_the_named_stat() -> void:
	var s := Stats.new()
	s.core = 7
	assert_eq(s.get_level(Stats.Kind.CORE), 7)
	assert_eq(s.get_level(Stats.Kind.FOOTWORK), 0)


func test_endurance_raises_max_stamina() -> void:
	var low := Fixtures.climber_from(Stats.uniform(0))
	var high := Fixtures.climber_from(Stats.uniform(5))
	assert_gt(high.max_stamina, low.max_stamina)
	assert_eq(high.stamina, high.max_stamina)


func test_basic_wall_is_well_formed() -> void:
	var wall := TestWalls.basic()
	for hold: Hold in wall.holds:
		assert_true(Rect2(Vector2.ZERO, wall.size).has_point(hold.position), "hold %d is on the wall" % hold.id)
	assert_eq(wall.start_holds.size(), 2)
	var body := BodyDims.from_character(Catalog.character(&"default"))
	for spot: RestSpot in wall.rests:
		assert_true(spot.fits(body), "%s fits the default climber" % spot.display_name())
