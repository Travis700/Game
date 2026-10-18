class_name Piano
extends Node3D
## The old upright piano in the band room. E on it plays a note (the next of a few that don't
## quite go together), loud enough that the monsters that hunt by sound come to see who's
## playing. Now and then, with nobody in sight of it, it plays a few notes by itself (Haunting
## decides when and asks us). The host decides; every computer plays it.

## The notes it has (assets/sounds/piano_<note>.ogg, made by tools/gen_fixture_sounds.py), in
## the order E plays them.
const NOTES: Array[String] = ["c4", "e4", "ds4", "a3", "e4", "d4", "a4", "ds4"]
## What it plays by itself: a few notes each, never quite a tune.
const TUNES: Array[Array] = [["e4", "ds4", "e4", "a3"], ["a3", "c4", "e4", "ds4", "d4"], ["a4", "e4", "c4", "a3"],
	["c4", "c4", "ds4"]]
const TUNE_STEP := 0.5
## Real seconds between notes from the same guard's presses (host).
const PLAY_EVERY := 0.3
## How long a note keeps the sound hunters coming, and how far it carries.
const NOISE_SECONDS := 3.0
const NOISE_REACH := 28.0

var _keys: Interactable
var _next := 0
var _played_at := -10.0


## Every computer, as the school is built: the piano SchoolBuilder put in the band room.
func build(builder: SchoolBuilder) -> void:
	name = "Piano"
	_keys = builder.piano_body
	if _keys == null:
		return
	_keys.prompt = "Play the piano"
	_keys.used.connect(_on_used)


func _on_used(by: Node) -> void:
	var guard := by as Guard
	if guard == null or not guard.is_local() or guard.is_dead:
		return
	if multiplayer.is_server():
		_request_note()
	else:
		_request_note.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_note() -> void:
	if not multiplayer.is_server() or _keys == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _played_at < PLAY_EVERY:
		return
	_played_at = now
	var note := NOTES[_next % NOTES.size()]
	_next += 1
	_play_note.rpc(note)
	var game := get_tree().get_first_node_in_group("game")
	var director := game.get("director") as MonsterDirector if game else null
	if director:
		director.make_noise(_keys.global_position, NOISE_SECONDS, NOISE_REACH)


@rpc("authority", "call_local", "reliable")
func _play_note(note: String) -> void:
	if not note in NOTES:
		return
	_sound(note, 0.0)
	get_tree().call_group("captions", "heard", "Fixture", "piano", _keys.global_position)


func _sound(note: String, volume_db: float) -> void:
	var freq := {"a3": 220.0, "c4": 261.6, "d4": 293.7, "ds4": 311.1, "e4": 329.6, "a4": 440.0}.get(note, 261.6) as float
	SoundBank.play_at(_keys, "piano_" + note, volume_db, 40.0, Sfx.notes([freq, freq, freq * 0.5], 0.4, 0.2, "sine"))


## Host, for Haunting: where the piano is (Vector3.INF if there isn't one).
func haunt_spot() -> Vector3:
	return _keys.global_position if _keys else Vector3.INF


## Host, for Haunting: nobody's at it, but the piano plays a few notes.
func haunt() -> void:
	if _keys:
		_play_tune.rpc(randi() % TUNES.size())


@rpc("authority", "call_local", "reliable")
func _play_tune(index: int) -> void:
	if index < 0 or index >= TUNES.size() or _keys == null:
		return
	var tune: Array = TUNES[index]
	var notes := create_tween()
	for i in tune.size():
		var note: String = tune[i]
		notes.tween_callback(func() -> void: _sound(note, -3.0))
		# Unsteady, as if whoever's playing is feeling for the keys.
		notes.tween_interval(TUNE_STEP * randf_range(0.7, 1.5))
	get_tree().call_group("captions", "heard", "Haunt", "piano", _keys.global_position)
