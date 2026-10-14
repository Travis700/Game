class_name Photographer
extends Monster
## The Photographer: the yearbook photographer, still taking pictures for a yearbook that was
## never printed. It wanders the main building with an old flash camera.
##
## When it sees a guard, it stops and its flash starts to whine as it charges. If that guard is
## looking at it when the flash goes off, they're blinded, and it comes at them while they can't
## see. Look away (or get out of sight) before the flash and it only gets a picture of your back.
## The opposite of the Mascot: this one you mustn't watch.

const WANDER_SPEED := 1.6
const RUSH_SPEED := 5.0
const SIGHT_RANGE := 16.0
## Real seconds the flash takes to charge, how long a blinded guard is rushed, and the rest after.
const CHARGE_SECONDS := 2.2
const RUSH_SECONDS := 6.0
const REST_SECONDS := 12.0
## How directly a guard has to be looking at it to be caught by the flash.
const LOOK_ANGLE := deg_to_rad(35)
const BLIND_SECONDS := 3.5
const SPOTS: Array[Vector3] = [
	Vector3(0, 0, 15), Vector3(-30, 0, 7), Vector3(-14, 0, 15), Vector3(-25, 0, -10),
	Vector3(30, 0, 7), Vector3(22, 0, -10), Vector3(0, 0, 7),
]

var _target: Guard
var _left := 0.0
var _flash_light: OmniLight3D


func _init() -> void:
	display_name = "the Photographer"
	state = "wander"


func think(delta: float) -> void:
	_left -= delta
	match state:
		"charging":
			halt()
			if not is_instance_valid(_target) or _target.is_dead:
				state = "wander"
				return
			face(_target.global_position - global_position)
			if _left <= 0.0:
				_take_picture()
		"rush":
			if _left <= 0.0 or not chase(_target, RUSH_SPEED, delta, 3.0):
				_rest()
		"rest", "missed":
			patrol_step(SPOTS, delta, WANDER_SPEED, Vector2(2.0, 5.0))
			if _left <= 0.0:
				state = "wander"
		_:
			patrol_step(SPOTS, delta, WANDER_SPEED, Vector2(2.0, 5.0))
			var guard := find_guard(SIGHT_RANGE, true)
			if guard:
				_target = guard
				_left = CHARGE_SECONDS
				state = "charging"
				director.tell(guard.name.to_int(), "A high whine, like an old camera flash charging.")


func _take_picture() -> void:
	var eye := _target.camera.global_position
	var to_me := eye_position() - eye
	var looking := (-_target.camera.global_basis.z).angle_to(to_me) < LOOK_ANGLE \
			and director.can_see(eye_position(), _target)
	if looking:
		director.flash_screen(_target.name.to_int(), Color(1, 1, 1, 1), BLIND_SECONDS)
		director.tell(_target.name.to_int(), "FLASH. You can't see a thing, but you can hear it coming.")
		_left = RUSH_SECONDS
		start_chase()
		state = "rush"
	else:
		director.tell(_target.name.to_int(), "The flash goes off behind you. It only got your back.")
		_rest()
		state = "missed"


func _rest() -> void:
	_target = null
	_left = REST_SECONDS
	state = "rest"


func _on_state_changed(new_state: String) -> void:
	match new_state:
		"charging":
			Sfx.play_at(self, _whine(), -2.0, 25.0)
		"rush", "missed":
			# Whether or not it caught anyone, the flash goes off for everyone nearby to see.
			_pop()


## The flash, seen by everyone nearby.
func _pop() -> void:
	if _flash_light == null:
		_flash_light = OmniLight3D.new()
		_flash_light.light_color = Color(1.0, 0.98, 0.9)
		_flash_light.omni_range = 14.0
		_flash_light.position = Vector3(0, 1.7, -0.4)
		add_child(_flash_light)
	_flash_light.light_energy = 12.0
	_flash_light.visible = true
	var fade := create_tween()
	fade.tween_property(_flash_light, "light_energy", 0.0, 0.35)
	fade.tween_callback(func() -> void: _flash_light.visible = false)
	Sfx.play_at(self, Sfx.thud(2.2, 0.06, 0.6), 2.0, 30.0)


func _whine() -> AudioStreamWAV:
	var freqs: Array = []
	for i in 22:
		freqs.append(1200.0 + i * 160.0)
	return Sfx.notes(freqs, CHARGE_SECONDS / 22.0, 0.18, "sine")


func _build_body() -> void:
	part(capsule(0.27, 1.75), Color(0.35, 0.3, 0.26), Vector3(0, 0.88, 0))
	part(sphere(0.15), Color(0.78, 0.74, 0.68), Vector3(0, 1.88, 0))
	# The camera, held up to where its face should be, and the flash on top.
	part(box(Vector3(0.3, 0.2, 0.16)), Color(0.08, 0.08, 0.09), Vector3(0, 1.85, -0.22))
	part(box(Vector3(0.1, 0.1, 0.12)), Color(0.15, 0.15, 0.16), Vector3(0, 1.85, -0.36))
	part(box(Vector3(0.16, 0.08, 0.06)), Color(0.9, 0.9, 0.85), Vector3(0.05, 2.0, -0.24), 1.5)
	part(box(Vector3(0.05, 0.6, 0.05)), Color(0.4, 0.3, 0.2), Vector3(-0.22, 1.3, -0.15))
