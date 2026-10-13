extends CanvasLayer
## The time clock's keypad. Guards clock in by typing the number on their badge.

signal submitted(number: int)
signal closed

var is_open := false
var _display: Label
var _hint: Label
var _typed := ""


func _ready() -> void:
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.18, 0.97)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)

	var title := Label.new()
	title.text = "TIME CLOCK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)

	var screen := PanelContainer.new()
	var screen_style := StyleBoxFlat.new()
	screen_style.bg_color = Color(0.03, 0.1, 0.04)
	screen_style.set_content_margin_all(10)
	screen.add_theme_stylebox_override("panel", screen_style)
	_display = Label.new()
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.custom_minimum_size = Vector2(240, 0)
	_display.add_theme_font_size_override("font_size", 36)
	_display.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	screen.add_child(_display)
	column.add_child(screen)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for key: String in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "Clear", "0", "Enter"]:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size = Vector2(76, 52)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_press.bind(key))
		grid.add_child(button)
	column.add_child(grid)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.modulate.a = 0.7
	column.add_child(_hint)


func open(badge: String) -> void:
	_typed = ""
	_refresh()
	_hint.text = "Your badge reads %s. Type it and press Enter.\nEsc to step away." % badge
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	if not is_open:
		return
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Shows a short reply on the clock's screen, e.g. "UNKNOWN".
func flash_display(text: String) -> void:
	_display.text = text
	_typed = ""


func _press(key: String) -> void:
	match key:
		"Clear":
			_typed = ""
		"Enter":
			if _typed != "":
				submitted.emit(_typed.to_int())
			return
		_:
			if _typed.length() < 4:
				_typed += key
	_refresh()


func _refresh() -> void:
	_display.text = "#" + _typed.rpad(4, "_")


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	if key.keycode >= KEY_0 and key.keycode <= KEY_9:
		_press(str(key.keycode - KEY_0))
	elif key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
		_press(str(key.keycode - KEY_KP_0))
	elif key.keycode == KEY_BACKSPACE:
		_typed = _typed.left(-1)
		_refresh()
	elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		_press("Enter")
	elif key.keycode == KEY_ESCAPE or key.keycode == KEY_TAB:
		close()
