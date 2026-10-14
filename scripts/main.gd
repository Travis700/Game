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
## Real seconds between the last guard being caught and the night's results.
const SCARE_SECONDS := 2.0

const PORT := 7777
const MAX_GUARDS := 4
## Where guards start each night: outside the gate, facing the school (north is -Z).
const SPAWN_POINT := Vector3(0, 0.1, 54)

## Shown on the menu after returning to it, e.g. "The host ended the session."
static var _menu_message := ""

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
var vending: CanvasLayer
var keypad: CanvasLayer
var ambience: Ambience
var voice: VoiceChat
var career: Career
var dread: Dread
var rounds: Rounds
var _siren: AudioStreamPlayer
var hiding: Hiding
## Host: when each ghost may next leave a cold spot.
var _ghost_ping_at: Dictionary = {}
var power: Power
var pause_menu: CanvasLayer
var spawner: MultiplayerSpawner
var _local_guard: Guard
var _mode := ""
## True once this player has clocked in for the coming night (before it starts).
var _clocked_in := false
## Command-line test sessions (--host/--join) always use direct connections, even with Steam.
var _direct_only := false


func _ready() -> void:
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
	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	shift.started.connect(ambience.start)
	shift.morning_started.connect(ambience.stop)
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
	menu_camera.position = Vector3(9, 2.2, 52)
	menu_camera.rotation_degrees = Vector3(-3, 12, 0)
	add_child(menu_camera)
	menu_camera.current = true

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
	director.lockdown_changed.connect(func(on: bool) -> void: _set_lockdown.rpc(on))
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
	director.voice = voice
	add_child(voice)

	dread = Dread.new()
	dread.name = "Dread"
	dread.director = director
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
	totems.shop = shop
	guard_room.shop = shop
	vending = VendingUI.new()
	vending.name = "Vending"
	add_child(vending)
	vending.buy_requested.connect(shop.request_buy)
	vending.closed.connect(_on_ui_closed)
	shop.wallet_changed.connect(func(_points: int) -> void: _refresh_inventory())
	shop.holding_changed.connect(func(_item: String) -> void: _refresh_inventory())
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
	pause_menu.closed.connect(hud.refresh_key_hint)
	pause_menu.voice = voice
	pause_menu.leave_requested.connect(func() -> void:
		_back_to_menu("You ended the session." if multiplayer.is_server() and _mode != "solo" else ""))

	var report := Report.new()
	report.name = "Report"
	add_child(report)

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
	night.totems = totems
	night.shop = shop
	night.guard_room = guard_room
	night.doors = doors
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
	power.career = career
	add_child(power)
	power.breaker_reset.connect(night.add_bonus)
	night.power = power
	var conditions := Conditions.new()
	conditions.name = "Conditions"
	conditions.lighting = lighting
	conditions.players = players
	conditions.hud = hud
	add_child(conditions)
	night.conditions = conditions
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
	var nerve := Nerve.new()
	nerve.name = "Nerve"
	nerve.director = director
	nerve.players = players
	nerve.power = power
	nerve.hud = hud
	add_child(nerve)
	night.nerve = nerve
	director.nerve = nerve
	dread.night = night
	add_child(night)
	shop.night = night
	director.student_helped.connect(func(peer_id: int) -> void:
		night.add_bonus(peer_id)
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
		if menu.confirm_new_run():
			_host())
	menu.join_requested.connect(_join)
	menu.daily_requested.connect(_play_daily)
	night.daily_finished.connect(func() -> void: _back_to_menu(""))
	SteamService.lobby_ready.connect(_on_steam_lobby_ready)
	SteamService.lobby_failed.connect(_on_steam_lobby_failed)
	SteamService.invite_accepted.connect(_on_steam_invite)
	SteamService.set_presence("In the main menu")
	menu.set_steam_status(SteamService.available, SteamService.user_name)
	if SteamService.pending_lobby != 0 and _mode == "":
		_on_steam_invite.call_deferred(SteamService.pending_lobby)
	menu.show_status(_menu_message)
	_menu_message = ""

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


