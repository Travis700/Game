class_name Hats
extends RefCounted
## Hats: something to wear, unlocked by rank or by achievements. Picked on the menu, worn on
## your guard for everyone (and the cameras) to see. Most are real models
## (assets/models/hat_<name>.glb, see MODELS); the halo, the bulldog ears and the antennae are
## made here from simple shapes (see SHAPES).

## Each hat: its name, what unlocks it (a rank, or an achievement), and the boxes it's made of
## if its model is missing: [size, centre (on the head, y up from eye level), colour, glow].
const HATS := {
	"none": {"name": "No hat", "rank": 1, "parts": []},
	"cap": {"name": "Security cap", "rank": 1, "parts": [
		[Vector3(0.4, 0.12, 0.4), Vector3(0, 0.2, 0), Color(0.08, 0.1, 0.18), 0.0],
		[Vector3(0.36, 0.03, 0.2), Vector3(0, 0.15, -0.26), Color(0.06, 0.07, 0.12), 0.0],
		[Vector3(0.1, 0.06, 0.02), Vector3(0, 0.22, -0.2), Color(0.9, 0.75, 0.2), 0.5]]},
	"beanie": {"name": "Beanie", "rank": 2, "parts": [
		[Vector3(0.42, 0.18, 0.42), Vector3(0, 0.22, 0), Color(0.6, 0.15, 0.12), 0.0],
		[Vector3(0.12, 0.1, 0.12), Vector3(0, 0.36, 0), Color(0.9, 0.85, 0.8), 0.0]]},
	"hard_hat": {"name": "Hard hat", "rank": 3, "parts": [
		[Vector3(0.44, 0.16, 0.46), Vector3(0, 0.22, 0), Color(0.95, 0.75, 0.1), 0.0],
		[Vector3(0.52, 0.03, 0.56), Vector3(0, 0.15, -0.02), Color(0.95, 0.75, 0.1), 0.0]]},
	"cone": {"name": "Traffic cone", "rank": 4, "parts": [
		[Vector3(0.4, 0.04, 0.4), Vector3(0, 0.16, 0), Color(1.0, 0.4, 0.05), 0.0],
		[Vector3(0.28, 0.16, 0.28), Vector3(0, 0.26, 0), Color(1.0, 0.4, 0.05), 0.0],
		[Vector3(0.2, 0.08, 0.2), Vector3(0, 0.38, 0), Color(0.95, 0.95, 0.95), 0.0],
		[Vector3(0.12, 0.14, 0.12), Vector3(0, 0.49, 0), Color(1.0, 0.4, 0.05), 0.0]]},
	"top_hat": {"name": "Top hat", "rank": 5, "parts": [
		[Vector3(0.5, 0.03, 0.5), Vector3(0, 0.16, 0), Color(0.05, 0.05, 0.06), 0.0],
		[Vector3(0.32, 0.36, 0.32), Vector3(0, 0.35, 0), Color(0.05, 0.05, 0.06), 0.0],
		[Vector3(0.33, 0.06, 0.33), Vector3(0, 0.22, 0), Color(0.5, 0.08, 0.1), 0.0]]},
	"bucket": {"name": "Mop bucket", "rank": 6, "parts": [
		[Vector3(0.46, 0.34, 0.46), Vector3(0, 0.22, 0), Color(0.85, 0.75, 0.1), 0.0],
		[Vector3(0.5, 0.04, 0.04), Vector3(0, 0.42, 0), Color(0.3, 0.3, 0.32), 0.0]]},
	"party": {"name": "Party hat", "rank": 7, "parts": [
		[Vector3(0.3, 0.12, 0.3), Vector3(0, 0.2, 0), Color(0.3, 0.6, 1.0), 0.0],
		[Vector3(0.2, 0.12, 0.2), Vector3(0, 0.32, 0), Color(1.0, 0.3, 0.6), 0.0],
		[Vector3(0.1, 0.12, 0.1), Vector3(0, 0.44, 0), Color(0.3, 1.0, 0.5), 0.0],
		[Vector3(0.08, 0.08, 0.08), Vector3(0, 0.53, 0), Color(1.0, 0.95, 0.4), 1.0]]},
	"halo": {"name": "Legend's halo", "rank": 8},
	"mascot": {"name": "Bulldog ears", "achievement": "RUN_WON"},
	"antlers": {"name": "Specimen antennae", "achievement": "MONSTER_EXPERT"},
	"night_owl": {"name": "Night-vision goggles", "achievement": "WORKAHOLIC", "parts": [
		[Vector3(0.4, 0.06, 0.4), Vector3(0, 0.17, 0), Color(0.12, 0.14, 0.1), 0.0],
		[Vector3(0.08, 0.08, 0.12), Vector3(-0.07, 0.2, -0.24), Color(0.15, 0.17, 0.12), 0.0],
		[Vector3(0.08, 0.08, 0.12), Vector3(0.07, 0.2, -0.24), Color(0.15, 0.17, 0.12), 0.0],
		[Vector3(0.05, 0.05, 0.02), Vector3(-0.07, 0.2, -0.31), Color(0.3, 1.0, 0.3), 3.0],
		[Vector3(0.05, 0.05, 0.02), Vector3(0.07, 0.2, -0.31), Color(0.3, 1.0, 0.3), 3.0]]},
	"deerstalker": {"name": "Deerstalker", "achievement": "CASE_FILES", "parts": [
		[Vector3(0.42, 0.14, 0.44), Vector3(0, 0.21, 0), Color(0.45, 0.36, 0.22), 0.0],
		[Vector3(0.3, 0.03, 0.14), Vector3(0, 0.15, -0.27), Color(0.4, 0.32, 0.2), 0.0],
		[Vector3(0.3, 0.03, 0.14), Vector3(0, 0.15, 0.27), Color(0.4, 0.32, 0.2), 0.0]]},
	"fedora": {"name": "Detective's fedora", "achievement": "CASE_WORK", "parts": [
		[Vector3(0.54, 0.03, 0.54), Vector3(0, 0.16, 0), Color(0.18, 0.16, 0.14), 0.0],
		[Vector3(0.34, 0.16, 0.34), Vector3(0, 0.25, 0), Color(0.18, 0.16, 0.14), 0.0],
		[Vector3(0.35, 0.04, 0.35), Vector3(0, 0.19, 0), Color(0.08, 0.08, 0.08), 0.0]]},
	"badge_cap": {"name": "Chief's cap", "achievement": "CASE_CLOSED", "parts": [
		[Vector3(0.42, 0.13, 0.42), Vector3(0, 0.2, 0), Color(0.05, 0.06, 0.1), 0.0],
		[Vector3(0.38, 0.03, 0.22), Vector3(0, 0.15, -0.27), Color(0.03, 0.03, 0.05), 0.0],
		[Vector3(0.38, 0.03, 0.03), Vector3(0, 0.27, -0.2), Color(0.95, 0.8, 0.3), 1.0],
		[Vector3(0.12, 0.1, 0.02), Vector3(0, 0.23, -0.21), Color(0.95, 0.8, 0.3), 2.0]]},
}


