class_name SchoolBuilder
extends Node3D
## Builds the placeholder ("greybox") school out of simple boxes: the main building, plus the
## classroom wing (difficulty 2) and science wing (difficulty 3) behind red doors at each end
## of the main hallway.
##
## Units are metres. +X is east, -Z is north (deeper into the school), +Z is south (towards the gate).
##
##   z = -30 +-----------------+--------+------------------+
##           |                 |KITCHEN |                  |
##           |   CAFETERIA     +--------+       GYM        |
##           |                 |CUSTODN |                  |
##   z =   4 +-----------------+--------+------------------+
##           |                  MAIN HALLWAY               |
##   z =  10 +----------+---------+-------+---------+------+
##           | (closed) |  FRONT  | LOBBY | GUARD   |(clsd)|
##           |          |  OFFICE |       | ROOM    |      |
##   z =  20 +----------+---------+--[ ]--+---------+------+
##          x=-40      -20       -6   0   6        20     40
##                         front yard, path, gate at z = 45
##
## The wings (z = -14 to 20) continue the main hallway west (x = -80 to -40) and east (40 to 80):
##
##   CLASSROOM WING (west)                        SCIENCE WING (east)
##   +-----------+---------+                      +-----------+---------+
##   |  LIBRARY  | ROOM 103|                      |SCIENCE LAB|ART ROOM |
##   +-----------+---------+                      +-----------+---------+
##   |      WEST HALL      |== main hallway ==    |      EAST HALL      |
##   +------+------+-------+                      +---------------------+
##   |NURSE | 102  |  101  |                      |    LOCKER ROOMS     |
##   +------+------+-------+                      +---------------------+

const WALL_H := 3.5
const WALL_T := 0.25
const DOOR_H := 2.4
const SCHOOL_NAME := "WESTFIELD HIGH SCHOOL"
## What each camera covers, so monsters and logs can tell which area a spot is in.
const AREAS := {
	"Front Gate": AABB(Vector3(-40, -1, 20), Vector3(80, 8, 28)),
	"Lobby": AABB(Vector3(-6, -1, 10), Vector3(12, 6, 10)),
	"Front Office": AABB(Vector3(-20, -1, 10), Vector3(14, 6, 10)),
	"Main Hall West": AABB(Vector3(-40, -1, 4), Vector3(40, 6, 6)),
	"Main Hall East": AABB(Vector3(0, -1, 4), Vector3(40, 6, 6)),
	"Cafeteria": AABB(Vector3(-40, -1, -30), Vector3(35, 6, 34)),
	"Kitchen": AABB(Vector3(-5, -1, -30), Vector3(10, 6, 18)),
	"Gym": AABB(Vector3(5, -1, -30), Vector3(35, 6, 34)),
	"West Hall": AABB(Vector3(-80, -1, 4), Vector3(40, 6, 6)),
	"Room 101": AABB(Vector3(-54, -1, 10), Vector3(14, 6, 10)),
	"Room 102": AABB(Vector3(-68, -1, 10), Vector3(14, 6, 10)),
	"Nurse's Office": AABB(Vector3(-80, -1, 10), Vector3(12, 6, 10)),
	"Room 103": AABB(Vector3(-58, -1, -14), Vector3(18, 6, 18)),
	"Library": AABB(Vector3(-80, -1, -14), Vector3(22, 6, 18)),
	"East Hall": AABB(Vector3(40, -1, 4), Vector3(40, 6, 6)),
	"Science Lab": AABB(Vector3(40, -1, -14), Vector3(22, 6, 18)),
	"Art Room": AABB(Vector3(62, -1, -14), Vector3(18, 6, 18)),
	"Locker Rooms": AABB(Vector3(40, -1, 10), Vector3(40, 6, 10)),
	# No camera covers it, but from night 7 things get in, and guards need to log them.
	"Guard Room": AABB(Vector3(6, -1, 10), Vector3(14, 6, 10)),
}
## The lowest difficulty each wing's areas are open at. Areas not listed are always open.
const AREA_DIFFICULTY := {
	"West Hall": 2, "Room 101": 2, "Room 102": 2, "Nurse's Office": 2, "Room 103": 2, "Library": 2,
	"East Hall": 3, "Science Lab": 3, "Art Room": 3, "Locker Rooms": 3,
}
## The wing doors at each end of the main hallway, and the difficulty that opens them.
const WING_DOORS := [
	{"x": -40.0, "difficulty": 2, "sign": "CLASSROOM WING\nclosed"},
	{"x": 40.0, "difficulty": 3, "sign": "SCIENCE WING\nclosed"},
]
## The navigation mesh covers the whole school, both wings included.
const NAV_BOUNDS := AABB(Vector3(-81, -1, -31), Vector3(162, 6, 80))
## Physics layer 1 holds the building, props and guards. Monsters live on their own layer.
const NAV_SOURCE_GROUP := "nav_source"
## Size of each guard room monitor's picture, in metres (16:9 like the camera feeds).
const MONITOR_SIZE := Vector2(0.96, 0.54)

## The time clock in the guard room. Main connects it to the shift.
var clock_machine: Interactable
## The vending machine in the guard room. Main opens the shop when it's used.
var vending_machine: Interactable
## Where the 16 guard room monitor screens go: [{"desk", "position"}], in monitor order.
var monitor_spots: Array[Dictionary] = []
## The chair at each guard room desk, and where a seated guard goes.
var desk_chairs: Array[Interactable] = []
var desk_chair_positions: Array[Vector3] = []
## The CCTV cameras: [{"name", "position", "target", "difficulty"}].
var camera_spots: Array[Dictionary] = []
## Things a wing monster uses, e.g. the Self-Portrait's easel. Set while building.
var self_portrait_easel: Interactable
## The school bell's control panel in the front office. Shuts off the Bell.
var bell_panel: Interactable
var specimen_jar: Node3D

var _wing_doors: Array[Node3D] = []

var _mats: Dictionary = {}


## The camera area a point is in, or "" if none (e.g. the guard room).
static func area_at(point: Vector3) -> String:
	for area: String in AREAS:
		if (AREAS[area] as AABB).has_point(point):
			return area
	return ""


## The lowest difficulty an area is open at (1 for the main building).
static func area_difficulty(area: String) -> int:
	return AREA_DIFFICULTY.get(area, 1)


## Is this point somewhere guards and monsters can go at this difficulty?
static func is_open_at(point: Vector3, difficulty: int) -> bool:
	return area_difficulty(area_at(point)) <= difficulty


func _ready() -> void:
	add_to_group(NAV_SOURCE_GROUP)
	_make_materials()
	_build_grounds()
	_build_walls()
	_build_lobby()
	_build_front_office()
	_build_guard_room()
	_build_hallway()
	_build_cafeteria()
	_build_kitchen_and_closet()
	_build_gym()
	_build_signs()
	_build_lights()
	_build_cameras()
	# After the main building's cameras, so those come first on the monitors.
	_build_classroom_wing()
	_build_science_wing()
	_build_facade()
	_merge_static_meshes()


## Thousands of boxes would each be a draw call. Once everything is built, the boxes that never
## change are merged into one mesh per material per 20-metre square (so off-screen squares are
## still skipped). Collision bodies stay as they are. Left alone: anything that's hidden, see-through,
## has children, or gets its look changed later (ceiling light panels).
const MERGE_CELL := 20.0


func _merge_static_meshes() -> void:
	var tools: Dictionary = {}
	var merged: Array[MeshInstance3D] = []
	var to_local := global_transform.affine_inverse()
	for child in get_children():
		var candidates: Array = []
		if child is MeshInstance3D:
			candidates.append(child)
		elif child is StaticBody3D and not child is Interactable and (child as Node3D).visible:
			for part in child.get_children():
				if part is MeshInstance3D:
					candidates.append(part)
		for mesh: MeshInstance3D in candidates:
			var material := mesh.material_override as StandardMaterial3D
			if not mesh.visible or mesh.get_child_count() > 0 or not mesh.mesh is BoxMesh or material == null \
					or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED \
					or material == _mats["light_panel"] or material == _mats["flood_glow"]:
				continue
			var xform := to_local * mesh.global_transform
			var cell := Vector2i(floori(xform.origin.x / MERGE_CELL), floori(xform.origin.z / MERGE_CELL))
			var key := "%d|%d|%d" % [material.get_instance_id(), cell.x, cell.y]
			if not tools.has(key):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[key] = [tool, material]
			(tools[key][0] as SurfaceTool).append_from(mesh.mesh, 0, xform)
			merged.append(mesh)
	for key: String in tools:
		var batch := MeshInstance3D.new()
		batch.mesh = (tools[key][0] as SurfaceTool).commit()
		batch.material_override = tools[key][1]
		add_child(batch)
	for mesh in merged:
		mesh.free()


# --- Materials ---------------------------------------------------------------

func _make_materials() -> void:
	_add_mat("grass", Color(0.11, 0.16, 0.1))
	_add_mat("concrete", Color(0.3, 0.3, 0.29))
	_add_mat("asphalt", Color(0.09, 0.09, 0.1))
	_add_mat("brick", Color(0.4, 0.22, 0.17))
	_add_mat("wall", Color(0.62, 0.6, 0.52))
	_add_mat("floor", Color(0.5, 0.48, 0.42), 0.6)
	_add_mat("gym_floor", Color(0.6, 0.43, 0.24), 0.45)
	_add_mat("ceiling", Color(0.45, 0.44, 0.4))
	_add_mat("wood", Color(0.33, 0.25, 0.17))
	_add_mat("desk", Color(0.4, 0.34, 0.26))
	_add_mat("metal", Color(0.42, 0.44, 0.46), 0.45)
	_add_mat("dark", Color(0.08, 0.08, 0.09), 0.5)
	_add_mat("locker", Color(0.2, 0.3, 0.42), 0.55)
	_add_mat("red", Color(0.45, 0.1, 0.1))
	_add_mat("plant", Color(0.12, 0.3, 0.14))
	_add_mat("costume", Color(0.45, 0.32, 0.2))
	_add_mat("cork", Color(0.55, 0.4, 0.25))
	_add_mat("clock_screen", Color(0.02, 0.06, 0.02), 0.3, Color(0.2, 0.9, 0.3), 1.2)
	_add_mat("vending_glow", Color(0.1, 0.1, 0.12), 0.3, Color(0.7, 0.85, 1.0), 1.0)
	_add_mat("light_panel", Color(1, 1, 1), 0.5, Color(1.0, 0.95, 0.85), 2.0)
	_add_mat("light_panel_off", Color(0.55, 0.55, 0.52), 0.5)
	_add_mat("flood_glow", Color(1, 1, 1), 0.3, Color(1.0, 0.97, 0.9), 4.0)
	_add_mat("flood_off", Color(0.15, 0.15, 0.16), 0.3)
	_add_mat("led", Color(1, 0.1, 0.1), 0.5, Color(1, 0.1, 0.05), 3.0)
	_add_mat("lamp_glow", Color(1, 0.8, 0.5), 0.5, Color(1.0, 0.7, 0.4), 3.0)
	_add_mat("glass", Color(0.6, 0.75, 0.8), 0.1, Color.BLACK, 0.0, 0.25)
	_add_mat("fence", Color(0.35, 0.37, 0.38), 0.5, Color.BLACK, 0.0, 0.35)
	_add_mat("board", Color(0.08, 0.16, 0.12), 0.8)
	_add_mat("canvas", Color(0.85, 0.82, 0.74), 0.9)
	_add_mat("gym_roof", Color(0.2, 0.21, 0.22), 0.8)
	_add_mat("steel", Color(0.3, 0.32, 0.34), 0.45)
	_add_mat("riser", Color(0.16, 0.17, 0.19), 0.6)
	_add_mat("safety_yellow", Color(0.85, 0.68, 0.1), 0.6)
	_add_mat("paint_white", Color(0.92, 0.92, 0.9), 0.5)
	_add_mat("pad", Color(0.1, 0.15, 0.32), 0.7)
	_add_mat("rim", Color(0.85, 0.3, 0.06), 0.4)
	_add_mat("night_window", Color(0.03, 0.04, 0.07), 0.1, Color(0.16, 0.22, 0.38), 0.7)
	_add_mat("jar", Color(0.55, 0.75, 0.45), 0.1, Color(0.3, 0.5, 0.2), 0.6, 0.55)
	_make_gym_materials()
	_add_mat("linen", Color(0.85, 0.86, 0.84), 0.95)
	_add_mat("window_out", Color(0.05, 0.06, 0.08), 0.08)
	_add_mat("window_lit", Color(0.3, 0.25, 0.15), 0.2, Color(1.0, 0.82, 0.5), 0.9)
	_add_mat("baseboard", Color(0.1, 0.1, 0.11), 0.7)
	_add_mat("door_frame", Color(0.24, 0.27, 0.3), 0.45)
	_add_mat("tray", Color(0.45, 0.6, 0.66), 0.5)
	_add_mat("curtain", Color(0.38, 0.5, 0.5), 1.0)
	_add_mat("lab_base", Color(0.5, 0.53, 0.48), 0.7)
	_add_mat("lab_top", Color(0.05, 0.05, 0.06), 0.25)
	var books := StandardMaterial3D.new()
	books.albedo_texture = load("res://assets/textures/school/bookcase.png")
	books.uv1_scale = Vector3(4, 1, 1)
	books.roughness = 0.9
	_mats["books"] = books
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(0.85, 0.66, 0.22)
	gold.metallic = 0.85
	gold.roughness = 0.3
	_mats["gold"] = gold


