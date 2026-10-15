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
	return model


static func _collect(node: Node, into: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		into.append(node)
	for child in node.get_children():
		_collect(child, into)
