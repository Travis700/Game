class_name FieldGuide
extends RefCounted
## The field guide: what's known about each monster. An entry fills in once you've logged that
## monster correctly (on any run); until then it's a rumour. Shown on the clipboard and the
## Records screen, and once a monster is in your guide you can name it in a Monster log
## for extra pay.

## By monster kind (the names Career uses): its name, where it lives, how to spot it, how to
## live through it, and the rumour shown before you've found it.
const ENTRIES := {
	"HallMonitor": {
		"name": "the Hall Monitor", "where": "Main hallway",
		"signs": "Tall and thin, with a sash and a clipboard. Walks the main hallway end to end.",
		"rule": "Walk, don't run, and keep your voice down. If it blows its whistle, break line of sight.",
		"rumour": "Something in the main hallway takes the rules very seriously.",
	},
	"Mascot": {
		"name": "the Mascot", "where": "Gym",
		"signs": "The bulldog costume that should be on its stand by the gym doors.",
		"rule": "It only moves while nobody is watching it. Keep it on a monitor, or keep your eyes on it.",
		"rumour": "The school mascot never seems to be quite where they left it.",
	},
	"LunchLady": {
		"name": "the Lunch Lady", "where": "Cafeteria and kitchen",
		"signs": "Humming to herself as she wanders between the tables.",
		"rule": "She's blind and hunts by sound. Don't run near her, and don't talk. Standing still is silent.",
		"rumour": "Someone is still humming in the cafeteria after closing.",
	},
	"Lockers": {
		"name": "the Locker Thing", "where": "Main hallway lockers",
		"signs": "Locker doors swing open one at a time. Watch the hallway cameras.",
		"rule": "Never walk past an open locker. Press E on it to shut it first.",
		"rumour": "Some of the hallway lockers don't stay shut.",
	},
	"Principal": {
		"name": "the Principal", "where": "Front office",
		"signs": "A voice on the intercom calling a guard to the office.",
		"rule": "When you're called, go to the front office before time runs out, or it comes to find you.",
		"rumour": "The intercom still works. Someone still uses it.",
	},
	"OtherCleaner": {
		"name": "the Other Cleaner", "where": "Anywhere the cleaner goes",
		"signs": "Looks just like the night cleaner, but it has no cart and its head sits wrong.",
		"rule": "Don't get close. Log it as a Monster where you see it and it leaves.",
		"rumour": "The night cleaner has been seen in two places at once.",
	},
	"Student": {
		"name": "the Student", "where": "Main hallway",
		"signs": "A kid who says they're locked in. Real kids show up on the cameras; it doesn't.",
		"rule": "Check the cameras before you follow. If they're not on screen, don't go with them.",
		"rumour": "A student keeps getting locked in after hours.",
	},
	"SchoolGhost": {
		"name": "the Ghost", "where": "Anywhere",
		"signs": "Invisible to the eye. Only spectral monitors show it. Cameras it passes lose signal.",
		"rule": "Fit a spectral camera upgrade, and move away from the cameras that are cutting out.",
		"rumour": "An old guard still clocks in. The time clock remembers.",
	},
	"Substitute": {
		"name": "the Substitute", "where": "Classroom wing",
		"signs": "A teacher nobody hired, at the front of an empty classroom.",
		"rule": "When it calls your name, look at it and press E to answer \"Here!\" in time.",
		"rumour": "A class is still being taught in the classroom wing.",
	},
	"Librarian": {
		"name": "the Librarian", "where": "Library and West Hall",
		"signs": "Hunched and long-necked, shelving books nobody borrowed.",
		"rule": "No light and no noise near it: flashlight off, walk, don't talk.",
		"rumour": "The library's books get put back overnight.",
	},
	"Nurse": {
		"name": "the Nurse", "where": "Classroom wing",
		"signs": "White uniform and a mask, with a heart monitor's beep following her.",
		"rule": "She comes for guards on their own. Stay within a few metres of a teammate, or keep moving.",
		"rumour": "Someone is doing rounds in the nurse's office.",
	},
	"CrossingGuard": {
		"name": "the Crossing Guard", "where": "Science wing and east main hall",
		"signs": "An orange vest and a STOP sign. A whistle before the sign goes up.",
		"rule": "While the sign is up, don't move. When it comes down, go.",
		"rumour": "Someone is directing traffic in the halls.",
	},
	"SelfPortrait": {
		"name": "the Self-Portrait", "where": "Art room",
		"signs": "The covered canvas at the front of the art room paints a guard, stage by stage.",
		"rule": "Before it's finished, go to the art room and turn the canvas to the wall (E).",
		"rumour": "A painting in the art room is coming along nicely.",
	},
	"Specimen": {
		"name": "the Specimen", "where": "Science lab",
		"signs": "Pale, low to the ground, too many legs. Its jar in the lab is empty.",
		"rule": "It hates light. Catch it in your flashlight beam and it flees into the ceiling.",
		"rumour": "Something in the science lab's big jar has been moving.",
	},
	"Photographer": {
		"name": "the Photographer", "where": "Main building",
		"signs": "An old flash camera where its face should be. A high whine as the flash charges.",
		"rule": "Don't look at it when you hear the whine. Turn away or get out of sight, or it blinds you and comes.",
		"rumour": "Someone is still taking yearbook pictures, long after the yearbook stopped.",
	},
	"Understudy": {
		"name": "the Understudy", "where": "Science wing",
		"signs": "An extra guard with no face behind the visor, following one of you around. It talks in your teammates' voices.",
		"rule": "Keep moving. Spot the extra guard on the cameras and log it as a Monster.",
		"rumour": "Count the guards on the cameras. Then count them again.",
	},
}


static func display_name(kind: String) -> String:
	return ENTRIES[kind]["name"] if ENTRIES.has(kind) else kind


## The monsters in this player's guide: the kinds they've logged correctly at least once.
static func discovered() -> Array[String]:
	var result: Array[String] = []
	var seen := Career.monsters_seen()
	for kind: String in ENTRIES:
		if kind in seen:
			result.append(kind)
	return result


## The guide as a list of labels, coloured `ink`. Undiscovered monsters show their rumour.
static func build_page(ink: Color, width: float) -> VBoxContainer:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	var known := discovered()
	var intro := _text("%d of %d monsters in your guide. Log a monster correctly to fill in its page; then you can name it in a Monster log for +%d more." % [
			known.size(), ENTRIES.size(), Night.NAME_POINTS], 15, ink, width)
	intro.modulate.a = 0.75
	page.add_child(intro)
	for kind: String in ENTRIES:
		var entry: Dictionary = ENTRIES[kind]
		if kind in known:
			page.add_child(_text("%s  ·  %s" % ["T" + entry["name"].substr(1), entry["where"]], 19, ink, width))
			page.add_child(_text("Signs: " + entry["signs"], 15, ink, width))
			page.add_child(_text("Survive: " + entry["rule"], 15, ink, width))
		else:
			var unknown := _text("???  ·  \"%s\"" % entry["rumour"], 16, ink, width)
			unknown.modulate.a = 0.6
			page.add_child(unknown)
	return page


static func _text(text: String, size: int, ink: Color, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	return label
