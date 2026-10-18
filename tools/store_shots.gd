extends SceneTree
## Steam store screenshots (see STEAM.md): run rendered at 1920x1080; saves to steam/screenshots/.
var main: Node
var f := 0
const OUT := "res://steam/screenshots/"
## name, guard spot, guard turn, head pitch, [[kind, spot, turn], ...]
var SCENES := [
	["hall_monitor", Vector3(5, 0.1, 7), PI / 2, 0.16, [["hall_monitor", Vector3(1.0, 0, 7), -PI / 2]]],
	["principal", Vector3(22, 0.1, -10.2), 0.0, 0.18, [["principal", Vector3(22, 0, -11.9), PI]]],
	["lunch_lady", Vector3(-15, 0.1, -2), 0.0, -0.08, [["lunch_lady", Vector3(-15.3, 0, -5.0), PI]]],
	["twins", Vector3(-47, 0.1, 11), PI, -0.12, [["twin", Vector3(-47.8, 0, 13.8), 0.0], ["twin", Vector3(-46.3, 0, 14.4), 0.0]]],
	["mascot", Vector3(22, 0.1, -8), 0.0, -0.02, [["mascot", Vector3(22, 0, -11.2), PI]]],
	["librarian", Vector3(-69, 0.1, -1.5), 0.1, -0.04, [["librarian", Vector3(-69.3, 0, -5.0), PI]]],
	["team", Vector3(9, 0.1, 7), -PI / 2, -0.02, [["photographer", Vector3(18.5, 0, 7.0), PI / 2]]],
	["band_room", Vector3(27.5, 0.1, 15.5), 0.812, -0.02, [["student", Vector3(24.2, 0, 12.4), 0.812 + PI]]],
	["restroom", Vector3(-21.6, 0.1, 11.6), 2.356, -0.06, [["other_cleaner", Vector3(-25.6, 0, 15.6), 2.356 + PI]]],
]
## Frames each shot is given to settle (monsters in place, shadows and bounced light).
const SETTLE := 24
## The flashlight sits above the eye line: look down a little so it lands on the monster.
const AIM_DOWN := 0.14
var _scene := -1
## Which scenes to shoot (all, or those named after --).
var _order: Array[int] = []
var _start := 0
var others: Array = []


func _initialize() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var only := OS.get_cmdline_user_args()
	for i in SCENES.size():
		if only.is_empty() or SCENES[i][0] in only:
			_order.append(i)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))


func _hide_ui(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = false
		_hide_ui(child)


func _process(_d: float) -> bool:
	f += 1
	var g: Guard = main._local_guard
	if f == 5:
		main.menu._continue.button_pressed = false
		main._play_solo(); main.night.number = 5; main.night.seconds_per_minute = 1000.0
	if f == 10:
		main._on_clock_machine_used(g); main._on_keypad_submitted(g.employee_number)
		main.director.tonight.clear(); main.director._lockdown_times.clear()
		for child in main.director._container.get_children():
			child.queue_free()
	# On a slow (software) renderer each frame only moves the clock a little: run the lights-out
	# to its end.
	if f >= 12 and f <= 20:
		for tween: Tween in main.lighting._tweens:
			if tween.is_valid():
				tween.custom_step(30.0)
	# Every shot is indoors: the grass outside is never seen, so don't spend time drawing it.
	for grass in get_nodes_in_group("long_grass"):
		grass.visible = false
	if f < 50:
		return false
	if _scene < 0 or f - _start == SETTLE:
		if _scene >= 0:
			var shot := root.get_viewport().get_texture().get_image()
			shot.save_png(ProjectSettings.globalize_path(OUT + "%d_%s.png" % [_order[_scene] + 1, SCENES[_order[_scene]][0]]))
		_scene += 1
		if _scene >= _order.size():
			return true
		_start = f
		for child in main.director._container.get_children():
			child.queue_free()
		var s: Array = SCENES[_order[_scene]]
		g.global_position = s[1]; g.rotation.y = s[2]; g.head.rotation.x = s[3] - AIM_DOWN
		for other in others:
			other.queue_free()
		others.clear()
		if s[0] == "team":
			for i in 3:
				var other: Guard = load("res://scenes/player.tscn").instantiate()
				other.name = str(900 + i)
				other.slot = i + 2
				other.hat = "cap" if i == 1 else ""
				main.add_child(other)
				others.append(other)
		for spec in s[4]:
			# Out of reach at first: it's moved in once it's been stopped.
			var away: Vector3 = spec[1] + (spec[1] - s[1]).normalized() * 8.0
			main.director.spawn(spec[0], Vector3(away.x, 0, away.z), {"target": 1})
	var since := f - _start
	if since >= 2 and since <= 12:
		var s: Array = SCENES[_order[_scene]]
		var monsters: Array = main.director._container.get_children().filter(func(m): return not m.is_queued_for_deletion())
		for i in monsters.size():
			var m: Node3D = monsters[i]
			m.set_physics_process(false)
			var spec: Array = s[4][mini(i, s[4].size() - 1)]
			m.global_position = spec[1]; m.rotation.y = spec[2]
	if since > 2:
		# Flashlights stutter near monsters (Dread): hold them steady for the photo.
		main.dread.process_mode = Node.PROCESS_MODE_DISABLED
		g.flashlight.visible = true
		g.flashlight.light_energy = g.flashlight_energy()
		var spots := [Vector3(12.5, 0.1, 5.8), Vector3(13.6, 0.1, 8.0), Vector3(15.2, 0.1, 6.6)]
		for i in others.size():
			others[i].global_position = spots[i]; others[i].rotation.y = -PI / 2 + (i - 1) * 0.25
			others[i].flashlight.visible = true
			others[i].flashlight.light_energy = others[i].flashlight_energy()
			others[i].name_tag.visible = false
		_hide_ui(main)
	return false
