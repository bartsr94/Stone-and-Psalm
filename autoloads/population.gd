## The community: every `Person`, and the state machine that moves them through the day.
##
## Authoritative and headless (Architecture Guide §2). It runs on `SimClock.substep_passed` —
## the fixed 10-sim-minute step — so the same seed and calendar always produce the same
## movements; the view only interpolates between substeps.
##
## Phase 3 is one monk; Phase 4 adds haulers and builders. Each substep, for every person in id
## order (never dictionary order — Architecture Guide §7): look up the day's horarium from
## `Liturgy`, decide whether this minute belongs to an office, a work block, or sleep. In a work
## block, `_resolve_work` asks `Labour` for a haul or construction task and walks the person
## toward it — falling back to the Phase 3 greybox clearing in `data/precinct.json` when there is
## nothing queued, which is what keeps the one-monk demo unchanged with no buildings placed.
## Arrival executes the task (`_execute_task`): a labour contribution to `Buildings`, or a
## pickup/dropoff through `Hauling`.
extends Node

const PRECINCT_PATH := "res://data/precinct.json"

var _people: Dictionary = {}          ## id -> Person
var _next_id: int = 1

var _church_door: Vector2i = Vector2i.ZERO
var _dormitory_door: Vector2i = Vector2i.ZERO
var _work_site: Vector2i = Vector2i.ZERO
var _precinct: Dictionary = {}

var _move_cells_per_substep: int = 22
var _loaded_speed_factor: float = 0.7
var _snow_speed_factor: float = 0.6
var _road_speed_factor: float = 1.5
var _plan_cache: Dictionary = {}       ## "day|class|order" -> day_plan
var _pending_settle: Dictionary = {}   ## person id -> Activity; scratch, valid _decide→_advance within one substep


func _ready() -> void:
	_move_cells_per_substep = Tuning.get_int("agents.move_cells_per_substep")
	_loaded_speed_factor = Tuning.get_num("hauling.loaded_speed_factor")
	_snow_speed_factor = Tuning.get_num("hauling.snow_speed_factor")
	_road_speed_factor = Tuning.get_num("roads.speed_factor")
	_load_precinct()
	SimClock.substep_passed.connect(_on_substep)
	# Phase 3 demo: found a one-monk house once the world exists.
	call_deferred("found_demo_house")


# --- reading -----------------------------------------------------------------------------

func person_count() -> int:
	return _people.size()


func person_ids() -> Array:
	var ids := _people.keys()
	ids.sort()
	return ids


func get_person(id: int) -> Person:
	return _people.get(id) as Person


## A presentation snapshot for `monk_view.gd`: where the person is, where they are heading, and
## what they are doing. All positions are world-space `Vector3` at the cell's ground height.
func get_person_view(id: int) -> Dictionary:
	var person: Person = _people.get(id)
	if person == null:
		return {}
	var here := Terrain.cell_to_world(person.grid_pos.x, person.grid_pos.y)
	var next := here
	var path_world: Array[Vector3] = []
	for step in person.path:
		path_world.append(Terrain.cell_to_world(step.x, step.y))
	if not path_world.is_empty():
		next = path_world[0]
	return {
		"id": id,
		"name": person.given_name,
		"world_pos": here,
		"next_world_pos": next,
		"path_world": path_world,
		"moving": not person.path.is_empty(),
		"activity": person.activity,
		"office": person.current_office,
		"order": person.order,
		"person_class": person.person_class,
		"carrying_good": person.carrying_good,
		"carrying_qty": person.carrying_qty,
	}


func church_door() -> Vector2i:
	return _church_door


func dormitory_door() -> Vector2i:
	return _dormitory_door


func work_site_cell() -> Vector2i:
	return _work_site


func precinct_config() -> Dictionary:
	return _precinct


# --- founding and editing --------------------------------------------------------------

func add_person(given_name: String, person_class: Monastic.Class, order: Monastic.Order, cell: Vector2i) -> int:
	var person := Person.new()
	person.id = _next_id
	_next_id += 1
	person.given_name = given_name
	person.person_class = person_class
	person.order = order
	person.grid_pos = cell
	# A sentinel, not `cell`: `_decide` treats "desired_cell == target_cell" as "already pursuing
	# this, nothing to do", which would wrongly skip ever settling this person if their very first
	# decision happened to want the cell they were placed on (a hauler seeded at their own
	# building's door, say). No real grid cell is negative, so this can never collide.
	person.target_cell = Vector2i(-1, -1)
	person.activity = Person.Activity.SLEEP
	_people[person.id] = person
	return person.id


func clear() -> void:
	_people.clear()
	_next_id = 1
	_plan_cache.clear()
	_pending_settle.clear()


## Founds the Phase 3 one-monk house if the community is empty. Idempotent — safe to call from
## the autoload boot and from a test's setup.
func found_demo_house() -> void:
	if _people.is_empty():
		add_person("Brother Ælred", Monastic.Class.CHOIR_MONK, Monastic.Order.CISTERCIAN, _dormitory_door)


