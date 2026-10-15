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
		"lore": "Sept 3. First week. A kid with a sash told me to walk, not run. At 3 in the morning. When I turned round the hall was empty.",
	},
	"Mascot": {
		"name": "the Mascot", "where": "Gym",
		"signs": "The bulldog costume that should be on its stand by the gym doors.",
		"rule": "It only moves while nobody is watching it. Keep it on a monitor, or keep your eyes on it.",
		"rumour": "The school mascot never seems to be quite where they left it.",
		"lore": "Sept 9. Somebody keeps moving the bulldog. I put a sticker on its foot by the stand. Next night the sticker was on the gym door, two metres up.",
	},
	"LunchLady": {
		"name": "the Lunch Lady", "where": "Cafeteria and kitchen",
		"signs": "Humming to herself as she wanders between the tables.",
		"rule": "She's blind and hunts by sound. Don't run near her, and don't talk. Standing still is silent.",
		"rumour": "Someone is still humming in the cafeteria after closing.",
		"lore": "Sept 14. Humming in the cafeteria. I said hello. The humming stopped, and I heard her turn towards me. I didn't say anything else.",
	},
	"Lockers": {
		"name": "the Locker Thing", "where": "Main hallway lockers",
		"signs": "Locker doors swing open one at a time, with a faint red glow inside. Watch the hallway cameras.",
		"rule": "Never walk past an open locker. Press E on it to shut it first.",
		"rumour": "Some of the hallway lockers don't stay shut.",
		"lore": "Sept 20. Locker 113 was open again. I shut it. Locker 114 was open behind me. I shut that one too. I don't open lockers any more.",
	},
	"Principal": {
		"name": "the Principal", "where": "Front office",
		"signs": "A voice on the intercom calling a guard to the office.",
		"rule": "When you're called, go to the front office before time runs out, or it comes to find you.",
		"rumour": "The intercom still works. Someone still uses it.",
		"lore": "Oct 2. The intercom called me to the office. Principal Danvers retired in 1987. I went anyway. Better than the alternative.",
	},
	"OtherCleaner": {
		"name": "the Other Cleaner", "where": "Anywhere the cleaner goes",
		"signs": "EMF 5. Looks just like the night cleaner, but it has no cart, never puts a WET FLOOR sign down, and its head sits wrong. Your heart races near it.",
		"rule": "Don't get close. Log it as a Monster where you see it and it leaves.",
		"rumour": "The night cleaner has been seen in two places at once.",
		"lore": "Oct 5. Waved at Gus on camera 4. Gus was standing next to me. He doesn't know I saw.",
	},
	"Student": {
		"name": "the Student", "where": "Main hallway",
		"signs": "A kid who says they're locked in. Real kids show up on the cameras; it doesn't. And your heart races near the fake one.",
		"rule": "Check the cameras before you follow. If they're not on screen, don't go with them.",
		"rumour": "A student keeps getting locked in after hours.",
		"lore": "Oct 11. A kid asked me to walk him out. I checked the cameras first. He wasn't on any of them. He was very patient about it.",
	},
	"SchoolGhost": {
		"name": "the Ghost", "where": "Anywhere",
		"signs": "EMF 5. Invisible to the eye. Only spectral monitors show it. Cameras it passes lose signal.",
		"rule": "Fit a spectral camera upgrade, and move away from the cameras that are cutting out.",
		"rumour": "An old guard still clocks in. The time clock remembers.",
		"lore": "Oct 17. Camera 2 went to snow and came back. The time clock printed a card with my name on it. I hadn't clocked in yet.",
	},
	"Substitute": {
		"name": "the Substitute", "where": "Classroom wing",
		"signs": "A teacher nobody hired, at the front of an empty classroom.",
		"rule": "When it calls your name, look at it and press E to answer \"Here!\" in time.",
		"rumour": "A class is still being taught in the classroom wing.",
		"lore": "Oct 23. Room 101 had a lesson on. Twenty empty chairs, one teacher, my name on the register. I answered. Seemed polite.",
	},
	"Librarian": {
		"name": "the Librarian", "where": "Library and West Hall",
		"signs": "Hunched and long-necked, shelving books nobody borrowed.",
		"rule": "No light and no noise near it: flashlight off, walk, don't talk.",
		"rumour": "The library's books get put back overnight.",
		"lore": "Oct 30. The library wants it quiet. I took my boots off and walked the stacks in socks. The books were back on the shelves by morning.",
	},
	"Nurse": {
		"name": "the Nurse", "where": "Classroom wing",
		"signs": "White uniform and a mask, with a heart monitor's beep following her.",
		"rule": "She comes for guards on their own. Stay within a few metres of a teammate, or keep moving.",
		"rumour": "Someone is doing rounds in the nurse's office.",
		"lore": "Nov 4. Never do the west wing alone. That beeping only starts when you're on your own. Gus won't come with me any more.",
	},
	"CrossingGuard": {
		"name": "the Crossing Guard", "where": "Science wing and east main hall",
		"signs": "An orange vest and a STOP sign. A whistle before the sign goes up.",
		"rule": "While the sign is up, don't move. When it comes down, go.",
		"rumour": "Someone is directing traffic in the halls.",
		"lore": "Nov 8. STOP sign in the science hall. I stopped. Something went past me very close. I didn't look. I'm getting good at not looking.",
	},
	"SelfPortrait": {
		"name": "the Self-Portrait", "where": "Art room",
		"signs": "The covered canvas at the front of the art room paints a guard, stage by stage.",
		"rule": "Before it's finished, go to the art room and turn the canvas to the wall (E).",
		"rumour": "A painting in the art room is coming along nicely.",
		"lore": "Nov 15. There's a painting of me in the art room. It's very good. It's nearly finished. I turned it round.",
	},
	"Specimen": {
		"name": "the Specimen", "where": "Science lab",
		"signs": "EMF 5. Pale, low to the ground, too many legs. Its jar in the lab is empty.",
		"rule": "It hates light. Catch it in your flashlight beam and it flees into the ceiling.",
		"rumour": "Something in the science lab's big jar has been moving.",
		"lore": "Nov 21. The big jar in the lab is empty. I keep my flashlight on now, even in the guard room.",
	},
	"Coach": {
		"name": "the Coach", "where": "Locker rooms and East Hall",
		"signs": "A tracksuit, a red cap and a whistle. Paces the locker rooms.",
		"rule": "When it whistles at you, RUN, and keep running until you're out of its sight. Walking or standing where it can see you is what gets you.",
		"rumour": "Somebody is still running practice in the locker rooms.",
		"lore": "Nov 27. A whistle in the locker room. HUSTLE. I ran until my lungs burned. It watched me the whole way, like it was proud.",
	},
	"Twin": {
		"name": "the Twins", "where": "Classroom wing",
		"signs": "Two girls in matching dresses, one in Room 101 and one in Room 102. A giggle when they move.",
		"rule": "They only move when neither is watched. Keep one of them on a monitor, or in sight, at all times.",
		"rumour": "Two girls are waiting in the classrooms. They never come one at a time.",
		"lore": "Dec 2. Two girls in 101 and 102. Same dress. I keep one on the monitor at all times. I don't know what happens if I don't, and I'm not finding out.",
	},
	"Photographer": {
		"name": "the Photographer", "where": "Main building",
		"signs": "An old flash camera where its face should be. A high whine as the flash charges.",
		"rule": "Don't look at it when you hear the whine. Turn away or get out of sight, or it blinds you and comes.",
		"rumour": "Someone is still taking yearbook pictures, long after the yearbook stopped.",
		"lore": "Dec 8. Flash on the stairs. I saw spots for an hour. When they cleared, there were two of me in the corner of my eye.",
	},
	"Understudy": {
		"name": "the Understudy", "where": "Science wing",
		"signs": "EMF 5. An extra guard with no face behind the visor, following one of you around. It talks in your teammates' voices.",
		"rule": "Keep moving. Spot the extra guard on the cameras and log it as a Monster.",
		"rumour": "Count the guards on the cameras. Then count them again.",
		"lore": "Dec 14. Count the guards on camera. Gus, me, and one more. It had my voice tonight. It's practising.",
	},
}


