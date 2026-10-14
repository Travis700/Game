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
## Voice chat: "push" (hold the push-to-talk key), "open" (talks when you're loud enough) or "off".
var voice_mode := "push"
## Open mic: how loud (0-1) you have to be before it sends.
var mic_threshold := 0.12
## Other players' voices, 0 to 1.5.
var voice_volume := 1.0
## Which microphone ("" for the system default).
var mic_device := ""
## The hat your guard wears (see Hats).
var hat := "cap"
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
		voice_mode = config.get_value("voice", "mode", "push")
		mic_threshold = config.get_value("voice", "threshold", 0.12)
		voice_volume = config.get_value("voice", "volume", 1.0)
		mic_device = config.get_value("voice", "device", "")
		voice_mimic = config.get_value("voice", "mimic", true)
		hat = config.get_value("look", "hat", "cap")
	apply_volume()
	if employee_number < 1000:
		employee_number = randi_range(1000, 9999)
		# 0451 belongs to someone else.
		config.set_value("employee", "number", employee_number)
		config.save(PATH)


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
	config.set_value("voice", "mode", voice_mode)
	config.set_value("voice", "threshold", mic_threshold)
	config.set_value("voice", "volume", voice_volume)
	config.set_value("voice", "device", mic_device)
	config.set_value("voice", "mimic", voice_mimic)
	config.set_value("look", "hat", hat)
	config.save(PATH)


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
