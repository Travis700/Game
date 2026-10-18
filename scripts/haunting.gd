class_name Haunting
extends Node3D
## "Did you hear that?": the building itself acting up, for everyone at once. Every so often,
## somewhere a little way off from one of the guards (and out of their sight if it can be), a
## door slams, a locker bangs, a ball bounces in the empty gym, a phone rings once, someone
## giggles far off, footsteps run away down an empty hall, the pipes knock, or a room's lights
## click on by themselves. Nothing is there. It can't hurt anyone; it's there so a quiet hallway
## never feels quite safe, and so the crew has something to argue about over the radio.
##
## The host picks when and where; every computer plays it at the same spot, with a caption.
## A slow start on a guard's first night, busier as the nights go on and towards 3-5 AM, and
## never in the guard room.

## Real seconds between events, mid-night on an ordinary night (scaled by night and hour).
const EVERY := Vector2(40.0, 90.0)
## How far from the guard it's meant for (metres).
const NEAR := 8.0
const FAR := 25.0
## Nothing before this many in-game minutes past midnight.
const QUIET_START_MINUTES := 15.0
## The events, by name. Each has its own sound and caption (Captions: "Haunt:<name>").
const KINDS: Array[String] = ["door", "locker", "ball", "phone", "giggle", "steps", "pipes", "lights"]
## Somewhere in the empty gym for the ball.
const GYM_SPOTS: Array[Vector3] = [
	Vector3(12, 0.2, -24), Vector3(22, 0.2, -24), Vector3(32, 0.2, -24), Vector3(12, 0.2, -14),
	Vector3(22, 0.2, -14), Vector3(32, 0.2, -14), Vector3(14, 0.2, -5), Vector3(30, 0.2, -5),
]
## Rooms a phone might be ringing in (an extension on a teacher's desk).
const PHONE_ROOMS: Array[String] = ["Front Office", "Room 101", "Room 102", "Room 103", "Nurse's Office",
	"Library", "Science Lab", "Art Room", "Kitchen", "Locker Rooms"]
## The halls footsteps run down: [z, from x, to x].
const HALLS: Array[Array] = [[7.0, -37.0, 37.0], [7.0, -77.0, -43.0], [7.0, 43.0, 77.0]]
## How long running footsteps take to cross their stretch of hall (real seconds), and how far.
const RUN_SECONDS := 2.6
const RUN_DISTANCE := 9.0

var director: MonsterDirector
var night: Night
var power: Power
var school_doors: SchoolDoors
var light_switches: LightSwitches

## Host: real seconds to the next event, and the clock it was last updated at (a new night
## shows up as the clock going backwards).
var _next_in := -1.0
var _last_minutes := INF


## Host, every frame of the shift.
func update(delta: float) -> void:
	if director == null or night == null or not multiplayer.is_server():
		return
	var minutes := night.minutes
	if minutes < _last_minutes or _next_in < 0.0:
		_next_in = _interval(minutes)
	_last_minutes = minutes
	if night.training != null or minutes < QUIET_START_MINUTES:
		return
	_next_in -= delta
	if _next_in > 0.0:
		return
	# Not over the top of something real: a lockdown or the last bell.
	if director.lockdown_left > 0.0 or director.finale or not _haunt():
		_next_in = 10.0
		return
	_next_in = _interval(minutes)


## Host: as a shift ends, the building settles down.
func end_night() -> void:
	_next_in = -1.0
	_last_minutes = INF


## Real seconds to wait for the next event: fewer on night 1, more as the run goes on, and the
## most from 3 to 5 AM.
func _interval(minutes: float) -> float:
	var nights := 0.45 if night.number <= 1 else clampf(0.75 + 0.06 * night.number, 0.75, 1.3)
	var hours := 0.55
	if minutes >= 300.0:
		hours = 0.9
	elif minutes >= 180.0:
		hours = 1.2
	elif minutes >= 120.0:
		hours = 1.0
	elif minutes >= 60.0:
		hours = 0.85
	return randf_range(EVERY.x, EVERY.y) / (nights * hours)


## Host: picks a guard, a kind of event and a spot near them, and sets it off. False if there
## was nowhere suitable this time.
func _haunt() -> bool:
	var guards: Array[Guard] = []
	for guard in director.living_guards():
		if not MonsterDirector.GUARD_ROOM.has_point(guard.global_position):
			guards.append(guard)
	if guards.is_empty():
		return false
	var guard: Guard = guards.pick_random()
	var kinds := KINDS.duplicate()
	kinds.shuffle()
	# Out of the guard's sight if anything is; failing that, anywhere in range will do.
	var fallback := {}
	for kind: String in kinds:
		var best := _pick_spot(kind, guard)
		if best.is_empty():
			continue
		if best["unseen"]:
			_set_off(kind, best["index"], best["at"], guard)
			return true
		if fallback.is_empty():
			fallback = best
			fallback["kind"] = kind
	if fallback.is_empty():
		return false
	_set_off(fallback["kind"], fallback["index"], fallback["at"], guard)
	return true


## A spot for this kind of event near `guard`: {"at", "index" (door or room, else -1),
## "unseen"}, or empty if there's none in range.
func _pick_spot(kind: String, guard: Guard) -> Dictionary:
	var spots := _spots_for(kind)
	var order := range(spots.size())
	order.shuffle()
	var seen := {}
	for i: int in order:
		var at: Vector3 = spots[i]
		if at == Vector3.INF or not _fits(kind, at, guard):
			continue
		if not _in_view(guard, at):
			return {"at": at, "index": i, "unseen": true}
		if seen.is_empty():
			seen = {"at": at, "index": i, "unseen": false}
	return seen


