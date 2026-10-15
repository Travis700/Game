class_name Anomalies
extends Node3D
## Things that change around the school during the night, for guards to spot on the cameras.
##
## Every anomaly is visible on one camera, and has one of four types that guards log on their
## clipboards. The host decides when anomalies appear and disappear and tells everyone; each
## computer just shows or moves the props.
##
## The props that can go missing or move (the lobby plant, the mascot costume, the mop bucket...)
## live here rather than in SchoolBuilder, so this script owns their normal state.

## What guards can log. "Monster" entries are checked by the MonsterDirector instead.
const TYPES: Array[String] = ["Moved object", "Missing object", "Extra object", "Figure", "Monster"]
## Anomalies never appear or get cleared up while a guard is this close (metres).
const UNSEEN_DISTANCE := 12.0
## A figure disappears when a guard gets this close.
const FIGURE_VANISH_DISTANCE := 7.0
## After a correct report, the anomaly is cleared up this many in-game minutes later.
const CLEAR_AFTER_REPORT := 15.0
## A cleared or vanished anomaly can still be logged for this many in-game minutes.
const LOG_WINDOW_AFTER_END := 30.0
const MAX_ACTIVE := 4
## An anomaly nobody logs fades away after this many in-game minutes (once nobody's near),
## making room for new ones. It can come back later in the night.
const FADE_AFTER := 90.0
const REAPPEAR_AFTER := 60.0

