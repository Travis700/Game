class_name Dread
extends Node
## Makes monsters felt, on each computer: a heartbeat that quickens as something gets close,
## a low drone while something nearby is hunting, flashlights and ceiling lights that flicker
## when a monster is near (as seen on this computer), and the jumpscare when you're caught.
##
## And on a player's first night, once: the first time they walk the main hallway after a few
## minutes, a tall figure is standing at the far end, the lights stutter, and it's gone. It
## can't hurt anyone; it's there so the first night has its moment.

## Monster states that mean "it's coming for someone".
const CHASE_STATES: Array[String] = ["chase", "hunt", "detention", "reveal", "charge", "moving", "follow",
	"crawl", "step1", "step2", "step3", "step4", "rush", "charging", "hunt"]
const HEARTBEAT_RANGE := 16.0
const DRONE_RANGE := 22.0
const FLICKER_RANGE := 9.0
## Ceiling lights this close to a monster stutter.
const LAMP_FLICKER_RANGE := 6.0

var director: MonsterDirector
var players: Node3D
## The local guard. Set by Main.
var local_guard: Guard
var hud: CanvasLayer
var night: Night
var career: Career
var shift: Shift
var school: SchoolBuilder
var lighting: ShiftLighting
## Ceiling lights stuttering near a monster right now, and their steady brightness.
var _stuttering: Dictionary = {}

var _heart: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _beat_left := 0.0
var _scaring := false
## The first-night glimpse: done for this night, and the figure while it's showing.
var _glimpsed := false
## The EMF reader's current level (0-5) and time to its next beep.
var emf_level := 0
var _emf_beep := 0.0
var _figure: Node3D


func _ready() -> void:
	_heart = AudioStreamPlayer.new()
	_heart.stream = Sfx.thud(0.55, 0.16, 0.9)
	add_child(_heart)
	_drone = AudioStreamPlayer.new()
	_drone.stream = SoundBank.get_sound("chase", _make_drone(), true)
	_drone.volume_db = -80.0
	add_child(_drone)


func _process(delta: float) -> void:
	_flicker_flashlights()
	_flicker_lamps()
	_first_night_glimpse()
	_read_emf(delta)
	if local_guard == null or not is_instance_valid(local_guard) or local_guard.is_dead or director == null:
		_fade_out(delta)
		return
	var nearest := INF
	var hunting := INF
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		if monster == null or monster.harmless or monster.state == "hidden" or monster.disguised():
			continue
		var distance := monster.global_position.distance_to(local_guard.global_position)
		nearest = minf(nearest, distance)
		# The Understudy's states carry the slot of the guard it's after ("follow2", "step2").
		if monster.state in CHASE_STATES or monster.state.trim_suffix(monster.state.right(1)) in CHASE_STATES:
			hunting = minf(hunting, distance)
	# Heartbeat: from one a second, far off, to racing when it's on top of you.
	if nearest < HEARTBEAT_RANGE:
		var closeness := 1.0 - nearest / HEARTBEAT_RANGE
		_beat_left -= delta
		if _beat_left <= 0.0:
			_beat_left = lerpf(1.0, 0.33, closeness)
			_heart.volume_db = lerpf(-22.0, 2.0, closeness)
			_heart.play()
	# Drone: rises while something nearby is on the hunt.
	var target_db := -80.0
	if hunting < DRONE_RANGE:
		target_db = lerpf(-24.0, -4.0, 1.0 - hunting / DRONE_RANGE)
		if not _drone.playing:
			_drone.play()
	_drone.volume_db = move_toward(_drone.volume_db, target_db, delta * 30.0)
	if _drone.volume_db <= -79.0 and _drone.playing:
		_drone.stop()


func _fade_out(delta: float) -> void:
	_drone.volume_db = move_toward(_drone.volume_db, -80.0, delta * 30.0)
	if _drone.volume_db <= -79.0 and _drone.playing:
		_drone.stop()


## Flashlights stutter when a monster is close to whoever's holding them.
func _flicker_flashlights() -> void:
	if director == null or players == null:
		return
	var monsters: Array[Node3D] = []
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		if monster and not monster.harmless and monster.state != "hidden" and not monster.disguised():
			monsters.append(monster)
	for guard: Guard in players.get_children():
		if not guard.flashlight.visible:
			continue
		var base := guard.flashlight_energy()
		var near := false
		for monster in monsters:
			if monster.global_position.distance_to(guard.global_position) < FLICKER_RANGE:
				near = true
				break
		guard.flashlight.light_energy = base * (0.05 if randf() < 0.35 else randf_range(0.4, 1.0)) if near else base


