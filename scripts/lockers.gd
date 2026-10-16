class_name Lockers
extends Node3D
## Some of the hallway lockers have real doors, and they're home to the Locker Thing.
##
## When the Locker Thing is out tonight, locker doors start swinging open one at a time
## (watch for them on the hallway cameras). Walk past an open locker and something pulls you in.
## Press E on an open locker to shut it.

## Each door: [x, z of the locker face, which way the face points (+1 south / -1 north)].
const DOORS: Array[Array] = [
	[-31.35, 9.37, -1.0], [-18.85, 9.37, -1.0], [-8.35, 9.37, -1.0], [8.45, 9.37, -1.0],
	[23.35, 9.37, -1.0], [33.35, 9.37, -1.0],
	[-36.35, 4.63, 1.0], [-25.35, 4.63, 1.0], [-6.55, 4.63, 1.0], [9.25, 4.63, 1.0],
	[27.45, 4.63, 1.0], [35.45, 4.63, 1.0],
]
const GRAB_DISTANCE := 1.2
## In-game minutes between doors opening.
const OPEN_EVERY := Vector2(25.0, 45.0)
## Doors never open while a guard is this close.
const UNSEEN_DISTANCE := 10.0

var director: MonsterDirector
## True on nights the Locker Thing is out. Host only.
var active := false
## Guards who have logged the Locker Thing tonight. Host only.
var credited: Array[int] = []

var _hinges: Array[Node3D] = []
var _glows: Dictionary = {}
var _handles: Array[Interactable] = []
var _open: Array[bool] = []
var _next_open_at := 0.0
var _creak: AudioStream
var _slam: AudioStream


func build(locker_material: Material, dark_material: Material) -> void:
	_creak = SoundBank.get_sound("creak", Sfx.notes([140.0, 150.0, 160.0, 150.0], 0.12, 0.2, "saw"))
	_slam = SoundBank.get_sound("slam_metal", Sfx.notes([90.0, 60.0], 0.08, 0.6, "noise"))
	for i in DOORS.size():
		var door: Array = DOORS[i]
		var facing: float = door[2]
		var face := Vector3(door[0], 0, door[1])
		# A black gap behind the door, seen when it swings open.
		var gap := MeshInstance3D.new()
		gap.mesh = Monster.box(Vector3(0.44, 1.8, 0.01))
		gap.material_override = dark_material
		gap.position = face + Vector3(0, 0.95, facing * 0.006)
		add_child(gap)
		# The door hangs on a hinge at its left edge (seen from the hallway).
		var hinge := Node3D.new()
		hinge.position = face + Vector3(-0.23 * facing, 0.95, facing * 0.015)
		add_child(hinge)
		var panel := MeshInstance3D.new()
		panel.mesh = Monster.box(Vector3(0.46, 1.84, 0.02))
		panel.material_override = locker_material
		panel.position = Vector3(0.23 * facing, 0, 0)
		hinge.add_child(panel)
		# Painted like the rest of the row (see SchoolBuilder._locker_row).
		var front := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.46, 1.84)
		front.mesh = quad
		front.material_override = _door_paint()
		front.position = Vector3(0, 0, facing * 0.011)
		front.rotation.y = 0.0 if facing > 0.0 else PI
		panel.add_child(front)
		# Something to press E on while the door is open.
		var handle := Interactable.new()
		handle.prompt = "Close the locker"
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.46, 1.84, 0.06)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.disabled = true
		handle.add_child(collider)
		handle.position = panel.position
		handle.used.connect(func(_by: Node) -> void: request_close(i))
		hinge.add_child(handle)
		_hinges.append(hinge)
		_handles.append(handle)
		_open.append(false)


var _paint: StandardMaterial3D


func _door_paint() -> StandardMaterial3D:
	if _paint == null:
		_paint = StandardMaterial3D.new()
		_paint.albedo_texture = load("res://assets/textures/school/locker.png")
		_paint.normal_enabled = true
		_paint.normal_texture = load("res://assets/textures/school/locker_n.png")
		_paint.roughness = 0.5
		_paint.metallic = 0.35
	return _paint


## Host, every frame during the shift.
func update(minutes: float) -> void:
	if not active:
		return
	if minutes >= _next_open_at:
		_open_one()
		_next_open_at = minutes + randf_range(OPEN_EVERY.x, OPEN_EVERY.y)
	for i in _open.size():
		if not _open[i]:
			continue
		for guard in director.targetable_guards():
			if guard.global_position.distance_to(_front(i)) < GRAB_DISTANCE:
				director.kill(guard, "something in the lockers", _front(i) + Vector3(0, 1.2, 0))
				_set_open.rpc(i, false)
				break


## Host: starts the Locker Thing tonight. The first door opens a little later.
func activate(minutes: float) -> void:
	active = true
	_next_open_at = minutes + randf_range(5.0, 20.0)


## Host: is an open locker in this camera area?
func has_open_in(area: String) -> bool:
	for i in _open.size():
		if _open[i] and SchoolBuilder.area_at(_front(i)) == area:
			return true
	return false


## Host: shuts every locker and puts the Locker Thing away for the night.
func reset_all() -> void:
	active = false
	credited.clear()
	for i in _open.size():
		if _open[i]:
			_set_open.rpc(i, false)


func request_close(index: int) -> void:
	if multiplayer.is_server():
		_request_close(index)
	else:
		_request_close.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_close(index: int) -> void:
	if multiplayer.is_server() and index >= 0 and index < _open.size() and _open[index]:
		_set_open.rpc(index, false)


## Host: for a player who joins mid-evening.
func send_state_to(peer_id: int) -> void:
	for i in _open.size():
		if _open[i]:
			_set_open.rpc_id(peer_id, i, true)


@rpc("authority", "call_local", "reliable")
func _set_open(index: int, open: bool) -> void:
	_open[index] = open
	# Both rows swing out into the hallway with the same turn, because their hinges sit on opposite sides.
	var tween := create_tween()
	tween.tween_property(_hinges[index], "rotation_degrees:y", -100.0 if open else 0.0, 0.6 if open else 0.12)
	(_handles[index].get_child(0) as CollisionShape3D).disabled = not open
	Sfx.play_at(_hinges[index], _creak if open else _slam, 0.0, 25.0)
	if open:
		get_tree().call_group("captions", "heard", "Lockers", "open", _front(index))
	# A faint red glow from inside an open one, so you can see it coming even in the dark.
	if open and not _glows.has(index):
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.9, 0.15, 0.1)
		glow.light_energy = 0.6
		glow.omni_range = 1.8
		add_child(glow)
		glow.global_position = _front(index) + Vector3(0, 1.2, 0)
		_glows[index] = glow
	elif not open and _glows.has(index):
		(_glows[index] as Node).queue_free()
		_glows.erase(index)


func _open_one() -> void:
	var closed: Array[int] = []
	for i in _open.size():
		if not _open[i] and not director.guard_near(_front(i), UNSEEN_DISTANCE):
			closed.append(i)
	if not closed.is_empty():
		_set_open.rpc(closed.pick_random(), true)


## A spot in the hallway just in front of a locker.
func _front(index: int) -> Vector3:
	var door: Array = DOORS[index]
	return Vector3(door[0], 0, door[1] + door[2] * 0.5)
