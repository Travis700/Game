class_name Mascot
extends Monster
## The Mascot: the school's bulldog costume, which steps down from its stand in the gym.
## It only moves while nobody is watching it, in person or on a guard room monitor.
## Keep it on a screen and it stays put.

const SPEED := 3.8


func _init() -> void:
	display_name = "the Mascot"
	# Big padded feet.
	footstep_pitch = 0.6
	footstep_volume = 2.0
	state = "frozen"


var _watched := false
var _look_again := 0.0


func think(delta: float) -> void:
	# Checking every guard and camera is a lot of rays, so look ten times a second.
	_look_again -= delta
	if _look_again <= 0.0:
		_look_again = 0.1
		_watched = director.is_watched(self)
	if _watched:
		halt()
		state = "frozen"
		return
	state = "moving"
	var guard := director.nearest_living_guard(global_position)
	if guard == null:
		halt()
		return
	move_to(guard.global_position, SPEED)
	catch_nearby()


func _build_body() -> void:
	var fur := Color(0.45, 0.32, 0.2)
	part(capsule(0.4, 1.7), fur, Vector3(0, 0.85, 0))
	part(box(Vector3(0.62, 0.52, 0.56)), fur, Vector3(0, 1.88, 0))
	for side: float in [-1.0, 1.0]:
		part(box(Vector3(0.14, 0.18, 0.06)), fur.darkened(0.3), Vector3(side * 0.26, 2.18, 0.05))
		part(sphere(0.06), Color(0.02, 0.02, 0.02), Vector3(side * 0.14, 1.98, -0.28))
	part(box(Vector3(0.32, 0.2, 0.14)), Color(0.85, 0.82, 0.75), Vector3(0, 1.8, -0.32))
	part(box(Vector3(0.26, 0.04, 0.02)), Color(0.5, 0.05, 0.05), Vector3(0, 1.73, -0.4))
