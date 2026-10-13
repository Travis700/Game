class_name Monster
extends CharacterBody3D
## Base for every monster with a body.
##
## The host runs each monster's behaviour (think) and moves it around the school with
## Godot's navigation. Everyone else just shows it where the host says, through the Sync node,
## and reacts to `state` changes with animations and sounds.

## Monsters live on physics layer 4, so they never block guards or line-of-sight checks.
const LAYER := 1 << 3
const KILL_DISTANCE := 1.1
const GRAVITY := 9.8

var director: MonsterDirector
## Shown in death messages, e.g. "Caught by the Hall Monitor."
var display_name := "Something"
## What the monster is doing ("patrol", "chase"...). Copied to every computer.
var state := "":
	set(value):
		if value == state:
			return
		state = value
		if is_inside_tree():
			_on_state_changed(value)

var _agent: NavigationAgent3D


func _ready() -> void:
	collision_layer = LAYER
	collision_mask = 1
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.9
	add_child(collider)

	_agent = NavigationAgent3D.new()
	_agent.radius = 0.4
	# The walkable surface Godot builds sits a little above the floor; this keeps the agent
	# from treating that height gap as distance still to cover.
	_agent.path_height_offset = 0.5
	_agent.path_desired_distance = 1.0
	_agent.target_desired_distance = 0.8
	add_child(_agent)

	_build_body()
	_add_sync()
	set_physics_process(multiplayer.is_server())
	_on_state_changed(state)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	think(delta)


## The monster's behaviour, run on the host every physics frame. Override this.
func think(_delta: float) -> void:
	pass


## Builds the monster's look out of simple shapes. Override this.
func _build_body() -> void:
	pass


## Reacts to a new state on every computer, e.g. to play a sound. Override as needed.
func _on_state_changed(_new_state: String) -> void:
	pass


# --- Helpers for behaviours (host) ----------------------------------------------------

## Walks toward `target` along the navigation mesh. Returns false if the way is barred,
## e.g. the guard room before night 7.
func move_to(target: Vector3, speed: float) -> bool:
	_agent.target_position = target
	if _agent.is_navigation_finished():
		halt()
		return true
	var next := _agent.get_next_path_position()
	if not director.may_enter(next):
		halt()
		return false
	var direction := next - global_position
	direction.y = 0.0
	if direction.length() > 0.05:
		direction = direction.normalized()
		face(direction)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()
	return true


func halt() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	move_and_slide()


## Turns smoothly to face a direction on the ground.
func face(direction: Vector3) -> void:
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 0.2)


func distance_to_guard(guard: Guard) -> float:
	return global_position.distance_to(guard.global_position)


## Catches any living guard within reach. Returns true if it caught someone.
func catch_nearby() -> bool:
	for guard in director.living_guards():
		if distance_to_guard(guard) < KILL_DISTANCE:
			director.kill(guard, display_name)
			return true
	return false


## Roughly where its eyes are, for line-of-sight checks.
func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


# --- Building blocks -----------------------------------------------------------------

func part(mesh: Mesh, color: Color, offset: Vector3, glow := 0.0, alpha := 1.0) -> MeshInstance3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.roughness = 0.9
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	if alpha < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = offset
	add_child(instance)
	return instance


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


func _add_sync() -> void:
	var config := SceneReplicationConfig.new()
	for path: String in [".:position", ".:rotation", ".:state"]:
		config.add_property(path)
		config.property_set_spawn(path, false)
		config.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE
				if path == ".:state" else SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_config = config
	add_child(sync)
