## The liturgical calendar and the day it dictates. `SIMULATION_SPEC.md` §2.4 and §6.
##
## Authoritative, headless, no scene tree. It is a pure lookup over `data/liturgical_calendar.json`
## plus the `Computus` and `Daylight` calculators — it holds no state of its own, so `serialize`
## is empty. The one thing it needs the running world for is the weekday, which it takes from
## the same epoch as `SimClock`.
##
## The signature method is `day_plan(person_class, order, year, day_of_year)`: it places the
## eight offices on the unequal-hour scaffold, subtracts the chapter, the Masses, lectio, meals
## and sleep, and hands back the work blocks — the spans left for manual labour, and how much
## of that falls in daylight. `SIMULATION_SPEC.md` §6.1.
extends Node

const CONFIG_PATH := "res://data/liturgical_calendar.json"
const _RANK_ORDER := ["ferial", "simplex", "duplex", "duplex_maius", "solemnity"]
const _OFFICE_KEYS := ["vigils", "lauds", "prime", "terce", "sext", "none", "vespers", "compline"]

var _config: Dictionary = {}
var _latitude: float = 54.0
var _tilt: float = 23.44
var _solar_noon: float = 720.0
var _start_year: int = 1132
var _start_doy: int = 75
var _start_dow: int = 3
var _days_per_year: int = 365


