class_name Footsteps
extends Node
## Plays footstep sounds for its parent (a guard or a monster) as it moves, on every computer.
## It works from the parent's position, which is synced for everyone, so other players hear
## your steps too.

## Metres between steps.
@export var stride := 0.75
@export var volume_db := -6.0
## Lower for heavy things, higher for small scuttling ones.
@export var pitch := 1.0
## How far away the steps can be heard.
@export var reach := 22.0
## Set false to go quiet (e.g. a ghost, or someone sitting down).
var enabled := true

var _last := Vector3.INF
var _walked := 0.0
## Speed smoothed over about a quarter of a second. Bodies move in physics steps, so on a fast
## monitor some frames see no movement and others a whole step; the average is the real speed.
var _speed := 0.0


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
		return
	_walked += moved
	_speed = lerpf(_speed, moved / maxf(delta, 0.001), 1.0 - exp(-delta * 4.0))
	# Running steps come further apart and land harder.
	var running := _speed > 4.5
	if _walked >= stride * (1.35 if running else 1.0):
		_walked = 0.0
		var loudness := volume_db + (5.0 if running else 0.0)
		var player := Sfx.play_at(body, SoundBank.get_sound(_surface(now), Sfx.thud(pitch)), loudness, reach * (1.5 if running else 1.0))
		player.pitch_scale = pitch * randf_range(0.92, 1.08)


## What's underfoot here: the gym's wooden floor, the grass outside (or the path through it),
## or the school's hard floors.
static func _surface(at: Vector3) -> String:
	var area := SchoolBuilder.area_at(at)
	if area == "Gym":
		return "step_wood"
	if at.z > 20.6 and absf(at.x) < 41.0:
		return "step_concrete" if absf(at.x) < 2.2 or at.z > 60.0 else "step_grass"
	return "step_concrete"
