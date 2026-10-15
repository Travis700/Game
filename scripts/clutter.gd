class_name Clutter
extends Node3D
## Things lying about the school you can pick up (E) and throw (E again). Where one lands it
## clatters, and the monsters that hunt by sound (the Lunch Lady, the Librarian, the Hall
## Monitor) go to look: a decoy. Ghosts can knock one over too (E while looking at it),
## poltergeist-style, every so often.
##
## The host keeps track of who's carrying what and where things are; every computer shows it.

const ITEMS := [
	{"name": "traffic cone", "at": Vector3(-3.0, 0, 7.0), "size": Vector3(0.3, 0.45, 0.3), "color": Color(1.0, 0.4, 0.05)},
	{"name": "cardboard box", "at": Vector3(-24.0, 0, 8.6), "size": Vector3(0.45, 0.35, 0.4), "color": Color(0.6, 0.45, 0.28)},
	{"name": "basketball", "at": Vector3(18.0, 0, -6.0), "size": Vector3(0.25, 0.25, 0.25), "color": Color(0.85, 0.42, 0.1)},
	{"name": "lunch tray", "at": Vector3(-28.0, 0.78, -8.0), "size": Vector3(0.45, 0.04, 0.32), "color": Color(0.55, 0.6, 0.62)},
	{"name": "stack of books", "at": Vector3(-14.5, 0.79, 17.5), "size": Vector3(0.3, 0.2, 0.22), "color": Color(0.5, 0.15, 0.12)},
	{"name": "mop bucket lid", "at": Vector3(2.5, 0, -8.0), "size": Vector3(0.35, 0.06, 0.35), "color": Color(0.8, 0.7, 0.1)},
	{"name": "trophy", "at": Vector3(-4.6, 0, 13.6), "size": Vector3(0.15, 0.35, 0.15), "color": Color(0.85, 0.7, 0.2)},
	{"name": "paint tin", "at": Vector3(30.0, 0, 8.8), "size": Vector3(0.22, 0.25, 0.22), "color": Color(0.3, 0.45, 0.7)},
	{"name": "library book", "at": Vector3(-70.0, 0.79, -1.0), "size": Vector3(0.22, 0.06, 0.3), "color": Color(0.2, 0.3, 0.5)},
	{"name": "beaker", "at": Vector3(54.0, 0.92, -5.0), "size": Vector3(0.12, 0.2, 0.12), "color": Color(0.7, 0.9, 0.8)},
	{"name": "dodgeball", "at": Vector3(66.0, 0, 13.0), "size": Vector3(0.25, 0.25, 0.25), "color": Color(0.8, 0.15, 0.15)},
]
## How far a throw goes, how long the noise carries, and how often each ghost can knock things.
const THROW_RANGE := 12.0
const NOISE_SECONDS := 6.0
const KNOCK_EVERY := 20.0

## Someone picked something up or let go of it (for the HUD).
signal carried_changed

var director: MonsterDirector
var shift: Shift

## Peer id -> the index of the item they're carrying. On every computer.
var carried: Dictionary = {}

var _props: Array[Interactable] = []
## Each prop's flight, so a reset can stop one mid-air.
var _flights: Dictionary = {}
var _knock_ready: Dictionary = {}


func _ready() -> void:
	for i in ITEMS.size():
		_build(i)


## The item a guard's carrying, as "traffic cone", or "".
func carried_name(peer_id: int) -> String:
	return ITEMS[carried[peer_id]]["name"] if carried.has(peer_id) else ""


## Which item this collider is, or -1.
func index_of(body: Object) -> int:
	return _props.find(body) if body is Interactable else -1


# --- Host --------------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_pick_up(index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead or index < 0 or index >= _props.size() or index in carried.values():
		return
	if shift and shift.state != Shift.State.ON_SHIFT:
		director.tell(peer, "Leave it. The school's tidy until the shift starts.")
		return
	if carried.has(peer):
		director.tell(peer, "Your hands are full. E to throw the %s first." % carried_name(peer))
		return
	if guard.global_position.distance_to(_props[index].global_position) > 3.5:
		return
	_set_carried.rpc(peer, index)


