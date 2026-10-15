class_name SoundBank
## The game's recorded sounds, in assets/sounds (see CREDITS.md). get_sound("step_concrete") picks
## one of step_concrete_0, _1... at random, or the single file step_concrete.ogg. Anything
## missing falls back to the synthesised sound passed in, so the game always has audio.

const DIR := "res://assets/sounds/"
static var _cache: Dictionary = {}


static func get_sound(sound_name: String, fallback: AudioStream = null, loop := false) -> AudioStream:
	var key := sound_name + (":loop" if loop else "")
	if not _cache.has(key):
		var found: Array[AudioStream] = []
		if ResourceLoader.exists(DIR + sound_name + ".ogg"):
			found.append(load(DIR + sound_name + ".ogg"))
		for i in 10:
			var path := "%s%s_%d.ogg" % [DIR, sound_name, i]
			if ResourceLoader.exists(path):
				found.append(load(path))
		if loop:
			for i in found.size():
				var copy := found[i].duplicate() as AudioStreamOggVorbis
				if copy:
					copy.loop = true
					found[i] = copy
		_cache[key] = found
	var options: Array = _cache[key]
	return options.pick_random() if not options.is_empty() else fallback


## Plays a recorded sound at a point in the world (or the fallback, if there's no recording).
static func play_at(parent: Node3D, sound_name: String, volume_db := 0.0, max_distance := 30.0,
		fallback: AudioStream = null) -> AudioStreamPlayer3D:
	var stream := get_sound(sound_name, fallback)
	return Sfx.play_at(parent, stream, volume_db, max_distance) if stream else null


## Plays a recorded sound that isn't anywhere in particular.
static func play_flat(parent: Node, sound_name: String, volume_db := 0.0, fallback: AudioStream = null) -> void:
	var stream := get_sound(sound_name, fallback)
	if stream:
		Sfx.play_flat(parent, stream, volume_db)
