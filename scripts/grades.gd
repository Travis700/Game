class_name Grades
extends RefCounted
## Grades: harder runs, unlocked one at a time by winning a run at the grade before. Each adds
## to the ones below it and is worth +20% XP. A crew's grade shows on the clock all night.

const LIST: Array[Dictionary] = [
	{"name": "Grade 1", "text": "Monsters have moods from night 1, and lockdowns start on night 4."},
	{"name": "Grade 2", "text": "Mistakes cost double: false reports -20, wrong names -20."},
	{"name": "Grade 3", "text": "Two write-ups and you're fired, and the only checkpoints are nights 1 and 5."},
	{"name": "Grade 4", "text": "Everything in the school moves 10% faster."},
	{"name": "Grade 5", "text": "No second wind, and no revive totems. Get caught and you stay caught."},
]
const MAX := 5
const XP_PER_GRADE := 0.2
const SPEED := 1.1


## The highest grade this player can pick: one above the best they've won (0 = none yet).
static func unlocked() -> int:
	return clampi(Career.best_grade() + 1, 0, MAX)


static func title(grade: int) -> String:
	return LIST[grade - 1]["name"] if grade >= 1 and grade <= MAX else ""


## Everything this grade adds, one line per grade up to it.
static func describe(grade: int) -> String:
	var lines: Array[String] = []
	for i in clampi(grade, 0, MAX):
		lines.append("%s: %s" % [LIST[i]["name"], LIST[i]["text"]])
	return "\n".join(lines)
