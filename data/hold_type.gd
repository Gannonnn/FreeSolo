class_name HoldType
extends Resource
## A kind of hold: a natural rock feature (edge, pocket, crack, flake…) or a foot-only spot.

## How the hold is carved into the rock. The numbers are saved in the .tres files, so only append.
## SMEAR draws nothing: smears and the ground are plain rock or dirt you can stand on.
enum Shape { JUG, EDGE, SLOPER, PINCH, POCKET, CHIP, LEDGE, FLAKE, CRACK, HORN, SMEAR, TUFA }

@export var id: StringName
@export var display_name: String
@export var shape: Shape = Shape.EDGE
## Grip when pulled straight against the hold's facing (0 = glass, 1 = bucket).
## Affects per-second hand drain, the cost of moving onto it, and skill-check window size.
@export_range(0.0, 1.0, 0.01) var grip: float = 0.5
## How far off-axis the pull can be before grip starts to fade. Pinches are forgiving, slopers aren't.
@export_range(0.0, 180.0, 1.0, "radians_as_degrees") var direction_tolerance: float = PI / 4.0
## How much the fingers stat matters on this hold (pockets ~1, jugs ~0.1).
@export_range(0.0, 1.0, 0.01) var finger_load: float = 0.5
## How much weight a foot here takes off the hands. 0 = hands only.
@export_range(0.0, 1.0, 0.01) var foot_quality: float = 0.3
## Two hands, or two feet, can share it.
@export var matchable: bool = false
## Meters. Carved size, and how close the cursor must be to pick it.
@export_range(0.02, 0.6, 0.01) var radius: float = 0.05
## Rack shop price (boss milestone).
@export var price: int = 0
## Plastic color if it's ever used as a gym hold on the boss wall. Natural rock ignores it.
@export var color: Color = Color(0.8, 0.8, 0.8)
