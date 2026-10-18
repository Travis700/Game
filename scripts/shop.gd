class_name Shop
extends Node
## The vending machine in the guard room. Guards spend the points they've earned; the item
## drops into the tray, and they pick it up into their hotbar (the flashlight's slot, then up to
## BAG_SIZE things). Some things are fitted where they go with E (camera kit, door kit); the rest
## are used or put down with G, whichever is picked on the hotbar. A heavy-duty flashlight goes
## straight into the flashlight's slot.
##
## The host holds everyone's points (Night keeps the totals), what each guard is carrying, and
## the sensors and traps guards have put down tonight.

signal wallet_changed(points: int)
## What the local guard is carrying changed (see local_bag).
signal holding_changed(items: Array[String])

const ITEMS := {
	"camera_kit": {
		"name": "Spectral camera kit", "price": 220, "rank": 2,
		"about": "Install it at a guard room desk: stand by the desk's chair and press {item} (it takes 10 seconds). That desk's monitors then show what ordinary cameras can't.",
	},
	"lucky_charm": {
		"name": "Lucky rabbit's foot", "price": 60,
		"about": "Carry it to a revive totem. Your roll brings a teammate back on 5 in 6 instead of 4 in 6.",
	},
	"door_kit": {
		"name": "Guard room door kit", "price": 180,
		"about": "A heavy door for one of the guard room's two doorways: press {use} in the doorway to fit it, then {use} to open and shut it. Monsters can get in from night 7. A shut door holds them for a while before it gives.",
	},
	"motion_sensor": {
		"name": "Motion sensor", "price": 25,
		"about": "Press {item} to put it down. When something walks past tonight, everyone hears where.",
	},
	"glue_trap": {
		"name": "Industrial glue trap", "price": 60, "rank": 2,
		"about": "Press {item} to put it down. The first monster to step on it is stuck there for 20 seconds.",
	},
	"portable_camera": {
		"name": "Portable camera", "price": 140, "rank": 3,
		"about": "Press {item} to set it up where you stand, pointing the way you're facing. It shows up on the guard room monitors ({left} / {right} to find it) until morning. Two at most.",
	},
	"radio": {
		"name": "Walkie-talkie", "price": 130,
		"about": "Press {item} to clip it on (it's yours for the run). Hold {radio} to talk to everyone else with one, wherever they are. Careful: a radio blares when someone calls in, and monsters hear it.",
	},
	"energy_drink": {
		"name": "Energy drink", "price": 25,
		"about": "Press {item} to drink it: you run faster for 30 seconds.",
	},
	"flashlight": {
		"name": "Heavy-duty flashlight", "price": 140, "rank": 3,
		"about": "Pick it up and it replaces the flashlight in your first hotbar slot: a longer, wider beam, for good. (The Librarian will notice it from further away too.)",
	},
	"emf": {
		"name": "Pocket EMF reader", "price": 150, "rank": 2,
		"about": "Press {item} to clip it on (it's yours for the run). Its lights climb as a monster gets close, even one you can't see. A few kinds push it all the way to EMF 5 (see the field guide).",
	},
	"coffee": {
		"name": "Thermos of coffee", "price": 30,
		"about": "Press {item} to drink it: steadies your nerve (+40). Low nerve means monsters notice you sooner, and you start seeing things.",
	},
	"decoy_radio": {
		"name": "Decoy radio", "price": 60, "rank": 2,
		"about": "Press {item} to put it down. Eight seconds later it starts blaring music for twenty: everything that hunts by sound goes to look. Then get somewhere else.",
	},
	"donuts": {
		"name": "Box of donuts for the district", "price": 300, "rank": 3,
		"about": "Press {item} to send it to the district office: they forget one of the team's write-ups.",
	},
	"spirit_box": {
		"name": "Spirit box", "price": 120, "rank": 2,
		"about": "Press {item} to switch it on or off. While it's on it hisses and sweeps the stations, and anyone within about 10 metres hears caught teammates who talk near it, through the static. Monsters close by hear the hiss now and then.",
	},
	"air_horn": {
		"name": "Air horn", "price": 70, "rank": 4,
		"about": "Press {item} to blast it: every monster within 15 metres freezes for 6 seconds. Everything in the school hears it.",
	},
}
## Every item needs at least this rank to buy, unless it says otherwise.
const DEFAULT_RANK := 1
## How many things a guard can carry besides their flashlight.
const BAG_SIZE := 4
## How close a teammate has to be to hand them something.
const GIVE_REACH := 2.5
## Items used or put down with G (the rest are fitted with E).
const USED_WITH_G: Array[String] = ["camera_kit", "portable_camera", "radio", "motion_sensor", "glue_trap", "energy_drink", "flashlight", "air_horn", "coffee", "emf", "decoy_radio", "donuts", "spirit_box"]
## The decoy radio: seconds before it starts, and how long it plays.
const DECOY_DELAY := 8.0
const DECOY_SECONDS := 20.0
## How far a motion sensor notices things, and how long it stays quiet after going off.
const SENSOR_RANGE := 10.0
const SENSOR_COOLDOWN := 30.0
const TRAP_RANGE := 1.5
## How long a vending tray item is kept for whoever bought it.
const DROP_RESERVED_SECONDS := 30.0
const TRAP_SECONDS := 20.0
const BOOST_SECONDS := 30.0
const HORN_RANGE := 15.0
const HORN_SECONDS := 6.0
## A switched-on spirit box: every so often (seconds) its hiss is loud enough for a monster this
## close (metres) to notice.
const SPIRIT_NOISE_EVERY := Vector2(18.0, 35.0)
const SPIRIT_NOISE_REACH := 12.0
## Where purchases land: the tray at the bottom of the vending machine.
const TRAY := Vector3(18.75, 0.15, 16.6)

