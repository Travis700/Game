class_name Guard
extends CharacterBody3D
## First-person security guard: walking, running, mouse look, flashlight and using things.
##
## Every guard in a session exists on every computer. The node is named after the
## network ID of the player who controls it; only that player's computer moves it,
## and the Sync node copies its position, look direction and flashlight to everyone else.

signal prompt_changed(text: String)
signal message_shown(text: String, seconds: float)
## Keys pressed while sitting at a guard room desk: "prev", "next", "zoom", "stand" or "back".
signal desk_action(action: String)
signal clipboard_requested
## Esc: open the pause menu.
signal pause_requested
## G: use or place whatever the guard is carrying.
signal item_use_requested
## E while hiding in a cupboard: climb out.
signal leave_hiding_requested
## G as a ghost: watch through the next living teammate's eyes (or back to your own).
signal spectate_requested
## Tab as a ghost: open or close the school's cameras. While they're open, "prev" and "next"
## flick between them and "close" shuts them.
signal ghost_cameras_requested(action: String)
## E as a ghost: leave a cold spot where you're looking, for the living to see.
signal ghost_ping_requested(at: Vector3, touched: Object)
## Right click (or T): throw what you picked up off the floor, if anything.
signal throw_requested
## X: put down the thing picked on the hotbar, or hand it to the teammate in front of you.
signal drop_requested
## Q away from the desks: mark the spot you're looking at for the team.
signal mark_requested(at: Vector3)

const WALK_SPEED := 3.2
const SPRINT_SPEED := 5.6
## Right-stick look speed (in the same units as mouse movement, per second).
const STICK_LOOK_SPEED := 1100.0
## Stamina: seconds of running from full, how long before it starts coming back, how fast it
## comes back (fraction a second), and how much has to come back before you can run again.
const STAMINA_SECONDS := 6.0
const STAMINA_DELAY := 1.0
const STAMINA_REGEN := 0.2
const WINDED_UNTIL := 0.3
## Running speed while an energy drink lasts.
const BOOSTED_SPRINT_SPEED := 7.2
const ACCELERATION := 10.0
const LOOK_LIMIT := deg_to_rad(85)
const BOB_AMOUNT := 0.04
const STANDING_EYE_HEIGHT := 1.6
## Crouched (C): eyes this high, this fast, and a body this tall (low enough to duck under a desk).
const CROUCH_EYE_HEIGHT := 0.95
const CROUCH_SPEED := 1.6
const CROUCH_BODY_HEIGHT := 1.1
## Crouched: quieter footsteps. Synced, so everyone sees (and hears) it.
var is_crouching := false
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
## The player's name (their Steam name), or "" to show "Guard 2".
var player_name := ""
## The player's rank (1 = Trainee), from their career. Shown on their name tag; some vending
## machine items need a higher rank.
var rank := 1
## The hat this guard wears (see Hats).
var hat := "cap"
## The perk this guard brought (see Perks).
var perk := "thermos"
## The monsters in this player's field guide (see FieldGuide), sent when they join.
var known_monsters: Array[String] = []
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
## How strong the flashlight's batteries are tonight (1 = fresh; less on an "Old batteries" night).
var battery := 1.0
## Stamina, 0 to 1 (the guard's own computer only). Running uses it up.
var stamina := 1.0
## Out of breath: can't run until stamina is back up to WINDED_UNTIL.
var winded := false
var _rest_for := 0.0
## True while hiding in a cupboard: can look around (not right round), can't move, and monsters
## can't find you.
var hiding := false:
	set(value):
		hiding = value
		_hide_yaw = NAN
