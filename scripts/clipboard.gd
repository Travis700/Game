extends CanvasLayer
## Your clipboard: the incident log for tonight. Each guard has their own.
## Open it with Tab, pick where and what, and log it. The time is filled in for you.
## Each line gets a tick or a cross (and what it paid) as soon as the host has checked it.

## `named` is the monster kind picked for a Monster log, or "" for "not sure".
signal log_submitted(area: String, type: String, named: String)
signal closed

const PAPER := Color(0.93, 0.9, 0.8)
const INK := Color(0.12, 0.12, 0.16)
const BOARD := Color(0.42, 0.29, 0.17)

var is_open := false

var _header: Label
var _entries: VBoxContainer
## Lines still waiting for the host's verdict, by log number.
var _by_id: Dictionary = {}
var _empty_note: Label
var _area: OptionButton
var _type: OptionButton
var _type_about: Label
var _name: OptionButton
var _log_button: Button
var _title: Label
var _guide_button: Button
var _log_page: VBoxContainer
var _guide_scroll: ScrollContainer
## What each kind of entry means, shown under the drop-downs.
const TYPE_HELP := {
	"Moved object": "Something is somewhere other than where it belongs.",
	"Missing object": "Something that's normally there is gone.",
	"Extra object": "Something that shouldn't be there at all.",
	"Figure": "A dark shape, standing still. It vanishes if you walk up to it.",
	"Noise": "A sound with nothing making it: a radio, static, whispering. Cameras don't pick these up: someone has to be there to hear it.",
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
	# Everything on the paper is typed.
	if Fonts.typed():
		var typed := Theme.new()
		typed.default_font = Fonts.typed()
		paper.theme = typed
	board.add_child(paper)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	paper.add_child(column)

	var title_row := HBoxContainer.new()
	_title = _label("INCIDENT LOG", 30)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_title)
	_guide_button = Button.new()
	_guide_button.text = "Field guide"
	_guide_button.custom_minimum_size = Vector2(130, 36)
	_guide_button.pressed.connect(_toggle_guide)
	title_row.add_child(_guide_button)
	column.add_child(title_row)
	_header = _label("", 17)
	_header.modulate.a = 0.75
	column.add_child(_header)
	column.add_child(HSeparator.new())

	_guide_scroll = ScrollContainer.new()
	_guide_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_guide_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_guide_scroll.visible = false
	column.add_child(_guide_scroll)
	_log_page = VBoxContainer.new()
	_log_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_page.add_theme_constant_override("separation", 10)
	column.add_child(_log_page)
	column = _log_page

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
	_name = OptionButton.new()
	_name.custom_minimum_size = Vector2(0, 40)
	column.add_child(_name)
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

	var hint := _label(KeyText.fill("{clip} or Esc to put the clipboard away"), 15)
	hint.modulate.a = 0.6
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(hint)


func set_areas(areas: Array[String]) -> void:
	_area.clear()
	for area in areas:
		_area.add_item(area)


func set_header(text: String) -> void:
	_header.text = text


## Lists the kinds of entry this night can have (some only turn up later in a run).
func set_night(night_number: int) -> void:
	var picked := _type.get_item_text(_type.selected) if _type.selected >= 0 else ""
	_type.clear()
	for type in Anomalies.TYPES:
		if night_number >= int(Anomalies.TYPE_FROM_NIGHT.get(type, 0)):
			_type.add_item(type)
			if type == picked:
				_type.select(_type.item_count - 1)
	_explain_type()


## Opens the clipboard. `area` pre-selects a location, e.g. the camera you were just looking at.
func open(area := "") -> void:
	for i in _area.item_count:
		if _area.get_item_text(i) == area:
			_area.select(i)
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fill_names()
	_show_guide(false)
	if not Input.get_connected_joypads().is_empty():
		_area.grab_focus.call_deferred()


func close() -> void:
	if not is_open:
		return
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func add_entry(time_text: String, area: String, type: String, log_id := 0) -> void:
	_empty_note.visible = false
	var entry := _label("%s   %s   —   %s" % [time_text, area, type], 18)
	_entries.add_child(entry)
	if log_id != 0:
		_by_id[log_id] = entry


## Ticks or crosses a line once the host has checked it, with what it paid.
func mark_entry(log_id: int, correct: bool, pay := "") -> void:
	var entry := _by_id.get(log_id) as Label
	if entry == null or not is_instance_valid(entry):
		return
	_by_id.erase(log_id)
	entry.text = ("✓  " if correct else "✗  ") + entry.text + ("   " + pay if pay != "" else "")
	entry.add_theme_color_override("font_color", Color(0.15, 0.45, 0.2) if correct else Color(0.65, 0.12, 0.1))


func clear_entries() -> void:
	_by_id.clear()
	for child in _entries.get_children():
		if child != _empty_note:
			child.queue_free()
	_empty_note.visible = true


func _input(event: InputEvent) -> void:
	var back := event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")
	if is_open and (event.is_action_pressed("clipboard") or event.is_action_pressed("pause") or back):
		get_viewport().set_input_as_handled()
		close()


func _on_log_pressed() -> void:
	if _area.selected < 0:
		return
	var type := _type.get_item_text(_type.selected)
	var named: String = _name.get_item_metadata(_name.selected) if type == "Monster" and _name.selected >= 0 else ""
	log_submitted.emit(_area.get_item_text(_area.selected), type, named)
	# A short pause so a double-click doesn't log the same thing twice.
	_log_button.disabled = true
	get_tree().create_timer(0.8).timeout.connect(func() -> void: _log_button.disabled = false)


func _explain_type() -> void:
	var type := _type.get_item_text(_type.selected)
	_type_about.text = TYPE_HELP.get(type, "")
	_name.visible = type == "Monster"
	if type == "Monster" and _name.item_count <= 1:
		_type_about.text += " Log one correctly and it goes in your field guide; after that you can name it here for +%d." % Night.NAME_POINTS


## The "which monster?" list: not sure, then every monster in this player's field guide.
func _fill_names() -> void:
	var previous: String = _name.get_item_metadata(_name.selected) if _name.selected >= 0 else ""
	_name.clear()
	_name.add_item("Which monster? Not sure")
	_name.set_item_metadata(0, "")
	for kind in FieldGuide.discovered():
		_name.add_item("It's " + FieldGuide.display_name(kind))
		_name.set_item_metadata(_name.item_count - 1, kind)
		if kind == previous:
			_name.select(_name.item_count - 1)
	_explain_type()


func _toggle_guide() -> void:
	_show_guide(not _guide_scroll.visible)


func _show_guide(on: bool) -> void:
	if on:
		for child in _guide_scroll.get_children():
			child.queue_free()
		_guide_scroll.add_child(FieldGuide.build_page(INK, 470))
	_guide_scroll.visible = on
	_log_page.visible = not on
	_title.text = "FIELD GUIDE" if on else "INCIDENT LOG"
	_guide_button.text = "Incident log" if on else "Field guide"


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