## Surfaces with a texture in assets/textures, and how many metres one copy of it covers. They're
## mapped in world space, so every box tiles at the same scale. The .jpg ones are CC0 photo
## textures from Poly Haven (see CREDITS.md); the .png ones are made by tools/gen_textures.py.
const TEXTURE_METRES := {
	"floor": 2.4, "wall": 1.8, "ceiling": 1.2, "brick": 1.0, "concrete": 2.5, "asphalt": 2.1,
	"grass": 2.5, "gym_floor": 1.7, "wood": 1.7, "desk": 0.6, "metal": 1.0, "locker": 1.2,
	"cork": 1.0, "board": 2.0,
}


## Gym materials that need more than a colour: the bleacher seats (the floor's wood, darker),
## the hoop nets and the basketballs.
func _make_gym_materials() -> void:
	var seat := (_mats["gym_floor"] as StandardMaterial3D).duplicate() as StandardMaterial3D
	seat.albedo_color = Color(0.82, 0.66, 0.5)
	_mats["bleacher_seat"] = seat
	var net := StandardMaterial3D.new()
	net.albedo_texture = load("res://assets/textures/gym/net.png")
	net.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	net.cull_mode = BaseMaterial3D.CULL_DISABLED
	net.uv1_scale = Vector3(4, 1, 1)
	net.roughness = 1.0
	_mats["net"] = net
	var ball := StandardMaterial3D.new()
	ball.albedo_texture = load("res://assets/textures/gym/basketball.png")
	ball.roughness = 0.75
	_mats["basketball"] = ball


func _add_mat(mat_name: String, color: Color, roughness := 0.9, emission := Color.BLACK,
		emission_energy := 0.0, alpha := 1.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	var ext := "jpg" if ResourceLoader.exists("res://assets/textures/%s.jpg" % mat_name) else "png"
	var path := "res://assets/textures/%s.%s" % [mat_name, ext]
	if TEXTURE_METRES.has(mat_name) and ResourceLoader.exists(path):
		# The texture carries the colour itself.
		mat.albedo_color = Color.WHITE
		mat.albedo_texture = load(path)
		mat.normal_enabled = true
		mat.normal_texture = load("res://assets/textures/%s_n.%s" % [mat_name, ext])
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 8.0
		mat.uv1_scale = Vector3.ONE / float(TEXTURE_METRES[mat_name])
		# A locker texture is one locker tall, so its vents sit at the top of every door.
		if mat_name == "locker":
			mat.uv1_scale = Vector3(1.0 / 2.0, 1.0 / 1.9, 1.0 / 2.0)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = emission_energy
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = alpha
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[mat_name] = mat


# --- Building blocks -----------------------------------------------------------

## Adds a box centred on `pos`. Solid boxes get collision so guards can't walk through them.
func _box(pos: Vector3, size: Vector3, mat: String, solid := true) -> Node3D:
	var mesh := _box_mesh(size, mat)
	if not solid:
		mesh.position = pos
		add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	_fill_body(body, pos, size, mesh)
	return body


## A ready-made model (assets/models/<name>.glb) with its feet at `pos`, `height` tall, turned
## by `turn` (0: its front faces +Z). Null if there's no such model: keep the boxes.
func _model(model_name: String, pos: Vector3, height: float, turn := 0.0) -> Node3D:
	if not ResourceLoader.exists("res://assets/models/%s.glb" % model_name):
		return null
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	return ModelKit.add(holder, model_name, height, turn)


## Hides the boxes drawn for something that now has a model (its collision stays).
func _hide_boxes(node: Node) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).visible = false
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).visible = false


func _box_mesh(size: Vector3, mat: String) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = _mats[mat]
	return mesh


func _fill_body(body: StaticBody3D, pos: Vector3, size: Vector3, mesh: MeshInstance3D) -> void:
	body.position = pos
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	body.add_child(mesh)
	add_child(body)


func _interactable(pos: Vector3, size: Vector3, mat: String, prompt: String, message: String) -> Interactable:
	var body := Interactable.new()
	body.prompt = prompt
	body.message = message
	_fill_body(body, pos, size, _box_mesh(size, mat))
	return body


## A wall running east-west at depth `z`, from `x1` to `x2`.
## Each opening is [centre, width] or [centre, width, height].
func _wall_x(z: float, x1: float, x2: float, openings: Array = [], mat := "wall") -> void:
	_wall(true, z, x1, x2, openings, mat)


## A wall running north-south at `x`, from `z1` to `z2`.
func _wall_z(x: float, z1: float, z2: float, openings: Array = [], mat := "wall") -> void:
	_wall(false, x, z1, z2, openings, mat)


func _wall(along_x: bool, fixed: float, from: float, to: float, openings: Array, mat: String) -> void:
	# Stretch each wall by half its thickness so corners meet without gaps.
	var start := from - WALL_T * 0.5
	var end := to + WALL_T * 0.5
	var sorted := openings.duplicate()
	sorted.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var cursor := start
	for opening: Array in sorted:
		var width: float = opening[1]
		var height: float = opening[2] if opening.size() > 2 else DOOR_H
		var gap_start: float = opening[0] - width * 0.5
		var gap_end: float = opening[0] + width * 0.5
		if gap_start > cursor:
			_wall_piece(along_x, fixed, cursor, gap_start, 0.0, WALL_H, mat)
		_wall_piece(along_x, fixed, gap_start, gap_end, height, WALL_H, mat)
		_door_frame(along_x, fixed, gap_start, gap_end, height)
		cursor = gap_end
	if end > cursor:
		_wall_piece(along_x, fixed, cursor, end, 0.0, WALL_H, mat)


func _wall_piece(along_x: bool, fixed: float, from: float, to: float, bottom: float, top: float, mat: String) -> void:
	var length := to - from
	var middle := (from + to) * 0.5
	var height := top - bottom
	if along_x:
		_box(Vector3(middle, bottom + height * 0.5, fixed), Vector3(length, height, WALL_T), mat)
	else:
		_box(Vector3(fixed, bottom + height * 0.5, middle), Vector3(WALL_T, height, length), mat)
	# Painted walls get a dark rubber baseboard along both sides.
	if bottom == 0.0 and mat == "wall":
		var skirt := Vector3(length, 0.1, WALL_T + 0.024) if along_x else Vector3(WALL_T + 0.024, 0.1, length)
		_box(Vector3(middle, 0.05, fixed) if along_x else Vector3(fixed, 0.05, middle), skirt, "baseboard", false)


## A painted steel frame round a doorway, on both sides of the wall.
func _door_frame(along_x: bool, fixed: float, from: float, to: float, height: float) -> void:
	const BAR := 0.07
	var depth := WALL_T + 0.05
	var place := func(along: float, y: float, size_along: float, size_y: float) -> void:
		var size := Vector3(size_along, size_y, depth) if along_x else Vector3(depth, size_y, size_along)
		_box(Vector3(along, y, fixed) if along_x else Vector3(fixed, y, along), size, "door_frame", false)
	place.call(from - BAR * 0.5 + 0.01, height * 0.5, BAR, height)
	place.call(to + BAR * 0.5 - 0.01, height * 0.5, BAR, height)
	place.call((from + to) * 0.5, height + BAR * 0.5, to - from + BAR * 2.0 - 0.02, BAR)


func _sign(text: String, pos: Vector3, facing: Vector3, font_size := 56, color := Color(0.95, 0.93, 0.85)) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.004
	label.modulate = color
	label.outline_size = 8
	label.double_sided = false
	label.position = pos
	label.rotation.y = atan2(facing.x, facing.z)
	add_child(label)


## A light that ShiftLighting switches between its before-shift and night brightness.
## `night_energy` of 0 means the light is switched off when the shift starts.
## `day_energy` below 0 means "a well-lit version of the night value".
func _light(pos: Vector3, night_energy := 0.6, light_range := 8.0, flicker := false, panel := true,
		color := Color(1.0, 0.95, 0.85), day_energy := -1.0) -> OmniLight3D:
	var light: OmniLight3D
	if flicker:
		light = FlickerLight.new()
	else:
		light = OmniLight3D.new()
	if day_energy < 0.0:
		day_energy = maxf(night_energy * 3.5, 2.4)
	light.position = pos
	light.light_energy = day_energy
	light.omni_range = light_range
	light.light_color = color
	light.set_meta("day_energy", day_energy)
	light.set_meta("night_energy", night_energy)
	light.add_to_group(ShiftLighting.SCHOOL_LIGHTS)
	add_child(light)
	if panel:
		light.set_meta("panel", _box(Vector3(pos.x, WALL_H - 0.03, pos.z), Vector3(1.2, 0.04, 0.3), "light_panel", false))
	return light


## One of the gym's hanging lamps: the model, a glowing lens under it that dims with the light,
## and the light itself just below.
func _gym_lamp(x: float, z: float, night_energy: float, flicker := false) -> void:
	const LAMP_H := 1.36
	var bottom := GYM_H - LAMP_H
	var light := _light(Vector3(x, bottom - 0.3, z), night_energy, 17.0, flicker, false,
			Color(1.0, 0.94, 0.82), maxf(night_energy * 4.0, 3.2))
	_model("prop_hanging_industrial_lamp", Vector3(x, bottom, z), LAMP_H)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.02
	var lens := MeshInstance3D.new()
	lens.mesh = disc
	lens.material_override = _mats["light_panel"]
	lens.position = Vector3(x, bottom + 0.03, z)
	add_child(lens)
	light.set_meta("panel", lens)


## A floodlight that is on before the shift and cut when the night starts.
## `rotation_deg` aims it: a spotlight with no rotation points north (-Z).
func _floodlight(pos: Vector3, rotation_deg: Vector3, energy: float, light_range: float, angle: float) -> void:
	var housing := _box(pos, Vector3(0.6, 0.35, 0.35), "dark", false)
	housing.rotation_degrees = rotation_deg
	var lens := _box_mesh(Vector3(0.5, 0.27, 0.02), "flood_glow")
	lens.position = Vector3(0, 0, -0.18)
	housing.add_child(lens)
	var light := SpotLight3D.new()
	light.position = pos
	light.rotation_degrees = rotation_deg
	light.light_energy = energy
	light.spot_range = light_range
	light.spot_angle = angle
	light.light_color = Color(1.0, 0.97, 0.9)
	light.set_meta("lens", lens)
	light.add_to_group(ShiftLighting.FLOODLIGHTS)
	add_child(light)


## Posters' materials, one per picture (see _poster).
var _posters: Dictionary = {}


## Hands out shared materials, e.g. so lighting can dim every ceiling panel at once.
func get_material(mat_name: String) -> StandardMaterial3D:
	return _mats[mat_name]


