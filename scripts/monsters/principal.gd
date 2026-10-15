class_name Principal
extends Monster
## The Principal. Most of the night it's only a voice on the intercom, calling one guard to
## the front office. If they don't come in time, it comes out of the office to find them.
## The summons themselves are run by the MonsterDirector; this is the Principal on the move.

const SPEED := 3.7
const HUNT_TIME := 50.0

var target_peer := 0
var _left := HUNT_TIME


func _init() -> void:
	display_name = "the Principal"
	state = "hunt"


func think(delta: float) -> void:
	_left -= delta
	var target := director.guard_by_peer(target_peer)
	if target == null or target.is_dead:
		director.principal_done(self)
		return
	if _left <= 0.0:
		director.principal_done(self, target_peer)
		return
	move_to(target.global_position, SPEED)
	catch_nearby()


func _build_body() -> void:
	part(capsule(0.3, 1.95), Color(0.14, 0.14, 0.16), Vector3(0, 0.98, 0))
	part(box(Vector3(0.08, 0.5, 0.04)), Color(0.55, 0.05, 0.05), Vector3(0, 1.45, -0.29))
	part(box(Vector3(0.22, 0.18, 0.04)), Color(0.9, 0.9, 0.9), Vector3(0, 1.62, -0.27))
	part(sphere(0.16), Color(0.7, 0.62, 0.55), Vector3(0, 2.08, 0))
	part(box(Vector3(0.26, 0.05, 0.02)), Color(0.02, 0.02, 0.02), Vector3(0, 2.1, -0.15))