## Can this player wear it? (Their own rank and achievements, on this computer.)
static func is_unlocked(hat: String) -> bool:
	if not HATS.has(hat):
		return false
	var info: Dictionary = HATS[hat]
	if info.has("achievement"):
		return Career.unlocked().has(info["achievement"])
	return Career.rank() >= int(info.get("rank", 1))


## What it takes, e.g. "Rank 5: Shift Supervisor" or "Achievement: Nine nights".
static func requirement(hat: String) -> String:
	var info: Dictionary = HATS[hat]
	if info.has("achievement"):
		return "Achievement: " + Career.ACHIEVEMENTS[info["achievement"]][0]
	var rank := int(info.get("rank", 1))
	return "Rank %d: %s" % [rank, Career.rank_title(rank)]


## Hats with a model: [how high its base sits above eye level, its height, how far back its
## middle sits (the brim of a cap pushes the box forward)] in head units. Hats were made for the
## old block head and are shrunk to fit the real one (see Guard.MODEL_HAT_SCALE).
const MODELS := {
	"cap": [0.1, 0.2, 0.0],
	"beanie": [0.03, 0.3, 0.036],
	"hard_hat": [0.07, 0.24, 0.018],
	"cone": [0.1, 0.36, 0.05],
	"top_hat": [0.11, 0.23, 0.05],
	"bucket": [0.03, 0.31, 0.05],
	"party": [0.16, 0.35, 0.05],
	"night_owl": [0.12, 0.12, -0.17],
	"deerstalker": [0.06, 0.2, 0.05],
	"fedora": [0.09, 0.21, 0.02],
	"badge_cap": [0.1, 0.15, 0.056],
}

