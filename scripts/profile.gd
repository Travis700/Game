extends Node
## This player's profile and settings, kept on this computer: their badge number (typed into
## the time clock to clock in; saves and scores are linked to it), mouse sensitivity and volume.

const PATH := "user://profile.cfg"

var employee_number := 0
## Multiplier on the guard's mouse look speed (1.0 = default).
var mouse_sensitivity := 1.0
## Master volume, 0 to 1.
var volume := 0.8
## Graphics: V-sync, 3D resolution (1.0 = full), shadows, and anti-aliasing (0 off, 1 = 2x, 2 = 4x).
var vsync := true
var render_scale := 1.0
var shadows := true
var antialiasing := 1
## Field of view, in degrees.
var fov := 75.0
## Overall brightness (1 = as designed). For dark screens: the night should be dark, not invisible.
var brightness := 1.0
## Voice chat: "push" (hold the push-to-talk key), "open" (talks when you're loud enough) or "off".
var voice_mode := "push"
## Open mic: how loud (0-1) you have to be before it sends.
var mic_threshold := 0.12
## Other players' voices, 0 to 1.5.
var voice_volume := 1.0
## Which microphone ("" for the system default).
var mic_device := ""
## Night length on the menu: 0 short, 1 normal, 2 long.
var night_length := 1
## Sound captions for monsters' noises (bottom right).
var captions := true
## True once this player has finished the training shift.
var training_done := false
## How many times this player has had the night-1 tips (they stop after a couple of runs).
var tips_shown := 0
## The hat your guard wears (see Hats).
var hat := "cap"
## The perk your guard brings to work (see Perks).
var perk := "thermos"
## Custom shift: the shift notes the host wants every night (empty: random, as usual).
var custom_notes: Array = []
## Whether the Understudy may say back things you said (kept only in the host's memory).
var voice_mimic := true

## Lights that cast shadows (the moon, flashlights), switched by the Shadows setting.
const SHADOW_LIGHTS := "shadow_lights"


func _enter_tree() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		employee_number = config.get_value("employee", "number", 0)
		mouse_sensitivity = config.get_value("settings", "mouse_sensitivity", 1.0)
		volume = config.get_value("settings", "volume", 0.8)
		vsync = config.get_value("graphics", "vsync", true)
		render_scale = config.get_value("graphics", "render_scale", 1.0)
		shadows = config.get_value("graphics", "shadows", true)
		antialiasing = config.get_value("graphics", "antialiasing", 1)
		fov = config.get_value("graphics", "fov", 75.0)
		brightness = config.get_value("graphics", "brightness", 1.0)
		voice_mode = config.get_value("voice", "mode", "push")
		mic_threshold = config.get_value("voice", "threshold", 0.12)
		voice_volume = config.get_value("voice", "volume", 1.0)
		mic_device = config.get_value("voice", "device", "")
		voice_mimic = config.get_value("voice", "mimic", true)
		hat = config.get_value("look", "hat", "cap")
		perk = config.get_value("look", "perk", "thermos")
		custom_notes = config.get_value("settings", "custom_notes", [])
		training_done = config.get_value("career", "training_done", false)
		tips_shown = config.get_value("career", "tips_shown", 0)
		captions = config.get_value("settings", "captions", true)
		night_length = config.get_value("settings", "night_length", 1)
	apply_volume()
	if employee_number < 1000:
		employee_number = randi_range(1000, 9999)
		# 0451 belongs to someone else.
		config.set_value("employee", "number", employee_number)
		_save(config)


## "#2731"
func badge() -> String:
	return "#%04d" % employee_number


## Saves the settings (and badge) to disk.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("employee", "number", employee_number)
	config.set_value("settings", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("settings", "volume", volume)
	config.set_value("graphics", "vsync", vsync)
	config.set_value("graphics", "render_scale", render_scale)
	config.set_value("graphics", "shadows", shadows)
	config.set_value("graphics", "antialiasing", antialiasing)
	config.set_value("graphics", "fov", fov)
	config.set_value("graphics", "brightness", brightness)
	config.set_value("voice", "mode", voice_mode)
	config.set_value("voice", "threshold", mic_threshold)
	config.set_value("voice", "volume", voice_volume)
	config.set_value("voice", "device", mic_device)
	config.set_value("voice", "mimic", voice_mimic)
	config.set_value("look", "hat", hat)
	config.set_value("look", "perk", perk)
	config.set_value("settings", "custom_notes", custom_notes)
	config.set_value("career", "training_done", training_done)
	config.set_value("career", "tips_shown", tips_shown)
	config.set_value("settings", "captions", captions)
	config.set_value("settings", "night_length", night_length)
	_save(config)


## Applies the brightness setting to the game world's look (WorldEnvironments in "world_env").
func apply_brightness() -> void:
	for node in get_tree().get_nodes_in_group("world_env"):
		var env := (node as WorldEnvironment).environment
		env.adjustment_enabled = true
		env.adjustment_brightness = brightness


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))


func _ready() -> void:
	apply_graphics()


## Applies the graphics settings to the game window and every shadow-casting light.
func apply_graphics() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	var root := get_tree().root
	root.scaling_3d_scale = clampf(render_scale, 0.5, 1.0)
	root.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][clampi(antialiasing, 0, 2)]
	for light in get_tree().get_nodes_in_group(SHADOW_LIGHTS):
		(light as Light3D).shadow_enabled = shadows


## Writes a new file and swaps it in, so a crash mid-save can't lose the settings and badge.
func _save(config: ConfigFile) -> void:
	var temp := PATH + ".new"
	if config.save(temp) != OK:
		return
	var dir := DirAccess.open("user://")
	if dir and dir.rename(temp, PATH) != OK:
		dir.remove(PATH)
		dir.rename(temp, PATH)
