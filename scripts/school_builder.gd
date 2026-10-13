class_name SchoolBuilder
extends Node3D
## Builds the placeholder ("greybox") school for difficulty 1 out of simple boxes.
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

const WALL_H := 3.5
const WALL_T := 0.25
const DOOR_H := 2.4
const SCHOOL_NAME := "WESTFIELD HIGH SCHOOL"

## The time clock in the guard room. Main connects it to the shift.
var clock_machine: Interactable
## Where the 16 guard room monitor screens go: [{"desk", "position"}], in monitor order.
var monitor_spots: Array[Dictionary] = []
## The chair at each guard room desk, and where a seated guard goes.
var desk_chairs: Array[Interactable] = []
var desk_chair_positions: Array[Vector3] = []
## The CCTV cameras: [{"name", "position", "target"}].
var camera_spots: Array[Dictionary] = []

var _mats: Dictionary = {}


func _ready() -> void:
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


func _add_mat(mat_name: String, color: Color, roughness := 0.9, emission := Color.BLACK,
		emission_energy := 0.0, alpha := 1.0) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
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


## Hands out shared materials, e.g. so lighting can dim every ceiling panel at once.
func get_material(mat_name: String) -> StandardMaterial3D:
	return _mats[mat_name]


## A wall-mounted CCTV camera: a small housing with a red light, plus a spot for SecurityCameras.
func _camera(camera_name: String, pos: Vector3, target: Vector3) -> void:
	var housing := _box(pos, Vector3(0.18, 0.14, 0.3), "dark", false)
	housing.look_at(target)
	var led := _box_mesh(Vector3(0.03, 0.03, 0.01), "led")
	led.position = Vector3(0.05, 0.04, -0.155)
	housing.add_child(led)
	camera_spots.append({"name": camera_name, "position": pos + (target - pos).normalized() * 0.2, "target": target})


# --- Areas -------------------------------------------------------------------

func _build_grounds() -> void:
	# Grass sits a touch lower than the building floor so the two never flicker against each other.
	_box(Vector3(0, -0.27, 10), Vector3(220, 0.5, 170), "grass")
	_box(Vector3(0, -0.1, -5), Vector3(80, 0.2, 50), "floor")
	_box(Vector3(0, WALL_H + 0.1, -5), Vector3(80.5, 0.2, 50.5), "ceiling", false)
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
		# Gate leaves, swung open into the yard.
		var leaf := _box(Vector3(side * (GATE_HALF + 0.2), FENCE_H * 0.5, FENCE_Z - 1.2),
				Vector3(0.05, FENCE_H, 2.4), "fence")
		leaf.rotation.y = side * 0.35
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
	_wall_z(-40, -30, 20, [], "brick")
	_wall_z(40, -30, 20, [], "brick")

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


func _build_front_office() -> void:
	# Reception counter with a gap to walk through.
	_box(Vector3(-9.0, 0.55, 18.0), Vector3(0.6, 1.1, 4.0), "wood")
	_box(Vector3(-9.0, 0.55, 12.0), Vector3(0.6, 1.1, 2.0), "wood")
	for desk_pos: Vector3 in [Vector3(-14, 0, 13), Vector3(-14, 0, 17.5), Vector3(-18, 0, 15)]:
		_desk(desk_pos, 1.6, 0.8)
	for i in 4:
		_box(Vector3(-19.2 + i * 0.6, 0.65, 10.45), Vector3(0.55, 1.3, 0.6), "metal")
	# The PA microphone the Principal will use.
	_box(Vector3(-18.0, 0.82, 14.8), Vector3(0.1, 0.12, 0.1), "dark", false)


