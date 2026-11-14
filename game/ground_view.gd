class_name GroundView
extends Node2D
## The ground at the foot of the cliff with boulders and grass, and grass and trees along the
## summit. Cosmetic, seeded from the wall.

const DIRT := Color(0.29, 0.24, 0.18)
const GRASS := Color(0.34, 0.44, 0.22)
const GRASS_DARK := Color(0.21, 0.3, 0.14)
const BOULDER_LIT := Color(0.6, 0.58, 0.54)
const BOULDER_DARK := Color(0.33, 0.32, 0.31)
const PINE := Color(0.13, 0.22, 0.14)
const TRUNK := Color(0.25, 0.18, 0.12)
## Meters of ground drawn past each side of the wall.
const SPREAD: float = 30.0

var wall: Wall


func show_wall(w: Wall) -> void:
	wall = w
	queue_redraw()


func _draw() -> void:
	if wall == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = wall.gen_seed + 99
	_draw_ground(rng)
	_draw_summit(rng)


func _draw_ground(rng: RandomNumberGenerator) -> void:
	var ground := wall.ground_y()
	var top := PackedVector2Array()
	var x := -SPREAD
	while x <= wall.size.x + SPREAD:
		top.append(View.px(Vector2(x, ground + rng.randf_range(-0.01, 0.05))))
		x += 0.4
	var earth := top.duplicate()
	earth.append(View.px(Vector2(wall.size.x + SPREAD, ground + 10.0)))
	earth.append(View.px(Vector2(-SPREAD, ground + 10.0)))
	draw_colored_polygon(earth, DIRT)
	draw_polyline(top, GRASS, 8.0)
	var start_x := wall.size.x * 0.5
	if wall.start_holds.size() == 2:
		start_x = (wall.start_holds[0].position.x + wall.start_holds[1].position.x) * 0.5
	for i: int in rng.randi_range(5, 9):
		var size := rng.randf_range(0.12, 0.4)
		var boulder_x := rng.randf_range(-3.0, wall.size.x + 3.0)
		if absf(boulder_x - start_x) < 1.6:
			continue
		_boulder(Vector2(boulder_x, ground + size * 0.35), size, rng)
	for i: int in 220:
		_tuft(Vector2(rng.randf_range(-SPREAD, wall.size.x + SPREAD), ground + 0.03), rng.randf_range(0.06, 0.16), rng)


func _draw_summit(rng: RandomNumberGenerator) -> void:
	var span := wall.face_span(0.05)
	var x := span.x - 0.4
	while x < span.y + 0.4:
		_tuft(Vector2(x, rng.randf_range(0.0, 0.06)), rng.randf_range(0.1, 0.24), rng)
		x += rng.randf_range(0.06, 0.2)
	for i: int in rng.randi_range(3, 6):
		_pine(Vector2(rng.randf_range(span.x - 0.5, span.y + 0.5), 0.04), rng.randf_range(0.9, 2.4))


func _boulder(center: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var outline := PackedVector2Array()
	var lit := PackedVector2Array()
	var light := View.px(center + Vector2(-size * 0.4, -size * 0.3))
	for k: int in 12:
		var angle := TAU * k / 12.0
		var radius := size * rng.randf_range(0.82, 1.05)
		var p := View.px(center + Vector2(cos(angle) * radius * 1.3, sin(angle) * radius * 0.75))
		outline.append(p)
		lit.append(p.lerp(light, 0.38))
	draw_colored_polygon(outline, BOULDER_DARK)
	draw_colored_polygon(lit, BOULDER_LIT)


func _tuft(base: Vector2, height: float, rng: RandomNumberGenerator) -> void:
	var color := GRASS if rng.randf() < 0.6 else GRASS_DARK
	for blade: int in 3:
		var lean := rng.randf_range(-0.6, 0.6) * height
		var foot := base + Vector2((blade - 1) * 0.015, 0.0)
		draw_colored_polygon(PackedVector2Array([
			View.px(foot + Vector2(-0.008, 0.0)),
			View.px(foot + Vector2(0.008, 0.0)),
			View.px(foot + Vector2(lean, -height)),
		]), color)


func _pine(base: Vector2, height: float) -> void:
	draw_line(View.px(base), View.px(base + Vector2(0.0, -height * 0.3)), TRUNK, height * 6.0)
	for tier: int in 3:
		var bottom := base.y - height * (0.2 + tier * 0.25)
		var half := height * (0.32 - tier * 0.08)
		draw_colored_polygon(PackedVector2Array([
			View.px(Vector2(base.x - half, bottom)),
			View.px(Vector2(base.x + half, bottom)),
			View.px(Vector2(base.x, bottom - height * 0.4)),
		]), PINE)
