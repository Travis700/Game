class_name SelfPortrait
extends Node3D
## The Self-Portrait: the covered canvas at the front of the art room is painting itself, and
## it's painting one of the guards. Each stage shows on the Art Room camera: an outline, then
## the uniform, the face, and finally eyes and a name. When it's finished, that guard is caught,
## wherever they are.
##
## Someone has to walk to the art room and turn the canvas to the wall (E), which wipes it.
## A while later it starts again, maybe on someone else. The host runs it; every computer shows it.

const FINISHED := 5
## In-game minutes per stage, and the rest after the canvas is turned around.
const STAGE_MINUTES := 22.0
const REST_MINUTES := Vector2(45.0, 70.0)

var director: MonsterDirector
## Host: true while it's part of tonight.
var active := false
## Guards who've logged it tonight. Host only.
var credited: Array[int] = []
## 0 = blank, 1-4 = painting, 5 = finished. Shown on every computer.
var stage := 0

var _easel: Interactable
var _layers: Array[Node3D] = []
var _uniform: StandardMaterial3D
var _name_label: Label3D
var _subject := 0
var _next_at := 0.0


func build(easel: Interactable) -> void:
	_easel = easel
	_easel.used.connect(func(_by: Node) -> void:
		if multiplayer.is_server():
			_request_turn()
		else:
			_request_turn.rpc_id(1))
	# The painting is drawn on boxes just in front of the canvas, one per stage.
	var front := easel.global_position + Vector3(0, 0, 0.07)
	_layers.append(_flat(front + Vector3(0, -0.05, 0), Vector2(0.55, 1.2), Color(0.15, 0.13, 0.12)))
	var body := _flat(front + Vector3(0, -0.25, 0.002), Vector2(0.5, 0.7), Color(0.2, 0.3, 0.55))
	_uniform = (body.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
	_layers.append(body)
	_layers.append(_flat(front + Vector3(0, 0.32, 0.004), Vector2(0.28, 0.34), Color(0.8, 0.72, 0.62)))
	var eyes := Node3D.new()
	add_child(eyes)
	for side: float in [-1.0, 1.0]:
		var eye := _flat(front + Vector3(side * 0.06, 0.35, 0.006), Vector2(0.05, 0.03), Color(0.95, 0.95, 0.9), 2.0)
		eye.reparent(eyes)
	_name_label = Label3D.new()
	_name_label.font_size = 36
	_name_label.pixel_size = 0.004
	_name_label.modulate = Color(0.1, 0.05, 0.05)
	_name_label.outline_size = 0
	_name_label.position = front + Vector3(0, -0.68, 0.008)
	eyes.add_child(_name_label)
	_layers.append(eyes)
	_show(0, 1)


# --- Host -------------------------------------------------------------------------------

func activate(minutes: float) -> void:
	active = true
	credited.clear()
	_start_painting(minutes)


func deactivate() -> void:
	active = false
	_subject = 0
	if stage != 0:
		_show.rpc(0, 1)


func update(minutes: float) -> void:
	# The finale is a chase, not a sitting: the painting waits.
	if not active or director.finale:
		return
	var subject := director.guard_by_peer(_subject)
	if stage > 0 and (subject == null or subject.is_dead):
		# Its model is gone. It starts on someone else.
		_start_painting(minutes)
		return
	if minutes < _next_at:
		return
	if stage == 0:
		_start_painting(minutes)
		return
	var next := stage + 1
	_next_at = minutes + STAGE_MINUTES
	_show.rpc(next, subject.slot)
	match next:
		2:
			director.tell(_subject, "You feel watched, like someone is studying your face. You smell paint, from the direction of the art room.")
		3:
			director.tell(_subject, "Your face feels stiff, like drying paint. Something in the art room is nearly done with you.")
		4:
			director.tell(_subject, "Somewhere in the art room, a portrait of %s is almost finished." % subject.display_name())
			director.announcement.emit("A smell of fresh paint drifts through the school. In the art room, a portrait of %s is almost finished." % subject.display_name(), "")
		FINISHED:
			director.kill(subject, "the Self-Portrait")
			_next_at = minutes + randf_range(REST_MINUTES.x, REST_MINUTES.y)
			_subject = 0
			_show.rpc(0, 1)


func _start_painting(minutes: float) -> void:
	var living := director.living_guards()
	if living.is_empty():
		return
	var subject: Guard = living.pick_random()
	_subject = subject.name.to_int()
	_next_at = minutes + STAGE_MINUTES
	_show.rpc(1, subject.slot)


@rpc("any_peer", "call_remote", "reliable")
func _request_turn() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	if stage == 0:
		director.tell(peer, "A blank canvas on an easel.")
		return
	director.tell(peer, "You turn the canvas to the wall. Behind you, something sighs.")
	if director.career:
		director.career.award(peer, "ART_CRITIC")
	_subject = 0
	_next_at = director.minutes() + randf_range(REST_MINUTES.x, REST_MINUTES.y)
	_show.rpc(0, 1)


# --- Every computer ----------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _show(new_stage: int, slot: int) -> void:
	stage = new_stage
	for i in _layers.size():
		_layers[i].visible = stage > i
	_uniform.albedo_color = Guard.UNIFORM_COLORS[(slot - 1) % Guard.UNIFORM_COLORS.size()]
	_name_label.text = "GUARD %d" % slot
	_easel.prompt = "Turn the canvas to the wall" if stage > 0 else "Look at the canvas"


func _flat(at: Vector3, size: Vector2, color: Color, glow := 0.0) -> Node3D:
	var holder := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(Vector3(size.x, size.y, 0.002))
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	mesh.material_override = material
	holder.add_child(mesh)
	holder.position = at
	add_child(holder)
	return holder
