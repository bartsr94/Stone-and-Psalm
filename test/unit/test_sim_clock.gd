## The authoritative clock keeps year, month, day, weekday and minute-of-day in agreement, and
## emits each boundary exactly once.
##
## `SimClock` is an autoload singleton, so every test resets it through `deserialize` rather
## than depending on the order tests run in. The founding epoch is AD 1132, day-of-year 75 —
## Wednesday 16 March — set in `data/tuning.json`.
extends GutTest


func before_each() -> void:
	SimClock.deserialize({"abs_minute": 0.0, "speed_index": 0})


func test_starts_paused_at_the_founding_epoch() -> void:
	assert_true(SimClock.is_paused(), "the clock does not run until something starts it")
	assert_eq(SimClock.speed_index(), 0)
	assert_eq(SimClock.year(), 1132)
	assert_eq(SimClock.day_of_year(), 75)
	assert_eq(SimClock.month(), 3, "day 75 is in March")
	assert_eq(SimClock.day_of_month(), 16, "31 + 28 + 16 = 75")
	assert_eq(SimClock.day_of_week(), 3, "Wednesday")
	assert_eq(SimClock.minute_of_day(), 0)


func test_minutes_accumulate_and_floor() -> void:
	SimClock.advance_minutes(0.6)
	SimClock.advance_minutes(0.6)
	assert_eq(SimClock.total_minutes(), 1, "fractional minutes accumulate, the reading floors")


func test_minute_of_day_and_time_string() -> void:
	SimClock.advance_minutes(90.0)
	assert_eq(SimClock.minute_of_day(), 90)
	assert_eq(SimClock.hour_of_day(), 1)
	assert_eq(SimClock.time_string(), "01:30")


func test_day_fraction_is_continuous() -> void:
	SimClock.advance_minutes(720.0)
	assert_almost_eq(SimClock.day_fraction(), 0.5, 0.0001, "noon is half the day")


func test_crossing_midnight_advances_the_calendar() -> void:
	SimClock.advance_minutes(1440.0)
	assert_eq(SimClock.day_of_year(), 76)
	assert_eq(SimClock.total_days(), 1)
	assert_eq(SimClock.day_of_week(), 4, "Wednesday + 1 = Thursday")
	assert_eq(SimClock.minute_of_day(), 0)


func test_advance_days_rolls_the_month() -> void:
	# Day 75 is 16 March (day 60 is 1 March); 16 more days reaches day 91, which is 1 April.
	SimClock.advance_days(16)
	assert_eq(SimClock.day_of_year(), 91)
	assert_eq(SimClock.month(), 4)
	assert_eq(SimClock.day_of_month(), 1)


func test_a_full_year_returns_to_the_same_date() -> void:
	SimClock.advance_days(365)
	assert_eq(SimClock.year(), 1133)
	assert_eq(SimClock.day_of_year(), 75)
	assert_eq(SimClock.month(), 3)


func test_seasons_follow_the_boundary_days() -> void:
	assert_eq(SimClock.season(), SimClock.Season.SPRING, "day 75 is spring")
	SimClock.advance_days(152 - 75)
	assert_eq(SimClock.season(), SimClock.Season.SUMMER, "day 152 is summer")
	SimClock.advance_days(244 - 152)
	assert_eq(SimClock.season(), SimClock.Season.AUTUMN, "day 244 is autumn")
	SimClock.advance_days(335 - 244)
	assert_eq(SimClock.season(), SimClock.Season.WINTER, "day 335 is winter")


func test_hour_passed_fires_once_per_hour_boundary() -> void:
	watch_signals(SimClock)
	SimClock.advance_minutes(59.0)
	assert_signal_not_emitted(SimClock, "hour_passed", "still inside the first hour")
	SimClock.advance_minutes(2.0)
	assert_signal_emitted_with_parameters(SimClock, "hour_passed", [1], 0)


func test_day_and_month_signals_fire_on_rollover() -> void:
	SimClock.advance_days(15)  # day 75 -> day 90, which is 31 March
	assert_eq(SimClock.day_of_month(), 31)
	assert_eq(SimClock.month(), 3)
	watch_signals(SimClock)
	SimClock.advance_days(1)  # to day 91, 1 April
	assert_signal_emitted_with_parameters(SimClock, "day_passed", [91], 0)
	assert_signal_emitted_with_parameters(SimClock, "month_passed", [4], 0)


func test_season_changed_fires_when_the_season_turns() -> void:
	SimClock.advance_days(152 - 75 - 1)  # day before summer starts
	watch_signals(SimClock)
	SimClock.advance_days(1)
	assert_signal_emitted_with_parameters(
		SimClock, "season_changed", [SimClock.Season.SUMMER], 0
	)


func test_speed_control() -> void:
	watch_signals(SimClock)
	SimClock.set_speed_index(2)
	assert_almost_eq(SimClock.speed_multiplier(), 3.0, 0.0001)
	assert_false(SimClock.is_paused())
	assert_signal_emitted_with_parameters(SimClock, "speed_changed", [2], 0)

	SimClock.set_speed_index(99)
	assert_eq(SimClock.speed_index(), 3, "clamped to the fastest speed")

	SimClock.cycle_speed()
	assert_eq(SimClock.speed_index(), 1, "cycling past the fastest wraps to 1x, not to pause")


func test_toggle_pause_restores_the_running_speed() -> void:
	SimClock.set_speed_index(3)
	SimClock.toggle_pause()
	assert_true(SimClock.is_paused())
	SimClock.toggle_pause()
	assert_eq(SimClock.speed_index(), 3, "resumes at the speed it was paused from")


func test_paused_clock_ignores_advance_from_zero_delta() -> void:
	SimClock.advance_minutes(0.0)
	SimClock.advance_minutes(-5.0)
	assert_eq(SimClock.total_minutes(), 0, "time never runs backwards")


func test_serialize_round_trip() -> void:
	SimClock.advance_days(40)
	SimClock.advance_minutes(613.0)
	SimClock.set_speed_index(2)
	var saved := SimClock.serialize()

	SimClock.deserialize({"abs_minute": 0.0, "speed_index": 0})
	assert_eq(SimClock.total_days(), 0, "reset landed")

	SimClock.deserialize(saved)
	assert_eq(SimClock.total_days(), 40)
	assert_eq(SimClock.minute_of_day(), 613)
	assert_eq(SimClock.speed_index(), 2)


func test_two_paths_to_the_same_instant_agree() -> void:
	SimClock.advance_minutes(1440.0 * 10.0 + 375.0)
	var one_jump := SimClock.date_string()

	SimClock.deserialize({"abs_minute": 0.0, "speed_index": 0})
	for _i in 10:
		SimClock.advance_days(1)
	SimClock.advance_minutes(375.0)
	assert_eq(SimClock.date_string(), one_jump, "many small steps land where one big step did")
