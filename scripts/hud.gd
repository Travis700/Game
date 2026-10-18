extends CanvasLayer
## On-screen overlay: crosshair, "[E] ..." prompts, short messages, a controls reminder,
## and the full-screen camera view.

const CCTV_CANVAS_SHADER := preload("res://shaders/cctv_canvas.gdshader")

const MESSAGE_SECONDS := 4.0
const HINT_SECONDS := 12.0

var _prompt: Label
var _crosshair: Control
var _message: Label
var _hint: Label
var _status: Label
var _controls: Label
var _clock: Label
var _objective: Label
var _voice_label: Label
var _voice_bar: ProgressBar
var _nerve_box: Control
var _nerve_bar: ProgressBar
var _emf: Label
var _stamina: ProgressBar
var _inventory: Label
## The flashlight and what the guard is carrying, along the bottom.
var hotbar: Hotbar
var _ghost_tint: ColorRect
var _ghost_note: Label
var _flash: ColorRect
var _feed_view: Control
var _feed_picture: TextureRect
var _feed_title: Label
var _message_time := 0.0
## Messages waiting their turn: [text, seconds, sticky, queued at (msec)].
var _queue: Array = []
## Whether the message showing is a teaching message (holds the screen while it's read).
var _message_sticky := false
const STICKY_SECONDS := 8.0
## Ordinary messages that waited longer than this are out of date ("A phone is ringing") and dropped.
const STALE_MSEC := 8000
var _hint_time := HINT_SECONDS
## Playing alone (no voice chat lines in the key list).
var solo := false


func _ready() -> void:
	_build_fear()
	hotbar = Hotbar.new()
	hotbar.name = "Hotbar"
	add_child(hotbar)
	Controls.device_changed.connect(func() -> void:
		refresh_key_hint()
		_hint_time = HINT_SECONDS
		_hint.modulate.a = 1.0)
	var crosshair_holder := CenterContainer.new()
	crosshair_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair_holder)
	_crosshair = crosshair_holder
	var crosshair := ColorRect.new()
	crosshair.color = Color(1, 1, 1, 0.7)
	crosshair.custom_minimum_size = Vector2(4, 4)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_holder.add_child(crosshair)

	_prompt = _make_label(24, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_CENTER)
	_prompt.offset_top = 110

	_message = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_message.offset_bottom = -104
	_message.modulate.a = 0.0

	_hint = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_hint.offset_left = 20
	_hint.offset_top = 16
	refresh_key_hint()

	_status = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	_status.offset_right = -20
	_status.offset_top = 16
	_status.modulate.a = 0.75

	_controls = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_controls.offset_bottom = -24
	_controls.modulate.a = 0.85

	_clock = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_clock.offset_top = 14

	_objective = _make_label(18, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_objective.offset_top = 46
	_objective.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_objective.modulate.a = 0.85

	_inventory = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_inventory.offset_right = -20
	_inventory.offset_bottom = -20
	_inventory.modulate.a = 0.8

	# Bottom left: shows when your microphone is being sent, and how loud you are.
	var voice_box := HBoxContainer.new()
	voice_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	voice_box.offset_left = 20
	voice_box.offset_top = -48
	voice_box.offset_bottom = -20
	voice_box.add_theme_constant_override("separation", 10)
	voice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(voice_box)
	_voice_label = Label.new()
	_voice_label.text = "TALKING"
	_voice_label.add_theme_font_size_override("font_size", 18)
	_voice_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.6))
	voice_box.add_child(_voice_label)
	_voice_bar = ProgressBar.new()
	_voice_bar.custom_minimum_size = Vector2(120, 10)
	_voice_bar.show_percentage = false
	_voice_bar.max_value = 1.0
	_voice_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	voice_box.add_child(_voice_bar)
	voice_box.visible = false
	_voice_label.set_meta("box", voice_box)

	# Bottom left, above the microphone: your nerve, while on shift.
	var nerve_box := HBoxContainer.new()
	nerve_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	nerve_box.offset_left = 20
	nerve_box.offset_top = -80
	nerve_box.offset_bottom = -54
	nerve_box.add_theme_constant_override("separation", 10)
	nerve_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nerve_box)
	var nerve_label := Label.new()
	nerve_label.text = "NERVE"
	nerve_label.add_theme_font_size_override("font_size", 15)
	nerve_label.modulate.a = 0.75
	nerve_box.add_child(nerve_label)
	_nerve_bar = ProgressBar.new()
	_nerve_bar.custom_minimum_size = Vector2(140, 10)
	_nerve_bar.show_percentage = false
	_nerve_bar.max_value = 100.0
	_nerve_bar.value = 100.0
	_nerve_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nerve_box.add_child(_nerve_bar)
	nerve_box.visible = false
	_nerve_box = nerve_box

	# Bottom centre: stamina, while it isn't full.
	_stamina = ProgressBar.new()
	_stamina.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_stamina.offset_left = -90
	_stamina.offset_right = 90
	# Just above the hotbar.
	_stamina.offset_top = -94
	_stamina.offset_bottom = -86
	_stamina.max_value = 1.0
	_stamina.show_percentage = false
	_stamina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stamina.visible = false
	add_child(_stamina)

	# Bottom left, above nerve: the EMF reader's lights, for guards who carry one.
	_emf = Label.new()
	_emf.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_emf.offset_left = 20
	_emf.offset_top = -112
	_emf.offset_bottom = -84
	_emf.add_theme_font_size_override("font_size", 18)
	_emf.visible = false
	add_child(_emf)

	_build_feed_view()

	_ghost_tint = ColorRect.new()
	_ghost_tint.color = Color(0.35, 0.45, 0.7, 0.18)
	_ghost_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_tint.visible = false
	add_child(_ghost_tint)
	_ghost_note = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_ghost_note.offset_top = 76
	_ghost_note.text = Controls.fill(GHOST_NOTE)
	_ghost_note.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	_ghost_note.visible = false

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(0, 0, 0, 0)
	add_child(_flash)


