extends CanvasLayer
## The menu's "How to play" page: the goal, a night step by step, logging, staying alive,
## the vending machine and the controls.

const PAGES := [
	["The job", "You're a night security guard at Westfield High School, alone or with up to three friends. Survive nine nights, midnight to 6 AM. Each night pays: 100 for clocking out in the morning, more for every odd thing you spot and log. Points buy gear at the guard room's vending machine.\n\nIf everyone is caught, you go back to the last checkpoint (night 1, 4 or 7) with your gear and half your points. On Hardcore, it's back to night 1 with nothing."],
	["A night, step by step", "1. You arrive at the front gate. Walk through the front doors; the guard room is on the right of the lobby.\n2. Clock in at the time clock (E, then type your badge number). When the whole team has, the lights go out.\n3. Sit at a desk (E on a chair) to watch the cameras, and go out to punch the stations on tonight's round.\n4. At 6 AM the lights come back. Clock out at the time clock to get paid."],
	["Logging what you see", "Press Tab for your clipboard. Pick the area and what you saw:\n• Moved object: something isn't where it belongs.\n• Missing object: something that's normally there is gone.\n• Extra object: something that shouldn't be there at all.\n• Figure: a still, dark shape. It vanishes if you walk up to it.\n• Monster: something that moves and comes after people.\n\nCorrect logs pay +25 to whoever logs it first; a teammate confirming it afterwards gets +10. Wrong guesses cost 10, so learn what's normal (the real night cleaner moves things too).\n\nThe first time you log a monster correctly, it goes in your field guide (the button at the top of the clipboard): what it looks like and how to survive it. After that you can name it in a Monster log. Name it right for +25 more."],
	["Staying alive", "Every monster has its own rules, and its own way to beat it: some hate running, light or being watched; some only move when nobody's looking. Watch the cameras, read the messages, and you'll work them out.\n\nUntil night 7 the guard room is safe. After that, things come in: door kits from the vending machine help.\n\nA caught guard becomes a ghost and can still watch, and press E to leave a cold spot (a blue glow the living can see) to point things out, or press G to watch through a living teammate's eyes. Teammates can try to bring them back at a revive totem (a dice roll: it might let something out instead). Every guard caught costs the whole team 50 points."],
	["At the monitors", "Sit at a desk to watch the cameras. Full screen on a camera (Space), you can:\n• R: compare it with the photo taken just after midnight.\n• Q: flag it for the team (a message and a marker everyone can see).\n• F: set off its speaker. The monsters that hunt by sound (the Lunch Lady, the Librarian, the Hall Monitor) go to look. Once a minute.\n\nThe guard at the desk can steer the night for everyone out in the school."],
	["Rounds", "Every night comes with a round: a few punch stations around the school (amber lamps) that someone has to punch before 6 AM. Hold E at a station to punch it.\n\nEach punch pays +20 to whoever did it. Finish the whole round and everyone who clocks out gets +50. Every station still unpunched at 6 AM costs everyone 10.\n\nThe station's bell rings when you punch it, and things nearby hear it. Look before you punch."],
	["The work target", "From night 2 the district sets the team a work target, shown under the clock and on the guard room's notice board: points from correct logs, named monsters and punched stations. Clocking out doesn't count.\n\nMiss it and the whole team gets a write-up. Three write-ups and you're fired: back to the last checkpoint (night 1 on Hardcore). Sitting in the guard room all night isn't the job."],
	["Hiding", "Slatted cupboards stand around the school. Press E to climb in, and E again to climb out. Inside, nothing can find you, and whatever was chasing you loses you. Unless it saw you go in: then it pulls you out. Get out of sight first.\n\nHiding wears on your nerve. If it runs out while you're in there, you'll burst out screaming."],
	["Nerve", "Your nerve (bottom left) wears down in the dark, on your own, near monsters, and when a teammate is caught. It comes back in the lit guard room, near teammates, and with a thermos of coffee from the vending machine.\n\nLow nerve is dangerous: monsters notice you from further away, and you start hearing and seeing things that aren't there."],
	["Lockdown", "From night 6 an alarm can go off: LOCKDOWN. For 30 seconds every monster hunts the nearest guard it can reach, wherever they are. Get into a cupboard, get to the guard room (until night 7), or run: you're just faster than they are, but only for as long as your stamina lasts (the bar at the bottom of the screen). An energy drink lets you run without tiring for 30 seconds."],
	["The last bell", "The front gate is chained shut all shift. At 5 AM on the last night (night 9), the alarm goes and doesn't stop: every monster hunts, faster as six gets closer. The gate's padlock key turns up somewhere deep in the school, and the intercom says where. Fetch it (E) and carry it to the gate to open it, then get out into the street, where nothing can reach you. Whoever's still inside at 6 AM is caught. One guard out wins the run. If whoever has the key is caught, it lies where they fell."],
	["Power cuts", "From night 2 the power goes out now and then. The lights die, the cameras show NO POWER and the vending machine stops; only red emergency lights are left.\n\nSomeone has to go to the custodian's closet (the door across the main hallway from the lobby) and hold E on the breaker panel. Whoever resets it is paid like a correct log."],
	["The phone", "From night 2 the phone on the front office desk rings once or twice a night. Answer it (E) within about 35 seconds and a voice tells you where something is out of place right now: log it for easy points. Let it ring out, and the power goes."],
	["Throwing things", "Cones, boxes, balls, books and more lie about the school. Press E to pick one up, and E again (looking at nothing in particular) to throw it. Where it lands it clatters, and the monsters that hunt by sound go to look: a decoy.\n\nGhosts can knock things over too: look at one and press E."],
	["Bonus objectives", "Each night has one bonus objective for the whole team, shown under the clock: nobody runs all night, nobody raises their voice, log a number of things correctly, name a monster, finish the round before 3 AM, or nobody gets caught. Pull it off and everyone who clocks out gets +60 and +50 XP. Some can be failed partway through, and then it's gone for the night."],
	["Shift notes", "From night 2, every night comes with conditions, shown when the lights go out and under the clock: fog, faulty wiring, old flashlight batteries, a full moon, an inspector's visit and more. One a night at first, two from night 5. Each one makes the night harder and is worth +15% XP."],
	["Voice chat", "Hold V to talk (or switch to an open mic in the Esc menu). Voices fade with distance, and only ghosts hear ghosts.\n\nMonsters hear you too, and louder carries further. The Lunch Lady hears even a whisper up close, the Librarian hates any talking near her stacks, and the Hall Monitor chases anyone shouting in the halls. Sometimes the only way to stay alive is to keep quiet.\n\nA walkie-talkie from the vending machine lets you talk to the team from anywhere (hold B), but a call blares out of everyone else's radio, and monsters near them hear it.\n\nSomething in the science wing learns your lines. If a teammate's voice comes from somewhere they shouldn't be, it isn't them. (Esc menu: untick \"May copy my voice\" to opt out. Nothing is recorded to disk.)"],
	["Ranks", "Every night you work earns XP, even a night where you're caught: more for clocking out, correct logs, naming monsters and punching stations. XP stays with you between runs.\n\nRanks: Trainee, Night Watch, Patrol Officer, Senior Guard, Shift Supervisor, Head of Security, Night Warden, Legend of Westfield. Some vending machine items need a rank, and your rank shows on your name tag. Ranks and some achievements also unlock hats: pick one on the menu, and everyone sees it.\n\nEach rank also unlocks a perk, a small edge you bring to work: pick one on the menu. Thermos (nerve wears down slower), Track star (more stamina), Spare batteries (a stronger flashlight), Handy (hold-E jobs take half as long), Low profile (monsters notice you from less far), Lookout (a built-in EMF reader), Cool head (hiding costs no nerve)."],
	["Daily shift", "Once a day there's a new daily shift: one night, played solo, exactly the same for everyone that day (the same night, conditions, round, bonus objective and monsters). You start with 250 points to spend; your score is that night's pay, and 0 if you're caught. Your best for the day and how many days in a row you've played are on the menu. It never touches your saved run."],
	["Overtime", "Survive the ninth night and the run is won. The host can then start a new run, or keep going into Overtime: night 10, 11 and on, with your points and gear, one more monster and one more shift note every night. How far can you get? Your furthest night is on the Records screen."],
	["Difficulty", "Difficulty sets how much of the school is open. 1 is the main building. 2 adds the classroom wing, 3 the science wing too, each with its own monsters and cameras. Auto picks one level per guard."],
	["Controls", "WASD move · Shift run (it tires you out) · Mouse look · F flashlight · E use (hold it on punch stations and the breaker; E on clutter to pick it up, E again to throw) · Tab clipboard and field guide · G use the item you're carrying · V push to talk · B walkie-talkie · Esc menu (keys can be changed there) · F11 fullscreen\n\nAt a desk: A / D change a monitor's camera · Space or click for full screen · 1-4 a monitor full screen · R compare with tonight's photo · Q flag the camera for the team · F (full screen) set off its speaker · S stand up\n\nAs a ghost: E leave a cold spot, or knock over the clutter you're looking at · G watch through a teammate's eyes"],
]