## A wall-mounted CCTV camera: a small housing with a red light, plus a spot for SecurityCameras.
func _camera(camera_name: String, pos: Vector3, target: Vector3, difficulty := 1) -> void:
	var housing := _box(pos, Vector3(0.18, 0.14, 0.3), "dark", false)
	housing.look_at(target)
	var led := _box_mesh(Vector3(0.03, 0.03, 0.01), "led")
	led.position = Vector3(0.05, 0.04, -0.155)
	housing.add_child(led)
	camera_spots.append({"name": camera_name, "position": pos + (target - pos).normalized() * 0.2, "target": target,
			"difficulty": difficulty})


# --- Areas -------------------------------------------------------------------

func _build_grounds() -> void:
	# Grass sits a touch lower than the building floor so the two never flicker against each other.
	_box(Vector3(0, -0.27, 10), Vector3(220, 0.5, 170), "grass")
	_box(Vector3(0, -0.1, -5), Vector3(80, 0.2, 50), "floor")
	# The ceiling everywhere but the gym, which has its own roof higher up.
	_box(Vector3(-17.625, WALL_H + 0.1, -5), Vector3(45.25, 0.2, 50.5), "ceiling", false)
	_box(Vector3(22.625, WALL_H + 0.1, 12.125), Vector3(35.25, 0.2, 16.25), "ceiling", false)
	# Path from the street, through the gate, to the front doors.
	_box(Vector3(0, -0.11, 42), Vector3(4, 0.2, 44), "concrete")
	# Street outside the gate.
	_box(Vector3(0, -0.11, 66), Vector3(220, 0.2, 10), "asphalt")
	_build_fence()


func _build_fence() -> void:
	const FENCE_Z := 45.0
	const FENCE_H := 2.2
	const GATE_HALF := 2.5
	# Front fence with the gate gap, then the two sides back to the building.
	for side: float in [-1.0, 1.0]:
		var x_mid := side * (40.0 + GATE_HALF) * 0.5
		_box(Vector3(x_mid, FENCE_H * 0.5, FENCE_Z), Vector3(40.0 - GATE_HALF, FENCE_H, 0.05), "fence")
		_box(Vector3(side * 40.0, FENCE_H * 0.5, 32.5), Vector3(0.05, FENCE_H, 25.0), "fence")
		# The gate's leaves are Finale's: they shut for the shift.
	var x := -40.0
	while x <= 40.0:
		if absf(x) >= GATE_HALF:
			_box(Vector3(x, FENCE_H * 0.5, FENCE_Z), Vector3(0.08, FENCE_H, 0.08), "metal")
		x += 2.5
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * GATE_HALF, 1.35, FENCE_Z), Vector3(0.15, 2.7, 0.15), "metal")
	_box(Vector3(0, 2.75, FENCE_Z), Vector3(GATE_HALF * 2.0 + 0.3, 0.5, 0.08), "dark")
	# Lamps either side of the gate: bright while people arrive, dimmed for the night.
	for side: float in [-1.0, 1.0]:
		_lamp_post(Vector3(side * 4.0, 0, 47.0), 1.0, 4.0)
	# Street lights along the road. They belong to the town, so they stay on all night.
	var street_x := -60.0
	while street_x <= 60.0:
		_lamp_post(Vector3(street_x, 0, 60.5), 2.2, 2.2)
		street_x += 20.0
	# Floodlights on the front of the building, aimed down at the yard...
	for flood_x: float in [-32.0, -18.0, -8.0, 8.0, 18.0, 32.0]:
		_floodlight(Vector3(flood_x, 3.2, 20.45), Vector3(-40, 180, 0), 9.0, 28.0, 55.0)
	# ...and two on poles in the yard, washing the brick front with light.
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 22.0, 0.6, 40.0), Vector3(0.15, 1.2, 0.15), "metal")
		_floodlight(Vector3(side * 22.0, 1.3, 40.0), Vector3(12, side * -10.0, 0), 16.0, 45.0, 38.0)


func _lamp_post(base: Vector3, night_energy: float, day_energy: float) -> void:
	_box(base + Vector3(0, 2.25, 0), Vector3(0.15, 4.5, 0.15), "metal")
	_box(base + Vector3(0, 4.5, 0), Vector3(0.5, 0.15, 0.3), "lamp_glow", false)
	_light(base + Vector3(0, 4.3, 0), night_energy, 16.0, false, false, Color(1.0, 0.72, 0.42), day_energy)


func _build_walls() -> void:
	# Outside walls. The front doors are a wide opening in the south wall.
	_wall_x(20, -40, 40, [[0.0, 4.0, 2.7]], "brick")
	_wall_x(-30, -40, 40, [], "brick")
	# The ends of the main hallway lead into the wings.
	_wall_z(-40, -30, 20, [[7.0, 2.6]], "brick")
	_wall_z(40, -30, 20, [[7.0, 2.6]], "brick")

	# North side of the main hallway: lobby arch and the guard room's back door.
	_wall_x(10, -40, 40, [[0.0, 6.0, 3.0], [16.0, 1.6]])
	# Rooms along the front of the building.
	_wall_z(-20, 10, 20)
	_wall_z(-6, 10, 20, [[15.0, 1.6]])
	_wall_z(6, 10, 20, [[15.0, 1.6]])
	_wall_z(20, 10, 20)

	# South side of the main hallway: cafeteria, custodian's closet, gym.
	_wall_x(4, -40, 40, [[-15.0, 3.0], [0.0, 1.6], [15.0, 3.0]])
	_wall_z(-5, -30, 4, [[-21.0, 1.8]])
	_wall_z(5, -30, 4)
	_wall_x(-12, -5, 5)


func _build_lobby() -> void:
	# The east bench and the plant belong to Anomalies, since they can move or go missing.
	_box(Vector3(-4.0, 0.22, 18.8), Vector3(2.4, 0.44, 0.6), "wood")
	# Trophy case.
	_box(Vector3(-5.55, 0.5, 12.5), Vector3(0.6, 1.0, 2.4), "wood")
	_box(Vector3(-5.55, 1.5, 12.5), Vector3(0.58, 1.0, 2.38), "glass")
	# Doormat.
	_box(Vector3(0, 0.01, 19.0), Vector3(3.5, 0.02, 1.5), "dark", false)
	# Trophies on two glass shelves in the case.
	for shelf_y: float in [1.0, 1.5]:
		_box(Vector3(-5.55, shelf_y, 12.5), Vector3(0.5, 0.015, 2.3), "glass", false)
	for i in 6:
		_trophy(Vector3(-5.55, 1.0 if i < 3 else 1.5, 11.75 + (i % 3) * 0.75), 1.6 if i % 3 == 1 else 1.1)
	_model("prop_wall_clock", Vector3(0, 2.85, 19.875), 0.38, PI)
	_model("prop_fire_alarm", Vector3(-3.6, 1.3, 10.125), 0.2)
	_poster("poster_basketball", Vector3(5.875, 1.6, 18.0), Vector3.LEFT)


func _build_front_office() -> void:
	# Reception counter with a gap to walk through.
	_box(Vector3(-9.0, 0.55, 18.0), Vector3(0.6, 1.1, 4.0), "wood")
	_box(Vector3(-9.0, 0.55, 12.0), Vector3(0.6, 1.1, 2.0), "wood")
	for desk_pos: Vector3 in [Vector3(-14, 0, 13), Vector3(-14, 0, 17.5), Vector3(-18, 0, 15)]:
		_steel_desk(desk_pos, PI)
	_model("prop_classic_laptop", Vector3(-18.0, 0.77, 15.05), 0.24, PI)
	# Filing cabinets: four drawers each, with handles.
	for i in 4:
		var cabinet_x := -19.2 + i * 0.6
		_box(Vector3(cabinet_x, 0.65, 10.45), Vector3(0.55, 1.3, 0.6), "metal")
		for drawer in 4:
			var drawer_y := 0.16 + drawer * 0.32
			_box(Vector3(cabinet_x, drawer_y + 0.15, 10.752), Vector3(0.5, 0.012, 0.006), "dark", false)
			_box(Vector3(cabinet_x, drawer_y + 0.06, 10.765), Vector3(0.14, 0.025, 0.02), "steel", false)
	_solid_model("prop_shelf_01", Vector3(-11.5, 0, 19.72), 2.0, PI, Vector3(0.96, 2.0, 0.26))
	_model("prop_wall_clock", Vector3(-14.0, 2.4, 19.875), 0.36, PI)
	_model("prop_hanging_picture_frame_01", Vector3(-19.875, 1.35, 16.2), 0.7, PI * 0.5)
	_poster("poster_lost_found", Vector3(-6.125, 1.55, 17.3), Vector3.LEFT)
	# The bell's control panel, by the filing cabinets.
	bell_panel = _interactable(Vector3(-19.82, 1.5, 18.5), Vector3(0.1, 0.5, 0.4), "metal", "School bell panel", "")
	_box(Vector3(-19.76, 1.62, 18.5), Vector3(0.02, 0.1, 0.1), "led", false)
	# The PA microphone the Principal will use.
	_box(Vector3(-18.0, 0.82, 14.8), Vector3(0.1, 0.12, 0.1), "dark", false)


func _build_guard_room() -> void:
	# Four desks against the front wall, each with a 2x2 bank of monitors facing the chair.
	for i in 4:
		var x := 7.9 + i * 3.4
		_desk(Vector3(x, 0, 19.0), 2.8, 1.0)
		# Top row first, left to right as seen from the chair (the chair faces +Z, so its left is +X).
		var number := 1
		for row in [1, 0]:
			for col in [1, 0]:
				var screen_pos := Vector3(x + (col - 0.5) * (MONITOR_SIZE.x + 0.06), 1.06 + row * 0.6, 19.15)
				_box(screen_pos, Vector3(MONITOR_SIZE.x + 0.05, MONITOR_SIZE.y + 0.05, 0.06), "dark", false)
				monitor_spots.append({"desk": i, "position": screen_pos + Vector3(0, 0, -0.035)})
				_sign(str(number), screen_pos + Vector3(MONITOR_SIZE.x * 0.5 - 0.03, -MONITOR_SIZE.y * 0.5 - 0.0, -0.04),
						Vector3.FORWARD, 22, Color(0.7, 0.75, 0.7))
				number += 1
		_box(Vector3(x, 1.05, 19.24), Vector3(0.1, 0.6, 0.06), "metal", false)
		_chair(Vector3(x, 0, 18.0), i)

	# Clock machine on the east wall.
	clock_machine = _interactable(Vector3(19.72, 1.4, 13.0), Vector3(0.3, 0.6, 0.5), "metal", "Clock in", "")
	var clock_screen := _box(Vector3(19.56, 1.52, 13.0), Vector3(0.02, 0.15, 0.35), "clock_screen", false)
	if _model("prop_time_clock", Vector3(19.75, 1.1, 13.0), 0.6, -PI / 2.0):
		_hide_boxes(clock_machine)
		clock_screen.visible = false

	# Vending machine on the east wall.
	vending_machine = _interactable(Vector3(19.4, 1.0, 16.6), Vector3(0.9, 2.0, 1.1), "red", "Use the vending machine", "")
	var vending_glow := _box(Vector3(18.94, 1.2, 16.45), Vector3(0.02, 1.3, 0.7), "vending_glow", false)
	if _model("prop_vending_machine", Vector3(19.45, 0, 16.6), 2.0, -PI / 2.0):
		_hide_boxes(vending_machine)
		vending_glow.visible = false

	# Notice board on the back wall.
	_box(Vector3(9.5, 1.6, 10.16), Vector3(2.4, 1.2, 0.05), "cork", false)


func _build_hallway() -> void:
	# Lockers line both sides, leaving gaps for the doorways.
	for span: Vector2 in [Vector2(-39.6, -3.2), Vector2(3.2, 14.9), Vector2(17.1, 39.6)]:
		_locker_row(span.x, span.y, 9.62)
	for span: Vector2 in [Vector2(-39.6, -16.7), Vector2(-13.3, -1.0), Vector2(1.0, 13.3), Vector2(16.7, 39.6)]:
		_locker_row(span.x, span.y, 4.38)
	# Posters above the lockers, and clocks.
	for item: Array in [["poster_no_running", -30.0, 9.875], ["poster_dance", -9.0, 9.875], ["poster_president", 32.0, 9.875],
			["poster_science_fair", -21.0, 4.125], ["poster_basketball", 11.5, 4.125], ["poster_no_running", 25.0, 4.125]]:
		var on_north: bool = item[2] > 7.0
		_poster(item[0], Vector3(item[1], 2.5, item[2]), Vector3.FORWARD if on_north else Vector3.BACK)
	_model("prop_wall_clock", Vector3(-14.0, 2.35, 9.875), 0.36, PI)
	_model("prop_wall_clock", Vector3(21.0, 2.35, 4.125), 0.36)


