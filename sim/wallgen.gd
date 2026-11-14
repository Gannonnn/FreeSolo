class_name WallGen
extends RefCounted
## Turns a WallSpec and a seed into a natural rock wall: a face outline, a steepness profile,
## cracks, flakes, rails, pockets and tufas, holds scattered the way real rock has them, rests, a
## start and a summit. Then RouteFinder's test climber climbs it, and wherever it gets stuck, or
## runs low with no rest in reach, the generator adds a hold or a rest. So the default character
## can always climb it with careful play. Same spec and seed, same wall.

# --- Shape ------------------------------------------------------------------------

## Meters per angle grid cell.
const ANGLE_CELL: float = 0.5
## Meters over which the angle blends from one band into the next.
const BAND_BLEND: float = 1.0
## Degrees the angle wanders across the face on top of its band.
const ACROSS_DEGREES: float = 6.0
## Meters above the ground kept slabby or vertical, so the start is never steep.
const EASY_START: float = 2.5
## Meters below the top that round over into a slab.
const SUMMIT_SLAB: float = 1.5
## Meters the middle of the face drifts left and right up the wall.
const CENTER_DRIFT: float = 0.8
## Meters over which the face gets wider or narrower. Lower = a more ragged outline.
const OUTLINE_WAVE: float = 4.0
## Meters of small-scale raggedness on the face's left and right edges.
const OUTLINE_JAG: float = 0.15

# --- Holds ------------------------------------------------------------------------

## Meters of bare rock kept between the edges of neighbouring holds.
const HOLD_GAP: float = 0.04
## Holds stay at least this far inside the face outline.
const FACE_MARGIN: float = 0.2
## Meters between holds along cracks, flakes, rails and tufas.
const LINE_SPACING: Vector2 = Vector2(0.28, 0.42)
## How much scattered hold density swings between blank and featured patches (0 = even, 1 = the
## blankest patches get none). Higher reads more like real rock, and makes the generator repair
## more gaps.
const DENSITY_SWING: float = 0.9
## Meters across a typical blank or featured patch.
const DENSITY_PATCH: float = 3.5
## Chance a scattered hold faces sideways (a sidepull or gaston).
const SIDEPULL_CHANCE: float = 0.16
## Chance a scattered edge, jug or flake faces down (an undercling).
const UNDERCLING_CHANCE: float = 0.05
## Degrees of random tilt on holds that face up.
const TILT_DEGREES: float = 16.0
## How strongly steep rock favors high-grip holds and slabs favor small ones. 0 = same mix everywhere.
const STEEP_GRIP_BIAS: float = 3.0
## Smears only go on slabs steeper than this many degrees.
const SMEAR_MAX_DEGREES: float = -5.0
## Meters above the ground where the start holds sit.
const START_HEIGHT: float = 1.65

# --- Making it climbable ----------------------------------------------------------

## Climb-and-repair passes. The first pass that needs no repairs ends it.
const MAX_PASSES: int = 4
## Meters above the higher hand to try a repair hold, best first.
const REPAIR_RISES: Array[float] = [0.34, 0.28, 0.22, 0.16]
## Meters sideways from the higher hand to try a repair hold, toward the middle of the face first.
const REPAIR_SHIFTS: Array[float] = [0.0, 0.2, -0.2, 0.38, -0.38]
## Hold types a repair may add: good holds that look natural anywhere.
const REPAIR_TYPES: Array[StringName] = [&"edge", &"jug", &"flake", &"horn"]

static func generate(spec: WallSpec, seed_value: int) -> Wall:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wall := Wall.new(Vector2(spec.width, spec.height), Tuning.TOP_OUT_DEPTH)
	wall.gen_seed = seed_value
	wall.rock = spec.rock
	var shin := BodyDims.from_character(Catalog.character(&"default")).shin
	var per_wall := spec.height / 25.0
	_shape_outline(wall, spec, rng)
	_shape_angles(wall, spec, rng)
	_add_start(wall, rng)
	_add_summit(wall, rng)
	_add_natural_rests(wall, spec, rng, shin, per_wall)
	_add_cracks(wall, rng, _count(spec.rock.cracks, rng, per_wall))
	_add_flakes(wall, rng, _count(spec.rock.flakes, rng, per_wall))
	_add_rails(wall, rng, _count(spec.rock.rails, rng, per_wall))
	_add_tufas(wall, rng, _count(spec.rock.tufa_lines, rng, per_wall))
	_add_pocket_clusters(wall, rng, _count(spec.rock.pocket_clusters, rng, per_wall))
	_scatter_holds(wall, spec, rng)
	_scatter_feet(wall, spec, rng)
	_make_climbable(wall, rng, shin)
	return wall


