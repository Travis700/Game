class_name Clutter
extends Node3D
## Things lying about the school you can pick up (E) and throw (right click). They're real
## physical objects: a thrown one tumbles and settles, walking into a light one (a cone, a bin,
## a ball) shoves it along, and a ghost can give one a poltergeist push. Where one lands hard it
## clatters, and the monsters that hunt by sound (the Lunch Lady, the Librarian, the Hall
## Monitor) go to look: a decoy.
##
## Only the host runs the physics. Everyone else is sent where the moving things are, ten
## times a second, and glides them there; things at rest send nothing.

## Each item: its name, where its feet stand, roughly how big it is (the model is fitted to this
## height; its footprint comes from the model), and optionally: "model" (assets/models), "shape"
## ("box", "can" for a cylinder, "ball"), "mass" (kg), "sound" (what it sounds like landing),
## "turn" (which way it faces) and "color" (for the painted box when there's no model).
const ITEMS := [
	# The originals.
	{"name": "traffic cone", "at": Vector3(-3.0, 0, 7.0), "size": Vector3(0.3, 0.45, 0.3), "color": Color(1.0, 0.4, 0.05),
		"model": "prop_cone", "shape": "cone", "mass": 1.2, "sound": "land_soft"},
	{"name": "cardboard box", "at": Vector3(-24.0, 0, 8.6), "size": Vector3(0.45, 0.35, 0.4), "color": Color(0.6, 0.45, 0.28),
		"model": "prop_cardboard_box_01", "mass": 1.5, "sound": "land_soft"},
	{"name": "basketball", "at": Vector3(18.0, 0, -6.0), "size": Vector3(0.25, 0.25, 0.25), "color": Color(0.85, 0.42, 0.1),
		"shape": "ball", "mass": 0.6, "sound": "ball_bounce"},
	{"name": "lunch tray", "at": Vector3(-25.2, 0.75, -8.0), "size": Vector3(0.45, 0.04, 0.32), "color": Color(0.55, 0.6, 0.62),
		"mass": 0.4, "sound": "land_plate"},
	{"name": "stack of books", "at": Vector3(-14.5, 0.79, 17.5), "size": Vector3(0.3, 0.2, 0.22), "color": Color(0.5, 0.15, 0.12),
		"model": "prop_book_stack", "mass": 2.0, "sound": "land_wood"},
	{"name": "mop bucket lid", "at": Vector3(2.5, 0, -8.0), "size": Vector3(0.35, 0.06, 0.35), "color": Color(0.8, 0.7, 0.1),
		"mass": 0.4, "sound": "land_plate"},
	{"name": "trophy", "at": Vector3(-4.6, 0, 13.6), "size": Vector3(0.15, 0.35, 0.15), "color": Color(0.85, 0.7, 0.2),
		"mass": 1.0, "sound": "land_metal"},
	{"name": "paint tin", "at": Vector3(30.0, 0, 8.8), "size": Vector3(0.22, 0.25, 0.22), "color": Color(0.3, 0.45, 0.7),
		"shape": "can", "mass": 2.0, "sound": "land_metal"},
	{"name": "library book", "at": Vector3(-70.0, 0.79, -1.0), "size": Vector3(0.22, 0.06, 0.3), "color": Color(0.2, 0.3, 0.5),
		"model": "prop_book_stack", "mass": 0.8, "sound": "land_wood"},
	{"name": "beaker", "at": Vector3(54.0, 0.92, -5.0), "size": Vector3(0.12, 0.2, 0.12), "color": Color(0.7, 0.9, 0.8),
		"mass": 0.3, "sound": "land_plate"},
	{"name": "dodgeball", "at": Vector3(66.0, 0, 13.0), "size": Vector3(0.25, 0.25, 0.25), "color": Color(0.8, 0.15, 0.15),
		"shape": "ball", "mass": 0.4, "sound": "ball_bounce"},
	# The main hall and the wing halls.
	{"name": "trash can", "at": Vector3(-22.0, 0, 8.95), "size": Vector3(0.4, 0.6, 0.4), "model": "prop_trash_can",
		"shape": "can", "mass": 3.0, "sound": "land_metal"},
	{"name": "wet floor sign", "at": Vector3(12.0, 0, 5.4), "size": Vector3(0.3, 0.6, 0.3), "model": "prop_wet_floor_sign",
		"mass": 1.0, "sound": "land_plate", "turn": 0.4},
	{"name": "traffic cone", "at": Vector3(30.0, 0, 5.5), "size": Vector3(0.3, 0.45, 0.3), "model": "prop_cone",
		"shape": "cone", "mass": 1.2, "sound": "land_soft"},
	{"name": "cardboard box", "at": Vector3(-36.0, 0, 5.4), "size": Vector3(0.45, 0.35, 0.4), "model": "prop_cardboard_box_01",
		"mass": 1.5, "sound": "land_soft", "turn": 0.5},
	{"name": "backpack", "at": Vector3(-56.0, 0, 5.5), "size": Vector3(0.3, 0.42, 0.2), "model": "prop_backpack",
		"mass": 1.5, "sound": "land_soft", "turn": 1.2},
	{"name": "traffic cone", "at": Vector3(60.0, 0, 8.5), "size": Vector3(0.3, 0.45, 0.3), "model": "prop_cone",
		"shape": "cone", "mass": 1.2, "sound": "land_soft"},
	# The cafeteria.
	{"name": "milk carton", "at": Vector3(-31.5, 0.745, -1.4), "size": Vector3(0.07, 0.11, 0.07), "model": "prop_milk_carton",
		"mass": 0.2, "sound": "land_soft", "turn": 0.7},
	{"name": "milk carton", "at": Vector3(-22.0, 0.745, -8.1), "size": Vector3(0.07, 0.11, 0.07), "model": "prop_milk_carton",
		"mass": 0.2, "sound": "land_soft", "turn": 2.1},
	{"name": "school chair", "at": Vector3(-20.0, 0, -25.0), "size": Vector3(0.45, 0.82, 0.45), "model": "prop_school_chair",
		"mass": 4.0, "sound": "land_metal", "turn": 0.3},
	{"name": "trash can", "at": Vector3(-30.0, 0, 2.5), "size": Vector3(0.4, 0.6, 0.4), "model": "prop_trash_can",
		"shape": "can", "mass": 3.0, "sound": "land_metal"},
	# The gym.
	{"name": "basketball", "at": Vector3(20.0, 0, -15.0), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.6,
		"sound": "ball_bounce", "color": Color(0.85, 0.42, 0.1)},
	{"name": "basketball", "at": Vector3(26.0, 0, -9.0), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.6,
		"sound": "ball_bounce", "color": Color(0.85, 0.42, 0.1)},
	{"name": "basketball", "at": Vector3(17.0, 0, -22.0), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.6,
		"sound": "ball_bounce", "color": Color(0.85, 0.42, 0.1)},
	{"name": "dodgeball", "at": Vector3(21.0, 0, -4.0), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.4,
		"sound": "ball_bounce", "color": Color(0.8, 0.15, 0.15)},
	{"name": "traffic cone", "at": Vector3(10.0, 0, -26.0), "size": Vector3(0.3, 0.45, 0.3), "model": "prop_cone",
		"shape": "cone", "mass": 1.2, "sound": "land_soft"},
	# The front office and the lobby.
	{"name": "coffee mug", "at": Vector3(-18.6, 0.77, 15.2), "size": Vector3(0.1, 0.1, 0.1), "model": "prop_coffee_mug",
		"mass": 0.3, "sound": "land_plate", "turn": 1.0},
	{"name": "stack of books", "at": Vector3(-13.35, 0.77, 17.4), "size": Vector3(0.3, 0.11, 0.22), "model": "prop_book_stack",
		"mass": 1.5, "sound": "land_wood", "turn": 0.3},
	{"name": "backpack", "at": Vector3(2.0, 0, 13.0), "size": Vector3(0.3, 0.42, 0.2), "model": "prop_backpack",
		"mass": 1.5, "sound": "land_soft", "turn": 2.6},
	{"name": "cardboard box", "at": Vector3(-1.5, 0, 16.0), "size": Vector3(0.45, 0.35, 0.4), "model": "prop_cardboard_box_01",
		"mass": 1.5, "sound": "land_soft", "turn": 1.1},
	# The library.
	{"name": "stack of books", "at": Vector3(-69.2, 0.765, -0.8), "size": Vector3(0.3, 0.11, 0.22), "model": "prop_book_stack",
		"mass": 1.5, "sound": "land_wood", "turn": 2.0},
	{"name": "globe", "at": Vector3(-60.3, 0.765, -9.2), "size": Vector3(0.3, 0.4, 0.3), "model": "prop_globe",
		"mass": 1.5, "sound": "land_plate", "turn": 0.8},
	# The classrooms.
	{"name": "backpack", "at": Vector3(-49.4, 0, 13.0), "size": Vector3(0.3, 0.42, 0.2), "model": "prop_backpack",
		"mass": 1.5, "sound": "land_soft", "turn": 0.4},
	{"name": "basketball", "at": Vector3(-42.2, 0, 12.0), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.6,
		"sound": "ball_bounce", "color": Color(0.85, 0.42, 0.1)},
	{"name": "cardboard box", "at": Vector3(-58.6, 0, 13.0), "size": Vector3(0.45, 0.35, 0.4), "model": "prop_cardboard_box_01",
		"mass": 1.5, "sound": "land_soft", "turn": 2.3},
	{"name": "school chair", "at": Vector3(-51.4, 0, -7.0), "size": Vector3(0.45, 0.82, 0.45), "model": "prop_school_chair",
		"mass": 4.0, "sound": "land_metal", "turn": 2.8},
	{"name": "dodgeball", "at": Vector3(-44.2, 0, 0.8), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.4,
		"sound": "ball_bounce", "color": Color(0.8, 0.15, 0.15)},
	# The science wing and its locker rooms.
	{"name": "trash can", "at": Vector3(42.5, 0, 2.8), "size": Vector3(0.4, 0.6, 0.4), "model": "prop_trash_can",
		"shape": "can", "mass": 3.0, "sound": "land_metal"},
	{"name": "cardboard box", "at": Vector3(58.5, 0, -12.8), "size": Vector3(0.45, 0.35, 0.4), "model": "prop_cardboard_box_01",
		"mass": 1.5, "sound": "land_soft", "turn": 0.2},
	{"name": "basketball", "at": Vector3(51.5, 0, 17.0), "size": Vector3(0.25, 0.25, 0.25), "shape": "ball", "mass": 0.6,
		"sound": "ball_bounce", "color": Color(0.85, 0.42, 0.1)},
	{"name": "mop bucket", "at": Vector3(56.5, 0, 18.5), "size": Vector3(0.45, 0.5, 0.35), "model": "prop_mop_bucket",
		"mass": 4.0, "sound": "land_plate", "turn": -0.6},
	# The custodian's closet, the kitchen and the nurse.
	{"name": "mop bucket", "at": Vector3(-2.5, 0, 1.5), "size": Vector3(0.45, 0.5, 0.35), "model": "prop_mop_bucket",
		"mass": 4.0, "sound": "land_plate", "turn": 0.9},
	{"name": "traffic cone", "at": Vector3(1.5, 0, -3.5), "size": Vector3(0.3, 0.45, 0.3), "model": "prop_cone",
		"shape": "cone", "mass": 1.2, "sound": "land_soft"},
	{"name": "cooking pot", "at": Vector3(2.0, 0, -25.0), "size": Vector3(0.3, 0.18, 0.25), "model": "prop_pot_enamel_01",
		"shape": "can", "mass": 1.0, "sound": "land_metal", "turn": 1.4},
	{"name": "first-aid kit", "at": Vector3(-71.0, 0.77, 12.15), "size": Vector3(0.3, 0.12, 0.2), "model": "prop_medical_box",
		"mass": 0.8, "sound": "land_plate", "turn": 0.2},
]
## Physics layer the clutter itself is on: it bumps into the school and into other clutter, but
## guards walk through it (shoving it as they go, see _push_by_guards) and monsters ignore it.
const PROP_LAYER := 1 << 14
## How hard a throw is (m/s along the guard's look, plus a little lift).
const THROW_SPEED := 8.5
const THROW_LIFT := 1.5
## How long the noise carries, and how often each ghost can knock things.
const NOISE_SECONDS := 6.0
const KNOCK_EVERY := 20.0
## A change of speed this sudden (m/s in one physics step) is a clatter you can hear...
const CLATTER_AT := 1.6
## ...and this sudden is loud enough to bring the sound hunters, even if nobody threw it.
const LOUD_AT := 5.0
## Things this light or lighter get shoved along when a guard walks into them.
const PUSHABLE_MASS := 5.0
## How often the host sends where moving things are (seconds).
const SYNC_EVERY := 0.1
## At most this many moving things in one packet (each is 32 bytes).
const POSES_PER_PACKET := 30

