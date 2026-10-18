class_name WallClocks
extends Node
## Turns the hands of the school's wall clocks (SchoolBuilder.wall_clocks) to the shift's time.
## Before the shift they show a real evening, creeping from 11:40 towards midnight; on shift they
## follow the night's clock. They're electric: a power cut stops them until the breaker's reset.
## And very now and then, deep in the night, one of them runs backwards for a few seconds.
## That's only on this computer, so nobody will believe you.

## Before the shift: the time the clocks show at first, and the latest (minutes after midnight,
## so 23:40 is twenty to midnight), and how many real seconds each of those minutes takes.
const EVENING_START := 23.0 * 60.0 + 40.0
const EVENING_LATEST := 23.0 * 60.0 + 59.0
const EVENING_SECONDS_PER_MINUTE := 6.0
## Real seconds between chances of a clock running backwards, the chance each time, how long
## it runs back, and how fast (clock minutes per real second).
const TRICK_EVERY := Vector2(60.0, 150.0)
const TRICK_CHANCE := 0.3
const TRICK_SECONDS := Vector2(3.0, 6.0)
const TRICK_SPEED := 5.0

var school: SchoolBuilder
var night: Night
var power: Power

## Real seconds since the evening began (before the shift).
var _evening := 0.0
## What each clock shows, so a power cut can leave them stopped.
var _shown: Array[float] = []
## The clock running backwards (or -1), how long it has left, and how far back it's got.
var _trick_clock := -1
var _trick_left := 0.0
var _trick_back := 0.0
var _next_trick := 0.0


## Turns a clock's hands to a time (minutes after midnight; any number, it wraps round).
static func show_time(clock: Dictionary, minutes: float) -> void:
	var on_dial := fposmod(minutes, 720.0)
	(clock["minute"] as Node3D).rotation.z = -TAU * fposmod(on_dial, 60.0) / 60.0
	(clock["hour"] as Node3D).rotation.z = -TAU * on_dial / 720.0


func _ready() -> void:
	_next_trick = randf_range(TRICK_EVERY.x, TRICK_EVERY.y)


func _process(delta: float) -> void:
	if school == null or school.wall_clocks.is_empty():
		return
	if _shown.size() != school.wall_clocks.size():
		_shown.resize(school.wall_clocks.size())
		_shown.fill(EVENING_START)
	var on_shift := night != null and night.shift != null and night.shift.state != Shift.State.PRE_SHIFT
	var now: float
	if on_shift:
		_evening = 0.0
		now = night.minutes
	else:
		_evening += delta
		now = minf(EVENING_START + _evening / EVENING_SECONDS_PER_MINUTE, EVENING_LATEST)
	# No power, no clocks: the hands stay where they stopped, and catch up when it's back.
	if power != null and not power.on:
		return
	_run_trick(delta, on_shift and night.shift.state == Shift.State.ON_SHIFT)
	for i in school.wall_clocks.size():
		var time := now - (_trick_back if i == _trick_clock else 0.0)
		if not is_equal_approx(time, _shown[i]):
			_shown[i] = time
			show_time(school.wall_clocks[i], time)


## Now and then one clock runs backwards for a few seconds, then snaps back to the right time.
func _run_trick(delta: float, allowed: bool) -> void:
	if _trick_clock >= 0:
		_trick_left -= delta
		_trick_back += TRICK_SPEED * delta
		if _trick_left <= 0.0 or not allowed:
			_trick_clock = -1
			_trick_back = 0.0
		return
	if not allowed:
		return
	_next_trick -= delta
	if _next_trick > 0.0:
		return
	_next_trick = randf_range(TRICK_EVERY.x, TRICK_EVERY.y)
	if randf() < TRICK_CHANCE:
		_trick_clock = randi() % school.wall_clocks.size()
		_trick_left = randf_range(TRICK_SECONDS.x, TRICK_SECONDS.y)
		_trick_back = 0.0