func _build_guard_room() -> void:
	# Four desks against the front wall, each with a 2x2 bank of monitors facing the chair.
	for i in 4:
		var x := 7.9 + i * 3.4
		_desk(Vector3(x, 0, 19.0), 2.8, 1.0)
		# Top row first, left to right as seen from the chair (the chair faces +Z, so its left is +X).
		for row in [1, 0]:
			for col in [1, 0]:
				var screen_pos := Vector3(x - 0.34 + col * 0.68, 1.05 + row * 0.5, 19.3)
				_box(screen_pos, Vector3(0.66, 0.48, 0.06), "dark", false)
				monitor_spots.append({"desk": i, "position": screen_pos + Vector3(0, 0, -0.035)})
		_box(Vector3(x, 0.92, 19.35), Vector3(0.08, 0.35, 0.08), "metal", false)
		_chair(Vector3(x, 0, 18.0), i)

	# Clock machine on the east wall.
	clock_machine = _interactable(Vector3(19.72, 1.4, 13.0), Vector3(0.3, 0.6, 0.5), "metal", "Clock in", "")
	_box(Vector3(19.56, 1.52, 13.0), Vector3(0.02, 0.15, 0.35), "clock_screen", false)

	# Vending machine on the east wall.
	_interactable(Vector3(19.4, 1.0, 16.6), Vector3(0.9, 2.0, 1.1), "red", "Use vending machine",
			"OUT OF ORDER. The vending machine opens in a later build.")
	_box(Vector3(18.94, 1.2, 16.45), Vector3(0.02, 1.3, 0.7), "vending_glow", false)

	# Notice board on the back wall.
	_box(Vector3(9.5, 1.6, 10.16), Vector3(2.4, 1.2, 0.05), "cork", false)


func _build_hallway() -> void:
	# Lockers line both sides, leaving gaps for the doorways.
	for span: Vector2 in [Vector2(-39.6, -3.2), Vector2(3.2, 14.9), Vector2(17.1, 39.6)]:
		_locker_row(span.x, span.y, 9.62)
	for span: Vector2 in [Vector2(-39.6, -16.7), Vector2(-13.3, -1.0), Vector2(1.0, 13.3), Vector2(16.7, 39.6)]:
		_locker_row(span.x, span.y, 4.38)
	# Locked double doors at each end, to wings that open at higher difficulties.
	_box(Vector3(-39.8, 1.2, 7.0), Vector3(0.1, 2.4, 2.6), "red")
	_box(Vector3(39.8, 1.2, 7.0), Vector3(0.1, 2.4, 2.6), "red")


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
	# Thin dark seams between lockers so the row reads as individual doors.
	var x := x1 + 0.5
	var face_z := z + (DEPTH * 0.5 + 0.003) * (1.0 if z < 7.0 else -1.0)
	while x < x2 - 0.1:
		_box(Vector3(x, HEIGHT * 0.5, face_z), Vector3(0.025, HEIGHT - 0.1, 0.005), "dark", false)
		x += 0.5


func _build_cafeteria() -> void:
	for z: float in [-1.5, -8.0, -14.5, -21.0]:
		for x: float in [-33.0, -23.5]:
			_box(Vector3(x, 0.74, z), Vector3(6.0, 0.06, 1.0), "desk")
			_box(Vector3(x, 0.36, z), Vector3(5.6, 0.72, 0.15), "metal")
			for side: float in [-1.0, 1.0]:
				_box(Vector3(x, 0.22, z + side * 0.85), Vector3(6.0, 0.44, 0.35), "metal")
	# Serving counter in front of the kitchen door.
	_box(Vector3(-7.5, 0.5, -26.0), Vector3(0.8, 1.0, 6.0), "metal")
	_box(Vector3(-7.5, 0.5, -16.5), Vector3(0.8, 1.0, 5.0), "metal")
	# The other trash can (by the hallway) belongs to Anomalies.
	_box(Vector3(-38.8, 0.45, -27.5), Vector3(0.6, 0.9, 0.6), "dark")


func _build_kitchen_and_closet() -> void:
	# Kitchen: counters, a fridge and a stove.
	_box(Vector3(0, 0.45, -29.3), Vector3(9.4, 0.9, 1.0), "metal")
	_box(Vector3(4.2, 1.0, -20.0), Vector3(1.0, 2.0, 1.4), "metal")
	_box(Vector3(0, 0.45, -18.0), Vector3(3.0, 0.9, 1.2), "dark")
	# Custodian's closet shelves. The mop bucket belongs to Anomalies.
	_box(Vector3(-4.5, 1.0, -6.0), Vector3(0.6, 2.0, 6.0), "metal")


