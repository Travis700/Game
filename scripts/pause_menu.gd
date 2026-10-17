extends CanvasLayer
## The Esc menu: settings, and leaving the game. Playing solo it pauses the game; in a group
## the night carries on (other guards are still playing), so your guard just stands still.

signal closed
signal leave_requested
## The host wants this player out of the session.
signal kick_requested(peer_id: int)

## Voice chat modes: setting value, and what the menu calls it.
const VOICE_MODES := [["push", "Push to talk"], ["open", "Open mic"], ["off", "Off"]]
## Choices for the 3D resolution, as a percentage of the window.
const RENDER_SCALES: Array[int] = [100, 85, 70, 50]

var is_open := false
var _title: Label
var _note: Label
var _sensitivity: HSlider
var _volume: HSlider
var _fullscreen: CheckBox
var _leave: Button
var _invite: Button
var _resume: Button
## Set by Main, for the microphone level meter and to apply the voice settings.
var voice: VoiceChat
var _mic_meter: ProgressBar
var _main_column: VBoxContainer
var _scroll: ScrollContainer
var _keys: VBoxContainer
var _key_buttons: Dictionary = {}
var _key_help: Label
const KEYS_HELP := "Click a key, then press the new one (Esc to cancel). Taking a key another action uses swaps them. Arrow keys and the mouse keep working too."
## The action waiting for a key press, or "".
var _listening := ""


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
	# The settings scroll if the window is too short for all of them.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(460, 0)
	panel.add_child(scroll)
	_scroll = scroll
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	_main_column = column
	_build_keys(panel)

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
	column.add_child(_label("Field of view"))
	var fov := _slider(60.0, 100.0, Profile.fov)
	fov.step = 1.0
	fov.value_changed.connect(func(value: float) -> void: Profile.fov = value)
	column.add_child(fov)
	column.add_child(_label("Brightness"))
	var brightness := _slider(0.6, 1.8, Profile.brightness)
	brightness.value_changed.connect(func(value: float) -> void:
		Profile.brightness = value
		Profile.apply_brightness())
	column.add_child(brightness)
	column.add_child(_label("Volume"))
	_volume = _slider(0.0, 1.0, Profile.volume)
	_volume.value_changed.connect(func(value: float) -> void:
		Profile.volume = value
		Profile.apply_volume())
	column.add_child(_volume)
	column.add_child(_label("Voice chat"))
	var voice_grid := GridContainer.new()
	voice_grid.columns = 2
	voice_grid.add_theme_constant_override("h_separation", 12)
	voice_grid.add_theme_constant_override("v_separation", 6)
	column.add_child(voice_grid)
	voice_grid.add_child(_small("Microphone"))
	var mode := OptionButton.new()
	for option in VOICE_MODES:
		mode.add_item(option[1])
	mode.select(maxi(VOICE_MODES.map(func(entry: Array) -> String: return entry[0]).find(Profile.voice_mode), 0))
	mode.item_selected.connect(func(index: int) -> void:
		Profile.voice_mode = VOICE_MODES[index][0]
		if voice:
			voice.set_active(true))
	voice_grid.add_child(mode)
	voice_grid.add_child(_small("Device"))
	var device := OptionButton.new()
	device.add_item("System default")
	for device_name in AudioServer.get_input_device_list():
		if device_name != "Default":
			device.add_item(device_name)
			if device_name == Profile.mic_device:
				device.select(device.item_count - 1)
	device.item_selected.connect(func(index: int) -> void:
		Profile.mic_device = "" if index == 0 else device.get_item_text(index)
		AudioServer.input_device = "Default" if index == 0 else device.get_item_text(index))
	voice_grid.add_child(device)
	voice_grid.add_child(_small("Open mic starts at"))
	var threshold := _slider(0.02, 0.5, Profile.mic_threshold)
	threshold.step = 0.01
	threshold.value_changed.connect(func(value: float) -> void: Profile.mic_threshold = value)
	voice_grid.add_child(threshold)
	voice_grid.add_child(_small("Your mic level"))
	_mic_meter = ProgressBar.new()
	_mic_meter.max_value = 1.0
	_mic_meter.show_percentage = false
	_mic_meter.custom_minimum_size = Vector2(0, 14)
	voice_grid.add_child(_mic_meter)
	voice_grid.add_child(_small("Others' voices"))
	var others := _slider(0.0, 1.5, Profile.voice_volume)
	others.value_changed.connect(func(value: float) -> void: Profile.voice_volume = value)
	voice_grid.add_child(others)
	voice_grid.add_child(_small("Monsters"))
	var mimic := CheckBox.new()
	mimic.text = "May copy my voice"
	mimic.button_pressed = Profile.voice_mimic
	mimic.toggled.connect(func(on: bool) -> void:
		Profile.voice_mimic = on
		if voice:
			voice.send_mimic_consent())
	voice_grid.add_child(mimic)
	voice_grid.add_child(_small("Captions"))
	var captions := CheckBox.new()
	captions.text = "Show sound captions"
	captions.button_pressed = Profile.captions
	captions.toggled.connect(func(on: bool) -> void: Profile.captions = on)
	voice_grid.add_child(captions)

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
	var effects := CheckBox.new()
	effects.text = "Ambient occlusion and haze"
	effects.button_pressed = Profile.effects
	effects.toggled.connect(func(on: bool) -> void:
		Profile.effects = on
		Profile.apply_graphics())
	graphics.add_child(effects)
	var bounce := CheckBox.new()
	bounce.text = "Bounced light"
	bounce.button_pressed = Profile.bounce_light
	bounce.toggled.connect(func(on: bool) -> void:
		Profile.bounce_light = on
		Profile.apply_graphics())
	graphics.add_child(bounce)
	var grass := CheckBox.new()
	grass.text = "Long grass"
	grass.button_pressed = Profile.long_grass
	grass.toggled.connect(func(on: bool) -> void:
		Profile.long_grass = on
		Profile.apply_graphics())
	graphics.add_child(grass)
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

	_invite = _button("Invite Steam friends", func() -> void: SteamService.invite_friends())
	column.add_child(_invite)
	column.add_child(_button("Change keys...", func() -> void:
		_scroll.visible = false
		_keys.visible = true))
	# The host's list of the other players, each with a button to remove them.
	_team = VBoxContainer.new()
	column.add_child(_team)
	_resume = _button("Resume", close)
	column.add_child(_resume)
	_leave = _button("Leave to the main menu", func() -> void: leave_requested.emit())
	column.add_child(_leave)
	column.add_child(_button("Quit the game", func() -> void: get_tree().quit()))