func _ready() -> void:
	var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("Liturgy: cannot open %s" % CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		_config = parsed
	else:
		push_error("Liturgy: %s is not a JSON object" % CONFIG_PATH)

	_latitude = Tuning.get_num("world.latitude_deg")
	_tilt = Tuning.get_num("sky.axial_tilt_deg")
	_solar_noon = Tuning.get_num("sky.solar_noon_minute")
	_start_year = Tuning.get_int("time.start_year")
	_start_doy = Tuning.get_int("time.start_day_of_year")
	_start_dow = Tuning.get_int("time.start_day_of_week")
	_days_per_year = Tuning.get_int("time.days_per_year")


# --- the calendar ----------------------------------------------------------------------

## Weekday of a date, 0 = Sunday, on the same anchor as `SimClock.day_of_week`.
func weekday(year: int, day_of_year: int) -> int:
	var absolute := (year - _start_year) * _days_per_year + (day_of_year - _start_doy)
	return posmod(_start_dow + absolute, 7)


func is_sunday(year: int, day_of_year: int) -> bool:
	return weekday(year, day_of_year) == 0


## Advent Sunday: the fourth Sunday before Christmas (25 December = day 359).
func advent_sunday(year: int) -> int:
	var christmas := Computus.month_day_to_day_of_year(12, 25)
	return christmas - weekday(year, christmas) - 21


func is_in_advent(year: int, day_of_year: int) -> bool:
	return day_of_year >= advent_sunday(year) and day_of_year <= Computus.month_day_to_day_of_year(12, 24)


## A fast day: every Friday, all of Lent, and all of Advent. `SIMULATION_SPEC.md` §2.4.
func is_fast_day(year: int, day_of_year: int) -> bool:
	if weekday(year, day_of_year) == 5:
		return true
	if Computus.is_in_lent(year, day_of_year):
		return true
	return is_in_advent(year, day_of_year)


## The feast falling on a date, as `{name, rank}`. The highest-ranked one wins; a plain day is
## `{name = "", rank = "ferial"}`. A Sunday with no feast is `{name = "Sunday", rank = "simplex"}`.
func feast_for_day(year: int, day_of_year: int) -> Dictionary:
	var best := {"name": "", "rank": "ferial"}

	for entry in _config.get("fixed_feasts", []):
		var doy := Computus.month_day_to_day_of_year(int(entry["month"]), int(entry["day"]))
		if doy == day_of_year and _rank_index(entry["rank"]) > _rank_index(best["rank"]):
			best = {"name": entry["name"], "rank": entry["rank"]}

	for entry in _config.get("moveable_feasts", []):
		var feast: int = Computus.Feast[entry["feast"]]
		var doy := Computus.feast_day_of_year(year, feast)
		if doy == day_of_year and _rank_index(entry["rank"]) > _rank_index(best["rank"]):
			best = {"name": entry["name"], "rank": entry["rank"]}

	if best["rank"] == "ferial" and is_sunday(year, day_of_year):
		return {"name": "Sunday", "rank": "simplex"}
	return best


func rank_for_day(year: int, day_of_year: int) -> String:
	return feast_for_day(year, day_of_year)["rank"]


## No manual labour today: a Sunday, or a feast of `duplex_maius` or higher. `SIMULATION_SPEC.md`
## §2.4 — "higher ranks further restrict labour".
func is_labour_restricted(year: int, day_of_year: int) -> bool:
	if is_sunday(year, day_of_year):
		return true
	var threshold := _rank_index(_config.get("labour_forbidden_from_rank", "duplex_maius"))
	return _rank_index(rank_for_day(year, day_of_year)) >= threshold


# --- offices ---------------------------------------------------------------------------

## The duration of one office for an order on a day of the given feast rank, in minutes.
func office_duration(order: Monastic.Order, office_key: String, rank: String) -> float:
	var tables: Dictionary = _config.get("office_durations_min", {})
	var order_table: Dictionary = tables.get(Monastic.order_key(order), tables.get("base", {}))
	var base: float = float(order_table.get(office_key, 0.0))
	var multiplier: float = float(_config.get("feast_rank_multiplier", {}).get(rank, 1.0))
	return base * multiplier


## The full day for a person: offices placed on the unequal-hour scaffold, everything else
## subtracted, and the work blocks that remain. See the class doc.
func day_plan(person_class: Monastic.Class, order: Monastic.Order, year: int, day_of_year: int) -> Dictionary:
	var daylight: float = Daylight.daylight_minutes(day_of_year, _latitude, _tilt)
	var sunrise: float = Daylight.sunrise_minute(day_of_year, _latitude, _tilt, _solar_noon)
	var sunset: float = Daylight.sunset_minute(day_of_year, _latitude, _tilt, _solar_noon)
	var rank := rank_for_day(year, day_of_year)
	var feast := feast_for_day(year, day_of_year)
	var restricted := is_labour_restricted(year, day_of_year)
	var fast := is_fast_day(year, day_of_year)
	var in_choir: bool = Monastic.is_choir(person_class)
	var attends_choir_today: bool = in_choir or (
		person_class == Monastic.Class.CONVERSUS
		and (is_sunday(year, day_of_year) or _rank_index(rank) >= _rank_index("duplex"))
	)

	# --- place the seven day offices, plus Vigils backward from dawn ---
	var day_minutes := UnequalHours.day_office_minutes(sunrise, daylight)
	var vigils_dur := office_duration(order, "vigils", rank)
	var vigils_block := vigils_dur + float(_config.get("vigils_to_lauds_gap_min", 20))
	var offices: Array = []
	if person_class != Monastic.Class.FAMULUS:
		offices.append(_office_entry("vigils", UnequalHours.vigils_start(sunrise, vigils_block), vigils_dur, attends_choir_today))
		var order_office := {
			"lauds": UnequalHours.Office.LAUDS, "prime": UnequalHours.Office.PRIME,
			"terce": UnequalHours.Office.TERCE, "sext": UnequalHours.Office.SEXT,
			"none": UnequalHours.Office.NONE, "vespers": UnequalHours.Office.VESPERS,
			"compline": UnequalHours.Office.COMPLINE,
		}
		for key in order_office:
			var start: float = day_minutes[order_office[key]]
			offices.append(_office_entry(key, start, office_duration(order, key, rank), attends_choir_today))

	# --- build the busy intervals during the waking working day ---
	var busy: Array = []
	var conversus_short := float(_config.get("conversus_workplace_office_min", 10))
	for entry in offices:
		if entry["attends"]:
			busy.append([entry["start_min"], entry["start_min"] + entry["duration_min"]])
	if person_class == Monastic.Class.CONVERSUS and not attends_choir_today:
		# One short memorised office at the workplace, mid-morning.
		var terce_min: float = day_minutes[UnequalHours.Office.TERCE]
		busy.append([terce_min, terce_min + conversus_short])

	var add: Dictionary = _config.get("additional_offices_min", {})
	var lectio_min := 0.0
	if in_choir:
		# Chapter after Prime, morrow Mass after Terce, High Mass on Sundays and feasts.
		var prime_end: float = _end_of("prime", offices)
		busy.append([prime_end, prime_end + float(add.get("chapter", 30))])
		var terce_end: float = _end_of("terce", offices)
		busy.append([terce_end, terce_end + float(add.get("morrow_mass", 30))])
		if is_sunday(year, day_of_year) or _rank_index(rank) >= _rank_index("duplex"):
			busy.append([terce_end + float(add.get("morrow_mass", 30)),
				terce_end + float(add.get("morrow_mass", 30)) + float(add.get("high_mass", 45))])
		# Lectio: two chunks, morning and afternoon.
		lectio_min = float(_config.get("lectio_min", {}).get(
			"lent" if Computus.is_in_lent(year, day_of_year) else "ferial", 180))
		var none_end: float = _end_of("none", offices)
		busy.append([_solar_noon - lectio_min * 0.6 - 30.0, _solar_noon - 30.0])
		busy.append([none_end + 15.0, none_end + 15.0 + lectio_min * 0.4])

	# Meals: main meal after Sext; collation after Vespers, but not on a fast day.
	if person_class != Monastic.Class.FAMULUS:
		var meals: Dictionary = _config.get("meal_min", {})
		var sext_end: float = _end_of("sext", offices) if in_choir else _solar_noon
		busy.append([sext_end, sext_end + float(meals.get("main", 40))])
		if not fast:
			var vespers_end: float = _end_of("vespers", offices) if not offices.is_empty() else sunset
			busy.append([vespers_end, vespers_end + float(meals.get("collation", 20))])

	# --- the waking window, and the free spans within it ---
	var night_sleep := float(_config.get("night_sleep_min", 420))
	var window_start: float = sunrise if person_class == Monastic.Class.FAMULUS else _end_of("lauds", offices)
	if is_nan(window_start) or window_start <= 0.0:
		window_start = sunrise
	var window_end: float = minf(window_start + (1440.0 - night_sleep), 1439.0)

	var work_blocks := Horarium.free_spans(busy, window_start, window_end, 10.0)
	if restricted:
		work_blocks = []

	# --- the headline budget (SIMULATION_SPEC.md §6.4 arithmetic) ---
	var total_office := 0.0
	for entry in offices:
		if entry["attends"]:
			total_office += entry["duration_min"]
	var additional_total := 0.0
	if in_choir:
		additional_total = float(add.get("chapter", 30)) + float(add.get("morrow_mass", 30))
		if is_sunday(year, day_of_year) or _rank_index(rank) >= _rank_index("duplex"):
			additional_total += float(add.get("high_mass", 45))
	var meal_total := float(_config.get("meal_min", {}).get("main", 40))
	if not fast and person_class != Monastic.Class.FAMULUS:
		meal_total += float(_config.get("meal_min", {}).get("collation", 20))
	var labour_budget := 1440.0 - total_office - additional_total - lectio_min - night_sleep - meal_total
	if restricted:
		labour_budget = 0.0

	var free_daylight := Horarium.daylight_minutes(work_blocks, sunrise, sunset)
	var daylight_labour := minf(labour_budget, free_daylight)

	return {
		"year": year, "day_of_year": day_of_year,
		"daylight_min": daylight, "hour_length_min": UnequalHours.hour_length(daylight),
		"sunrise_min": sunrise, "sunset_min": sunset,
		"feast_name": feast["name"], "rank": rank,
		"is_sunday": is_sunday(year, day_of_year), "is_fast_day": fast,
		"labour_restricted": restricted,
		"offices": offices,
		"work_blocks": work_blocks,
		"lectio_min": lectio_min,
		"labour_budget_min": maxf(labour_budget, 0.0),
		"work_span_min": Horarium.total_minutes(work_blocks),
		"daylight_labour_min": maxf(daylight_labour, 0.0),
		"longest_block_min": Horarium.longest_span(work_blocks),
	}


func serialize() -> Dictionary:
	return {}


func deserialize(_data: Dictionary) -> void:
	pass


# --- internal -----------------------------------------------------------------------

func _rank_index(rank: Variant) -> int:
	var i := _RANK_ORDER.find(str(rank))
	return i if i >= 0 else 0


func _office_entry(key: String, start_min: float, duration_min: float, attends: bool) -> Dictionary:
	return {"key": key, "start_min": start_min, "duration_min": duration_min, "attends": attends}


func _end_of(key: String, offices: Array) -> float:
	for entry in offices:
		if entry["key"] == key:
			return entry["start_min"] + entry["duration_min"]
	return NAN