# --- the substep tick ----------------------------------------------------------------

func _on_substep() -> void:
	var year := SimClock.year()
	var day := SimClock.day_of_year()
	var minute := float(SimClock.minute_of_day())
	for id in person_ids():
		var person: Person = _people[id]
		_decide(person, minute, _day_plan_for(person, year, day))
		_advance(person)


## Picks where the person should be for this minute and repaths if it changed. In a work block
## this defers to `_resolve_work`, which is where Phase 4's haul/build assignment happens.
func _decide(person: Person, minute: float, plan: Dictionary) -> void:
	var desired_cell := _dormitory_door
	var settled := Person.Activity.SLEEP
	var office_key := ""

	for entry in plan.get("offices", []):
		if not entry["attends"]:
			continue
		var start: float = entry["start_min"]
		if minute >= start and minute < start + float(entry["duration_min"]):
			desired_cell = _church_door
			settled = Person.Activity.AT_OFFICE
			office_key = entry["key"]
			break

	if settled == Person.Activity.SLEEP and not plan.get("labour_restricted", false):
		for block in plan.get("work_blocks", []):
			if minute >= float(block[0]) and minute < float(block[1]):
				desired_cell = _resolve_work(person)
				settled = _activity_for_current_task(person)
				break

	person.current_office = office_key
	_pending_settle[person.id] = settled

	if desired_cell == person.target_cell:
		# Already committed to this destination; arrival is handled in _advance.
		return

	person.target_cell = desired_cell
	if person.grid_pos == desired_cell:
		person.path = []
		person.activity = settled
		_execute_task(person)
		return

	person.path = _repath(person.grid_pos, desired_cell)
	person.activity = _walking_activity(settled)


## Walks the person up to their effective speed in cells along their path, then settles and
## executes whatever they arrived to do.
func _advance(person: Person) -> void:
	if person.path.is_empty():
		_execute_task(person)
		return
	var steps := _effective_move_cells(person)
	while steps > 0 and not person.path.is_empty():
		person.grid_pos = person.path.pop_front()
		steps -= 1
	if person.path.is_empty():
		person.activity = _pending_settle.get(person.id, person.activity)
		_execute_task(person)


# --- Phase 4: task assignment and execution --------------------------------------------

## Where a work block should send this person: continues an in-progress haul or build task,
## asks `Labour` for a new one if idle, and falls back to the Phase 3 greybox clearing when
## there is nothing queued (no buildings placed yet, or nothing left to do).
func _resolve_work(person: Person) -> Vector2i:
	if not _task_still_valid(person):
		person.current_task = {}
		person.carrying_good = ""
		person.carrying_qty = 0

	if person.current_task.is_empty():
		var assigned := Labour.request_task(person)
		if not assigned.is_empty():
			if assigned["kind"] == "haul":
				assigned["stage"] = "to_pickup"
			person.current_task = assigned

	if person.current_task.is_empty():
		return _work_site

	if person.current_task["kind"] == "haul":
		var task := Hauling.get_task(int(person.current_task["task_id"]))
		if task.is_empty():
			person.current_task = {}
			return _work_site
		var stage: String = person.current_task.get("stage", "to_pickup")
		var building_id: int = int(task["from_id"]) if stage == "to_pickup" else int(task["to_id"])
		return Buildings.door_cell(building_id)

	return Buildings.door_cell(int(person.current_task["building_id"]))


## A held task survives an office interruption unchanged (`SIMULATION_SPEC.md` §6.5's "suspend,
## resume later"), but not the building finishing, being demolished, or the haul task completing
## through someone else — those must be re-checked before we walk back to them.
func _task_still_valid(person: Person) -> bool:
	if person.current_task.is_empty():
		return true
	match person.current_task.get("kind", ""):
		"build":
			var b := Buildings.get_building(int(person.current_task["building_id"]))
			return b != null and b.construction_state == Building.State.UNDER_CONSTRUCTION
		"haul":
			return not Hauling.get_task(int(person.current_task["task_id"])).is_empty()
		_:
			return false


func _activity_for_current_task(person: Person) -> Person.Activity:
	match person.current_task.get("kind", ""):
		"haul":
			return Person.Activity.HAULING
		"build":
			return Person.Activity.BUILDING
		_:
			return Person.Activity.WORKING   # legacy fallback: the clearing


## Runs once arrival is settled: a construction site gets this substep's labour-hours; a haul
## task's pickup point hands the person their load and flips them toward the dropoff, and the
## dropoff point clears them to be reassigned. Guarded on `person.activity` (not just
## `current_task`) so a task held through an office interruption is never executed while the
## person is actually standing in choir.
func _execute_task(person: Person) -> void:
	if person.current_task.is_empty():
		return
	match person.current_task.get("kind", ""):
		"build":
			if person.activity != Person.Activity.BUILDING:
				return
			Buildings.contribute_labour(
				int(person.current_task["building_id"]), float(SimClock.MINUTES_PER_SUBSTEP) / 60.0
			)
		"haul":
			if person.activity != Person.Activity.HAULING:
				return
			_execute_haul_step(person)