## Someone picked something up or let go of it (for the HUD).
signal carried_changed

var director: MonsterDirector
var shift: Shift

## Peer id -> the index of the item they're carrying. On every computer.
var carried: Dictionary = {}

## What E is pressed on: one per item, riding along inside it.
var _props: Array[Interactable] = []
var _bodies: Array[RigidBody3D] = []
## Each item's half-width across the floor (for guards walking into it).
var _radius: Array[float] = []
var _knock_ready: Dictionary = {}
## Host: each item's velocity last physics step (to feel it hit something), whether it was
## thrown or knocked and still owes the monsters a noise, when it last clattered, and whether it
## was moving at the last send.
var _last_velocity: Array[Vector3] = []
var _owes_noise: Array[bool] = []
var _clattered_at: Array[float] = []
var _was_moving: Array[bool] = []
var _still_for: Array[float] = []
var _sync_left := 0.0
## Host: guard -> where they were last physics step (so we know which way they're walking).
var _guard_steps: Dictionary = {}
## Guards each item has been told to pass through (they're on the school's layer).
var _excepted: Dictionary = {}
## Everyone else: where each item is heading (from the host), and the newest host physics frame
## heard about it (older news arriving late is ignored). Items still gliding are in _gliding.
var _goal: Array[Transform3D] = []
var _heard: Array[int] = []
var _gliding: Dictionary = {}
## Whether this computer was simulating last frame (it changes when we join someone).
var _simulating := true
## Host: who last threw each item (for a basket), each ball's height last step, and baskets
## sunk this session.
var _thrown_by: Dictionary = {}
var _ball_y: Dictionary = {}
var _baskets: Dictionary = {}
## The gym's two rims (the centre of each ring), and how near the middle a ball has to drop.
const RIM_HEIGHT := 3.05
const RIM_CATCH := 0.2
var _shift_state := -1


