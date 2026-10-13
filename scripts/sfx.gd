class_name Sfx
## Small sounds made from simple waves, so the game has audio before real sound effects exist.

const RATE := 22050


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


## Plays a sound from a point in the world. One-off sounds clean themselves up.
static func play_at(parent: Node3D, stream: AudioStream, volume_db := 0.0, max_distance := 30.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
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
	player.stream = stream
	player.volume_db = volume_db
	parent.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