## Closes every menu, e.g. when your guard is caught or the night report comes up.
func _close_all_ui() -> void:
	clipboard.close()
	keypad.close()
	vending.close()
	pause_menu.close()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(_delta: float) -> void:
	if _mode == "":
		return
	var guards := players.get_child_count()
	var status := "Solo" if _mode == "solo" else "%s · %d guard%s" % [_mode, guards, "" if guards == 1 else "s"]
	if _room_code != "":
		status = "Room %s%s · %s" % [_room_code, " (password)" if _password != "" else "", status]
	if _local_guard:
		status += " · Badge #%04d" % _local_guard.employee_number
	if night.difficulty > 0:
		status += " · Difficulty %d" % night.difficulty
	hud.set_objective(_objective())
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
	_spawn_guard(1, Profile.employee_number, _player_name(), Career.rank(), _hat())


## Today's daily shift: one solo night, the same for everyone today. Never touches the saved run.
func _play_daily() -> void:
	menu._continue.button_pressed = false
	night.daily = Daily.today()
	night.keep_gear = false
	_play_solo()
	night.number = Daily.night_of(night.daily)
	night.give_everyone(Daily.STARTING_POINTS)


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
	_start_run()
	_enter_school()
	_spawn_guard(1, Profile.employee_number, _player_name(), Career.rank(), _hat())


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
	night.difficulty_choice = options["difficulty"]
	night.keep_gear = options["keep_gear"]
	# The daily shift is the same length for everyone.
	night.seconds_per_minute = Night.SECONDS_PER_MINUTE if night.daily != "" else options["seconds_per_minute"]
	_password = options["password"]
	if not options["continue"]:
		return
	var saved := RunSave.read()
	night.number = clampi(int(saved.get("night", 1)), 1, 99)
	night.saved_points = saved.get("points", {})
	night.saved_items = saved.get("items", {})
	if saved.get("in_progress", false):
		# The last session quit in the middle of a night. Replaying it costs that night's
		# survival pay, so quitting isn't a way out of a bad night.
		for key: String in night.saved_points:
			night.saved_points[key] = maxi(int(night.saved_points[key]) - Night.SURVIVAL_PAY, 0)
		menu.show_status("Last time, the run was left mid-shift. Everyone loses %d points." % Night.SURVIVAL_PAY)
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
	night.run_team = int(saved.get("team", 0))
	# Saves from before the walkie-talkie listed flashlights on their own.
	for badge: String in saved.get("bright", []):
		var list: Array = night.saved_personal.get_or_add(badge, [])
		if "flashlight" not in list:
			list.append("flashlight")
	print("[run] Continuing the saved run: ", RunSave.describe(saved))


## The hat this player picked, if they've still got it unlocked.
func _hat() -> String:
	return Profile.hat if Hats.is_unlocked(Profile.hat) else "cap"


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
	_register_employee.rpc_id(1, Profile.employee_number, _password, _player_name(), Career.rank(), _hat())
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
	if shift.state == Shift.State.ON_SHIFT:
		_reject(peer_id, "That team's shift has already started.")
		return
	print("[net] Guard joined (peer %d)" % peer_id)
	guard_room.send_state_to(peer_id)
	anomalies.send_state_to(peer_id)
	# Their guard spawns once their computer tells us their badge number (_register_employee).