# --- Shape ------------------------------------------------------------------------

static func _shape_outline(wall: Wall, spec: WallSpec, rng: RandomNumberGenerator) -> void:
	var rows := ceili(wall.size.y / Wall.FACE_CELL)
	var drift := _wave(rng, wall.size.y, OUTLINE_WAVE * 1.5)
	var spread := _wave(rng, wall.size.y, OUTLINE_WAVE)
	var left_jag := _wave(rng, wall.size.y, 0.75)
	var right_jag := _wave(rng, wall.size.y, 0.75)
	var mid := wall.size.x * 0.5
	wall.face_left.resize(rows)
	wall.face_right.resize(rows)
	for row: int in rows:
		var y := (row + 0.5) * Wall.FACE_CELL
		var center := mid + _sample(drift, y, OUTLINE_WAVE * 1.5) * CENTER_DRIFT
		var half := lerpf(spec.face_width.x, spec.face_width.y, 0.5 + 0.5 * _sample(spread, y, OUTLINE_WAVE)) * 0.5
		var left := center - half + _sample(left_jag, y, 0.75) * OUTLINE_JAG
		var right := center + half + _sample(right_jag, y, 0.75) * OUTLINE_JAG
		wall.face_left[row] = clampf(left, 0.3, mid - 2.0)
		wall.face_right[row] = clampf(right, mid + 2.0, wall.size.x - 0.3)


static func _shape_angles(wall: Wall, spec: WallSpec, rng: RandomNumberGenerator) -> void:
	# Bands from the ground up. x = the height (y) where the band ends going up, y = degrees.
	var bands: Array[Vector2] = []
	var y := wall.size.y - EASY_START
	bands.append(Vector2(y, rng.randf_range(spec.slab_degrees.y, spec.vertical_degrees.y * 0.5)))
	while y > SUMMIT_SLAB + 1.0:
		var top := maxf(SUMMIT_SLAB, y - rng.randf_range(spec.band_length.x, spec.band_length.y))
		bands.append(Vector2(top, _band_degrees(spec, rng)))
		y = top
	bands.append(Vector2(0.0, rng.randf_range(-25.0, -12.0)))
	var across := FastNoiseLite.new()
	across.seed = rng.randi()
	across.frequency = 0.12
	across.fractal_type = FastNoiseLite.FRACTAL_NONE
	var cols := ceili(wall.size.x / ANGLE_CELL)
	var rows := ceili(wall.size.y / ANGLE_CELL)
	var values := PackedFloat32Array()
	values.resize(cols * rows)
	for row: int in rows:
		var cy := (row + 0.5) * ANGLE_CELL
		var band := _band_angle(bands, wall.size.y, cy)
		for col: int in cols:
			var cx := (col + 0.5) * ANGLE_CELL
			values[row * cols + col] = band + deg_to_rad(ACROSS_DEGREES) * across.get_noise_2d(cx, cy)
	wall.set_angle_grid(ANGLE_CELL, cols, values)


static func _band_degrees(spec: WallSpec, rng: RandomNumberGenerator) -> float:
	var roll := rng.randf()
	if roll < spec.slab_chance:
		return rng.randf_range(spec.slab_degrees.x, spec.slab_degrees.y)
	if roll < spec.slab_chance + spec.overhang_chance:
		return rng.randf_range(spec.overhang_degrees.x, spec.overhang_degrees.y)
	return rng.randf_range(spec.vertical_degrees.x, spec.vertical_degrees.y)


