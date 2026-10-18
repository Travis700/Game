class_name SchoolDoors
extends Node3D
## A door in every doorway of the school: the classic wooden school door with a narrow wired-
## glass window you can see through, a steel lever and a kick plate. Wide doorways get a pair.
## Guards open and shut them with E (they swing away from whoever's using them); monsters
## shove them open as they come through, so a door swinging open on its own means something's
## coming. A monster chasing someone bangs into a shut door first, and is held there a moment
## before it bursts through: a breather for whoever's running. The host keeps every door's
## state and tells everyone.
##
## Not here: the guard room's two doorways (GuardRoomDoors: a door kit from the vending machine)
## and the lobby's wide opening onto the main hall. The doors at the two wing entrances only
## appear once their wing is open (until then the chained red doors are there).
## Doors live outside the school node, so the navigation mesh is baked as if they were open.

## Doorways wider than this are left as open archways.
const ARCHWAY_WIDTH := 4.5
## Up to this wide gets one door; wider gets a pair.
const SINGLE_DOOR_WIDTH := 1.9
const OPEN_DEGREES := 95.0
const SWING_SECONDS := 0.55
## A monster this close to a shut door pushes it open.
const MONSTER_REACH := 1.4
## Real seconds a chasing monster is held at a shut door, banging on it, before it opens.
const CHASE_HOLD_SECONDS := 0.7
const THICKNESS := 0.05
## The window: narrow and tall, towards the handle, its top this far below the top of the door.
const WINDOW_SIZE := Vector2(0.2, 0.78)
const WINDOW_FROM_TOP := 0.32
## Where the guard room's doorways are (GuardRoomDoors' own).
const GUARD_ROOM_DOORWAYS: Array[Vector3] = [Vector3(6.0, 0, 15.0), Vector3(16.0, 0, 10.0)]

var director: MonsterDirector

## One entry per door: {"centre", "normal" (Vector3), "leaves" (Array of [hinge, base_yaw, sign]),
## "bodies" (Array[Interactable]), "wing" (difficulty it needs, 0 for none), "double"}.
var _doors: Array[Dictionary] = []
## Each door's swing: 0 shut, 1 open towards its normal, -1 open the other way. Same everywhere.
var _swing: PackedInt32Array = []
var _wing_difficulty := 1
## Set while the doors are first hung, so they don't all bang at once.
var _quiet := false
## Host: door index -> [the monster banging on it, real time it bursts open].
var _held: Dictionary = {}


## Hangs the doors in the school's doorways (every computer, as the school is built).
func build(doorways: Array[Dictionary]) -> void:
	for doorway in doorways:
		var centre: Vector3 = doorway["centre"]
		var width: float = doorway["width"]
		if width > ARCHWAY_WIDTH or _is_guard_room(centre):
			continue
		var along_x: bool = doorway["along_x"]
		var along := Vector3.RIGHT if along_x else Vector3.BACK
		var normal := Vector3.BACK if along_x else Vector3.RIGHT
		var height: float = doorway["height"]
		var door := {"centre": centre, "normal": normal, "leaves": [], "bodies": [],
				"double": width > SINGLE_DOOR_WIDTH, "wing": _wing_of(centre)}
		var leaf_width := width * (0.5 if door["double"] else 1.0) - 0.012
		var sides: Array[float] = [1.0]
		if door["double"]:
			sides.append(-1.0)
		for side in sides:
			# Hinged at the jamb, the leaf reaching across the doorway (side 1 from the low end).
			var hinge := Node3D.new()
			hinge.position = centre - along * side * (width * 0.5 - 0.006)
			var base_yaw := (0.0 if along_x else -PI * 0.5) + (0.0 if side > 0.0 else PI)
			hinge.rotation.y = base_yaw
			add_child(hinge)
			var body := _leaf(leaf_width, height - 0.015, door["double"])
			body.used.connect(_on_used.bind(_doors.size()))
			hinge.add_child(body)
			(door["leaves"] as Array).append([hinge, base_yaw])
			(door["bodies"] as Array).append(body)
		_doors.append(door)
		_swing.append(0)
	set_open_wings(_wing_difficulty)
	# As the crew arrives: the same as the start of a shift, quietly.
	_quiet = true
	for i in _doors.size():
		_set_swing(i, _default_swing(i))
	_quiet = false


