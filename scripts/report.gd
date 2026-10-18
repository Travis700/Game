extends CanvasLayer
## The end-of-night report: each guard's pay for the night and the team's results.

## Leave the session from the report (the host ends it for everyone).
signal leave_requested
signal next_night_requested
## The host chose to keep going after the ninth night.
signal overtime_requested

var _title: Label
var _table: GridContainer
var _summary: Label
var _next_button: Button
var _overtime_button: Button
var _waiting: Label
var _ready_button: Button
## The next-night button's text, before the ready count goes on the end.
var _next_text := ""
## Host: the other players who've said they're ready.
var _ready_peers: Dictionary = {}
const WAITING := "Waiting for the host to start the next night..."
## A promotion earned with this night's XP, shown at the bottom of the next report.
var promotion := ""
## Tonight's incident photos so far: [texture, caption]. Shown (the last four) on the report.
var incidents: Array = []
var _incidents_row: HBoxContainer

const COLUMNS := ["Guard", "Clocked out", "Correct logs", "False reports", "Round", "Tonight's pay", "Total", "XP"]


func _ready() -> void:
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 0.85)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(1080, 0)
	outer.add_theme_constant_override("separation", 16)
	center.add_child(outer)
	# Everything above the buttons scrolls if a big team's night won't fit, so the buttons
	# always stay on screen.
	_body_scroll = ScrollContainer.new()
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(_body_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	_body_scroll.add_child(column)
	_body = column

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 56 if Fonts.title() else 44)
	if Fonts.title():
		_title.add_theme_font_override("font", Fonts.title())
	column.add_child(_title)

	_table = GridContainer.new()
	_table.columns = COLUMNS.size()
	_table.add_theme_constant_override("h_separation", 28)
	_table.add_theme_constant_override("v_separation", 10)
	column.add_child(_table)

	_incidents_row = HBoxContainer.new()
	_incidents_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_incidents_row.add_theme_constant_override("separation", 14)
	column.add_child(_incidents_row)

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
	outer.add_child(_next_button)
	_overtime_button = Button.new()
	_overtime_button.custom_minimum_size = Vector2(0, 52)
	_overtime_button.add_theme_font_size_override("font_size", 22)
	_overtime_button.pressed.connect(func() -> void: overtime_requested.emit())
	outer.add_child(_overtime_button)

	var leave := Button.new()
	leave.text = "Leave"
	leave.flat = true
	leave.add_theme_font_size_override("font_size", 16)
	leave.modulate.a = 0.7
	leave.pressed.connect(func() -> void: leave_requested.emit())
	outer.add_child(leave)

	# Everyone but the host: say you're done reading, so the host knows when to go on.
	_ready_button = Button.new()
	_ready_button.toggle_mode = true
	_ready_button.text = "I'm ready"
	_ready_button.custom_minimum_size = Vector2(0, 44)
	_ready_button.add_theme_font_size_override("font_size", 20)
	_ready_button.toggled.connect(func(on: bool) -> void:
		_ready_button.text = "Ready ✓" if on else "I'm ready"
		if multiplayer.multiplayer_peer and not multiplayer.is_server():
			_request_ready.rpc_id(1, on))
	outer.add_child(_ready_button)

	_waiting = Label.new()
	_waiting.text = WAITING
	_waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting.modulate.a = 0.7
	outer.add_child(_waiting)


## `rows` is one dictionary per guard; see Night._build_report.
## `outcome` is "night" (an ordinary night), "caught" (everyone was caught, back to night 1),
## "checkpoint:N" (caught, back to night N), "fired:N" (three write-ups, back to night N), "won", "overtime", "daily" or "training".
var _body_scroll: ScrollContainer
var _body: VBoxContainer
## Room kept on screen below the report for its buttons (virtual pixels).
const BUTTONS_ROOM := 300.0


## Fits the scrolling part to whatever it holds, up to what leaves the buttons on screen.
func _fit_body() -> void:
	var room := get_viewport().get_visible_rect().size.y - BUTTONS_ROOM
	_body_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, maxf(room, 200.0))