var _team: VBoxContainer


## The host's team list: `others` is [peer id, name] for everyone but the host.
func set_team(others: Array) -> void:
	for child in _team.get_children():
		child.queue_free()
	for other: Array in others:
		var peer: int = other[0]
		_team.add_child(_button("Remove %s from the session" % other[1], func() -> void:
			kick_requested.emit(peer)
			close()))


## `solo` pauses the game; `hosting` means leaving ends the session for everyone.
## `abandons`: leaving now walks out on a saved run mid-shift, which counts as a wipe.
func open(solo: bool, hosting: bool, abandons := false) -> void:
	_title.text = "PAUSED" if solo else "MENU"
	_note.text = "Take your time." if solo else "The night doesn't stop while you're in here."
	if abandons:
		_note.text += "\nLeaving mid-shift counts as the whole team being caught."
	get_tree().paused = solo
	_fullscreen.set_pressed_no_signal(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
	_leave.text = "End the session (everyone leaves)" if hosting else "Leave to the main menu"
	_scroll.custom_minimum_size.y = minf(get_viewport().get_visible_rect().size.y * 0.85, 900.0)
	_show_main()
	_invite.visible = SteamService.available and SteamService.lobby_id != 0
	visible = true
	if not Input.get_connected_joypads().is_empty():
		_resume.grab_focus.call_deferred()
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


func _process(_delta: float) -> void:
	if is_open and voice and _mic_meter:
		_mic_meter.value = voice.level


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if _listening != "":
		var key := event as InputEventKey
		if key == null or not key.pressed or key.echo:
			return
		get_viewport().set_input_as_handled()
		if key.physical_keycode != KEY_ESCAPE:
			var problem: String = Controls.rebind(_listening, key.physical_keycode)
			_key_help.text = problem if problem != "" else KEYS_HELP
		_listening = ""
		_refresh_keys()
		return
	if event.is_action_pressed("pause") or (event is InputEventJoypadButton and event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		if _keys.visible:
			_show_main()
		else:
			close()


## The "Change keys" page: one button per action; click it, then press the new key.
func _build_keys(panel: PanelContainer) -> void:
	_keys = VBoxContainer.new()
	_keys.add_theme_constant_override("separation", 8)
	_keys.visible = false
	panel.add_child(_keys)
	var title := Label.new()
	title.text = "KEYS"
	title.add_theme_font_size_override("font_size", 30)
	_keys.add_child(title)
	var help := _small(KEYS_HELP)
	_key_help = help
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(400, 0)
	_keys.add_child(help)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	_keys.add_child(grid)
	for entry: Array in Controls.REBINDABLE:
		var action: String = entry[0]
		grid.add_child(_label(entry[1]))
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 34)
		button.pressed.connect(func() -> void:
			_refresh_keys()
			_listening = action
			button.text = "Press a key...")
		grid.add_child(button)
		_key_buttons[action] = button
	_keys.add_child(_button("Reset to defaults", func() -> void:
		Controls.reset_all()
		_refresh_keys()))
	_keys.add_child(_button("Back", _show_main))
	_refresh_keys()


func _refresh_keys() -> void:
	for action: String in _key_buttons:
		(_key_buttons[action] as Button).text = Controls.key_name(action)


func _show_main() -> void:
	_listening = ""
	_refresh_keys()
	_keys.visible = false
	_scroll.visible = true


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
