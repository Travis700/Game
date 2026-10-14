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


func _process(_delta: float) -> void:
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
	# Running steps come further apart and land harder.
	var running := moved / maxf(get_process_delta_time(), 0.001) > 4.5
	if _walked >= stride * (1.35 if running else 1.0):
		_walked = 0.0
		var loudness := volume_db + (5.0 if running else 0.0)
		var player := Sfx.play_at(body, Sfx.thud(pitch), loudness, reach * (1.5 if running else 1.0))
		player.pitch_scale = randf_range(0.92, 1.08)
