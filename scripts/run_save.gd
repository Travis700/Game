class_name RunSave
## The host's saved run: which night is next, the difficulty, everyone's points (by badge
## number, so they come back when the same guards play again) and the guard room upgrades.

const PATH := "user://run.json"


static func exists() -> bool:
	return FileAccess.file_exists(PATH)


## The saved run, or an empty dictionary if there isn't one (or it can't be read).
static func read() -> Dictionary:
	if not exists():
		return {}
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


static func write(data: Dictionary) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))


static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


## "Night 3 · difficulty 2" for the menu.
static func describe(data: Dictionary) -> String:
	var difficulty := int(data.get("difficulty", 0))
	return "Night %d · %s" % [int(data.get("night", 1)), "auto difficulty" if difficulty == 0 else "difficulty %d" % difficulty]
