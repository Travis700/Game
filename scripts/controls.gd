extends Node
## Registers the game's input actions at startup, so nothing has to be set up by hand in the editor.

const BINDINGS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT],
	"crouch": [KEY_C],
	"interact": [KEY_E],
	"flashlight": [KEY_F],
	"pause": [KEY_ESCAPE],
	"toggle_fullscreen": [KEY_F11],
	"zoom": [KEY_SPACE],
	"clipboard": [KEY_TAB],
	"use_item": [KEY_G],
	# Puts down what's picked on the hotbar, or hands it to the teammate you're facing.
	"drop_item": [KEY_X],
	# Throws what you picked up off the floor (the right mouse button too).
	"throw": [KEY_T],
	"push_to_talk": [KEY_V],
	"radio_talk": [KEY_B],
	"compare": [KEY_R],
	"ping": [KEY_Q],
	"monitor_1": [KEY_1],
	"monitor_2": [KEY_2],
	"monitor_3": [KEY_3],
	"monitor_4": [KEY_4],
	# The hotbar (the same keys as the monitors: at a desk they pick a monitor instead).
	"slot_1": [KEY_1],
	"slot_2": [KEY_2],
	"slot_3": [KEY_3],
	"slot_4": [KEY_4],
	"slot_5": [KEY_5],
}
## Controller buttons (Xbox layout names; Godot maps PlayStation and Switch pads the same).
const JOY_BUTTONS := {
	"interact": [JOY_BUTTON_A],
	"flashlight": [JOY_BUTTON_Y],
	"zoom": [JOY_BUTTON_X],
	"compare": [JOY_BUTTON_RIGHT_STICK],
	"sprint": [JOY_BUTTON_LEFT_STICK],
	# Away from a desk (where it compares with the photo).
	"crouch": [JOY_BUTTON_RIGHT_STICK],
	"clipboard": [JOY_BUTTON_BACK],
	"use_item": [JOY_BUTTON_RIGHT_SHOULDER],
	"ping": [JOY_BUTTON_B],
	"push_to_talk": [JOY_BUTTON_LEFT_SHOULDER],
	"pause": [JOY_BUTTON_START],
	# The D-pad works the hotbar (at a desk, left and right still flick between cameras).
	"slot_prev": [JOY_BUTTON_DPAD_LEFT],
	"slot_next": [JOY_BUTTON_DPAD_RIGHT],
	"throw": [JOY_BUTTON_DPAD_UP],
	"drop_item": [JOY_BUTTON_DPAD_DOWN],
}
## Controller sticks and triggers: action -> [axis, direction].
const JOY_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"radio_talk": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
const MOUSE_BINDINGS := {
	"zoom": [MOUSE_BUTTON_LEFT],
	# Left click switches the flashlight (at a desk it's the full-screen camera, checked first).
	"flashlight": [MOUSE_BUTTON_LEFT],
	"throw": [MOUSE_BUTTON_RIGHT],
	"slot_next": [MOUSE_BUTTON_WHEEL_DOWN],
	"slot_prev": [MOUSE_BUTTON_WHEEL_UP],
}


## Keys the player can change in the Esc menu, with the names shown there.
const REBINDABLE := [
	["move_forward", "Walk forward"], ["move_back", "Walk back / stand up"], ["move_left", "Walk left"],
	["move_right", "Walk right"], ["sprint", "Run"], ["crouch", "Crouch"], ["interact", "Use"], ["flashlight", "Flashlight"],
	["clipboard", "Clipboard"], ["use_item", "Use item"], ["drop_item", "Put down / hand over item"], ["throw", "Throw"], ["zoom", "Full-screen camera"], ["compare", "Compare camera with photo"], ["ping", "Mark a spot (or flag a camera) for the team"], ["push_to_talk", "Push to talk"], ["radio_talk", "Talk on the walkie-talkie"],
]
const SAVE_PATH := "user://controls.cfg"

## Action -> the main key's physical keycode, where the player changed it.
var _primary: Dictionary = {}


func _enter_tree() -> void:
	# This is the first autoload, so older saves are moved into place before anything reads them.
	RunSave.migrate_old_saves()
	_register_defaults()
	_load_changes()


