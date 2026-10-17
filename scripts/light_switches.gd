class_name LightSwitches
extends Node3D
## A light switch inside the door of every room. Guards flick a room's lights on to look round
## it properly (or off, to keep out of sight); on the cameras, a room that lights up or goes dark
## is somebody, or something, at the switch. Monsters turn the lights off in rooms they pass
## through now and then, so a classroom that was lit a minute ago and isn't any more is a sign.
##
## The halls and the lobby have no switches: their lights are on a timer. During a power cut the
## switches do nothing. Ghosts can flick them too, now and then: one more way to say "over here".
## The host decides; every computer shows it.

## Rooms with a switch, and where each one is (the corridors are left out).
const ROOMS := {
	"Front Office": AABB(Vector3(-20, -1, 10), Vector3(14, 6, 10)),
	"Guard Room": AABB(Vector3(6, -1, 10), Vector3(14, 6, 10)),
	"Cafeteria": AABB(Vector3(-40, -1, -30), Vector3(35, 6, 34)),
	"Kitchen": AABB(Vector3(-5, -1, -30), Vector3(10, 6, 18)),
	"Custodian's Closet": AABB(Vector3(-5, -1, -12), Vector3(10, 6, 16)),
	"Gym": AABB(Vector3(5, -1, -30), Vector3(35, 10, 34)),
	"Room 101": AABB(Vector3(-54, -1, 10), Vector3(14, 6, 10)),
	"Room 102": AABB(Vector3(-68, -1, 10), Vector3(14, 6, 10)),
	"Nurse's Office": AABB(Vector3(-80, -1, 10), Vector3(12, 6, 10)),
	"Room 103": AABB(Vector3(-58, -1, -14), Vector3(18, 6, 18)),
	"Library": AABB(Vector3(-80, -1, -14), Vector3(22, 6, 18)),
	"Science Lab": AABB(Vector3(40, -1, -14), Vector3(22, 6, 18)),
	"Art Room": AABB(Vector3(62, -1, -14), Vector3(18, 6, 18)),
	"Locker Rooms": AABB(Vector3(40, -1, 10), Vector3(40, 6, 10)),
}
## How bright a room's lights are when someone switches them on at night (their own night
## brightness, if they have one: some rooms are left on).
const SWITCHED_ON_ENERGY := 0.55
const SWITCH_HEIGHT := 1.25
## Host: how often a monster might reach for the switch of a lit room it's in, and the chance.
const MONSTER_CHECK_SECONDS := 4.0
const MONSTER_CHANCE := 0.12
## Host: how close a ghost has to be to flick a switch, and how often each one can.
const GHOST_REACH := 4.0
const GHOST_EVERY := 8.0

var lighting: ShiftLighting
var power: Power
var director: MonsterDirector
var school: SchoolBuilder
## The guards, by peer id (for ghosts flicking switches). Set by Main.
var players: Node3D

## One entry per room: {"name", "lights": Array[Light3D], "switch": Interactable, "lever": Node3D}.
var _rooms: Array[Dictionary] = []
## Host: rooms switched by hand (or by a monster) since the last morning (index -> on), for joiners.
var _changed: Dictionary = {}
var _monster_timer := 0.0
## Host: when each ghost (by peer id) may next flick a switch.
var _ghost_next: Dictionary = {}


## Every computer, once the school is built: a switch by one door of each room.
func build(builder: SchoolBuilder) -> void:
	school = builder
	var lights := get_tree().get_nodes_in_group(ShiftLighting.SCHOOL_LIGHTS)
	for room_name: String in ROOMS:
		var box: AABB = ROOMS[room_name]
		var room := {"name": room_name, "lights": [] as Array[Light3D]}
		for node in lights:
			var light := node as Light3D
			if light and box.has_point(light.global_position):
				(room["lights"] as Array[Light3D]).append(light)
		var spot := _switch_spot(box, builder.doorways)
		if room["lights"].is_empty() or spot.is_empty():
			continue
		_make_switch(room, spot["at"], spot["facing"], _rooms.size())
		_rooms.append(room)


