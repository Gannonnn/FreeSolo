class_name Backdrop
extends Node2D
## The landscape behind the cliff: a fixed sky, then far mountains, nearer ridges, forested hills
## and the valley floor in parallax layers. Farther layers move less as the camera climbs, so the
## cliff reads as standing in front of them, and the valley drops away as you gain height.
## Cosmetic, seeded from the wall.

## Share of the screen height where the horizon sits when the climb starts.
const HORIZON: float = 0.6
## Pixels of landscape drawn to each side, enough for the zoomed-out wall preview.
const SPREAD: float = 8000.0
## Pixels each layer reaches below its base line, well past the bottom of the screen.
const DEPTH: float = 6000.0
## The haze that fills the valleys, matching the sky at the horizon.
const HAZE := Color(0.78, 0.83, 0.9)


class Layer extends Node2D:
	## 0 = fixed to the screen (infinitely far), 1 = moves with the wall.
	var scroll: float
	## Ridge line, left to right, and the layer's color along it.
	var ridge: PackedVector2Array
	var ridge_colors: PackedColorArray
	## Pixels: where the layer has faded into the haze, and the haze color there.
	var haze_y: float
	var haze: Color

	func _draw() -> void:
		for i: int in range(1, ridge.size()):
			var a := ridge[i - 1]
			var b := ridge[i]
			draw_primitive(PackedVector2Array([a, b, Vector2(b.x, haze_y), Vector2(a.x, haze_y)]),
					PackedColorArray([ridge_colors[i - 1], ridge_colors[i], haze, haze]), PackedVector2Array())
		var bottom := haze_y + DEPTH
		draw_rect(Rect2(ridge[0].x, haze_y, ridge[ridge.size() - 1].x - ridge[0].x, bottom - haze_y), haze)


var _layers: Array[Layer] = []
var _start_camera_y: float = 0.0


## `start_camera_y` is where the camera sits when the climb begins; the horizon is placed for it.
func build(wall: Wall, start_camera_y: float) -> void:
	for child: Node in get_children():
		child.queue_free()
	_layers.clear()
	_start_camera_y = start_camera_y
	var rng := RandomNumberGenerator.new()
	rng.seed = wall.gen_seed + 7
	_add_sky()
	_add_layer(rng, 0.03, 0.0, 320.0, 0.0, Color(0.62, 0.69, 0.8), 0.85)
	_add_layer(rng, 0.08, 40.0, 230.0, 0.0, Color(0.44, 0.52, 0.63), 0.7)
	_add_layer(rng, 0.18, 120.0, 150.0, 7.0, Color(0.27, 0.37, 0.35), 0.45)
	_add_layer(rng, 0.38, 250.0, 80.0, 14.0, Color(0.17, 0.26, 0.19), 0.22)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var horizon := (HORIZON - 0.5) * get_viewport_rect().size.y
	for layer: Layer in _layers:
		var s := layer.scroll
		layer.position = Vector2(cam.position.x * (1.0 - s), cam.position.y * (1.0 - s) + s * _start_camera_y + horizon)


func _add_sky() -> void:
	var sky := CanvasLayer.new()
	sky.layer = -10
	add_child(sky)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([Color(0.3, 0.5, 0.8), Color(0.72, 0.8, 0.9), Color(0.82, 0.86, 0.9)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 256
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A ridge line `height` pixels tall at most, sitting `base` pixels below the horizon, filled down
## to well below the screen. `roughness` adds treetop jaggedness. Peaks show the layer's `color`;
## lower down it fades into the valley haze, by `hazy` (0..1) at its base line.
func _add_layer(rng: RandomNumberGenerator, scroll: float, base: float, height: float, roughness: float, color: Color, hazy: float) -> void:
	var layer := Layer.new()
	layer.scroll = scroll
	layer.haze_y = base + height * 0.35
	layer.haze = color.lerp(HAZE, minf(1.0, hazy * 1.15))
	var freq := Vector3(rng.randf_range(0.0015, 0.003), rng.randf_range(0.005, 0.009), rng.randf_range(0.013, 0.02))
	var phase := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var step := 16.0 if roughness > 0.0 else 40.0
	var top := base - height
	var x := -SPREAD
	while x <= SPREAD:
		var shape := 0.5 + 0.28 * sin(x * freq.x + phase.x) + 0.14 * sin(x * freq.y + phase.y) + 0.08 * sin(x * freq.z + phase.z)
		var y := base - height * shape - rng.randf() * roughness
		layer.ridge.append(Vector2(x, y))
		var low := clampf(inverse_lerp(top, layer.haze_y, y), 0.0, 1.0)
		layer.ridge_colors.append(color.lerp(HAZE, hazy * low * low))
		x += step
	add_child(layer)
	_layers.append(layer)
