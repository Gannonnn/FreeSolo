class_name Hud
extends Control
## Screen-space HUD: stamina, what you can do next, messages, the wall's side profile, the end banner.

const BAR_SIZE := Vector2(320.0, 18.0)
const TEXT := Color(0.95, 0.95, 0.92)
const DIM := Color(0.8, 0.8, 0.78, 0.8)
const PANEL := Color(0.0, 0.0, 0.0, 0.5)
const STAMINA_FULL := Color(0.35, 0.8, 0.45)
const STAMINA_LOW := Color(0.9, 0.3, 0.25)
const PROFILE := Color(0.85, 0.8, 0.7)
const CONTROLS := "LMB / RMB: move left / right hand     Space: hold + release to dyno, tap to catch a deadpoint     E: rest     F1: debug     R: restart"
## Seconds a message stays up.
const MESSAGE_TIME: float = 2.0

var sim: ClimbSim
var seed_label: String = ""
## The wall's name and rock, shown at the top.
var title: String = ""
## True while the camera shows the whole wall before the climb.
var previewing: bool = false
var _message: String = ""
var _message_left: float = 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_message(text: String) -> void:
	_message = text
	_message_left = MESSAGE_TIME


func _process(delta: float) -> void:
	_message_left = maxf(0.0, _message_left - delta)
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if sim == null:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.09, 0.11))
		draw_string(font, Vector2(0.0, size.y * 0.5), "Generating the wall…", HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, TEXT)
		return
	draw_string(font, Vector2(0.0, 30.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, TEXT)
	draw_string(font, Vector2(size.x - 220.0, size.y - 18.0), seed_label, HORIZONTAL_ALIGNMENT_RIGHT, 200, 12, DIM)
	if previewing:
		var band_y := size.y - 110.0
		draw_rect(Rect2(Vector2(0.0, band_y), Vector2(size.x, 48.0)), PANEL)
		draw_string(font, Vector2(0.0, band_y + 32.0), "Click or press any key to start climbing", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, TEXT)
		return
	_draw_stamina(font)
	var status := _status_text()
	if status != "":
		draw_string(font, Vector2(24.0, 122.0), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, TEXT)
	if _message_left > 0.0:
		var alpha := clampf(_message_left / 0.5, 0.0, 1.0)
		draw_string(font, Vector2(0.0, 150.0), _message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(TEXT, alpha))
	_draw_profile(font)
	draw_string(font, Vector2(24.0, size.y - 18.0), CONTROLS, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	_draw_banner(font)


func _draw_stamina(font: Font) -> void:
	var climber := sim.climber
	var share := climber.stamina / climber.max_stamina
	var origin := Vector2(24.0, 24.0)
	draw_rect(Rect2(origin - Vector2(4.0, 4.0), BAR_SIZE + Vector2(8.0, 8.0)), PANEL)
	var fill := STAMINA_LOW.lerp(STAMINA_FULL, clampf(share / 0.5, 0.0, 1.0))
	draw_rect(Rect2(origin, Vector2(BAR_SIZE.x * share, BAR_SIZE.y)), fill)
	if sim.rest != null:
		var cap_x := origin.x + BAR_SIZE.x * sim.rest.ceiling()
		draw_line(Vector2(cap_x, origin.y - 4.0), Vector2(cap_x, origin.y + BAR_SIZE.y + 4.0), TEXT, 2.0)
	var label := "Stamina %d / %d" % [roundi(climber.stamina), roundi(climber.max_stamina)]
	if climber.state == Climber.State.RESTING:
		label += "   recovering"
	elif not sim.is_over() and climber.state != Climber.State.FALLING:
		label += "   drain %.1f/s" % Difficulty.drain_per_second(climber, sim.wall)
	draw_string(font, origin + Vector2(0.0, BAR_SIZE.y + 22.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)
	var high := sim.wall.size.y
	for hand: Climber.Limb in Climber.HANDS:
		high = minf(high, sim.limb_pos[hand].y)
	var height := "Height %.1f m of %d m" % [sim.wall.size.y - high, roundi(sim.wall.size.y)]
	draw_string(font, origin + Vector2(0.0, BAR_SIZE.y + 44.0), height, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)


func _status_text() -> String:
	match sim.climber.state:
		Climber.State.SKILL_CHECK:
			return "Deadpoint! Press Space when the needle is in the white zone"
		Climber.State.DYNO_CHARGE:
			return "Dyno: aim at a hold, release Space inside the green band"
		Climber.State.RESTING:
			return "Resting on the %s, refills to %d%%. E or any move to leave" % [sim.rest.display_name(), roundi(sim.rest.ceiling() * 100.0)]
		Climber.State.CLIMBING:
			var spot := sim.usable_rest()
			if spot != null:
				return "E: rest on the %s (refills to %d%%)" % [spot.display_name(), roundi(spot.ceiling() * 100.0)]
	return ""


## A side view of the wall's angle along its height under the climber, with a dot for the climber.
func _draw_profile(font: Font) -> void:
	var wall := sim.wall
	var top := 90.0
	var bottom := size.y - 60.0
	var px_per_m := (bottom - top) / wall.size.y
	var base_x := size.x - 70.0
	var step := 0.1
	var points := PackedVector2Array([Vector2(base_x, bottom)])
	var marker := Vector2(base_x, bottom)
	var x := 0.0
	var y := wall.size.y
	while y > 0.0:
		var angle := wall.angle_at(Vector2(sim.climber.pelvis.x, y - step * 0.5))
		x -= tan(angle) * step * px_per_m
		y -= step
		var point := Vector2(base_x + x, top + y * px_per_m)
		points.append(point)
		if absf(y - sim.climber.pelvis.y) < step * 0.5:
			marker = point
	draw_polyline(points, PROFILE, 3.0)
	draw_circle(marker + Vector2(-10.0, 0.0), 5.0, ClimberView.SHIRT)
	draw_string(font, Vector2(base_x - 70.0, top - 14.0), "side view", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)


func _draw_banner(font: Font) -> void:
	var text := ""
	match sim.climber.state:
		Climber.State.FALLEN:
			text = "You fell. With no gear placed, that ends the attempt. R to retry"
		Climber.State.TOPPED_OUT:
			text = "Topped out! R to climb again"
		_:
			return
	var band_y := size.y * 0.42
	draw_rect(Rect2(Vector2(0.0, band_y), Vector2(size.x, 56.0)), PANEL)
	draw_string(font, Vector2(0.0, band_y + 37.0), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 24, TEXT)
