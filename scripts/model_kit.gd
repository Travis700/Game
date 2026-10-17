class_name ModelKit
## Puts a ready-made 3D model (res://assets/models/<name>.glb) into the world, scaled to a
## height and standing on the parent's origin. Monsters keep their block bodies as a fallback.


## Adds the model to `parent` and returns it, or null if there's no such model.
## `turn` spins it round (models face +Z; monsters face -Z, hence PI by default).
static func add(parent: Node3D, model_name: String, height: float, turn := PI, layers := 1) -> Node3D:
	var path := "res://assets/models/%s.glb" % model_name
	if not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var model := scene.instantiate() as Node3D
	var meshes: Array[MeshInstance3D] = []
	_collect(model, meshes)
	var box := AABB()
	for i in meshes.size():
		var mesh_box := meshes[i].transform * meshes[i].get_aabb()
		box = mesh_box if i == 0 else box.merge(mesh_box)
		meshes[i].layers = layers
	var size := height / maxf(box.size.y, 0.01)
	model.scale = Vector3.ONE * size
	model.rotation.y = turn
	# Feet on the floor, centred over the origin.
	var centre := box.get_center()
	model.position = Vector3(-centre.x, -box.position.y, -centre.z).rotated(Vector3.UP, turn) * size
	parent.add_child(model)
	_setup_moves(model, model_name)
	return model


## A one-mesh model's mesh, for drawing many copies (a MultiMesh): {"mesh", "box" (its bounds,
## in the model's space), "transform" (where the mesh sits in the model)}. Empty if there's no model.
static func mesh_of(model_name: String) -> Dictionary:
	if _meshes.has(model_name):
		return _meshes[model_name]
	var path := "res://assets/models/%s.glb" % model_name
	var found := {}
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		var instances := model.find_children("*", "MeshInstance3D", true, false)
		if not instances.is_empty():
			var instance := instances[0] as MeshInstance3D
			var placed := instance.transform
			var parent := instance.get_parent() as Node3D
			while parent != null and parent != model:
				placed = parent.transform * placed
				parent = parent.get_parent() as Node3D
			found = {"mesh": instance.mesh, "box": placed * instance.get_aabb(), "transform": placed}
		model.free()
	_meshes[model_name] = found
	return found


## Where a mesh_of() piece goes to fill a box of `size` centred on `centre`, turned by `turn`
## (stretched to fit: the pieces of a row of lockers share it out evenly).
static func fit(piece: Dictionary, centre: Vector3, size: Vector3, turn := 0.0) -> Transform3D:
	var box: AABB = piece["box"]
	var stretch := Basis.from_scale(size / box.size.max(Vector3.ONE * 0.001))
	return Transform3D(Basis(Vector3.UP, turn) * stretch, centre) * Transform3D(Basis(), -box.get_center()) \
			* (piece["transform"] as Transform3D)


static var _meshes := {}


## Clips that can come in their own files next to the model (see _setup_moves).
const EXTRA_CLIPS: Array[String] = ["run", "sit"]


## The model's AnimationPlayer, with "walk" and any EXTRA_CLIPS that exist, or null.
static func moves(model: Node3D) -> AnimationPlayer:
	return model.get_meta("moves") as AnimationPlayer if model != null and model.has_meta("moves") else null


static func _setup_moves(model: Node3D, model_name: String) -> void:
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or player.get_animation_list().is_empty():
		return
	var library := AnimationLibrary.new()
	var walk := player.get_animation(player.get_animation_list()[0]).duplicate() as Animation
	walk.loop_mode = Animation.LOOP_LINEAR
	_pin_in_place(walk)
	library.add_animation("walk", walk)
	# Extra clips made on the same rig, each in its own file: <name>_run.glb, <name>_sit.glb.
	for clip in EXTRA_CLIPS:
		var clip_path := "res://assets/models/%s_%s.glb" % [model_name, clip]
		if not ResourceLoader.exists(clip_path):
			continue
		var source := (load(clip_path) as PackedScene).instantiate()
		var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if source_player != null and not source_player.get_animation_list().is_empty():
			var extra := source_player.get_animation(source_player.get_animation_list()[0]).duplicate() as Animation
			extra.loop_mode = Animation.LOOP_LINEAR
			_pin_in_place(extra)
			library.add_animation(clip, extra)
		source.free()
	for old in player.get_animation_library_list():
		player.remove_animation_library(old)
	player.add_animation_library("", library)
	model.set_meta("moves", player)


## Keeps the hips over the spot: the monster's own movement does the travelling.
static func _pin_in_place(animation: Animation) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_POSITION_3D:
			continue
		var keys := animation.track_get_key_count(track)
		if keys == 0:
			continue
		var start: Vector3 = animation.track_get_key_value(track, 0)
		for key in keys:
			var at: Vector3 = animation.track_get_key_value(track, key)
			animation.track_set_key_value(track, key, Vector3(start.x, at.y, start.z))


## A spot that rides on one of a rigged model's bones: `at` is where it sits in the rest pose,
## in the skeleton's space (centimetres, model facing +Z). Children of it use the owner's
## space (metres, facing -Z). Null if there's no such bone.
static func bone_anchor(model: Node3D, owner: Node3D, bone: String, at: Vector3) -> Node3D:
	var bones := model.find_child("Skeleton3D", true, false) as Skeleton3D if model else null
	if bones == null or bones.find_bone(bone) < 0:
		return null
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	bones.add_child(attach)
	var anchor := Node3D.new()
	var rest := bones.get_bone_global_rest(bones.find_bone(bone))
	var shrink := owner.global_basis.get_scale().x / bones.global_basis.get_scale().x
	anchor.transform = rest.affine_inverse() * Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * shrink), at)
	attach.add_child(anchor)
	return anchor


## Makes every surface of the model see-through and faintly glowing, e.g. the Ghost.
static func ghostly(model: Node3D, tint: Color, glow: float) -> void:
	var meshes: Array[MeshInstance3D] = []
	_collect(model, meshes)
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			var material := (source.duplicate() if source else StandardMaterial3D.new()) as BaseMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = tint
			material.emission_enabled = true
			material.emission = Color(tint, 1.0)
			material.emission_energy_multiplier = glow
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.set_surface_override_material(surface, material)


## Every material on the model, made unique so it can be recoloured (e.g. the Understudy).
static func own_materials(model: Node3D) -> Array[BaseMaterial3D]:
	var found: Array[BaseMaterial3D] = []
	var meshes: Array[MeshInstance3D] = []
	_collect(model, meshes)
	for mesh in meshes:
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as BaseMaterial3D
			mesh.set_surface_override_material(surface, material)
			found.append(material)
	return found


static func _collect(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)