func _locker_row(x1: float, x2: float, z: float) -> void:
	const DEPTH := 0.5
	const HEIGHT := 1.9
	_box(Vector3((x1 + x2) * 0.5, HEIGHT * 0.5, z), Vector3(x2 - x1, HEIGHT, DEPTH), "locker", false)
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(x2 - x1, HEIGHT, DEPTH)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.position = Vector3((x1 + x2) * 0.5, HEIGHT * 0.5, z)
	body.add_child(collider)
	add_child(body)
	# The doors: one painted locker door, repeated along the row's front.
	var facing := 1.0 if z < 7.0 else -1.0
	var doors := int(round((x2 - x1) / 0.5))
	var key := "lockers_%d" % doors
	if not _mats.has(key):
		var front := StandardMaterial3D.new()
		front.albedo_texture = load("res://assets/textures/school/locker.png")
		front.normal_enabled = true
		front.normal_texture = load("res://assets/textures/school/locker_n.png")
		front.uv1_scale = Vector3(doors, 1, 1)
		front.roughness = 0.5
		front.metallic = 0.35
		_mats[key] = front
	var quad := QuadMesh.new()
	quad.size = Vector2(x2 - x1, HEIGHT)
	var face := MeshInstance3D.new()
	face.mesh = quad
	face.material_override = _mats[key]
	face.position = Vector3((x1 + x2) * 0.5, HEIGHT * 0.5, z + facing * (DEPTH * 0.5 + 0.004))
	face.rotation.y = 0.0 if facing > 0.0 else PI
	add_child(face)


func _build_cafeteria() -> void:
	for z: float in [-1.5, -8.0, -14.5, -21.0]:
		for x: float in [-33.0, -23.5]:
			var parts: Array[Node3D] = [_box(Vector3(x, 0.74, z), Vector3(6.0, 0.06, 1.0), "desk"),
					_box(Vector3(x, 0.36, z), Vector3(5.6, 0.72, 0.15), "metal")]
			for side: float in [-1.0, 1.0]:
				parts.append(_box(Vector3(x, 0.22, z + side * 0.85), Vector3(6.0, 0.44, 0.35), "metal"))
			# Two real tables, end to end, where the boxes stand (they stay as the solid part).
			if _model("prop_cafeteria_table", Vector3(x - 1.5, 0, z), 0.8) and _model("prop_cafeteria_table", Vector3(x + 1.5, 0, z), 0.8):
				for part in parts:
					_hide_boxes(part)
	# Serving counter in front of the kitchen door, with a sneeze guard and a tray rail.
	for counter: Vector2 in [Vector2(-26.0, 6.0), Vector2(-16.5, 5.0)]:
		_box(Vector3(-7.5, 0.5, counter.x), Vector3(0.8, 1.0, counter.y), "metal")
		_box(Vector3(-7.5, 1.4, counter.x), Vector3(0.5, 0.02, counter.y - 0.2), "glass", false)
		for end: float in [-1.0, 1.0]:
			_box(Vector3(-7.5, 1.2, counter.x + end * (counter.y * 0.5 - 0.15)), Vector3(0.03, 0.4, 0.03), "steel", false)
		_box(Vector3(-8.05, 0.85, counter.x), Vector3(0.3, 0.03, counter.y), "steel", false)
		# Food pans set into the counter top.
		var pan := counter.x - counter.y * 0.5 + 0.6
		while pan < counter.x + counter.y * 0.5 - 0.4:
			_box(Vector3(-7.45, 1.0, pan), Vector3(0.5, 0.012, 0.42), "steel", false)
			pan += 0.55
	# A stack of lunch trays at the start of the line.
	for tray in 8:
		_box(Vector3(-8.05, 0.88 + tray * 0.018, -14.35), Vector3(0.32, 0.014, 0.45), "tray", false)
	_poster("menu", Vector3(-5.125, 1.7, -21.5 + 3.1), Vector3.LEFT, Vector2(0.9, 1.2))
	# The other trash can (by the hallway) belongs to Anomalies.
	_box(Vector3(-38.8, 0.45, -27.5), Vector3(0.6, 0.9, 0.6), "dark")
	_model("prop_wall_clock", Vector3(-22.5, 2.5, 3.875), 0.4, PI)
	_poster("poster_dance", Vector3(-30.0, 1.7, 3.875), Vector3.FORWARD)
	_poster("poster_president", Vector3(-34.0, 1.7, 3.875), Vector3.FORWARD)


func _build_kitchen_and_closet() -> void:
	# Kitchen: counters, a fridge and a stove.
	_box(Vector3(0, 0.45, -29.3), Vector3(9.4, 0.9, 1.0), "metal")
	_box(Vector3(4.2, 1.0, -20.0), Vector3(1.0, 2.0, 1.4), "metal")
	# The fridge's two doors and their handles.
	_box(Vector3(3.695, 1.0, -20.0), Vector3(0.01, 1.96, 0.012), "dark", false)
	for handle_z: float in [-20.12, -19.88]:
		_box(Vector3(3.67, 1.15, handle_z), Vector3(0.03, 0.5, 0.025), "steel", false)
	_box(Vector3(0, 0.45, -18.0), Vector3(3.0, 0.9, 1.2), "dark")
	_solid_model("prop_electric_stove", Vector3(-4.55, 0, -24.9), 0.9, PI * 0.5, Vector3(0.68, 0.9, 0.52))
	_solid_model("prop_electric_stove", Vector3(-4.55, 0, -25.45), 0.9, PI * 0.5, Vector3(0.68, 0.9, 0.52))
	_model("prop_vintage_microwave", Vector3(3.6, 0.9, -29.45), 0.32)
	_solid_model("prop_steel_frame_shelves_01", Vector3(4.55, 0, -23.3), 1.8, -PI * 0.5, Vector3(0.45, 1.8, 0.95))
	_solid_model("prop_plastic_container", Vector3(4.45, 0, -22.0), 0.4, PI * 0.5, Vector3(0.6, 0.4, 0.84))
	_solid_model("prop_industrial_storage_cart", Vector3(2.5, 0, -12.6), 0.9, PI, Vector3(1.05, 0.9, 0.72))
	# Custodian's closet shelves. The mop bucket belongs to Anomalies.
	var shelves := _box(Vector3(-4.5, 1.0, -6.0), Vector3(0.6, 2.0, 6.0), "metal")
	var shelf_z := -8.4
	var have_models := true
	while shelf_z < -3.0 and have_models:
		have_models = _model("prop_steel_frame_shelves_01", Vector3(-4.55, 0, shelf_z), 1.9, PI * 0.5) != null
		shelf_z += 1.0
	if have_models:
		_hide_boxes(shelves)
	for bottle_z: float in [-7.6, -7.35, -4.4]:
		_model("prop_multi_cleaner_5_litre", Vector3(-4.5, 1.9, bottle_z), 0.3, PI * 0.5)
	for bottle_z: float in [-6.3, -5.3, -5.05]:
		_model("prop_multi_cleaner_5_litre", Vector3(-4.6, 0.0, bottle_z), 0.3, PI * 0.5)
	_model("prop_cardboard_box_01", Vector3(-4.5, 1.9, -6.2), 0.3, 0.2)
	_solid_model("prop_cardboard_box_01", Vector3(-4.35, 0, -10.6), 0.34, 0.0, Vector3(0.4, 0.62, 0.52))
	_model("prop_cardboard_box_01", Vector3(-4.35, 0.34, -10.55), 0.28, 0.4)
	_model("prop_plastic_broom", Vector3(4.6, 0, -11.5), 1.2, -PI * 0.5)


## How high the nurse's cot mattresses sit on their bed frames.
const NURSE_MATTRESS_Y := 0.36

## The gym is a hall of its own: its roof is twice the height of the rest of the school.
const GYM_H := 7.5
## The court, painted on the gym floor: 25.6 x 15.2 m with its length running north-south.
const COURT_CENTRE := Vector3(22.5, 0.0, -13.0)
const COURT_HALF := Vector2(7.6, 12.8)
## Bleachers: four tiers, each 0.75 m deep and 0.45 m up, the front row 2.3 m in from the wall.
## The east ones' front edge; the west ones mirror them across the court.
const BLEACHER_FRONT := 36.775
const BLEACHER_TIER := Vector2(0.75, 0.45)
const BLEACHER_ROWS := 4
const BLEACHER_Z := Vector2(-23.0, -3.0)
## The two aisles up each stand (their centres), each this wide.
const BLEACHER_AISLES: Array[float] = [-18.0, -8.0]
const AISLE_WIDTH := 1.1


func _build_gym() -> void:
	_box(Vector3(22.5, 0.005, -13.0), Vector3(34.6, 0.01, 33.6), "gym_floor", false)
	_build_gym_shell()
	_build_court()
	for side: float in [1.0, -1.0]:
		_bleachers(side)
	for end: float in [-1.0, 1.0]:
		_hoop(end)
	_build_gym_walls()
	_build_gym_courtside()
	# The mascot's stand by the gym doors. The costume itself belongs to Anomalies.
	_box(Vector3(9.0, 0.15, 1.5), Vector3(1.2, 0.3, 1.2), "wood")


## The walls carry on up past the rest of the school to the gym's own roof: steel decking on
## beams, with a row of high windows along each end letting in a little moonlight.
func _build_gym_shell() -> void:
	var half_t := WALL_T * 0.5
	_wall_piece(true, 4.0, 5.0 - half_t, 40.0 + half_t, WALL_H, GYM_H, "wall")
	_wall_piece(true, -30.0, 5.0 - half_t, 40.0 + half_t, WALL_H, GYM_H, "brick")
	_wall_piece(false, 5.0, -30.0 - half_t, 4.0 + half_t, WALL_H, GYM_H, "wall")
	_wall_piece(false, 40.0, -30.0 - half_t, 4.0 + half_t, WALL_H, GYM_H, "brick")
	_box(Vector3(22.625, GYM_H + 0.1, -13.0), Vector3(35.25, 0.2, 34.25), "gym_roof", false)
	var z := -27.0
	while z < 3.0:
		_box(Vector3(22.5, GYM_H - 0.25, z), Vector3(34.75, 0.5, 0.22), "steel", false)
		z += 4.5
	for x: float in [14.0, 31.0]:
		_box(Vector3(x, GYM_H - 0.6, -13.0), Vector3(0.18, 0.18, 33.75), "steel", false)
	for wall_z: float in [-29.875, 3.875]:
		var inward := 1.0 if wall_z < 0.0 else -1.0
		for x: float in [9.0, 13.0, 17.0, 28.0, 32.0, 36.0]:
			_box(Vector3(x, 6.35, wall_z + inward * 0.02), Vector3(2.4, 1.1, 0.04), "night_window", false)
			for bar: float in [-0.4, 0.4]:
				_box(Vector3(x + bar, 6.35, wall_z + inward * 0.045), Vector3(0.05, 1.1, 0.02), "steel", false)
			_box(Vector3(x, 6.35, wall_z + inward * 0.045), Vector3(2.4, 0.05, 0.02), "steel", false)


## The court lines and paint, as one see-through sheet just above the wooden floor.
func _build_court() -> void:
	var paint := StandardMaterial3D.new()
	paint.albedo_texture = load("res://assets/textures/gym/court.png")
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.roughness = 0.4
	paint.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var plane := PlaneMesh.new()
	# The picture has a metre of floor round the court; its long side runs along the court.
	plane.size = Vector2(COURT_HALF.y * 2.0 + 2.0, COURT_HALF.x * 2.0 + 2.0)
	var sheet := MeshInstance3D.new()
	sheet.mesh = plane
	sheet.material_override = paint
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position = COURT_CENTRE + Vector3(0, 0.012, 0)
	sheet.rotation.y = PI * 0.5
	add_child(sheet)