## Ceiling lights near a monster stutter too (not the ones already failing on their own). Only
## once the night's lights have settled, so nothing else is setting their brightness.
func _flicker_lamps() -> void:
	var near: Dictionary = {}
	if director != null and lighting != null and lighting.is_dark():
		var monsters: Array[Node3D] = []
		for node in director.get_node("Live").get_children():
			var monster := node as Monster
			if monster and not monster.harmless and monster.state != "hidden" and not monster.disguised():
				monsters.append(monster)
		if not monsters.is_empty():
			for node in get_tree().get_nodes_in_group(ShiftLighting.SCHOOL_LIGHTS):
				var lamp := node as Light3D
				if lamp == null or not lamp.visible or lamp is FlickerLight:
					continue
				for monster in monsters:
					if monster.global_position.distance_to(lamp.global_position) < LAMP_FLICKER_RANGE:
						near[lamp] = true
						break
	for lamp: Light3D in _stuttering.keys():
		if not near.has(lamp) or not is_instance_valid(lamp):
			if is_instance_valid(lamp):
				lamp.light_energy = _stuttering[lamp]
			_stuttering.erase(lamp)
	for lamp: Light3D in near:
		if not _stuttering.has(lamp):
			_stuttering[lamp] = lamp.light_energy
		lamp.light_energy = _stuttering[lamp] * (0.04 if randf() < 0.3 else randf_range(0.6, 1.0))


## The local guard was caught: the camera snaps to whatever caught them, with a scream.
## The local guard's EMF reader: lights climb as monsters get close. Ordinary monsters top out
## at 4 (harmless ones, like the night cleaner, at 3); EMF 5 is evidence of certain kinds.
func _read_emf(delta: float) -> void:
	var on := local_guard != null and is_instance_valid(local_guard) and local_guard.has_emf \
			and not local_guard.is_dead and shift != null and shift.state == Shift.State.ON_SHIFT
	if not on:
		emf_level = 0
		if hud:
			hud.set_emf(-1)
		return
	var level := 0
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		if monster == null or monster.state == "hidden":
			continue
		var distance := monster.global_position.distance_to(local_guard.global_position)
		var reading := 0
		if distance < 20.0:
			reading = 1
		if distance < 13.0:
			reading = 2
		if distance < 8.0:
			reading = 3
		if distance < 4.0:
			reading = 4
		reading = mini(reading, 3 if monster.harmless else 4)
		if monster.emf5 and distance < 6.0:
			reading = 5
		level = maxi(level, reading)
	if level == 5 and emf_level != 5 and career:
		career._unlock("EMF_FIVE")
	emf_level = level
	if hud:
		hud.set_emf(level)
	_emf_beep -= delta
	if level > 0 and _emf_beep <= 0.0:
		_emf_beep = 1.3 - level * 0.22
		Sfx.play_flat(self, Sfx.notes([600.0 + level * 180.0], 0.05, 0.12, "square"), -12.0)


## Night 1, a few minutes in, the first time this player looks down the main hallway.
func _first_night_glimpse() -> void:
	if night == null or shift == null:
		return
	if shift.state != Shift.State.ON_SHIFT:
		_glimpsed = false
		return
	if _glimpsed or night.number != 1 or night.minutes < 15.0 or night.daily != "":
		return
	if local_guard == null or not is_instance_valid(local_guard) or local_guard.is_dead or local_guard.seated_desk >= 0:
		return
	var at := local_guard.global_position
	if at.z < 4.5 or at.z > 9.5 or absf(at.x) > 36.0:
		return
	var facing := -local_guard.camera.global_basis.z
	if absf(facing.x) < 0.85:
		return
	var end := clampf(at.x + signf(facing.x) * 22.0, -38.5, 38.5)
	if absf(end - at.x) < 12.0:
		return
	_glimpsed = true
	_show_figure(Vector3(end, 0.0, 7.0), at)


