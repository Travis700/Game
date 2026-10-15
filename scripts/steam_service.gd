extends Node
## Steam: lobbies (with a short code to share), friend invites, rich presence, achievements
## and stats. Uses the GodotSteam add-on when it's installed and Steam is running; otherwise
## everything here quietly does nothing and the game uses direct connections and room codes.
##
## GodotSteam is looked up while the game runs (not referenced by name), so the project opens
## and runs without it. See STEAM.md for setting it up.
##
## Networking over Steam uses GodotSteam's SteamMultiplayerPeer, so the rest of the game's
## multiplayer works exactly as it does over a direct connection.

## A lobby is ready and its multiplayer peer is set up: the game can start (hosting) or
## register with the host (joining).
signal lobby_ready(peer: MultiplayerPeer, is_host: bool)
## Something went wrong with a lobby: a message for the menu.
signal lobby_failed(reason: String)
## A friend invited us (or the game was launched from an invite): join this lobby.
signal invite_accepted(lobby_id: int)
## Friends' scores on a leaderboard arrived: [{"name", "score", "rank"}], best first.
signal leaderboard_loaded(board: String, entries: Array)

## Steam's test app ("Spacewar"), used until the game has its own app ID (set it in
## Project Settings under night_shift/steam/app_id, or in steam_appid.txt next to the game).
const TEST_APP_ID := 480
const APP_ID_SETTING := "night_shift/steam/app_id"
## Lobby data keys. "game" tells our lobbies apart from other games' on the test app ID.
const GAME_TAG := "night_shift"
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

## True when GodotSteam is installed and Steam started up.
var available := false
var user_name := ""
var steam_id := 0
## The lobby we're in, or 0.
var lobby_id := 0
## The code of the lobby we're in (or hosting), e.g. "K7QM2D".
var lobby_code := ""
## A lobby to join as soon as the menu is ready (from an invite or the launch command line).
var pending_lobby := 0

## Tests only: a stand-in for GodotSteam, and a function (is_host, lobby_id) -> MultiplayerPeer
## used instead of SteamMultiplayerPeer.
var test_peer_factory := Callable()

var _steam: Object
var _hosting := false
var _wanted_code := ""
var _max_members := 4
## Leaderboards: name -> Steam handle once found, and what's waiting for each board's handle.
var _boards: Dictionary = {}
var _waiting_uploads: Dictionary = {}
var _waiting_downloads: Array[String] = []
var _finding: Array[String] = []
## Friends'-scores requests go one at a time (some GodotSteam versions can't tell overlapping
## answers apart): the one in progress, and the ones waiting.
var _requesting := ""
var _queued_requests: Array[String] = []


## Tests only: uses `fake` as if it were GodotSteam's Steam singleton.
func use_fake_steam(fake: Object) -> void:
	_steam = fake
	available = true
	user_name = str(_call("getPersonaName"))
	steam_id = _int(_call("getSteamID"))
	_connect("lobby_created", _on_lobby_created)
	_connect("lobby_joined", _on_lobby_joined)
	_connect("lobby_match_list", _on_lobby_match_list)
	_connect("join_requested", _on_join_requested)
	_connect("leaderboard_find_result", _on_leaderboard_found)
	_connect("leaderboard_scores_downloaded", _on_leaderboard_downloaded)


func _ready() -> void:
	# Steam's callbacks keep running while the game is paused (solo Esc menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not Engine.has_singleton("Steam"):
		print("[steam] GodotSteam isn't installed; using direct connections.")
		return
	_steam = Engine.get_singleton("Steam")
	if not _initialize():
		_steam = null
		return
	available = true
	user_name = str(_call("getPersonaName"))
	steam_id = _int(_call("getSteamID"))
	print("[steam] Signed in as %s" % user_name)
	_connect("lobby_created", _on_lobby_created)
	_connect("lobby_joined", _on_lobby_joined)
	_connect("lobby_match_list", _on_lobby_match_list)
	_connect("join_requested", _on_join_requested)
	_connect("leaderboard_find_result", _on_leaderboard_found)
	_connect("leaderboard_scores_downloaded", _on_leaderboard_downloaded)
	# Launched from a friend's invite: "+connect_lobby <id>".
	var args := OS.get_cmdline_args()
	var at := args.find("+connect_lobby")
	if at >= 0 and at + 1 < args.size():
		pending_lobby = args[at + 1].to_int()


