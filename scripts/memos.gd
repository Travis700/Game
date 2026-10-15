class_name Memos
extends RefCounted
## Overtime's district memos: each night past the last brings one more, and they stay. Nights
## stop being "the same, plus another shift note" and turn into a list of standing orders that
## keeps getting longer. Worked out from the night number, so nothing needs saving or sending.

const LIST: Array[Dictionary] = [
	{"key": "moods", "text": "Staff are on edge. Every one of them is in a mood now."},
	{"key": "bell", "text": "The bell's on a new timer. It rings three times a night."},
	{"key": "lockdowns", "text": "More drills, by order of the board. Three lockdowns a night."},
	{"key": "late", "text": "Two latecomers a night now, both around 4 AM."},
	{"key": "cameras", "text": "Camera maintenance is cancelled. A third of the cameras stay dead."},
]
## Every third night of Overtime (12, 15, 18...) ends with the last bell again.
const FINALE_EVERY := 3


## The memos in force on this night.
static func active(night_number: int) -> Array[String]:
	var keys: Array[String] = []
	for i in clampi(night_number - Night.LAST_NIGHT, 0, LIST.size()):
		keys.append(LIST[i]["key"])
	return keys


static func has(night_number: int, key: String) -> bool:
	return key in active(night_number)


## Tonight's new memo, or "" if there isn't one.
static func new_tonight(night_number: int) -> String:
	var i := night_number - Night.LAST_NIGHT - 1
	return LIST[i]["text"] if i >= 0 and i < LIST.size() else ""


static func has_finale(night_number: int) -> bool:
	return night_number == Night.LAST_NIGHT \
			or (night_number > Night.LAST_NIGHT and (night_number - Night.LAST_NIGHT) % FINALE_EVERY == 0)
