class_name GuardRoomDoors
extends Node
## The guard room's two doorways (from the lobby, and the back door to the main hall).
## Each can be fitted with a door bought at the vending machine. Guards open and shut them with E.
##
## From night 7 monsters can come into the guard room. A shut door stops them, but anything
## stuck at it bangs away until it gives: then it hangs open, broken, for a while.
## The host keeps the doors' state and tells everyone.

## Real seconds of banging a shut door can take.
const STRENGTH := 15.0
## Real seconds a broken door hangs open before it can be shut again.
const BROKEN_SECONDS := 60.0
## How close a monster has to be to bang on a door.
const BANG_DISTANCE := 1.7
## Each doorway: where it is, which way the door runs, and the hinge.
const DOORWAYS: Array[Dictionary] = [
	{"name": "lobby door", "centre": Vector3(6.0, 0, 15.0), "along_x": false},
	{"name": "back door", "centre": Vector3(16.0, 0, 10.0), "along_x": true},
]
const WIDTH := 1.6
const HEIGHT := 2.35

var shop: Shop
var director: MonsterDirector
var local_guard: Guard
## Host: has a monster battered one of the doors tonight? (For the Hold the door achievement.)
var battered_tonight := false

## Doorway index -> fitted / shut / broken. Shown on every computer.
var installed: Array[bool] = [false, false]
var closed: Array[bool] = [false, false]
var broken: Array[bool] = [false, false]

var _frames: Array[Interactable] = []
var _hinges: Array[Node3D] = []
var _panels: Array[CollisionShape3D] = []
# Host only.
var _health: Array[float] = [STRENGTH, STRENGTH]
var _broken_left: Array[float] = [0.0, 0.0]
var _bang_cooldown: Array[float] = [0.0, 0.0]


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.32, 0.36)
	material.roughness = 0.5
	for i in DOORWAYS.size():
		var info := DOORWAYS[i]
		var centre: Vector3 = info["centre"]
		var along_x: bool = info["along_x"]
		# Something to press E on in the doorway. It doesn't block anyone.
		var frame := Interactable.new()
		frame.collision_layer = Interactable.TALK_LAYER
		frame.collision_mask = 0
		frame.position = centre + Vector3(0, HEIGHT * 0.5, 0)
		var frame_shape := BoxShape3D.new()
		frame_shape.size = Vector3(WIDTH, HEIGHT, 0.5) if along_x else Vector3(0.5, HEIGHT, WIDTH)
		var frame_collider := CollisionShape3D.new()
		frame_collider.shape = frame_shape
		frame.add_child(frame_collider)
		frame.used.connect(_on_frame_used.bind(i))
		add_child(frame)
		_frames.append(frame)

		# The door itself swings on a hinge at one side of the doorway.
		var hinge := StaticBody3D.new()
		hinge.position = centre - (Vector3(WIDTH * 0.5, 0, 0) if along_x else Vector3(0, 0, WIDTH * 0.5))
		var size := Vector3(WIDTH, HEIGHT, 0.08) if along_x else Vector3(0.08, HEIGHT, WIDTH)
		var offset := Vector3(WIDTH * 0.5, HEIGHT * 0.5, 0) if along_x else Vector3(0, HEIGHT * 0.5, WIDTH * 0.5)
		var mesh := MeshInstance3D.new()
		mesh.mesh = Monster.box(size)
		mesh.material_override = material
		mesh.position = offset
		hinge.add_child(mesh)
		var window := MeshInstance3D.new()
		window.mesh = Monster.box(Vector3(0.4, 0.3, 0.1) if along_x else Vector3(0.1, 0.3, 0.4))
		window.material_override = StandardMaterial3D.new()
		(window.material_override as StandardMaterial3D).albedo_color = Color(0.05, 0.07, 0.08)
		window.position = offset + Vector3(0, 0.5, 0)
		hinge.add_child(window)
		var shape := BoxShape3D.new()
		shape.size = size
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = offset
		hinge.add_child(collider)
		add_child(hinge)
		_hinges.append(hinge)
		_panels.append(collider)
		_show(i)


func _process(_delta: float) -> void:
	if local_guard == null:
		return
	for i in DOORWAYS.size():
		var label: String = DOORWAYS[i]["name"]
		var prompt := ""
		if not installed[i]:
			prompt = "Fit the door kit in the %s" % label if shop.local_item == "door_kit" else "Empty doorway (a door kit from the vending machine fits here)"
		elif broken[i]:
			prompt = "The %s is hanging off its hinges" % label
		else:
			prompt = ("Open the %s" if closed[i] else "Shut the %s") % label
		_frames[i].prompt = prompt


