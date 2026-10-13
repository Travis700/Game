extends CanvasLayer
## Start menu: play solo, host a game, or join one. The school shows behind it.

signal solo_requested
signal host_requested
signal join_requested(address: String)

var _status: Label
var _address: LineEdit
var _buttons: Array[Button] = []


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

	column.add_child(_spacer(18))
	column.add_child(_button("Play solo", func() -> void: solo_requested.emit()))
	column.add_child(_button("Host a game", func() -> void: host_requested.emit()))

	column.add_child(_spacer(6))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	_address = LineEdit.new()
	_address.text = "127.0.0.1"
	_address.placeholder_text = "Host's address"
	_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_address.custom_minimum_size = Vector2(0, 44)
	_address.text_submitted.connect(func(text: String) -> void: join_requested.emit(text.strip_edges()))
	join_row.add_child(_address)
	var join := _button("Join", func() -> void: join_requested.emit(_address.text.strip_edges()))
	join.custom_minimum_size = Vector2(120, 44)
	join_row.add_child(join)
	column.add_child(join_row)

	var hint := Label.new()
	hint.text = "To test on one computer, host in one window and join 127.0.0.1 in another."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.modulate = Color(1, 1, 1, 0.5)
	hint.add_theme_font_size_override("font_size", 15)
	column.add_child(hint)

	column.add_child(_spacer(6))
	column.add_child(_button("Quit", func() -> void: get_tree().quit()))

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	column.add_child(_status)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func show_status(text: String) -> void:
	_status.text = text


## Greys the buttons out while a connection attempt is in progress.
func set_busy(busy: bool) -> void:
	for button in _buttons:
		button.disabled = busy
	_address.editable = not busy


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
