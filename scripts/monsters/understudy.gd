class_name Understudy
extends Monster
## The Understudy: it has been rehearsing your part. It looks like one of the guards (same
## uniform, no face behind the visor) and follows one of them around at a distance, copying them.
##
## Keep moving. If the guard it's following stands still where it can see them for a few
## seconds, it steps in to take over the role. On the cameras it's an extra guard who shouldn't
## be there: log it as a Monster and it takes a bow and leaves.

const FOLLOW_DISTANCE := 7.0
const FOLLOW_SPEED := 3.6
const STEP_IN_SPEED := 5.4
const SIGHT_RANGE := 14.0
## Real seconds its guard can stand still before it steps in, and how long it keeps coming.
const STILL_SECONDS := 4.0
const STEP_IN_SECONDS := 4.0
const STILL_SPEED := 0.3

var _target: Guard
var _still_for := 0.0
var _warned := false
var _step_left := 0.0
var _uniform: StandardMaterial3D


func _init() -> void:
	display_name = "the Understudy"
	leaves_when_logged = true
	state = "wait"


func think(delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_dead or not director.may_enter(_target.global_position):
		_target = _pick_target()
		_still_for = 0.0
		_warned = false
		if _target == null:
			halt()
			state = "wait"
			return
	if state.begins_with("step"):
		_step_in(delta)
		return
	state = "follow%d" % _target.slot
	var distance := distance_to_guard(_target)
	if distance > FOLLOW_DISTANCE:
		move_to(_target.global_position, FOLLOW_SPEED)
	else:
		halt()
		face(_target.global_position - global_position)
	var watching := distance < SIGHT_RANGE and director.can_see(eye_position(), _target)
	if watching and director.guard_speed(_target) < STILL_SPEED:
		_still_for += delta
	else:
		_still_for = 0.0
		_warned = false
	if _still_for > STILL_SECONDS * 0.5 and not _warned:
		_warned = true
		director.tell(_target.name.to_int(), "Footsteps behind you stop when yours do.")
	if _still_for > STILL_SECONDS:
		_step_left = STEP_IN_SECONDS
		state = "step%d" % _target.slot


func _step_in(delta: float) -> void:
	_step_left -= delta
	if _step_left <= 0.0 or not move_to(_target.global_position, STEP_IN_SPEED):
		_still_for = 0.0
		state = "follow%d" % _target.slot
		return
	catch_nearby()


func _pick_target() -> Guard:
	var best: Guard = null
	var best_distance := INF
	for guard in director.living_guards():
		var distance := distance_to_guard(guard)
		if director.may_enter(guard.global_position) and distance < best_distance:
			best = guard
			best_distance = distance
	return best


## Wears the uniform of whichever guard it's copying.
func _on_state_changed(new_state: String) -> void:
	if _uniform == null:
		return
	var slot := new_state.right(1).to_int()
	if slot >= 1:
		_uniform.albedo_color = Guard.UNIFORM_COLORS[(slot - 1) % Guard.UNIFORM_COLORS.size()]
	if new_state.begins_with("step"):
		Sfx.play_at(self, Sfx.notes([196.0, 0.0, 196.0, 0.0, 196.0], 0.1, 0.3, "saw"), 0.0, 25.0)


func _build_body() -> void:
	var body := part(capsule(0.35, 1.75), Guard.UNIFORM_COLORS[0], Vector3(0, 0.875, 0))
	_uniform = body.material_override as StandardMaterial3D
	part(box(Vector3(0.42, 0.14, 0.12)), Color(0.02, 0.02, 0.03), Vector3(0, 1.6, -0.3))
	part(box(Vector3(0.36, 0.1, 0.38)), Color(0.08, 0.08, 0.1), Vector3(0, 1.82, 0))
