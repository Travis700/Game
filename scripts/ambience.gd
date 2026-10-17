class_name Ambience
extends Node3D
## Night-time sound for the building: a low electrical hum, and every so often a creak, the
## heating pipes knocking or a distant thump somewhere nearby. Each computer plays its own (it's
## only atmosphere: nothing that sounds like a door, which would mean something).

## Real seconds between the odd noises.
const NOISE_EVERY := Vector2(15.0, 40.0)

## The guard whose ears these are. Set by Main.
var listener: Node3D
## How far into the night it is (0 at midnight, 1 at 6 AM). Set by Main. The building gets
## louder and busier towards the small hours, and settles a little in the last hour.
var night_progress := 0.0

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


## 0..1: how tense the building sounds now. Peaks between 3 and 5 AM.
func tension() -> float:
	return clampf(night_progress * 1.6, 0.0, 1.0) * (1.0 - clampf((night_progress - 0.85) * 2.0, 0.0, 0.3))


func _process(delta: float) -> void:
	if not _playing or listener == null or not listener.is_inside_tree():
		return
	_hum.volume_db = lerpf(-20.0, -12.0, tension())
	_next_noise -= delta
	if _next_noise > 0.0:
		return
	# Up to twice as often in the small hours.
	_next_noise = randf_range(NOISE_EVERY.x, NOISE_EVERY.y) / (1.0 + tension())
	# Somewhere off to one side, 8-20 metres away.
	var angle := randf() * TAU
	var spot := listener.global_position + Vector3(cos(angle), 0, sin(angle)) * randf_range(8.0, 20.0)
	spot.y = 2.0
	var roll := randf()
	var stream: AudioStream
	if roll < 0.5:
		stream = SoundBank.get_sound("creak", Sfx.creak())
	elif roll < 0.8:
		# The heating pipes, ticking and knocking as they cool.
		stream = SoundBank.get_sound("pipe_knock", Sfx.thud(1.4, 0.05, 0.5))
	else:
		stream = Sfx.thud(0.45, 0.35, 0.9)
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = lerpf(-6.0, -1.0, tension())
	player.max_distance = 40.0
	player.position = spot
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
