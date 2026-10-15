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
## A correct Monster log with the wrong name pays this much less.
const MISNAME_POINTS := 10
## Docked from a guard who ignored the Principal's summons.
const IGNORED_SUMMONS_POINTS := 40
## A teammate logging something someone else already logged: confirming it pays less.
const CONFIRM_POINTS := 10
## Extra pay for naming the monster in a correct Monster log.
const NAME_POINTS := 25
const FALSE_REPORT_POINTS := 10
const DEATH_PENALTY := 50
## XP (career progress, kept across runs) for a night: clocking out (plus a bit per night of the
## run), or just being there, and more for each correct log, named monster and punched station.
const XP_CLOCKED_OUT := 100
const XP_PER_NIGHT := 10
const XP_CAUGHT := 25
const XP_PER_LOG := 20
const XP_PER_NAME := 20
const XP_PER_PUNCH := 10
const XP_PER_WING := 0.25
## Survive this night and the run is won.
const LAST_NIGHT := 9
## Overtime: after the ninth night the host can keep going. This night earns "Workaholic".
const OVERTIME_GOAL := 15
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
var career: Career
var rounds: Rounds
var power: Power
var conditions: Conditions
var bonus: Bonus
var phone: Phone
var hiding: Hiding
var clutter: Clutter
var finale: Finale
var nerve: Nerve
## The date of the daily shift being played (see Daily), or "" for an ordinary run.
var daily := ""
## The training shift, when that's what's being played (see Training), or null.
var training: Training
## Emitted on the host when a daily shift's report is closed: back to the menu.
signal daily_finished

var number := 1
## Tonight's map size (1-3), sent by the host when the night starts. 0 before the first night.
var difficulty := 0
## Host: the difficulty picked on the menu (0 = auto, one level per guard).
var difficulty_choice := 0
## Host: upgrades and carried items survive the whole team being caught.
var keep_gear := false
## Host: Hardcore runs go back to night 1 with nothing when the team is caught; otherwise to the
## last checkpoint (nights 1, 4 and 7) with gear kept and points halved.
var hardcore := false
## The nightly work target (from night 2): the team has to earn this many points from real work
## (logs, naming, stations) per guard. Miss it and everyone gets a write-up; three and the
## district lets the team go (back to the last checkpoint, or night 1 on Hardcore).
const QUOTA_BASE := 30
const QUOTA_PER_NIGHT := 22
const WRITE_UPS_TO_FIRE := 3
var write_ups := 0
## Host: tonight's team target (0 = none tonight).
var quota_target := 0
## Every computer: "Work target: 85 / 160   ·   write-ups 1 of 3", or "".
var quota_text := ""
var _quota_timer := 0.0
## Host: where a run picks up after a wipe (0 = not restarting at a checkpoint).
var _restart_at := 0
## Host: points and carried items from the saved run, by badge number (as text).
var saved_points: Dictionary = {}
var saved_items: Dictionary = {}
## Host: personal upgrades (heavy-duty flashlight, walkie-talkie) by badge, from the saved run.
var saved_personal: Dictionary = {}
var minutes := 0.0
var seconds_per_minute := SECONDS_PER_MINUTE

# Host only.
var _schedule: Array[float] = []
var _stats: Dictionary = {}
var _totals: Dictionary = {}
var _deaths := 0
var _restart_run := false
var _won := false
## Host: the most guards on any night of this run (so "solo" means solo all the way). Saved.
var run_team := 0
## Host: each guard's correct logs tonight, as "area|type", so logging the same thing again
## isn't counted as a false report.
var _logged: Dictionary = {}
## Host: totals for the whole run so far, by guard name ("Sam" or "Guard 2"): logs, named,
## stations, caught. Shown when the run ends. And how many nights it has lasted.
var _run_stats: Dictionary = {}
var _run_nights := 0
## Host: everyone's nerve at 6 AM, for the Nerves of steel achievement.
var _morning_nerve: Dictionary = {}
var _clock_out_left := 0.0
var _sync_timer := 0.0


