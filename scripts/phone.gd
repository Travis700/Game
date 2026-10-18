class_name Phone
extends Node3D
## The phone on the front office desk. From night 3 it rings once or twice a night, loud enough
## to hear across the building. Whoever answers it (E) hears a tip-off: where something out of
## place is right now. Nobody answers in time, and the line goes dead. So do the lights.
##
## The host decides when it rings; every computer hears it.

const AT := Vector3(-14.4, 0.8, 13.0)
## Real seconds to answer.
const RING_SECONDS := 35.0
## When it can ring (in-game minutes).
const WINDOW := Vector2(40.0, 330.0)
## What the voice says about each kind of anomaly. %s is the area.
const TIPS := {
	"Moved object": "\"Someone's been moving things in the %s.\"",
	"Missing object": "\"Something's gone from the %s. You'll want to write that down.\"",
	"Extra object": "\"Somebody left something in the %s.\"",
	"Figure": "\"There's someone standing in the %s. Don't go near them.\"",
	"Noise": "\"Can you hear that? Something in the %s. Go and listen.\"",
}

var director: MonsterDirector
var _ring_noise := 0.0
var anomalies: Anomalies
var power: Power

## True while it's ringing. On every computer.
var ringing := false

var _phone: Interactable
var _ring_player: AudioStreamPlayer3D
# Host only.
var _schedule: Array[float] = []
var _ring_left := 0.0


func _ready() -> void:
	_phone = Interactable.new()
	_phone.name = "OfficePhone"
	add_child(_phone)
	_phone.position = AT
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 0.15, 0.25)
	shape.shape = box
	_phone.add_child(shape)
	_part(Vector3(0.26, 0.07, 0.22), Vector3(0, 0, 0), Color(0.12, 0.12, 0.13))
	_part(Vector3(0.28, 0.06, 0.08), Vector3(0, 0.07, 0.0), Color(0.08, 0.08, 0.09))
	_part(Vector3(0.04, 0.02, 0.04), Vector3(0.09, 0.045, -0.07), Color(1.0, 0.2, 0.1), 2.0)
	_phone.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				_request_answer()
			else:
				_request_answer.rpc_id(1))
	_ring_player = AudioStreamPlayer3D.new()
	_ring_player.bus = &"SFX"
	_ring_player.stream = SoundBank.get_sound("phone_ring",
			Sfx.notes([880.0, 740.0, 880.0, 740.0, 880.0, 740.0, 0.0, 0.0, 0.0, 0.0], 0.09, 0.35, "square", true), true)
	_ring_player.max_distance = 70.0
	_ring_player.unit_size = 6.0
	_phone.add_child(_ring_player)
	_show()


# --- Host --------------------------------------------------------------------------------

## `ends_by` (in-game minutes) keeps every ring before then: the finale wants the phone quiet.
func plan(night_number: int, ends_by := WINDOW.y) -> void:
	_schedule.clear()
	var count := 0 if night_number < 3 else (1 if night_number < 6 else 2)
	for i in count:
		_schedule.append(randf_range(WINDOW.x, minf(WINDOW.y, ends_by)))
	_schedule.sort()


func update(minutes: float, delta: float) -> void:
	if ringing:
		# The ringing carries: anything that hunts by sound drifts toward the office.
		_ring_noise -= delta
		if _ring_noise <= 0.0:
			_ring_noise = 1.0
			director.make_noise(AT, 1.5, 30.0)
		_ring_left -= delta
		if _ring_left <= 0.0:
			_set_ringing.rpc(false)
			for guard in director.living_guards():
				director.tell(guard.name.to_int(), "The phone stops ringing. Then the lights go out." if power.on
						else "The phone in the front office stops ringing.")
			power.cut(true)
		return
	if not _schedule.is_empty() and minutes >= _schedule[0]:
		_schedule.pop_front()
		_ring_left = RING_SECONDS
		_set_ringing.rpc(true)
		for guard in director.living_guards():
			director.tell(guard.name.to_int(), "A phone is ringing in the front office. Answer it ({use}), or the power goes.")


func end_night() -> void:
	_schedule.clear()
	if ringing:
		_set_ringing.rpc(false)


@rpc("any_peer", "call_remote", "reliable")
func _request_answer() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead or guard.global_position.distance_to(AT) > 4.0:
		return
	if not ringing:
		director.tell(peer, "Just the dial tone.")
		return
	_set_ringing.rpc(false)
	var tip := anomalies.tip()
	if tip.is_empty():
		director.tell(peer, "Breathing on the line. Then a click.")
	else:
		director.tell(peer, "A whisper on the line: " + TIPS.get(tip["type"], "\"Look in the %s.\"") % tip["area"])


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_ringing(on: bool) -> void:
	ringing = on
	_show()


func _show() -> void:
	_phone.prompt = "Answer the phone" if ringing else "Office phone"
	if ringing and not _ring_player.playing:
		_ring_player.play()
	elif not ringing:
		_ring_player.stop()


func _part(size: Vector3, at: Vector3, color: Color, glow := 0.0) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(size)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = glow
	mesh.material_override = material
	mesh.position = at
	_phone.add_child(mesh)
