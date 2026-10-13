class_name Specimen
extends Monster
## The Specimen: whatever was floating in the big jar in the science lab. Pale, low to the
## ground, too many legs. It crawls after the nearest guard in the dark.
##
## It can't stand light. Catch it in your flashlight beam and it scuttles off into the ceiling,
## then drops out somewhere else a while later. The Librarian hates that flashlight, though.

const CRAWL_SPEED := 3.0
const FLEE_SPEED := 6.0
const LIGHT_RANGE := 12.0
## Real seconds it stays hidden in the ceiling.
const HIDE_SECONDS := Vector2(20.0, 40.0)
const HIDING_PLACES: Array[Vector3] = [
	Vector3(51, 0, -6), Vector3(71, 0, -8), Vector3(56, 0, 16), Vector3(60, 0, 7), Vector3(45, 0, 7),
	Vector3(-60, 0, 7), Vector3(-70, 0, -2), Vector3(-49, 0, -5), Vector3(-47, 0, 14),
	Vector3(25, 0, 7), Vector3(-25, 0, 7), Vector3(-20, 0, -12), Vector3(22, 0, -12), Vector3(-13, 0, 15),
]

var _hide_left := 0.0
var _flee_to := Vector3.ZERO


func _init() -> void:
	display_name = "the Specimen"
	state = "crawl"


func _ready() -> void:
	super()
	# The jar in the science lab is empty now, its lid knocked off.
	var jar := director.school.specimen_jar if director.school else null
	if jar and jar.get_child_count() > 1:
		var lid := jar.get_child(1) as Node3D
		lid.position = Vector3(0.3, 0.05, 0.2)
		lid.rotation_degrees = Vector3(80, 20, 0)
		(jar.get_child(0) as MeshInstance3D).transparency = 0.6


func loggable() -> bool:
	return state != "hidden"


func think(delta: float) -> void:
	match state:
		"flee":
			if not move_to(_flee_to, FLEE_SPEED) or arrived() or is_stuck():
				_hide_left = randf_range(HIDE_SECONDS.x, HIDE_SECONDS.y)
				state = "hidden"
		"hidden":
			halt()
			_hide_left -= delta
			if _hide_left <= 0.0:
				var spot := _drop_spot()
				if spot != Vector3.INF:
					global_position = spot
					state = "crawl"
				else:
					_hide_left = 5.0
		_:
			if is_lit(LIGHT_RANGE):
				_flee_to = _nearest_hiding_place()
				state = "flee"
				return
			var guard := director.nearest_living_guard(global_position)
			if guard == null:
				halt()
				return
			move_to(guard.global_position, CRAWL_SPEED)
			catch_nearby()


func _nearest_hiding_place() -> Vector3:
	var best := global_position
	var best_distance := INF
	for spot in _open_places():
		var distance := global_position.distance_to(spot)
		if distance > 6.0 and distance < best_distance:
			best = spot
			best_distance = distance
	return best


## Somewhere out of sight, not too close to anyone, but close enough to go hunting again.
func _drop_spot() -> Vector3:
	var spots := _open_places()
	spots.shuffle()
	for spot in spots:
		var nearest := INF
		for guard in director.living_guards():
			nearest = minf(nearest, spot.distance_to(guard.global_position))
		if nearest > 12.0 and nearest < 40.0:
			return spot
	return Vector3.INF


func _open_places() -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for spot in HIDING_PLACES:
		if SchoolBuilder.is_open_at(spot, director.difficulty):
			spots.append(spot)
	return spots


## Hidden in the ceiling, it can't be seen.
func _on_state_changed(new_state: String) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = new_state != "hidden"
	if new_state == "flee":
		Sfx.play_at(self, Sfx.notes([900.0, 1400.0, 700.0], 0.07, 0.25, "saw"), 0.0, 25.0)


func _build_body() -> void:
	var skin := Color(0.78, 0.76, 0.66)
	var torso := part(capsule(0.2, 1.0), skin, Vector3(0, 0.3, 0))
	torso.rotation_degrees.x = 90.0
	part(sphere(0.17), skin, Vector3(0, 0.38, -0.55))
	for side: float in [-1.0, 1.0]:
		part(sphere(0.03), Color(0.5, 1.0, 0.4), Vector3(side * 0.07, 0.45, -0.7), 3.0)
		for i in 4:
			var leg := part(box(Vector3(0.45, 0.04, 0.04)), skin.darkened(0.2), Vector3(side * 0.3, 0.15, -0.3 + i * 0.22))
			leg.rotation_degrees.z = side * -35.0
