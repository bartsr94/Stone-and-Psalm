## The community: every `Person`, and the state machine that moves them through the day.
##
## Authoritative and headless (Architecture Guide §2). It runs on `SimClock.substep_passed` —
## the fixed 10-sim-minute step — so the same seed and calendar always produce the same
## movements; the view only interpolates between substeps.
##
## Phase 3 is one monk. Each substep, for every person in id order (never dictionary order —
## Architecture Guide §7): look up the day's horarium from `Liturgy`, decide whether this
## minute belongs to an office, a work block, or sleep, walk them toward the right building,
## and settle them when they arrive. The precinct is the greybox church, dormitory and work
## site in `data/precinct.json`.
extends Node

const PRECINCT_PATH := "res://data/precinct.json"

var _people: Dictionary = {}          ## id -> Person
var _next_id: int = 1

var _church_door: Vector2i = Vector2i.ZERO
var _dormitory_door: Vector2i = Vector2i.ZERO
var _work_site: Vector2i = Vector2i.ZERO
var _precinct: Dictionary = {}

var _move_cells_per_substep: int = 22
var _plan_cache: Dictionary = {}       ## "day|class|order" -> day_plan


func _ready() -> void:
	_move_cells_per_substep = Tuning.get_int("agents.move_cells_per_substep")
	_load_precinct()
	SimClock.substep_passed.connect(_on_substep)
	# Phase 3 demo: found a one-monk house once the world exists.
	call_deferred("_found_demo_house_if_empty")


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
	if not person.path.is_empty():
		var step: Vector2i = person.path[0]
		next = Terrain.cell_to_world(step.x, step.y)
	return {
		"id": id,
		"name": person.given_name,
		"world_pos": here,
		"next_world_pos": next,
		"moving": not person.path.is_empty(),
		"activity": person.activity,
		"office": person.current_office,
		"order": person.order,
		"person_class": person.person_class,
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
	person.target_cell = cell
	person.activity = Person.Activity.SLEEP
	_people[person.id] = person
	return person.id


func clear() -> void:
	_people.clear()
	_next_id = 1
	_plan_cache.clear()


func _found_demo_house_if_empty() -> void:
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


## Picks where the person should be for this minute and repaths if it changed.
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
				desired_cell = _work_site
				settled = Person.Activity.WORKING
				break

	person.current_office = office_key

	if desired_cell == person.target_cell:
		# Already committed to this destination; arrival is handled in _advance.
		return

	person.target_cell = desired_cell
	if person.grid_pos == desired_cell:
		person.path = []
		person.activity = settled
		return

	person.path = _repath(person.grid_pos, desired_cell)
	person.activity = _walking_activity(settled)


## Walks the person up to `move_cells_per_substep` cells along their path, then settles them if
## they have arrived.
func _advance(person: Person) -> void:
	if person.path.is_empty():
		return
	var steps := _move_cells_per_substep
	while steps > 0 and not person.path.is_empty():
		person.grid_pos = person.path.pop_front()
		steps -= 1
	if person.path.is_empty():
		person.activity = _settled_for_cell(person.target_cell)


# --- helpers --------------------------------------------------------------------------

func _walking_activity(settled: Person.Activity) -> Person.Activity:
	match settled:
		Person.Activity.AT_OFFICE:
			return Person.Activity.TO_CHURCH
		Person.Activity.WORKING:
			return Person.Activity.TO_WORK
		_:
			return Person.Activity.IDLE


func _settled_for_cell(cell: Vector2i) -> Person.Activity:
	if cell == _church_door:
		return Person.Activity.AT_OFFICE
	if cell == _work_site:
		return Person.Activity.WORKING
	return Person.Activity.SLEEP


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