## Where a room's switch goes: on the wall just inside its first doorway, beside the opening,
## {"at", "facing"} (the way the wall faces, into the room). Empty if the room has no door.
func _switch_spot(box: AABB, doorways: Array[Dictionary]) -> Dictionary:
	var middle := box.get_center()
	for doorway in doorways:
		var centre: Vector3 = doorway["centre"]
		var along_x: bool = doorway["along_x"]
		var width: float = doorway["width"]
		# The doorway is in one of the room's walls (on the box's edge, within its span).
		var on_edge := absf(centre.z - box.position.z) < 0.2 or absf(centre.z - box.end.z) < 0.2 if along_x \
				else absf(centre.x - box.position.x) < 0.2 or absf(centre.x - box.end.x) < 0.2
		var inside_span := centre.x > box.position.x and centre.x < box.end.x if along_x \
				else centre.z > box.position.z and centre.z < box.end.z
		if not on_edge or not inside_span or width > 4.5:
			continue
		var into := Vector3(0, 0, signf(middle.z - centre.z)) if along_x else Vector3(signf(middle.x - centre.x), 0, 0)
		var along := Vector3.RIGHT if along_x else Vector3.BACK
		# Beside the opening, on the side nearer the middle of the wall.
		var beside := along * signf((middle - centre).dot(along) + 0.001) * (width * 0.5 + 0.14)
		return {"at": centre + beside + into * (SchoolBuilder.WALL_T * 0.5 + 0.005) + Vector3(0, SWITCH_HEIGHT, 0),
				"facing": into}
	return {}


func _make_switch(room: Dictionary, at: Vector3, facing: Vector3, index: int) -> void:
	var body := Interactable.new()
	body.prompt = "Light switch"
	body.position = at
	body.rotation.y = atan2(facing.x, facing.z)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.16, 0.22, 0.08)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var plate := MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(0.075, 0.12, 0.008)
	plate.mesh = plate_box
	plate.material_override = _plate_material()
	plate.position = Vector3(0, 0, 0.004)
	body.add_child(plate)
	# The toggle: tipped up for on, down for off.
	var lever := MeshInstance3D.new()
	var lever_box := BoxMesh.new()
	lever_box.size = Vector3(0.016, 0.03, 0.018)
	lever.mesh = lever_box
	lever.material_override = _plate_material()
	lever.position = Vector3(0, 0, 0.014)
	body.add_child(lever)
	for mesh: MeshInstance3D in [plate, lever]:
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end = 18.0
	body.used.connect(_on_used.bind(index))
	add_child(body)
	room["switch"] = body
	room["lever"] = lever
	_show_switch(room, true)


var _plate: StandardMaterial3D


func _plate_material() -> StandardMaterial3D:
	if _plate == null:
		_plate = StandardMaterial3D.new()
		_plate.albedo_color = Color(0.86, 0.84, 0.78)
		_plate.roughness = 0.45
	return _plate


func _is_on(index: int) -> bool:
	for light: Light3D in _rooms[index]["lights"]:
		if light.visible:
			return true
	return false


func _show_switch(room: Dictionary, on: bool) -> void:
	var lever: Node3D = room["lever"]
	lever.rotation.x = -0.45 if on else 0.45
	lever.position.y = 0.012 if on else -0.012
	(room["switch"] as Interactable).prompt = "Turn the lights off" if on else "Turn the lights on"


# --- Using them -----------------------------------------------------------------------------

