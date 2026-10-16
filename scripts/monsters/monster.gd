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
## The Bell never pushes a monster faster than this (just under a guard's running speed),
## so every chase can still be outrun.
const BELL_SPEED_CAP := 5.4
## Moods: from night 5 a monster can come in out of sorts. Same rules, different numbers, and
## a correct log tells you which. pace scales its speed, senses how far off it notices guards.
const MOODS := {
	"restless": {"pace": 1.15, "senses": 1.0, "tell": "%s seems restless tonight: quicker on its feet, and it won't stay put."},
	"keen": {"pace": 1.0, "senses": 1.25, "tell": "%s seems keen tonight: it'll notice you from further off."},
	"drowsy": {"pace": 0.85, "senses": 0.85, "tell": "%s seems drowsy tonight: slower, and slower to notice. Don't count on it."},
}

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
			get_tree().call_group("captions", "heard", get_script().get_global_name(), value, global_position)

## Render layers for the monster's body, e.g. the Ghost only shows on spectral camera feeds.
var visual_layers := 1
## Harmless characters (the real night cleaner, a real student) can't be logged as monsters.
var harmless := false
## Training's Hall Monitor: harmless, but it can be logged, for practice.
var practice := false
## Some monsters slip away once a guard logs them on the clipboard (e.g. the Other Cleaner).
var leaves_when_logged := false
## Footstep sound: lower pitch for heavy things, higher for small ones. Silent ones float.
var footstep_pitch := 1.0
var footstep_stride := 0.8
var footstep_volume := -2.0
var silent := false
## Joins in when the lockdown alarm goes (the Ghost and the Shade have their own ways).
var hunts_in_lockdown := true
## What it was doing before a lockdown, to go back to afterwards. Host only.
var _pre_lockdown_state := ""
## Pushes an EMF reader to its top level (EMF 5) up close. Evidence for the field guide.
var emf5 := false
## Host: staring into a camera (see stare_at), and whether it already has tonight.
var stared := false
var _stare_at := Vector3.ZERO
var _stare_left := 0.0
## Tonight's mood ("" for none; see MOODS).
var mood := ""
var pace := 1.0
var senses := 1.0

var _agent: NavigationAgent3D
## Real seconds it has been trying to move without getting anywhere.
var _stuck_for := 0.0
## Real seconds left stuck fast in a glue trap. Host only.
var stuck_in_trap := 0.0


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
	if not silent:
		var steps := Footsteps.new()
		steps.pitch = footstep_pitch
		steps.stride = footstep_stride
		steps.volume_db = footstep_volume
		steps.reach = 28.0
		add_child(steps)
	_add_sync()
	set_physics_process(multiplayer.is_server())
	_on_state_changed(state)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	if stuck_in_trap > 0.0:
		stuck_in_trap -= delta
		halt()
		return
	# Caught on camera, it stops and looks straight back down the lens.
	if _stare_left > 0.0:
		_stare_left -= delta
		halt()
		face(_stare_at - global_position)
		return
	if director.lockdown_left > 0.0 and hunts_in_lockdown and not harmless:
		if _pre_lockdown_state == "":
			_pre_lockdown_state = state
		_lockdown_hunt()
		return
	if _pre_lockdown_state != "":
		state = _pre_lockdown_state
		_pre_lockdown_state = ""
	think(delta)


var _drill_look := 0.0
var _drill_watched := false


## Lockdown: straight for the nearest guard it can reach (following the drill's rule, if any).
func _lockdown_hunt() -> void:
	if director.drill == "watched":
		_drill_look -= get_physics_process_delta_time()
		if _drill_look <= 0.0:
			_drill_look = 0.1
			_drill_watched = director.is_watched(self)
		if _drill_watched:
			halt()
			return
	var guard := director.lockdown_target(global_position)
	if guard == null:
		halt()
		return
	state = "hunt"
	move_to(guard.global_position, director.hunt_speed)
	catch_nearby()


## The monster's behaviour, run on the host every physics frame. Override this.
func think(_delta: float) -> void:
	pass


## Builds the monster's look out of simple shapes. Override this.
func _build_body() -> void:
	pass


# A rigged model's walk/run animations, driven by how fast it's really moving (every computer).
var _moves: AnimationPlayer
var _model: Node3D
var _model_height := 0.0
var _last_spot := Vector3.INF
var _pace_seen := 0.0