## Hats (or bits of hats) made from simple shapes, on the model or instead of one:
## [shape, size, centre, colour, glow, tilt in degrees]. A "band" is a headband over the top
## from ear to ear (the rest of it is hidden in the head), a "ring" lies flat.
const SHAPES := {
	"halo": [
		["ring", Vector3(0.34, 0.035, 0.34), Vector3(0, 0.36, 0.05), Color(1.0, 0.85, 0.3), 3.0, Vector3(-8, 0, 0)]],
	"mascot": [
		["band", Vector3(0.29, 0.22, 0.05), Vector3(0, 0.0, 0.07), Color(0.2, 0.15, 0.12), 0.0, Vector3.ZERO],
		["sphere", Vector3(0.14, 0.1, 0.045), Vector3(-0.13, 0.2, 0.07), Color(0.55, 0.38, 0.22), 0.0, Vector3(0, 0, 40)],
		["sphere", Vector3(0.14, 0.1, 0.045), Vector3(0.13, 0.2, 0.07), Color(0.55, 0.38, 0.22), 0.0, Vector3(0, 0, -40)],
		["sphere", Vector3(0.07, 0.05, 0.05), Vector3(-0.16, 0.21, 0.065), Color(0.85, 0.6, 0.55), 0.0, Vector3(0, 0, 40)],
		["sphere", Vector3(0.07, 0.05, 0.05), Vector3(0.16, 0.21, 0.065), Color(0.85, 0.6, 0.55), 0.0, Vector3(0, 0, -40)]],
	"antlers": [
		["band", Vector3(0.28, 0.21, 0.035), Vector3(0, 0.0, 0.06), Color(0.1, 0.11, 0.1), 0.0, Vector3.ZERO],
		["cylinder", Vector3(0.016, 0.22, 0.016), Vector3(-0.05, 0.3, 0.06), Color(0.75, 0.8, 0.7), 0.0, Vector3(0, 0, 15)],
		["cylinder", Vector3(0.016, 0.22, 0.016), Vector3(0.05, 0.3, 0.06), Color(0.75, 0.8, 0.7), 0.0, Vector3(0, 0, -15)],
		["sphere", Vector3(0.065, 0.065, 0.065), Vector3(-0.079, 0.41, 0.06), Color(0.6, 1.0, 0.6), 2.0, Vector3.ZERO],
		["sphere", Vector3(0.065, 0.065, 0.065), Vector3(0.079, 0.41, 0.06), Color(0.6, 1.0, 0.6), 2.0, Vector3.ZERO]],
	# The goggles' strap, round the head.
	"night_owl": [
		["ring", Vector3(0.29, 0.03, 0.31), Vector3(0, 0.15, 0.05), Color(0.1, 0.11, 0.09), 0.0, Vector3(-6, 0, 0)]],
}


