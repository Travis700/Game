class_name Rounds
extends Node3D
## Watchman rounds: punch-clock stations on the walls around the school. Each night the host
## writes a work order of stations to punch before 6 AM, and their lamps glow amber.
##
## Hold E at a station to punch it. That pays the guard who punched it, but the station's bell
## rings out, and anything close enough hears it. Finish the whole round and everyone who clocks
## out gets a bonus; every station still unpunched at 6 AM is docked from everyone's pay.
## The host runs it; every computer shows the lamps and the HUD list.

const PUNCH_POINTS := 20
const ROUND_BONUS := 50
const MISSED_PENALTY := 10
const HOLD_SECONDS := 1.5
## How loud the bell is to monsters, as if the guard who punched it had shouted (0-1).
const BELL_LOUDNESS := 0.8
## Each station: its area, where it hangs, and which way it faces (out from the wall).
const STATIONS := [
	{"area": "Front Gate", "at": Vector3(4.0, 1.3, 42.0), "facing": Vector3(0, 0, -1), "post": true},
	{"area": "Front Office", "at": Vector3(-19.8, 1.4, 13.5), "facing": Vector3(1, 0, 0)},
	{"area": "Main Hall West", "at": Vector3(-28.0, 1.4, 9.3), "facing": Vector3(0, 0, -1)},
	{"area": "Main Hall East", "at": Vector3(28.0, 1.4, 9.3), "facing": Vector3(0, 0, -1)},
	{"area": "Cafeteria", "at": Vector3(-39.8, 1.4, -12.0), "facing": Vector3(1, 0, 0)},
	{"area": "Kitchen", "at": Vector3(4.8, 1.4, -26.0), "facing": Vector3(-1, 0, 0)},
	{"area": "Gym", "at": Vector3(12.0, 1.4, -29.8), "facing": Vector3(0, 0, 1)},
	{"area": "West Hall", "at": Vector3(-79.8, 1.4, 7.0), "facing": Vector3(1, 0, 0)},
	{"area": "Library", "at": Vector3(-79.8, 1.4, -12.0), "facing": Vector3(1, 0, 0)},
	{"area": "Nurse's Office", "at": Vector3(-79.8, 1.4, 11.0), "facing": Vector3(1, 0, 0)},
	{"area": "Room 103", "at": Vector3(-57.8, 1.4, -3.0), "facing": Vector3(1, 0, 0)},
	{"area": "East Hall", "at": Vector3(79.8, 1.4, 7.0), "facing": Vector3(-1, 0, 0)},
	{"area": "Science Lab", "at": Vector3(61.8, 1.4, 1.5), "facing": Vector3(-1, 0, 0)},
	{"area": "Art Room", "at": Vector3(79.8, 1.4, -2.0), "facing": Vector3(-1, 0, 0)},
	{"area": "Locker Rooms", "at": Vector3(45.0, 1.4, 19.8), "facing": Vector3(0, 0, -1)},
]
const LAMP_OFF := Color(0.08, 0.08, 0.08)
const LAMP_TODO := Color(1.0, 0.6, 0.1)
const LAMP_DONE := Color(0.2, 1.0, 0.35)

var director: MonsterDirector
var conditions: Conditions
var career: Career

## Tonight's work order (station indices), and the ones punched so far. On every computer.
var order: Array[int] = []
var punched: Array[int] = []
## False once it's 6 AM (or before the night starts): stations can't be punched.
var open := false
## Host: how many stations each guard punched tonight, by peer id.
var punches: Dictionary = {}

var _stations: Array[Interactable] = []
var _lamps: Array[StandardMaterial3D] = []
var _glows: Array[OmniLight3D] = []


func _ready() -> void:
	for i in STATIONS.size():
		_build_station(i)
	_show()


# --- Host --------------------------------------------------------------------------------

## The night is starting: writes tonight's work order from the stations in open areas.
func plan(night_number: int, difficulty: int) -> void:
	var candidates: Array[int] = []
	for i in STATIONS.size():
		if SchoolBuilder.AREA_DIFFICULTY.get(STATIONS[i]["area"], 1) <= difficulty:
			candidates.append(i)
	candidates.shuffle()
	var count := 3 + int((night_number - 1) / 2.0) + (3 if conditions and conditions.has("inspector") else 0)
	count = mini(count, candidates.size())
	var picked := candidates.slice(0, count)
	picked.sort()
	punches.clear()
	_set_state.rpc(PackedInt32Array(picked), PackedInt32Array(), true)


## 6 AM, or the night ended early: no more punching.
func close() -> void:
	if open:
		_set_state.rpc(PackedInt32Array(order), PackedInt32Array(punched), false)


## Clears the work order (between nights).
func clear() -> void:
	punches.clear()
	_set_state.rpc(PackedInt32Array(), PackedInt32Array(), false)


## Pay per punch: double when the inspector is visiting.
func punch_points() -> int:
	return PUNCH_POINTS * (2 if conditions and conditions.has("inspector") else 1)


func missed_count() -> int:
	return order.size() - punched.size()


func is_complete() -> bool:
	return not order.is_empty() and missed_count() == 0