## Whether the player last used a controller: prompts then name its buttons instead of keys.
var using_pad := false
signal device_changed

const PAD_NAMES := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L-stick click",
	JOY_BUTTON_RIGHT_STICK: "R-stick click", JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
}
## Placeholders that text can use for the player's own keys, e.g. "Press {use} to answer".
const TOKENS := {
	"use": "interact", "item": "use_item", "clip": "clipboard", "ping": "ping", "radio": "radio_talk", "drop": "drop_item", "throw": "throw",
	"talk": "push_to_talk", "zoom": "zoom", "compare": "compare", "light": "flashlight", "run": "sprint", "crouch": "crouch",
	"menu": "pause", "left": "move_left", "right": "move_right",
}


func _input(event: InputEvent) -> void:
	var pad := using_pad
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if pad != using_pad:
		using_pad = pad
		device_changed.emit()


## The main key for an action, e.g. "W" (or the controller button, if that's what's in use).
## (Arrow keys and the mouse still work alongside.)
func key_name(action: String) -> String:
	if using_pad:
		if JOY_BUTTONS.has(action):
			return PAD_NAMES.get(JOY_BUTTONS[action][0], "?")
		if action == "radio_talk":
			return "RT"
	if action == "pause":
		return "Esc"
	if action == "throw" and not _primary.has(action):
		return "Right click"
	# The key's name on this keyboard's layout (on AZERTY, Z rather than W).
	var key := primary_key(action)
	if DisplayServer.get_name() != "headless":
		key = DisplayServer.keyboard_get_keycode_from_physical(key)
	return OS.get_keycode_string(key)


## Swaps "{use}", "{item}"... in `text` for the player's own keys.
func fill(text: String) -> String:
	if not "{" in text:
		return text
	for token: String in TOKENS:
		text = text.replace("{%s}" % token, key_name(TOKENS[token]))
	return text


func primary_key(action: String) -> int:
	return _primary.get(action, BINDINGS[action][0])


## Keys that can't be taken: Esc (menu), F11 (fullscreen) and 1-5 (monitors and the hotbar).
const RESERVED: Array[int] = [KEY_ESCAPE, KEY_F11, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]


## Changes an action's main key and saves it. If another action already uses that key, the
## two swap. Returns "" or a reason it can't be used.
func rebind(action: String, keycode: int) -> String:
	if keycode in RESERVED:
		return "%s is kept for the game itself." % OS.get_keycode_string(keycode)
	for other: String in BINDINGS:
		if keycode in (BINDINGS[other] as Array).slice(1):
			return "%s is always a second key for walking. Pick another." % OS.get_keycode_string(keycode)
	var old_key := primary_key(action)
	for entry: Array in REBINDABLE:
		var other: String = entry[0]
		if other != action and keycode in _keys_of(other):
			# Swap: the other action takes this one's old key.
			_primary[other] = old_key
			_apply(other)
	_primary[action] = keycode
	_apply(action)
	_save()
	return ""


## Puts every key back the way it started.
func reset_all() -> void:
	_primary.clear()
	for action: String in BINDINGS:
		_apply(action)
	_save()


## Every key an action responds to right now.
func _keys_of(action: String) -> Array[int]:
	var keys: Array[int] = [primary_key(action)]
	for key: int in BINDINGS[action].slice(1):
		if key not in keys:
			keys.append(key)
	return keys


## Rebuilds an action's keys from scratch: its main key plus its built-in extras (arrow keys),
## leaving mouse buttons alone.
func _apply(action: String) -> void:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	for keycode in _keys_of(action):
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		InputMap.action_add_event(action, key)


func _load_changes() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK or not config.has_section("keys"):
		return
	for action: String in config.get_section_keys("keys"):
		if BINDINGS.has(action):
			_primary[action] = int(config.get_value("keys", action))
			_apply(action)


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
	for action: String in JOY_BUTTONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for button: int in JOY_BUTTONS[action]:
			var press := InputEventJoypadButton.new()
			press.button_index = button
			InputMap.action_add_event(action, press)
	for action: String in JOY_AXES:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXES[action][0]
		stick.axis_value = JOY_AXES[action][1]
		InputMap.action_add_event(action, stick)