## Every computer: which wings are open tonight (their entrance doors appear).
func set_open_wings(difficulty: int) -> void:
	_wing_difficulty = difficulty
	for i in _doors.size():
		var shown: bool = _doors[i]["wing"] == 0 or difficulty >= int(_doors[i]["wing"])
		for leaf: Array in _doors[i]["leaves"]:
			(leaf[0] as Node3D).visible = shown
		for body: Interactable in _doors[i]["bodies"]:
			body.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
			for child in body.get_children():
				if child is CollisionShape3D:
					(child as CollisionShape3D).disabled = not shown


# --- Using them ---------------------------------------------------------------------------

func _on_used(by: Node, door: int) -> void:
	var guard := by as Guard
	if guard == null or not guard.is_local() or guard.is_dead:
		return
	if multiplayer.is_server():
		_request_use(door, guard.global_position)
	else:
		_request_use.rpc_id(1, door, guard.global_position)


@rpc("any_peer", "call_remote", "reliable")
func _request_use(door: int, from: Vector3) -> void:
	if not multiplayer.is_server() or door < 0 or door >= _doors.size():
		return
	if _swing[door] != 0:
		_set_swing.rpc(door, 0)
	else:
		_set_swing.rpc(door, _away_from(door, from))


## Which way a door swings to open away from someone standing at `from`.
func _away_from(door: int, from: Vector3) -> int:
	var normal: Vector3 = _doors[door]["normal"]
	return -1 if (from - (_doors[door]["centre"] as Vector3)).dot(normal) > 0.0 else 1


## Host, every frame of the night: monsters barge through shut doors.
func update(_delta: float) -> void:
	if director == null:
		return
	# The last bell: the front doors are flung open for the run to the gate.
	if director.finale:
		for i in _doors.size():
			if _swing[i] == 0 and (_doors[i]["centre"] as Vector3).z > 19.0:
				_set_swing.rpc(i, 1)
	var now := Time.get_ticks_msec() / 1000.0
	# Doors a chasing monster has been banging on give way.
	for i: int in _held.keys():
		var held: Array = _held[i]
		var monster := held[0] as Monster
		if _swing[i] != 0:
			_held.erase(i)
		elif not is_instance_valid(monster) or now >= float(held[1]):
			_held.erase(i)
			_set_swing.rpc(i, _away_from(i, monster.global_position) if is_instance_valid(monster) else 1)
	for monster in _monsters():
		var at := monster.global_position
		for i in _doors.size():
			if _swing[i] != 0 or not _usable(i) or _held.has(i):
				continue
			var centre: Vector3 = _doors[i]["centre"]
			if Vector2(at.x - centre.x, at.z - centre.z).length() < MONSTER_REACH:
				if Dread.is_chasing(monster.state) and not monster.harmless:
					# Mid-chase it slams into the door: a bang, a moment, then it's through.
					_held[i] = [monster, now + CHASE_HOLD_SECONDS]
					monster.stuck_in_trap = maxf(monster.stuck_in_trap, CHASE_HOLD_SECONDS)
					_bang.rpc(i, true)
				else:
					_set_swing.rpc(i, _away_from(i, at))


func _monsters() -> Array[Monster]:
	var found: Array[Monster] = []
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		# The Ghost drifts through walls; it has no need of doors.
		if monster and not monster is SchoolGhost and not monster.is_queued_for_deletion():
			found.append(monster)
	return found


func _usable(door: int) -> bool:
	return _doors[door]["wing"] == 0 or _wing_difficulty >= int(_doors[door]["wing"])


## Host: the usable doors' centres (index matches haunt_door), for picking one near a spot.
func door_spots() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for i in _doors.size():
		spots.append(_doors[i]["centre"] if _usable(i) else Vector3.INF)
	return spots


## Host: nothing's there, but a door slams. An open one swings shut with a bang; a shut one
## shakes in its frame. (Never opens one: a door opening by itself means a monster.)
func haunt_door(door: int) -> void:
	if door < 0 or door >= _doors.size() or not _usable(door) or _held.has(door):
		return
	if _swing[door] != 0:
		_set_swing.rpc(door, 0)
		_bang.rpc(door, false, "slam")
	else:
		_bang.rpc(door, true, "slam")


