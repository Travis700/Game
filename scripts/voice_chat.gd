class_name VoiceChat
extends Node
## Proximity voice chat. Each player's voice comes out of their guard, fading with distance, so
## guards who split up can't hear each other. The dead hear the living, but only other ghosts
## hear the dead.
##
## Monsters can hear it too: the host is told how loud each guard is talking (see
## MonsterDirector.voice_reach), and some monsters come for the noise.
##
## How it works: the microphone plays into a muted "Mic" bus with a capture effect. While you
## talk (push-to-talk, or an open mic over a loudness threshold), the captured sound is cut down
## to 16 kHz mono, squeezed to 8 bits per sample (mu-law) and sent to everyone in 20 ms packets.
## Each computer plays other guards' voices through a 3D player on their guard.

## Voice is sent at this sample rate.
const VOICE_RATE := 16000
## Samples per packet: 20 ms.
const PACKET_SAMPLES := 320
## Keep sending this long after an open mic drops below the threshold, so words don't get cut off.
const HANGOVER := 0.35
## How far a voice carries for other players (metres).
const HEARING_RANGE := 26.0
## Network channel for voice, so it never holds up the game's own messages.
const CHANNEL := 2
## The Understudy's lines go on their own channel: they're big, and must arrive whole.
const MIMIC_CHANNEL := 3
## The Understudy's lines: the host keeps the last few things each guard said, in memory only
## (never saved), so it can say them back. A pause this long (seconds) ends a line; lines are
## kept between these lengths (bytes: one per sample at VOICE_RATE).
const LINE_GAP := 0.5
const LINE_MIN_BYTES := 8000
const LINE_MAX_BYTES := 64000
const LINES_KEPT := 6

## The local player's guard. Set by Main.
var local_guard: Guard
var director: MonsterDirector
## For the base station: guards at a desk can talk over the radio without a walkie-talkie.
var guard_room: GuardRoom
## Set by tests: a function returning fake microphone frames (PackedVector2Array) instead of
## the real microphone.
var test_input := Callable()

## The local player's voice right now: 0 (silent) to 1 (shouting). For the HUD.
var level := 0.0
## True while the local player is being sent to everyone.
var transmitting := false
## True while that's over the walkie-talkie.
var on_radio := false
## Beyond this, a radio call is heard over the radio rather than in person.
const RADIO_OVER := 8.0
## A ghost standing this close to a living guard with a walkie-talkie breaks through on it, as
## static-wrapped bursts: a few seconds at a time, then not again for a while. Monsters never
## hear it (it's only played on that guard's computer).
const GHOST_RADIO_RANGE := 3.0
const GHOST_CLIP := 3.0
const GHOST_CLIP_EVERY := 20.0
## Peer id -> when (s) that ghost's current burst began, on this computer.
var _ghost_clip_from: Dictionary = {}

var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _outgoing := PackedFloat32Array()
var _hangover_left := 0.0
var _resample_position := 0.0
## Peer id -> AudioStreamPlayer3D playing that guard's voice on this computer.
var _voices: Dictionary = {}
## Peer id -> AudioStreamPlayer for that guard's voice coming over this guard's radio.
var _radio_voices: Dictionary = {}
var _radio_last_heard: Dictionary = {}
## Peer id -> when their last voice packet arrived (seconds), for the "talking" marker.
var _last_packet: Dictionary = {}
## A little delay before a voice starts playing, so packets arriving unevenly don't leave gaps,
## and the most that may be queued before packets are dropped (so delay can't build up).
const PRIME_FRAMES := 960
const MAX_QUEUED_FRAMES := 2400
var _active := false
## Host: peer id -> recent lines (PackedByteArray of mu-law samples), and the line being heard now.
var _lines: Dictionary = {}
var _taking: Dictionary = {}
## Host: peers who've said monsters may not copy their voice.
var _no_mimic: Dictionary = {}


func _ready() -> void:
	multiplayer.peer_disconnected.connect(_forget_speaker)
	var bus := AudioServer.get_bus_index("Mic")
	if bus < 0:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, "Mic")
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
		# The capture still hears it; you just don't hear yourself.
		AudioServer.set_bus_mute(bus, true)
	_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	# The walkie-talkie: thin and crackly.
	if AudioServer.get_bus_index("Radio") < 0:
		AudioServer.add_bus()
		var radio := AudioServer.bus_count - 1
		AudioServer.set_bus_name(radio, "Radio")
		var band := AudioEffectBandPassFilter.new()
		band.cutoff_hz = 1600.0
		band.resonance = 0.7
		AudioServer.add_bus_effect(radio, band)
		var crunch := AudioEffectDistortion.new()
		crunch.mode = AudioEffectDistortion.MODE_CLIP
		crunch.drive = 0.35
		AudioServer.add_bus_effect(radio, crunch)
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = "Mic"
	add_child(_mic_player)