## Each anomaly: area (a camera name), type, first night it can happen, what it does to which prop.
## "alts" are other places it can happen (where a moved thing ends up, where an extra thing or a
## figure appears), picked at random each time, so nobody can learn them all by heart.
const DEFINITIONS: Array[Dictionary] = [
	{"area": "Lobby", "type": "Missing object", "night": 1, "kind": "hide", "prop": "plant"},
	{"area": "Lobby", "type": "Moved object", "night": 1, "kind": "move", "prop": "bench", "alts": [Vector3(-3.5, 0, 15.5), Vector3(3.0, 0, 12.0)],
		"to": Vector3(1.5, 0, 14.0), "turn": 70.0},
	{"area": "Gym", "type": "Missing object", "night": 1, "kind": "hide", "prop": "mascot"},
	{"area": "Gym", "type": "Moved object", "night": 2, "kind": "move", "prop": "mascot", "alts": [Vector3(16.0, 0, -20.0), Vector3(30.0, 0, -6.0)],
		"to": Vector3(22.5, 0, -12.0), "turn": 200.0},
	{"area": "Main Hall East", "type": "Moved object", "night": 1, "kind": "move", "prop": "mop_bucket", "alts": [Vector3(14.0, 0, 8.5), Vector3(34.0, 0, 5.5)],
		"to": Vector3(26.0, 0, 6.5), "turn": 0.0},
	{"area": "Cafeteria", "type": "Moved object", "night": 1, "kind": "move", "prop": "trash_can", "alts": [Vector3(-30.0, 0, -18.0), Vector3(-12.0, 0, -4.0)],
		"to": Vector3(-21.0, 0, -11.0), "turn": 0.0},
	{"area": "Front Office", "type": "Moved object", "night": 1, "kind": "move", "prop": "office_chair", "alts": [Vector3(-17.0, 0.3, 17.0), Vector3(-8.0, 0.3, 12.0)],
		"to": Vector3(-10.5, 0.3, 16.0), "turn": 40.0, "tip": 90.0},
	{"area": "Main Hall West", "type": "Extra object", "night": 1, "kind": "show", "prop": "hall_box", "alts": [Vector3(-12.0, 0, 8.5), Vector3(-34.0, 0, 5.5)]},
	{"area": "Front Gate", "type": "Extra object", "night": 1, "kind": "show", "prop": "cone", "alts": [Vector3(-8.0, 0, 30.0), Vector3(9.0, 0, 40.0)]},
	{"area": "Gym", "type": "Extra object", "night": 1, "kind": "show", "prop": "ball_cart", "alts": [Vector3(12.0, 0, -24.0), Vector3(32.0, 0, -4.0)]},
	{"area": "Kitchen", "type": "Extra object", "night": 1, "kind": "show", "prop": "kitchen_crate", "alts": [Vector3(-3.0, 0, -16.0), Vector3(2.5, 0, -27.5)]},
	{"area": "Front Office", "type": "Extra object", "night": 1, "kind": "show", "prop": "counter_box"},
	{"area": "Main Hall East", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_hall", "alts": [Vector3(20.0, 0, 8.0), Vector3(35.5, 0, 5.5)]},
	{"area": "Cafeteria", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_cafeteria", "alts": [Vector3(-20.0, 0, -5.0), Vector3(-35.0, 0, -12.0)]},
	{"area": "Front Gate", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_gate", "alts": [Vector3(-12.5, 0, 45.5)]},
	{"area": "Gym", "type": "Figure", "night": 3, "kind": "figure", "prop": "figure_bleachers"},
	# Classroom wing (difficulty 2).
	{"area": "Room 101", "type": "Extra object", "night": 1, "kind": "show", "prop": "backpack", "alts": [Vector3(-44.0, 0, 16.0), Vector3(-50.0, 0, 18.0)]},
	{"area": "Room 103", "type": "Moved object", "night": 1, "kind": "move", "prop": "globe", "alts": [Vector3(-55.0, 0, -10.0), Vector3(-44.0, 0, -2.0)],
		"to": Vector3(-52.0, 0, -4.0), "turn": 0.0},
	{"area": "Room 103", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_classroom", "alts": [Vector3(-55.0, 0, -1.0)]},
	{"area": "Library", "type": "Moved object", "night": 1, "kind": "move", "prop": "book_cart", "alts": [Vector3(-74.5, 0, -7.5), Vector3(-66.5, 0, -9.5)],
		"to": Vector3(-72.0, 0, -2.5), "turn": 60.0},
	{"area": "Library", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_library", "alts": [Vector3(-60.0, 0, -12.0)]},
	{"area": "Nurse's Office", "type": "Missing object", "night": 1, "kind": "hide", "prop": "wheelchair"},
	{"area": "West Hall", "type": "Extra object", "night": 1, "kind": "show", "prop": "wet_floor_sign", "alts": [Vector3(-48.0, 0, 7.0), Vector3(-70.0, 0, 8.0)]},
	# Science wing (difficulty 3).
	{"area": "Science Lab", "type": "Missing object", "night": 1, "kind": "hide", "prop": "skeleton"},
	{"area": "Science Lab", "type": "Moved object", "night": 2, "kind": "move", "prop": "skeleton", "alts": [Vector3(57.5, 0, -9.5), Vector3(45.5, 0, -0.5)],
		"to": Vector3(50.0, 0, -3.0), "turn": 120.0},
	{"area": "Art Room", "type": "Extra object", "night": 1, "kind": "show", "prop": "clay_bust"},
	{"area": "Locker Rooms", "type": "Extra object", "night": 1, "kind": "show", "prop": "duffel_bag", "alts": [Vector3(48.0, 0, 12.0), Vector3(69.5, 0, 13.5)]},
	{"area": "Locker Rooms", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_showers", "alts": [Vector3(48.5, 0, 17.5)]},
	{"area": "East Hall", "type": "Moved object", "night": 1, "kind": "move", "prop": "hall_bin", "alts": [Vector3(50.0, 0, 5.5), Vector3(72.0, 0, 8.5)],
		"to": Vector3(63.0, 0, 6.8), "turn": 30.0},
	{"area": "East Hall", "type": "Figure", "night": 2, "kind": "figure", "prop": "figure_east_hall", "alts": [Vector3(46.0, 0, 8.5), Vector3(76.0, 0, 6.0)]},
]

var school: SchoolBuilder
## Guards' positions, for the "never in front of a guard" rules. Set by Main.
var players: Node3D

## Anomaly index -> {"credited": [peer ids], "clear_at": minutes or -1, "ended_at": minutes or -1}.
## Holds every anomaly that has appeared tonight. Host only.
var records: Dictionary = {}
## Props a monster is using tonight (e.g. the Mascot takes the mascot costume). Host only.
var reserved_props: Array[String] = []
## Tonight's difficulty: anomalies only happen in open wings.
var difficulty := 1

var _props: Dictionary = {}
var _home: Dictionary = {}
var _active: Array[int] = []
## Host: whether the last correct check_log was the first guard to log that anomaly.
var last_was_first := true
## Host: tonight's count of anomalies, including ones that came back a second time, and
## missed ones whose record was replaced when they came back.
var _appeared := 0
var _missed_earlier := 0
var _missed_names: Array[String] = []
## Host: tonight's anomalies in play (see plan). Empty means all of them.
var _pool: Array[int] = []
## Host: tonight's spot for each anomaly (0 = its usual one, n = alts[n - 1]). See plan.
var _spots: Dictionary = {}


func build(school_builder: SchoolBuilder) -> void:
	school = school_builder
	# Props that are there every night until an anomaly moves or removes them.
	_prop("plant", Vector3(5.3, 0, 11.0), [
		[Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), "red"],
		[Vector3(0, 1.0, 0), Vector3(0.8, 0.9, 0.8), "plant"]])
	_prop("bench", Vector3(4.0, 0, 18.8), [[Vector3(0, 0.22, 0), Vector3(2.4, 0.44, 0.6), "wood"]])
	_prop("mascot", Vector3(9.0, 0.3, 1.5), [
		[Vector3(0, 0.85, 0), Vector3(0.7, 1.7, 0.5), "costume"],
		[Vector3(0, 1.85, 0), Vector3(0.6, 0.5, 0.55), "costume"]])
	_prop("mop_bucket", Vector3(2.5, 0, -2.0), [
		[Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), "red"],
		[Vector3(0, 0.9, 0), Vector3(0.05, 1.3, 0.05), "wood"]])
	_prop("trash_can", Vector3(-38.8, 0, -4.0), [[Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), "dark"]])
	_prop("office_chair", Vector3(-14.0, 0, 12.2), [
		[Vector3(0, 0.25, 0), Vector3(0.1, 0.5, 0.1), "metal"],
		[Vector3(0, 0.5, 0), Vector3(0.55, 0.08, 0.55), "dark"],
		[Vector3(0, 0.85, -0.25), Vector3(0.55, 0.6, 0.06), "dark"]])
	# Props that only appear as anomalies.
	_prop("hall_box", Vector3(-25.0, 0, 7.0), [[Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.7), "cork"]], false)
	_prop("cone", Vector3(0.6, 0, 36.0), [
		[Vector3(0, 0.35, 0), Vector3(0.3, 0.7, 0.3), "cone"],
		[Vector3(0, 0.02, 0), Vector3(0.45, 0.04, 0.45), "cone"]], false)
	_prop("ball_cart", Vector3(22.5, 0, -13.0), [
		[Vector3(0, 0.5, 0), Vector3(1.2, 1.0, 0.6), "metal"],
		[Vector3(0, 1.1, 0), Vector3(1.1, 0.25, 0.5), "costume"]], false)
	_prop("kitchen_crate", Vector3(0, 0, -22.0), [[Vector3(0, 0.4, 0), Vector3(0.8, 0.8, 0.8), "wood"]], false)
	_prop("counter_box", Vector3(-9.0, 1.1, 18.5), [[Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), "cork"]], false)
	_build_wing_props()
	_figure("figure_hall", Vector3(30.0, 0, 6.5), -90.0)
	_figure("figure_cafeteria", Vector3(-30.0, 0, -25.0), 150.0)
	_figure("figure_gate", Vector3(12.0, 0, 47.5), 190.0)
	_figure("figure_bleachers", Vector3(38.65, 1.35, -16.0), 220.0)


func _build_wing_props() -> void:
	_prop("globe", Vector3(-46.0, 0.77, -12.2), [
		[Vector3(0, 0.1, 0), Vector3(0.2, 0.2, 0.2), "wood"],
		[Vector3(0, 0.38, 0), Vector3(0.36, 0.36, 0.36), "globe"]])
	_prop("book_cart", Vector3(-62.0, 0, -2.4), [
		[Vector3(0, 0.45, 0), Vector3(1.0, 0.9, 0.45), "metal"],
		[Vector3(-0.2, 1.02, 0), Vector3(0.5, 0.25, 0.3), "red"],
		[Vector3(0.25, 1.0, 0), Vector3(0.35, 0.2, 0.3), "plant"]])
	_prop("wheelchair", Vector3(-72.0, 0, 17.5), [
		[Vector3(0, 0.5, 0), Vector3(0.55, 0.08, 0.55), "dark"],
		[Vector3(0, 0.85, 0.27), Vector3(0.55, 0.6, 0.05), "dark"],
		[Vector3(-0.3, 0.35, 0), Vector3(0.04, 0.7, 0.7), "metal"],
		[Vector3(0.3, 0.35, 0), Vector3(0.04, 0.7, 0.7), "metal"]])
	_prop("skeleton", Vector3(44.0, 0, -12.5), [
		[Vector3(0, 0.05, 0), Vector3(0.5, 0.1, 0.5), "dark"],
		[Vector3(0, 0.9, 0), Vector3(0.06, 1.6, 0.06), "metal"],
		[Vector3(0, 1.25, 0), Vector3(0.4, 0.5, 0.18), "bone"],
		[Vector3(0, 1.7, 0), Vector3(0.22, 0.26, 0.24), "bone"],
		[Vector3(0, 0.8, 0), Vector3(0.32, 0.12, 0.15), "bone"]])
	_prop("hall_bin", Vector3(58.0, 0, 9.4), [[Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6), "dark"]])
	_prop("backpack", Vector3(-52.8, 0, 13.0), [[Vector3(0, 0.25, 0), Vector3(0.4, 0.5, 0.25), "red"]], false)
	# A stack of classroom chairs that nobody put there (named for what it used to be).
	_prop("wet_floor_sign", Vector3(-58.0, 0, 6.0), [
		[Vector3(0, 0.23, 0), Vector3(0.45, 0.06, 0.45), "wood"],
		[Vector3(0, 0.4, 0), Vector3(0.45, 0.06, 0.45), "wood"],
		[Vector3(0, 0.57, 0), Vector3(0.45, 0.06, 0.45), "wood"],
		[Vector3(0, 0.3, 0.2), Vector3(0.45, 0.6, 0.05), "metal"],
		[Vector3(0, 0.75, 0.2), Vector3(0.45, 0.4, 0.05), "wood"]], false)
	_prop("clay_bust", Vector3(66.0, 0.77, -12.0), [
		[Vector3(0, 0.15, 0), Vector3(0.3, 0.3, 0.25), "clay"],
		[Vector3(0, 0.45, 0), Vector3(0.2, 0.3, 0.22), "clay"]], false)
	_prop("duffel_bag", Vector3(55.0, 0.44, 14.0), [[Vector3(0, 0.15, 0), Vector3(0.8, 0.3, 0.35), "plant"]], false)
	_figure("figure_classroom", Vector3(-44.0, 0, -7.0), 160.0)
	_figure("figure_library", Vector3(-70.0, 0, -7.5), 30.0)
	_figure("figure_showers", Vector3(66.0, 0, 18.4), 90.0)
	_figure("figure_east_hall", Vector3(66.0, 0, 6.5), 90.0)


## Area names guards can log at this difficulty: the cameras' areas first, in camera order,
## then any areas without a camera.
func areas(max_difficulty := 1) -> Array[String]:
	var names: Array[String] = []
	for spot: Dictionary in school.camera_spots:
		if spot.get("difficulty", 1) <= max_difficulty:
			names.append(spot["name"])
	for area: String in SchoolBuilder.AREAS:
		if area not in names and SchoolBuilder.area_difficulty(area) <= max_difficulty:
			names.append(area)
	return names


# --- Host: deciding what happens -----------------------------------------------------

## Tries to start one anomaly that can happen on this night. Returns true if one started.
func spawn_random(night: int, minutes: float) -> bool:
	if _active.size() >= MAX_ACTIVE:
		return false
	var candidates: Array[int] = []
	for i in DEFINITIONS.size():
		var def := DEFINITIONS[i]
		var ended: float = records[i]["ended_at"] if records.has(i) else -1.0
		var used := records.has(i) and (ended < 0.0 or minutes - ended < REAPPEAR_AFTER)
		if def["night"] > night or used or _prop_busy(def["prop"]) or def["prop"] in reserved_props \
				or (not _pool.is_empty() and i not in _pool) \
				or SchoolBuilder.area_difficulty(def["area"]) > difficulty:
			continue
		if _guard_within(_props[def["prop"]].global_position, UNSEEN_DISTANCE):
			continue
		candidates.append(i)
	if candidates.is_empty():
		return false
	start(candidates.pick_random(), minutes, night)
	return true


## Host, as the shift starts: tonight only some of the anomalies are in play (about 70%), so no
## two nights look alike.
func plan(night: int) -> void:
	_pool.clear()
	for i in DEFINITIONS.size():
		if DEFINITIONS[i]["night"] <= night and SchoolBuilder.area_difficulty(DEFINITIONS[i]["area"]) <= difficulty:
			_pool.append(i)
	_pool.shuffle()
	# Where each one happens tonight, settled now (so a daily shift is the same for everyone).
	_spots.clear()
	for i in DEFINITIONS.size():
		_spots[i] = randi() % (DEFINITIONS[i].get("alts", []).size() + 1)
	_pool.resize(maxi(6, ceili(_pool.size() * 0.7)) if _pool.size() > 6 else _pool.size())


## Host: starts one particular anomaly (by its place in DEFINITIONS), e.g. for training.
## Later in the run, moved things move less (a nudge instead of across the room), so the
## cameras need a closer look: from all the way on night 1 to about a third by night 9.
func start(index: int, minutes: float, night := 1) -> void:
	if records.has(index) and records[index]["credited"].is_empty():
		_missed_earlier += 1
		_missed_names.append(_describe(index))
	_appeared += 1
	var amount := clampf(1.12 - 0.085 * night + randf_range(-0.08, 0.08), 0.3, 1.0)
	var alts: Array = DEFINITIONS[index].get("alts", [])
	var variant: int = _spots.get(index, 0)
	# Never right in front of somebody.
	if variant > 0 and _guard_within(alts[variant - 1], UNSEEN_DISTANCE):
		variant = 0
	records[index] = {"credited": [], "clear_at": -1.0, "ended_at": -1.0, "started_at": minutes, "amount": amount, "variant": variant}
	_set_active.rpc(index, true, amount, variant)


## Host, every frame: figures vanish when approached; reported anomalies get cleared up.
func update(minutes: float) -> void:
	for i in _active.duplicate():
		if not records.has(i):
			continue
		var def := DEFINITIONS[i]
		var record: Dictionary = records[i]
		var spot: Vector3 = _props[def["prop"]].global_position
		if def["kind"] == "figure" and _guard_within(spot, FIGURE_VANISH_DISTANCE):
			_end(i, minutes)
		elif record["clear_at"] >= 0.0 and minutes >= record["clear_at"] and not _guard_within(spot, UNSEEN_DISTANCE):
			_end(i, minutes)
		elif minutes - record["started_at"] > FADE_AFTER and not _guard_within(spot, UNSEEN_DISTANCE):
			_end(i, minutes)


## Host: checks a clipboard entry. Returns true if it matches an anomaly this guard hasn't logged yet.
func check_log(peer_id: int, area: String, type: String, minutes: float) -> bool:
	for i: int in records:
		var def := DEFINITIONS[i]
		var record: Dictionary = records[i]
		if def["area"] != area or def["type"] != type or peer_id in record["credited"]:
			continue
		var ended: float = record["ended_at"]
		if ended >= 0.0 and minutes - ended > LOG_WINDOW_AFTER_END:
			continue
		last_was_first = record["credited"].is_empty()
		record["credited"].append(peer_id)
		if record["clear_at"] < 0.0:
			record["clear_at"] = minutes + CLEAR_AFTER_REPORT
		return true
	return false


