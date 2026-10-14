class_name Shift
extends Node
## Tracks where the team is in the night:
## before the shift (clocking in), on shift (midnight to 6), morning (clocking out), and the report.
##
## In multiplayer only the host keeps the clock-in and clock-out lists. The host tells
## everyone when the state changes (see Main and Night).

signal started
signal morning_started

enum State { PRE_SHIFT, ON_SHIFT, MORNING, REPORT }

var state := State.PRE_SHIFT
## How many guards must clock in before the night starts: everyone in the session.
var guards_required := 1

var _clocked_in: Array[int] = []
var _clocked_out: Array[int] = []


## Clocks in the guard controlled by `peer_id` and returns the message to show them.
func clock_in(peer_id: int) -> String:
	if peer_id in _clocked_in:
		return "You're clocked in. Waiting for the rest of the team."
	_clocked_in.append(peer_id)
	if everyone_clocked_in():
		return "Clocked in at 11:59 PM. The building is yours until 6."
	var waiting_for := guards_required - _clocked_in.size()
	return "Clocked in. Waiting for %d more guard%s." % [waiting_for, "" if waiting_for == 1 else "s"]


## Clocks a guard out after 6 AM and returns the message to show them.
func clock_out(peer_id: int) -> String:
	if peer_id in _clocked_out:
		return "You've already clocked out."
	_clocked_out.append(peer_id)
	return "Clocked out. You made it through the night."


## Forgets a guard who left the session.
func remove_guard(peer_id: int) -> void:
	_clocked_in.erase(peer_id)
	_clocked_out.erase(peer_id)


func everyone_clocked_in() -> bool:
	return _clocked_in.size() >= guards_required and guards_required > 0


func everyone_clocked_out() -> bool:
	return _clocked_out.size() >= guards_required and guards_required > 0


func clocked_in_count() -> int:
	return _clocked_in.size()


func has_clocked_out(peer_id: int) -> bool:
	return peer_id in _clocked_out


## Starts the night. Called on every computer at once.
func begin() -> void:
	if state != State.PRE_SHIFT:
		return
	state = State.ON_SHIFT
	started.emit()


## 6 AM. Called on every computer at once.
func start_morning() -> void:
	state = State.MORNING
	morning_started.emit()


## Back to the start of an evening, for the next night.
func reset() -> void:
	state = State.PRE_SHIFT
	_clocked_in.clear()
	_clocked_out.clear()
