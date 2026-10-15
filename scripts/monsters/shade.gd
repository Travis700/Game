class_name Shade
extends Monster
## What crawls out of a revive totem on a bad roll: a dark shape that hunts the guard who
## rolled the dice, then fades away after a while.

const SPEED := 4.4
const LIFETIME := 25.0
const RISE_SECONDS := 1.5

## Network ID of the guard it's after.
var target_peer := 0
var _age := 0.0


func _init() -> void:
	hunts_in_lockdown = false
	display_name = "the shade from the totem"
	state = "rise"


## Something let out of a totem isn't one of the school's monsters, so it can't be logged.
func loggable() -> bool:
	return false


func think(delta: float) -> void:
	_age += delta
	if _age > LIFETIME:
		director.remove_monster(self)
		return
	# It takes a moment to pull itself together: a head start to run.
	if _age < RISE_SECONDS:
		halt()
		return
	state = "hunt"
	var target := director.guard_by_peer(target_peer)
	if target == null or target.is_dead:
		target = director.nearest_living_guard(global_position)
	if target == null:
		halt()
		return
	move_to(target.global_position, SPEED)
	catch_nearby()


func _build_body() -> void:
	part(capsule(0.3, 1.8), Color(0.03, 0.02, 0.05), Vector3(0, 0.9, 0), 0.0, 0.85)
	for side: float in [-1.0, 1.0]:
		part(sphere(0.03), Color(0.7, 0.3, 1.0), Vector3(side * 0.08, 1.6, -0.27), 3.0)
