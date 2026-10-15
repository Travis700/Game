class_name Training
extends Node
## The training shift: a short, guided night for new guards. One step at a time, shown under
## the clock: watch the cameras, log something, punch a station, reset the breaker, hide.
## Nothing here can hurt you except the Hall Monitor at the end, and only if you run at it.
## Solo only; it never touches the saved run.

## The anomaly to log (the lobby bench, moved) and the station to punch (Main Hall East).
const ANOMALY := 1
const STATION := 3
## Real seconds to stay hidden while the Hall Monitor goes past.
const HIDE_SECONDS := 8.0

const STEPS := [
	"Training 1/7: sit at a desk in the guard room ({use} on a chair) to watch the cameras. {left} / {right} changes a monitor's camera.",
	"Training 2/7: something in the Lobby has moved: the bench. Press {clip}, pick Lobby and Moved object, and log it.",
	"Training 3/7: every night has a round. Go and punch the station in the Main Hall East (amber lamp): hold {use} on it.",
	"Training 4/7: the power's out. Reset the breaker in the custodian's closet, across the hall from the lobby: hold {use} on it.",
	"Training 5/7: something's coming down the hall. Hide in a cupboard: there's one at each end of the main hallway ({use}).",
	"Training 6/7: stay hidden until it's gone past... (Hiding wears on your nerve, bottom left; the lit guard room brings it back.)",
	"Training 7/7: that was the Hall Monitor, a monster. Log it: {clip}, pick the area it's in (Main Hall West or East: watch the cameras or peek out), and Monster.",
]

var night: Night
var guard: Guard
var hud: CanvasLayer

var step := -1
var objective := ""
var _hidden_for := 0.0
var _finished := false


## The shift has started: no monsters, no conditions, a frozen clock, and the first step.
func begin() -> void:
	night.seconds_per_minute = 100000.0
	night.director.tonight.clear()
	night.rounds._set_state.rpc(PackedInt32Array(), PackedInt32Array(), false)
	_go(0)


func _process(delta: float) -> void:
	if guard == null and get_parent().get("_local_guard"):
		guard = get_parent().get("_local_guard")
	if step < 0 or _finished or guard == null or not is_instance_valid(guard):
		return
	match step:
		0:
			if guard.seated_desk >= 0:
				_go(1)
		1:
			if int(night._stats.get(1, {}).get("correct", 0)) >= 1:
				_go(2)
		2:
			if night.rounds.is_complete():
				_go(3)
		3:
			if night.power.on:
				_go(4)
		4:
			if guard.hiding:
				_go(5)
		5:
			_hidden_for += delta
			if _hidden_for >= HIDE_SECONDS:
				_go(6)
		6:
			if night.director._logged_tonight.has("HallMonitor"):
				_finish()


func _go(next: int) -> void:
	step = next
	# (Controls is an autoload, looked up by path from a class_name script.)
	var controls := get_node_or_null("/root/Controls")
	var key := func(action: String, fallback: String) -> String:
		return controls.key_name(action) if controls else fallback
	objective = (STEPS[step] as String).format({"use": key.call("interact", "E"), "clip": key.call("clipboard", "Tab"),
			"left": key.call("move_left", "A"), "right": key.call("move_right", "D")})
	match step:
		1:
			night.anomalies.start(ANOMALY, night.minutes)
		2:
			night.rounds._set_state.rpc(PackedInt32Array([STATION]), PackedInt32Array(), true)
		3:
			night.power.cut()
		4:
			# At the far end of the hall from the guard, and only for show: it can't hurt anyone.
			var x := 36.0 if guard == null or guard.global_position.x < 0.0 else -36.0
			night.director.spawn("hall_monitor", Vector3(x, 0, 7))
			for monster in night.director.get_node("Live").get_children():
				(monster as Monster).harmless = true
				(monster as Monster).practice = true
	if step > 0:
		Sfx.play_flat(self, Sfx.notes([660.0, 990.0], 0.08, 0.2, "sine"))
		# A beat later, so whatever just happened (a log's ✓) is read first. The step itself is
		# already under the clock.
		get_tree().create_timer(1.5).timeout.connect(func() -> void: hud.show_message("Step done.", 2.0))


func _finish() -> void:
	_finished = true
	objective = ""
	if night.career:
		night.career._unlock("TRAINED")
	var profile := get_node_or_null("/root/Profile")
	if profile:
		profile.set("training_done", true)
		profile.save_settings()
	night.director.end_night()
	night.power.end_night()
	night.hiding.release_all()
	night._show_report.rpc(0, [], "That's the job. From here on, nights bring monsters, and every one has its own rules: watch the cameras, read the messages, and check your field guide (the button on your clipboard) once you've logged one.\n\nThe guard room is safe until night 7. Good luck.", "training")
