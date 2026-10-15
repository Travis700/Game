class_name MonsterDirector
extends Node3D
## Decides which monsters come out each night and when, and gives them what they need:
## a navigation mesh to walk on, who's alive, who can see what, and catching guards.
##
## Each monster has a home area and can only appear if that area is open tonight: the
## classroom wing's monsters need difficulty 2, the science wing's need difficulty 3. The host runs all of this; monsters
## are spawned on every computer through the MonsterSpawner.

## A guard's screen flashes (e.g. the Photographer's flash). Main shows it on their computer.
## A lockdown started or ended (everyone hears the alarm).
signal lockdown_changed(on: bool)
signal screen_flashed(peer_id: int, color: Color, seconds: float)
signal guard_caught(peer_id: int, by: String, from: Vector3)
signal message_for(peer_id: int, text: String)
## Something everyone hears, e.g. the Principal on the intercom. `sound` is "" or "intercom".
signal announcement(text: String, sound: String)
## A guard walked a real lost student to safety.
signal student_helped(peer_id: int)
## A camera lost or got back its signal (the Ghost passing by).
signal camera_signal_changed(camera_index: int, working: bool)
## The school bell started or stopped ringing.
signal bell_changed(ringing: bool)
## The Principal gave up on a guard who never came to the office (and is still alive).
signal principal_ignored(peer_id: int)

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
	"photographer": {"name": "The Photographer", "home": "Lobby", "night": 3},
	"twins": {"name": "The Twins", "home": "Room 101", "night": 2},
	"coach": {"name": "The Coach", "home": "Locker Rooms", "night": 2},
}
## Lockdown: from this night the alarm can go, and for LOCKDOWN_SECONDS (real) every monster
## hunts the nearest guard it can reach, wherever they are. Hide, or get to the guard room.
const LOCKDOWN_FROM_NIGHT := 6
const LOCKDOWN_SECONDS := 30.0
const LOCKDOWN_SPEED := 3.6
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
const BELL_FROM_NIGHT := 5
const BELL_SPEED := 1.35
const BELL_MAX_SECONDS := 60.0
## Monster moods (see Monster.MOODS): from this night, and how often.
const MOODS_FROM_NIGHT := 5
const MOOD_CHANCE := 0.45

var players: Node3D
var guard_room: GuardRoom
var cameras: SecurityCameras
var anomalies: Anomalies
var lockers: Lockers
var school: SchoolBuilder
var portrait: SelfPortrait
var career: Career
## Voice chat, so the Understudy can copy what guards said. Host only.
var voice: VoiceChat
## Tonight's conditions (a full moon, sound carrying...). Host only.
var conditions: Conditions
## Real seconds of lockdown left (0 when there isn't one). Host only.
var lockdown_left := 0.0
## How fast monsters hunt in a lockdown (the finale speeds it up). Host only.
var hunt_speed := LOCKDOWN_SPEED
## The last night's last hour: one long lockdown, and guards out through the gate are out of reach.
var finale := false
## The finale's gate is open: guards out in the street are out of reach.
var gate_open := false
## Host: peer id -> when their close-call grace runs out (real seconds).
var _grace: Dictionary = {}
## Host: tonight_summary() as it was at the end of the night.
var tonight_report := ""
## Host: monster kinds someone logged tonight (for the report).
var _logged_tonight: Dictionary = {}
var _stare_timer := 1.0
## Each second a watched monster is on a monitor, the chance it looks into the camera.
const STARE_CHANCE := 0.04
const STARE_SECONDS := 2.5
## Host: the monsters each night of this run brought, by night number (see plan_night).
var _run_history: Dictionary = {}
## Host: the mood of the monster being started right now (see update and spawn).
var _starting_mood := ""
var _lockdown_times: Array[float] = []
## Everyone's nerve. Host only.
var nerve: Nerve
## Host: whether the last correct Monster log was the first guard to log that monster.
var last_log_was_first := true
## Host: recent loud noises: [position, until (real seconds)].
var _noises: Array = []

