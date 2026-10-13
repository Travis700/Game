class_name Totems
extends Node3D
## Revive totems: small carved stones hidden around the school, a few each night.
## A living guard can use one to roll the dice for a dead teammate:
## 4 in 6 brings them back, 2 in 6 lets something out instead. Either way the totem crumbles.

signal revive_rolled(user_peer: int, roll: int, revived_peer: int, at: Vector3)
signal bad_roll(user_peer: int, roll: int, at: Vector3)

const PER_NIGHT := 3
const REVIVE_ON_OR_BELOW := 4
const SPOTS: Array[Vector3] = [
	Vector3(-38.0, 0, -28.0), Vector3(3.5, 0, -28.5), Vector3(36.5, 0, -27.0), Vector3(7.0, 0, -28.5),
	Vector3(-19.0, 0, 19.0), Vector3(3.5, 0, -10.5), Vector3(-30.0, 0, 32.0), Vector3(30.0, 0, 32.0),
	Vector3(-38.5, 0, 0.0), Vector3(38.0, 0, 2.5),
]

var director: MonsterDirector
var _stones: Dictionary = {}
var _stone_material: StandardMaterial3D
var _rune_material: StandardMaterial3D


func _ready() -> void:
	_stone_material = StandardMaterial3D.new()
	_stone_material.albedo_color = Color(0.3, 0.29, 0.27)
	_rune_material = StandardMaterial3D.new()
	_rune_material.albedo_color = Color(0.4, 0.9, 0.8)
	_rune_material.emission_enabled = true
	_rune_material.emission = Color(0.3, 0.9, 0.8)
	_rune_material.emission_energy_multiplier = 2.0


## Host: hides tonight's totems in random spots.
func place_random() -> void:
	clear_all()
	var spots: Array = range(SPOTS.size())
	spots.shuffle()
	for i in mini(PER_NIGHT, spots.size()):
		_place.rpc(spots[i])


## Host: removes any totems left over.
func clear_all() -> void:
	for index: int in _stones.keys():
		_remove.rpc(index)


## Host: for a player who joins mid-evening.
func send_state_to(peer_id: int) -> void:
	for index: int in _stones:
		_place.rpc_id(peer_id, index)


@rpc("authority", "call_local", "reliable")
func _place(index: int) -> void:
	if _stones.has(index):
		return
	var stone := Interactable.new()
	stone.prompt = "Use the revive totem  (4 in 6: revive a teammate · 2 in 6: something gets out)"
	stone.position = SPOTS[index]
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.9, 0.45)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 0.45
	stone.add_child(collider)
	var body := MeshInstance3D.new()
	body.mesh = Monster.box(Vector3(0.4, 0.8, 0.4))
	body.material_override = _stone_material
	body.position.y = 0.4
	stone.add_child(body)
	for side in 4:
		var rune := MeshInstance3D.new()
		rune.mesh = Monster.box(Vector3(0.12, 0.3, 0.01))
		rune.material_override = _rune_material
		var angle := side * PI * 0.5
		rune.position = Vector3(0, 0.5, 0) + Vector3(0, 0, 0.205).rotated(Vector3.UP, angle)
		rune.rotation.y = angle
		stone.add_child(rune)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 0.9, 0.8)
	glow.light_energy = 0.4
	glow.omni_range = 2.5
	glow.position.y = 0.6
	stone.add_child(glow)
	stone.used.connect(func(_by: Node) -> void: _request_use_from_here(index))
	add_child(stone)
	_stones[index] = stone


@rpc("authority", "call_local", "reliable")
func _remove(index: int) -> void:
	if _stones.has(index):
		(_stones[index] as Node).queue_free()
		_stones.erase(index)


func _request_use_from_here(index: int) -> void:
	if multiplayer.is_server():
		_request_use(index)
	else:
		_request_use.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_use(index: int) -> void:
	if not multiplayer.is_server() or not _stones.has(index):
		return
	var user := multiplayer.get_remote_sender_id()
	if user == 0:
		user = multiplayer.get_unique_id()
	var dead := director.dead_guards()
	if dead.is_empty():
		director.tell(user, "The totem stays cold. There's nobody to bring back.")
		return
	var at: Vector3 = SPOTS[index]
	_remove.rpc(index)
	var roll := randi_range(1, 6)
	if roll <= REVIVE_ON_OR_BELOW:
		revive_rolled.emit(user, roll, dead[0].name.to_int(), at)
	else:
		bad_roll.emit(user, roll, at)
