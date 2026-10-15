class_name CrossingGuard
extends Monster
## The Crossing Guard: an orange vest, a white cap and a STOP sign, working the hallways of
## the science wing and the east end of the main hall as if they were roads.
##
## It walks to a "crossing", blows its whistle and holds up the sign. While the sign is up,
## don't move: anyone it can see moving gets run down. When the sign comes down, go.

const WALK_SPEED := 2.0
## Just under running speed: run and break line of sight and you can get away.
const CHARGE_SPEED := 5.4
const SIGHT_RANGE := 22.0
## Real seconds: grace after the whistle, how long the sign stays up, and the longest charge.
const GRACE_SECONDS := 1.2
const STOP_SECONDS := 6.0
const CHARGE_SECONDS := 6.0
## Faster than this (metres per second) counts as moving.
const MOVING_SPEED := 0.6
const CROSSINGS: Array[Vector3] = [
	Vector3(75, 0, 7), Vector3(62, 0, 7), Vector3(48, 0, 7), Vector3(34, 0, 7), Vector3(18, 0, 7),
]

var _crossing := 0
var _stop_left := 0.0
var _target: Guard
var _charge_left := 0.0
var _sign: Node3D


func _init() -> void:
	display_name = "the Crossing Guard"
	state = "walk"


func think(delta: float) -> void:
	match state:
		"stop":
			_hold_sign(delta)
		"charge":
			_charge(delta)
		_:
			_walk()


func _walk() -> void:
	var spot := CROSSINGS[_crossing]
	if Vector2(global_position.x - spot.x, global_position.z - spot.z).length() < 1.0:
		_stop_left = STOP_SECONDS + GRACE_SECONDS
		state = "stop"
		return
	move_to(spot, WALK_SPEED)


func _hold_sign(delta: float) -> void:
	halt()
	_stop_left -= delta
	if _stop_left <= 0.0:
		_crossing = (_crossing + 1 + randi() % (CROSSINGS.size() - 1)) % CROSSINGS.size()
		# The sign comes down: "clear" (walking on, with an all-clear whistle).
		state = "clear"
		return
	if _stop_left > STOP_SECONDS:
		return
	var mover := find_guard(SIGHT_RANGE, true, func(guard: Guard) -> bool:
		return director.guard_speed(guard) > MOVING_SPEED)
	if mover:
		_target = mover
		_charge_left = CHARGE_SECONDS
		state = "charge"


func _charge(delta: float) -> void:
	_charge_left -= delta
	if _charge_left <= 0.0 or not chase(_target, CHARGE_SPEED, delta):
		_target = null
		state = "walk"


func _on_state_changed(new_state: String) -> void:
	if _sign:
		var raised := new_state == "stop" or new_state == "charge"
		_sign.position = Vector3(0.35, 1.9, -0.2) if raised else Vector3(0.35, 0.9, -0.1)
		_sign.rotation_degrees.x = 0.0 if raised else -70.0
	if new_state == "stop":
		SoundBank.play_at(self, "whistle_crossing", 3.0, 45.0, Sfx.notes([2800.0, 2800.0], 0.25, 0.3, "square"))
	elif new_state == "clear":
		SoundBank.play_at(self, "rush_steps", 0.0, 45.0, Sfx.notes([2400.0, 0.0, 3000.0], 0.07, 0.3, "square"))
	elif new_state == "charge":
		var clear := SoundBank.play_at(self, "whistle_crossing", 4.0, 45.0, Sfx.notes([2800.0, 0.0, 2800.0, 0.0, 2800.0], 0.08, 0.35, "square"))
		if clear:
			clear.pitch_scale = 1.15


func _build_body() -> void:
	part(capsule(0.27, 1.7), Color(0.2, 0.2, 0.25), Vector3(0, 0.85, 0))
	part(box(Vector3(0.58, 0.75, 0.4)), Color(1.0, 0.45, 0.05), Vector3(0, 1.15, 0), 0.5)
	part(box(Vector3(0.6, 0.06, 0.42)), Color(0.9, 0.9, 0.7), Vector3(0, 1.1, 0), 1.2)
	part(sphere(0.15), Color(0.7, 0.62, 0.55), Vector3(0, 1.85, 0))
	part(box(Vector3(0.34, 0.08, 0.36)), Color(0.95, 0.95, 0.95), Vector3(0, 1.98, -0.03))
	part(box(Vector3(0.3, 0.03, 0.14)), Color(0.95, 0.95, 0.95), Vector3(0, 1.95, -0.2))
	_sign = Node3D.new()
	add_child(_sign)
	var pole := part(box(Vector3(0.04, 1.1, 0.04)), Color(0.6, 0.6, 0.6), Vector3.ZERO)
	pole.reparent(_sign, false)
	pole.position = Vector3(0, -0.3, 0)
	var plate := part(box(Vector3(0.5, 0.5, 0.03)), Color(0.85, 0.05, 0.05), Vector3.ZERO, 0.6)
	plate.reparent(_sign, false)
	plate.position = Vector3(0, 0.45, 0)
	plate.rotation_degrees.z = 22.5
	var word := Label3D.new()
	word.text = "STOP"
	word.font_size = 40
	word.pixel_size = 0.004
	word.position = Vector3(0, 0.45, -0.02)
	word.rotation.y = PI
	word.layers = visual_layers
	_sign.add_child(word)
