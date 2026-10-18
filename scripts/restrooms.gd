class_name Restrooms
extends Node3D
## The boys' and girls' restrooms off the main hall: taps that run, toilets that flush and stall
## doors that swing. E on a sink turns its tap on or off (it runs until someone turns it off), E on
## a toilet or urinal flushes it, and E on a stall door opens or shuts it. A flush is loud enough
## for the monsters that hunt by sound to come and look. Monsters shove shut stall doors open as
## they pass.
##
## And now and then, with nobody in sight of it, a toilet flushes by itself, a tap comes on, or a
## stall door slams (Haunting decides when and asks us). The host keeps the taps and doors and
## tells everyone.
##
## SchoolBuilder builds the rooms and the fixtures in them; this node hangs the stall doors and
## makes things work. It lives beside the school, not in it, so the navigation mesh is baked as if
## the stall doors were open.

## Seconds before a toilet can be flushed again (the cistern refilling).
const REFILL_SECONDS := 5.0
## How long the monsters that hunt by sound go on hearing a flush.
const FLUSH_NOISE_SECONDS := 2.0
const OPEN_DEGREES := 85.0
const SWING_SECONDS := 0.35
## A monster this close to a shut stall door pushes it open.
const MONSTER_REACH := 1.0
## Stall doors propped open as the crew arrives each night (the rest are shut).
const OPEN_AT_START := [0, 2, 4]
const DOOR_HEIGHT := 1.7
const DOOR_BOTTOM := 0.32

var school: SchoolBuilder

## Every toilet and urinal (SchoolBuilder's), and when each can next be flushed (host).
var _flushers: Array[Interactable] = []
var _refilled_at: Array[float] = []
## Each sink: {"body", "water" (the stream from the tap), "sound" (its loop, or null)}.
var _sinks: Array[Dictionary] = []
var _running: Array[bool] = []
## Each stall door: {"hinge" (Node3D), "leaf" (Interactable)}.
var _stalls: Array[Dictionary] = []
var _open: Array[bool] = []
var _water_material: StandardMaterial3D
var _monster_check := 0.0


## Every computer, as the school is built: hangs the stall doors and hooks up the fixtures.
func build(builder: SchoolBuilder) -> void:
	school = builder
	name = "Restrooms"
	for i in builder.flushers.size():
		var body := builder.flushers[i]
		_flushers.append(body)
		_refilled_at.append(0.0)
		body.used.connect(_on_flush_used.bind(i))
	for i in builder.sinks.size():
		var info: Dictionary = builder.sinks[i]
		var body: Interactable = info["body"]
		body.prompt = "Turn the tap on"
		body.used.connect(_on_tap_used.bind(i))
		_sinks.append({"body": body, "water": _water(info["spout"], info["basin"]), "sound": null})
		_running.append(false)
	for i in builder.stalls.size():
		_hang_stall_door(builder.stalls[i], i)
		_open.append(false)
		_show_stall(i, i in OPEN_AT_START, false)


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)


## A thin trickle from the tap to the basin, shown while the tap runs.
func _water(spout: Vector3, basin: Vector3) -> MeshInstance3D:
	if _water_material == null:
		_water_material = StandardMaterial3D.new()
		_water_material.albedo_color = Color(0.75, 0.85, 0.95, 0.45)
		_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_water_material.roughness = 0.05
		_water_material.emission_enabled = true
		_water_material.emission = Color(0.2, 0.25, 0.3)
	var stream := CylinderMesh.new()
	stream.top_radius = 0.006
	stream.bottom_radius = 0.009
	stream.height = maxf(spout.y - basin.y, 0.05)
	stream.radial_segments = 6
	stream.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = stream
	mesh.material_override = _water_material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.position = Vector3(spout.x, (spout.y + basin.y) * 0.5, spout.z)
	mesh.visible = false
	add_child(mesh)
	return mesh


## A stall door: a painted steel leaf hinged on the left of the opening, swinging into the stall.
func _hang_stall_door(info: Dictionary, index: int) -> void:
	var width: float = info["width"]
	var hinge := Node3D.new()
	hinge.position = info["hinge"]
	add_child(hinge)
	var leaf := Interactable.new()
	leaf.prompt = "Open the stall door"
	leaf.position = Vector3(width * 0.5, DOOR_BOTTOM + DOOR_HEIGHT * 0.5, 0)
	var size := Vector3(width - 0.02, DOOR_HEIGHT, 0.025)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	leaf.add_child(collider)
	var panel := BoxMesh.new()
	panel.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = panel
	mesh.material_override = school.get_material("stall")
	leaf.add_child(mesh)
	# The latch, on the side away from the hinge.
	var latch := BoxMesh.new()
	latch.size = Vector3(0.06, 0.03, 0.05)
	var latch_mesh := MeshInstance3D.new()
	latch_mesh.mesh = latch
	latch_mesh.material_override = school.get_material("steel")
	latch_mesh.position = Vector3(width * 0.5 - 0.08, 0.05, 0)
	latch_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leaf.add_child(latch_mesh)
	for part: MeshInstance3D in [mesh, latch_mesh]:
		part.visibility_range_end = 30.0
	leaf.used.connect(_on_stall_used.bind(index))
	hinge.add_child(leaf)
	_stalls.append({"hinge": hinge, "leaf": leaf})


