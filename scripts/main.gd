extends Node3D
## Entry point: sets up the night sky, builds the school, and spawns the guard at the front gate.

const PlayerScene := preload("res://scenes/player.tscn")
const HUD := preload("res://scripts/hud.gd")

## Where a guard starts each night: outside the gate, facing the school (north is -Z).
const SPAWN_POINT := Vector3(0, 0.1, 54)


func _ready() -> void:
	_make_environment()

	var school := SchoolBuilder.new()
	school.name = "School"
	add_child(school)

	var hud := HUD.new()
	hud.name = "HUD"
	add_child(hud)

	var player := PlayerScene.instantiate() as Guard
	player.position = SPAWN_POINT
	add_child(player)
	player.prompt_changed.connect(hud.set_prompt)
	player.message_shown.connect(hud.show_message)


func _make_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.045)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.12, 0.14, 0.2)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.09)
	env.fog_density = 0.015

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
