class_name NightCleaner
extends Monster
## The night cleaner: a harmless school employee pushing a mop cart from room to room.
## Things they move around are just cleaning, not anomalies.
##
## From night 5 a second "cleaner" can turn up (OtherCleaner). Telling them apart on the
## cameras is the point: the real one always has their cart.

const WALK_SPEED := 1.3
const ROUTE: Array[Vector3] = [
	Vector3(0, 0, 15), Vector3(-13, 0, 15), Vector3(-25, 0, 7), Vector3(-22, 0, -10),
	Vector3(0, 0, -20), Vector3(25, 0, 7), Vector3(22, 0, -12), Vector3(0, 0, -5),
]

var _stop := 0
var _pause := 0.0


func _init() -> void:
	display_name = "the night cleaner"
	harmless = true
	state = "walk"


func think(delta: float) -> void:
	_wander(delta)


func _wander(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		halt()
		return
	var spot := ROUTE[_stop]
	if Vector2(global_position.x - spot.x, global_position.z - spot.z).length() < 1.2:
		# Mop for a while, then move on to another room.
		_pause = randf_range(6.0, 12.0)
		_stop = (_stop + 1 + randi() % 3) % ROUTE.size()
		state = "mop"
		return
	state = "walk"
	move_to(spot, WALK_SPEED)


func _build_body() -> void:
	_build_person(true)


func _build_person(with_cart: bool) -> void:
	part(capsule(0.28, 1.65), Color(0.32, 0.4, 0.5), Vector3(0, 0.83, 0))
	part(sphere(0.15), Color(0.72, 0.6, 0.5), Vector3(0, 1.78, 0))
	part(box(Vector3(0.3, 0.08, 0.32)), Color(0.12, 0.15, 0.25), Vector3(0, 1.9, -0.03))
	for side: float in [-1.0, 1.0]:
		part(sphere(0.07), Color(0.95, 0.85, 0.1), Vector3(side * 0.3, 1.0, -0.15))
	if with_cart:
		part(box(Vector3(0.6, 0.5, 0.5)), Color(0.95, 0.8, 0.1), Vector3(0, 0.3, -0.75))
		part(box(Vector3(0.04, 1.3, 0.04)), Color(0.5, 0.4, 0.3), Vector3(0.22, 0.95, -0.75))
		part(box(Vector3(0.25, 0.12, 0.12)), Color(0.85, 0.85, 0.8), Vector3(0.22, 0.3, -0.95))
