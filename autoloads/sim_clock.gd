## The authoritative clock: the one place that knows what day it is.
##
## Headless. It never touches the scene tree. `world_renderer` and the view read it every
## frame; nothing here knows a frame exists. `SIMULATION_SPEC.md` §2.1.
##
## Time is stored as a single absolute quantity — `_abs_minute`, sim-minutes since the epoch
## (`time.start_year`, `time.start_day_of_year`, minute 0). Every calendar field is derived
## from it on demand rather than stored, so there is no way for year, month, day and
## minute-of-day to disagree with each other, and a save is one float plus the speed setting.
##
## **The clock starts paused.** Nothing advances until something calls `set_speed_index` — the
## game does this from its HUD; a test that wants time to pass calls `advance_minutes` or
## `advance_days` directly and never depends on `_process`.
##
## Real-time advance (`_process`) is coalesced: it emits each boundary signal at most once per
## call. Bulk headless advance goes through `advance_days`, which loops one day at a time so
## `day_passed` fires for every day — the daily labour budget (`SIMULATION_SPEC.md` §6.1)
## depends on that.
extends Node

## Emitted once per 10-sim-minute substep boundary crossed. Agent movement and task decisions
## run on this fixed step so they are deterministic and frame-rate independent (Architecture
## Guide §2.3); the view interpolates between substeps.
signal substep_passed
## Emitted once per whole sim-hour crossed, with the hour of day just entered (0–23).
signal hour_passed(hour_of_day: int)
## Emitted once per midnight crossed, with the day of year just entered (1–365).
signal day_passed(day_of_year: int)
## Emitted when the month rolls over, with the new month (1–12).
signal month_passed(month: int)
## Emitted when the year rolls over, with the new year.
signal year_passed(year: int)
## Emitted when the meteorological season changes, with the new season (see `Season`).
signal season_changed(season: int)
## Emitted when the play speed changes, with the new speed index.
signal speed_changed(speed_index: int)

enum Season { WINTER, SPRING, SUMMER, AUTUMN }

const MINUTES_PER_HOUR := 60
const MINUTES_PER_SUBSTEP := 10
## A single realtime advance never fires more than this many coalesced substeps, so a long
## frame hitch or a speed change cannot make the agents lurch across the map.
const MAX_SUBSTEPS_PER_ADVANCE := 24

var _abs_minute: float = 0.0
var _speed_index: int = 0
var _resume_speed_index: int = 1

var _minutes_per_day: int = 1440
var _days_per_year: int = 365
var _month_lengths: PackedInt32Array = PackedInt32Array()
var _real_seconds_per_day: float = 20.0
var _speed_multipliers: PackedFloat32Array = PackedFloat32Array()
var _start_year: int = 1
var _start_day_index: int = 0
var _start_day_of_week: int = 0
var _season_start_days: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	_minutes_per_day = Tuning.get_int("time.minutes_per_day")
	_days_per_year = Tuning.get_int("time.days_per_year")
	_real_seconds_per_day = Tuning.get_num("time.real_seconds_per_day_1x")
	_start_year = Tuning.get_int("time.start_year")
	_start_day_index = Tuning.get_int("time.start_day_of_year") - 1
	_start_day_of_week = Tuning.get_int("time.start_day_of_week")

	_month_lengths = _int_array("time.month_lengths")
	_speed_multipliers = _float_array("time.speed_multipliers")
	_season_start_days = _int_array("time.season_start_days")


func _process(delta: float) -> void:
	if _speed_index <= 0:
		return
	# 1× is defined as one day per `real_seconds_per_day` real seconds.
	var sim_minutes_per_real_second: float = float(_minutes_per_day) / _real_seconds_per_day
	advance_minutes(delta * sim_minutes_per_real_second * speed_multiplier())


# --- advancing time -------------------------------------------------------------------------

