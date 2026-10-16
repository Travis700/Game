class_name Nerve
extends Node
## Nerve: how steady each guard is, 100 (calm) to 0 (falling apart). It wears down in the dark,
## alone, near monsters, and when a teammate is caught; it comes back in the lit guard room, near
## teammates, and with coffee.
##
## Low nerve is dangerous: monsters notice you from further away, and you start to hear and
## see things that aren't there (footsteps behind you, whispers, a figure at the edge of the
## light). The host keeps everyone's nerve and tells each guard theirs; each computer plays its
## own guard's hallucinations.

const MAX := 100.0
## Per real second.
const BASE_DRAIN := 0.04
const ALONE_DRAIN := 0.12
const SOLO_DRAIN := 0.06
const DARK_DRAIN := 0.5
const MONSTER_DRAIN := 0.7
## Crouched in the dark in a cupboard, listening.
const HIDING_DRAIN := 1.0
const GUARD_ROOM_GAIN := 0.5
const COMPANY_GAIN := 0.08
const MONSTER_RANGE := 12.0
const COMPANY_RANGE := 8.0
## Losing a teammate.
const TEAMMATE_CAUGHT := 15.0
## Below this, things start happening that aren't real.
const HALLUCINATE_BELOW := 40.0
## How much further monsters notice a guard with no nerve left (1.3 = 30% further).
const SHAKEN_REACH := 1.3

var director: MonsterDirector
var players: Node3D
var power: Power
var hiding: Hiding
var hud: CanvasLayer
## The local guard. Set by Main.
var local_guard: Guard

## Host: peer id -> nerve.
var levels: Dictionary = {}
## This computer's own guard's nerve, as last told by the host.
var mine := MAX

var _send_timer := 0.0
var _next_vision := 0.0


# --- Host --------------------------------------------------------------------------------

func reset() -> void:
	levels.clear()
	# Sent the sure way: nothing re-sends it in the morning, and a lost one would leave the fear on.
	for guard: Guard in players.get_children():
		var peer_id := guard.name.to_int()
		if peer_id == multiplayer.get_unique_id():
			_set_mine(MAX)
		elif peer_id in multiplayer.get_peers():
			_reset_mine.rpc_id(peer_id)


func update(delta: float) -> void:
	var living := director.living_guards()
	for guard in living:
		var peer := guard.name.to_int()
		var nerve: float = levels.get(peer, MAX)
		var at := guard.global_position
		var change := -BASE_DRAIN
		if SchoolBuilder.AREAS["Guard Room"].has_point(at) and power.on:
			change += GUARD_ROOM_GAIN
		elif not power.on:
			change -= DARK_DRAIN
		var company := false
		for other in living:
			if other != guard and other.global_position.distance_to(at) < COMPANY_RANGE:
				company = true
		# Being on your own only wears on you when there's a team to have split up from.
		if company:
			change += COMPANY_GAIN
		elif living.size() > 1:
			change -= ALONE_DRAIN
		else:
			# On your own all night: it wears on you, if less than splitting from a team.
			change -= SOLO_DRAIN
		for monster in director.active_monsters():
			if monster.global_position.distance_to(at) < MONSTER_RANGE:
				change -= MONSTER_DRAIN
				break
		if guard.hiding and guard.perk != "cool_head":
			change -= HIDING_DRAIN
		if change < 0.0 and guard.perk == "thermos":
			change *= 0.75
		levels[peer] = clampf(nerve + change * delta, 0.0, MAX)
		if guard.hiding and levels[peer] <= 0.0:
			_panic(guard)
	_send_timer -= delta
	if _send_timer <= 0.0:
		_send_timer = 1.0
		_send_all()


## Host: a guard's nerve gave out in a cupboard. Out they come, screaming, and everything hears.
func _panic(guard: Guard) -> void:
	var peer := guard.name.to_int()
	if hiding:
		hiding._set_hidden.rpc(peer, -1)
	director.report_voice(peer, 1.0)
	director.tell(peer, "You can't stand it any longer. You burst out of the cupboard, screaming.")
	levels[peer] = 15.0


## Host: a guard's nerve goes up (coffee) or down (a scare).
func add(peer_id: int, amount: float) -> void:
	levels[peer_id] = clampf(float(levels.get(peer_id, MAX)) + amount, 0.0, MAX)
	_send_to(peer_id)


## Host: a guard was caught. Everyone else is shaken.
func on_caught(caught: Guard) -> void:
	for guard in director.living_guards():
		if guard != caught:
			add(guard.name.to_int(), -TEAMMATE_CAUGHT)


