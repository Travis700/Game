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
var _ghost_tint: ColorRect
var _ghost_note: Label
var _flash: ColorRect
var _feed_view: Control
var _feed_picture: TextureRect
var _feed_title: Label
var _message_time := 0.0
var _hint_time := HINT_SECONDS


func _ready() -> void:
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
	_message.offset_bottom = -70
	_message.modulate.a = 0.0

	_hint = _make_label(18, HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_hint.offset_left = 20
	_hint.offset_top = 16
	_hint.text = "WASD  move\nShift  run\nF  flashlight\nE  use\nTab  clipboard\nEsc  free the mouse"

	_status = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	_status.offset_right = -20
	_status.offset_top = 16
	_status.modulate.a = 0.75

	_controls = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	_controls.offset_bottom = -24
	_controls.modulate.a = 0.85

	_clock = _make_label(22, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_clock.offset_top = 14

	_build_feed_view()

	_ghost_tint = ColorRect.new()
	_ghost_tint.color = Color(0.35, 0.45, 0.7, 0.18)
	_ghost_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ghost_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost_tint.visible = false
	add_child(_ghost_tint)
	_ghost_note = _make_label(20, HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_TOP)
	_ghost_note.offset_top = 48
	_ghost_note.text = "You're a ghost. A teammate can try to bring you back at a revive totem."
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
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time, 0.0, 1.0)
	if _hint_time > 0.0:
		_hint_time -= delta
		_hint.modulate.a = clampf(_hint_time, 0.0, 1.0)


func set_prompt(text: String) -> void:
	_prompt.text = text


## The night clock at the top of the screen, e.g. "NIGHT 1 · 2:05 AM". Empty hides it.
func set_clock(text: String) -> void:
	_clock.text = text


## The faint blue look and reminder while you're a ghost.
func set_ghost(on: bool) -> void:
	_ghost_tint.visible = on
	_ghost_note.visible = on


## A quick full-screen flash of colour that fades out, e.g. red when you're caught.
func flash(color: Color, seconds := 1.2) -> void:
	_flash.color = color
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


## Session info in the top-right corner, e.g. "Hosting · 2 guards".
func set_status(text: String) -> void:
	_status.text = text


func show_message(text: String) -> void:
	_message.text = text
	_message_time = MESSAGE_SECONDS
	_message.modulate.a = 1.0


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