## Starts or stops listening to the microphone, e.g. when a session starts, or the setting changes.
func set_active(on: bool) -> void:
	_active = on and _profile_value("voice_mode", "push") != "off"
	if on:
		send_mimic_consent()
	if _active and not _mic_player.playing and not test_input.is_valid():
		var device: String = _profile_value("mic_device", "")
		if device != "" and device in AudioServer.get_input_device_list():
			AudioServer.input_device = device
		_mic_player.play()
	elif not _active and _mic_player.playing:
		_mic_player.stop()
	if not _active:
		transmitting = false
		level = 0.0


func _process(delta: float) -> void:
	if not _active or local_guard == null or not local_guard.is_inside_tree() or multiplayer.multiplayer_peer == null:
		return
	var frames := _read_input()
	if frames.is_empty():
		return
	# How loud: the RMS of what just came in, mapped so normal speech sits around 0.3-0.6.
	var sum := 0.0
	for frame in frames:
		var mono := (frame.x + frame.y) * 0.5
		sum += mono * mono
	var rms := sqrt(sum / frames.size())
	level = clampf((rms - 0.005) / 0.12, 0.0, 1.0)

	var wants := false
	# Talking works with menus open (the night report especially), just not while typing.
	var focus := local_guard.get_viewport().gui_get_focus_owner()
	var typing := focus is LineEdit or focus is TextEdit
	match _profile_value("voice_mode", "push"):
		"push":
			wants = Input.is_action_pressed("push_to_talk") and not typing
		"open":
			var threshold: float = _profile_value("mic_threshold", 0.12)
			if level > threshold:
				_hangover_left = HANGOVER
			else:
				_hangover_left -= delta
			wants = _hangover_left > 0.0
	# The walkie-talkie: hold its key (only while alive, with one clipped on, or at a guard room
	# desk, where the base station is).
	var radio := (local_guard.has_radio or at_desk(local_guard)) and not local_guard.is_dead and not typing \
			and Input.is_action_pressed("radio_talk")
	if radio and not on_radio:
		_squelch(null)
	on_radio = radio
	wants = wants or radio
	transmitting = wants
	if not wants:
		_outgoing.clear()
		return
	_downsample_into_outgoing(frames)
	while _outgoing.size() >= PACKET_SAMPLES:
		var packet := _encode(_outgoing.slice(0, PACKET_SAMPLES))
		_outgoing = _outgoing.slice(PACKET_SAMPLES)
		_send(packet, level, on_radio)


func _read_input() -> PackedVector2Array:
	if test_input.is_valid():
		return test_input.call()
	if _capture == null or _capture.get_frames_available() == 0:
		return PackedVector2Array()
	return _capture.get_buffer(_capture.get_frames_available())


## From the mixer's rate (usually 44.1 or 48 kHz) down to 16 kHz mono, averaging as it goes.
func _downsample_into_outgoing(frames: PackedVector2Array) -> void:
	var step := AudioServer.get_mix_rate() / VOICE_RATE
	if test_input.is_valid():
		step = 1.0
	while _resample_position < frames.size():
		var start := int(_resample_position)
		var end := mini(int(_resample_position + step), frames.size())
		var total := 0.0
		for i in range(start, maxi(end, start + 1)):
			total += (frames[i].x + frames[i].y) * 0.5
		_outgoing.append(total / maxi(end - start, 1))
		_resample_position += step
	_resample_position -= frames.size()


func _send(packet: PackedByteArray, loudness: float, radio: bool) -> void:
	var me := multiplayer.get_unique_id()
	if multiplayer.is_server():
		_heard_by_host(me, loudness, radio, packet)
	_voice.rpc(packet, loudness, radio)


## Every other computer: a packet of someone's voice, maybe over the walkie-talkie.
@rpc("any_peer", "call_remote", "unreliable_ordered", CHANNEL)
func _voice(packet: PackedByteArray, loudness: float, radio: bool) -> void:
	var speaker := multiplayer.get_remote_sender_id()
	if multiplayer.is_server():
		_heard_by_host(speaker, loudness, radio, packet)
	if radio and _hears_on_radio(speaker):
		_play_radio(speaker, packet)
	else:
		_play(speaker, packet)


