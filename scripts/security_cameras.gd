class_name SecurityCameras
extends Node
## The school's CCTV cameras. Each camera renders into small offscreen pictures ("feeds"),
## and any number of guard room monitors can show a feed.
##
## Every camera has two feeds: the normal one, and a spectral one for desks with the camera
## upgrade, which also shows the Ghost. A feed is only drawn while a monitor shows it.
##
## Rendering a feed costs about as much as drawing the game a second time, so feeds only refresh
## while you're in the guard room, and only one feed refreshes per frame. That gives each feed a
## choppy, CCTV-like frame rate for free. A feed shown full screen refreshes every frame.

const FEED_SIZE := Vector2i(640, 360)
## The guard room. Feeds only refresh while your guard is inside it.
const GUARD_ROOM := AABB(Vector3(6, -1, 10), Vector3(14, 5, 10))
## Things on this layer (the Ghost) only show up on spectral feeds.
const SPECTRAL_LAYER := 1 << 12
## Things on this layer (the fake Student) never show up on any camera.
const HIDDEN_FROM_CAMERAS := 1 << 11

var names: Array[String] = []
## The lowest difficulty each camera's wing is open at.
var difficulties: Array[int] = []
## Tonight's difficulty: cameras in closed wings can't be picked on the monitors.
var difficulty := 1
## The guard whose computer this is. Set by Main.
var viewer: Node3D
## Feeds currently on at least one monitor, as feed keys (see `key`). Set by GuardRoom.
var shown: Array[int] = []

## Feed key -> SubViewport. Key = camera * 2, plus 1 for the spectral feed.
var _feeds: Array[SubViewport] = []
var _no_signal: Array[Control] = []
var _focus := -1
var _next := 0
var _blink := 0.0
var _rec_labels: Array[Label] = []
var _time_labels: Array[Label] = []


## Creates the cameras. Each spot is {"name", "position", "target"}.
func build(spots: Array[Dictionary]) -> void:
	var normal_env := _make_environment(false)
	var spectral_env := _make_environment(true)
	for i in spots.size():
		var spot := spots[i]
		names.append(spot["name"])
		difficulties.append(spot.get("difficulty", 1))
		for spectral: bool in [false, true]:
			var viewport := SubViewport.new()
			viewport.name = "Feed%d%s" % [i + 1, "Spectral" if spectral else ""]
			viewport.size = FEED_SIZE
			viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if not spectral else SubViewport.UPDATE_DISABLED
			add_child(viewport)
			var camera := Camera3D.new()
			camera.fov = 72.0
			camera.far = 60.0
			camera.environment = spectral_env if spectral else normal_env
			camera.cull_mask &= ~HIDDEN_FROM_CAMERAS
			if not spectral:
				camera.cull_mask &= ~SPECTRAL_LAYER
			viewport.add_child(camera)
			camera.look_at_from_position(spot["position"], spot["target"], Vector3.UP)
			_add_overlay(viewport, i, spot["name"], spectral)
			_feeds.append(viewport)


func count() -> int:
	return names.size()


## Can this camera be shown at tonight's difficulty?
func is_open(camera_index: int) -> bool:
	return difficulties[camera_index] <= difficulty


## The cameras that can be shown tonight, in order.
func open_cameras() -> Array[int]:
	var result: Array[int] = []
	for i in count():
		if is_open(i):
			result.append(i)
	return result


static func key(camera_index: int, spectral: bool) -> int:
	return camera_index * 2 + (1 if spectral else 0)


## The (normal) Camera3D for a camera, e.g. to check what it can see.
func camera(index: int) -> Camera3D:
	return _feeds[key(index, false)].get_child(0) as Camera3D


func texture(camera_index: int, spectral := false) -> Texture2D:
	return _feeds[key(camera_index, spectral)].get_texture()


## "CAM 03 · Cafeteria"
func title(camera_index: int) -> String:
	return "CAM %02d · %s" % [camera_index + 1, names[camera_index]]


## The time stamp in the corner of every feed.
func set_time(text: String) -> void:
	for label in _time_labels:
		label.text = text


## Knocks a camera out (both feeds show NO SIGNAL) or brings it back.
func set_signal(camera_index: int, working: bool) -> void:
	for spectral: bool in [false, true]:
		var feed_key := key(camera_index, spectral)
		_no_signal[feed_key].visible = not working
		if feed_key != _focus:
			_feeds[feed_key].render_target_update_mode = SubViewport.UPDATE_ONCE


func is_working(camera_index: int) -> bool:
	return not _no_signal[key(camera_index, false)].visible


## Shows one feed full screen (-1 for none). That feed then refreshes every frame.
func set_focus(feed_key: int) -> void:
	if _focus >= 0 and _focus != feed_key:
		_feeds[_focus].render_target_update_mode = SubViewport.UPDATE_DISABLED
	_focus = feed_key
	if feed_key >= 0:
		_feeds[feed_key].render_target_update_mode = SubViewport.UPDATE_ALWAYS


func _process(delta: float) -> void:
	_blink = fmod(_blink + delta, 1.2)
	for label in _rec_labels:
		label.visible = _blink < 0.7

	if shown.is_empty() or viewer == null or not viewer.is_inside_tree() or not GUARD_ROOM.has_point(viewer.global_position):
		return
	_next = (_next + 1) % shown.size()
	var feed_key := shown[_next]
	if feed_key != _focus:
		_feeds[feed_key].render_target_update_mode = SubViewport.UPDATE_ONCE


## Camera name, a blinking REC, the time, and a hidden NO SIGNAL screen, drawn over the picture.
func _add_overlay(viewport: SubViewport, index: int, camera_name: String, spectral: bool) -> void:
	var name_label := _feed_label("CAM %02d  %s%s" % [index + 1, camera_name.to_upper(), "  ·  SPECTRAL" if spectral else ""],
			Vector2(16, 10))
	viewport.add_child(name_label)

	var rec := _feed_label("● REC", Vector2(FEED_SIZE.x - 100, 10))
	rec.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	viewport.add_child(rec)
	_rec_labels.append(rec)

	var time := _feed_label("", Vector2(16, FEED_SIZE.y - 44))
	viewport.add_child(time)
	_time_labels.append(time)

	var no_signal := ColorRect.new()
	no_signal.color = Color(0.04, 0.04, 0.05)
	no_signal.size = Vector2(FEED_SIZE)
	no_signal.visible = false
	var text := _feed_label("NO SIGNAL", Vector2(0, 0))
	text.size = Vector2(FEED_SIZE)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 48)
	no_signal.add_child(text)
	viewport.add_child(no_signal)
	_no_signal.append(no_signal)


func _feed_label(text: String, at: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


## Security cameras see in infrared, so the feeds stay readable after the lights go down.
## The spectral feed is a little brighter and colder.
func _make_environment(spectral: bool) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.03, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.85, 1.0) if spectral else Color(0.85, 0.9, 0.85)
	env.ambient_light_energy = 0.65 if spectral else 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.05, 0.05)
	env.fog_density = 0.01
	return env
