class_name SpiritBox
extends Node3D
## A switched-on spirit box, hissing on the guard who holds it (vending machine). It lives on
## that guard on every computer, so everyone close by hears the static sweeping.
##
## Ghosts who talk near it come through its static (see VoiceChat), and a ghost's cold spot
## nearby makes it spit out a word (`say`). Shop switches it on and off.

## How far the box's static carries, and how close a ghost (or a listener) must be to it.
const RANGE := 10.0
## The words a box can spit out when a ghost leaves a cold spot near it.
const WORDS: Array[String] = ["here", "behind", "run", "help"]

## The last word it said (for tests).
var last_word := ""
var _hiss: AudioStreamPlayer3D
## Seconds until the next sweep blip.
var _sweep_in := 0.5


func _ready() -> void:
	name = "SpiritBox"
	position = Vector3(0, 1.2, 0)
	# The hiss: quiet looped noise, wavering as it sweeps the stations.
	_hiss = AudioStreamPlayer3D.new()
	_hiss.bus = &"SFX"
	_hiss.stream = _static_loop()
	_hiss.volume_db = -20.0
	_hiss.unit_size = 2.0
	_hiss.max_distance = RANGE
	add_child(_hiss)
	_hiss.play()


func _process(delta: float) -> void:
	_sweep_in -= delta
	if _sweep_in > 0.0:
		return
	# The sweep: a click and a scrap of a station every second or so, and the hiss shifting.
	_sweep_in = randf_range(0.5, 1.4)
	_hiss.volume_db = randf_range(-24.0, -17.0)
	_hiss.pitch_scale = randf_range(0.85, 1.2)
	if randf() < 0.5:
		var blip := Sfx.play_at(self, Sfx.chirp(randf_range(500.0, 1400.0), randf_range(300.0, 1800.0), 0.05, 1, 0.08), -16.0, RANGE)
		blip.unit_size = 2.0
	elif randf() < 0.4:
		var crackle := SoundBank.play_at(self, "squelch", -22.0, RANGE, _crackle())
		if crackle:
			crackle.unit_size = 2.0


## Every computer: the box spits out a word through a burst of static. The living near it
## read it on screen.
func say(word: String) -> void:
	last_word = word
	var burst := SoundBank.play_at(self, "glitch", -4.0, RANGE * 1.5, _burst())
	if burst:
		burst.unit_size = 3.0
	var listener := _local_guard()
	if listener == null or listener.is_dead or listener.global_position.distance_to(global_position) > RANGE:
		return
	var holder := get_parent() as Guard
	var whose := "Your" if holder == listener else ("%s's" % holder.display_name() if holder else "The")
	listener.message_shown.emit("%s spirit box crackles: \"%s.\"" % [whose, word.to_upper()], 5.0)
	get_tree().call_group("captions", "heard", "SpiritBox", "word", global_position)


## The guard this computer's player controls, or null.
func _local_guard() -> Guard:
	var holder := get_parent()
	if holder == null or holder.get_parent() == null:
		return null
	for guard in holder.get_parent().get_children():
		if guard is Guard and (guard as Guard).is_local():
			return guard
	return null


## Two seconds of soft, looping radio hiss.
## Built once and shared (making the noise takes a moment).
static var _loop_cache: AudioStreamWAV
static var _crackle_cache: AudioStreamWAV
static var _burst_cache: AudioStreamWAV


static func _static_loop() -> AudioStreamWAV:
	if _loop_cache == null:
		_loop_cache = Sfx.notes([1.0], 2.0, 0.25, "noise", true)
	return _loop_cache


static func _crackle() -> AudioStreamWAV:
	if _crackle_cache == null:
		_crackle_cache = Sfx.notes([1.0], 0.08, 0.15, "noise")
	return _crackle_cache


static func _burst() -> AudioStreamWAV:
	if _burst_cache == null:
		_burst_cache = Sfx.notes([1.0, 1.0, 1.0], 0.12, 0.3, "noise")
	return _burst_cache
