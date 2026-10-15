class_name Captions
extends CanvasLayer
## Sound captions: when a monster makes a telling noise within earshot, a line at the bottom
## right says what it was and which way, e.g. "[Whistle blast, behind you]". On by default;
## the Esc menu turns them off. Each computer captions what its own guard can hear.

## By "MonsterClass:state": what that state change sounds like.
const SOUNDS := {
	"Decoy:plays": "Music from a decoy radio",
	"HallMonitor:chase": "Whistle blast",
	"Coach:whistle": "Whistle: \"HUSTLE!\"",
	"Coach:chase": "Whistle blasts",
	"CrossingGuard:stop": "Whistle, and a sign going up",
	"CrossingGuard:charge": "Running footsteps",
	"CrossingGuard:clear": "Two short whistles: all clear",
	"Understudy:step": "Footsteps rushing up behind you",
	"Lockers:open": "A locker door creaking open",
	"SchoolGhost:breath": "A cold breath, close by",
	"Librarian:shush": "\"Shhh.\"",
	"Librarian:hunt": "Hissing",
	"LunchLady:hunt": "The humming stops",
	"Mascot:moving": "Heavy padded footsteps",
	"Nurse:follow": "A heart monitor beeping",
	"OtherCleaner:reveal": "A wet, wrong voice",
	"Photographer:charging": "A camera flash charging",
	"Photographer:rush": "A camera flash",
	"Photographer:missed": "A camera flash",
	"Principal:hunt": "Heavy, purposeful footsteps",
	"Shade:hunt": "Something dragging itself",
	"Specimen:crawl": "Skittering",
	"Specimen:flee": "Skittering, going away",
	"Student:reveal": "A scream",
	"Substitute:register": "\"Guard...?\"",
	"Substitute:detention": "A bell: detention",
	"Twin:moving": "Giggling",
	":hunt": "Running footsteps",
	"Speaker:lure": "An alarm from a camera speaker",
	"Clutter:landed": "Something clattering",
	"Radio:ghost": "A voice through the static on your radio",
	"Noise:radio": "A radio playing, very quietly",
	"Noise:static": "A TV hissing static",
	"Noise:whisper": "Someone whispering",
	"Noise:ball": "A ball bouncing, slowly",
}
const HEARING := 30.0
const SHOW_SECONDS := 4.0
const MAX_LINES := 4

## The local guard. Set by Main.
var local_guard: Guard

var _box: VBoxContainer
## Caption text -> when it was last shown, so a monster flickering between states doesn't spam.
var _shown_at: Dictionary = {}


func _ready() -> void:
	layer = 6
	add_to_group("captions")
	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_box.offset_left = -460
	_box.offset_right = -20
	_box.offset_top = -190
	_box.offset_bottom = -40
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)


## Called (through the "captions" group) by a monster whose state just changed.
func heard(kind: String, new_state: String, at: Vector3) -> void:
	# "step2" (the Understudy, after guard 2) reads as "step".
	new_state = new_state.rstrip("0123456789")
	var text: String = SOUNDS.get(kind + ":" + new_state, SOUNDS.get(":" + new_state, "") if new_state == "hunt" else "")
	if text == "" or not _enabled() or local_guard == null or not is_instance_valid(local_guard):
		return
	var to := at - local_guard.global_position
	if to.length() > HEARING:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_shown_at.get(text, -100.0)) < SHOW_SECONDS:
		return
	_shown_at[text] = now
	_add("[%s, %s]" % [text, _direction(to)])


func _direction(to: Vector3) -> String:
	if to.length() < 3.0:
		return "right next to you"
	var basis := local_guard.global_basis
	var forward := -basis.z.dot(to.normalized())
	var right := basis.x.dot(to.normalized())
	if forward > 0.6:
		return "ahead"
	if forward < -0.6:
		return "behind you"
	return "to your right" if right > 0.0 else "to your left"


func _add(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.75))
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	_box.add_child(label)
	while _box.get_child_count() > MAX_LINES:
		_box.get_child(0).free()
	var fade := label.create_tween()
	fade.tween_interval(SHOW_SECONDS)
	fade.tween_property(label, "modulate:a", 0.0, 0.6)
	fade.tween_callback(label.queue_free)


func _enabled() -> bool:
	var profile := get_node_or_null("/root/Profile")
	return profile == null or bool(profile.get("captions"))
