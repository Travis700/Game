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

const PORT := 7777
const MAX_GUARDS := 4
## Where guards start each night: outside the gate, facing the school (north is -Z).
const SPAWN_POINT := Vector3(0, 0.1, 54)

## Shown on the menu after returning to it, e.g. "The host ended the session."
static var _menu_message := ""

var shift: Shift
var lighting: ShiftLighting
var hud: CanvasLayer
var menu: CanvasLayer
var players: Node3D
var cameras: SecurityCameras
var guard_room: GuardRoom
var spawner: MultiplayerSpawner
var _local_guard: Guard
var _mode := ""


func _ready() -> void:
	add_to_group("game")
	var environment := _make_environment()

	var school := SchoolBuilder.new()
	school.name = "School"
	add_child(school)

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
	shift.started.connect(func() -> void: school.clock_machine.prompt = "Check time clock")
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

	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.solo_requested.connect(_play_solo)
	menu.host_requested.connect(_host)
	menu.join_requested.connect(_join)
	menu.show_status(_menu_message)
	_menu_message = ""

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	_start_from_command_line()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _process(_delta: float) -> void:
	if _mode == "":
		return
	var guards := players.get_child_count()
	var status := "Solo" if _mode == "solo" else "%s · %d guard%s" % [_mode, guards, "" if guards == 1 else "s"]
	hud.set_status(status)


# --- Starting a session --------------------------------------------------------

## Lets Godot's "Customize Run Instances" start copies of the game straight into a session.
## Launch arguments: --solo, --host, or --join (optionally --join=ADDRESS).
func _start_from_command_line() -> void:
	for arg in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if arg == "--solo":
			_play_solo()
		elif arg == "--host":
			_use_test_window(0)
			_host()
		elif arg.begins_with("--join"):
			_use_test_window(1)
			_join(arg.get_slice("=", 1) if "=" in arg else "127.0.0.1")


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
	_enter_school()
	_spawn_guard(1)


func _host() -> void:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, MAX_GUARDS - 1)
	if error != OK:
		menu.show_status("Couldn't host on port %d. Is another copy of the game already hosting?" % PORT)
		return
	multiplayer.multiplayer_peer = peer
	_mode = "Hosting"
	_enter_school()
	_spawn_guard(1)
	print("[net] Hosting on port %d" % PORT)


func _join(address: String) -> void:
	if address == "":
		menu.show_status("Type the host's address first.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, PORT)
	if error != OK:
		menu.show_status("Couldn't start connecting to %s." % address)
		return
	multiplayer.multiplayer_peer = peer
	menu.set_busy(true)
	menu.show_status("Connecting to %s..." % address)


func _on_connected_to_server() -> void:
	_mode = "Connected"
	_enter_school()
	print("[net] Joined as peer %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = null
	menu.set_busy(false)
	menu.show_status("Couldn't reach the host. Check the address, and that the host is in a game.")


func _on_server_disconnected() -> void:
	_back_to_menu("The host ended the session.")


func _enter_school() -> void:
	menu.visible = false
	hud.visible = true


func _back_to_menu(message: String) -> void:
	_menu_message = message
	multiplayer.multiplayer_peer = null
	get_tree().reload_current_scene()


# --- Guards (host only) ------------------------------------------------------------

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if shift.state == Shift.State.ON_SHIFT:
		_turn_away.rpc_id(peer_id, "That team's shift has already started.")
		return
	print("[net] Guard joined (peer %d)" % peer_id)
	guard_room.send_state_to(peer_id)
	_spawn_guard(peer_id)
	_update_guards_required()


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	print("[net] Guard left (peer %d)" % peer_id)
	var guard := players.get_node_or_null(str(peer_id))
	if guard:
		guard.queue_free()
	shift.remove_guard(peer_id)
	guard_room.on_peer_left(peer_id)
	# Count the guards once the leaver's node is gone.
	_update_guards_required.call_deferred()


## Host only. The spawner runs _create_guard with the same data on every computer,
## including players who join later.
func _spawn_guard(peer_id: int) -> void:
	spawner.spawn({"peer_id": peer_id, "slot": _free_slot()})


func _create_guard(data: Dictionary) -> Node:
	var guard := PlayerScene.instantiate() as Guard
	guard.name = str(data["peer_id"])
	guard.slot = data["slot"]
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


func _update_guards_required() -> void:
	shift.guards_required = players.get_child_count()
	if shift.state == Shift.State.PRE_SHIFT and shift.clocked_in_count() > 0 and shift.everyone_clocked_in():
		_start_night.rpc()


@rpc("authority", "call_remote", "reliable")
func _turn_away(reason: String) -> void:
	_back_to_menu(reason)


## Called by each guard's own computer when it spawns, to hook up that player's HUD.
func on_local_guard_ready(guard: Guard) -> void:
	_local_guard = guard
	guard.prompt_changed.connect(hud.set_prompt)
	guard.message_shown.connect(hud.show_message)
	guard.desk_action.connect(guard_room.on_desk_action)
	guard_room.local_guard = guard
	cameras.viewer = guard


# --- Clocking in ---------------------------------------------------------------

func _on_clock_machine_used(_guard: Node) -> void:
	if multiplayer.is_server():
		_handle_clock_in(multiplayer.get_unique_id())
	else:
		_request_clock_in.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_clock_in() -> void:
	if multiplayer.is_server():
		_handle_clock_in(multiplayer.get_remote_sender_id())


func _handle_clock_in(peer_id: int) -> void:
	var message := shift.clock_in(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_show_local_message(message)
	else:
		_receive_message.rpc_id(peer_id, message)
	if shift.state == Shift.State.PRE_SHIFT and shift.everyone_clocked_in():
		_start_night.rpc()


@rpc("authority", "call_local", "reliable")
func _start_night() -> void:
	print("[net] Night started")
	shift.begin()


@rpc("authority", "call_remote", "reliable")
func _receive_message(message: String) -> void:
	_show_local_message(message)


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
	moon.rotation_degrees = Vector3(-40, 35, 0)
	add_child(moon)
	return env