func _process(_delta: float) -> void:
	if available:
		_call("run_callbacks")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and available:
		leave_lobby()


# --- Lobbies ----------------------------------------------------------------------------

## Creates a friends-only (or public) lobby for up to `max_members` guards. Emits lobby_ready
## (or lobby_failed) when it's done.
func host_lobby(max_members: int, public := false) -> void:
	if not available:
		lobby_failed.emit("Steam isn't running.")
		return
	_hosting = true
	_max_members = max_members
	lobby_code = _new_code()
	# 1 = friends only, 2 = public (Steam's ELobbyType).
	_call("createLobby", [2 if public else 1, max_members])


## Finds the lobby with this code and joins it.
func join_by_code(code: String) -> void:
	if not available:
		lobby_failed.emit("Steam isn't running.")
		return
	_hosting = false
	_wanted_code = code.strip_edges().to_upper()
	_call("addRequestLobbyListStringFilter", ["code", _wanted_code, 0])
	_call("addRequestLobbyListStringFilter", ["game", GAME_TAG, 0])
	# Worldwide, so friends far away are found too.
	_call("addRequestLobbyListDistanceFilter", [3])
	_call("requestLobbyList")


func join_lobby(id: int) -> void:
	if not available:
		return
	_hosting = false
	_call("joinLobby", [id])


func leave_lobby() -> void:
	if available and lobby_id != 0:
		_call("leaveLobby", [lobby_id])
	lobby_id = 0
	lobby_code = ""


## Opens Steam's overlay to invite friends to our lobby.
func invite_friends() -> void:
	if available and lobby_id != 0:
		_call("activateGameOverlayInviteDialog", [lobby_id])


## Does this look like a Steam lobby code (6 letters and digits) rather than an address?
static func is_lobby_code(text: String) -> bool:
	var clean := text.strip_edges().to_upper()
	if clean.length() != 6:
		return false
	for letter in clean:
		if CODE_ALPHABET.find(letter) < 0:
			return false
	return true


func _on_lobby_created(result: int, id: int) -> void:
	if result != 1:
		_hosting = false
		lobby_failed.emit("Steam couldn't create a lobby (error %d)." % result)
		return
	lobby_id = id
	_call("setLobbyData", [id, "game", GAME_TAG])
	_call("setLobbyData", [id, "code", lobby_code])
	_call("setLobbyData", [id, "name", "%s's night shift" % user_name])
	_call("setLobbyJoinable", [id, true])
	var peer := _make_peer()
	if peer == null:
		lobby_failed.emit("GodotSteam's networking (SteamMultiplayerPeer) is missing. Update GodotSteam.")
		leave_lobby()
		return
	var error := ERR_UNAVAILABLE
	if test_peer_factory.is_valid():
		peer = test_peer_factory.call(true, id)
		error = OK
	elif peer.has_method("host_with_lobby"):
		error = _result(peer.call("host_with_lobby", id))
	elif peer.has_method("create_host"):
		error = _result(peer.call("create_host", 0))
	else:
		lobby_failed.emit("This version of GodotSteam's SteamMultiplayerPeer isn't supported. Install GodotSteam 4.13 or newer.")
		leave_lobby()
		return
	if error != OK:
		lobby_failed.emit("Couldn't start hosting over Steam (error %d)." % error)
		leave_lobby()
		return
	set_presence("Hosting a night shift")
	lobby_ready.emit(peer, true)


func _on_lobby_match_list(lobbies: Array) -> void:
	if lobbies.is_empty():
		lobby_failed.emit("No game with the code %s. Check the code, and that the host is still in the lobby." % _wanted_code)
		return
	join_lobby(int(lobbies[0]))


func _on_lobby_joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if _hosting:
		# Our own lobby: handled in _on_lobby_created.
		return
	if response != 1:
		lobby_failed.emit(_join_problem(response))
		return
	lobby_id = id
	lobby_code = str(_call("getLobbyData", [id, "code"]))
	var owner := _int(_call("getLobbyOwner", [id]))
	if owner == steam_id:
		lobby_failed.emit("That's your own lobby.")
		leave_lobby()
		return
	var peer := _make_peer()
	if peer == null:
		lobby_failed.emit("GodotSteam's networking (SteamMultiplayerPeer) is missing. Update GodotSteam.")
		leave_lobby()
		return
	var error := ERR_UNAVAILABLE
	if test_peer_factory.is_valid():
		peer = test_peer_factory.call(false, id)
		error = OK
	elif peer.has_method("connect_to_lobby"):
		error = _result(peer.call("connect_to_lobby", id))
	elif peer.has_method("create_client"):
		error = _result(peer.call("create_client", owner, 0))
	else:
		lobby_failed.emit("This version of GodotSteam's SteamMultiplayerPeer isn't supported. Install GodotSteam 4.13 or newer.")
		leave_lobby()
		return
	if error != OK:
		lobby_failed.emit("Couldn't connect to the host over Steam (error %d)." % error)
		leave_lobby()
		return
	set_presence("On a night shift")
	lobby_ready.emit(peer, false)