## One stand of bleachers: east (side 1) or west (side -1). The tiers are solid steps (dark steel
## risers) you can climb; on each sit a wooden deck and, along its front edge, a seat plank.
## Two aisles have half-steps with yellow edges and a hand rail up the middle.
func _bleachers(side: float) -> void:
	var along := func(depth: float) -> float:
		return BLEACHER_FRONT + depth if side > 0.0 else 45.0 - BLEACHER_FRONT - depth
	var length := BLEACHER_Z.y - BLEACHER_Z.x
	var middle_z := (BLEACHER_Z.x + BLEACHER_Z.y) * 0.5
	var seats := _gaps_between(BLEACHER_Z, BLEACHER_AISLES, AISLE_WIDTH)
	for row in BLEACHER_ROWS:
		var front: float = row * BLEACHER_TIER.x
		var top: float = (row + 1) * BLEACHER_TIER.y
		var centre_x: float = along.call(front + BLEACHER_TIER.x * 0.5)
		_box(Vector3(centre_x, top * 0.5, middle_z), Vector3(BLEACHER_TIER.x, top, length), "riser")
		_box(Vector3(centre_x, top + 0.015, middle_z), Vector3(BLEACHER_TIER.x - 0.02, 0.03, length), "gym_floor", false)
		# The seat: a thick plank along the front edge, standing a little proud of the riser.
		for run: Vector2 in seats:
			_box(Vector3(along.call(front + 0.12), top + 0.06, (run.x + run.y) * 0.5),
					Vector3(0.3, 0.06, run.y - run.x), "bleacher_seat", false)
		for aisle: float in BLEACHER_AISLES:
			# A half-step up to this tier, in the aisle.
			var step_top := top - BLEACHER_TIER.y * 0.5
			_box(Vector3(along.call(front - 0.19), step_top - 0.1125, aisle),
					Vector3(0.375, 0.225, AISLE_WIDTH), "riser")
			_box(Vector3(along.call(front - 0.19), step_top + 0.012, aisle),
					Vector3(0.375, 0.024, AISLE_WIDTH), "gym_floor", false)
			for edge_top: float in [step_top, top]:
				var edge_depth: float = front - 0.36 if edge_top == step_top else front + 0.02
				_box(Vector3(along.call(edge_depth), edge_top + 0.036, aisle),
						Vector3(0.05, 0.012, AISLE_WIDTH - 0.02), "safety_yellow", false)
	# Hand rails: up each aisle and each end, and along the back.
	var rise := Vector2(BLEACHER_TIER.x * (BLEACHER_ROWS - 1), BLEACHER_TIER.y * (BLEACHER_ROWS - 1))
	var rail_zs: Array[float] = [BLEACHER_Z.x + 0.08, BLEACHER_Z.y - 0.08]
	rail_zs.append_array(BLEACHER_AISLES)
	for rail_z: float in rail_zs:
		for row in BLEACHER_ROWS:
			_box(Vector3(along.call(row * BLEACHER_TIER.x + 0.3), (row + 1) * BLEACHER_TIER.y + 0.45, rail_z),
					Vector3(0.05, 0.9, 0.05), "steel", false)
		var rail := _box(Vector3(along.call(0.3 + rise.x * 0.5), BLEACHER_TIER.y + 0.9 + rise.y * 0.5, rail_z),
				Vector3(rise.length() + 0.2, 0.05, 0.05), "steel", false)
		rail.rotation.z = atan2(rise.y, rise.x) * side
	var back_top: float = BLEACHER_ROWS * BLEACHER_TIER.y
	_box(Vector3(along.call(BLEACHER_ROWS * BLEACHER_TIER.x - 0.15), back_top + 1.0, middle_z),
			Vector3(0.05, 0.05, length), "steel", false)
	_box(Vector3(along.call(BLEACHER_ROWS * BLEACHER_TIER.x - 0.15), back_top + 0.5, middle_z),
			Vector3(0.04, 0.04, length), "steel", false)


## The stretches of [from, to] left between gaps of `width` centred on `gaps`.
func _gaps_between(span: Vector2, gaps: Array[float], width: float) -> Array[Vector2]:
	var runs: Array[Vector2] = []
	var cursor := span.x
	for gap in gaps:
		runs.append(Vector2(cursor, gap - width * 0.5))
		cursor = gap + width * 0.5
	runs.append(Vector2(cursor, span.y))
	return runs


## A basketball goal at one end (-1 south, 1 north): a glass backboard hung from the roof on a
## steel frame, an orange rim and a white net, rim 3.05 m up, 1.575 m in from the baseline.
func _hoop(end: float) -> void:
	var baseline := COURT_CENTRE.z + end * COURT_HALF.y
	var inward := -end
	var face := baseline + inward * 1.22
	var board_z := face - inward * 0.015
	var x := COURT_CENTRE.x
	_box(Vector3(x, 3.435, board_z), Vector3(1.83, 1.07, 0.03), "glass", false)
	# White edging round the board, and the target square over the rim.
	for y: float in [3.435 - 0.51, 3.435 + 0.51]:
		_box(Vector3(x, y, board_z), Vector3(1.83, 0.05, 0.036), "paint_white", false)
	for dx: float in [-0.89, 0.89]:
		_box(Vector3(x + dx, 3.435, board_z), Vector3(0.05, 1.07, 0.036), "paint_white", false)
	var square_z := face + inward * 0.004
	for y: float in [3.075, 3.48]:
		_box(Vector3(x, y, square_z), Vector3(0.61, 0.05, 0.008), "paint_white", false)
	for dx: float in [-0.28, 0.28]:
		_box(Vector3(x + dx, 3.2775, square_z), Vector3(0.05, 0.455, 0.008), "paint_white", false)
	_box(Vector3(x, 2.87, board_z), Vector3(1.83, 0.07, 0.09), "pad", false)
	# The rim, on a bracket, and its net.
	var rim_z := face + inward * (0.15 + 0.2305)
	_box(Vector3(x, 3.035, face + inward * 0.1), Vector3(0.22, 0.04, 0.2), "rim", false)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.2225
	ring.outer_radius = 0.2385
	ring.rings = 24
	var rim := MeshInstance3D.new()
	rim.mesh = ring
	rim.material_override = _mats["rim"]
	rim.position = Vector3(x, 3.05, rim_z)
	add_child(rim)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.225
	cone.bottom_radius = 0.14
	cone.height = 0.42
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 16
	var net := MeshInstance3D.new()
	net.mesh = cone
	net.material_override = _mats["net"]
	net.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	net.position = Vector3(x, 3.05 - 0.21, rim_z)
	add_child(net)
	# The frame: two posts up from the board to the roof, tied back to the end wall.
	var wall_face := -29.875 if end < 0.0 else 3.875
	var behind := board_z - inward * 0.12
	for dx: float in [-0.6, 0.6]:
		var post_bottom := 3.97
		_box(Vector3(x + dx, (post_bottom + GYM_H) * 0.5, behind), Vector3(0.1, GYM_H - post_bottom, 0.1), "steel", false)
		var span := absf(wall_face - behind)
		_box(Vector3(x + dx, 6.6, (wall_face + behind) * 0.5), Vector3(0.1, 0.1, span), "steel", false)
		var drop := Vector2(span, 6.6 - 4.2)
		var brace := _box(Vector3(x + dx, (6.6 + 4.2) * 0.5, (wall_face + behind) * 0.5),
				Vector3(0.08, 0.08, drop.length()), "steel", false)
		brace.rotation.x = atan2(drop.y, drop.x) * (1.0 if wall_face < behind else -1.0)


## Pads on the walls behind each basket, the scoreboards, and the banners.
func _build_gym_walls() -> void:
	for wall_z: float in [-29.875, 3.875]:
		var inward := 1.0 if wall_z < 0.0 else -1.0
		# (The north wall has the gym doors at x 13.5-16.5.)
		var first := 15.3 if wall_z < 0.0 else 17.3
		var x := first
		while x + 2.4 <= 30.0:
			_box(Vector3(x + 1.2, 1.05, wall_z + inward * 0.05), Vector3(2.36, 1.9, 0.1), "pad", false)
			x += 2.4
		_scoreboard(Vector3(22.5, 5.0, wall_z + inward * 0.12), inward)
	_banner("banner_home", Vector3(5.125 + 0.02, 5.2, -13.0), Vector3.RIGHT, Vector2(6.0, 2.0))
	var pennants := ["banner_state_87", "banner_district_94", "banner_conference_03", "banner_state_11"]
	for i in pennants.size():
		_banner(pennants[i], Vector3(39.875 - 0.02, 5.6, -19.0 + i * 4.0), Vector3.LEFT, Vector2(1.3, 2.03))


func _scoreboard(pos: Vector3, facing: float) -> void:
	_box(pos, Vector3(3.3, 1.7, 0.2), "dark", false)
	var face := StandardMaterial3D.new()
	face.albedo_texture = load("res://assets/textures/gym/scoreboard.png")
	face.emission_enabled = true
	face.emission_texture = load("res://assets/textures/gym/scoreboard_glow.png")
	face.emission_energy_multiplier = 0.8
	face.roughness = 0.6
	var quad := QuadMesh.new()
	quad.size = Vector2(3.2, 1.6)
	var board := MeshInstance3D.new()
	board.mesh = quad
	board.material_override = face
	board.position = pos + Vector3(0, 0, facing * 0.105)
	board.rotation.y = 0.0 if facing > 0.0 else PI
	add_child(board)


## A cloth banner hung flat on a wall, facing `facing`.
func _banner(art: String, pos: Vector3, facing: Vector3, size: Vector2) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = load("res://assets/textures/gym/%s.png" % art)
	cloth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cloth.roughness = 0.95
	var quad := QuadMesh.new()
	quad.size = size
	var banner := MeshInstance3D.new()
	banner.mesh = quad
	banner.material_override = cloth
	banner.position = pos
	banner.rotation.y = atan2(facing.x, facing.z)
	add_child(banner)


## Team benches, the scorer's table, a crate of balls, the clock and a fire alarm.
func _build_gym_courtside() -> void:
	# Home bench on the east side, visitors on the west, either side of the scorer's table.
	for i in 5:
		_gym_chair(Vector3(32.3, 0, -19.0 + i * 0.7), -PI * 0.5)
		_gym_chair(Vector3(12.7, 0, -9.8 + i * 0.7), PI * 0.5)
	_box(Vector3(12.5, 0.74, -14.0), Vector3(0.75, 0.05, 3.0), "desk")
	_box(Vector3(12.9, 0.4, -14.0), Vector3(0.04, 0.68, 3.0), "pad", false)
	for dz: float in [-1.4, 1.4]:
		_box(Vector3(12.3, 0.36, -14.0 + dz), Vector3(0.05, 0.72, 0.05), "steel", false)
	for i in 2:
		_gym_chair(Vector3(12.0, 0, -14.6 + i * 1.2), PI * 0.5)
	# Balls: a crate of them by the home bench, and a few left out.
	_model("prop_plastic_crate_01", Vector3(33.4, 0, -20.4), 0.26, 0.3)
	for spot: Vector3 in [Vector3(33.33, 0.39, -20.45), Vector3(33.5, 0.39, -20.3), Vector3(33.95, 0.12, -20.9),
			Vector3(26.0, 0.12, -24.9), Vector3(18.4, 0.12, -6.2)]:
		_ball(spot)
	_box(Vector3(33.4, 0.13, -20.4), Vector3(0.3, 0.26, 0.41), "dark").visible = false
	_model("prop_wall_clock", Vector3(5.125, 3.6, -21.5), 0.42, PI * 0.5)
	_model("prop_fire_alarm", Vector3(12.0, 1.35, 3.875), 0.2, PI)
	_model("prop_steel_frame_shelves_01", Vector3(34.2, 0, 3.6), 1.8, PI)
	_box(Vector3(34.2, 0.9, 3.6), Vector3(0.95, 1.8, 0.45), "dark").visible = false


