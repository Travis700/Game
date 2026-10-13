class_name GuardRoom
extends Node
## The guard room's 16 monitors (4 desks x 4 screens): which camera each screen shows,
## who is sitting at which desk, and the full-screen camera view.
##
## The host keeps the official monitor and desk state and shares every change with all players,
## so everyone sees the same thing on the same screen. The full-screen view is just for you.

const CCTV_SHADER := preload("res://shaders/cctv.gdshader")
## Monitors sit on their own physics layer, so only a seated guard's view can pick them out.
const MONITOR_LAYER := 2
const DESKS := 4

var cameras: SecurityCameras
var hud: CanvasLayer
var local_guard: Guard

## Monitor index -> camera index.
var assignments: Array[int] = []
## Desk index -> network ID of the guard sitting there (0 = empty).
var occupants: Array[int] = [0, 0, 0, 0]

var _screens: Array[Interactable] = []
var _materials: Array[ShaderMaterial] = []
var _chairs: Array[Interactable] = []
var _chair_positions: Array[Vector3] = []
var _zoomed := -1
var _focused := -1


func build(school: SchoolBuilder, security: SecurityCameras, hud_layer: CanvasLayer) -> void:
	cameras = security
	hud = hud_layer
	# Start with the cameras spread across the screens in order.
	for spot: Dictionary in school.monitor_spots:
		var monitor := _screens.size()
		_add_screen(spot["position"], monitor)
		assignments.append(monitor % cameras.feeds.size())
	for desk in school.desk_chairs.size():
		var chair: Interactable = school.desk_chairs[desk]
		chair.used.connect(_on_chair_used.bind(desk))
		_chairs.append(chair)
		_chair_positions.append(school.desk_chair_positions[desk])
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


func _process(_delta: float) -> void:
	if local_guard == null:
		return
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
				var count := cameras.feeds.size()
				request_camera(monitor, (assignments[monitor] + step + count) % count)
		"zoom":
			if monitor >= 0:
				_toggle_zoom(monitor)
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
	return cameras.names[assignments[monitor]] if monitor >= 0 else ""


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


func _show_zoomed_feed() -> void:
	var camera := assignments[_zoomed]
	cameras.set_focus(camera)
	hud.show_feed(cameras.texture(camera), "MONITOR %d   ·   %s" % [_zoomed + 1, cameras.title(camera)])


func _update_controls_hint() -> void:
	if local_guard.seated_desk < 0:
		hud.set_controls("")
	elif _zoomed >= 0:
		hud.set_controls("A / D  change camera     1-4  other monitors     Space  back to the desk")
	elif _focused >= 0:
		hud.set_controls("A / D  change camera     Space  full screen     1-4  monitor full screen     S  stand up")
	else:
		hud.set_controls("Look at a monitor     1-4  monitor full screen     S  stand up")


func _on_chair_used(by: Node, desk: int) -> void:
	if by != local_guard or local_guard.seated_desk >= 0:
		return
	if occupants[desk] != 0:
		local_guard.show_message("Someone's already sitting there.")
		return
	request_sit(desk)


func _stand_up() -> void:
	var desk := local_guard.seated_desk
	local_guard.stand(_chair_positions[desk] + Vector3(0, 0, -0.9))
	request_stand()


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


## Host only: frees the desk of a guard who left the session.
func on_peer_left(peer_id: int) -> void:
	_free_desks_of(peer_id)


## Host only: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	_sync_state.rpc_id(peer_id, assignments, occupants)


@rpc("any_peer", "call_remote", "reliable")
func _request_camera(monitor: int, camera: int) -> void:
	if not multiplayer.is_server():
		return
	if monitor < 0 or monitor >= assignments.size() or camera < 0 or camera >= cameras.feeds.size():
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
	_chairs[desk].prompt = "Sit at desk %d" % (desk + 1) if peer_id == 0 else "Desk %d (taken)" % (desk + 1)
	if peer_id != 0 and peer_id == multiplayer.get_unique_id() and local_guard:
		local_guard.sit(desk, _chair_positions[desk])


@rpc("authority", "call_remote", "reliable")
func _sync_state(new_assignments: Array, new_occupants: Array) -> void:
	assignments.assign(new_assignments)
	for desk in DESKS:
		_set_occupant(desk, new_occupants[desk])
	_refresh_all()


# --- Screens -------------------------------------------------------------------------

func _refresh_all() -> void:
	for monitor in assignments.size():
		_refresh_screen(monitor)
	_update_shown()


func _refresh_screen(monitor: int) -> void:
	var camera := assignments[monitor]
	_materials[monitor].set_shader_parameter("feed", cameras.texture(camera))
	_screens[monitor].prompt = cameras.title(camera)


func _update_shown() -> void:
	var shown: Array[int] = []
	for camera in assignments:
		if camera not in shown:
			shown.append(camera)
	cameras.shown = shown


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
