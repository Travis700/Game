class_name Strider
extends Node
## Plays a rigged model's walk or run to match how fast its body is really moving, on every
## computer (so it works for synced remote players and monsters alike). Stands still mid-stride.

var moves: AnimationPlayer
## How tall the model is: the clips were made at about 1.7 m, so taller strides cover more ground.
var height := 1.7

## A clip to hold instead of walking, e.g. "sit" at a desk ("" to walk as usual).
var hold := ""

var _body: Node3D
var _last_spot := Vector3.INF
var _pace_seen := 0.0


static func attach(body: Node3D, player: AnimationPlayer, model_height: float) -> Strider:
	var strider := Strider.new()
	strider.moves = player
	strider.height = model_height
	strider._body = body
	body.add_child(strider)
	# Stand in the walk's first frame rather than the stiff arms-out pose it was rigged in.
	player.play("walk")
	player.seek(0.0, true)
	player.pause()
	return strider


func _process(delta: float) -> void:
	if moves == null or _body == null or delta <= 0.0:
		return
	if hold != "" and moves.has_animation(hold):
		if moves.current_animation != hold or not moves.is_playing():
			moves.play(hold, 0.3)
			moves.speed_scale = 1.0
		_last_spot = Vector3.INF
		return
	var spot := _body.global_position
	if _last_spot != Vector3.INF:
		var moved := Vector2(spot.x - _last_spot.x, spot.z - _last_spot.z).length() / delta
		_pace_seen = lerpf(_pace_seen, moved, minf(1.0, delta * 8.0))
	_last_spot = spot
	var stride := maxf(height, 0.5) / 1.7
	if _pace_seen < 0.15:
		if moves.is_playing():
			moves.pause()
		return
	var running := _pace_seen > 2.6 * stride and moves.has_animation("run")
	var clip := "run" if running else "walk"
	if moves.current_animation != clip or not moves.is_playing():
		moves.play(clip, 0.25)
	moves.speed_scale = clampf(_pace_seen / ((3.6 if running else 1.3) * stride), 0.4, 2.2)