## Throws what this guard is carrying, from `from` along `direction` (their eyes).
@rpc("any_peer", "call_remote", "reliable")
func request_throw(from: Vector3, direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	if guard == null or not carried.has(peer) or from.distance_to(guard.global_position) > 3.0:
		return
	var index: int = carried[peer]
	var land := _landing(from, direction.normalized())
	_set_carried.rpc(peer, -1)
	_fly.rpc(index, from, land)
	get_tree().create_timer(0.6).timeout.connect(func() -> void: director.make_noise(land, NOISE_SECONDS))


## A ghost knocked an item: it hops and clatters.
@rpc("any_peer", "call_remote", "reliable")
func request_knock(index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	if guard == null or not guard.is_dead or index < 0 or index >= _props.size() or index in carried.values():
		return
	var now := Time.get_ticks_msec() / 1000.0
	# Keyed by badge, so leaving and rejoining doesn't reset it.
	if now < float(_knock_ready.get(guard.employee_number, 0.0)):
		director.tell(peer, "You haven't the strength yet. Try again in a moment.")
		return
	_knock_ready[guard.employee_number] = now + KNOCK_EVERY
	var at := _props[index].global_position
	var hop := at + Vector3(randf_range(-1.2, 1.2), 0, randf_range(-1.2, 1.2))
	_fly.rpc(index, at, Vector3(hop.x, _floor_under(hop), hop.z))
	get_tree().create_timer(0.6).timeout.connect(func() -> void: director.make_noise(hop, NOISE_SECONDS))


## Host: a guard who was carrying something was caught or left: it drops where they were.
func drop(peer: int, at: Vector3) -> void:
	if not carried.has(peer):
		return
	var index: int = carried[peer]
	_set_carried.rpc(peer, -1)
	_put.rpc(index, Vector3(at.x, _floor_under(at), at.z))


## Host: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	for peer: int in carried:
		_set_carried.rpc_id(peer_id, peer, carried[peer])
	for i in _props.size():
		if i not in carried.values():
			_put.rpc_id(peer_id, i, _props[i].global_position - Vector3(0, ITEMS[i]["size"].y * 0.5, 0))


## Host: the night's over; everyone drops what they're holding and things go back.
func reset_all() -> void:
	for peer: int in carried.keys():
		_set_carried.rpc(peer, -1)
	for i in _props.size():
		_put.rpc(i, ITEMS[i]["at"])


func _landing(from: Vector3, direction: Vector3) -> Vector3:
	var to := from + direction * THROW_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.exclude = _prop_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var spot: Vector3 = (hit["position"] - direction * 0.3) if not hit.is_empty() else to
	return Vector3(spot.x, _floor_under(spot), spot.z)


func _floor_under(at: Vector3) -> float:
	var query := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1.5, 0), at - Vector3(0, 5, 0), 1)
	query.exclude = _prop_rids()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else 0.0


func _prop_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for prop in _props:
		rids.append(prop.get_rid())
	return rids


func _sender() -> int:
	var peer := multiplayer.get_remote_sender_id()
	return peer if peer != 0 else multiplayer.get_unique_id()


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_carried(peer: int, index: int) -> void:
	if index < 0:
		carried.erase(peer)
	else:
		_stop_flight(index)
		carried[peer] = index
		_props[index].visible = false
		_props[index].collision_layer = 0
	carried_changed.emit()


@rpc("authority", "call_local", "reliable")
func _fly(index: int, from: Vector3, to: Vector3) -> void:
	var prop := _props[index]
	prop.visible = true
	prop.collision_layer = 0
	prop.global_position = from
	_stop_flight(index)
	var arc := create_tween()
	_flights[index] = arc
	var top := from.lerp(to, 0.5) + Vector3(0, 1.2, 0)
	arc.tween_method(func(t: float) -> void:
		prop.global_position = from.lerp(top, t).lerp(top.lerp(to, t), t), 0.0, 1.0, 0.6)
	arc.tween_callback(func() -> void:
		prop.collision_layer = Interactable.TALK_LAYER
		Sfx.play_at(prop, Sfx.thud(1.3, 0.12, 0.8), 4.0, 40.0)
		Sfx.play_at(prop, Sfx.thud(0.9, 0.08, 0.6), 0.0, 40.0)
		get_tree().call_group("captions", "heard", "Clutter", "landed", to))


func _stop_flight(index: int) -> void:
	var flight: Variant = _flights.get(index)
	if flight is Tween and (flight as Tween).is_valid():
		(flight as Tween).kill()
	_flights.erase(index)


@rpc("authority", "call_local", "reliable")
func _put(index: int, at: Vector3) -> void:
	_stop_flight(index)
	var prop := _props[index]
	prop.global_position = at + Vector3(0, ITEMS[index]["size"].y * 0.5, 0)
	prop.visible = true
	prop.collision_layer = Interactable.TALK_LAYER


func _build(index: int) -> void:
	var info: Dictionary = ITEMS[index]
	var prop := Interactable.new()
	prop.name = "Clutter%d" % index
	prop.prompt = "Pick up the %s" % info["name"]
	# On the talk layer: E finds it, but nobody bumps into it.
	prop.collision_layer = Interactable.TALK_LAYER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = (info["size"] as Vector3) + Vector3(0.1, 0.1, 0.1)
	shape.shape = box
	prop.add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(info["size"])
	var material := StandardMaterial3D.new()
	material.albedo_color = info["color"]
	mesh.material_override = material
	prop.add_child(mesh)
	add_child(prop)
	prop.global_position = info["at"] + Vector3(0, info["size"].y * 0.5, 0)
	prop.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				request_pick_up(index)
			else:
				request_pick_up.rpc_id(1, index))
	_props.append(prop)
