class_name Career
extends Node
## Each player's achievements, career stats and best scores, kept on their own computer in
## user://career.cfg, and mirrored to Steam when it's running (achievements and stats).
##
## Most things worth an achievement happen on the host, so the host calls `award` and
## `add_stat` with a guard's peer id, and this sends it to that player's computer.

const PATH := "user://career.cfg"
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
}
## Every kind of monster, for the Field guide achievement.
const MONSTER_KINDS: Array[String] = [
	"HallMonitor", "Mascot", "LunchLady", "Lockers", "Principal", "OtherCleaner", "Student", "SchoolGhost",
	"Substitute", "Librarian", "Nurse", "CrossingGuard", "SelfPortrait", "Specimen", "Understudy",
]
## Career stats shown on the Records screen (and sent to Steam under the same names).
const STATS := {
	"nights_survived": "Nights survived",
	"runs_won": "Runs won",
	"correct_logs": "Correct logs",
	"times_caught": "Times caught",
	"monsters_logged": "Monsters logged",
}
const MAX_SCORES := 10


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


func logged_monster(peer_id: int, kind: String) -> void:
	add_stat(peer_id, "monsters_logged")
	if peer_id == multiplayer.get_unique_id():
		_saw_monster(kind)
	elif peer_id in multiplayer.get_peers():
		_saw_monster.rpc_id(peer_id, kind)


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
	config.save(PATH)
	get_tree().call_group("game", "on_achievement", ACHIEVEMENTS[achievement][0])


@rpc("authority", "call_remote", "reliable")
func _add_stat(stat: String, amount: int) -> void:
	var config := _load()
	var value: int = config.get_value("stats", stat, 0) + amount
	config.set_value("stats", stat, value)
	config.save(PATH)
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
		config.save(PATH)
	if MONSTER_KINDS.all(func(each: String) -> bool: return each in seen):
		_unlock("MONSTER_EXPERT")


@rpc("authority", "call_remote", "reliable")
func _record_score(points: int, difficulty: int, guards: int) -> void:
	var config := _load()
	var scores: Array = config.get_value("career", "scores", [])
	scores.append({"points": points, "difficulty": difficulty, "guards": guards,
			"date": Time.get_date_string_from_system()})
	scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["points"] > b["points"])
	config.set_value("career", "scores", scores.slice(0, MAX_SCORES))
	config.save(PATH)


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


static func monsters_seen() -> Array:
	return _load().get_value("career", "monsters_seen", [])


static func _load() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(PATH)
	return config
