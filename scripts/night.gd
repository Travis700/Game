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
## Survive this night and the run is won.
const LAST_NIGHT := 9
## The highest difficulty: the main building plus both wings.
const MAX_DIFFICULTY := 3

var shift: Shift
var lighting: ShiftLighting
var anomalies: Anomalies
var cameras: SecurityCameras
var hud: CanvasLayer
var clipboard: CanvasLayer
var report: CanvasLayer
var players: Node3D
var director: MonsterDirector
var totems: Totems
var shop: Shop
var guard_room: GuardRoom
var doors: GuardRoomDoors

var number := 1
## Tonight's map size (1-3), sent by the host when the night starts. 0 before the first night.
var difficulty := 0
## Host: the difficulty picked on the menu (0 = auto, one level per guard).
var difficulty_choice := 0
## Host: upgrades and carried items survive the whole team being caught.
var keep_gear := false
## Host: points and carried items from the saved run, by badge number (as text).
var saved_points: Dictionary = {}
var saved_items: Dictionary = {}
## Host: badges of guards who fitted the heavy-duty flashlight in the saved run.
var saved_bright: Array = []
var minutes := 0.0
var seconds_per_minute := SECONDS_PER_MINUTE

# Host only.
var _schedule: Array[float] = []
var _stats: Dictionary = {}
var _totals: Dictionary = {}
var _deaths := 0
var _restart_run := false
var _won := false
## Host: each guard's correct logs tonight, as "area|type", so logging the same thing again
## isn't counted as a false report.
var _logged: Dictionary = {}
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
			var message := "It's %s. You can clock out at 6 AM." % time_text()
			if director.ghost_active:
				message += "\nTonight's clock-ins show one name too many: employee #0451, R. Hale. Nobody by that name works here."
			return message
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
	_logged.clear()
	_deaths = 0
	save_run(number, true)
	director.plan_night(number)
	totems.place_random()
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
	director.update(minutes, delta)
	shop.update(delta)
	doors.update(delta)

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 5.0
		_sync_clock.rpc(minutes, seconds_per_minute)

	if minutes >= SHIFT_MINUTES:
		# Morning: the monsters are gone, and only the living have to clock out.
		director.end_night()
		totems.clear_all()
		shop.clear_placed()
		shift.guards_required = director.living_guards().size()
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
	var entry := "%s|%s" % [area, type]
	var logged: Array = _logged.get_or_add(peer, [])
	var correct := director.check_log(peer, area) if type == "Monster" else anomalies.check_log(peer, area, type, minutes)
	if not correct and type == "Missing object":
		# The Mascot's empty stand really is a missing object.
		correct = director.check_mascot_missing(peer, area)
	if correct:
		stats["correct"] += 1
		logged.append(entry)
	elif entry in logged:
		# Already logged and paid for; a repeat isn't a false report.
		director.tell(peer, "You've already logged that one.")
	else:
		stats["false"] += 1


## Host: tonight's difficulty, from the menu choice or the number of guards.
func pick_difficulty() -> int:
	if difficulty_choice > 0:
		return clampi(difficulty_choice, 1, MAX_DIFFICULTY)
	return clampi(players.get_child_count(), 1, MAX_DIFFICULTY)


## Host: a guard just spawned. Gives back what they had in the saved run.
func restore_guard(peer_id: int, badge: int) -> void:
	var key := str(badge)
	if saved_points.has(key):
		_totals[peer_id] = int(saved_points[key])
		shop.send_wallet(peer_id)
	if saved_items.has(key):
		shop.give(peer_id, str(saved_items[key]))
	if key in saved_bright:
		shop.set_bright(peer_id, true)


## Host: a guard's player left. Their points, item and flashlight are kept by badge, and
## dropped from this session, so rejoining gives back exactly what they had.
func remember_guard(guard: Guard) -> void:
	var peer := guard.name.to_int()
	var key := str(guard.employee_number)
	saved_points[key] = points_of(peer)
	var item := shop.held_by(peer)
	if item != "":
		saved_items[key] = item
	else:
		saved_items.erase(key)
	if shop.has_bright(peer) and key not in saved_bright:
		saved_bright.append(key)
	_totals.erase(peer)
	shop.forget(peer)


## Host: writes the run to disk so it can be continued, with `next_night` up next.
## `in_progress` marks a save made as a night starts (the night isn't finished yet).
func save_run(next_night: int, in_progress := false) -> void:
	for guard: Guard in players.get_children():
		var key := str(guard.employee_number)
		var peer := guard.name.to_int()
		saved_points[key] = points_of(peer)
		var item := shop.held_by(peer)
		if item != "":
			saved_items[key] = item
		else:
			saved_items.erase(key)
		if shop.has_bright(peer) and key not in saved_bright:
			saved_bright.append(key)
	RunSave.write({
		"night": next_night, "difficulty": difficulty_choice, "keep_gear": keep_gear,
		"points": saved_points, "items": saved_items, "upgrades": guard_room.upgraded.duplicate(),
		"doors": doors.installed.duplicate(), "bright": saved_bright, "in_progress": in_progress,
	})


