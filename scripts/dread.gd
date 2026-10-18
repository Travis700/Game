class_name Dread
extends Node
## Makes monsters felt, on each computer: a heartbeat that quickens as something gets close,
## a low drone while something nearby is hunting, flashlights and ceiling lights that flicker
## when a monster is near (as seen on this computer), and the jumpscare when you're caught.
## A walkie-talkie crackles with something close, a ghost standing by a guard makes their
## flashlight stutter, and when a teammate is caught everyone nearby hears it.
##
## And on a player's first night, once: the first time they walk the main hallway after a few
## minutes, a tall figure is standing at the far end, the lights stutter, and it's gone. It
## can't hurt anyone; it's there so the first night has its moment.

## Monster states that mean "it's coming for someone" (a chase, or about to be one): the drone
## means this and nothing else. (The Understudy's "step2" counts as "step".)
const CHASE_STATES: Array[String] = ["chase", "hunt", "detention", "reveal", "charge", "step", "rush", "charging"]
## States where it's up and about, near you, but not coming for anyone yet (following, creeping,
## moving while unwatched): the heartbeat picks up a little sooner, but no drone.
## (And "seek"/"search": walking up to a cupboard someone's hiding in, and rattling its doors.)
const PRESENCE_STATES: Array[String] = ["moving", "follow", "crawl", "lead", "whistle", "stop", "register", "shush", "seek", "search"]
const HEARTBEAT_RANGE := 16.0
const DRONE_RANGE := 22.0
const FLICKER_RANGE := 9.0
## Ceiling lights this close to a monster stutter.
const LAMP_FLICKER_RANGE := 6.0
## How far round the local guard the lights stutter in a lockdown.
const LOCKDOWN_FLICKER_RANGE := 24.0
## A monster this close makes the local guard's walkie-talkie crackle.
const RADIO_INTERFERENCE_RANGE := 12.0
## A ghost (a caught guard) this close to a living guard makes their flashlight stutter.
const GHOST_FLICKER_RANGE := 5.0
## How far a teammate's scream carries when they're caught.
const SCREAM_REACH := 60.0

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
## A lockdown is on (set by Main on every computer): the lights round the guard stutter too.
var lockdown := false

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
## Real seconds to the walkie-talkie's next crackle.
var _crackle_left := 0.0


## True when the player has asked for less flashing (Profile.reduce_flashing): flickers stay
## gentle, and the jumpscare doesn't shake or punch the view so hard. (Looked up by path: this
## can compile before the autoloads exist.)
func _gentle() -> bool:
	var profile := get_node_or_null("/root/Profile")
	return profile != null and profile.get("reduce_flashing") == true


## Is this monster state a chase (see CHASE_STATES)? Also used by the doors and the lockdown.
static func is_chasing(state: String) -> bool:
	return state.rstrip("0123456789") in CHASE_STATES


func _ready() -> void:
	_heart = AudioStreamPlayer.new()
	_heart.bus = &"SFX"
	_heart.stream = Sfx.thud(0.55, 0.16, 0.9)
	add_child(_heart)
	_drone = AudioStreamPlayer.new()
	_drone.bus = &"Music"
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
	var radio_near := INF
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		if monster == null or monster.harmless or monster.state == "hidden" or monster.disguised():
			continue
		var distance := monster.global_position.distance_to(local_guard.global_position)
		radio_near = minf(radio_near, distance)
		# Up and about counts as a little closer, for the heartbeat.
		nearest = minf(nearest, distance * (0.75 if monster.state.rstrip("0123456789") in PRESENCE_STATES else 1.0))
		if is_chasing(monster.state):
			hunting = minf(hunting, distance)
	_radio_interference(radio_near, delta)
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


## Flashlights stutter when a monster is close to whoever's holding them, or a ghost (a caught
## teammate) is standing right by them.
func _flicker_flashlights() -> void:
	if director == null or players == null:
		return
	var monsters: Array[Node3D] = []
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		if monster and not monster.harmless and monster.state != "hidden" and not monster.disguised():
			monsters.append(monster)
	var ghosts: Array[Guard] = []
	for guard: Guard in players.get_children():
		if guard.is_dead:
			ghosts.append(guard)
	var gentle := _gentle()
	for guard: Guard in players.get_children():
		if not guard.flashlight.visible or guard.is_dead:
			continue
		var base := guard.flashlight_energy()
		var near := false
		for monster in monsters:
			if monster.global_position.distance_to(guard.global_position) < FLICKER_RANGE:
				near = true
				break
		if not near:
			for ghost in ghosts:
				if ghost.global_position.distance_to(guard.global_position) < GHOST_FLICKER_RANGE:
					near = true
					break
		if not near:
			guard.flashlight.light_energy = base
		elif gentle:
			guard.flashlight.light_energy = base * randf_range(0.75, 1.0)
		else:
			guard.flashlight.light_energy = base * (0.05 if randf() < 0.35 else randf_range(0.4, 1.0))


