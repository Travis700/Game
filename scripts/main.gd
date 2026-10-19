extends Node3D
## Entry point. Builds the school, shows the start menu, and runs the session:
## solo, hosting or joining, spawning a guard for each player, and starting the night
## once every guard has clocked in.
##
## The host is in charge: it spawns guards, keeps the clock-in list and tells
## everyone when the night starts. In solo play your computer is the host.

const PlayerScene := preload("res://scenes/player.tscn")
const HUD := preload("res://scripts/hud.gd")
const Menu := preload("res://scripts/menu.gd")
const Clipboard := preload("res://scripts/clipboard.gd")
const Report := preload("res://scripts/report.gd")
const VendingUI := preload("res://scripts/vending_ui.gd")
const KeypadUI := preload("res://scripts/keypad_ui.gd")
const PauseMenu := preload("res://scripts/pause_menu.gd")
## Ghosts' cold spots: how often each ghost can leave one, and how long one lasts.
const GHOST_PING_EVERY := 4.0
const GHOST_PING_SECONDS := 6.0
## Marks: a living guard's "look here" for the team (Q), how often, and how long one shows.
const MARK_EVERY := 1.5
## Close calls (see _close_call): the nerve they cost, seconds before anything can come for the
## guard again, a solo second wind's cost, and where they wake up.
const CLOSE_CALL_NERVE := 40.0
const CLOSE_CALL_GRACE := 8.0
const SECOND_WIND_POINTS := 50
const CLOSE_CALL_WAKE := Vector3(13, 0.1, 16)
const MARK_SECONDS := 8.0
## How close a monster has to be to a mark for it to read "MONSTER!".
const MARK_MONSTER_RANGE := 2.5
## How long a flagged camera's marker shows.
const FLAG_SECONDS := 20.0
## Real seconds between camera speaker noises, per guard.
const LURE_COOLDOWN := 60.0
## Real seconds between the last guard being caught and the night's results.
const SCARE_SECONDS := 2.0

const PORT := 7777
const MAX_GUARDS := 4
## Where guards start each night: outside the gate, facing the school (north is -Z).
const SPAWN_POINT := Vector3(0, 0.1, 54)

## Shown on the menu after returning to it, e.g. "The host ended the session."
static var _menu_message := ""
## Set when training ends with "Start night 1": the menu comes back and goes straight into a solo night.
static var _play_after_reload := false

## Host: the password joiners must give ("" for none). Joiner: the password to send.
var _password := ""
## Host: the room code for this computer's address.
var _room_code := ""

var shift: Shift
var lighting: ShiftLighting
var hud: CanvasLayer
var menu: CanvasLayer
var players: Node3D
var cameras: SecurityCameras
var guard_room: GuardRoom
var anomalies: Anomalies
var night: Night
var clipboard: CanvasLayer
var school: SchoolBuilder
var director: MonsterDirector
var lockers: Lockers
var totems: Totems
var shop: Shop
var doors: GuardRoomDoors
var school_doors: SchoolDoors
var vending: CanvasLayer
var keypad: CanvasLayer
var ambience: Ambience
var voice: VoiceChat
var career: Career
var dread: Dread
var rounds: Rounds
var _siren: AudioStreamPlayer
var captions: Captions
## The teammate a ghost is watching through, or null.
var _spectating: Guard
## The notice board in the guard room: tonight's shift notes, bonus objective and round.
var _tonight_board: Label3D
var _board_timer := 0.0
## Who's clocked in so far tonight (every computer; sent by the host), for the briefing.
var _clocked_in_peers: Array[int] = []
## Host: when each guard can next use a camera speaker.
var _lure_ready: Dictionary = {}
var hiding: Hiding
var clutter: Clutter
var drawers: Drawers
var finale: Finale
## Host: when each ghost may next leave a cold spot.
var _ghost_ping_at: Dictionary = {}
## Host: the monster kinds each guard has had a close call with this run (badge -> kinds).
var _close_calls: Dictionary = {}
## Host: hosting today's daily for a team (set from the menu; the daily starts once hosting
## does), and the badges already given today's starting points.
var _team_daily := false
var _daily_paid: Dictionary = {}
## Host: a solo guard's second wind, once a night.
var _second_wind_used := false
## Host: badges of the guards who started tonight's shift, and of those who left it still alive
## (if they come back tonight, it counts as being caught: no dodging a catch by quitting).
var _shift_badges: Dictionary = {}
var _left_alive: Dictionary = {}
var power: Power
var light_switches: LightSwitches
var televisions: Televisions
var haunting: Haunting
var glare: Glare
var pause_menu: CanvasLayer
var spawner: MultiplayerSpawner
var _local_guard: Guard
var _mode := ""
## True once this player has clocked in for the coming night (before it starts).
var _clocked_in := false
## Behind the menu, the camera drifts between two views: [position, rotation, position, rotation].
const MENU_VIEW := [Vector3(-14.0, 2.3, 52.0), Vector3(-3, -22, 0), Vector3(-9.0, 2.5, 50.5), Vector3(-4, -28, 0)]
## Command-line test sessions (--host/--join) always use direct connections, even with Steam.
var _direct_only := false