func _ready() -> void:
	for i in ITEMS.size():
		_build(i)


## The item a guard's carrying, as "traffic cone", or "".
func carried_name(peer_id: int) -> String:
	return ITEMS[carried[peer_id]]["name"] if carried.has(peer_id) else ""


## Which item this collider is, or -1.
func index_of(body: Object) -> int:
	return _props.find(body) if body is Interactable else -1


## Where an item is right now (its middle).
func position_of(index: int) -> Vector3:
	return _bodies[index].global_position


# --- Host --------------------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func request_pick_up(index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := _sender()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead or index < 0 or index >= _props.size() or index in carried.values():
		return
	# (Basketballs are fair game before the shift: shoot some hoops while the team turns up.)
	if shift and shift.state != Shift.State.ON_SHIFT and ITEMS[index]["name"] != "basketball":
		director.tell(peer, "Leave it. The school's tidy until the shift starts.")
		return
	if carried.has(peer):
		director.tell(peer, "Your hands are full. {throw} to throw the %s first." % carried_name(peer))
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
	if guard == null or guard.is_dead or not carried.has(peer) or from.distance_to(guard.global_position) > 3.0:
		return
	var index: int = carried[peer]
	direction = direction.normalized()
	_thrown_by[index] = peer
	_set_carried.rpc(peer, -1)
	var start := _clear_spot(from, direction, 0.45)
	var spin := Vector3(randf_range(-6, 6), randf_range(-3, 3), randf_range(-6, 6))
	_launch(index, Transform3D(_bodies[index].global_basis, start), direction * THROW_SPEED + Vector3(0, THROW_LIFT, 0), spin, true)