## Host: tells the monsters who's talking and how loudly. A radio call also comes out of
## every other living guard's radio, and monsters near them hear that too.
func _heard_by_host(speaker: int, loudness: float, radio: bool, packet: PackedByteArray) -> void:
	if director == null:
		return
	director.report_voice(speaker, loudness)
	_record(speaker, packet)
	if not radio:
		return
	var talker := director.guard_by_peer(speaker)
	# Only a living guard with a radio (or at the base station) can call over it.
	if talker == null or talker.is_dead or not (talker.has_radio or at_desk(talker)):
		return
	for guard in director.living_guards():
		# Guards close by hear the call in person, not out of their own radio. The base station
		# comes out of every guard's radio and the hallway speakers alike.
		if guard != talker and (guard.has_radio or at_desk(talker)) and guard.global_position.distance_to(talker.global_position) > RADIO_OVER:
			director.report_voice(guard.name.to_int(), loudness * 0.85)


## Does the local guard hear this speaker over the radio (rather than in person)?
## Is this guard at a guard room desk, on the base station?
func at_desk(guard: Guard) -> bool:
	return guard_room != null and guard.name.to_int() in guard_room.occupants


func _hears_on_radio(speaker: int) -> bool:
	var talker := players_guard(speaker)
	if talker == null or local_guard == null or local_guard.is_dead or talker.is_dead:
		return false
	# A walkie-talkie or the desk's base station picks up calls; so does anyone, from the base station.
	if not local_guard.has_radio and not at_desk(local_guard) and not at_desk(talker):
		return false
	return talker.global_position.distance_to(local_guard.global_position) > RADIO_OVER


func _play_radio(speaker: int, packet: PackedByteArray) -> void:
	if _muted.has(speaker):
		return
	var existing: Variant = _radio_voices.get(speaker)
	var player: AudioStreamPlayer = existing if is_instance_valid(existing) else null
	if player == null:
		player = AudioStreamPlayer.new()
		player.stream = _make_generator()
		player.bus = "Radio"
		add_child(player)
		player.play()
		_radio_voices[speaker] = player
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_radio_last_heard.get(speaker, 0.0)) > 0.5:
		# The click at the start of a call.
		_squelch(player)
	_radio_last_heard[speaker] = now
	player.volume_db = linear_to_db(maxf(float(_profile_value("voice_volume", 1.0)), 0.0001)) + 2.0
	_push(player, speaker, packet)


## The radio's click and hiss, when you key up (`from` null) or a call comes in.
func _squelch(_from: Node) -> void:
	var click := AudioStreamPlayer.new()
	click.stream = SoundBank.get_sound("squelch", Sfx.notes([1.0, 1.0], 0.06, 0.25, "noise"))
	click.bus = "Radio"
	click.volume_db = -6.0
	add_child(click)
	click.play()
	click.finished.connect(click.queue_free)


## Players this player has muted (just on this computer).
var _muted: Dictionary = {}
## Speaker -> whether a wall's between us (checked a few times a second), and when last checked.
var _behind_wall: Dictionary = {}
var _wall_checked: Dictionary = {}
## Voices through a wall: duller (frequencies above this cut) and quieter.
const MUFFLED_CUTOFF := 900.0
const MUFFLED_DB := -7.0


func is_muted(peer_id: int) -> bool:
	return _muted.has(peer_id)


func set_muted(peer_id: int, on: bool) -> void:
	if on:
		_muted[peer_id] = true
	else:
		_muted.erase(peer_id)


## Is there a wall between this player and that guard? (Remembered for a quarter second.)
func _walled_off(speaker: int, guard: Guard) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_wall_checked.get(speaker, -1000)) < 250:
		return bool(_behind_wall.get(speaker, false))
	_wall_checked[speaker] = now
	var eye := local_guard.camera.global_position
	var query := PhysicsRayQueryParameters3D.create(eye, guard.global_position + Vector3(0, 1.6, 0), 1)
	query.exclude = [local_guard.get_rid(), guard.get_rid()]
	var blocked := not local_guard.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
	_behind_wall[speaker] = blocked
	return blocked


