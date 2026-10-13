extends Node
## This player's employee profile, kept on this computer. For now that's their badge number,
## which they type into the time clock to clock in. Saves and scores are linked to it.

const PATH := "user://profile.cfg"

var employee_number := 0


func _enter_tree() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		employee_number = config.get_value("employee", "number", 0)
	if employee_number < 1000:
		employee_number = randi_range(1000, 9999)
		# 0451 belongs to someone else.
		config.set_value("employee", "number", employee_number)
		config.save(PATH)


## "#2731"
func badge() -> String:
	return "#%04d" % employee_number