## A ghost knocked an item: a poltergeist shove that sends it skidding (or flying, if it's light).
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
	var body := _bodies[index]
	# Away from the ghost, more or less, and up.
	var away := body.global_position - guard.global_position
	away.y = 0.0
	away = (away.normalized() if away.length() > 0.1 else Vector3.FORWARD).rotated(Vector3.UP, randf_range(-0.6, 0.6))
	var spin := Vector3(randf_range(-8, 8), randf_range(-4, 4), randf_range(-8, 8))
	_launch(index, body.global_transform, away * randf_range(2.5, 4.0) + Vector3(0, randf_range(2.5, 3.5), 0), spin, true)


## Host: a guard who was carrying something was caught or left: it drops where they were.
func drop(peer: int, at: Vector3) -> void:
	if not carried.has(peer):
		return
	var index: int = carried[peer]
	_set_carried.rpc(peer, -1)
	var start := Transform3D(Basis(Vector3.UP, randf() * TAU), at + Vector3(0, 0.9, 0))
	_launch(index, start, Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)), Vector3.ZERO, false)


## Host: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	for peer: int in carried:
		_set_carried.rpc_id(peer_id, peer, carried[peer])
	var frame := Engine.get_physics_frames()
	for i in _bodies.size():
		if i not in carried.values():
			_place.rpc_id(peer_id, i, _bodies[i].global_transform, frame, true)


## Host: the night's over; everyone drops what they're holding and things go back.
func reset_all() -> void:
	for peer: int in carried.keys():
		_set_carried.rpc(peer, -1)
	var frame := Engine.get_physics_frames()
	for i in _bodies.size():
		_place.rpc(i, _home(i), frame, true)


