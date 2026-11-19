class_name Footsteps
extends Node
## Plays footstep sounds for its parent (a guard or a monster) as it moves, on every computer.
## It works from the parent's position, which is synced for everyone, so other players hear
## your steps too.

## Metres between steps (monsters: their steps come with distance covered).
@export var stride := 0.75
@export var volume_db := -6.0
## Lower for heavy things, higher for small scuttling ones.
@export var pitch := 1.0
## How far away the steps can be heard.
@export var reach := 22.0
## Guards step to a rhythm instead: an easy walking pace, and once they run, steps that start
## a little quicker and keep quickening as they get into their stride.
@export var paced := false
## Set false to go quiet (e.g. a ghost, or someone sitting down).
var enabled := true

## Seconds between a guard's steps: creeping, walking, the first running steps, flat out.
const CROUCH_STEP := 0.72
const WALK_STEP := 0.5
const RUN_STEP_START := 0.4
const RUN_STEP_TOP := 0.27
## Seconds of running it takes to get up to the top pace.
const RUN_RAMP := 2.0
## Above this speed (metres a second) a body is running.
const RUN_SPEED := 4.5

var _last := Vector3.INF
var _walked := 0.0
## Speed smoothed over about a quarter of a second. Bodies move in physics steps, so on a fast
## monitor some frames see no movement and others a whole step; the average is the real speed.
var _speed := 0.0
## Paced: seconds since the last step, and how long it has been running (0 to RUN_RAMP).
var _since_step := 0.0
var _running_for := 0.0
## Which foot is next (they sound a touch different), and the last sound played, so the same
## recording doesn't land twice in a row.
var _left_foot := false
var _last_sound: AudioStream


func _process(delta: float) -> void:
	var body := get_parent() as Node3D
	if body == null or not body.is_inside_tree():
		return
	var now := body.global_position
	if _last == Vector3.INF:
		_last = now
		return
	var moved := Vector2(now.x - _last.x, now.z - _last.z).length()
	_last = now
	# Teleports (sitting down, being revived, a new night) aren't steps.
	if not enabled or moved > 2.0:
		_walked = 0.0
		_since_step = 0.0
		_running_for = 0.0
		return
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), 1.0 - exp(-delta * 4.0))
	var running := _speed > RUN_SPEED
	# Getting into a run builds up; slowing down lets it go again quickly.
	_running_for = clampf(_running_for + (delta if running else -delta * 3.0), 0.0, RUN_RAMP)
	if paced:
		if _speed < 0.6:
			# Standing still: the next step comes as soon as they set off.
			_since_step = 1.0
			return
		_since_step += delta
		if _since_step < _step_time(body):
			return
		_since_step = 0.0
	else:
		_walked += moved
		# Running steps come further apart and land harder.
		if _walked < stride * (1.35 if running else 1.0):
			return
		_walked = 0.0
	var build := _running_for / RUN_RAMP
	var loudness := volume_db + (lerpf(3.0, 6.0, build) if running else 0.0)
	var heard := reach * (1.5 if running else 1.0)
	# Crouched, you creep: softer steps, heard only close by.
	if body.get("is_crouching"):
		loudness -= 10.0
		heard *= 0.35
	_left_foot = not _left_foot
	var sound := _pick(_surface(now))
	var player := Sfx.play_at(body, sound, loudness + randf_range(-1.5, 1.0), heard)
	player.pitch_scale = pitch * (1.0 if _left_foot else 0.95) * randf_range(0.95, 1.05)


## Seconds until a guard's next step at the speed they're going.
func _step_time(body: Node3D) -> float:
	if body.get("is_crouching"):
		return CROUCH_STEP
	if _speed <= RUN_SPEED:
		# Slower than a walk (easing off, pushing a door): a slower step.
		return lerpf(CROUCH_STEP, WALK_STEP, clampf((_speed - 1.0) / 2.2, 0.0, 1.0))
	# Running: quicker the longer they keep it up (ease out, so the change is felt early), and
	# quicker still on an energy drink.
	var build := 1.0 - pow(1.0 - _running_for / RUN_RAMP, 2.0)
	var step := lerpf(RUN_STEP_START, RUN_STEP_TOP, build)
	return step * clampf(5.6 / _speed, 0.85, 1.0)


## A step for this surface, not the same recording as last time.
func _pick(surface: String) -> AudioStream:
	var sound := SoundBank.get_sound(surface, Sfx.thud(pitch))
	for _i in 3:
		if sound != _last_sound:
			break
		sound = SoundBank.get_sound(surface, Sfx.thud(pitch))
	_last_sound = sound
	return sound


## What's underfoot here: the gym's wooden floor, the grass outside (or the path through it),
## or the school's hard floors.
static func _surface(at: Vector3) -> String:
	var area := SchoolBuilder.area_at(at)
	if area == "Gym":
		return "step_wood"
	if at.z > 20.6 and absf(at.x) < 41.0:
		return "step_concrete" if absf(at.x) < 2.2 or at.z > 60.0 else "step_grass"
	return "step_concrete"