func _ready() -> void:
	shift.started.connect(_on_shift_started)
	report.next_night_requested.connect(_on_next_night_requested)
	report.overtime_requested.connect(_on_overtime_requested)
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
	run_team = maxi(run_team, players.get_child_count())
	_shift_team = players.get_child_count()
	_stats.clear()
	_logged.clear()
	_deaths = 0
	save_run(number, true)
	if training:
		training.begin()
		return
	if daily != "":
		# Everything planned from here on (monsters, conditions, round, bonus) is the same for
		# everyone playing today's shift.
		seed(Daily.seed_of(daily))
		conditions.forced = Daily.conditions_of(daily)
	conditions.pick(number)
	director.team_size = players.get_child_count()
	director.plan_night(number)
	finale.planned = number == LAST_NIGHT and daily == ""
	finale.difficulty = difficulty
	rounds.plan(number, difficulty)
	bonus.pick(number)
	nerve.reset()
	quota_target = 0 if number < 2 or daily != "" else quota_for(players.get_child_count())
	power.plan(number)
	phone.plan(number)
	# Totems only matter with teammates to bring back; alone, being caught ends the run.
	if players.get_child_count() > 1:
		totems.place_random()
	anomalies.plan(number)
	# Spread tonight's anomalies across the night, starting about 20 minutes in.
	_schedule.clear()
	# More guards, more to find.
	var count := 4 + number * 2 + 2 * (players.get_child_count() - 1)
	if conditions.has("messy"):
		count = int(count * 1.5)
	for i in count:
		_schedule.append(randf_range(20.0, SHIFT_MINUTES - 40.0))
	_schedule.sort()
	# Something to find early, so the first minutes of a shift aren't empty.
	if not _schedule.is_empty():
		_schedule[0] = minf(_schedule[0], 20.0 + randf() * 5.0)


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
	power.update(minutes)
	phone.update(minutes, delta)
	bonus.update(minutes, delta)
	nerve.update(delta)
	_quota_timer -= delta
	if _quota_timer <= 0.0:
		_quota_timer = 1.0
		_send_quota()
		var now := Time.get_ticks_msec() / 1000.0
		for guard in director.living_guards():
			var area := SchoolBuilder.area_at(guard.global_position)
			if area != "":
				(_visits.get_or_add(guard.name.to_int(), {}) as Dictionary)[area] = now
	shop.update(delta)
	doors.update(delta)
	finale.update(minutes)
	if finale.everyone_out() and minutes < SHIFT_MINUTES:
		# Everyone still standing got out: no need to wait for six.
		minutes = SHIFT_MINUTES

	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 5.0
		_sync_clock.rpc(minutes, seconds_per_minute)

	if minutes >= SHIFT_MINUTES:
		# The finale: the gate shuts on anyone still inside, and whoever got out is done.
		var got_out := finale.lock_in()
		finale.reset()
		# Morning: the monsters are gone, and only the living have to clock out.
		director.end_night()
		totems.clear_all()
		shop.clear_placed()
		rounds.close()
		power.end_night()
		phone.end_night()
		hiding.release_all()
		clutter.reset_all()
		# Morning: nerves settle (kept for the night's awards first).
		_morning_nerve = nerve.levels.duplicate()
		nerve.reset()
		shift.guards_required = director.living_guards().size()
		_start_morning.rpc()
		for guard in got_out:
			var peer := guard.name.to_int()
			shift.clock_out(peer)
			if career:
				career.award(peer, "LAST_BELL")
			director.tell(peer, "You're out. Behind you the gate swings shut, and the school goes quiet. Clocked out.")
		if not got_out.is_empty() and shift.everyone_clocked_out():
			_end_night.call_deferred()


func _on_log_submitted(area: String, type: String, named := "") -> void:
	clipboard.add_entry(time_text(), area, type if named == "" else FieldGuide.display_name(named).capitalize())
	hud.show_message("Logged: %s, %s." % [area, type.to_lower()])
	if multiplayer.is_server():
		_receive_log(area, type, named)
	else:
		_receive_log.rpc_id(1, area, type, named)


