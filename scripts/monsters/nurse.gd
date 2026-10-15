class_name Nurse
extends Monster
## The Nurse: in a white uniform and a mask, making rounds of the classroom wing with a
## heart monitor's beep that follows her around.
##
## She looks after guards who are on their own. Anyone with nobody else within 8 metres gets her
## attention, and she walks after them, slowly but without stopping. Stick together (or keep
## moving) and she leaves you be. She walks faster the longer she follows, and gives up after a
## while (or at the guard room door, before night 7).

const ROUNDS_SPEED := 1.3
const FOLLOW_SPEED := 1.7
## A guard is "alone" with no other living guard this close.
const BUDDY_DISTANCE := 8.0
const NOTICE_RANGE := 18.0
## Real seconds she follows someone before giving up, and then rests before following again.
const FOLLOW_SECONDS := 70.0
const REST_SECONDS := 40.0
const ROUNDS: Array[Vector3] = [
	Vector3(-74, 0, 15), Vector3(-72, 0, 7), Vector3(-61, 0, 15), Vector3(-55, 0, 7),
	Vector3(-47, 0, 15), Vector3(-30, 0, 7), Vector3(-49, 0, -6),
]

var _target: Guard
var _follow_left := 0.0
var _rest_left := 0.0
var _beep_left := 0.0
var _beep: AudioStream


func _init() -> void:
	display_name = "the Nurse"
	# Hard shoes, in no hurry.
	footstep_pitch = 1.5
	footstep_volume = 1.0
	state = "rounds"


func think(delta: float) -> void:
	_rest_left = maxf(_rest_left - delta, 0.0)
	if state == "follow":
		_follow(delta)
	else:
		_rounds(delta)


func _rounds(delta: float) -> void:
	if _rest_left <= 0.0:
		var guard := find_guard(NOTICE_RANGE, true, _is_alone)
		if guard:
			_target = guard
			# A guard on their own all night gets shorter visits.
			_follow_left = FOLLOW_SECONDS * (0.7 if director.team_size <= 1 else 1.0)
			state = "follow"
			director.tell(guard.name.to_int(), "A heart monitor beeps somewhere behind you. \"You shouldn't be wandering about alone.\"")
			return
	patrol_step(ROUNDS, delta, ROUNDS_SPEED, Vector2(4.0, 8.0))


func _follow(delta: float) -> void:
	_follow_left -= delta
	# She walks faster the longer she follows: it won't do to just stroll ahead of her.
	var followed := FOLLOW_SECONDS * (0.7 if director.team_size <= 1 else 1.0) - _follow_left
	# Slow at first, then faster than walking: you can't just stroll away from her for long.
	var speed := minf(FOLLOW_SPEED + 0.04 * followed, 3.6)
	if not is_instance_valid(_target) or _follow_left <= 0.0 or not _is_alone(_target) \
			or not chase(_target, speed, delta):
		_stop_following()


func _stop_following() -> void:
	_target = null
	_rest_left = REST_SECONDS
	state = "rounds"


func _is_alone(guard: Guard) -> bool:
	for other in director.living_guards():
		if other != guard and other.global_position.distance_to(guard.global_position) < BUDDY_DISTANCE:
			return false
	return true


## The beep plays on every computer while she's following someone.
func _process(delta: float) -> void:
	if state != "follow":
		return
	_beep_left -= delta
	if _beep_left <= 0.0:
		_beep_left = 1.1
		if _beep == null:
			_beep = Sfx.notes([1760.0], 0.09, 0.22, "sine")
		SoundBank.play_at(self, "monitor_beep", -2.0, 22.0, _beep)


func _build_body() -> void:
	var white := Color(0.88, 0.88, 0.86)
	part(capsule(0.27, 1.7), white, Vector3(0, 0.85, 0))
	part(sphere(0.15), Color(0.8, 0.76, 0.72), Vector3(0, 1.85, 0))
	part(box(Vector3(0.24, 0.12, 0.06)), Color(0.75, 0.85, 0.85), Vector3(0, 1.8, -0.13))
	part(box(Vector3(0.28, 0.1, 0.24)), white, Vector3(0, 2.0, 0))
	part(box(Vector3(0.08, 0.03, 0.02)), Color(0.8, 0.05, 0.05), Vector3(0, 2.02, -0.12))
	part(box(Vector3(0.03, 0.08, 0.02)), Color(0.8, 0.05, 0.05), Vector3(0, 2.02, -0.12))
	for side: float in [-1.0, 1.0]:
		part(sphere(0.02), Color(0.05, 0.05, 0.05), Vector3(side * 0.06, 1.89, -0.14))
