class_name Finale
extends Node3D
## The front gate, and the last night's last hour.
##
## All shift, every night, the gate is chained shut: nobody leaves early. At 5 AM on the final
## night of a run the intercom calls an assembly, the alarm goes, and every monster in the
## building hunts, a little faster as six gets closer. The gate's padlock key turns up somewhere
## deep in the school (the intercom says where). Someone has to fetch it and bring it to the
## gate; then the gate swings open, and a guard standing in the street is out of reach. Whoever
## carries the key and is caught drops it where they fell. Whoever's still inside at 6 AM stays
## inside. One guard out is enough to win the run.

const STARTS_AT := 300.0
const GATE_Z := 45.0
const GATE_HALF := 2.5
const GATE_H := 2.2
## Past this (south of the gate) a guard is out.
const OUT_Z := 45.6
## How close to the padlock the key has to come.
const UNLOCK_RANGE := 3.5
## How fast the hunt goes at 5 AM and by 6 AM (a walking guard does 3.2, running 5.6).
const HUNT_SPEED := Vector2(3.0, 3.8)
## Brought in for the finale, as well as whatever's already out tonight.
const EXTRAS := {"hall_monitor": Vector3(-36, 0, 7), "lunch_lady": Vector3(0, 0, -25)}
const OPEN_ANGLE := 1.92

signal key_changed

var director: MonsterDirector
var shift: Shift
var hud: CanvasLayer
var players: Node3D
var hiding: Hiding
## Host: whether tonight ends with the finale, and the difficulty (which wings the key can be in).
var planned := false
var difficulty := 1
## Every computer: the finale is on (the hunt), and whether the gate's been unlocked.
var active := false
var unlocked := false
## Every computer: where the key is ("the Gym"), and who's carrying it (peer id, or 0).
var key_area := ""
var key_holder := 0
## Host: peer -> the in-game minute they first got out through the gate.
var escaped_at: Dictionary = {}

var _leaves: Array[Node3D] = []
var _gate_open := true
var _swing: Tween
var _told_locked := 0.0
var _key: Interactable


func _ready() -> void:
	for side: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "GateLeaf%d" % (0 if side < 0.0 else 1)
		add_child(pivot)
		pivot.position = Vector3(side * GATE_HALF, 0, GATE_Z)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.position = Vector3(-side * GATE_HALF * 0.5, GATE_H * 0.5, 0)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(GATE_HALF, GATE_H, 0.12)
		shape.shape = box
		body.add_child(shape)
		var bars := StandardMaterial3D.new()
		bars.albedo_color = Color(0.35, 0.37, 0.38)
		bars.metallic = 0.5
		bars.roughness = 0.5
		# A frame and upright bars, so you can see through it.
		for y: float in [-GATE_H * 0.5 + 0.06, 0.0, GATE_H * 0.5 - 0.06]:
			_bar(body, Vector3(0, y, 0), Vector3(GATE_HALF, 0.06, 0.05), bars)
		var x := -GATE_HALF * 0.5 + 0.05
		while x <= GATE_HALF * 0.5:
			_bar(body, Vector3(x, 0, 0), Vector3(0.04, GATE_H, 0.04), bars)
			x += 0.25
		pivot.add_child(body)
		pivot.rotation.y = -side * OPEN_ANGLE
		_leaves.append(pivot)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.85, 0.68, 0.2)
	brass.metallic = 0.8
	brass.roughness = 0.3
	# The chain and padlock where the leaves meet: only there while it's shut.
	var chain := MeshInstance3D.new()
	chain.name = "Chain"
	chain.mesh = Monster.box(Vector3(0.12, 0.3, 0.16))
	chain.material_override = brass
	chain.position = Vector3(0, 1.1, GATE_Z - 0.05)
	chain.visible = false
	add_child(chain)
	# The key: hidden until the finale, then lying on the floor somewhere, glowing.
	_key = Interactable.new()
	_key.name = "GateKey"
	_key.prompt = "Take the gate key"
	_key.collision_layer = 0
	_key.visible = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.4, 0.5)
	shape.shape = box
	_key.add_child(shape)
	var ring := MeshInstance3D.new()
	ring.mesh = Monster.box(Vector3(0.12, 0.02, 0.12))
	ring.material_override = brass
	_key.add_child(ring)
	var shaft := MeshInstance3D.new()
	shaft.mesh = Monster.box(Vector3(0.03, 0.02, 0.2))
	shaft.material_override = brass
	shaft.position = Vector3(0, 0, 0.15)
	_key.add_child(shaft)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.35)
	glow.light_energy = 1.2
	glow.omni_range = 2.5
	glow.position = Vector3(0, 0.3, 0)
	_key.add_child(glow)
	add_child(_key)
	_key.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				request_take()
			else:
				request_take.rpc_id(1))


