class_name GuardRoom
extends Node
## The guard room's 16 monitors (4 desks x 4 screens): which camera each screen shows,
## who is sitting at which desk, and the full-screen camera view.
##
## The host keeps the official monitor and desk state and shares every change with all players,
## so everyone sees the same thing on the same screen. The full-screen view is just for you.

## The local guard flagged a camera for the team (Q at a desk).
signal camera_pinged(camera_index: int)
## The local guard played a noise through a camera's speaker (F, full screen).
signal camera_lured(camera_index: int)

const CCTV_SHADER := preload("res://shaders/cctv.gdshader")
## Monitors sit on their own physics layer, so only a seated guard's view can pick them out.
const MONITOR_LAYER := 2
const DESKS := 4
## Seconds it takes to install the spectral camera kit at a desk.
const INSTALL_SECONDS := 10.0
## How far you can stray from the chair before an installation is abandoned.
const INSTALL_REACH := 2.0

var cameras: SecurityCameras
var hud: CanvasLayer
var local_guard: Guard
var shop: Shop

## Monitor index -> camera index.
var assignments: Array[int] = []
## Desk index -> network ID of the guard sitting there (0 = empty).
var occupants: Array[int] = [0, 0, 0, 0]
## Desk index -> has the spectral camera kit been installed there?
var upgraded: Array[bool] = [false, false, false, false]

var _screens: Array[Interactable] = []
var _materials: Array[ShaderMaterial] = []
var _chairs: Array[Interactable] = []
var _chair_positions: Array[Vector3] = []
var _zoomed := -1
## True while the full-screen view shows the early-night photo instead of the live feed.
var _comparing := false
var _focused := -1
var _installing := -1
var _install_left := 0.0
var _upgrade_signs: Array[Label3D] = []
## Host: the difficulty the monitors were last spread over the open cameras for.
var _fitted_difficulty := 1


func build(school: SchoolBuilder, security: SecurityCameras, hud_layer: CanvasLayer) -> void:
	cameras = security
	hud = hud_layer
	# Start with the cameras spread across the screens in order.
	for spot: Dictionary in school.monitor_spots:
		var monitor := _screens.size()
		_add_screen(spot["position"], monitor)
		var open := cameras.open_cameras()
		assignments.append(open[monitor % open.size()])
	for desk in school.desk_chairs.size():
		var chair: Interactable = school.desk_chairs[desk]
		chair.used.connect(_on_chair_used.bind(desk))
		_chairs.append(chair)
		_chair_positions.append(school.desk_chair_positions[desk])
		# A small sign on the desk once the spectral kit is in.
		var sign := Label3D.new()
		sign.text = "SPECTRAL"
		sign.font_size = 28
		sign.pixel_size = 0.004
		sign.modulate = Color(0.6, 0.85, 1.0)
		sign.outline_size = 6
		sign.position = school.desk_chair_positions[desk] + Vector3(0, 0.8, 0.52)
		sign.rotation.y = PI
		sign.visible = false
		add_child(sign)
		_upgrade_signs.append(sign)
	_refresh_all()


func _add_screen(pos: Vector3, monitor: int) -> void:
	var material := ShaderMaterial.new()
	material.shader = CCTV_SHADER
	material.set_shader_parameter("seed", float(monitor) * 7.31)
	_materials.append(material)

	var quad := QuadMesh.new()
	quad.size = SchoolBuilder.MONITOR_SIZE
	var mesh := MeshInstance3D.new()
	mesh.mesh = quad
	mesh.material_override = material

	var screen := Interactable.new()
	screen.name = "Monitor%d" % (monitor + 1)
	screen.collision_layer = MONITOR_LAYER
	screen.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(SchoolBuilder.MONITOR_SIZE.x, SchoolBuilder.MONITOR_SIZE.y, 0.02)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	screen.add_child(collider)
	screen.add_child(mesh)
	screen.position = pos
	# Quads face +Z; the screens face the chairs at -Z.
	screen.rotation.y = PI
	screen.used.connect(func(_by: Node) -> void: _toggle_zoom(monitor))
	add_child(screen)
	_screens.append(screen)


func _process(delta: float) -> void:
	if local_guard == null:
		return
	_update_chair_prompts()
	_update_install(delta)
	var focused := -1
	if local_guard.seated_desk >= 0 and _zoomed < 0:
		var target := local_guard.focused_interactable()
		focused = _screens.find(target)
	if focused != _focused:
		if _focused >= 0:
			_materials[_focused].set_shader_parameter("highlight", 0.0)
		if focused >= 0:
			_materials[focused].set_shader_parameter("highlight", 1.0)
		_focused = focused
	_update_controls_hint()


