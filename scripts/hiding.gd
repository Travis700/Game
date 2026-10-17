class_name Hiding
extends Node3D
## Hiding places: slatted cupboards around the school. Press E on one to climb in, E again to
## climb out. Inside, monsters can't find you: whatever was after you loses you. Unless it saw
## you go in. Then it pulls you out.
##
## The host decides who's hiding where and tells everyone; the guard's own computer moves them
## in and out and shows the view through the slats.

## Each cupboard: where it stands and which way its doors face.
const SPOTS := [
	{"at": Vector3(-38.9, 0, 9.2), "facing": Vector3(1, 0, 0), "area": "Main Hall West"},
	{"at": Vector3(38.9, 0, 9.2), "facing": Vector3(-1, 0, 0), "area": "Main Hall East"},
	{"at": Vector3(-39.2, 0, -20.0), "facing": Vector3(1, 0, 0), "area": "Cafeteria"},
	{"at": Vector3(-3.2, 0, -29.2), "facing": Vector3(0, 0, 1), "area": "Kitchen"},
	{"at": Vector3(6.0, 0, -29.2), "facing": Vector3(0, 0, 1), "area": "Gym"},
	{"at": Vector3(-6.7, 0, 19.2), "facing": Vector3(0, 0, -1), "area": "Front Office"},
	{"at": Vector3(-79.2, 0, 1.0), "facing": Vector3(1, 0, 0), "area": "Library"},
	{"at": Vector3(-41.0, 0, 19.2), "facing": Vector3(0, 0, -1), "area": "Room 101"},
	{"at": Vector3(-57.0, 0, -13.2), "facing": Vector3(0, 0, 1), "area": "Room 103"},
	{"at": Vector3(41.0, 0, -13.2), "facing": Vector3(0, 0, 1), "area": "Science Lab"},
	{"at": Vector3(79.2, 0, 15.0), "facing": Vector3(-1, 0, 0), "area": "Locker Rooms"},
	{"at": Vector3(79.2, 0, -10.0), "facing": Vector3(-1, 0, 0), "area": "Art Room"},
	{"at": Vector3(19.2, 0, 11.0), "facing": Vector3(-1, 0, 0), "area": "Guard Room"},
]
## A monster this close that can see you climb in knows where you are.
const SEEN_RANGE := 10.0
## Real seconds before it pulls you out.
const PULL_OUT_SECONDS := 1.4

var director: MonsterDirector
var shift: Shift
var players: Node3D
## The local guard. Set by Main.
var local_guard: Guard
var hud: CanvasLayer

## Peer id -> the cupboard they're in. On every computer.
var hidden: Dictionary = {}

var _doors: Array[Interactable] = []
var _slats: Control


func _ready() -> void:
	for i in SPOTS.size():
		_build_cupboard(i)
	_slats = _make_slats()


# --- Host --------------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _request(spot: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead:
		return
	if hidden.has(peer):
		_set_hidden.rpc(peer, -1)
		return
	# Cupboards are for the night shift: hiding before it or after 6 AM would leave you stuck.
	if shift and shift.state != Shift.State.ON_SHIFT:
		director.tell(peer, "Nothing to hide from right now.")
		return
	if spot < 0 or spot >= SPOTS.size() or guard.global_position.distance_to(SPOTS[spot]["at"]) > 3.0:
		return
	if spot in hidden.values():
		director.tell(peer, "Someone's already in there.")
		return
	var seen_by := _watcher(guard)
	_set_hidden.rpc(peer, spot)
	if seen_by:
		# Remembered now: the monster itself may be gone by the time it pulls them out.
		var by := seen_by.display_name
		var from := seen_by.face_point()
		get_tree().create_timer(PULL_OUT_SECONDS, false).timeout.connect(func() -> void:
			if hidden.get(peer, -1) == spot and is_instance_valid(guard) and not guard.is_dead:
				_set_hidden.rpc(peer, -1)
				director.kill(guard, by, from))


## A monster that saw this guard climb in, or null.
func _watcher(guard: Guard) -> Monster:
	for monster in director.active_monsters():
		# Not the blind, and not the ones minding their own business.
		if monster is LunchLady or monster is Nurse or monster is Substitute or monster is Twin or monster is Mascot:
			continue
		if monster.global_position.distance_to(guard.global_position) < SEEN_RANGE \
				and director.can_see(monster.eye_position(), guard):
			return monster
	return null