## Every computer: a loud bang on a door, and (`shake`) the door jolting in its frame.
## `caption` is the sound caption's "Doors:..." entry (see Captions).
@rpc("authority", "call_local", "reliable")
func _bang(door: int, shake: bool, caption := "bang") -> void:
	if door < 0 or door >= _doors.size():
		return
	var first: Node3D = (_doors[door]["leaves"] as Array)[0][0]
	SoundBank.play_at(first, "door_bang", 2.0, 35.0, Sfx.notes([80.0, 60.0], 0.1, 0.6, "noise"))
	get_tree().call_group("captions", "heard", "Doors", caption, _doors[door]["centre"])
	if not shake or _swing[door] != 0:
		return
	for leaf: Array in _doors[door]["leaves"]:
		var hinge: Node3D = leaf[0]
		var rest := float(leaf[1])
		var jolt := hinge.create_tween()
		jolt.tween_property(hinge, "rotation:y", rest + deg_to_rad(randf_range(2.0, 4.0)), 0.05)
		jolt.tween_property(hinge, "rotation:y", rest - deg_to_rad(1.5), 0.07)
		jolt.tween_property(hinge, "rotation:y", rest, 0.1)


## Host, as a shift starts: classroom doors shut, the wide double doors propped open.
func reset_for_night() -> void:
	_held.clear()
	for i in _doors.size():
		_set_swing.rpc(i, _default_swing(i))


## Inside the school, double doors stand propped open, back into their room and out of the
## hallway; the rest (and the front doors) are shut.
func _default_swing(door: int) -> int:
	var centre: Vector3 = _doors[door]["centre"]
	if not _doors[door]["double"] or centre.z > 19.0:
		return 0
	var normal: Vector3 = _doors[door]["normal"]
	return -1 if "Hall" in SchoolBuilder.area_at(centre + normal * 1.0) else 1


## Host: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	for i in _doors.size():
		if _swing[i] != 0:
			_set_swing.rpc_id(peer_id, i, _swing[i])


@rpc("authority", "call_local", "reliable")
func _set_swing(door: int, swing: int) -> void:
	if door < 0 or door >= _doors.size() or _swing[door] == swing:
		return
	var was := _swing[door]
	_swing[door] = swing
	var normal: Vector3 = _doors[door]["normal"]
	for leaf: Array in _doors[door]["leaves"]:
		var hinge: Node3D = leaf[0]
		var base_yaw: float = leaf[1]
		# Turn the leaf so its free edge heads towards the chosen side.
		var target := base_yaw
		if swing != 0:
			var reach := Basis(Vector3.UP, base_yaw) * Vector3.RIGHT
			var turn_sign := signf(reach.cross(normal * swing).y)
			target = base_yaw + deg_to_rad(OPEN_DEGREES) * turn_sign
		if _quiet:
			hinge.rotation.y = target
			continue
		var tween := hinge.create_tween()
		tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		tween.tween_property(hinge, "rotation:y", target, SWING_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for body: Interactable in _doors[door]["bodies"]:
		body.prompt = "Shut the door" if swing != 0 else "Open the door"
	var first: Node3D = (_doors[door]["leaves"] as Array)[0][0]
	if _quiet:
		return
	if swing == 0:
		SoundBank.play_at(first, "door_close", -2.0, 22.0, Sfx.notes([140.0, 90.0], 0.08, 0.35, "square"))
	elif was == 0:
		SoundBank.play_at(first, "door_open", -4.0, 20.0, Sfx.notes([300.0, 380.0], 0.06, 0.15, "saw"))


# --- Building them ------------------------------------------------------------------------

func _is_guard_room(centre: Vector3) -> bool:
	for spot in GUARD_ROOM_DOORWAYS:
		if Vector2(spot.x - centre.x, spot.z - centre.z).length() < 0.5:
			return true
	return false


## The wing an entrance belongs to (0 if it isn't a wing entrance).
func _wing_of(centre: Vector3) -> int:
	for info: Dictionary in SchoolBuilder.WING_DOORS:
		if absf(centre.x - float(info["x"])) < 0.5 and absf(centre.z - 7.0) < 2.0:
			return int(info["difficulty"])
	return 0


## One door leaf, in its hinge's space: it runs from the hinge along +X, `width` wide.
func _leaf(width: float, height: float, in_pair: bool) -> Interactable:
	var body := Interactable.new()
	body.prompt = "Open the door"
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, THICKNESS)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position = Vector3(width * 0.5, height * 0.5, 0)
	body.add_child(collider)
	body.add_child(leaf_mesh(width, height, in_pair))
	return body