# --- Seated controls (local only) ---------------------------------------------------

## Keys pressed by the local guard while seated: "prev", "next", "zoom", "stand", "back",
## or "monitor_1" to "monitor_4" to show one of your desk's monitors full screen.
func on_desk_action(action: String) -> void:
	var monitor := _zoomed if _zoomed >= 0 else _focused
	if action.begins_with("monitor_"):
		var chosen := local_guard.seated_desk * 4 + action.to_int() - 1
		if _zoomed >= 0 and _zoomed != chosen:
			_toggle_zoom(_zoomed)
		_toggle_zoom(chosen)
		return
	match action:
		"prev", "next":
			if monitor >= 0:
				var step := -1 if action == "prev" else 1
				var open := cameras.open_cameras()
				var at := open.find(assignments[monitor])
				request_camera(monitor, open[(maxi(at, 0) + step + open.size()) % open.size()])
		"zoom":
			if monitor >= 0:
				_toggle_zoom(monitor)
		"ping":
			if monitor >= 0:
				camera_pinged.emit(assignments[monitor])
		"lure":
			if _zoomed >= 0:
				camera_lured.emit(assignments[_zoomed])
		"compare":
			if _zoomed < 0 and monitor >= 0:
				_toggle_zoom(monitor)
			_toggle_compare()
		"back":
			if _zoomed >= 0:
				_toggle_zoom(_zoomed)
		"stand":
			if _zoomed >= 0:
				_toggle_zoom(_zoomed)
			else:
				_stand_up()


## The camera you're looking at (full screen, or the monitor in front of you), or "" if none.
func current_area() -> String:
	var monitor := _zoomed if _zoomed >= 0 else _focused
	return cameras.area_of(assignments[monitor]) if monitor >= 0 else ""


## Leaves the full-screen view and stands up, e.g. when the next night begins.
func leave_desk() -> void:
	if local_guard == null or local_guard.seated_desk < 0:
		return
	if _zoomed >= 0:
		_toggle_zoom(_zoomed)
	_stand_up()


func _toggle_zoom(monitor: int) -> void:
	if _zoomed == monitor:
		_zoomed = -1
		cameras.set_focus(-1)
		hud.hide_feed()
		local_guard.look_locked = false
		return
	_zoomed = monitor
	_show_zoomed_feed()
	local_guard.look_locked = true


## Full screen, flips between the live picture and the photo taken early in the night.
func _toggle_compare() -> void:
	if _zoomed < 0:
		return
	var camera := assignments[_zoomed]
	var photo := cameras.reference(camera)
	if _comparing or photo == null:
		_comparing = false
		_show_zoomed_feed()
		if photo == null:
			local_guard.show_message("No photo from this camera yet tonight. They're taken a few minutes after midnight.")
		return
	_comparing = true
	hud.show_feed(photo, "PHOTO FROM %s   ·   %s   ·   %s to go back to live" % [
		cameras.reference_time, cameras.title(camera), _key("compare")])


func _show_zoomed_feed() -> void:
	_comparing = false
	var camera := assignments[_zoomed]
	var spectral := _is_spectral(_zoomed)
	cameras.set_focus(SecurityCameras.key(camera, spectral))
	hud.show_feed(cameras.texture(camera, spectral), "MONITOR %d   ·   %s%s" % [
		_zoomed + 1, cameras.title(camera), "   ·   SPECTRAL" if spectral else ""])


func _update_controls_hint() -> void:
	if _installing >= 0:
		hud.set_controls("Installing the spectral camera kit at desk %d...  %d%%   (stay by the desk)" % [
			_installing + 1, int(100.0 * (1.0 - _install_left / INSTALL_SECONDS))])
	elif local_guard.seated_desk < 0:
		hud.set_controls("")
	elif _zoomed >= 0:
		hud.set_controls("%s / %s  change camera     %s  compare     %s  flag it     %s  noise through its speaker     %s  back     %s  log it" % [
			_key("move_left"), _key("move_right"), _key("compare"), _key("ping"), _key("flashlight"), _key("zoom"), _key("clipboard")])
	elif _focused >= 0:
		hud.set_controls("%s / %s  change camera     %s  full screen     %s  compare with photo     %s  log     %s  stand up" % [
			_key("move_left"), _key("move_right"), _key("zoom"), _key("compare"), _key("clipboard"), _key("move_back")])
	else:
		hud.set_controls("Look at a monitor     1-4  monitor full screen     %s  log     %s  base station radio (everyone hears)     %s  stand up" % [
			_key("clipboard"), _key("radio_talk"), _key("move_back")])


