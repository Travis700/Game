class_name SchoolGhost
extends Monster
## The Ghost: a guard who worked here long ago and still clocks in. Nobody can see it with
## their own eyes. Only monitors with the spectral camera upgrade show it (and other ghosts can
## see it, once they've been caught). It drifts straight through walls toward the living,
## and cameras it passes close to lose their signal for a while.

const SPEED := 1.4
const BLACKOUT_DISTANCE := 9.0


func _init() -> void:
	display_name = "something you couldn't see"
	visual_layers = SecurityCameras.SPECTRAL_LAYER
	state = "drift"


func _ready() -> void:
	super._ready()
	# It passes through everything.
	collision_layer = 0
	collision_mask = 0


func think(delta: float) -> void:
	var target := director.nearest_living_guard(global_position)
	if target == null:
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	if to_target.length() > 0.1:
		var step := to_target.normalized() * SPEED * delta
		var next := global_position + step
		if director.may_enter(next):
			global_position = next
		face(to_target)
	director.ghost_passing(global_position, BLACKOUT_DISTANCE)
	catch_nearby()


func _build_body() -> void:
	var pale := Color(0.75, 0.85, 1.0)
	part(capsule(0.33, 1.75), pale, Vector3(0, 0.88, 0), 1.2, 0.55)
	part(sphere(0.16), pale, Vector3(0, 1.85, 0), 1.5, 0.6)
	part(box(Vector3(0.36, 0.1, 0.12)), Color(0.4, 0.5, 0.7), Vector3(0, 1.88, -0.12), 1.0, 0.6)
	for side: float in [-1.0, 1.0]:
		part(sphere(0.025), Color(0.05, 0.05, 0.1), Vector3(side * 0.06, 1.87, -0.15))
