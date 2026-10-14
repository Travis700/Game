extends CanvasLayer
## The menu's "Records" page: career stats, best run scores, achievements and the field guide.

signal closed

var _body: VBoxContainer


func _ready() -> void:
	layer = 15
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 1.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)
	var title := Label.new()
	title.text = "RECORDS"
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	scroll.add_child(_body)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	column.add_child(back)


func open() -> void:
	_fill()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _fill() -> void:
	for child in _body.get_children():
		child.queue_free()
	_heading("Career")
	for stat: String in Career.STATS:
		_line("%s: %d" % [Career.STATS[stat], Career.stat(stat)])
	_line("Monsters in your field guide: %d of %d" % [FieldGuide.discovered().size(), FieldGuide.ENTRIES.size()])

	_heading("Best scores (runs won)")
	var scores := Career.best_scores()
	if scores.is_empty():
		_line("None yet. Survive all nine nights to set one.", 0.6)
	for i in scores.size():
		var entry: Dictionary = scores[i]
		var team := int(entry.get("guards", 1))
		_line("%d.  %d points   ·   difficulty %d, %s   ·   %s" % [i + 1, int(entry["points"]), int(entry.get("difficulty", 1)),
				"solo" if team == 1 else "%d guards" % team, entry.get("date", "")])

	var unlocked := Career.unlocked()
	_heading("Achievements (%d of %d)" % [unlocked.size(), Career.ACHIEVEMENTS.size()])
	for key: String in Career.ACHIEVEMENTS:
		var info: Array = Career.ACHIEVEMENTS[key]
		var got := unlocked.has(key)
		_line("%s  %s  —  %s" % ["✓" if got else "·", info[0], info[1]], 1.0 if got else 0.5)

	_heading("Field guide")
	_body.add_child(FieldGuide.build_page(Color(0.92, 0.92, 0.95), 720))


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_body.add_child(label)


func _line(text: String, alpha := 1.0) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(720, 0)
	label.add_theme_font_size_override("font_size", 17)
	label.modulate.a = alpha
	_body.add_child(label)
