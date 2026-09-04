## Pure recipe-batch progress arithmetic, `SIMULATION_SPEC.md` §9. No state, no autoload
## dependency — `autoloads/production.gd` is the only caller.
##
## The same shape as `Construction`'s progress arithmetic (§11): a labour contribution as a
## fraction of a batch's total labour-hours. Kept as its own tiny calculator rather than reused
## from `Construction` — a recipe batch and a building's construction are different concepts that
## happen to share today's formula, and `Production` (the autoload) already needs the name
## `Production` for itself, so this could not be `class_name Production` even if reuse were
## wanted.
class_name RecipeProgress
extends RefCounted


## The fraction of a batch's total labour a contribution of `hours` at `skill_factor` represents.
## `skill_factor` is a placeholder 1.0 for everyone until Phase 6 gives people real skills.
static func progress_delta(hours: float, skill_factor: float, total_labour_hours: float) -> float:
	if total_labour_hours <= 0.0:
		return 1.0
	return (hours * skill_factor) / total_labour_hours


## Applies a labour contribution to existing progress, clamped to the [0, 1] a batch can be.
static func apply_progress(current_progress: float, hours: float, skill_factor: float, total_labour_hours: float) -> float:
	return clampf(current_progress + progress_delta(hours, skill_factor, total_labour_hours), 0.0, 1.0)