func _on_join_requested(id: int, _friend: int) -> void:
	pending_lobby = id
	invite_accepted.emit(id)


func _join_problem(response: int) -> String:
	match response:
		2:
			return "That lobby doesn't exist any more."
		4:
			return "That game is full."
		5:
			return "Steam had a problem joining the lobby."
		6:
			return "You're banned from that lobby."
		7:
			return "You can't join that lobby (limited Steam account)."
	return "Couldn't join the lobby (Steam response %d)." % response


func _make_peer() -> MultiplayerPeer:
	if test_peer_factory.is_valid():
		return OfflineMultiplayerPeer.new()
	if not ClassDB.class_exists("SteamMultiplayerPeer"):
		return null
	return ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer


func _new_code() -> String:
	var code := ""
	for i in 6:
		code += CODE_ALPHABET[randi() % CODE_ALPHABET.length()]
	return code


# --- Presence, achievements and stats -----------------------------------------------------

## What friends see in their Steam friends list, e.g. "Night 4 · 2:15 AM".
func set_presence(text: String) -> void:
	if available:
		_call("setRichPresence", ["steam_display", "#Status"])
		_call("setRichPresence", ["status", text])


func unlock_achievement(api_name: String) -> void:
	if not available:
		return
	_call("setAchievement", [api_name])
	_call("storeStats")


## Adds to one of the player's Steam stats (Steam keeps the total, across all their PCs).
func add_stat(api_name: String, amount: int) -> void:
	if not available:
		return
	var current: Variant = _call("getStatInt", [api_name]) if _steam.has_method("getStatInt") else _call("getStat", [api_name])
	var total := _int(current) + amount
	if _steam.has_method("setStatInt"):
		_call("setStatInt", [api_name, total])
	else:
		_call("setStat", [api_name, total])
	_call("storeStats")


# --- Leaderboards -----------------------------------------------------------------------------

## Posts a score (Steam keeps each player's best). Boards are made the first time they're used:
## "daily_20261014" for a day's daily shift, "furthest_night" for Overtime.
func submit_score(board: String, score: int) -> void:
	if not available:
		return
	if _boards.has(board):
		_call("uploadLeaderboardScore", [score, true, PackedInt32Array(), _boards[board]])
	else:
		_waiting_uploads[board] = maxi(score, int(_waiting_uploads.get(board, score)))
		_find_board(board)


## Asks for the player's friends' scores on a board. Answers with leaderboard_loaded.
func request_friends_scores(board: String) -> void:
	if not available:
		return
	if _requesting != "" and _requesting != board:
		if board not in _queued_requests:
			_queued_requests.append(board)
		return
	_requesting = board
	# Don't wait forever on an answer that never comes.
	get_tree().create_timer(10.0).timeout.connect(func() -> void:
		if _requesting == board:
			_next_request())
	if _boards.has(board):
		# 2: the player's friends (and the player).
		_call("downloadLeaderboardEntries", [1, 100, 2, _boards[board]])
	else:
		if board not in _waiting_downloads:
			_waiting_downloads.append(board)
		_find_board(board)


func _find_board(board: String) -> void:
	if board in _finding:
		return
	_finding.append(board)
	# 2: higher is better. 1: shown as a plain number.
	_call("findOrCreateLeaderboard", [board, 2, 1])


func _next_request() -> void:
	_requesting = ""
	if not _queued_requests.is_empty():
		request_friends_scores(_queued_requests.pop_front())


