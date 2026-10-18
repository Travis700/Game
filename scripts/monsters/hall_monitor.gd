class_name HallMonitor
extends Monster
## The Hall Monitor: a tall, thin figure with a sash and a clipboard of its own.
## It walks the main hallway end to end. It leaves walkers alone, but if it sees a guard
## running, or hears one talking loudly ("No talking in the halls!"), it blows its whistle and
## chases them until it loses sight of them.

const PATROL_SPEED := 1.5
const CHASE_SPEED := 4.3
const SIGHT_RANGE := 22.0
## Only loud talking bothers it (quiet voices are fine): how loud, and how far it carries.
const LOUD_VOICE := 0.45
const HEAR_SHOUT := 16.0
## Seconds without seeing its target before it gives up the chase.
const GIVE_UP_AFTER := 4.0
const HALL_ENDS: Array[Vector3] = [Vector3(-36, 0, 7), Vector3(36, 0, 7)]

var _target: Guard
var _whistle: AudioStream


func _init() -> void:
	display_name = "the Hall Monitor"
	# It chases runners by sight: hide while it can still see you and it checks the cupboard.
	searches_cupboards = true
	state = "patrol"


func think(delta: float) -> void:
	if _target:
		if not chase(_target, CHASE_SPEED, delta, GIVE_UP_AFTER):
			_target = null
			state = "patrol"
		return
	# Noise in the halls: it goes to check.
	var noise := director.noise_near(global_position, 25.0)
	if noise != Vector3.INF:
		move_to(noise, PATROL_SPEED * 2.0)
	else:
		patrol_step(HALL_ENDS, delta, PATROL_SPEED, Vector2.ZERO)
	# Not one the Coach is making run: the hallway has two sets of rules, and that one wins.
	var runner := find_guard(SIGHT_RANGE, true, func(guard: Guard) -> bool: return guard.is_running and not director.coached(guard))
	if runner == null:
		runner = find_guard(HEAR_SHOUT, false, func(guard: Guard) -> bool:
			return director.voice_level(guard) > LOUD_VOICE and distance_to_guard(guard) < director.voice_reach(guard, 0.0, HEAR_SHOUT))
	if runner:
		_target = runner
		start_chase()
		state = "chase"


## After a lockdown it goes back to its rounds, not to the runner it was after (and no whistle).
func _after_lockdown(before: String) -> void:
	_target = null
	super(before)


func _on_state_changed(new_state: String) -> void:
	if new_state == "chase":
		if _whistle == null:
			_whistle = Sfx.notes([2400.0, 0.0, 2400.0, 2900.0], 0.12, 0.3, "square")
		SoundBank.play_at(self, "whistle_monitor", 2.0, 45.0, _whistle)


func _build_body() -> void:
	# Head and shoulders above anyone, but still under the door frames (2.4 m).
	if use_model("hall_monitor", 2.35):
		return
	part(capsule(0.22, 2.0), Color(0.16, 0.16, 0.18), Vector3(0, 1.0, 0))
	part(sphere(0.14), Color(0.72, 0.69, 0.62), Vector3(0, 2.14, 0))
	part(box(Vector3(0.24, 0.05, 0.02)), Color(0.02, 0.02, 0.02), Vector3(0, 2.16, -0.13))
	var sash := part(box(Vector3(0.08, 0.95, 0.47)), Color(0.95, 0.5, 0.1), Vector3(0, 1.4, 0), 0.6)
	sash.rotation_degrees.z = 35.0
	part(box(Vector3(0.26, 0.34, 0.02)), Color(0.45, 0.3, 0.15), Vector3(0.24, 1.2, -0.2))