## The player's key for an action (Controls is an autoload, looked up by path so this
## class-named script compiles anywhere).
func _key(action: String) -> String:
	var controls := get_node_or_null("/root/Controls")
	return controls.key_name(action) if controls else action


func _on_chair_used(by: Node, desk: int) -> void:
	if by != local_guard or local_guard.seated_desk >= 0 or _installing >= 0:
		return
	if occupants[desk] != 0:
		local_guard.show_message("Someone's already sitting there.")
		return
	request_sit(desk)


## G while carrying the spectral camera kit: starts installing it at the nearest desk.
## Returns false if you're not carrying the kit (so G does its usual thing).
func try_install() -> bool:
	if shop == null or shop.local_item != "camera_kit" or local_guard == null:
		return false
	if _installing >= 0 or local_guard.seated_desk >= 0:
		return true
	for desk in _chairs.size():
		if local_guard.global_position.distance_to(_chair_positions[desk]) < INSTALL_REACH:
			if upgraded[desk]:
				local_guard.show_message("Desk %d already has the spectral kit." % (desk + 1))
			elif occupants[desk] != 0:
				local_guard.show_message("Someone's sitting at desk %d." % (desk + 1))
			else:
				_installing = desk
				_install_left = INSTALL_SECONDS
			return true
	local_guard.show_message("Stand by one of the guard room desk chairs to install it.")
	return true


func _stand_up() -> void:
	var desk := local_guard.seated_desk
	local_guard.stand(_chair_positions[desk] + Vector3(0, 0, -0.9))
	request_stand()


func _can_install_at(desk: int) -> bool:
	return shop != null and shop.local_item == "camera_kit" and not upgraded[desk] and occupants[desk] == 0


func _update_chair_prompts() -> void:
	for desk in _chairs.size():
		var prompt := "Sit at desk %d" % (desk + 1)
		if occupants[desk] != 0:
			prompt = "Desk %d (taken)" % (desk + 1)
		elif _can_install_at(desk):
			prompt = "Sit at desk %d     (G: install the spectral camera kit here)" % (desk + 1)
		_chairs[desk].prompt = prompt


func _update_install(delta: float) -> void:
	if _installing < 0:
		return
	var too_far := local_guard.global_position.distance_to(_chair_positions[_installing]) > INSTALL_REACH
	if local_guard.is_dead or too_far:
		local_guard.show_message("Installation abandoned.")
		_installing = -1
		return
	_install_left -= delta
	if _install_left <= 0.0:
		var desk := _installing
		_installing = -1
		if multiplayer.is_server():
			_request_upgrade(desk)
		else:
			_request_upgrade.rpc_id(1, desk)


## Host: the run is starting over, so the upgrades come out again.
func reset_upgrades() -> void:
	for desk in DESKS:
		if upgraded[desk]:
			_set_upgraded.rpc(desk, false)


@rpc("any_peer", "call_remote", "reliable")
func _request_upgrade(desk: int) -> void:
	if not multiplayer.is_server() or desk < 0 or desk >= DESKS or upgraded[desk]:
		return
	if shop.take(_sender(), "camera_kit"):
		_set_upgraded.rpc(desk, true)


@rpc("authority", "call_local", "reliable")
func _set_upgraded(desk: int, on: bool) -> void:
	upgraded[desk] = on
	_upgrade_signs[desk].visible = on
	for monitor in range(desk * 4, desk * 4 + 4):
		_refresh_screen(monitor)
		if _zoomed == monitor:
			_show_zoomed_feed()
	_update_shown()
	if on and local_guard and local_guard.global_position.distance_to(_chair_positions[desk]) < 3.0:
		local_guard.show_message("Desk %d's monitors now show the spectral feed." % (desk + 1))


# --- Shared state ------------------------------------------------------------------

func request_camera(monitor: int, camera: int) -> void:
	if multiplayer.is_server():
		_request_camera(monitor, camera)
	else:
		_request_camera.rpc_id(1, monitor, camera)


func request_sit(desk: int) -> void:
	if multiplayer.is_server():
		_request_sit(desk)
	else:
		_request_sit.rpc_id(1, desk)