## Uses assets/models/<name>.glb for the body if it's there. False means build the blocks.
func use_model(model_name: String, height: float) -> bool:
	var model := ModelKit.add(self, model_name, height, PI, visual_layers)
	if model == null:
		return false
	_model = model
	_moves = ModelKit.moves(model)
	_model_height = height
	# Stand in the walk's first frame rather than the stiff arms-out pose it was rigged in.
	if _moves != null:
		_moves.play("walk")
		_moves.seek(0.0, true)
		_moves.pause()
	return true


## The rigged model's skeleton, or null for a block body.
func skeleton() -> Skeleton3D:
	return _model.find_child("Skeleton3D", true, false) as Skeleton3D if _model != null else null


## A spot that rides on one of the model's bones: `at` is where it sits in the rest pose, in
## the skeleton's space (centimetres, model facing +Z). Children use ordinary monster space
## (metres, facing -Z). Null if there's no such bone.
func bone_anchor(bone: String, at: Vector3) -> Node3D:
	var bones := skeleton()
	if bones == null or bones.find_bone(bone) < 0:
		return null
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	bones.add_child(attach)
	var anchor := Node3D.new()
	var rest := bones.get_bone_global_rest(bones.find_bone(bone))
	var shrink := global_basis.get_scale().x / bones.global_basis.get_scale().x
	anchor.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * shrink), at)
	attach.add_child(anchor)
	return anchor


## Where a bone sits in the rest pose, in the skeleton's space (see bone_anchor).
func bone_rest(bone: String) -> Vector3:
	var bones := skeleton()
	if bones == null or bones.find_bone(bone) < 0:
		return Vector3.ZERO
	return bones.get_bone_global_rest(bones.find_bone(bone)).origin


## Bends a bone on top of the animation (see BoneTweak). Null without a rig.
func tweak_bone(bone: String, axis: Vector3, angle: float) -> BoneTweak:
	var bones := skeleton()
	if bones == null or bones.find_bone(bone) < 0:
		return null
	var tweak := BoneTweak.new()
	tweak.bone = bone
	tweak.axis = axis
	tweak.angle = angle
	bones.add_child(tweak)
	return tweak


func _process(delta: float) -> void:
	if _moves == null or delta <= 0.0:
		return
	var spot := global_position
	if _last_spot != Vector3.INF:
		var moved := Vector2(spot.x - _last_spot.x, spot.z - _last_spot.z).length() / delta
		_pace_seen = lerpf(_pace_seen, moved, minf(1.0, delta * 8.0))
	_last_spot = spot
	# The clips were made at about 1.7 m tall: a taller body covers more ground per stride.
	var stride := maxf(_model_height, 0.5) / 1.7
	if _pace_seen < 0.15:
		if _moves.is_playing():
			_moves.pause()
		return
	var running := _pace_seen > 2.6 * stride and _moves.has_animation("run")
	var clip := "run" if running else "walk"
	if _moves.current_animation != clip or not _moves.is_playing():
		_moves.play(clip, 0.25)
	_moves.speed_scale = clampf(_pace_seen / ((3.6 if running else 1.3) * stride), 0.4, 2.2)


## Reacts to a new state on every computer, e.g. to play a sound. Override as needed.
func _on_state_changed(_new_state: String) -> void:
	pass


# --- Helpers for behaviours (host) ----------------------------------------------------

## Host: stops for `seconds` and looks at `point` (a camera someone's watching).
func stare_at(point: Vector3, seconds: float) -> void:
	stared = true
	_stare_at = point
	_stare_left = seconds


func set_mood(new_mood: String) -> void:
	mood = new_mood if MOODS.has(new_mood) else ""
	pace = MOODS[mood]["pace"] if mood != "" else 1.0
	senses = MOODS[mood]["senses"] if mood != "" else 1.0


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
	# Everything moves faster while the school bell rings (and a restless one is quicker anyway),
	# but never faster than it could already go or a guard can run.
	speed = minf(speed * pace * director.speed_multiplier(), maxf(speed, BELL_SPEED_CAP))
	if direction.length() > 0.05:
		direction = direction.normalized()
		face(direction)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	var before := global_position
	move_and_slide()
	var delta := get_physics_process_delta_time()
	if Vector2(global_position.x - before.x, global_position.z - before.z).length() < speed * delta * 0.15:
		_stuck_for += delta
	else:
		_stuck_for = 0.0
	return true