func _play(speaker: int, packet: PackedByteArray) -> void:
	var guard := players_guard(speaker)
	if guard == null or local_guard == null or _muted.has(speaker):
		return
	# Ghosts hear everyone; the living only hear the living (bar a ghost on their radio).
	if guard.is_dead and not local_guard.is_dead:
		if _ghost_breaks_through(speaker, guard):
			_play_radio(speaker, packet)
		return
	# Untyped first: the player may have been freed along with a guard who left.
	var existing: Variant = _voices.get(speaker)
	var player: AudioStreamPlayer3D = existing if is_instance_valid(existing) else null
	if player == null or player.get_parent() != guard:
		player = AudioStreamPlayer3D.new()
		player.stream = _make_generator()
		player.max_distance = HEARING_RANGE
		player.unit_size = 4.0
		player.position = Vector3(0, 1.6, 0)
		guard.add_child(player)
		player.play()
		_voices[speaker] = player
	var volume := linear_to_db(maxf(float(_profile_value("voice_volume", 1.0)), 0.0001))
	if guard.is_dead and local_guard.is_dead:
		# Two ghosts: heard anywhere, as if right beside you.
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		player.attenuation_filter_cutoff_hz = 20500.0
		player.max_distance = 0.0
	else:
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.max_distance = HEARING_RANGE
		var walled := _walled_off(speaker, guard)
		player.attenuation_filter_cutoff_hz = MUFFLED_CUTOFF if walled else 5000.0
		if walled:
			volume += MUFFLED_DB
	player.volume_db = volume
	_push(player, speaker, packet)


## Does this ghost's voice come through the local guard's walkie-talkie right now?
func _ghost_breaks_through(speaker: int, ghost: Guard) -> bool:
	if not local_guard.has_radio or ghost.global_position.distance_to(local_guard.global_position) > GHOST_RADIO_RANGE:
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var from := float(_ghost_clip_from.get(speaker, -INF))
	if now - from < GHOST_CLIP:
		return true
	if now - from >= GHOST_CLIP_EVERY:
		_ghost_clip_from[speaker] = now
		_squelch(null)
		var hud := get_tree().get_first_node_in_group("captions") as Captions
		if hud:
			hud.heard("Radio", "ghost", ghost.global_position)
		return true
	return false


func _make_generator() -> AudioStreamGenerator:
	var stream := AudioStreamGenerator.new()
	# Godot 4.4+ only uses mix_rate when told the rate is custom.
	if "mix_rate_mode" in stream:
		stream.set("mix_rate_mode", 2)
	stream.mix_rate = VOICE_RATE
	stream.buffer_length = 0.4
	return stream


## Queues a packet on a voice player: after a pause it first queues a moment of silence
## (smoothing out uneven packets), and it drops packets if too much is waiting (so the delay
## can't build up).
func _push(player: Node, speaker: int, packet: PackedByteArray) -> void:
	var playback := player.call("get_stream_playback") as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var free := playback.get_frames_available()
	# The buffer's real size (Godot rounds it up), learned from how much is free when empty.
	var capacity := maxi(int(player.get_meta("capacity", 0)), free)
	player.set_meta("capacity", capacity)
	var queued := capacity - free
	var samples := _decode(packet)
	if now - float(_last_packet.get(speaker, 0.0)) > 0.3 and queued == 0:
		for i in mini(PRIME_FRAMES, free):
			playback.push_frame(Vector2.ZERO)
		free = playback.get_frames_available()
	_last_packet[speaker] = now
	if queued > MAX_QUEUED_FRAMES or free < samples.size():
		return
	for sample in samples:
		playback.push_frame(Vector2(sample, sample))


# --- The Understudy's lines ----------------------------------------------------------------

## Host: adds a packet to what this guard is saying now.
func _record(speaker: int, packet: PackedByteArray) -> void:
	if _no_mimic.has(speaker):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var take: Dictionary = _taking.get(speaker, {})
	if take.is_empty() or now - float(take["last"]) > LINE_GAP or (take["data"] as PackedByteArray).size() >= LINE_MAX_BYTES:
		_finish_line(speaker)
		take = {"data": PackedByteArray(), "last": now}
		_taking[speaker] = take
	var data: PackedByteArray = take["data"]
	data.append_array(packet)
	take["data"] = data
	take["last"] = now


func _finish_line(speaker: int) -> void:
	var take: Dictionary = _taking.get(speaker, {})
	_taking.erase(speaker)
	if take.is_empty() or (take["data"] as PackedByteArray).size() < LINE_MIN_BYTES:
		return
	var kept: Array = _lines.get_or_add(speaker, [])
	kept.append(take["data"])
	if kept.size() > LINES_KEPT:
		kept.pop_front()


## Host: something this guard said a while ago, or an empty array if there's nothing yet.
func line_of(peer_id: int) -> PackedByteArray:
	var take: Dictionary = _taking.get(peer_id, {})
	if not take.is_empty() and Time.get_ticks_msec() / 1000.0 - float(take["last"]) > LINE_GAP:
		_finish_line(peer_id)
	var kept: Array = _lines.get(peer_id, [])
	return kept.pick_random() if not kept.is_empty() else PackedByteArray()