func show_report(night: int, rows: Array, summary: String, is_host: bool, outcome := "night") -> void:
	match outcome:
		"caught":
			_title.text = "NIGHT %d: EVERYONE WAS CAUGHT" % night
		"won":
			_title.text = "NIGHT %d: YOU MADE IT. THE RUN IS WON" % night
		"daily":
			_title.text = "DAILY SHIFT: NIGHT %d" % night
		"training":
			_title.text = "TRAINING COMPLETE"
		"overtime":
			_title.text = "OVERTIME: NIGHT %d SURVIVED" % night
		_:
			_title.text = "NIGHT %d REPORT" % night
	if outcome.begins_with("checkpoint"):
		_title.text = "NIGHT %d: EVERYONE WAS CAUGHT" % night
	elif outcome.begins_with("fired"):
		_title.text = "NIGHT %d: FIRED" % night
	for child in _table.get_children():
		child.queue_free()
	for heading in COLUMNS:
		_table.add_child(_cell(heading, 18, 0.6))
	for row: Dictionary in rows:
		_table.add_child(_cell(row["name"], 22))
		_table.add_child(_cell("Joined late" if row.get("late", false) else "Caught" if row.get("died", false) else ("Yes" if row["clocked_out"] else "No"), 22))
		_table.add_child(_cell("%d  (+%d)" % [row["correct"], row["correct_points"]], 22))
		_table.add_child(_cell("%d  (-%d)" % [row["false"], row["false_points"]], 22))
		_table.add_child(_cell("%d  (%+d)" % [row.get("punched", 0), row.get("round_points", 0)], 22))
		_table.add_child(_cell("points lost" if row.get("lost", false) else "%+d" % row["pay"], 22))
		_table.add_child(_cell(str(row["total"]), 22))
		_table.add_child(_cell("+%d" % row.get("xp", 0), 22))
	_show_incidents()
	_summary.text = summary
	# How each guard who didn't make it went.
	for row: Dictionary in rows:
		if str(row.get("fate", "")) != "":
			_summary.text += "\n%s: %s." % [str(row["name"]).get_slice("  #", 0), row["fate"]]
	if outcome != "training":
		_summary.text += "\nYour field guide: %d of %d monsters   ·   case file stamps: %d of %d" % [FieldGuide.discovered().size(),
				FieldGuide.ENTRIES.size(), Career.stamp_count(), Career.MONSTER_KINDS.size() * Career.STAMPS.size()]
	if promotion != "":
		_summary.text += "\n\n★ " + promotion + " ★"
		promotion = ""
	_next_button.text = "Back to night %d" % outcome.get_slice(":", 1).to_int() if ":" in outcome else {"caught": "Start over from night 1", "won": "Start a new run", "daily": "Back to the menu", "training": "Start night 1"}.get(outcome, "Start night %d" % (night + 1))
	_next_text = _next_button.text
	_ready_peers.clear()
	_ready_button.set_pressed_no_signal(false)
	_ready_button.text = "I'm ready"
	_ready_button.visible = not is_host
	_show_ready(0, multiplayer.get_peers().size() if multiplayer.multiplayer_peer else 0)
	_next_button.visible = is_host
	_overtime_button.visible = is_host and outcome == "won"
	_overtime_button.text = "Keep going: Overtime (night %d)" % (night + 1)
	_waiting.visible = not is_host
	visible = true
	_fit_body.call_deferred()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_host and not Input.get_connected_joypads().is_empty():
		_next_button.grab_focus.call_deferred()


## Every computer: a camera still of a guard being caught, for tonight's report.
func add_incident(image: Image, caption: String) -> void:
	if image == null:
		return
	image.resize(240, 135)
	incidents.append([ImageTexture.create_from_image(image), caption])


func _show_incidents() -> void:
	for child in _incidents_row.get_children():
		child.queue_free()
	for incident: Array in incidents.slice(-4):
		var box := VBoxContainer.new()
		var picture := TextureRect.new()
		picture.texture = incident[0]
		picture.custom_minimum_size = Vector2(240, 135)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		box.add_child(picture)
		var caption := _cell(incident[1], 13, 0.75)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.custom_minimum_size = Vector2(240, 0)
		box.add_child(caption)
		_incidents_row.add_child(box)
	_incidents_row.visible = not incidents.is_empty()
	incidents.clear()


func hide_report() -> void:
	visible = false


func _cell(text: String, size: int, alpha := 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate.a = alpha
	return label


@rpc("any_peer", "call_remote", "reliable")
func _request_ready(on: bool) -> void:
	if not multiplayer.is_server() or not visible:
		return
	var peer := multiplayer.get_remote_sender_id()
	if on:
		_ready_peers[peer] = true
	else:
		_ready_peers.erase(peer)
	# Only players still here count.
	for gone: int in _ready_peers.keys():
		if gone not in multiplayer.get_peers():
			_ready_peers.erase(gone)
	_set_ready_count.rpc(_ready_peers.size(), multiplayer.get_peers().size())


## Host: someone left; the tally goes out again without them.
func recount_ready() -> void:
	if not multiplayer.is_server() or not visible:
		return
	for gone: int in _ready_peers.keys():
		if gone not in multiplayer.get_peers():
			_ready_peers.erase(gone)
	_set_ready_count.rpc(_ready_peers.size(), multiplayer.get_peers().size())


## Every computer: how many of the others are ready ("2 of 3 ready").
@rpc("authority", "call_local", "reliable")
func _set_ready_count(count: int, of: int) -> void:
	_show_ready(count, of)


func _show_ready(count: int, of: int) -> void:
	var tally := "   (%d of %d ready)" % [count, of] if of > 0 else ""
	_next_button.text = _next_text + tally
	_waiting.text = WAITING + tally
