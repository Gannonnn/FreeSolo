class_name Tuning
extends RefCounted
## Global tuning numbers. Each comment says what the number changes in play.
## Per-content numbers (a hold's grip, a character's height) live in the .tres files instead.

# --- Simulation ---------------------------------------------------------------

## Seconds per sim step; matches the physics tick rate. Smaller = tighter skill-check timing.
const STEP: float = 1.0 / 60.0

# --- Body proportions (shares of height) ----------------------------------------

## Distance between shoulder joints. Spreads the two hands' reach apart.
const SHOULDER_WIDTH: float = 0.23
## Distance between hip joints. Spreads the two feet apart.
const HIP_WIDTH: float = 0.10
## Hip joint to shoulder joint. A longer torso reaches higher above the feet.
const TORSO: float = 0.29
## Hip to knee. Part of leg length, which limits how high you can stand up.
const THIGH: float = 0.245
## Knee to foot contact. Part of leg length; knee-bars fit when their span is close to it.
const SHIN: float = 0.25
## The grip point sits this share of the way out to the fingertips. Scales arm length, so reach.
const ARM_GRIP_POINT: float = 0.92
## Share of arm length above the elbow. Only changes how arms are drawn.
const UPPER_ARM_SHARE: float = 0.46

# --- Reach ----------------------------------------------------------------------

## Share of arm length usable for a static move. Lower = more moves become deadpoints.
const STATIC_EXTENSION: float = 0.97
## Meters past the static envelope a deadpoint can reach at power 0.
const DEADPOINT_EXTRA: float = 0.12
## Extra deadpoint reach per power level, in meters.
const DEADPOINT_EXTRA_PER_POWER: float = 0.015
## Meters past the static envelope a dyno can reach at power 0, with feet on.
const DYNO_JUMP: float = 0.4
## Extra dyno reach per power level, in meters.
const DYNO_JUMP_PER_POWER: float = 0.06
## With no feet on, dynos only reach this share of the normal distance.
const DYNO_NO_FEET: float = 0.6
## Fully sideways dynos reach this much farther than vertical ones (rockfall dodge).
const DYNO_HORIZONTAL_EXTRA: float = 0.75
## With no feet on, how far the supporting arm can bend (share of arm length) at power 0.
## Limits how high you can pull up to reach.
const LOCKOFF_BASE: float = 0.3
## Extra lock-off per power level.
const LOCKOFF_PER_POWER: float = 0.04
## Lock-off can never go past this share of arm length.
const LOCKOFF_MAX: float = 0.8
## Solver passes when working out how far a hand can reach. More = more accurate, slower.
const REACH_ITERATIONS: int = 10
## Holds with less grip than this are footholds only.
const MIN_HAND_GRIP: float = 0.08

# --- Grip -----------------------------------------------------------------------

## Past a hold's direction tolerance, grip fades to 0 over this many radians (90°).
const GRIP_FALLOFF: float = PI / 2.0
## Each fingers level adds this times the hold's finger_load to its grip.
const FINGERS_GRIP_PER_LEVEL: float = 0.03

# --- Stamina and drain ------------------------------------------------------------

## Stamina pool at endurance 0.
const MAX_STAMINA_BASE: float = 115.0
## Extra stamina pool per endurance level.
const MAX_STAMINA_PER_ENDURANCE: float = 9.2
## Drain per second with all your weight on perfect holds. Hanging on jugs costs about this.
const HANG_DRAIN_BASE: float = 0.6
## Extra drain per second as grip falls to 0 (scales with (1 - grip)²). The main cost of bad holds.
const HANG_DRAIN_POOR: float = 7.0
## Each fingers level divides the poor-hold drain by (1 + this × the hold's finger_load).
const FINGERS_DRAIN_PER_LEVEL: float = 0.06
## Share of body weight a perfect foothold takes off the hands.
const FOOT_SHARE_PER_FOOT: float = 0.32
## Feet never take more than this share of body weight.
const FOOT_SHARE_MAX: float = 0.75
## Each footwork level multiplies the weight on the feet by (1 + this).
const FOOTWORK_SHARE_PER_LEVEL: float = 0.04
## On a 45° slab the feet take this much more weight (0.6 = 60% more).
const SLAB_FOOT_BONUS: float = 0.6
## On a 45° overhang the feet lose this share of their weight, before core.
const OVERHANG_FOOT_LOSS: float = 0.8
## Each core level cancels this much of OVERHANG_FOOT_LOSS.
const CORE_FOOT_KEEP_PER_LEVEL: float = 0.06
## On a 45° slab, hand drain drops by this share.
const SLAB_DRAIN_RELIEF: float = 0.3
## On a 45° overhang, hand drain rises by this share, before core.
const OVERHANG_DRAIN: float = 0.6
## Each core level cancels this much of OVERHANG_DRAIN and MOVE_COST_OVERHANG.
const CORE_ANGLE_PER_LEVEL: float = 0.05