## Host: how much further monsters notice this guard (1 when calm).
func reach_factor(guard: Guard) -> float:
	var nerve: float = levels.get(guard.name.to_int(), MAX)
	return lerpf(SHAKEN_REACH, 1.0, nerve / MAX) * (0.85 if guard.perk == "low_profile" else 1.0)


func _send_all() -> void:
	for guard: Guard in players.get_children():
		_send_to(guard.name.to_int())


func _send_to(peer_id: int) -> void:
	var value: float = levels.get(peer_id, MAX)
	# A ghost has nothing left to be afraid of: no fear on their screen.
	var guard := director.guard_by_peer(peer_id) if director else null
	if guard and guard.is_dead:
		value = MAX
	if peer_id == multiplayer.get_unique_id():
		_set_mine(value)
	elif peer_id in multiplayer.get_peers():
		_set_mine.rpc_id(peer_id, value)


# --- This computer's guard -----------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _reset_mine() -> void:
	_set_mine(MAX)


@rpc("authority", "call_remote", "unreliable_ordered")
func _set_mine(value: float) -> void:
	mine = value
	if hud and hud.has_method("set_nerve"):
		hud.set_nerve(mine)


func _process(delta: float) -> void:
	if local_guard == null or not is_instance_valid(local_guard) or local_guard.is_dead or mine >= HALLUCINATE_BELOW:
		_next_vision = randf_range(8.0, 16.0)
		return
	_next_vision -= delta
	if _next_vision > 0.0:
		return
	# The lower it gets, the more often.
	_next_vision = lerpf(8.0, 30.0, mine / HALLUCINATE_BELOW) * randf_range(0.7, 1.3)
	match randi() % 4:
		0:
			_footsteps_behind()
		1:
			_whisper()
		2:
			_figure_at_the_edge()
		3:
			_knock()


func _footsteps_behind() -> void:
	var spot := Node3D.new()
	local_guard.add_child(spot)
	spot.position = Vector3(randf_range(-1.5, 1.5), 0.1, 3.5)
	var steps := create_tween()
	for i in 4:
		steps.tween_callback(func() -> void: Sfx.play_at(spot, Sfx.thud(0.8, 0.07, 0.5), -6.0, 12.0))
		steps.tween_interval(0.45)
	steps.tween_interval(1.0)
	steps.tween_callback(spot.queue_free)


func _whisper() -> void:
	var spot := Node3D.new()
	local_guard.add_child(spot)
	spot.position = Vector3(randf_range(-2.0, 2.0), 1.6, randf_range(-2.0, 2.0))
	var player := Sfx.play_at(spot, Sfx.notes([1.0, 1.0, 1.0], 0.35, 0.08, "noise"), -10.0, 8.0)
	if player:
		player.pitch_scale = 0.5
	get_tree().create_timer(2.0).timeout.connect(spot.queue_free)
	if randf() < 0.5:
		# A whisper, as a sound caption (not the message line: it mustn't push real news away).
		get_tree().call_group("captions", "_add", "[A whisper: \"%s\"]" % ["...behind you...", "...it's here...", "...don't turn around...", "...Guard..."].pick_random())


func _figure_at_the_edge() -> void:
	# Just off to one side, a little way off: there when you glance, gone when you look.
	var camera := local_guard.camera
	var side := camera.global_basis.x * (1.0 if randf() < 0.5 else -1.0)
	var spot := camera.global_position - camera.global_basis.z * 7.0 + side * 4.5
	spot.y = local_guard.global_position.y
	var figure := Node3D.new()
	add_child(figure)
	figure.global_position = spot
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.025)
	var body := MeshInstance3D.new()
	body.mesh = Monster.box(Vector3(0.45, 2.1, 0.3))
	body.position = Vector3(0, 1.05, 0)
	body.material_override = dark
	figure.add_child(body)
	# Gone the moment you look at it, or after a few seconds anyway.
	var timer := Timer.new()
	timer.wait_time = 0.05
	timer.autostart = true
	figure.add_child(timer)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(camera):
			figure.queue_free()
			return
		var to_figure := figure.global_position + Vector3(0, 1.2, 0) - camera.global_position
		if (-camera.global_basis.z).angle_to(to_figure) < deg_to_rad(18):
			figure.queue_free())
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(figure):
			figure.queue_free())


func _knock() -> void:
	var spot := Node3D.new()
	local_guard.add_child(spot)
	spot.position = Vector3(randf_range(-4.0, 4.0), 1.2, randf_range(-4.0, 4.0))
	var knocks := create_tween()
	for i in 3:
		knocks.tween_callback(func() -> void: Sfx.play_at(spot, Sfx.thud(1.4, 0.05, 0.7), -2.0, 15.0))
		knocks.tween_interval(0.22)
	knocks.tween_interval(1.0)
	knocks.tween_callback(spot.queue_free)
