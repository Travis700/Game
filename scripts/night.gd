class_name Night
extends Node
## One night shift, midnight to 6 AM: the clock, when anomalies appear, checking clipboard logs,
## the morning clock-out, and each guard's pay.
##
## The host runs the clock and the scoring and tells everyone else; other computers just keep
## their clock ticking between the host's updates.

const SHIFT_MINUTES := 360.0
## Real seconds per in-game minute: 2.0 makes a night last 12 minutes.
const SECONDS_PER_MINUTE := 2.0
## After 6 AM, guards have this long (real seconds) to clock out.
const CLOCK_OUT_SECONDS := 90.0

const SURVIVAL_PAY := 100
const CORRECT_LOG_POINTS := 25
const FALSE_REPORT_POINTS := 10
const DEATH_PENALTY := 50

var shift: Shift
var lighting: ShiftLighting
var anomalies: Anomalies
var cameras: SecurityCameras
var hud: CanvasLayer
var clipboard: CanvasLayer
var report: CanvasLayer
var players: Node3D

var number := 1
var minutes := 0.0
var seconds_per_minute := SECONDS_PER_MINUTE

# Host only.
var _schedule: Array[float] = []
var _stats: Dictionary = {}
var _totals: Dictionary = {}
var _deaths := 0
var _clock_out_left := 0.0
var _sync_timer := 0.0


func _ready() -> void:
	shift.started.connect(_on_shift_started)
	report.next_night_requested.connect(_on_next_night_requested)
	clipboard.log_submitted.connect(_on_log_submitted)


func _process(delta: float) -> void:
	if shift.state == Shift.State.ON_SHIFT:
		minutes = minf(minutes + delta / seconds_per_minute, SHIFT_MINUTES)
		_show_time()
	if not multiplayer.is_server():
		return
	match shift.state:
		Shift.State.ON_SHIFT:
			_run_shift(delta)
		Shift.State.MORNING:
			_clock_out_left -= delta
			if _clock_out_left <= 0.0 or shift.everyone_clocked_out():
				_end_night()


## "2:05 AM"
static func format_time(game_minutes: float) -> String:
	var whole := int(game_minutes)
	var hour := whole / 60
	return "%d:%02d AM" % [12 if hour == 0 else hour, whole % 60]


func time_text() -> String:
	return format_time(minutes)


## Main calls this when a guard uses the time clock after midnight. Host only.
func use_time_clock(peer_id: int) -> String:
	match shift.state:
		Shift.State.ON_SHIFT:
			return "It's %s. You can clock out at 6 AM." % time_text()
		Shift.State.MORNING:
			var message := shift.clock_out(peer_id)
			if shift.everyone_clocked_out():
				_end_night.call_deferred()
			return message
	return "The shift is over."


# --- Host: running the night ---------------------------------------------------------

func _on_shift_started() -> void:
	minutes = 0.0
	clipboard.set_header("Night %d   ·   Westfield High School" % number)
	if not multiplayer.is_server():
		return
	_stats.clear()
	_deaths = 0
	# Spread tonight's anomalies across the night, starting about 20 minutes in.
	_schedule.clear()
	var count := 4 + number * 2
	for i in count:
		_schedule.append(randf_range(20.0, SHIFT_MINUTES - 40.0))
	_schedule.sort()


func _run_shift(delta: float) -> void:
	while not _schedule.is_empty() and minutes >= _schedule[0]:
		if anomalies.spawn_random(number, minutes):
			_schedule.pop_front()
		else:
			# Nothing could appear right now (a guard nearby, or too many already). Try again soon.
			_schedule[0] = minutes + 5.0
			break
	anomalies.update(minutes)

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 5.0
		_sync_clock.rpc(minutes, seconds_per_minute)

	if minutes >= SHIFT_MINUTES:
		_start_morning.rpc()


func _on_log_submitted(area: String, type: String) -> void:
	clipboard.add_entry(time_text(), area, type)
	hud.show_message("Logged: %s, %s." % [area, type.to_lower()])
	if multiplayer.is_server():
		_receive_log(area, type)
	else:
		_receive_log.rpc_id(1, area, type)


@rpc("any_peer", "call_remote", "reliable")
func _receive_log(area: String, type: String) -> void:
	if not multiplayer.is_server():
		return
	if shift.state != Shift.State.ON_SHIFT and shift.state != Shift.State.MORNING:
		return
	var peer := _sender()
	var stats: Dictionary = _stats.get_or_add(peer, {"correct": 0, "false": 0})
	if anomalies.check_log(peer, area, type, minutes):
		stats["correct"] += 1
	else:
		stats["false"] += 1


func _end_night() -> void:
	if shift.state != Shift.State.MORNING:
		return
	var rows: Array = []
	for guard: Guard in players.get_children():
		var peer := guard.name.to_int()
		var stats: Dictionary = _stats.get(peer, {"correct": 0, "false": 0})
		var clocked_out := shift.has_clocked_out(peer)
		var correct_points: int = stats["correct"] * CORRECT_LOG_POINTS
		var false_points: int = stats["false"] * FALSE_REPORT_POINTS
		var pay: int = (SURVIVAL_PAY if clocked_out else 0) + correct_points - false_points - _deaths * DEATH_PENALTY
		_totals[peer] = _totals.get(peer, 0) + pay
		rows.append({
			"name": "Guard %d" % guard.slot, "clocked_out": clocked_out,
			"correct": stats["correct"], "correct_points": correct_points,
			"false": stats["false"], "false_points": false_points,
			"pay": pay, "total": _totals[peer],
		})
	var appeared := anomalies.appeared_count()
	var missed := anomalies.missed_count()
	var summary := "%d anomal%s tonight, %d missed by everyone.   Guards lost: %d." % [
		appeared, "y" if appeared == 1 else "ies", missed, _deaths]
	summary += "\nPay: %d for clocking out, +%d per correct log, -%d per false report, -%d for each guard lost." % [
		SURVIVAL_PAY, CORRECT_LOG_POINTS, FALSE_REPORT_POINTS, DEATH_PENALTY]
	_show_report.rpc(number, rows, summary)


func _on_next_night_requested() -> void:
	if multiplayer.is_server():
		anomalies.reset_all()
		_begin_next_night.rpc(number + 1)


# --- Every computer --------------------------------------------------------------------

@rpc("authority", "call_remote", "unreliable_ordered")
func _sync_clock(host_minutes: float, host_seconds_per_minute: float) -> void:
	minutes = host_minutes
	seconds_per_minute = host_seconds_per_minute


@rpc("authority", "call_local", "reliable")
func _start_morning() -> void:
	minutes = SHIFT_MINUTES
	_show_time()
	_clock_out_left = CLOCK_OUT_SECONDS
	shift.start_morning()
	lighting.go_bright()
	hud.show_message("It's 6 AM. Clock out at the time clock in the guard room to get paid.")


@rpc("authority", "call_local", "reliable")
func _show_report(night: int, rows: Array, summary: String) -> void:
	shift.state = Shift.State.REPORT
	clipboard.close()
	get_tree().call_group("game", "on_report")
	hud.set_clock("")
	report.show_report(night, rows, summary, multiplayer.is_server())


@rpc("authority", "call_local", "reliable")
func _begin_next_night(next_number: int) -> void:
	number = next_number
	minutes = 0.0
	shift.reset()
	clipboard.clear_entries()
	report.hide_report()
	hud.set_clock("")
	cameras.set_time("")
	get_tree().call_group("game", "on_next_night")


func _show_time() -> void:
	var text := time_text()
	hud.set_clock("NIGHT %d   ·   %s" % [number, text])
	cameras.set_time(text)


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