## Host: a player who just joined shows their badge. Their guard spawns with it.
@rpc("any_peer", "call_remote", "reliable")
func _register_employee(badge: int, password: String, player_name := "", rank := 1, hat := "cap") -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.is_server() or players.has_node(str(peer_id)):
		return
	if password != _password:
		_reject(peer_id, "Wrong room password." if password != "" else "That room needs a password.")
		return
	if shift.state != Shift.State.PRE_SHIFT:
		_reject(peer_id, "That team's shift has already started.")
		return
	if players.get_child_count() >= MAX_GUARDS:
		_reject(peer_id, "That team is full.")
		return
	# Two copies of the game on one computer share a badge. Lend the second one a spare.
	while badge < 1000 or _badge_in_use(badge):
		badge = randi_range(1000, 9999)
	_spawn_guard(peer_id, badge, player_name, rank, hat)
	# Spawn data is replayed as it was first sent: tell them about anyone promoted since.
	for guard: Guard in players.get_children():
		if guard.name.to_int() != peer_id:
			_set_rank.rpc_id(peer_id, guard.name.to_int(), guard.rank)
	shop.send_state_to(peer_id)
	doors.send_state_to(peer_id)
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
	if guard:
		# Keep what they had, by badge, so they get exactly that back if they rejoin.
		night.remember_guard(guard)
		guard.queue_free()
	shift.remove_guard(peer_id)
	guard_room.on_peer_left(peer_id)
	if hiding.hidden.has(peer_id):
		hiding._set_hidden.rpc(peer_id, -1)
	_update_guards_required()


## Host only. The spawner runs _create_guard with the same data on every computer,
## including players who join later.
func _spawn_guard(peer_id: int, badge: int, player_name := "", rank := 1, hat := "cap") -> void:
	# Personal upgrades go in the spawn data so every computer builds the guard with them.
	var personal: Array = night.saved_personal.get(str(badge), [])
	spawner.spawn({"peer_id": peer_id, "slot": _free_slot(), "badge": badge, "personal": personal,
			"name": player_name.left(24), "rank": clampi(rank, 1, Career.RANKS.size()),
			"hat": hat if Hats.HATS.has(hat) else "cap"})
	night.restore_guard(peer_id, badge)


func _create_guard(data: Dictionary) -> Node:
	var guard := PlayerScene.instantiate() as Guard
	guard.name = str(data["peer_id"])
	guard.slot = data["slot"]
	guard.employee_number = data.get("badge", 0)
	guard.player_name = data.get("name", "")
	guard.rank = data.get("rank", 1)
	guard.hat = data.get("hat", "cap")
	guard.bright_flashlight = "flashlight" in data.get("personal", [])
	guard.has_radio = "radio" in data.get("personal", [])
	guard.has_emf = "emf" in data.get("personal", [])
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


func _update_guards_required() -> void:
	if shift.state == Shift.State.ON_SHIFT and _guard_count() > 0 and director.living_guards().is_empty():
		night.fail_night()
		return
	if shift.state == Shift.State.MORNING:
		shift.guards_required = director.living_guards().size()
		if shift.everyone_clocked_out():
			night._end_night()
		return
	shift.guards_required = _guard_count()
	if shift.state == Shift.State.PRE_SHIFT and shift.clocked_in_count() > 0 and shift.everyone_clocked_in():
		_start_night.rpc(night.number, night.pick_difficulty())


## Host: tells a player why they can't join, then disconnects them once the message is through.
func _reject(peer_id: int, reason: String) -> void:
	_turn_away.rpc_id(peer_id, reason)
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		if multiplayer.multiplayer_peer is ENetMultiplayerPeer and peer_id in multiplayer.get_peers():
			(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(peer_id))


@rpc("authority", "call_remote", "reliable")
func _turn_away(reason: String) -> void:
	_back_to_menu(reason)


## Called by each guard's own computer when it spawns, to hook up that player's HUD.
func on_local_guard_ready(guard: Guard) -> void:
	_local_guard = guard
	guard.prompt_changed.connect(hud.set_prompt)
	guard.message_shown.connect(hud.show_message)
	guard.desk_action.connect(guard_room.on_desk_action)
	guard.clipboard_requested.connect(_open_clipboard)
	guard.leave_hiding_requested.connect(func() -> void:
		if multiplayer.is_server():
			hiding._request(-1)
		else:
			hiding._request.rpc_id(1, -1))
	guard.ghost_ping_requested.connect(func(at: Vector3) -> void:
		if multiplayer.is_server():
			_request_ghost_ping(at)
		else:
			_request_ghost_ping.rpc_id(1, at))
	guard.item_use_requested.connect(func() -> void:
		if not guard_room.try_install():
			shop.request_use())
	guard.pause_requested.connect(func() -> void:
		guard.input_blocked = true
		pause_menu.open(_mode == "solo", _mode == "Hosting"))
	doors.local_guard = guard
	guard_room.local_guard = guard
	cameras.viewer = guard
	ambience.listener = guard
	night.nerve.local_guard = guard
	dread.local_guard = guard
	voice.local_guard = guard
	voice.set_active(true)