func _ready() -> void:
	# (A ghost watching the cameras switches the world off behind the feed; a session left
	# that way would otherwise stay dark.)
	get_viewport().disable_3d = false
	# A daily shift seeds the random numbers; leaving it early mustn't make the next run predictable.
	randomize()
	add_to_group("game")
	var environment := _make_environment()

	school = SchoolBuilder.new()
	school.name = "School"
	add_child(school)
	var wing_doors := Node3D.new()
	wing_doors.name = "WingDoors"
	add_child(wing_doors)
	school.build_wing_doors(wing_doors)
	school_doors = SchoolDoors.new()
	school_doors.name = "SchoolDoors"
	add_child(school_doors)
	school_doors.build(school.doorways)

	shift = Shift.new()
	shift.name = "Shift"
	add_child(shift)

	lighting = ShiftLighting.new()
	lighting.name = "Lighting"
	lighting.environment = environment
	lighting.school = school
	add_child(lighting)
	lighting.apply_pre_shift()
	shift.started.connect(lighting.go_dark)
	shift.started.connect(func() -> void:
		_second_wind_used = false
		night.report.incidents.clear()
		if night.number == 1:
			_close_calls.clear()
		_left_alive.clear()
		night.late_joiners.clear()
		_shift_badges.clear()
		for guard: Guard in players.get_children():
			_shift_badges[guard.employee_number] = true)
	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	shift.started.connect(ambience.start)
	shift.morning_started.connect(ambience.stop)
	shift.morning_started.connect(_dawn_chorus)
	shift.started.connect(func() -> void: school.clock_machine.prompt = "Check time clock")
	shift.morning_started.connect(func() -> void: school.clock_machine.prompt = "Clock out")
	school.clock_machine.used.connect(_on_clock_machine_used)

	players = Node3D.new()
	players.name = "Players"
	add_child(players)
	spawner = MultiplayerSpawner.new()
	spawner.name = "PlayerSpawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players)
	spawner.spawn_function = _create_guard

	# A view of the floodlit school to sit behind the menu.
	var menu_camera := Camera3D.new()
	menu_camera.name = "MenuCamera"
	# From across the road, off to the west, so the school fills the right of the screen beside the
	# menu.
	menu_camera.position = MENU_VIEW[0]
	menu_camera.rotation_degrees = MENU_VIEW[1]
	add_child(menu_camera)
	menu_camera.current = true
	# Behind the menu: a slow, uneasy drift along the fence, as if someone's watching the school.
	var drift := menu_camera.create_tween().set_loops()
	drift.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(menu_camera, "position", MENU_VIEW[2], 24.0)
	drift.parallel().tween_property(menu_camera, "rotation_degrees", MENU_VIEW[3], 24.0)
	drift.tween_property(menu_camera, "position", MENU_VIEW[0], 24.0)
	drift.parallel().tween_property(menu_camera, "rotation_degrees", MENU_VIEW[1], 24.0)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.visible = false

	cameras = SecurityCameras.new()
	cameras.name = "Cameras"
	add_child(cameras)
	cameras.build(school.camera_spots)

	guard_room = GuardRoom.new()
	guard_room.name = "GuardRoom"
	add_child(guard_room)
	guard_room.build(school, cameras, hud)

	anomalies = Anomalies.new()
	anomalies.name = "Anomalies"
	anomalies.players = players
	add_child(anomalies)
	anomalies.build(school)

	clipboard = Clipboard.new()
	clipboard.name = "Clipboard"
	add_child(clipboard)
	clipboard.set_areas(anomalies.areas(1))
	clipboard.closed.connect(_on_ui_closed)

	lockers = Lockers.new()
	lockers.name = "Lockers"
	add_child(lockers)
	lockers.build(school.get_material("locker"), school.get_material("dark"))

	director = MonsterDirector.new()
	director.name = "Monsters"
	director.players = players
	director.guard_room = guard_room
	director.cameras = cameras
	director.anomalies = anomalies
	director.lockers = lockers
	director.school = school
	add_child(director)
	director.build()
	lockers.director = director
	director.guard_caught.connect(_on_guard_caught)
	director.message_for.connect(_tell)
	director.screen_flashed.connect(func(peer_id: int, color: Color, seconds: float) -> void:
		if peer_id == multiplayer.get_unique_id():
			_flash_screen(color, seconds)
		elif peer_id in multiplayer.get_peers():
			_flash_screen.rpc_id(peer_id, color, seconds))
	director.announcement.connect(func(text: String, sound: String) -> void: _announce.rpc(text, sound))
	director.camera_signal_changed.connect(func(index: int, working: bool) -> void: _camera_signal.rpc(index, working))
	director.bell_changed.connect(func(ringing: bool) -> void: _set_bell.rpc(ringing))
	director.summons_changed.connect(func(peer: int, seconds: float, held: bool) -> void: _show_summons.rpc(peer, seconds, held))
	director.lockdown_changed.connect(func(on: bool, rule: String) -> void: _set_lockdown.rpc(on, rule))
	school.bell_panel.used.connect(func(by: Node) -> void:
		if by != _local_guard or _local_guard.is_dead:
			return
		if multiplayer.is_server():
			_request_bell_off()
		else:
			_request_bell_off.rpc_id(1))

	voice = VoiceChat.new()
	voice.name = "Voice"
	voice.director = director
	voice.guard_room = guard_room
	director.voice = voice
	add_child(voice)

	dread = Dread.new()
	dread.name = "Dread"
	dread.director = director
	dread.lighting = lighting
	dread.hud = hud
	dread.players = players
	dread.shift = shift
	add_child(dread)

	career = Career.new()
	career.name = "Career"
	add_child(career)
	director.career = career

	totems = Totems.new()
	totems.name = "Totems"
	totems.director = director
	add_child(totems)
	totems.revive_rolled.connect(_on_revive_rolled)
	totems.bad_roll.connect(_on_bad_roll)

	shop = Shop.new()
	shop.name = "Shop"
	shop.director = director
	shop.career = career
	shop.cameras = cameras
	shop.guard_room = guard_room
	add_child(shop)
	doors = GuardRoomDoors.new()
	doors.name = "GuardRoomDoors"
	doors.shop = shop
	doors.director = director
	add_child(doors)
	school_doors.director = director
	totems.shop = shop
	guard_room.shop = shop
	vending = VendingUI.new()
	vending.name = "Vending"
	add_child(vending)
	vending.buy_requested.connect(shop.request_buy)
	vending.closed.connect(_on_ui_closed)
	shop.wallet_changed.connect(func(_points: int) -> void: _refresh_inventory())
	shop.holding_changed.connect(func(items: Array[String]) -> void:
		hud.hotbar.set_items(items)
		_refresh_inventory())
	school.vending_machine.used.connect(_on_vending_used)

	keypad = KeypadUI.new()
	keypad.name = "Keypad"
	add_child(keypad)
	keypad.submitted.connect(_on_keypad_submitted)
	keypad.closed.connect(_on_ui_closed)

	pause_menu = PauseMenu.new()
	pause_menu.name = "PauseMenu"
	add_child(pause_menu)
	pause_menu.closed.connect(_on_ui_closed)
	pause_menu.kick_requested.connect(func(peer: int) -> void:
		var guard := director.guard_by_peer(peer)
		if guard:
			_kicked[guard.employee_number] = true
		# And the badge they came with, in case they were lent a spare.
		if _badge_sent.has(peer):
			_kicked[_badge_sent[peer]] = true
		_reject(peer, "The host removed you from the session."))
	pause_menu.closed.connect(func() -> void:
		if night.report.visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE)
	pause_menu.closed.connect(hud.refresh_key_hint)
	pause_menu.voice = voice
	pause_menu.leave_requested.connect(func() -> void:
		_back_to_menu("You ended the session." if multiplayer.is_server() and _mode != "solo" else ""))

	var report := Report.new()
	report.name = "Report"
	add_child(report)
	report.leave_requested.connect(func() -> void:
		_back_to_menu("You ended the session." if multiplayer.is_server() and _mode != "solo" else ""))

	night = Night.new()
	night.name = "Night"
	night.shift = shift
	night.lighting = lighting
	night.anomalies = anomalies
	night.cameras = cameras
	night.hud = hud
	night.clipboard = clipboard
	night.report = report
	night.players = players
	night.director = director
	director.principal_ignored.connect(night.on_principal_ignored)
	career.guide_entry_added.connect(func(kind: String) -> void:
		var entry: Dictionary = FieldGuide.ENTRIES.get(kind, {})
		if not entry.is_empty():
			Sfx.play_flat(self, Sfx.notes([523.0, 784.0, 1047.0], 0.1, 0.25, "triangle"))
			hud.show_message("NEW IN YOUR FIELD GUIDE: %s\nHow to survive it: %s" % [(entry["name"] as String).to_upper(), entry["rule"]], 12.0)
			if ResourceLoader.exists("res://assets/guide/%s.png" % kind):
				hud.show_sketch(load("res://assets/guide/%s.png" % kind)))
	career.stamp_added.connect(func(kind: String, which: String) -> void:
		# (The 6 AM "handled" stamps come in a bunch with the report: the field guide shows those.)
		# (After the log's own result, which would otherwise replace it.)
		if shift.state == Shift.State.ON_SHIFT:
			get_tree().create_timer(2.5).timeout.connect(func() -> void:
				hud.show_message("Case file stamp: %s, %s. (%d of %d)" % [FieldGuide.display_name(kind).capitalize(), which,
						Career.stamp_count(), Career.MONSTER_KINDS.size() * Career.STAMPS.size()])))
	night.totems = totems
	totems.late_joiners = night.late_joiners
	night.shop = shop
	night.guard_room = guard_room
	night.doors = doors
	night.school_doors = school_doors
	night.career = career
	rounds = Rounds.new()
	rounds.name = "Rounds"
	rounds.director = director
	rounds.career = career
	add_child(rounds)
	night.rounds = rounds
	power = Power.new()
	power.name = "Power"
	power.school = school
	power.cameras = cameras
	power.director = director
	for station: Dictionary in Rounds.STATIONS:
		director.work_spots.append(station["at"])
	(func() -> void: director.work_spots.append(power._breaker.global_position)).call_deferred()
	# Other places the job means holding still: the revive totems, and the desks (fitting a kit).
	for spot: Vector3 in Totems.SPOTS:
		director.work_spots.append(spot)
	(func() -> void: director.work_spots.append_array(guard_room._chair_positions)).call_deferred()
	power.career = career
	add_child(power)
	power.breaker_reset.connect(night.add_bonus)
	power.night_dock = night.dock
	director.power = power
	anomalies.director_noise = director.make_noise
	night.power = power
	light_switches = LightSwitches.new()
	light_switches.name = "LightSwitches"
	light_switches.lighting = lighting
	light_switches.power = power
	light_switches.director = director
	light_switches.players = players
	add_child(light_switches)
	light_switches.build(school)
	night.light_switches = light_switches
	_build_staff_locker()
	glare = Glare.new()
	glare.name = "Glare"
	glare.players = players
	glare.hud = hud
	add_child(glare)
	televisions = Televisions.new()
	televisions.name = "Televisions"
	televisions.power = power
	televisions.director = director
	add_child(televisions)
	televisions.build(school.tv_spots)
	night.televisions = televisions
	haunting = Haunting.new()
	haunting.name = "Haunting"
	haunting.director = director
	haunting.night = night
	haunting.power = power
	haunting.school_doors = school_doors
	haunting.light_switches = light_switches
	add_child(haunting)
	night.haunting = haunting
	var conditions := Conditions.new()
	conditions.name = "Conditions"
	conditions.lighting = lighting
	conditions.players = players
	conditions.hud = hud
	add_child(conditions)
	night.conditions = conditions
	var storm := Storm.new()
	storm.name = "Storm"
	storm.moon = get_node("Moon")
	storm.environment = lighting.environment
	storm.window_glass = school.get_material("night_window")
	add_child(storm)
	conditions.storm = storm
	director.conditions = conditions
	rounds.conditions = conditions
	power.conditions = conditions
	var bonus := Bonus.new()
	bonus.name = "Bonus"
	bonus.director = director
	bonus.rounds = rounds
	add_child(bonus)
	night.bonus = bonus
	var phone := Phone.new()
	phone.name = "Phone"
	phone.director = director
	phone.anomalies = anomalies
	phone.power = power
	add_child(phone)
	night.phone = phone
	hiding = Hiding.new()
	hiding.name = "Hiding"
	hiding.director = director
	hiding.shift = shift
	hiding.players = players
	hiding.hud = hud
	add_child(hiding)
	night.hiding = hiding
	clutter = Clutter.new()
	clutter.name = "Clutter"
	clutter.director = director
	clutter.shift = shift
	add_child(clutter)
	drawers = Drawers.new()
	drawers.name = "Drawers"
	drawers.director = director
	drawers.shift = shift
	drawers.night = night
	add_child(drawers)
	clutter.carried_changed.connect(_refresh_inventory)
	night.clutter = clutter
	finale = Finale.new()
	finale.name = "Finale"
	finale.director = director
	finale.shift = shift
	finale.hud = hud
	finale.players = players
	finale.hiding = hiding
	add_child(finale)
	night.finale = finale
	var nerve := Nerve.new()
	nerve.name = "Nerve"
	nerve.director = director
	nerve.players = players
	nerve.power = power
	nerve.light_switches = light_switches
	nerve.hiding = hiding
	nerve.hud = hud
	add_child(nerve)
	night.nerve = nerve
	captions = Captions.new()
	captions.name = "Captions"
	add_child(captions)
	director.nerve = nerve
	dread.night = night
	dread.career = career
	add_child(night)
	var wall_clocks := WallClocks.new()
	wall_clocks.name = "WallClocks"
	wall_clocks.school = school
	wall_clocks.night = night
	wall_clocks.power = power
	add_child(wall_clocks)
	var room_tones := RoomTones.new()
	room_tones.name = "RoomTones"
	room_tones.school = school
	room_tones.power = power
	add_child(room_tones)
	shop.night = night
	director.student_helped.connect(func(peer_id: int) -> void:
		night.add_bonus(peer_id)
		night.pay_extra(peer_id, 50)
		career.award(peer_id, "GOOD_SAMARITAN"))
	_refresh_inventory()

	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	# From the menu buttons, check first that a new run won't silently replace the saved one.
	menu.solo_requested.connect(func() -> void:
		if menu.confirm_new_run():
			_play_solo())
	menu.host_requested.connect(func() -> void:
		_team_daily = false
		if menu.confirm_new_run():
			_host())
	menu.join_requested.connect(_join)
	menu.daily_requested.connect(_play_daily)
	menu.team_daily_requested.connect(func() -> void:
		menu._continue.button_pressed = false
		# Made a daily only once hosting has actually started (it can fail).
		_team_daily = true
		_host())
	menu.training_requested.connect(_play_training)
	night.daily_finished.connect(func() -> void:
		_play_after_reload = night.training != null
		_back_to_menu(""))
	SteamService.lobby_ready.connect(_on_steam_lobby_ready)
	SteamService.lobby_failed.connect(_on_steam_lobby_failed)
	SteamService.invite_accepted.connect(_on_steam_invite)
	SteamService.set_presence("In the main menu")
	menu.set_steam_status(SteamService.available, SteamService.user_name)
	if SteamService.pending_lobby != 0 and _mode == "":
		_on_steam_invite.call_deferred(SteamService.pending_lobby)
	menu.show_status(_menu_message)
	_menu_message = ""
	if _play_after_reload:
		_play_after_reload = false
		# Straight into a new night 1, unless that would replace a saved run (or an invite's
		# being answered): then the menu, where the player chooses.
		if RunSave.exists():
			menu.show_status("Training done. You have a saved run: continue it, or untick \"Continue saved run\" to start again from night 1.")
		elif SteamService.pending_lobby == 0:
			menu._continue.button_pressed = false
			_play_solo.call_deferred()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_start_from_command_line()


## A menu (clipboard, keypad, vending machine, Esc menu) closed: the guard can move again,
## unless another menu is still open or the night report is up.
func _on_ui_closed() -> void:
	if _local_guard == null or shift.state == Shift.State.REPORT:
		return
	if clipboard.is_open or keypad.is_open or vending.is_open or pause_menu.is_open:
		return
	_local_guard.input_blocked = false


## Solo: tabbing away mid-shift pauses the game, rather than leaving the guard standing there.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT or _mode != "solo" or shift.state != Shift.State.ON_SHIFT:
		return
	if _local_guard == null or _local_guard.is_dead or _local_guard.input_blocked or pause_menu.is_open:
		return
	_local_guard.input_blocked = true
	pause_menu.open(true, false)