func _bar(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(size)
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)


## Is this spot out through the gate?
static func is_out(at: Vector3) -> bool:
	return at.z > OUT_Z


## "the Gym", but "Room 103".
static func the(area: String) -> String:
	return area if area.begins_with("Room") else "the " + area


## Is this spot inside the fence: the yard, the building or its wings?
static func on_grounds(at: Vector3) -> bool:
	if at.z > GATE_Z + 0.3 or at.z < -30.5 or absf(at.x) > 80.5:
		return false
	return absf(at.x) <= 40.5 or (at.z <= 20.5 and at.z >= -14.5)


## The line under the clock for this guard during the finale.
func objective_for(guard: Guard) -> String:
	if is_out(guard.global_position):
		return "You're out. Stay out here until 6 AM; the gate shuts at six."
	if unlocked:
		return "GET OUT. The front gate is open: get through it before 6 AM. Whoever's inside at six stays inside."
	if key_holder == guard.name.to_int():
		return "You have the gate key. Get it to the front gate before 6 AM. Everything is hunting you."
	if key_holder != 0:
		var holder := players.get_node_or_null(str(key_holder)) as Guard
		return "Guard %d has the gate key. Get to the front gate before 6 AM." % (holder.slot if holder else 0)
	return "The gate's padlock key is in %s. Fetch it and unlock the front gate before 6 AM." % the(key_area)


# --- Host --------------------------------------------------------------------------------

func update(minutes: float) -> void:
	if not planned:
		return
	if not active and minutes >= STARTS_AT:
		_begin()
	if not active:
		return
	# When each guard first got out (for the last-minute achievement).
	if unlocked:
		for guard in director.living_guards():
			if is_out(guard.global_position) and not escaped_at.has(guard.name.to_int()):
				escaped_at[guard.name.to_int()] = minutes
	director.hunt_speed = lerpf(HUNT_SPEED.x, HUNT_SPEED.y, clampf((minutes - STARTS_AT) / 60.0, 0.0, 1.0))
	if not unlocked and key_holder != 0:
		var holder := director.guard_by_peer(key_holder)
		if holder and not holder.is_dead and holder.global_position.distance_to(Vector3(0, holder.global_position.y, GATE_Z)) < UNLOCK_RANGE:
			_set_key.rpc("", 0, Vector3.ZERO, true)
			director.gate_open = true
			director.announcement.emit("The padlock drops. The front gate is OPEN. GET OUT.", "")


## Host: everyone still standing is out. The night can end now.
func everyone_out() -> bool:
	var living := director.living_guards()
	if not unlocked or living.is_empty():
		return false
	for guard in living:
		if not is_out(guard.global_position):
			return false
	return true


## Host, at 6 AM: the gate swings shut on anyone still inside. Returns the guards who got out.
func lock_in() -> Array[Guard]:
	var out: Array[Guard] = []
	if not active:
		return out
	# Nobody's dropping the key now: it's over.
	key_holder = 0
	for guard in director.living_guards():
		if unlocked and is_out(guard.global_position):
			out.append(guard)
		else:
			director.kill(guard, "the school")
	return out


@rpc("any_peer", "call_remote", "reliable")
func request_take() -> void:
	if not multiplayer.is_server() or not active or unlocked or key_holder != 0:
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead or guard.global_position.distance_to(_key.global_position) > 3.5:
		return
	_set_key.rpc(key_area, peer, _key.global_position, false)
	director.announcement.emit("Guard %d has the gate key." % guard.slot, "")


