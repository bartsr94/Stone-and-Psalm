## Weather is seasonally driven, three-day smoothed, and fully deterministic from its injected
## dice. These tests step it with `roll_day` directly rather than through the clock.
extends GutTest


func before_each() -> void:
	Weather.set_dice(Dice.new(4321))


func _series(seed_value: int, days: Array) -> Array:
	Weather.set_dice(Dice.new(seed_value))
	var out: Array = []
	for day in days:
		Weather.roll_day(day)
		out.append([Weather.temperature_c(), Weather.precip_amount(), Weather.sky()])
	return out


func test_same_seed_gives_the_same_weather() -> void:
	var days := [10, 40, 70, 100, 130, 160, 190]
	assert_eq(_series(555, days), _series(555, days), "reproducible from the seed")


func test_a_different_seed_gives_different_weather() -> void:
	var days := [10, 40, 70, 100, 130]
	assert_ne(_series(1, days), _series(2, days))


func test_winter_is_colder_than_summer() -> void:
	Weather.set_dice(Dice.new(88))
	var winter_total := 0.0
	for _i in 30:
		Weather.roll_day(20)
		winter_total += Weather.temperature_c()

	Weather.set_dice(Dice.new(88))
	var summer_total := 0.0
	for _i in 30:
		Weather.roll_day(203)
		summer_total += Weather.temperature_c()

	assert_lt(winter_total / 30.0, 4.0, "winter averages near the winter mean")
	assert_gt(summer_total / 30.0, 12.0, "summer averages near the summer mean")


func test_precipitation_falls_as_snow_when_cold_and_rain_when_mild() -> void:
	# Per roll_day the dice are drawn: temp noise, precip noise, then the precipitation check.
	Weather.set_dice(ScriptedDice.new([0.4, 0.5, 0.05]))
	Weather.roll_day(20)
	assert_eq(Weather.sky(), Weather.Condition.SNOW, "a cold wet day snows")
	assert_true(Weather.is_snowing())

	Weather.set_dice(ScriptedDice.new([0.5, 0.5, 0.05]))
	Weather.roll_day(200)
	assert_eq(Weather.sky(), Weather.Condition.RAIN, "a mild wet day rains")


func test_a_dry_draw_leaves_the_sky_clear() -> void:
	Weather.set_dice(ScriptedDice.new([0.5, 0.5, 0.99]))
	Weather.roll_day(200)
	assert_eq(Weather.sky(), Weather.Condition.CLEAR)
	assert_almost_eq(Weather.precip_amount(), 0.0, 0.0001, "nothing falling")


func test_hard_frost_when_the_baseline_and_noise_both_push_down() -> void:
	# temp noise 0.0 -> the coldest end of the variation band, on the coldest day.
	Weather.set_dice(ScriptedDice.new([0.0, 0.5, 0.99]))
	Weather.roll_day(20)
	assert_true(Weather.is_frost(), "below freezing")
	assert_true(Weather.is_hard_frost(), "and below the hard-frost threshold")


func test_three_day_smoothing_averages_recent_days() -> void:
	# Feed three days whose temp noise is min, mid, max; the reading is their mean, not the last.
	Weather.set_dice(ScriptedDice.new([0.0, 0.5, 0.99, 0.5, 0.5, 0.99, 1.0, 0.5, 0.99]))
	Weather.roll_day(100)
	var after_one := Weather.temperature_c()
	Weather.roll_day(100)
	Weather.roll_day(100)
	var after_three := Weather.temperature_c()
	assert_ne(after_one, after_three, "the window fills and the average shifts")
	# Day 100 baseline with noise -4.5, 0, +4.5 averages back to roughly the baseline.
	assert_almost_eq(after_three, after_one + 4.5, 0.001, "mean of the three noise offsets")


func test_serialize_round_trip() -> void:
	Weather.set_dice(Dice.new(2024))
	for day in [15, 45, 75]:
		Weather.roll_day(day)
	var saved := Weather.serialize()
	var temp := Weather.temperature_c()

	Weather.set_dice(Dice.new(1))
	Weather.roll_day(200)
	assert_ne(Weather.temperature_c(), temp, "state moved on")

	Weather.deserialize(saved)
	assert_almost_eq(Weather.temperature_c(), temp, 0.0001, "restored")