var night_number := 1
## Host: how many guards started tonight (set by Night before plan_night).
var team_size := 1
## Where guards stand still to do the job: punch stations and the breaker. Set by Main.
var work_spots: Array[Vector3] = []
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
## Voice chat, host only: peer -> {"until": seconds, "level": 0-1} while that guard is talking.
var _voices: Dictionary = {}
## How long a voice counts as "still talking" after its last packet.
const VOICE_LINGER := 0.4


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
	# A deck, not a lottery: monsters this run hasn't shown yet come first, and nothing turns up
	# three nights running.
	if number <= 1:
		_run_history.clear()
	var weight := {}
	for kind: String in pool:
		var seen: bool = _run_history.keys().any(func(night: int) -> bool: return night < number and kind in _run_history[night])
		var twice: bool = kind in _run_history.get(number - 1, []) and kind in _run_history.get(number - 2, [])
		weight[kind] = randf() + (3.0 if twice else 0.0) - (0.6 if not seen else 0.0)
	pool.sort_custom(func(a: String, b: String) -> bool: return weight[a] < weight[b])
	# Bigger maps (for bigger teams) bring one more monster per open wing.
	# One more per open wing, but only for teams big enough to cover them.
	var wanted := MONSTERS_PER_NIGHT[clampi(number - 1, 0, MONSTERS_PER_NIGHT.size() - 1)] + mini(difficulty, team_size) - 1
	if conditions and conditions.has("hazard_pay"):
		wanted += 1
	# Overtime: one more for every night past the last.
	wanted += clampi(number - MONSTERS_PER_NIGHT.size(), 0, 5)
	var count := mini(wanted, pool.size())
	for i in count:
		tonight.append({"kind": pool[i], "at": randf_range(25.0, 220.0)})
		if pool[i] == "mascot":
			anomalies.reserved_props.append("mascot")
	# Night 1: the first monster turns up early, so a new guard meets one before they've settled in.
	if number == 1 and count >= 1:
		tonight[0]["at"] = randf_range(30.0, 60.0)
	# From night 2, one of them comes in late (around 4 AM), so the night builds to the end.
	if number >= 2 and count >= 2:
		tonight[count - 1]["at"] = randf_range(235.0, 255.0)
		tonight[count - 1]["late"] = true
	# The Bell rings once or twice a night from night 4.
	_bell_times.clear()
	if number >= BELL_FROM_NIGHT:
		# Twice a night from night 8 (not 7, when the guard room opens: one new thing at a time).
		for i in (1 if number < 8 else 2):
			_bell_times.append(randf_range(60.0, 300.0))
		_bell_times.sort()
	# Lockdowns: once a night from night 6, twice from night 9 (and Overtime).
	_lockdown_times.clear()
	_logged_tonight.clear()
	lockdown_left = 0.0
	hunt_speed = LOCKDOWN_SPEED
	finale = false
	gate_open = false
	if number >= LOCKDOWN_FROM_NIGHT:
		for i in (1 if number < 9 else 2):
			_lockdown_times.append(randf_range(90.0, 320.0))
	if conditions and conditions.has("drill"):
		_lockdown_times.append(randf_range(60.0, 300.0))
	_lockdown_times.sort()
	# An early start: everything's out by about 2 AM, the latecomer included.
	if conditions and conditions.has("early_start"):
		for plan in tonight:
			plan["at"] = minf(float(plan["at"]) * 0.5, 115.0)
			plan.erase("late")
	# Camera faults: a third of the open cameras are dead all night.
	if conditions and conditions.has("camera_fault"):
		var open: Array[int] = []
		for i in cameras.count():
			if cameras.is_open(i):
				open.append(i)
		open.shuffle()
		for i in open.slice(0, open.size() / 3):
			_blackouts[i] = INF
			camera_signal_changed.emit(i, false)
	_run_history[number] = tonight.map(func(plan: Dictionary) -> String: return plan["kind"])
	# Moods (and whether a student is real) are settled now, while a daily shift's dice are
	# still the same for everyone.
	for plan in tonight:
		if number >= MOODS_FROM_NIGHT and plan["kind"] not in ["student", "ghost", "locker_thing", "self_portrait", "principal"] \
				and randf() < MOOD_CHANCE:
			plan["mood"] = Monster.MOODS.keys().pick_random()
		if plan["kind"] == "student":
			plan["real"] = randf() < 0.2
	# The real night cleaner works every night, unless they've called in sick.
	if not (conditions and conditions.has("messy")):
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
		_starting_mood = plan.get("mood", "")
		_start(plan["kind"], minutes, plan)
		_starting_mood = ""
		if plan.get("late", false):
			announcement.emit("Something else just came into the building. It's not on anyone's rota.", "")
	lockers.update(minutes)
	portrait.update(minutes)
	_update_bell(minutes, delta)
	_stare_timer -= delta
	if _stare_timer <= 0.0:
		_stare_timer = 1.0
		_camera_stares()
	_update_lockdown(minutes, delta)
	_update_principal(minutes, delta)
	for camera_index: int in _blackouts.keys():
		if minutes >= _blackouts[camera_index]:
			_blackouts.erase(camera_index)
			camera_signal_changed.emit(camera_index, true)