## Host: an item leaves someone's hands (or a ghost's shove) from `start`, moving.
func _launch(index: int, start: Transform3D, velocity: Vector3, spin: Vector3, noisy: bool) -> void:
	_place.rpc(index, start, Engine.get_physics_frames(), false)
	var body := _bodies[index]
	body.sleeping = false
	body.linear_velocity = velocity
	body.angular_velocity = spin
	_last_velocity[index] = velocity
	_owes_noise[index] = noisy
	_was_moving[index] = true


## Just in front of the guard's eyes, unless that's inside a wall: then just short of it.
func _clear_spot(from: Vector3, direction: Vector3, reach: float) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * (reach + 0.25), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return from + direction * reach
	return from + direction * maxf(from.distance_to(hit["position"]) - 0.25, 0.0)


func _sender() -> int:
	var peer := multiplayer.get_remote_sender_id()
	return peer if peer != 0 else multiplayer.get_unique_id()


func _physics_process(delta: float) -> void:
	var simulating := not multiplayer.has_multiplayer_peer() or multiplayer.is_server()
	if simulating != _simulating:
		_simulating = simulating
		for i in _bodies.size():
			_apply_role(i)
	if not simulating:
		return
	_pass_through_guards()
	var now := Time.get_ticks_msec() / 1000.0
	for i in _bodies.size():
		var body := _bodies[i]
		if body.freeze or body.sleeping:
			if _owes_noise[i] and body.sleeping:
				# It came to rest without a bang worth the name: it still made some noise.
				_owes_noise[i] = false
				_make_noise(body.global_position)
			continue
		if body.global_position.y < -3.0:
			# Squeezed out through the floor by something (an anomaly moving in on it): home it goes.
			_place.rpc(i, _home(i), Engine.get_physics_frames(), true)
			continue
		var velocity := body.linear_velocity
		var change := (velocity - _last_velocity[i]).length()
		if change > CLATTER_AT and now - _clattered_at[i] > 0.2:
			_clattered_at[i] = now
			_clatter.rpc(i, body.global_position, minf(change / LOUD_AT, 1.0))
			if _owes_noise[i] or change > LOUD_AT:
				_owes_noise[i] = false
				_make_noise(body.global_position)
		_last_velocity[i] = velocity
		# Round things can rock on the spot for ever: once it's all but still, it's asleep.
		if velocity.length() < 0.12 and body.angular_velocity.length() < 1.0:
			_still_for[i] += delta
			if _still_for[i] > 0.6:
				body.sleeping = true
		else:
			_still_for[i] = 0.0
	_watch_hoops()
	_tidy_balls_for_shift()
	_push_by_guards(delta)
	_sync_left -= delta
	if _sync_left <= 0.0:
		_sync_left = SYNC_EVERY
		_send_poses()


## Host: a thrown basketball dropping down through either rim is a basket.
func _watch_hoops() -> void:
	for i: int in _thrown_by.keys():
		var body := _bodies[i]
		var y := body.global_position.y
		var before: float = _ball_y.get(i, y)
		_ball_y[i] = y
		if body.sleeping:
			_thrown_by.erase(i)
			_ball_y.erase(i)
			continue
		if ITEMS[i]["name"] != "basketball" or not (before > RIM_HEIGHT and y <= RIM_HEIGHT) or body.linear_velocity.y > 0.0:
			continue
		for rim in rims():
			if Vector2(body.global_position.x - rim.x, body.global_position.z - rim.z).length() < RIM_CATCH:
				var peer: int = _thrown_by[i]
				_baskets[peer] = int(_baskets.get(peer, 0)) + 1
				_thrown_by.erase(i)
				get_tree().call_group("game", "on_basket", peer, int(_baskets[peer]), rim)
				_basket.rpc(rim)
				break


## Every computer: swish.
@rpc("authority", "call_local", "reliable")
func _basket(at: Vector3) -> void:
	var player := SoundBank.play_at(self, "swish", 0.0, 40.0, Sfx.thud(1.6, 0.08, 0.5))
	if player:
		player.global_position = at


## Where the gym's two rims are (see SchoolBuilder._hoop).
static func rims() -> Array[Vector3]:
	var found: Array[Vector3] = []
	for end: float in [-1.0, 1.0]:
		var baseline := SchoolBuilder.COURT_CENTRE.z + end * SchoolBuilder.COURT_HALF.y
		var inward := -end
		var face := baseline + inward * 1.22
		found.append(Vector3(SchoolBuilder.COURT_CENTRE.x, RIM_HEIGHT, face + inward * (0.15 + 0.2305)))
	return found


