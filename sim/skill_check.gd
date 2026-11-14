class_name SkillCheck
extends RefCounted
## Timing checks for big moves.
## Deadpoint: a Dead by Daylight-style dial. The needle sweeps around once; press Space while it's
## inside the zone. The first part of the zone is "great".
## Dyno: holding Space fills a meter that sweeps up and down; release inside the band.

enum Kind { DEADPOINT, DYNO }
enum Result { MISS, GOOD, GREAT }

var kind: Kind
## Seconds for one sweep of the dial, or one fill of the meter.
var duration: float
var elapsed: float = 0.0
## Deadpoint only: where the zone starts, 0..1 around the dial.
var zone_start: float = 0.0
## Deadpoint only: zone size, which is the move's window.
var zone_size: float = 0.0


static func deadpoint(window: float, rng: RandomNumberGenerator) -> SkillCheck:
	var check := SkillCheck.new()
	check.kind = Kind.DEADPOINT
	check.duration = Tuning.DIAL_SWEEP_TIME
	check.zone_size = window
	check.zone_start = rng.randf_range(Tuning.DIAL_ZONE_EARLIEST, minf(Tuning.DIAL_ZONE_LATEST, 1.0 - window))
	return check


static func dyno_meter() -> SkillCheck:
	var check := SkillCheck.new()
	check.kind = Kind.DYNO
	check.duration = Tuning.DYNO_CHARGE_TIME
	return check


## Deadpoint: how far round the dial the needle is, 0..1.
func needle() -> float:
	return elapsed / duration


## Dyno: the current charge, sweeping 0 → 1 → 0.
func meter() -> float:
	return pingpong(elapsed / duration, 1.0)


func is_past_zone() -> bool:
	return needle() > zone_start + zone_size


func judge_dial() -> Result:
	var at := needle()
	if at < zone_start or at > zone_start + zone_size:
		return Result.MISS
	if at <= zone_start + zone_size * Tuning.GREAT_SHARE:
		return Result.GREAT
	return Result.GOOD


## Dyno: the band is centered on the power the jump needs; its middle is "great".
static func judge_band(charge: float, power: float, window: float) -> Result:
	var off := absf(charge - power)
	if off > window * 0.5:
		return Result.MISS
	if off <= window * Tuning.GREAT_SHARE * 0.5:
		return Result.GREAT
	return Result.GOOD
