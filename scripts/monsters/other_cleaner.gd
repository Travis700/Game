class_name OtherCleaner
extends NightCleaner
## The Other Cleaner: looks almost exactly like the night cleaner and walks the same rounds.
## It has no cart, and its head sits at a slightly wrong angle. Get close and it drops the act.
## Log it as a Monster where you see it and it leaves.

const NOTICE_DISTANCE := 6.0
const CHASE_SPEED := 4.5
const CHASE_TIME := 7.0
## The moment it drops the act (a beat to react), how soon it gives up once it can't see you,
## and how long before it can do it again.
const REVEAL_SECONDS := 0.8
const LOSE_SIGHT_AFTER := 3.0
const REVEAL_COOLDOWN := 20.0
const LOST_COOLDOWN := 5.0

var _chase_left := 0.0
var _reveal_left := 0.0
var _cooldown := 0.0
var _target: Guard
var _eyes: Array[MeshInstance3D] = []


func _init() -> void:
	emf5 = true
	display_name = "the other cleaner"
	# Once it has shown itself it chases by sight, and checks a cupboard it saw you dive into.
	searches_cupboards = true
	harmless = false
	leaves_when_logged = true
	state = "walk"


func think(delta: float) -> void:
	_cooldown -= delta
	if _reveal_left > 0.0:
		_reveal_left -= delta
		halt()
		if is_instance_valid(_target):
			face(_target.global_position - global_position)
		if _reveal_left <= 0.0:
			start_chase()
		return
	if _chase_left > 0.0:
		_chase_left -= delta
		if not chase(_target, CHASE_SPEED, delta, LOSE_SIGHT_AFTER) or _chase_left <= 0.0:
			# A full rest only after a full chase: slipping out of sight buys a few seconds.
			_cooldown = REVEAL_COOLDOWN if _chase_left <= 0.0 else LOST_COOLDOWN
			_chase_left = 0.0
			state = "walk"
		return
	var guard := find_guard(NOTICE_DISTANCE) if _cooldown <= 0.0 else null
	if guard:
		_target = guard
		_chase_left = CHASE_TIME
		_reveal_left = REVEAL_SECONDS
		state = "reveal"
		return
	_wander(delta)


## Where its eyes are, from the Head bone in the rest pose (skeleton space, cm).
const EYES_FROM_HEAD := Vector3(0.0, 9.0, 9.5)


func _build_body() -> void:
	_build_person(false)
	if _model != null:
		# The head leans a little too far, and the eyes are waiting for their cue.
		tweak_bone("Head", Vector3(0, 0, 1), deg_to_rad(16.0))
		var face := bone_anchor("Head", bone_rest("Head") + EYES_FROM_HEAD)
		if face != null:
			for side: float in [-1.0, 1.0]:
				var eye := part(sphere(0.022), Color(1, 0.15, 0.1), Vector3.ZERO, 4.0)
				eye.reparent(face, false)
				eye.position = Vector3(side * 0.033, 0, 0)
				eye.visible = false
				_eyes.append(eye)
		return
	# The head and cap lean a little too far.
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).position.y > 1.7:
			(child as MeshInstance3D).rotation_degrees.z = 14.0
	for side: float in [-1.0, 1.0]:
		var eye := part(sphere(0.025), Color(1, 0.15, 0.1), Vector3(side * 0.06, 1.8, -0.14), 4.0)
		eye.visible = false
		_eyes.append(eye)


## After a lockdown it goes back to mopping (and acting), with a rest before it reveals again.
func _after_lockdown(before: String) -> void:
	if before == "reveal":
		_target = null
		_reveal_left = 0.0
		_chase_left = 0.0
		_cooldown = REVEAL_COOLDOWN
	super(before)


func _on_state_changed(new_state: String) -> void:
	for eye in _eyes:
		eye.visible = new_state == "reveal"
	if new_state == "reveal":
		# A wet, wrong gurgle as it drops the act.
		var voice := Sfx.play_at(self, SoundBank.get_sound("wet_voice", Sfx.notes([140.0, 120.0, 96.0, 80.0], 0.18, 0.5, "saw")), 4.0, 30.0)
		if voice:
			voice.pitch_scale = 0.6


## Passes for the real thing (see Monster.disguised).
func disguised() -> bool:
	return state != "reveal"