func _process(delta: float) -> void:
	if not visible:
		return
	_update_fear(delta)
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	while _message_time <= 0.25 and not _queue.is_empty():
		var next: Array = _queue.pop_front()
		if next[2]:
			_display(next[0], next[1], true)
		elif Time.get_ticks_msec() - int(next[3]) < STALE_MSEC:
			# Ordinary news that waited is shown briefly; news too old to matter is skipped.
			_display(next[0], minf(next[1], 3.0), false)
	if _hint_time > 0.0:
		_hint_time -= delta
		_hint.modulate.a = clampf(_hint_time, 0.0, 1.0)


func set_prompt(text: String) -> void:
	_prompt.text = text


## The night clock at the top of the screen, e.g. "NIGHT 1 · 2:05 AM". Empty hides it.
func set_clock(text: String) -> void:
	_clock.text = text


## Your points, and anything picked up off the floor, in the bottom-right corner (the hotbar
## shows the rest).
func set_inventory(points: int, item_name: String) -> void:
	_inventory.text = "%d points%s" % [points, ("   ·   " + item_name) if item_name != "" else ""]


## Someone's flashlight in your eyes (0 none, 1 blinded), and where on screen it is.
var _glare_wash: ColorRect
var _glare_bloom: TextureRect


func set_glare(amount: float, at: Vector2) -> void:
	if _glare_wash == null:
		_glare_wash = ColorRect.new()
		_glare_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_glare_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glare_wash.color = Color(1.0, 0.98, 0.92, 0.0)
		add_child(_glare_wash)
		var glow := Gradient.new()
		glow.set_color(0, Color(1.0, 1.0, 0.96, 1.0))
		glow.set_color(1, Color(1.0, 0.96, 0.85, 0.0))
		glow.add_point(0.2, Color(1.0, 0.98, 0.92, 0.85))
		var texture := GradientTexture2D.new()
		texture.gradient = glow
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 256
		texture.height = 256
		_glare_bloom = TextureRect.new()
		_glare_bloom.texture = texture
		_glare_bloom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glare_bloom.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		add_child(_glare_bloom)
	_glare_wash.visible = amount > 0.01
	_glare_bloom.visible = amount > 0.01
	if amount <= 0.01:
		return
	amount *= Profile.flash_strength()
	_glare_wash.color.a = amount * 0.6
	var size := Vector2.ONE * lerpf(250.0, 1400.0, amount)
	_glare_bloom.size = size
	_glare_bloom.position = at - size * 0.5
	_glare_bloom.modulate.a = minf(1.0, amount * 1.5)


## The faint blue look and reminder while you're a ghost.
const GHOST_NOTE := "You're a ghost. A teammate can try to bring you back at a revive totem.\n{use}: leave a cold spot the living can see.   {item}: watch through a teammate's eyes.   {clip}: watch the cameras ({left} / {right} to flick)."


func set_ghost(on: bool) -> void:
	_is_ghost = on
	_ghost_note.text = Controls.fill(GHOST_NOTE)
	if on:
		_fear_target = 0.0
	_ghost_tint.visible = on
	_ghost_note.visible = on


## A quick full-screen flash of colour that fades out, e.g. red when you're caught.
## A sketch from the field guide, pinned at the top right for a while (a new page in the guide).
func show_sketch(texture: Texture2D, seconds := 10.0) -> void:
	var sketch := TextureRect.new()
	sketch.texture = texture
	sketch.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sketch.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	sketch.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sketch.offset_left = -250
	sketch.offset_right = -20
	sketch.offset_top = 60
	sketch.offset_bottom = 290
	sketch.rotation_degrees = 2.0
	sketch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sketch)
	var fade := sketch.create_tween()
	sketch.modulate.a = 0.0
	fade.tween_property(sketch, "modulate:a", 1.0, 0.4)
	fade.tween_interval(seconds)
	fade.tween_property(sketch, "modulate:a", 0.0, 0.8)
	fade.tween_callback(sketch.queue_free)


