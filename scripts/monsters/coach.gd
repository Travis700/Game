class_name Coach
extends Monster
## The Coach: a whistle, a clipboard and a tracksuit, pacing the locker rooms and the east hall.
## It can't stand a slacker. When it sees a guard it blows its whistle: "HUSTLE!" From then
## until they're out of its sight, that guard had better be running. Walk or stand still where
## it can see you and it comes for you. The opposite of the Hall Monitor.

const PACE_SPEED := 1.7
const CHASE_SPEED := 4.4
const SIGHT_RANGE := 18.0
## Seconds of grace after the whistle before it checks you're running.
const GRACE_SECONDS := 1.0
## Below this speed (m/s) counts as slacking.
const HUSTLE_SPEED := 4.2
const GIVE_UP_AFTER := 4.0
## Run for this long after the whistle and it's satisfied ("Good hustle!"), even if you can't
## get out of its sight before you're winded.
const HUSTLE_SECONDS := 5.0
## How long below hustle speed before it counts as slacking.
const SLACK_SECONDS := 0.4
const SPOTS: Array[Vector3] = [Vector3(45, 0, 15), Vector3(66, 0, 15), Vector3(76, 0, 15), Vector3(55, 0, 7), Vector3(72, 0, 7)]

var _target: Guard
var _watching: Guard
var _grace := 0.0
var _slacking := 0.0
## How long (real seconds) a guard who hustled well is left alone before it'll whistle again.
const WELL_DONE_SECONDS := 30.0

## The guards it's already blown the whistle at (by name), and when (real seconds) it may
## whistle at them again: INF while it's still watching them run.
var _whistled: Dictionary = {}
var _hustled := 0.0


func _init() -> void:
	display_name = "the Coach"
	# It chases guards who won't run: duck into a cupboard under its nose and it looks.
	searches_cupboards = true
	state = "pace"


func think(delta: float) -> void:
	if state == "chase":
		if not chase(_target, CHASE_SPEED, delta, GIVE_UP_AFTER):
			if is_instance_valid(_target):
				_whistled.erase(_target.name)
			_target = null
			state = "pace"
		return
	patrol_step(SPOTS, delta, PACE_SPEED, Vector2(1.0, 3.0))
	if _watching:
		if not is_instance_valid(_watching) or _watching.is_dead or _watching.hiding \
				or distance_to_guard(_watching) > SIGHT_RANGE * senses * director.nerve_reach(_watching) \
				or not director.can_see(eye_position(), _watching):
			# Out of its sight: off the hook (until it spots them again).
			if is_instance_valid(_watching):
				_whistled.erase(_watching.name)
			_watching = null
			state = "pace"
			return
		face(_watching.global_position - global_position)
		_grace -= delta
		_hustled = _hustled + delta if director.guard_speed(_watching) >= HUSTLE_SPEED else _hustled
		if _hustled >= HUSTLE_SECONDS:
			director.tell(_watching.name.to_int(), "\"GOOD HUSTLE, Guard %d!\" The whistle stops." % _watching.slot)
			# Left alone for a while, then fair game again.
			_whistled[_watching.name] = _now() + WELL_DONE_SECONDS
			_watching = null
			state = "pace"
			return
		# A moment of slacking, not a single slow reading.
		# (Standing still for the Crossing Guard's sign doesn't count: one rule at a time.)
		_slacking = _slacking + delta if director.guard_speed(_watching) < HUSTLE_SPEED and not director.stop_sign_up_for(_watching) else 0.0
		if _grace <= 0.0 and _slacking > SLACK_SECONDS:
			director.tell(_watching.name.to_int(), "\"DID I SAY STOP?\"")
			_target = _watching
			_watching = null
			start_chase()
			state = "chase"
		return
	var now := _now()
	var guard := find_guard(SIGHT_RANGE, true, func(someone: Guard) -> bool: return now >= float(_whistled.get(someone.name, 0.0)))
	if guard:
		_watching = guard
		_whistled[guard.name] = INF
		_grace = GRACE_SECONDS
		_slacking = 0.0
		state = "whistle"
		_hustled = 0.0
		director.tell(guard.name.to_int(), "A whistle. \"HUSTLE, Guard %d! Laps! Until I can't see you!\"" % guard.slot)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## After a lockdown it starts pacing again, with nobody on laps and nobody in trouble.
func _after_lockdown(before: String) -> void:
	_target = null
	_watching = null
	_whistled.clear()
	super(before)
	if state == "whistle":
		state = "pace"


func _on_state_changed(new_state: String) -> void:
	if new_state == "whistle":
		SoundBank.play_at(self, "whistle_coach", 3.0, 45.0, Sfx.notes([2600.0, 2600.0, 0.0, 2600.0], 0.15, 0.35, "square"))
	elif new_state == "chase":
		SoundBank.play_at(self, "whistle_coach", 4.0, 45.0, Sfx.notes([2600.0, 2900.0, 2600.0, 2900.0, 2600.0], 0.08, 0.35, "square"))


func _build_body() -> void:
	if use_model("coach", 1.85):
		return
	var tracksuit := Color(0.12, 0.22, 0.5)
	part(capsule(0.3, 1.85), tracksuit, Vector3(0, 0.92, 0))
	part(box(Vector3(0.62, 0.1, 0.4)), Color(0.95, 0.95, 0.95), Vector3(0, 1.3, 0))
	part(sphere(0.15), Color(0.72, 0.58, 0.48), Vector3(0, 1.98, 0))
	part(box(Vector3(0.34, 0.08, 0.36)), Color(0.85, 0.15, 0.1), Vector3(0, 2.1, -0.04))
	part(box(Vector3(0.24, 0.04, 0.14)), Color(0.85, 0.15, 0.1), Vector3(0, 2.07, -0.22))
	part(box(Vector3(0.04, 0.04, 0.06)), Color(0.85, 0.85, 0.2), Vector3(0, 1.85, -0.18), 0.5)
	part(box(Vector3(0.26, 0.34, 0.02)), Color(0.45, 0.3, 0.15), Vector3(0.28, 1.15, -0.2))