# --- Move costs (stamina per move) ---------------------------------------------------

## Flat cost of any hand move.
const MOVE_COST_BASE: float = 1.0
## Cost per meter the hand travels.
const MOVE_COST_PER_METER: float = 2.0
## Cost multiplier for a static move.
const MOVE_COST_STATIC: float = 1.0
## Cost multiplier for a deadpoint.
const MOVE_COST_DEADPOINT: float = 2.5
## Cost multiplier for a dyno.
const MOVE_COST_DYNO: float = 4.0
## Cost × (1 + this × (1 - grip on the target)). Catching bad holds is expensive.
const MOVE_COST_POOR_TARGET: float = 0.8
## Cost × (1 + this) with no feet on, and half as much extra with one foot.
const MOVE_COST_NO_FEET: float = 0.6
## On a 45° overhang, move cost rises by this share, before core.
const MOVE_COST_OVERHANG: float = 0.6
## Cost × (1 + this × fatigue). Tired moves cost more.
const MOVE_COST_FATIGUE: float = 0.3
## Each footwork level divides static move cost by (1 + this).
const FOOTWORK_STATIC_DISCOUNT: float = 0.04
## Each power level divides deadpoint and dyno cost by (1 + this).
const POWER_BIG_MOVE_DISCOUNT: float = 0.05

# --- Skill checks --------------------------------------------------------------------

## Seconds for the deadpoint needle to sweep the whole dial once.
const DIAL_SWEEP_TIME: float = 1.1
## Earliest point the dial's zone can start, as a share of the sweep.
const DIAL_ZONE_EARLIEST: float = 0.35
## Latest point the dial's zone can start. A wider range makes checks less predictable.
const DIAL_ZONE_LATEST: float = 0.85
## Zone size (share of the dial) for the easiest deadpoint.
const DEADPOINT_WINDOW: float = 0.18
## Band size (share of the meter) for the easiest dyno.
const DYNO_WINDOW: float = 0.32
## Smallest a window can get.
const WINDOW_MIN: float = 0.03
## Biggest a window can get.
const WINDOW_MAX: float = 0.4
## Each power level widens deadpoint and dyno windows by this share.
const WINDOW_POWER_PER_LEVEL: float = 0.05
## At empty stamina, windows shrink by this share.
const WINDOW_FATIGUE: float = 0.4
## The first part of a dial zone (or the middle of a dyno band) that counts as "great".
const GREAT_SHARE: float = 0.25
## A great hit costs this share of the move's stamina.
const GREAT_COST: float = 0.5
## Stamina lost on a missed deadpoint, on top of the move's cost.
const MISSED_DEADPOINT_PENALTY: float = 6.0
## Seconds for the dyno meter to fill; it then sweeps back down and repeats.
const DYNO_CHARGE_TIME: float = 0.9
## Releasing Space below this charge cancels the dyno instead of jumping.
const DYNO_MIN_CHARGE: float = 0.12
## Where the band sits on the meter for the shortest possible dyno.
const DYNO_POWER_MIN: float = 0.3

# --- Move timing (seconds) -------------------------------------------------------------

## Base time a static move takes. Stamina keeps draining while the hand is off.
const STATIC_MOVE_TIME: float = 0.2
## Extra static move time per meter of hand travel.
const STATIC_MOVE_TIME_PER_METER: float = 0.2
## Time to latch (or return to the old hold) after a deadpoint check.
const CATCH_TIME: float = 0.12
## Time in the air during a dyno.
const DYNO_FLIGHT_TIME: float = 0.35
## Time to settle into or out of a rest.
const REST_SETTLE_TIME: float = 0.3

