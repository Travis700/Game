extends CanvasLayer
## Start menu: play solo, host a game, or join one. The school shows behind it.

signal solo_requested
signal host_requested
signal join_requested(address: String)

## What each difficulty adds to the map. Auto picks one level per guard (up to 3).
const DIFFICULTIES := [
	["Auto: one level per guard", "Picks the map size from the team: 1 guard plays difficulty 1, 2 guards play 2, and 3 or 4 guards play 3."],
	["1 · Main building", "The gate, lobby, front office, main hall, cafeteria, kitchen and gym. Best for one guard."],
	["2 · + Classroom wing", "Opens the west wing: classrooms, the library and the nurse's office, and the Substitute, the Librarian and the Nurse who work there. Best for two guards."],
	["3 · + Science wing", "Opens the east wing too: the science lab, art room and locker rooms, with the Specimen, the Self-Portrait, the Understudy and the Crossing Guard. Best for three or four guards."],
]

const HowToPlay := preload("res://scripts/how_to_play.gd")

var _how_to_play: CanvasLayer
var _status: Label
var _address: LineEdit
var _password: LineEdit
var _buttons: Array[Button] = []
var _difficulty: OptionButton
var _difficulty_about: Label
var _keep_gear: CheckBox
var _continue: CheckBox
var _warned_about_save := false


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override("separation", 12)
	center.add_child(column)

	var title := Label.new()
	title.text = "NIGHT SHIFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Westfield High School · Security"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	subtitle.add_theme_font_size_override("font_size", 20)
	column.add_child(subtitle)

	var badge := Label.new()
	badge.text = "Your employee badge: %s" % Profile.badge()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	column.add_child(badge)

	column.add_child(_spacer(10))
	_add_run_options(column)
	column.add_child(_spacer(6))
	column.add_child(_button("Play solo", func() -> void: solo_requested.emit()))
	column.add_child(_button("Host a game", func() -> void: host_requested.emit()))

	_password = LineEdit.new()
	_password.placeholder_text = "Room password (optional, for hosting or joining)"
	_password.secret = true
	_password.custom_minimum_size = Vector2(0, 40)
	column.add_child(_password)

	column.add_child(_spacer(6))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Room code or host's address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.custom_minimum_size = Vector2(0, 44)
	_address.text_submitted.connect(func(text: String) -> void: join_requested.emit(text.strip_edges()))
	join_row.add_child(_address)
	var join := _button("Join", func() -> void: join_requested.emit(_address.text.strip_edges()))
	join.custom_minimum_size = Vector2(120, 44)
	join_row.add_child(join)
	column.add_child(join_row)

	var hint := Label.new()
	hint.text = "The host's room code shows in the top right once they're in. Codes work on the same network, or over the internet if the host forwards port 7777. To test on one computer, host in one window and join 127.0.0.1 in another."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 15)
	column.add_child(hint)

	column.add_child(_spacer(6))
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 8)
	var how := _button("How to play", func() -> void: _how_to_play.open())
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(how)
	var quit := _button("Quit", func() -> void: get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(quit)
	column.add_child(bottom_row)
	_how_to_play = HowToPlay.new()
	add_child(_how_to_play)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	column.add_child(_status)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## The host's choices for the run: {"difficulty": 0-3 (0 = auto), "keep_gear", "continue"}.
func options() -> Dictionary:
	return {
		"difficulty": _difficulty.selected,
		"keep_gear": _keep_gear.button_pressed,
		"continue": _continue.visible and _continue.button_pressed,
		"password": _password.text,
	}


func _add_run_options(column: VBoxContainer) -> void:
	var saved := RunSave.read()
	var heading := Label.new()
	heading.text = "Run settings (used when you play solo or host; joiners use the host's)"
	heading.add_theme_font_size_override("font_size", 16)
	heading.modulate.a = 0.7
	column.add_child(heading)

	_difficulty = OptionButton.new()
	_difficulty.custom_minimum_size = Vector2(0, 40)
	_difficulty.add_theme_font_size_override("font_size", 18)
	for entry: Array in DIFFICULTIES:
		_difficulty.add_item(entry[0])
	_difficulty.select(clampi(int(saved.get("difficulty", 0)), 0, DIFFICULTIES.size() - 1))
	_difficulty.item_selected.connect(func(_index: int) -> void: _explain_difficulty())
	column.add_child(_difficulty)

	_difficulty_about = Label.new()
	_difficulty_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_difficulty_about.custom_minimum_size = Vector2(420, 0)
	_difficulty_about.add_theme_font_size_override("font_size", 15)
	_difficulty_about.modulate.a = 0.65
	column.add_child(_difficulty_about)
	_explain_difficulty()

	_keep_gear = CheckBox.new()
	_keep_gear.text = "Keep gear if the whole team is caught"
	_keep_gear.tooltip_text = "Upgrades and carried items survive a restart. Points still go back to zero."
	_keep_gear.button_pressed = bool(saved.get("keep_gear", false))
	_keep_gear.add_theme_font_size_override("font_size", 17)
	column.add_child(_keep_gear)

	_continue = CheckBox.new()
	_continue.text = "Continue saved run: %s" % RunSave.describe(saved)
	_continue.visible = not saved.is_empty()
	_continue.button_pressed = not saved.is_empty()
	_continue.add_theme_font_size_override("font_size", 17)
	column.add_child(_continue)


func _explain_difficulty() -> void:
	_difficulty_about.text = DIFFICULTIES[_difficulty.selected][1]


## Starting a new run would replace the saved one. Returns true if that's fine (no save,
## continuing it, or the player has already been warned once and clicked again).
func confirm_new_run() -> bool:
	if not _continue.visible or _continue.button_pressed or _warned_about_save:
		return true
	_warned_about_save = true
	show_status("You have a saved run (%s). Starting a new one will replace it when the first night begins. Click again to start anyway, or tick \"Continue saved run\"." % RunSave.describe(RunSave.read()))
	return false


func show_status(text: String) -> void:
	_status.text = text


## Greys the buttons out while a connection attempt is in progress.
func set_busy(busy: bool) -> void:
	for button in _buttons:
		button.disabled = busy
	_address.editable = not busy
	_password.editable = not busy


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(on_press)
	if text != "Quit":
		_buttons.append(button)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer
