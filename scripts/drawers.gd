class_name Drawers
extends Node3D
## Drawers you can open: the front office's filing cabinets, the teachers' and the nurse's desks,
## the classroom cabinets and the nurse's medicine cabinet. E slides one out (or back in).
##
## Most hold nothing but old forms. Each night a few hold something: a spare battery (a brighter
## flashlight for the rest of the night), loose change (a few points), a page in R. Hale's
## handwriting, and once in a while something that bolts out at you. The host decides what's
## where from the night's number, and only the guard who opens a drawer finds out what was in it.

## Each drawer: [x, y of its middle, z of its front, which way it faces (+1 south / -1 north),
## width, height, what it's part of]. The furniture itself is built by SchoolBuilder; these
## match where it puts it.
const DRAWERS: Array[Array] = [
	# Front office: four filing cabinets, four drawers each (see SchoolBuilder._build_front_office).
	[-19.2, 0.16, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-19.2, 0.48, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-19.2, 0.80, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-19.2, 1.12, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-18.6, 0.16, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-18.6, 0.48, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-18.6, 0.80, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-18.6, 1.12, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-18.0, 0.16, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-18.0, 0.48, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-18.0, 0.80, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-18.0, 1.12, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-17.4, 0.16, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-17.4, 0.48, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	[-17.4, 0.80, 10.75, 1.0, 0.5, 0.29, "cabinet"], [-17.4, 1.12, 10.75, 1.0, 0.5, 0.29, "cabinet"],
	# The front office's three desks (their chairs are on the north side).
	[-13.5, 0.62, 12.62, -1.0, 0.42, 0.14, "desk"], [-13.5, 0.62, 17.12, -1.0, 0.42, 0.14, "desk"],
	[-17.5, 0.62, 14.62, -1.0, 0.42, 0.14, "desk"],
	# The teachers' desks in Rooms 101, 102 and 103, and the nurse's desk.
	[-43.5, 0.62, 18.53, 1.0, 0.42, 0.14, "desk"], [-57.5, 0.62, 18.53, 1.0, 0.42, 0.14, "desk"],
	[-46.5, 0.62, -12.53, -1.0, 0.42, 0.14, "desk"], [-70.0, 0.62, 12.38, 1.0, 0.42, 0.14, "desk"],
	# The cabinets at the back of each classroom.
	[-53.25, 0.3, 10.75, 1.0, 0.84, 0.26, "classroom"], [-67.25, 0.3, 10.75, 1.0, 0.84, 0.26, "classroom"],
	[-40.75, 0.3, 3.25, -1.0, 0.84, 0.26, "classroom"],
	# The nurse's medicine cabinet.
	[-69.35, 0.22, 19.25, -1.0, 0.6, 0.3, "medicine"], [-68.65, 0.22, 19.25, -1.0, 0.6, 0.3, "medicine"],
	[-69.35, 0.56, 19.25, -1.0, 0.6, 0.3, "medicine"], [-68.65, 0.56, 19.25, -1.0, 0.6, 0.3, "medicine"],
]
## How far a drawer slides out, and how deep it is.
const SLIDE := 0.3
const DEPTH := 0.38
const REACH := 3.0
## Pay for loose change.
const CHANGE_POINTS := 10
## Pages from R. Hale's notebook, one a night, in order.
const NOTES: Array[String] = [
	"Night 1. Quiet. The cleaner says not to sit at the desk with the monitors after 3. Didn't ask why.",
	"The lockers on the west side are warm to the touch. All of them. At 2 AM.",
	"Counted the students in the yearbook photo twice. Got a different number each time.",
	"If the intercom asks for you by name, don't answer it. It doesn't have my name. I never told it.",
	"The Lunch Lady still sets out trays. Seven of them. There were seven of us on the first shift.",
	"Something is learning the rounds. It was at Station 3 before me tonight. It punched in.",
	"Left the lights on in the library. They were off when I came back. The books were on the floor, open at the same page.",
	"I've started hearing the bell before it rings.",
	"If you're reading this, check your badge number. Make sure it's still yours.",
	"Last night I saw myself on Camera 4. I was in the guard room. I was not in the guard room.",
]
## What's in the empty ones.
const NOTHING: Array[String] = [
	"Old attendance sheets and a dead pen.", "Paper clips, rubber bands, a bus pass from 1994.",
	"Nothing but forms. Hundreds of them, all unsigned.", "A broken stapler and some cough drops.",
	"Empty, except for a lot of dust.",
]

var director: MonsterDirector
var shift: Shift
## For loose change (Night.pay_extra). Optional.
var night: Node

## Host: drawer index -> what's in it tonight ("battery", "change", "note" or "scare").
var contents: Dictionary = {}
var _open: Array[bool] = []
var _slides: Array[Node3D] = []
var _handles: Array[Interactable] = []
var _tweens: Dictionary = {}
## Host: drawers opened tonight (only the first look turns up the odd remark).
var _looked: Dictionary = {}
var _last_state := -1
var _materials := {}


func _ready() -> void:
	for i in DRAWERS.size():
		_build(i)


## Host: decides tonight's contents from the night's number (the same night, the same drawers).
func stock(night_number: int) -> void:
	contents.clear()
	_looked.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(night_number * 7919 + 1013)
	var picks: Array[int] = []
	for i in DRAWERS.size():
		picks.append(i)
	# Shuffled with our own generator, so it doesn't depend on anything else's luck.
	for i in range(picks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := picks[i]
		picks[i] = picks[j]
		picks[j] = swap
	var kinds: Array[String] = ["battery", "change", "change", "note"]
	for extra in night_number % 3:
		kinds.append("change")
	if rng.randf() < 0.2:
		kinds.append("scare")
	for n in kinds.size():
		contents[picks[n]] = kinds[n]
	_note_index = (night_number - 1) % NOTES.size()


var _note_index := 0


## Host: every drawer shut and emptied (the night's over).
func reset_all() -> void:
	contents.clear()
	_looked.clear()
	for i in _open.size():
		if _open[i]:
			_set_open.rpc(i, false, false)


## Host: for a player who joins mid-evening.
func send_state_to(peer_id: int) -> void:
	for i in _open.size():
		if _open[i]:
			_set_open.rpc_id(peer_id, i, true, true)


## Host: stocks the drawers when the shift starts and empties them when it ends, by itself
## (nobody has to remember to call stock() and reset_all()).
func _process(_delta: float) -> void:
	if shift == null or not multiplayer.is_server():
		return
	var state := int(shift.state)
	if state == _last_state:
		return
	if state == Shift.State.ON_SHIFT:
		stock(int(night.get("number")) if night and night.get("number") != null else 1)
	elif _last_state == Shift.State.ON_SHIFT:
		reset_all()
	_last_state = state


func request_toggle(index: int) -> void:
	if multiplayer.is_server():
		_request_toggle(index)
	else:
		_request_toggle.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_toggle(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _open.size():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer) if director else null
	if guard == null or guard.is_dead or guard.global_position.distance_to(_front(index)) > REACH:
		return
	var opening := not _open[index]
	_set_open.rpc(index, opening, false)
	if not opening or shift == null or shift.state != Shift.State.ON_SHIFT:
		return
	if contents.has(index):
		_give(peer, index, contents[index])
		contents.erase(index)
	elif not _looked.has(index) and randf() < 0.35:
		director.tell(peer, NOTHING.pick_random())
	_looked[index] = true


## Host: what the opener found.
func _give(peer: int, index: int, kind: String) -> void:
	if kind != "scare":
		get_tree().call_group("game", "on_award", peer, "FINDERS_KEEPERS")
	match kind:
		"battery":
			_brighten.rpc(peer)
			director.tell(peer, "A spare battery, still in the packet. Your flashlight burns brighter for the rest of the night.")
		"change":
			if night and night.has_method("pay_extra"):
				night.pay_extra(peer, CHANGE_POINTS)
			director.tell(peer, "Loose change at the back of the drawer.  +%d" % CHANGE_POINTS)
		"note":
			director.tell(peer, "A page torn from a notebook, in R. Hale's handwriting:\n\"%s\"" % NOTES[_note_index])
			_note_index = (_note_index + 1) % NOTES.size()
		"scare":
			var doll := randf() < 0.5
			_scare.rpc(index, peer, doll)
			director.flash_screen(peer, Color(0, 0, 0, 0.7), 0.4)
			director.tell(peer, "A doll's face looks up at you from the drawer. Its eyes are open. They weren't a moment ago." if doll
					else "Something small and quick bolts out of the drawer, over your hand, and is gone.")
	_found_sound(peer, kind)


func _found_sound(peer: int, kind: String) -> void:
	if kind == "scare":
		return
	if peer == multiplayer.get_unique_id():
		_found(kind)
	else:
		_found.rpc_id(peer, kind)


# --- Every computer ------------------------------------------------------------------------

## The opener's own little sound for what they found.
@rpc("authority", "call_remote", "reliable")
func _found(kind: String) -> void:
	match kind:
		"note":
			SoundBank.play_flat(self, "paper_flip", -2.0, Sfx.chirp(900.0, 600.0, 0.08, 2, 0.1))
		"battery":
			SoundBank.play_flat(self, "metal_click", -4.0, Sfx.thud(2.0, 0.05, 0.4))
		"change":
			Sfx.play_flat(self, Sfx.notes([1568.0, 2093.0], 0.07, 0.18), -6.0)


## A guard's flashlight gets a fresh battery: brighter and further, everywhere, for tonight.
@rpc("authority", "call_local", "reliable")
func _brighten(peer: int) -> void:
	var guard := director.guard_by_peer(peer) if director else null
	if guard:
		guard.battery = maxf(guard.battery, 1.0) * 1.25
		guard.apply_flashlight()


## Something in the drawer: everyone near hears it; the one who opened it jumps.
@rpc("authority", "call_local", "reliable")
func _scare(index: int, peer: int, doll: bool) -> void:
	var slide := _slides[index]
	if doll:
		SoundBank.play_at(slide, "giggle", 0.0, 18.0, Sfx.chirp(700.0, 1200.0, 0.1, 3, 0.15))
	else:
		SoundBank.play_at(slide, "skitter", 2.0, 18.0, Sfx.notes([1800.0, 2400.0, 1600.0, 2600.0], 0.03, 0.12, "noise"))
	if peer == multiplayer.get_unique_id():
		SoundBank.play_flat(self, "stinger", -3.0, Sfx.notes([110.0, 104.0, 98.0], 0.3, 0.4, "saw"))


@rpc("authority", "call_local", "reliable")
func _set_open(index: int, open: bool, instant: bool) -> void:
	_open[index] = open
	_handles[index].prompt = "Close the drawer" if open else "Open the drawer"
	var box := _slides[index].get_child(0) as Node3D
	var running: Tween = _tweens.get(index)
	if running and running.is_valid():
		running.kill()
	var to := SLIDE if open else 0.0
	if instant:
		box.position.z = to
		return
	var tween := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tweens[index] = tween
	tween.tween_property(box, "position:z", to, 0.35 if open else 0.22)
	var metal: bool = DRAWERS[index][6] != "classroom"
	if open:
		SoundBank.play_at(_slides[index], "metal_click" if metal else "creak", -6.0, 14.0, Sfx.thud(1.6, 0.06, 0.4))
	else:
		tween.tween_callback(func() -> void:
			SoundBank.play_at(_slides[index], "latch", -4.0, 14.0, Sfx.thud(1.2, 0.08, 0.5)))


## Just in front of a drawer, on the floor.
func _front(index: int) -> Vector3:
	var info: Array = DRAWERS[index]
	return Vector3(info[0], 0.0, info[2] + info[3] * 0.4)


func _material(kind: String) -> StandardMaterial3D:
	if not _materials.has(kind):
		var material := StandardMaterial3D.new()
		match kind:
			"cabinet":
				material.albedo_color = Color(0.46, 0.48, 0.5)
				material.metallic = 0.45
				material.roughness = 0.45
			"desk":
				material.albedo_color = Color(0.42, 0.44, 0.45)
				material.metallic = 0.35
				material.roughness = 0.5
			"classroom":
				material.albedo_color = Color(0.5, 0.36, 0.22)
				material.roughness = 0.7
			"medicine":
				material.albedo_color = Color(0.86, 0.86, 0.83)
				material.roughness = 0.6
			"handle":
				material.albedo_color = Color(0.75, 0.76, 0.78)
				material.metallic = 0.8
				material.roughness = 0.3
			"inside":
				material.albedo_color = Color(0.18, 0.18, 0.19)
				material.roughness = 0.9
			"paper":
				material.albedo_color = Color(0.88, 0.86, 0.78)
				material.roughness = 0.95
		_materials[kind] = material
	return _materials[kind]


func _piece(parent: Node3D, size: Vector3, at: Vector3, material: String) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(size)
	mesh.material_override = _material(material)
	mesh.position = at
	parent.add_child(mesh)


## One drawer: its front with a handle, and the tray behind it (inside the furniture while shut).
func _build(index: int) -> void:
	var info: Array = DRAWERS[index]
	var width: float = info[4]
	var height: float = info[5]
	var slide := Node3D.new()
	slide.name = "Drawer%d" % index
	slide.position = Vector3(info[0], info[1], info[2])
	# Its local +Z points out of the furniture.
	slide.rotation.y = 0.0 if float(info[3]) > 0.0 else PI
	add_child(slide)
	var box := Node3D.new()
	slide.add_child(box)
	_piece(box, Vector3(width, height, 0.02), Vector3(0, 0, 0.012), info[6])
	_piece(box, Vector3(minf(width * 0.35, 0.16), 0.022, 0.02), Vector3(0, height * 0.18, 0.032), "handle")
	# The tray: a floor, two sides and a back, dark inside, with papers in it.
	var inner := Vector2(width - 0.04, height - 0.04)
	_piece(box, Vector3(inner.x, 0.01, DEPTH), Vector3(0, -inner.y * 0.5, -DEPTH * 0.5), "inside")
	for side: float in [-1.0, 1.0]:
		_piece(box, Vector3(0.01, inner.y, DEPTH), Vector3(side * inner.x * 0.5, 0, -DEPTH * 0.5), "inside")
	_piece(box, Vector3(inner.x, inner.y, 0.01), Vector3(0, 0, -DEPTH), "inside")
	_piece(box, Vector3(inner.x * 0.75, 0.012, DEPTH * 0.7), Vector3(0.01, -inner.y * 0.5 + 0.012, -DEPTH * 0.5), "paper")
	# What E is pressed on: on the talk layer, so nobody bumps into it.
	var handle := Interactable.new()
	handle.prompt = "Open the drawer"
	handle.collision_layer = Interactable.TALK_LAYER
	handle.collision_mask = 0
	var shape := CollisionShape3D.new()
	var block := BoxShape3D.new()
	block.size = Vector3(width, height, 0.06)
	shape.shape = block
	shape.position = Vector3(0, 0, 0.02)
	handle.add_child(shape)
	box.add_child(handle)
	handle.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			request_toggle(index))
	_slides.append(slide)
	_handles.append(handle)
	_open.append(false)