## Which way you faced as you got into the cupboard (taken on the first look round).
var _hide_yaw := NAN
const HIDING_YAW_LIMIT := deg_to_rad(70)
## True once this guard has clipped on a walkie-talkie: they can talk on it (B) and hear it.
var has_radio := false
## True once this guard has clipped on an EMF reader: its lights show on their screen.
var has_emf := false
## True while this guard's spirit box is switched on (vending machine). Set by Shop on every
## computer, so everyone near hears it.
var spirit_box_on := false
## True while this ghost is watching the school's cameras (Tab). They stand still meanwhile.
var ghost_watching := false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _bob_time := 0.0
var _footsteps: Footsteps
var _prompt := ""
## The thing E is being held down on (for things that take a moment, like a punch station).
var _holding: Interactable
var _hold_time := 0.0

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
	_dress()
	name_tag.text = _tag_text()

	_footsteps = Footsteps.new()
	_footsteps.name = "Footsteps"
	add_child(_footsteps)
	flashlight.set_meta("base_energy", flashlight.light_energy)
	# A torch's beam, not an even cone: a hot centre and a ring from the reflector, dust in the air.
	flashlight.light_projector = BEAM_PATTERN
	flashlight.spot_angle_attenuation = 0.7
	flashlight.light_volumetric_fog_energy = 0.6
	_beam_basis = flashlight.global_basis
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
	# Your own hat is hidden from your eyes like your body, but the others and the cameras see it.
	_wear_hat(Hats.build(hat, SELF_LAYER if local else 1))
	name_tag.position.y += Hats.height(hat)
	if local:
		# Your own steps, quieter: you mostly hear everyone else's.
		_footsteps.volume_db = -14.0
	set_physics_process(local)
	set_process_unhandled_input(local)
	interact_ray.enabled = local
	interact_ray.collision_mask = 1 | Interactable.TALK_LAYER
	if local:
		interact_ray.add_exception(self)
		_make_dust()
		_make_viewmodel()
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().call_group("game", "on_local_guard_ready", self)


## Fits or removes a personal upgrade ("flashlight" or "radio"). Called on every computer.
func apply_personal(upgrade: String, on: bool) -> void:
	match upgrade:
		"flashlight":
			set_bright_flashlight(on)
		"radio":
			has_radio = on
		"emf":
			has_emf = on or perk == "lookout"


## Fits (or removes) the heavy-duty flashlight. Called on every computer, so everyone sees the beam.
func set_bright_flashlight(on: bool) -> void:
	bright_flashlight = on
	apply_flashlight()


## Sets the beam from the flashlight upgrade and tonight's batteries.
func apply_flashlight() -> void:
	var reach := lerpf(0.6, 1.0, battery) * (1.2 if perk == "spare_batteries" else 1.0)
	flashlight.spot_range = (32.0 if bright_flashlight else 22.0) * reach
	flashlight.spot_angle = 46.0 if bright_flashlight else 38.0
	flashlight.light_energy = flashlight_energy()


## How bright the beam is right now, before any flicker.
func flashlight_energy() -> float:
	return flashlight.get_meta("base_energy", flashlight.light_energy) * (1.5 if bright_flashlight else 1.0) * battery


const BEAM_PATTERN := preload("res://assets/textures/flashlight_cookie.png")
## How quickly the beam catches up with where the guard looks (a hand-held torch trails a little).
const BEAM_FOLLOW := 16.0
var _beam_basis := Basis.IDENTITY


func _process(delta: float) -> void:
	_show_crouch(delta)
	var aim := camera.global_basis.orthonormalized()
	_beam_basis = _beam_basis.slerp(aim, minf(1.0, BEAM_FOLLOW * delta)).orthonormalized()
	flashlight.global_basis = _beam_basis
	if _viewmodel:
		_viewmodel.visible = not is_dead and not hiding and seated_desk < 0
		_viewmodel.global_basis = _beam_basis
		_viewmodel_lens.material_override = _lens_on if flashlight.visible else _lens_off
		_viewmodel_fill.visible = flashlight.visible
	elif not is_local():
		_update_flare()
	# The field of view from the Esc menu (Profile looked up by path, see _look).
	if is_local():
		var profile := get_node_or_null("/root/Profile")
		if profile:
			camera.fov = float(profile.get("fov"))


