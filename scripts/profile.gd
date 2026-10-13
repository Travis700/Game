extends Node
## This player's profile and settings, kept on this computer: their badge number (typed into
## the time clock to clock in; saves and scores are linked to it), mouse sensitivity and volume.

const PATH := "user://profile.cfg"

var employee_number := 0
## Multiplier on the guard's mouse look speed (1.0 = default).
var mouse_sensitivity := 1.0
## Master volume, 0 to 1.
var volume := 0.8


func _enter_tree() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		employee_number = config.get_value("employee", "number", 0)
		mouse_sensitivity = config.get_value("settings", "mouse_sensitivity", 1.0)
		volume = config.get_value("settings", "volume", 0.8)
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
	config.save(PATH)


func apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