func _gym_chair(pos: Vector3, turn: float) -> void:
	if _model("prop_schoolchair_01", pos, 0.82, turn) == null:
		_box(pos + Vector3(0, 0.22, 0), Vector3(0.45, 0.44, 0.45), "pad", false)
	_box(pos + Vector3(0, 0.41, 0), Vector3(0.5, 0.82, 0.5), "dark").visible = false


func _ball(pos: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	var ball := MeshInstance3D.new()
	ball.mesh = sphere
	ball.material_override = _mats["basketball"]
	ball.position = pos
	ball.rotation = Vector3(randf() * TAU, randf() * TAU, 0.0)
	add_child(ball)


# --- Outside -------------------------------------------------------------------

## The front of the school, which the crew walks up to every night: a band of windows (dark
## glass outside, moonlight inside; the guard room's are lit), a parapet along the roof, a canopy
## over the doors with the school's name, a flagpole, and a covered car out on the street.
func _build_facade() -> void:
	# Where windows can't go: the doors, the classroom boards (and their clocks) on the front wall.
	var skip: Array[Vector2] = [Vector2(-3.4, 3.4), Vector2(-49.8, -44.2), Vector2(-63.8, -58.2)]
	var x := -78.4
	while x < 79.0:
		var clear := true
		for span in skip:
			if x + 0.9 > span.x and x - 0.9 < span.y:
				clear = false
		if clear:
			_front_window(x, x > 6.0 and x < 20.0)
		x += 3.2
	_box(Vector3(0, WALL_H + 0.2, 20.05), Vector3(160.5, 0.5, 0.45), "concrete", false)
	# The entrance canopy.
	_box(Vector3(0, 3.0, 21.6), Vector3(6.4, 0.28, 3.0), "concrete", false)
	_box(Vector3(0, 3.0, 23.07), Vector3(6.5, 0.5, 0.08), "concrete", false)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 2.95, 1.43, 22.8), Vector3(0.26, 2.86, 0.26), "concrete")
	_flagpole(Vector3(8.0, 0, 27.0))
	_solid_model("prop_covered_car", Vector3(-11.0, 0, 62.6), 1.35, PI * 0.5, Vector3(4.3, 1.35, 1.8))


func _front_window(x: float, lit: bool) -> void:
	const SIZE := Vector2(1.6, 0.8)
	const Y := 2.6
	_box(Vector3(x, Y, 20.0 + WALL_T * 0.5 + 0.01), Vector3(SIZE.x, SIZE.y, 0.02), "window_lit" if lit else "window_out", false)
	_box(Vector3(x, Y, 20.0 - WALL_T * 0.5 - 0.01), Vector3(SIZE.x, SIZE.y, 0.02), "night_window", false)
	for side: float in [-1.0, 1.0]:
		var face := 20.0 + side * (WALL_T * 0.5 + 0.025)
		_box(Vector3(x, Y, face), Vector3(0.04, SIZE.y, 0.03), "door_frame", false)
		_box(Vector3(x, Y + SIZE.y * 0.5 + 0.025, face), Vector3(SIZE.x + 0.1, 0.05, 0.03), "door_frame", false)
		_box(Vector3(x, Y - SIZE.y * 0.5 - 0.025, face), Vector3(SIZE.x + 0.1, 0.05, 0.03), "door_frame", false)
	_box(Vector3(x, Y - SIZE.y * 0.5 - 0.07, 20.0 + WALL_T * 0.5 + 0.06), Vector3(SIZE.x + 0.2, 0.06, 0.14), "concrete", false)


func _flagpole(base: Vector3) -> void:
	const HEIGHT := 9.0
	_box(base + Vector3(0, 0.15, 0), Vector3(0.8, 0.3, 0.8), "concrete")
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.07
	pole.height = HEIGHT
	pole.radial_segments = 10
	var mast := MeshInstance3D.new()
	mast.mesh = pole
	mast.material_override = _mats["steel"]
	mast.position = base + Vector3(0, HEIGHT * 0.5 + 0.3, 0)
	add_child(mast)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_texture = load("res://assets/textures/school/flag.png")
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	cloth.roughness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(1.5, 1.0)
	var flag := MeshInstance3D.new()
	flag.mesh = quad
	flag.material_override = cloth
	flag.position = base + Vector3(0.8, HEIGHT - 0.4, 0)
	add_child(flag)


# --- Furnishing ---------------------------------------------------------------

## A ready-made model that's also solid: an invisible box of `solid` size, standing on the floor
## under `pos`, keeps guards and monsters out of it. Null (and no box) if there's no such model.
func _solid_model(model_name: String, pos: Vector3, height: float, turn: float, solid: Vector3) -> Node3D:
	var model := _model(model_name, pos, height, turn)
	if model:
		_box(pos + Vector3(0, solid.y * 0.5, 0), solid, "dark").visible = false
	return model


## A sheet on a wall (assets/textures/school/<art>.png): a poster, a chart, a painting.
## `pos` is on the wall's face; `facing` is the way the wall faces.
func _poster(art: String, pos: Vector3, facing: Vector3, size := Vector2(0.6, 0.84)) -> void:
	var paper: StandardMaterial3D = _posters.get(art)
	if paper == null:
		paper = StandardMaterial3D.new()
		paper.albedo_texture = load("res://assets/textures/school/%s.png" % art)
		paper.roughness = 0.85
		_posters[art] = paper
	var quad := QuadMesh.new()
	quad.size = size
	var sheet := MeshInstance3D.new()
	sheet.mesh = quad
	sheet.material_override = paper
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sheet.position = pos + facing * 0.012
	sheet.rotation.y = atan2(facing.x, facing.z)
	add_child(sheet)


## The teacher's (or nurse's) steel desk, `turn` 0 when whoever sits at it is on its +Z side.
func _steel_desk(pos: Vector3, turn: float) -> void:
	var across := Vector3(2.0, 0.77, 0.95) if is_zero_approx(fmod(absf(turn), PI)) else Vector3(0.95, 0.77, 2.0)
	if _solid_model("prop_metal_office_desk", pos, 0.77, turn, across) == null:
		_desk(pos, 1.6, 0.8)


## A school chair; `turn` 0 faces +Z. Solid, so nobody walks through it.
func _school_chair(pos: Vector3, turn: float) -> void:
	_gym_chair(pos, turn)


## A double-sided library bookcase running north-south, 2 m tall: shelves full of books on both
## faces (one painted texture, tiled), wooden ends and a top.
func _bookcase_row(centre: Vector3, length: float) -> void:
	const HEIGHT := 2.0
	const DEPTH := 0.6
	_box(centre + Vector3(0, HEIGHT * 0.5, 0), Vector3(DEPTH, HEIGHT, length), "wood")
	for end: float in [-1.0, 1.0]:
		_box(centre + Vector3(0, (HEIGHT + 0.05) * 0.5, end * (length * 0.5 + 0.025)),
				Vector3(DEPTH + 0.04, HEIGHT + 0.05, 0.05), "wood", false)
	_box(centre + Vector3(0, HEIGHT + 0.03, 0), Vector3(DEPTH + 0.06, 0.06, length + 0.1), "wood", false)
	for side: float in [-1.0, 1.0]:
		var quad := QuadMesh.new()
		quad.size = Vector2(length, HEIGHT - 0.04)
		var books := MeshInstance3D.new()
		books.mesh = quad
		books.material_override = _mats["books"]
		books.position = centre + Vector3(side * (DEPTH * 0.5 + 0.004), HEIGHT * 0.5, 0)
		books.rotation.y = side * PI * 0.5
		add_child(books)


## A science lab bench, 4 x 1.2 m: painted cupboards under a black top, doors down both sides.
func _lab_bench(pos: Vector3) -> void:
	_box(pos + Vector3(0, 0.45, 0), Vector3(4.0, 0.9, 1.2), "lab_base")
	_box(pos + Vector3(0, 0.9, 0), Vector3(4.1, 0.04, 1.3), "lab_top", false)
	for side: float in [-1.0, 1.0]:
		var face_z := pos.z + side * 0.603
		for k in 7:
			_box(Vector3(pos.x - 1.5 + k * 0.5, 0.43, face_z), Vector3(0.014, 0.78, 0.006), "dark", false)
		for k in 8:
			var door_x := pos.x - 1.75 + k * 0.5
			_box(Vector3(door_x + (0.17 if k % 2 == 0 else -0.17), 0.72, face_z + side * 0.012),
					Vector3(0.02, 0.12, 0.02), "steel", false)
	_box(pos + Vector3(1.4, 1.05, 0), Vector3(0.08, 0.3, 0.08), "metal", false)


## An easel in the art room, turned so its canvas faces `facing` (radians about Y, 0 = +Z).
func _easel(spot: Vector3, facing: float, painting: int) -> void:
	var place := func(offset: Vector3) -> Vector3:
		return spot + offset.rotated(Vector3.UP, facing)
	var solid := _box(place.call(Vector3(0, 0.9, 0)), Vector3(0.7, 1.8, 0.4), "wood")
	solid.visible = false
	solid.rotation.y = facing
	for leg_x: float in [-0.28, 0.28]:
		var leg := _box(place.call(Vector3(leg_x, 0.85, 0.05)), Vector3(0.035, 1.72, 0.035), "wood", false)
		leg.rotation = Vector3(-0.09, facing, 0)
	var back := _box(place.call(Vector3(0, 0.78, -0.2)), Vector3(0.035, 1.6, 0.035), "wood", false)
	back.rotation = Vector3(0.28, facing, 0)
	var ledge := _box(place.call(Vector3(0, 0.82, 0.11)), Vector3(0.7, 0.03, 0.07), "wood", false)
	ledge.rotation.y = facing
	var canvas := _box(place.call(Vector3(0, 1.24, 0.1)), Vector3(0.6, 0.8, 0.03), "canvas", false)
	canvas.rotation.y = facing
	_poster("painting_%d" % painting, place.call(Vector3(0, 1.24, 0.11)), Vector3.BACK.rotated(Vector3.UP, facing), Vector2(0.58, 0.78))


## A trophy on a shelf: a dark base, a stem and a gold cup.
func _trophy(pos: Vector3, scale: float) -> void:
	_box(pos + Vector3(0, 0.03 * scale, 0), Vector3(0.1, 0.06, 0.1) * scale, "dark", false)
	var cup := CylinderMesh.new()
	cup.top_radius = 0.06 * scale
	cup.bottom_radius = 0.02 * scale
	cup.height = 0.18 * scale
	cup.radial_segments = 12
	var trophy := MeshInstance3D.new()
	trophy.mesh = cup
	trophy.material_override = _mats["gold"]
	trophy.position = pos + Vector3(0, 0.15 * scale, 0)
	add_child(trophy)


func _desk(pos: Vector3, width: float, depth: float) -> void:
	_box(pos + Vector3(0, 0.74, 0), Vector3(width, 0.05, depth), "desk")
	for side: float in [-1.0, 1.0]:
		_box(pos + Vector3(side * (width * 0.5 - 0.04), 0.36, 0), Vector3(0.05, 0.72, depth - 0.05), "desk")


## A desk chair. Guard room chairs (desk >= 0) can be sat in.
func _chair(pos: Vector3, desk := -1, solid := true) -> void:
	if _model("prop_office_chair", pos, 1.15) == null:
		_box(pos + Vector3(0, 0.25, 0), Vector3(0.1, 0.5, 0.1), "metal", false)
		_box(pos + Vector3(0, 0.5, 0), Vector3(0.55, 0.08, 0.55), "dark", false)
		_box(pos + Vector3(0, 0.85, -0.25), Vector3(0.55, 0.6, 0.06), "dark", false)
	var size := Vector3(0.6, 1.15, 0.6)
	if desk < 0:
		if solid:
			_box(pos + Vector3(0, size.y * 0.5, 0), size, "dark").visible = false
		return
	var seat := Interactable.new()
	seat.prompt = "Sit at desk %d" % (desk + 1)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	seat.add_child(collider)
	seat.position = pos + Vector3(0, size.y * 0.5, 0)
	add_child(seat)
	desk_chairs.append(seat)
	desk_chair_positions.append(pos)