func _on_frame_used(by: Node, doorway: int) -> void:
	if by != local_guard or local_guard.is_dead:
		return
	if multiplayer.is_server():
		_request_use(doorway)
	else:
		_request_use.rpc_id(1, doorway)


@rpc("any_peer", "call_remote", "reliable")
func _request_use(doorway: int) -> void:
	if not multiplayer.is_server() or doorway < 0 or doorway >= DOORWAYS.size():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	if not installed[doorway]:
		if shop.take(peer, "door_kit"):
			_set_state.rpc(doorway, true, false, false)
			director.tell(peer, "Door fitted. Press {use} to shut it.")
		return
	if broken[doorway]:
		director.tell(peer, "It won't shut. Give it a minute.")
		return
	_health[doorway] = STRENGTH
	_set_state.rpc(doorway, true, not closed[doorway], false)


## Host, every frame of the night: monsters at a shut door bang on it until it gives.
func update(delta: float) -> void:
	# Before night 7 nothing tries to get in, so nothing bangs on the doors.
	if director.night_number < MonsterDirector.GUARD_ROOM_OPENS_ON_NIGHT:
		return
	for i in DOORWAYS.size():
		if broken[i]:
			_broken_left[i] -= delta
			if _broken_left[i] <= 0.0:
				_set_state.rpc(i, true, false, false)
			continue
		if not installed[i] or not closed[i]:
			continue
		var centre: Vector3 = DOORWAYS[i]["centre"]
		var banging := false
		for monster in director.active_monsters():
			if Vector2(monster.global_position.x - centre.x, monster.global_position.z - centre.z).length() < BANG_DISTANCE:
				banging = true
				break
		if not banging:
			continue
		_health[i] -= delta
		battered_tonight = true
		_bang_cooldown[i] -= delta
		if _bang_cooldown[i] <= 0.0:
			_bang_cooldown[i] = 0.9
			_bang.rpc(i)
		if _health[i] <= 0.0:
			_health[i] = STRENGTH
			_broken_left[i] = BROKEN_SECONDS
			_set_state.rpc(i, true, false, true)
			director.announcement.emit("CRASH. The guard room's %s gives way." % DOORWAYS[i]["name"], "")


## Host: the run is starting over without gear, so the doors come off.
func reset_all() -> void:
	for i in DOORWAYS.size():
		if installed[i]:
			_set_state.rpc(i, false, false, false)


## Host: a new night. Fitted doors are mended and left open.
func reset_for_night() -> void:
	battered_tonight = false
	for i in DOORWAYS.size():
		_health[i] = STRENGTH
		if installed[i] and (closed[i] or broken[i]):
			_set_state.rpc(i, true, false, false)


## Host: fits doors from a saved run.
func install(doorway: int) -> void:
	_set_state.rpc(doorway, true, false, false)


## Host: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	for i in DOORWAYS.size():
		_set_state.rpc_id(peer_id, i, installed[i], closed[i], broken[i])


@rpc("authority", "call_local", "reliable")
func _set_state(doorway: int, is_installed: bool, is_closed: bool, is_broken: bool) -> void:
	var was_closed := closed[doorway]
	installed[doorway] = is_installed
	closed[doorway] = is_closed
	broken[doorway] = is_broken
	_show(doorway)
	if is_installed and was_closed != is_closed:
		var sound := Sfx.notes([140.0, 90.0], 0.08, 0.35, "square") if is_closed else Sfx.notes([300.0, 380.0], 0.06, 0.15, "saw")
		SoundBank.play_at(_hinges[doorway], "door_close" if is_closed else "door_open", 0.0, 25.0, sound)


@rpc("authority", "call_local", "reliable")
func _bang(doorway: int) -> void:
	SoundBank.play_at(_hinges[doorway], "door_bang", 6.0, 40.0, Sfx.notes([70.0, 55.0], 0.09, 0.6, "square"))


func _show(doorway: int) -> void:
	var hinge := _hinges[doorway]
	hinge.visible = installed[doorway]
	_panels[doorway].disabled = not (installed[doorway] and closed[doorway])
	var along_x: bool = DOORWAYS[doorway]["along_x"]
	# Open doors swing into the guard room; broken ones hang at an angle.
	var open_angle := -90.0 if along_x else 90.0
	if closed[doorway]:
		hinge.rotation_degrees.y = 0.0
	else:
		hinge.rotation_degrees.y = open_angle * (0.7 if broken[doorway] else 1.0)
	hinge.rotation_degrees.z = 6.0 if broken[doorway] else 0.0
