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
var _unseen_for := 0.0
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
	for guard in director.living_guards():
		if _excused.has(guard.name.to_int()) or distance_to_guard(guard) > NOTICE_RANGE:
			continue
		if director.can_see(eye_position(), guard):
			_target = guard
			_answer_left = ANSWER_SECONDS
			state = "register"
			director.tell(guard.name.to_int(), "The Substitute looks up from its register. \"Guard %d?\"\nLook at it and press E to answer." % guard.slot)
			return


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
		_unseen_for = 0.0
		director.tell(_target.name.to_int(), "\"Absent.\" The Substitute closes the register. \"Detention.\"")


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
	else:
		director.tell(peer, "It nods without looking up.")


func _chase(delta: float) -> void:
	_chase_left -= delta
	if not is_instance_valid(_target) or _target.is_dead or _chase_left <= 0.0:
		_target = null
		state = "walk"
		return
	if director.can_see(eye_position(), _target):
		_unseen_for = 0.0
	else:
		_unseen_for += delta
	if _unseen_for > GIVE_UP_AFTER or not move_to(_target.global_position, CHASE_SPEED):
		_target = null
		state = "walk"
		return
	catch_nearby()


func _on_state_changed(new_state: String) -> void:
	if new_state == "register":
		Sfx.play_at(self, Sfx.notes([330.0, 0.0, 294.0], 0.18, 0.25, "square"), 0.0, 20.0)
	elif new_state == "detention":
		Sfx.play_at(self, Sfx.notes([1200.0, 1200.0, 0.0, 1200.0, 1200.0], 0.12, 0.3, "square"), 2.0, 40.0)


func _build_body() -> void:
	var cardigan := Color(0.33, 0.35, 0.2)
	part(capsule(0.26, 1.9), cardigan, Vector3(0, 0.95, 0))
	part(box(Vector3(0.5, 0.7, 0.36)), Color(0.55, 0.5, 0.42), Vector3(0, 0.45, 0))
	part(sphere(0.15), Color(0.82, 0.8, 0.76), Vector3(0, 2.02, 0))
	part(box(Vector3(0.32, 0.12, 0.3)), Color(0.35, 0.3, 0.28), Vector3(0, 2.14, 0.03))
	for side: float in [-1.0, 1.0]:
		part(box(Vector3(0.09, 0.06, 0.02)), Color(0.85, 0.9, 1.0), Vector3(side * 0.06, 2.03, -0.15), 0.6)
	# The register, held open.
	part(box(Vector3(0.34, 0.03, 0.26)), Color(0.3, 0.08, 0.08), Vector3(0, 1.25, -0.32))