# --- Feet -----------------------------------------------------------------------------

## A foothold can be at most this share of leg length from its hip.
const FOOT_REACH: float = 0.97
## How far above the pelvis a foot can go, in meters. Bigger = higher high-steps.
const FOOT_HIGH_STEP: float = 0.1
## The ideal foot sits this share of leg length below its hip. Lower = feet stay higher = more reach.
const FOOT_IDEAL_DROP: float = 0.4
## The ideal foot sits this many meters out to the side of its hip.
const FOOT_IDEAL_SPREAD: float = 0.12
## Worst foothold quality usable at footwork 0.
const FOOT_MIN_QUALITY: float = 0.2
## Each footwork level lowers FOOT_MIN_QUALITY by this much.
const FOOT_MIN_QUALITY_PER_LEVEL: float = 0.015
## Foothold scoring: weight on the hold's quality. Too high and great footholds win even when
## they're too low, which cuts reach.
const FOOT_SCORE_QUALITY: float = 0.6
## Foothold scoring: penalty per meter away from the ideal spot.
const FOOT_SCORE_DISTANCE: float = 1.5
## Foothold scoring: how many times worse each meter below the ideal spot is than a meter above
## it. Low feet cut reach; high feet only bend the knee more.
const FOOT_SCORE_LOW_WEIGHT: float = 2.0
## Foothold scoring: bonus for the hold the foot is already on, so feet don't fidget.
## Too high and feet lag behind the hands, which cuts reach.
const FOOT_SCORE_KEEP: float = 0.05

# --- Body pose ----------------------------------------------------------------------

## Hanging pose: shoulders sit this share of arm length below the hands. Feet are planned from
## this pose, so lower = higher feet = more reach.
const HANG_ARM_SHARE: float = 0.75
## How far the pelvis shifts sideways toward the feet (0 = under the hands, 1 = over the feet).
const FEET_PULL_X: float = 0.35
## Torso lean toward the hands, as a share of the hands-to-feet angle.
const LEAN_SHARE: float = 0.5
## Torso lean never goes past this many radians.
const LEAN_MAX: float = 0.45
## Legs can't fold tighter than this share of leg length, so high feet push the body up.
const LEG_MIN_FOLD: float = 0.3
## Solver passes when placing the body.
const BODY_ITERATIONS: int = 12

# --- Rests ---------------------------------------------------------------------------

## Knee-bars refill stamina up to this share of max.
const KNEEBAR_CEILING: float = 0.8
## Knee-bar recovery, in stamina per second.
const KNEEBAR_RATE: float = 14.0
## Ledges refill stamina up to this share of max.
const LEDGE_CEILING: float = 1.0
## Ledge recovery, in stamina per second.
const LEDGE_RATE: float = 20.0
## Each endurance level speeds up rest recovery by this share.
const REST_RATE_PER_ENDURANCE: float = 0.05
## A knee-bar fits when its span is within this many meters of your shin length.
const KNEEBAR_FIT: float = 0.08
## A knee-bar's knee spot must be within this share of thigh length from a hip.
const KNEEBAR_HIP_REACH: float = 1.4
## Below this share of stamina, the climber's legs shake.
const LOW_STAMINA: float = 0.3

# --- Falling -------------------------------------------------------------------------

## Meters per second squared.
const GRAVITY: float = 9.8

# --- Generated walls -------------------------------------------------------------------

## Both hands on holds less than this many meters below the top finishes a generated wall.
const TOP_OUT_DEPTH: float = 0.6
## The generator's test climber hangs this many seconds before each move, draining like a player
## looking for the next hold. Higher = the generator adds more rests to each wall.
const GUIDE_THINK_TIME: float = 1.0
## The test climber rests below this share of stamina, and the generator adds a rest where none
## is in reach. Higher = more rests on each wall (0.5 gave a rest every ~2.5 m; 0.35 every ~4 m).
const GUIDE_REST_BELOW: float = 0.35
