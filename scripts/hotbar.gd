class_name Hotbar
extends HBoxContainer
## The row of slots along the bottom of the screen: the flashlight in the first (the heavy-duty
## one once it's fitted, lit while it's on), then what the guard has bought, in the order they
## picked it up. 1-5 or the mouse wheel picks a slot, and G uses what's in it (with the
## flashlight's slot picked, G uses the first thing carried, so a controller needs no picking).

const SLOT_SIZE := Vector2(104, 62)
## Short names that fit in a slot.
const SHORT := {
	"camera_kit": "Spectral\ncamera kit", "lucky_charm": "Rabbit's\nfoot", "door_kit": "Door kit",
	"motion_sensor": "Motion\nsensor", "glue_trap": "Glue trap", "portable_camera": "Portable\ncamera",
	"radio": "Walkie-\ntalkie", "energy_drink": "Energy\ndrink", "flashlight": "Heavy-duty\nflashlight",
	"emf": "EMF\nreader", "coffee": "Coffee", "decoy_radio": "Decoy\nradio", "donuts": "Donuts",
	"air_horn": "Air horn", "spirit_box": "Spirit box",
}

## The guard whose hands these are. Set by Main.
var guard: Guard
## The slot picked: 0 is the flashlight, 1 onwards what's carried.
var selected := 0

var _items: Array[String] = []
var _panels: Array[PanelContainer] = []
var _labels: Array[Label] = []
var _plain: StyleBoxFlat
var _picked: StyleBoxFlat


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plain = StyleBoxFlat.new()
	_plain.bg_color = Color(0.03, 0.04, 0.06, 0.55)
	_plain.border_color = Color(1, 1, 1, 0.18)
	_plain.set_border_width_all(1)
	_plain.set_corner_radius_all(6)
	_picked = _plain.duplicate()
	_picked.bg_color = Color(0.1, 0.11, 0.14, 0.75)
	_picked.border_color = Color(0.95, 0.85, 0.55, 0.9)
	_picked.set_border_width_all(2)
	for i in Shop.BAG_SIZE + 1:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = SLOT_SIZE
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		panel.add_child(label)
		var number := Label.new()
		number.text = str(i + 1)
		number.add_theme_font_size_override("font_size", 12)
		number.modulate.a = 0.55
		number.position = Vector2(6, 2)
		panel.add_child(number)
		add_child(panel)
		_panels.append(panel)
		_labels.append(label)
	# Sized to the slots, bottom centre, a little up from the edge.
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	refresh()


## What the guard is carrying changed (from the shop).
func set_items(items: Array[String]) -> void:
	_items = items.duplicate()
	selected = mini(selected, _items.size())
	refresh()


## Which carried thing G uses: the picked one, or the first if the flashlight's slot is picked.
func item_slot() -> int:
	return maxi(selected - 1, 0)


func refresh() -> void:
	for i in _panels.size():
		var label := _labels[i]
		if i == 0:
			var bright := guard != null and guard.bright_flashlight
			var on := guard != null and guard.flashlight.visible
			label.text = ("Heavy-duty torch" if bright else "Flashlight") + ("\nON" if on else "\noff")
			label.modulate = Color(1.0, 0.95, 0.75) if on else Color(1, 1, 1, 0.7)
		elif i - 1 < _items.size() and _items[i - 1] == "spirit_box":
			# Shows whether it's switched on (G).
			var on := guard != null and guard.spirit_box_on
			label.text = "Spirit box\n" + ("ON" if on else "off")
			label.modulate = Color(0.7, 0.9, 1.0) if on else Color.WHITE
		elif i - 1 < _items.size():
			label.text = SHORT.get(_items[i - 1], Shop.item_name(_items[i - 1]))
			label.modulate = Color.WHITE
		else:
			label.text = ""
		_panels[i].add_theme_stylebox_override("panel", _picked if i == selected else _plain)


func _unhandled_input(event: InputEvent) -> void:
	if guard == null or not is_instance_valid(guard) or guard.input_blocked or guard.is_dead or guard.seated_desk >= 0:
		return
	var picked := selected
	for i in _panels.size():
		if event.is_action_pressed("slot_%d" % (i + 1)):
			picked = i
	if event.is_action_pressed("slot_next"):
		picked = wrapi(selected + 1, 0, _items.size() + 1)
	elif event.is_action_pressed("slot_prev"):
		picked = wrapi(selected - 1, 0, _items.size() + 1)
	# Only the flashlight's slot and the ones with something in them can be picked.
	if picked != selected and picked <= _items.size():
		selected = picked
		refresh()


## The flashlight's (and spirit box's) state as last drawn ("on?bright?box on?").
var _shown := ""


func _process(_delta: float) -> void:
	visible = guard != null and is_instance_valid(guard) and not guard.is_dead and guard.seated_desk < 0
	if not visible:
		return
	# The flashlight's slot shows whether it's on (switched with F or the left mouse button).
	var state := "%s%s%s" % [guard.flashlight.visible, guard.bright_flashlight, guard.spirit_box_on]
	if state != _shown:
		_shown = state
		refresh()
