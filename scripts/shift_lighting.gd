class_name ShiftLighting
extends Node
## Lighting for the two halves of the evening.
## Before the shift: floodlights, street lights and every light inside on, so arriving feels ordinary.
## On clock-in: the floodlights cut out one by one, some ceiling lights click off,
## the rest dim, the fog closes in and the faulty lights start to flicker.

const SCHOOL_LIGHTS := "school_lights"
const FLOODLIGHTS := "floodlights"

const FLOOD_GAP := 0.35
const CLICK_GAP := 0.18
const DIM_SECONDS := 3.0

const PRE_SHIFT := {
	"background_color": Color(0.07, 0.09, 0.15),
	"ambient_light_color": Color(0.42, 0.44, 0.5),
	"ambient_light_energy": 0.45,
	"fog_light_color": Color(0.14, 0.15, 0.2),
	"fog_density": 0.002,
}
const NIGHT := {
	"background_color": Color(0.015, 0.02, 0.035),
	"ambient_light_color": Color(0.1, 0.12, 0.18),
	"ambient_light_energy": 0.28,
	"fog_light_color": Color(0.04, 0.05, 0.08),
	"fog_density": 0.02,
}

var environment: Environment
var school: SchoolBuilder
## The lights-out sequence and the dimming, so going bright can cut them short.
var _tweens: Array[Tween] = []
## Night values that differ tonight (e.g. thick fog), over NIGHT. Set by Conditions.
var _night_overrides: Dictionary = {}
## True once the night's dimming has finished (until the lights come back).
var _dark := false


func apply_pre_shift() -> void:
	for property: String in PRE_SHIFT:
		environment.set(property, PRE_SHIFT[property])


func go_dark() -> void:
	var sequence := create_tween()
	_tweens.append(sequence)
	for flood: SpotLight3D in get_tree().get_nodes_in_group(FLOODLIGHTS):
		sequence.tween_callback(_cut_floodlight.bind(flood))
		sequence.tween_interval(FLOOD_GAP)
	sequence.tween_interval(0.5)
	for light: Light3D in _school_lights():
		if light.get_meta("night_energy") == 0.0:
			sequence.tween_callback(_switch_off.bind(light))
			sequence.tween_interval(CLICK_GAP)
	sequence.tween_interval(0.4)
	sequence.tween_callback(_dim_everything)


func _cut_floodlight(flood: SpotLight3D) -> void:
	flood.visible = false
	var lens: MeshInstance3D = flood.get_meta("lens")
	lens.material_override = school.get_material("flood_off")


func _switch_off(light: Light3D) -> void:
	light.visible = false
	if light.has_meta("panel"):
		var panel: MeshInstance3D = light.get_meta("panel")
		panel.material_override = school.get_material("light_panel_off")


func _dim_everything() -> void:
	var dim := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	_tweens.append(dim)
	for light: Light3D in _school_lights():
		if light.visible:
			dim.tween_property(light, "light_energy", light.get_meta("night_energy"), DIM_SECONDS)
	for property: String in NIGHT:
		dim.tween_property(environment, property, _night_overrides.get(property, NIGHT[property]), DIM_SECONDS)
	dim.tween_property(school.get_material("light_panel"), "emission_energy_multiplier", 1.0, DIM_SECONDS)
	dim.chain().tween_callback(_start_flickering)
	dim.chain().tween_callback(func() -> void: _dark = true)


## Tonight's differences from an ordinary night. If the night has already gone dark, the
## change fades in now.
func set_night_overrides(overrides: Dictionary) -> void:
	_night_overrides = overrides
	if not _dark:
		return
	var fade := create_tween().set_parallel(true)
	_tweens.append(fade)
	for property: String in NIGHT:
		fade.tween_property(environment, property, _night_overrides.get(property, NIGHT[property]), DIM_SECONDS)


func _start_flickering() -> void:
	for light: Light3D in _school_lights():
		if light is FlickerLight and light.visible:
			(light as FlickerLight).start_flickering()


## 6 AM (or the team being caught): everything comes back on, ready for the next evening.
## Safe to call when the lights are already on.
func go_bright() -> void:
	_dark = false
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens.clear()
	for flood: SpotLight3D in get_tree().get_nodes_in_group(FLOODLIGHTS):
		flood.visible = true
		var lens: MeshInstance3D = flood.get_meta("lens")
		lens.material_override = school.get_material("flood_glow")
	var brighten := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	for light: Light3D in _school_lights():
		if light is FlickerLight:
			(light as FlickerLight).stop_flickering()
		if not light.visible:
			light.visible = true
			light.light_energy = 0.0
			if light.has_meta("panel"):
				var panel: MeshInstance3D = light.get_meta("panel")
				panel.material_override = school.get_material("light_panel")
		brighten.tween_property(light, "light_energy", light.get_meta("day_energy"), DIM_SECONDS)
	for property: String in PRE_SHIFT:
		brighten.tween_property(environment, property, PRE_SHIFT[property], DIM_SECONDS)
	brighten.tween_property(school.get_material("light_panel"), "emission_energy_multiplier", 2.0, DIM_SECONDS)


func _school_lights() -> Array[Node]:
	return get_tree().get_nodes_in_group(SCHOOL_LIGHTS)
