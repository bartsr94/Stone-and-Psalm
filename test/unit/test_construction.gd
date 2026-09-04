## Pure arithmetic, no autoloads: the frost gate and the labour-progress maths,
## `SIMULATION_SPEC.md` §11.
extends GutTest


func test_no_mortar_required_is_never_frost_blocked() -> void:
	assert_false(Construction.frost_blocks_progress(false, -15.0, 2.0), "timber framing works through any winter")


func test_mortar_blocks_below_the_threshold() -> void:
	assert_true(Construction.frost_blocks_progress(true, 1.0, 2.0))


func test_mortar_does_not_block_at_or_above_the_threshold() -> void:
	assert_false(Construction.frost_blocks_progress(true, 2.0, 2.0), "the threshold itself is not blocked")
	assert_false(Construction.frost_blocks_progress(true, 10.0, 2.0))


func test_progress_delta_is_hours_times_skill_over_total() -> void:
	assert_almost_eq(Construction.progress_delta(10.0, 1.0, 100.0), 0.1, 0.0001)


func test_progress_delta_scales_with_skill_factor() -> void:
	assert_almost_eq(Construction.progress_delta(10.0, 0.5, 100.0), 0.05, 0.0001)


func test_apply_progress_accumulates() -> void:
	assert_almost_eq(Construction.apply_progress(0.2, 10.0, 1.0, 100.0), 0.3, 0.0001)


func test_apply_progress_clamps_at_complete() -> void:
	assert_almost_eq(Construction.apply_progress(0.95, 10.0, 1.0, 100.0), 1.0, 0.0001)


func test_zero_total_hours_completes_immediately() -> void:
	assert_almost_eq(Construction.apply_progress(0.0, 0.0, 1.0, 0.0), 1.0, 0.0001)
