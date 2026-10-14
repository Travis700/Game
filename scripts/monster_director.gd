class_name MonsterDirector
extends Node3D
## Decides which monsters come out each night and when, and gives them what they need:
## a navigation mesh to walk on, who's alive, who can see what, and catching guards.
##
## Each monster has a home area and can only appear if that area is open tonight: the
## classroom wing's monsters need difficulty 2, the science wing's need difficulty 3. The host runs all of this; monsters
## are spawned on every computer through the MonsterSpawner.

signal guard_caught(peer_id: int, by: String)
signal message_for(peer_id: int, text: String)
## Something everyone hears, e.g. the Principal on the intercom. `sound` is "" or "intercom".
signal announcement(text: String, sound: String)
## A guard walked a real lost student to safety.
signal student_helped(peer_id: int)
## A camera lost or got back its signal (the Ghost passing by).
signal camera_signal_changed(camera_index: int, working: bool)
## The school bell started or stopped ringing.
signal bell_changed(ringing: bool)

## How many monsters each night (1-9) can bring.
const MONSTERS_PER_NIGHT: Array[int] = [1, 1, 2, 2, 3, 3, 4, 4, 5]
## From this night on, monsters can come into the guard room.
const GUARD_ROOM_OPENS_ON_NIGHT := 7
## Every monster: its name, home area and the first night it can appear.
const ROSTER := {
	"hall_monitor": {"name": "Hall Monitor", "home": "Main Hall West", "night": 1},
	"mascot": {"name": "The Mascot", "home": "Gym", "night": 1},
	"lunch_lady": {"name": "Lunch Lady", "home": "Cafeteria", "night": 2},
	"locker_thing": {"name": "Locker Thing", "home": "Main Hall West", "night": 3},
	"principal": {"name": "The Principal", "home": "Front Office", "night": 3},
	"other_cleaner": {"name": "The Other Cleaner", "home": "Lobby", "night": 5},
	"student": {"name": "The Student", "home": "Main Hall West", "night": 5},
	"ghost": {"name": "The Ghost", "home": "Lobby", "night": 5},
	"substitute": {"name": "The Substitute", "home": "Room 101", "night": 1},
	"librarian": {"name": "The Librarian", "home": "Library", "night": 2},
	"nurse": {"name": "The Nurse", "home": "Nurse's Office", "night": 3},
	"crossing_guard": {"name": "The Crossing Guard", "home": "East Hall", "night": 1},
	"self_portrait": {"name": "The Self-Portrait", "home": "Art Room", "night": 2},
	"specimen": {"name": "The Specimen", "home": "Science Lab", "night": 3},
	"understudy": {"name": "The Understudy", "home": "Locker Rooms", "night": 4},
}
## The intercom: in-game minutes between the Principal's summonses, and real seconds to answer.
const SUMMON_EVERY := Vector2(60.0, 100.0)
const SUMMON_SECONDS := 45.0
## How long a camera stays dark after the Ghost passes (in-game minutes).
const BLACKOUT_MINUTES := 20.0
const FRONT_OFFICE := Vector3(-11.5, 0, 15)
const GUARD_ROOM := AABB(Vector3(6, -1, 10), Vector3(14, 5, 10))
const MASCOT_STAND := Vector3(9.0, 0.3, 1.5)
## The Bell: from this night it can ring at the wrong time, speeding every monster up until
## someone shuts it off at the panel in the front office (or it stops by itself).
const BELL_FROM_NIGHT := 4
const BELL_SPEED := 1.35
const BELL_MAX_SECONDS := 60.0

var players: Node3D
var guard_room: GuardRoom
var cameras: SecurityCameras
var anomalies: Anomalies
var lockers: Lockers
var school: SchoolBuilder
var portrait: SelfPortrait

var night_number := 1
## Tonight's difficulty: which wings are open. Monsters only come from open areas.
var difficulty := 1
## Monsters coming out tonight and when: [{"kind", "at"}]. Host only.
var tonight: Array[Dictionary] = []

var _container: Node3D
var _spawner: MultiplayerSpawner
var _navigation: NavigationRegion3D
var _next_id := 1
## Guards who have logged each monster: monster node name -> [peer ids]. Host only.
var _credited: Dictionary = {}
var _last_positions: Dictionary = {}
var _speeds: Dictionary = {}
var _corpses: Dictionary = {}
## True while the Ghost is out tonight (it shows up on the time clock). Host only.
var ghost_active := false
var _minutes := 0.0
var _principal_on := false
var _next_summon := 0.0
var _summoned := 0
var _summon_left := 0.0
var _principal_out := false
var _blackouts: Dictionary = {}
## True while the school bell is ringing. Shown on every computer.
var bell_ringing := false
var _bell_times: Array[float] = []
var _bell_left := 0.0


