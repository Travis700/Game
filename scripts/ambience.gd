class_name Ambience
extends Node3D
## Night-time sound for the building: a low electrical hum, and every so often a creak or a
## distant thump somewhere nearby. Each computer plays its own (it's only atmosphere).

## Real seconds between the odd noises.
const NOISE_EVERY := Vector2(15.0, 40.0)

## The guard whose ears these are. Set by Main.
var listener: Node3D

var _hum: AudioStreamPlayer
var _next_noise := 0.0
var _playing := false


func _ready() -> void:
	_hum = AudioStreamPlayer.new()
	_hum.stream = SoundBank.get_sound("ambience", Sfx.hum(), true)
	_hum.volume_db = -18.0
	add_child(_hum)


## The lights have gone down.
func start() -> void:
	_playing = true
	_next_noise = randf_range(NOISE_EVERY.x, NOISE_EVERY.y)
	_hum.play()


## Morning, or a new evening.
func stop() -> void:
	_playing = false
	_hum.stop()


func _process(delta: float) -> void:
	if not _playing or listener == null or not listener.is_inside_tree():
		return
	_next_noise -= delta
	if _next_noise > 0.0:
		return
	_next_noise = randf_range(NOISE_EVERY.x, NOISE_EVERY.y)
	# Somewhere off to one side, 8-20 metres away.
	var angle := randf() * TAU
	var spot := listener.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(8.0, 20.0)
	spot.y = 2.0
	var stream: AudioStream = SoundBank.get_sound("creak", Sfx.creak()) if randf() < 0.65 else Sfx.thud(0.45, 0.35, 0.9)
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = -4.0
	player.max_distance = 40.0
	player.position = spot
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