# --- Clocking in ---------------------------------------------------------------

func _on_clock_machine_used(by: Node) -> void:
	if by != _local_guard or _local_guard.is_dead:
		return
	if shift.state == Shift.State.PRE_SHIFT:
		# Clocking in takes your badge number.
		_local_guard.input_blocked = true
		keypad.open("#%04d" % _local_guard.employee_number)
		return
	_request_time_clock()


var _boost_was_on := false


## The line under the clock telling you what to do next.
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
			var text := "Survive until 6 AM. Watch the cameras and log anything odd (%s)." % Controls.key_name("clipboard")
			var round_text := rounds.objective_text()
			if round_text != "":
				text += "\n" + round_text
			if night.bonus.status != "":
				text += "\n" + night.bonus.status
			if not night.conditions.active.is_empty():
				text += "\nTonight: " + ", ".join(night.conditions.names())
			return text
		Shift.State.MORNING:
			return "It's 6 AM. Clock out at the time clock in the guard room to get paid."
	return ""


func _on_keypad_submitted(number: int) -> void:
	if _local_guard == null or number != _local_guard.employee_number:
		keypad.flash_display("UNKNOWN")
		Sfx.play_flat(self, Sfx.notes([220.0, 180.0], 0.15, 0.25, "square"))
		return
	keypad.close()
	_clocked_in = true
	Sfx.play_flat(self, Sfx.notes([880.0, 1320.0], 0.08, 0.25, "square"))
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
	if shift.state == Shift.State.PRE_SHIFT and shift.everyone_clocked_in():
		_start_night.rpc(night.number, night.pick_difficulty())


@rpc("authority", "call_local", "reliable")
func _start_night(number: int, difficulty: int) -> void:
	print("[net] Night %d started at difficulty %d" % [number, difficulty])
	night.number = number
	night.difficulty = difficulty
	cameras.clear_references()
	_apply_difficulty(difficulty)
	shift.begin()
	_clocked_in = false
	# A few minutes in, every camera takes a photo to compare against later.
	get_tree().create_timer(night.seconds_per_minute * 5.0).timeout.connect(func() -> void:
		if shift.state == Shift.State.ON_SHIFT:
			cameras.capture_references(night.time_text()))
	SteamService.set_presence("Overtime: night %d" % number if number > Night.LAST_NIGHT
			else "Night %d of %d" % [number, Night.LAST_NIGHT])
	if number == 1:
		_show_first_night_tips()
	elif number == 2:
		hud.show_message("Tip: from tonight the power can go out. The breaker is in the custodian's closet, across the hall from the lobby.")


## A few pointers on the first night, a few seconds apart.
func _show_first_night_tips() -> void:
	var tips: Array[String] = [
		"Tip: sit at a desk (E on a chair) to watch the cameras. A / D changes a monitor's camera.",
		"Tip: something moved, missing, or there that shouldn't be? Press Tab and log where and what. Wrong guesses cost points.",
		"Tip: the real night cleaner moves things too. Learn what's normal.",
		"Tip: tonight's round is at the top of the screen. Find the amber lamps and hold E to punch them. The bell is loud.",
		"Tip: at 6 AM, clock out at the time clock or you don't get paid.",
	]
	for i in tips.size():
		get_tree().create_timer(8.0 + i * 14.0).timeout.connect(func() -> void:
			if shift.state == Shift.State.ON_SHIFT and night.number == 1:
				hud.show_message(tips[i]))


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
	cameras.difficulty = difficulty
	anomalies.difficulty = difficulty
	director.difficulty = difficulty
	clipboard.set_areas(anomalies.areas(difficulty))
	if multiplayer.is_server():
		guard_room.fit_to_open_cameras()