func build() -> void:
	_container = Node3D.new()
	_container.name = "Live"
	add_child(_container)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "MonsterSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_container)
	_spawner.spawn_function = _create_monster
	portrait = SelfPortrait.new()
	portrait.name = "SelfPortrait"
	portrait.director = self
	add_child(portrait)
	portrait.build(school.self_portrait_easel)


## Host: works out where monsters can walk, from the school's floors, walls and furniture.
func bake_navigation() -> void:
	var mesh := NavigationMesh.new()
	# Sizes are whole multiples of the 0.25 m grid the navigation mesh is built on.
	mesh.agent_radius = 0.5
	mesh.agent_height = 1.75
	mesh.agent_max_climb = 0.25
	mesh.cell_size = 0.25
	mesh.cell_height = 0.25
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	mesh.geometry_source_group_name = SchoolBuilder.NAV_SOURCE_GROUP
	mesh.filter_baking_aabb = SchoolBuilder.NAV_BOUNDS
	_navigation = NavigationRegion3D.new()
	_navigation.name = "Navigation"
	_navigation.navigation_mesh = mesh
	add_child(_navigation)
	_navigation.bake_navigation_mesh(false)


# --- Planning the night (host) ---------------------------------------------------------

func plan_night(number: int) -> void:
	night_number = number
	tonight.clear()
	_credited.clear()
	var pool: Array = []
	for kind: String in ROSTER:
		var home: String = ROSTER[kind]["home"]
		if ROSTER[kind]["night"] <= number and SchoolBuilder.area_difficulty(home) <= difficulty:
			pool.append(kind)
	pool.shuffle()
	# Bigger maps (for bigger teams) bring one more monster per open wing.
	var wanted := MONSTERS_PER_NIGHT[clampi(number - 1, 0, MONSTERS_PER_NIGHT.size() - 1)] + difficulty - 1
	var count := mini(wanted, pool.size())
	for i in count:
		tonight.append({"kind": pool[i], "at": randf_range(25.0, 150.0)})
		if pool[i] == "mascot":
			anomalies.reserved_props.append("mascot")
	# The Bell rings once or twice a night from night 4.
	_bell_times.clear()
	if number >= BELL_FROM_NIGHT:
		for i in (1 if number < 7 else 2):
			_bell_times.append(randf_range(60.0, 300.0))
		_bell_times.sort()
	# The real night cleaner works every night.
	tonight.append({"kind": "cleaner", "at": 10.0})
	print("[night] Monsters tonight: ", tonight.map(func(m: Dictionary) -> String: return "%s at %s" % [m["kind"], Night.format_time(m["at"])]))


## Host, every frame during the shift.
func update(minutes: float, delta: float) -> void:
	_minutes = minutes
	_track_guard_speeds(delta)
	for plan in tonight:
		if plan.get("started", false) or minutes < plan["at"]:
			continue
		plan["started"] = true
		_start(plan["kind"], minutes)
	lockers.update(minutes)
	portrait.update(minutes)
	_update_bell(minutes, delta)
	_update_principal(minutes, delta)
	for camera_index: int in _blackouts.keys():
		if minutes >= _blackouts[camera_index]:
			_blackouts.erase(camera_index)
			camera_signal_changed.emit(camera_index, true)


func _start(kind: String, minutes: float) -> void:
	match kind:
		"hall_monitor":
			spawn("hall_monitor", Vector3(-36, 0, 7))
		"mascot":
			anomalies.set_prop_shown.rpc("mascot", false)
			spawn("mascot", MASCOT_STAND)
		"lunch_lady":
			spawn("lunch_lady", Vector3(0, 0, -25))
		"locker_thing":
			lockers.activate(minutes)
		"principal":
			_principal_on = true
			_next_summon = minutes + randf_range(5.0, 30.0)
		"cleaner":
			spawn("cleaner", Vector3(0, 0, -5))
		"other_cleaner":
			spawn("other_cleaner", NightCleaner.ROUTE.pick_random())
		"student":
			spawn("student", Vector3(randf_range(-30.0, 30.0), 0, 7), {"real": randf() < 0.2})
		"ghost":
			ghost_active = true
			spawn("ghost", Vector3(-35, 0, -25))
		"substitute":
			spawn("substitute", Substitute.CLASSROOMS.pick_random())
		"librarian":
			spawn("librarian", Vector3(-70, 0, -3))
		"nurse":
			spawn("nurse", Vector3(-74, 0, 15))
		"crossing_guard":
			spawn("crossing_guard", Vector3(75, 0, 7))
		"self_portrait":
			portrait.activate(minutes)
		"specimen":
			spawn("specimen", Vector3(58, 0, -6))
		"understudy":
			spawn("understudy", Vector3(50, 0, 15))


