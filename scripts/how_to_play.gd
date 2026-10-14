extends CanvasLayer
## The menu's "How to play" page: the goal, a night step by step, logging, staying alive,
## the vending machine and the controls.

const PAGES := [
	["The job", "You're a night security guard at Westfield High School, alone or with up to three friends. Survive nine nights, midnight to 6 AM. Each night pays: 100 for clocking out in the morning, more for every odd thing you spot and log. Points buy gear at the guard room's vending machine.\n\nIf everyone is caught, the run starts again from night 1."],
	["A night, step by step", "1. You arrive at the front gate. Walk through the front doors; the guard room is on the right of the lobby.\n2. Clock in at the time clock (E, then type your badge number). When the whole team has, the lights go out.\n3. Sit at a desk (E on a chair) to watch the cameras, and go out to punch the stations on tonight's round.\n4. At 6 AM the lights come back. Clock out at the time clock to get paid."],
	["Rounds", "Every night comes with a round: a few punch stations around the school (amber lamps) that someone has to punch before 6 AM. Hold E at a station to punch it.\n\nEach punch pays +20 to whoever did it. Finish the whole round and everyone who clocks out gets +50. Every station still unpunched at 6 AM costs everyone 10.\n\nThe station's bell rings when you punch it, and things nearby hear it. Look before you punch."],
	["Bonus objectives", "Each night has one bonus objective for the whole team, shown under the clock: nobody runs all night, nobody raises their voice, log a number of things correctly, name a monster, finish the round before 3 AM, or nobody gets caught. Pull it off and everyone who clocks out gets +60 and +50 XP. Some can be failed partway through, and then it's gone for the night."],
	["Shift notes", "From night 2, every night comes with conditions, shown when the lights go out and under the clock: fog, faulty wiring, old flashlight batteries, a full moon, an inspector's visit and more. One a night at first, two from night 5. Each one makes the night harder and is worth +15% XP."],
	["Power cuts", "From night 2 the power goes out now and then. The lights die, the cameras show NO POWER and the vending machine stops; only red emergency lights are left.\n\nSomeone has to go to the custodian's closet (the door across the main hallway from the lobby) and hold E on the breaker panel. Whoever resets it is paid like a correct log."],
	["Logging what you see", "Press Tab for your clipboard. Pick the area and what you saw:\n• Moved object: something isn't where it belongs.\n• Missing object: something that's normally there is gone.\n• Extra object: something that shouldn't be there at all.\n• Figure: a still, dark shape. It vanishes if you walk up to it.\n• Monster: something that moves and comes after people.\n\nCorrect logs pay +25. Wrong guesses cost 10, so learn what's normal (the real night cleaner moves things too).\n\nThe first time you log a monster correctly, it goes in your field guide (the button at the top of the clipboard): what it looks like and how to survive it. After that you can name it in a Monster log. Name it right for +25 more."],
	["Staying alive", "Every monster has its own rules, and its own way to beat it: some hate running, light or being watched; some only move when nobody's looking. Watch the cameras, read the messages, and you'll work them out.\n\nUntil night 7 the guard room is safe. After that, things come in: door kits from the vending machine help.\n\nA caught guard becomes a ghost and can still watch. Teammates can try to bring them back at a revive totem (a dice roll: it might let something out instead). Every guard caught costs the whole team 50 points."],
	["Voice chat", "Hold V to talk (or switch to an open mic in the Esc menu). Voices fade with distance, and only ghosts hear ghosts.\n\nMonsters hear you too, and louder carries further. The Lunch Lady hears even a whisper up close, the Librarian hates any talking near her stacks, and the Hall Monitor chases anyone shouting in the halls. Sometimes the only way to stay alive is to keep quiet.\n\nA walkie-talkie from the vending machine lets you talk to the team from anywhere (hold B), but a call blares out of everyone else's radio, and monsters near them hear it.\n\nSomething in the science wing learns your lines. If a teammate's voice comes from somewhere they shouldn't be, it isn't them. (Esc menu: untick \"May copy my voice\" to opt out. Nothing is recorded to disk.)"],
	["Ranks", "Every night you work earns XP, even a night where you're caught: more for clocking out, correct logs, naming monsters and punching stations. XP stays with you between runs.\n\nRanks: Trainee, Night Watch, Patrol Officer, Senior Guard, Shift Supervisor, Head of Security, Night Warden, Legend of Westfield. Some vending machine items need a rank, and your rank shows on your name tag."],
	["Difficulty", "Difficulty sets how much of the school is open. 1 is the main building. 2 adds the classroom wing, 3 the science wing too, each with its own monsters and cameras. Auto picks one level per guard."],
	["Controls", "WASD move · Shift run · Mouse look · F flashlight · E use · Tab clipboard · G use the item you're carrying · V push to talk · B walkie-talkie · Esc menu · F11 fullscreen\n\nAt a desk: A / D change a monitor's camera · Space or click for full screen · 1-4 a monitor full screen · S stand up"],
]

signal closed


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
	column.custom_minimum_size = Vector2(760, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 620)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var pages := VBoxContainer.new()
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pages.add_theme_constant_override("separation", 18)
	scroll.add_child(pages)
	for page: Array in PAGES:
		var heading := Label.new()
		heading.text = page[0]
		heading.add_theme_font_size_override("font_size", 24)
		heading.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
		pages.add_child(heading)
		var body := Label.new()
		body.text = page[1]
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(720, 0)
		body.add_theme_font_size_override("font_size", 17)
		pages.add_child(body)

	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(0, 48)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(close)
	column.add_child(back)


func open() -> void:
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
