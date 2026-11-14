class_name InputSetup
extends RefCounted
## Registers the game's input actions in code. Change bindings here.


static func register() -> void:
	_bind_mouse(&"grab_left", MOUSE_BUTTON_LEFT)
	_bind_mouse(&"grab_right", MOUSE_BUTTON_RIGHT)
	# Hold to charge a dyno; during a deadpoint dial, press to catch.
	_bind_key(&"dyno_or_catch", KEY_SPACE)
	_bind_key(&"rest", KEY_E)
	_bind_key(&"place_gear", KEY_G)
	_bind_key(&"restart", KEY_R)
	_bind_key(&"toggle_debug", KEY_F1)


static func _bind_key(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)


static func _bind_mouse(action: StringName, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)