func spawn(kind: String, at: Vector3, extra := {}) -> void:
	var data := {"kind": kind, "id": _next_id, "position": at}
	data.merge(extra)
	_next_id += 1
	_spawner.spawn(data)


## Host: a bad roll at a totem lets a shade out to hunt whoever rolled.
func summon_shade(at: Vector3, target_peer: int) -> void:
	spawn("shade", at, {"target": target_peer})


func remove_monster(monster: Monster) -> void:
	monster.queue_free()


## Host: 6 AM, everything goes back where it came from.
func end_night() -> void:
	for monster in _container.get_children():
		monster.queue_free()
	tonight.clear()
	_bell_times.clear()
	if bell_ringing:
		stop_bell()
	ghost_active = false
	_principal_on = false
	_principal_out = false
	_summoned = 0
	for camera_index: int in _blackouts.keys():
		camera_signal_changed.emit(camera_index, true)
	_blackouts.clear()
	lockers.reset_all()
	portrait.deactivate()
	anomalies.reserved_props.erase("mascot")
	anomalies.set_prop_shown.rpc("mascot", true)


func _create_monster(data: Dictionary) -> Node:
	var monster: Monster
	match data["kind"]:
		"hall_monitor":
			monster = HallMonitor.new()
		"mascot":
			monster = Mascot.new()
		"lunch_lady":
			monster = LunchLady.new()
		"cleaner":
			monster = NightCleaner.new()
		"other_cleaner":
			monster = OtherCleaner.new()
		"principal":
			var principal := Principal.new()
			principal.target_peer = data.get("target", 0)
			monster = principal
		"student":
			var student := Student.new()
			student.real = data.get("real", false)
			monster = student
		"ghost":
			monster = SchoolGhost.new()
		"substitute":
			monster = Substitute.new()
		"librarian":
			monster = Librarian.new()
		"nurse":
			monster = Nurse.new()
		"crossing_guard":
			monster = CrossingGuard.new()
		"specimen":
			monster = Specimen.new()
		"understudy":
			monster = Understudy.new()
		_:
			var shade := Shade.new()
			shade.target_peer = data.get("target", 0)
			monster = shade
	monster.name = "Monster%d" % data["id"]
	monster.director = self
	monster.position = data["position"]
	return monster


# --- What monsters ask about (host) -----------------------------------------------------

func living_guards() -> Array[Guard]:
	var living: Array[Guard] = []
	for guard: Guard in players.get_children():
		# A guard whose player just left is still in the tree until the end of the frame.
		if not guard.is_dead and guard.is_inside_tree() and not guard.is_queued_for_deletion():
			living.append(guard)
	return living


## Living guards a monster may go after: before night 7 that leaves out anyone in the
## guard room, so nothing reaches (or notices) them through its walls and doorways.
func targetable_guards() -> Array[Guard]:
	var result: Array[Guard] = []
	for guard in living_guards():
		if may_enter(guard.global_position):
			result.append(guard)
	return result


func dead_guards() -> Array[Guard]:
	var dead: Array[Guard] = []
	for guard: Guard in players.get_children():
		if guard.is_dead:
			dead.append(guard)
	return dead


func guard_by_peer(peer_id: int) -> Guard:
	return players.get_node_or_null(str(peer_id)) as Guard


func nearest_living_guard(from: Vector3) -> Guard:
	var best: Guard = null
	var best_distance := INF
	for guard in living_guards():
		var distance := from.distance_to(guard.global_position)
		if distance < best_distance and may_enter(guard.global_position):
			best = guard
			best_distance = distance
	return best


func guard_near(point: Vector3, distance: float) -> bool:
	for guard: Guard in players.get_children():
		if guard.global_position.distance_to(point) < distance:
			return true
	return false


## How fast a guard is moving, worked out from where they've been (works for every player).
func guard_speed(guard: Guard) -> float:
	return _speeds.get(guard.name, 0.0)


