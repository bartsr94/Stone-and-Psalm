## The season blender resolves data/seasons.json into a concrete parameter set, lerping scalars
## and colours between the two bracketing keyframes and looping across the year end.
extends GutTest

var _blender: SeasonBlender


func before_all() -> void:
	_blender = SeasonBlender.new()


func test_config_loads_with_four_keyframes() -> void:
	assert_true(_blender.is_loaded(), "data/seasons.json parsed")
	assert_eq(_blender.peak_days(), [20, 105, 195, 288], "winter, spring, summer, autumn peaks")


func test_a_day_on_a_peak_returns_that_keyframe() -> void:
	var winter := _blender.sample(20)
	assert_eq(winter["season_name"], "winter")
	assert_almost_eq(winter["snow_coverage"], 0.90, 0.0001, "deep winter is fully covered")
	assert_true(winter["broadleaf_bare"], "broadleaves are bare in winter")

	var summer := _blender.sample(195)
	assert_eq(summer["season_name"], "summer")
	assert_almost_eq(summer["snow_coverage"], 0.0, 0.0001, "no snow in high summer")
	assert_false(summer["broadleaf_bare"])


func test_scalars_interpolate_between_keyframes() -> void:
	# Day 62 is halfway (span 85) between the winter (20) and spring (105) peaks.
	var mid := _blender.sample(62)
	var expected_snow := lerpf(0.90, 0.06, (62.0 - 20.0) / 85.0)
	assert_almost_eq(mid["snow_coverage"], expected_snow, 0.0001, "snow melting through spring")
	assert_between(mid["sun_energy_scale"], 0.72, 1.00, "sun strengthens from winter to spring")


func test_colours_resolve_to_color_values() -> void:
	var state := _blender.sample(105)
	assert_true(state["fog_color"] is Color, "fog_color is parsed from hex")
	assert_true(state["sun_tint"] is Color)
	assert_true(state["water_color"] is Color)


func test_sampling_wraps_across_the_year_end() -> void:
	# Early in the autumn->winter segment: still nearer autumn, leaves not yet dropped.
	var december := _blender.sample(300)
	assert_eq(december["season_name"], "autumn")
	assert_false(december["broadleaf_bare"])
	assert_between(december["snow_coverage"], 0.0, 0.90, "snow accumulating toward winter")

	# Late in the same segment: nearer the winter keyframe, leaves dropped.
	var deep := _blender.sample(360)
	assert_eq(deep["season_name"], "winter")
	assert_true(deep["broadleaf_bare"])


func test_out_of_range_days_do_not_crash() -> void:
	assert_false(_blender.sample(0).is_empty(), "day 0 wraps to 365")
	assert_false(_blender.sample(400).is_empty(), "day 400 wraps into the year")
