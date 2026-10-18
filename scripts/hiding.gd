class_name Hiding
extends Node3D
## Hiding places: slatted cupboards around the school. Press E on one to climb in, E again to
## climb out. Inside, monsters can't find you: whatever was after you loses you.
##
## Unless it still had you in view (or only just lost you). Then it comes to the doors and
## searches: a few seconds of rattling and creaking, the slats shaking on every computer. It
## only finds you if you give yourself away: talking (or any noise on voice chat), nerve almost
## gone, or getting in right under its nose. Hold still and keep quiet and it gives up.
## (Which monsters search is up to each one: see Monster.searches_cupboards.) Never in a
## lockdown: hiding is the way out of one.
##
## The host decides who's hiding where and tells everyone; the guard's own computer moves them
## in and out and shows the view through the slats.

## Each cupboard: where it stands and which way its doors face.
const SPOTS := [
	{"at": Vector3(-38.9, 0, 9.2), "facing": Vector3(1, 0, 0), "area": "Main Hall West"},
	{"at": Vector3(38.9, 0, 9.2), "facing": Vector3(-1, 0, 0), "area": "Main Hall East"},
	{"at": Vector3(-39.2, 0, -20.0), "facing": Vector3(1, 0, 0), "area": "Cafeteria"},
	{"at": Vector3(-4.37, 0, -14.0), "facing": Vector3(1, 0, 0), "area": "Kitchen"},
	{"at": Vector3(6.0, 0, -29.2), "facing": Vector3(0, 0, 1), "area": "Gym"},
	{"at": Vector3(-6.7, 0, 19.2), "facing": Vector3(0, 0, -1), "area": "Front Office"},
	{"at": Vector3(-79.2, 0, 1.0), "facing": Vector3(1, 0, 0), "area": "Library"},
	{"at": Vector3(-41.0, 0, 19.2), "facing": Vector3(0, 0, -1), "area": "Room 101"},
	{"at": Vector3(-57.0, 0, -13.2), "facing": Vector3(0, 0, 1), "area": "Room 103"},
	{"at": Vector3(41.0, 0, -13.2), "facing": Vector3(0, 0, 1), "area": "Science Lab"},
	{"at": Vector3(79.2, 0, 15.0), "facing": Vector3(-1, 0, 0), "area": "Locker Rooms"},
	{"at": Vector3(79.2, 0, -10.0), "facing": Vector3(-1, 0, 0), "area": "Art Room"},
	{"at": Vector3(19.2, 0, 11.0), "facing": Vector3(-1, 0, 0), "area": "Guard Room"},
	{"at": Vector3(39.2, 0, 18.6), "facing": Vector3(-1, 0, 0), "area": "Music Room"},
]
## A monster this close that sees you climb in saw exactly where you went: it searches, and it
## pulls you out.
const SEEN_CLOSE := 4.0
## Nerve below this and you can't keep still in there: a search finds you.
const SHAKY_NERVE := 20.0
## Any sound on voice chat louder than this, mid-search, gives you away.
const VOICE_GIVES_AWAY := 0.05
## How far from the doors a searching monster stands.
const SEARCH_STAND := 1.3
## The hider's view shaking while their doors rattle (much less with Profile.reduce_flashing).
const SHAKE := 0.014
const GENTLE_SHAKE := 0.003

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
## Each cupboard's base node and its doors' slats (a mesh of their own, so they can shake).
var _holders: Array[Node3D] = []
var _door_meshes: Array[MeshInstance3D] = []
## Host: peer -> true when a monster saw them climb in from close up (cleared when they're out).
var _seen_close: Dictionary = {}
## Cupboards being searched right now -> real seconds to the next rattle sound. Every computer.
var _rattling: Dictionary = {}
var _heartbeat: AudioStreamPlayer
var _shaking := false


func _ready() -> void:
	for i in SPOTS.size():
		_build_cupboard(i)
	_slats = _make_slats()
	if director:
		director.hiding = self
	_heartbeat = AudioStreamPlayer.new()
	_heartbeat.stream = SoundBank.get_sound("heartbeat", Sfx.thud(0.55, 0.16, 0.9), true)
	_heartbeat.volume_db = -3.0
	add_child(_heartbeat)


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
	var close_by := _watcher(guard)
	_set_hidden.rpc(peer, spot)
	if close_by:
		# It watched them get in from right there: it comes to the doors, and it knows.
		_seen_close[peer] = true
		close_by.begin_search(guard)


## A searching monster that saw this guard climb in from close up, or null. (One chasing them
## from further off searches anyway, when it notices they've gone: see Monster.chase.)
func _watcher(guard: Guard) -> Monster:
	if director.lockdown_left > 0.0:
		return null
	for monster in director.active_monsters():
		# (Not a harmless one, or one still in disguise: they haven't shown themselves yet.)
		if monster.searches_cupboards and not monster.is_searching() and not monster.harmless and not monster.disguised() \
				and monster.global_position.distance_to(guard.global_position) < SEEN_CLOSE \
				and director.can_see(monster.eye_position(), guard):
			return monster
	return null


## Where a monster stands to search this cupboard.
func front_of(spot: int) -> Vector3:
	return SPOTS[spot]["at"] + SPOTS[spot]["facing"] * SEARCH_STAND


## The middle of this cupboard's doors, for a searching monster to face.
func door_of(spot: int) -> Vector3:
	return SPOTS[spot]["at"] + SPOTS[spot]["facing"] * 0.5 + Vector3(0, 1.0, 0)