## Before night 7 the guard room is off limits to monsters.
func may_enter(point: Vector3) -> bool:
	return night_number >= GUARD_ROOM_OPENS_ON_NIGHT or not GUARD_ROOM.has_point(point)


## Can someone at `from` see this guard, with nothing solid in between?
func can_see(from: Vector3, guard: Guard) -> bool:
	return _clear_line(from, guard.global_position + Vector3(0, 1.4, 0), guard)


## Is a living guard shining their flashlight at this point? Only checks `only` if given.
func lit_by_flashlight(point: Vector3, max_distance: float, only: Guard = null) -> bool:
	for guard in living_guards():
		if only != null and guard != only:
			continue
		if not guard.flashlight.visible:
			continue
		var from := guard.camera.global_position
		var to_point := point - from
		# The heavy-duty flashlight reaches further and wider.
		if to_point.length() > max_distance * (1.4 if guard.bright_flashlight else 1.0):
			continue
		var cone := deg_to_rad(30 if guard.bright_flashlight else 24)
		if (-guard.camera.global_basis.z).angle_to(to_point) < cone and _clear_line(from, point, null):
			return true
	return false


## Is anyone looking at this monster: a living guard facing it, or a monitor showing it
## while someone is in the guard room?
func is_watched(monster: Monster) -> bool:
	var target := monster.global_position + Vector3(0, 1.2, 0)
	for guard in living_guards():
		var eye := guard.camera.global_position
		var to_monster := target - eye
		if to_monster.length() < 40.0 and (-guard.camera.global_basis.z).angle_to(to_monster) < deg_to_rad(50) \
				and _clear_line(eye, target, null):
			return true
	if not _anyone_in_guard_room():
		return false
	for feed_key in cameras.shown:
		var camera_index := feed_key / 2
		if not cameras.is_working(camera_index):
			continue
		var camera := cameras.camera(camera_index)
		var to_monster := target - camera.global_position
		if to_monster.length() < 45.0 and (-camera.global_basis.z).angle_to(to_monster) < deg_to_rad(42) \
				and _clear_line(camera.global_position, target, null):
			return true
	return false


## Monsters out right now that sensors and traps react to (not the Ghost, which floats).
func active_monsters() -> Array[Monster]:
	var result: Array[Monster] = []
	for node in _container.get_children():
		var monster := node as Monster
		# The Shade counts here even though it can't be logged; the Ghost floats over everything.
		if monster and not monster.harmless and not monster is SchoolGhost \
				and (monster.loggable() or monster is Shade) and not monster.is_queued_for_deletion():
			result.append(monster)
	return result


## Is this guard sitting at a guard room desk? (Works for every guard, on the host.)
func is_seated(guard: Guard) -> bool:
	return guard.name.to_int() in guard_room.occupants


## True while a Crossing Guard is holding up its STOP sign (everyone should be standing still).
func stop_sign_up() -> bool:
	for node in _container.get_children():
		if node is CrossingGuard and (node as Monster).state == "stop":
			return true
	return false


## How much faster monsters move right now (the Bell).
func speed_multiplier() -> float:
	return BELL_SPEED if bell_ringing else 1.0


func _update_bell(minutes: float, delta: float) -> void:
	if bell_ringing:
		_bell_left -= delta
		if _bell_left <= 0.0:
			stop_bell()
		return
	if not _bell_times.is_empty() and minutes >= _bell_times[0]:
		_bell_times.pop_front()
		_bell_left = BELL_MAX_SECONDS
		bell_changed.emit(true)
		announcement.emit("The school bell is ringing, and everything out there just got faster. The bell panel is in the front office.", "")


## Host: someone shut the bell off at the panel (or it stopped by itself).
func stop_bell() -> void:
	if bell_ringing:
		bell_changed.emit(false)


## Tonight's clock, in in-game minutes. Host only.
func minutes() -> float:
	return _minutes


func kill(guard: Guard, by: String) -> void:
	if not guard.is_dead:
		guard_caught.emit(guard.name.to_int(), by)


## Sends a message to one player's screen.
func tell(peer_id: int, text: String) -> void:
	message_for.emit(peer_id, text)