## Host: tonight's rounds pay for one guard.
func pay_for(peer_id: int, clocked_out: bool) -> int:
	var pay: int = punches.get(peer_id, 0) * punch_points() - missed_count() * MISSED_PENALTY
	if clocked_out and is_complete():
		pay += ROUND_BONUS
	return pay


@rpc("any_peer", "call_remote", "reliable")
func _request_punch(index: int) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead or index < 0 or index >= STATIONS.size():
		return
	if guard.global_position.distance_to(STATIONS[index]["at"]) > 4.0:
		return
	if not open or index not in order:
		director.tell(peer, "This station isn't on tonight's round.")
		return
	if index in punched:
		director.tell(peer, "Already punched tonight.")
		return
	var now_punched := punched.duplicate()
	now_punched.append(index)
	punches[peer] = punches.get(peer, 0) + 1
	# The bell carries: anything that listens for loud voices hears it.
	director.report_voice(peer, BELL_LOUDNESS)
	_set_state.rpc(PackedInt32Array(order), PackedInt32Array(now_punched), true)
	_rang.rpc(index)
	if career:
		career.add_stat(peer, "stations_punched")
	var left := order.size() - now_punched.size()
	if left == 0:
		for living in director.living_guards():
			director.tell(living.name.to_int(), "Round complete: every station is punched. Bonus +%d each at clock-out." % ROUND_BONUS)
			if career:
				career.award(living.name.to_int(), "FULL_ROUND")
	else:
		director.tell(peer, "Punched: %s. +%d.  %d left on the round." % [STATIONS[index]["area"], punch_points(), left])


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_state(new_order: PackedInt32Array, new_punched: PackedInt32Array, is_open: bool) -> void:
	order.assign(Array(new_order))
	punched.assign(Array(new_punched))
	open = is_open
	_show()


@rpc("authority", "call_local", "reliable")
func _rang(index: int) -> void:
	var station := _stations[index]
	Sfx.play_at(station, Sfx.thud(0.7, 0.12, 0.6), 2.0, 25.0)
	Sfx.play_at(station, Sfx.notes([1568.0, 0.0, 1568.0, 0.0, 1568.0], 0.09, 0.3, "triangle"), 0.0, 45.0)


## The HUD's line: what's left on tonight's round.
func objective_text() -> String:
	if order.is_empty():
		return ""
	if is_complete():
		return "Round complete (%d/%d). Bonus +%d at clock-out." % [punched.size(), order.size(), ROUND_BONUS]
	var left: Array[String] = []
	for i in order:
		if i not in punched:
			left.append(STATIONS[i]["area"])
	return "Round %d/%d, still to punch: %s" % [punched.size(), order.size(), ", ".join(left)]


func _show() -> void:
	for i in _stations.size():
		var color := LAMP_OFF
		if i in order:
			color = LAMP_DONE if i in punched else LAMP_TODO
		_lamps[i].albedo_color = color
		_lamps[i].emission = color
		_lamps[i].emission_energy_multiplier = 0.0 if color == LAMP_OFF else 3.0
		_glows[i].visible = color != LAMP_OFF
		_glows[i].light_color = color
		var waiting := open and i in order and i not in punched
		_stations[i].prompt = "Punch the station (%s)" % STATIONS[i]["area"] if waiting else "Punch station"


func _build_station(index: int) -> void:
	var info: Dictionary = STATIONS[index]
	var facing: Vector3 = info["facing"]
	var station := Interactable.new()
	station.name = "Station%d" % index
	station.hold_seconds = HOLD_SECONDS
	add_child(station)
	station.position = info["at"]
	# Its local -Z points into the wall, so +Z faces whoever is punching it.
	station.look_at(station.position - facing, Vector3.UP)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.5, 0.2)
	shape.shape = box
	station.add_child(shape)
	_part(station, Vector3(0.36, 0.46, 0.14), Vector3.ZERO, Color(0.22, 0.24, 0.22))
	_part(station, Vector3(0.22, 0.12, 0.02), Vector3(0, 0.08, 0.075), Color(0.85, 0.82, 0.7))
	_part(station, Vector3(0.05, 0.12, 0.05), Vector3(0, -0.12, 0.09), Color(0.1, 0.1, 0.1))
	var lamp := _part(station, Vector3(0.06, 0.06, 0.04), Vector3(0, 0.25, 0.06), LAMP_OFF)
	_lamps.append(lamp.material_override as StandardMaterial3D)
	var glow := OmniLight3D.new()
	glow.omni_range = 2.2
	glow.light_energy = 0.5
	glow.position = Vector3(0, 0.3, 0.25)
	glow.shadow_enabled = false
	station.add_child(glow)
	_glows.append(glow)
	if info.get("post", false):
		_part(station, Vector3(0.12, 1.3, 0.12), Vector3(0, -0.7, -0.14), Color(0.3, 0.3, 0.32))
	station.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				_request_punch(index)
			else:
				_request_punch.rpc_id(1, index))
	_stations.append(station)


func _part(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(size)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.6
	material.emission_enabled = true
	material.emission = Color.BLACK
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh
