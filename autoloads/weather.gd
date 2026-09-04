## Daily weather: temperature and precipitation, seasonally driven, three-day smoothed.
##
## Authoritative and headless. `SIMULATION_SPEC.md` open question 9 — weather is resolved once
## per day, not per hour. It draws from an injected `Dice` (`set_dice`), so a run is
## reproducible from a seed and the rolls survive a save.
##
## The seasonal baseline is a cosine through the year: coldest around `weather.coldest_day`,
## warmest half a year later, swinging between the winter and summer means in `data/tuning.json`.
## Precipitation runs on the same cosine with its own amplitude, wetter in winter. Each day adds
## bounded noise on top and the last three days are averaged, so the weather has runs of
## fair and foul rather than flickering day to day.
##
## Frost (`is_frost`) and hard frost (`is_hard_frost`) read off the smoothed temperature; the
## construction frost gate (`SIMULATION_SPEC.md` §11) will consume them in Phase 4.
extends Node

signal weather_changed

enum Condition { CLEAR, RAIN, SNOW }

const _TAU := PI * 2.0

var _dice: Dice = null

var _temp_history: Array[float] = []
var _precip_history: Array[float] = []
var _temperature_c: float = 8.0
var _precip_amount: float = 0.0
var _sky: int = Condition.CLEAR

var _smoothing_days: int = 3
var _temp_variation_c: float = 4.5
var _precip_variation: float = 0.22
var _freeze_point_c: float = 0.0
var _hard_frost_c: float = -3.0
var _coldest_day: int = 20
var _winter_temp: float = 1.5
var _summer_temp: float = 16.0
var _winter_precip: float = 0.42
var _summer_precip: float = 0.30
var _snow_below_temp_c: float = 1.0


func _ready() -> void:
	_smoothing_days = maxi(Tuning.get_int("weather.smoothing_days"), 1)
	_temp_variation_c = Tuning.get_num("weather.temp_variation_c")
	_precip_variation = Tuning.get_num("weather.precip_variation")
	_freeze_point_c = Tuning.get_num("weather.freeze_point_c")
	_hard_frost_c = Tuning.get_num("weather.hard_frost_c")
	_coldest_day = Tuning.get_int("weather.coldest_day_of_year")
	_winter_temp = Tuning.get_num("weather.winter_mean_temp_c")
	_summer_temp = Tuning.get_num("weather.summer_mean_temp_c")
	_winter_precip = Tuning.get_num("weather.winter_precip_chance")
	_summer_precip = Tuning.get_num("weather.summer_precip_chance")
	_snow_below_temp_c = Tuning.get_num("weather.snow_below_temp_c")

	_dice = Dice.new(Tuning.get_int("weather.rng_seed"))

	SimClock.day_passed.connect(_on_day_passed)
	roll_day(SimClock.day_of_year())


## Replaces the random stream. Call before the first day rolls (game start, or a test) so the
## sequence is under the caller's control. Clears the smoothing history so the new stream
## starts clean.
func set_dice(dice: Dice) -> void:
	_dice = dice
	_temp_history.clear()
	_precip_history.clear()


func _on_day_passed(day_of_year: int) -> void:
	roll_day(day_of_year)


## Resolves the weather for one day. Public so a headless test can step it without a clock.
func roll_day(day_of_year: int) -> void:
	if _dice == null:
		_dice = Dice.new(0)

	var raw_temp := _seasonal_temperature(day_of_year) + _dice.randf_range(
		-_temp_variation_c, _temp_variation_c
	)
	var raw_precip := clampf(
		_seasonal_precip_chance(day_of_year) + _dice.randf_range(-_precip_variation, _precip_variation),
		0.0, 1.0
	)

	_push(_temp_history, raw_temp)
	_push(_precip_history, raw_precip)

	_temperature_c = _mean(_temp_history)
	var smoothed_precip := _mean(_precip_history)

	if not _dice.chance(smoothed_precip):
		_sky = Condition.CLEAR
		_precip_amount = 0.0
	elif _temperature_c <= _snow_below_temp_c:
		_sky = Condition.SNOW
		_precip_amount = smoothed_precip
	else:
		_sky = Condition.RAIN
		_precip_amount = smoothed_precip

	weather_changed.emit()


# --- reading the weather ------------------------------------------------------------------

func temperature_c() -> float:
	return _temperature_c


## The three-day-smoothed chance of precipitation, 0…1. Also the intensity of whatever is
## currently falling.
func precip_amount() -> float:
	return _precip_amount


func sky() -> int:
	return _sky


func is_raining() -> bool:
	return _sky == Condition.RAIN


func is_snowing() -> bool:
	return _sky == Condition.SNOW


func is_frost() -> bool:
	return _temperature_c <= _freeze_point_c


func is_hard_frost() -> bool:
	return _temperature_c <= _hard_frost_c


func sky_string() -> String:
	match _sky:
		Condition.RAIN:
			return "Rain"
		Condition.SNOW:
			return "Snow"
		_:
			return "Clear"


# --- the seasonal baseline ---------------------------------------------------------------

## Mean temperature for a day: a cosine swinging from the winter mean at the coldest day to the
## summer mean half a year later.
func _seasonal_temperature(day_of_year: int) -> float:
	var midpoint := (_summer_temp + _winter_temp) * 0.5
	var amplitude := (_summer_temp - _winter_temp) * 0.5
	return midpoint - amplitude * cos(_TAU * float(day_of_year - _coldest_day) / 365.0)


## Mean precipitation chance for a day: the same cosine, wettest at the coldest day.
func _seasonal_precip_chance(day_of_year: int) -> float:
	var midpoint := (_winter_precip + _summer_precip) * 0.5
	var amplitude := (_winter_precip - _summer_precip) * 0.5
	return midpoint + amplitude * cos(_TAU * float(day_of_year - _coldest_day) / 365.0)


func _push(history: Array[float], value: float) -> void:
	history.push_back(value)
	while history.size() > _smoothing_days:
		history.pop_front()


func _mean(history: Array[float]) -> float:
	if history.is_empty():
		return 0.0
	var total := 0.0
	for value in history:
		total += value
	return total / float(history.size())


# --- save / load -----------------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"dice": _dice.serialize() if _dice != null else {},
		"temp_history": _temp_history.duplicate(),
		"precip_history": _precip_history.duplicate(),
		"temperature_c": _temperature_c,
		"precip_amount": _precip_amount,
		"sky": _sky,
	}


func deserialize(data: Dictionary) -> void:
	if _dice != null and data.has("dice"):
		_dice.deserialize(data["dice"])
	_temp_history.assign(data.get("temp_history", []))
	_precip_history.assign(data.get("precip_history", []))
	_temperature_c = float(data.get("temperature_c", 8.0))
	_precip_amount = float(data.get("precip_amount", 0.0))
	_sky = int(data.get("sky", Condition.CLEAR))