## Dust hanging in the air round the guard: lit specks, so only seen where a light (mostly the
## flashlight) falls on them. Only made for your own guard.
func _make_dust() -> void:
	var dust := GPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 260
	dust.lifetime = 9.0
	dust.preprocess = 9.0
	dust.local_coords = false
	dust.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 6, 10))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(4.0, 1.6, 4.0)
	motion.direction = Vector3(0, -1, 0)
	motion.spread = 180.0
	motion.initial_velocity_min = 0.0
	motion.initial_velocity_max = 0.05
	motion.gravity = Vector3(0, -0.01, 0)
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 0.4
	motion.turbulence_noise_scale = 3.0
	motion.turbulence_influence_min = 0.02
	motion.turbulence_influence_max = 0.06
	motion.scale_min = 0.5
	motion.scale_max = 1.4
	dust.process_material = motion
	var speck := QuadMesh.new()
	speck.size = Vector2(0.008, 0.008)
	var look := StandardMaterial3D.new()
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	look.albedo_color = Color(0.85, 0.82, 0.75)
	look.roughness = 1.0
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color.a = 0.7
	speck.material = look
	dust.draw_pass_1 = speck
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	camera.add_child(dust)


## Your own arm, bottom right, holding the flashlight: its lens is where the beam comes from.
## Drawn at VIEWMODEL_SIZE and as much closer, so it doesn't poke into walls you stand against,
## and kept off the security cameras.
const VIEWMODEL := preload("res://assets/models/viewmodel_flashlight.glb")
const VIEWMODEL_AT := Vector3(0.11, -0.095, -0.28)
const VIEWMODEL_SIZE := 0.75
var _viewmodel: Node3D
var _viewmodel_lens: MeshInstance3D
var _viewmodel_fill: OmniLight3D
var _lens_on: StandardMaterial3D
var _lens_off: StandardMaterial3D


func _make_viewmodel() -> void:
	_viewmodel = Node3D.new()
	_viewmodel.name = "Viewmodel"
	_viewmodel.position = VIEWMODEL_AT
	camera.add_child(_viewmodel)
	var model := VIEWMODEL.instantiate() as Node3D
	model.scale = Vector3.ONE * VIEWMODEL_SIZE
	_viewmodel.add_child(model)
	# The lens: a disc over the torch's glass, lit while the flashlight is on.
	_lens_on = StandardMaterial3D.new()
	_lens_on.albedo_color = Color(1.0, 0.96, 0.88)
	_lens_on.emission_enabled = true
	_lens_on.emission = Color(1.0, 0.94, 0.82)
	_lens_on.emission_energy_multiplier = 4.0
	_lens_off = StandardMaterial3D.new()
	_lens_off.albedo_color = Color(0.18, 0.18, 0.17)
	_lens_off.metallic = 0.4
	_lens_off.roughness = 0.2
	var disc := CylinderMesh.new()
	disc.top_radius = 0.0136 * VIEWMODEL_SIZE
	disc.bottom_radius = 0.0136 * VIEWMODEL_SIZE
	disc.height = 0.001
	disc.radial_segments = 16
	_viewmodel_lens = MeshInstance3D.new()
	_viewmodel_lens.mesh = disc
	_viewmodel_lens.rotation.x = PI * 0.5
	_viewmodel_lens.position = Vector3(0, 0, -0.001)
	_viewmodel.add_child(_viewmodel_lens)
	for mesh: MeshInstance3D in _viewmodel.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = SecurityCameras.HIDDEN_FROM_CAMERAS
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A little spill from the torch on your own hand (lighting nothing else), so in a dark room
	# it isn't a black shape.
	_viewmodel_fill = OmniLight3D.new()
	_viewmodel_fill.light_cull_mask = SecurityCameras.HIDDEN_FROM_CAMERAS
	_viewmodel_fill.omni_range = 0.8
	_viewmodel_fill.omni_attenuation = 0.5
	_viewmodel_fill.light_energy = 0.25
	_viewmodel_fill.light_color = Color(1.0, 0.92, 0.8)
	# From about where your eyes are, so the side of the hand you see is lit evenly.
	_viewmodel_fill.position = -VIEWMODEL_AT + Vector3(0, 0.05, 0)
	_viewmodel.add_child(_viewmodel_fill)
	# The beam comes out of it.
	flashlight.position = VIEWMODEL_AT + Vector3(0, 0, -0.02)


