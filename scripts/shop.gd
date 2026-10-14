class_name Shop
extends Node
## The vending machine in the guard room. Guards spend the points they've earned; the item
## drops into the tray, and they pick it up and carry it (one thing at a time). Some things are
## fitted where they go with E (camera kit, door kit); the rest are used or put down with G.
##
## The host holds everyone's points (Night keeps the totals), what each guard is carrying, and
## the sensors and traps guards have put down tonight.

signal wallet_changed(points: int)
signal holding_changed(item: String)

const ITEMS := {
	"camera_kit": {
		"name": "Spectral camera kit", "price": 150,
		"about": "Install it at a guard room desk: stand at the desk's chair and press E. That desk's monitors then show what ordinary cameras can't.",
	},
	"lucky_charm": {
		"name": "Lucky rabbit's foot", "price": 60,
		"about": "Carry it to a revive totem. Your roll brings a teammate back on 5 in 6 instead of 4 in 6.",
	},
	"door_kit": {
		"name": "Guard room door kit", "price": 120,
		"about": "A heavy door for one of the guard room's two doorways: press E in the doorway to fit it, then E to open and shut it. Monsters can get in from night 7. A shut door holds them for a while before it gives.",
	},
	"motion_sensor": {
		"name": "Motion sensor", "price": 40,
		"about": "Press G to put it down. When something walks past tonight, everyone hears where.",
	},
	"glue_trap": {
		"name": "Industrial glue trap", "price": 60,
		"about": "Press G to put it down. The first monster to step on it is stuck there for 20 seconds.",
	},
	"energy_drink": {
		"name": "Energy drink", "price": 25,
		"about": "Press G to drink it: you run faster for 30 seconds.",
	},
	"flashlight": {
		"name": "Heavy-duty flashlight", "price": 80,
		"about": "Press G to swap it for your flashlight. A longer, wider beam, for good. (The Librarian will notice it from further away too.)",
	},
}
## Items used or put down with G (the rest are fitted with E).
const USED_WITH_G: Array[String] = ["motion_sensor", "glue_trap", "energy_drink", "flashlight"]
## How far a motion sensor notices things, and how long it stays quiet after going off.
const SENSOR_RANGE := 5.0
const SENSOR_COOLDOWN := 30.0
const TRAP_RANGE := 0.9
const TRAP_SECONDS := 20.0
const BOOST_SECONDS := 30.0
## Where purchases land: the tray at the bottom of the vending machine.
const TRAY := Vector3(18.75, 0.15, 16.6)

var night: Night
var director: MonsterDirector
## What this player is carrying ("" for nothing). Updated by the host.
var local_item := ""
var local_points := 0

# Host only: peer -> item id.
var _held: Dictionary = {}
var _drops: Dictionary = {}
var _next_drop := 1
## Sensors and traps put down tonight: id -> {"item", "node", "position", "quiet"}. Every computer
## has the nodes; the host checks them.
var _placed: Dictionary = {}
## Host: peers who've fitted the heavy-duty flashlight.
var _bright: Array[int] = []
var _box_material: StandardMaterial3D


func _ready() -> void:
	_box_material = StandardMaterial3D.new()
	_box_material.albedo_color = Color(0.85, 0.75, 0.4)
	_box_material.emission_enabled = true
	_box_material.emission = Color(0.4, 0.35, 0.15)
	_box_material.emission_energy_multiplier = 0.4


static func item_name(item: String) -> String:
	return ITEMS[item]["name"] if ITEMS.has(item) else ""


func request_buy(item: String) -> void:
	if multiplayer.is_server():
		_request_buy(item)
	else:
		_request_buy.rpc_id(1, item)


## Host: takes an item from a guard (e.g. installing the camera kit). True if they had it.
func take(peer_id: int, item: String) -> bool:
	if _held.get(peer_id, "") != item:
		return false
	_held.erase(peer_id)
	_send_holding(peer_id)
	return true


