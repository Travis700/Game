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
	state = "out"
	# Its own heavy footsteps (a recording), not the generic ones.
	silent = true


var _steps: AudioStreamPlayer3D


func think(delta: float) -> void:
	# (Set here, in the tree, so everyone hears and the caption shows.)
	state = "hunt"
	_left -= delta
	var target := director.guard_by_peer(target_peer)
	# Gone (or knocked out and carried off: a close call): it's over, and nobody's docked.
	if target == null or target.is_dead or director.is_gone(target):
		director.principal_done(self)
		return
	if _left <= 0.0:
		director.principal_done(self, target_peer)
		return
	# Late, but they came: that'll do.
	if SchoolBuilder.area_at(target.global_position) == "Front Office" and distance_to_guard(target) > 3.0:
		director.tell(target_peer, "\"You're late, Guard. Don't let it happen again.\"")
		director.principal_done(self)
		return
	move_to(target.global_position, SPEED)
	catch_nearby()


func _build_body() -> void:
	if use_model("principal", 1.98):
		_smear_face()
		return
	part(capsule(0.3, 1.95), Color(0.14, 0.14, 0.16), Vector3(0, 0.98, 0))
	part(box(Vector3(0.08, 0.5, 0.04)), Color(0.55, 0.05, 0.05), Vector3(0, 1.45, -0.29))
	part(box(Vector3(0.22, 0.18, 0.04)), Color(0.9, 0.9, 0.9), Vector3(0, 1.62, -0.27))
	part(sphere(0.16), Color(0.7, 0.62, 0.55), Vector3(0, 2.08, 0))
	part(box(Vector3(0.26, 0.05, 0.02)), Color(0.02, 0.02, 0.02), Vector3(0, 2.1, -0.15))


## Where the face sits, in the model's skeleton space (centimetres, facing +Z), and its size.
const FACE_AT := Vector3(0.0, 177.0, 9.5)
const FACE_SIZE := Vector2(17.0, 22.0)


## Covers the face with a smudge of the notebook drawing that follows the head and never
## comes into focus.
func _smear_face() -> void:
	var skeleton := find_child("Skeleton3D", true, false) as Skeleton3D
	var texture := load("res://assets/models/principal_face.png") as Texture2D
	if skeleton == null or texture == null or skeleton.find_bone("Head") < 0:
		return
	var head := BoneAttachment3D.new()
	head.bone_name = "Head"
	skeleton.add_child(head)
	var quad := QuadMesh.new()
	quad.size = FACE_SIZE
	quad.subdivide_width = 8
	quad.subdivide_depth = 8
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/models/smeared_face.gdshader")
	material.set_shader_parameter("face", texture)
	var patch := MeshInstance3D.new()
	patch.mesh = quad
	patch.material_override = material
	patch.layers = visual_layers
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Placed against the face in the rest pose, then carried by the head bone.
	var rest := skeleton.get_bone_global_rest(skeleton.find_bone("Head"))
	patch.transform = rest.affine_inverse() * Transform3D(Basis.IDENTITY, FACE_AT)
	head.add_child(patch)


## Heavy, purposeful steps on every computer while it's out hunting.
func _on_state_changed(new_state: String) -> void:
	if new_state == "hunt" and _steps == null:
		var stream := SoundBank.get_sound("principal_steps", null, true)
		if stream:
			_steps = Sfx.play_at(self, stream, 2.0, 35.0)
