extends RefCounted
## Small walls, climbers and sims for tests.


## The default character, the same one the game uses.
static func climber() -> Climber:
	return Climber.from_character(Catalog.character(&"default"))


## The default character's body with different stats.
static func climber_from(stats: Stats) -> Climber:
	return Climber.new(BodyDims.from_character(Catalog.character(&"default")), stats)


## A 5 m by 10 m wall at one angle, with a grid of foot chips every 0.3 m up its middle.
static func wall(angle_degrees: float = 0.0) -> Wall:
	var w := Wall.new(Vector2(5.0, 10.0), 0.5)
	w.set_uniform_angle(deg_to_rad(angle_degrees))
	var chip := Catalog.hold_type(&"foot_chip")
	var y := 9.9
	while y > 1.0:
		for x: float in [1.9, 2.5, 3.1]:
			w.add_hold(chip, Vector2(x, y))
		y -= 0.3
	return w


static func hold(w: Wall, type_id: StringName, at: Vector2, rotation_degrees: float = 0.0) -> Hold:
	return w.add_hold(Catalog.hold_type(type_id), at, deg_to_rad(rotation_degrees))


## Hands on `left` and `right`, with the body and feet settled.
static func hang(c: Climber, w: Wall, left: Hold, right: Hold) -> void:
	var contacts: Array[Hold] = [left, right, null, null]
	BodySolver.apply(c, BodySolver.settle(c, w, contacts))


## A sim on `w` that starts with the hands on jugs at (2.2, 6) and (2.8, 6).
static func sim_on(w: Wall, seed_value: int = 1) -> ClimbSim:
	var start: Array[Hold] = [hold(w, &"jug", Vector2(2.2, 6.0)), hold(w, &"jug", Vector2(2.8, 6.0))]
	w.start_holds = start
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return ClimbSim.new(w, climber(), rng)


## Adds jugs straight above `limb`'s hold, 5 cm apart, until one needs a move of type `wanted`.
## Returns that jug, or null if the type never shows up below `top_y`.
static func probe(w: Wall, c: Climber, limb: Climber.Limb, wanted: Difficulty.MoveType, top_y: float = 3.0) -> Hold:
	var from := c.contacts[limb].position
	var y := from.y - 0.1
	while y > top_y:
		var candidate := hold(w, &"jug", Vector2(from.x, y))
		if Difficulty.evaluate(c, limb, candidate, w).type == wanted:
			return candidate
		y -= 0.05
	return null
