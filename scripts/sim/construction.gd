## Pure construction-progress arithmetic, `SIMULATION_SPEC.md` §11. No state, no autoload
## dependency — `autoloads/buildings.gd` is the only caller, and it supplies `Weather` and
## `Tuning` values as plain arguments so this stays trivially unit-testable.
class_name Construction
extends RefCounted


## True when a stage requiring mortar cannot progress: the frost rule, "temperature < 2°C"
## (SIMULATION_SPEC.md §11), read off the already-simulated `Weather.temperature_c()` rather
## than a hardcoded calendar window (`data/tuning.json` "construction" comment explains why). A
## building whose type does not need mortar is never frost-blocked.
static func frost_blocks_progress(requires_mortar: bool, temperature_c: float, threshold_c: float) -> bool:
	return requires_mortar and temperature_c < threshold_c


## The fraction of the total labour a contribution of `hours` at `skill_factor` represents.
## `skill_factor` is a placeholder 1.0 for everyone until Phase 6 gives people real skills.
static func progress_delta(hours: float, skill_factor: float, total_labour_hours: float) -> float:
	if total_labour_hours <= 0.0:
		return 1.0
	return (hours * skill_factor) / total_labour_hours


## Applies a labour contribution to existing progress, clamped to the [0, 1] a building can be.
static func apply_progress(current_progress: float, hours: float, skill_factor: float, total_labour_hours: float) -> float:
	return clampf(current_progress + progress_delta(hours, skill_factor, total_labour_hours), 0.0, 1.0)