## Host: the shift's starting, so the basketballs go back where they were (they were for
## messing about with before it).
func _tidy_balls_for_shift() -> void:
	if shift == null or shift.state == _shift_state:
		return
	var starting := shift.state == Shift.State.ON_SHIFT and _shift_state == Shift.State.PRE_SHIFT
	_shift_state = shift.state
	if not starting:
		return
	_baskets.clear()
	for i in ITEMS.size():
		if ITEMS[i]["name"] == "basketball" and not i in carried.values():
			_place.rpc(i, _home(i), Engine.get_physics_frames(), true)
	for peer: int in carried.keys():
		if ITEMS[carried[peer]]["name"] == "basketball":
			var index: int = carried[peer]
			_set_carried.rpc(peer, -1)
			_place.rpc(index, _home(index), Engine.get_physics_frames(), true)


func _make_noise(at: Vector3) -> void:
	if director:
		director.make_noise(at, NOISE_SECONDS)


## Guards are on the school's own physics layer, so each item is told to ignore them (they
## shove things by walking into them instead, below).
func _pass_through_guards() -> void:
	if director == null or director.players == null:
		return
	for guard in director.players.get_children():
		if guard is PhysicsBody3D and not _excepted.has(guard.get_instance_id()):
			_excepted[guard.get_instance_id()] = true
			for body in _bodies:
				body.add_collision_exception_with(guard)


## Host: a living guard walking into a light thing pushes it ahead of them (a running one
## sends a ball flying).
func _push_by_guards(delta: float) -> void:
	if director == null:
		return
	var seen := {}
	for guard in director.living_guards():
		var at := guard.global_position
		# (By instance id: a guard who leaves is freed, and a freed key can't be read back.)
		var id := guard.get_instance_id()
		var last: Vector3 = _guard_steps.get(id, at)
		_guard_steps[id] = at
		seen[id] = true
		var step := (at - last) / maxf(delta, 0.001)
		step.y = 0.0
		if step.length() < 0.3 or step.length() > 12.0:
			continue
		for i in _bodies.size():
			var body := _bodies[i]
			if body.freeze or body.mass > PUSHABLE_MASS:
				continue
			var to := body.global_position - at
			if to.y < -0.2 or to.y > 1.2:
				continue
			to.y = 0.0
			var reach := 0.38 + _radius[i]
			if to.length() > reach:
				continue
			var away := to.normalized() if to.length() > 0.01 else step.normalized()
			var toward := step.dot(away)
			if toward <= 0.0:
				continue
			# At least as fast as the guard's coming on; balls more so, and off the floor a bit.
			var ball: bool = ITEMS[i].get("shape", "box") == "ball"
			var want := toward * (1.1 if ball else 1.05) + 0.2
			var moving := body.linear_velocity.dot(away)
			if moving >= want:
				continue
			body.sleeping = false
			body.linear_velocity += away * (want - moving)
			if ball:
				body.linear_velocity.y = maxf(body.linear_velocity.y, toward * 0.25)
			_last_velocity[i] = body.linear_velocity
	for id: int in _guard_steps.keys():
		if not seen.has(id):
			_guard_steps.erase(id)


## Host: where every moving thing is, to everyone. Things that have just come to rest get one
## last, reliable word, and then nothing until they move again.
func _send_poses() -> void:
	var indices := PackedInt32Array()
	var data := PackedFloat32Array()
	var frame := Engine.get_physics_frames()
	for i in _bodies.size():
		var body := _bodies[i]
		var moving := not body.freeze and not body.sleeping
		if moving:
			indices.append(i)
			var at := body.global_position
			var turn := body.global_basis.get_rotation_quaternion()
			data.append_array([at.x, at.y, at.z, turn.x, turn.y, turn.z, turn.w])
		elif _was_moving[i] and not body.freeze:
			_place.rpc(i, body.global_transform, frame, false)
		_was_moving[i] = moving
	if indices.is_empty() or not multiplayer.has_multiplayer_peer() or multiplayer.get_peers().is_empty():
		return
	# In packets small enough not to be split up on the way (losing a piece would lose the lot).
	for start in range(0, indices.size(), POSES_PER_PACKET):
		var end := mini(start + POSES_PER_PACKET, indices.size())
		_poses.rpc(frame, indices.slice(start, end), data.slice(start * 7, end * 7))


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_carried(peer: int, index: int) -> void:
	if index < 0:
		carried.erase(peer)
	else:
		carried[peer] = index
		_bodies[index].visible = false
		_props[index].collision_layer = 0
		_gliding.erase(index)
		_apply_role(index)
	carried_changed.emit()


