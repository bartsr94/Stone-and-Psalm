## Recipes: what a COMPLETE building can turn labour (and, for a recipe with inputs, its own
## stock) into. `SIMULATION_SPEC.md` §9, roadmap 5.1.
##
## Authoritative and headless (Architecture Guide §2) — it never touches the scene tree. A
## recipe's batch state lives on the `Building` record itself (`active_recipe`, `recipe_progress`,
## same shape as construction's `build_progress`), not here; this autoload is the stateless rule
## book, exactly the relationship `scripts/sim/recipe_progress.gd` (pure arithmetic) has to this
## (stateful orchestration) has to `autoloads/buildings.gd` (the record store). Every input and
## output moves through a building's own `inventory` via `Buildings.remove_from_inventory` /
## `add_to_inventory` — there is still no global pool (`SIMULATION_SPEC.md` §10).
extends Node

signal batch_completed(building_id: int, recipe_id: String)

const RECIPES_PATH := "res://data/recipes.json"

var _recipes: Dictionary = {}   ## recipe_id -> Dictionary (data/recipes.json)
var _default_skill_factor: float = 1.0


func _ready() -> void:
	_load_recipes()
	_default_skill_factor = Tuning.get_num("production.default_skill_factor")


func clear() -> void:
	pass   # stateless — every batch's state lives on its Building, not here


# --- recipes ------------------------------------------------------------------------------

func recipe_ids() -> Array:
	var ids := _recipes.keys()
	ids.sort()
	return ids


func has_recipe(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)


func get_recipe(recipe_id: String) -> Dictionary:
	return _recipes.get(recipe_id, {})


## Every recipe that can run at a building of this type, sorted (so an auto-started batch is
## deterministic — Architecture Guide §7 — and so `CrewPanel`-style callers get a stable list).
func recipe_ids_for(building_type: String) -> Array:
	var ids: Array = []
	for id in recipe_ids():
		if str(_recipes[id].get("building_type", "")) == building_type:
			ids.append(id)
	return ids


# --- batches --------------------------------------------------------------------------------

## Whether `recipe_id` could start at `building_id` right now: the building is `COMPLETE`, of the
## matching type, idle (no batch already running), and its own inventory already holds every
## input the batch needs — a recipe with no inputs (raw extraction) always clears that last check.
func can_start(building_id: int, recipe_id: String) -> bool:
	if not has_recipe(recipe_id):
		return false
	var b := Buildings.get_building(building_id)
	if b == null or b.construction_state != Building.State.COMPLETE:
		return false
	if b.active_recipe != "":
		return false
	var recipe := get_recipe(recipe_id)
	if str(recipe.get("building_type", "")) != b.type_id:
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for good_id in inputs:
		if Buildings.inventory_of(building_id, good_id) < int(inputs[good_id]):
			return false
	return true


## Starts a batch: consumes its inputs from the building's own inventory immediately (the same
## "per batch" framing §9's table uses) and marks it the building's active recipe. False, with
## nothing consumed, if `can_start` would say no.
func start(building_id: int, recipe_id: String) -> bool:
	if not can_start(building_id, recipe_id):
		return false
	var b := Buildings.get_building(building_id)
	var recipe := get_recipe(recipe_id)
	var inputs: Dictionary = recipe.get("inputs", {})
	for good_id in inputs:
		Buildings.remove_from_inventory(building_id, good_id, int(inputs[good_id]))
	b.active_recipe = recipe_id
	b.recipe_progress = 0.0
	return true


## Whether there is (or could right now be started) a batch running at this building — the
## question `Labour` asks before sending a worker here, the production equivalent of
## `Buildings.is_frost_gated` for "why is nothing happening here".
func can_produce(building_id: int) -> bool:
	var b := Buildings.get_building(building_id)
	if b == null or b.construction_state != Building.State.COMPLETE:
		return false
	if b.active_recipe != "":
		return true
	for recipe_id in recipe_ids_for(b.type_id):
		if can_start(building_id, recipe_id):
			return true
	return false


## A worker's contribution for this substep/hour. Auto-starts the first startable recipe for the
## building's type if nothing is running yet (mirroring how a construction site needs no explicit
## "begin building" call once materials are complete). Returns `false` if nothing could run at
## all — the building is not a complete production site, or no recipe is startable (missing
## inputs, most likely). `skill_factor` defaults to the tuned placeholder, same as construction's.
func contribute_labour(building_id: int, hours: float, skill_factor: float = -1.0) -> bool:
	var b := Buildings.get_building(building_id)
	if b == null or b.construction_state != Building.State.COMPLETE:
		return false

	if b.active_recipe == "":
		var started := false
		for recipe_id in recipe_ids_for(b.type_id):
			if start(building_id, recipe_id):
				started = true
				break
		if not started:
			return false

	var recipe := get_recipe(b.active_recipe)
	var factor := skill_factor if skill_factor >= 0.0 else _default_skill_factor
	var total_hours := float(recipe.get("labour_hours", 1.0))
	b.recipe_progress = RecipeProgress.apply_progress(b.recipe_progress, hours, factor, total_hours)

	if b.recipe_progress >= 1.0:
		var finished_recipe := b.active_recipe
		var outputs: Dictionary = recipe.get("outputs", {})
		for good_id in outputs:
			Buildings.add_to_inventory(building_id, good_id, int(outputs[good_id]))
		b.active_recipe = ""
		b.recipe_progress = 0.0
		batch_completed.emit(building_id, finished_recipe)
	return true


func _load_recipes() -> void:
	var file := FileAccess.open(RECIPES_PATH, FileAccess.READ)
	if file == null:
		push_error("Production: cannot open %s" % RECIPES_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Production: %s is not a JSON object" % RECIPES_PATH)
		return
	for key in (parsed as Dictionary).keys():
		if key == "_comment":
			continue
		_recipes[key] = parsed[key]