## Radians at height `y`, blending into the neighbouring band near each boundary.
static func _band_angle(bands: Array[Vector2], ground: float, y: float) -> float:
	var lower_edge := ground
	for i: int in bands.size():
		var upper_edge := bands[i].x
		if y >= upper_edge or i == bands.size() - 1:
			var degrees := bands[i].y
			if i + 1 < bands.size() and y - upper_edge < BAND_BLEND * 0.5:
				degrees = lerpf(degrees, bands[i + 1].y, 0.5 - (y - upper_edge) / BAND_BLEND)
			elif i > 0 and lower_edge - y < BAND_BLEND * 0.5:
				degrees = lerpf(degrees, bands[i - 1].y, 0.5 - (lower_edge - y) / BAND_BLEND)
			return deg_to_rad(degrees)
		lower_edge = upper_edge
	return 0.0


## Heights where steeper rock starts above less steep rock: the lips of roofs, where knee-bars
## naturally form. Bottom first.
static func _roof_lips(wall: Wall) -> PackedFloat32Array:
	var lips := PackedFloat32Array()
	var x := wall.size.x * 0.5
	var y := wall.size.y - 1.0
	var last := INF
	while y > 2.0:
		var jump := wall.angle_at(Vector2(x, y - 0.75)) - wall.angle_at(Vector2(x, y))
		if jump > deg_to_rad(10.0) and last - y > 2.0:
			lips.append(y - 0.25)
			last = y
		y -= 0.25
	return lips


# --- Features ---------------------------------------------------------------------

static func _add_start(wall: Wall, rng: RandomNumberGenerator) -> void:
	var ground := wall.ground_y()
	var y := ground - START_HEIGHT
	var span := wall.face_span(y)
	var x := clampf(wall.size.x * 0.5 + rng.randf_range(-1.5, 1.5), span.x + 1.0, span.y - 1.0)
	var start_type := Catalog.hold_type(&"jug" if rng.randf() < 0.5 else &"edge")
	var left := wall.add_hold(start_type, Vector2(x - 0.28, y + rng.randf_range(-0.04, 0.04)), _tilt(rng))
	var right := wall.add_hold(start_type, Vector2(x + 0.28, y + rng.randf_range(-0.04, 0.04)), _tilt(rng))
	wall.start_holds = [left, right]
	var dirt := Catalog.hold_type(&"ground")
	var base := wall.face_span(ground - 0.1)
	var gx := base.x + 0.15
	while gx < base.y - 0.15:
		wall.add_hold(dirt, Vector2(gx, ground - 0.03))
		gx += 0.3


## The lip of the cliff: big holds just below the top, so the top-out reads clearly.
static func _add_summit(wall: Wall, rng: RandomNumberGenerator) -> void:
	var ids: Array[StringName] = [&"jug", &"edge", &"horn", &"jug", &"sloper"]
	var span := wall.face_span(0.45)
	var x := span.x + rng.randf_range(0.3, 0.6)
	while x < span.y - 0.3:
		var type := Catalog.hold_type(ids[rng.randi_range(0, ids.size() - 1)])
		var at := Vector2(x, rng.randf_range(0.3, wall.top_out_y - 0.08))
		if not _crowded(wall, at, type.radius):
			wall.add_hold(type, at, _tilt(rng))
		x += rng.randf_range(0.3, 0.65)


static func _add_natural_rests(wall: Wall, spec: WallSpec, rng: RandomNumberGenerator, shin: float, per_wall: float) -> void:
	var lips := _roof_lips(wall)
	for i: int in _count(spec.kneebars, rng, per_wall):
		var y := lips[i] + 0.05 if i < lips.size() else rng.randf_range(4.0, wall.size.y - 3.0)
		var span := wall.face_span(y)
		var knee := Vector2(rng.randf_range(span.x + 0.8, span.y - 0.8), y)
		_add_kneebar(wall, knee, knee + Vector2(rng.randf_range(-0.04, 0.04), shin))
static func _add_kneebar(wall: Wall, knee: Vector2, foot_at: Vector2) -> void:
	var foot := wall.add_hold(Catalog.hold_type(&"foot_chip"), foot_at)
	wall.add_rest(RestSpot.kneebar(knee, foot))
	wall.features.append(RockFeature.make(RockFeature.Kind.NOTCH, PackedVector2Array([knee]), 0.42))


