class_name Librarian
extends Monster
## The Librarian: hunched and long-necked, shelving books that nobody borrowed, in the library
## and along the West Hall. It can't stand light or noise.
##
## Shine a flashlight on it, or run near it, and it hisses "Shhh." Keep it up and it comes for
## you, until it's been dark and quiet for a few seconds. Walk past with your light off.

const SHELVE_SPEED := 1.2
const HUNT_SPEED := 4.6
const LIGHT_RANGE := 14.0
const HEAR_RUNNING := 10.0
## Talking anywhere near the stacks: a whisper carries this far, a shout this far.
const HEAR_WHISPER := 6.0
const HEAR_SHOUT := 20.0
## Real seconds between the warning and the hunt.
const WARNING_SECONDS := 2.0
## Real seconds of dark and quiet before it calms down.
const CALM_AFTER := 3.0
const STOPS: Array[Vector3] = [
	Vector3(-75.5, 0, -3), Vector3(-69.5, 0, -10), Vector3(-66.5, 0, -3), Vector3(-62, 0, -10),
	Vector3(-72.5, 0, -11),
	Vector3(-63, 0, 1.5), Vector3(-60, 0, 7), Vector3(-75, 0, 7),
]

var _target: Guard
var _warning_left := 0.0
var _calm_for := 0.0


func _init() -> void:
	display_name = "the Librarian"
	state = "shelve"


func think(delta: float) -> void:
	match state:
		"shush":
			_shush(delta)
		"hunt":
			_hunt(delta)
		_:
			_shelve(delta)


func _shelve(delta: float) -> void:
	var offender := _offender()
	if offender:
		_target = offender
		_warning_left = WARNING_SECONDS
		state = "shush"
		var what := _reason(offender)
		director.tell(offender.name.to_int(), "\"Shhh.\" Something in the stacks doesn't like your %s." % what)
		return
	# A noise in the stacks: she goes to see who's making it.
	var noise := director.noise_near(global_position, 25.0)
	if noise != Vector3.INF:
		move_to(noise, SHELVE_SPEED * 2.0)
		return
	patrol_step(STOPS, delta, SHELVE_SPEED, Vector2(5.0, 10.0), 3)


## The nearest living guard it can see with their light on it, or hear running.
func _offender() -> Guard:
	for guard in director.targetable_guards():
		var distance := distance_to_guard(guard)
		if guard.is_running and distance < HEAR_RUNNING:
			return guard
		if distance < director.voice_reach(guard, HEAR_WHISPER, HEAR_SHOUT):
			return guard
		if guard.flashlight.visible and distance < LIGHT_RANGE and director.lit_by_flashlight(eye_position(), LIGHT_RANGE, guard):
			return guard
	return null


## What gave this guard away, in the order _offender checks it.
func _reason(guard: Guard) -> String:
	var distance := distance_to_guard(guard)
	if guard.is_running and distance < HEAR_RUNNING:
		return "footsteps"
	if distance < director.voice_reach(guard, HEAR_WHISPER, HEAR_SHOUT):
		return "voice"
	return "light"


func _shush(delta: float) -> void:
	halt()
	if not is_instance_valid(_target) or _target.is_dead:
		state = "shelve"
		return
	face(_target.global_position - global_position)
	_warning_left -= delta
	if _warning_left > 0.0:
		return
	if _offender() == _target:
		state = "hunt"
		_calm_for = 0.0
	else:
		state = "shelve"


func _hunt(delta: float) -> void:
	if not is_instance_valid(_target) or _target.is_dead:
		state = "shelve"
		return
	# Only what it can still see or hear counts: get far enough away and it loses you.
	var distance := distance_to_guard(_target)
	var loud := (_target.flashlight.visible and distance < LIGHT_RANGE * 1.5) or (_target.is_running and distance < HEAR_RUNNING) \
			or distance < director.voice_reach(_target, HEAR_WHISPER, HEAR_SHOUT)
	_calm_for = 0.0 if loud else _calm_for + delta
	# In a power cut there's nothing to see by: it gives up twice as fast.
	if _calm_for > CALM_AFTER * (0.5 if director.is_dark() else 1.0) or not chase(_target, HUNT_SPEED, delta):
		state = "shelve"


func _on_state_changed(new_state: String) -> void:
	if new_state == "shush":
		SoundBank.play_at(self, "shush", 4.0, 25.0, Sfx.notes([1.0, 1.0, 1.0], 0.35, 0.18, "noise"))
	elif new_state == "hunt":
		SoundBank.play_at(self, "hiss", 6.0, 35.0, Sfx.notes([1.0, 1.0, 1.0, 1.0], 0.2, 0.35, "noise"))


func _build_body() -> void:
	if use_model("librarian", 1.95):
		return
	var cardigan := Color(0.25, 0.18, 0.22)
	var body := part(capsule(0.3, 1.5), cardigan, Vector3(0, 0.75, 0.1))
	body.rotation_degrees.x = 15.0
	# A neck that goes on too long, leaning forward.
	var neck := part(capsule(0.06, 0.7), Color(0.75, 0.72, 0.68), Vector3(0, 1.75, -0.12))
	neck.rotation_degrees.x = -30.0
	part(sphere(0.14), Color(0.78, 0.75, 0.7), Vector3(0, 2.08, -0.3))
	part(sphere(0.1), Color(0.5, 0.48, 0.45), Vector3(0, 2.2, -0.22))
	for side: float in [-1.0, 1.0]:
		part(sphere(0.022), Color(0.9, 0.9, 0.6), Vector3(side * 0.05, 2.1, -0.43), 2.0)
	part(box(Vector3(0.22, 0.3, 0.08)), Color(0.15, 0.3, 0.2), Vector3(0.25, 1.05, -0.25))