## Moves the clock forward by `sim_minutes` and emits whatever boundaries were crossed, each at
## most once. This is the real-time path; for large jumps prefer `advance_days`.
func advance_minutes(sim_minutes: float) -> void:
	if sim_minutes <= 0.0:
		return

	var before := int(floor(_abs_minute))
	_abs_minute += sim_minutes
	var after := int(floor(_abs_minute))
	if after == before:
		return

	if _days_crossed(before, after) > _days_per_year + 1:
		push_warning(
			"SimClock: advance_minutes jumped more than a year; use advance_days for bulk time"
		)

	@warning_ignore("integer_division")
	var substeps: int = after / MINUTES_PER_SUBSTEP - before / MINUTES_PER_SUBSTEP
	for _i in mini(substeps, MAX_SUBSTEPS_PER_ADVANCE):
		substep_passed.emit()

	@warning_ignore("integer_division")
	var crossed_an_hour: bool = after / MINUTES_PER_HOUR != before / MINUTES_PER_HOUR
	if crossed_an_hour:
		hour_passed.emit(hour_of_day())

	if _days_crossed(before, after) > 0:
		var old_month := _month_for_day(_day_index_at(before) % _days_per_year + 1)
		var old_year := _start_year + _absolute_day_index_at(before) / _days_per_year
		var old_season := _season_for_day(_day_index_at(before) % _days_per_year + 1)

		day_passed.emit(day_of_year())
		if month() != old_month:
			month_passed.emit(month())
		if year() != old_year:
			year_passed.emit(year())
		if _season_for_day(day_of_year()) != old_season:
			season_changed.emit(season())


## Moves the clock forward whole days, emitting `day_passed` (and any month/year/season
## rollover) for every one. The sanctioned path for headless soak runs.
func advance_days(count: int) -> void:
	for _i in maxi(count, 0):
		advance_minutes(float(_minutes_per_day))


## Convenience for tests and steppers: advance to the next whole sim-minute.
func advance_one_minute() -> void:
	advance_minutes(1.0)


# --- speed ---------------------------------------------------------------------------------

func speed_index() -> int:
	return _speed_index


func speed_multiplier() -> float:
	if _speed_index < 0 or _speed_index >= _speed_multipliers.size():
		return 0.0
	return _speed_multipliers[_speed_index]


func is_paused() -> bool:
	return _speed_index <= 0


## Sets the play speed by index into `time.speed_multipliers` (0 is pause). Clamped, and a
## no-op if unchanged, so it is safe to call from a HUD button every frame.
func set_speed_index(index: int) -> void:
	var clamped := clampi(index, 0, _speed_multipliers.size() - 1)
	if clamped == _speed_index:
		return
	_speed_index = clamped
	speed_changed.emit(_speed_index)


## Steps to the next speed, wrapping from the fastest back to 1× (not to pause — pause is its
## own control so the fast-forward key never accidentally stops time).
func cycle_speed() -> void:
	var next := _speed_index + 1
	if next >= _speed_multipliers.size():
		next = 1
	set_speed_index(next)


## Toggles between paused and the last running speed; resumes at 1× if it was never running.
func toggle_pause() -> void:
	if _speed_index > 0:
		_resume_speed_index = _speed_index
		set_speed_index(0)
	else:
		set_speed_index(maxi(_resume_speed_index, 1))


# --- reading the calendar -----------------------------------------------------------------

## Whole sim-minutes since the epoch.
func total_minutes() -> int:
	return int(floor(_abs_minute))


## Whole days since the epoch.
func total_days() -> int:
	@warning_ignore("integer_division")
	return total_minutes() / _minutes_per_day


func minute_of_day() -> int:
	return total_minutes() % _minutes_per_day


func hour_of_day() -> int:
	@warning_ignore("integer_division")
	return minute_of_day() / MINUTES_PER_HOUR


## Fraction of the day elapsed, 0.0 at midnight to 1.0 at the next midnight. Continuous, for
## driving the sun and any other smooth visual.
func day_fraction() -> float:
	return (_abs_minute - float(total_days() * _minutes_per_day)) / float(_minutes_per_day)


