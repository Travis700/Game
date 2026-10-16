class_name Fonts
## The game's two typefaces beyond the default: a bold condensed one for big titles, and a
## typewriter for paperwork (the clipboard, notices, the notebook).

static var _cache: Dictionary = {}


## Big titles: the menu's NIGHT SHIFT, the night report.
static func title() -> Font:
	return _load("res://assets/fonts/BebasNeue.ttf")


## Typed paperwork.
static func typed() -> Font:
	return _load("res://assets/fonts/SpecialElite.ttf")


static func _load(path: String) -> Font:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
