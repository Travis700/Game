class_name Career
extends Node
## Each player's achievements, career stats and best scores, kept on their own computer in
## user://career.cfg, and mirrored to Steam when it's running (achievements and stats).
##
## Most things worth an achievement happen on the host, so the host calls `award` and
## `add_stat` with a guard's peer id, and this sends it to that player's computer.

const PATH := "user://career.cfg"
const TEMP_PATH := "user://career.cfg.new"
const BACKUP_PATH := "user://career.cfg.bak"
## Achievement API names (also used in Steamworks), with the name and how to get it.
const ACHIEVEMENTS := {
	"FIRST_SHIFT": ["First shift", "Clock out after your first night."],
	"NIGHT_FIVE": ["Halfway there", "Survive night 5."],
	"RUN_WON": ["Nine nights", "Survive all nine nights."],
	"RUN_WON_SOLO": ["Night owl", "Survive all nine nights on your own."],
	"RUN_WON_D3": ["The whole school", "Survive all nine nights at difficulty 3."],
	"SHARP_EYES": ["Sharp eyes", "Log 10 things correctly in one night."],
	"BY_THE_BOOK": ["By the book", "Log at least 5 things correctly in a night with no false reports."],
	"MONSTER_EXPERT": ["Field guide", "Log every kind of monster at least once (across all your runs)."],
	"GOOD_SAMARITAN": ["Good Samaritan", "Walk a real lost student to safety."],
	"BACK_FROM_DEAD": ["Not dead yet", "Be brought back at a revive totem."],
	"LIFESAVER": ["Lifesaver", "Bring a teammate back at a revive totem."],
	"PRESENT": ["Present!", "Answer the Substitute's register."],
	"ART_CRITIC": ["Art critic", "Turn the Self-Portrait to the wall."],
	"BIG_SPENDER": ["Big spender", "Spend 1000 points at the vending machine in one run."],
	"HOLD_THE_DOOR": ["Hold the door", "Clock out of a night where a monster battered a guard room door."],
	"FULL_ROUND": ["Full round", "Punch every station on a night's round."],
	"LIGHTS_ON": ["Who turned out the lights?", "Reset the breaker after a power cut."],
	"DAILY": ["Clocking on", "Finish a daily shift."],
	"DAILY_STREAK": ["Regular", "Play the daily shift five days in a row."],
	"HIDE_AND_SEEK": ["Hide and seek", "Be hidden in a cupboard when a lockdown ends."],
	"STEADY_NERVES": ["Nerves of steel", "Clock out of night 6 or later with your nerve above 70."],
	"EMF_FIVE": ["Five lights", "See an EMF reader hit 5."],
	"TRAINED": ["Fully trained", "Finish the training shift."],
	"LEGEND": ["Legend of Westfield", "Reach the top rank."],
	"CLOSE_CALL": ["Close call", "Get knocked out by a monster you'd never logged, and live to log it."],
	"TEAM_DAILY": ["Team player", "Finish a daily shift as a team."],
	"SECOND_CHANCE": ["Second chance", "Win a run on the last night's retry."],
	"DOWN_TO_THE_WIRE": ["Down to the wire", "Get out through the gate in the finale after 5:55 AM."],
	"LAST_BELL": ["Last bell", "Get out through the front gate in the final night's finale."],
	"OVERTIME": ["Overtime", "Survive a night of Overtime, after the ninth."],
	"WORKAHOLIC": ["Workaholic", "Survive night 15."],
}
## Every kind of monster, for the Field guide achievement.
const MONSTER_KINDS: Array[String] = [
	"HallMonitor", "Mascot", "LunchLady", "Lockers", "Principal", "OtherCleaner", "Student", "SchoolGhost",
	"Substitute", "Librarian", "Nurse", "CrossingGuard", "SelfPortrait", "Specimen", "Understudy", "Photographer", "Twin", "Coach",
]
## Career stats shown on the Records screen (and sent to Steam under the same names).
const STATS := {
	"nights_survived": "Nights survived",
	"runs_won": "Runs won",
	"correct_logs": "Correct logs",
	"times_caught": "Times caught",
	"monsters_logged": "Monsters logged",
	"stations_punched": "Stations punched",
}
const MAX_SCORES := 10
## Ranks: the XP needed for each, and its title. XP comes from every night worked, and stays
## with the player across runs.
const RANKS := [
	[0, "Trainee"], [400, "Night Watch"], [1200, "Patrol Officer"], [2500, "Senior Guard"],
	[4500, "Shift Supervisor"], [7500, "Head of Security"], [12000, "Night Warden"],
	[20000, "Legend of Westfield"],
]


