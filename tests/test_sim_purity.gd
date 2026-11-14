extends GutTest
## The sim must stay pure: no Nodes, scene tree, input or rendering, and no global randomness.

const NODE_USE := "\\b(Node|Node2D|Node3D|Control|CanvasItem|Viewport|SceneTree|Sprite2D|RenderingServer)\\b|\\bget_tree\\(|\\bget_node\\(|\\bInput\\."
const GLOBAL_RANDOM := "(?<![.\\w])(randi|randf|randi_range|randf_range|randfn|randomize|seed)\\(|\\.shuffle\\(|\\.pick_random\\("


func _sim_sources() -> Dictionary[String, String]:
	var sources: Dictionary[String, String] = {}
	for file: String in DirAccess.get_files_at("res://sim"):
		if file.ends_with(".gd"):
			sources[file] = FileAccess.get_file_as_string("res://sim/" + file)
	return sources


func test_sim_scripts_are_found() -> void:
	assert_gt(_sim_sources().size(), 5)


func test_sim_never_touches_nodes() -> void:
	var regex := RegEx.create_from_string(NODE_USE)
	var sources := _sim_sources()
	for file: String in sources:
		var found := regex.search(sources[file])
		assert_null(found, "%s uses %s" % [file, found.get_string() if found != null else ""])


func test_sim_never_uses_global_random() -> void:
	var regex := RegEx.create_from_string(GLOBAL_RANDOM)
	var sources := _sim_sources()
	for file: String in sources:
		var found := regex.search(sources[file])
		assert_null(found, "%s calls %s" % [file, found.get_string() if found != null else ""])
