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
## Esc: open the pause menu.
signal pause_requested
## G: use or place whatever the guard is carrying.
signal item_use_requested

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
## Running speed while an energy drink lasts.
const BOOSTED_SPRINT_SPEED := 7.2
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
## The number on this guard's badge, typed into the time clock. Set by the host when it spawns.
var employee_number := 0
## The guard room desk this guard is sitting at, or -1 when standing.
var seated_desk := -1
## Mouse look is paused while a camera feed fills the screen.
var look_locked := false
## True once a monster has caught this guard. Ghosts can walk and watch, but can't use anything,
## and only other ghosts can see them.
var is_dead := false
## True while a menu like the clipboard has the mouse: the guard stands still and ignores keys.
var input_blocked := false
## Real seconds of energy drink left (faster running). Only used by the guard's own computer.
var boost_left := 0.0
## True once this guard has fitted the heavy-duty flashlight: a longer, wider beam.
var bright_flashlight := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _footsteps: Footsteps
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
	uniform.albedo_color = uniform_color()
	body_mesh.material_override = uniform
	name_tag.text = "Guard %d  #%04d" % [slot, employee_number]

	_footsteps = Footsteps.new()
	_footsteps.name = "Footsteps"
	add_child(_footsteps)
	flashlight.set_meta("base_energy", flashlight.light_energy)
	# The Shadows setting (Profile is an autoload; looked up by path, see _look).
	flashlight.add_to_group("shadow_lights")
	var profile := get_node_or_null("/root/Profile")
	if profile:
		flashlight.shadow_enabled = bool(profile.get("shadows"))
	if bright_flashlight:
		set_bright_flashlight(true)
	var local := is_local()
	# Your own body is hidden from your own eyes but still shows up on the cameras.
	if local:
		body_mesh.layers = SELF_LAYER
		visor.layers = SELF_LAYER
		camera.cull_mask &= ~SELF_LAYER
		# The living can't see the Ghost with their own eyes.
		camera.cull_mask &= ~SecurityCameras.SPECTRAL_LAYER
	name_tag.visible = not local
	if local:
		# Your own steps, quieter: you mostly hear everyone else's.
		_footsteps.volume_db = -14.0
	set_physics_process(local)
	set_process_unhandled_input(local)
	interact_ray.enabled = local
	interact_ray.collision_mask = 1 | Interactable.TALK_LAYER
	if local:
		interact_ray.add_exception(self)
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().call_group("game", "on_local_guard_ready", self)


## Fits (or removes) the heavy-duty flashlight. Called on every computer, so everyone sees the beam.
func set_bright_flashlight(on: bool) -> void:
	bright_flashlight = on
	flashlight.spot_range = 32.0 if on else 22.0
	flashlight.spot_angle = 34.0 if on else 26.0
	flashlight.light_energy = flashlight.get_meta("base_energy", flashlight.light_energy) * (1.5 if on else 1.0)


## Shows a "talking" marker on the name tag while this guard's voice is coming through.
func show_talking(talking: bool) -> void:
	var base := "Guard %d  #%04d" % [slot, employee_number]
	name_tag.text = base + ("\n((( talking )))" if talking else "")


func uniform_color() -> Color:
	return UNIFORM_COLORS[(slot - 1) % UNIFORM_COLORS.size()]


## Called on every computer when this guard is caught or revived.
func set_dead(dead: bool) -> void:
	is_dead = dead
	# Ghosts make no sound.
	_footsteps.enabled = not dead
	if dead:
		flashlight.visible = false
		is_running = false
	interact_ray.enabled = is_local() and not dead
	if is_local():
		# Once you're a ghost yourself, you can see the other one.
		if dead:
			camera.cull_mask |= SecurityCameras.SPECTRAL_LAYER
		else:
			camera.cull_mask &= ~SecurityCameras.SPECTRAL_LAYER


## Shows or hides this guard for the player on this computer. Ghosts are only visible to
## other ghosts, and look faint.
func update_visibility(viewer_is_dead: bool) -> void:
	var material := body_mesh.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_dead else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color.a = 0.3 if is_dead else 1.0
	if is_local():
		# Your own body only shows on the security cameras, and not at all once you're a ghost.
		body_mesh.visible = not is_dead
		visor.visible = not is_dead
		return
	var shown := not is_dead or viewer_is_dead
	body_mesh.visible = shown
	visor.visible = shown
	name_tag.visible = shown


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
	interact_ray.collision_mask = 1 | Interactable.TALK_LAYER


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
		pause_requested.emit()
	elif event.is_action_pressed("flashlight") and not is_dead:
		flashlight.visible = not flashlight.visible
	elif event.is_action_pressed("interact"):
		_interact()
	elif event.is_action_pressed("use_item") and not is_dead:
		item_use_requested.emit()


func _look(relative: Vector2) -> void:
	# The player's setting from the Esc menu (Profile is an autoload, looked up by path so this
	# script also compiles where autoloads aren't loaded yet).
	var profile := get_node_or_null("/root/Profile")
	var sensitivity := mouse_sensitivity * (float(profile.get("mouse_sensitivity")) if profile else 1.0)
	rotate_y(-relative.x * sensitivity)
	var pitch := head.rotation.x - relative.y * sensitivity
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
	else:
		for number in range(1, 5):
			if event.is_action_pressed("monitor_%d" % number):
				action = "monitor_%d" % number
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
	boost_left = maxf(boost_left - delta, 0.0)
	var speed := WALK_SPEED
	if is_running:
		speed = BOOSTED_SPRINT_SPEED if boost_left > 0.0 else SPRINT_SPEED

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
	var target := focused_interactable() if not is_dead else null
	var text := "[E] " + target.prompt if target else ""
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _interact() -> void:
	if is_dead:
		return
	var target := focused_interactable()
	if target:
		target.interact(self)
