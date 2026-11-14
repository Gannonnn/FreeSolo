class_name RestSpot
extends RefCounted
## A place to recover stamina with E. Jugs aren't rests; they only drain less.

enum Kind { KNEEBAR, LEDGE }

var kind: Kind
## Knee-bar: where the knee jams. Ledge: the ledge itself.
var position: Vector2
## The foothold you brace or stand on. For a ledge, the ledge hold.
var foot_hold: Hold
## Knee-bar only: foot-to-knee distance. It fits when this is close to your shin length.
var span: float = 0.0


static func kneebar(knee_at: Vector2, foot: Hold) -> RestSpot:
	var spot := RestSpot.new()
	spot.kind = Kind.KNEEBAR
	spot.position = knee_at
	spot.foot_hold = foot
	spot.span = knee_at.distance_to(foot.position)
	return spot


static func ledge(ledge_hold: Hold) -> RestSpot:
	var spot := RestSpot.new()
	spot.kind = Kind.LEDGE
	spot.position = ledge_hold.position
	spot.foot_hold = ledge_hold
	return spot


func fits(body: BodyDims) -> bool:
	return kind != Kind.KNEEBAR or absf(span - body.shin) <= Tuning.KNEEBAR_FIT


## Share of max stamina this rest refills to.
func ceiling() -> float:
	return Tuning.KNEEBAR_CEILING if kind == Kind.KNEEBAR else Tuning.LEDGE_CEILING


## Stamina recovered per second.
func rate(stats: Stats) -> float:
	var base := Tuning.KNEEBAR_RATE if kind == Kind.KNEEBAR else Tuning.LEDGE_RATE
	return base * (1.0 + Tuning.REST_RATE_PER_ENDURANCE * stats.endurance)


func display_name() -> String:
	return "knee-bar" if kind == Kind.KNEEBAR else "ledge"
