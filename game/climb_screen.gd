class_name ClimbScreen
extends Node2D
## One climbing session on a generated rock wall. Builds the wall and its art once, shows the wall
## preview, then steps the ClimbSim every physics tick and turns mouse and keys into sim inputs.
## Restarting reuses the same wall.

## Meters around a hold's edge that still count as hovering it.
const HOVER_SLACK: float = 0.08
## The climber's shadow on the rock: how dark, and its edge blur in screen pixels. Purely visual.
const SHADOW_ALPHA: float = 0.45
const SHADOW_SOFTNESS: float = 4.0

var sim: ClimbSim
var _wall_seed: int
var _options: Dictionary
var _attempt: int = 0
var _wall: Wall
var _hovered: Hold
var _backdrop: Backdrop
var _rock_view: RockView
var _ground_view: GroundView
var _haze: HeightHaze
var _wall_view: WallView
var _shadow_view: ClimberView
var _climber_view: ClimberView
var _skill_view: SkillCheckView
var _hover_hint: HoverHint
var _overlay: DebugOverlay
var _camera: CameraRig
var _hud: Hud


## `options` are the command line options from Main: rock=<id>, test-wall, no-preview, debug,
## look=<x>,<y>,<zoom>, light-bands=<n>, live-rock.
func _init(wall_seed: int, options: Dictionary) -> void:
	_wall_seed = wall_seed
	_options = options


func _ready() -> void:
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	_rock_view = RockView.new()
	add_child(_rock_view)
	var shadow_group := CanvasGroup.new()
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = preload("res://game/soft_shadow.gdshader")
	shadow_material.set_shader_parameter("opacity", SHADOW_ALPHA)
	shadow_material.set_shader_parameter("softness", SHADOW_SOFTNESS)
	shadow_group.material = shadow_material
	shadow_group.fit_margin = SHADOW_SOFTNESS * 3.0
	shadow_group.clear_margin = SHADOW_SOFTNESS * 3.0
	add_child(shadow_group)
	_shadow_view = ClimberView.new()
	_shadow_view.shadow = true
	shadow_group.add_child(_shadow_view)
	_ground_view = GroundView.new()
	add_child(_ground_view)
	_haze = HeightHaze.new()
	add_child(_haze)
	_wall_view = WallView.new()
	add_child(_wall_view)
	_climber_view = ClimberView.new()
	add_child(_climber_view)
	_skill_view = SkillCheckView.new()
	add_child(_skill_view)
	_hover_hint = HoverHint.new()
	add_child(_hover_hint)
	_overlay = DebugOverlay.new()
	_overlay.visible = _options.has("debug")
	add_child(_overlay)
	_camera = CameraRig.new()
	add_child(_camera)
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Hud.new()
	layer.add_child(_hud)
	# Let the "Generating" screen show before the long build.
	await get_tree().process_frame
	await get_tree().process_frame
	await _build_wall()
	restart()
	_backdrop.build(_wall, _camera.follow_target().y)
	if _options.has("look"):
		var look := str(_options["look"]).split_floats(",")
		_camera.fixed_view = Vector3(look[0], look[1], look[2] if look.size() > 2 else 1.0)
		_haze.fixed_y = look[1]
	elif not _options.has("no-preview"):
		_camera.start_preview()


func _build_wall() -> void:
	var started := Time.get_ticks_msec()
	if _options.has("test-wall"):
		_wall = TestWalls.basic()
		_hud.title = "Test wall"
	else:
		var spec := Catalog.wall_spec(&"crag_1").duplicate() as WallSpec
		var rock_id := StringName(str(_options.get("rock", "")))
		if Catalog.has_rock(rock_id):
			spec.rock = Catalog.rock(rock_id)
		_wall = WallGen.generate(spec, _wall_seed)
		_hud.title = "%s  ·  %d m of %s" % [spec.display_name, roundi(spec.height), spec.rock.display_name.to_lower()]
	var generated := Time.get_ticks_msec()
	var relief := RockRelief.bake(_wall)
	var baked := Time.get_ticks_msec()
	_ground_view.show_wall(_wall)
	_rock_view.light_bands = int(_options.get("light-bands", 0))
	_rock_view.live = _options.has("live-rock")
	await _rock_view.show_relief(_wall, relief)
	var start_x := (_wall.start_holds[0].position.x + _wall.start_holds[1].position.x) * 0.5
	print("Wall seed %d: %d holds, %d rests, start at x %.1f m. Generated in %d ms, art baked in %d ms, lit in %d ms" % [
		_wall_seed, _wall.holds.size(), _wall.rests.size(), start_x, generated - started, baked - generated, Time.get_ticks_msec() - baked])


func restart() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _wall_seed + _attempt
	_attempt += 1
	var climber := Climber.from_character(Catalog.character(&"default"))
	sim = ClimbSim.new(_wall, climber, rng)
	sim.message.connect(_hud.show_message)
	_wall_view.sim = sim
	_haze.sim = sim
	_shadow_view.sim = sim
	_climber_view.sim = sim
	_skill_view.sim = sim
	_hover_hint.sim = sim
	_overlay.sim = sim
	_hud.sim = sim
	_hud.seed_label = "wall seed %d" % _wall_seed
	_camera.sim = sim
	_camera.snap()


func _physics_process(_delta: float) -> void:
	if sim == null or _camera.previewing:
		return
	sim.step(Tuning.STEP)


func _process(_delta: float) -> void:
	if sim == null:
		return
	_hud.previewing = _camera.previewing
	_hovered = null
	if not _camera.previewing:
		_hovered = sim.wall.hold_at(View.to_meters(get_global_mouse_position()), HOVER_SLACK, true)
	_wall_view.set_hovered(_hovered)
	_skill_view.hovered = _hovered
	_hover_hint.hovered = _hovered
	_overlay.hovered = _hovered


func _unhandled_input(event: InputEvent) -> void:
	if sim == null:
		return
	if _camera.previewing:
		if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton):
			_camera.skip_preview()
		return
	if event.is_action_pressed(&"grab_left"):
		if _hovered != null:
			sim.queue_hand(Climber.Limb.LEFT_HAND, _hovered)
	elif event.is_action_pressed(&"grab_right"):
		if _hovered != null:
			sim.queue_hand(Climber.Limb.RIGHT_HAND, _hovered)
	elif event.is_action_pressed(&"dyno_or_catch"):
		sim.queue_space_press()
	elif event.is_action_released(&"dyno_or_catch"):
		sim.queue_space_release(_hovered)
	elif event.is_action_pressed(&"rest"):
		sim.queue_rest()
	elif event.is_action_pressed(&"toggle_debug"):
		_overlay.visible = not _overlay.visible
	elif event.is_action_pressed(&"place_gear"):
		_hud.show_message("Protection arrives in Milestone 3")
	elif event.is_action_pressed(&"restart"):
		restart()