## GodotSteam: (handle, found). Which board it was is asked of Steam, as finds can overlap.
func _on_leaderboard_found(handle: Variant, found: Variant = 1) -> void:
	var board_handle := _int(handle)
	if board_handle == 0 or _int(found) == 0:
		if _requesting != "" and _requesting in _finding:
			_finding.erase(_requesting)
			_waiting_downloads.erase(_requesting)
			_next_request()
		return
	var board := str(_call("getLeaderboardName", [board_handle]))
	if board == "" or board == "<null>":
		if _finding.size() != 1:
			return
		board = _finding[0]
	_finding.erase(board)
	_boards[board] = board_handle
	if _waiting_uploads.has(board):
		_call("uploadLeaderboardScore", [int(_waiting_uploads[board]), true, PackedInt32Array(), board_handle])
		_waiting_uploads.erase(board)
	if board in _waiting_downloads:
		_waiting_downloads.erase(board)
		_call("downloadLeaderboardEntries", [1, 100, 2, board_handle])


## GodotSteam: (message, handle, entries). Older versions leave out the handle.
func _on_leaderboard_downloaded(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	var handle := 0
	var rows: Array = []
	for value: Variant in [a, b, c]:
		if value is Array:
			rows = value
		elif value is int:
			handle = value
	var board := ""
	for name: String in _boards:
		if _boards[name] == handle:
			board = name
	if board == "" and _boards.size() == 1:
		board = _boards.keys()[0]
	# Requests go one at a time, so an unnamed answer is for the one asked.
	if board == "":
		board = _requesting
	var entries: Array = []
	for row: Variant in rows:
		if not row is Dictionary:
			continue
		var id := _int((row as Dictionary).get("steam_id", 0))
		var who := user_name if id == steam_id else str(_call("getFriendPersonaName", [id]))
		entries.append({"name": who, "score": _int(row.get("score", 0)), "rank": _int(row.get("global_rank", 0)),
				"me": id == steam_id})
	entries.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["score"] > y["score"])
	leaderboard_loaded.emit(board, entries)
	if board == _requesting:
		_next_request()


## A day's daily shift board, e.g. "daily_20261014".
static func daily_board(date: String) -> String:
	return "daily_" + date.replace("-", "")


# --- Talking to GodotSteam ------------------------------------------------------------------

## Starts Steam up, coping with the different GodotSteam versions' steamInitEx arguments.
func _initialize() -> bool:
	var app_id := _app_id()
	var arguments := -1
	for method in _steam.get_method_list():
		if method["name"] == "steamInitEx":
			arguments = (method["args"] as Array).size()
	var result: Variant
	if arguments < 0:
		# Very old GodotSteam: only steamInit. Bool in some versions, a dictionary in others.
		result = _steam.call("steamInit") if _steam.has_method("steamInit") else null
	elif arguments >= 3:
		# Older GodotSteam: steamInitEx(retrieve_stats, app_id, embed_callbacks).
		result = _steam.call("steamInitEx", true, app_id, false)
	else:
		result = _steam.call("steamInitEx", app_id, false)
	var status := -1
	if result is Dictionary:
		status = int((result as Dictionary).get("status", -1))
		# Old steamInit reported success as 1; steamInitEx reports it as 0.
		if arguments < 0 and status == 1:
			status = 0
	elif result is bool:
		status = 0 if result else -1
	if status != 0:
		print("[steam] Steam didn't start (%s). Is the Steam client running? Using direct connections." % str(result))
		return false
	return true


func _app_id() -> int:
	if FileAccess.file_exists("res://steam_appid.txt"):
		var text := FileAccess.get_file_as_string("res://steam_appid.txt").strip_edges()
		if text.is_valid_int():
			return text.to_int()
	var exe_dir := OS.get_executable_path().get_base_dir()
	if FileAccess.file_exists(exe_dir.path_join("steam_appid.txt")):
		var text := FileAccess.get_file_as_string(exe_dir.path_join("steam_appid.txt")).strip_edges()
		if text.is_valid_int():
			return text.to_int()
	return int(ProjectSettings.get_setting(APP_ID_SETTING, TEST_APP_ID))


## A GodotSteam call's result as an Error, treating "returns nothing" as success.
static func _result(value: Variant) -> int:
	return int(value) if value is int else OK


## An int from a GodotSteam call, or 0 if it gave something else (or nothing).
static func _int(value: Variant) -> int:
	return int(value) if (value is int or value is float) else 0


func _call(method: String, arguments: Array = []) -> Variant:
	if _steam == null or not _steam.has_method(method):
		return null
	return _steam.callv(method, arguments)


func _connect(signal_name: String, handler: Callable) -> void:
	if _steam and _steam.has_signal(signal_name):
		_steam.connect(signal_name, handler)