## Host: a ghost left a cold spot. One every few seconds each, so it can't be spammed.
@rpc("any_peer", "call_remote", "reliable")
func _request_ghost_ping(at: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := players.get_node_or_null(str(peer)) as Guard
	var now := Time.get_ticks_msec() / 1000.0
	if guard == null or not guard.is_dead or now < float(_ghost_ping_at.get(peer, 0.0)):
		return
	if shift.state != Shift.State.ON_SHIFT or at.distance_to(guard.global_position) > 30.0:
		return
	_ghost_ping_at[peer] = now + GHOST_PING_EVERY
	_ghost_ping.rpc(at, guard.slot)


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
		hud.show_message("A cold spot. Guard %d is trying to tell you something." % slot)


## Every computer: the lockdown alarm wails (or stops).
@rpc("authority", "call_local", "reliable")
func _set_lockdown(on: bool) -> void:
	if on:
		if _siren == null:
			_siren = AudioStreamPlayer.new()
			var freqs: Array = []
			for i in 16:
				freqs.append(520.0 + 380.0 * sin(i / 16.0 * PI))
			_siren.stream = Sfx.notes(freqs, 0.08, 0.22, "saw", true)
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
func _receive_message(message: String) -> void:
	_show_local_message(message)


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


# --- Caught, ghosts and totems ---------------------------------------------------------------

## Host: a monster caught a guard.
func _on_guard_caught(peer_id: int, by: String, from := Vector3.INF) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null or guard.is_dead:
		return
	night.record_death()
	# Caught in a cupboard (e.g. by the Self-Portrait): the ghost climbs out.
	if hiding.hidden.has(peer_id):
		hiding._set_hidden.rpc(peer_id, -1)
	night.bonus.on_caught(guard)
	night.nerve.on_caught(guard)
	career.add_stat(peer_id, "times_caught")
	_guard_died.rpc(peer_id, by, guard.global_position, from)
	if director.living_guards().is_empty():
		# Give the last guard's jumpscare time to play before the night's results cover it.
		get_tree().create_timer(SCARE_SECONDS).timeout.connect(func() -> void:
			if director.living_guards().is_empty():
				night.fail_night())


@rpc("authority", "call_local", "reliable")
func _guard_died(peer_id: int, by: String, at: Vector3, from := Vector3.INF) -> void:
	var guard := players.get_node_or_null(str(peer_id)) as Guard
	if guard == null:
		return
	guard.set_dead(true)
	director.place_corpse(peer_id, at, guard.uniform_color())
	if guard == _local_guard:
		guard_room.leave_desk()
		_close_all_ui()
		guard.input_blocked = false
		dread.jumpscare(from)
		hud.flash(Color(0.6, 0.0, 0.0, 0.4), 2.0)
		hud.set_ghost(true)
		hud.show_message("You were caught by %s." % by)
		Sfx.play_flat(self, Sfx.notes([110.0, 104.0, 98.0, 92.0], 0.35, 0.4, "saw"))
	else:
		hud.show_message("Guard %d was caught by %s." % [guard.slot, by])
	_refresh_guard_visibility()


## Host: a good roll at a revive totem.
func _on_revive_rolled(user_peer: int, roll: int, revived_peer: int, at: Vector3) -> void:
	var user := director.guard_by_peer(user_peer)
	var revived := director.guard_by_peer(revived_peer)
	if user == null or revived == null:
		return
	_announce.rpc("Guard %d rolled a %d at a totem. Guard %d is back!" % [user.slot, roll, revived.slot])
	night.record_revive()
	career.award(user_peer, "LIFESAVER")
	career.award(revived_peer, "BACK_FROM_DEAD")
	_guard_revived.rpc(revived_peer, at + Vector3(0.8, 0.1, 0))


## Host: a bad roll lets something out of the totem.
func _on_bad_roll(user_peer: int, roll: int, at: Vector3) -> void:
	var user := director.guard_by_peer(user_peer)
	_announce.rpc("Guard %d rolled a %d at a totem. Something climbs out..." % [user.slot if user else 0, roll])
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
		Sfx.play_flat(self, Sfx.notes([660.0, 523.0, 0.0], 0.35, 0.3, "sine"))
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
		_bell_sound = Sfx.play_at(school, Sfx.notes(ring, 0.04, 0.25, "square", true), -4.0, 200.0)
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


func _on_vending_used(by: Node) -> void:
	if by != _local_guard or _local_guard.is_dead:
		return
	if not power.on:
		hud.show_message("The vending machine is dead. No power.")
		return
	_local_guard.input_blocked = true
	vending.open(shop.local_points, shop.local_item, _mode == "solo", _local_guard.rank)


func _refresh_inventory() -> void:
	var carrying := Shop.item_name(shop.local_item)
	if shop.local_item in Shop.USED_WITH_G:
		carrying += "  (G to use)"
	hud.set_inventory(shop.local_points, carrying)
	if vending.is_open:
		vending.refresh(shop.local_points, shop.local_item)


## Host: sends a message to one player's screen.
func _tell(peer_id: int, text: String) -> void:
	if peer_id == multiplayer.get_unique_id():
		_show_local_message(text)
	else:
		_receive_message.rpc_id(peer_id, text)


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
			night.report.promotion += " New hat: %s (pick it on the menu)." % Hats.HATS[hat]["name"]
	Sfx.play_flat(self, Sfx.notes([523.0, 659.0, 784.0, 1047.0], 0.14, 0.3, "triangle"))
	if _local_guard:
		_local_guard.rank = rank
		if multiplayer.is_server():
			_request_rank(rank)
		else:
			_request_rank.rpc_id(1, rank)


## Host: a guard was promoted mid-session; everyone updates their name tag (and the shop knows).
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


func on_achievement(title: String) -> void:
	hud.show_message("Achievement unlocked: %s" % title)
	Sfx.play_flat(self, Sfx.notes([784.0, 988.0, 1175.0, 1568.0], 0.09, 0.22, "sine"))


## Every computer, when the night report appears: leave the desk and stop moving.
func on_report() -> void:
	_close_all_ui()
	if _local_guard:
		guard_room.leave_desk()
		_local_guard.input_blocked = true


## Every computer, when the host starts the next night: back to the gate, lights on, desks empty.
func on_next_night() -> void:
	school.clock_machine.prompt = "Clock in"
	_clocked_in = false
	_close_all_ui()
	# After a team wipe the lights are still down; bring them back for the evening.
	lighting.go_bright()
	ambience.stop()
	# The wings stay locked until the night starts.
	school.open_wings(1)
	# Everyone starts the new night alive.
	for guard: Guard in players.get_children():
		guard.set_dead(false)
	director.remove_all_corpses()
	hud.set_ghost(false)
	_refresh_guard_visibility()
	if _local_guard:
		guard_room.leave_desk()
		_local_guard.input_blocked = false
		_local_guard.flashlight.visible = false
		_local_guard.global_position = SPAWN_POINT + Vector3((_local_guard.slot - 2.5) * 1.4, 0, 0)
		_local_guard.rotation.y = 0.0
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show_local_message(message: String) -> void:
	if _local_guard:
		_local_guard.show_message(message)


# --- World ---------------------------------------------------------------------

func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.25
	moon.shadow_enabled = true
	moon.add_to_group(Profile.SHADOW_LIGHTS)
	moon.shadow_enabled = Profile.shadows
	moon.rotation_degrees = Vector3(-40, 35, 0)
	add_child(moon)
	return env