## Someone else's flashlight, seen from here: a glare on its lens, brighter the more squarely
## it's pointed at you.
var _flare: MeshInstance3D


func _update_flare() -> void:
	if _flare == null:
		_flare = MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(1, 1)
		_flare.mesh = quad
		_flare.material_override = _flare_material()
		_flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flashlight.add_sibling(_flare)
		_flare.position = flashlight.position
	var eye := get_viewport().get_camera_3d()
	var facing := 0.0
	if flashlight.visible and eye and not is_dead:
		var to_eye := eye.global_position - flashlight.global_position
		facing = clampf(((-flashlight.global_basis.z).dot(to_eye.normalized()) - 0.75) / 0.25, 0.0, 1.0)
	_flare.visible = facing > 0.0
	if _flare.visible:
		_flare.scale = Vector3.ONE * lerpf(0.12, 0.7, facing * facing)
		(_flare.material_override as StandardMaterial3D).albedo_color.a = lerpf(0.35, 1.0, facing)


func _flare_material() -> StandardMaterial3D:
	var glow := Gradient.new()
	glow.set_color(0, Color(1.0, 0.97, 0.9, 1.0))
	glow.set_color(1, Color(1.0, 0.9, 0.75, 0.0))
	glow.add_point(0.12, Color(1.0, 0.96, 0.88, 0.9))
	var texture := GradientTexture2D.new()
	texture.gradient = glow
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var look := StandardMaterial3D.new()
	look.albedo_texture = texture
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return look


## Redraws the name tag (e.g. after a promotion).
func refresh_tag() -> void:
	name_tag.text = _tag_text()


## Shows a "talking" marker on the name tag while this guard's voice is coming through.
func show_talking(talking: bool) -> void:
	name_tag.text = _tag_text() + ("\n((( talking )))" if talking else "")


## What to call this guard in messages: their Steam name, or "Guard 2".
func display_name() -> String:
	return player_name if player_name != "" else "Guard %d" % slot


## "Guard 2  #1637", or "Sam (Guard 2)" with a Steam name, and their rank under it.
func _tag_text() -> String:
	var title := Career.rank_title(rank)
	if player_name != "":
		return "%s  (Guard %d)\n%s" % [player_name, slot, title]
	return "Guard %d  #%04d\n%s" % [slot, employee_number, title]


func uniform_color() -> Color:
	return UNIFORM_COLORS[(slot - 1) % UNIFORM_COLORS.size()]


## Called on every computer when this guard is caught or revived.
func set_dead(dead: bool) -> void:
	if dead and is_local():
		is_crouching = false
		_set_body_height(_stand_height)
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


## How tall the guard model stands.
const MODEL_HEIGHT := 1.8

## The guard's 3D model (null: the plain capsule), and its materials, for fading as a ghost.
var _model: Node3D
var _model_materials: Array[BaseMaterial3D] = []
var _strider: Strider


## Puts the guard in uniform: the 3D model, with the shirt in this guard's colour. Without the
## model file it stays the coloured capsule.
func _dress() -> void:
	_model = ModelKit.add(body_mesh, "guard", MODEL_HEIGHT, PI, SELF_LAYER if is_local() else 1)
	if _model == null:
		return
	_model.position.y -= body_mesh.position.y
	_model_floor = _model.position.y
	body_mesh.mesh = null
	visor.mesh = null
	_model_materials = ModelKit.own_materials(_model)
	var shirt := load("res://assets/models/guard_uniform_%d.jpg" % ((slot - 1) % UNIFORM_COLORS.size() + 1)) as Texture2D
	if shirt:
		for material in _model_materials:
			if material.albedo_texture != null:
				material.albedo_texture = shirt
	var moves := ModelKit.moves(_model)
	if moves:
		_strider = Strider.attach(self, moves, MODEL_HEIGHT)


