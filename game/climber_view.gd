class_name ClimberView
extends Node2D
## Draws the climber with two-bone IK from each shoulder and hip to its hand or foot.

const SKIN := Color(0.93, 0.76, 0.6)
const SHIRT := Color(0.82, 0.24, 0.22)
const PANTS := Color(0.2, 0.25, 0.42)
const SHOE := Color(0.12, 0.12, 0.13)
const CHALK := Color(0.96, 0.96, 0.94)
const HAIR := Color(0.25, 0.17, 0.1)
const SHADOW_COLOR := Color(0.0, 0.0, 0.0)
## Meters. Limb thickness when drawn.
const LIMB_WIDTH: float = 0.07
## Meters of knee wobble at empty stamina.
const SHAKE_MAX: float = 0.03
## Meters the body sinks at full dyno charge.
const DYNO_CROUCH: float = 0.08
## Meters the hips and chest stand off the rock, which sets how far their shadow falls from them.
const SHADOW_DEPTH: float = 0.28
## Extra stand-off at full overhang (scaled by the sine of the angle): on a roof the body hangs out.
const SHADOW_DEPTH_STEEP: float = 0.25
## How far each part stands off the rock, as a share of the body's stand-off. Hands and feet on
## holds touch the rock, so their shadows meet them.
const LIFT_HEAD: float = 1.2
const LIFT_ELBOW: float = 0.55
const LIFT_KNEE: float = 0.6
## A hand or foot that isn't on a hold.
const LIFT_FREE: float = 0.7
## Falling, the whole body comes away from the rock.
const LIFT_FALLING: float = 1.6

var sim: ClimbSim
## Draw a flat silhouette where the climber's shadow falls on the rock, instead of the climber.
## Put it in a CanvasGroup so the whole shadow gets one even, soft transparency.
var shadow: bool = false
## Meters from a body part at full stand-off to its shadow. Zero when drawing the climber.
var _shift := Vector2.ZERO
var _off_wall: bool = false


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var climber := sim.climber
	var body := climber.body
	_shift = _shadow_shift() if shadow else Vector2.ZERO
	_off_wall = climber.state == Climber.State.FALLING or climber.state == Climber.State.FALLEN
	var pelvis := climber.pelvis
	if climber.state == Climber.State.DYNO_CHARGE and sim.check != null:
		pelvis.y += sim.check.meter() * DYNO_CROUCH
	var lean := climber.lean
	var up := Vector2.UP.rotated(lean)
	var right := up.rotated(PI / 2.0)
	var shake := _shake_amount(climber)
	var t := Time.get_ticks_msec() / 1000.0
	var width := LIMB_WIDTH * View.PX_PER_M

	for foot: Climber.Limb in Climber.FEET:
		var hip := pelvis + climber.root_offset(foot, lean)
		var end := sim.limb_pos[foot]
		var knee := IK.solve(hip, end, body.thigh, body.shin, Climber.side_sign(foot), -0.5)
		var knee_lift := LIFT_KNEE
		if sim.knee_limb == foot and sim.rest != null:
			knee = sim.rest.position
			knee_lift = 0.0
		else:
			var phase := 0.0 if foot == Climber.Limb.LEFT_FOOT else 2.1
			knee += Vector2(sin(t * 41.0 + phase), cos(t * 33.0 + phase * 1.3)) * shake
		hip = _lift(hip, 1.0)
		knee = _lift(knee, knee_lift)
		end = _lift(end, 0.0 if climber.contacts[foot] != null else LIFT_FREE)
		_segment(hip, knee, PANTS, width * 1.15)
		_segment(knee, end, PANTS, width)
		draw_circle(View.px(end), width * 0.75, _tint(SHOE))

	var neck := pelvis + up * body.torso
	var torso := PackedVector2Array([
		View.px(_lift(neck - right * body.shoulder_width * 0.55, 1.0)),
		View.px(_lift(neck + right * body.shoulder_width * 0.55, 1.0)),
		View.px(_lift(pelvis + right * body.hip_width * 0.8, 1.0)),
		View.px(_lift(pelvis - right * body.hip_width * 0.8, 1.0)),
	])
	draw_colored_polygon(torso, _tint(SHIRT))
	var head_radius := body.height * 0.06
	draw_circle(View.px(_lift(neck + up * head_radius * 1.25, LIFT_HEAD)), head_radius * View.PX_PER_M, _tint(HAIR))

	for hand: Climber.Limb in Climber.HANDS:
		var shoulder := pelvis + climber.root_offset(hand, lean)
		var end := sim.limb_pos[hand]
		var elbow := IK.solve(shoulder, end, body.upper_arm, body.forearm, Climber.side_sign(hand), 0.5)
		shoulder = _lift(shoulder, 1.0)
		elbow = _lift(elbow, LIFT_ELBOW)
		end = _lift(end, 0.0 if climber.contacts[hand] != null else LIFT_FREE)
		_segment(shoulder, elbow, SHIRT, width * 1.05)
		_segment(elbow, end, SKIN, width * 0.9)
		draw_circle(View.px(end), width * 0.6, _tint(CHALK))


func _segment(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var c := _tint(color)
	draw_line(View.px(a), View.px(b), c, width)
	draw_circle(View.px(a), width * 0.5, c)
	draw_circle(View.px(b), width * 0.5, c)


func _tint(color: Color) -> Color:
	return SHADOW_COLOR if shadow else color


## Where a body part's shadow falls, for a part standing `lift` times the body's stand-off from
## the rock. Returns `p` unchanged when drawing the climber.
func _lift(p: Vector2, lift: float) -> Vector2:
	return p + _shift * (LIFT_FALLING if _off_wall else lift)


## Meters from a body part at full stand-off to its shadow, cast away from the sun.
func _shadow_shift() -> Vector2:
	var angle := sim.wall.angle_at(sim.climber.pelvis)
	var depth := SHADOW_DEPTH + SHADOW_DEPTH_STEEP * maxf(0.0, sin(angle))
	var sun := RockRelief.SUN
	return Vector2(-sun.x, -sun.y) / sun.z * depth


func _shake_amount(climber: Climber) -> float:
	if climber.state == Climber.State.FALLING or climber.state == Climber.State.FALLEN:
		return 0.0
	var share := climber.stamina / climber.max_stamina
	if share >= Tuning.LOW_STAMINA:
		return 0.0
	return SHAKE_MAX * (1.0 - share / Tuning.LOW_STAMINA)