## An item is put somewhere (dropped, thrown from a hand, sent home, or come to rest).
## `snap`: it jumps there at once, rather than gliding.
@rpc("authority", "call_local", "reliable")
func _place(index: int, at: Transform3D, frame: int, snap: bool) -> void:
	var body := _bodies[index]
	var was_hidden := not body.visible
	if not index in carried.values():
		body.visible = true
		_props[index].collision_layer = Interactable.TALK_LAYER
	_apply_role(index)
	if _simulating:
		body.global_transform = at
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		_last_velocity[index] = Vector3.ZERO
		_owes_noise[index] = false
		if snap:
			body.sleeping = true
			_was_moving[index] = false
		return
	if frame < _heard[index]:
		return
	_heard[index] = frame
	_goal[index] = at
	if snap or was_hidden or body.global_position.distance_to(at.origin) > 6.0:
		body.global_transform = at
		_gliding.erase(index)
	else:
		_gliding[index] = true


## Where the moving things are now (from the host): [x, y, z, quaternion x, y, z, w] each.
@rpc("authority", "call_remote", "unreliable_ordered")
func _poses(frame: int, indices: PackedInt32Array, data: PackedFloat32Array) -> void:
	for n in indices.size():
		var i := indices[n]
		if i < 0 or i >= _bodies.size() or frame < _heard[i] or data.size() < n * 7 + 7:
			continue
		_heard[i] = frame
		var turn := Quaternion(data[n * 7 + 3], data[n * 7 + 4], data[n * 7 + 5], data[n * 7 + 6]).normalized()
		_goal[i] = Transform3D(Basis(turn), Vector3(data[n * 7], data[n * 7 + 1], data[n * 7 + 2]))
		_gliding[i] = true


## Thump: something hit the floor (or a wall). `loudness` 0-1.
@rpc("authority", "call_local", "unreliable")
func _clatter(index: int, at: Vector3, loudness: float) -> void:
	var info: Dictionary = ITEMS[index]
	var sound: String = info.get("sound", ["land_wood", "land_metal", "land_plate", "land_soft"].pick_random())
	var player := SoundBank.play_at(self, sound, lerpf(-8.0, 6.0, loudness), 40.0, Sfx.thud(1.3, 0.12, 0.8))
	if player:
		player.global_position = at
	if loudness > 0.5:
		get_tree().call_group("captions", "heard", "Clutter", "landed", at)


## Everyone but the host: glide each item towards where the host last said it was.
func _process(delta: float) -> void:
	if _simulating or _gliding.is_empty():
		return
	var blend := 1.0 - exp(-14.0 * delta)
	for i: int in _gliding.keys():
		var body := _bodies[i]
		var goal := _goal[i]
		var now := body.global_transform
		var turn := now.basis.get_rotation_quaternion().slerp(goal.basis.get_rotation_quaternion(), blend)
		body.global_transform = Transform3D(Basis(turn), now.origin.lerp(goal.origin, blend))
		if body.global_position.distance_to(goal.origin) < 0.002:
			body.global_transform = goal
			_gliding.erase(i)


## The host simulates (unless the item's in someone's hands); everyone else just shows it.
func _apply_role(index: int) -> void:
	var body := _bodies[index]
	var held := index in carried.values()
	body.freeze = held or not _simulating
	body.collision_layer = 0 if held else PROP_LAYER
	body.collision_mask = 0 if held or not _simulating else 1 | PROP_LAYER


## Where an item starts the night.
func _home(index: int) -> Transform3D:
	var info: Dictionary = ITEMS[index]
	return Transform3D(Basis(Vector3.UP, float(info.get("turn", 0.0))), info["at"] + Vector3(0, info["size"].y * 0.5, 0))