## Mostly vertical cracks with finger jams along them, and the odd edge on a lip for laybacking.
static func _add_cracks(wall: Wall, rng: RandomNumberGenerator, count: int) -> void:
	var jam := Catalog.hold_type(&"crack")
	var edge := Catalog.hold_type(&"edge")
	for i: int in count:
		var length := rng.randf_range(3.5, 9.0)
		var bottom_y := rng.randf_range(minf(length + 1.0, wall.size.y - 0.8), wall.size.y - 0.8)
		var span := wall.face_span(bottom_y)
		var p := Vector2(rng.randf_range(span.x + 0.8, span.y - 0.8), bottom_y)
		var lean := rng.randf_range(-0.3, 0.3)
		var line := PackedVector2Array([p])
		while p.y > bottom_y - length:
			p += Vector2(lean * 0.35 + rng.randf_range(-0.06, 0.06), -0.35)
			if not wall.contains(p, FACE_MARGIN):
				break
			line.append(p)
		if line.size() < 5:
			continue
		var width := rng.randf_range(0.012, 0.03)
		wall.features.append(RockFeature.make(RockFeature.Kind.CRACK, line, width))
		for at: Vector2 in _stations(line, rng):
			if not _crowded(wall, at, jam.radius * 0.7):
				wall.add_hold(jam, at, deg_to_rad(rng.randfn(0.0, 8.0)))
			if rng.randf() < 0.25:
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				var lip := at + Vector2(side * (width + edge.radius * 0.9), rng.randf_range(-0.1, 0.1))
				if wall.contains(lip, FACE_MARGIN) and not _crowded(wall, lip, edge.radius):
					wall.add_hold(edge, lip, -side * PI / 2.0 + deg_to_rad(rng.randfn(0.0, 10.0)))


## Detached plates standing off the wall. The free edge is a sidepull or layback.
static func _add_flakes(wall: Wall, rng: RandomNumberGenerator, count: int) -> void:
	var flake := Catalog.hold_type(&"flake")
	for i: int in count:
		var length := rng.randf_range(0.8, 2.2)
		var bottom_y := rng.randf_range(length + 1.5, wall.size.y - 1.0)
		var span := wall.face_span(bottom_y)
		var start := Vector2(rng.randf_range(span.x + 0.8, span.y - 0.8), bottom_y)
		var tilt := rng.randf_range(-0.25, 0.25)
		var bow := rng.randf_range(-0.12, 0.12)
		var line := PackedVector2Array()
		var steps := ceili(length / 0.2)
		for s: int in steps + 1:
			var t := float(s) / steps
			line.append(start + Vector2(tilt * length * t + bow * sin(t * PI), -length * t))
		if not wall.contains(line[0], FACE_MARGIN) or not wall.contains(line[line.size() - 1], FACE_MARGIN):
			continue
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		wall.features.append(RockFeature.make(RockFeature.Kind.FLAKE, line, rng.randf_range(0.14, 0.3), side))
		var facing := -side * PI / 2.0 + atan(tilt)
		for at: Vector2 in _stations(line, rng):
			if not _crowded(wall, at, flake.radius * 0.6):
				wall.add_hold(flake, at, facing + deg_to_rad(rng.randfn(0.0, 10.0)))


## Roughly horizontal seams with a line of edges along them.
static func _add_rails(wall: Wall, rng: RandomNumberGenerator, count: int) -> void:
	var rock := wall.rock
	for i: int in count:
		var y := rng.randf_range(3.0, wall.size.y - 2.5)
		var span := wall.face_span(y)
		var length := rng.randf_range(1.8, minf(5.0, span.y - span.x - 1.0))
		var x0 := rng.randf_range(span.x + 0.4, span.y - 0.4 - length)
		var slope := rng.randf_range(-0.12, 0.12)
		var line := PackedVector2Array()
		var steps := ceili(length / 0.25)
		for s: int in steps + 1:
			var x := x0 + length * s / steps
			line.append(Vector2(x, y + slope * (x - x0) + rng.randf_range(-0.015, 0.015)))
		wall.features.append(RockFeature.make(RockFeature.Kind.RAIL, line, rng.randf_range(0.07, 0.12)))
		for at: Vector2 in _stations(line, rng):
			var type := Catalog.hold_type(_pick_id(rock.rail_ids, rock.rail_weights, rng))
			if not _crowded(wall, at, type.radius * 0.8):
				wall.add_hold(type, at, atan(slope) + deg_to_rad(rng.randfn(0.0, 6.0)))


