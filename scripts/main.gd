extends Node3D
## Entry point: sets up the sky, builds the school, spawns the guard at the front gate,
## and starts the night when the guard clocks in.

const PlayerScene := preload("res://scenes/player.tscn")
const HUD := preload("res://scripts/hud.gd")

## Where a guard starts each night: outside the gate, facing the school (north is -Z).
const SPAWN_POINT := Vector3(0, 0.1, 54)

var shift: Shift
var lighting: ShiftLighting


func _ready() -> void:
	var environment := _make_environment()

	var school := SchoolBuilder.new()
	school.name = "School"
	add_child(school)

	shift = Shift.new()
	shift.name = "Shift"
	add_child(shift)

	lighting = ShiftLighting.new()
	lighting.name = "Lighting"
	lighting.environment = environment
	lighting.school = school
	add_child(lighting)
	lighting.apply_pre_shift()
	shift.started.connect(lighting.go_dark)

	school.clock_machine.used.connect(_on_clock_machine_used)
	shift.started.connect(func() -> void: school.clock_machine.prompt = "Check time clock")

	var hud := HUD.new()
	hud.name = "HUD"
	add_child(hud)

	var player := PlayerScene.instantiate() as Guard
	player.position = SPAWN_POINT
	add_child(player)
	player.prompt_changed.connect(hud.set_prompt)
	player.message_shown.connect(hud.show_message)


func _on_clock_machine_used(guard: Node) -> void:
	var message := shift.clock_in(guard)
	if guard.has_method("show_message"):
		guard.show_message(message)


func _make_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.6, 0.7, 1.0)
	moon.light_energy = 0.25
	moon.shadow_enabled = true
	moon.rotation_degrees = Vector3(-40, 35, 0)
	add_child(moon)
	return env
