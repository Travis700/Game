class_name Glare
extends Node3D
## Being blinded by a teammate's flashlight: when another guard's beam points into your eyes
## (you're in the middle of it, close enough, nothing between you, and you're looking their
## way), the picture washes out round their torch. Each computer works out its own.

## How much of the beam's cone counts as "in your eyes", and how much of its reach.
const CONE_SHARE := 0.55
const RANGE_SHARE := 0.8
## How fast the glare comes on and wears off (per second).
const RISE := 6.0
const FALL := 2.5

## The guards. Set by Main.
var players: Node3D
var hud: CanvasLayer
## The local guard. Set by Main.
var local_guard: Guard

var _amount := 0.0
## Where on screen the torch was last seen (the glare fades out there).
var _at := Vector2.ZERO


func _process(delta: float) -> void:
	var target := 0.0
	var eye := get_viewport().get_camera_3d()
	if eye and local_guard and is_instance_valid(local_guard) and players:
		for node in players.get_children():
			var other := node as Guard
			if other == null or other == local_guard or other.is_dead or not other.flashlight.visible:
				continue
			var light := other.flashlight
			var from := light.global_position
			var to_eye := eye.global_position - from
			var distance := to_eye.length()
			var reach := light.spot_range * RANGE_SHARE
			if distance > reach or distance < 0.05:
				continue
			var angle := (-light.global_basis.z).angle_to(to_eye)
			var cone := deg_to_rad(light.spot_angle) * CONE_SHARE
			if angle > cone:
				continue
			# Only if you're facing the light.
			var facing := (-eye.global_basis.z).dot(-to_eye / distance)
			if facing < 0.3:
				continue
			var query := PhysicsRayQueryParameters3D.create(from, eye.global_position, 1)
			query.exclude = [other.get_rid(), local_guard.get_rid()]
			if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
				continue
			var amount := (1.0 - angle / cone) * (1.0 - distance / reach) * clampf((facing - 0.3) / 0.5, 0.0, 1.0)
			amount *= light.light_energy / maxf(other.flashlight_energy(), 0.01)
			if amount > target:
				target = amount
				_at = eye.unproject_position(from)
	_amount = move_toward(_amount, clampf(target * 1.6, 0.0, 1.0), delta * (RISE if target * 1.6 > _amount else FALL))
	hud.set_glare(_amount, _at)
