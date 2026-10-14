extends CanvasLayer
## The end-of-night report: each guard's pay for the night and the team's results.

signal next_night_requested

var _title: Label
var _table: GridContainer
var _summary: Label
var _next_button: Button
var _waiting: Label

const COLUMNS := ["Guard", "Clocked out", "Correct logs", "False reports", "Tonight's pay", "Total"]


func _ready() -> void:
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(900, 0)
	column.add_theme_constant_override("separation", 16)
	center.add_child(column)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 44)
	column.add_child(_title)

	_table = GridContainer.new()
	_table.columns = COLUMNS.size()
	_table.add_theme_constant_override("h_separation", 28)
	_table.add_theme_constant_override("v_separation", 10)
	column.add_child(_table)

	_summary = Label.new()
	_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_theme_font_size_override("font_size", 20)
	_summary.modulate.a = 0.8
	column.add_child(_summary)

	_next_button = Button.new()
	_next_button.custom_minimum_size = Vector2(0, 52)
	_next_button.add_theme_font_size_override("font_size", 22)
	_next_button.pressed.connect(func() -> void: next_night_requested.emit())
	column.add_child(_next_button)

	_waiting = Label.new()
	_waiting.text = "Waiting for the host to start the next night..."
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting.modulate.a = 0.7
	column.add_child(_waiting)


## `rows` is one dictionary per guard; see Night._build_report.
## `outcome` is "night" (an ordinary night), "caught" (everyone was caught) or "won" (the last night).
func show_report(night: int, rows: Array, summary: String, is_host: bool, outcome := "night") -> void:
	match outcome:
		"caught":
			_title.text = "NIGHT %d: EVERYONE WAS CAUGHT" % night
		"won":
			_title.text = "NIGHT %d: YOU MADE IT. THE RUN IS WON" % night
		_:
			_title.text = "NIGHT %d REPORT" % night
	for child in _table.get_children():
		child.queue_free()
	for heading in COLUMNS:
		_table.add_child(_cell(heading, 18, 0.6))
	for row: Dictionary in rows:
		_table.add_child(_cell(row["name"], 22))
		_table.add_child(_cell("Caught" if row.get("died", false) else ("Yes" if row["clocked_out"] else "No"), 22))
		_table.add_child(_cell("%d  (+%d)" % [row["correct"], row["correct_points"]], 22))
		_table.add_child(_cell("%d  (-%d)" % [row["false"], row["false_points"]], 22))
		_table.add_child(_cell("points lost" if row.get("lost", false) else "%+d" % row["pay"], 22))
		_table.add_child(_cell(str(row["total"]), 22))
	_summary.text = summary
	_next_button.text = {"caught": "Start over from night 1", "won": "Start a new run"}.get(outcome, "Start night %d" % (night + 1))
	_next_button.visible = is_host
	_waiting.visible = not is_host
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_report() -> void:
	visible = false


func _cell(text: String, size: int, alpha := 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate.a = alpha
	return label
