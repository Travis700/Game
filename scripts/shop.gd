class_name Shop
extends Node
## The vending machine in the guard room. Guards spend the points they've earned; the item
## drops into the tray, and they pick it up and carry it (one thing at a time).
##
## The host holds everyone's points (Night keeps the totals) and what each guard is carrying.

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
}
## Where purchases land: the tray at the bottom of the vending machine.
const TRAY := Vector3(18.75, 0.15, 16.6)

var night: Night
## What this player is carrying ("" for nothing). Updated by the host.
var local_item := ""
var local_points := 0

# Host only: peer -> item id.
var _held: Dictionary = {}
var _drops: Dictionary = {}
var _next_drop := 1
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
	push_wallets()


@rpc("any_peer", "call_remote", "reliable")
func _request_buy(item: String) -> void:
	if not multiplayer.is_server() or not ITEMS.has(item):
		return
	var peer := _sender()
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
	night.director.tell(peer_id, text)


func _all_peers() -> Array[int]:
	var peers: Array[int] = [multiplayer.get_unique_id()]
	for peer in multiplayer.get_peers():
		peers.append(peer)
	return peers


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()
