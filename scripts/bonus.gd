class_name Bonus
extends Node
## Tonight's bonus objective: one challenge for the whole team, shown under the clock. Pull it
## off by 6 AM and everyone who clocks out gets extra pay and XP. Some can be failed
## partway through ("Guard 2 ran"), and then it's gone for the night.
##
## The host keeps track and tells everyone how it's going.

const POINTS := 60
const XP := 50
## Running means moving faster than this (m/s) for this long (seconds).
const RUN_SPEED := 4.6
const RUN_SECONDS := 0.6
## Shouting: voice level (0-1) above this.
const SHOUT := 0.6
## The round has to be finished by this time (in-game minutes after midnight: 3 AM).
const ROUND_BY := 180.0

const KINDS := ["no_running", "quiet", "logs", "name", "early_round", "nobody_caught"]

var director: MonsterDirector
var rounds: Rounds

## On every computer: the line shown under the clock, e.g. "Bonus: nobody runs (so far, so good)".
var status := ""

# Host only.
var kind := ""
var failed := false
var _goal := 0
var _logs := 0
var _named := 0
var _round_done_at := -1.0
var _running_for: Dictionary = {}


## Host: picks tonight's objective.
func pick(night_number: int) -> void:
	kind = KINDS.pick_random()
	if kind == "early_round" and rounds.order.is_empty():
		kind = "logs"
	failed = false
	_logs = 0
	_named = 0
	_round_done_at = -1.0
	_running_for.clear()
	_goal = 3 + int(night_number / 2.0)
	_send()


## Host: every frame of the shift.
func update(minutes: float, delta: float) -> void:
	if kind == "" or failed:
		return
	match kind:
		"no_running":
			for guard in director.living_guards():
				var key := guard.name
				_running_for[key] = (float(_running_for.get(key, 0.0)) + delta) if director.guard_speed(guard) > RUN_SPEED else 0.0
				if _running_for[key] > RUN_SECONDS:
					_fail("%s ran." % _who(guard))
					return
		"quiet":
			for guard in director.living_guards():
				if director.voice_level(guard) > SHOUT:
					_fail("%s raised their voice." % _who(guard))
					return
		"early_round":
			if _round_done_at < 0.0 and rounds.is_complete():
				_round_done_at = minutes
				_send()
			elif _round_done_at < 0.0 and minutes > ROUND_BY:
				_fail("It's past 3 AM.")


## Host: a correct log (and whether the monster was named).
func on_correct_log(named: bool) -> void:
	_logs += 1
	if named:
		_named += 1
	if kind in ["logs", "name"]:
		_send()


## Host: a guard was caught.
func on_caught(guard: Guard) -> void:
	if kind == "nobody_caught" and not failed:
		_fail("%s was caught." % _who(guard))


## Host, at 6 AM: did the team pull it off?
func achieved() -> bool:
	if kind == "" or failed:
		return false
	match kind:
		"logs":
			return _logs >= _goal
		"name":
			return _named >= 1
		"early_round":
			return _round_done_at >= 0.0
	return true


## For the report: "Bonus objective: nobody runs: done, +60 each." or "...: failed (Guard 2 ran)."
func summary() -> String:
	if kind == "":
		return ""
	return "Bonus objective: %s: %s" % [_title(), ("done, +%d each and +%d XP." % [POINTS, XP]) if achieved() else "missed."]


## Host: the night is over.
func clear() -> void:
	kind = ""
	_show.rpc("")


func _fail(why: String) -> void:
	failed = true
	_show.rpc("Bonus failed (%s): %s" % [_title(), why])
	for guard in director.living_guards():
		director.tell(guard.name.to_int(), "Bonus objective failed: %s" % why)


func _send() -> void:
	var progress := ""
	match kind:
		"logs":
			progress = " (%d / %d)" % [mini(_logs, _goal), _goal]
		"name":
			progress = " (done)" if _named > 0 else ""
		"early_round":
			progress = " (done)" if _round_done_at >= 0.0 else ""
	_show.rpc("Bonus +%d: %s%s" % [POINTS, _title(), progress])


func _title() -> String:
	match kind:
		"no_running":
			return "nobody runs all night"
		"quiet":
			return "nobody raises their voice"
		"logs":
			return "log %d thing%s correctly between you" % [_goal, "" if _goal == 1 else "s"]
		"name":
			return "name a monster correctly in a log"
		"early_round":
			return "finish the round before 3 AM"
		"nobody_caught":
			return "nobody gets caught"
	return ""


func _who(guard: Guard) -> String:
	return guard.player_name if guard.player_name != "" else "Guard %d" % guard.slot


@rpc("authority", "call_local", "reliable")
func _show(text: String) -> void:
	status = text