## Where the eyes are on the model, as a share of its height (hats sit relative to eye level).
const MODEL_EYES := 0.935
## Hats were made for the old block head: on a real head they're this much smaller.
const MODEL_HAT_SCALE := 0.6


## On the model's head (so it moves with it), or on the plain head without a model.
func _wear_hat(worn: Node3D) -> void:
	_hat = worn
	_fade_with_body(worn)
	var on_head := ModelKit.bone_anchor(_model, self, "Head", Vector3(0, MODEL_HEIGHT * 100.0 * MODEL_EYES, 1.0)) if _model else null
	if on_head == null:
		head.add_child(worn)
		return
	on_head.add_child(worn)
	worn.scale = Vector3.ONE * MODEL_HAT_SCALE


var _hat: Node3D


## Which camera layers the body, the model and the hat are drawn on: SELF_LAYER to keep them out
## of a camera looking out through these eyes (yours, or a ghost's spectating), 1 otherwise.
func set_body_layers(layers: int) -> void:
	for root: Node in [body_mesh, visor, _hat, _flare]:
		if root == null or not is_instance_valid(root):
			continue
		if root is VisualInstance3D:
			(root as VisualInstance3D).layers = layers
		for part: Node in root.find_children("*", "VisualInstance3D", true, false):
			(part as VisualInstance3D).layers = layers