## Host: has this guard said anything it could copy?
func has_lines(peer_id: int) -> bool:
	return not line_of(peer_id).is_empty()


## Host: `at` says something `peer_id` said, in their voice, for everyone nearby to hear.
func mimic(at: Node3D, peer_id: int) -> bool:
	var line := line_of(peer_id)
	if line.is_empty():
		return false
	_mimic.rpc(at.get_path(), line)
	return true


@rpc("authority", "call_local", "reliable", MIMIC_CHANNEL)
func _mimic(path: NodePath, line: PackedByteArray) -> void:
	var speaker := get_node_or_null(path) as Node3D
	if speaker == null:
		return
	_play_line(speaker, line)


## Host: something a guard said earlier comes from an empty spot, once, with nothing there.
func echo_at(at: Vector3, peer_id: int) -> bool:
	var line := line_of(peer_id)
	if line.is_empty():
		return false
	_echo.rpc(at, line)
	return true


@rpc("authority", "call_local", "reliable", MIMIC_CHANNEL)
func _echo(at: Vector3, line: PackedByteArray) -> void:
	var spot := Node3D.new()
	get_tree().root.add_child(spot)
	spot.global_position = at
	_play_line(spot, line)
	get_tree().create_timer(15.0).timeout.connect(spot.queue_free)
	var captions := get_tree().get_first_node_in_group("captions") as Captions
	if captions:
		captions.heard("Echo", "voice", at)


func _play_line(speaker: Node3D, line: PackedByteArray) -> void:
	var samples := _decode(line)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = VOICE_RATE
	wav.data = data
	var player := Sfx.play_at(speaker, wav, linear_to_db(maxf(float(_profile_value("voice_volume", 1.0)), 0.0001)), HEARING_RANGE)
	if player:
		player.position = Vector3(0, 1.6, 0)
		player.unit_size = 4.0
		# Not quite right.
		player.pitch_scale = 0.94


## Tells the host whether monsters may copy this player's voice (the Esc menu setting).
func send_mimic_consent() -> void:
	if multiplayer.multiplayer_peer == null:
		return
	var allowed: bool = _profile_value("voice_mimic", true)
	if multiplayer.is_server():
		_mimic_consent(allowed)
	else:
		_mimic_consent.rpc_id(1, allowed)


@rpc("any_peer", "call_remote", "reliable")
func _mimic_consent(allowed: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	if peer == 0:
		peer = multiplayer.get_unique_id()
	if allowed:
		_no_mimic.erase(peer)
	else:
		_no_mimic[peer] = true
		_lines.erase(peer)
		_taking.erase(peer)


## A player left: their voice players go too.
func _forget_speaker(peer_id: int) -> void:
	for table: Dictionary in [_voices, _radio_voices]:
		var existing: Variant = table.get(peer_id)
		if is_instance_valid(existing):
			(existing as Node).queue_free()
		table.erase(peer_id)
	_radio_last_heard.erase(peer_id)
	_last_packet.erase(peer_id)
	_lines.erase(peer_id)
	_taking.erase(peer_id)
	_no_mimic.erase(peer_id)


func players_guard(peer_id: int) -> Guard:
	return director.guard_by_peer(peer_id) if director else null


## Is this player talking right now (for the "talking" marker over teammates)? Every computer.
func is_talking(peer_id: int) -> bool:
	return Time.get_ticks_msec() / 1000.0 - float(_last_packet.get(peer_id, -10.0)) < 0.25


# --- mu-law: 8 bits a sample, plenty for speech -------------------------------------------

static func _encode(samples: PackedFloat32Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(samples.size())
	for i in samples.size():
		var x := clampf(samples[i], -1.0, 1.0)
		var magnitude := log(1.0 + 255.0 * absf(x)) / log(256.0)
		bytes[i] = int(magnitude * 127.0) | (128 if x < 0.0 else 0)
	return bytes


static func _decode(bytes: PackedByteArray) -> PackedFloat32Array:
	var samples := PackedFloat32Array()
	samples.resize(bytes.size())
	for i in bytes.size():
		var byte := bytes[i]
		var magnitude := (pow(256.0, float(byte & 127) / 127.0) - 1.0) / 255.0
		samples[i] = -magnitude if byte & 128 else magnitude
	return samples


func _profile_value(key: String, fallback: Variant) -> Variant:
	var profile := get_node_or_null("/root/Profile")
	if profile == null:
		return fallback
	var value: Variant = profile.get(key)
	return fallback if value == null else value
