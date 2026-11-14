class_name RockView
extends Node2D
## Draws a wall's rock. Each baked chunk is lit once by the rock shader in an offscreen viewport, one
## texel per screen pixel, and the result is shown as a plain mipmapped sprite: the sun never moves,
## so the rock costs next to nothing to draw while climbing. When the window's scale changes the
## rock is lit again so it stays sharp. Without a GPU (headless) the chunks keep the shader instead.

const SHADER := preload("res://game/rock.gdshader")
## The most screen pixels per view pixel the rock is lit at. Past this, big screens show it a little
## soft; memory and the pause while lighting grow with the square of it.
const MAX_DENSITY: float = 2.0
## Seconds the window has to keep one size before the rock is lit again for it.
const RELIGHT_DELAY: float = 0.4

## Sunlight on the rock in this many flat steps, for a posterized look. 0 = smooth.
var light_bands: int = 0
## Runs the rock shader every frame instead of lighting once, for comparing the two.
var live: bool = false

var _wall: Wall
var _relief: RockRelief
## Screen pixels per view pixel the shown rock was lit at.
var _density: float = 0.0
## Counts lightings, so one that a newer one has replaced is dropped.
var _lightings: int = 0
var _relight_in: float = -1.0


func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void: _relight_in = RELIGHT_DELAY)


func _process(delta: float) -> void:
	if _relight_in < 0.0:
		return
	_relight_in -= delta
	if _relight_in < 0.0 and _relief != null and not live and not is_equal_approx(_screen_density(), _density):
		show_relief(_wall, _relief)


## Returns once the rock is lit and showing (a frame later).
func show_relief(wall: Wall, relief: RockRelief) -> void:
	_wall = wall
	_relief = relief
	_lightings += 1
	var lighting := _lightings
	var old := get_children()
	var look := RockRelief.look_of(wall)
	if live or DisplayServer.get_name() == "headless":
		for child: Node in old:
			child.queue_free()
		for chunk: RockRelief.Chunk in relief.chunks:
			var sprite := _lit_sprite(wall, relief, chunk, look)
			sprite.position = View.px(chunk.rect.position)
			sprite.scale = Vector2.ONE * (View.PX_PER_M / RockRelief.FINE_PX_PER_M)
			add_child(sprite)
		return
	var density := _screen_density()
	var viewports: Array[SubViewport] = []
	var corners: Array[Vector2i] = []
	for chunk: RockRelief.Chunk in relief.chunks:
		# In screen pixels. Each edge is rounded on its own so neighbouring chunks meet exactly.
		var corner := Vector2i((View.px(chunk.rect.position) * density).round())
		var viewport := SubViewport.new()
		viewport.size = Vector2i((View.px(chunk.rect.end) * density).round()) - corner
		viewport.transparent_bg = true
		viewport.disable_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		var sprite := _lit_sprite(wall, relief, chunk, look)
		sprite.scale = Vector2(viewport.size) / sprite.region_rect.size
		viewport.add_child(sprite)
		add_child(viewport)
		viewports.append(viewport)
		corners.append(corner)
	await RenderingServer.frame_post_draw
	if lighting != _lightings:
		for viewport: SubViewport in viewports:
			viewport.queue_free()
		return
	for child: Node in old:
		child.queue_free()
	# The viewports hold color already multiplied by coverage, so the face's soft outline is drawn
	# with premultiplied blending.
	var premultiplied := CanvasItemMaterial.new()
	premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	for i: int in viewports.size():
		var image := viewports[i].get_texture().get_image()
		image.generate_mipmaps()
		var shown := Sprite2D.new()
		shown.texture = ImageTexture.create_from_image(image)
		shown.centered = false
		shown.position = Vector2(corners[i]) / density
		shown.scale = Vector2.ONE / density
		shown.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		shown.material = premultiplied
		add_child(shown)
		viewports[i].queue_free()
	_density = density


## Screen pixels per view pixel: 1 in a 1280x720 window, 1.5 full screen at 1080p.
func _screen_density() -> float:
	return clampf(get_viewport().get_final_transform().get_scale().x, 0.5, MAX_DENSITY)


## A sprite covering `chunk` with its top-left corner at the origin, drawn by the rock shader.
func _lit_sprite(wall: Wall, relief: RockRelief, chunk: RockRelief.Chunk, look: RockType) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = chunk.texture
	sprite.centered = false
	sprite.region_enabled = true
	var margin_px := (chunk.rect.position - chunk.tex_rect.position) * RockRelief.FINE_PX_PER_M
	sprite.region_rect = Rect2(margin_px, chunk.rect.size * RockRelief.FINE_PX_PER_M)
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("relief", chunk.texture)
	mat.set_shader_parameter("relief_rect", _rect4(chunk.tex_rect))
	mat.set_shader_parameter("relief_texel", Vector2.ONE / Vector2(chunk.texture.get_size()))
	mat.set_shader_parameter("relief_texel_m", 1.0 / RockRelief.FINE_PX_PER_M)
	mat.set_shader_parameter("detail", chunk.detail)
	mat.set_shader_parameter("detail_depth", look.crease_depth)
	mat.set_shader_parameter("coarse", relief.coarse)
	mat.set_shader_parameter("coarse_rect", _rect4(relief.coarse_rect))
	mat.set_shader_parameter("coarse_texel", Vector2.ONE / Vector2(relief.coarse_size))
	mat.set_shader_parameter("coarse_texel_m", 1.0 / RockRelief.COARSE_PX_PER_M)
	mat.set_shader_parameter("wet", relief.wet)
	mat.set_shader_parameter("sun_dir", RockRelief.SUN)
	mat.set_shader_parameter("light_bands", float(light_bands))
	mat.set_shader_parameter("base_color", _rgb(look.base_color))
	mat.set_shader_parameter("dark_color", _rgb(look.dark_color))
	mat.set_shader_parameter("light_color", _rgb(look.light_color))
	mat.set_shader_parameter("accent_color", _rgb(look.accent_color))
	mat.set_shader_parameter("streak_color", _rgb(look.streak_color))
	mat.set_shader_parameter("grain", look.grain)
	mat.set_shader_parameter("strata", look.strata)
	mat.set_shader_parameter("streaks", look.streaks)
	mat.set_shader_parameter("lichen", look.lichen)
	mat.set_shader_parameter("noise_seed", float(wall.gen_seed % 997))
	sprite.material = mat
	return sprite


static func _rect4(r: Rect2) -> Vector4:
	return Vector4(r.position.x, r.position.y, r.size.x, r.size.y)


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
