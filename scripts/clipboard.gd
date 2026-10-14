extends CanvasLayer
## Your clipboard: the incident log for tonight. Each guard has their own.
## Open it with Tab, pick where and what, and log it. The time is filled in for you.
## You only find out how accurate your log was in the morning report.

signal log_submitted(area: String, type: String)
signal closed

const PAPER := Color(0.93, 0.9, 0.8)
const INK := Color(0.12, 0.12, 0.16)
const BOARD := Color(0.42, 0.29, 0.17)

var is_open := false

var _header: Label
var _entries: VBoxContainer
var _empty_note: Label
var _area: OptionButton
var _type: OptionButton
var _type_about: Label
var _log_button: Button
## What each kind of entry means, shown under the drop-downs.
const TYPE_HELP := {
	"Moved object": "Something is somewhere other than where it belongs.",
	"Missing object": "Something that's normally there is gone.",
	"Extra object": "Something that shouldn't be there at all.",
	"Figure": "A still, dark shape. It vanishes if you walk up to it.",
	"Monster": "Something that moves and comes after people. Log the area it's in right now.",
}


func _ready() -> void:
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var board := PanelContainer.new()
	board.custom_minimum_size = Vector2(560, 640)
	board.add_theme_stylebox_override("panel", _box_style(BOARD, 18, 14))
	center.add_child(board)

	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _box_style(PAPER, 4, 26))
	board.add_child(paper)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	paper.add_child(column)

	column.add_child(_label("INCIDENT LOG", 30))
	_header = _label("", 17)
	_header.modulate.a = 0.75
	column.add_child(_header)
	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_entries = VBoxContainer.new()
	_entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entries.add_theme_constant_override("separation", 6)
	scroll.add_child(_entries)
	_empty_note = _label("Nothing logged yet. Anything out of place on the cameras goes here.", 17)
	_empty_note.modulate.a = 0.6
	_empty_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_entries.add_child(_empty_note)

	column.add_child(HSeparator.new())
	column.add_child(_label("New entry", 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_area = OptionButton.new()
	_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_area.custom_minimum_size = Vector2(0, 40)
	row.add_child(_area)
	_type = OptionButton.new()
	_type.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_type.custom_minimum_size = Vector2(0, 40)
	for type in Anomalies.TYPES:
		_type.add_item(type)
	row.add_child(_type)
	column.add_child(row)
	_type_about = _label("", 15)
	_type_about.modulate.a = 0.7
	_type_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_type_about)
	_type.item_selected.connect(func(_index: int) -> void: _explain_type())
	_explain_type()

	_log_button = Button.new()
	_log_button.text = "Log it"
	_log_button.custom_minimum_size = Vector2(0, 44)
	_log_button.add_theme_font_size_override("font_size", 20)
	_log_button.pressed.connect(_on_log_pressed)
	column.add_child(_log_button)

	var hint := _label("Tab or Esc to put the clipboard away", 15)
	hint.modulate.a = 0.6
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func set_areas(areas: Array[String]) -> void:
	_area.clear()
	for area in areas:
		_area.add_item(area)


func set_header(text: String) -> void:
	_header.text = text


## Opens the clipboard. `area` pre-selects a location, e.g. the camera you were just looking at.
func open(area := "") -> void:
	for i in _area.item_count:
		if _area.get_item_text(i) == area:
			_area.select(i)
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


func add_entry(time_text: String, area: String, type: String) -> void:
	_empty_note.visible = false
	var entry := _label("%s   %s   —   %s" % [time_text, area, type], 18)
	_entries.add_child(entry)


func clear_entries() -> void:
	for child in _entries.get_children():
		if child != _empty_note:
			child.queue_free()
	_empty_note.visible = true


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("clipboard") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _on_log_pressed() -> void:
	if _area.selected < 0:
		return
	log_submitted.emit(_area.get_item_text(_area.selected), _type.get_item_text(_type.selected))
	# A short pause so a double-click doesn't log the same thing twice.
	_log_button.disabled = true
	get_tree().create_timer(0.8).timeout.connect(func() -> void: _log_button.disabled = false)


func _explain_type() -> void:
	_type_about.text = TYPE_HELP.get(_type.get_item_text(_type.selected), "")


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", INK)
	return label


func _box_style(color: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style
