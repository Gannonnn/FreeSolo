class_name CameraRig
extends Camera2D
## Shows the whole wall first (the preview), flies in to the climber, then follows them.

signal preview_finished

## How quickly the camera catches up, per second.
const FOLLOW_RATE: float = 4.0
## Meters above the pelvis the camera centers on, so more of the wall ahead is visible.
const LOOK_AHEAD: float = 0.8
## Seconds the preview holds on the whole wall before flying in.
const PREVIEW_HOLD: float = 5.0
## Seconds the fly-in from the whole wall to the climber takes.
const PREVIEW_FLY: float = 1.6
## Pixels of landscape kept around the wall in the preview, at full zoom.
const PREVIEW_PADDING: float = 140.0
## Pixels the follow view may show past the wall's sides, top and bottom.
const SIDE_ROOM: float = 160.0
const TOP_ROOM: float = 200.0
const BOTTOM_ROOM: float = 120.0

var sim: ClimbSim
var previewing: bool = false
## For checking the art: when z > 0, the camera stays at meters (x, y) with zoom z.
var fixed_view: Vector3 = Vector3.ZERO
var _preview_time: float = 0.0
## Where the follow view is, before rounding to screen pixels.
var _follow: Vector2 = Vector2.ZERO


func _ready() -> void:
	make_current()


func start_preview() -> void:
	previewing = true
	_preview_time = 0.0
	_apply_preview(0.0)


## Skips the rest of the hold and starts the fly-in now.
func skip_preview() -> void:
	if previewing:
		_preview_time = maxf(_preview_time, PREVIEW_HOLD)


func snap() -> void:
	zoom = Vector2.ONE
	_follow = follow_target()
	position = _on_screen_pixels(_follow)


## Where the camera sits when following the climber.
func follow_target() -> Vector2:
	var wall_px := View.px(sim.wall.size)
	var half := get_viewport_rect().size * 0.5
	var pelvis := View.px(sim.climber.pelvis)
	var x := wall_px.x * 0.5
	if wall_px.x + SIDE_ROOM * 2.0 > half.x * 2.0:
		x = clampf(pelvis.x, half.x - SIDE_ROOM, wall_px.x + SIDE_ROOM - half.x)
	var y := clampf(pelvis.y - LOOK_AHEAD * View.PX_PER_M, half.y - TOP_ROOM, wall_px.y + BOTTOM_ROOM - half.y)
	return Vector2(x, y)


func _process(delta: float) -> void:
	if sim == null:
		return
	if fixed_view.z > 0.0:
		position = View.px(Vector2(fixed_view.x, fixed_view.y))
		zoom = Vector2.ONE * fixed_view.z
		return
	if previewing:
		_preview_time += delta
		var fly := clampf((_preview_time - PREVIEW_HOLD) / PREVIEW_FLY, 0.0, 1.0)
		_apply_preview(fly)
		if fly >= 1.0:
			previewing = false
			preview_finished.emit()
		return
	_follow = _follow.lerp(follow_target(), 1.0 - exp(-FOLLOW_RATE * delta))
	position = _on_screen_pixels(_follow)


func _apply_preview(fly: float) -> void:
	var eased := fly * fly * (3.0 - 2.0 * fly)
	var view := get_viewport_rect().size
	var wall_px := View.px(sim.wall.size)
	var overview := minf(view.y / (wall_px.y + PREVIEW_PADDING * 2.0), view.x / (wall_px.x + PREVIEW_PADDING * 2.0))
	zoom = Vector2.ONE * exp(lerpf(log(overview), 0.0, eased))
	position = (wall_px * 0.5).lerp(follow_target(), eased)
	_follow = position


## The lit rock is a texture with one texel per screen pixel, and it only looks sharp while those
## line up; between pixels it is resampled and softens. At zoom 1 this keeps them lined up.
func _on_screen_pixels(at: Vector2) -> Vector2:
	var density := get_viewport().get_final_transform().get_scale().x
	var half := get_viewport_rect().size * 0.5
	return half - ((half - at) * density).round() / density
