class_name SetDressing
extends Node3D
## The odds and ends that make the school look like people were here this afternoon: books and
## papers on the desks, bags left under them, mugs and computers in the offices, milk cartons on
## the lunch tables, cobwebs in the corners, radiators under the windows. None of it does
## anything; it's there so the rooms feel full, and so a flashlight beam has things to throw
## shadows from.
##
## Small things are drawn in batches (one MultiMesh per model per 20-metre square) so a few
## hundred of them cost a few dozen draw calls. Placed from a fixed seed, so the school looks the
## same every night and for every player. Built by SchoolBuilder after the rooms.

## Batches are split into squares this big, so the ones out of sight are skipped.
const CELL := 20.0
## How far away clutter is still drawn, for a thing 1 m tall (smaller things, less).
const DRAW_DISTANCE := 20.0

## For the odds and ends that are placed at random: the same every time.
var rng := RandomNumberGenerator.new()
## "model|cell x|cell z" -> {"model", "height", "transforms": Array[Transform3D]}.
var _batches: Dictionary = {}


func _init() -> void:
	name = "SetDressing"
	rng.seed = 2024


## Puts a copy of a model (assets/models/<name>.glb, one mesh) with its base at `pos`, `height`
## tall, turned by `turn` (0: its front faces +Z). `tip` leans it over (radians about its own X),
## e.g. a bag slumped on its side.
func put(model_name: String, pos: Vector3, height: float, turn := 0.0, tip := 0.0) -> void:
	var piece := ModelKit.mesh_of(model_name)
	if piece.is_empty():
		return
	var box: AABB = piece["box"]
	var size := height / maxf(box.size.y, 0.001)
	var centre := box.get_center()
	var xform := Transform3D(Basis(Vector3.UP, turn) * Basis(Vector3.RIGHT, tip) * Basis.from_scale(Vector3.ONE * size), pos) \
			* Transform3D(Basis(), Vector3(-centre.x, -box.position.y, -centre.z)) * (piece["transform"] as Transform3D)
	var cell := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	var key := "%s|%d|%d" % [model_name, cell.x, cell.y]
	if not _batches.has(key):
		_batches[key] = {"model": model_name, "height": height, "transforms": [] as Array[Transform3D]}
	(_batches[key]["transforms"] as Array[Transform3D]).append(xform)
	_batches[key]["height"] = maxf(_batches[key]["height"], height)


## Draws everything put so far. Called once the school is built.
func commit() -> void:
	for key: String in _batches:
		var batch: Dictionary = _batches[key]
		var transforms: Array[Transform3D] = batch["transforms"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = ModelKit.mesh_of(batch["model"])["mesh"]
		multi.instance_count = transforms.size()
		for i in transforms.size():
			multi.set_instance_transform(i, transforms[i])
		var drawn := MultiMeshInstance3D.new()
		drawn.multimesh = multi
		var height: float = batch["height"]
		drawn.visibility_range_end = DRAW_DISTANCE * clampf(height * 1.5, 0.6, 2.0)
		drawn.visibility_range_end_margin = 2.0
		drawn.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Things smaller than a shoe box don't need shadows of their own.
		if height < 0.2:
			drawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(drawn)
	_batches.clear()


## A thing or two left on a desk or table top (its centre at `top`, `size` across and deep,
## turned by `turn`): a stack of books, loose sheets, a pencil cup, a mug. Some desks get nothing.
func desk_top(top: Vector3, size: Vector2, turn: float, chance := 0.7, staff := false) -> void:
	var picks := ["prop_book_stack", "prop_paper_scrap", "prop_paper_scrap", "prop_pencil_cup"]
	if staff:
		picks.append_array(["prop_coffee_mug", "prop_coffee_mug", "prop_tissue_box"])
	var count := 2 if staff else 1
	for i in count:
		if rng.randf() > chance:
			continue
		var model: String = picks[rng.randi() % picks.size()]
		var along := Vector3(rng.randf_range(-0.35, 0.35) * size.x, 0, rng.randf_range(-0.3, 0.3) * size.y)
		put(model, top + along.rotated(Vector3.UP, turn), SMALL[model], turn + rng.randf_range(-0.6, 0.6))


## How tall the small things are.
const SMALL := {"prop_book_stack": 0.11, "prop_paper_scrap": 0.012, "prop_pencil_cup": 0.16,
	"prop_coffee_mug": 0.1, "prop_tissue_box": 0.13, "prop_milk_carton": 0.11, "prop_paper_ball": 0.05,
	"prop_paper_ball_b": 0.07}


## Crumpled paper and the odd dropped sheet on a floor between x1-x2 and z1-z2.
func litter(x1: float, x2: float, z1: float, z2: float, count: int) -> void:
	for i in count:
		var model: String = ["prop_paper_ball", "prop_paper_ball_b", "prop_paper_scrap"][rng.randi() % 3]
		var height: float = SMALL.get(model, 0.012)
		put(model, Vector3(rng.randf_range(x1, x2), 0.0, rng.randf_range(z1, z2)), height, rng.randf() * TAU)


## A school bag dropped by a desk or a locker: standing, or flopped on its back.
func bag(at: Vector3) -> void:
	if rng.randf() < 0.4:
		put("prop_backpack", at + Vector3(0, 0.16, 0), 0.4, rng.randf() * TAU, PI * 0.5)
	else:
		put("prop_backpack", at, 0.42, rng.randf() * TAU, rng.randf_range(-0.15, 0.1))


## Cobwebs in the top corners of a room (inside faces x1-x2, z1-z2), each corner with a
## `chance`, strung across the corner under a ceiling `ceiling` high.
func corner_webs(x1: float, x2: float, z1: float, z2: float, ceiling: float, chance := 0.6) -> void:
	for corner: Vector2 in [Vector2(x1, z1), Vector2(x2, z1), Vector2(x1, z2), Vector2(x2, z2)]:
		if rng.randf() > chance:
			continue
		var into := Vector3(signf((x1 + x2) * 0.5 - corner.x), 0, signf((z1 + z2) * 0.5 - corner.y)).normalized()
		var model: String = ["prop_cobweb_sag", "prop_cobweb_corner", "prop_cobweb_corner_b"][rng.randi() % 3]
		var height := rng.randf_range(0.35, 0.6)
		var reach := height * 0.6
		put(model, Vector3(corner.x, ceiling - height - 0.01, corner.y) + into * reach, height, atan2(into.x, into.z))