# --- Host: things happening to a guard ----------------------------------------------------

func award(peer_id: int, achievement: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_unlock(achievement)
	elif peer_id in multiplayer.get_peers():
		_unlock.rpc_id(peer_id, achievement)


func add_stat(peer_id: int, stat: String, amount := 1) -> void:
	if peer_id == multiplayer.get_unique_id():
		_add_stat(stat, amount)
	elif peer_id in multiplayer.get_peers():
		_add_stat.rpc_id(peer_id, stat, amount)


## This player logged a monster for the first time ever: its page in the guide just filled in.
signal guide_entry_added(kind: String)


func logged_monster(peer_id: int, kind: String) -> void:
	add_stat(peer_id, "monsters_logged")
	if peer_id == multiplayer.get_unique_id():
		_saw_monster(kind)
	elif peer_id in multiplayer.get_peers():
		_saw_monster.rpc_id(peer_id, kind)


## Host: a guard clocked out of this night; each player keeps the furthest night they've reached.
func record_night(peer_id: int, night: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_record_night(night)
	elif peer_id in multiplayer.get_peers():
		_record_night.rpc_id(peer_id, night)


## This player's daily shift score for `date`. Keeps the best one. True if it's a new best.
func record_daily(date: String, score: int, team := 0) -> bool:
	var config := _load()
	var section := "daily" if team == 0 else "daily_team%d" % team
	# Any daily played counts towards the streak.
	if not config.has_section_key("daily_played", date):
		config.set_value("daily_played", date, true)
		_save(config)
	var best := int(config.get_value(section, date, -1))
	if score <= best:
		if daily_streak() >= 5:
			_unlock("DAILY_STREAK")
		_unlock("DAILY")
		return false
	config.set_value(section, date, score)
	_save(config)
	_unlock("DAILY")
	if daily_streak() >= 5:
		_unlock("DAILY_STREAK")
	return true


## Host: XP for a guard's night.
func add_xp(peer_id: int, amount: int) -> void:
	if amount <= 0:
		return
	if peer_id == multiplayer.get_unique_id():
		_add_xp(amount)
	elif peer_id in multiplayer.get_peers():
		_add_xp.rpc_id(peer_id, amount)


## Host: a run was won with these final points; each player keeps it in their best scores.
func record_score(peer_id: int, points: int, difficulty: int, guards: int) -> void:
	if peer_id == multiplayer.get_unique_id():
		_record_score(points, difficulty, guards)
	elif peer_id in multiplayer.get_peers():
		_record_score.rpc_id(peer_id, points, difficulty, guards)


# --- Every computer: this player's own records --------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _unlock(achievement: String) -> void:
	if not ACHIEVEMENTS.has(achievement):
		return
	var config := _load()
	var steam := get_node_or_null("/root/SteamService")
	if steam:
		steam.unlock_achievement(achievement)
	if config.get_value("achievements", achievement, false):
		return
	config.set_value("achievements", achievement, Time.get_datetime_string_from_system(false, true))
	_save(config)
	get_tree().call_group("game", "on_achievement", ACHIEVEMENTS[achievement][0])


@rpc("authority", "call_remote", "reliable")
func _add_stat(stat: String, amount: int) -> void:
	var config := _load()
	var value: int = config.get_value("stats", stat, 0) + amount
	config.set_value("stats", stat, value)
	_save(config)
	var steam := get_node_or_null("/root/SteamService")
	if steam:
		steam.add_stat(stat, amount)


@rpc("authority", "call_remote", "reliable")
func _saw_monster(kind: String) -> void:
	var config := _load()
	var seen: Array = config.get_value("career", "monsters_seen", [])
	if kind not in seen:
		seen.append(kind)
		config.set_value("career", "monsters_seen", seen)
		_save(config)
		guide_entry_added.emit(kind)
	if MONSTER_KINDS.all(func(each: String) -> bool: return each in seen):
		_unlock("MONSTER_EXPERT")


@rpc("authority", "call_remote", "reliable")
func _record_night(night: int) -> void:
	var config := _load()
	if night > int(config.get_value("career", "best_night", 0)):
		config.set_value("career", "best_night", night)
		_save(config)
		var steam := get_node_or_null("/root/SteamService")
		if steam and night > 9:
			steam.submit_score("furthest_night", night)


@rpc("authority", "call_remote", "reliable")
func _add_xp(amount: int) -> void:
	var config := _load()
	var before: int = config.get_value("career", "xp", 0)
	config.set_value("career", "xp", before + amount)
	_save(config)
	var old_rank := rank_of(before)
	var new_rank := rank_of(before + amount)
	if new_rank > old_rank:
		get_tree().call_group("game", "on_rank_up", new_rank, rank_title(new_rank))
	# Also for anyone who was already at the top before this achievement existed.
	if new_rank >= RANKS.size():
		_unlock("LEGEND")


@rpc("authority", "call_remote", "reliable")
func _record_score(points: int, difficulty: int, guards: int) -> void:
	var config := _load()
	var scores: Array = config.get_value("career", "scores", [])
	scores.append({"points": points, "difficulty": difficulty, "guards": guards,
			"date": Time.get_date_string_from_system()})
	scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["points"] > b["points"])
	config.set_value("career", "scores", scores.slice(0, MAX_SCORES))
	_save(config)


# --- Reading the records (for the menu) ---------------------------------------------------

static func unlocked() -> Dictionary:
	var config := _load()
	var result := {}
	if config.has_section("achievements"):
		for key in config.get_section_keys("achievements"):
			result[key] = config.get_value("achievements", key)
	return result


static func stat(name: String) -> int:
	return _load().get_value("stats", name, 0)


static func best_scores() -> Array:
	return _load().get_value("career", "scores", [])


## Best daily shift score for a date, or -1 if it hasn't been played.
static func daily_best(date: String, team := 0) -> int:
	return int(_load().get_value("daily" if team == 0 else "daily_team%d" % team, date, -1))


## Days in a row the daily shift has been played, up to today (or yesterday, if today's
## hasn't been played yet).
static func daily_streak() -> int:
	var config := _load()
	var day := Time.get_unix_time_from_datetime_string(Time.get_date_string_from_system(true))
	var played := func(date: String) -> bool:
		return config.has_section_key("daily", date) or config.has_section_key("daily_played", date)
	if not played.call(Time.get_date_string_from_unix_time(day)):
		day -= 86400
	var streak := 0
	while played.call(Time.get_date_string_from_unix_time(day)):
		streak += 1
		day -= 86400
	return streak


## The furthest night this player has clocked out of (Overtime counts).
static func best_night() -> int:
	return _load().get_value("career", "best_night", 0)


static func xp() -> int:
	return _load().get_value("career", "xp", 0)


## This player's rank, 1 (Trainee) and up.
static func rank() -> int:
	return rank_of(xp())


static func rank_of(points: int) -> int:
	var result := 1
	for i in RANKS.size():
		if points >= int(RANKS[i][0]):
			result = i + 1
	return result


static func rank_title(rank_number: int) -> String:
	return RANKS[clampi(rank_number, 1, RANKS.size()) - 1][1]


## XP needed for the rank after this one, or -1 at the top.
static func next_rank_xp(rank_number: int) -> int:
	return int(RANKS[rank_number][0]) if rank_number < RANKS.size() else -1


static func monsters_seen() -> Array:
	return _load().get_value("career", "monsters_seen", [])


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	var damaged := config.load(PATH) != OK
	# A file with something in it but nothing readable is damaged too.
	if not damaged and config.get_sections().is_empty() and FileAccess.file_exists(PATH):
		damaged = FileAccess.get_file_as_bytes(PATH).size() > 0
	if damaged and FileAccess.file_exists(BACKUP_PATH):
		# The career file is damaged (e.g. the game was killed while saving): use the backup.
		config = ConfigFile.new()
		config.load(BACKUP_PATH)
	return config


## Saves without ever leaving a half-written career behind: write a new file, keep the old one
## as a backup, then swap the new one in.
static func _save(config: ConfigFile) -> void:
	if config.save(TEMP_PATH) != OK:
		return
	var dir := DirAccess.open("user://")
	if dir == null:
		return
	if FileAccess.file_exists(PATH):
		dir.copy(PATH, BACKUP_PATH)
	if dir.rename(TEMP_PATH, PATH) != OK:
		# Some systems won't rename over an existing file.
		dir.remove(PATH)
		dir.rename(TEMP_PATH, PATH)
