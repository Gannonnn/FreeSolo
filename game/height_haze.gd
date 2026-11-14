class_name HeightHaze
extends Node2D
## Haze over the world below the climber once they're high up, so the ground and the lower wall
## fade away as they climb. Purely visual.

## Meters below the climber's hips where the haze starts, and where it's thickest.
const START_BELOW: float = 1.5
const FULL_BELOW: float = 12.0
## How thick (0..1) the haze gets far below a climber who is high up.
const THICKEST: float = 0.6
## Meters of height over which the haze builds up: none near the ground, all of it from the top
## of this range.
const BUILD_FROM: float = 2.0
const BUILD_TO: float = 14.0
## Meters drawn beyond the wall on each side and below the ground, enough for any camera view.
const REACH: float = 200.0

var sim: ClimbSim
## For checking the art: meters down the wall to treat as the climber's height, when set.
var fixed_y: float = NAN


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var climber_y := sim.climber.pelvis.y if is_nan(fixed_y) else fixed_y
	var amount := THICKEST * smoothstep(BUILD_FROM, BUILD_TO, sim.wall.ground_y() - climber_y)
	if amount <= 0.0:
		return
	var clear := Color(Backdrop.HAZE, 0.0)
	var thick := Color(Backdrop.HAZE, amount)
	var left := -REACH
	var right := sim.wall.size.x + REACH
	var top := climber_y + START_BELOW
	var full := climber_y + FULL_BELOW
	draw_primitive(PackedVector2Array([View.px(Vector2(left, top)), View.px(Vector2(right, top)), View.px(Vector2(right, full)), View.px(Vector2(left, full))]),
			PackedColorArray([clear, clear, thick, thick]), PackedVector2Array())
	var bottom := maxf(full, sim.wall.ground_y()) + REACH
	draw_rect(Rect2(View.px(Vector2(left, full)), View.px(Vector2(right - left, bottom - full))), thick)