## The field guide kind for each planned monster.
const GUIDE_KINDS := {
	"hall_monitor": "HallMonitor", "mascot": "Mascot", "lunch_lady": "LunchLady", "locker_thing": "Lockers",
	"principal": "Principal", "other_cleaner": "OtherCleaner", "student": "Student", "ghost": "SchoolGhost",
	"substitute": "Substitute", "librarian": "Librarian", "nurse": "Nurse", "crossing_guard": "CrossingGuard",
	"self_portrait": "SelfPortrait", "specimen": "Specimen", "understudy": "Understudy",
	"photographer": "Photographer", "twins": "Twin", "coach": "Coach",
}


## Host: for the night report. Which monsters came out tonight, and whether anyone logged each:
## "the Hall Monitor (logged)", "the Mascot (nobody logged it)".
func tonight_summary() -> String:
	var lines: Array[String] = []
	for plan in tonight:
		# (The Principal is mostly a voice: not something you could have logged.)
		if not plan.get("started", false) or not GUIDE_KINDS.has(plan["kind"]) or plan["kind"] == "principal":
			continue
		var kind: String = GUIDE_KINDS[plan["kind"]]
		lines.append("%s (%s)" % [FieldGuide.display_name(kind), "logged" if kind in _logged_tonight else "nobody logged it"])
	return "" if lines.is_empty() else "Out tonight: " + ", ".join(lines) + "."


func _start(kind: String, minutes: float, plan := {}) -> void:
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
			spawn("student", Vector3(randf_range(-30.0, 30.0), 0, 7), {"real": plan.get("real", false)})
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
		"photographer":
			spawn("photographer", Vector3(0, 0, 15))
		"coach":
			spawn("coach", Vector3(66, 0, 15))
		"twins":
			spawn("twin", Vector3(-47, 0, 15))
			spawn("twin", Vector3(-61, 0, 15))
			var twins: Array = _container.get_children().filter(func(m: Node) -> bool:
				return m is Twin and (m as Twin).sibling == null)
			if twins.size() >= 2:
				twins[-2].sibling = twins[-1]
				twins[-1].sibling = twins[-2]
		"understudy":
			spawn("understudy", Vector3(50, 0, 15))


func spawn(kind: String, at: Vector3, extra := {}) -> void:
	var data := {"kind": kind, "id": _next_id, "position": at}
	data.merge(extra)
	# Planned in plan_night: some come in out of sorts.
	if _starting_mood != "" and not data.has("mood"):
		data["mood"] = _starting_mood
	_next_id += 1
	_spawner.spawn(data)


## Host: a bad roll at a totem lets a shade out to hunt whoever rolled.
func summon_shade(at: Vector3, target_peer: int) -> void:
	# A little way off, not right on top of whoever rolled.
	var away := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * 8.0
	var map := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map) > 0:
		at = NavigationServer3D.map_get_closest_point(map, at + away)
	spawn("shade", at, {"target": target_peer})


func remove_monster(monster: Monster) -> void:
	monster.queue_free()


## Host: 6 AM, everything goes back where it came from.
func end_night() -> void:
	finale = false
	gate_open = false
	hunt_speed = LOCKDOWN_SPEED
	if lockdown_left > 0.0:
		lockdown_left = 0.0
		lockdown_changed.emit(false)
	_lockdown_times.clear()
	for monster in _container.get_children():
		monster.queue_free()
	# Kept for the night report, which comes after.
	tonight_report = tonight_summary()
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
		"photographer":
			monster = Photographer.new()
		"twin":
			monster = Twin.new()
		"coach":
			monster = Coach.new()
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
	monster.set_mood(data.get("mood", ""))
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
		if may_enter(guard.global_position) and not guard.hiding and not is_gone(guard):
			result.append(guard)
	return result