@rpc("any_peer", "call_remote", "reliable")
func _receive_log(area: String, type: String, named := "") -> void:
	if not multiplayer.is_server():
		return
	if shift.state != Shift.State.ON_SHIFT and shift.state != Shift.State.MORNING:
		return
	var peer := _sender()
	var stats: Dictionary = _stats.get_or_add(peer, {"correct": 0, "false": 0})
	var entry := "%s|%s" % [area, type]
	var logged: Array = _logged.get_or_add(peer, [])
	var found := ""
	var correct := false
	if type == "Monster":
		found = director.check_log(peer, area, named)
		correct = found != ""
	else:
		correct = anomalies.check_log(peer, area, type, minutes)
	if not correct and type == "Missing object":
		# The Mascot's empty stand really is a missing object.
		correct = director.check_mascot_missing(peer, area)
		if correct and director.guard_by_peer(peer) and "Mascot" not in director.guard_by_peer(peer).known_monsters:
			director.guard_by_peer(peer).known_monsters.append("Mascot")
		anomalies.last_was_first = director.last_log_was_first
	var first_or_seen := (director.last_log_was_first if type == "Monster" else anomalies.last_was_first) or _could_see(peer, area)
	if correct and first_or_seen:
		bonus.on_correct_log(named != "" and named == found)
		var logger := director.guard_by_peer(peer)
		if logger and found != "" and found not in logger.known_monsters:
			logger.known_monsters.append(found)
	var first := (director.last_log_was_first if type == "Monster" else anomalies.last_was_first) or not correct
	if correct and not first and not _could_see(peer, area):
		# Only passed on by a teammate: noted, but nobody pays for hearsay.
		logged.append(entry)
		_log_result(peer, true, "Noted: %s, %s. A teammate logged it first, and you didn't see it yourself: no pay." % [area, type.to_lower()])
	elif correct and not first:
		stats["confirmed"] = int(stats.get("confirmed", 0)) + 1
		logged.append(entry)
		_log_result(peer, true, "Confirmed: %s, %s. A teammate logged it first.  +%d" % [area, type.to_lower(), CONFIRM_POINTS])
	elif correct and named != "" and named == found:
		stats["correct"] += 1
		stats["named"] = stats.get("named", 0) + 1
		logged.append(entry)
		_log_result(peer, true, "Confirmed: %s in %s, named right.  +%d" % [
				FieldGuide.display_name(found), area, CORRECT_LOG_POINTS + NAME_POINTS])
	elif correct and named != "":
		stats["correct"] += 1
		stats["misnamed"] = int(stats.get("misnamed", 0)) + 1
		logged.append(entry)
		_log_result(peer, true, "Confirmed: a monster in %s, but it wasn't %s.  +%d" % [
				area, FieldGuide.display_name(named), CORRECT_LOG_POINTS - MISNAME_POINTS])
	elif correct:
		stats["correct"] += 1
		logged.append(entry)
		_log_result(peer, true, "Confirmed: %s, %s.  +%d" % [area, type.to_lower(), CORRECT_LOG_POINTS])
	elif entry in logged and entry not in stats.get("warned", []):
		# Already logged and paid for; the first repeat is just a reminder...
		stats.get_or_add("warned", []).append(entry)
		director.tell(peer, "You've already logged that one. Log it again with nothing new there and it counts as a false report.")
	else:
		stats["false"] += 1
		_log_result(peer, false, "Nothing like that in %s.  -%d" % [area, FALSE_REPORT_POINTS])


## Host: tells a guard straight away whether their log was right.
func _log_result(peer: int, correct: bool, text: String) -> void:
	if peer == multiplayer.get_unique_id():
		_show_log_result(correct, text)
	else:
		_show_log_result.rpc_id(peer, correct, text)


@rpc("authority", "call_remote", "reliable")
func _show_log_result(correct: bool, text: String) -> void:
	hud.show_message(("✓ " if correct else "✗ ") + text)
	var tune: Array = [880.0, 1320.0] if correct else [220.0, 165.0]
	Sfx.play_flat(self, Sfx.notes(tune, 0.1, 0.25, "sine" if correct else "square"))


## Host: tonight's difficulty, from the menu choice or the number of guards.
func pick_difficulty() -> int:
	if daily != "":
		return Daily.DIFFICULTY
	if training:
		return 1
	if difficulty_choice > 0:
		return clampi(difficulty_choice, 1, MAX_DIFFICULTY)
	# Auto: one wing per guard, and the school opens up as the run goes on (a new wing at
	# nights 4 and 7), so even a solo guard meets everything.
	var ramp := 1 + int((number - 1) / 3.0)
	return clampi(maxi(players.get_child_count(), ramp), 1, MAX_DIFFICULTY)


## Host: a guard just spawned. Gives back what they had in the saved run.
func restore_guard(peer_id: int, badge: int) -> void:
	var key := str(badge)
	if saved_points.has(key):
		_totals[peer_id] = int(saved_points[key])
		shop.send_wallet(peer_id)
	if saved_items.has(key):
		shop.give(peer_id, str(saved_items[key]))
	for upgrade: String in saved_personal.get(key, []):
		shop.set_owned(peer_id, upgrade, true)


## Host: a guard's player left. Their points, item and flashlight are kept by badge, and
## dropped from this session, so rejoining gives back exactly what they had.
func remember_guard(guard: Guard) -> void:
	var peer := guard.name.to_int()
	if _won or _restart_run:
		# The run is over (won or lost); nothing carries into the next one.
		_totals.erase(peer)
		shop.forget(peer)
		return
	var key := str(guard.employee_number)
	saved_points[key] = points_of(peer)
	var item := shop.held_by(peer)
	if item != "":
		saved_items[key] = item
	else:
		saved_items.erase(key)
	saved_personal[key] = shop.owned_by(peer)
	_totals.erase(peer)
	shop.forget(peer)


