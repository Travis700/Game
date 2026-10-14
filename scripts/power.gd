class_name Power
extends Node3D
## Power cuts. From night 2 the school's power goes out now and then: every ceiling light dies,
## the cameras show NO POWER, the vending machine goes dark and only the red emergency lights
## are left. It stays out until someone walks to the custodian's closet and holds E on the
## breaker panel, which pays them like a correct log.
##
## The host decides when the power goes; every computer shows it.

signal breaker_reset(peer_id: int)

const BREAKER_AT := Vector3(4.8, 1.5, -4.0)
const BREAKER_HOLD := 3.0
## Earliest and latest a cut can happen, and the least time between two (in-game minutes).
const CUT_WINDOW := Vector2(45.0, 320.0)
const CUT_GAP := 50.0
## Where the red emergency lights hang.
const EMERGENCY_LIGHTS: Array[Vector3] = [
	Vector3(13.0, 3.1, 15.0), Vector3(0.0, 3.1, 15.0), Vector3(0.0, 3.1, -4.0),
	Vector3(-20.0, 3.1, 7.0), Vector3(0.0, 3.1, 7.0), Vector3(20.0, 3.1, 7.0),
	Vector3(-22.0, 3.1, -13.0), Vector3(22.0, 3.1, -13.0),
	Vector3(-60.0, 3.1, 7.0), Vector3(60.0, 3.1, 7.0),
]

var school: SchoolBuilder
var cameras: SecurityCameras
var director: MonsterDirector
var career: Career

## False while the power is out. On every computer.
var on := true

var _breaker: Interactable
var _emergency: Array[OmniLight3D] = []
## Host: tonight's cut times (in-game minutes), soonest first.
var _schedule: Array[float] = []
## Every computer: the lights this computer switched off for the cut, and whether each was flickering.
var _hidden: Array[Light3D] = []
var _flickering: Array[Light3D] = []
var _panel_glow := 1.0


func _ready() -> void:
	_breaker = Interactable.new()
	_breaker.name = "Breaker"
	_breaker.hold_seconds = BREAKER_HOLD
	add_child(_breaker)
	_breaker.position = BREAKER_AT
	_breaker.rotation.y = -PI * 0.5
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.6, 0.8, 0.2)
	shape.shape = box
	_breaker.add_child(shape)
	_part(_breaker, Vector3(0.6, 0.8, 0.12), Vector3.ZERO, Color(0.35, 0.36, 0.33))
	for row in 3:
		for col in 4:
			_part(_breaker, Vector3(0.06, 0.1, 0.04), Vector3(-0.18 + col * 0.12, 0.22 - row * 0.2, 0.07), Color(0.1, 0.1, 0.1))
	_part(_breaker, Vector3(0.2, 0.04, 0.02), Vector3(0, 0.36, 0.07), Color(0.9, 0.75, 0.1))
	_breaker.used.connect(func(by: Node) -> void:
		if by is Guard and (by as Guard).is_local():
			if multiplayer.is_server():
				_request_reset()
			else:
				_request_reset.rpc_id(1))
	for at in EMERGENCY_LIGHTS:
		var light := OmniLight3D.new()
		light.position = at
		light.light_color = Color(1.0, 0.12, 0.08)
		light.light_energy = 0.55
		light.omni_range = 9.0
		light.visible = false
		add_child(light)
		_emergency.append(light)
		_part(self, Vector3(0.25, 0.1, 0.12), at + Vector3(0, 0.3, 0), Color(0.6, 0.05, 0.05))
	_show_breaker()


# --- Host --------------------------------------------------------------------------------

## The night is starting: picks tonight's cuts. None on night 1, more as the run goes on.
func plan(night_number: int) -> void:
	_schedule.clear()
	var count := 0 if night_number < 2 else (1 if night_number < 5 else (2 if night_number < 8 else 3))
	var tries := 0
	while _schedule.size() < count and tries < 50:
		tries += 1
		var at := randf_range(CUT_WINDOW.x, CUT_WINDOW.y)
		if _schedule.all(func(other: float) -> bool: return absf(other - at) >= CUT_GAP):
			_schedule.append(at)
	_schedule.sort()


func update(minutes: float) -> void:
	if _schedule.is_empty() or minutes < _schedule[0]:
		return
	_schedule.pop_front()
	if on:
		cut()


## Host: the power goes out now.
func cut() -> void:
	if not on:
		return
	_set_power.rpc(false, true)
	for guard in director.living_guards():
		director.tell(guard.name.to_int(), "The power's gone out. The breaker panel is in the custodian's closet, across the main hallway.")


## Host: 6 AM or the end of the night. The power comes back on quietly.
func end_night() -> void:
	_schedule.clear()
	if not on:
		_set_power.rpc(true, false)


@rpc("any_peer", "call_remote", "reliable")
func _request_reset() -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	var guard := director.guard_by_peer(peer)
	if guard == null or guard.is_dead or guard.global_position.distance_to(BREAKER_AT) > 4.0:
		return
	if on:
		director.tell(peer, "Every switch is up. Nothing to do here.")
		return
	_set_power.rpc(true, true)
	breaker_reset.emit(peer)
	if career:
		career.award(peer, "LIGHTS_ON")
	for living in director.living_guards():
		var who := "You" if living == guard else "Guard %d" % guard.slot
		director.tell(living.name.to_int(), "%s reset the breaker. The power's back." % who)


# --- Every computer ------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _set_power(power_on: bool, loud: bool) -> void:
	if power_on == on:
		return
	on = power_on
	var panel_material := school.get_material("light_panel")
	if not on:
		_hidden.clear()
		_flickering.clear()
		for node in get_tree().get_nodes_in_group(ShiftLighting.SCHOOL_LIGHTS):
			var light := node as Light3D
			if light == null or not light.visible:
				continue
			if light is FlickerLight and (light as FlickerLight).flickering:
				(light as FlickerLight).stop_flickering()
				_flickering.append(light)
			light.visible = false
			_hidden.append(light)
		_panel_glow = panel_material.emission_energy_multiplier
		panel_material.emission_energy_multiplier = 0.0
		if loud:
			Sfx.play_flat(self, Sfx.notes([140.0, 110.0, 85.0, 60.0, 45.0], 0.18, 0.45, "saw"), -2.0)
	else:
		for light in _hidden:
			if is_instance_valid(light):
				light.visible = true
		for light in _flickering:
			if is_instance_valid(light):
				(light as FlickerLight).start_flickering()
		_hidden.clear()
		_flickering.clear()
		panel_material.emission_energy_multiplier = _panel_glow
		if loud:
			Sfx.play_flat(self, Sfx.thud(0.6, 0.15, 0.6), 0.0)
			Sfx.play_flat(self, Sfx.notes([55.0, 80.0, 110.0, 140.0], 0.12, 0.3, "saw"), -6.0)
	for light in _emergency:
		light.visible = not on
	cameras.set_power(on)
	_show_breaker()


func _show_breaker() -> void:
	_breaker.prompt = "Breaker panel" if on else "Reset the breaker"


func _part(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = Monster.box(size)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.7
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)
	return mesh