var night: Night
var director: MonsterDirector
var cameras: SecurityCameras
var career: Career
## Host: points spent this run, by badge (for the Big spender achievement). Saved with the run.
var spent: Dictionary = {}
var guard_room: GuardRoom
## What this player is carrying, in hotbar order after the flashlight. Updated by the host.
var local_bag: Array[String] = []
var local_points := 0

# Host only: peer -> Array[String] of item ids, in hotbar order.
var _held: Dictionary = {}
var _drops: Dictionary = {}
var _next_drop := 1
## Sensors and traps put down tonight: id -> {"item", "node", "position", "quiet"}. Every computer
## has the nodes; the host checks them.
var _placed: Dictionary = {}
## Host: drop id -> [buyer peer, when bought].
var _drop_buyers: Dictionary = {}
# Host only: drop id -> the peer whose pockets it goes back to, for things put down on the floor.
var _floor_owners: Dictionary = {}
## Host: personal upgrades each guard has fitted for the run: peer -> ["flashlight", "radio"].
var _owned: Dictionary = {}
var _box_material: StandardMaterial3D
## Host: peer -> seconds until their switched-on spirit box next hisses loud enough for monsters.
var _spirit_boxes: Dictionary = {}


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


## Is the local guard carrying one of these?
func has_local(item: String) -> bool:
	return item in local_bag


func _bag(peer_id: int) -> Array:
	if not _held.has(peer_id):
		_held[peer_id] = []
	return _held[peer_id]


## Host: takes an item from a guard (e.g. installing the camera kit). True if they had it.
func take(peer_id: int, item: String) -> bool:
	var bag := _bag(peer_id)
	if not item in bag:
		return false
	bag.erase(item)
	_send_holding(peer_id)
	return true


