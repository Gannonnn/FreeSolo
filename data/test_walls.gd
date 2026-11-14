class_name TestWalls
extends RefCounted
## Hand-built walls for Milestone 1 and the tests, as plain data.

## 5 m × 10 m: slab at the bottom, vertical in the middle, a 30° overhang near the top.
## A knee-bar under the overhang; a ledge hold remains only so RestSpot.ledge can still be tested.
const BASIC: Dictionary = {
	"size": Vector2(5.0, 10.0),
	"top_out_y": 0.8,
	"angle_cell": 0.25,
	# [from y, to y, degrees past vertical]. Negative is slab, positive is overhang.
	"angle_bands": [
		[0.0, 0.8, 10.0],
		[0.8, 3.5, 30.0],
		[3.5, 6.5, 0.0],
		[6.5, 10.0, -15.0],
	],
	# [hold type, x, y, rotation in degrees]. 0° faces up, 90° faces right, 180° is an undercling.
	"holds": [
		[&"jug", 2.2, 8.4, 0.0],
		[&"jug", 2.8, 8.4, 0.0],
		[&"crimp", 2.95, 8.0, 0.0],
		[&"sloper", 2.1, 7.62, 0.0],
		[&"pinch", 2.9, 7.24, 90.0],
		[&"crimp", 2.15, 6.86, -20.0],
		[&"jug", 2.85, 6.48, 0.0],
		[&"pocket", 2.2, 6.1, 0.0],
		[&"crimp", 3.0, 5.72, 60.0],
		[&"ledge", 2.5, 5.5, 0.0],
		[&"crimp", 2.15, 5.18, 0.0],
		[&"crimp", 2.9, 4.8, 0.0],
		[&"sloper", 2.2, 4.42, 0.0],
		[&"jug", 2.85, 4.04, 0.0],
		[&"crimp", 2.1, 3.66, 0.0],
		[&"pinch", 2.9, 3.28, 90.0],
		[&"crimp", 2.15, 2.9, -15.0],
		[&"sloper", 2.85, 2.52, 0.0],
		[&"crimp", 2.2, 2.14, 0.0],
		[&"crimp", 2.9, 1.76, 20.0],
		[&"jug", 2.15, 1.38, 0.0],
		[&"jug", 2.85, 1.0, 0.0],
		[&"jug", 2.2, 0.55, 0.0],
		[&"jug", 2.85, 0.55, 0.0],
		[&"jug", 1.35, 7.0, 0.0],
		[&"crimp", 1.2, 5.9, -35.0],
		[&"jug", 3.75, 5.0, 0.0],
		[&"crimp", 3.85, 6.3, 35.0],
		[&"pocket", 1.4, 3.9, 0.0],
		[&"sloper", 3.65, 2.9, 0.0],
		[&"crimp", 2.55, 4.62, 180.0],
		[&"jug", 3.55, 1.7, 0.0],
		[&"crimp", 1.45, 2.4, -60.0],
	],
	# Indices into "holds": [left hand, right hand].
	"start": [0, 1],
	# [knee x, knee y, index of the foothold it braces from].
	"kneebars": [[2.9, 3.6, 13]],
	# Indices of holds that are ledges you can rest on.
	"ledges": [9],
	# Rows of foot chips: [y, x, x, ...]. The first row is the ground.
	"foot_rows": [
		[9.95, 1.6, 2.0, 2.4, 2.8, 3.2, 3.6],
		[9.6, 2.15, 2.85],
		[9.25, 1.9, 2.5, 3.1],
		[8.9, 2.2, 2.85],
		[8.55, 1.95, 2.55, 3.15],
		[8.2, 2.3, 2.75],
		[7.85, 1.9, 2.55, 3.1],
		[7.5, 2.25, 2.8],
		[7.15, 1.95, 2.6, 3.15],
		[6.8, 2.35, 2.75],
		[6.45, 1.9, 3.1],
		[6.1, 2.6, 2.95],
		[5.75, 1.95, 2.6],
		[5.4, 3.1],
		[5.05, 2.5, 3.15],
		[4.7, 1.95, 3.15],
		[4.35, 2.55, 3.15],
		[3.95, 1.95, 2.5],
		[3.6, 2.5, 3.2],
		[3.25, 1.95, 2.55],
		[2.9, 2.5, 3.2],
		[2.55, 1.95, 2.5],
		[2.2, 2.55, 3.2],
		[1.85, 1.95, 2.5],
		[1.5, 2.55, 3.2],
	],
}


static func basic() -> Wall:
	return build(BASIC)


static func build(layout: Dictionary) -> Wall:
	var size: Vector2 = layout["size"]
	var wall := Wall.new(size, float(layout["top_out_y"]))
	var cell := float(layout["angle_cell"])
	var cols := ceili(size.x / cell)
	var rows := ceili(size.y / cell)
	var angles := PackedFloat32Array()
	angles.resize(cols * rows)
	for row: int in rows:
		var y := (row + 0.5) * cell
		var degrees := 0.0
		for band: Array in layout["angle_bands"]:
			if y >= float(band[0]) and y < float(band[1]):
				degrees = float(band[2])
		for col: int in cols:
			angles[row * cols + col] = deg_to_rad(degrees)
	wall.set_angle_grid(cell, cols, angles)
	for entry: Array in layout["holds"]:
		var at := Vector2(float(entry[1]), float(entry[2]))
		wall.add_hold(Catalog.hold_type(entry[0]), at, deg_to_rad(float(entry[3])))
	var start: Array = layout["start"]
	wall.start_holds = [wall.holds[int(start[0])], wall.holds[int(start[1])]]
	for knee: Array in layout["kneebars"]:
		var knee_at := Vector2(float(knee[0]), float(knee[1]))
		wall.add_rest(RestSpot.kneebar(knee_at, wall.holds[int(knee[2])]))
	for index: int in layout["ledges"]:
		wall.add_rest(RestSpot.ledge(wall.holds[index]))
	var chip := Catalog.hold_type(&"foot_chip")
	for row_spec: Array in layout["foot_rows"]:
		var chip_y := float(row_spec[0])
		for i: int in range(1, row_spec.size()):
			wall.add_hold(chip, Vector2(float(row_spec[i]), chip_y))
	return wall
