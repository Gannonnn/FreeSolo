class_name View
extends RefCounted
## The drawing scale: the one place that converts sim meters to screen pixels.

const PX_PER_M: float = 100.0


static func px(meters: Vector2) -> Vector2:
	return meters * PX_PER_M


static func to_meters(pixels: Vector2) -> Vector2:
	return pixels / PX_PER_M