func _show_figure(spot: Vector3, viewer: Vector3) -> void:
	_figure = Node3D.new()
	add_child(_figure)
	_figure.global_position = spot
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.025)
	dark.roughness = 1.0
	for part: Array in [[Vector3(0.5, 2.3, 0.3), Vector3(0, 1.15, 0)], [Vector3(0.3, 0.32, 0.3), Vector3(0, 2.46, 0)],
			[Vector3(0.12, 1.3, 0.12), Vector3(-0.33, 1.4, 0)], [Vector3(0.12, 1.3, 0.12), Vector3(0.33, 1.4, 0)]]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = Monster.box(part[0])
		mesh.position = part[1]
		mesh.material_override = dark
		_figure.add_child(mesh)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		eye.mesh = Monster.box(Vector3(0.05, 0.03, 0.02))
		eye.position = Vector3(side * 0.07, 2.5, 0.16)
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(1.0, 0.9, 0.8)
		glow.emission_enabled = true
		glow.emission = Color(1.0, 0.9, 0.8)
		glow.emission_energy_multiplier = 4.0
		eye.material_override = glow
		_figure.add_child(eye)
	_figure.look_at(Vector3(viewer.x, 0.0, viewer.z), Vector3.UP, true)
	SoundBank.play_flat(self, "stinger", -6.0, Sfx.notes([62.0, 58.0, 55.0], 0.45, 0.5, "saw"))
	# The lights near it stutter, and when they come back it's gone.
	var lights: Array[Light3D] = []
	for node in get_tree().get_nodes_in_group(ShiftLighting.SCHOOL_LIGHTS):
		var light := node as Light3D
		if light and light.visible and light.global_position.distance_to(spot) < 14.0:
			lights.append(light)
	var sequence := create_tween()
	sequence.tween_interval(1.6)
	for i in 3:
		sequence.tween_callback(func() -> void:
			for light in lights:
				light.visible = false)
		sequence.tween_interval(0.08)
		sequence.tween_callback(func() -> void:
			for light in lights:
				light.visible = true)
		sequence.tween_interval(0.12)
	sequence.tween_callback(func() -> void:
		for light in lights:
			light.visible = false
		_figure.queue_free())
	sequence.tween_interval(0.5)
	sequence.tween_callback(func() -> void:
		for light in lights:
			light.visible = true)


func jumpscare(from: Vector3) -> void:
	if local_guard == null or _scaring:
		return
	_scaring = true
	var camera := local_guard.camera
	local_guard.input_blocked = true
	if from != Vector3.INF:
		# `from` is the face of whatever caught you.
		var look := from
		if camera.global_position.distance_to(look) > 0.3:
			camera.look_at(look, Vector3.UP)
	var start_fov := camera.fov
	SoundBank.play_flat(self, "scream", 2.0, _make_scream())
	var shake := create_tween()
	for i in 10:
		shake.tween_property(camera, "h_offset", randf_range(-0.06, 0.06), 0.04)
		shake.parallel().tween_property(camera, "v_offset", randf_range(-0.05, 0.05), 0.04)
	shake.tween_property(camera, "h_offset", 0.0, 0.05)
	shake.parallel().tween_property(camera, "v_offset", 0.0, 0.05)
	var zoom := create_tween()
	zoom.tween_property(camera, "fov", 38.0, 0.15)
	zoom.tween_interval(0.9)
	zoom.tween_property(camera, "fov", start_fov, 0.3)
	zoom.tween_callback(func() -> void:
		camera.rotation = Vector3.ZERO
		# (Not if the night report came up meanwhile: that keeps the controls.)
		if night == null or night.shift.state != Shift.State.REPORT:
			local_guard.input_blocked = false
		_scaring = false)


func _make_drone() -> AudioStreamWAV:
	# Two low saws slightly out of tune with each other, beating slowly.
	var seconds := 4.0
	var count := int(seconds * Sfx.RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var t := float(n) / Sfx.RATE
		var a := fmod(t * 55.0, 1.0) * 2.0 - 1.0
		var b := fmod(t * 55.5, 1.0) * 2.0 - 1.0
		var c := sin(TAU * 27.5 * t)
		var value := (a * 0.3 + b * 0.3 + c * 0.4) * 0.35
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = Sfx.RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


func _make_scream() -> AudioStreamWAV:
	# A harsh, falling shriek over a burst of noise.
	var seconds := 1.1
	var count := int(seconds * Sfx.RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for n in count:
		var t := float(n) / count
		phase += TAU * lerpf(1400.0, 300.0, t) * (1.0 + 0.08 * sin(n * 0.02)) / Sfx.RATE
		var shriek := (fmod(phase / TAU, 1.0) * 2.0 - 1.0)
		var noise := randf_range(-1.0, 1.0)
		var envelope := minf(t * 30.0, 1.0) * (1.0 - t)
		var value := (shriek * 0.6 + noise * 0.4) * envelope
		data.encode_s16(n * 2, int(clampf(value, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = Sfx.RATE
	wav.data = data
	return wav
