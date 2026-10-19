class_name Substitute
extends Monster
## The Substitute: a teacher nobody hired, standing at the front of an empty classroom in the
## classroom wing. Every so often it walks to another room.
##
## Come near it and it takes the register: "Guard 2?" Look at it and press E to answer
## "Here!" in time and it lets you be for a while. Stay quiet and you get detention: it comes
## after you until it loses sight of you.

const WALK_SPEED := 1.4
const CHASE_SPEED := 4.1
const NOTICE_RANGE := 8.0
## Real seconds to answer the register.
const ANSWER_SECONDS := 4.0
## Real seconds a guard who answered is left alone.
const EXCUSED_SECONDS := 60.0
const CHASE_SECONDS := 20.0
const GIVE_UP_AFTER := 5.0
## Where it stands to teach in each classroom (by the board).
const CLASSROOMS: Array[Vector3] = [Vector3(-47.0, 0, 18.2), Vector3(-61.0, 0, 18.2), Vector3(-49.0, 0, -12.0)]

var _room := 0
var _teach_left := 0.0
var _target: Guard
var _answer_left := 0.0
var _chase_left := 0.0
## Peer id -> real seconds that guard is excused for.
var _excused: Dictionary = {}
var _talk: Interactable


func _init() -> void:
	display_name = "the Substitute"
	state = "teach"


func _ready() -> void:
	super()
	_room = randi() % CLASSROOMS.size()
	_teach_left = randf_range(40.0, 80.0)
	_talk = add_talk_point("Answer the register: \"Here!\"")
	_talk.used.connect(func(_by: Node) -> void:
		if multiplayer.is_server():
			_answer()
		else:
			_answer.rpc_id(1))


func think(delta: float) -> void:
	for peer: int in _excused.keys():
		_excused[peer] -= delta
		if _excused[peer] <= 0.0:
			_excused.erase(peer)
	match state:
		"register":
			_take_register(delta)
		"detention":
			_chase(delta)
		_:
			_go_about(delta)


func _go_about(delta: float) -> void:
	var spot := CLASSROOMS[_room]
	if global_position.distance_to(spot) > 1.0:
		state = "walk"
		move_to(spot, WALK_SPEED)
	else:
		state = "teach"
		halt()
		face(Vector3(0, 0, -1) if spot.z > 0.0 else Vector3(0, 0, 1))
		_teach_left -= delta
		if _teach_left <= 0.0:
			_room = (_room + 1 + randi() % (CLASSROOMS.size() - 1)) % CLASSROOMS.size()
			_teach_left = randf_range(40.0, 80.0)
	var guard := find_guard(NOTICE_RANGE, true, func(someone: Guard) -> bool:
		return not _excused.has(someone.name.to_int()))
	if guard:
		_target = guard
		_answer_left = ANSWER_SECONDS
		state = "register"
		director.tell(guard.name.to_int(), "The Substitute looks up from its register. \"%s?\"\nLook at it and press {use} to answer." % guard.display_name())


func _take_register(delta: float) -> void:
	halt()
	if not is_instance_valid(_target) or _target.is_dead:
		state = "teach"
		return
	face(_target.global_position - global_position)
	_answer_left -= delta
	if _answer_left <= 0.0:
		state = "detention"
		_chase_left = CHASE_SECONDS
		start_chase()
		director.tell(_target.name.to_int(), "\"Absent.\" The Substitute closes the register. \"Detention.\"")
		_write_up(_target.display_name())


@rpc("any_peer", "call_remote", "reliable")
func _answer() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead:
		return
	_excused[peer] = EXCUSED_SECONDS
	if guard == _target and state in ["register", "detention"]:
		_target = null
		state = "teach"
		director.tell(peer, "\"...Present.\" It makes a mark and goes back to the board.")
		if director.career:
			director.career.award(peer, "PRESENT")
	else:
		director.tell(peer, "It nods without looking up.")


func _chase(delta: float) -> void:
	_chase_left -= delta
	if _chase_left <= 0.0 or not chase(_target, CHASE_SPEED, delta, GIVE_UP_AFTER):
		_target = null
		state = "walk"


## After a lockdown: back to teaching, and a register in progress starts its count again.
func _after_lockdown(before: String) -> void:
	_answer_left = ANSWER_SECONDS
	super(before)


func _on_state_changed(new_state: String) -> void:
	if new_state == "register":
		Sfx.play_at(self, Sfx.notes([330.0, 0.0, 294.0], 0.18, 0.25, "square"), 0.0, 20.0)
	elif new_state == "detention":
		SoundBank.play_at(self, "hand_bell", 2.0, 40.0, Sfx.notes([1200.0, 1200.0, 0.0, 1200.0, 1200.0], 0.12, 0.3, "square"))


## Host: the name goes up behind it, in red marker, for the rest of the night (on the board
## if it's at the front of a classroom).
func _write_up(who: String) -> void:
	# (It faces -Z, like everything else: behind it is +Z.)
	var back := Vector3(global_basis.z.x, 0, global_basis.z.z).normalized()
	var from := global_position + Vector3(0, 1.6, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + back * 3.0, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# Only on a wall or a board (not a guard, a door, or the floor).
	if hit.is_empty() or not hit["collider"] is StaticBody3D or absf((hit["normal"] as Vector3).y) > 0.5:
		return
	_writings.append([hit["position"], hit["normal"], who])
	_show_writing.rpc(hit["position"], hit["normal"], who)


## What it's written up tonight: [at, normal, name] each, for anyone who joins later.
var _writings: Array = []


## Host: a late joiner sees what's already on the walls.
func send_writing_to(peer_id: int) -> void:
	for writing: Array in _writings:
		_show_writing.rpc_id(peer_id, writing[0], writing[1], writing[2])


@rpc("authority", "call_local", "reliable")
func _show_writing(at: Vector3, normal: Vector3, who: String) -> void:
	var writing := Label3D.new()
	writing.text = "DETENTION\n%s" % who.to_upper()
	writing.font_size = 64
	writing.pixel_size = 0.004
	writing.modulate = Color(0.75, 0.08, 0.06)
	writing.outline_size = 0
	writing.shaded = true
	writing.double_sided = false
	# (On the director, not among the monsters, which is all the monster list should hold.)
	director.add_child(writing)
	writing.global_position = at + normal * 0.02
	writing.look_at(writing.global_position - normal, Vector3.UP)
	writing.rotate_object_local(Vector3.FORWARD, randf_range(-0.08, 0.08))
	# Gone with it at the end of the night.
	tree_exiting.connect(writing.queue_free)


func _build_body() -> void:
	if use_model("substitute", 1.8):
		return
	var cardigan := Color(0.33, 0.35, 0.2)
	part(capsule(0.26, 1.9), cardigan, Vector3(0, 0.95, 0))
	part(box(Vector3(0.5, 0.7, 0.36)), Color(0.55, 0.5, 0.42), Vector3(0, 0.45, 0))
	part(sphere(0.15), Color(0.82, 0.8, 0.76), Vector3(0, 2.02, 0))
	part(box(Vector3(0.32, 0.12, 0.3)), Color(0.35, 0.3, 0.28), Vector3(0, 2.14, 0.03))
	for side: float in [-1.0, 1.0]:
		part(box(Vector3(0.09, 0.06, 0.02)), Color(0.85, 0.9, 1.0), Vector3(side * 0.06, 2.03, -0.15), 0.6)
	# The register, held open.
	part(box(Vector3(0.34, 0.03, 0.26)), Color(0.3, 0.08, 0.08), Vector3(0, 1.25, -0.32))