## Closes every menu, e.g. when your guard is caught or the night report comes up.
func _close_all_ui() -> void:
	_close_ghost_cameras()
	clipboard.close()
	keypad.close()
	vending.close()
	pause_menu.close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		Profile.set_fullscreen(DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(_delta: float) -> void:
	if _mode == "":
		return
	ambience.night_progress = night.minutes / Night.SHIFT_MINUTES
	# Stop watching a teammate who's gone or been caught, or once you're back on your feet.
	if _spectating != null and (not is_instance_valid(_spectating) or _spectating.is_dead
			or _local_guard == null or not _local_guard.is_dead):
		_watch(null)
	# The same for the cameras a ghost is watching.
	if _ghost_camera >= 0 and (_local_guard == null or not _local_guard.is_dead or shift.state == Shift.State.REPORT):
		_close_ghost_cameras()
	var guards := players.get_child_count()
	var status := "Solo" if _mode == "solo" else "%s · %d guard%s" % [_mode, guards, "" if guards == 1 else "s"]
	# The room code is for getting in: shown before the shift, not all night (or on a stream).
	if _room_code != "" and shift.state != Shift.State.ON_SHIFT:
		status = "Room %s%s · %s" % [_room_code, " (password)" if _password != "" else "", status]
	if _local_guard:
		status += " · Badge #%04d" % _local_guard.employee_number
	if night.difficulty > 0:
		status += " · Difficulty %d" % night.difficulty
	hud.set_objective(_objective())
	if _local_guard and is_instance_valid(_local_guard):
		hud.set_stamina(_local_guard.stamina, _local_guard.winded)
	_board_timer -= _delta
	if _board_timer <= 0.0:
		_board_timer = 1.0
		_update_tonight_board()
	hud.set_voice(voice.transmitting, voice.level, voice.on_radio)
	for guard: Guard in players.get_children():
		if guard != _local_guard:
			guard.show_talking(voice.is_talking(guard.name.to_int()))
	if _local_guard and _local_guard.boost_left > 0.0:
		hud.set_inventory(shop.local_points, "Energy drink: %ds" % ceili(_local_guard.boost_left))
	elif _local_guard and _boost_was_on:
		_refresh_inventory()
	_boost_was_on = _local_guard != null and _local_guard.boost_left > 0.0
	hud.set_status(status)


# --- Starting a session --------------------------------------------------------

## Lets Godot's "Customize Run Instances" start copies of the game straight into a session.
## Launch arguments: --solo, --host, or --join (optionally --join=ADDRESS).
func _start_from_command_line() -> void:
	var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	# Settings first, so they're in place before a session starts.
	var night_number := 0
	for arg in args:
		if arg.begins_with("--difficulty="):
			# For testing the wings: --difficulty=3 opens both.
			menu._difficulty.select(clampi(arg.get_slice("=", 1).to_int(), 0, Night.MAX_DIFFICULTY))
			menu._continue.button_pressed = false
		elif arg.begins_with("--conditions="):
			# For testing a night's conditions, e.g. --conditions=fog,batteries
			night.conditions.forced.assign(arg.get_slice("=", 1).split(","))
		elif arg.begins_with("--night="):
			# For testing later nights, e.g. --night=7 when monsters can enter the guard room.
			night_number = clampi(arg.get_slice("=", 1).to_int(), 1, 99)
			menu._continue.button_pressed = false
	for arg in args:
		if arg == "--solo":
			_play_solo()
		elif arg == "--host":
			_direct_only = true
			_use_test_window(0)
			_host()
		elif arg.begins_with("--join"):
			_direct_only = true
			_use_test_window(1)
			_join(arg.get_slice("=", 1) if "=" in arg else "127.0.0.1")
		elif arg == "--fast-night":
			# For testing: a whole night in about a minute.
			night.seconds_per_minute = 0.2
		elif arg == "--rich":
			# For testing the vending machine: everyone starts with 1000 points.
			night.give_everyone.call_deferred(1000)
	if night_number > 0 and multiplayer.is_server():
		night.number = night_number


## When testing several copies on one screen, put each in its own half instead of fullscreen.
## The host goes on the left, players who join go on the right.
func _use_test_window(side: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var screen := DisplayServer.screen_get_usable_rect()
	var size := Vector2i(screen.size.x / 2, screen.size.x * 9 / 32)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + Vector2i(side * size.x, (screen.size.y - size.y) / 2))


func _play_solo() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_mode = "solo"
	director.bake_navigation()
	_start_run()
	_enter_school()
	_spawn_guard(1, Profile.employee_number, _player_name(), Career.rank(), _hat(), _perk(), Career.monsters_seen())


## Today's daily shift: one solo night, the same for everyone today. Never touches the saved run.
func _play_daily() -> void:
	menu._continue.button_pressed = false
	night.daily = Daily.today()
	_play_solo()
	night.hardcore = false
	night.grade = 0
	night.number = Daily.night_of(night.daily)
	night.give_everyone(Daily.STARTING_POINTS)


## The training shift: a guided solo night. Never touches the saved run.
func _play_training() -> void:
	menu._continue.button_pressed = false
	var training := Training.new()
	training.name = "Training"
	training.night = night
	training.hud = hud
	add_child(training)
	night.training = training
	_play_solo()
	night.hardcore = false
	night.grade = 0
	night.number = 1
	training.guard = _local_guard


func _host() -> void:
	# On Steam, host through a Steam lobby (friends can join with its code or an invite).
	if SteamService.available and not _direct_only:
		menu.set_busy(true)
		menu.show_status("Creating a Steam lobby...")
		SteamService.host_lobby(MAX_GUARDS, true)
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_GUARDS - 1)
	if error != OK:
		_team_daily = false
		menu.show_status("Couldn't host on port %d. Is another copy of the game already hosting?" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	_room_code = RoomCode.from_address(RoomCode.local_address())
	_begin_hosting()
	print("[net] Hosting on port %d" % PORT)


## Starts the session once the host's multiplayer peer is ready (direct or Steam).
func _begin_hosting() -> void:
	_mode = "Hosting"
	menu.set_busy(false)
	director.bake_navigation()
	# Before the run starts, so a team daily gets the daily's night length, not the host's.
	if _team_daily:
		night.daily = Daily.today()
	_start_run()
	_enter_school()
	_spawn_guard(1, Profile.employee_number, _player_name(), Career.rank(), _hat(), _perk(), Career.monsters_seen())
	_daily_paid[Profile.employee_number] = true
	# A team daily shift: today's night, today's notes, today's starting points.
	if _team_daily:
		night.daily = Daily.today()
		night.team_daily = true
		night.hardcore = false
		night.grade = 0
		night.number = Daily.night_of(night.daily)
		night.give_everyone(Daily.STARTING_POINTS)


func _join(typed: String) -> void:
	if typed == "":
		menu.show_status("Type the host's room code or address first.")
		return
	_password = menu.options()["password"]
	if SteamService.available and SteamService.is_lobby_code(typed):
		menu.set_busy(true)
		menu.show_status("Looking for Steam lobby %s..." % typed.strip_edges().to_upper())
		SteamService.join_by_code(typed)
		return
	var address := RoomCode.resolve(typed)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		menu.show_status("Couldn't start connecting to %s." % address)
		return
	multiplayer.multiplayer_peer = peer
	menu.set_busy(true)
	menu.show_status("Connecting to %s..." % address)


## Host: applies the menu's run options, and loads the saved run if the host chose to continue it.
func _start_run() -> void:
	var options: Dictionary = menu.options()
	Shop.donuts_bought = 0
	night.difficulty_choice = options["difficulty"]
	night.hardcore = options["hardcore"]
	night.grade = options["grade"]
	# A custom shift: the same shift notes every night.
	if not (options["notes"] as Array).is_empty() and night.daily == "":
		night.conditions.forced.assign(options["notes"])
		night.conditions.custom = true
	# The daily shift is the same length for everyone.
	night.seconds_per_minute = Night.SECONDS_PER_MINUTE if night.daily != "" else options["seconds_per_minute"]
	_password = options["password"]
	# The daily is a night on its own: the saved run stays out of it.
	if not options["continue"] or night.daily != "":
		return
	var saved := RunSave.read()
	night.number = clampi(int(saved.get("night", 1)), 1, 99)
	night.grade = clampi(int(saved.get("grade", 0)), 0, Grades.MAX)
	night.saved_points = saved.get("points", {})
	night.saved_items = saved.get("items", {})
	if saved.get("in_progress", false):
		# The last session walked out in the middle of a night. That counts as the team being
		# caught, the same rules as a wipe, so quitting is never a way out of a bad night.
		var text := ""
		if bool(saved.get("hardcore", false)) or night.number > Night.LAST_NIGHT:
			text = "Last time, the shift was abandoned. That counts as the whole team being caught: the run starts over from night 1."
			night.number = 1
			night.saved_points = {}
			night.saved_items = {}
			saved["write_ups"] = 0
			saved["run_stats"] = {}
			saved["run_nights"] = 0
			saved["last_retried"] = false
			if bool(saved.get("hardcore", false)) or not bool(saved.get("keep_gear", false)):
				# Nothing carries over: a fresh run.
				_tell_abandoned(text)
				return
		else:
			var back := Night.checkpoint_for(night.number, night.grade)
			text = "Last time, the shift was abandoned. That counts as the whole team being caught: back to night %d, the last checkpoint, with half your points." % back
			# The last night gets one more go, once a run, just as after a wipe.
			if night.number == Night.LAST_NIGHT and not bool(saved.get("last_retried", false)):
				back = Night.LAST_NIGHT
				saved["last_retried"] = true
				text = "Last time, the shift was abandoned. That counts as the whole team being caught: the district gives you one more go at the last night, with half your points."
			saved["run_nights"] = int(saved.get("run_nights", 0)) + 1
			night.number = back
			for key: String in night.saved_points:
				night.saved_points[key] = int(night.saved_points[key]) / 2
			saved["write_ups"] = 0
		_tell_abandoned(text)
	var upgrades: Array = saved.get("upgrades", [])
	for desk in mini(upgrades.size(), GuardRoom.DESKS):
		if upgrades[desk]:
			guard_room._set_upgraded(desk, true)
	var fitted: Array = saved.get("doors", [])
	for doorway in mini(fitted.size(), GuardRoomDoors.DOORWAYS.size()):
		if fitted[doorway]:
			doors.install(doorway)
	night.saved_personal = saved.get("personal", {})
	shop.spent = saved.get("spent", {})
	Shop.donuts_bought = int(saved.get("donuts", 0))
	night.run_team = int(saved.get("team", 0))
	night._run_stats = saved.get("run_stats", {})
	night._run_nights = int(saved.get("run_nights", 0))
	night.write_ups = int(saved.get("write_ups", 0))
	night._last_night_retried = bool(saved.get("last_retried", false))
	# Saves from before the walkie-talkie listed flashlights on their own.
	for badge: String in saved.get("bright", []):
		var list: Array = night.saved_personal.get_or_add(badge, [])
		if "flashlight" not in list:
			list.append("flashlight")
	print("[run] Continuing the saved run: ", RunSave.describe(saved))


## 6 AM on every computer: the birds start up outside, a few at first, then more.
func _dawn_chorus() -> void:
	var dawn := SoundBank.get_sound("dawn", null, false)
	if dawn:
		SoundBank.play_flat(self, "dawn", -10.0, dawn)
		return
	for i in 14:
		var wait := 0.6 + i * randf_range(0.9, 1.6)
		get_tree().create_timer(wait).timeout.connect(func() -> void:
			if shift.state != Shift.State.MORNING:
				return
			var low := randf_range(2600.0, 3600.0)
			Sfx.play_flat(self, Sfx.chirp(low, low * randf_range(1.2, 1.6), randf_range(0.08, 0.16), randi_range(1, 4)), randf_range(-20.0, -11.0)))


## Tells the host, on the menu and once the night starts, what walking out last time cost.
func _tell_abandoned(text: String) -> void:
	menu.show_status(text)
	get_tree().create_timer(2.0).timeout.connect(func() -> void: hud.show_message(text, 10.0))


## The hat this player picked, if they've still got it unlocked.
func _hat() -> String:
	return Profile.hat if Hats.is_unlocked(Profile.hat) else "cap"


## The perk this player picked, if they've still got it unlocked.
func _perk() -> String:
	return Perks.valid(Profile.perk)


## The name shown over your guard: your Steam name, or nothing (it then shows "Guard 2").
func _player_name() -> String:
	return SteamService.user_name if SteamService.available else ""


## Steam: our lobby is ready, with its multiplayer peer.
func _on_steam_lobby_ready(peer: MultiplayerPeer, is_host: bool) -> void:
	multiplayer.multiplayer_peer = peer
	_room_code = SteamService.lobby_code
	if is_host:
		_begin_hosting()
		print("[net] Hosting Steam lobby %s" % _room_code)
	else:
		menu.show_status("Connecting to the host over Steam...")


func _on_steam_lobby_failed(reason: String) -> void:
	_team_daily = false
	SteamService.leave_lobby()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	menu.set_busy(false)
	menu.show_status(reason)


## Steam: a friend's invite was accepted (or the game was started from one).
func _on_steam_invite(lobby_id: int) -> void:
	SteamService.pending_lobby = 0
	if _mode != "":
		_show_local_message("Leave this game first (Esc → Leave) to join your friend's.")
		return
	_password = menu.options()["password"]
	menu.set_busy(true)
	menu.show_status("Joining your friend's game...")
	SteamService.join_lobby(lobby_id)


func _on_connected_to_server() -> void:
	_mode = "Connected"
	_enter_school()
	_register_employee.rpc_id(1, Profile.employee_number, _password, _player_name(), Career.rank(), _hat(), _perk(), Career.monsters_seen())
	print("[net] Joined as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	SteamService.leave_lobby()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	menu.set_busy(false)
	menu.show_status("Couldn't reach the host. Check the address, and that the host is in a game.")


func _on_server_disconnected() -> void:
	_back_to_menu("The host ended the session.")


func _enter_school() -> void:
	menu.visible = false
	hud.visible = true
	hud.solo = _mode == "solo"
	hud.show_hint()


func _back_to_menu(message: String) -> void:
	_menu_message = message
	SteamService.leave_lobby()
	get_tree().paused = false
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	get_tree().reload_current_scene()


# --- Guards (host only) ------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if shift.state == Shift.State.MORNING or shift.state == Shift.State.REPORT:
		_reject(peer_id, "That team's just finishing a night. Try again in a minute.")
		return
	print("[net] Guard joined (peer %d)" % peer_id)
	guard_room.send_state_to(peer_id)
	anomalies.send_state_to(peer_id)
	clutter.send_state_to(peer_id)
	drawers.send_state_to(peer_id)
	# Their guard spawns once their computer tells us their badge number (_register_employee).


## Host: someone joined in the middle of a shift. They come in as a ghost (they can watch, leave
## cold spots and knock things over, and a totem can bring them back), and clock in properly
## from the next night. Their computer is brought up to date with the night so far.
func _catch_up_late_joiner(peer_id: int) -> void:
	var joiner := players.get_node_or_null(str(peer_id)) as Guard
	var badge := joiner.employee_number if joiner else 0
	var back_alive := false
	if _left_alive.has(badge) and not _left_alive[badge]["cornered"] \
			and Time.get_ticks_msec() / 1000.0 - float(_left_alive[badge]["left"]) <= RECONNECT_GRACE:
		# A dropped connection, back within the grace: as they were, where they were.
		var left: Dictionary = _left_alive[badge]
		_left_alive.erase(badge)
		back_alive = true
		if left["stats"] != null:
			night._stats[peer_id] = left["stats"]
		if int(left["punches"]) > 0:
			rounds.punches[peer_id] = left["punches"]
		_put_back.rpc_id(peer_id, left["at"])
		_announce.rpc("%s reconnected." % (joiner.display_name() if joiner else "A guard"))
	elif _left_alive.has(badge):
		# They left the shift alive and stayed away: that counts as being caught.
		_left_alive.erase(badge)
		night.record_death()
		career.add_stat(peer_id, "times_caught")
		if joiner:
			night.bonus.on_caught(joiner)
	elif not _shift_badges.has(badge):
		night.late_joiners[peer_id] = true
	_start_night.rpc_id(peer_id, night.number, night.difficulty, true, night.grade)
	# (The clock goes unreliably, so again a moment later, after the start has surely landed.)
	night._sync_clock.rpc_id(peer_id, night.minutes, night.seconds_per_minute)
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if peer_id in multiplayer.get_peers():
			night._sync_clock.rpc_id(peer_id, night.minutes, night.seconds_per_minute))
	night.conditions._set_conditions.rpc_id(peer_id, PackedStringArray(night.conditions.active), night.number)
	rounds._set_state.rpc_id(peer_id, PackedInt32Array(rounds.order), PackedInt32Array(rounds.punched), rounds.open)
	if not power.on:
		power._set_power.rpc_id(peer_id, false, false)
	for hidden_peer: int in hiding.hidden:
		hiding._set_hidden.rpc_id(peer_id, hidden_peer, hiding.hidden[hidden_peer])
	if director.lockdown_left > 0.0:
		_set_lockdown.rpc_id(peer_id, true, director.drill_rule)
	if director.bell_ringing:
		_set_bell.rpc_id(peer_id, true)
	if director._summoned != 0:
		_show_summons.rpc_id(peer_id, director._summoned, director._summon_left, director.finale or director.lockdown_left > 0.0)
	if finale.active:
		finale._set_active.rpc_id(peer_id, true)
		finale._set_key.rpc_id(peer_id, finale.key_area, finale.key_holder, finale._key.global_position, finale.unlocked)
	for camera_index: int in director._blackouts:
		_camera_signal.rpc_id(peer_id, camera_index, false)
	totems.send_state_to(peer_id)
	director.lockers.send_state_to(peer_id)
	for monster in director._container.get_children():
		if monster is Substitute:
			(monster as Substitute).send_writing_to(peer_id)
	for slot: int in cameras.portable_spots:
		cameras.place_portable.rpc_id(peer_id, slot, cameras.portable_spots[slot][0], cameras.portable_spots[slot][1])
	if night.phone.ringing:
		night.phone._set_ringing.rpc_id(peer_id, true)
	if director.portrait.stage > 0:
		var subject := director.guard_by_peer(director.portrait._subject)
		director.portrait._show.rpc_id(peer_id, director.portrait.stage, subject.slot if subject else 1)
	if director._container.get_children().any(func(monster: Node) -> bool: return monster is Mascot):
		anomalies.set_prop_shown.rpc_id(peer_id, "mascot", false)
	if night.bonus.status != "":
		night.bonus._show.rpc_id(peer_id, night.bonus.status)
	for guard: Guard in players.get_children():
		if guard.is_dead:
			_show_ghost.rpc_id(peer_id, guard.name.to_int(), false)
			var body: Node3D = director._corpses.get(guard.name.to_int())
			if is_instance_valid(body):
				_show_corpse.rpc_id(peer_id, guard.name.to_int(), body.global_position - Vector3(0, 0.22, 0))
	if not back_alive:
		_show_ghost.rpc(peer_id, true)


## How long a guard who dropped out mid-shift has to come back as they were (seconds).
const RECONNECT_GRACE := 90.0
## A monster this close when they dropped: it counts as a catch whenever they come back.
const CORNERED_RANGE := 12.0
## A rejoining guard's spot, if it arrives before their guard does.
var _put_back_at := Vector3.INF


## The rejoining player's computer: back where they were when they dropped.
@rpc("authority", "call_remote", "reliable")
func _put_back(at: Vector3) -> void:
	if _local_guard and is_instance_valid(_local_guard):
		_local_guard.global_position = at + Vector3(0, 0.1, 0)
	else:
		_put_back_at = at


## Every computer: the nearest camera caught it. Its picture goes on tonight's report.
@rpc("authority", "call_local", "reliable")
func _incident(camera_index: int, caption: String) -> void:
	var image: Image = await cameras.snapshot(camera_index)
	night.report.add_incident(image, caption)


## A body where a guard was caught, for a computer that joined after it happened.
@rpc("authority", "call_remote", "reliable")
func _show_corpse(peer_id: int, at: Vector3) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard:
		director.place_corpse(peer_id, at, guard.uniform_color(), guard.slot)


## Every computer: a guard is a ghost (a late joiner, or someone who was already caught when
## this computer joined). `joined` says it's a new arrival, for the message.
@rpc("authority", "call_local", "reliable")
func _show_ghost(peer_id: int, joined: bool) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null:
		return
	guard.set_dead(true)
	if guard == _local_guard:
		# In through the (locked) gate, so there's somewhere to haunt.
		if not Finale.on_grounds(guard.global_position):
			guard.global_position = Vector3((guard.slot - 2.5) * 1.4, 0.1, Finale.GATE_Z - 4.0)
		hud.set_ghost(true)
		hud.show_message("The shift had already started, so you've come in as a ghost: watch, leave cold spots ({use}), knock things over, and help where you can. You'll clock in properly from the next night.", 12.0)
	elif joined:
		hud.show_message("%s joined mid-shift. They're a ghost until the next night." % guard.display_name())
	_refresh_guard_visibility()


## Host: a player who just joined shows their badge. Their guard spawns with it.
@rpc("any_peer", "call_remote", "reliable")
func _register_employee(badge: int, password: String, player_name := "", rank := 1, hat := "cap", perk := "thermos", known := []) -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or players.has_node(str(peer_id)):
		return
	# A Steam friend of the host (in through an invite, say) doesn't need the password.
	if password != _password and not SteamService.is_friend(SteamService.steam_id_of_peer(multiplayer.multiplayer_peer, peer_id)):
		_reject(peer_id, "Wrong room password." if password != "" else "That room needs a password.")
		return
	if shift.state != Shift.State.PRE_SHIFT and shift.state != Shift.State.ON_SHIFT:
		_reject(peer_id, "That team's just finishing a night. Try again in a minute.")
		return
	if players.get_child_count() >= MAX_GUARDS:
		_reject(peer_id, "That team is full.")
		return
	if _kicked.has(badge):
		_reject(peer_id, "The host removed you from this session.")
		return
	_badge_sent[peer_id] = badge
	# Two copies of the game on one computer share a badge. Lend the second one a spare.
	while badge < 1000 or _badge_in_use(badge):
		badge = randi_range(1000, 9999)
	_spawn_guard(peer_id, badge, player_name, rank, hat, perk, known)
	# Today's starting points, once per guard (leaving and rejoining doesn't top them up).
	if night.daily != "" and shift.state == Shift.State.PRE_SHIFT and not _daily_paid.has(badge):
		_daily_paid[badge] = true
		night._totals[peer_id] = Daily.STARTING_POINTS
		shop.push_wallets()
	# Spawn data is replayed as it was first sent: tell them about anyone promoted since.
	for guard: Guard in players.get_children():
		if guard.name.to_int() != peer_id:
			_set_rank.rpc_id(peer_id, guard.name.to_int(), guard.rank)
			_set_look.rpc_id(peer_id, guard.name.to_int(), guard.hat, guard.perk)
	shop.send_state_to(peer_id)
	# The briefing's clocked-in list.
	_set_clocked_in.rpc_id(peer_id, PackedInt32Array(_clocked_in_peers))
	if shift.state == Shift.State.ON_SHIFT:
		_catch_up_late_joiner(peer_id)
	doors.send_state_to(peer_id)
	school_doors.send_state_to(peer_id)
	televisions.send_state_to(peer_id)
	# After their own lights-out has run.
	get_tree().create_timer(12.0).timeout.connect(func() -> void:
		if multiplayer.get_peers().has(peer_id):
			light_switches.send_state_to(peer_id))
	_sync_session.rpc_id(peer_id, night.number, night.difficulty)
	_update_guards_required()


func _badge_in_use(badge: int) -> bool:
	for guard: Guard in players.get_children():
		if guard.employee_number == badge:
			return true
	return false


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[net] Guard left (peer %d)" % peer_id)
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	var last_at := guard.global_position if guard else Vector3.ZERO
	if guard:
		if shift.state == Shift.State.ON_SHIFT and not guard.is_dead:
			# Kept for a quick reconnect: where they were and what they'd done tonight (taken off
			# their old peer id, so nothing counts twice). Not if something was on them as they went:
			# pulling the plug isn't a way out of a catch.
			var cornered := director.active_monsters().any(func(monster: Monster) -> bool:
				return not monster.harmless and monster.global_position.distance_to(last_at) < CORNERED_RANGE)
			var spot: int = hiding.hidden.get(peer_id, -1)
			_left_alive[guard.employee_number] = {"at": hiding.front_of(spot) if spot >= 0 else last_at,
					"left": Time.get_ticks_msec() / 1000.0, "cornered": cornered,
					"stats": night._stats.get(peer_id), "punches": rounds.punches.get(peer_id, 0)}
			night._stats.erase(peer_id)
			rounds.punches.erase(peer_id)
		# Keep what they had, by badge, so they get exactly that back if they rejoin.
		night.remember_guard(guard)
		# Out of the team straight away, so nothing below (a night starting or ending, a save)
		# still counts them.
		players.remove_child(guard)
		guard.queue_free()
	shift.remove_guard(peer_id)
	guard_room.on_peer_left(peer_id)
	if guard:
		clutter.drop(peer_id, last_at)
		finale.drop(peer_id, last_at, true)
	if hiding.hidden.has(peer_id):
		hiding._set_hidden.rpc(peer_id, -1)
	if shift.state == Shift.State.PRE_SHIFT:
		_set_clocked_in.rpc(PackedInt32Array(shift.clocked_in_peers()))
	night.report.recount_ready()
	_update_guards_required(guard != null and not guard.is_dead)


## Host only. The spawner runs _create_guard with the same data on every computer,
## including players who join later.
func _spawn_guard(peer_id: int, badge: int, player_name := "", rank := 1, hat := "cap", perk := "thermos", known := []) -> void:
	# Personal upgrades go in the spawn data so every computer builds the guard with them.
	var personal: Array = night.saved_personal.get(str(badge), [])
	spawner.spawn({"peer_id": peer_id, "slot": _free_slot(), "badge": badge, "personal": personal,
			"name": player_name.left(24), "rank": clampi(rank, 1, Career.RANKS.size()),
			"hat": hat if Hats.HATS.has(hat) else "cap", "perk": Perks.valid(perk, clampi(rank, 1, Career.RANKS.size())),
			"known": known.filter(func(kind: Variant) -> bool: return kind is String and FieldGuide.ENTRIES.has(kind))})
	night.restore_guard(peer_id, badge)


func _create_guard(data: Dictionary) -> Node:
	var guard := PlayerScene.instantiate() as Guard
	guard.name = str(data["peer_id"])
	guard.slot = data["slot"]
	guard.employee_number = data.get("badge", 0)
	guard.player_name = data.get("name", "")
	guard.rank = data.get("rank", 1)
	guard.hat = data.get("hat", "cap")
	guard.perk = data.get("perk", "thermos")
	guard.known_monsters.assign(data.get("known", []))
	guard.bright_flashlight = "flashlight" in data.get("personal", [])
	guard.has_radio = "radio" in data.get("personal", [])
	guard.emf_fitted = "emf" in data.get("personal", [])
	guard.has_emf = guard.emf_fitted or guard.perk == "lookout"
	guard.position = SPAWN_POINT + Vector3((guard.slot - 2.5) * 1.4, 0, 0)
	return guard


func _free_slot() -> int:
	var taken: Array[int] = []
	for guard: Guard in players.get_children():
		taken.append(guard.slot)
	for slot in range(1, MAX_GUARDS + 1):
		if slot not in taken:
			return slot
	return MAX_GUARDS


## Guards in the session, not counting one whose player has just left.
func _guard_count() -> int:
	var count := 0
	for guard in players.get_children():
		if not guard.is_queued_for_deletion():
			count += 1
	return count


func _update_guards_required(left_alive := false) -> void:
	if shift.state == Shift.State.ON_SHIFT and _guard_count() > 0 and director.living_guards().is_empty():
		night.fail_night()
		return
	# In the morning, the last one still to clock out leaving just ends the night.
	# In the morning, the last one still to clock out leaving just ends the night (if they were
	# alive: everyone being caught is still a wipe, even if a ghost leaves during the scare).
	if shift.state == Shift.State.MORNING and director.living_guards().is_empty():
		if left_alive:
			night._end_night.call_deferred()
		else:
			night.fail_night()
		return
	if shift.state == Shift.State.MORNING:
		shift.guards_required = director.living_guards().size()
		if shift.everyone_clocked_out():
			night._end_night()
		return
	shift.guards_required = _guard_count()
	if shift.state == Shift.State.PRE_SHIFT and shift.clocked_in_count() > 0 and shift.everyone_clocked_in():
		_start_night.rpc(night.number, night.pick_difficulty(), false, night.grade)


## Host: badges removed from this session (they can't come back in).
var _kicked: Dictionary = {}
## Host: the badge each peer joined with, before any spare was lent (so a kick sticks).
var _badge_sent: Dictionary = {}


## Host: tells a player why they can't join, then disconnects them once the message is through.
func _reject(peer_id: int, reason: String) -> void:
	_turn_away.rpc_id(peer_id, reason)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer and peer_id in multiplayer.get_peers():
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer_id))