## Host: checks a clipboard "Monster" entry. True if a monster this guard hasn't logged yet is
## in that area right now.
func check_log(peer_id: int, area: String) -> bool:
	for node: Node in _container.get_children():
		var monster := node as Monster
		if monster == null or monster.harmless or monster.is_queued_for_deletion() or not monster.loggable():
			continue
		var credited: Array = _credited.get_or_add(monster.name, [])
		if peer_id not in credited and SchoolBuilder.area_at(monster.global_position) == area:
			credited.append(peer_id)
			if monster.leaves_when_logged:
				# Found out, it slips away.
				get_tree().create_timer(2.0).timeout.connect(func() -> void:
					if is_instance_valid(monster):
						remove_monster(monster))
			return true
	if portrait.active and portrait.stage > 0 and area == "Art Room" and peer_id not in portrait.credited:
		portrait.credited.append(peer_id)
		return true
	if lockers.active and peer_id not in lockers.credited and lockers.has_open_in(area):
		lockers.credited.append(peer_id)
		return true
	return false


# --- The Principal and the Ghost (host) ---------------------------------------------------

func _update_principal(minutes: float, delta: float) -> void:
	if not _principal_on or _principal_out:
		return
	if _summoned == 0:
		if minutes < _next_summon:
			return
		var guard: Guard = living_guards().pick_random() if not living_guards().is_empty() else null
		if guard == null:
			return
		_summoned = guard.name.to_int()
		_summon_left = SUMMON_SECONDS
		announcement.emit("The intercom crackles: \"Guard %d. My office. Now.\"" % guard.slot, "intercom")
		return
	var summoned := guard_by_peer(_summoned)
	if summoned == null or summoned.is_dead:
		_summoned = 0
		_next_summon = minutes + randf_range(SUMMON_EVERY.x, SUMMON_EVERY.y)
		return
	if SchoolBuilder.area_at(summoned.global_position) == "Front Office":
		announcement.emit("The intercom crackles: \"...Good. Back to work.\"", "intercom")
		_summoned = 0
		_next_summon = minutes + randf_range(SUMMON_EVERY.x, SUMMON_EVERY.y)
		return
	_summon_left -= delta
	if _summon_left <= 0.0:
		announcement.emit("The intercom crackles: \"Then I'll come to you, Guard %d.\"" % summoned.slot, "intercom")
		_principal_out = true
		spawn("principal", FRONT_OFFICE, {"target": _summoned})
		_summoned = 0


## Called by the Principal when it gives up and goes back to its office.
func principal_done(principal: Monster) -> void:
	remove_monster(principal)
	_principal_out = false
	_next_summon = _minutes + randf_range(SUMMON_EVERY.x, SUMMON_EVERY.y)


## Called by the Ghost every frame: cameras near it lose their signal for a while.
func ghost_passing(at: Vector3, distance: float) -> void:
	for i in cameras.count():
		if cameras.camera(i).global_position.distance_to(at) < distance and not _blackouts.has(i):
			_blackouts[i] = _minutes + BLACKOUT_MINUTES
			camera_signal_changed.emit(i, false)


# --- Bodies (every computer) -------------------------------------------------------------

## Leaves a guard's body where they fell.
func place_corpse(peer_id: int, at: Vector3, color: Color) -> void:
	remove_corpse(peer_id)
	var body := MeshInstance3D.new()
	body.mesh = Monster.capsule(0.33, 1.75)
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.3)
	body.material_override = material
	body.position = at + Vector3(0, 0.3, 0)
	body.rotation_degrees = Vector3(90, randf() * 360.0, 0)
	add_child(body)
	_corpses[peer_id] = body


func remove_corpse(peer_id: int) -> void:
	if _corpses.has(peer_id):
		(_corpses[peer_id] as Node).queue_free()
		_corpses.erase(peer_id)


func remove_all_corpses() -> void:
	for peer_id: int in _corpses.keys():
		remove_corpse(peer_id)


# --- Internals -----------------------------------------------------------------------

func _clear_line(from: Vector3, to: Vector3, allowed: Node) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["collider"] == allowed or hit["collider"] is Guard


func _anyone_in_guard_room() -> bool:
	for guard in living_guards():
		if GUARD_ROOM.has_point(guard.global_position):
			return true
	return false


func _track_guard_speeds(delta: float) -> void:
	if delta <= 0.0:
		return
	for guard: Guard in players.get_children():
		var now := guard.global_position
		var before: Vector3 = _last_positions.get(guard.name, now)
		var speed := Vector2(now.x - before.x, now.z - before.z).length() / delta
		# Faster than anyone can run means a teleport (sitting down, standing up, a revive),
		# not movement.
		_speeds[guard.name] = 0.0 if speed > 12.0 else speed
		_last_positions[guard.name] = now
