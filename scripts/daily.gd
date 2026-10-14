class_name Daily
extends RefCounted
## The daily shift: one night a day, played solo, the same for everyone on that date: the
## same night, conditions, bonus objective, round and monster plan. Score is that night's pay.
## Each player keeps their best score for each day and how many days in a row they've played.

const DIFFICULTY := 2
## How many shift notes a daily shift has.
const CONDITIONS := 2
## Points to spend at the vending machine before the shift.
const STARTING_POINTS := 250


## Today's date, e.g. "2026-10-14" (UTC, so everyone's day changes at the same moment).
static func today() -> String:
	return Time.get_date_string_from_system(true)


static func seed_of(date: String) -> int:
	return hash("night-shift-daily-" + date)


## Which night of the run the daily shift plays as (4-8: monsters out, but not night 9).
static func night_of(date: String) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of(date)
	return rng.randi_range(4, 8)


static func conditions_of(date: String) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_of(date) + 1
	var night := night_of(date)
	var pool: Array[String] = []
	for key: String in Conditions.CATALOGUE:
		if Conditions.CATALOGUE[key]["night"] <= night:
			pool.append(key)
	var picked: Array[String] = []
	while picked.size() < CONDITIONS and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## One line for the menu, e.g. "Night 6 · Fog advisory, Full moon".
static func describe(date: String) -> String:
	var names: Array[String] = []
	for key in conditions_of(date):
		names.append(Conditions.CATALOGUE[key]["name"])
	return "Night %d · %s" % [night_of(date), ", ".join(names)]
