extends Node
## Registers the game's input actions at startup, so nothing has to be set up by hand in the editor.

const BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"toggle_fullscreen": [KEY_F11],
	"zoom": [KEY_SPACE],
	"clipboard": [KEY_TAB],
	"monitor_1": [KEY_1],
	"monitor_2": [KEY_2],
	"monitor_3": [KEY_3],
	"monitor_4": [KEY_4],
}
const MOUSE_BINDINGS := {
	"zoom": [MOUSE_BUTTON_LEFT],
}


func _enter_tree() -> void:
	for action: String in BINDINGS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key: int in BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for action: String in MOUSE_BINDINGS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button: int in MOUSE_BINDINGS[action]:
			var click := InputEventMouseButton.new()
			click.button_index = button
			InputMap.action_add_event(action, click)
