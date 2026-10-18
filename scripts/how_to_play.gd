extends CanvasLayer
## The menu's "How to play" page: the goal, a night step by step, logging, staying alive,
## the vending machine and the controls.

const PAGES := [
	["The job", "You're a night security guard at Westfield High School, alone or with up to three friends. Survive nine nights, midnight to 6 AM. Each night pays: 100 for clocking out in the morning, more for every odd thing you spot and log. Points buy gear at the guard room's vending machine.\n\nIf everyone is caught, you go back to the last checkpoint (night 1, 4 or 7) with your gear and half your points. On Hardcore, it's back to night 1 with nothing."],
	["A night, step by step", "1. You arrive at the front gate. Walk through the front doors; the guard room is on the right of the lobby.\n2. Clock in at the time clock ({use}, then type your badge number). When the whole team has, the lights go out.\n3. Sit at a desk ({use} on a chair) to watch the cameras, and go out to punch the stations on tonight's round.\n4. At 6 AM the lights come back. Clock out at the time clock to get paid."],
	["Logging what you see", "Press {clip} for your clipboard. Pick the area and what you saw:\n• Moved object: something isn't where it belongs.\n• Missing object: something that's normally there is gone.\n• Extra object: something that shouldn't be there at all.\n• Figure: a dark shape, standing still. It vanishes if you walk up to it. (From night 6 some step somewhere else when nobody's near.)\n• Noise (from night 5): a sound with nothing making it. Cameras don't pick these up; someone has to be there to hear it.\n• Monster: something that moves and comes after people.\n\nCorrect logs pay +25 to whoever logs it first; a teammate who saw it too (there, or with its camera already on their monitors) gets +10 for confirming it. Spotted something? Call it out ({ping} marks a spot, or flags a camera at the desk): if a teammate logs it within a minute, you get +15 too. Wrong guesses cost 10, so learn what's normal (the real night cleaner leaves a yellow WET FLOOR sign wherever they've mopped: that's just cleaning).\n\nThe first time you log a monster correctly, it goes in your field guide (the button at the top of the clipboard): what it looks like and how to survive it. After that you can name it in a Monster log. Name it right for +25 more."],
	["Staying alive", "Every monster has its own rules, and its own way to beat it: some hate running, light or being watched; some only move when nobody's looking. Watch the cameras, read the messages, and you'll work them out.\n\nUntil night 7 the guard room is safe. After that, things come in: door kits from the vending machine help.\n\nA caught guard becomes a ghost and can still watch, and press {use} to leave a cold spot (a blue glow the living can see) to point things out, or press {item} to watch through a living teammate's eyes. Teammates can try to bring them back at a revive totem (a dice roll: it might let something out instead). Every guard caught costs the whole team 50 points."],
	["At the monitors", "Sit at a desk to watch the cameras. Full screen on a camera ({zoom}), you can:\n• {compare}: compare it with the photo taken just after midnight.\n• {ping}: flag it for the team (a message and a marker everyone can see).\n• {light}: set off its speaker. The monsters that hunt by sound (the Lunch Lady, the Librarian, the Hall Monitor) go to look. Once a minute.\n\nThe guard at the desk can steer the night for everyone out in the school."],
	["Rounds", "Every night comes with a round: a few punch stations around the school (amber lamps) that someone has to punch before 6 AM. Hold {use} at a station to punch it.\n\nEach punch pays +20 to whoever did it. Finish the whole round and everyone who clocks out gets +50. Every station still unpunched at 6 AM costs everyone 10, and counts against the team's work target.\n\nThe station's bell rings when you punch it, and things nearby hear it. Look before you punch."],
	["The work target", "From night 2 the district sets the team a work target, shown under the clock and on the guard room's notice board: points from correct logs, named monsters and punched stations. Clocking out doesn't count.\n\nMiss it and the whole team gets a write-up. Three write-ups and you're fired: back to the last checkpoint (night 1 on Hardcore). False reports count against it, and so does every station still unpunched at 6 AM. Sitting in the guard room all night isn't the job."],
	["Close calls", "The first time a monster you've never logged catches you, you're knocked out instead of caught: you wake in the guard room, shaken, and now you know its rule. It won't happen twice. Playing alone you also get one second wind a night: the first catch knocks you out instead (and costs 50 points).\n\nAfter each night the report lists what nobody logged and which monsters were out, with a camera's photo of every catch. Learn from it."],
	["Moods", "From night 5 a monster can come in out of sorts. A restless one is quicker and never stays put; a keen one notices you from further off; a drowsy one is slower and duller. Its rules never change, just how hard they bite. Log it correctly and you'll be told its mood, so log early."],
	["Marking", "Press {ping} to mark whatever you're looking at for the whole team: a marker in your colour, seen through walls, for 8 seconds. Mark a monster and it reads MONSTER! in red (but not the ones in disguise: you'll have to work those out). At a desk, {ping} flags the camera you're watching instead."],
	["Hiding", "Slatted cupboards stand around the school. Press {use} to climb in, and {use} again to climb out. Inside, nothing can find you, and whatever was chasing you loses you. Unless it saw you go in: then it pulls you out. Get out of sight first.\n\nHiding wears on your nerve. If it runs out while you're in there, you'll burst out screaming."],
	["Nerve", "Your nerve (bottom left) wears down in the dark, on your own, near monsters, and when a teammate is caught. It comes back in the lit guard room, near teammates, and with a thermos of coffee from the vending machine.\n\nLow nerve is dangerous: monsters notice you from further away, and you start hearing and seeing things that aren't there."],
	["Lockdown", "From night 6 an alarm can go off: LOCKDOWN. For 30 seconds every monster hunts the nearest guard it can reach, wherever they are. Get into a cupboard, get to the guard room (until night 7), or run: you're just faster than they are, but only for as long as your stamina lasts (the bar at the bottom of the screen). An energy drink lets you run without tiring for 30 seconds. Often a lockdown is a drill that follows one monster's rule, and the alarm says which: the Hall Monitor's (only guards who run or shout are hunted), the Lunch Lady's (freeze when they're near) or the Mascot's (nothing moves while it's watched). Under the clock it says what to do."],
	["The last bell", "The front gate is chained shut all shift. At 5 AM on the last night (night 9), the alarm goes and doesn't stop: every monster hunts, faster as six gets closer. The gate's padlock key turns up somewhere deep in the school, and the intercom says where. Fetch it ({use}) and carry it to the gate to open it, then get out into the street, where nothing can reach you. Whoever's still inside at 6 AM is caught. One guard out wins the run. If whoever has the key is caught, it lies where they fell."],
	["Power cuts", "From night 2 the power goes out now and then. The lights die, the cameras show NO POWER and the vending machine stops; only red emergency lights are left.\n\nSomeone has to go to the custodian's closet (the door across the main hallway from the lobby) and hold {use} on the breaker panel. Whoever resets it is paid like a correct log."],
	["The phone", "From night 3 the phone on the front office desk rings once or twice a night. Answer it ({use}) within about 35 seconds and a voice tells you where something is out of place right now: log it for easy points. Let it ring out, and the power goes. While it rings, anything that hunts by sound comes to see what the noise is: answering can be a gamble."],
	["Throwing things", "Cones, boxes, balls, books and more lie about the school. Press {use} to pick one up, and {throw} to throw it. Where it lands it clatters, and the monsters that hunt by sound go to look: a decoy.\n\nGhosts can knock things over too: look at one and press {use}."],
	["Bonus objectives", "From night 2, each night has one bonus objective for the whole team, shown under the clock: nobody runs all night, nobody raises their voice, log a number of things correctly, name a monster, finish the round before 3 AM, or nobody gets caught. Pull it off and everyone who clocks out gets +60 and +50 XP. Some can be failed partway through, and then it's gone for the night."],
	["Light switches and TVs", "Every room has a light switch just inside its door ({use}). Switch the lights on to search a room properly (standing in the light steadies your nerve, a little), or off to keep out of sight. The halls' lights are on a timer.\n\nMonsters put the lights out in rooms they pass through. If a room was lit on the cameras a minute ago and it's dark now, something has been in there. During a power cut the switches do nothing.\n\nThe old TVs on their carts in the classrooms work the same way: something passing one may switch it on, and it glows with snow until someone switches it off ({use})."],
	["Shift notes", "From night 3, every night comes with conditions, shown when the lights go out and on the guard room notice board: fog, a thunderstorm, faulty wiring, old flashlight batteries, a full moon, an inspector's visit and more. One a night at first, two from night 5. Each one makes the night harder and is worth +15% XP."],
	["Voice chat", "Hold {talk} to talk (or switch to an open mic in the Esc menu). Voices fade with distance, and only ghosts hear ghosts.\n\nMonsters hear you too, and louder carries further. The Lunch Lady hears even a whisper up close, the Librarian hates any talking near her stacks, and the Hall Monitor chases anyone shouting in the halls. Sometimes the only way to stay alive is to keep quiet.\n\nA walkie-talkie from the vending machine lets you talk to the team from anywhere (hold {radio}), but a call blares out of everyone else's radio, and monsters near them hear it. Sitting at a guard room desk you don't need one: hold {radio} there to call everyone over the base station (they'll need a walkie of their own to answer).\n\nSomething in the science wing learns your lines. If a teammate's voice comes from somewhere they shouldn't be, it isn't them. (Esc menu: untick \"May copy my voice\" to opt out. Nothing is recorded to disk.)"],
	["The vending machine", "Points buy things at the vending machine in the guard room: camera kits for the desks, doors for the guard room, motion sensors, glue traps, portable cameras, a walkie-talkie, an EMF reader, a better flashlight, energy drinks, coffee for your nerve, an air horn, a decoy radio that draws the sound-hunters away, and a box of donuts that makes the district forget a write-up. Some need a rank. What you buy drops in the tray for you (it's yours for 30 seconds). Pick it up and it goes on your hotbar along the bottom: your flashlight in slot 1, then up to four things. 1-5 or the mouse wheel picks a slot, and {item} uses it or puts it down. {drop} leaves the picked thing at your feet, or hands it to the teammate you're looking at. A heavy-duty flashlight replaces yours in slot 1. If you're caught, what you carry spills on the floor for the others (and comes back to you in the morning)."],
	["Ranks", "Every night you work earns XP, even a night where you're caught: more for clocking out, correct logs, naming monsters and punching stations. XP stays with you between runs.\n\nRanks: Trainee, Night Watch, Patrol Officer, Senior Guard, Shift Supervisor, Head of Security, Night Warden, Legend of Westfield. Some vending machine items need a rank, and your rank shows on your name tag. Ranks and some achievements also unlock hats: pick one on the menu, and everyone sees it.\n\nEach rank also unlocks a perk, a small edge you bring to work: pick one on the menu. Thermos (nerve wears down slower), Track star (more stamina), Spare batteries (a stronger flashlight), Handy (hold-{use} jobs take half as long), Low profile (monsters notice you from less far), Lookout (a built-in EMF reader), Cool head (hiding costs no nerve)."],
	["Daily shift", "Once a day there's a new daily shift: one night, exactly the same for everyone that day (the same night, conditions, round, bonus objective and monsters). Play it solo, or click Host today's daily to play it as a team: friends join as usual, and the team's score (everyone's pay) goes on a board for teams that size. You start with 250 points to spend; your score is that night's pay, and 0 if you're caught. Your best for the day and how many days in a row you've played are on the menu. It never touches your saved run."],
	["Overtime", "Survive the ninth night and the run is won. The host can then start a new run, or keep going into Overtime: night 10, 11 and on, with your points and gear, one more monster every night, and a new district memo each night that stays (moods on everything, the bell three times, three lockdowns...). Every third Overtime night ends with the last bell again. How far can you get? Your furthest night is on the Records screen."],
	["Grades", "Win a run and Grade 1 opens on the menu (under the difficulty). Win a run at a grade to open the next one, up to Grade 5. Each grade adds to the ones before it and is worth +20% XP:\n• Grade 1: moods from night 1, lockdowns from night 4.\n• Grade 2: false reports and wrong names cost double.\n• Grade 3: fired at two write-ups; checkpoints only at nights 1 and 5.\n• Grade 4: everything moves 10% faster.\n• Grade 5: no second wind and no revive totems."],
	["Difficulty", "Difficulty sets how much of the school is open. 1 is the main building. 2 adds the classroom wing, 3 the science wing too, each with its own monsters and cameras. Auto grows with the run: alone, the classroom wing opens on night 4 and the science wing on night 7; bigger teams start bigger."],
	["Controls", "WASD move · Shift run (it tires you out) · Mouse look · F or left click flashlight · 1-5 or mouse wheel hotbar slot · E use (hold it on punch stations and the breaker; E on clutter to pick it up) · right click throw · Tab clipboard and field guide · G use the hotbar slot · X put it down or hand it over · V push to talk · B walkie-talkie · Esc menu (keys can be changed there) · F11 fullscreen\n\nAt a desk: A / D change a monitor's camera · Space or click for full screen · 1-4 a monitor full screen · R compare with tonight's photo · Q flag the camera for the team · F (full screen) set off its speaker · S stand up\n\nAs a ghost: E leave a cold spot, knock over the clutter you're looking at, or flick a light switch you're next to · G watch through a teammate's eyes"],
]

