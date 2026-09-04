## The solar model reproduces the daylight table in SIMULATION_SPEC.md §2.2 at 54°N, and the
## sun rises in the east, crosses due south, and sets in the west.
##
## The three reference days are the ones the spec pins, tolerance ±2 minutes. Everything about
## the winter economy depends on this curve being right.
extends GutTest

const LATITUDE := 54.0
const TILT := 23.44
const NOON := 720.0
const TOLERANCE_MIN := 2.0


func _daylight(day: int) -> float:
	return Daylight.daylight_minutes(day, LATITUDE, TILT)


func _sunrise(day: int) -> float:
	return Daylight.sunrise_minute(day, LATITUDE, TILT, NOON)


func _sunset(day: int) -> float:
	return Daylight.sunset_minute(day, LATITUDE, TILT, NOON)


func test_midsummer_day_172() -> void:
	assert_almost_eq(_daylight(172), 16.0 * 60.0 + 53.0, TOLERANCE_MIN, "16 h 53 m of daylight")
	assert_almost_eq(_sunrise(172), 3.0 * 60.0 + 34.0, TOLERANCE_MIN, "sunrise 03:34")
	assert_almost_eq(_sunset(172), 20.0 * 60.0 + 26.0, TOLERANCE_MIN, "sunset 20:26")
	assert_almost_eq(_daylight(172) / 12.0, 84.0, TOLERANCE_MIN, "the unequal hour is ~84 min")


func test_equinox_day_80() -> void:
	assert_almost_eq(_daylight(80), 11.0 * 60.0 + 55.0, TOLERANCE_MIN, "11 h 55 m of daylight")
	assert_almost_eq(_sunrise(80), 6.0 * 60.0 + 2.0, TOLERANCE_MIN, "sunrise 06:02")
	assert_almost_eq(_sunset(80), 17.0 * 60.0 + 58.0, TOLERANCE_MIN, "sunset 17:58")
	assert_almost_eq(_daylight(80) / 12.0, 60.0, TOLERANCE_MIN, "the unequal hour is ~60 min")


func test_midwinter_day_355() -> void:
	assert_almost_eq(_daylight(355), 7.0 * 60.0 + 6.0, TOLERANCE_MIN, "7 h 06 m of daylight")
	assert_almost_eq(_sunrise(355), 8.0 * 60.0 + 27.0, TOLERANCE_MIN, "sunrise 08:27")
	assert_almost_eq(_sunset(355), 15.0 * 60.0 + 33.0, TOLERANCE_MIN, "sunset 15:33")
	assert_almost_eq(_daylight(355) / 12.0, 36.0, TOLERANCE_MIN, "the unequal hour is ~36 min")


func test_daylight_is_symmetric_about_solar_noon() -> void:
	for day in [10, 100, 200, 300]:
		assert_almost_eq(
			NOON - _sunrise(day), _sunset(day) - NOON, 0.001,
			"sunrise and sunset are mirrored across noon on day %d" % day
		)


func test_declination_signs_track_the_seasons() -> void:
	assert_almost_eq(Daylight.declination_deg(172, TILT), 23.44, 0.5, "midsummer sun is highest")
	assert_almost_eq(Daylight.declination_deg(355, TILT), -23.44, 0.5, "midwinter sun is lowest")
	assert_almost_eq(Daylight.declination_deg(81, TILT), 0.0, 0.1, "spring equinox is day 81")


func test_noon_altitude_is_high_in_summer_and_low_in_winter() -> void:
	var summer := Daylight.solar_altitude_deg(172, NOON, LATITUDE, TILT, NOON)
	var winter := Daylight.solar_altitude_deg(355, NOON, LATITUDE, TILT, NOON)
	assert_almost_eq(summer, 59.4, 1.0, "midsummer noon sun ~59° up")
	assert_almost_eq(winter, 12.6, 1.0, "midwinter noon sun ~13° up")
	assert_lt(winter, summer)


func test_altitude_is_near_zero_at_sunrise_and_negative_at_night() -> void:
	var at_sunrise := Daylight.solar_altitude_deg(172, _sunrise(172), LATITUDE, TILT, NOON)
	assert_almost_eq(at_sunrise, 0.0, 1.0, "the sun is on the horizon at sunrise")
	var at_midnight := Daylight.solar_altitude_deg(172, 0.0, LATITUDE, TILT, NOON)
	assert_lt(at_midnight, 0.0, "the sun is below the horizon at midnight")


func test_azimuth_sweeps_east_to_south_to_west() -> void:
	var morning := Daylight.solar_azimuth_deg(172, 6.0 * 60.0, LATITUDE, TILT, NOON)
	var noon := Daylight.solar_azimuth_deg(172, NOON, LATITUDE, TILT, NOON)
	var evening := Daylight.solar_azimuth_deg(172, 18.0 * 60.0, LATITUDE, TILT, NOON)
	assert_between(morning, 45.0, 135.0, "morning sun is in the east")
	assert_almost_eq(noon, 180.0, 1.0, "the sun is due south at solar noon")
	assert_between(evening, 225.0, 315.0, "evening sun is in the west")


func test_polar_clamp_keeps_the_function_total() -> void:
	# 78°N in high summer: the sun never sets. The arc must clamp rather than feed acos a value
	# outside [-1, 1].
	var arctic_daylight := Daylight.daylight_minutes(172, 78.0, TILT)
	assert_almost_eq(arctic_daylight, 1440.0, 0.001, "a full day of daylight, not a NaN")
