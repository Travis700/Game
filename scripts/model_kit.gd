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


## The model's AnimationPlayer, with "walk" and (if <name>_run.glb exists) "run", or null.
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
	var run_path := "res://assets/models/%s_run.glb" % model_name
	if ResourceLoader.exists(run_path):
		var source := (load(run_path) as PackedScene).instantiate()
		var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if source_player != null and not source_player.get_animation_list().is_empty():
			var run := source_player.get_animation(source_player.get_animation_list()[0]).duplicate() as Animation
			run.loop_mode = Animation.LOOP_LINEAR
			_pin_in_place(run)
			library.add_animation("run", run)
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


static func _collect(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)