## The hat's materials join the body's, so a ghost's hat is as faint as the rest of them.
func _fade_with_body(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh := node as MeshInstance3D
		if mesh.material_override is BaseMaterial3D:
			mesh.material_override = mesh.material_override.duplicate()
			_model_materials.append(mesh.material_override)
		elif mesh.mesh:
			for surface in mesh.mesh.get_surface_count():
				var source := mesh.get_active_material(surface) as BaseMaterial3D
				if source:
					var material := source.duplicate() as BaseMaterial3D
					mesh.set_surface_override_material(surface, material)
					_model_materials.append(material)
	for child in node.get_children():
		_fade_with_body(child)


## Shows or hides this guard for the player on this computer. Ghosts are only visible to
## other ghosts, and look faint.
func update_visibility(viewer_is_dead: bool) -> void:
	var material := body_mesh.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if is_dead else BaseMaterial3D.TRANSPARENCY_DISABLED
	material.albedo_color.a = 0.3 if is_dead else 1.0
	for model_material in _model_materials:
		model_material.transparency = material.transparency
		model_material.albedo_color.a = material.albedo_color.a
	if is_local():
		# Your own body only shows on the security cameras, and not at all once you're a ghost.
		body_mesh.visible = not is_dead
		visor.visible = not is_dead
		return
	var shown := (not is_dead or viewer_is_dead) and not hiding
	body_mesh.visible = shown
	visor.visible = shown
	name_tag.visible = shown


## Crouches or stands up (this guard's own computer). Stands only if there's headroom.
func set_crouching(on: bool) -> void:
	if on == is_crouching:
		return
	if not on and not _room_to_stand():
		# (Asked every frame while run is held: say it now and then, not sixty times a second.)
		var now := Time.get_ticks_msec()
		if now - _told_no_room > 2500:
			_told_no_room = now
			message_shown.emit("No room to stand up here.", 2.0)
		return
	is_crouching = on
	_set_body_height(CROUCH_BODY_HEIGHT if on else _stand_height)


var _told_no_room := -100000


## Shrinks or grows the body's capsule (standing on the floor either way).
func _set_body_height(height: float) -> void:
	var collider := $CollisionShape3D as CollisionShape3D
	# The capsule is shared by every guard in the scene file: this one gets its own to shrink.
	if not collider.has_meta("own_shape"):
		collider.shape = collider.shape.duplicate()
		collider.set_meta("own_shape", true)
	var shape := collider.shape as CapsuleShape3D
	shape.height = height
	collider.position.y = shape.height * 0.5


var _stand_height := 1.8


## Is there nothing over a crouched guard's head, up to standing height?
func _room_to_stand() -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var probe := CapsuleShape3D.new()
	probe.radius = ((get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D).radius - 0.01
	probe.height = _stand_height - 0.1
	query.shape = probe
	query.transform = Transform3D(Basis(), global_position + Vector3(0, _stand_height * 0.5 + 0.05, 0))
	query.exclude = [get_rid()]
	query.collision_mask = 1
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## Every computer: a crouched guard's eyes drop (theirs) and their body ducks (everyone else's).
func _show_crouch(delta: float) -> void:
	var low := is_crouching and seated_desk < 0 and not is_dead and not hiding
	# The head (and the torch in it) goes down on every computer, so the beam comes from low too.
	if seated_desk < 0 and not hiding and not _shown_seated:
		head.position.y = lerpf(head.position.y, CROUCH_EYE_HEIGHT if low else STANDING_EYE_HEIGHT, 1.0 - exp(-12.0 * delta))
	if _model:
		# Knees bent (the sitting pose) and lowered, so it reads as a crouch from across a room.
		_model.position.y = lerpf(_model.position.y, _model_floor - (0.42 if low else 0.0), 1.0 - exp(-12.0 * delta))
		if _strider and not _shown_seated:
			_strider.hold = "sit" if low else ""
	name_tag.position.y = lerpf(name_tag.position.y, 1.5 if low else 2.05, 1.0 - exp(-8.0 * delta))


## Where the model stands when upright (its offset under the body mesh).
var _model_floor := 0.0
## Shown sitting at a desk (on every computer; seated_desk is only known to the sitter's).
var _shown_seated := false


## Shows the guard sitting at a desk (everyone's computer), or back on their feet.
func show_seated(on: bool) -> void:
	_shown_seated = on
	if _strider:
		_strider.hold = "sit" if on else ""


## True on the computer of the player controlling this guard.
func is_local() -> bool:
	return is_multiplayer_authority()


## Sits down at a guard room desk, facing its monitors (+Z).
func sit(desk: int, chair_position: Vector3) -> void:
	set_crouching(false)
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
	if ghost_watching:
		_handle_ghost_camera_input(event)
		return
	if event.is_action_pressed("clipboard") and is_dead:
		ghost_cameras_requested.emit("open")
	elif event.is_action_pressed("clipboard"):
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
	elif event.is_action_pressed("ping") and not is_dead and not hiding:
		_mark()
	elif event.is_action_pressed("use_item") and is_dead:
		spectate_requested.emit()
	elif event.is_action_pressed("use_item") and not is_dead and hiding:
		message_shown.emit("Not from inside a cupboard.", 2.5)
	elif event.is_action_pressed("use_item") and not is_dead:
		item_use_requested.emit()
	elif event.is_action_pressed("crouch") and not is_dead and not hiding and seated_desk < 0:
		set_crouching(not is_crouching)
	elif event.is_action_pressed("drop_item") and not is_dead and not hiding and seated_desk < 0:
		drop_requested.emit()
	elif event.is_action_pressed("throw") and not is_dead and not hiding and seated_desk < 0:
		throw_requested.emit()


## Looking around with a controller's right stick.
func _stick_look(delta: float) -> void:
	if input_blocked or look_locked:
		return
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() < 0.15:
		return
	# Curved so small pushes are fine aiming and a full push turns quickly.
	stick = stick.normalized() * pow((stick.length() - 0.15) / 0.85, 1.6)
	_look(stick * STICK_LOOK_SPEED * delta)


func _look(relative: Vector2) -> void:
	# The player's setting from the Esc menu (Profile is an autoload, looked up by path so this
	# script also compiles where autoloads aren't loaded yet).
	var profile := get_node_or_null("/root/Profile")
	var sensitivity := mouse_sensitivity * (float(profile.get("mouse_sensitivity")) if profile else 1.0)
	rotate_y(-relative.x * sensitivity)
	var invert := -1.0 if profile and profile.get("invert_y") else 1.0
	var pitch := head.rotation.x - relative.y * sensitivity * invert
	if seated_desk >= 0:
		# Seated, you can look around your desk but not turn your back on it.
		var yaw := clampf(wrapf(rotation.y - PI, -PI, PI), -SEATED_YAW_LIMIT, SEATED_YAW_LIMIT)
		rotation.y = PI + yaw
		head.rotation.x = clampf(pitch, -SEATED_PITCH_DOWN, SEATED_PITCH_UP)
	else:
		head.rotation.x = clampf(pitch, -LOOK_LIMIT, LOOK_LIMIT)
	if hiding:
		# In a cupboard you can peer out through the slats, not turn round inside it.
		if is_nan(_hide_yaw):
			_hide_yaw = rotation.y + relative.x * sensitivity
		rotation.y = _hide_yaw + clampf(wrapf(rotation.y - _hide_yaw, -PI, PI), -HIDING_YAW_LIMIT, HIDING_YAW_LIMIT)


## A ghost watching the cameras: left / right (or the mouse wheel) flick between them, and Tab
## or Esc goes back. Nothing else works meanwhile (no cold spots from here).
func _handle_ghost_camera_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left") or event.is_action_pressed("slot_prev"):
		ghost_cameras_requested.emit("prev")
	elif event.is_action_pressed("move_right") or event.is_action_pressed("slot_next"):
		ghost_cameras_requested.emit("next")
	elif event.is_action_pressed("clipboard") or event.is_action_pressed("pause"):
		ghost_cameras_requested.emit("close")


## Returns true if the event was a desk control.
func _handle_desk_input(event: InputEvent) -> bool:
	var action := ""
	if event.is_action_pressed("move_left") or event.is_action_pressed("slot_prev"):
		action = "prev"
	elif event.is_action_pressed("move_right") or event.is_action_pressed("slot_next"):
		action = "next"
	elif event.is_action_pressed("zoom"):
		action = "zoom"
	elif event.is_action_pressed("compare"):
		action = "compare"
	elif event.is_action_pressed("ping"):
		action = "ping"
	elif event.is_action_pressed("flashlight") and look_locked:
		action = "lure"
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
	_stick_look(delta)
	_update_hold(delta)
	if seated_desk >= 0:
		_update_prompt()
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta

	var input := Vector2.ZERO
	if not input_blocked and not hiding and not ghost_watching:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var wants_to_run := not input_blocked and not hiding and not ghost_watching and Input.is_action_pressed("sprint") and input.y < 0.0
	# Running stands you up (if there's room).
	if wants_to_run and is_crouching:
		set_crouching(false)
	is_running = wants_to_run and not winded and not is_crouching
	boost_left = maxf(boost_left - delta, 0.0)
	var speed := CROUCH_SPEED if is_crouching else WALK_SPEED
	if is_running:
		speed = BOOSTED_SPRINT_SPEED if boost_left > 0.0 else SPRINT_SPEED

	var blend := 1.0 - exp(-ACCELERATION * delta)
	velocity.x = lerpf(velocity.x, direction.x * speed, blend)
	velocity.z = lerpf(velocity.z, direction.z * speed, blend)
	move_and_slide()
	# Pushing into a wall isn't running: no stamina spent, and no noise for monsters to hear.
	if is_running and Vector2(get_real_velocity().x, get_real_velocity().z).length() < WALK_SPEED * 0.8:
		is_running = false
	_update_stamina(delta)

	_update_head_bob(delta, input.length() > 0.1)
	_update_prompt()


func _update_stamina(delta: float) -> void:
	if is_running and boost_left <= 0.0:
		stamina = maxf(stamina - delta / (STAMINA_SECONDS * (1.5 if perk == "track_star" else 1.0)), 0.0)
		_rest_for = 0.0
		if stamina <= 0.0:
			winded = true
	else:
		_rest_for += delta
		if _rest_for > STAMINA_DELAY:
			stamina = minf(stamina + STAMINA_REGEN * delta, 1.0)
	if winded and stamina >= WINDED_UNTIL:
		winded = false
	_update_panting(delta)


## Out of breath, you hear yourself gasping (only you: it's on this computer), fading as you
## get your breath back.
var _panting: AudioStreamPlayer


func _update_panting(delta: float) -> void:
	var gasping := (winded or stamina < 0.25) and not is_dead
	if _panting == null:
		if not gasping:
			return
		_panting = AudioStreamPlayer.new()
		_panting.bus = &"SFX"
		_panting.stream = SoundBank.get_sound("panting", null, true)
		_panting.volume_db = -60.0
		add_child(_panting)
	var target := lerpf(-8.0, -20.0, clampf(stamina / 0.3, 0.0, 1.0)) if gasping else -60.0
	_panting.volume_db = move_toward(_panting.volume_db, target, delta * 30.0)
	if _panting.volume_db > -59.0 and not _panting.playing and _panting.stream:
		_panting.play()
	elif _panting.volume_db <= -59.0 and _panting.playing:
		_panting.stop()


func show_message(text: String, seconds := -1.0) -> void:
	message_shown.emit(text, seconds)


func _update_head_bob(delta: float, moving: bool) -> void:
	if moving and is_on_floor():
		var speed := Vector2(velocity.x, velocity.z).length()
		_bob_time += delta * speed * 2.2
		# Off in the comfort settings (Profile is an autoload, looked up by path).
		var profile := get_node_or_null("/root/Profile")
		var amount := BOB_AMOUNT if profile == null or profile.get("head_bob") else 0.0
		camera.position.y = sin(_bob_time) * amount
		camera.position.x = cos(_bob_time * 0.5) * amount * 0.6
	else:
		camera.position = camera.position.lerp(Vector3.ZERO, 1.0 - exp(-8.0 * delta))


func focused_interactable() -> Interactable:
	return interact_ray.get_collider() as Interactable


func _update_prompt() -> void:
	var target := focused_interactable() if not is_dead else null
	var text := "[%s] " % KeyText.key("interact") + target.prompt if target else ""
	if target and target.hold_seconds > 0.0:
		if target == _holding:
			var filled := mini(int(_hold_time / _hold_needed(target) * 10.0), 10)
			text += "   " + "|".repeat(filled) + ".".repeat(10 - filled)
		else:
			text = "[Hold %s] " % KeyText.key("interact") + target.prompt
	if text != _prompt:
		_prompt = text
		prompt_changed.emit(text)


func _interact() -> void:
	if is_dead:
		_ghost_ping()
		return
	if hiding:
		leave_hiding_requested.emit()
		return
	var target := focused_interactable()
	if target and target.hold_seconds > 0.0:
		_holding = target
		_hold_time = 0.0
	elif target:
		target.interact(self)


## Marks whatever is in front of you, up to 40 metres away.
func _mark() -> void:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 40.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | Interactable.TALK_LAYER | Monster.LAYER)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	mark_requested.emit(hit["position"] + (hit["normal"] as Vector3) * 0.2 if not hit.is_empty() else to)


## Where a ghost is looking: the first thing within 25 metres, or 25 metres out.
func _ghost_ping() -> void:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 25.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | Interactable.TALK_LAYER)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var at: Vector3 = hit["position"] + (hit["normal"] as Vector3) * 0.3 if not hit.is_empty() else to
	ghost_ping_requested.emit(at, hit.get("collider"))


## How long E has to be held on this (Handy guards are quicker).
func _hold_needed(target: Interactable) -> float:
	return target.hold_seconds * (0.5 if perk == "handy" else 1.0)


## Counts up while E stays held on the same thing, and uses it once it's been held long enough.
func _update_hold(delta: float) -> void:
	if _holding == null:
		return
	if is_dead or input_blocked or not Input.is_action_pressed("interact") \
			or not is_instance_valid(_holding) or focused_interactable() != _holding:
		_holding = null
		return
	_hold_time += delta
	if _hold_time >= _hold_needed(_holding):
		var target := _holding
		_holding = null
		target.interact(self)
