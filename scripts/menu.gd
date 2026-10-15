extends CanvasLayer
## Start menu: play solo, host a game, or join one. The school shows behind it.

signal solo_requested
signal host_requested
signal daily_requested
signal training_requested
signal join_requested(address: String)

## Night length choices: the label and real seconds per in-game minute.
const NIGHT_LENGTHS := [["Short nights (8 min)", 1.35], ["Normal nights (12 min)", 2.0], ["Long nights (16 min)", 2.7]]
## What each difficulty adds to the map. Auto picks one level per guard (up to 3).
const DIFFICULTIES := [
	["Auto: one level per guard", "Picks the map size from the team: 1 guard plays difficulty 1, 2 guards play 2, and 3 or 4 guards play 3."],
	["1 · Main building", "The gate, lobby, front office, main hall, cafeteria, kitchen and gym. Best for one guard."],
	["2 · + Classroom wing", "Opens the west wing: classrooms, the library and the nurse's office, and the Substitute, the Librarian, the Nurse and the Twins who work there. Best for two guards."],
	["3 · + Science wing", "Opens the east wing too: the science lab, art room and locker rooms, with the Specimen, the Self-Portrait, the Understudy, the Crossing Guard and the Coach. Best for three or four guards."],
]

const HowToPlay := preload("res://scripts/how_to_play.gd")
const Records := preload("res://scripts/records.gd")
const Credits := preload("res://scripts/credits.gd")

var _how_to_play: CanvasLayer
var _records: CanvasLayer
var _credits: CanvasLayer
var _steam_label: Label
var _rank_label: Label
var _rank_bar: ProgressBar
var _hat: OptionButton
var _perk: OptionButton
var _perk_text: Label
var _daily_label: Label
var _daily_friends: Label
var _status: Label
var _address: LineEdit
var _password: LineEdit
var _buttons: Array[Button] = []
var _difficulty: OptionButton
var _difficulty_about: Label
var _keep_gear: CheckBox
var _night_length: OptionButton
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
	# A dark panel behind the menu so it reads clearly over the school.
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.07, 0.82)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	panel.add_child(column)

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
	_rank_label = Label.new()
	_rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_rank_label)
	_rank_bar = ProgressBar.new()
	_rank_bar.show_percentage = false
	_rank_bar.custom_minimum_size = Vector2(0, 8)
	column.add_child(_rank_bar)
	var hat_row := HBoxContainer.new()
	hat_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hat_row.add_theme_constant_override("separation", 10)
	var hat_label := Label.new()
	hat_label.text = "Hat"
	hat_row.add_child(hat_label)
	_hat = OptionButton.new()
	_hat.custom_minimum_size = Vector2(320, 0)
	_hat.item_selected.connect(func(index: int) -> void:
		Profile.hat = _hat.get_item_metadata(index)
		Profile.save_settings())
	hat_row.add_child(_hat)
	column.add_child(hat_row)
	var perk_row := HBoxContainer.new()
	perk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	perk_row.add_theme_constant_override("separation", 10)
	var perk_label := Label.new()
	perk_label.text = "Perk"
	perk_row.add_child(perk_label)
	_perk = OptionButton.new()
	_perk.custom_minimum_size = Vector2(320, 0)
	_perk.item_selected.connect(func(index: int) -> void:
		Profile.perk = _perk.get_item_metadata(index)
		Profile.save_settings()
		_perk_text.text = Perks.PERKS[Profile.perk]["text"])
	perk_row.add_child(_perk)
	column.add_child(perk_row)
	_perk_text = Label.new()
	_perk_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_perk_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_perk_text.add_theme_font_size_override("font_size", 14)
	_perk_text.modulate.a = 0.75
	column.add_child(_perk_text)
	_show_rank()
	visibility_changed.connect(func() -> void:
		if visible:
			_show_rank())
	_steam_label = Label.new()
	_steam_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_steam_label.add_theme_font_size_override("font_size", 15)
	_steam_label.modulate.a = 0.7
	column.add_child(_steam_label)

	column.add_child(_spacer(10))
	_add_run_options(column)
	column.add_child(_spacer(6))
	var play_row := HBoxContainer.new()
	play_row.add_theme_constant_override("separation", 8)
	var solo := _button("Play solo", func() -> void: solo_requested.emit())
	solo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_row.add_child(solo)
	var daily := _button("Daily shift", func() -> void: daily_requested.emit())
	daily.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_row.add_child(daily)
	var training := _button("Training" if Profile.training_done else "Training (start here)", func() -> void: training_requested.emit())
	training.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_row.add_child(training)
	column.add_child(play_row)
	_daily_label = Label.new()
	_daily_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daily_label.add_theme_font_size_override("font_size", 14)
	_daily_label.modulate.a = 0.7
	column.add_child(_daily_label)
	_daily_friends = Label.new()
	_daily_friends.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_daily_friends.add_theme_font_size_override("font_size", 14)
	_daily_friends.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_daily_friends.visible = false
	column.add_child(_daily_friends)
	SteamService.leaderboard_loaded.connect(_on_leaderboard_loaded)
	_show_rank()
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
	how = _button("Records", func() -> void: _records.open())
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(how)
	how = _button("Credits", func() -> void: _credits.open())
	how.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(how)
	var quit := _button("Quit", func() -> void: get_tree().quit())
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(quit)
	column.add_child(bottom_row)
	_how_to_play = HowToPlay.new()
	add_child(_how_to_play)
	_records = Records.new()
	add_child(_records)
	_credits = Credits.new()
	add_child(_credits)

	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "dev")
	version.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 16
	version.offset_top = -34
	version.modulate.a = 0.4
	add_child(version)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	column.add_child(_status)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# With a controller, start on the first button so the D-pad can move around the menu.
	if not Input.get_connected_joypads().is_empty():
		_buttons[0].grab_focus.call_deferred()