## Host: a guard's banked points.
func points_of(peer_id: int) -> int:
	return _totals.get(peer_id, 0)


## Host: spends a guard's points at the vending machine.
func spend(peer_id: int, amount: int) -> void:
	_totals[peer_id] = points_of(peer_id) - amount


## Host, for testing: gives everyone points to spend.
func give_everyone(amount: int) -> void:
	for guard: Guard in players.get_children():
		_totals[guard.name.to_int()] = points_of(guard.name.to_int()) + amount
	shop.push_wallets()


## Host: a guard did something worth a correct log's pay (e.g. walking a real student out).
func add_bonus(peer_id: int) -> void:
	var stats: Dictionary = _stats.get_or_add(peer_id, {"correct": 0, "false": 0})
	stats["correct"] += 1


## Host: a guard was caught tonight.
func record_death() -> void:
	_deaths += 1


## Host: a guard was revived at a totem, so their death doesn't cost anyone.
func record_revive() -> void:
	_deaths = maxi(_deaths - 1, 0)


## Host: the whole team has been caught. The run starts over from night 1.
func fail_night() -> void:
	if shift.state != Shift.State.ON_SHIFT:
		return
	director.end_night()
	totems.clear_all()
	shop.clear_placed()
	_restart_run = true
	var rows := _build_rows(false)
	var summary := "The whole team was caught at %s.\nThe school keeps its secrets. The run starts over from night 1." % time_text()
	if keep_gear:
		summary += "\nYou keep your upgrades and whatever you're carrying. Points start again from zero."
	else:
		shop.reset_all()
		guard_room.reset_upgrades()
		doors.reset_all()
		saved_items.clear()
		saved_bright.clear()
	# Everyone's points are gone, including guards who aren't here tonight.
	saved_points.clear()
	_show_report.rpc(number, rows, summary, "caught")
	save_run(1)


func _end_night() -> void:
	if shift.state != Shift.State.MORNING:
		return
	var rows := _build_rows(true)
	var appeared := anomalies.appeared_count()
	var missed := anomalies.missed_count()
	var summary := "%d anomal%s tonight, %d missed by everyone.   Guards lost: %d." % [
		appeared, "y" if appeared == 1 else "ies", missed, _deaths]
	summary += "\nPay: %d for clocking out, +%d per correct log, -%d per false report, -%d for each guard lost." % [
		SURVIVAL_PAY, CORRECT_LOG_POINTS, FALSE_REPORT_POINTS, DEATH_PENALTY]
	if number >= LAST_NIGHT:
		_won = true
		_restart_run = true
		var team_total := 0
		for guard: Guard in players.get_children():
			team_total += points_of(guard.name.to_int())
		summary = "You kept Westfield High safe for all %d nights. Whatever lives here will wait for the next crew.\nFinal team score: %d points.\n" % [LAST_NIGHT, team_total] + summary
		_show_report.rpc(number, rows, summary, "won")
		# The next run starts fresh.
		shop.reset_all()
		guard_room.reset_upgrades()
		doors.reset_all()
		RunSave.clear()
		saved_points.clear()
		saved_items.clear()
		saved_bright.clear()
		return
	_show_report.rpc(number, rows, summary, "night")
	shop.push_wallets()
	save_run(number + 1)


## One row per guard for the report. `keep_pay` is false when the run is starting over.
func _build_rows(keep_pay: bool) -> Array:
	var rows: Array = []
	for guard: Guard in players.get_children():
		var peer := guard.name.to_int()
		var stats: Dictionary = _stats.get(peer, {"correct": 0, "false": 0})
		var clocked_out := shift.has_clocked_out(peer)
		var correct_points: int = stats["correct"] * CORRECT_LOG_POINTS
		var false_points: int = stats["false"] * FALSE_REPORT_POINTS
		var pay: int = (SURVIVAL_PAY if clocked_out else 0) + correct_points - false_points - _deaths * DEATH_PENALTY
		if keep_pay:
			# Points never go below zero.
			_totals[peer] = maxi(_totals.get(peer, 0) + pay, 0)
		else:
			_totals[peer] = 0
		rows.append({
			"name": "Guard %d  #%04d" % [guard.slot, guard.employee_number], "clocked_out": clocked_out, "died": guard.is_dead,
			"correct": stats["correct"], "correct_points": correct_points,
			"false": stats["false"], "false_points": false_points,
			"pay": pay, "total": _totals[peer], "lost": not keep_pay,
		})
	return rows


func _on_next_night_requested() -> void:
	if multiplayer.is_server():
		anomalies.reset_all()
		doors.reset_for_night()
		var next := 1 if _restart_run else number + 1
		if _won:
			for guard: Guard in players.get_children():
				_totals[guard.name.to_int()] = 0
			shop.push_wallets()
		_restart_run = false
		_won = false
		_begin_next_night.rpc(next)


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
func _show_report(night: int, rows: Array, summary: String, outcome: String) -> void:
	shift.state = Shift.State.REPORT
	clipboard.close()
	get_tree().call_group("game", "on_report")
	hud.set_clock("")
	report.show_report(night, rows, summary, multiplayer.is_server(), outcome)


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
