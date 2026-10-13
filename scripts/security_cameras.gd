class_name SecurityCameras
extends Node
## The school's CCTV cameras. Each camera renders into its own small offscreen picture (a "feed"),
## and any number of guard room monitors can show that feed.
##
## Rendering a camera costs about as much as drawing the game a second time, so feeds only refresh
## while you're in the guard room, and only one feed refreshes per frame. That gives each feed a
## choppy, CCTV-like frame rate for free. A feed shown full screen refreshes every frame.

const FEED_SIZE := Vector2i(640, 360)
## The guard room. Feeds only refresh while your guard is inside it.
const GUARD_ROOM := AABB(Vector3(6, -1, 10), Vector3(14, 5, 10))

## One SubViewport per camera; its texture is the feed.
var feeds: Array[SubViewport] = []
var names: Array[String] = []
## The guard whose computer this is. Set by Main.
var viewer: Node3D
## Camera indices currently on at least one monitor. Set by GuardRoom.
var shown: Array[int] = []

var _focus := -1
var _next := 0
var _blink := 0.0
var _rec_labels: Array[Label] = []
var _time_labels: Array[Label] = []


## Creates one camera per spot. Each spot is {"name", "position", "target"}.
func build(spots: Array[Dictionary]) -> void:
	var environment := _make_infrared_environment()
	for i in spots.size():
		var spot := spots[i]
		var viewport := SubViewport.new()
		viewport.name = "Feed%d" % (i + 1)
		viewport.size = FEED_SIZE
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)

		var camera := Camera3D.new()
		camera.fov = 72.0
		camera.far = 60.0
		camera.environment = environment
		viewport.add_child(camera)
		camera.look_at_from_position(spot["position"], spot["target"], Vector3.UP)

		_add_overlay(viewport, i, spot["name"])
		feeds.append(viewport)
		names.append(spot["name"])


## The Camera3D behind a feed, e.g. to check what it can see.
func camera(index: int) -> Camera3D:
	return feeds[index].get_child(0) as Camera3D


func texture(camera: int) -> Texture2D:
	return feeds[camera].get_texture()


## "CAM 03 · Cafeteria"
func title(camera: int) -> String:
	return "CAM %02d · %s" % [camera + 1, names[camera]]


## The time stamp in the corner of every feed.
func set_time(text: String) -> void:
	for label in _time_labels:
		label.text = text


## Shows one feed full screen (-1 for none). That feed then refreshes every frame.
func set_focus(camera: int) -> void:
	if _focus >= 0 and _focus != camera:
		feeds[_focus].render_target_update_mode = SubViewport.UPDATE_DISABLED
	_focus = camera
	if camera >= 0:
		feeds[camera].render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.2)
	for label in _rec_labels:
		label.visible = _blink < 0.7

	if shown.is_empty() or viewer == null or not viewer.is_inside_tree() or not GUARD_ROOM.has_point(viewer.global_position):
		return
	_next = (_next + 1) % shown.size()
	var camera := shown[_next]
	if camera != _focus:
		feeds[camera].render_target_update_mode = SubViewport.UPDATE_ONCE


## Camera name and a blinking REC drawn on top of the picture.
func _add_overlay(viewport: SubViewport, index: int, camera_name: String) -> void:
	var name_label := Label.new()
	name_label.text = "CAM %02d  %s" % [index + 1, camera_name.to_upper()]
	name_label.position = Vector2(16, 10)
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_constant_override("outline_size", 6)
	name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	viewport.add_child(name_label)

	var rec := Label.new()
	rec.text = "● REC"
	rec.position = Vector2(FEED_SIZE.x - 100, 10)
	rec.add_theme_font_size_override("font_size", 24)
	rec.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	viewport.add_child(rec)
	_rec_labels.append(rec)

	var time := Label.new()
	time.position = Vector2(16, FEED_SIZE.y - 44)
	time.add_theme_font_size_override("font_size", 24)
	time.add_theme_constant_override("outline_size", 6)
	time.add_theme_color_override("font_outline_color", Color.BLACK)
	viewport.add_child(time)
	_time_labels.append(time)


## Security cameras see in infrared, so the feeds stay readable after the lights go down.
func _make_infrared_environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.9, 0.85)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.05)
	env.fog_density = 0.01
	return env
