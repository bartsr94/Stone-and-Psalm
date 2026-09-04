## Pure arithmetic, no autoloads: recipe-batch labour progress, `SIMULATION_SPEC.md` §9. Same
## shape as `test_construction.gd` — this is `Construction`'s progress maths mirrored for a
## recipe batch rather than a building.
extends GutTest


func test_progress_delta_is_hours_times_skill_over_total() -> void:
	assert_almost_eq(RecipeProgress.progress_delta(2.0, 1.0, 4.0), 0.5, 0.0001)


func test_progress_delta_scales_with_skill_factor() -> void:
	assert_almost_eq(RecipeProgress.progress_delta(2.0, 0.5, 4.0), 0.25, 0.0001)


func test_apply_progress_accumulates() -> void:
	assert_almost_eq(RecipeProgress.apply_progress(0.25, 1.0, 1.0, 4.0), 0.5, 0.0001)


func test_apply_progress_clamps_at_complete() -> void:
	assert_almost_eq(RecipeProgress.apply_progress(0.9, 1.0, 1.0, 4.0), 1.0, 0.0001)


func test_zero_total_hours_completes_immediately() -> void:
	assert_almost_eq(RecipeProgress.apply_progress(0.0, 0.0, 1.0, 0.0), 1.0, 0.0001)
