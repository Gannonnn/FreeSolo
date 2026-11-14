class_name Climber
extends RefCounted
## One climber on one wall: the player, or either side of a boss fight.
## Changed only by ClimbSim (or by the boss AI, on a copy). The renderer only reads it.

enum Limb { LEFT_HAND, RIGHT_HAND, LEFT_FOOT, RIGHT_FOOT }
enum State { CLIMBING, MOVING, SKILL_CHECK, DYNO_CHARGE, RESTING, FALLING, FALLEN, TOPPED_OUT }

const LIMBS: Array[Limb] = [Limb.LEFT_HAND, Limb.RIGHT_HAND, Limb.LEFT_FOOT, Limb.RIGHT_FOOT]
const HANDS: Array[Limb] = [Limb.LEFT_HAND, Limb.RIGHT_HAND]
const FEET: Array[Limb] = [Limb.LEFT_FOOT, Limb.RIGHT_FOOT]

var body: BodyDims
## Effective levels, with upgrades and relics already applied.
var stats: Stats
var rules: Array[Relic.Rule] = []
var max_stamina: float
## Drains per second and per move. At 0 you fall.
var stamina: float
## Indexed by Limb. null means that limb is off the wall.
var contacts: Array[Hold] = [null, null, null, null]
## Meters, wall space. Placed by BodySolver from the contacts.
var pelvis: Vector2 = Vector2.ZERO
## In-plane torso tilt, in radians.
var lean: float = 0.0
var state: State = State.CLIMBING
## Protection pieces carried (Milestone 3).
var gear_left: int = 0


func _init(dims: BodyDims, levels: Stats) -> void:
	body = dims
	stats = levels
	max_stamina = Tuning.MAX_STAMINA_BASE + Tuning.MAX_STAMINA_PER_ENDURANCE * levels.endurance
	stamina = max_stamina


static func from_character(def: CharacterDef) -> Climber:
	var climber := Climber.new(BodyDims.from_character(def), def.starting_stats.duplicate() as Stats)
	climber.gear_left = def.starting_gear
	return climber


static func is_hand(limb: Limb) -> bool:
	return limb == Limb.LEFT_HAND or limb == Limb.RIGHT_HAND


static func other_hand(limb: Limb) -> Limb:
	return Limb.RIGHT_HAND if limb == Limb.LEFT_HAND else Limb.LEFT_HAND


## -1 for left limbs, +1 for right limbs.
static func side_sign(limb: Limb) -> float:
	return -1.0 if limb == Limb.LEFT_HAND or limb == Limb.LEFT_FOOT else 1.0


## 0 fresh, 1 empty. An input to the difficulty model.
func fatigue() -> float:
	return 1.0 - stamina / max_stamina


func has_rule(rule: Relic.Rule) -> bool:
	return rules.has(rule)


func hand_count() -> int:
	return int(contacts[Limb.LEFT_HAND] != null) + int(contacts[Limb.RIGHT_HAND] != null)


func foot_count() -> int:
	return int(contacts[Limb.LEFT_FOOT] != null) + int(contacts[Limb.RIGHT_FOOT] != null)


func limb_length(limb: Limb) -> float:
	return body.arm_length() if is_hand(limb) else body.leg_length()


## Where `limb`'s root joint (shoulder or hip) sits relative to the pelvis, for a torso lean.
func root_offset(limb: Limb, at_lean: float) -> Vector2:
	var up := Vector2.UP.rotated(at_lean)
	var right := up.rotated(PI / 2.0)
	var side := side_sign(limb)
	if is_hand(limb):
		return up * body.torso + right * (side * body.shoulder_width * 0.5)
	return right * (side * body.hip_width * 0.5)


func root_position(limb: Limb) -> Vector2:
	return pelvis + root_offset(limb, lean)


func up_axis() -> Vector2:
	return Vector2.UP.rotated(lean)


## A cheap copy for boss AI lookahead. Body and stats are shared; they don't change mid-climb.
func copy() -> Climber:
	var c := Climber.new(body, stats)
	c.rules = rules.duplicate()
	c.max_stamina = max_stamina
	c.stamina = stamina
	c.contacts = contacts.duplicate()
	c.pelvis = pelvis
	c.lean = lean
	c.state = state
	c.gear_left = gear_left
	return c