## Limestone columns: a vertical line of pinches.
static func _add_tufas(wall: Wall, rng: RandomNumberGenerator, count: int) -> void:
	var tufa := Catalog.hold_type(&"tufa")
	for i: int in count:
		var length := rng.randf_range(1.5, 4.0)
		var bottom_y := rng.randf_range(length + 1.5, wall.size.y - 1.2)
		var span := wall.face_span(bottom_y)
		var p := Vector2(rng.randf_range(span.x + 0.8, span.y - 0.8), bottom_y)
		var line := PackedVector2Array([p])
		while p.y > bottom_y - length:
			p += Vector2(rng.randf_range(-0.05, 0.05), -0.25)
			if not wall.contains(p, FACE_MARGIN):
				break
			line.append(p)
		if line.size() < 4:
			continue
		wall.features.append(RockFeature.make(RockFeature.Kind.TUFA, line, rng.randf_range(0.05, 0.08)))
		for at: Vector2 in _stations(line, rng):
			if not _crowded(wall, at, tufa.radius * 0.5):
				wall.add_hold(tufa, at, deg_to_rad(rng.randfn(0.0, 15.0)))


static func _add_pocket_clusters(wall: Wall, rng: RandomNumberGenerator, count: int) -> void:
	var pocket := Catalog.hold_type(&"pocket")
	var mono := Catalog.hold_type(&"mono")
	for i: int in count:
		var center_y := rng.randf_range(2.0, wall.size.y - 1.5)
		var span := wall.face_span(center_y)
		var center := Vector2(rng.randf_range(span.x + 0.8, span.y - 0.8), center_y)
		for j: int in rng.randi_range(4, 9):
			var at := center + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.5, 0.5))
			var type := mono if rng.randf() < 0.25 else pocket
			if wall.contains(at, FACE_MARGIN) and not _crowded(wall, at, type.radius):
				wall.add_hold(type, at, _tilt(rng))


# --- Scattered holds --------------------------------------------------------------

## Handholds across the whole face, denser in some patches than others, with steep rock getting
## bigger holds.
static func _scatter_holds(wall: Wall, spec: WallSpec, rng: RandomNumberGenerator) -> void:
	var density := FastNoiseLite.new()
	density.seed = rng.randi()
	density.frequency = 1.0 / DENSITY_PATCH
	density.fractal_type = FastNoiseLite.FRACTAL_NONE
	var types: Array[HoldType] = []
	for id: StringName in spec.rock.hold_ids:
		types.append(Catalog.hold_type(id))
	var attempts := roundi(spec.hold_density * _face_area(wall) * (1.0 + DENSITY_SWING))
	for i: int in attempts:
		var at := _random_spot(wall, rng, 0.35, wall.size.y - 0.45)
		if rng.randf() * (1.0 + DENSITY_SWING) > 1.0 + DENSITY_SWING * density.get_noise_2dv(at):
			continue
		var steep := clampf(wall.angle_at(at) / (PI / 4.0), -1.0, 1.0)
		var type := _pick_type(types, spec.rock.hold_weights, steep, rng)
		if _crowded(wall, at, type.radius):
			continue
		wall.add_hold(type, at, _rotation_for(type, rng))


## Foot chips everywhere, and smears on slabs.
static func _scatter_feet(wall: Wall, spec: WallSpec, rng: RandomNumberGenerator) -> void:
	var chip := Catalog.hold_type(&"foot_chip")
	var smear := Catalog.hold_type(&"smear")
	var area := _face_area(wall)
	for i: int in roundi(spec.foot_density * area):
		var at := _random_spot(wall, rng, 0.8, wall.size.y - 0.12)
		if not _crowded(wall, at, chip.radius):
			wall.add_hold(chip, at, deg_to_rad(rng.randfn(0.0, 20.0)))
	for i: int in roundi(spec.smear_density * area):
		var at := _random_spot(wall, rng, 0.8, wall.size.y - 0.12)
		if wall.angle_at(at) < deg_to_rad(SMEAR_MAX_DEGREES) and not _crowded(wall, at, smear.radius * 0.5):
			wall.add_hold(smear, at)


