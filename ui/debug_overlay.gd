class_name DebugOverlay
extends Node2D
## F1 overlay: the generator's proven line, reach envelopes for both hands, and the full difficulty
## breakdown for the hovered hold.

const SEGMENTS: int = 40
const STATIC_LINE := Color(0.4, 1.0, 0.5, 0.9)
const DEADPOINT_LINE := Color(1.0, 0.85, 0.3, 0.85)
const DYNO_LINE := Color(1.0, 0.4, 0.35, 0.7)
const FACING_LINE := Color(1.0, 1.0, 1.0, 0.9)
const GUIDE_LINE := Color(0.3, 0.85, 1.0, 0.7)
const GUIDE_FOOT := Color(0.3, 0.85, 1.0, 0.5)
const PANEL := Color(0.0, 0.0, 0.0, 0.72)
const TEXT := Color(0.95, 0.95, 0.9)
const FONT_SIZE: int = 13

var sim: ClimbSim
var hovered: Hold
## Per hand: static, deadpoint and dyno outlines, in pixels.
var _envelopes: Array[PackedVector2Array] = []
var _envelope_key: String = ""


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	_draw_guide()
	_refresh_envelopes()
	var colors: Array[Color] = [STATIC_LINE, DEADPOINT_LINE, DYNO_LINE]
	for i: int in _envelopes.size():
		draw_polyline(_envelopes[i], colors[i % 3], 2.0 if i % 3 == 0 else 1.5)
	_draw_climber_info()
	if hovered != null:
		var at := View.px(hovered.position)
		draw_line(at, at + hovered.facing() * 26.0, FACING_LINE, 2.0)
		_draw_hold_info(hovered)


## The hand moves the generator's test climber made to the top, and the feet it used.
func _draw_guide() -> void:
	var points := PackedVector2Array()
	for hold: Hold in sim.wall.guide:
		points.append(View.px(hold.position))
	if points.size() > 1:
		draw_polyline(points, GUIDE_LINE, 2.0)
	for hold: Hold in sim.wall.guide_feet:
		draw_circle(View.px(hold.position), 4.0, GUIDE_FOOT)


func _refresh_envelopes() -> void:
	var climber := sim.climber
	if climber.state != Climber.State.CLIMBING and climber.state != Climber.State.RESTING:
		_envelopes.clear()
		_envelope_key = ""
		return
	var key := "%s %s" % [climber.pelvis, climber.lean]
	for hold: Hold in climber.contacts:
		key += " %d" % (hold.id if hold != null else -1)
	if key == _envelope_key:
		return
	_envelope_key = key
	_envelopes.clear()
	var extras: Array[float] = [0.0, Difficulty.deadpoint_extra(climber.stats), Difficulty.dyno_jump(climber)]
	for hand: Climber.Limb in Climber.HANDS:
		for extra: float in extras:
			var outline := Difficulty.reach_envelope(climber, hand, extra, SEGMENTS)
			var points := PackedVector2Array()
			for p: Vector2 in outline:
				points.append(View.px(p))
			points.append(points[0])
			_envelopes.append(points)


func _draw_climber_info() -> void:
	var climber := sim.climber
	var lines := PackedStringArray()
	lines.append("state %s" % str(Climber.State.find_key(climber.state)).to_lower())
	lines.append("stamina %.1f / %.0f   fatigue %.2f" % [climber.stamina, climber.max_stamina, climber.fatigue()])
	var angle := sim.wall.angle_at(climber.pelvis)
	lines.append("drain %.2f/s   feet carry %d%%" % [Difficulty.drain_per_second(climber, sim.wall), roundi(Difficulty.foot_share(climber, angle) * 100.0)])
	lines.append("wall here: %s" % _angle_text(angle))
	lines.append("arm %.2f m   leg %.2f m   shin %.2f m" % [climber.body.arm_length(), climber.body.leg_length(), climber.body.shin])
	lines.append("green static / yellow deadpoint / red dyno")
	_text_box(get_canvas_transform().affine_inverse() * Vector2(24.0, 140.0), lines)


func _draw_hold_info(hold: Hold) -> void:
	var climber := sim.climber
	var t := hold.type
	var lines := PackedStringArray()
	lines.append("%s   facing %d°   %s" % [t.display_name, roundi(rad_to_deg(hold.rotation)), _angle_text(sim.wall.angle_at(hold.position))])
	lines.append("grip %.2f   tolerance %d°   finger load %.1f   foot %.2f" % [t.grip, roundi(rad_to_deg(t.direction_tolerance)), t.finger_load, t.foot_quality])
	for hand: Climber.Limb in Climber.HANDS:
		var hand_name := "L hand" if hand == Climber.Limb.LEFT_HAND else "R hand"
		var r := Difficulty.evaluate(climber, hand, hold, sim.wall)
		if r.is_possible():
			lines.append("%s: %s   cost %.1f   window %.2f   reach %.2f   pull %.2f   grip %.2f" % [
				hand_name, _type_name(r.type), r.stamina_cost, r.window, r.reach_ratio, r.pull_alignment, r.grip])
		else:
			lines.append("%s: %s" % [hand_name, r.reason])
	var dyno := Difficulty.evaluate_dyno(climber, hold, sim.wall)
	if dyno.is_possible():
		var catcher := "L" if dyno.limb == Climber.Limb.LEFT_HAND else "R"
		lines.append("dyno (%s catches): power %.2f   band %.2f   cost %.1f" % [catcher, dyno.power, dyno.window, dyno.stamina_cost])
	else:
		lines.append("dyno: %s" % dyno.reason)
	_text_box(View.px(hold.position) + Vector2(26.0, -10.0), lines)


func _text_box(top_left: Vector2, lines: PackedStringArray) -> void:
	var font := ThemeDB.fallback_font
	var line_height := FONT_SIZE + 4
	var width := 0.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x)
	draw_rect(Rect2(top_left - Vector2(6.0, 4.0), Vector2(width + 12.0, line_height * lines.size() + 8.0)), PANEL)
	for i: int in lines.size():
		draw_string(font, top_left + Vector2(0.0, FONT_SIZE + i * line_height), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)


static func _type_name(type: Difficulty.MoveType) -> String:
	match type:
		Difficulty.MoveType.STATIC:
			return "static"
		Difficulty.MoveType.DEADPOINT:
			return "DEADPOINT"
		Difficulty.MoveType.DYNO:
			return "needs a dyno"
	return "impossible"


static func _angle_text(angle: float) -> String:
	var degrees := roundi(rad_to_deg(angle))
	if degrees < 0:
		return "%d° slab" % -degrees
	if degrees > 0:
		return "%d° overhang" % degrees
	return "vertical"