## The host's choices for the run: {"difficulty": 0-3 (0 = auto), "keep_gear", "continue"}.
func options() -> Dictionary:
	return {
		"difficulty": _difficulty.selected,
		"hardcore": _keep_gear.button_pressed,
		"continue": _continue.visible and _continue.button_pressed,
		"password": _password.text,
		"seconds_per_minute": float(NIGHT_LENGTHS[maxi(_night_length.selected, 0)][1]),
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
	_keep_gear.text = "Hardcore"
	_keep_gear.tooltip_text = "Normally, if the whole team is caught you go back to the last checkpoint (nights 1, 4 and 7) with your gear and half your points. Hardcore: back to night 1 with nothing."
	_keep_gear.button_pressed = bool(saved.get("hardcore", false))
	_keep_gear.add_theme_font_size_override("font_size", 17)
	_keep_gear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_child(_keep_gear)
	_night_length = OptionButton.new()
	for entry: Array in NIGHT_LENGTHS:
		_night_length.add_item(entry[0])
	_night_length.select(clampi(int(Profile.get("night_length")), 0, NIGHT_LENGTHS.size() - 1))
	_night_length.item_selected.connect(func(index: int) -> void:
		Profile.set("night_length", index)
		Profile.save_settings())
	row.add_child(_night_length)
	column.add_child(row)

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


## Shows whether Steam is on, and changes the join hint to match.
func set_steam_status(on: bool, user_name: String) -> void:
	_steam_label.text = ("Steam: signed in as %s. Hosting makes a Steam lobby; friends join with its 6-letter code or an invite." % user_name) if on \
			else "Steam isn't running: playing over direct connections."
	if on:
		_address.text = ""
		_address.placeholder_text = "Friend's 6-letter lobby code"


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


## "Rank 3 · Patrol Officer · 1,450 / 2,500 XP", with a bar to the next rank, and the hats.
func _show_rank() -> void:
	_fill_hats()
	_fill_perks()
	if _daily_label == null:
		return
	var today := Daily.today()
	var best := Career.daily_best(today)
	_daily_label.text = "Today's daily shift (solo, the same for everyone): %s%s%s" % [Daily.describe(today),
			"   ·   your best: %d" % best if best >= 0 else "",
			"   ·   %d days in a row" % Career.daily_streak() if Career.daily_streak() > 1 else ""]
	SteamService.request_friends_scores(SteamService.daily_board(today))
	var xp := Career.xp()
	var rank := Career.rank()
	var floor_xp: int = Career.RANKS[rank - 1][0]
	var next := Career.next_rank_xp(rank)
	if next < 0:
		_rank_label.text = "Rank %d · %s · %d XP" % [rank, Career.rank_title(rank), xp]
		_rank_bar.value = _rank_bar.max_value
	else:
		_rank_label.text = "Rank %d · %s · %d / %d XP" % [rank, Career.rank_title(rank), xp, next]
		_rank_bar.max_value = next - floor_xp
		_rank_bar.value = xp - floor_xp


## Every hat: unlocked ones to pick, locked ones greyed out with what unlocks them.
func _fill_hats() -> void:
	_hat.clear()
	for hat: String in Hats.HATS:
		var unlocked := Hats.is_unlocked(hat)
		_hat.add_item(Hats.HATS[hat]["name"] if unlocked else "%s  (%s)" % [Hats.HATS[hat]["name"], Hats.requirement(hat)])
		var index := _hat.item_count - 1
		_hat.set_item_metadata(index, hat)
		_hat.set_item_disabled(index, not unlocked)
		if hat == Profile.hat and unlocked:
			_hat.select(index)


## Every perk: unlocked ones to pick, locked ones greyed out with the rank that unlocks them.
func _fill_perks() -> void:
	_perk.clear()
	var current := Perks.valid(Profile.perk)
	for perk: String in Perks.PERKS:
		var unlocked := Perks.is_unlocked(perk)
		var info: Dictionary = Perks.PERKS[perk]
		_perk.add_item(info["name"] if unlocked else "%s  (rank %d)" % [info["name"], info["rank"]])
		var index := _perk.item_count - 1
		_perk.set_item_metadata(index, perk)
		_perk.set_item_disabled(index, not unlocked)
		if perk == current:
			_perk.select(index)
	_perk_text.text = Perks.PERKS[current]["text"]


## Friends' daily shift scores from Steam, e.g. "Friends today: 1. Sam 340  ·  2. You 180".
func _on_leaderboard_loaded(board: String, entries: Array) -> void:
	if board != SteamService.daily_board(Daily.today()) or entries.is_empty():
		return
	var parts: Array[String] = []
	for i in mini(entries.size(), 5):
		var entry: Dictionary = entries[i]
		parts.append("%d. %s %d" % [i + 1, "You" if entry.get("me", false) else entry["name"], entry["score"]])
	_daily_friends.text = "Friends today: " + "  ·  ".join(parts)
	_daily_friends.visible = true