func request_stand() -> void:
	if multiplayer.is_server():
		_request_stand()
	else:
		_request_stand.rpc_id(1)


## Host, when the night starts: monitors showing a camera in a closed wing switch to an open
## one, and when a wing opens, the monitors spread out over every open camera.
func fit_to_open_cameras() -> void:
	var open := cameras.open_cameras()
	if cameras.difficulty == _fitted_difficulty:
		# Same wings as last night: keep the cameras guards picked.
		return
	_fitted_difficulty = cameras.difficulty
	for monitor in assignments.size():
		var camera := open[monitor % open.size()]
		if assignments[monitor] != camera:
			_set_camera.rpc(monitor, camera)


## Host: monitors showing a camera that's gone (a portable camera packed away) switch to
## an open one.
func drop_closed_cameras() -> void:
	var open := cameras.open_cameras()
	for monitor in assignments.size():
		if not cameras.is_open(assignments[monitor]):
			_set_camera.rpc(monitor, open[monitor % open.size()])


## Host only: frees the desk of a guard who left the session.
func on_peer_left(peer_id: int) -> void:
	_free_desks_of(peer_id)


## Host only: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	_sync_state.rpc_id(peer_id, assignments, occupants, upgraded)


@rpc("any_peer", "call_remote", "reliable")
func _request_camera(monitor: int, camera: int) -> void:
	if not multiplayer.is_server():
		return
	if monitor < 0 or monitor >= assignments.size() or camera < 0 or camera >= cameras.count() or not cameras.is_open(camera):
		return
	_set_camera.rpc(monitor, camera)


@rpc("any_peer", "call_remote", "reliable")
func _request_sit(desk: int) -> void:
	if not multiplayer.is_server() or desk < 0 or desk >= DESKS:
		return
	var peer := _sender()
	if occupants[desk] != 0 or peer in occupants:
		return
	_set_occupant.rpc(desk, peer)


@rpc("any_peer", "call_remote", "reliable")
func _request_stand() -> void:
	if multiplayer.is_server():
		_free_desks_of(_sender())


func _free_desks_of(peer_id: int) -> void:
	for desk in DESKS:
		if occupants[desk] == peer_id:
			_set_occupant.rpc(desk, 0)


@rpc("authority", "call_local", "reliable")
func _set_camera(monitor: int, camera: int) -> void:
	assignments[monitor] = camera
	_refresh_screen(monitor)
	_update_shown()
	if _zoomed == monitor:
		_show_zoomed_feed()


@rpc("authority", "call_local", "reliable")
func _set_occupant(desk: int, peer_id: int) -> void:
	occupants[desk] = peer_id
	if peer_id != 0 and peer_id == multiplayer.get_unique_id() and local_guard:
		local_guard.sit(desk, _chair_positions[desk])


@rpc("authority", "call_remote", "reliable")
func _sync_state(new_assignments: Array, new_occupants: Array, new_upgraded: Array) -> void:
	assignments.assign(new_assignments)
	for desk in DESKS:
		_set_occupant(desk, new_occupants[desk])
		upgraded[desk] = new_upgraded[desk]
		_upgrade_signs[desk].visible = upgraded[desk]
	_refresh_all()


# --- Screens -------------------------------------------------------------------------

func _refresh_all() -> void:
	for monitor in assignments.size():
		_refresh_screen(monitor)
	_update_shown()


func _is_spectral(monitor: int) -> bool:
	return upgraded[monitor / 4]


func _refresh_screen(monitor: int) -> void:
	var camera := assignments[monitor]
	_materials[monitor].set_shader_parameter("feed", cameras.texture(camera, _is_spectral(monitor)))
	_screens[monitor].prompt = cameras.title(camera)


## The feeds on the monitors of desks someone is sitting at (what's actually being watched).
func watched_feeds() -> Array[int]:
	var feeds: Array[int] = []
	for monitor in assignments.size():
		if occupants[monitor / 4] == 0:
			continue
		var feed_key := SecurityCameras.key(assignments[monitor], _is_spectral(monitor))
		if feed_key not in feeds:
			feeds.append(feed_key)
	return feeds


func _update_shown() -> void:
	var shown: Array[int] = []
	for monitor in assignments.size():
		var feed_key := SecurityCameras.key(assignments[monitor], _is_spectral(monitor))
		if feed_key not in shown:
			shown.append(feed_key)
	cameras.shown = shown


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