func _build_gym() -> void:
	_box(Vector3(22.5, 0.005, -13.0), Vector3(34.6, 0.01, 33.6), "gym_floor", false)
	# Bleachers along the east wall.
	for step in 4:
		_box(Vector3(37.15 + step * 0.75, 0.225 + step * 0.45 * 0.5, -13.0),
				Vector3(0.75, 0.45 + step * 0.45, 20.0), "wood")
	# Basketball hoops at each end.
	for z: float in [-29.4, 3.4]:
		var facing := 1.0 if z < 0.0 else -1.0
		_box(Vector3(22.5, 1.5, z), Vector3(0.15, 3.0, 0.15), "metal")
		_box(Vector3(22.5, 2.95, z + facing * 0.3), Vector3(1.8, 1.05, 0.05), "glass", false)
		_box(Vector3(22.5, 2.6, z + facing * 0.6), Vector3(0.45, 0.03, 0.45), "red", false)
	# The mascot's stand by the gym doors. The costume itself belongs to Anomalies.
	_box(Vector3(9.0, 0.15, 1.5), Vector3(1.2, 0.3, 1.2), "wood")


func _desk(pos: Vector3, width: float, depth: float) -> void:
	_box(pos + Vector3(0, 0.74, 0), Vector3(width, 0.05, depth), "desk")
	for side: float in [-1.0, 1.0]:
		_box(pos + Vector3(side * (width * 0.5 - 0.04), 0.36, 0), Vector3(0.05, 0.72, depth - 0.05), "desk")


## A desk chair. Guard room chairs (desk >= 0) can be sat in.
func _chair(pos: Vector3, desk := -1) -> void:
	_box(pos + Vector3(0, 0.25, 0), Vector3(0.1, 0.5, 0.1), "metal", false)
	_box(pos + Vector3(0, 0.5, 0), Vector3(0.55, 0.08, 0.55), "dark", false)
	_box(pos + Vector3(0, 0.85, -0.25), Vector3(0.55, 0.6, 0.06), "dark", false)
	var size := Vector3(0.6, 1.15, 0.6)
	if desk < 0:
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
	_sign(SCHOOL_NAME, Vector3(0, 3.05, 20.2), Vector3.BACK, 72)
	_sign("STAFF ENTRANCE", Vector3(0, 2.75, 45.06), Vector3.BACK, 44, Color(1, 0.85, 0.4))
	_sign("SECURITY", Vector3(5.85, 2.7, 15.0), Vector3.LEFT)
	_sign("FRONT OFFICE", Vector3(-5.85, 2.7, 15.0), Vector3.RIGHT)
	_sign("MAIN HALL", Vector3(0, 3.25, 10.15), Vector3.BACK, 44)
	_sign("SECURITY", Vector3(16.0, 2.7, 9.85), Vector3.FORWARD)
	_sign("CAFETERIA", Vector3(-15.0, 2.7, 4.15), Vector3.BACK)
	_sign("CUSTODIAN", Vector3(0, 2.7, 4.15), Vector3.BACK, 40)
	_sign("GYMNASIUM", Vector3(15.0, 2.7, 4.15), Vector3.BACK)
	_sign("KITCHEN", Vector3(-5.15, 2.6, -21.0), Vector3.LEFT, 40)
	_sign("CLASSROOM WING\nclosed", Vector3(-39.7, 2.85, 7.0), Vector3.RIGHT, 40, Color(1, 0.6, 0.5))
	_sign("LIBRARY & SCIENCE\nclosed", Vector3(39.7, 2.85, 7.0), Vector3.LEFT, 40, Color(1, 0.6, 0.5))
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
	# Gym.
	_light(Vector3(15, CEILING, -5), 0.4, 13.0)
	_light(Vector3(30, CEILING, -5), 0.0, 13.0)
	_light(Vector3(15, CEILING, -21), 0.0, 13.0)
	_light(Vector3(30, CEILING, -21), 0.35, 13.0)


func _build_cameras() -> void:
	_camera("Front Gate", Vector3(7.0, 3.2, 20.4), Vector3(0, 0, 44))
	_camera("Lobby", Vector3(5.6, 3.2, 19.6), Vector3(-2, 0.5, 11))
	_camera("Main Hall West", Vector3(-39.5, 3.2, 9.6), Vector3(0, 0.3, 6.5))
	_camera("Main Hall East", Vector3(39.5, 3.2, 4.4), Vector3(0, 0.3, 7.5))
	_camera("Front Office", Vector3(-6.4, 3.2, 10.4), Vector3(-16, 0.3, 17))
	_camera("Cafeteria", Vector3(-39.4, 3.2, 3.4), Vector3(-15, 0, -20))
	_camera("Kitchen", Vector3(4.4, 3.2, -12.6), Vector3(-2, 0.3, -27))
	_camera("Gym", Vector3(39.4, 3.2, -29.4), Vector3(12, 0.5, 0))