func _on_used(by: Node, index: int) -> void:
	var guard := by as Guard
	if guard == null or not guard.is_local() or guard.is_dead:
		return
	if multiplayer.is_server():
		_request_flip(index)
	else:
		_request_flip.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_flip(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _rooms.size():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	if power and not power.on:
		_click.rpc(index)
		if director:
			director.tell(peer, "Nothing happens. The power's out.")
		return
	flip(index, not _is_on(index))


## Is this point in a room (other than the guard room) with its lights on?
func lit_at(point: Vector3) -> bool:
	for i in _rooms.size():
		if _rooms[i]["name"] != "Guard Room" and (ROOMS[_rooms[i]["name"]] as AABB).has_point(point):
			return _is_on(i)
	return false


## The switch this physics body is, or -1.
func index_of(body: Object) -> int:
	for i in _rooms.size():
		if _rooms[i]["switch"] == body:
			return i
	return -1


## A ghost pressed E on a switch: it flicks, if they're close enough and haven't just done it.
@rpc("any_peer", "call_remote", "reliable")
func request_ghost_flip(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _rooms.size() or players == null:
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = 1
	var ghost := players.get_node_or_null(str(peer)) as Guard
	var now := Time.get_ticks_msec() / 1000.0
	if ghost == null or not ghost.is_dead or now < float(_ghost_next.get(peer, 0.0)) \
			or ghost.global_position.distance_to((_rooms[index]["switch"] as Node3D).global_position) > GHOST_REACH:
		return
	_ghost_next[peer] = now + GHOST_EVERY
	if power and not power.on:
		_click.rpc(index)
		return
	flip(index, not _is_on(index))


## Host: switches a room's lights on or off, for everyone.
func flip(index: int, on: bool) -> void:
	_changed[index] = on
	_set_room.rpc(index, on)


@rpc("authority", "call_local", "reliable")
func _set_room(index: int, on: bool) -> void:
	if index < 0 or index >= _rooms.size():
		return
	var room := _rooms[index]
	var dark := lighting != null and lighting.is_dark()
	for light: Light3D in room["lights"]:
		if light is FlickerLight:
			(light as FlickerLight).stop_flickering()
		light.visible = on
		if on:
			var night_energy: float = light.get_meta("night_energy")
			light.light_energy = (night_energy if night_energy > 0.0 else SWITCHED_ON_ENERGY) if dark \
					else float(light.get_meta("day_energy"))
			if dark and light is FlickerLight:
				(light as FlickerLight).start_flickering()
		if light.has_meta("panel"):
			var panel: MeshInstance3D = light.get_meta("panel")
			panel.material_override = school.get_material("light_panel" if on else "light_panel_off")
	_show_switch(room, on)
	SoundBank.play_at(room["switch"], "switch", -6.0, 14.0, Sfx.notes([900.0, 0.0, 600.0], 0.015, 0.25, "square"))


@rpc("authority", "call_local", "reliable")
func _click(index: int) -> void:
	SoundBank.play_at(_rooms[index]["switch"], "switch", -6.0, 14.0, Sfx.notes([900.0, 0.0, 600.0], 0.015, 0.25, "square"))


## Every computer: the switches follow the lights when something else changes them (lights
## out at clock-in, everything back on in the morning). Left as they were through a power cut.
var _refresh_timer := 0.0


func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer > 0.0 or (power != null and not power.on):
		return
	_refresh_timer = 0.5
	for i in _rooms.size():
		var on := _is_on(i)
		if (_rooms[i]["switch"] as Interactable).prompt != ("Turn the lights off" if on else "Turn the lights on"):
			_show_switch(_rooms[i], on)


## Host, every frame of the night: monsters put out the lights in rooms they pass through.
func update(delta: float) -> void:
	_monster_timer -= delta
	if _monster_timer > 0.0 or director == null or (power and not power.on):
		return
	_monster_timer = MONSTER_CHECK_SECONDS
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		# Not the real cleaner, and nothing in disguise: that would give it away.
		if monster == null or monster.is_queued_for_deletion() or monster.harmless or monster.disguised() \
				or monster.state == "hidden":
			continue
		for i in _rooms.size():
			# The Librarian can't stand the light: it puts it out almost at once.
			var chance := 0.6 if monster is Librarian else MONSTER_CHANCE
			if (ROOMS[_rooms[i]["name"]] as AABB).has_point(monster.global_position + Vector3(0, 0.5, 0)) and _is_on(i) \
					and randf() < chance:
				flip(i, false)


## Host, as a shift ends: the switches are back as the lights are.
func end_night() -> void:
	_changed.clear()


## Host: brings a player who just joined up to date (after their lights have gone down).
func send_state_to(peer_id: int) -> void:
	for index: int in _changed:
		_set_room.rpc_id(peer_id, index, _changed[index])