func day_of_year() -> int:
	return _absolute_day_index() % _days_per_year + 1


func year() -> int:
	@warning_ignore("integer_division")
	return _start_year + _absolute_day_index() / _days_per_year


func month() -> int:
	return _month_for_day(day_of_year())


func day_of_month() -> int:
	var day := day_of_year()
	for m in _month_lengths.size():
		if day <= _month_lengths[m]:
			return day
		day -= _month_lengths[m]
	return day


## 0 = Sunday … 6 = Saturday.
func day_of_week() -> int:
	return posmod(_start_day_of_week + total_days(), 7)


func is_sunday() -> bool:
	return day_of_week() == 0


func season() -> int:
	return _season_for_day(day_of_year())


# --- formatting (for the HUD; no logic depends on these) --------------------------------

const _MONTH_NAMES := [
	"January", "February", "March", "April", "May", "June",
	"July", "August", "September", "October", "November", "December",
]
const _WEEKDAY_NAMES := [
	"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
]
const _SEASON_NAMES := ["Winter", "Spring", "Summer", "Autumn"]


func time_string() -> String:
	return "%02d:%02d" % [hour_of_day(), minute_of_day() % MINUTES_PER_HOUR]


func date_string() -> String:
	return "%s %d %s, AD %d" % [
		_WEEKDAY_NAMES[day_of_week()], day_of_month(), _MONTH_NAMES[month() - 1], year()
	]


func season_string() -> String:
	return _SEASON_NAMES[season()]


# --- save / load -------------------------------------------------------------------------

func serialize() -> Dictionary:
	return {"abs_minute": _abs_minute, "speed_index": _speed_index}


## Loads a saved instant. Emits `day_passed` and `season_changed` afterwards so everything that
## tracks the calendar — weather, the sky, the seasonal materials — resyncs to the loaded date
## rather than holding whatever it last computed.
func deserialize(data: Dictionary) -> void:
	_abs_minute = float(data.get("abs_minute", 0.0))
	_speed_index = int(data.get("speed_index", 0))
	day_passed.emit(day_of_year())
	season_changed.emit(season())


# --- internals -------------------------------------------------------------------------

## Days since the epoch measured from Jan 1 of the start year, so month/year maths is uniform.
func _absolute_day_index() -> int:
	return _start_day_index + total_days()


func _absolute_day_index_at(minute: int) -> int:
	@warning_ignore("integer_division")
	return _start_day_index + minute / _minutes_per_day


func _day_index_at(minute: int) -> int:
	return _absolute_day_index_at(minute)


func _days_crossed(before: int, after: int) -> int:
	@warning_ignore("integer_division")
	return after / _minutes_per_day - before / _minutes_per_day


func _month_for_day(day_of_year_value: int) -> int:
	var day := day_of_year_value
	for m in _month_lengths.size():
		if day <= _month_lengths[m]:
			return m + 1
		day -= _month_lengths[m]
	return _month_lengths.size()


## The season a day of year falls in, using the `time.season_start_days` boundaries. Winter
## wraps the year end, so it is whatever is left once the other three are placed.
func _season_for_day(day_of_year_value: int) -> int:
	var spring_start := _season_start_days[Season.SPRING]
	var summer_start := _season_start_days[Season.SUMMER]
	var autumn_start := _season_start_days[Season.AUTUMN]
	var winter_start := _season_start_days[Season.WINTER]
	if day_of_year_value >= winter_start or day_of_year_value < spring_start:
		return Season.WINTER
	if day_of_year_value < summer_start:
		return Season.SPRING
	if day_of_year_value < autumn_start:
		return Season.SUMMER
	return Season.AUTUMN


func _int_array(path: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for value in Tuning.get_array(path):
		out.append(int(value))
	return out


func _float_array(path: String) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for value in Tuning.get_array(path):
		out.append(float(value))
	return out