func _execute_haul_step(person: Person) -> void:
	var task_id: int = int(person.current_task["task_id"])
	var stage: String = person.current_task.get("stage", "to_pickup")
	if stage == "to_pickup":
		var got := Hauling.pickup(task_id)
		if got.is_empty():
			person.current_task = {}
			return
		person.carrying_good = got["good_id"]
		person.carrying_qty = int(got["qty"])
		person.current_task["stage"] = "to_dropoff"
	else:
		Hauling.dropoff(task_id)
		person.carrying_good = ""
		person.carrying_qty = 0
		person.current_task = {}


# --- helpers --------------------------------------------------------------------------

func _walking_activity(settled: Person.Activity) -> Person.Activity:
	match settled:
		Person.Activity.AT_OFFICE:
			return Person.Activity.TO_CHURCH
		Person.Activity.WORKING, Person.Activity.HAULING, Person.Activity.BUILDING:
			return Person.Activity.TO_WORK
		_:
			return Person.Activity.IDLE


## Effective cells moved this substep: the Phase 3 watchable pace, slowed while carrying a load
## or crossing snow, sped up while on a road (`SIMULATION_SPEC.md` §10) — see `data/tuning.json`'s
## "hauling" comment for why this scales the placeholder pace rather than switching to a real
## walking speed. The road check reads the cell the person is already standing on, not every cell
## the coming dash will cross — the same substep-uniform coarseness the other two factors already
## have, not a new approximation.
func _effective_move_cells(person: Person) -> int:
	var factor := 1.0
	if person.carrying_qty > 0:
		factor *= _loaded_speed_factor
	if Weather.is_snowing():
		factor *= _snow_speed_factor
	if Terrain.is_road(person.grid_pos.x, person.grid_pos.y):
		factor *= _road_speed_factor
	return maxi(1, int(round(float(_move_cells_per_substep) * factor)))


func _day_plan_for(person: Person, year: int, day: int) -> Dictionary:
	var key := "%d|%d|%d" % [day, person.person_class, person.order]
	if not _plan_cache.has(key):
		_plan_cache.clear()  # one day at a time; keep it small
		_plan_cache[key] = Liturgy.day_plan(person.person_class, person.order, year, day)
	return _plan_cache[key]


func _repath(from_cell: Vector2i, to_cell: Vector2i) -> Array[Vector2i]:
	var cells := Pathfinder.find_path(
		from_cell, to_cell,
		Terrain.is_walkable_cell, Terrain.move_cost, Terrain.min_step_cost()
	)
	var typed: Array[Vector2i] = []
	# Drop the first cell — it is where the person already stands.
	for i in range(1, cells.size()):
		typed.append(cells[i])
	if typed.is_empty() and from_cell != to_cell:
		push_warning("Population: no path from %s to %s" % [from_cell, to_cell])
	return typed


func _load_precinct() -> void:
	var file := FileAccess.open(PRECINCT_PATH, FileAccess.READ)
	if file == null:
		push_error("Population: cannot open %s" % PRECINCT_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Population: %s is not a JSON object" % PRECINCT_PATH)
		return
	_precinct = parsed

	for building in parsed.get("buildings", []):
		var anchor := Vector2i(int(building["anchor"][0]), int(building["anchor"][1]))
		var radius := int(building.get("search_radius_cells", 12))
		var footprint := _nearest_walkable(anchor, radius)
		var door_offset := Vector2i(
			int(building["door_offset_cells"][0]), int(building["door_offset_cells"][1])
		)
		var door := _nearest_walkable(footprint + door_offset, 6)
		if building["id"] == "church":
			_church_door = door
		elif building["id"] == "dormitory":
			_dormitory_door = door

	var work: Dictionary = parsed.get("work_site", {})
	if work.has("anchor"):
		_work_site = _nearest_walkable(
			Vector2i(int(work["anchor"][0]), int(work["anchor"][1])),
			int(work.get("search_radius_cells", 16))
		)


## The walkable cell closest to `anchor` within `radius`, or `anchor` itself as a last resort.
func _nearest_walkable(anchor: Vector2i, radius: int) -> Vector2i:
	if Terrain.is_walkable(anchor.x, anchor.y):
		return anchor
	var best := anchor
	var best_distance := INF
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var cell := anchor + Vector2i(dx, dy)
			if not Terrain.is_walkable(cell.x, cell.y):
				continue
			var d := Vector2(dx, dy).length_squared()
			if d < best_distance:
				best_distance = d
				best = cell
	return best


# --- save / load ---------------------------------------------------------------------

func serialize() -> Dictionary:
	var people: Array = []
	for id in person_ids():
		people.append((_people[id] as Person).to_dict())
	return {"people": people, "next_id": _next_id}


func deserialize(data: Dictionary) -> void:
	_people.clear()
	_plan_cache.clear()
	for entry in data.get("people", []):
		var person := Person.from_dict(entry)
		_people[person.id] = person
	_next_id = int(data.get("next_id", _people.size() + 1))