func flash(color: Color, seconds := 1.2) -> void:
	_flash.color = Color(color, color.a * Profile.flash_strength())
	create_tween().tween_property(_flash, "color:a", 0.0, seconds)


## Controls for what you're doing right now, e.g. while seated at the monitors.
func set_controls(text: String) -> void:
	_controls.text = text


## Fills the screen with one camera feed.
func show_feed(feed: Texture2D, title: String) -> void:
	_feed_picture.texture = feed
	_feed_title.text = title
	_feed_view.visible = true
	_prompt.visible = false
	_crosshair.visible = false


func hide_feed() -> void:
	_feed_view.visible = false
	_feed_picture.texture = null
	_prompt.visible = true
	_crosshair.visible = true


func _build_feed_view() -> void:
	_feed_view = Control.new()
	_feed_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feed_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_view.visible = false
	add_child(_feed_view)
	# Draw it underneath the prompt, message and controls labels.
	move_child(_feed_view, 0)

	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_view.add_child(backdrop)

	var material := ShaderMaterial.new()
	material.shader = CCTV_CANVAS_SHADER
	_feed_picture = TextureRect.new()
	_feed_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feed_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feed_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_feed_picture.material = material
	_feed_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_view.add_child(_feed_picture)

	_feed_title = Label.new()
	_feed_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_feed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# At the bottom, above the controls, clear of the labels inside the feed.
	_feed_title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_feed_title.offset_bottom = -60
	_feed_title.add_theme_font_size_override("font_size", 22)
	_feed_title.add_theme_constant_override("outline_size", 6)
	_feed_title.add_theme_color_override("font_outline_color", Color.BLACK)
	_feed_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed_view.add_child(_feed_title)


## Shows the key list again for a while (on entering the school).
func show_hint() -> void:
	refresh_key_hint()
	_hint_time = HINT_SECONDS
	_hint.modulate.a = 1.0


## The key list in the top left, using the player's own keys.
func refresh_key_hint() -> void:
	var move := "%s%s%s%s" % [Controls.key_name("move_forward"), Controls.key_name("move_left"),
			Controls.key_name("move_back"), Controls.key_name("move_right")]
	var lines: Array[String] = [
		"%s  move" % ("Left stick" if Controls.using_pad else move if move.length() == 4 else "Move keys"),
		"%s  run" % Controls.key_name("sprint"), "%s  crouch" % Controls.key_name("crouch"),
		"%s  flashlight" % Controls.key_name("flashlight"),
		"%s  use" % Controls.key_name("interact"), "%s  clipboard" % Controls.key_name("clipboard"),
		"%s  use item" % Controls.key_name("use_item"), "%s  put down / hand over" % Controls.key_name("drop_item"),
		"%s  mark a spot" % Controls.key_name("ping"),
	]
	# Talking is for teams.
	if not solo:
		lines.append("%s  talk (voice chat)" % Controls.key_name("push_to_talk"))
		lines.append("%s  walkie-talkie" % Controls.key_name("radio_talk"))
	lines.append("%s  menu" % Controls.key_name("pause"))
	_hint.text = "\n".join(lines)


## What you should be doing right now, under the clock, e.g. "Clock in at the guard room".
func set_objective(text: String) -> void:
	_objective.text = text


## The microphone indicator: shown while you're being heard, with how loud you are
## (monsters hear loud voices from further away).
func set_voice(transmitting: bool, level: float, on_radio := false) -> void:
	var box: Control = _voice_label.get_meta("box")
	box.visible = transmitting
	_voice_bar.value = level
	_voice_label.text = ("ON RADIO" if on_radio else "TALKING") + (" (LOUD)" if level > 0.6 else "")


## Stamina 0-1; hidden when full. Red while winded.
func set_stamina(value: float, winded: bool) -> void:
	_stamina.visible = value < 0.999
	_stamina.value = value
	_stamina.modulate = Color(1.0, 0.35, 0.3) if winded else Color(1, 1, 1, 0.8)


## The EMF reader: level 0-5, or -1 to hide it.
func set_emf(level: int) -> void:
	_emf.visible = level >= 0
	if level < 0:
		return
	_emf.text = "EMF  " + "■".repeat(level) + "□".repeat(5 - level)
	var colours := [Color(0.6, 0.6, 0.6), Color(0.4, 1.0, 0.4), Color(0.6, 1.0, 0.3), Color(1.0, 0.9, 0.3), Color(1.0, 0.55, 0.2), Color(1.0, 0.2, 0.2)]
	_emf.add_theme_color_override("font_color", colours[level])