## Topics about things that start later in a run: shown as "from night N" until this player has
## got that far (their furthest night), so the guide teases what's coming instead of front-loading it.
const FROM_NIGHT := {
	"The work target": 2, "Power cuts": 2, "Bonus objectives": 2, "The phone": 3, "Shift notes": 3,
	"Moods": 5, "Lockdown": 6, "The last bell": 9, "Overtime": 9, "Grades": 9,
}

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
		if _locked(index):
			topic.text += "  (night %d)" % FROM_NIGHT[PAGES[index][0]]
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
	for i in _topics.size():
		_topics[i].modulate = Color(1.0, 0.9, 0.6) if i == index else Color(1, 1, 1, 0.45 if _locked(i) else 0.8)
	if _locked(index):
		_body.text = "Something for later: this starts on night %d. Get that far and it'll be explained here." % FROM_NIGHT[PAGES[index][0]]
		return
	_body.text = Controls.fill(PAGES[index][1]) if PAGES[index][0] != "Controls" else _controls_text()


## A topic about a night this player hasn't reached yet.
func _locked(index: int) -> bool:
	return int(FROM_NIGHT.get(PAGES[index][0], 0)) > Career.best_night() + 1


## The Controls page, built from the player's own keys.
func _controls_text() -> String:
	var k := func(action: String) -> String: return Controls.key_name(action)
	return ("{move} move · {run} run (it tires you out) · {look} look · {light} or left click flashlight · 1-5 or mouse wheel hotbar slot · {use} use (hold it on punch stations and the breaker; {use} on clutter to pick it up) · {throw} throw · {clip} clipboard and field guide · {item} use the hotbar slot · {drop} put it down or hand it over · {ping} mark a spot · {talk} push to talk · {radio} walkie-talkie · Esc menu (keys can be changed there) · F11 fullscreen\n\n"
		+ "At a desk: {left} / {right} change a monitor's camera · {zoom} or click for full screen · 1-4 a monitor full screen · {compare} compare with tonight's photo · {ping} flag the camera · {light} its speaker · {back} stand up\n\n"
		+ "As a ghost: {use} leave a cold spot, knock over clutter you're looking at, or flick a light switch you're next to · {item} watch through a teammate's eyes\n\n"
		+ "A controller works too: the prompts switch to its buttons when you use it.").format({
			"move": "Left stick" if Controls.using_pad else "%s%s%s%s" % [k.call("move_forward"), k.call("move_left"), k.call("move_back"), k.call("move_right")],
			"look": "Right stick" if Controls.using_pad else "Mouse",
			"run": k.call("sprint"), "light": k.call("flashlight"), "use": k.call("interact"), "clip": k.call("clipboard"),
			"item": k.call("use_item"), "throw": k.call("throw"), "drop": k.call("drop_item"), "ping": k.call("ping"), "talk": k.call("push_to_talk"), "radio": k.call("radio_talk"),
			"left": k.call("move_left"), "right": k.call("move_right"), "zoom": k.call("zoom"), "compare": k.call("compare"),
			"back": k.call("move_back")})


func close() -> void:
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()
