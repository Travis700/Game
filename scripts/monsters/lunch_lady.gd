class_name LunchLady
extends Monster
## The Lunch Lady: blind, humming to herself as she wanders the cafeteria and kitchen.
## She hunts by sound. Running is loud enough to hear from across the cafeteria;
## walking is only heard close up; standing still is silent.

const WANDER_SPEED := 1.2
const HUNT_SPEED := 4.6
const HEAR_RUNNING := 16.0
const HEAR_WALKING := 5.0
## Voices: a whisper carries this far to her, a shout this far.
const HEAR_WHISPER := 5.0
const HEAR_SHOUT := 22.0
## Seconds of silence at the place she heard something before she goes back to wandering.
const LOSE_INTEREST_AFTER := 6.0
## How far short of the sound she stops to listen.
const STOP_SHORT := 2.0
const HOME: Array[AABB] = [
	AABB(Vector3(-39, 0, -29), Vector3(33, 1, 32)),
	AABB(Vector3(-4, 0, -29), Vector3(8, 1, 16)),
]

## How far she hears a loud noise (a camera speaker).
const NOISE_REACH := 40.0

var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _heard_at := Vector3.ZERO
var _silence := 0.0
var _hum: AudioStreamPlayer3D


func _init() -> void:
	display_name = "the Lunch Lady"
	state = "wander"


func think(delta: float) -> void:
	var heard := _listen()
	if heard:
		state = "hunt"
		_silence = 0.0
	if state == "hunt":
		_silence += delta
		# She stops a step short of where the sound was and listens: a guard who keeps still
		# right there is never found.
		# (While she can still hear someone, she keeps coming.)
		var reached := not heard and Vector2(global_position.x - _heard_at.x, global_position.z - _heard_at.z).length() < STOP_SHORT
		if _silence > LOSE_INTEREST_AFTER or (not reached and not move_to(_heard_at, HUNT_SPEED)):
			state = "wander"
			_wander_timer = 0.0
		elif reached:
			halt()
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 1.0:
			_pick_wander_target()
		move_to(_wander_target, WANDER_SPEED)
	_catch_audible()


## She only catches what she can hear: a guard standing still beside her is safe.
func _catch_audible() -> void:
	for guard in director.targetable_guards():
		if distance_to_guard(guard) < KILL_DISTANCE and (director.guard_speed(guard) > 0.8 or director.voice_reach(guard, HEAR_WHISPER, HEAR_SHOUT) > 0.0):
			director.kill(guard, display_name, global_position)
			return


func _listen() -> bool:
	for guard in director.targetable_guards():
		var speed := director.guard_speed(guard)
		var reach := HEAR_RUNNING if guard.is_running else (HEAR_WALKING if speed > 0.8 else 0.0)
		reach = maxf(reach, director.voice_reach(guard, HEAR_WHISPER, HEAR_SHOUT))
		if reach > 0.0 and distance_to_guard(guard) < reach:
			_heard_at = guard.global_position
			return true
	# Or anything loud nearby, like a camera speaker.
	var noise := director.noise_near(global_position, NOISE_REACH)
	if noise != Vector3.INF:
		_heard_at = noise
		return true
	return false


func _pick_wander_target() -> void:
	var room: AABB = HOME.pick_random()
	_wander_target = room.position + Vector3(randf() * room.size.x, 0, randf() * room.size.z)
	_wander_timer = 10.0


func _on_state_changed(new_state: String) -> void:
	if _hum == null:
		var tune := Sfx.notes([220.0, 247.0, 262.0, 247.0, 220.0, 196.0, 220.0, 0.0, 0.0], 0.45, 0.25, "sine", true)
		_hum = Sfx.play_at(self, tune, -2.0, 22.0)
	# She stops humming when she's heard something.
	_hum.stream_paused = new_state == "hunt"


func _build_body() -> void:
	part(capsule(0.42, 1.6), Color(0.5, 0.45, 0.58), Vector3(0, 0.8, 0))
	part(box(Vector3(0.6, 0.9, 0.05)), Color(0.9, 0.9, 0.88), Vector3(0, 0.75, -0.41))
	part(sphere(0.17), Color(0.75, 0.7, 0.62), Vector3(0, 1.74, 0))
	part(sphere(0.19), Color(0.92, 0.92, 0.92), Vector3(0, 1.82, 0.02), 0.0, 0.7)
	# Eyes shut.
	for side: float in [-1.0, 1.0]:
		part(box(Vector3(0.06, 0.012, 0.01)), Color(0.1, 0.05, 0.05), Vector3(side * 0.06, 1.77, -0.165))
	part(box(Vector3(0.04, 0.6, 0.04)), Color(0.6, 0.62, 0.65), Vector3(0.38, 1.0, -0.2))
	part(sphere(0.08), Color(0.6, 0.62, 0.65), Vector3(0.38, 0.68, -0.2))