@rpc("authority", "call_remote", "reliable")
func _turn_away(reason: String) -> void:
	_back_to_menu(reason)


## The peer of the living teammate right in front of `guard` and within reach (0 for nobody).
func _teammate_in_front(guard: Guard) -> int:
	var best := 0
	var best_angle := deg_to_rad(25)
	for other: Guard in players.get_children():
		if other == guard or other.is_dead:
			continue
		var to := other.global_position + Vector3(0, 1.2, 0) - guard.camera.global_position
		if to.length() > Shop.GIVE_REACH:
			continue
		var angle := (-guard.camera.global_basis.z).angle_to(to)
		if angle < best_angle:
			best_angle = angle
			best = other.name.to_int()
	return best


## What to call the guard in this slot (their Steam name, or "Guard 2").
func _name_of_slot(slot: int) -> String:
	for guard: Guard in players.get_children():
		if guard.slot == slot:
			return guard.display_name()
	return "Guard %d" % slot


## Host: something elsewhere earned a guard an achievement (Hiding, Drawers...).
func on_award(peer_id: int, achievement: String) -> void:
	if career:
		career.award(peer_id, achievement)
		# (Counted too, for the district bounties.)
		var stat: String = {"STILL_AS_STONE": "searches_survived", "FINDERS_KEEPERS": "drawer_finds",
				"NOTHING_BUT_NET": "baskets"}.get(achievement, "")
		if stat != "":
			career.add_stat(peer_id, stat)


