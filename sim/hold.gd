class_name Hold
extends RefCounted
## One hold on a wall or arena. Fixed once placed.

## Index into Wall.holds.
var id: int = -1
var type: HoldType
## Meters, wall space.
var position: Vector2
## Radians. 0 faces up (crimp), PI/2 faces right (sidepull), PI faces down (undercling).
var rotation: float = 0.0
## Money on this hold (Milestone 3).
var coins: int = 0
## Meant to be easy to miss: same climbing rules, but drawn to blend into the rock (look later).
var hard_to_spot: bool = false


## Normal of the gripping surface. The ideal pull is the opposite way.
func facing() -> Vector2:
	return Vector2.UP.rotated(rotation)


func is_handhold() -> bool:
	return type.grip >= Tuning.MIN_HAND_GRIP


func is_foothold() -> bool:
	return type.foot_quality > 0.0