## Host, mid-search: has this guard given themselves away? Talking (any sound on voice chat),
## nerve nearly gone, or seen getting in from close up. Keeping still and quiet never does.
func gives_away(guard: Guard) -> bool:
	var peer := guard.name.to_int()
	if _seen_close.get(peer, false):
		return true
	if director.voice_level(guard) > VOICE_GIVES_AWAY:
		return true
	return director.nerve != null and float(director.nerve.levels.get(peer, Nerve.MAX)) < SHAKY_NERVE


## Host: a monster has reached the doors and starts searching.
func start_search(spot: int, _by: Monster) -> void:
	_set_rattling.rpc(spot, true)
	for peer: int in hidden:
		if hidden[peer] == spot:
			director.tell(peer, "Something's at the doors. Don't move. Don't make a sound.")


## Host: the search is over. Not `caught`: it gave up and the guard inside hears it go.
func stop_search(spot: int, caught: bool) -> void:
	_set_rattling.rpc(spot, false)
	if caught:
		return
	for peer: int in hidden:
		if hidden[peer] == spot:
			director.tell(peer, "The rattling stops. Footsteps, going away.")
			get_tree().call_group("game", "on_award", peer, "STILL_AS_STONE")


## Host: it found them. Out they come.
func pull_out(guard: Guard, by: Monster) -> void:
	var peer := guard.name.to_int()
	_set_hidden.rpc(peer, -1)
	director.kill(guard, by.display_name, by.face_point())


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
		_seen_close.erase(peer)
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
	# The slats are a mesh of their own, so they can rattle when something searches the cupboard.
	var slat_tool := SurfaceTool.new()
	slat_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for slat in 9:
		slat_tool.append_from(Monster.box(Vector3(1.05, 0.1, 0.04)), 0,
				Transform3D(Basis(), Vector3(0, -0.9 + slat * 0.225, 0)))
	holder.add_child(door)
	var cupboard := MeshInstance3D.new()
	cupboard.mesh = shape_tool.commit()
	cupboard.material_override = metal
	cupboard.visibility_range_end = 40.0
	holder.add_child(cupboard)
	var slats := MeshInstance3D.new()
	slats.mesh = slat_tool.commit()
	slats.material_override = metal
	slats.visibility_range_end = 40.0
	slats.position = door.position
	holder.add_child(slats)
	_holders.append(holder)
	_door_meshes.append(slats)
	door.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				_request(index)
			else:
				_request.rpc_id(1, index))
	_doors.append(door)


# --- Searches, on every computer ----------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_rattling(spot: int, on: bool) -> void:
	if spot < 0 or spot >= _holders.size():
		return
	if on:
		_rattling[spot] = 0.0
		SoundBank.play_at(_holders[spot], "slam_metal", 0.0, 30.0, Sfx.thud(0.7, 0.12, 0.6))
		get_tree().call_group("captions", "heard", "Hiding", "search", _holders[spot].global_position)
	else:
		_rattling.erase(spot)
		_door_meshes[spot].position = Vector3(0, 1.05, 0.5)
		_door_meshes[spot].rotation = Vector3.ZERO


func _process(delta: float) -> void:
	if multiplayer.is_server() and not _rattling.is_empty():
		_check_searches()
	for spot: int in _rattling.keys():
		var slats := _door_meshes[spot]
		slats.position = Vector3(0, 1.05, 0.5) + Vector3(randf_range(-0.015, 0.015), randf_range(-0.01, 0.01), randf_range(-0.03, 0.02))
		slats.rotation = Vector3(0, randf_range(-0.03, 0.03), randf_range(-0.012, 0.012))
		_rattling[spot] = float(_rattling[spot]) - delta
		if float(_rattling[spot]) <= 0.0:
			_rattling[spot] = randf_range(0.35, 0.8)
			var sound: String = ["creak", "creak", "latch", "metal_click", "door_bang"].pick_random()
			SoundBank.play_at(_holders[spot], sound, -1.0 if sound == "door_bang" else 1.0, 25.0, Sfx.creak(0.4, 0.25))
	_shake_hider()


## Host: stops the rattling at any cupboard nothing is searching any more (say, the monster was
## sent away mid-search).
func _check_searches() -> void:
	for spot: int in _rattling.keys():
		var searched := false
		for node in director.get_node("Live").get_children():
			var monster := node as Monster
			if monster and monster._search_spot == spot and monster._search_rattled >= 0.0 and not monster.is_queued_for_deletion():
				searched = true
		if not searched:
			_set_rattling.rpc(spot, false)


## The guard inside the cupboard being searched: the view jolts with the doors and their heart
## pounds. Just on their own computer.
func _shake_hider() -> void:
	var me := players.get_node_or_null(str(multiplayer.get_unique_id())) as Guard if players else null
	var searched := me != null and not me.is_dead and _rattling.has(int(hidden.get(multiplayer.get_unique_id(), -1)))
	if searched:
		var profile := get_node_or_null("/root/Profile")
		var strength := GENTLE_SHAKE if profile != null and profile.get("reduce_flashing") == true else SHAKE
		me.camera.h_offset = randf_range(-strength, strength)
		me.camera.v_offset = randf_range(-strength, strength)
		_shaking = true
		if not _heartbeat.playing:
			_heartbeat.play()
	elif _shaking:
		_shaking = false
		_heartbeat.stop()
		if me != null:
			me.camera.h_offset = 0.0
			me.camera.v_offset = 0.0


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
