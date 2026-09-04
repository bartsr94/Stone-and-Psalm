## The season curve brackets a day between the two keyframes it falls between, loops cleanly
## across the year end, and stays continuous through 31 December → 1 January.
extends GutTest

const PEAKS := [20, 105, 195, 288]  # winter, spring, summer, autumn peak days


func test_a_day_on_a_peak_sits_exactly_on_that_keyframe() -> void:
	var winter := SeasonCurve.blend(20, PEAKS)
	assert_eq(winter["from"], 0)
	assert_almost_eq(winter["t"], 0.0, 0.0001)

	var summer := SeasonCurve.blend(195, PEAKS)
	assert_eq(summer["from"], 2)
	assert_almost_eq(summer["t"], 0.0, 0.0001)


func test_a_day_between_peaks_blends_the_two() -> void:
	# Halfway between winter (20) and spring (105) is day 62 (span 85).
	var b := SeasonCurve.blend(62, PEAKS)
	assert_eq(b["from"], 0)
	assert_eq(b["to"], 1)
	assert_almost_eq(b["t"], (62.0 - 20.0) / 85.0, 0.0001)


func test_the_wrapping_segment_covers_both_sides_of_new_year() -> void:
	var december := SeasonCurve.blend(300, PEAKS)
	assert_eq(december["from"], 3, "autumn keyframe")
	assert_eq(december["to"], 0, "blending toward winter")
	assert_almost_eq(december["t"], (300.0 - 288.0) / 97.0, 0.0001)

	var january := SeasonCurve.blend(10, PEAKS)
	assert_eq(january["from"], 3)
	assert_eq(january["to"], 0)
	assert_almost_eq(january["t"], (375.0 - 288.0) / 97.0, 0.0001)


func test_blend_factor_is_continuous_across_the_year_boundary() -> void:
	var last_day: float = SeasonCurve.blend(365, PEAKS)["t"]
	var first_day: float = SeasonCurve.blend(1, PEAKS)["t"]
	assert_almost_eq(first_day - last_day, 1.0 / 97.0, 0.0001, "one day's worth of change, no jump")


func test_lerp_scalar_interpolates_between_keyframe_values() -> void:
	var snow := [0.85, 0.10, 0.0, 0.0]  # snow coverage per season keyframe
	assert_almost_eq(SeasonCurve.lerp_scalar(20, PEAKS, snow), 0.85, 0.0001, "deep winter")
	assert_almost_eq(SeasonCurve.lerp_scalar(195, PEAKS, snow), 0.0, 0.0001, "high summer")
	var mid := SeasonCurve.lerp_scalar(62, PEAKS, snow)
	assert_almost_eq(mid, lerpf(0.85, 0.10, (62.0 - 20.0) / 85.0), 0.0001, "melting through spring")


func test_lerp_color_interpolates_between_keyframe_colours() -> void:
	var tints := [Color.WHITE, Color(0.4, 0.7, 0.3), Color(0.5, 0.6, 0.25), Color(0.7, 0.5, 0.2)]
	var deep_winter := SeasonCurve.lerp_color(20, PEAKS, tints)
	assert_almost_eq(deep_winter.r, 1.0, 0.0001)
	assert_almost_eq(deep_winter.g, 1.0, 0.0001)


func test_out_of_range_days_wrap_into_the_year() -> void:
	assert_eq(SeasonCurve.blend(366, PEAKS)["from"], SeasonCurve.blend(1, PEAKS)["from"])
	assert_eq(SeasonCurve.blend(0, PEAKS)["from"], SeasonCurve.blend(365, PEAKS)["from"])