## Every place this kind of event could happen (Vector3.INF for one that can't right now).
func _spots_for(kind: String) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	match kind:
		"door":
			if school_doors:
				for at in school_doors.door_spots():
					spots.append(at + Vector3(0, 1.0, 0) if at != Vector3.INF else at)
		"locker":
			for door: Array in Lockers.DOORS:
				spots.append(Vector3(door[0], 1.0, float(door[1]) + float(door[2]) * 0.3))
		"ball":
			spots.append_array(GYM_SPOTS)
		"phone":
			for room in PHONE_ROOMS:
				spots.append((SchoolBuilder.AREAS[room] as AABB).get_center() + Vector3(0, -1.0, 0))
		"giggle", "pipes":
			for area: String in SchoolBuilder.AREAS:
				if area != "Guard Room" and area != "Front Gate":
					var centre := (SchoolBuilder.AREAS[area] as AABB).get_center()
					centre.y = 3.0 if kind == "pipes" else 1.2
					spots.append(centre)
		"steps":
			for hall: Array in HALLS:
				var x: float = hall[1]
				while x <= float(hall[2]):
					spots.append(Vector3(x, 0.1, float(hall[0])))
					x += 6.0
		"lights":
			# A dark room's lights coming on (not in a power cut: the switches do nothing then).
			if light_switches and (power == null or power.on):
				for room: Dictionary in light_switches._rooms:
					var switch := room["switch"] as Node3D
					var box: AABB = LightSwitches.ROOMS[room["name"]]
					var dark: bool = room["name"] != "Guard Room" and not light_switches.lit_at(box.get_center())
					spots.append(switch.global_position if dark and is_instance_valid(switch) else Vector3.INF)
	return spots


## Is this spot right for an event meant for `guard`: in range, in an open part of the school,
## and not in the guard room?
func _fits(kind: String, at: Vector3, guard: Guard) -> bool:
	var distance := Vector2(at.x - guard.global_position.x, at.z - guard.global_position.z).length()
	# A giggle is always a long way off.
	var near := 15.0 if kind == "giggle" else NEAR
	if distance < near or distance > FAR:
		return false
	if MonsterDirector.GUARD_ROOM.has_point(Vector3(at.x, 1.0, at.z)):
		return false
	return SchoolBuilder.is_open_at(Vector3(at.x, 1.0, at.z), director.difficulty)


## Could this guard see the spot right now (roughly ahead of them, nothing in the way)?
func _in_view(guard: Guard, at: Vector3) -> bool:
	var eye := guard.camera.global_position
	var to := at - eye
	if (-guard.camera.global_basis.z).dot(to.normalized()) < 0.35:
		return false
	var ray := PhysicsRayQueryParameters3D.create(eye, at, 1)
	ray.exclude = [guard.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or (hit["position"] as Vector3).distance_to(at) < 0.8


## Host: sets the chosen event off, for everyone.
func _set_off(kind: String, index: int, at: Vector3, guard: Guard) -> void:
	match kind:
		"door":
			school_doors.haunt_door(index)
		"lights":
			light_switches.flip(index, true)
			_play.rpc(kind, at, at)
		"steps":
			# They run off away from the guard, down the hall.
			var away := signf(at.x - guard.global_position.x)
			if away == 0.0:
				away = 1.0
			_play.rpc(kind, at, at + Vector3(away * RUN_DISTANCE, 0, 0))
		_:
			_play.rpc(kind, at, at)


## Every computer: plays an event at `at` (and, for running footsteps, on to `to`).
@rpc("authority", "call_local", "reliable")
func _play(kind: String, at: Vector3, to: Vector3) -> void:
	if not kind in KINDS:
		return
	var spot := Node3D.new()
	add_child(spot)
	spot.global_position = at
	var keep_for := 5.0
	match kind:
		"locker":
			# Bang, and again.
			var bangs := create_tween()
			for i in 2:
				bangs.tween_callback(func() -> void:
					SoundBank.play_at(spot, "slam_metal", 3.0, 35.0, Sfx.notes([90.0, 60.0], 0.08, 0.6, "noise")))
				bangs.tween_interval(randf_range(0.25, 0.5))
		"ball":
			SoundBank.play_at(spot, "ball_bounce", 0.0, 40.0, Sfx.thud(1.2, 0.12, 0.6))
		"phone":
			# One ring, then nothing.
			var ring := SoundBank.play_at(spot, "phone_ring", -2.0, 35.0, Sfx.notes([440.0, 480.0, 440.0, 480.0], 0.1, 0.25, "square"))
			if ring:
				var cut := ring.create_tween()
				cut.tween_interval(1.8)
				cut.tween_property(ring, "volume_db", -60.0, 0.25)
				cut.tween_callback(ring.stop)
		"giggle":
			SoundBank.play_at(spot, "giggle", -3.0, 45.0, Sfx.notes([900.0, 1100.0, 950.0, 1200.0], 0.08, 0.15, "sine"))
		"steps":
			var run := create_tween()
			run.tween_property(spot, "global_position", to, RUN_SECONDS)
			run.parallel().tween_callback(func() -> void:
				SoundBank.play_at(spot, "rush_steps", 2.0, 35.0, Sfx.thud(1.0, 0.08, 0.6)))
			run.parallel().tween_callback(func() -> void:
				SoundBank.play_at(spot, "rush_steps", 1.0, 35.0, Sfx.thud(1.0, 0.08, 0.6))).set_delay(RUN_SECONDS * 0.5)
		"pipes":
			SoundBank.play_at(spot, "pipe_knock", 0.0, 35.0, Sfx.thud(1.6, 0.06, 0.7))
		"lights":
			# (The switch clicks by itself: LightSwitches plays that.)
			keep_for = 1.0
	get_tree().create_timer(keep_for).timeout.connect(spot.queue_free)
	get_tree().call_group("captions", "heard", "Haunt", kind, at)
