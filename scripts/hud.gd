extends CanvasLayer
## On-screen overlay: crosshair, "[E] ..." prompts, short messages and a controls reminder.

const MESSAGE_SECONDS := 4.0
const HINT_SECONDS := 12.0

var _prompt: Label
var _message: Label
var _hint: Label
var _status: Label
var _message_time := 0.0
var _hint_time := HINT_SECONDS


func _ready() -> void:
	var crosshair_holder := CenterContainer.new()
	crosshair_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair_holder)
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
	_hint.text = "WASD  move\nShift  run\nF  flashlight\nE  use\nEsc  free the mouse"

	_status = _make_label(18, HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_TOP)
	_status.offset_right = -20
	_status.offset_top = 16
	_status.modulate.a = 0.75


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