## Uses or puts down whatever the local guard is carrying (G).
func request_use() -> void:
	if multiplayer.is_server():
		_request_use()
	else:
		_request_use.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _request_use() -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	var item: String = _held.get(peer, "")
	if guard == null or guard.is_dead:
		return
	match item:
		"":
			_tell(peer, "You're not carrying anything. Buy something at the vending machine.")
		"camera_kit":
			_tell(peer, "Take it to a desk chair in the guard room and press E to install it.")
		"lucky_charm":
			_tell(peer, "Keep it on you. It helps your roll at a revive totem.")
		"door_kit":
			_tell(peer, "Stand in one of the guard room's doorways and press E to fit it.")
		"motion_sensor", "glue_trap":
			if take(peer, item):
				var at := guard.global_position
				at.y = 0.0
				_place.rpc(_next_drop, item, at)
				_next_drop += 1
				_tell(peer, "Motion sensor set up in %s." % _area_name(at) if item == "motion_sensor" else "Glue trap down. Try not to step in it.")
		"energy_drink":
			if take(peer, item):
				if peer == multiplayer.get_unique_id():
					_drink()
				else:
					_drink.rpc_id(peer)
				_tell(peer, "You down the energy drink. Your heart's going like a drum.")
		"flashlight":
			if take(peer, item):
				set_bright(peer, true)
				_tell(peer, "You swap in the heavy-duty flashlight. That's a proper beam.")


## Host: fits (or removes) a guard's heavy-duty flashlight, on every computer.
func set_bright(peer_id: int, on: bool) -> void:
	if on and peer_id not in _bright:
		_bright.append(peer_id)
	elif not on:
		_bright.erase(peer_id)
	_set_bright.rpc(peer_id, on)


## Host: a guard's player left; what they held is now kept in the save (see Night).
func forget(peer_id: int) -> void:
	_held.erase(peer_id)
	_bright.erase(peer_id)


func has_bright(peer_id: int) -> bool:
	return peer_id in _bright


## Host: brings a player who just joined up to date on everyone's flashlights.
func send_state_to(peer_id: int) -> void:
	for bright_peer in _bright:
		_set_bright.rpc_id(peer_id, bright_peer, true)
	# Anything still sitting in the vending machine's tray.
	for drop_id: int in _drops:
		_spawn_drop.rpc_id(peer_id, drop_id, _drops[drop_id]["item"])


@rpc("authority", "call_local", "reliable")
func _set_bright(peer_id: int, on: bool) -> void:
	var guard := director.guard_by_peer(peer_id)
	if guard:
		guard.set_bright_flashlight(on)


@rpc("authority", "call_remote", "reliable")
func _drink() -> void:
	var guard := director.guard_by_peer(multiplayer.get_unique_id())
	if guard:
		guard.boost_left = BOOST_SECONDS


## Host, every frame of the night: sensors notice monsters walking by, traps catch them.
func update(delta: float) -> void:
	for id: int in _placed.keys():
		var placed: Dictionary = _placed[id]
		placed["quiet"] = maxf(placed["quiet"] - delta, 0.0)
		var at: Vector3 = placed["position"]
		for monster in director.active_monsters():
			var distance := Vector2(monster.global_position.x - at.x, monster.global_position.z - at.z).length()
			if placed["item"] == "motion_sensor" and distance < SENSOR_RANGE and placed["quiet"] <= 0.0:
				placed["quiet"] = SENSOR_COOLDOWN
				director.announcement.emit("Motion sensor: something moved in %s." % _area_name(at), "sensor")
			elif placed["item"] == "glue_trap" and distance < TRAP_RANGE and monster.stuck_in_trap <= 0.0:
				monster.stuck_in_trap = TRAP_SECONDS
				director.announcement.emit("A glue trap in %s just caught something." % _area_name(at), "sensor")
				_remove_placed.rpc(id)
				break


## Host: the night's over, so the sensors and traps get cleared away.
func clear_placed() -> void:
	for id: int in _placed.keys():
		_remove_placed.rpc(id)


@rpc("authority", "call_local", "reliable")
func _place(id: int, item: String, at: Vector3) -> void:
	var node := Node3D.new()
	node.position = at
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if item == "motion_sensor":
		mesh.mesh = Monster.box(Vector3(0.2, 0.3, 0.2))
		mesh.position.y = 0.15
		material.albedo_color = Color(0.2, 0.2, 0.22)
		var led := MeshInstance3D.new()
		led.mesh = Monster.sphere(0.03)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.2, 1.0, 0.3)
		glow.emission_enabled = true
		glow.emission = Color(0.2, 1.0, 0.3)
		glow.emission_energy_multiplier = 3.0
		led.material_override = glow
		led.position = Vector3(0, 0.32, 0)
		node.add_child(led)
	else:
		mesh.mesh = Monster.box(Vector3(0.7, 0.02, 0.7))
		mesh.position.y = 0.01
		material.albedo_color = Color(0.9, 0.8, 0.2)
	mesh.material_override = material
	node.add_child(mesh)
	add_child(node)
	_placed[id] = {"item": item, "node": node, "position": at, "quiet": 0.0}


