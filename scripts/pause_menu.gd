extends CanvasLayer
## The Esc menu: settings, and leaving the game. Playing solo it pauses the game; in a group
## the night carries on (other guards are still playing), so your guard just stands still.

signal closed
signal leave_requested

## Choices for the 3D resolution, as a percentage of the window.
const RENDER_SCALES: Array[int] = [100, 85, 70, 50]

var is_open := false
var _title: Label
var _note: Label
var _sensitivity: HSlider
var _volume: HSlider
var _fullscreen: CheckBox
var _leave: Button


func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.14, 0.96)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	column.add_child(_title)
	_note = Label.new()
	_note.modulate.a = 0.6
	column.add_child(_note)

	column.add_child(_label("Mouse sensitivity"))
	_sensitivity = _slider(0.2, 3.0, Profile.mouse_sensitivity)
	_sensitivity.value_changed.connect(func(value: float) -> void: Profile.mouse_sensitivity = value)
	column.add_child(_sensitivity)
	column.add_child(_label("Volume"))
	_volume = _slider(0.0, 1.0, Profile.volume)
	_volume.value_changed.connect(func(value: float) -> void:
		Profile.volume = value
		Profile.apply_volume())
	column.add_child(_volume)
	column.add_child(_label("Graphics"))
	var graphics := GridContainer.new()
	graphics.columns = 2
	graphics.add_theme_constant_override("h_separation", 12)
	graphics.add_theme_constant_override("v_separation", 6)
	column.add_child(graphics)
	graphics.add_child(_small("Resolution"))
	var scale := OptionButton.new()
	for percent in RENDER_SCALES:
		scale.add_item("%d%%%s" % [percent, " (sharpest)" if percent == 100 else ""])
	scale.select(maxi(RENDER_SCALES.find(roundi(Profile.render_scale * 100)), 0))
	scale.item_selected.connect(func(index: int) -> void:
		Profile.render_scale = RENDER_SCALES[index] / 100.0
		Profile.apply_graphics())
	graphics.add_child(scale)
	graphics.add_child(_small("Anti-aliasing"))
	var aa := OptionButton.new()
	for option in ["Off", "2x", "4x"]:
		aa.add_item(option)
	aa.select(Profile.antialiasing)
	aa.item_selected.connect(func(index: int) -> void:
		Profile.antialiasing = index
		Profile.apply_graphics())
	graphics.add_child(aa)
	var shadows := CheckBox.new()
	shadows.text = "Shadows"
	shadows.button_pressed = Profile.shadows
	shadows.toggled.connect(func(on: bool) -> void:
		Profile.shadows = on
		Profile.apply_graphics())
	graphics.add_child(shadows)
	var vsync := CheckBox.new()
	vsync.text = "V-sync"
	vsync.button_pressed = Profile.vsync
	vsync.toggled.connect(func(on: bool) -> void:
		Profile.vsync = on
		Profile.apply_graphics())
	graphics.add_child(vsync)

	_fullscreen = CheckBox.new()
	_fullscreen.text = "Fullscreen (F11)"
	_fullscreen.toggled.connect(func(on: bool) -> void:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED))
	column.add_child(_fullscreen)

	column.add_child(_button("Resume", close))
	_leave = _button("Leave to the main menu", func() -> void: leave_requested.emit())
	column.add_child(_leave)
	column.add_child(_button("Quit the game", func() -> void: get_tree().quit()))


## `solo` pauses the game; `hosting` means leaving ends the session for everyone.
func open(solo: bool, hosting: bool) -> void:
	_title.text = "PAUSED" if solo else "MENU"
	_note.text = "Take your time." if solo else "The night doesn't stop while you're in here."
	get_tree().paused = solo
	_fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_leave.text = "End the session (everyone leaves)" if hosting else "Leave to the main menu"
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not is_open:
		return
	visible = false
	is_open = false
	get_tree().paused = false
	Profile.save_settings()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _input(event: InputEvent) -> void:
	if is_open and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	return label


func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.modulate.a = 0.8
	return label


func _slider(low: float, high: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(0, 28)
	return slider


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.add_theme_font_size_override("font_size", 19)
	button.pressed.connect(on_press)
	return button