## Uses or puts down the `index`th thing carried (0 for the first; the hotbar's slot 2) (G).
func request_use(index: int) -> void:
	if multiplayer.is_server():
		_request_use(index)
	else:
		_request_use.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_use(index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	var bag := _bag(peer)
	var item: String = bag[index] if index >= 0 and index < bag.size() else ""
	if guard == null or guard.is_dead:
		return
	match item:
		"":
			_tell(peer, "Nothing in that slot. Buy something at the vending machine." if not bag.is_empty()
					else "You're not carrying anything. Buy something at the vending machine.")
		"camera_kit":
			_tell(peer, "Stand by a desk chair in the guard room and press {item} to install it.")
		"lucky_charm":
			_tell(peer, "Keep it on you. It helps your roll at a revive totem.")
		"door_kit":
			_tell(peer, "Stand in one of the guard room's doorways and press {use} to fit it.")
		"motion_sensor", "glue_trap":
			if take(peer, item):
				var at := guard.global_position
				at.y = 0.0
				_place.rpc(_next_drop, item, at)
				_next_drop += 1
				_tell(peer, "Motion sensor set up in %s." % _area_name(at) if item == "motion_sensor" else "Glue trap down. Try not to step in it.")
		"portable_camera":
			var slot := cameras.free_portable()
			if slot < 0:
				_tell(peer, "Both portable camera channels are in use tonight.")
				return
			if take(peer, item):
				var forward := -guard.global_basis.z
				forward.y = 0.0
				forward = forward.normalized()
				var at := guard.global_position + forward * 0.2 + Vector3(0, 2.2, 0)
				var target := at + forward * 8.0
				target.y = 0.6
				cameras.place_portable.rpc(slot, at, target)
				_tell(peer, "Portable camera %d is up. Find it on the guard room monitors." % (slot + 1))
		"coffee":
			if night.shift.state != Shift.State.ON_SHIFT:
				_tell(peer, "Save it for the night. You'll need it then.")
			elif take(peer, item):
				night.nerve.add(peer, 40.0)
				_tell(peer, "Hot, bitter, and exactly what you needed. Your hands stop shaking.")
		"decoy_radio":
			if night.shift.state != Shift.State.ON_SHIFT:
				_tell(peer, "Save it for the night.")
			elif take(peer, item):
				var at := guard.global_position
				at.y = 0.0
				var id := _next_drop
				_next_drop += 1
				_place.rpc(id, item, at)
				_tell(peer, "The decoy radio's down. Eight seconds. Move.")
				get_tree().create_timer(DECOY_DELAY, false).timeout.connect(func() -> void:
					if not _placed.has(id):
						return
					director.make_noise(at, DECOY_SECONDS)
					_decoy_plays.rpc(id))
				get_tree().create_timer(DECOY_DELAY + DECOY_SECONDS, false).timeout.connect(func() -> void:
					if _placed.has(id):
						_remove_placed.rpc(id))
		"donuts":
			if night.write_ups <= 0:
				_tell(peer, "The team hasn't got any write-ups. Keep the donuts for when you do.")
			elif take(peer, item):
				night.write_ups -= 1
				night._send_quota()
				_tell(peer, "The district office sends its thanks. One write-up quietly disappears.")
		"spirit_box":
			var on := not _spirit_boxes.has(peer)
			set_spirit_box(peer, on)
			_tell(peer, "You switch the spirit box on. It hisses, sweeping the stations. Anyone caught can talk to you through it now. Keep it quiet." if on
					else "You switch the spirit box off. Quiet again.")
		"air_horn":
			if take(peer, item):
				var frozen := 0
				for monster in director.active_monsters():
					if monster.global_position.distance_to(guard.global_position) < HORN_RANGE:
						monster.stuck_in_trap = maxf(monster.stuck_in_trap, HORN_SECONDS)
						frozen += 1
				# As loud as it gets: everything listening hears it, from far off, and the ones it froze
				# come to look once they can move again.
				director.report_voice(peer, 1.0, false)
				var at := guard.global_position
				director.make_noise(at, 4.0, 60.0)
				get_tree().create_timer(HORN_SECONDS).timeout.connect(func() -> void:
					director.make_noise(at, 10.0, 60.0))
				_horn.rpc(peer)
				_tell(peer, "HOOOONK. Everything nearby freezes." if frozen > 0 else "HOOOONK. Nothing nearby, but everything heard that.")
		"energy_drink":
			if take(peer, item):
				if peer == multiplayer.get_unique_id():
					_drink()
				else:
					_drink.rpc_id(peer)
				_tell(peer, "You down the energy drink. Your heart's going like a drum.")
		"flashlight", "radio", "emf":
			if owns(peer, item):
				_tell(peer, "You've already got one of those.")
				return
			if take(peer, item):
				_fit(peer, item)


## Puts down the `index`th thing carried at your feet, or hands it to `to_peer` (0: nobody).
func request_drop(index: int, to_peer := 0) -> void:
	if multiplayer.is_server():
		_request_drop(index, to_peer)
	else:
		_request_drop.rpc_id(1, index, to_peer)


@rpc("any_peer", "call_remote", "reliable")
func _request_drop(index: int, to_peer: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	var bag := _bag(peer)
	if guard == null or guard.is_dead or guard.hiding or index < 0 or index >= bag.size():
		return
	var item: String = bag[index]
	var other := director.guard_by_peer(to_peer) if to_peer != 0 else null
	if other and not other.is_dead and other.global_position.distance_to(guard.global_position) < GIVE_REACH:
		if _bag(to_peer).size() >= BAG_SIZE:
			_tell(peer, "Their pockets are full.")
			return
		bag.remove_at(index)
		_send_holding(peer)
		give(to_peer, item)
		_tell(peer, "You hand over the %s." % item_name(item).to_lower())
		_tell(to_peer, "%s hands you the %s." % [guard.display_name(), item_name(item).to_lower()])
		return
	bag.remove_at(index)
	_send_holding(peer)
	drop_at(item, guard.global_position - guard.global_basis.z * 0.5, peer)


## Host: leaves an item on the floor at `at` for anyone to pick up. Whatever's still lying
## about in the morning goes back into `owner_peer`'s pockets.
func drop_at(item: String, at: Vector3, owner_peer: int) -> void:
	var floor_at := Vector3(at.x, 0.12, at.z)
	_floor_owners[_next_drop] = owner_peer
	_spawn_drop.rpc(_next_drop, item, floor_at)
	_next_drop += 1


## Host: a caught guard's pockets spill on the floor beside them, for the others to pick up.
func spill(peer_id: int, at: Vector3) -> void:
	var bag := _bag(peer_id)
	for i in bag.size():
		drop_at(bag[i], at + Vector3(cos(i * 1.7), 0, sin(i * 1.7)) * 0.6, peer_id)
	bag.clear()
	_send_holding(peer_id)


## Host: the night's over; things left on the floor go back to whoever dropped them.
func _return_floor_items() -> void:
	for drop_id: int in _floor_owners.keys():
		var owner_peer: int = _floor_owners[drop_id]
		if _drops.has(drop_id):
			var item: String = _drops[drop_id]["item"]
			_remove_drop.rpc(drop_id)
			if owner_peer in _connected_peers() and _bag(owner_peer).size() < BAG_SIZE:
				give(owner_peer, item)
			else:
				# No room (or they've gone): it waits in the vending machine's tray instead.
				_spawn_drop.rpc(_next_drop, item, TRAY + Vector3(0, 0, randf_range(-0.25, 0.25)))
				_next_drop += 1
	_floor_owners.clear()


## Host: a personal upgrade goes on for the run.
func _fit(peer: int, item: String) -> void:
	set_owned(peer, item, true)
	_tell(peer, {"flashlight": "You swap in the heavy-duty flashlight. That's a proper beam.",
			"emf": "You clip the EMF reader to your pocket. Its lights are quiet. For now."}.get(item,
			"You clip the walkie-talkie to your belt. Hold %s to talk on it." % _key("radio_talk")))


func _connected_peers() -> Array:
	var peers: Array = Array(multiplayer.get_peers())
	peers.append(multiplayer.get_unique_id())
	return peers


## Host: fits (or removes) one of a guard's personal upgrades, on every computer.
func set_owned(peer_id: int, upgrade: String, on: bool) -> void:
	var list: Array = _owned.get_or_add(peer_id, [])
	if on and upgrade not in list:
		list.append(upgrade)
	elif not on:
		list.erase(upgrade)
	_set_owned.rpc(peer_id, upgrade, on)


## Host: does this guard have this personal upgrade?
func owns(peer_id: int, upgrade: String) -> bool:
	return upgrade in _owned.get(peer_id, [])


## Host: every personal upgrade a guard has, e.g. for saving.
func owned_by(peer_id: int) -> Array:
	return (_owned.get(peer_id, []) as Array).duplicate()


## Host: a guard's player left; what they held is now kept in the save (see Night).
func forget(peer_id: int) -> void:
	_held.erase(peer_id)
	# What they'd put down is in the save with the rest (see held_by): off the floor it goes.
	for drop_id: int in _floor_owners.keys():
		if _floor_owners[drop_id] == peer_id:
			_floor_owners.erase(drop_id)
			_remove_drop.rpc(drop_id)
	_owned.erase(peer_id)
	set_spirit_box(peer_id, false)


## Host: brings a player who just joined up to date on everyone's upgrades.
func send_state_to(peer_id: int) -> void:
	for owner_peer: int in _owned:
		for upgrade: String in _owned[owner_peer]:
			_set_owned.rpc_id(peer_id, owner_peer, upgrade, true)
	# Sensors, traps and decoys already put down (before the shift, too).
	for id: int in _placed:
		_place.rpc_id(peer_id, id, _placed[id]["item"], _placed[id]["position"])
	# Spirit boxes switched on right now.
	for owner_peer: int in _spirit_boxes:
		_set_spirit_box.rpc_id(peer_id, owner_peer, true)
	# Anything still sitting in the vending machine's tray.
	for drop_id: int in _drops:
		_spawn_drop.rpc_id(peer_id, drop_id, _drops[drop_id]["item"], _drops[drop_id]["at"])


@rpc("authority", "call_local", "reliable")
func _set_owned(peer_id: int, upgrade: String, on: bool) -> void:
	var guard := director.guard_by_peer(peer_id)
	if guard:
		guard.apply_personal(upgrade, on)


@rpc("authority", "call_remote", "reliable")
func _drink() -> void:
	var guard := director.guard_by_peer(multiplayer.get_unique_id())
	if guard:
		guard.boost_left = BOOST_SECONDS


## Host: switches a guard's spirit box on or off, on every computer.
func set_spirit_box(peer_id: int, on: bool) -> void:
	if on == _spirit_boxes.has(peer_id):
		return
	if on:
		_spirit_boxes[peer_id] = randf_range(SPIRIT_NOISE_EVERY.x, SPIRIT_NOISE_EVERY.y)
	else:
		_spirit_boxes.erase(peer_id)
	_set_spirit_box.rpc(peer_id, on)


## Every computer: a guard's spirit box goes on (hissing on them) or off.
@rpc("authority", "call_local", "reliable")
func _set_spirit_box(peer_id: int, on: bool) -> void:
	var guard := director.guard_by_peer(peer_id)
	if guard == null:
		return
	guard.spirit_box_on = on
	var box := guard.get_node_or_null("SpiritBox")
	if on and box == null:
		guard.add_child(SpiritBox.new())
	elif not on and box:
		box.queue_free()


## Host: a ghost left a cold spot at `at`. Any switched-on spirit box near it spits out a word:
## "run" with a monster close to its holder, "behind" if the spot is behind them, else "here" or
## "help".
func spirit_word_near(at: Vector3) -> void:
	for peer_id: int in _spirit_boxes:
		var guard := director.guard_by_peer(peer_id)
		if guard == null or guard.global_position.distance_to(at) > SpiritBox.RANGE:
			continue
		var word: String = ["here", "help"].pick_random()
		var to := at - guard.global_position
		if to.length() > 1.0 and (-guard.global_basis.z).dot(to.normalized()) < -0.4:
			word = "behind"
		for monster in director.active_monsters():
			if monster.global_position.distance_to(guard.global_position) < 15.0:
				word = "run"
		_spirit_word.rpc(peer_id, word)


## Every computer: that guard's spirit box says a word.
@rpc("authority", "call_local", "reliable")
func _spirit_word(peer_id: int, word: String) -> void:
	var guard := director.guard_by_peer(peer_id)
	var box := guard.get_node_or_null("SpiritBox") as SpiritBox if guard else null
	if box:
		box.say(word)


## Host, every frame of the night: sensors notice monsters walking by, traps catch them.
func update(delta: float) -> void:
	for peer_id: int in _spirit_boxes.keys():
		var holder := director.guard_by_peer(peer_id)
		if holder == null or holder.is_dead:
			set_spirit_box(peer_id, false)
			continue
		_spirit_boxes[peer_id] = float(_spirit_boxes[peer_id]) - delta
		if _spirit_boxes[peer_id] <= 0.0:
			_spirit_boxes[peer_id] = randf_range(SPIRIT_NOISE_EVERY.x, SPIRIT_NOISE_EVERY.y)
			director.make_noise(holder.global_position, 2.0, 0.0, SPIRIT_NOISE_REACH)
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


## Host: the night's over, so the sensors, traps and portable cameras get cleared away.
func clear_placed() -> void:
	for peer_id: int in _spirit_boxes.keys():
		set_spirit_box(peer_id, false)
	_return_floor_items()
	for id: int in _placed.keys():
		_remove_placed.rpc(id)
	cameras.clear_portables.rpc()
	guard_room.drop_closed_cameras()


@rpc("authority", "call_local", "reliable")
func _place(id: int, item: String, at: Vector3) -> void:
	var node := Node3D.new()
	node.position = at
	var mesh := MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	if item == "decoy_radio":
		mesh.mesh = Monster.box(Vector3(0.35, 0.22, 0.12))
		mesh.position.y = 0.11
		material.albedo_color = Color(0.55, 0.15, 0.12)
	elif item == "motion_sensor":
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


## Host: a run ended; spending counts from zero again.
func reset_spending() -> void:
	spent.clear()
	_set_donuts.rpc(0)


## Every computer: how many boxes of donuts the team has sent this run. Each one costs more:
## the district's forgiveness wears thin.
static var donuts_bought := 0
const DONUTS_RISE := 100


@rpc("authority", "call_local", "reliable")
func _set_donuts(count: int) -> void:
	donuts_bought = count


## What an item costs right now.
static func price_of(item: String) -> int:
	var price: int = ITEMS[item]["price"]
	if item == "donuts":
		price += DONUTS_RISE * donuts_bought
	return price


## Host: hands a guard an item without buying it, e.g. one they were carrying in a saved run.
func give(peer_id: int, item: String) -> void:
	if ITEMS.has(item) and _bag(peer_id).size() < BAG_SIZE:
		_bag(peer_id).append(item)
		_send_holding(peer_id)


## Host: what a guard is carrying, in hotbar order (for saving: with what they've put down on
## the floor, which is theirs again in the morning).
func held_by(peer_id: int) -> Array[String]:
	var items: Array[String] = []
	items.assign(_bag(peer_id))
	for drop_id: int in _floor_owners:
		if _floor_owners[drop_id] == peer_id and _drops.has(drop_id) and items.size() < BAG_SIZE:
			items.append(_drops[drop_id]["item"])
	return items


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
	_floor_owners.clear()
	for peer_id: int in _owned.keys():
		for upgrade: String in (_owned[peer_id] as Array).duplicate():
			set_owned(peer_id, upgrade, false)
	_owned.clear()
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
	var price := price_of(item)
	if director.is_dark():
		_tell(peer, "The vending machine is dead. No power.")
		return
	if buyer.rank < rank_needed(item):
		_tell(peer, "That's for a %s or above." % Career.rank_title(rank_needed(item)))
		return
	if night.points_of(peer) < price:
		_tell(peer, "You don't have enough points for that.")
		return
	night.spend(peer, price)
	var badge := str(buyer.employee_number)
	spent[badge] = int(spent.get(badge, 0)) + price
	if career and spent[badge] >= 1000:
		career.award(peer, "BIG_SPENDER")
	_send_wallet(peer)
	_drop_buyers[_next_drop] = [peer, Time.get_ticks_msec() / 1000.0]
	_spawn_drop.rpc(_next_drop, item, TRAY + Vector3(0, 0, randf_range(-0.25, 0.25)))
	_next_drop += 1
	_tell(peer, "Clunk. %s drops into the tray." % item_name(item))
	if item == "donuts":
		_set_donuts.rpc(donuts_bought + 1)


## The rank a guard needs to buy this item.
static func rank_needed(item: String) -> int:
	return ITEMS[item].get("rank", DEFAULT_RANK)


@rpc("authority", "call_local", "reliable")
func _horn(peer_id: int) -> void:
	var guard := director.guard_by_peer(peer_id)
	if guard:
		SoundBank.play_at(guard, "air_horn", 8.0, 80.0, Sfx.notes([233.0, 233.0, 233.0, 233.0, 233.0, 233.0], 0.14, 0.6, "saw"))


## Every computer: a decoy radio starts blaring.
@rpc("authority", "call_local", "reliable")
func _decoy_plays(id: int) -> void:
	if not _placed.has(id):
		return
	var node: Node3D = _placed[id]["node"]
	var recorded := SoundBank.get_sound("radio", null, true)
	if recorded:
		var player := Sfx.play_at(node, recorded, 8.0, 60.0)
		get_tree().create_timer(DECOY_SECONDS).timeout.connect(func() -> void:
			if is_instance_valid(player):
				player.queue_free())
		return
	var tune := [392.0, 440.0, 494.0, 523.0, 494.0, 440.0, 392.0, 330.0]
	var music := create_tween().set_loops(int(DECOY_SECONDS / (tune.size() * 0.25)))
	music.tween_callback(func() -> void:
		if is_instance_valid(node):
			Sfx.play_at(node, Sfx.notes(tune, 0.25, 0.35, "square"), 6.0, 60.0))
	music.tween_interval(tune.size() * 0.25)
	node.tree_exiting.connect(music.kill)
	get_tree().call_group("captions", "heard", "Decoy", "plays", node.global_position)


@rpc("any_peer", "call_remote", "reliable")
func _request_pickup(drop_id: int) -> void:
	if not multiplayer.is_server() or not _drops.has(drop_id):
		return
	var peer := _sender()
	var item: String = _drops[drop_id]["item"]
	var guard := director.guard_by_peer(peer)
	var node: Node3D = _drops[drop_id]["node"]
	if guard == null or guard.is_dead or guard.global_position.distance_to(node.global_position) > 4.0:
		return
	# The heavy-duty flashlight goes straight into the flashlight's slot.
	if item == "flashlight" and owns(peer, item):
		_tell(peer, "You've already got the heavy-duty flashlight.")
		return
	if item != "flashlight" and _bag(peer).size() >= BAG_SIZE:
		_tell(peer, "Your pockets are full. Use or put down something first.")
		return
	# Whoever paid for it gets it (anyone may, if it's been sitting there a while).
	var buyer: Array = _drop_buyers.get(drop_id, [peer, 0.0])
	if int(buyer[0]) != peer and int(buyer[0]) in _connected_peers() \
			and Time.get_ticks_msec() / 1000.0 - float(buyer[1]) < DROP_RESERVED_SECONDS:
		_tell(peer, "That's someone else's. Give them a moment to pick it up.")
		return
	_drop_buyers.erase(drop_id)
	_floor_owners.erase(drop_id)
	_remove_drop.rpc(drop_id)
	if item == "flashlight":
		_fit(peer, item)
		return
	_bag(peer).append(item)
	_send_holding(peer)


@rpc("authority", "call_local", "reliable")
func _spawn_drop(drop_id: int, item: String, at: Vector3) -> void:
	var pickup := Interactable.new()
	pickup.prompt = "Pick up: %s" % item_name(item)
	pickup.position = at
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
	_drops[drop_id] = {"item": item, "node": pickup, "at": at}
	# Out of the machine it clunks; on the floor it just lands.
	if at.distance_to(TRAY) < 1.0:
		SoundBank.play_at(pickup, "vend", 0.0, 20.0)
	else:
		Sfx.play_at(pickup, Sfx.thud(0.5), -14.0)


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
		_set_donuts.rpc_id(peer_id, donuts_bought)


func _send_holding(peer_id: int) -> void:
	# A spirit box put down, handed over or spilled goes off.
	if _spirit_boxes.has(peer_id) and not "spirit_box" in _bag(peer_id):
		set_spirit_box(peer_id, false)
	var items := PackedStringArray(_bag(peer_id))
	if peer_id == multiplayer.get_unique_id():
		_set_holding(items)
	else:
		_set_holding.rpc_id(peer_id, items)


@rpc("authority", "call_remote", "reliable")
func _set_wallet(points: int) -> void:
	local_points = points
	wallet_changed.emit(points)


@rpc("authority", "call_remote", "reliable")
func _set_holding(items: PackedStringArray) -> void:
	local_bag.assign(Array(items))
	holding_changed.emit(local_bag)


## A player's key for an action (Controls is an autoload, looked up by path). Note this is the
## host's own setting, close enough for a hint.
func _key(action: String) -> String:
	var controls := get_node_or_null("/root/Controls")
	return controls.key_name(action) if controls else action


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