## Ceiling lights near a monster stutter too, and in a lockdown the ones round you (not the ones
## already failing on their own). Only once the night's lights have settled, so nothing else is
## setting their brightness.
func _flicker_lamps() -> void:
	# Each stuttering lamp, and how often it drops out (near a monster: often).
	var near: Dictionary = {}
	if director != null and lighting != null and lighting.is_dark():
		var monsters: Array[Node3D] = []
		for node in director.get_node("Live").get_children():
			var monster := node as Monster
			if monster and not monster.harmless and monster.state != "hidden" and not monster.disguised():
				monsters.append(monster)
		var me := local_guard.global_position if local_guard and is_instance_valid(local_guard) else Vector3.INF
		if not monsters.is_empty() or (lockdown and me != Vector3.INF):
			for node in get_tree().get_nodes_in_group(ShiftLighting.SCHOOL_LIGHTS):
				var lamp := node as Light3D
				if lamp == null or not lamp.visible or lamp is FlickerLight:
					continue
				for monster in monsters:
					if monster.global_position.distance_to(lamp.global_position) < LAMP_FLICKER_RANGE:
						near[lamp] = 0.3
						break
				if not near.has(lamp) and lockdown and me.distance_to(lamp.global_position) < LOCKDOWN_FLICKER_RANGE:
					near[lamp] = 0.1
	for lamp: Light3D in _stuttering.keys():
		if not near.has(lamp) or not is_instance_valid(lamp):
			if is_instance_valid(lamp):
				lamp.light_energy = _stuttering[lamp]
			_stuttering.erase(lamp)
	var gentle := _gentle()
	for lamp: Light3D in near:
		if not _stuttering.has(lamp):
			_stuttering[lamp] = lamp.light_energy
		if gentle:
			lamp.light_energy = _stuttering[lamp] * randf_range(0.8, 1.0)
		else:
			lamp.light_energy = _stuttering[lamp] * (0.04 if randf() < near[lamp] else randf_range(0.6, 1.0))


## The local guard's walkie-talkie crackles while a monster is close: more often the closer it is.
func _radio_interference(distance: float, delta: float) -> void:
	if not local_guard.has_radio or distance >= RADIO_INTERFERENCE_RANGE:
		_crackle_left = minf(_crackle_left, 0.4)
		return
	_crackle_left -= delta
	if _crackle_left > 0.0:
		return
	var closeness := 1.0 - distance / RADIO_INTERFERENCE_RANGE
	_crackle_left = lerpf(3.0, 0.5, closeness) * randf_range(0.7, 1.3)
	if randf() < 0.5:
		_radio_sound(SoundBank.get_sound("squelch", Sfx.notes([1.0, 1.0], 0.06, 0.25, "noise")), lerpf(-16.0, -6.0, closeness), randf_range(0.8, 1.3))
	else:
		# A few broken blips.
		var blips := create_tween()
		for i in randi_range(2, 4):
			blips.tween_callback(func() -> void:
				_radio_sound(SoundBank.get_sound("glitch", Sfx.notes([1.0], 0.03, 0.3, "noise")), lerpf(-14.0, -4.0, closeness), randf_range(0.7, 1.4)))
			blips.tween_interval(randf_range(0.04, 0.12))


## Plays a sound out of the local guard's walkie-talkie (the thin, crackly "Radio" bus).
func _radio_sound(stream: AudioStream, volume_db: float, pitch := 1.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	if AudioServer.get_bus_index("Radio") >= 0:
		player.bus = "Radio"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## Every computer but the caught guard's own: a teammate was caught at `at`. Their scream comes
## from where they fell, and a walkie-talkie bursts with static.
func witness_catch(at: Vector3) -> void:
	var spot := Node3D.new()
	add_child(spot)
	spot.global_position = at + Vector3(0, 1.5, 0)
	SoundBank.play_at(spot, "scream", 4.0, SCREAM_REACH, _make_scream())
	get_tree().create_timer(3.0).timeout.connect(spot.queue_free)
	get_tree().call_group("captions", "heard", "Guard", "caught", at)
	if local_guard != null and is_instance_valid(local_guard) and not local_guard.is_dead and local_guard.has_radio:
		_radio_sound(SoundBank.get_sound("squelch", Sfx.notes([1.0, 1.0], 0.06, 0.25, "noise")), -2.0, 0.8)
		_radio_sound(Sfx.notes([1.0, 1.0, 1.0, 1.0], 0.25, 0.3, "noise"), -8.0)
		get_tree().call_group("captions", "heard", "Radio", "burst", local_guard.global_position)


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
	for i in (0 if _gentle() else 3):
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


## The local guard was caught: the camera snaps to whatever caught them, with a scream.
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
	# Less flashing asked for: a small nudge rather than a shake, and a gentler zoom.
	var strength := 0.25 if _gentle() else 1.0
	SoundBank.play_flat(self, "scream", 2.0, _make_scream())
	var shake := create_tween()
	for i in 10:
		shake.tween_property(camera, "h_offset", randf_range(-0.06, 0.06) * strength, 0.04)
		shake.parallel().tween_property(camera, "v_offset", randf_range(-0.05, 0.05) * strength, 0.04)
	shake.tween_property(camera, "h_offset", 0.0, 0.05)
	shake.parallel().tween_property(camera, "v_offset", 0.0, 0.05)
	var zoom := create_tween()
	zoom.tween_property(camera, "fov", lerpf(start_fov, 38.0, strength), 0.15)
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