## Host: an anomaly that's out right now, as {"area", "type"}, or {} if there isn't one.
## (For the phone's tip-offs.)
func tip() -> Dictionary:
	if _active.is_empty():
		return {}
	var def: Dictionary = DEFINITIONS[_active.pick_random()]
	return {"area": def["area"], "type": def["type"]}


## Host: anomalies tonight that nobody logged.
func missed_count() -> int:
	var missed := _missed_earlier
	for i: int in records:
		if records[i]["credited"].is_empty():
			missed += 1
	return missed


## Host: what nobody logged tonight, as "Lobby: moved object".
func missed_list() -> Array[String]:
	var missed: Array[String] = _missed_names.duplicate()
	for i: int in records:
		if records[i]["credited"].is_empty():
			missed.append(_describe(i))
	return missed


func _describe(index: int) -> String:
	var def: Dictionary = DEFINITIONS[index]
	return "%s: %s" % [def["area"], (def["type"] as String).to_lower()]


func appeared_count() -> int:
	return _appeared


## Host: for a player who joins mid-evening.
func send_state_to(peer_id: int) -> void:
	for i in _active:
		_set_active.rpc_id(peer_id, i, true, float(records.get(i, {}).get("amount", 1.0)), int(records.get(i, {}).get("variant", 0)))


## Host: puts everything back for the next night.
func reset_all() -> void:
	for i in _active.duplicate():
		_set_active.rpc(i, false)
	records.clear()
	_appeared = 0
	_missed_earlier = 0
	_missed_names.clear()


func _end(index: int, minutes: float) -> void:
	records[index]["ended_at"] = minutes
	_set_active.rpc(index, false)


func _prop_busy(prop: String) -> bool:
	for i in _active:
		if DEFINITIONS[i]["prop"] == prop:
			return true
	return false


func _guard_within(spot: Vector3, distance: float) -> bool:
	if players == null:
		return false
	for guard: Guard in players.get_children():
		# Ghosts drift about unseen: they don't scare anything off or keep it there.
		if not guard.is_dead and guard.global_position.distance_to(spot) < distance:
			return true
	return false


# --- Every computer: showing it ------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_active(index: int, on: bool, amount := 1.0, variant := 0) -> void:
	var def := DEFINITIONS[index]
	var prop: Node3D = _props[def["prop"]]
	var alts: Array = def.get("alts", [])
	var spot: Variant = alts[variant - 1] if variant > 0 and variant <= alts.size() else null
	if on and index not in _active:
		_active.append(index)
	elif not on:
		_active.erase(index)
	match def["kind"]:
		"hide":
			_set_visible(prop, not on)
		"show", "figure":
			prop.transform = _home[def["prop"]]
			if on and spot != null:
				prop.position = spot
			_set_visible(prop, on)
		"move":
			if on:
				var home: Transform3D = _home[def["prop"]]
				prop.position = home.origin.lerp(def["to"] if spot == null else spot, amount)
				prop.rotation_degrees = home.basis.get_euler() * (180.0 / PI) * (1.0 - amount) \
						+ Vector3(0, def["turn"], def.get("tip", 0.0)) * amount
			else:
				prop.transform = _home[def["prop"]]