## Host: a basket in the gym (from Clutter).
func on_basket(peer_id: int, count: int, at: Vector3) -> void:
	on_award(peer_id, "NOTHING_BUT_NET")
	var guard := director.guard_by_peer(peer_id)
	_show_basket.rpc(guard.display_name() if guard else "Someone", count, at)


## Every computer: whoever's in the gym hears about it.
@rpc("authority", "call_local", "reliable")
func _show_basket(who: String, count: int, at: Vector3) -> void:
	if _local_guard and is_instance_valid(_local_guard) and _local_guard.global_position.distance_to(at) < 35.0:
		hud.show_message("%s scores!%s" % [who, "  (%d so far)" % count if count > 1 else ""], 3.0)


## Called by each guard's own computer when it spawns, to hook up that player's HUD.
func on_local_guard_ready(guard: Guard) -> void:
	_local_guard = guard
	if _put_back_at != Vector3.INF:
		guard.global_position = _put_back_at + Vector3(0, 0.1, 0)
		_put_back_at = Vector3.INF
	hud.hotbar.guard = guard
	glare.local_guard = guard
	guard.prompt_changed.connect(hud.set_prompt)
	guard.message_shown.connect(hud.show_message)
	guard.desk_action.connect(guard_room.on_desk_action)
	guard.clipboard_requested.connect(_open_clipboard)
	guard.leave_hiding_requested.connect(func() -> void:
		if multiplayer.is_server():
			hiding._request(-1)
		else:
			hiding._request.rpc_id(1, -1))
	guard.mark_requested.connect(func(at: Vector3) -> void:
		if multiplayer.is_server():
			_request_mark(at)
		else:
			_request_mark.rpc_id(1, at))
	guard.ghost_ping_requested.connect(func(at: Vector3, touched: Object) -> void:
		var item := clutter.index_of(touched)
		var switch := light_switches.index_of(touched)
		if switch >= 0 and guard.global_position.distance_to((touched as Node3D).global_position) < LightSwitches.GHOST_REACH:
			# Or flick the lights.
			if multiplayer.is_server():
				light_switches.request_ghost_flip(switch)
			else:
				light_switches.request_ghost_flip.rpc_id(1, switch)
		elif item >= 0:
			# A ghost can knock things over instead.
			if multiplayer.is_server():
				clutter.request_knock(item)
			else:
				clutter.request_knock.rpc_id(1, item)
		elif multiplayer.is_server():
			_request_ghost_ping(at)
		else:
			_request_ghost_ping.rpc_id(1, at))
	guard.throw_requested.connect(func() -> void:
		if not clutter.carried.has(multiplayer.get_unique_id()):
			return
		var eye := guard.camera.global_position
		var forward := -guard.camera.global_basis.z
		if multiplayer.is_server():
			clutter.request_throw(eye, forward)
		else:
			clutter.request_throw.rpc_id(1, eye, forward))
	guard.drop_requested.connect(func() -> void:
		if hud.hotbar.selected == 0:
			hud.show_message("Pick something on the hotbar first (1-5 or the mouse wheel). The flashlight stays with you.")
			return
		shop.request_drop(hud.hotbar.selected - 1, _teammate_in_front(guard)))
	guard.spectate_requested.connect(_spectate_next)
	guard.ghost_cameras_requested.connect(_on_ghost_cameras)
	guard.item_use_requested.connect(func() -> void:
		if not guard_room.try_install():
			shop.request_use(hud.hotbar.item_slot()))
	guard.pause_requested.connect(func() -> void:
		guard.input_blocked = true
		var others: Array = []
		if _mode != "solo":
			for other: Guard in players.get_children():
				if other.name.to_int() != multiplayer.get_unique_id():
					others.append([other.name.to_int(), other.display_name()])
		pause_menu.set_team(others, _mode == "Hosting")
		pause_menu.open(_mode == "solo", _mode == "Hosting", (_mode == "solo" or _mode == "Hosting")
				and shift.state == Shift.State.ON_SHIFT and night.daily == "" and night.training == null))
	doors.local_guard = guard
	guard_room.local_guard = guard
	if not guard_room.camera_pinged.is_connected(_on_camera_pinged):
		guard_room.camera_pinged.connect(_on_camera_pinged)
		guard_room.camera_lured.connect(func(camera_index: int) -> void:
			if multiplayer.is_server():
				_request_lure(camera_index)
			else:
				_request_lure.rpc_id(1, camera_index))
	cameras.viewer = guard
	ambience.listener = guard
	captions.local_guard = guard
	night.nerve.local_guard = guard
	dread.local_guard = guard
	voice.local_guard = guard
	voice.set_active(true)


# --- Clocking in ---------------------------------------------------------------

func _on_clock_machine_used(by: Node) -> void:
	if by != _local_guard or _local_guard.is_dead:
		return
	if shift.state == Shift.State.PRE_SHIFT:
		if _badge_typed:
			# The clock remembers you after the first night of the session.
			if not _clocked_in:
				_on_keypad_submitted(_local_guard.employee_number)
			return
		# Clocking in takes your badge number.
		_local_guard.input_blocked = true
		keypad.open("#%04d" % _local_guard.employee_number)
		return
	_request_time_clock()


var _boost_was_on := false
## True once this player has typed their badge number this session; after that the clock
## just takes a tap.
var _badge_typed := false


## The line under the clock telling you what to do next.
## Who the Principal has called to the office (0: nobody), and when their time is up.
var _summons_peer := 0
var _summons_until := 0
## The host's summons clock is stopped (a lockdown or the finale): the countdown stands still.
var _summons_held := false
var _summons_held_left := 0


@rpc("authority", "call_local", "reliable")
func _show_summons(peer: int, seconds: float, held := false) -> void:
	_summons_peer = peer
	_summons_until = Time.get_ticks_msec() + int(seconds * 1000.0)
	_summons_held = held
	_summons_held_left = ceili(seconds)


## The summons, for the objective line: the one called gets a countdown, the rest a heads-up.
func _summons_text() -> String:
	if _summons_peer == 0:
		return ""
	var left := _summons_held_left if _summons_held else ceili((_summons_until - Time.get_ticks_msec()) / 1000.0)
	if left <= 0:
		return ""
	if _summons_peer == multiplayer.get_unique_id():
		return "THE PRINCIPAL WANTS YOU: get to the front office (%d s%s)." % [left, ", on hold" if _summons_held else ""]
	var called := director.guard_by_peer(_summons_peer)
	return "The Principal has called %s to the front office." % called.display_name() if called else ""


func _objective() -> String:
	if _local_guard == null:
		return ""
	if _local_guard.is_dead:
		return ""
	match shift.state:
		Shift.State.PRE_SHIFT:
			if _clocked_in:
				return "Waiting for the rest of the team to clock in."
			return "Head through the front doors. The guard room is the door on the right of the lobby: clock in at the time clock."
		Shift.State.ON_SHIFT:
			if night.training:
				return night.training.objective
			if finale.active:
				return finale.objective_for(_local_guard)
			var text := "Survive until 6 AM. Watch the cameras and log anything odd (%s)." % Controls.key_name("clipboard") \
					if night.number <= 1 else "Survive until 6 AM."
			if _drill_rule != "":
				text = "LOCKDOWN DRILL: " + _drill_rule + "\n" + text
			elif _summons_text() != "":
				text = _summons_text() + "\n" + text
			var round_text := rounds.objective_text()
			if round_text != "":
				text += "\n" + round_text
			if night.quota_text != "":
				text += "\n" + night.quota_text
			if night.bonus.status != "":
				text += "\n" + night.bonus.status
			return text
		Shift.State.MORNING:
			return "It's 6 AM. Clock out at the time clock in the guard room to get paid."
	return ""


func _on_keypad_submitted(number: int) -> void:
	if _local_guard == null or number != _local_guard.employee_number:
		keypad.flash_display("UNKNOWN")
		SoundBank.play_flat(self, "ui_error", 0.0, Sfx.notes([220.0, 180.0], 0.15, 0.25, "square"))
		return
	keypad.close()
	_clocked_in = true
	_badge_typed = true
	SoundBank.play_flat(self, "punch_clock", 0.0, Sfx.notes([880.0, 1320.0], 0.08, 0.25, "square"))
	_request_time_clock()


func _request_time_clock() -> void:
	if multiplayer.is_server():
		_handle_clock_in(multiplayer.get_unique_id())
	else:
		_request_clock_in.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_clock_in() -> void:
	if multiplayer.is_server():
		_handle_clock_in(multiplayer.get_remote_sender_id())


func _handle_clock_in(peer_id: int) -> void:
	var message := ""
	if shift.state == Shift.State.PRE_SHIFT:
		message = shift.clock_in(peer_id)
	else:
		message = night.use_time_clock(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_show_local_message(message)
	else:
		_receive_message.rpc_id(peer_id, message)
	if shift.state == Shift.State.PRE_SHIFT:
		_set_clocked_in.rpc(PackedInt32Array(shift.clocked_in_peers()))
	if shift.state == Shift.State.PRE_SHIFT and shift.everyone_clocked_in():
		_start_night.rpc(night.number, night.pick_difficulty(), false, night.grade)


@rpc("authority", "call_local", "reliable")
func _start_night(number: int, difficulty: int, late := false, grade := 0) -> void:
	print("[net] Night %d started at difficulty %d" % [number, difficulty])
	_clocked_in_peers.clear()
	night.number = number
	night.grade = grade
	night.difficulty = difficulty
	cameras.clear_references()
	_apply_difficulty(difficulty)
	shift.begin()
	_clocked_in = false
	# A few minutes in, every camera takes a photo to compare against later. (Not for someone
	# joining late: by now the photos would have tonight's anomalies in them.)
	if not late:
		get_tree().create_timer(night.seconds_per_minute * 5.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT:
				cameras.capture_references(night.time_text()))
	SteamService.set_presence("Overtime: night %d" % number if number > Night.LAST_NIGHT
			else "Night %d of %d" % [number, Night.LAST_NIGHT])
	if not late and night.training == null:
		_show_feature_tips()
	if late:
		pass
	elif number == 1 and night.training == null:
		_show_first_night_tips()
	elif number == 2:
		# Night 2 brings two new things: say both, once, and give it time to be read.
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT:
				hud.show_message("NEW TONIGHT: the district wants a work target met by 6 AM (logs and punched stations; it's under the clock). Miss it and the team gets a write-up; three and you're fired. There's a bonus objective too, for extra pay.\nAnd the power can go out: hold %s on the breaker in the custodian's closet, across the hall from the lobby." % Controls.key_name("interact"), 14.0))
	elif number == 3 and night.daily == "":
		get_tree().create_timer(14.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT:
				hud.show_message("NEW TONIGHT: the phone on the front office desk may ring. Answer it ({use}) within about 35 seconds and a voice tips you off about something out of place. Let it ring out and the power goes.", 12.0))
	elif number == Anomalies.TYPE_FROM_NIGHT["Noise"] and night.daily == "":
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT:
				hud.show_message("NEW TONIGHT: some things can only be heard. A radio, static or whispering with nothing making it is a Noise: log it like anything else. The cameras won't pick it up, so someone has to be out there listening.", 12.0))
	elif number > Night.LAST_NIGHT:
		var memo := Memos.new_tonight(number)
		var finale_text := "And tonight ends like the last night did: at 5 AM, the last bell. Get the key, get out (+%d each)." % Night.OVERTIME_ESCAPE_PAY \
				if Memos.has_finale(number) else ""
		if memo != "" or finale_text != "":
			get_tree().create_timer(6.0).timeout.connect(func() -> void:
				if shift.state == Shift.State.ON_SHIFT:
					hud.show_message(("DISTRICT MEMO: %s\n" % memo if memo != "" else "") + finale_text, 12.0))
	elif number == 6 and night.daily == "":
		get_tree().create_timer(6.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT:
				hud.show_message("NEW TONIGHT: some figures don't stay put. Keep a camera on one and you might see it step somewhere else.", 10.0))


## A few pointers on the first night, a few seconds apart.
## Things worth knowing that the training doesn't cover, one or two a night until each has
## been seen once (Profile remembers which).
const FEATURE_TIPS := {
	"crouch": "Tip: {crouch} crouches. You're slow, but your footsteps barely carry, and a desk will hide you.",
	"search": "Tip: hide in a cupboard and a monster that saw you may come and rattle the doors. Hold still and keep quiet (no talking!) and it gives up.",
	"drawers": "Tip: drawers and filing cabinets open ({use}). A few hold something each night: a spare battery, loose change, a note.",
	"share": "Tip: {drop} puts down the item you've picked on the hotbar, or hands it to a teammate you're looking at.",
}


func _show_feature_tips() -> void:
	var shown := 0
	for key: String in FEATURE_TIPS:
		if key in Profile.tips_seen or shown >= 2:
			continue
		if key == "share" and hud.solo:
			continue
		var tip := Controls.fill(FEATURE_TIPS[key])
		# Only counted as seen once it's actually been on screen.
		get_tree().create_timer(100.0 + shown * 140.0, false).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT and _local_guard and not _local_guard.is_dead:
				hud.show_message(tip, 8.0)
				if key not in Profile.tips_seen:
					Profile.tips_seen.append(key)
					Profile.save_settings())
		shown += 1


func _show_first_night_tips() -> void:
	var use := Controls.key_name("interact")
	var tips: Array[String] = [
		"Tip: sit at a desk (%s on a chair) to watch the cameras. %s / %s changes a monitor's camera." % [use, Controls.key_name("move_left"), Controls.key_name("move_right")],
		"Tip: something moved, missing, or there that shouldn't be? Press %s and log where and what. Wrong guesses cost points." % Controls.key_name("clipboard"),
		"Tip: the real night cleaner leaves WET FLOOR signs where they've mopped. That's just cleaning: learn what's normal.",
		"Tip: tonight's round is under the clock. Find the amber lamps and hold %s to punch them. Each punch rings out, and monsters hear it." % use,
		"Tip: at 6 AM, clock out at the time clock or you don't get paid.",
	]
	# Someone who did the training knows the desks, the clipboard and the round already, and
	# after a couple of runs nobody needs telling.
	if Profile.training_done:
		tips = [tips[2], tips[4]]
	if Profile.tips_shown >= 2:
		tips.clear()
	# With a team, the most useful thing to know: call things out.
	if not hud.solo and Profile.tips_shown < 4:
		tips.push_front("Tip: spotted something? Look at it and press %s: your team sees a marker. If one of them logs it within a minute, you get +%d too." % [Controls.key_name("ping"), Night.SPOTTER_POINTS])
	if tips.is_empty():
		return
	Profile.tips_shown += 1
	Profile.save_settings()
	for i in tips.size():
		get_tree().create_timer(10.0 + i * 16.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT and night.number == 1:
				hud.show_message(tips[i], 8.0))


## A player who just joined: which night it is and last night's difficulty, so their cameras
## and clipboard match everyone else's until the night starts.
@rpc("authority", "call_remote", "reliable")
func _sync_session(number: int, difficulty: int) -> void:
	night.number = number
	night.difficulty = difficulty
	if difficulty > 0:
		_apply_difficulty(difficulty, false)


## Every computer, as the night starts: opens tonight's wings and their cameras and areas.
func _apply_difficulty(difficulty: int, open_doors := true) -> void:
	if open_doors:
		school.open_wings(difficulty)
		school_doors.set_open_wings(difficulty)
	cameras.difficulty = difficulty
	anomalies.difficulty = difficulty
	director.difficulty = difficulty
	clipboard.set_areas(anomalies.areas(difficulty))
	if multiplayer.is_server():
		guard_room.fit_to_open_cameras()


## Host: a guard marked a spot for the team. If a monster's right there, it says so.
@rpc("any_peer", "call_remote", "reliable")
func _request_mark(at: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := players.get_node_or_null(str(peer)) as Guard
	var now := Time.get_ticks_msec() / 1000.0
	if guard == null or guard.is_dead or now < float(_ghost_ping_at.get(-peer - 1000000, 0.0)):
		return
	if at.distance_to(guard.global_position) > 45.0:
		return
	_ghost_ping_at[-peer - 1000000] = now + MARK_EVERY
	night.note_callout(peer, SchoolBuilder.area_at(at))
	var monster := false
	for found in director.active_monsters():
		# Not the ones in disguise: telling them apart is the whole game.
		if found is OtherCleaner or found is Student or found is Understudy:
			continue
		if found.global_position.distance_to(at) < MARK_MONSTER_RANGE or (found.global_position + Vector3(0, 1.2, 0)).distance_to(at) < MARK_MONSTER_RANGE:
			monster = true
	_mark.rpc(at, guard.slot, monster)


## Every computer: a marker in that guard's colour, seen through walls, that fades.
@rpc("authority", "call_local", "reliable")
func _mark(at: Vector3, slot: int, monster: bool) -> void:
	var color: Color = Guard.UNIFORM_COLORS[(slot - 1) % Guard.UNIFORM_COLORS.size()]
	var label := Label3D.new()
	label.text = "▼\n%s: %s" % [_name_of_slot(slot), "MONSTER!" if monster else "here"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0012
	label.font_size = 28
	label.outline_size = 8
	label.modulate = Color(1.0, 0.25, 0.2) if monster else color.lightened(0.35)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(label)
	label.global_position = at + Vector3(0, 0.3, 0)
	SoundBank.play_flat(self, "ping", -4.0 if not monster else 0.0, Sfx.notes([880.0, 1320.0] if not monster else [990.0, 660.0, 990.0], 0.07, 0.18, "triangle"))
	var fade := create_tween()
	fade.tween_interval(MARK_SECONDS - 1.5)
	fade.tween_property(label, "modulate:a", 0.0, 1.5)
	fade.tween_callback(label.queue_free)


## Host: a ghost left a cold spot. One every few seconds each, so it can't be spammed.
@rpc("any_peer", "call_remote", "reliable")
func _request_ghost_ping(at: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := players.get_node_or_null(str(peer)) as Guard
	var now := Time.get_ticks_msec() / 1000.0
	if guard == null or not guard.is_dead or now < float(_ghost_ping_at.get(guard.employee_number, 0.0)):
		return
	if shift.state != Shift.State.ON_SHIFT or at.distance_to(guard.global_position) > 30.0:
		return
	_ghost_ping_at[guard.employee_number] = now + GHOST_PING_EVERY
	_ghost_ping.rpc(at, guard.slot)
	# A switched-on spirit box near the cold spot spits out a word.
	shop.spirit_word_near(at)


## Every computer: a cold blue glow that fades, and a chill. The living see it too.
@rpc("authority", "call_local", "reliable")
func _ghost_ping(at: Vector3, slot: int) -> void:
	var spot := Node3D.new()
	add_child(spot)
	spot.global_position = at
	var light := OmniLight3D.new()
	light.light_color = Color(0.45, 0.7, 1.0)
	light.light_energy = 2.5
	light.omni_range = 4.0
	spot.add_child(light)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	orb.mesh = sphere
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.6, 0.85, 1.0, 0.6)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.emission_enabled = true
	glow.emission = Color(0.5, 0.8, 1.0)
	glow.emission_energy_multiplier = 3.0
	orb.material_override = glow
	spot.add_child(orb)
	Sfx.play_at(spot, Sfx.notes([1318.0, 1244.0, 1175.0], 0.25, 0.12, "sine"), -4.0, 25.0)
	var fade := create_tween()
	fade.tween_property(light, "light_energy", 0.0, GHOST_PING_SECONDS)
	fade.parallel().tween_property(orb, "scale", Vector3.ONE * 0.2, GHOST_PING_SECONDS)
	fade.tween_callback(spot.queue_free)
	if _local_guard and not _local_guard.is_dead and _local_guard.global_position.distance_to(at) < 25.0:
		hud.show_message("A cold spot. %s is trying to tell you something." % _name_of_slot(slot))


## The guard room's notice board, written up for tonight.
func _update_tonight_board() -> void:
	if _tonight_board == null:
		_tonight_board = Label3D.new()
		_tonight_board.position = Vector3(9.5, 1.62, 10.2)
		_tonight_board.pixel_size = 0.0032
		_tonight_board.font_size = 30
		_tonight_board.width = 700
		_tonight_board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_tonight_board.modulate = Color(0.12, 0.1, 0.08)
		if Fonts.typed():
			_tonight_board.font = Fonts.typed()
		_tonight_board.outline_size = 0
		_tonight_board.double_sided = false
		add_child(_tonight_board)
	var lines: Array[String] = ["TONIGHT  ·  NIGHT %d" % night.number]
	if shift.state == Shift.State.PRE_SHIFT:
		pass
	elif night.conditions.active.is_empty():
		lines.append("Shift notes: none")
	else:
		lines.append("Shift notes: " + ", ".join(night.conditions.names()))
	if night.quota_text != "":
		lines.append(night.quota_text)
	if night.bonus.status != "":
		lines.append(night.bonus.status)
	var round_text := rounds.objective_text()
	if round_text != "":
		lines.append(round_text)
	if shift.state == Shift.State.PRE_SHIFT:
		lines.append_array(_briefing_lines())
		lines.append(Career.bounty_text())
	_tonight_board.text = "\n".join(lines)


## Every computer: who's clocked in so far (the host sends it with each clock-in).
@rpc("authority", "call_local", "reliable")
func _set_clocked_in(peers: PackedInt32Array) -> void:
	_clocked_in_peers.assign(Array(peers))


## Roster kinds whose field guide entry goes by another name.
const BRIEFING_GUIDE_KEYS := {"locker_thing": "Lockers", "ghost": "SchoolGhost", "twins": "Twin"}


## Before the shift, the board is a briefing: the team, what's been seen in the wings open
## tonight, and a plan.
func _briefing_lines() -> Array[String]:
	var lines: Array[String] = []
	var team: Array[String] = []
	for guard: Guard in players.get_children():
		var ready := guard.name.to_int() in _clocked_in_peers
		team.append("%s (%s) %s" % [guard.display_name(), Career.rank_title(guard.rank), "✓" if ready else "· not in yet"])
	lines.append("TEAM: " + ",  ".join(team))
	# The monsters that could be about tonight: named if you've met them.
	var known := FieldGuide.discovered()
	var met: Array[String] = []
	var strangers := 0
	for kind: String in MonsterDirector.ROSTER:
		var entry: Dictionary = MonsterDirector.ROSTER[kind]
		if entry["night"] > night.number:
			continue
		if night.difficulty > 0 and SchoolBuilder.area_difficulty(entry["home"]) > night.difficulty:
			continue
		if BRIEFING_GUIDE_KEYS.get(kind, kind.to_pascal_case()) in known:
			met.append(entry["name"])
		else:
			strangers += 1
	var seen_text := ", ".join(met) if not met.is_empty() else "nothing you've met"
	lines.append("Reported in the open wings: %s%s." % [seen_text,
			" and %d you haven't" % strangers if strangers > 0 else ""])
	var guards := players.get_child_count()
	lines.append("Plan: %s Shift notes go up when everyone clocks in." % (
			"one of you at the desk on the cameras, the rest out on the round." if guards > 1
			else "the round first, then the cameras; come back if it goes quiet."))
	return lines


## The local guard flagged a camera: everyone gets told, and a marker shows the spot.
func _on_camera_pinged(camera_index: int) -> void:
	var area := cameras.area_of(camera_index)
	if area == "" or not SchoolBuilder.AREAS.has(area):
		return
	if multiplayer.is_server():
		_request_flag(area)
	else:
		_request_flag.rpc_id(1, area)


@rpc("any_peer", "call_remote", "reliable")
func _request_flag(area: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := players.get_node_or_null(str(peer)) as Guard
	if guard == null or guard.is_dead or not SchoolBuilder.AREAS.has(area):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(_ghost_ping_at.get(-peer, 0.0)):
		return
	_ghost_ping_at[-peer] = now + 2.0
	night.note_callout(peer, area)
	_flag.rpc(area, guard.player_name if guard.player_name != "" else "Guard %d" % guard.slot)


## Every computer: a flag over the middle of an area for a while, seen through walls.
@rpc("authority", "call_local", "reliable")
func _flag(area: String, who: String) -> void:
	var box: AABB = SchoolBuilder.AREAS[area]
	var marker := Label3D.new()
	marker.text = "⚑ %s\n(%s)" % [area, who]
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	marker.fixed_size = true
	marker.pixel_size = 0.0012
	marker.font_size = 28
	marker.modulate = Color(1.0, 0.85, 0.3)
	marker.outline_size = 6
	add_child(marker)
	marker.global_position = Vector3(box.get_center().x, 2.2, box.get_center().z)
	var fade := marker.create_tween()
	fade.tween_interval(FLAG_SECONDS)
	fade.tween_property(marker, "modulate:a", 0.0, 1.0)
	fade.tween_callback(marker.queue_free)
	hud.show_message("%s flagged the %s camera." % [who, area])
	SoundBank.play_flat(self, "ping", -6.0, Sfx.notes([1046.0, 1318.0], 0.08, 0.2, "triangle"))


## Host: a guard at the monitors set off a camera's speaker. Monsters that listen come running.
@rpc("any_peer", "call_remote", "reliable")
func _request_lure(camera_index: int) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := players.get_node_or_null(str(peer)) as Guard
	if guard == null or guard.is_dead or shift.state != Shift.State.ON_SHIFT or camera_index < 0 or camera_index >= cameras.count():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var ready_at := float(_lure_ready.get(peer, 0.0))
	if now < ready_at:
		_tell(peer, "The speaker's still recharging (%d s)." % ceili(ready_at - now))
		return
	if not cameras.is_working(camera_index):
		_tell(peer, "That camera's not working.")
		return
	_lure_ready[peer] = now + LURE_COOLDOWN
	var at := cameras.camera(camera_index).global_position
	at.y = 0.0
	director.make_noise(at)
	_lure_sound.rpc(at)
	_tell(peer, "A burst of static and an alarm tone from the %s camera. Anything that listens will go and look." % cameras.area_of(camera_index))


@rpc("authority", "call_local", "reliable")
func _lure_sound(at: Vector3) -> void:
	var spot := Node3D.new()
	add_child(spot)
	spot.global_position = at + Vector3(0, 2.5, 0)
	Sfx.play_at(spot, Sfx.notes([1.0, 1.0, 900.0, 1200.0, 900.0, 1200.0, 900.0], 0.2, 0.4, "square"), 4.0, 45.0)
	get_tree().create_timer(3.0).timeout.connect(spot.queue_free)
	captions.heard("Speaker", "lure", at)


## A ghost pressed G: the next living teammate's view, then back to wandering about.
func _spectate_next() -> void:
	var living: Array[Guard] = []
	for guard: Guard in players.get_children():
		if guard != _local_guard and not guard.is_dead:
			living.append(guard)
	var next := living.find(_spectating) + 1 if _spectating else 0
	_watch(living[next] if next < living.size() else null)


func _watch(target: Guard) -> void:
	if _spectating and is_instance_valid(_spectating):
		_spectating.camera.current = false
		_show_body_to_viewer(_spectating, true)
	_spectating = target
	if target:
		# See what they see: without their own body in the way, or the Ghost they can't see.
		_show_body_to_viewer(target, false)
		target.camera.cull_mask &= ~(Guard.SELF_LAYER | SecurityCameras.SPECTRAL_LAYER)
		target.camera.current = true
		hud.show_message("Watching %s. {item} for the next, or back to yourself." % (target.player_name if target.player_name != "" else "Guard %d" % target.slot))
	elif _local_guard and is_instance_valid(_local_guard):
		_local_guard.camera.current = true


func _show_body_to_viewer(guard: Guard, shown: bool) -> void:
	guard.set_body_layers(1 if shown else Guard.SELF_LAYER)


# --- Ghosts watching the cameras ---------------------------------------------------------------

## The camera this player's ghost is watching full screen (Tab), or -1. Only ever this
## computer's business: watching changes nothing for anyone else, and it's look only (no flags,
## no speaker noise from here).
var _ghost_camera := -1
## The camera a ghost last watched, to open on it again.
var _ghost_camera_last := 0


## A ghost pressed Tab ("open"), flicked between cameras ("prev" / "next"), or went back ("close").
func _on_ghost_cameras(action: String) -> void:
	if _local_guard == null or not _local_guard.is_dead:
		return
	match action:
		"open":
			if shift.state == Shift.State.REPORT:
				return
			var open := cameras.open_cameras()
			if open.is_empty():
				return
			_ghost_camera = _ghost_camera_last if _ghost_camera_last in open else open[0]
			_local_guard.ghost_watching = true
			_local_guard.look_locked = true
			_show_ghost_camera()
			SoundBank.play_flat(self, "monitor_beep", -14.0)
		"prev", "next":
			if _ghost_camera < 0:
				return
			var open := cameras.open_cameras()
			var at := open.find(_ghost_camera)
			_ghost_camera = open[(maxi(at, 0) + (-1 if action == "prev" else 1) + open.size()) % open.size()]
			_show_ghost_camera()
		"close":
			_close_ghost_cameras()


func _show_ghost_camera() -> void:
	# The world behind the full-screen feed needn't be drawn as well.
	get_viewport().disable_3d = true
	_ghost_camera_last = _ghost_camera
	# Only the feed being watched is drawn (every frame while it's up).
	cameras.set_focus(SecurityCameras.key(_ghost_camera, false))
	hud.show_feed(cameras.texture(_ghost_camera), "GHOST   ·   %s   ·   %s / %s  change camera   ·   %s  back" % [
		cameras.title(_ghost_camera), Controls.key_name("move_left"), Controls.key_name("move_right"), Controls.key_name("clipboard")])


func _close_ghost_cameras() -> void:
	get_viewport().disable_3d = false
	if _ghost_camera < 0:
		return
	_ghost_camera = -1
	cameras.set_focus(-1)
	hud.hide_feed()
	if _local_guard and is_instance_valid(_local_guard):
		_local_guard.ghost_watching = false
		_local_guard.look_locked = false


## This lockdown's drill, shown under the objective while it lasts.
var _drill_rule := ""


## Every computer: the lockdown alarm wails (or stops).
@rpc("authority", "call_local", "reliable")
func _set_lockdown(on: bool, rule := "") -> void:
	_drill_rule = rule if on else ""
	dread.lockdown = on
	if on:
		if _siren == null:
			_siren = AudioStreamPlayer.new()
			_siren.bus = &"SFX"
			var freqs: Array = []
			for i in 16:
				freqs.append(520.0 + 380.0 * sin(i / 16.0 * PI))
			_siren.stream = SoundBank.get_sound("siren", Sfx.notes(freqs, 0.08, 0.22, "saw", true), true)
			_siren.volume_db = -8.0
			add_child(_siren)
		_siren.play()
		hud.flash(Color(0.8, 0.0, 0.0, 0.45), 1.5)
	elif _siren:
		_siren.stop()


@rpc("authority", "call_remote", "reliable")
func _flash_screen(color: Color, seconds: float) -> void:
	hud.flash(color, seconds)


@rpc("authority", "call_remote", "reliable")
func _receive_message(message: String, seconds := -1.0) -> void:
	_show_local_message(message, seconds)


func _open_clipboard() -> void:
	if _local_guard.is_dead:
		return
	if shift.state == Shift.State.PRE_SHIFT:
		_show_local_message("Your clipboard is for logging anything odd once the shift has started.")
		return
	if shift.state == Shift.State.REPORT:
		return
	_local_guard.input_blocked = true
	# The camera you're looking at, or else the area you're standing in.
	var area := guard_room.current_area()
	if area == "":
		area = SchoolBuilder.area_at(_local_guard.global_position)
	clipboard.open(area)
	SoundBank.play_flat(self, "paper_open", -8.0)


# --- Caught, ghosts and totems ---------------------------------------------------------------

## Host: a monster caught a guard.
func _on_guard_caught(peer_id: int, by: String, from := Vector3.INF) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null or guard.is_dead:
		return
	if _close_call(guard, by):
		return
	var where := SchoolBuilder.area_at(guard.global_position)
	night.record_death(peer_id, "caught by %s%s at %s" % [by, " in the %s" % where if where != "" else "", night.time_text()])
	var camera_index := cameras.best_view_of(guard.global_position)
	if camera_index >= 0:
		_incident.rpc(camera_index, "%s · %s cam · %s, caught by %s" % [night.time_text(), cameras.area_of(camera_index), guard.display_name(), by])
	clutter.drop(peer_id, guard.global_position)
	finale.drop(peer_id, guard.global_position)
	# What they carried spills on the floor, for the others to pick up (theirs again in the morning).
	shop.spill(peer_id, guard.global_position)
	# Caught in a cupboard (e.g. by the Self-Portrait): the ghost climbs out.
	if hiding.hidden.has(peer_id):
		hiding._set_hidden.rpc(peer_id, -1)
	night.bonus.on_caught(guard)
	night.nerve.on_caught(guard)
	career.add_stat(peer_id, "times_caught")
	_guard_died.rpc(peer_id, by, guard.global_position, from)
	if director.living_guards().is_empty():
		# Give the last guard's jumpscare time to play before the night's results cover it.
		get_tree().create_timer(SCARE_SECONDS, false).timeout.connect(func() -> void:
			if director.living_guards().is_empty():
				night.fail_night())


## Host: just before a catch lands. The first time a guard meets a monster that isn't in their
## field guide (once per kind, per run), or once a night for a guard on their own, they're
## knocked out instead: they wake in the guard room, shaken, and know the rule now.
## Returns true if that's what happened.
func _close_call(guard: Guard, by: String) -> bool:
	# (Not the gate shutting at 6 AM on the last night: there's no waking up from that.)
	if night.hardcore or night.training or night.grade >= 5 or shift.state != Shift.State.ON_SHIFT or by == "the school":
		return false
	var peer := guard.name.to_int()
	var kind := FieldGuide.kind_for_name(by)
	# By badge, so reconnecting doesn't bring them back. (Not in the finale: that's the test.)
	var used: Array = _close_calls.get_or_add(guard.employee_number, [])
	var text := ""
	if kind != "" and kind not in guard.known_monsters and kind not in used and not finale.active:
		used.append(kind)
		career.award(peer, "CLOSE_CALL")
		text = "Everything goes black. You come to in the guard room, shaking. That was %s, and you got lucky. You won't next time.\nHow to survive it: %s" % [
				FieldGuide.display_name(kind), FieldGuide.ENTRIES[kind]["rule"]]
	elif night.shift_team() == 1 and not _second_wind_used:
		_second_wind_used = true
		night.dock(peer, SECOND_WIND_POINTS)
		text = "Everything goes black. You come to in the guard room, head pounding. Second wind: it won't happen twice tonight.  -%d" % SECOND_WIND_POINTS
		if kind != "":
			text += "\n" + FieldGuide.caught_tip(by)
	else:
		return false
	clutter.drop(peer, guard.global_position)
	finale.drop(peer, guard.global_position)
	if hiding.hidden.has(peer):
		hiding._set_hidden.rpc(peer, -1)
	night.nerve.add(peer, -CLOSE_CALL_NERVE)
	director.give_grace(peer, CLOSE_CALL_GRACE)
	director.flash_screen(peer, Color.BLACK, 2.5)
	if peer == multiplayer.get_unique_id():
		_wake_in_guard_room()
	else:
		_wake_in_guard_room.rpc_id(peer)
	get_tree().create_timer(1.5).timeout.connect(func() -> void: _tell(peer, text, 12.0))
	return true


## The guard who was knocked out wakes up in the guard room.
@rpc("authority", "call_remote", "reliable")
func _wake_in_guard_room() -> void:
	if _local_guard == null or _local_guard.is_dead:
		return
	guard_room.leave_desk()
	_local_guard.global_position = CLOSE_CALL_WAKE + Vector3((_local_guard.slot - 2.5) * 0.9, 0, 0)
	_local_guard.velocity = Vector3.ZERO
	SoundBank.play_flat(self, "stinger", -4.0, Sfx.thud(0.5, 0.3, 1.0))


@rpc("authority", "call_local", "reliable")
func _guard_died(peer_id: int, by: String, at: Vector3, from := Vector3.INF) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null:
		return
	guard.set_dead(true)
	director.place_corpse(peer_id, at, guard.uniform_color(), guard.slot)
	if guard == _local_guard:
		guard_room.leave_desk()
		_close_all_ui()
		hud.clear_messages()
		guard.input_blocked = false
		dread.jumpscare(from)
		hud.flash(Color(0.6, 0.0, 0.0, 0.4), 2.0)
		hud.set_ghost(true)
		var tip := FieldGuide.caught_tip(by)
		if players.get_child_count() > 1 and not hud.solo:
			tip += ("\n" if tip != "" else "") + "As a ghost: %s leaves a cold spot and %s watches the cameras. Talk near a teammate with a spirit box switched on (or right by a walkie-talkie) and they'll hear you through the static." % [Controls.key_name("interact"), Controls.key_name("clipboard")]
		hud.show_message("You were caught by %s.%s" % [by, "\n" + tip if tip != "" else ""], 9.0 if tip != "" else 4.0)
		SoundBank.play_flat(self, "stinger", 0.0, Sfx.notes([110.0, 104.0, 98.0, 92.0], 0.35, 0.4, "saw"))
	else:
		hud.show_message("%s was caught by %s." % [guard.display_name(), by])
		dread.witness_catch(at)
	_refresh_guard_visibility()


## Host: a good roll at a revive totem.
func _on_revive_rolled(user_peer: int, roll: int, revived_peer: int, at: Vector3) -> void:
	var user := director.guard_by_peer(user_peer)
	var revived := director.guard_by_peer(revived_peer)
	if user == null or revived == null:
		return
	_announce.rpc("%s rolled a %d at a totem. %s is back!" % [user.display_name(), roll, revived.display_name()])
	night.record_revive(revived_peer)
	career.award(user_peer, "LIFESAVER")
	career.award(revived_peer, "BACK_FROM_DEAD")
	_guard_revived.rpc(revived_peer, at + Vector3(0.8, 0.1, 0))


## Host: a bad roll lets something out of the totem.
func _on_bad_roll(user_peer: int, roll: int, at: Vector3) -> void:
	var user := director.guard_by_peer(user_peer)
	_announce.rpc("%s rolled a %d at a totem. Something climbs out..." % [user.display_name() if user else "Someone", roll])
	director.summon_shade(at + Vector3(0, 0.1, 1.0), user_peer)


@rpc("authority", "call_local", "reliable")
func _guard_revived(peer_id: int, at: Vector3) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null:
		return
	guard.set_dead(false)
	director.remove_corpse(peer_id)
	if guard == _local_guard:
		guard.global_position = at
		hud.set_ghost(false)
		hud.flash(Color(0.3, 0.9, 0.8, 0.6), 1.5)
	_refresh_guard_visibility()


@rpc("authority", "call_local", "reliable")
func _announce(text: String, sound := "") -> void:
	hud.show_message(text)
	if sound == "intercom":
		SoundBank.play_flat(self, "intercom", -2.0, Sfx.notes([660.0, 523.0, 0.0], 0.35, 0.3, "sine"))
	elif sound == "sensor":
		Sfx.play_flat(self, Sfx.notes([1320.0, 0.0, 1320.0], 0.1, 0.2, "square"))


var _bell_sound: AudioStreamPlayer3D


## Every computer: the bell starts or stops. It rings from the hallway ceiling.
@rpc("authority", "call_local", "reliable")
func _set_bell(ringing: bool) -> void:
	director.bell_ringing = ringing
	school.bell_panel.prompt = "Shut off the school bell" if ringing else "School bell panel"
	if _bell_sound:
		_bell_sound.queue_free()
		_bell_sound = null
	if ringing:
		var ring: Array = []
		for i in 24:
			ring.append(1100.0 if i % 2 == 0 else 1180.0)
		ring.append_array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0])
		_bell_sound = Sfx.play_at(school, SoundBank.get_sound("school_bell", Sfx.notes(ring, 0.04, 0.25, "square", true), true), -4.0, 200.0)
		_bell_sound.position = Vector3(0, 3.0, 7.0)
		_bell_sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	elif multiplayer.is_server() and shift.state == Shift.State.ON_SHIFT:
		_announce.rpc("The bell goes quiet.")


@rpc("any_peer", "call_remote", "reliable")
func _request_bell_off() -> void:
	if not multiplayer.is_server():
		return
	if director.bell_ringing:
		director.stop_bell()
	else:
		_tell(_sender_id(), "Switches for the school bell. It's quiet.")


func _sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


@rpc("authority", "call_local", "reliable")
func _camera_signal(camera_index: int, working: bool) -> void:
	cameras.set_signal(camera_index, working)
	# A crackle from the desk when a feed someone's watching cuts out.
	if not working and _local_guard and _local_guard.seated_desk >= 0:
		SoundBank.play_flat(self, "glitch", -6.0)


func _on_vending_used(by: Node) -> void:
	if by != _local_guard or _local_guard.is_dead:
		return
	if not power.on:
		hud.show_message("The vending machine is dead. No power.")
		return
	_local_guard.input_blocked = true
	vending.open(shop.local_points, shop.local_bag, _mode == "solo", _local_guard.rank)


func _refresh_inventory() -> void:
	# What's bought is on the hotbar; this is for something picked up off the floor.
	var carrying := ""
	var in_hand := clutter.carried_name(multiplayer.get_unique_id()) if clutter and multiplayer.multiplayer_peer else ""
	if in_hand != "":
		carrying = "Carrying a %s (%s to throw)" % [in_hand, Controls.key_name("throw")]
	hud.set_inventory(shop.local_points, carrying)
	if vending.is_open:
		vending.refresh(shop.local_points, shop.local_bag)


## Host: sends a message to one player's screen.
## `seconds` of 8 or more makes it a teaching message that holds the screen until read.
func _tell(peer_id: int, text: String, seconds := -1.0) -> void:
	if peer_id == multiplayer.get_unique_id():
		_show_local_message(text, seconds)
	else:
		_receive_message.rpc_id(peer_id, text, seconds)


func _refresh_guard_visibility() -> void:
	var viewer_is_dead := _local_guard != null and _local_guard.is_dead
	for guard: Guard in players.get_children():
		guard.update_visibility(viewer_is_dead)


## Every computer: this player just unlocked an achievement.
## Called (through the "game" group) when this player reaches a new rank.
func on_rank_up(rank: int, title: String) -> void:
	hud.show_message("PROMOTED: you're now a %s (rank %d)." % [title, rank])
	night.report.promotion = "Promoted to %s (rank %d)." % [title, rank]
	var unlocked: Array[String] = []
	for item: String in Shop.ITEMS:
		if Shop.rank_needed(item) == rank:
			unlocked.append(Shop.item_name(item))
	if not unlocked.is_empty():
		night.report.promotion += " New at the vending machine: " + ", ".join(unlocked) + "."
	for hat: String in Hats.HATS:
		if int(Hats.HATS[hat].get("rank", 0)) == rank:
			night.report.promotion += " New hat: %s (put it on at the staff locker in the guard room)." % Hats.HATS[hat]["name"]
	for perk: String in Perks.PERKS:
		if int(Perks.PERKS[perk]["rank"]) == rank:
			night.report.promotion += " New perk: %s (pick it on the guard room duty roster)." % Perks.describe(perk)
	Sfx.play_flat(self, Sfx.notes([523.0, 659.0, 784.0, 1047.0], 0.14, 0.3, "triangle"))
	if _local_guard:
		_local_guard.rank = rank
		if multiplayer.is_server():
			_request_rank(rank)
		else:
			_request_rank.rpc_id(1, rank)


## Host: a guard was promoted mid-session; everyone updates their rank (and the shop knows).
@rpc("any_peer", "call_remote", "reliable")
func _request_rank(rank: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	_set_rank.rpc(peer, clampi(rank, 1, Career.RANKS.size()))


@rpc("authority", "call_local", "reliable")
func _set_rank(peer_id: int, rank: int) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard:
		guard.rank = rank
		guard.refresh_tag()


# --- The staff locker: change your hat (any time) and perk (before the shift) mid-session ---

const LOCKER_AT := Vector3(18.6, 0.0, 10.3)


func _build_staff_locker() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.32, 0.36, 0.4)
	metal.metallic = 0.5
	metal.roughness = 0.5
	var locker := _staff_fitting(LOCKER_AT + Vector3(0, 0.95, 0), Vector3(0.6, 1.9, 0.45), metal, "Staff locker: change your hat")
	locker.used.connect(func(by: Node) -> void:
		if by == _local_guard:
			_next_look(true))
	var cork := StandardMaterial3D.new()
	cork.albedo_color = Color(0.55, 0.42, 0.28)
	var roster := _staff_fitting(LOCKER_AT + Vector3(-0.85, 1.45, -0.18), Vector3(0.6, 0.45, 0.04), cork, "Duty roster: change your perk")
	roster.used.connect(func(by: Node) -> void:
		if by == _local_guard:
			_next_look(false))
	var label := Label3D.new()
	label.text = "DUTY ROSTER"
	label.font_size = 28
	label.pixel_size = 0.003
	label.modulate = Color(0.1, 0.08, 0.06)
	label.outline_size = 0
	label.position = Vector3(0, 0.15, 0.025)
	roster.add_child(label)


func _staff_fitting(at: Vector3, size: Vector3, look: StandardMaterial3D, prompt: String) -> Interactable:
	var body := Interactable.new()
	body.prompt = prompt
	body.position = at
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = look
	body.add_child(mesh)
	add_child(body)
	return body


## The next unlocked hat (or perk), worn at once and remembered for next time.
func _next_look(hat: bool) -> void:
	if _local_guard == null:
		return
	var hat_id := _local_guard.hat
	var perk_id := _local_guard.perk
	if hat:
		var hats: Array = Hats.HATS.keys().filter(func(each: String) -> bool: return Hats.is_unlocked(each))
		hat_id = hats[(hats.find(hat_id) + 1) % hats.size()]
		Profile.hat = hat_id
		hud.show_message("Hat: %s" % Hats.HATS[hat_id]["name"], 2.5)
	else:
		if shift.state != Shift.State.PRE_SHIFT:
			hud.show_message("The roster's set for tonight. Change your perk before the next shift.")
			return
		var perks: Array = Perks.PERKS.keys().filter(func(each: String) -> bool: return Perks.is_unlocked(each))
		perk_id = perks[(perks.find(perk_id) + 1) % perks.size()]
		Profile.perk = perk_id
		hud.show_message(Perks.describe(perk_id), 4.0)
	Profile.save_settings()
	if multiplayer.is_server():
		_request_look(hat_id, perk_id)
	else:
		_request_look.rpc_id(1, hat_id, perk_id)


@rpc("any_peer", "call_remote", "reliable")
func _request_look(hat: String, perk: String) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := players.get_node_or_null(str(peer)) as Guard
	if guard == null or not Hats.HATS.has(hat):
		return
	# (A hat that needs a rank they haven't got stays off; achievement hats are taken on trust.)
	if guard.rank < int(Hats.HATS[hat].get("rank", 1)):
		hat = guard.hat
	# Perks only change before the shift (they're part of the night's plan).
	if shift.state != Shift.State.PRE_SHIFT:
		perk = guard.perk
	_set_look.rpc(peer, hat, Perks.valid(perk, guard.rank))


## Every computer: a guard's hat and perk.
@rpc("authority", "call_local", "reliable")
func _set_look(peer_id: int, hat: String, perk: String) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null:
		return
	if guard.hat != hat:
		guard.change_hat(hat)
	if guard.perk != perk:
		guard.perk = perk
		guard.has_emf = guard.emf_fitted or perk == "lookout"
		guard.apply_flashlight()


func on_bounty(title: String, xp: int) -> void:
	hud.show_message("District bounty complete: %s  (+%d XP)" % [title, xp])


func on_achievement(title: String) -> void:
	hud.show_message("Achievement unlocked: %s" % title)
	Sfx.play_flat(self, Sfx.notes([784.0, 988.0, 1175.0, 1568.0], 0.09, 0.22, "sine"))


## Every computer, when the night report appears: leave the desk and stop moving.
func on_report() -> void:
	_close_all_ui()
	hud.clear_messages()
	if _local_guard:
		guard_room.leave_desk()
		_local_guard.input_blocked = true


## Every computer, when the host starts the next night: back to the gate, lights on, desks empty.
func on_next_night() -> void:
	school.clock_machine.prompt = "Clock in"
	_clocked_in = false
	_close_all_ui()
	hud.clear_messages()
	# After a team wipe the lights are still down; bring them back for the evening.
	lighting.go_bright()
	ambience.stop()
	# The wings stay locked until the night starts.
	school.open_wings(1)
	# Everyone starts the new night alive.
	for guard: Guard in players.get_children():
		guard.set_dead(false)
	director.remove_all_corpses()
	# Everyone has to clock in again (the morning only counted the living).
	if multiplayer.is_server():
		_update_guards_required()
	hud.set_ghost(false)
	_refresh_guard_visibility()
	if _local_guard:
		guard_room.leave_desk()
		_local_guard.input_blocked = false
		_local_guard.flashlight.visible = false
		_local_guard.global_position = SPAWN_POINT + Vector3((_local_guard.slot - 2.5) * 1.4, 0, 0)
		_local_guard.rotation.y = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_local_message(message: String, seconds := -1.0) -> void:
	if _local_guard:
		_local_guard.show_message(message, seconds)


# --- World ---------------------------------------------------------------------

func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	# Soft shadow where things meet (walls and floor, furniture), and a thin haze in the air that
	# catches the flashlight beams. Both switched by the "Ambient occlusion and haze" setting.
	env.ssao_radius = 1.1
	env.ssao_intensity = 1.8
	env.ssao_power = 1.4
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.7, 0.72, 0.75)
	env.volumetric_fog_length = 40.0
	env.volumetric_fog_ambient_inject = 0.0
	# Light bouncing round the rooms: a lit classroom spills a warm glow into the dark hall, and a
	# flashlight on a wall lights the room a little. Switched by the "Bounced light" setting.
	env.sdfgi_use_occlusion = true
	env.sdfgi_cascades = 4
	env.sdfgi_min_cell_size = 0.2
	env.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_50_PERCENT
	env.sdfgi_energy = 1.0
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.8
	env.sdfgi_enabled = Profile.bounce_light
	env.ssil_enabled = Profile.bounce_light
	env.ssao_enabled = Profile.effects
	env.volumetric_fog_enabled = Profile.effects

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	world_env.add_to_group("world_env")
	add_child(world_env)
	(func() -> void: Profile.apply_brightness()).call_deferred()

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.25
	moon.shadow_enabled = true
	moon.add_to_group(Profile.SHADOW_LIGHTS)
	moon.shadow_enabled = Profile.shadows
	moon.rotation_degrees = Vector3(-40, 35, 0)
	moon.light_volumetric_fog_energy = 0.4
	add_child(moon)
	return env