## The look of a door leaf (also the guard room's): the wood round a window (left, right,
## above, below), the glass, a rubber bead, kick plates, lever handles and hinges, as one mesh
## with a surface per material. It runs from x = 0 (the hinge) to `width`, from the floor up.
static func leaf_mesh(width: float, height: float, in_pair: bool) -> MeshInstance3D:
	if _wood == null:
		_make_materials()
	_pieces.clear()
	# The window sits towards the handle on a single door, in the middle of each of a pair.
	var window_x := width * (0.5 if in_pair else 0.62)
	var left := window_x - WINDOW_SIZE.x * 0.5
	var right := window_x + WINDOW_SIZE.x * 0.5
	var top := height - WINDOW_FROM_TOP
	var bottom := top - WINDOW_SIZE.y
	_part(Vector3(left * 0.5, height * 0.5, 0), Vector3(left, height, THICKNESS), _wood)
	_part(Vector3((right + width) * 0.5, height * 0.5, 0), Vector3(width - right, height, THICKNESS), _wood)
	_part(Vector3(window_x, (top + height) * 0.5, 0), Vector3(WINDOW_SIZE.x, height - top, THICKNESS), _wood)
	_part(Vector3(window_x, bottom * 0.5, 0), Vector3(WINDOW_SIZE.x, bottom, THICKNESS), _wood)
	_part(Vector3(window_x, (top + bottom) * 0.5, 0), Vector3(WINDOW_SIZE.x, WINDOW_SIZE.y, 0.008), _glass)
	for face: float in [-1.0, 1.0]:
		var z := face * (THICKNESS * 0.5 + 0.004)
		_part(Vector3(window_x, top + 0.012, z), Vector3(WINDOW_SIZE.x + 0.05, 0.024, 0.01), _black)
		_part(Vector3(window_x, bottom - 0.012, z), Vector3(WINDOW_SIZE.x + 0.05, 0.024, 0.01), _black)
		_part(Vector3(left - 0.012, (top + bottom) * 0.5, z), Vector3(0.024, WINDOW_SIZE.y, 0.01), _black)
		_part(Vector3(right + 0.012, (top + bottom) * 0.5, z), Vector3(0.024, WINDOW_SIZE.y, 0.01), _black)
		# Kick plate, and a lever handle by the free edge.
		_part(Vector3(width * 0.5, 0.13, face * (THICKNESS * 0.5 + 0.002)), Vector3(width - 0.06, 0.25, 0.004), _steel)
		var handle_x := width - 0.08
		_part(Vector3(handle_x, 1.0, face * (THICKNESS * 0.5 + 0.01)), Vector3(0.06, 0.06, 0.02), _steel)
		_part(Vector3(handle_x - 0.06, 1.0, face * (THICKNESS * 0.5 + 0.045)), Vector3(0.14, 0.022, 0.022), _steel)
		_part(Vector3(handle_x, 1.0, face * (THICKNESS * 0.5 + 0.03)), Vector3(0.022, 0.022, 0.04), _steel)
	for hinge_y: float in [0.25, height * 0.5, height - 0.25]:
		_part(Vector3(0.0, hinge_y, 0), Vector3(0.025, 0.11, THICKNESS + 0.012), _steel)
	var mesh := ArrayMesh.new()
	for material: Material in _pieces:
		var tool: SurfaceTool = _pieces[material]
		tool.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var leaf := MeshInstance3D.new()
	leaf.mesh = mesh
	leaf.visibility_range_end = 40.0
	return leaf


## The parts of the leaf being built, by material.
static var _pieces: Dictionary = {}
static var _wood: StandardMaterial3D
static var _steel: StandardMaterial3D
static var _glass: StandardMaterial3D
static var _black: StandardMaterial3D


static func _part(at: Vector3, size: Vector3, material: Material) -> void:
	if not _pieces.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		_pieces[material] = tool
	var box := BoxMesh.new()
	box.size = size
	(_pieces[material] as SurfaceTool).append_from(box, 0, Transform3D(Basis.IDENTITY, at))


static func _make_materials() -> void:
	_wood = StandardMaterial3D.new()
	_wood.albedo_texture = load("res://assets/textures/door_wood.jpg")
	_wood.normal_enabled = true
	_wood.normal_texture = load("res://assets/textures/door_wood_n.jpg")
	_wood.roughness_texture = load("res://assets/textures/door_wood_orm.jpg")
	_wood.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	# Mapped on the door itself (not the world), so the grain swings with it.
	_wood.uv1_triplanar = true
	_wood.uv1_scale = Vector3.ONE / 0.8
	_wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = Color(0.62, 0.63, 0.64)
	_steel.metallic = 0.85
	_steel.roughness = 0.35
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.7, 0.8, 0.82, 0.16)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.metallic = 0.4
	_glass.roughness = 0.05
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_black = StandardMaterial3D.new()
	_black.albedo_color = Color(0.03, 0.03, 0.03)
	_black.roughness = 0.6
