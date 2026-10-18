class_name Student
extends Monster
## The Student: a kid in the hallway who says they're locked in and asks for help.
## They lead the guard who comes close to "their friend". Usually it's a trap: at the end
## they turn around, and they never show up on the security cameras. Rarely, they're real.

const LEAD_SPEED := 2.6
const CHASE_SPEED := 5.2
const CHASE_TIME := 10.0
const NOTICE_DISTANCE := 4.5
## Real seconds it waits for a guard who stopped following before giving up on them.
const WAIT_FOR_FOLLOWER := 20.0
## Real seconds the fake stands still after turning round, before it comes for you.
const REVEAL_PAUSE := 1.2
const DESTINATIONS: Array[Vector3] = [Vector3(35, 0, -25), Vector3(-35, 0, -25), Vector3(0, 0, -27)]

## Set by the director when it spawns: is this a real kid?
var real := false
var _destination := Vector3.ZERO
var _follower: Guard
var _chase_left := 0.0
var _waiting_for := 0.0


func _init() -> void:
	display_name = "the student"
	footstep_pitch = 1.4
	footstep_stride = 0.55
	state = "wait"


func _ready() -> void:
	harmless = real
	if not real:
		visual_layers = SecurityCameras.HIDDEN_FROM_CAMERAS
	super._ready()


func think(delta: float) -> void:
	match state:
		"wait":
			halt()
			for guard in director.targetable_guards():
				if distance_to_guard(guard) < NOTICE_DISTANCE and director.can_see(eye_position(), guard):
					_follower = guard
					_waiting_for = 0.0
					_destination = DESTINATIONS.pick_random()
					state = "lead"
					director.tell(guard.name.to_int(), "A kid grabs your sleeve: \"Please, I got locked in, and my friend's hurt. Follow me!\"")
					return
		"lead":
			if not is_instance_valid(_follower) or _follower.is_dead:
				state = "wait"
				return
			if global_position.distance_to(_destination) < 1.5:
				_arrive()
			elif distance_to_guard(_follower) > 8.0:
				halt()
				face(_follower.global_position - global_position)
				_waiting_for += delta
				if _waiting_for > WAIT_FOR_FOLLOWER:
					# They didn't follow. Wait for someone else.
					_follower = null
					state = "wait"
			else:
				_waiting_for = 0.0
				move_to(_destination, LEAD_SPEED)
		"reveal":
			_chase_left -= delta
			if _chase_left > CHASE_TIME - REVEAL_PAUSE:
				# A moment to see its face, and to run.
				halt()
			else:
				chase(_follower, CHASE_SPEED, delta)
			if _chase_left <= 0.0:
				director.remove_monster(self)
		"leave":
			# Out of the gate, or stuck on the way (gone home another way): either way, gone.
			if global_position.distance_to(Vector3(0, 0, 40)) < 2.0 or is_stuck():
				director.remove_monster(self)
			else:
				move_to(Vector3(0, 0, 40), LEAD_SPEED)


func _arrive() -> void:
	var peer := _follower.name.to_int()
	if real:
		director.tell(peer, "\"Oh! They must have gone home. Thanks for walking with me... I'll wait outside for my mom.\"")
		director.student_helped.emit(peer)
		_stuck_for = 0.0
		state = "leave"
	else:
		director.tell(peer, "The kid turns around. Its face is wrong.")
		_chase_left = CHASE_TIME
		state = "reveal"


## Once it has turned round it can't pass for a kid again: a lockdown doesn't change that.
func _after_lockdown(before: String) -> void:
	if before == "reveal":
		state = before
	else:
		super(before)


## The fake turns round with a scream, heard on every computer.
func _on_state_changed(new_state: String) -> void:
	if new_state == "reveal" and is_inside_tree():
		SoundBank.play_at(self, "scream", 2.0, 40.0, Sfx.notes([1400.0, 1100.0, 800.0, 500.0], 0.12, 0.4, "saw"))


func _build_body() -> void:
	if use_model("student", 1.35):
		return
	part(capsule(0.22, 1.25), Color(0.2, 0.35, 0.55), Vector3(0, 0.63, 0))
	part(box(Vector3(0.36, 0.38, 0.14)), Color(0.55, 0.15, 0.15), Vector3(0, 0.95, 0.22))
	part(sphere(0.13), Color(0.75, 0.62, 0.52), Vector3(0, 1.38, 0))
	part(sphere(0.135), Color(0.2, 0.13, 0.08), Vector3(0, 1.43, 0.03))


## Passes for the real thing (see Monster.disguised).
func disguised() -> bool:
	return not real and state != "reveal"
