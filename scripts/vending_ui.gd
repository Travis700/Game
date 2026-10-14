extends CanvasLayer
## The vending machine's menu: what's for sale, what it does, and your points.

signal buy_requested(item: String)
signal closed

var is_open := false

var _points: Label
var _holding: Label
## Items only useful with teammates: item id -> its Buy button.
var _coop_buttons: Dictionary = {}
## Item -> its Buy button.
var _buy_buttons: Dictionary = {}
var _first_buy: Array = []
## The co-op-only items.
const COOP_ONLY: Array[String] = ["lucky_charm"]


func _ready() -> void:
	visible = false
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.14, 0.96)
	style.border_color = Color(0.7, 0.85, 1.0, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var title := Label.new()
	title.text = "STAFF VENDING"
	title.add_theme_font_size_override("font_size", 30)
	column.add_child(title)
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", 20)
	_points.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	column.add_child(_points)
	_holding = Label.new()
	_holding.add_theme_font_size_override("font_size", 17)
	_holding.modulate.a = 0.75
	column.add_child(_holding)
	column.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 520)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 14)
	scroll.add_child(rows)

	for item: String in Shop.ITEMS:
		var info: Dictionary = Shop.ITEMS[item]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var text := VBoxContainer.new()
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = "%s   ·   %d points" % [info["name"], info["price"]]
		name_label.add_theme_font_size_override("font_size", 20)
		text.add_child(name_label)
		var about := Label.new()
		about.text = info["about"]
		about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		about.custom_minimum_size = Vector2(420, 0)
		about.add_theme_font_size_override("font_size", 15)
		about.modulate.a = 0.75
		text.add_child(about)
		row.add_child(text)
		var buy := Button.new()
		buy.text = "Buy"
		buy.custom_minimum_size = Vector2(110, 44)
		buy.pressed.connect(func() -> void: buy_requested.emit(item))
		if _first_buy.is_empty():
			_first_buy.append(buy)
		_buy_buttons[item] = buy
		if item in COOP_ONLY:
			_coop_buttons[item] = buy
		row.add_child(buy)
		rows.add_child(row)

	var hint := Label.new()
	hint.text = "Tab, Esc or E to close."
	hint.modulate.a = 0.55
	hint.add_theme_font_size_override("font_size", 15)
	column.add_child(hint)


## `solo` greys out the things that only help a team, and `rank` the ones this guard can't buy yet.
func open(points: int, holding: String, solo := false, rank := 1) -> void:
	for item: String in _buy_buttons:
		var button: Button = _buy_buttons[item]
		var needed := Shop.rank_needed(item)
		if rank < needed:
			button.disabled = true
			button.text = "Rank %d" % needed
			button.tooltip_text = "Reach %s to buy this." % Career.rank_title(needed)
		elif solo and item in COOP_ONLY:
			button.disabled = true
			button.text = "Co-op only"
		else:
			button.disabled = false
			button.text = "Buy"
	refresh(points, holding)
	visible = true
	is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if not Input.get_connected_joypads().is_empty() and not _first_buy.is_empty():
		(_first_buy[0] as Button).grab_focus.call_deferred()


func refresh(points: int, holding: String) -> void:
	_points.text = "Your points: %d" % points
	_holding.text = "Carrying: %s" % (Shop.item_name(holding) if holding != "" else "nothing")


func close() -> void:
	if not is_open:
		return
	visible = false
	is_open = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _input(event: InputEvent) -> void:
	# E closes it from the keyboard; on a controller A presses Buy, so B (or Start) closes it.
	var interact_key := event is InputEventKey and event.is_action_pressed("interact")
	var back := event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")
	if is_open and (event.is_action_pressed("clipboard") or event.is_action_pressed("pause") or interact_key or back):
		get_viewport().set_input_as_handled()
		close()
