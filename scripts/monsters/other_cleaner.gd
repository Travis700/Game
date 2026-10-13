class_name OtherCleaner
extends NightCleaner
## The Other Cleaner: looks almost exactly like the night cleaner and walks the same rounds.
## It has no cart, and its head sits at a slightly wrong angle. Get close and it drops the act.
## Log it as a Monster where you see it and it leaves.

const NOTICE_DISTANCE := 6.0
const CHASE_SPEED := 5.0
const CHASE_TIME := 10.0

var _chase_left := 0.0
var _target: Guard
var _eyes: Array[MeshInstance3D] = []


func _init() -> void:
	display_name = "the other cleaner"
	harmless = false
	leaves_when_logged = true
	state = "walk"


func think(delta: float) -> void:
	if _chase_left > 0.0:
		_chase_left -= delta
		if not is_instance_valid(_target) or _target.is_dead or not move_to(_target.global_position, CHASE_SPEED):
			_chase_left = 0.0
		catch_nearby()
		if _chase_left <= 0.0:
			state = "walk"
		return
	for guard in director.living_guards():
		if distance_to_guard(guard) < NOTICE_DISTANCE and director.can_see(eye_position(), guard):
			_target = guard
			_chase_left = CHASE_TIME
			state = "reveal"
			return
	_wander(delta)


func _build_body() -> void:
	_build_person(false)
	# The head and cap lean a little too far.
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).position.y > 1.7:
			(child as MeshInstance3D).rotation_degrees.z = 14.0
	for side: float in [-1.0, 1.0]:
		var eye := part(sphere(0.025), Color(1, 0.15, 0.1), Vector3(side * 0.06, 1.8, -0.14), 4.0)
		eye.visible = false
		_eyes.append(eye)


func _on_state_changed(new_state: String) -> void:
	for eye in _eyes:
		eye.visible = new_state == "reveal"
