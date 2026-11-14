class_name HoverHint
extends Node2D
## A small label by the hovered hold: what kind of hold it is, and what each hand would need to
## reach it. Natural holds are harder to read than gym holds, so this names them.

const TEXT := Color(0.97, 0.97, 0.94)
const PANEL := Color(0.0, 0.0, 0.0, 0.6)
const STATIC := Color(0.5, 1.0, 0.6)
const DEADPOINT := Color(1.0, 0.85, 0.35)
const DYNO := Color(1.0, 0.6, 0.4)
const NO := Color(0.72, 0.72, 0.7)
const FONT_SIZE: int = 13

var sim: ClimbSim
var hovered: Hold


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null or hovered == null or sim.is_over():
		return
	var state := sim.climber.state
	if state != Climber.State.CLIMBING and state != Climber.State.RESTING:
		return
	var font := ThemeDB.fallback_font
	var parts: Array[String] = []
	var colors: Array[Color] = []
	for hand: Climber.Limb in Climber.HANDS:
		var r := Difficulty.evaluate(sim.climber, hand, hovered, sim.wall)
		parts.append(("L " if hand == Climber.Limb.LEFT_HAND else "R ") + _verdict(r))
		colors.append(_color(r))
	var gap := 12.0
	var name_width := font.get_string_size(hovered.type.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var hands_width := gap
	for part: String in parts:
		hands_width += font.get_string_size(part, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var line_height := FONT_SIZE + 4.0
	var at := View.px(hovered.position) + Vector2(hovered.type.radius * View.PX_PER_M + 14.0, -line_height)
	draw_rect(Rect2(at - Vector2(6.0, 4.0), Vector2(maxf(name_width, hands_width) + 12.0, line_height * 2.0 + 8.0)), PANEL)
	draw_string(font, at + Vector2(0.0, FONT_SIZE), hovered.type.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, TEXT)
	var x := 0.0
	for i: int in parts.size():
		draw_string(font, at + Vector2(x, FONT_SIZE + line_height), parts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, colors[i])
		x += font.get_string_size(parts[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + gap


static func _verdict(r: MoveResult) -> String:
	match r.type:
		Difficulty.MoveType.STATIC:
			return "reach"
		Difficulty.MoveType.DEADPOINT:
			return "deadpoint"
		Difficulty.MoveType.DYNO:
			return "dyno"
	if r.reason == "already on it":
		return "holding"
	return "no"


static func _color(r: MoveResult) -> Color:
	match r.type:
		Difficulty.MoveType.STATIC:
			return STATIC
		Difficulty.MoveType.DEADPOINT:
			return DEADPOINT
		Difficulty.MoveType.DYNO:
			return DYNO
	return NO