## Host: a guard who just had a close call can't be gone after for a few seconds.
func give_grace(peer_id: int, seconds: float) -> void:
	_grace[peer_id] = Time.get_ticks_msec() / 1000.0 + seconds


## Out through the gate in the finale: out of reach.
func is_gone(guard: Guard) -> bool:
	if _grace.has(guard.name.to_int()) and Time.get_ticks_msec() / 1000.0 < float(_grace[guard.name.to_int()]):
		return true
	return gate_open and Finale.is_out(guard.global_position)


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
		if distance < best_distance and may_enter(guard.global_position) and not guard.hiding and not is_gone(guard):
			best = guard
			best_distance = distance
	return best


func guard_near(point: Vector3, distance: float) -> bool:
	for guard: Guard in players.get_children():
		if not guard.is_dead and guard.global_position.distance_to(point) < distance:
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
	# The monitors only watch anything if someone's sitting at them: just that desk's four.
	if guard_room == null:
		return false
	for feed_key in guard_room.watched_feeds():
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


## Is this guard at a place where the job means standing still for a moment (a punch station,
## the breaker)? Set up by Main.
func at_work_spot(guard: Guard) -> bool:
	for spot in work_spots:
		if Vector2(guard.global_position.x - spot.x, guard.global_position.z - spot.z).length() < 2.5:
			return true
	return false


## Is this guard sitting at a guard room desk? (Works for every guard, on the host.)
func is_seated(guard: Guard) -> bool:
	return guard.name.to_int() in guard_room.occupants


## True while a Crossing Guard that can see this guard is holding up its STOP sign.
func stop_sign_up_for(guard: Guard) -> bool:
	for node in _container.get_children():
		if node is CrossingGuard and (node as Monster).state == "stop" \
				and (node as Monster).distance_to_guard(guard) < CrossingGuard.SIGHT_RANGE \
				and can_see((node as Monster).eye_position(), guard):
			return true
	return false


## True while a Crossing Guard is holding up its STOP sign (everyone should be standing still).
func stop_sign_up() -> bool:
	for node in _container.get_children():
		if node is CrossingGuard and (node as Monster).state == "stop":
			return true
	return false


## How much faster monsters move right now (the Bell).
func speed_multiplier() -> float:
	var moon := Conditions.FULL_MOON_SPEED if conditions and conditions.has("full_moon") else 1.0
	return (BELL_SPEED if bell_ringing else 1.0) * moon


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


## Host: the finale. The alarm goes and doesn't stop until 6 AM.
func start_finale() -> void:
	finale = true
	_lockdown_times.clear()
	if lockdown_left <= 0.0:
		lockdown_changed.emit(true)
	lockdown_left = INF


func _update_lockdown(minutes: float, delta: float) -> void:
	if finale:
		return
	if lockdown_left > 0.0:
		lockdown_left -= delta
		if lockdown_left <= 0.0:
			lockdown_left = 0.0
			lockdown_changed.emit(false)
			if career:
				for guard in living_guards():
					if guard.hiding:
						career.award(guard.name.to_int(), "HIDE_AND_SEEK")
			announcement.emit("The alarm stops. Whatever was hunting goes back to what it was doing.", "")
		return
	if not _lockdown_times.is_empty() and minutes >= _lockdown_times[0]:
		_lockdown_times.pop_front()
		lockdown_left = LOCKDOWN_SECONDS
		lockdown_changed.emit(true)
		announcement.emit("LOCKDOWN. Every one of them is hunting. Hide in a cupboard or get to the guard room.", "")


## Host: now and then, a monster on a monitor someone's watching stops and looks straight into
## the camera. Once a night each, never mid-chase.
func _camera_stares() -> void:
	if guard_room == null:
		return
	for feed_key in guard_room.watched_feeds():
		var camera_index: int = feed_key / 2
		if not cameras.is_working(camera_index):
			continue
		var lens := cameras.camera(camera_index)
		for monster in active_monsters():
			if monster.stared or monster is Mascot or monster is Twin or "chase" in monster.state \
					or "hunt" in monster.state or monster.stuck_in_trap > 0.0:
				continue
			var head := monster.global_position + Vector3(0, 1.4, 0)
			if head.distance_to(lens.global_position) > 20.0 or not lens.is_position_in_frustum(head) \
					or not _clear_line(lens.global_position, head, null):
				continue
			if randf() < STARE_CHANCE:
				monster.stare_at(lens.global_position, STARE_SECONDS)


