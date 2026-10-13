class_name FlickerLight
extends OmniLight3D
## A ceiling light on its way out: steady until the night starts, then it stutters now and then.

var flickering := false

var _base_energy := 1.0
var _timer := 0.0


## Starts flickering around the light's current brightness.
func start_flickering() -> void:
	_base_energy = light_energy
	_timer = randf_range(0.5, 3.0)
	flickering = true


func _process(delta: float) -> void:
	if not flickering:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if light_energy < _base_energy:
		light_energy = _base_energy
		_timer = randf_range(0.05, 0.25) if randf() < 0.5 else randf_range(1.5, 6.0)
	else:
		light_energy = _base_energy * randf_range(0.0, 0.3)
		_timer = randf_range(0.03, 0.15)