## The last page of R. Hale's notebook, shown once the whole guide is filled in.
const LAST_ENTRY := "Dec 20. I've written all of them down. Every rule. Whoever has this job next: you'll need them. I'm going to stay on a little longer. Somebody has to clock in. If the time clock prints my name, don't worry. I'm still doing my rounds. Walk, don't run. Keep one of them on the monitor. And get out through the gate before the bell."


## The kind of monster a "caught by ..." name belongs to (e.g. "the Lunch Lady" -> "LunchLady"),
## or "" if it isn't one in the guide.
static func kind_for_name(caught_by: String) -> String:
	if caught_by == "something you couldn't see":
		return "SchoolGhost"
	if caught_by == "something in the lockers":
		return "Lockers"
	for kind: String in ENTRIES:
		if (ENTRIES[kind]["name"] as String).to_lower() == caught_by.to_lower():
			return kind
	return ""


## What to tell a guard who was just caught by this: the rule, if they know the monster.
static func caught_tip(caught_by: String) -> String:
	var kind := kind_for_name(caught_by)
	if kind == "":
		return ""
	if kind in discovered():
		return "Remember: " + ENTRIES[kind]["rule"]
	return "Log it correctly next time and its page in your field guide will tell you how to survive it."


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
			var note := _text("From R. Hale's notebook: \"%s\"" % entry["lore"], 14, ink, width)
			note.modulate.a = 0.7
			page.add_child(note)
		else:
			var unknown := _text("???  ·  \"%s\"" % entry["rumour"], 16, ink, width)
			unknown.modulate.a = 0.6
			page.add_child(unknown)
	# Every page found: the last thing R. Hale wrote.
	if known.size() == ENTRIES.size():
		page.add_child(_text("R. Hale, employee #0451, last entry", 19, ink, width))
		page.add_child(_text(LAST_ENTRY, 15, ink, width))
	return page


static func _text(text: String, size: int, ink: Color, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", ink)
	return label