func _build(index: int) -> void:
	var info: Dictionary = ITEMS[index]
	var body := RigidBody3D.new()
	body.name = "Clutter%d" % index
	body.mass = float(info.get("mass", 1.0))
	body.continuous_cd = true
	body.can_sleep = true
	var ball: bool = info.get("shape", "box") == "ball"
	var surface := PhysicsMaterial.new()
	surface.bounce = 0.55 if ball else 0.12
	surface.friction = 0.6 if ball else 0.8
	body.physics_material_override = surface
	body.linear_damp = 1.0 if ball else 0.1
	body.angular_damp = 1.5 if ball else 0.6
	add_child(body)
	body.global_transform = _home(index)
	var extent := _dress(body, info)
	# Simple shapes: a box, an upright cylinder for round things, or a ball.
	var shape := CollisionShape3D.new()
	match info.get("shape", "box"):
		"ball":
			var sphere := SphereShape3D.new()
			sphere.radius = extent.size.x * 0.5
			shape.shape = sphere
		"can", "cone":
			# A many-sided prism (or, for a cone, a stub of one) rests steadier than a cylinder.
			var top := 0.3 if info["shape"] == "cone" else 1.0
			shape.shape = _prism(maxf(extent.size.x, extent.size.z) * 0.5, extent.size.y, top)
		_:
			var box := BoxShape3D.new()
			box.size = extent.size
			shape.shape = box
	shape.position = extent.get_center()
	body.add_child(shape)
	_radius.append(maxf(extent.size.x, extent.size.z) * 0.5)
	# What E finds: on the talk layer, a little bigger than the thing, riding along inside it.
	var prop := Interactable.new()
	prop.name = "Grab"
	prop.prompt = "Pick up the %s" % info["name"]
	prop.collision_layer = Interactable.TALK_LAYER
	prop.collision_mask = 0
	var grab_shape := CollisionShape3D.new()
	var grab_box := BoxShape3D.new()
	grab_box.size = extent.size + Vector3(0.1, 0.1, 0.1)
	grab_shape.shape = grab_box
	grab_shape.position = extent.get_center()
	prop.add_child(grab_shape)
	body.add_child(prop)
	prop.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				request_pick_up(index)
			else:
				request_pick_up.rpc_id(1, index))
	_props.append(prop)
	_bodies.append(body)
	_last_velocity.append(Vector3.ZERO)
	_owes_noise.append(false)
	_clattered_at.append(-10.0)
	_was_moving.append(false)
	_still_for.append(0.0)
	_goal.append(body.global_transform)
	_heard.append(-1)
	_apply_role(index)
	body.sleeping = true


## An upright 12-sided prism `height` tall round its middle, its top `top` times as wide.
func _prism(radius: float, height: float, top: float) -> ConvexPolygonShape3D:
	var points := PackedVector3Array()
	for n in 12:
		var rim := Vector3(radius, 0, 0).rotated(Vector3.UP, TAU * n / 12.0)
		points.append(rim + Vector3(0, -height * 0.5, 0))
		points.append(rim * top + Vector3(0, height * 0.5, 0))
	var prism := ConvexPolygonShape3D.new()
	prism.points = points
	return prism


## How an item looks: its real model (feet at the bottom of its box), a ball, or a plain painted
## box for the odd things there's no model for. Returns the space it fills, around its middle.
func _dress(body: Node3D, info: Dictionary) -> AABB:
	var size: Vector3 = info["size"]
	var look: String = info.get("model", "")
	var fallback := AABB(-size * 0.5, size)
	if info.get("shape", "box") == "ball":
		var sphere := SphereMesh.new()
		sphere.radius = size.x * 0.5
		sphere.height = size.x
		var ball := MeshInstance3D.new()
		ball.mesh = sphere
		var skin := StandardMaterial3D.new()
		if info["name"] == "basketball":
			skin.albedo_texture = load("res://assets/textures/gym/basketball.png")
		else:
			skin.albedo_color = info.get("color", Color.WHITE)
		skin.roughness = 0.75
		ball.material_override = skin
		body.add_child(ball)
		return AABB(-Vector3.ONE * size.x * 0.5, Vector3.ONE * size.x)
	if look != "":
		var feet := Node3D.new()
		feet.position = Vector3(0, -size.y * 0.5, 0)
		body.add_child(feet)
		var model := ModelKit.add(feet, look, size.y, 0.0)
		if model != null:
			# The model's own footprint, so the collision fits what you see.
			var to_body := body.global_transform.affine_inverse()
			var bounds := AABB()
			var first := true
			for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
				var box := to_body * mesh.global_transform * mesh.get_aabb()
				bounds = box if first else bounds.merge(box)
				first = false
			return fallback if first or bounds.size.y < 0.01 else bounds
		feet.queue_free()
	var mesh := MeshInstance3D.new()
	if info.get("shape", "box") in ["can", "cone"]:
		var can := CylinderMesh.new()
		can.top_radius = maxf(size.x, size.z) * 0.5
		can.bottom_radius = can.top_radius
		can.height = size.y
		mesh.mesh = can
	else:
		mesh.mesh = Monster.box(size)
	var material := StandardMaterial3D.new()
	material.albedo_color = info.get("color", Color(0.5, 0.5, 0.5))
	mesh.material_override = material
	body.add_child(mesh)
	return fallback
