class_name MoveResult
extends RefCounted
## What Difficulty says about one hand move.

var type: Difficulty.MoveType = Difficulty.MoveType.IMPOSSIBLE
## The hand making the move. For a dyno, the hand that catches.
var limb: Climber.Limb = Climber.Limb.LEFT_HAND
var stamina_cost: float = 0.0
## 0..1 share of the skill check that counts as a hit. 1 for static moves (no check).
var window: float = 0.0
## Dyno only: where the band sits on the charge meter, 0..1.
var power: float = 0.0
## Shoulder-to-target distance ÷ arm length, after the body shifts as far as it can.
var reach_ratio: float = 0.0
## Meters past the static envelope; 0 for static moves.
var excess: float = 0.0
## 1 = pulling straight against the hold's facing, -1 = pulling the wrong way entirely.
var pull_alignment: float = 0.0
## Grip on the target from the end position, after rotation and the fingers stat.
var grip: float = 0.0
## Why the move is impossible, for the debug overlay and HUD.
var reason: String = ""


func is_possible() -> bool:
	return type != Difficulty.MoveType.IMPOSSIBLE
