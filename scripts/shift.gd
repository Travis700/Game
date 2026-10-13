class_name Shift
extends Node
## Tracks the night shift. Before the shift the school is lit up and safe;
## once every guard has clocked in, the night starts.
##
## In multiplayer only the host keeps the clock-in list. The host tells everyone
## when the night starts (see Main._start_night).

signal started

enum State { PRE_SHIFT, ON_SHIFT }

var state := State.PRE_SHIFT
## How many guards must clock in before the night starts: everyone in the session.
var guards_required := 1

var _clocked_in: Array[int] = []


## Clocks in the guard controlled by `peer_id` and returns the message to show them.
func clock_in(peer_id: int) -> String:
	if peer_id in _clocked_in:
		return "You're already clocked in." if state == State.ON_SHIFT else "You're clocked in. Waiting for the rest of the team."
	_clocked_in.append(peer_id)
	if everyone_clocked_in():
		return "Clocked in at 11:59 PM. The building is yours until 6."
	var waiting_for := guards_required - _clocked_in.size()
	return "Clocked in. Waiting for %d more guard%s." % [waiting_for, "" if waiting_for == 1 else "s"]


## Forgets a guard who left the session.
func remove_guard(peer_id: int) -> void:
	_clocked_in.erase(peer_id)


func everyone_clocked_in() -> bool:
	return _clocked_in.size() >= guards_required and guards_required > 0


func clocked_in_count() -> int:
	return _clocked_in.size()


## Starts the night. Called on every computer at once.
func begin() -> void:
	if state == State.ON_SHIFT:
		return
	state = State.ON_SHIFT
	started.emit()