## Host: whoever had the key was caught (or left). It lies where they were: in front of their
## cupboard if they were hiding, and always somewhere a guard can walk to.
func drop(peer: int, at: Vector3, left := false) -> void:
	if not active or key_holder != peer or unlocked or shift.state != Shift.State.ON_SHIFT:
		return
	if hiding and hiding.hidden.has(peer):
		var spot: Dictionary = Hiding.SPOTS[hiding.hidden[peer]]
		at = spot["at"] + (spot["facing"] as Vector3) * 1.0
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		at = NavigationServer3D.map_get_closest_point(map, at)
	var area := SchoolBuilder.area_at(at)
	_set_key.rpc(area if area != "" else "guard room" if SchoolBuilder.AREAS["Guard Room"].has_point(at) else "yard", 0, Vector3(at.x, 0.05, at.z), false)
	director.announcement.emit("%s the gate key. It's lying in %s." % ["Whoever had it has gone, leaving" if left else "Whoever had it was caught. They dropped", the(key_area)], "")


func _begin() -> void:
	_set_active.rpc(true)
	director.start_finale()
	director.gate_open = false
	for kind: String in EXTRAS:
		director.spawn(kind, EXTRAS[kind])
	# The key: at one of the round stations, deep in the school (or out in tonight's wings).
	var spots: Array[Dictionary] = []
	for station: Dictionary in Rounds.STATIONS:
		if not station.get("post", false) and SchoolBuilder.AREA_DIFFICULTY.get(station["area"], 1) <= difficulty \
				and (station["at"].z < 0.0 or absf(station["at"].x) > 40.0):
			spots.append(station)
	# Overtime's finales go further: the key is as far from the gate as the open wings allow.
	if director.night_number > Night.LAST_NIGHT:
		spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return (a["at"] as Vector3).distance_to(Vector3(0, 0, GATE_Z)) > (b["at"] as Vector3).distance_to(Vector3(0, 0, GATE_Z)))
		spots = spots.slice(0, maxi(2, spots.size() / 3))
	var spot: Dictionary = spots.pick_random()
	var at: Vector3 = spot["at"] + (spot["facing"] as Vector3) * 0.8
	_set_key.rpc(spot["area"], 0, Vector3(at.x, 0.05, at.z), false)
	director.announcement.emit("Attention, all staff. Please make your way to the gym for this morning's assembly. Attendance is compulsory.", "intercom")
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if active:
			director.announcement.emit("Everything in the building is awake and coming. The front gate's padlock key is in %s: fetch it, unlock the gate and GET OUT before 6 AM. Whoever's inside at six stays inside." % the(key_area), ""))


## Host: a new night (or a new run). The gate's shut again.
func reset() -> void:
	planned = false
	escaped_at.clear()
	if active or unlocked or key_holder != 0 or key_area != "":
		_set_active.rpc(false)


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_active(on: bool) -> void:
	active = on
	if not on:
		unlocked = false
		key_holder = 0
		key_area = ""
		_key.visible = false
		_key.collision_layer = 0
		key_changed.emit()


@rpc("authority", "call_local", "reliable")
func _set_key(area: String, holder: int, at: Vector3, open_gate: bool) -> void:
	key_area = area
	key_holder = holder
	var lying := not open_gate and holder == 0
	_key.visible = lying
	_key.collision_layer = Interactable.TALK_LAYER if lying else 0
	if lying:
		_key.global_position = at
	if open_gate and not unlocked:
		unlocked = true
		SoundBank.play_at(_leaves[0], "gate", 6.0, 60.0, Sfx.notes([140.0, 120.0, 95.0], 0.25, 0.6, "square"))
	key_changed.emit()


func _process(delta: float) -> void:
	var should_open := shift == null or shift.state != Shift.State.ON_SHIFT or unlocked
	if should_open != _gate_open:
		_gate_open = should_open
		if _swing:
			_swing.kill()
		_swing = create_tween().set_parallel()
		for i in _leaves.size():
			var side := -1.0 if i == 0 else 1.0
			_swing.tween_property(_leaves[i], "rotation:y", -side * OPEN_ANGLE if should_open else 0.0, 1.5 if should_open else 0.6)
		get_node("Chain").visible = not should_open
	if _key.visible:
		_key.rotation.y += delta * 1.5
	# The gate's shut: anyone who somehow ended up off the grounds is back in the yard.
	_told_locked -= delta
	if _gate_open or players == null:
		return
	for guard: Guard in players.get_children():
		if guard.is_local() and not guard.is_dead and not guard.hiding and not on_grounds(guard.global_position):
			guard.global_position = Vector3((guard.slot - 2.5) * 1.4, 0.1, GATE_Z - 4.0)
			guard.velocity = Vector3.ZERO
			if _told_locked <= 0.0 and hud:
				_told_locked = 5.0
				hud.show_message("The gate's chained shut until morning.", 3.0)