## Your nerve (0-100), shown below 100 while on shift. Turns red as it runs low.
func set_nerve(value: float) -> void:
	_nerve_bar.value = value
	_fear_target = 0.0 if _is_ghost else clampf((FEAR_FROM - value) / FEAR_FROM, 0.0, 1.0)
	_nerve_box.visible = value < 99.5
	_nerve_bar.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.3, 0.25), clampf(1.0 - value / 60.0, 0.0, 1.0))


## Nerve below this starts to show on screen.
const FEAR_FROM := 70.0
var _fear: ColorRect
var _fear_target := 0.0
var _is_ghost := false
var _fear_now := 0.0


## The full-screen effect: the camera look, and low nerve (under everything else on the HUD).
func _build_fear() -> void:
	_fear = ColorRect.new()
	_fear.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/fear.gdshader")
	_fear.material = material
	add_child(_fear)
	move_child(_fear, 0)


func _update_fear(delta: float) -> void:
	_fear_now = move_toward(_fear_now, _fear_target, delta * 0.5)
	(_fear.material as ShaderMaterial).set_shader_parameter("fear", _fear_now)
	(_fear.material as ShaderMaterial).set_shader_parameter("film", 1.0 if Profile.film_grain else 0.0)
	_fear.visible = _fear_now > 0.01 or Profile.film_grain


## Session info in the top-right corner, e.g. "Hosting · 2 guards".
func set_status(text: String) -> void:
	_status.text = text


## Shows a message under the crosshair. Most messages simply replace the one before, as quick
## feedback should. But a teaching message (one given 8 seconds or more: a monster's rule, the
## shift notes, a tip) holds the screen while it's being read: anything ordinary that arrives
## meanwhile waits behind it (and similar waiting messages collapse into the latest). Urgent
## ones (being caught, a log's result, a lockdown) always go straight up, and put a teaching
## message they cut off back in line. `seconds` < 0 means "as long as it takes to read".
func show_message(text: String, seconds := -1.0, urgent := false) -> void:
	text = Controls.fill(text)
	var sticky := seconds >= STICKY_SECONDS
	if seconds < 0.0:
		seconds = clampf(1.5 + text.length() / 15.0, MESSAGE_SECONDS, 10.0)
	urgent = urgent or _is_urgent(text)
	if text == _message.text and _message_time > 0.0:
		_message_time = maxf(_message_time, seconds)
		return
	var holding := _message_sticky and _message_time > 1.0
	if not urgent and holding:
		if sticky:
			_queue = _queue.filter(func(queued: Array) -> bool: return queued[0] != text)
		else:
			# One waiting ordinary message per kind ("Watching...", "...flagged"): the latest wins.
			# Teaching messages never collapse: each is a different rule to read.
			var prefix := text.substr(0, 12)
			_queue = _queue.filter(func(queued: Array) -> bool:
				return queued[2] or (queued[0] != text and (queued[0] as String).substr(0, 12) != prefix))
		_queue.append([text, seconds, sticky, Time.get_ticks_msec()])
		if _queue.size() > 6:
			# Drop the oldest ordinary one, never a teaching message.
			for i in _queue.size():
				if not _queue[i][2]:
					_queue.remove_at(i)
					break
		return
	if not sticky:
		# Nothing's being read: fresh news replaces any older ordinary news still waiting.
		_queue = _queue.filter(func(queued: Array) -> bool: return queued[2])
	if urgent and _message_sticky and _message_time > 2.0:
		_queue.push_front([_message.text, _message_time, true, Time.get_ticks_msec()])
	_display(text, seconds, sticky)


## Clears whatever's showing or waiting (the night ended, or you were caught).
func clear_messages() -> void:
	_queue.clear()
	_message_time = 0.0
	_message_sticky = false
	_message.modulate.a = 0.0


func _display(text: String, seconds: float, sticky := false) -> void:
	_message.text = text
	_message_time = seconds
	_message_sticky = sticky
	_message.modulate.a = 1.0


## News that can't wait behind a lesson: results, alarms, and anything with a clock on it
## (the Principal's summons, the phone, the power, the bell).
const URGENT_STARTS: Array[String] = ["✓", "✗", "LOCKDOWN", "You were caught", "Everything goes black",
	"The intercom crackles", "A phone is ringing", "The phone stops ringing", "A whisper on the line",
	"The power's gone out", "The school bell is ringing"]


static func _is_urgent(text: String) -> bool:
	for start in URGENT_STARTS:
		if text.begins_with(start):
			return true
	return false


func _make_label(size: int, h_align: HorizontalAlignment, v_align: VerticalAlignment) -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = h_align
	label.vertical_alignment = v_align
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(label)
	return label