## Host: the night is over, or a guard left. Everyone climbs out.
func release_all() -> void:
	for peer: int in hidden.keys():
		_set_hidden.rpc(peer, -1)


func is_hiding(guard: Guard) -> bool:
	return hidden.has(guard.name.to_int())


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_hidden(peer: int, spot: int) -> void:
	var guard := players.get_node_or_null(str(peer)) as Guard
	if spot < 0:
		hidden.erase(peer)
	else:
		hidden[peer] = spot
	if guard == null:
		return
	guard.hiding = spot >= 0
	guard.body_mesh.visible = spot < 0 or guard.is_local()
	if guard.is_local():
		var info: Dictionary = SPOTS[spot] if spot >= 0 else {}
		if spot >= 0:
			guard.global_position = info["at"] + Vector3(0, 0.1, 0)
			guard.look_at(guard.global_position + info["facing"], Vector3.UP)
			guard.head.rotation.x = 0.0
		else:
			var last: Dictionary = SPOTS[guard.get_meta("hid_in", 0)]
			guard.global_position = last["at"] + last["facing"] * 1.0 + Vector3(0, 0.1, 0)
		if spot >= 0:
			guard.set_meta("hid_in", spot)
		_slats.visible = spot >= 0
		SoundBank.play_flat(self, "creak", -2.0, Sfx.creak(0.5, 0.25))
		SoundBank.play_flat(self, "cloth", -6.0)
	for i in _doors.size():
		_doors[i].prompt = "Climb out" if hidden.get(multiplayer.get_unique_id(), -1) == i else "Hide in the cupboard"


func _build_cupboard(index: int) -> void:
	var info: Dictionary = SPOTS[index]
	var holder := Node3D.new()
	# Monsters walk around it, not into it.
	holder.add_to_group(SchoolBuilder.NAV_SOURCE_GROUP)
	add_child(holder)
	holder.position = info["at"]
	holder.look_at(holder.position + info["facing"], Vector3.UP, true)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.32, 0.35, 0.33)
	metal.roughness = 0.7
	# Every panel and slat goes into one mesh (one draw call), not drawn from across the school.
	var shape_tool := SurfaceTool.new()
	shape_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Back and sides are solid; the guard stands inside, between them.
	for part: Array in [[Vector3(1.1, 2.1, 0.05), Vector3(0, 1.05, -0.5)], [Vector3(0.05, 2.1, 1.0), Vector3(-0.55, 1.05, 0)],
			[Vector3(0.05, 2.1, 1.0), Vector3(0.55, 1.05, 0)], [Vector3(1.1, 0.05, 1.0), Vector3(0, 2.1, 0)]]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = part[0]
		shape.shape = box
		body.add_child(shape)
		shape_tool.append_from(Monster.box(part[0]), 0, Transform3D(Basis(), part[1]))
		body.position = part[1]
		holder.add_child(body)
	# The doors: slats you can press E on, from outside or in.
	var door := Interactable.new()
	door.prompt = "Hide in the cupboard"
	var door_shape := CollisionShape3D.new()
	var door_box := BoxShape3D.new()
	door_box.size = Vector3(1.1, 2.0, 0.05)
	door_shape.shape = door_box
	door.add_child(door_shape)
	door.collision_layer = Interactable.TALK_LAYER
	door.position = Vector3(0, 1.05, 0.5)
	for slat in 9:
		shape_tool.append_from(Monster.box(Vector3(1.05, 0.1, 0.04)), 0,
				Transform3D(Basis(), door.position + Vector3(0, -0.9 + slat * 0.225, 0)))
	holder.add_child(door)
	var cupboard := MeshInstance3D.new()
	cupboard.mesh = shape_tool.commit()
	cupboard.material_override = metal
	cupboard.visibility_range_end = 40.0
	holder.add_child(cupboard)
	door.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				_request(index)
			else:
				_request.rpc_id(1, index))
	_doors.append(door)


## The note while hiding (the cupboard's own slats are the view).
func _make_slats() -> Control:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	layer.add_child(holder)
	var note := Label.new()
	note.text = KeyText.fill("Hiding. Press {use} to climb out.")
	note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	note.position.y -= 60
	note.modulate.a = 0.7
	holder.add_child(note)
	return holder