## Shows or hides one of the props on every computer, e.g. when the Mascot steps off its stand.
@rpc("authority", "call_local", "reliable")
func set_prop_shown(prop_name: String, on: bool) -> void:
	var prop: Node3D = _props[prop_name]
	prop.transform = _home[prop_name]
	_set_visible(prop, on)


func _set_visible(prop: Node3D, on: bool) -> void:
	prop.visible = on
	for child in prop.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not on


## A prop made of boxes. Each part is [offset, size, material name].
func _prop(prop_name: String, pos: Vector3, parts: Array, visible_at_start := true) -> void:
	var body := StaticBody3D.new()
	body.name = prop_name
	body.position = pos
	for part: Array in parts:
		var box := BoxMesh.new()
		box.size = part[1]
		var mesh := MeshInstance3D.new()
		mesh.mesh = box
		mesh.material_override = _material(part[2])
		mesh.position = part[0]
		body.add_child(mesh)
		var shape := BoxShape3D.new()
		shape.size = part[1]
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = part[0]
		body.add_child(collider)
	add_child(body)
	_props[prop_name] = body
	_home[prop_name] = body.transform
	_set_visible(body, visible_at_start)


## A dark, featureless person-shaped figure with two faint points for eyes.
func _figure(prop_name: String, pos: Vector3, facing_deg: float) -> void:
	var figure := Node3D.new()
	figure.name = prop_name
	figure.position = pos
	figure.rotation_degrees.y = facing_deg
	var body := CapsuleMesh.new()
	body.radius = 0.26
	body.height = 1.55
	var body_mesh := MeshInstance3D.new()
	body_mesh.mesh = body
	body_mesh.material_override = _material("figure")
	body_mesh.position = Vector3(0, 0.78, 0)
	figure.add_child(body_mesh)
	var head := SphereMesh.new()
	head.radius = 0.16
	head.height = 0.34
	var head_mesh := MeshInstance3D.new()
	head_mesh.mesh = head
	head_mesh.material_override = _material("figure")
	head_mesh.position = Vector3(0, 1.72, 0)
	figure.add_child(head_mesh)
	for side: float in [-1.0, 1.0]:
		var eye := SphereMesh.new()
		eye.radius = 0.018
		eye.height = 0.036
		var eye_mesh := MeshInstance3D.new()
		eye_mesh.mesh = eye
		eye_mesh.material_override = _material("figure_eye")
		eye_mesh.position = Vector3(side * 0.06, 1.75, -0.15)
		figure.add_child(eye_mesh)
	add_child(figure)
	_props[prop_name] = figure
	_home[prop_name] = figure.transform
	figure.visible = false


func _material(mat_name: String) -> Material:
	match mat_name:
		"cone":
			var cone := StandardMaterial3D.new()
			cone.albedo_color = Color(0.95, 0.4, 0.05)
			return cone
		"yellow", "globe", "bone", "clay":
			var colours := {"yellow": Color(0.95, 0.8, 0.1), "globe": Color(0.2, 0.4, 0.75),
				"bone": Color(0.85, 0.83, 0.75), "clay": Color(0.6, 0.38, 0.26)}
			var plain := StandardMaterial3D.new()
			plain.albedo_color = colours[mat_name]
			return plain
		"figure":
			var shadow := StandardMaterial3D.new()
			shadow.albedo_color = Color(0.02, 0.02, 0.025)
			shadow.roughness = 1.0
			return shadow
		"figure_eye":
			var eye := StandardMaterial3D.new()
			eye.albedo_color = Color(0.9, 0.9, 0.85)
			eye.emission_enabled = true
			eye.emission = Color(0.9, 0.9, 0.8)
			eye.emission_energy_multiplier = 1.5
			return eye
	return school.get_material(mat_name)
