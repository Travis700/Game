class_name RoomTones
extends Node3D
## The building's own small sounds, so each part of the school sounds a little different: the
## kitchen fridge, the vending machines, each wall clock's tick and the buzz of the ceiling lights
## that are on. All quiet, and only heard up close. A power cut silences the lot (the lights'
## buzz goes with the lights, see Power).
##
## Only on this computer: nothing here matters to the game, so nothing is sent.

## How each sound plays: [volume (dB), how far it carries (m)].
const SOUNDS := {
	"room_fridge": [-12.0, 9.0],
	"room_vending": [-13.0, 8.0],
	"clock_tick": [-14.0, 5.0],
	"room_fluorescent": [-24.0, 6.0],
}
## How often (real seconds) emitters near you are switched on and far ones off.
const CHECK_SECONDS := 0.3
## Ceiling lights higher than this (the gym's) are too far up to hear.
const BUZZ_MAX_HEIGHT := 4.0

var school: SchoolBuilder
var power: Power

## Each sound source: {"player", "light" (for a ceiling light's buzz, else null)}.
var _emitters: Array[Dictionary] = []
var _wait := 0.0


func _ready() -> void:
	# The school builds itself when it's added, so its spots are ready unless it came later.
	_build.call_deferred()


func _build() -> void:
	if school == null:
		return
	for spot: Dictionary in school.hum_spots:
		_add(spot["sound"], spot["at"], null)
	for node in get_tree().get_nodes_in_group(ShiftLighting.SCHOOL_LIGHTS):
		var light := node as Light3D
		if light == null or not light.has_meta("panel") or light.global_position.y > BUZZ_MAX_HEIGHT:
			continue
		_add("room_fluorescent", (light.get_meta("panel") as Node3D).global_position, light)


func _add(sound: String, at: Vector3, light: Light3D) -> void:
	var stream := SoundBank.get_sound(sound, null, true)
	if stream == null or not SOUNDS.has(sound):
		return
	var player := AudioStreamPlayer3D.new()
	player.bus = &"Ambience"
	player.stream = stream
	player.volume_db = SOUNDS[sound][0]
	player.max_distance = SOUNDS[sound][1]
	player.unit_size = 2.0
	# No two machines (or tubes) quite the same.
	player.pitch_scale = randf_range(0.94, 1.06)
	player.position = at
	add_child(player)
	_emitters.append({"player": player, "light": light})


func _process(delta: float) -> void:
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = CHECK_SECONDS
	var camera := get_viewport().get_camera_3d()
	var mains := power == null or power.on
	for emitter in _emitters:
		var player: AudioStreamPlayer3D = emitter["player"]
		var light: Light3D = emitter["light"]
		var heard := mains and camera != null \
				and camera.global_position.distance_to(player.global_position) < player.max_distance + 1.0
		if heard and light != null:
			heard = light.is_visible_in_tree() and light.light_energy > 0.05
		if heard != player.playing:
			if heard:
				# Each starts somewhere in its loop, so a row of lights doesn't buzz in step.
				player.play(randf() * 0.9)
			else:
				player.stop()
