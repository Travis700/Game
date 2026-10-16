class_name NightCleaner
extends Monster
## The night cleaner: a harmless school employee pushing a mop cart from room to room.
## Wherever they mop they put down a yellow WET FLOOR sign, and it stays there until their next
## stop: something extra on the cameras that is just cleaning, not an anomaly. Log it and it's a
## false report. (The Other Cleaner never puts one down.)
##
## From night 5 a second "cleaner" can turn up (OtherCleaner). Telling them apart on the
## cameras is the point: the real one always has their cart.

const WALK_SPEED := 1.3
const ROUTE: Array[Vector3] = [
	Vector3(0, 0, 15), Vector3(-13, 0, 15), Vector3(-25, 0, 7), Vector3(-22, 0, -10),
	Vector3(0, 0, -20), Vector3(25, 0, 7), Vector3(22, 0, -12), Vector3(0, 0, -5),
]



func _init() -> void:
	display_name = "the night cleaner"
	harmless = true
	state = "walk"


func think(delta: float) -> void:
	_wander(delta)


## Mops for a while in each room, then moves on to another.
func _wander(delta: float) -> void:
	if patrol_step(ROUTE, delta, WALK_SPEED, Vector2(6.0, 12.0), 3):
		state = "mop"
	elif _patrol_pause <= 0.0:
		state = "walk"


func _build_body() -> void:
	_build_person(true)


var _sign: Node3D


## Every computer: mopping starts, and the sign goes down beside the cleaner.
func _on_state_changed(new_state: String) -> void:
	if new_state != "mop" or not is_inside_tree():
		return
	if _sign == null:
		_sign = _build_sign()
		director.add_child.call_deferred(_sign)
		_sign.tree_entered.connect(func() -> void: _place_sign(), CONNECT_ONE_SHOT)
	else:
		_place_sign()


func _place_sign() -> void:
	if not is_instance_valid(_sign) or not _sign.is_inside_tree():
		return
	_sign.global_position = global_position + global_basis.x * 0.9
	_sign.rotation.y = rotation.y + 0.4


func _exit_tree() -> void:
	if is_instance_valid(_sign):
		_sign.queue_free()


func _build_sign() -> Node3D:
	var stand := Node3D.new()
	stand.name = "WetFloorSign"
	if ModelKit.add(stand, "prop_wet_floor_sign", 0.65, 0.0) != null:
		return stand
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(1.0, 0.85, 0.05)
	for side: float in [-1.0, 1.0]:
		var board := MeshInstance3D.new()
		board.mesh = Monster.box(Vector3(0.32, 0.62, 0.02))
		board.material_override = yellow
		board.position = Vector3(0, 0.3, side * 0.09)
		board.rotation.x = side * 0.28
		stand.add_child(board)
	var words := Label3D.new()
	words.text = "WET\nFLOOR"
	words.font_size = 20
	words.pixel_size = 0.004
	words.modulate = Color(0.05, 0.05, 0.05)
	words.position = Vector3(0, 0.36, 0.2)
	words.rotation.x = -0.28
	stand.add_child(words)
	return stand


func _build_person(with_cart: bool) -> void:
	# Both cleaners wear the same model: telling them apart is the whole point.
	if not use_model("other_cleaner", 1.8):
		part(capsule(0.28, 1.65), Color(0.32, 0.4, 0.5), Vector3(0, 0.83, 0))
		part(sphere(0.15), Color(0.72, 0.6, 0.5), Vector3(0, 1.78, 0))
		part(box(Vector3(0.3, 0.08, 0.32)), Color(0.12, 0.15, 0.25), Vector3(0, 1.9, -0.03))
		for side: float in [-1.0, 1.0]:
			part(sphere(0.07), Color(0.95, 0.85, 0.1), Vector3(side * 0.3, 1.0, -0.15))
	if with_cart and _model != null:
		# The mop bucket on wheels, pushed in front.
		var cart := Node3D.new()
		cart.position = Vector3(0, 0, -0.75)
		add_child(cart)
		if ModelKit.add(cart, "prop_mop_bucket", 1.3, PI * 0.5, visual_layers) != null:
			return
		cart.queue_free()
	if with_cart:
		part(box(Vector3(0.6, 0.5, 0.5)), Color(0.95, 0.8, 0.1), Vector3(0, 0.3, -0.75))
		part(box(Vector3(0.04, 1.3, 0.04)), Color(0.5, 0.4, 0.3), Vector3(0.22, 0.95, -0.75))
		part(box(Vector3(0.25, 0.12, 0.12)), Color(0.85, 0.85, 0.8), Vector3(0.22, 0.3, -0.95))
