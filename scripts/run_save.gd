class_name RunSave
## The host's saved run: which night is next, the difficulty, everyone's points (by badge
## number, so they come back when the same guards play again) and the guard room upgrades.

const PATH := "user://run.json"


## Saves and settings used to live in Godot's default folder ("app_userdata/Night Shift"); the
## game now has its own ("NightShift"). Copies anything over that isn't there yet, once.
static func migrate_old_saves() -> void:
	var old_dir := OS.get_data_dir().path_join("Godot/app_userdata/Night Shift")
	if not DirAccess.dir_exists_absolute(old_dir):
		return
	for file: String in ["profile.cfg", "controls.cfg", "run.json", "career.cfg"]:
		var from := old_dir.path_join(file)
		var to := "user://" + file
		if FileAccess.file_exists(from) and not FileAccess.file_exists(to):
			DirAccess.copy_absolute(from, ProjectSettings.globalize_path(to))


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
