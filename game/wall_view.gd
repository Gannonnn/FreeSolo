class_name WallView
extends Node2D
## Marks drawn over the rock: the hovered hold, rest spots near the climber, and the top-out line.

const HOVER := Color(1, 1, 1, 0.95)
const HOVER_SHADOW := Color(0, 0, 0, 0.5)
const TOP_LINE := Color(1, 1, 1, 0.5)
const REST_LABEL := Color(0.8, 1.0, 0.8, 0.9)
const LABEL_SHADOW := Color(0, 0, 0, 0.7)
## Rest spots within this many meters (up or down) of the climber get a label.
const REST_LABEL_RANGE: float = 3.5

var sim: ClimbSim
var _hovered: Hold


func set_hovered(hold: Hold) -> void:
	_hovered = hold


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var wall := sim.wall
	var font := ThemeDB.fallback_font
	var span := wall.face_span(wall.top_out_y)
	var left := View.px(Vector2(span.x, wall.top_out_y))
	draw_dashed_line(left, View.px(Vector2(span.y, wall.top_out_y)), TOP_LINE, 2.0, 12.0)
	_label(font, left + Vector2(8.0, -8.0), "TOP", TOP_LINE)
	for spot: RestSpot in wall.rests:
		if absf(spot.position.y - sim.climber.pelvis.y) > REST_LABEL_RANGE:
			continue
		var at := View.px(spot.position)
		if spot.kind == RestSpot.Kind.KNEEBAR:
			draw_arc(at, 7.0, 0.0, TAU, 16, REST_LABEL, 1.5)
			_label(font, at + Vector2(-24.0, 22.0), "knee-bar", REST_LABEL)
		else:
			_label(font, at + Vector2(-14.0, -16.0), "ledge", REST_LABEL)
	if _hovered != null:
		var center := View.px(_hovered.position)
		var radius := _hovered.type.radius * View.PX_PER_M + 6.0
		draw_arc(center, radius + 1.0, 0.0, TAU, 32, HOVER_SHADOW, 4.0)
		draw_arc(center, radius, 0.0, TAU, 32, HOVER, 2.0)


func _label(font: Font, at: Vector2, text: String, color: Color) -> void:
	draw_string(font, at + Vector2(1.0, 1.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL_SHADOW)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