## Steep rock (steep > 0) favors high-grip holds; slabs (steep < 0) favor small ones.
static func _pick_type(types: Array[HoldType], weights: PackedFloat32Array, steep: float, rng: RandomNumberGenerator) -> HoldType:
	var biased := PackedFloat32Array()
	var total := 0.0
	for i: int in types.size():
		var w := weights[i] * exp(STEEP_GRIP_BIAS * steep * (types[i].grip - 0.6))
		biased.append(w)
		total += w
	var roll := rng.randf() * total
	for i: int in types.size():
		roll -= biased[i]
		if roll <= 0.0:
			return types[i]
	return types[types.size() - 1]


static func _pick_id(ids: Array[StringName], weights: PackedFloat32Array, rng: RandomNumberGenerator) -> StringName:
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := rng.randf() * total
	for i: int in ids.size():
		roll -= weights[i]
		if roll <= 0.0:
			return ids[i]
	return ids[ids.size() - 1]


static func _rotation_for(type: HoldType, rng: RandomNumberGenerator) -> float:
	match type.shape:
		HoldType.Shape.PINCH, HoldType.Shape.TUFA:
			return deg_to_rad(rng.randfn(0.0, 18.0))
		HoldType.Shape.FLAKE:
			if rng.randf() < 0.7:
				return (PI / 2.0 if rng.randf() < 0.5 else -PI / 2.0) + deg_to_rad(rng.randfn(0.0, 12.0))
	var roll := rng.randf()
	var shape := type.shape
	var can_undercling := shape == HoldType.Shape.EDGE or shape == HoldType.Shape.JUG or shape == HoldType.Shape.FLAKE
	if can_undercling and roll < UNDERCLING_CHANCE:
		return PI + deg_to_rad(rng.randfn(0.0, 15.0))
	if roll < UNDERCLING_CHANCE + SIDEPULL_CHANCE:
		return (1.0 if rng.randf() < 0.5 else -1.0) * deg_to_rad(rng.randf_range(65.0, 110.0))
	return _tilt(rng)


# --- Making it climbable ----------------------------------------------------------

## Climbs the wall with the test climber, repairing as it goes, until a climb needs no repairs.
static func _make_climbable(wall: Wall, rng: RandomNumberGenerator, shin: float) -> void:
	var def := Catalog.character(&"default")
	var add_hold := func(sim: ClimbSim) -> bool: return _repair_reach(wall, rng, sim)
	var add_rest := func(sim: ClimbSim) -> bool: return _repair_rest(wall, rng, shin, sim)
	for pass_index: int in MAX_PASSES + 1:
		var climb_rng := RandomNumberGenerator.new()
		climb_rng.seed = wall.gen_seed + pass_index
		var repairing := pass_index < MAX_PASSES
		var result := RouteFinder.climb(wall, Climber.from_character(def), climb_rng,
			add_hold if repairing else Callable(), add_rest if repairing else Callable())
		if result.topped_out and result.repairs == 0:
			wall.guide = result.holds
			wall.guide_feet = result.feet
			return
	push_warning("WallGen: seed %d can't be topped out after %d repair passes" % [wall.gen_seed, MAX_PASSES])


## Adds a good hold the climber can reach statically above its higher hand. True if one fit.
static func _repair_reach(wall: Wall, rng: RandomNumberGenerator, sim: ClimbSim) -> bool:
	var c := sim.climber
	if c.hand_count() < 2:
		return false
	_repair_feet(wall, c)
	var left := c.contacts[Climber.Limb.LEFT_HAND]
	var right := c.contacts[Climber.Limb.RIGHT_HAND]
	var top := left if left.position.y <= right.position.y else right
	var inward := 1.0 if top.position.x < wall.size.x * 0.5 else -1.0
	var type := Catalog.hold_type(REPAIR_TYPES[rng.randi_range(0, REPAIR_TYPES.size() - 1)])
	var probe := Hold.new()
	probe.type = type
	probe.rotation = _tilt(rng) * 0.5
	for avoid_crowding: bool in [true, false]:
		for rise: float in REPAIR_RISES:
			for shift: float in REPAIR_SHIFTS:
				probe.position = top.position + Vector2(shift * inward, -rise)
				if not wall.contains(probe.position, FACE_MARGIN):
					continue
				if avoid_crowding and _crowded(wall, probe.position, type.radius * 0.7):
					continue
				for limb: Climber.Limb in Climber.HANDS:
					if c.contacts[limb].position.y - probe.position.y < RouteFinder.MIN_GAIN:
						continue
					if Difficulty.evaluate(c, limb, probe, wall).type == Difficulty.MoveType.STATIC:
						wall.add_hold(type, probe.position, probe.rotation)
						return true
	return false


