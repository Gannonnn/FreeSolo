class_name SkillCheckView
extends Node2D
## Draws the deadpoint dial around its target hold, and the dyno meter beside the climber.

const DIAL_RADIUS: float = 52.0
const RING := Color(0.0, 0.0, 0.0, 0.6)
const ZONE := Color(1.0, 1.0, 1.0, 0.55)
const GREAT := Color(1.0, 1.0, 1.0, 1.0)
const NEEDLE := Color(0.95, 0.2, 0.15)
const BAND := Color(0.3, 0.9, 0.4, 0.8)
const BAND_GREAT := Color(0.65, 1.0, 0.65, 1.0)
const METER_FILL := Color(1.0, 0.85, 0.3)
const TEXT := Color(1.0, 1.0, 1.0)
const METER_HEIGHT: float = 140.0
const METER_WIDTH: float = 16.0

var sim: ClimbSim
var hovered: Hold


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null or sim.check == null:
		return
	if sim.check.kind == SkillCheck.Kind.DEADPOINT and sim.check_target != null:
		_draw_dial(sim.check, View.px(sim.check_target.position))
	elif sim.check.kind == SkillCheck.Kind.DYNO:
		_draw_meter(sim.check)


func _draw_dial(check: SkillCheck, center: Vector2) -> void:
	draw_arc(center, DIAL_RADIUS, 0.0, TAU, 64, RING, 10.0)
	var zone_from := -PI / 2.0 + check.zone_start * TAU
	var zone_to := zone_from + check.zone_size * TAU
	var great_to := zone_from + check.zone_size * Tuning.GREAT_SHARE * TAU
	draw_arc(center, DIAL_RADIUS, zone_from, zone_to, 24, ZONE, 8.0)
	draw_arc(center, DIAL_RADIUS, zone_from, great_to, 8, GREAT, 9.0)
	var dir := Vector2.from_angle(-PI / 2.0 + check.needle() * TAU)
	draw_line(center + dir * DIAL_RADIUS * 0.55, center + dir * (DIAL_RADIUS + 9.0), NEEDLE, 3.0)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-40.0, DIAL_RADIUS + 26.0), "SPACE", HORIZONTAL_ALIGNMENT_CENTER, 80, 14, TEXT)


func _draw_meter(check: SkillCheck) -> void:
	var base := View.px(sim.climber.pelvis) + Vector2(-110.0, 40.0)
	draw_rect(Rect2(base - Vector2(0.0, METER_HEIGHT), Vector2(METER_WIDTH, METER_HEIGHT)), RING)
	var result: MoveResult = null
	if hovered != null:
		result = Difficulty.evaluate_dyno(sim.climber, hovered, sim.wall)
	if result != null and result.is_possible():
		var band_top := base.y - METER_HEIGHT * (result.power + result.window * 0.5)
		draw_rect(Rect2(Vector2(base.x - 4.0, band_top), Vector2(METER_WIDTH + 8.0, METER_HEIGHT * result.window)), BAND)
		var great_height := METER_HEIGHT * result.window * Tuning.GREAT_SHARE
		var great_top := base.y - METER_HEIGHT * result.power - great_height * 0.5
		draw_rect(Rect2(Vector2(base.x - 4.0, great_top), Vector2(METER_WIDTH + 8.0, great_height)), BAND_GREAT)
	else:
		var font := ThemeDB.fallback_font
		draw_string(font, base + Vector2(-30.0, 20.0), "no target", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
	var charge := check.meter()
	draw_rect(Rect2(Vector2(base.x + 3.0, base.y - METER_HEIGHT * charge), Vector2(METER_WIDTH - 6.0, METER_HEIGHT * charge)), METER_FILL)
	var min_y := base.y - METER_HEIGHT * Tuning.DYNO_MIN_CHARGE
	draw_line(Vector2(base.x - 6.0, min_y), Vector2(base.x + METER_WIDTH + 6.0, min_y), TEXT, 1.0)
