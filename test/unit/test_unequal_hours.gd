## Unequal hours: daylight in twelve parts, the night in four, and the seven day offices pinned
## to their canonical horae. Cross-checked against the SIMULATION_SPEC.md §2.3 figures at 54°N.
extends GutTest

const LAT := 54.0
const TILT := 23.44
const NOON := 720.0


func _daylight(day: int) -> float:
	return Daylight.daylight_minutes(day, LAT, TILT)


func _sunrise(day: int) -> float:
	return Daylight.sunrise_minute(day, LAT, TILT, NOON)


func test_hour_length_matches_the_spec_figures() -> void:
	assert_almost_eq(UnequalHours.hour_length(_daylight(172)), 84.0, 2.0, "midsummer hour ~84 min")
	assert_almost_eq(UnequalHours.hour_length(_daylight(80)), 60.0, 2.0, "equinox hour ~60 min")
	assert_almost_eq(UnequalHours.hour_length(_daylight(355)), 36.0, 2.0, "midwinter hour ~36 min")


func test_day_and_night_hours_fill_the_day() -> void:
	for day in [10, 100, 200, 300]:
		var daylight := _daylight(day)
		var total := UnequalHours.hour_length(daylight) * 12.0 + UnequalHours.watch_length(daylight) * 4.0
		assert_almost_eq(total, 1440.0, 0.001, "12 day hours + 4 watches = a full day on day %d" % day)


func test_first_hour_starts_at_sunrise_and_the_seventh_at_noon() -> void:
	var daylight := _daylight(80)
	var sunrise := _sunrise(80)
	assert_almost_eq(UnequalHours.hour_start(sunrise, daylight, 1), sunrise, 0.001, "hour 1 is sunrise")
	assert_almost_eq(
		UnequalHours.hour_start(sunrise, daylight, 7), NOON, 0.5,
		"the 7th hour begins at solar noon"
	)


func test_watches_start_at_sunset_and_span_the_night() -> void:
	var daylight := _daylight(355)
	var sunset := Daylight.sunset_minute(355, LAT, TILT, NOON)
	assert_almost_eq(UnequalHours.watch_start(sunset, daylight, 1), sunset, 0.001, "watch 1 is sunset")
	var fourth_end := UnequalHours.watch_start(sunset, daylight, 4) + UnequalHours.watch_length(daylight)
	assert_almost_eq(fourth_end, sunset + (1440.0 - daylight), 0.001, "four watches span the whole night")


func test_the_seven_day_offices_run_in_order_from_sunrise_to_sunset() -> void:
	var daylight := _daylight(172)
	var sunrise := _sunrise(172)
	var minutes := UnequalHours.day_office_minutes(sunrise, daylight)

	var ordered := [
		UnequalHours.Office.LAUDS, UnequalHours.Office.PRIME, UnequalHours.Office.TERCE,
		UnequalHours.Office.SEXT, UnequalHours.Office.NONE, UnequalHours.Office.VESPERS,
		UnequalHours.Office.COMPLINE,
	]
	for i in ordered.size() - 1:
		assert_lt(
			float(minutes[ordered[i]]), float(minutes[ordered[i + 1]]),
			"office %d comes before office %d" % [ordered[i], ordered[i + 1]]
		)

	assert_almost_eq(float(minutes[UnequalHours.Office.LAUDS]), sunrise, 0.001, "Lauds at first light")
	assert_almost_eq(
		float(minutes[UnequalHours.Office.SEXT]), NOON, 0.5, "Sext at midday"
	)
	assert_almost_eq(
		float(minutes[UnequalHours.Office.COMPLINE]),
		Daylight.sunset_minute(172, LAT, TILT, NOON), 0.5,
		"Compline at nightfall"
	)


func test_prime_is_one_unequal_hour_after_sunrise() -> void:
	var daylight := _daylight(355)
	var sunrise := _sunrise(355)
	var prime := UnequalHours.canonical_minute(UnequalHours.Office.PRIME, sunrise, daylight)
	assert_almost_eq(prime - sunrise, UnequalHours.hour_length(daylight), 0.001, "Prime = sunrise + 1 hour")


func test_vigils_is_placed_backward_from_dawn() -> void:
	var sunrise := _sunrise(172)
	var start := UnequalHours.vigils_start(sunrise, 110.0)
	assert_almost_eq(start, sunrise - 110.0, 0.001, "Vigils ends as Lauds begins")
