class_name Televisions
extends Node3D
## The old TVs on their carts in the classrooms. Nobody watches them at night, but something
## does: a monster passing one may switch it on, and it sits there glowing with snow, lighting
## up the corner of the room, until a guard switches it off (E). On the cameras, a classroom
## with a TV glowing in it is a sign something has been through. Quiet on purpose: the hissing
## TV you hear in Room 101 is a Noise to log, and this mustn't be mistaken for it.
##
## The host decides; every computer shows it.

## Host: how often each monster might reach for a TV it's near, from how far, and the chance.
const MONSTER_CHECK_SECONDS := 5.0
const MONSTER_REACH := 4.0
const MONSTER_CHANCE := 0.15
## The picture, on the set's front (in the set's own space: it faces +Z).
const SCREEN_AT := Vector3(0, 0.26, 0.178)
const SCREEN_SIZE := Vector2(0.3, 0.23)

var director: MonsterDirector
var power: Power

## One entry per set: {"screen": MeshInstance3D, "glow": OmniLight3D, "body": Interactable, "hum"}.
var _sets: Array[Dictionary] = []
var _on: Array[bool] = []
var _monster_timer := 0.0


## Every computer, once the school is built.
func build(spots: Array[Dictionary]) -> void:
	for spot in spots:
		var holder := Node3D.new()
		holder.position = spot["at"]
		holder.rotation.y = spot["turn"]
		add_child(holder)
		var body := Interactable.new()
		body.prompt = "Switch the TV on"
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.42, 0.42, 0.38)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		collider.position = Vector3(0, 0.21, 0)
		body.add_child(collider)
		body.used.connect(_on_used.bind(_sets.size()))
		holder.add_child(body)
		var screen := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = SCREEN_SIZE
		screen.mesh = quad
		screen.material_override = _snow_material()
		screen.position = SCREEN_AT
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.visible = false
		holder.add_child(screen)
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.7, 0.8, 1.0)
		glow.light_energy = 0.7
		glow.omni_range = 4.0
		glow.omni_attenuation = 1.4
		glow.position = SCREEN_AT + Vector3(0, 0, 0.35)
		glow.visible = false
		holder.add_child(glow)
		var hum := AudioStreamPlayer3D.new()
		hum.stream = Sfx.notes([120.0], 1.0, 0.03, "saw", true)
		hum.volume_db = -20.0
		hum.max_distance = 7.0
		holder.add_child(hum)
		_sets.append({"screen": screen, "glow": glow, "body": body, "hum": hum})
		_on.append(false)


var _snow: ShaderMaterial


func _snow_material() -> ShaderMaterial:
	if _snow == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded;
float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(UV * vec2(160.0, 120.0));
	float snow = rand(cell + floor(TIME * 30.0) * 7.13);
	float roll = 0.85 + 0.15 * sin(UV.y * 40.0 + TIME * 6.0);
	vec2 d = UV - 0.5;
	ALBEDO = vec3(0.75, 0.8, 0.9) * snow * roll * (1.0 - dot(d, d) * 1.6);
}
"""
		_snow = ShaderMaterial.new()
		_snow.shader = shader
	return _snow


func _on_used(by: Node, index: int) -> void:
	var guard := by as Guard
	if guard == null or not guard.is_local() or guard.is_dead:
		return
	if multiplayer.is_server():
		_request_toggle(index)
	else:
		_request_toggle.rpc_id(1, index)


@rpc("any_peer", "call_remote", "reliable")
func _request_toggle(index: int) -> void:
	if not multiplayer.is_server() or index < 0 or index >= _sets.size():
		return
	if power and not power.on:
		return
	_set_on.rpc(index, not _on[index])


@rpc("authority", "call_local", "reliable")
func _set_on(index: int, on: bool) -> void:
	if index < 0 or index >= _sets.size():
		return
	_on[index] = on
	var tv := _sets[index]
	(tv["screen"] as Node3D).visible = on
	(tv["glow"] as Node3D).visible = on
	var hum: AudioStreamPlayer3D = tv["hum"]
	if on:
		hum.play()
	else:
		hum.stop()
	(tv["body"] as Interactable).prompt = "Switch the TV off" if on else "Switch the TV on"
	SoundBank.play_at(tv["body"], "switch", -10.0, 10.0, Sfx.notes([500.0, 0.0, 300.0], 0.015, 0.2, "square"))


## Host, every frame of the night: monsters switch on the sets they pass.
func update(delta: float) -> void:
	_monster_timer -= delta
	if _monster_timer > 0.0 or director == null:
		return
	_monster_timer = MONSTER_CHECK_SECONDS
	if power and not power.on:
		all_off()
		return
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		# Not the real cleaner, and nothing in disguise: that would give it away.
		if monster == null or monster.is_queued_for_deletion() or monster.harmless or monster.disguised() \
				or monster.state == "hidden":
			continue
		for i in _sets.size():
			if not _on[i] and randf() < MONSTER_CHANCE \
					and monster.global_position.distance_to((_sets[i]["body"] as Node3D).global_position) < MONSTER_REACH:
				_set_on.rpc(i, true)


## Host: a power cut (seen within a few seconds), or the end of the night, switches every set off.
func all_off() -> void:
	for i in _sets.size():
		if _on[i]:
			_set_on.rpc(i, false)


## Host: brings a player who just joined up to date.
func send_state_to(peer_id: int) -> void:
	for i in _sets.size():
		if _on[i]:
			_set_on.rpc_id(peer_id, i, true)
