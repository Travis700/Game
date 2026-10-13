class_name MonsterDirector
extends Node3D
## Decides which monsters come out each night and when, and gives them what they need:
## a navigation mesh to walk on, who's alive, who can see what, and catching guards.
##
## Each monster has a home area and can only appear if that area is in tonight's map
## (difficulty 1 includes every home used so far). The host runs all of this; monsters
## are spawned on every computer through the MonsterSpawner.

signal guard_caught(peer_id: int, by: String)
signal message_for(peer_id: int, text: String)

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
}
const GUARD_ROOM := AABB(Vector3(6, -1, 10), Vector3(14, 5, 10))
const MASCOT_STAND := Vector3(9.0, 0.3, 1.5)

var players: Node3D
var guard_room: GuardRoom
var cameras: SecurityCameras
var anomalies: Anomalies
var lockers: Lockers

var night_number := 1
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


func build() -> void:
	_container = Node3D.new()
	_container.name = "Live"
	add_child(_container)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "MonsterSpawner"
	add_child(_spawner)
	_spawner.spawn_path = _spawner.get_path_to(_container)
	_spawner.spawn_function = _create_monster


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
	mesh.filter_baking_aabb = AABB(Vector3(-41, -1, -31), Vector3(82, 6, 80))
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
		if ROSTER[kind]["night"] <= number and SchoolBuilder.AREAS.has(ROSTER[kind]["home"]):
			pool.append(kind)
	pool.shuffle()
	var count := mini(MONSTERS_PER_NIGHT[clampi(number - 1, 0, MONSTERS_PER_NIGHT.size() - 1)], pool.size())
	for i in count:
		tonight.append({"kind": pool[i], "at": randf_range(25.0, 150.0)})
		if pool[i] == "mascot":
			anomalies.reserved_props.append("mascot")
	print("[night] Monsters tonight: ", tonight.map(func(m: Dictionary) -> String: return "%s at %s" % [m["kind"], Night.format_time(m["at"])]))


## Host, every frame during the shift.
func update(minutes: float, delta: float) -> void:
	_track_guard_speeds(delta)
	for plan in tonight:
		if plan.get("started", false) or minutes < plan["at"]:
			continue
		plan["started"] = true
		_start(plan["kind"], minutes)
	lockers.update(minutes)


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
	lockers.reset_all()
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
		if not guard.is_dead and guard.is_inside_tree():
			living.append(guard)
	return living


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
	for camera_index in cameras.shown:
		var camera := cameras.camera(camera_index)
		var to_monster := target - camera.global_position
		if to_monster.length() < 45.0 and (-camera.global_basis.z).angle_to(to_monster) < deg_to_rad(42) \
				and _clear_line(camera.global_position, target, null):
			return true
	return false


func kill(guard: Guard, by: String) -> void:
	if not guard.is_dead:
		guard_caught.emit(guard.name.to_int(), by)


## Sends a message to one player's screen.
func tell(peer_id: int, text: String) -> void:
	message_for.emit(peer_id, text)


## Host: checks a clipboard "Monster" entry. True if a monster this guard hasn't logged yet is
## in that area right now.
func check_log(peer_id: int, area: String) -> bool:
	for monster: Node in _container.get_children():
		if not monster is Monster or monster is Shade:
			continue
		var credited: Array = _credited.get_or_add(monster.name, [])
		if peer_id not in credited and SchoolBuilder.area_at((monster as Monster).global_position) == area:
			credited.append(peer_id)
			return true
	if lockers.active and peer_id not in lockers.credited and lockers.has_open_in(area):
		lockers.credited.append(peer_id)
		return true
	return false


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
		_speeds[guard.name] = Vector2(now.x - before.x, now.z - before.z).length() / delta
		_last_positions[guard.name] = now