@rpc("authority", "call_local", "reliable")
func _remove_placed(id: int) -> void:
	if _placed.has(id):
		(_placed[id]["node"] as Node).queue_free()
		_placed.erase(id)


func _area_name(at: Vector3) -> String:
	var area := SchoolBuilder.area_at(at)
	return area if area != "" else "the guard room"


## Host: hands a guard an item without buying it, e.g. one they were carrying in a saved run.
func give(peer_id: int, item: String) -> void:
	if ITEMS.has(item):
		_held[peer_id] = item
		_send_holding(peer_id)


## Host: what a guard is carrying ("" for nothing).
func held_by(peer_id: int) -> String:
	return _held.get(peer_id, "")


## Host: tells every player their current points, e.g. after the night report.
func push_wallets() -> void:
	for peer_id: int in _all_peers():
		_send_wallet(peer_id)


## Host: the run is starting over; nobody keeps anything.
func reset_all() -> void:
	for peer_id: int in _held.keys():
		_held.erase(peer_id)
		_send_holding(peer_id)
	for drop_id: int in _drops.keys():
		_remove_drop.rpc(drop_id)
	for peer_id in _bright.duplicate():
		set_bright(peer_id, false)
	clear_placed()
	push_wallets()


@rpc("any_peer", "call_remote", "reliable")
func _request_buy(item: String) -> void:
	if not multiplayer.is_server() or not ITEMS.has(item):
		return
	var peer := _sender()
	var buyer := director.guard_by_peer(peer)
	if buyer == null or buyer.is_dead:
		return
	var price: int = ITEMS[item]["price"]
	if night.points_of(peer) < price:
		_tell(peer, "You don't have enough points for that.")
		return
	night.spend(peer, price)
	_send_wallet(peer)
	_spawn_drop.rpc(_next_drop, item)
	_next_drop += 1
	_tell(peer, "Clunk. %s drops into the tray." % item_name(item))


@rpc("any_peer", "call_remote", "reliable")
func _request_pickup(drop_id: int) -> void:
	if not multiplayer.is_server() or not _drops.has(drop_id):
		return
	var peer := _sender()
	if _held.has(peer):
		_tell(peer, "Your hands are full. You're carrying the %s." % item_name(_held[peer]).to_lower())
		return
	_held[peer] = _drops[drop_id]["item"]
	_remove_drop.rpc(drop_id)
	_send_holding(peer)


@rpc("authority", "call_local", "reliable")
func _spawn_drop(drop_id: int, item: String) -> void:
	var pickup := Interactable.new()
	pickup.prompt = "Pick up: %s" % item_name(item)
	pickup.position = TRAY + Vector3(0, 0, randf_range(-0.25, 0.25))
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.35, 0.25, 0.3)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	pickup.add_child(collider)
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(Vector3(0.3, 0.2, 0.25))
	mesh.material_override = _box_material
	pickup.add_child(mesh)
	pickup.used.connect(func(_by: Node) -> void:
		if multiplayer.is_server():
			_request_pickup(drop_id)
		else:
			_request_pickup.rpc_id(1, drop_id))
	add_child(pickup)
	_drops[drop_id] = {"item": item, "node": pickup}


@rpc("authority", "call_local", "reliable")
func _remove_drop(drop_id: int) -> void:
	if _drops.has(drop_id):
		(_drops[drop_id]["node"] as Node).queue_free()
		_drops.erase(drop_id)


## Host: sends one guard their points.
func send_wallet(peer_id: int) -> void:
	_send_wallet(peer_id)


func _send_wallet(peer_id: int) -> void:
	var points := night.points_of(peer_id)
	if peer_id == multiplayer.get_unique_id():
		_set_wallet(points)
	else:
		_set_wallet.rpc_id(peer_id, points)


func _send_holding(peer_id: int) -> void:
	var item: String = _held.get(peer_id, "")
	if peer_id == multiplayer.get_unique_id():
		_set_holding(item)
	else:
		_set_holding.rpc_id(peer_id, item)


@rpc("authority", "call_remote", "reliable")
func _set_wallet(points: int) -> void:
	local_points = points
	wallet_changed.emit(points)


@rpc("authority", "call_remote", "reliable")
func _set_holding(item: String) -> void:
	local_item = item
	holding_changed.emit(item)


func _tell(peer_id: int, text: String) -> void:
	director.tell(peer_id, text)


func _all_peers() -> Array[int]:
	var peers: Array[int] = [multiplayer.get_unique_id()]
	for peer in multiplayer.get_peers():
		peers.append(peer)
	return peers


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
