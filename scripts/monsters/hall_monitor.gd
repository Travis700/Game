class_name HallMonitor
extends Monster
## The Hall Monitor: a tall, thin figure with a sash and a clipboard of its own.
## It walks the main hallway end to end. It leaves walkers alone, but if it sees a guard
## running it blows its whistle and chases them until it loses sight of them.

const PATROL_SPEED := 1.5
const CHASE_SPEED := 4.3
const SIGHT_RANGE := 22.0
## Seconds without seeing its target before it gives up the chase.
const GIVE_UP_AFTER := 4.0
const HALL_ENDS: Array[Vector3] = [Vector3(-36, 0, 7), Vector3(36, 0, 7)]

var _patrol_end := 1
var _target: Guard
var _unseen_for := 0.0
var _whistle: AudioStream


func _init() -> void:
	display_name = "the Hall Monitor"
	state = "patrol"


func think(delta: float) -> void:
	if _target:
		_chase(delta)
	else:
		_patrol()


func _patrol() -> void:
	var end := HALL_ENDS[_patrol_end]
	if global_position.distance_to(end) < 1.5:
		_patrol_end = 1 - _patrol_end
	move_to(end, PATROL_SPEED)
	for guard in director.living_guards():
		if guard.is_running and distance_to_guard(guard) < SIGHT_RANGE and director.can_see(eye_position(), guard):
			_target = guard
			_unseen_for = 0.0
			state = "chase"
			return


func _chase(delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_dead:
		_stop_chase()
		return
	if director.can_see(eye_position(), _target):
		_unseen_for = 0.0
	else:
		_unseen_for += delta
	if _unseen_for > GIVE_UP_AFTER or not move_to(_target.global_position, CHASE_SPEED):
		_stop_chase()
		return
	catch_nearby()


func _stop_chase() -> void:
	_target = null
	state = "patrol"


func _on_state_changed(new_state: String) -> void:
	if new_state == "chase":
		if _whistle == null:
			_whistle = Sfx.notes([2400.0, 0.0, 2400.0, 2900.0], 0.12, 0.3, "square")
		Sfx.play_at(self, _whistle, 2.0, 45.0)


func _build_body() -> void:
	part(capsule(0.22, 2.0), Color(0.16, 0.16, 0.18), Vector3(0, 1.0, 0))
	part(sphere(0.14), Color(0.72, 0.69, 0.62), Vector3(0, 2.14, 0))
	part(box(Vector3(0.24, 0.05, 0.02)), Color(0.02, 0.02, 0.02), Vector3(0, 2.16, -0.13))
	var sash := part(box(Vector3(0.08, 0.95, 0.47)), Color(0.95, 0.5, 0.1), Vector3(0, 1.4, 0), 0.6)
	sash.rotation_degrees.z = 35.0
	part(box(Vector3(0.26, 0.34, 0.02)), Color(0.45, 0.3, 0.15), Vector3(0.24, 1.2, -0.2))