# --- Shared behaviours (host) ----------------------------------------------------------

var _patrol_index := 0
var _patrol_pause := 0.0
var _unseen_for := 0.0


## Walks a round of `points`, pausing a while at each. Returns true on the frame it reaches
## one (e.g. to switch to a "mopping" state). `skip` > 0 jumps ahead 1 to `skip` points at
## random instead of going in order.
func patrol_step(points: Array[Vector3], delta: float, speed: float, pause: Vector2, skip := 0) -> bool:
	if _patrol_pause > 0.0:
		_patrol_pause -= delta
		halt()
		return false
	var spot := points[_patrol_index % points.size()]
	if Vector2(global_position.x - spot.x, global_position.z - spot.z).length() < 1.2 or is_stuck():
		_patrol_pause = randf_range(pause.x, pause.y) * (0.5 if mood == "restless" else 1.0)
		var step := 1 + (randi() % skip if skip > 0 else 0)
		_patrol_index = (_patrol_index + step) % points.size()
		_stuck_for = 0.0
		return true
	move_to(spot, speed)
	return false


## The first guard within `reach` that it can go after: in its line of sight (unless `need_sight`
## is false) and passing `test`, if given.
func find_guard(reach: float, need_sight := true, test := Callable()) -> Guard:
	for guard in director.targetable_guards():
		# A guard whose nerve is going is noticed from further off.
		if distance_to_guard(guard) > reach * senses * director.nerve_reach(guard):
			continue
		if test.is_valid() and not test.call(guard):
			continue
		if need_sight and not director.can_see(eye_position(), guard):
			continue
		return guard
	return null


## Call when a chase begins, so `chase` starts with a fresh "lost sight" timer.
func start_chase() -> void:
	_unseen_for = 0.0


## One frame of going after `target`, catching anyone in reach. Returns false when the chase
## is over: the target is gone or caught, can't be reached (e.g. the guard room before night 7),
## or has been out of sight for `give_up_after` seconds.
func chase(target: Guard, speed: float, delta: float, give_up_after := INF) -> bool:
	if not is_instance_valid(target) or target.is_dead:
		return false
	# Hidden in a cupboard: it's lost them (if it saw them go in, Hiding deals with that).
	if target.hiding:
		return false
	if give_up_after < INF:
		if director.can_see(eye_position(), target):
			_unseen_for = 0.0
		else:
			_unseen_for += delta
		if _unseen_for > give_up_after:
			return false
	if not move_to(target.global_position, speed):
		return false
	catch_nearby()
	return true


## True when it has been pushing against something for over a second (e.g. cutting a corner
## into furniture), so a behaviour can pick somewhere else to go.
func is_stuck() -> bool:
	return _stuck_for > 1.0


## True once the last move_to target has been reached, or is as close as it can get.
func arrived() -> bool:
	return _agent.is_navigation_finished()


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
	if harmless:
		return false
	for guard in director.targetable_guards():
		if distance_to_guard(guard) < KILL_DISTANCE:
			director.kill(guard, display_name, global_position)
			return true
	return false


## Roughly where its eyes are, for line-of-sight checks.
func eye_position() -> Vector3:
	return global_position + Vector3(0, 1.6, 0)


## Can a guard log this monster right now? (Not while it's hiding, for example.)
func loggable() -> bool:
	return true


## True if any living guard is shining their flashlight at this monster.
func is_lit(max_distance := 14.0) -> bool:
	return director.lit_by_flashlight(global_position + Vector3(0, 0.6, 0), max_distance)


## Adds something guards can press E on while looking at this monster (on every computer).
## It doesn't block anyone. Connect to its `used` signal.
func add_talk_point(prompt: String, size := Vector3(0.7, 1.9, 0.7)) -> Interactable:
	var point := Interactable.new()
	point.prompt = prompt
	point.collision_layer = Interactable.TALK_LAYER
	point.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	point.add_child(collider)
	point.position = Vector3(0, size.y * 0.5, 0)
	add_child(point)
	return point


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
	instance.layers = visual_layers
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
