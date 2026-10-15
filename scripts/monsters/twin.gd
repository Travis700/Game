class_name Twin
extends Monster
## The Twins: two girls in matching dresses, one in Room 101 and one in Room 102, holding hands
## with nobody. They only move when neither of them is being watched, in person or on a monitor:
## watch either one and both stand still. Leave them both alone and they come for the nearest
## guard. One guard on the monitors keeps the other safe; alone, you'll need two screens.

const SPEED := 3.2

## The other twin.
var sibling: Twin

var _watched := false
var _look_again := 0.0


func _init() -> void:
	display_name = "the Twins"
	footstep_pitch = 1.5
	footstep_volume = -6.0
	state = "still"


func think(delta: float) -> void:
	_look_again -= delta
	if _look_again <= 0.0:
		_look_again = 0.1
		_watched = director.is_watched(self)
	var sibling_watched := sibling != null and is_instance_valid(sibling) and sibling._watched
	if _watched or sibling_watched:
		halt()
		state = "still"
		return
	state = "moving"
	var guard := director.nearest_living_guard(global_position)
	if guard == null:
		halt()
		return
	move_to(guard.global_position, SPEED)
	catch_nearby()


var _last_giggle := -100.0


func _on_state_changed(new_state: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if new_state == "moving" and now - _last_giggle > 4.0:
		_last_giggle = now
		# A giggle, from both of them, as they set off.
		SoundBank.play_at(self, "giggle", -6.0, 18.0, Sfx.notes([880.0, 988.0, 880.0, 1046.0], 0.07, 0.15, "triangle"))


func _build_body() -> void:
	var dress := Color(0.55, 0.62, 0.78)
	part(capsule(0.22, 1.25), dress, Vector3(0, 0.62, 0))
	part(box(Vector3(0.5, 0.45, 0.36)), dress.darkened(0.15), Vector3(0, 0.3, 0))
	part(sphere(0.14), Color(0.86, 0.8, 0.74), Vector3(0, 1.38, 0))
	part(box(Vector3(0.34, 0.36, 0.3)), Color(0.15, 0.1, 0.07), Vector3(0, 1.42, 0.06))
	for side: float in [-1.0, 1.0]:
		part(sphere(0.025), Color(0.02, 0.02, 0.02), Vector3(side * 0.05, 1.4, -0.13))
