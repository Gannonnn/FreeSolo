class_name Stats
extends Resource
## The five trainable stats as integer levels. The same type holds a climber's levels,
## a relic's deltas and caps, and a boss's profile. Tuning maps levels to multipliers.

enum Kind { FINGERS, POWER, ENDURANCE, CORE, FOOTWORK }

## Poor holds: less drain and more grip on crimps, pockets and slopers.
@export var fingers: int = 0
## Big moves: longer deadpoint and dyno range, wider windows, cheaper big moves.
@export var power: int = 0
## Bigger stamina pool and faster rest recovery.
@export var endurance: int = 0
## Steep rock: feet keep more weight on overhangs, and the wall angle drains less.
@export var core: int = 0
## Feet take more weight (less hand drain), can use worse footholds, cheaper static moves.
@export var footwork: int = 0


static func uniform(level: int) -> Stats:
	var s := Stats.new()
	s.fingers = level
	s.power = level
	s.endurance = level
	s.core = level
	s.footwork = level
	return s


func get_level(kind: Kind) -> int:
	match kind:
		Kind.FINGERS:
			return fingers
		Kind.POWER:
			return power
		Kind.ENDURANCE:
			return endurance
		Kind.CORE:
			return core
		_:
			return footwork


func plus(other: Stats) -> Stats:
	var s := Stats.new()
	s.fingers = fingers + other.fingers
	s.power = power + other.power
	s.endurance = endurance + other.endurance
	s.core = core + other.core
	s.footwork = footwork + other.footwork
	return s


func clamped_to(caps: Stats) -> Stats:
	var s := Stats.new()
	s.fingers = clampi(fingers, 0, caps.fingers)
	s.power = clampi(power, 0, caps.power)
	s.endurance = clampi(endurance, 0, caps.endurance)
	s.core = clampi(core, 0, caps.core)
	s.footwork = clampi(footwork, 0, caps.footwork)
	return s
