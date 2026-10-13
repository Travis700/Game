class_name Shift
extends Node
## Tracks the night shift. Before the shift the school is lit up and safe;
## once enough guards have clocked in, the night starts.

signal started

enum State { PRE_SHIFT, ON_SHIFT }

var state := State.PRE_SHIFT
## How many guards must clock in before the night starts.
## Multiplayer will set this to the number of players in the session.
var guards_required := 1

var _clocked_in: Array[Node] = []


## Clocks a guard in and returns the message to show them.
func clock_in(guard: Node) -> String:
	if guard in _clocked_in:
		return "You're already clocked in." if state == State.ON_SHIFT else "You're clocked in. Waiting for the rest of the team."
	_clocked_in.append(guard)
	var waiting_for := guards_required - _clocked_in.size()
	if waiting_for > 0:
		return "Clocked in. Waiting for %d more guard%s." % [waiting_for, "" if waiting_for == 1 else "s"]
	state = State.ON_SHIFT
	started.emit()
	return "Clocked in at 11:59 PM. The building is yours until 6."