func _build_signs() -> void:
	_sign(SCHOOL_NAME, Vector3(0, 3.0, 23.08), Vector3.BACK, 72)
	_sign("STAFF ENTRANCE", Vector3(0, 2.75, 45.06), Vector3.BACK, 44, Color(1, 0.85, 0.4))
	_sign("SECURITY", Vector3(5.85, 2.7, 15.0), Vector3.LEFT)
	_sign("FRONT OFFICE", Vector3(-5.85, 2.7, 15.0), Vector3.RIGHT)
	_sign("MAIN HALL", Vector3(0, 3.25, 10.15), Vector3.BACK, 44)
	_sign("SECURITY", Vector3(16.0, 2.7, 9.85), Vector3.FORWARD)
	_sign("CAFETERIA", Vector3(-15.0, 2.7, 4.15), Vector3.BACK)
	_sign("CUSTODIAN", Vector3(0, 2.7, 4.15), Vector3.BACK, 40)
	_sign("GYMNASIUM", Vector3(15.0, 2.7, 4.15), Vector3.BACK)
	_sign("KITCHEN", Vector3(-5.15, 2.6, -21.0), Vector3.LEFT, 40)
	_sign("PLEASE CLOCK IN", Vector3(19.85, 2.0, 13.0), Vector3.LEFT, 40, Color(0.6, 1, 0.7))
	_sign("GO BULLDOGS", Vector3(9.0, 2.9, 2.0), Vector3.BACK, 40, Color(1, 0.8, 0.3))


func _build_lights() -> void:
	const CEILING := WALL_H - 0.3
	# Over the front doors: welcoming before the shift, off once the building is locked up.
	_light(Vector3(0, 3.0, 21.0), 0.0, 9.0, false, false, Color(1.0, 0.85, 0.6), 3.0)
	# Lobby and front office.
	_light(Vector3(0, CEILING, 15.0), 0.5, 9.0)
	_light(Vector3(-13.0, CEILING, 15.0), 0.4, 9.0, true)
	# Guard room stays the brightest place in the building.
	_light(Vector3(9.5, CEILING, 15.0), 1.0, 9.0, false, true, Color(1.0, 0.95, 0.85), 2.8)
	_light(Vector3(16.5, CEILING, 15.0), 1.0, 9.0, false, true, Color(1.0, 0.95, 0.85), 2.8)
	# Main hallway: a light every 8 m. At night some go off and two start failing.
	var hall_off := [-28.0, -12.0, 20.0, 36.0]
	var hall_flicker := [-20.0, 28.0]
	var x := -36.0
	while x <= 36.0:
		_light(Vector3(x, CEILING, 7.0), 0.0 if x in hall_off else 0.5, 8.0, x in hall_flicker)
		x += 8.0
	# Cafeteria, kitchen, closet.
	_light(Vector3(-30, CEILING, -5), 0.35, 12.0)
	_light(Vector3(-15, CEILING, -5), 0.0, 12.0)
	_light(Vector3(-30, CEILING, -20), 0.0, 12.0)
	_light(Vector3(-15, CEILING, -20), 0.35, 12.0, true)
	_light(Vector3(0, CEILING, -21), 0.35, 9.0)
	_light(Vector3(0, CEILING, -4), 0.2, 7.0, true)
	# Gym: high-bay lamps hanging from the roof. At night most are off.
	_gym_lamp(15.0, -3.0, 0.45)
	_gym_lamp(30.0, -3.0, 0.0)
	_gym_lamp(15.0, -13.0, 0.0)
	_gym_lamp(30.0, -13.0, 0.35, true)
	_gym_lamp(15.0, -23.0, 0.0)
	_gym_lamp(30.0, -23.0, 0.4)


func _build_cameras() -> void:
	_camera("Front Gate", Vector3(7.0, 3.2, 20.4), Vector3(0, 0, 44))
	_camera("Lobby", Vector3(5.6, 3.2, 19.6), Vector3(-2, 0.5, 11))
	_camera("Main Hall West", Vector3(-39.5, 3.2, 9.6), Vector3(0, 0.3, 6.5))
	_camera("Main Hall East", Vector3(39.5, 3.2, 4.4), Vector3(0, 0.3, 7.5))
	_camera("Front Office", Vector3(-6.4, 3.2, 10.4), Vector3(-16, 0.3, 17))
	_camera("Cafeteria", Vector3(-39.4, 3.2, 3.4), Vector3(-15, 0, -20))
	_camera("Kitchen", Vector3(4.4, 3.2, -12.6), Vector3(-2, 0.3, -27))
	_camera("Gym", Vector3(39.4, 5.2, -29.4), Vector3(14, 0, -2))


# --- The wings -----------------------------------------------------------------

## Builds the red doors that close off the wings. They go under `holder` rather than the school,
## so the navigation mesh (baked from the school) runs through them into the wings.
func build_wing_doors(holder: Node3D) -> void:
	for info: Dictionary in WING_DOORS:
		var x: float = info["x"]
		var inward := -1.0 if x > 0.0 else 1.0
		var door := StaticBody3D.new()
		door.name = "WingDoor%d" % info["difficulty"]
		door.position = Vector3(x, 1.2, 7.0)
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.12, 2.4, 2.6)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		door.add_child(collider)
		door.add_child(_box_mesh(Vector3(0.12, 2.4, 2.6), "red"))
		# A seam down the middle and a chain across the handles.
		var seam := _box_mesh(Vector3(0.14, 2.3, 0.04), "dark")
		door.add_child(seam)
		var chain := _box_mesh(Vector3(0.16, 0.06, 0.9), "metal")
		chain.position = Vector3(0, -0.1, 0)
		door.add_child(chain)
		var label := Label3D.new()
		label.text = info["sign"]
		label.font_size = 40
		label.pixel_size = 0.004
		label.modulate = Color(1, 0.6, 0.5)
		label.outline_size = 8
		label.double_sided = false
		label.position = Vector3(inward * 0.1, 1.65, 0)
		label.rotation.y = atan2(inward, 0.0)
		door.add_child(label)
		holder.add_child(door)
		door.set_meta("difficulty", info["difficulty"])
		_wing_doors.append(door)


## Opens the wing doors this difficulty allows and closes the rest.
func open_wings(difficulty: int) -> void:
	for door in _wing_doors:
		var open: bool = difficulty >= int(door.get_meta("difficulty"))
		door.visible = not open
		for child in door.get_children():
			if child is CollisionShape3D:
				(child as CollisionShape3D).disabled = open


func _build_wing_shell(x1: float, x2: float) -> void:
	var middle := (x1 + x2) * 0.5
	var width := absf(x2 - x1)
	_box(Vector3(middle, -0.1, 3.0), Vector3(width, 0.2, 34.0), "floor")
	# Overhanging the far wall only: on the near side it would poke into the gym's tall hall.
	var outward := signf(x2 - x1)
	_box(Vector3(middle + outward * 0.125, WALL_H + 0.1, 3.0), Vector3(width + 0.25, 0.2, 34.5), "ceiling", false)
	_wall_x(-14, minf(x1, x2), maxf(x1, x2), [], "brick")
	_wall_x(20, minf(x1, x2), maxf(x1, x2), [], "brick")
	_wall_z(x2, -14, 20, [], "brick")


func _build_classroom_wing() -> void:
	_build_wing_shell(-40.0, -80.0)
	# West Hall: classrooms and the nurse to the south, Room 103 and the library to the north.
	_wall_x(10, -80, -40, [[-47.0, 1.6], [-61.0, 1.6], [-74.0, 1.6]])
	_wall_x(4, -80, -40, [[-47.0, 1.6], [-66.0, 3.0]])
	_wall_z(-54, 10, 20)
	_wall_z(-68, 10, 20)
	_wall_z(-58, -14, 4)
	for span: Vector2 in [Vector2(-79.6, -75.2), Vector2(-72.8, -62.2), Vector2(-59.8, -48.2), Vector2(-45.8, -40.4)]:
		_locker_row(span.x, span.y, 9.62)

	_classroom(Vector3(-47.0, 0, 15.0), 1.0, 3, 7.0, "poster_stay_in_class")
	_classroom(Vector3(-61.0, 0, 15.0), 1.0, 3, 7.0, "poster_read")
	_classroom(Vector3(-49.0, 0, -9.0), -1.0, 3, 9.0, "poster_science_fair")

	# Library: rows of bookcases, the checkout desk and reading tables.
	for i in 4:
		_bookcase_row(Vector3(-76.0 + i * 4.0, 0, -9.0), 6.0)
	_box(Vector3(-62.0, 0.55, 0.5), Vector3(3.0, 1.1, 0.8), "wood")
	_model("prop_desk_lamp_arm_01", Vector3(-61.0, 1.1, 0.6), 0.5, PI)
	_model("prop_classic_laptop", Vector3(-62.4, 1.1, 0.45), 0.24, PI)
	for table: Vector3 in [Vector3(-70, 0, -1.0), Vector3(-61, 0, -9.0)]:
		_desk(table, 2.4, 1.2)
		for side: float in [-1.0, 1.0]:
			for along: float in [-0.6, 0.6]:
				_school_chair(table + Vector3(along, 0, side * 0.9), 0.0 if side < 0.0 else PI)
	_box(Vector3(-79.6, 1.6, -3.0), Vector3(0.1, 1.6, 4.0), "cork", false)
	_poster("poster_read", Vector3(-79.875, 1.6, -8.0), Vector3.RIGHT)
	_poster("poster_quiet", Vector3(-70.0, 1.6, -13.875), Vector3.BACK)
	_model("prop_wall_clock", Vector3(-66.0, 2.3, 3.875), 0.36, PI)

	# Nurse's office: two cots behind a curtain, and a medicine cabinet.
	for cot_z: float in [13.0, 17.5]:
		var cot := _box(Vector3(-77.5, 0.3, cot_z), Vector3(2.0, 0.6, 0.9), "metal")
		var mattress := _box(Vector3(-77.5, 0.63, cot_z), Vector3(1.9, 0.08, 0.85), "wall", false)
		if _model("prop_old_bed_frame", Vector3(-77.5, 0, cot_z), 1.0, PI * 0.5):
			_hide_boxes(cot)
			mattress.position.y = NURSE_MATTRESS_Y
			mattress.material_override = _mats["linen"]
	# The curtain round the cots, on a rail, pulled most of the way across.
	_box(Vector3(-75.6, 2.12, 14.6), Vector3(0.04, 0.04, 6.4), "steel", false)
	var fold := 0
	var z := 12.7
	while z < 17.8:
		var pleat := _box(Vector3(-75.6 + (0.04 if fold % 2 == 0 else -0.04), 1.1, z), Vector3(0.03, 1.95, 0.46), "curtain", false)
		pleat.rotation.y = 0.35 if fold % 2 == 0 else -0.35
		fold += 1
		z += 0.38
	_box(Vector3(-69.0, 1.0, 19.5), Vector3(1.4, 2.0, 0.5), "wall")
	_box(Vector3(-69.0, 1.3, 19.24), Vector3(0.3, 0.3, 0.02), "red", false)
	_model("prop_medical_box", Vector3(-69.0, 2.0, 19.5), 0.1)
	_steel_desk(Vector3(-70.5, 0, 12.0), 0.0)
	_school_chair(Vector3(-70.5, 0, 12.9), PI)
	_poster("poster_wash_hands", Vector3(-68.125, 1.6, 16.0), Vector3.LEFT)
	# Posters along West Hall.
	_poster("poster_stay_in_class", Vector3(-66.0, 2.5, 9.875), Vector3.FORWARD)
	_poster("poster_president", Vector3(-52.0, 2.5, 9.875), Vector3.FORWARD)
	_poster("poster_dance", Vector3(-55.0, 2.5, 4.125), Vector3.BACK)

	# Lights: the hallway, a light per room. Most of the wing is left dark at night.
	var x := -44.0
	while x >= -76.0:
		_light(Vector3(x, WALL_H - 0.3, 7.0), 0.0 if x in [-52.0, -68.0] else 0.45, 8.0, x == -60.0)
		x -= 8.0
	_light(Vector3(-47.0, WALL_H - 0.3, 15.0), 0.0, 9.0)
	_light(Vector3(-61.0, WALL_H - 0.3, 15.0), 0.25, 9.0, true)
	_light(Vector3(-74.0, WALL_H - 0.3, 15.0), 0.35, 8.0, false, true, Color(0.85, 1.0, 0.95))
	_light(Vector3(-49.0, WALL_H - 0.3, -5.0), 0.0, 11.0)
	_light(Vector3(-74.0, WALL_H - 0.3, -5.0), 0.2, 11.0)
	_light(Vector3(-63.0, WALL_H - 0.3, -5.0), 0.0, 11.0)

	_sign("ROOM 101", Vector3(-47.0, 2.7, 9.85), Vector3.FORWARD, 40)
	_sign("ROOM 102", Vector3(-61.0, 2.7, 9.85), Vector3.FORWARD, 40)
	_sign("NURSE", Vector3(-74.0, 2.7, 9.85), Vector3.FORWARD, 40, Color(1.0, 0.6, 0.6))
	_sign("ROOM 103", Vector3(-47.0, 2.7, 4.15), Vector3.BACK, 40)
	_sign("LIBRARY", Vector3(-66.0, 2.9, 4.15), Vector3.BACK, 44)
	_sign("CLASSROOM WING", Vector3(-40.2, 2.95, 7.0), Vector3.LEFT, 40, Color(1, 0.85, 0.4))

	_camera("West Hall", Vector3(-79.5, 3.2, 9.6), Vector3(-40, 0.3, 6.5), 2)
	_camera("Room 101", Vector3(-40.4, 3.2, 19.6), Vector3(-50, 0, 13), 2)
	_camera("Room 103", Vector3(-40.4, 3.2, 3.6), Vector3(-52, 0, -8), 2)
	_camera("Library", Vector3(-58.4, 3.2, 3.6), Vector3(-72, 0, -9), 2)
	_camera("Nurse's Office", Vector3(-68.4, 3.2, 10.4), Vector3(-77, 0, 17), 2)