# --- Guards using them ------------------------------------------------------------------------

func _local_guard(by: Node) -> bool:
	var guard := by as Guard
	return guard != null and guard.is_local() and not guard.is_dead


func _on_flush_used(by: Node, index: int) -> void:
	if not _local_guard(by):
		return
	if multiplayer.is_server():
		_request_flush(index)
	else:
		_request_flush.rpc_id(1, index)


func _on_tap_used(by: Node, index: int) -> void:
	if not _local_guard(by):
		return
	if multiplayer.is_server():
		_request_tap(index)
	else:
		_request_tap.rpc_id(1, index)


func _on_stall_used(by: Node, index: int) -> void:
	if not _local_guard(by):
		return
	if multiplayer.is_server():
		_request_stall(index)
	else:
		_request_stall.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_flush(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _flushers.size():
		return
	if not _flush_ready(index) or not _sender_can_reach(_flushers[index].global_position):
		return
	_refilled_at[index] = _now() + REFILL_SECONDS
	_flush.rpc(index, false)
	var director := _director()
	if director:
		director.make_noise(_flushers[index].global_position, FLUSH_NOISE_SECONDS)


@rpc("any_peer", "call_remote", "reliable")
func _request_tap(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _sinks.size() or not _sender_can_reach((_sinks[index]["body"] as Node3D).global_position):
		return
	_set_tap.rpc(index, not _running[index], false)


@rpc("any_peer", "call_remote", "reliable")
func _request_stall(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _stalls.size() or not _sender_can_reach((_stalls[index]["hinge"] as Node3D).global_position):
		return
	_set_stall.rpc(index, not _open[index], false)


## Host: is whoever asked alive and standing by it? (Their own computer checks too; this is
## so a ghost, or someone across the school, can't.)
func _sender_can_reach(at: Vector3) -> bool:
	var director := _director()
	if director == null:
		return true
	var peer := multiplayer.get_remote_sender_id()
	var guard := director.guard_by_peer(peer if peer != 0 else multiplayer.get_unique_id())
	return guard != null and not guard.is_dead and guard.global_position.distance_to(at) < 4.0


func _flush_ready(index: int) -> bool:
	return _now() >= _refilled_at[index]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _director() -> MonsterDirector:
	var game := get_tree().get_first_node_in_group("game") if is_inside_tree() else null
	return game.get("director") as MonsterDirector if game else null


# --- Every computer: showing it ---------------------------------------------------------------

## A toilet or urinal flushing. `haunted`: nobody touched it.
@rpc("authority", "call_local", "reliable")
func _flush(index: int, haunted: bool) -> void:
	if index < 0 or index >= _flushers.size():
		return
	var body := _flushers[index]
	SoundBank.play_at(body, "toilet_flush", 0.0, 26.0, Sfx.notes([1.0, 1.0, 1.0, 1.0, 1.0, 0.0], 0.5, 0.15, "noise"))
	get_tree().call_group("captions", "heard", "Haunt" if haunted else "Fixture", "flush", body.global_position)


@rpc("authority", "call_local", "reliable")
func _set_tap(index: int, on: bool, haunted: bool) -> void:
	if index < 0 or index >= _sinks.size() or _running[index] == on:
		return
	_running[index] = on
	var sink := _sinks[index]
	var body: Interactable = sink["body"]
	(sink["water"] as MeshInstance3D).visible = on
	body.prompt = "Turn the tap off" if on else "Turn the tap on"
	var old := sink["sound"] as AudioStreamPlayer3D
	if old:
		old.queue_free()
		sink["sound"] = null
	# The handle squeaks either way.
	SoundBank.play_at(body, "metal_click", -10.0, 12.0, Sfx.notes([1400.0, 1700.0], 0.03, 0.08, "square"))
	if on:
		var loop := Sfx.play_at(body, SoundBank.get_sound("tap_water",
				Sfx.notes([1.0, 1.0, 1.0, 1.0], 0.5, 0.05, "noise", true), true), -6.0, 16.0)
		loop.unit_size = 2.5
		sink["sound"] = loop
		get_tree().call_group("captions", "heard", "Haunt" if haunted else "Fixture", "tap", body.global_position)


@rpc("authority", "call_local", "reliable")
func _set_stall(index: int, open: bool, slam: bool) -> void:
	if index < 0 or index >= _stalls.size():
		return
	_show_stall(index, open, true, slam)


## Shows a stall door open or shut (`animate`: swinging there, with a sound).
func _show_stall(index: int, open: bool, animate: bool, slam := false) -> void:
	var was: bool = _open[index]
	_open[index] = open
	var stall := _stalls[index]
	var hinge: Node3D = stall["hinge"]
	(stall["leaf"] as Interactable).prompt = "Shut the stall door" if open else "Open the stall door"
	var yaw := -deg_to_rad(OPEN_DEGREES) if open else 0.0
	if not animate:
		hinge.rotation.y = yaw
		return
	var swing := hinge.create_tween()
	swing.tween_property(hinge, "rotation:y", yaw, SWING_SECONDS * (0.45 if slam else 1.0)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN if slam else Tween.EASE_IN_OUT)
	if slam:
		# Shut hard: a bang, and the leaf jolts back a touch.
		swing.tween_callback(func() -> void:
			SoundBank.play_at(stall["leaf"], "door_bang", 0.0, 32.0, Sfx.thud(0.9, 0.12, 0.7)))
		swing.tween_property(hinge, "rotation:y", -0.06, 0.06)
		swing.tween_property(hinge, "rotation:y", 0.0, 0.1)
		# Only ever a haunting: nobody slams a stall door.
		get_tree().call_group("captions", "heard", "Haunt", "stall", (stall["leaf"] as Node3D).global_position)
	elif was != open:
		SoundBank.play_at(stall["leaf"], "creak", -10.0, 16.0, Sfx.creak(0.4, 0.15))
		if not open:
			swing.tween_callback(func() -> void:
				SoundBank.play_at(stall["leaf"], "metal_click", -6.0, 14.0, Sfx.thud(1.6, 0.05, 0.4)))


## A shut stall door rattling hard in its frame, nobody near it.
@rpc("authority", "call_local", "reliable")
func _rattle(index: int) -> void:
	if index < 0 or index >= _stalls.size():
		return
	var hinge: Node3D = _stalls[index]["hinge"]
	var shake := hinge.create_tween()
	for i in 4:
		shake.tween_property(hinge, "rotation:y", -0.05 if i % 2 == 0 else 0.0, 0.07)
	SoundBank.play_at(_stalls[index]["leaf"], "door_bang", -4.0, 30.0, Sfx.thud(1.1, 0.1, 0.6))
	get_tree().call_group("captions", "heard", "Haunt", "stall", (_stalls[index]["leaf"] as Node3D).global_position)


# --- Host: monsters, hauntings, mornings and late joiners ------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():
		return
	_monster_check -= delta
	if _monster_check > 0.0:
		return
	_monster_check = 0.2
	var director := _director()
	if director == null:
		return
	var live := director.get_node_or_null("Live")
	if live == null:
		return
	for node in live.get_children():
		var monster := node as Monster
		# The Ghost drifts through doors; nothing else stops for a stall door.
		if monster == null or monster is SchoolGhost or monster.is_queued_for_deletion():
			continue
		for i in _stalls.size():
			if _open[i]:
				continue
			var leaf: Node3D = _stalls[i]["leaf"]
			var to := leaf.global_position - monster.global_position
			if Vector2(to.x, to.z).length() < MONSTER_REACH:
				_set_stall.rpc(i, true, false)


## Host, for Haunting: where each event of this kind could happen (Vector3.INF where it can't
## right now), indexed as `haunt` takes them.
func haunt_spots(kind: String) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	match kind:
		"flush":
			for i in _flushers.size():
				spots.append(_flushers[i].global_position if _flush_ready(i) else Vector3.INF)
		"tap":
			for i in _sinks.size():
				spots.append(Vector3.INF if _running[i] else (_sinks[i]["body"] as Node3D).global_position)
		"stall":
			for stall in _stalls:
				spots.append((stall["leaf"] as Node3D).global_position)
	return spots


## Host, for Haunting: nobody's there, but a toilet flushes, a tap comes on, or a stall door
## slams (an open one bangs shut; a shut one rattles hard).
func haunt(kind: String, index: int) -> void:
	match kind:
		"flush":
			if index >= 0 and index < _flushers.size():
				_refilled_at[index] = _now() + REFILL_SECONDS
				_flush.rpc(index, true)
		"tap":
			if index >= 0 and index < _sinks.size():
				_set_tap.rpc(index, true, true)
		"stall":
			if index < 0 or index >= _stalls.size():
				return
			if _open[index]:
				_set_stall.rpc(index, false, true)
			else:
				_rattle.rpc(index)


## Host, as a shift ends: the taps are turned off and the stall doors put back for the next night.
func settle() -> void:
	if not multiplayer.is_server():
		return
	for i in _sinks.size():
		if _running[i]:
			_set_tap.rpc(i, false, false)
	for i in _stalls.size():
		if _open[i] != (i in OPEN_AT_START):
			_set_stall.rpc(i, i in OPEN_AT_START, false)


## Host: someone joined; once their school is up, show them the taps and doors as they are.
func _on_peer_connected(peer: int) -> void:
	if not multiplayer.is_server():
		return
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if multiplayer.has_multiplayer_peer() and peer in multiplayer.get_peers():
			_sync.rpc_id(peer, _running, _open))


@rpc("authority", "call_remote", "reliable")
func _sync(running: Array, open: Array) -> void:
	for i in mini(running.size(), _sinks.size()):
		if bool(running[i]) != _running[i]:
			_set_tap(i, bool(running[i]), false)
	for i in mini(open.size(), _stalls.size()):
		if bool(open[i]) != _open[i]:
			_show_stall(i, bool(open[i]), false)
