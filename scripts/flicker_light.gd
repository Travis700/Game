class_name FlickerLight
extends OmniLight3D
## A ceiling light on its way out: mostly steady, with the occasional stutter.

var _base_energy := 1.0
var _timer := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_timer = randf_range(1.0, 5.0)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	if light_energy < _base_energy:
		light_energy = _base_energy
		_timer = randf_range(0.05, 0.25) if randf() < 0.5 else randf_range(1.5, 6.0)
	else:
		light_energy = _base_energy * randf_range(0.0, 0.3)
		_timer = randf_range(0.03, 0.15)
