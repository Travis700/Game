class_name Dread
extends Node
## Makes monsters felt, on each computer: a heartbeat that quickens as something gets close,
## a low drone while something nearby is hunting, flashlights that flicker when a monster is
## near (everyone's, as seen on this computer), and the jumpscare when you're caught.

## Monster states that mean "it's coming for someone".
const CHASE_STATES: Array[String] = ["chase", "hunt", "detention", "reveal", "charge", "moving", "follow",
	"crawl", "step1", "step2", "step3", "step4"]
const HEARTBEAT_RANGE := 16.0
const DRONE_RANGE := 22.0
const FLICKER_RANGE := 9.0

var director: MonsterDirector
var players: Node3D
## The local guard. Set by Main.
var local_guard: Guard
var hud: CanvasLayer

var _heart: AudioStreamPlayer
var _drone: AudioStreamPlayer
var _beat_left := 0.0
var _scaring := false


func _ready() -> void:
	_heart = AudioStreamPlayer.new()
	_heart.stream = Sfx.thud(0.55, 0.16, 0.9)
	add_child(_heart)
	_drone = AudioStreamPlayer.new()
	_drone.stream = _make_drone()
	_drone.volume_db = -80.0
	add_child(_drone)


func _process(delta: float) -> void:
	_flicker_flashlights()
	if local_guard == null or not is_instance_valid(local_guard) or local_guard.is_dead or director == null:
		_fade_out(delta)
		return
	var nearest := INF
	var hunting := INF
	for node in director.get_node("Live").get_children():
		var monster := node as Monster
		if monster == null or monster.harmless or monster.state == "hidden":
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
		if monster and not monster.harmless and monster.state != "hidden":
			monsters.append(monster)
	for guard: Guard in players.get_children():
		if not guard.flashlight.visible:
			continue
		var base: float = guard.flashlight.get_meta("base_energy", 1.0) * (1.5 if guard.bright_flashlight else 1.0)
		var near := false
		for monster in monsters:
			if monster.global_position.distance_to(guard.global_position) < FLICKER_RANGE:
				near = true
				break
		guard.flashlight.light_energy = base * (0.05 if randf() < 0.35 else randf_range(0.4, 1.0)) if near else base


## The local guard was caught: the camera snaps to whatever caught them, with a scream.
func jumpscare(from: Vector3) -> void:
	if local_guard == null or _scaring:
		return
	_scaring = true
	var camera := local_guard.camera
	local_guard.input_blocked = true
	if from != Vector3.INF:
		var look := from + Vector3(0, 1.55, 0)
		if camera.global_position.distance_to(look) > 0.3:
			camera.look_at(look, Vector3.UP)
	var start_fov := camera.fov
	Sfx.play_flat(self, _make_scream(), 4.0)
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