## Adds a foot chip where each loose foot would ideally stand, so the next stance has feet.
static func _repair_feet(wall: Wall, c: Climber) -> void:
	var chip := Catalog.hold_type(&"foot_chip")
	for foot: Climber.Limb in Climber.FEET:
		if c.contacts[foot] != null:
			continue
		var at := c.root_position(foot) + Vector2(Climber.side_sign(foot) * Tuning.FOOT_IDEAL_SPREAD, c.body.leg_length() * Tuning.FOOT_IDEAL_DROP)
		if wall.contains(at, FACE_MARGIN) and not _crowded(wall, at, chip.radius):
			wall.add_hold(chip, at)


## Adds a knee-bar the climber can use from where it is. True if one fit.
static func _repair_rest(wall: Wall, rng: RandomNumberGenerator, shin: float, sim: ClimbSim) -> bool:
	var c := sim.climber
	var first := 1.0 if rng.randf() < 0.5 else -1.0
	for side: float in [first, -first]:
		var foot := Climber.Limb.RIGHT_FOOT if side > 0.0 else Climber.Limb.LEFT_FOOT
		var knee := c.root_position(foot) + Vector2(side * 0.1, 0.22)
		var foot_at := knee + Vector2(side * 0.03, shin)
		if wall.contains(knee, 0.3) and wall.contains(foot_at, FACE_MARGIN):
			_add_kneebar(wall, knee, foot_at)
			return true
	return false


# --- Helpers ----------------------------------------------------------------------

static func _count(per_25m: Vector2i, rng: RandomNumberGenerator, per_wall: float) -> int:
	return roundi(rng.randi_range(per_25m.x, per_25m.y) * per_wall)


static func _tilt(rng: RandomNumberGenerator) -> float:
	return deg_to_rad(clampf(rng.randfn(0.0, TILT_DEGREES), -40.0, 40.0))


static func _crowded(wall: Wall, at: Vector2, radius: float) -> bool:
	for other: Hold in wall.holds_near(at, radius + 0.4):
		if other.type.shape == HoldType.Shape.SMEAR:
			continue
		if other.position.distance_to(at) < radius + other.type.radius + HOLD_GAP:
			return true
	return false


## A random point on the face between heights `y_min` and `y_max`, at least FACE_MARGIN inside.
static func _random_spot(wall: Wall, rng: RandomNumberGenerator, y_min: float, y_max: float) -> Vector2:
	var y := rng.randf_range(y_min, y_max)
	var span := wall.face_span(y)
	return Vector2(rng.randf_range(span.x + FACE_MARGIN, span.y - FACE_MARGIN), y)


static func _face_area(wall: Wall) -> float:
	var area := 0.0
	for row: int in wall.face_left.size():
		area += (wall.face_right[row] - wall.face_left[row]) * Wall.FACE_CELL
	return area


## Points along `line`, spaced randomly within LINE_SPACING.
static func _stations(line: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var out := PackedVector2Array()
	var next := rng.randf_range(0.05, LINE_SPACING.x)
	var walked := 0.0
	for i: int in range(1, line.size()):
		var a := line[i - 1]
		var b := line[i]
		var seg := a.distance_to(b)
		if seg <= 0.0:
			continue
		while next <= walked + seg:
			out.append(a.lerp(b, (next - walked) / seg))
			next += rng.randf_range(LINE_SPACING.x, LINE_SPACING.y)
		walked += seg
	return out


## Smooth random values in -1..1 along `length` meters, one control point every `spacing` meters.
static func _wave(rng: RandomNumberGenerator, length: float, spacing: float) -> PackedFloat32Array:
	var points := PackedFloat32Array()
	for i: int in ceili(length / spacing) + 2:
		points.append(rng.randf_range(-1.0, 1.0))
	return points


static func _sample(wave: PackedFloat32Array, at: float, spacing: float) -> float:
	var f := at / spacing
	var i := clampi(floori(f), 0, wave.size() - 2)
	var t := clampf(f - i, 0.0, 1.0)
	return lerpf(wave[i], wave[i + 1], t * t * (3.0 - 2.0 * t))