## The hat, to put on a guard's head. `layers` hides your own hat from your eyes.
static func build(hat: String, layers := 1) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Hat"
	if not HATS.has(hat):
		return holder
	# The real model if there is one, else the boxes it had before (if it had any).
	var modelled := MODELS.has(hat) and _add_model(holder, hat, layers)
	if modelled or not HATS[hat].has("parts"):
		for shape: Array in SHAPES.get(hat, []):
			holder.add_child(_shape(shape, layers))
	if not modelled:
		for part: Array in HATS[hat].get("parts", []):
			var box := BoxMesh.new()
			box.size = part[0]
			holder.add_child(_piece(box, part[1], part[2], part[3], layers))
	return holder


## Puts assets/models/hat_<name>.glb on, sized and placed by MODELS. False if there's no model.
static func _add_model(holder: Node3D, hat: String, layers: int) -> bool:
	var fit: Array = MODELS[hat]
	var spot := Node3D.new()
	spot.position = Vector3(0, fit[0], fit[2])
	holder.add_child(spot)
	if ModelKit.add(spot, "hat_" + hat, fit[1], PI, layers) == null:
		spot.free()
		return false
	return true


## One of SHAPES as a mesh.
static func _shape(shape: Array, layers: int) -> MeshInstance3D:
	var size: Vector3 = shape[1]
	var mesh: PrimitiveMesh
	match shape[0]:
		"ring":
			# Squashed front to back if it's deeper than it's wide (a strap round an oval head).
			var ring := TorusMesh.new()
			ring.outer_radius = size.x * 0.5
			ring.inner_radius = size.x * 0.5 - size.y
			ring.rings = 32
			ring.ring_segments = 8
			mesh = ring
		"cylinder":
			var stalk := CylinderMesh.new()
			stalk.top_radius = size.x * 0.5
			stalk.bottom_radius = size.x * 0.5
			stalk.height = size.y
			stalk.radial_segments = 8
			stalk.rings = 1
			mesh = stalk
		_:
			# A ball, stretched to its size; a band is the top half of one, flattened.
			var ball := SphereMesh.new()
			ball.radius = 0.5
			ball.height = 1.0
			ball.radial_segments = 16
			ball.rings = 8
			if shape[0] == "band":
				ball.is_hemisphere = true
				ball.height = 0.5
				ball.radial_segments = 24
			mesh = ball
	var piece := _piece(mesh, shape[2], shape[3], shape[4], layers)
	var tilt: Vector3 = shape[5]
	var stretch := Vector3.ONE
	match shape[0]:
		"ring":
			stretch = Vector3(1, 1, size.z / size.x)
		"band":
			stretch = Vector3(size.x, size.y * 2.0, size.z)
		"sphere":
			stretch = size
	piece.basis = Basis.from_euler(tilt * PI / 180.0) * Basis.from_scale(stretch)
	return piece


## A plain-coloured mesh on the head (glowing if `glow` > 0), too small to bother with shadows.
static func _piece(mesh: Mesh, centre: Vector3, colour: Color, glow: float, layers: int) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.position = centre
	piece.layers = layers
	piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = glow
	piece.material_override = material
	return piece


## How far the name tag has to move up to clear it.
static func height(hat: String) -> float:
	var top := 0.0
	if not HATS.has(hat):
		return 0.0
	if MODELS.has(hat) and ResourceLoader.exists("res://assets/models/hat_%s.glb" % hat):
		top = float(MODELS[hat][0]) + float(MODELS[hat][1])
	else:
		for part: Array in HATS[hat].get("parts", []):
			top = maxf(top, (part[1] as Vector3).y + (part[0] as Vector3).y * 0.5)
	for shape: Array in SHAPES.get(hat, []):
		top = maxf(top, (shape[2] as Vector3).y + (shape[1] as Vector3).y * 0.5)
	return maxf(top - 0.3, 0.0)
