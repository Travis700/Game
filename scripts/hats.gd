class_name Hats
extends RefCounted
## Hats: something to wear, unlocked by rank or by achievements. Picked on the menu, worn on
## your guard for everyone (and the cameras) to see. Built from boxes like everything else
## until the art pass.

## Each hat: its name, what unlocks it (a rank, or an achievement), and its boxes:
## [size, centre (on the head, y up from eye level), colour, glow].
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
	"halo": {"name": "Legend's halo", "rank": 8, "parts": [
		[Vector3(0.4, 0.03, 0.06), Vector3(0, 0.38, -0.17), Color(1.0, 0.85, 0.3), 3.0],
		[Vector3(0.4, 0.03, 0.06), Vector3(0, 0.38, 0.17), Color(1.0, 0.85, 0.3), 3.0],
		[Vector3(0.06, 0.03, 0.4), Vector3(-0.17, 0.38, 0), Color(1.0, 0.85, 0.3), 3.0],
		[Vector3(0.06, 0.03, 0.4), Vector3(0.17, 0.38, 0), Color(1.0, 0.85, 0.3), 3.0]]},
	"mascot": {"name": "Bulldog ears", "achievement": "RUN_WON", "parts": [
		[Vector3(0.42, 0.1, 0.42), Vector3(0, 0.19, 0), Color(0.55, 0.38, 0.22), 0.0],
		[Vector3(0.12, 0.16, 0.06), Vector3(-0.17, 0.3, 0), Color(0.45, 0.3, 0.18), 0.0],
		[Vector3(0.12, 0.16, 0.06), Vector3(0.17, 0.3, 0), Color(0.45, 0.3, 0.18), 0.0]]},
	"antlers": {"name": "Specimen antennae", "achievement": "MONSTER_EXPERT", "parts": [
		[Vector3(0.03, 0.3, 0.03), Vector3(-0.1, 0.32, 0), Color(0.75, 0.8, 0.7), 0.0],
		[Vector3(0.03, 0.3, 0.03), Vector3(0.1, 0.32, 0), Color(0.75, 0.8, 0.7), 0.0],
		[Vector3(0.07, 0.07, 0.07), Vector3(-0.1, 0.49, 0), Color(0.6, 1.0, 0.6), 2.0],
		[Vector3(0.07, 0.07, 0.07), Vector3(0.1, 0.49, 0), Color(0.6, 1.0, 0.6), 2.0]]},
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


## The hat as boxes, to put on a guard's head. `layers` hides your own hat from your eyes.
static func build(hat: String, layers := 1) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Hat"
	if not HATS.has(hat):
		return holder
	for part: Array in HATS[hat]["parts"]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = part[0]
		mesh.mesh = box
		mesh.position = part[1]
		mesh.layers = layers
		var material := StandardMaterial3D.new()
		material.albedo_color = part[2]
		material.roughness = 0.8
		if float(part[3]) > 0.0:
			material.emission_enabled = true
			material.emission = part[2]
			material.emission_energy_multiplier = part[3]
		mesh.material_override = material
		holder.add_child(mesh)
	return holder


## How far the name tag has to move up to clear it.
static func height(hat: String) -> float:
	var top := 0.0
	if HATS.has(hat):
		for part: Array in HATS[hat]["parts"]:
			top = maxf(top, (part[1] as Vector3).y + (part[0] as Vector3).y * 0.5)
	return maxf(top - 0.3, 0.0)