signal closed

var _heading: Label
var _body: Label
var _topics: Array[Button] = []


func _ready() -> void:
	layer = 15
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.06, 1.0)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(960, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	# Topics down the left; the chosen one on the right.
	var split := HBoxContainer.new()
	split.add_theme_constant_override("separation", 24)
	column.add_child(split)
	var topics_scroll := ScrollContainer.new()
	topics_scroll.custom_minimum_size = Vector2(250, 600)
	topics_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(topics_scroll)
	var topics := VBoxContainer.new()
	topics.add_theme_constant_override("separation", 4)
	topics_scroll.add_child(topics)
	var page_scroll := ScrollContainer.new()
	page_scroll.custom_minimum_size = Vector2(680, 600)
	page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(page_scroll)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 14)
	page_scroll.add_child(page)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 28)
	_heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	page.add_child(_heading)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(660, 0)
	_body.add_theme_font_size_override("font_size", 18)
	page.add_child(_body)
	for index in PAGES.size():
		var topic := Button.new()
		topic.text = PAGES[index][0]
		topic.alignment = HORIZONTAL_ALIGNMENT_LEFT
		topic.custom_minimum_size = Vector2(230, 34)
		topic.pressed.connect(_show_page.bind(index))
		topic.focus_entered.connect(_show_page.bind(index))
		topics.add_child(topic)
		_topics.append(topic)
	_show_page(0)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	column.add_child(back)


func open() -> void:
	visible = true
	if not Input.get_connected_joypads().is_empty() and not _topics.is_empty():
		_topics[0].grab_focus.call_deferred()


func _show_page(index: int) -> void:
	_heading.text = PAGES[index][0]
	_body.text = PAGES[index][1]
	for i in _topics.size():
		_topics[i].modulate = Color(1.0, 0.9, 0.6) if i == index else Color(1, 1, 1, 0.8)


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
