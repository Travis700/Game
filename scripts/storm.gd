class_name Storm
extends Node
## The "Thunderstorm" shift note: rain drumming on the roof all night, thunder rolling round the
## building, and lightning that lights up every window (and the gym through its high ones) for a
## moment. Each computer plays its own storm: it's weather, not a clue.

## Real seconds between peals of thunder.
const THUNDER_EVERY := Vector2(20.0, 55.0)
## How bright the moon flashes for lightning, near and far.
const FLASH_NEAR := 6.0
const FLASH_FAR := 1.6

var moon: DirectionalLight3D
var environment: Environment
## The windows' glass seen from inside, which flashes white.
var window_glass: StandardMaterial3D

var _rain: AudioStreamPlayer
var _next_thunder := 0.0
var _on := false


func _ready() -> void:
	_rain = AudioStreamPlayer.new()
	_rain.stream = SoundBank.get_sound("rain", Sfx.notes([1.0], 2.0, 0.05, "noise", true), true)
	_rain.volume_db = -15.0
	add_child(_rain)
	set_process(false)


## Every computer, as tonight's conditions arrive (and when they're cleared).
func set_active(on: bool) -> void:
	if on == _on:
		return
	_on = on
	set_process(on)
	if on:
		_rain.play()
		# Not until the lights have finished going down.
		_next_thunder = randf_range(15.0, 25.0)
	else:
		_rain.stop()


func _process(delta: float) -> void:
	_next_thunder -= delta
	if _next_thunder > 0.0:
		return
	_next_thunder = randf_range(THUNDER_EVERY.x, THUNDER_EVERY.y)
	var near := randf() < 0.35
	_flash(near)
	# Sound is slower than light: the further it struck, the longer the wait.
	var wait := randf_range(0.15, 0.6) if near else randf_range(1.5, 4.0)
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		if _on:
			SoundBank.play_flat(self, "thunder_%d" % (randi_range(2, 3) if near else randi_range(0, 1)),
					-1.0 if near else -7.0, Sfx.thud(1.5, 0.08, 2.0)))


func _flash(near: bool) -> void:
	if moon == null:
		return
	var base := moon.light_energy
	var peak := FLASH_NEAR if near else FLASH_FAR
	var ambient := environment.ambient_light_energy if environment else 0.0
	var glow := window_glass.emission_energy_multiplier if window_glass else 0.0
	var glow_colour := window_glass.emission if window_glass else Color.BLACK
	var flicker := create_tween()
	for i in (3 if near else 1):
		flicker.tween_callback(func() -> void:
			moon.light_energy = peak * randf_range(0.6, 1.0)
			if window_glass:
				window_glass.emission = Color(0.8, 0.85, 1.0)
				window_glass.emission_energy_multiplier = 5.0 if near else 1.8
			if environment:
				environment.ambient_light_energy = ambient + (0.25 if near else 0.08))
		flicker.tween_interval(randf_range(0.04, 0.09))
		flicker.tween_callback(func() -> void:
			moon.light_energy = base
			if window_glass:
				window_glass.emission = glow_colour
				window_glass.emission_energy_multiplier = glow
			if environment:
				environment.ambient_light_energy = ambient)
		flicker.tween_interval(randf_range(0.05, 0.15))