## A classroom: rows of student desks facing a chalkboard and the teacher's desk.
## `facing` is +1 when the board is on the south wall, -1 when it's on the north wall.
func _classroom(centre: Vector3, facing: float, rows := 3, half_width := 7.0, poster := "") -> void:
	var board_z := centre.z + facing * 4.75
	var board_wall := centre.z + facing * 4.875
	var back_wall := centre.z - facing * 4.875
	_box(Vector3(centre.x, 1.6, board_z), Vector3(4.0, 1.2, 0.06), "board", false)
	_steel_desk(Vector3(centre.x + 3.0, 0, board_z - facing * 1.6), PI if facing < 0.0 else 0.0)
	_school_chair(Vector3(centre.x + 3.0, 0, board_z - facing * 0.75), PI if facing > 0.0 else 0.0)
	_model("prop_wall_clock", Vector3(centre.x, 2.38, board_wall), 0.34, PI if facing > 0.0 else 0.0)
	# The TV cart in the corner by the board, on the side away from the teacher's desk.
	var side := -1.0 if facing > 0.0 else 1.0
	var cart := Vector3(centre.x + side * (half_width - 0.8), 0, board_z - facing * 0.9)
	_solid_model("prop_industrial_storage_cart", cart, 0.9, PI * 0.5, Vector3(0.72, 0.9, 1.05))
	_model("prop_television_02", cart + Vector3(0, 0.87, 0), 0.42, PI * 0.5 * -side)
	_solid_model("prop_shelf_01", Vector3(centre.x - side * 4.5, 0, back_wall + facing * 0.14), 2.0,
			0.0 if facing > 0.0 else PI, Vector3(0.96, 2.0, 0.26))
	if poster != "":
		_poster(poster, Vector3(centre.x - side * (half_width - 0.125), 1.6, centre.z), Vector3(side, 0, 0))
	# Spaced so a monster (or a guard) can get between any two desks.
	for row in rows:
		for col in 4:
			var spot := Vector3(centre.x - 3.6 + col * 2.4, 0, board_z - facing * (3.4 + row * 2.2))
			# A desk with its chair attached, facing the board; the box keeps it solid.
			if _model("prop_student_desk", spot - Vector3(0, 0, facing * 0.25), 0.8, 0.0 if facing > 0.0 else PI):
				_box(spot + Vector3(0, 0.4, -facing * 0.25), Vector3(0.7, 0.8, 1.0), "desk").visible = false
				continue
			_desk(spot, 0.7, 0.5)
			_chair(spot - Vector3(0, 0, facing * 0.55), -1, false)


func _build_science_wing() -> void:
	_build_wing_shell(40.0, 80.0)
	_wall_x(4, 40, 80, [[50.0, 1.6], [71.0, 1.6]])
	_wall_x(10, 40, 80, [[50.0, 1.8], [70.0, 1.8]])
	_wall_z(62, -14, 4)
	# The locker rooms: one long room split by a half wall.
	_wall_z(60, 10, 20, [[15.0, 2.0]])
	for span: Vector2 in [Vector2(40.4, 48.8), Vector2(51.2, 68.8), Vector2(72.2, 79.6)]:
		_locker_row(span.x, span.y, 4.38)

	# Science lab: black-topped benches, a fume hood and a shelf of jars.
	for bench_z: float in [-1.0, -5.0, -9.0]:
		for bench_x: float in [46.0, 54.0]:
			_lab_bench(Vector3(bench_x, 0, bench_z))
			# Stools along the side away from the board.
			for along: float in [-1.0, 1.0]:
				_solid_model("prop_metal_stool_02", Vector3(bench_x + along, 0, bench_z + 0.95), 0.65, 0.0,
						Vector3(0.4, 0.65, 0.4))
	_model("prop_vintage_microscope", Vector3(45.3, 0.92, -5.1), 0.36)
	_model("prop_vintage_microscope", Vector3(46.8, 0.92, -4.9), 0.36, 0.5)
	_model("prop_industrial_microscope", Vector3(55.0, 0.92, -9.0), 0.42, PI)
	_model("prop_chemistry_set", Vector3(46.0, 0.92, -9.15), 0.4)
	for burner: Vector3 in [Vector3(53.0, 0.92, -1.1), Vector3(55.0, 0.92, -0.9), Vector3(46.9, 0.92, -1.25)]:
		_model("prop_bunsen_burner", burner, 0.17)
	_poster("periodic", Vector3(40.125, 1.8, -3.5), Vector3.RIGHT, Vector2(2.0, 1.25))
	_poster("poster_science_fair", Vector3(61.875, 1.6, -11.0), Vector3.LEFT)
	_box(Vector3(40.6, 1.2, -9.0), Vector3(1.0, 2.4, 2.4), "metal")
	_box(Vector3(61.5, 0.5, -6.0), Vector3(0.6, 1.0, 5.0), "wood")
	specimen_jar = Node3D.new()
	specimen_jar.name = "SpecimenJar"
	specimen_jar.position = Vector3(61.5, 1.0, -6.0)
	add_child(specimen_jar)
	var jar := _box_mesh(Vector3(0.45, 0.6, 0.45), "jar")
	jar.position = Vector3(0, 0.3, 0)
	specimen_jar.add_child(jar)
	var lid := _box_mesh(Vector3(0.48, 0.06, 0.48), "metal")
	lid.position = Vector3(0, 0.63, 0)
	specimen_jar.add_child(lid)

	# Art room: easels in a ring, tables, and one covered canvas at the front.
	for i in 6:
		var angle := TAU * i / 6.0
		var spot := Vector3(71.0 + cos(angle) * 4.0, 0, -5.0 + sin(angle) * 4.0)
		# Canvas facing out of the ring, towards whoever's painting.
		_easel(spot, atan2(cos(angle), sin(angle)), i % 4 + 1)
	_desk(Vector3(66.0, 0, -12.0), 2.4, 1.0)
	_desk(Vector3(76.0, 0, -12.0), 2.4, 1.0)
	_model("prop_spray_paint_bottles", Vector3(75.3, 0.77, -12.2), 0.2)
	_model("prop_ceramic_vase_01", Vector3(76.6, 0.77, -11.9), 0.32)
	_model("prop_planter_pot_clay", Vector3(77.1, 0.77, -12.3), 0.2)
	_model("prop_spray_paint_bottles", Vector3(67.0, 0.77, -11.8), 0.2, 1.2)
	for stool_x: float in [65.2, 66.8, 75.2, 76.8]:
		_solid_model("prop_painted_wooden_stool", Vector3(stool_x, 0, -10.9), 0.5, 0.0, Vector3(0.36, 0.5, 0.38))
	_solid_model("prop_wooden_display_shelves_01", Vector3(79.6, 0, -6.0), 1.5, 0.0, Vector3(0.36, 1.5, 1.04))
	for hung: Array in [[66.0, 1], [76.0, 3]]:
		_box(Vector3(hung[0], 1.7, 3.85), Vector3(0.7, 0.9, 0.04), "wood", false)
		_poster("painting_%d" % hung[1], Vector3(hung[0], 1.7, 3.83), Vector3.FORWARD, Vector2(0.6, 0.8))
	self_portrait_easel = _interactable(Vector3(71.0, 1.2, -12.8), Vector3(1.3, 1.6, 0.12), "canvas", "Look at the canvas", "")
	_box(Vector3(71.0, 0.2, -12.8), Vector3(0.9, 0.4, 0.5), "wood")

	# Locker rooms: benches, showers along the back wall.
	for bench_x: float in [46.0, 54.0, 66.0, 74.0]:
		_box(Vector3(bench_x, 0.22, 14.0), Vector3(4.0, 0.44, 0.45), "wood")
	for shower_x in [44.0, 48.0, 52.0, 56.0, 64.0, 68.0, 72.0, 76.0]:
		_box(Vector3(shower_x, 2.1, 19.7), Vector3(0.2, 0.1, 0.3), "metal", false)
		_box(Vector3(shower_x + 2.0, 1.0, 19.0), Vector3(0.05, 2.0, 1.6), "wall")

	_model("prop_trash_can", Vector3(42.0, 0, 10.6), 0.9)
	_poster("poster_science_fair", Vector3(56.0, 2.5, 4.125), Vector3.BACK)
	_poster("poster_no_running", Vector3(76.0, 2.5, 4.125), Vector3.BACK)
	_poster("poster_basketball", Vector3(60.0, 2.5, 9.875), Vector3.FORWARD)

	var x := 44.0
	while x <= 76.0:
		_light(Vector3(x, WALL_H - 0.3, 7.0), 0.0 if x in [52.0, 68.0] else 0.45, 8.0, x == 60.0)
		x += 8.0
	_light(Vector3(51.0, WALL_H - 0.3, -5.0), 0.3, 12.0, true, true, Color(0.8, 1.0, 0.85))
	_light(Vector3(71.0, WALL_H - 0.3, -5.0), 0.0, 11.0)
	_light(Vector3(71.0, 2.6, -11.0), 0.35, 5.0, false, false, Color(1.0, 0.85, 0.65))
	_light(Vector3(50.0, WALL_H - 0.3, 15.0), 0.0, 10.0)
	_light(Vector3(70.0, WALL_H - 0.3, 15.0), 0.25, 10.0, true)

	_sign("SCIENCE LAB", Vector3(50.0, 2.7, 4.15), Vector3.BACK, 40)
	_sign("ART", Vector3(71.0, 2.7, 4.15), Vector3.BACK, 44, Color(0.9, 0.7, 1.0))
	_sign("LOCKER ROOMS", Vector3(50.0, 2.7, 9.85), Vector3.FORWARD, 40)
	_sign("LOCKER ROOMS", Vector3(70.0, 2.7, 9.85), Vector3.FORWARD, 40)
	_sign("SCIENCE WING", Vector3(40.2, 2.95, 7.0), Vector3.RIGHT, 40, Color(1, 0.85, 0.4))

	_camera("East Hall", Vector3(79.5, 3.2, 4.4), Vector3(40, 0.3, 7.5), 3)
	_camera("Science Lab", Vector3(40.4, 3.2, 3.6), Vector3(56, 0, -9), 3)
	_camera("Art Room", Vector3(79.6, 3.2, 3.6), Vector3(70, 0.5, -10), 3)
	_camera("Locker Rooms", Vector3(40.4, 3.2, 19.6), Vector3(60, 0, 12), 3)