## Host: writes the run to disk so it can be continued, with `next_night` up next.
## `in_progress` marks a save made as a night starts (the night isn't finished yet).
func save_run(next_night: int, in_progress := false) -> void:
	if daily != "" or training:
		return  # The daily shift and training are nights on their own; they never touch the saved run.
	for guard: Guard in players.get_children():
		var key := str(guard.employee_number)
		var peer := guard.name.to_int()
		saved_points[key] = points_of(peer)
		var item := shop.held_by(peer)
		if item != "":
			saved_items[key] = item
		else:
			saved_items.erase(key)
		saved_personal[key] = shop.owned_by(peer)
	RunSave.write({
		"night": next_night, "difficulty": difficulty_choice, "keep_gear": keep_gear, "hardcore": hardcore,
		"points": saved_points, "items": saved_items, "upgrades": guard_room.upgraded.duplicate(),
		"run_stats": _run_stats, "run_nights": _run_nights, "write_ups": write_ups,
		"doors": doors.installed.duplicate(), "personal": saved_personal, "in_progress": in_progress,
		"spent": shop.spent, "team": run_team, "last_retried": _last_night_retried,
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
	# Also from the morning: the last guard can be caught moments before 6 AM, and the report
	# waits for their jumpscare, by which time it's morning with nobody left to clock out.
	if shift.state != Shift.State.ON_SHIFT and not (shift.state == Shift.State.MORNING and director.living_guards().is_empty()):
		return
	director.end_night()
	finale.reset()
	totems.clear_all()
	shop.clear_placed()
	power.end_night()
	phone.end_night()
	hiding.release_all()
	clutter.reset_all()
	nerve.reset()
	quota_target = 0
	_show_quota.rpc("")
	if daily == "" and training == null and not hardcore and number <= LAST_NIGHT:
		_fail_to_checkpoint()
		return
	_restart_run = true
	var rows := _build_rows(false)
	rounds.clear()
	bonus.clear()
	conditions.clear()
	if daily != "":
		_finish_daily(rows, 0, "Caught at %s. Score: 0." % time_text())
		return
	var summary := "The whole team was caught at %s.\nThe school keeps its secrets. The run starts over from night 1." % time_text()
	_run_nights += 1
	summary += "\n" + _run_summary()
	_forget_run()
	if keep_gear:
		summary += "\nYou keep your upgrades and whatever you're carrying. Points start again from zero."
	else:
		shop.reset_all()
		guard_room.reset_upgrades()
		doors.reset_all()
		saved_items.clear()
		saved_personal.clear()
	# Everyone's points are gone, including guards who aren't here tonight.
	saved_points.clear()
	shop.reset_spending()
	_show_report.rpc(number, rows, summary, "caught")
	run_team = 0
	save_run(1)


## The team's work target tonight: each extra guard adds 60% of one guard's share, since a
## team shares one school's worth of anomalies.
## Host: how many guards clocked in for tonight's shift.
var _shift_team := 1
## Host: when each guard was last in each area (real seconds), for confirmations.
var _visits: Dictionary = {}
const SEEN_SECONDS := 90.0
## Host: today's daily, hosted for a team (scores go on the team boards, by team size).
var team_daily := false
## Host: whether this run has had its one retry of the last night.
var _last_night_retried := false
## Host: peers who joined mid-shift as ghosts tonight. Not in tonight's counts, pay or credit.
var late_joiners: Dictionary = {}


## Host: the guards working tonight's shift who are still here (not late-joining ghosts).
func shift_team() -> int:
	var present := 0
	for peer in shift.clocked_in_peers():
		if players.has_node(str(peer)) and not late_joiners.has(peer):
			present += 1
	return maxi(present, 1)


func quota_for(team: int) -> int:
	return int((QUOTA_BASE + QUOTA_PER_NIGHT * number) * (1.0 + 0.6 * (maxi(team, 1) - 1)))


## Host: a guard never answered the Principal's summons. It's noted on their pay.
func on_principal_ignored(peer: int) -> void:
	if shift.state != Shift.State.ON_SHIFT:
		return
	dock(peer, IGNORED_SUMMONS_POINTS)
	director.tell(peer, "The intercom crackles: \"Guard, you did not come when called. That will be noted on your pay.\"  -%d" % IGNORED_SUMMONS_POINTS)


## Host: could this guard see `area` for themselves: standing in it, or sitting at a desk with
## one of its cameras on their own monitors?
func _could_see(peer: int, area: String) -> bool:
	var guard := director.guard_by_peer(peer)
	if guard == null:
		return false
	if SchoolBuilder.area_at(guard.global_position) == area:
		return true
	# Or was there a moment ago (saw it, then stepped out to log it).
	var visits: Dictionary = _visits.get(peer, {})
	if visits.has(area) and Time.get_ticks_msec() / 1000.0 - float(visits[area]) < SEEN_SECONDS:
		return true
	var desk := guard_room.occupants.find(peer)
	if desk < 0:
		return false
	for monitor in range(desk * 4, desk * 4 + 4):
		if cameras.area_of(guard_room.assignments[monitor]) == area:
			return true
	return false


## Host: takes points off a guard's pay tonight.
func dock(peer: int, amount: int) -> void:
	var stats: Dictionary = _stats.get_or_add(peer, {"correct": 0, "false": 0})
	stats["docked"] = int(stats.get("docked", 0)) + amount


## Host: the team's work so far, less what the stations still unpunched would cost at 6 AM
## (a station's pay, scaled like the target is for the team's size).
func _work_after_round() -> int:
	var team_factor := 1.0 + 0.6 * (shift_team() - 1)
	return maxi(_team_work() - int(rounds.missed_count() * rounds.punch_points() * team_factor), 0)


## Host: points the team has earned tonight from work (not from clocking out).
func _team_work() -> int:
	var total := 0
	for peer: int in _stats:
		var stats: Dictionary = _stats[peer]
		total += int(stats["correct"]) * CORRECT_LOG_POINTS + int(stats.get("named", 0)) * NAME_POINTS \
				+ int(stats.get("confirmed", 0)) * CONFIRM_POINTS - int(stats.get("misnamed", 0)) * MISNAME_POINTS \
				- int(stats["false"]) * FALSE_REPORT_POINTS
	for peer: int in rounds.punches:
		total += int(rounds.punches[peer]) * rounds.punch_points()
	return maxi(total, 0)


func _send_quota() -> void:
	# Sized to whoever's still here (someone leaving mid-shift shouldn't sink the team).
	if quota_target > 0:
		# (Not counting anyone who joined mid-shift as a ghost.)
		quota_target = quota_for(shift_team())
	var text := ""
	if quota_target > 0:
		text = "Work target: %d / %d" % [mini(_work_after_round(), quota_target), quota_target]
		if _work_after_round() >= quota_target:
			text += " (met)"
		elif rounds.missed_count() > 0:
			text += " (unpunched stations count against it at 6)"
		if write_ups > 0:
			text += "   ·   write-ups %d of %d" % [write_ups, WRITE_UPS_TO_FIRE]
	_show_quota.rpc(text)


@rpc("authority", "call_local", "reliable")
func _show_quota(text: String) -> void:
	quota_text = text


## The first night of the stretch this night is in: 1, 4 or 7.
static func checkpoint_for(night_number: int) -> int:
	return 1 + int((clampi(night_number, 1, LAST_NIGHT) - 1) / 3.0) * 3


## Host: the team was caught on an ordinary (not Hardcore) run. Back to the last checkpoint:
## tonight's pay still counts, everyone keeps their gear, and then points are halved.
func _halve_points(rows: Array) -> void:
	for peer: int in _totals:
		_totals[peer] = int(_totals[peer] / 2)
	for badge: String in saved_points:
		saved_points[badge] = int(int(saved_points[badge]) / 2)
	for row: Dictionary in rows:
		row["total"] = int(int(row["total"]) / 2)


func _fail_to_checkpoint() -> void:
	var rows := _build_rows(true)
	rounds.clear()
	bonus.clear()
	conditions.clear()
	_run_nights += 1
	write_ups = 0
	_restart_at = checkpoint_for(number)
	_halve_points(rows)
	var summary := "The whole team was caught at %s.\nBack to night %d, the last checkpoint. You keep your gear; everyone's points are halved." % [time_text(), _restart_at]
	# The last night: one more go at it straight away, once a run, rather than two nights back.
	if number == LAST_NIGHT and not _last_night_retried:
		_last_night_retried = true
		_restart_at = LAST_NIGHT
		summary = "The whole team was caught at %s.\nThe district gives you one more chance at the last night. You keep your gear; everyone's points are halved. Next time it's back to night %d." % [time_text(), checkpoint_for(number)]
	_show_report.rpc(number, rows, summary, "checkpoint:%d" % _restart_at)
	shop.push_wallets()
	save_run(_restart_at)


func _end_night() -> void:
	if shift.state != Shift.State.MORNING:
		return
	var rows := _build_rows(true)
	# Stations nobody punched count against the work target, for every guard on shift.
	var work := _work_after_round()
	_run_nights += 1
	_award_night()
	var round_text := "Round: %d of %d stations punched%s." % [rounds.punched.size(), rounds.order.size(),
			" (complete, +%d each)" % Rounds.ROUND_BONUS if rounds.is_complete()
			else ", %d missed (-%d for each guard)" % [rounds.missed_count(), rounds.missed_count() * Rounds.MISSED_PENALTY]]
	var awards := _awards()
	rounds.clear()
	var appeared := anomalies.appeared_count()
	var missed := anomalies.missed_count()
	var summary := "%d anomal%s tonight, %d missed by everyone.   Guards lost: %d." % [
		appeared, "y" if appeared == 1 else "ies", missed, _deaths]
	var missed_list := anomalies.missed_list()
	if not missed_list.is_empty():
		summary += "\nMissed: " + ", ".join(missed_list.slice(0, 8)) + (" and %d more" % (missed_list.size() - 8) if missed_list.size() > 8 else "") + "."
	if director.tonight_report != "":
		summary += "\n" + director.tonight_report
	summary += "\n" + round_text
	if conditions.summary() != "":
		summary += "\n" + conditions.summary()
	if bonus.summary() != "":
		summary += "\n" + bonus.summary()
	conditions.clear()
	bonus.clear()
	if awards != "":
		summary += "\n" + awards
	if difficulty > 1:
		summary += "\nDifficulty %d: +%d%% XP." % [difficulty, int(XP_PER_WING * (difficulty - 1) * 100)]
	summary += "\nPay: %d for clocking out, +%d per correct log, -%d per false report, -%d for each guard lost." % [
		SURVIVAL_PAY, CORRECT_LOG_POINTS, FALSE_REPORT_POINTS, DEATH_PENALTY]
	if daily != "":
		# The team's score: everyone's pay tonight added up (just yours, solo).
		var score := 0
		for row: Dictionary in rows:
			score += int(row.get("pay", 0))
		_finish_daily(rows, score, summary)
		return
	var fired := false
	if quota_target > 0 and number != LAST_NIGHT:
		if work >= quota_target:
			summary = "Work target met: %d / %d.\n" % [work, quota_target] + summary
		else:
			write_ups += 1
			fired = write_ups >= WRITE_UPS_TO_FIRE
			summary = "WRITE-UP %d of %d: the team only managed %d of tonight's %d work target.\n" % [
					write_ups, WRITE_UPS_TO_FIRE, work, quota_target] + summary
	quota_target = 0
	_show_quota.rpc("")
	if fired:
		write_ups = 0
		if hardcore or number > LAST_NIGHT:
			_restart_run = true
			summary = "FIRED. Three write-ups, and the district lets the whole team go. A new crew starts from night 1.\n" + summary
			summary += "\n" + _run_summary()
			_show_report.rpc(number, rows, summary, "fired:1")
			_reset_run()
			run_team = 0
			save_run(1)
		else:
			_restart_at = checkpoint_for(number)
			_halve_points(rows)
			summary = "FIRED. Three write-ups. You're rehired on probation from night %d, the last checkpoint, and everyone's points are halved.\n" % _restart_at + summary
			_show_report.rpc(number, rows, summary, "fired:%d" % _restart_at)
			shop.push_wallets()
			save_run(_restart_at)
		return
	if number == LAST_NIGHT:
		_won = true
		_restart_run = true
		var team_total := 0
		for guard: Guard in players.get_children():
			team_total += points_of(guard.name.to_int())
		summary += "\n" + _run_summary()
		summary = "You kept Westfield High safe for all %d nights. Whatever lives here will wait for the next crew.\nFinal team score: %d points. Or stay on for Overtime: the nights keep coming, and get worse.\n" % [LAST_NIGHT, team_total] + summary
		_show_report.rpc(number, rows, summary, "won")
		shop.push_wallets()
		# The run is over unless the host picks Overtime. Nothing carries on from a saved run.
		RunSave.clear()
		return
	_show_report.rpc(number, rows, summary, "overtime" if number > LAST_NIGHT else "night")
	shop.push_wallets()
	save_run(number + 1)


## Host: achievements and stats for the night everyone clocked out of (or didn't).
func _award_night() -> void:
	if career == null:
		return
	var won := number == LAST_NIGHT
	var team := maxi(run_team, shift_team())
	for guard: Guard in players.get_children():
		var peer := guard.name.to_int()
		# Joined as a ghost tonight: no credit for a night they didn't work.
		if late_joiners.has(peer):
			continue
		var stats: Dictionary = _stats.get(peer, {"correct": 0, "false": 0})
		if stats["correct"] > 0:
			career.add_stat(peer, "correct_logs", stats["correct"])
		if stats["correct"] >= 10:
			career.award(peer, "SHARP_EYES")
		if stats["correct"] >= 5 and stats["false"] == 0:
			career.award(peer, "BY_THE_BOOK")
		if not shift.has_clocked_out(peer):
			continue
		career.add_stat(peer, "nights_survived")
		career.award(peer, "FIRST_SHIFT")
		if number >= 5:
			career.award(peer, "NIGHT_FIVE")
		if doors.battered_tonight:
			career.award(peer, "HOLD_THE_DOOR")
		if number >= 6 and float(_morning_nerve.get(peer, Nerve.MAX)) > 70.0:
			career.award(peer, "STEADY_NERVES")
		if daily == "":
			career.record_night(peer, number)
		if number > LAST_NIGHT:
			career.award(peer, "OVERTIME")
		if number >= OVERTIME_GOAL:
			career.award(peer, "WORKAHOLIC")
		if won:
			career.award(peer, "RUN_WON")
			career.add_stat(peer, "runs_won")
			career.record_score(peer, points_of(peer), difficulty, team)
			if team == 1:
				career.award(peer, "RUN_WON_SOLO")
			if difficulty >= MAX_DIFFICULTY:
				career.award(peer, "RUN_WON_D3")


## The run's totals for the report when it ends, e.g. "This run: 5 nights. Sam: 12 logs, 2 named,
## 8 stations, caught once. Run MVP: Sam." Then forgets them, ready for the next run.
func _run_summary() -> String:
	if _run_stats.is_empty():
		return ""
	var lines: Array[String] = []
	var best := ""
	var best_score := -INF
	for who: String in _run_stats:
		var run: Dictionary = _run_stats[who]
		var caught := int(run["caught"])
		lines.append("%s: %d logs, %d named, %d stations, %s" % [who, run["logs"], run["named"], run["stations"],
				"never caught" if caught == 0 else ("caught once" if caught == 1 else "caught %d times" % caught)])
		var score: float = run["logs"] * 25 + run["named"] * 25 + run["stations"] * 20 - caught * 50
		if score > best_score:
			best_score = score
			best = who
		elif score == best_score:
			best = ""  # A tie: no MVP.
	var text := "This run: %d night%s.  %s." % [_run_nights, "" if _run_nights == 1 else "s", ".  ".join(lines)]
	if _run_stats.size() > 1 and best != "" and best_score > 0.0:
		text += "  Run MVP: %s." % best
	return text


func _forget_run() -> void:
	_run_stats.clear()
	_run_nights = 0
	write_ups = 0
	_last_night_retried = false


## Co-op only: who did best tonight, e.g. "Sharpest eyes: Sam (4 logs)  ·  Night watchman: Guard 2 (3 stations)".
func _awards() -> String:
	if shift_team() < 2:
		return ""
	var awards: Array[String] = []
	var categories := [
		["Sharpest eyes", ["log", "logs"], func(peer: int) -> int: return int(_stats.get(peer, {}).get("correct", 0))],
		["Monster expert", ["named", "named"], func(peer: int) -> int: return int(_stats.get(peer, {}).get("named", 0))],
		["Night watchman", ["station", "stations"], func(peer: int) -> int: return int(rounds.punches.get(peer, 0))],
	]
	for category: Array in categories:
		var best: Guard = null
		var best_count := 0
		var tied := false
		for guard: Guard in players.get_children():
			var count: int = (category[2] as Callable).call(guard.name.to_int())
			if count > best_count:
				best = guard
				best_count = count
				tied = false
			elif count == best_count and count > 0:
				tied = true
		if best and not tied:
			var who := best.player_name if best.player_name != "" else "Guard %d" % best.slot
			awards.append("%s: %s (%d %s)" % [category[0], who, best_count, category[1][0 if best_count == 1 else 1]])
	return "  ·  ".join(awards)


## One row per guard for the report. `keep_pay` is false when the run is starting over.
func _build_rows(keep_pay: bool) -> Array:
	var rows: Array = []
	for guard: Guard in players.get_children():
		var peer := guard.name.to_int()
		var stats: Dictionary = _stats.get(peer, {"correct": 0, "false": 0})
		var clocked_out := shift.has_clocked_out(peer)
		var correct_points: int = stats["correct"] * CORRECT_LOG_POINTS + stats.get("named", 0) * NAME_POINTS \
				+ int(stats.get("confirmed", 0)) * CONFIRM_POINTS
		var false_points: int = stats["false"] * FALSE_REPORT_POINTS + int(stats.get("misnamed", 0)) * MISNAME_POINTS \
				+ int(stats.get("docked", 0))
		var round_points := rounds.pay_for(peer, clocked_out)
		var pay: int = (SURVIVAL_PAY if clocked_out else 0) + correct_points - false_points + round_points \
				- _deaths * DEATH_PENALTY
		if clocked_out and bonus.achieved():
			pay += Bonus.POINTS
		if pay > 0 and conditions.has("hazard_pay"):
			pay = int(pay * 1.5)
		var late := late_joiners.has(peer)
		if late:
			clocked_out = false
			pay = 0
		if keep_pay:
			# Points never go below zero.
			_totals[peer] = maxi(_totals.get(peer, 0) + pay, 0)
		else:
			_totals[peer] = 0
		var xp: int = 0 if late else (XP_CLOCKED_OUT + number * XP_PER_NIGHT if clocked_out else XP_CAUGHT) \
				+ stats["correct"] * XP_PER_LOG + stats.get("named", 0) * XP_PER_NAME \
				+ int(stats.get("confirmed", 0)) * int(XP_PER_LOG / 2) \
				+ int(rounds.punches.get(peer, 0)) * XP_PER_PUNCH
		if clocked_out and bonus.achieved():
			xp += Bonus.XP
		# Harder nights are worth more: shift notes, and the bigger school (+25% per wing open).
		xp = int(xp * conditions.xp_factor() * (1.0 + XP_PER_WING * (difficulty - 1)))
		if career:
			career.add_xp(peer, xp)
		var who := guard.player_name if guard.player_name != "" else "Guard %d" % guard.slot
		var run: Dictionary = _run_stats.get_or_add(who, {"logs": 0, "named": 0, "stations": 0, "caught": 0})
		run["logs"] += int(stats["correct"])
		run["named"] += int(stats.get("named", 0))
		run["stations"] += int(rounds.punches.get(peer, 0))
		run["caught"] += 1 if guard.is_dead and not late else 0
		rows.append({
			"xp": xp, "late": late,
			"name": "Guard %d  #%04d" % [guard.slot, guard.employee_number], "clocked_out": clocked_out, "died": guard.is_dead and not late,
			"correct": stats["correct"] + int(stats.get("confirmed", 0)), "correct_points": correct_points,
			"false": stats["false"], "false_points": false_points,
			"punched": rounds.punches.get(peer, 0), "round_points": round_points,
			"pay": pay, "total": _totals[peer], "lost": not keep_pay,
		})
	return rows


## Host: the daily shift is over. Its score is tonight's pay (0 if caught).
func _finish_daily(rows: Array, score: int, summary: String) -> void:
	score = maxi(score, 0)
	randomize()
	var team := maxi(run_team, _shift_team) if team_daily else 0
	var best_before := Career.daily_best(daily, team)
	var new_best := score > best_before
	# To everyone who worked tonight's shift (not anyone who joined it late as a ghost).
	for guard: Guard in players.get_children():
		var peer := guard.name.to_int()
		if late_joiners.has(peer):
			continue
		if peer == multiplayer.get_unique_id():
			_daily_result(daily, score, team)
		else:
			_daily_result.rpc_id(peer, daily, score, team)
	var headline := ("Daily shift for %s: you scored %d." if team == 0 else "Team daily shift for %s (%d guards): the team scored %d.") % (
			[daily, score] if team == 0 else [daily, team, score])
	if new_best and best_before >= 0:
		headline += " A new best for today (was %d)." % best_before
	elif not new_best:
		headline += " Today's best is still %d." % best_before
	headline += "  Days in a row: %d." % maxi(Career.daily_streak(), 1)
	_show_report.rpc(number, rows, headline + "\n" + summary, "daily")


## Each computer that worked the shift: today's daily score goes in that player's records, and on
## Steam. Solo scores and each team size have their own board ("daily_20261015_team3").
@rpc("authority", "call_remote", "reliable")
func _daily_result(date: String, score: int, team: int) -> void:
	if career:
		career.record_daily(date, score, team)
	var steam := get_node_or_null("/root/SteamService")
	if steam:
		steam.submit_score(steam.daily_board(date) + ("" if team == 0 else "_team%d" % team), score)


## Host, after the ninth night: the team stays on. Points, gear and upgrades carry on.
func _on_overtime_requested() -> void:
	if not multiplayer.is_server() or not _won:
		return
	anomalies.reset_all()
	doors.reset_for_night()
	_won = false
	_restart_run = false
	shop.push_wallets()
	save_run(number + 1)
	_begin_next_night.rpc(number + 1)


## Host: a won run is over and a new one starts from nothing.
func _reset_run() -> void:
	_forget_run()
	for guard: Guard in players.get_children():
		_totals[guard.name.to_int()] = 0
	shop.reset_spending()
	shop.reset_all()
	guard_room.reset_upgrades()
	doors.reset_all()
	saved_points.clear()
	saved_items.clear()
	saved_personal.clear()
	shop.push_wallets()


func _on_next_night_requested() -> void:
	if multiplayer.is_server():
		hiding.release_all()
		clutter.reset_all()
	if multiplayer.is_server() and (daily != "" or training):
		daily_finished.emit()
		return
	if multiplayer.is_server():
		anomalies.reset_all()
		doors.reset_for_night()
		var next := 1 if _restart_run else (_restart_at if _restart_at > 0 else number + 1)
		_restart_at = 0
		if _restart_run:
			run_team = 0
		if _won:
			_reset_run()
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
