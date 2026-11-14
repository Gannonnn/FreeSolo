extends Node
## Boots the game: registers input, then shows the climb screen.
## Options after `--` on the command line:
##   --seed=N          wall seed (random otherwise)
##   --rock=ID         rock type, e.g. granite or limestone (the wall's own otherwise)
##   --test-wall       the hand-built Milestone 1 test wall instead of a generated one
##   --no-preview      skip the wall preview
##   --debug           debug overlay on
##   --look=X,Y,ZOOM   camera fixed at X, Y meters with that zoom, for checking the art
##   --light-bands=N   sunlight on the rock in N flat steps, for a posterized look (off otherwise)
##   --live-rock       light the rock every frame instead of once at the start (slower; for comparing)
##   --screenshot=PATH saves one frame and quits, for checking visuals without a person at the screen
##   --shot-frames=N   frames to wait before that screenshot

const SCREENSHOT_FRAMES: int = 45

var _screenshot_path: String = ""
var _frames_left: int = SCREENSHOT_FRAMES


func _ready() -> void:
	InputSetup.register()
	var options := _user_options()
	var wall_seed := int(Time.get_unix_time_from_system() * 1000.0) % 1000000
	if options.has("seed"):
		wall_seed = int(options["seed"])
	add_child(ClimbScreen.new(wall_seed, options))
	_screenshot_path = options.get("screenshot", "")
	if options.has("shot-frames"):
		_frames_left = int(options["shot-frames"])


func _process(_delta: float) -> void:
	if _screenshot_path == "":
		return
	_frames_left -= 1
	if _frames_left > 0:
		return
	var image := get_viewport().get_texture().get_image()
	image.save_png(_screenshot_path)
	get_tree().quit()


func _user_options() -> Dictionary:
	var options := {}
	for arg: String in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		options[parts[0]] = parts[1] if parts.size() > 1 else ""
	return options
