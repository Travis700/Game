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
	"use_item": [KEY_G],
	"monitor_1": [KEY_1],
	"monitor_2": [KEY_2],
	"monitor_3": [KEY_3],
	"monitor_4": [KEY_4],
}
const MOUSE_BINDINGS := {
	"zoom": [MOUSE_BUTTON_LEFT],
}


## Keys the player can change in the Esc menu, with the names shown there.
const REBINDABLE := [
	["move_forward", "Walk forward"], ["move_back", "Walk back / stand up"], ["move_left", "Walk left"],
	["move_right", "Walk right"], ["sprint", "Run"], ["interact", "Use"], ["flashlight", "Flashlight"],
	["clipboard", "Clipboard"], ["use_item", "Use item"], ["zoom", "Full-screen camera"],
]
const SAVE_PATH := "user://controls.cfg"

## Action -> the main key's physical keycode, where the player changed it.
var _primary: Dictionary = {}


func _enter_tree() -> void:
	_register_defaults()
	_load_changes()


## The main key for an action, e.g. "W". (Arrow keys and the mouse still work alongside.)
func key_name(action: String) -> String:
	return OS.get_keycode_string(primary_key(action))


func primary_key(action: String) -> int:
	return _primary.get(action, BINDINGS[action][0])


## Changes an action's main key and saves it.
func rebind(action: String, keycode: int) -> void:
	_swap_key(action, primary_key(action), keycode)
	_primary[action] = keycode
	_save()


## Puts every key back the way it started.
func reset_all() -> void:
	for action: String in _primary.keys():
		_swap_key(action, _primary[action], BINDINGS[action][0])
	_primary.clear()
	_save()


func _swap_key(action: String, old_key: int, new_key: int) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == old_key:
			InputMap.action_erase_event(action, event)
	var key := InputEventKey.new()
	key.physical_keycode = new_key
	InputMap.action_add_event(action, key)


func _load_changes() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not config.has_section("keys"):
		return
	for action: String in config.get_section_keys("keys"):
		if BINDINGS.has(action):
			var keycode: int = config.get_value("keys", action)
			_swap_key(action, BINDINGS[action][0], keycode)
			_primary[action] = keycode


func _save() -> void:
	var config := ConfigFile.new()
	for action: String in _primary:
		config.set_value("keys", action, _primary[action])
	config.save(SAVE_PATH)


func _register_defaults() -> void:
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
