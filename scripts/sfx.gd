class_name Sfx
## Small sounds made from simple waves, so the game has audio before real sound effects exist.

const RATE := 22050

## Sounds that get played a lot (footsteps), built once.
static var _cache: Dictionary = {}


## Builds a sound from a list of note frequencies (0 = silence), each `note_seconds` long.
## `wave` is "sine", "square", "saw" or "noise".
static func notes(freqs: Array, note_seconds: float, volume := 0.35, wave := "sine", loop := false) -> AudioStreamWAV:
	var per_note := int(note_seconds * RATE)
	var data := PackedByteArray()
	data.resize(freqs.size() * per_note * 2)
	var offset := 0
	for freq: float in freqs:
		for n in per_note:
			var t := float(n) / RATE
			# Short fade in and out on every note so they don't click.
			var envelope := minf(1.0, minf(n / (RATE * 0.02), (per_note - n) / (RATE * 0.05)))
			var value := 0.0
			if freq > 0.0:
				var phase := fmod(t * freq, 1.0)
				match wave:
					"square":
						value = 1.0 if phase < 0.5 else -1.0
					"saw":
						value = 2.0 * phase - 1.0
					"noise":
						value = randf_range(-1.0, 1.0)
					_:
						value = sin(TAU * phase)
			data.encode_s16(offset, int(clampf(value * envelope * volume, -1.0, 1.0) * 32767.0))
			offset += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = data.size() / 2
	return wav


## A bird's chirp: a quick, wavering glide from `from_hz` to `to_hz`, a few times over.
static func chirp(from_hz: float, to_hz: float, seconds := 0.12, repeats := 2, volume := 0.18) -> AudioStreamWAV:
	var per := int(seconds * RATE)
	var gap := int(0.06 * RATE)
	var data := PackedByteArray()
	data.resize((per + gap) * repeats * 2)
	var offset := 0
	for r in repeats:
		var phase := 0.0
		for n in per:
			var k := float(n) / per
			var freq := lerpf(from_hz, to_hz, k * k) * (1.0 + 0.03 * sin(TAU * 38.0 * n / RATE))
			phase += freq / RATE
			var envelope := sin(PI * k)
			data.encode_s16(offset, int(clampf(sin(TAU * phase) * envelope * volume, -1.0, 1.0) * 32767.0))
			offset += 2
		for n in gap:
			data.encode_s16(offset, 0)
			offset += 2
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## Plays a sound from a point in the world. One-off sounds clean themselves up.
static func play_at(parent: Node3D, stream: AudioStream, volume_db := 0.0, max_distance := 30.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = max_distance
	parent.add_child(player)
	player.play()
	if not (stream is AudioStreamWAV and (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED):
		player.finished.connect(player.queue_free)
	return player


## Plays a sound that isn't anywhere in particular, e.g. your own death sting.
static func play_flat(parent: Node, stream: AudioStream, volume_db := 0.0) -> void:
	var player := AudioStreamPlayer.new()
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = volume_db
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


## A short thud: a falling low tone with a scuff of noise, e.g. a footstep.
## `pitch` around 1.0; heavier things go lower, small scuttling things higher.
static func thud(pitch := 1.0, seconds := 0.09, volume := 0.5) -> AudioStreamWAV:
	var key := "thud_%.2f_%.2f_%.2f" % [pitch, seconds, volume]
	if _cache.has(key):
		return _cache[key]
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for n in count:
		var t := float(n) / count
		var envelope := (1.0 - t) * (1.0 - t)
		phase += TAU * lerpf(140.0, 55.0, t) * pitch / RATE
		var value := sin(phase) * 0.7 + randf_range(-1.0, 1.0) * 0.3 * (1.0 - t)
		data.encode_s16(n * 2, int(clampf(value * envelope * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[key] = wav
	return wav


## A long, quiet, looping hum with a slow wobble, for the building at night.
static func hum(seconds := 4.0, volume := 0.12) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for n in count:
		var t := float(n) / RATE
		var wobble := 0.75 + 0.25 * sin(TAU * t / seconds)
		var value := (sin(TAU * 60.0 * t) * 0.6 + sin(TAU * 120.0 * t) * 0.25 + randf_range(-1.0, 1.0) * 0.08) * wobble
		data.encode_s16(n * 2, int(clampf(value * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = count
	return wav


## A creak: a slowly bending, scratchy tone, like an old door or a floor settling.
static func creak(seconds := 0.9, volume := 0.25) -> AudioStreamWAV:
	var count := int(seconds * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var start := randf_range(180.0, 320.0)
	var finish := start * randf_range(0.6, 1.4)
	for n in count:
		var t := float(n) / count
		var envelope := minf(t * 8.0, 1.0) * (1.0 - t)
		phase += TAU * lerpf(start, finish, t) / RATE
		# Scratchy: a sawtooth that stutters.
		var saw := fmod(phase / TAU, 1.0) * 2.0 - 1.0
		var stutter := 1.0 if fmod(t * 37.0, 1.0) > 0.3 else 0.4
		data.encode_s16(n * 2, int(clampf(saw * stutter * envelope * volume, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	return wav
