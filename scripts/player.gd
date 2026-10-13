class_name Guard
extends CharacterBody3D
## First-person security guard: walking, running, mouse look, flashlight and using things.
##
## Every guard in a session exists on every computer. The node is named after the
## network ID of the player who controls it; only that player's computer moves it,
## and the Sync node copies its position, look direction and flashlight to everyone else.

signal prompt_changed(text: String)
signal message_shown(text: String)
## Keys pressed while sitting at a guard room desk: "prev", "next", "zoom", "stand" or "back".
signal desk_action(action: String)
signal clipboard_requested

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
const ACCELERATION := 10.0
const LOOK_LIMIT := deg_to_rad(85)
const BOB_AMOUNT := 0.04
const STANDING_EYE_HEIGHT := 1.6
const SEATED_EYE_HEIGHT := 1.22
const SEATED_YAW_LIMIT := deg_to_rad(60)
const SEATED_PITCH_UP := deg_to_rad(30)
const SEATED_PITCH_DOWN := deg_to_rad(35)
## Your own body is drawn on this layer: hidden from your eyes, but visible on the security cameras.
const SELF_LAYER := 1 << 10
const UNIFORM_COLORS: Array[Color] = [
	Color(0.2, 0.3, 0.55), Color(0.55, 0.25, 0.2), Color(0.25, 0.45, 0.25), Color(0.5, 0.42, 0.18),
]

@export var mouse_sensitivity := 0.0025

## True while the guard is running. Monsters like the Hall Monitor will react to this.
var is_running := false
## Which of the four guard slots this is (1-4). Chosen by the host when the guard spawns.
var slot := 1
## The guard room desk this guard is sitting at, or -1 when standing.
var seated_desk := -1
## Mouse look is paused while a camera feed fills the screen.
var look_locked := false
## True while a menu like the clipboard has the mouse: the guard stands still and ignores keys.
var input_blocked := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _prompt := ""

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var body_mesh: MeshInstance3D = $Body
@onready var visor: MeshInstance3D = $Head/Visor
@onready var name_tag: Label3D = $NameTag


func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())


func _ready() -> void:
	var uniform := StandardMaterial3D.new()
	uniform.albedo_color = UNIFORM_COLORS[(slot - 1) % UNIFORM_COLORS.size()]
	body_mesh.material_override = uniform
	name_tag.text = "Guard %d" % slot

	var local := is_local()
	# Your own body is hidden from your own eyes but still shows up on the cameras.
	if local:
		body_mesh.layers = SELF_LAYER
		visor.layers = SELF_LAYER
		camera.cull_mask &= ~SELF_LAYER
	name_tag.visible = not local
	set_physics_process(local)
	set_process_unhandled_input(local)
	interact_ray.enabled = local
	if local:
		interact_ray.add_exception(self)
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().call_group("game", "on_local_guard_ready", self)


## True on the computer of the player controlling this guard.
func is_local() -> bool:
	return is_multiplayer_authority()


## Sits down at a guard room desk, facing its monitors (+Z).
func sit(desk: int, chair_position: Vector3) -> void:
	seated_desk = desk
	velocity = Vector3.ZERO
	is_running = false
	global_position = chair_position
	rotation.y = PI
	head.rotation.x = 0.0
	head.position.y = SEATED_EYE_HEIGHT
	camera.position = Vector3.ZERO
	interact_ray.collision_mask = GuardRoom.MONITOR_LAYER


func stand(at: Vector3) -> void:
	seated_desk = -1
	look_locked = false
	head.position.y = STANDING_EYE_HEIGHT
	global_position = at
	interact_ray.collision_mask = 1


func _unhandled_input(event: InputEvent) -> void:
	if input_blocked:
		return
	if event.is_action_pressed("clipboard"):
		clipboard_requested.emit()
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if not look_locked:
			_look((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif seated_desk >= 0 and _handle_desk_input(event):
		pass
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("interact"):
		_interact()


func _look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	var pitch := head.rotation.x - relative.y * mouse_sensitivity
	if seated_desk >= 0:
		# Seated, you can look around your desk but not turn your back on it.
		var yaw := clampf(wrapf(rotation.y - PI, -PI, PI), -SEATED_YAW_LIMIT, SEATED_YAW_LIMIT)
		rotation.y = PI + yaw
		head.rotation.x = clampf(pitch, -SEATED_PITCH_DOWN, SEATED_PITCH_UP)
	else:
		head.rotation.x = clampf(pitch, -LOOK_LIMIT, LOOK_LIMIT)


## Returns true if the event was a desk control.
func _handle_desk_input(event: InputEvent) -> bool:
	var action := ""
	if event.is_action_pressed("move_left"):
		action = "prev"
	elif event.is_action_pressed("move_right"):
		action = "next"
	elif event.is_action_pressed("zoom"):
		action = "zoom"
	elif event.is_action_pressed("move_back"):
		action = "stand"
	elif event.is_action_pressed("pause") and look_locked:
		action = "back"
	if action == "":
		return false
	desk_action.emit(action)
	return true


func _physics_process(delta: float) -> void:
	if seated_desk >= 0:
		_update_prompt()
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Vector2.ZERO
	if not input_blocked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	is_running = not input_blocked and Input.is_action_pressed("sprint") and input.y < 0.0
	var speed := SPRINT_SPEED if is_running else WALK_SPEED

	var blend := 1.0 - exp(-ACCELERATION * delta)
	velocity.x = lerpf(velocity.x, direction.x * speed, blend)
	velocity.z = lerpf(velocity.z, direction.z * speed, blend)
	move_and_slide()

	_update_head_bob(delta, input.length() > 0.1)
	_update_prompt()


func show_message(text: String) -> void:
	message_shown.emit(text)


func _update_head_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		var speed := Vector2(velocity.x, velocity.z).length()
		_bob_time += delta * speed * 2.2
		camera.position.y = sin(_bob_time) * BOB_AMOUNT
		camera.position.x = cos(_bob_time * 0.5) * BOB_AMOUNT * 0.6
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))


func focused_interactable() -> Interactable:
	return interact_ray.get_collider() as Interactable


func _update_prompt() -> void:
	var target := focused_interactable()
	var text := "[E] " + target.prompt if target else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _interact() -> void:
	var target := focused_interactable()
	if target:
		target.interact(self)