## Host: someone shut the bell off at the panel (or it stopped by itself).
func stop_bell() -> void:
	if bell_ringing:
		bell_changed.emit(false)


## Host: a "Missing object" log in the gym while the Mascot is off its stand counts as
## spotting it (the empty stand is exactly what the Gym camera shows).
func check_mascot_missing(peer_id: int, area: String) -> bool:
	if area != "Gym":
		return false
	for node in _container.get_children():
		if node is Mascot and not node.is_queued_for_deletion() \
				and (node as Node3D).global_position.distance_to(MASCOT_STAND) > 2.0:
			# Its own list: logging the Mascot as a Monster is a separate find.
			var credited: Array = _credited.get_or_add(str(node.name) + ":missing", [])
			if peer_id in credited:
				return false
			last_log_was_first = credited.is_empty()
			credited.append(peer_id)
			if career:
				career.logged_monster(peer_id, "Mascot")
			return true
	return false


## Host: a guard's voice packet arrived (or the host is talking). `loudness` is 0-1.
func report_voice(peer_id: int, loudness: float) -> void:
	var guard := guard_by_peer(peer_id)
	if guard == null or guard.is_dead:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var entry: Dictionary = _voices.get_or_add(peer_id, {"until": 0.0, "level": 0.0})
	# Remember the loudest bit of the last moment, not just the latest packet.
	entry["level"] = loudness if now > entry["until"] else maxf(entry["level"] * 0.9, loudness)
	entry["until"] = now + VOICE_LINGER


## How loud a guard is talking right now: 0 when they're quiet. Host only.
func voice_level(guard: Guard) -> float:
	var entry: Dictionary = _voices.get(guard.name.to_int(), {})
	if entry.is_empty() or Time.get_ticks_msec() / 1000.0 > entry["until"]:
		return 0.0
	return entry["level"]


## How far away a monster can hear this guard talking: from `whisper` (barely talking) to
## `shout`. 0 when they're quiet. Host only.
func voice_reach(guard: Guard, whisper: float, shout: float) -> float:
	var level := voice_level(guard)
	var carries := 1.5 if conditions and conditions.has("sharp_ears") else 1.0
	return 0.0 if level <= 0.0 else lerpf(whisper, shout, level) * carries


## Tonight's clock, in in-game minutes. Host only.
func minutes() -> float:
	return _minutes


## `from` is where the thing that caught them is (for the jumpscare), or Vector3.INF.
func kill(guard: Guard, by: String, from := Vector3.INF) -> void:
	if not guard.is_dead:
		guard_caught.emit(guard.name.to_int(), by, from)


## Sends a message to one player's screen.
## How much further than usual monsters notice this guard (their nerve).
func nerve_reach(guard: Guard) -> float:
	return nerve.reach_factor(guard) if nerve else 1.0


## Host: a loud noise somewhere (e.g. a camera speaker), for monsters that hunt by sound.
func make_noise(at: Vector3, seconds := 6.0) -> void:
	_noises.append([at, _minutes_clock() + seconds])


## Host: the newest noise still going within `reach` of `from`, or Vector3.INF.
func noise_near(from: Vector3, reach: float) -> Vector3:
	var now := _minutes_clock()
	var found := Vector3.INF
	for noise: Array in _noises:
		if float(noise[1]) >= now and (noise[0] as Vector3).distance_to(from) < reach:
			found = noise[0]
	_noises = _noises.filter(func(noise: Array) -> bool: return float(noise[1]) >= now)
	return found


func _minutes_clock() -> float:
	return Time.get_ticks_msec() / 1000.0


func flash_screen(peer_id: int, color: Color, seconds: float) -> void:
	screen_flashed.emit(peer_id, color, seconds)


func tell(peer_id: int, text: String) -> void:
	message_for.emit(peer_id, text)


