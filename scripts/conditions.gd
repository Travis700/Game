class_name Conditions
extends Node
## Tonight's conditions: from night 2, each night comes with one or two "shift notes" that
## change how it plays (fog, faulty wiring, a full moon...), so no two nights are the same.
## Harder nights earn more XP.
##
## The host picks them as the shift starts and tells everyone. Effects that only matter to the
## host (monsters, pay, rounds, power cuts) are read with `has()`; effects every computer shows
## (fog, flashlights) are applied here.

## Each condition: its name, what the shift note says, and the first night it can come up.
const CATALOGUE := {
	"fog": {"name": "Fog advisory", "night": 2,
		"about": "Thick fog tonight, inside and out. You won't see far."},
	"wiring": {"name": "Faulty wiring", "night": 2,
		"about": "The electrics are acting up: expect the power to go more often."},
	"inspector": {"name": "Inspector's visit", "night": 2,
		"about": "The district wants a thorough round: more stations, and each pays double."},
	"sharp_ears": {"name": "Sound carries", "night": 2,
		"about": "It's very quiet tonight. Monsters hear voices from half as far again."},
	"batteries": {"name": "Old batteries", "night": 3,
		"about": "The new batteries didn't arrive. Flashlights are dim and don't reach far."},
	"messy": {"name": "Messy school", "night": 2,
		"about": "The cleaner called in sick, and the place is a mess: half as many anomalies again."},
	"full_moon": {"name": "Full moon", "night": 4,
		"about": "Everything in this school is restless. Monsters move faster."},
	"hazard_pay": {"name": "Hazard pay", "night": 3,
		"about": "One more monster than usual tonight, but everyone's pay is half as much again."},
	"camera_fault": {"name": "Camera faults", "night": 3,
		"about": "A third of the cameras are down until the engineer comes in the morning. Some things you'll have to check in person."},
	"drill": {"name": "Lockdown drill", "night": 4,
		"about": "There's a lockdown drill tonight. When the alarm goes, everything in here takes it seriously."},
	"early_start": {"name": "Early start", "night": 3,
		"about": "Nothing's waiting for the small hours tonight: everything will be out by 2 AM."},
}
## How much faster monsters move under a full moon.
const FULL_MOON_SPEED := 1.15
## XP bonus per condition.
const XP_BONUS := 0.15

var lighting: ShiftLighting
var players: Node3D
var hud: CanvasLayer

## Tonight's conditions (keys of CATALOGUE). On every computer.
var active: Array[String] = []
## Host: conditions to use every night instead of random ones (--conditions=fog,batteries).
var forced: Array[String] = []


# --- Host --------------------------------------------------------------------------------

## Picks tonight's conditions: none on night 1, one on nights 2-4, two after that, and one
## more for every night past the ninth (Overtime).
func pick(night_number: int) -> void:
	var count := 0 if night_number < 2 else (1 if night_number < 5 else 2 + maxi(night_number - 9, 0))
	var pool: Array[String] = []
	for key: String in CATALOGUE:
		if CATALOGUE[key]["night"] <= night_number:
			pool.append(key)
	pool.shuffle()
	var picked := pool.slice(0, mini(count, pool.size()))
	if not forced.is_empty():
		picked = forced.filter(func(key: String) -> bool: return CATALOGUE.has(key))
	_set_conditions.rpc(PackedStringArray(picked), night_number)


## The night is over: everything goes back to normal.
func clear() -> void:
	if not active.is_empty():
		_set_conditions.rpc(PackedStringArray(), 0)


func has(key: String) -> bool:
	return key in active


## Multiplies tonight's XP: harder nights are worth more.
func xp_factor() -> float:
	return 1.0 + XP_BONUS * active.size()


## One line for the report, e.g. "Tonight's conditions: Fog advisory, Full moon (+30% XP)."
func summary() -> String:
	if active.is_empty():
		return ""
	return "Tonight's conditions: %s (+%d%% XP)." % [", ".join(names()), int(round(XP_BONUS * active.size() * 100.0))]


func names() -> Array[String]:
	var result: Array[String] = []
	for key in active:
		result.append(CATALOGUE[key]["name"])
	return result


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_conditions(keys: PackedStringArray, night_number: int) -> void:
	active.assign(Array(keys))
	lighting.set_night_overrides({"fog_density": 0.075, "fog_light_color": Color(0.07, 0.075, 0.09)} if has("fog") else {})
	apply_to_guards()
	if active.is_empty():
		return
	var lines: Array[String] = []
	for key in active:
		lines.append("%s: %s" % [CATALOGUE[key]["name"], CATALOGUE[key]["about"]])
	hud.show_message("SHIFT NOTES, NIGHT %d\n%s" % [night_number, "\n".join(lines)], 12.0)


## Old batteries dim every guard's flashlight. Also called when a guard spawns.
func apply_to_guards() -> void:
	for guard: Guard in players.get_children():
		guard.battery = 0.55 if has("batteries") and guard.perk != "spare_batteries" else 1.0
		guard.apply_flashlight()
