class_name Guard
extends CharacterBody3D
## First-person security guard: walking, running, mouse look, flashlight and using things.

signal prompt_changed(text: String)
signal message_shown(text: String)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
const ACCELERATION := 10.0
const LOOK_LIMIT := deg_to_rad(85)
const BOB_AMOUNT := 0.04

@export var mouse_sensitivity := 0.0025

## True while the guard is running. Monsters like the Hall Monitor will react to this.
var is_running := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _prompt := ""

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var flashlight: SpotLight3D = $Head/Camera3D/Flashlight
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay


func _ready() -> void:
	interact_ray.add_exception(self)
	flashlight.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * mouse_sensitivity, -LOOK_LIMIT, LOOK_LIMIT)
	elif event is InputEventMouseButton and event.is_pressed() and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("pause"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("flashlight"):
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("interact"):
		_interact()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	is_running = Input.is_action_pressed("sprint") and input.y < 0.0
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


func _focused_interactable() -> Interactable:
	return interact_ray.get_collider() as Interactable


func _update_prompt() -> void:
	var target := _focused_interactable()
	var text := "[E] " + target.prompt if target else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _interact() -> void:
	var target := _focused_interactable()
	if target:
		target.interact(self)