## Host: checks a clipboard "Monster" entry. Returns the kind of monster (e.g. "LunchLady") this
## guard hasn't logged yet that's in that area right now, or "" if there isn't one. If several
## are there, the one the guard `named` counts first.
func check_log(peer_id: int, area: String, named := "") -> String:
	var found: Array[Monster] = []
	for node: Node in _container.get_children():
		var monster := node as Monster
		if monster == null or (monster.harmless and not monster.practice) or monster.is_queued_for_deletion() or not monster.loggable():
			continue
		var credited: Array = _credited.get_or_add(monster.name, [])
		if peer_id not in credited and SchoolBuilder.area_at(monster.global_position) == area:
			found.append(monster)
	if not found.is_empty():
		var monster: Monster = found[0]
		for each in found:
			if each.get_script().get_global_name() == named:
				monster = each
		var kind: String = monster.get_script().get_global_name()
		last_log_was_first = (_credited[monster.name] as Array).is_empty()
		_logged_tonight[kind] = true
		if monster.mood != "":
			var mood_line: String = Monster.MOODS[monster.mood]["tell"] % (monster.display_name.left(1).to_upper() + monster.display_name.substr(1))
			get_tree().create_timer(1.5).timeout.connect(func() -> void: tell(peer_id, mood_line))
		_credited[monster.name].append(peer_id)
		if career:
			career.logged_monster(peer_id, kind)
		if monster.leaves_when_logged:
			# Found out, it slips away.
			get_tree().create_timer(2.0).timeout.connect(func() -> void:
				if is_instance_valid(monster):
					remove_monster(monster))
		return kind
	if portrait.active and portrait.stage > 0 and area == "Art Room" and peer_id not in portrait.credited:
		last_log_was_first = portrait.credited.is_empty()
		_logged_tonight["SelfPortrait"] = true
		portrait.credited.append(peer_id)
		if career:
			career.logged_monster(peer_id, "SelfPortrait")
		return "SelfPortrait"
	if lockers.active and peer_id not in lockers.credited and lockers.has_open_in(area):
		last_log_was_first = lockers.credited.is_empty()
		_logged_tonight["Lockers"] = true
		lockers.credited.append(peer_id)
		if career:
			career.logged_monster(peer_id, "Lockers")
		return "Lockers"
	return ""


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
	var before := _summon_left
	_summon_left -= delta
	if before > 15.0 and _summon_left <= 15.0:
		announcement.emit("The intercom crackles: \"Guard %d. I'm waiting.\"" % summoned.slot, "intercom")
	if _summon_left <= 0.0:
		announcement.emit("The intercom crackles: \"Then I'll come to you, Guard %d.\"" % summoned.slot, "intercom")
		_principal_out = true
		spawn("principal", FRONT_OFFICE, {"target": _summoned})
		_summoned = 0


## Called by the Principal when it gives up and goes back to its office.
func principal_done(principal: Monster, ignored_by := 0) -> void:
	if ignored_by != 0:
		principal_ignored.emit(ignored_by)
	remove_monster(principal)
	_principal_out = false
	_next_summon = _minutes + randf_range(SUMMON_EVERY.x, SUMMON_EVERY.y)


## Called by the Ghost every frame: cameras near it lose their signal for a while.
func ghost_passing(at: Vector3, distance: float) -> void:
	for i in cameras.count():
		if not cameras.is_open(i):
			continue
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


## Measured over a fifth of a second rather than one frame: other players' positions arrive in
## steps, so a single frame can look like standing still (or a jump).
const SPEED_WINDOW := 0.2


func _track_guard_speeds(delta: float) -> void:
	if delta <= 0.0:
		return
	var time := Time.get_ticks_msec() / 1000.0
	for guard: Guard in players.get_children():
		var now := guard.global_position
		var sample: Array = _last_positions.get(guard.name, [now, time])
		var elapsed := time - float(sample[1])
		if elapsed < SPEED_WINDOW and _last_positions.has(guard.name):
			continue
		var before: Vector3 = sample[0]
		var speed := Vector2(now.x - before.x, now.z - before.z).length() / maxf(elapsed, delta)
		# Faster than anyone can run means a teleport (sitting down, standing up, a revive),
		# not movement.
		_speeds[guard.name] = 0.0 if speed > 12.0 else speed
		_last_positions[guard.name] = [now, time]
