class_name Grass
extends Node3D
## Long grass on the lawns outside: one tuft of blades, made here in code, drawn thousands of
## times. The lawns are cut into square patches; each patch draws all its tufts up close and a
## third of them further off, and nothing beyond that (the flat lawn texture shows through).
## Switched off by the "Long grass" setting (Profile.long_grass).

## Tufts are spread on a jittered grid this far apart, in metres.
const SPACING := 0.3
## Size of each patch, in metres (each is its own MultiMesh, so it can be culled).
const PATCH := 10.0
## Up to this far every tuft is drawn; up to FAR_RANGE, every third.
const NEAR_RANGE := 20.0
const FAR_RANGE := 42.0
const BLADES := 6

var _tuft: ArrayMesh
var _material: ShaderMaterial


## Fills each lawn (Rect2 on the ground, x and z) with grass, leaving out the `gaps`
## (Rect2 too: buildings, paths, the street) and `clearings` (Vector3 centre, with the radius in y).
func build(lawns: Array[Rect2], gaps: Array[Rect2], clearings: Array[Vector3]) -> void:
	add_to_group("long_grass")
	_material = ShaderMaterial.new()
	_material.shader = load("res://shaders/grass.gdshader")
	_tuft = _make_tuft()
	var random := RandomNumberGenerator.new()
	random.seed = 451
	for lawn in lawns:
		var x := lawn.position.x
		while x < lawn.end.x:
			var z := lawn.position.y
			while z < lawn.end.y:
				var patch := Rect2(x, z, minf(PATCH, lawn.end.x - x), minf(PATCH, lawn.end.y - z))
				_fill(patch, gaps, clearings, random)
				z += PATCH
			x += PATCH


func _ready() -> void:
	# The setting (looked up here rather than named, so tools can build the school without it).
	var profile := get_node_or_null("/root/Profile")
	if profile:
		visible = profile.long_grass


func _fill(patch: Rect2, all_gaps: Array[Rect2], all_clearings: Array[Vector3], random: RandomNumberGenerator) -> void:
	# Only what touches this patch needs checking.
	var gaps: Array[Rect2] = []
	for gap in all_gaps:
		if gap.encloses(patch):
			return
		if gap.intersects(patch):
			gaps.append(gap)
	var clearings: Array[Vector3] = []
	for clearing in all_clearings:
		if patch.grow(clearing.y).has_point(Vector2(clearing.x, clearing.z)):
			clearings.append(clearing)
	var spots: Array[Transform3D] = []
	var x := patch.position.x + SPACING * 0.5
	while x < patch.end.x:
		var z := patch.position.y + SPACING * 0.5
		while z < patch.end.y:
			var spot := Vector2(x, z) + Vector2(random.randf_range(-0.45, 0.45), random.randf_range(-0.45, 0.45)) * SPACING
			z += SPACING
			if _blocked(spot, gaps, clearings):
				continue
			var tall := random.randf_range(0.7, 1.3)
			var shape := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3(random.randf_range(0.8, 1.2), tall, random.randf_range(0.8, 1.2)))
			spots.append(Transform3D(shape, Vector3(spot.x, 0.0, spot.y)))
		x += SPACING
	if spots.is_empty():
		return
	# The far set is every third tuft, so thinning out keeps the spread even.
	var far: Array[Transform3D] = []
	var near: Array[Transform3D] = []
	for i in spots.size():
		(far if i % 3 == 0 else near).append(spots[i])
	_add_layer(near, 0.0, NEAR_RANGE)
	_add_layer(far, 0.0, FAR_RANGE)


func _add_layer(spots: Array[Transform3D], begin: float, end: float) -> void:
	if spots.is_empty():
		return
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = _tuft
	many.instance_count = spots.size()
	# Each instance is a row-major 3x4 matrix in the buffer.
	var buffer := PackedFloat32Array()
	buffer.resize(spots.size() * 12)
	for i in spots.size():
		var t := spots[i]
		var at := i * 12
		buffer[at] = t.basis.x.x; buffer[at + 1] = t.basis.y.x; buffer[at + 2] = t.basis.z.x; buffer[at + 3] = t.origin.x
		buffer[at + 4] = t.basis.x.y; buffer[at + 5] = t.basis.y.y; buffer[at + 6] = t.basis.z.y; buffer[at + 7] = t.origin.y
		buffer[at + 8] = t.basis.x.z; buffer[at + 9] = t.basis.y.z; buffer[at + 10] = t.basis.z.z; buffer[at + 11] = t.origin.z
	many.buffer = buffer
	var layer := MultiMeshInstance3D.new()
	layer.multimesh = many
	layer.material_override = _material
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	layer.visibility_range_begin = begin
	layer.visibility_range_end = end
	layer.visibility_range_end_margin = 4.0
	layer.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(layer)


static func _blocked(spot: Vector2, gaps: Array[Rect2], clearings: Array[Vector3]) -> bool:
	for gap in gaps:
		if gap.has_point(spot):
			return true
	for clearing in clearings:
		if spot.distance_to(Vector2(clearing.x, clearing.z)) < clearing.y:
			return true
	return false


## One tuft: BLADES curved, tapering blades leaning out from a small patch of ground.
## UV.y runs 0 at the root to 1 at the tip (the shader bends and shades by it).
func _make_tuft() -> ArrayMesh:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	const SEGMENTS := 3
	for blade in BLADES:
		var root := Vector3(random.randf_range(-0.09, 0.09), 0.0, random.randf_range(-0.09, 0.09))
		var height := random.randf_range(0.3, 0.55)
		var width := random.randf_range(0.018, 0.03)
		var facing := random.randf() * TAU
		var across := Vector3(cos(facing), 0.0, sin(facing))
		var lean := Vector3(-across.z, 0.0, across.x) * random.randf_range(0.06, 0.2)
		var shade := random.randf_range(0.75, 1.15)
		var tint := Color(shade * random.randf_range(0.95, 1.1), shade, shade * random.randf_range(0.85, 1.0))
		var normal := across.cross(Vector3.UP + lean).normalized()
		var rows: Array[Array] = []
		for i in SEGMENTS + 1:
			var t := float(i) / SEGMENTS
			var centre := root + Vector3.UP * height * t + lean * t * t
			var half := width * (1.0 - t * 0.85) * 0.5
			rows.append([centre - across * half, centre + across * half, t])
		for i in SEGMENTS:
			var a: Array = rows[i]
			var b: Array = rows[i + 1]
			if i == SEGMENTS - 1:
				# The last segment closes to a point.
				var tip: Vector3 = (b[0] + b[1]) * 0.5
				_vertex(tool, a[0], a[2], normal, tint)
				_vertex(tool, a[1], a[2], normal, tint)
				_vertex(tool, tip, 1.0, normal, tint)
				continue
			_vertex(tool, a[0], a[2], normal, tint)
			_vertex(tool, a[1], a[2], normal, tint)
			_vertex(tool, b[1], b[2], normal, tint)
			_vertex(tool, a[0], a[2], normal, tint)
			_vertex(tool, b[1], b[2], normal, tint)
			_vertex(tool, b[0], b[2], normal, tint)
	return tool.commit()


static func _vertex(tool: SurfaceTool, at: Vector3, up: float, normal: Vector3, tint: Color) -> void:
	tool.set_color(tint)
	tool.set_normal(normal)
	tool.set_uv(Vector2(0.5, up))
	tool.add_vertex(at)
