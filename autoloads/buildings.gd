## Placed buildings: types from `data/buildings.json`, instances as `Building` records.
## `SIMULATION_SPEC.md` §7, §10, §11; roadmap 4.1–4.5.
##
## Authoritative and headless — it reasons about terrain cells through `Terrain`'s existing
## `is_walkable`/`cell_to_world`, never the scene tree (Architecture Guide §2). Every good a
## building holds lives in that building's own `inventory`; there is no global store
## (`SIMULATION_SPEC.md` §10, the single most important rule in that document).
##
## `Hauling` and `Labour` are the only other systems that call into this one; a view reads it to
## draw the site, never writes it.
extends Node

signal building_placed(id: int)
signal building_completed(id: int)

const BUILDINGS_PATH := "res://data/buildings.json"
const _ROTATIONS := [0, 90, 180, 270]
const _DEFAULT_CAPACITY := 999999   ## effectively unlimited for a production building with no storage_capacity of its own yet

var _types: Dictionary = {}       ## type_id -> Dictionary (data/buildings.json)
var _instances: Dictionary = {}   ## id -> Building
var _occupied: Dictionary = {}    ## Vector2i -> building id, every footprint cell of every building
var _next_id: int = 1

var _frost_gate_temp_c: float = 2.0
var _default_skill_factor: float = 1.0


func _ready() -> void:
	_load_types()
	_frost_gate_temp_c = Tuning.get_num("construction.frost_gate_temp_c")
	_default_skill_factor = Tuning.get_num("construction.default_skill_factor")
	# Phase 4 demo: a stocked stockpile, a granary rising beside it, and the two conversi who
	# raise it — once the world exists. Mirrors Population.found_demo_house()'s pattern.
	call_deferred("found_demo_construction_site")


func clear() -> void:
	_instances.clear()
	_occupied.clear()
	_next_id = 1


## Phase 4 demo, idempotent: a stocked open stockpile and a granary rising beside the greybox
## work site, with two conversi to build it. Safe to call again — it only acts once, exactly
## like `Population.found_demo_house()`. Bails out quietly if no valid site is found nearby
## rather than pushing an error; the founding valley preset always has room here in practice.
func found_demo_construction_site() -> void:
	if not _instances.is_empty():
		return

	# Close beside the assart clearing, not just "somewhere walkable" — a demo the camera's
	# default framing can actually see is worth more than one a few dozen metres out of frame.
	var anchor := Population.work_site_cell() + Vector2i(3, 3)
	var stockpile_site := find_site_near("open_stockpile", anchor)
	if stockpile_site == Vector2i(-1, -1):
		return
	var stockpile := seed_building("open_stockpile", stockpile_site, 0, {"sawn_timber": 200, "nails": 40})

	var granary_site := find_site_near("granary", stockpile_site + Vector2i(5, 0))
	if granary_site == Vector2i(-1, -1):
		return
	place_building("granary", granary_site)

	var door := door_cell(stockpile)
	Population.add_person("Brother Osric", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, door)
	Population.add_person("Brother Ediva", Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, door)


# --- types ------------------------------------------------------------------------------

func type_ids() -> Array:
	var ids := _types.keys()
	ids.sort()
	return ids


func has_type(type_id: String) -> bool:
	return _types.has(type_id)


func get_type(type_id: String) -> Dictionary:
	return _types.get(type_id, {})


## The nearest cell to `target` (ring search, closest first) this type can actually be placed
## on — the same search a placement UI's snap-to-nearest-valid-site would need, and how the demo
## site below and the Phase 4 tests avoid hardcoding coordinates that would rot if the terrain
## preset changes. `Vector2i(-1, -1)` if nothing within `max_radius` works.
func find_site_near(type_id: String, target: Vector2i, max_radius: int = 40) -> Vector2i:
	for radius in range(0, max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := target + Vector2i(dx, dy)
				if can_place(type_id, cell):
					return cell
	return Vector2i(-1, -1)


## The footprint in cells, width × length, after rotation has swapped the axes for 90°/270°.
func footprint_for(type_id: String, rotation_deg: int) -> Vector2i:
	var raw: Array = get_type(type_id).get("footprint_cells", [1, 1])
	var w := int(raw[0])
	var length := int(raw[1])
	var norm := _normalize_rotation(rotation_deg)
	if norm == 90 or norm == 270:
		return Vector2i(length, w)
	return Vector2i(w, length)


# --- placement ----------------------------------------------------------------------------

## True if every footprint cell is on the map, walkable (Terrain's existing rule — not in the
## river, not too steep), and not already claimed by another building.
func can_place(type_id: String, anchor: Vector2i, rotation_deg: int = 0) -> bool:
	if not has_type(type_id):
		return false
	var footprint := footprint_for(type_id, rotation_deg)
	for dy in footprint.y:
		for dx in footprint.x:
			var cell := anchor + Vector2i(dx, dy)
			if not Terrain.is_walkable(cell.x, cell.y):
				return false
			if _occupied.has(cell):
				return false
	return true


## Places a building. State starts `PLANNED` (or straight to `UNDER_CONSTRUCTION` if the type
## needs no materials, e.g. the open stockpile's token fencing). Returns the new id, or -1 if
## the site is invalid — the caller (a placement UI, a test, a demo seed) checks that.
func place_building(type_id: String, anchor: Vector2i, rotation_deg: int = 0) -> int:
	if not can_place(type_id, anchor, rotation_deg):
		return -1

	var b := Building.new()
	b.id = _next_id
	_next_id += 1
	b.type_id = type_id
	b.anchor = anchor
	b.footprint = footprint_for(type_id, rotation_deg)
	b.rotation_deg = _normalize_rotation(rotation_deg)

	var required: Dictionary = get_type(type_id).get("build_materials", {})
	b.construction_state = (
		Building.State.UNDER_CONSTRUCTION if required.is_empty() else Building.State.PLANNED
	)

	_instances[b.id] = b
	_register_footprint(b)
	building_placed.emit(b.id)
	return b.id


## Places a building already `COMPLETE`, with an optional starting inventory. For founding
## stores and tests only — a real building is always earned through `place_building`. A
## monastery's founding grant historically arrived with some stock already in hand; this is
## that, not a shortcut around the frost gate or the labour cost for anything the player builds.
func seed_building(type_id: String, anchor: Vector2i, rotation_deg: int = 0, initial_inventory: Dictionary = {}) -> int:
	if not can_place(type_id, anchor, rotation_deg):
		return -1

	var b := Building.new()
	b.id = _next_id
	_next_id += 1
	b.type_id = type_id
	b.anchor = anchor
	b.footprint = footprint_for(type_id, rotation_deg)
	b.rotation_deg = _normalize_rotation(rotation_deg)
	b.construction_state = Building.State.COMPLETE
	b.build_progress = 1.0
	# Backfill delivered_materials to match the type's cost — a seeded building owes nothing,
	# and materials_needed() has no other way to know that short of checking construction_state
	# (which stays true of a founding stockpile's own build cost too, not just player-built ones).
	for good_id in get_type(type_id).get("build_materials", {}).keys():
		b.delivered_materials[good_id] = int(get_type(type_id)["build_materials"][good_id])

	_instances[b.id] = b
	_register_footprint(b)
	for good_id in initial_inventory.keys():
		add_to_inventory(b.id, good_id, int(initial_inventory[good_id]))
	building_placed.emit(b.id)
	building_completed.emit(b.id)
	return b.id


# --- reading instances ----------------------------------------------------------------------

func get_building(id: int) -> Building:
	return _instances.get(id) as Building


func building_ids() -> Array:
	var ids := _instances.keys()
	ids.sort()
	return ids


func buildings_of_category(category: String) -> Array:
	var out: Array = []
	for id in building_ids():
		var b: Building = _instances[id]
		if str(get_type(b.type_id).get("category", "")) == category:
			out.append(id)
	return out


## The cell an agent stands on to reach this building — found once by searching outward from the
## footprint's centre and cached on the instance, since it never changes after placement.
func door_cell(id: int) -> Vector2i:
	var b := get_building(id)
	if b == null:
		return Vector2i.ZERO
	if not b.has_cached_door():
		b.set_cached_door(_find_door(b))
	return b.cached_door()


# --- construction: materials -----------------------------------------------------------------

## Goods still owed before this building leaves `PLANNED`/`MATERIALS_PENDING`, good id → qty,
## sorted by id. Empty once every requirement is met.
func materials_needed(id: int) -> Dictionary:
	var out := {}
	var b := get_building(id)
	if b == null:
		return out
	var required: Dictionary = get_type(b.type_id).get("build_materials", {})
	var ids := required.keys()
	ids.sort()
	for good_id in ids:
		var need := int(required[good_id]) - int(b.delivered_materials.get(good_id, 0))
		if need > 0:
			out[good_id] = need
	return out


func is_materials_complete(id: int) -> bool:
	return materials_needed(id).is_empty()


## A hauler drops off up to `qty` of `good_id` against what is still owed. Returns how much was
## actually accepted (never more than what is still needed). Moves `PLANNED` → `MATERIALS_PENDING`
## on the first delivery, and → `UNDER_CONSTRUCTION` once every good is fully delivered.
func deliver_material(id: int, good_id: String, qty: int) -> int:
	var b := get_building(id)
	if b == null or qty <= 0:
		return 0
	if b.construction_state != Building.State.PLANNED and b.construction_state != Building.State.MATERIALS_PENDING:
		return 0

	var required: Dictionary = get_type(b.type_id).get("build_materials", {})
	var already := int(b.delivered_materials.get(good_id, 0))
	var need := int(required.get(good_id, 0)) - already
	if need <= 0:
		return 0

	var accepted := mini(qty, need)
	b.delivered_materials[good_id] = already + accepted
	if b.construction_state == Building.State.PLANNED:
		b.construction_state = Building.State.MATERIALS_PENDING
	if is_materials_complete(id):
		b.construction_state = Building.State.UNDER_CONSTRUCTION
	return accepted


# --- construction: labour and the frost gate --------------------------------------------------

## A builder's contribution for this substep/hour. Returns `false` (no progress applied) if the
## building is not under construction, or if it needs mortar and the frost gate is shut
## (`Weather.temperature_c()` below `construction.frost_gate_temp_c` — `SIMULATION_SPEC.md` §11).
## `skill_factor` defaults to the tuned placeholder (everyone builds at the same rate until
## Phase 6).
func contribute_labour(id: int, hours: float, skill_factor: float = -1.0) -> bool:
	var b := get_building(id)
	if b == null or b.construction_state != Building.State.UNDER_CONSTRUCTION:
		return false

	var type := get_type(b.type_id)
	var requires_mortar: bool = type.get("requires_mortar", false)
	if Construction.frost_blocks_progress(requires_mortar, Weather.temperature_c(), _frost_gate_temp_c):
		return false

	var factor := skill_factor if skill_factor >= 0.0 else _default_skill_factor
	var total_hours := float(type.get("build_labour_hours", 1.0))
	b.build_progress = Construction.apply_progress(b.build_progress, hours, factor, total_hours)
	if b.build_progress >= 1.0:
		b.construction_state = Building.State.COMPLETE
		b.assigned_workers.clear()   # the crew's job here is done; a stale assignment would just hide them from the pool
		building_completed.emit(id)
	return true


## Whether this building's construction is currently blocked by frost (for a UI/test to explain
## "why is nothing happening here" without duplicating the rule).
func is_frost_gated(id: int) -> bool:
	var b := get_building(id)
	if b == null:
		return false
	var requires_mortar: bool = get_type(b.type_id).get("requires_mortar", false)
	return Construction.frost_blocks_progress(requires_mortar, Weather.temperature_c(), _frost_gate_temp_c)


# --- worker assignment (roadmap 4.9) ----------------------------------------------------------
#
# SIMULATION_SPEC.md §6.5, §7.3: the player can pin a person to a specific building — "assigned
# jobs... outrank the queue" — leaving everyone else as the laborer pool `Labour` already draws
# on. Scoped to construction crews for now: a production building's worker_slots have nothing to
# do until Phase 5 gives them a recipe to run, and assigning someone to stand at a finished shed
# doing nothing would look like a bug, not a feature.

## The building this person is currently pinned to, or -1 if they are in the laborer pool. A
## small linear scan over placed buildings rather than a reverse index on `Person` — there is no
## Phase 4 map large enough for this to matter, and it keeps `Building.assigned_workers` the one
## place this fact lives.
func building_for_worker(person_id: int) -> int:
	for id in building_ids():
		if (_instances[id] as Building).assigned_workers.has(person_id):
			return id
	return -1


func worker_count(id: int) -> int:
	var b := get_building(id)
	if b == null:
		return 0
	return b.assigned_workers.size()


func worker_slots(id: int) -> int:
	var b := get_building(id)
	if b == null:
		return 0
	return int(get_type(b.type_id).get("worker_slots", 0))


## Pins `person_id` to `building_id`'s construction crew, first releasing them from wherever they
## were pinned before (a person is never assigned to two sites at once). Refuses a building that
## is not `UNDER_CONSTRUCTION` (see the section comment above), one with no free slot, or a
## person already at that slot count. Returns whether the assignment took.
func assign_worker(building_id: int, person_id: int) -> bool:
	var b := get_building(building_id)
	if b == null or b.construction_state != Building.State.UNDER_CONSTRUCTION:
		return false
	if b.assigned_workers.has(person_id):
		return true
	if b.assigned_workers.size() >= worker_slots(building_id):
		return false
	unassign_worker(person_id)
	b.assigned_workers.append(person_id)
	return true


## Releases `person_id` from whatever building they are pinned to, if any. Safe to call on
## someone already in the laborer pool.
func unassign_worker(person_id: int) -> void:
	var current := building_for_worker(person_id)
	if current == -1:
		return
	(_instances[current] as Building).assigned_workers.erase(person_id)


# --- local inventory: no global pool -----------------------------------------------------------

func inventory_of(id: int, good_id: String) -> int:
	var b := get_building(id)
	if b == null:
		return 0
	return int(b.inventory.get(good_id, 0))


func capacity_of(id: int) -> int:
	var b := get_building(id)
	if b == null:
		return 0
	return int(get_type(b.type_id).get("storage_capacity", _DEFAULT_CAPACITY))


func _total_inventory(b: Building) -> int:
	var total := 0
	for qty in b.inventory.values():
		total += int(qty)
	return total


## Adds up to `qty` of `good_id`, capped by remaining capacity. Returns how much actually fit.
func add_to_inventory(id: int, good_id: String, qty: int) -> int:
	var b := get_building(id)
	if b == null or qty <= 0:
		return 0
	var room := maxi(capacity_of(id) - _total_inventory(b), 0)
	var accepted := mini(qty, room)
	if accepted <= 0:
		return 0
	b.inventory[good_id] = int(b.inventory.get(good_id, 0)) + accepted
	return accepted


## Removes up to `qty` of `good_id`. Returns how much was actually available and removed.
func remove_from_inventory(id: int, good_id: String, qty: int) -> int:
	var b := get_building(id)
	if b == null or qty <= 0:
		return 0
	var have := int(b.inventory.get(good_id, 0))
	var taken := mini(qty, have)
	if taken <= 0:
		return 0
	b.inventory[good_id] = have - taken
	if b.inventory[good_id] <= 0:
		b.inventory.erase(good_id)
	return taken


## The nearest building (by straight-line distance from `from_cell`, ties broken by lowest id)
## holding at least `min_qty` of `good_id`. -1 if none does. Used to source a delivery haul.
func find_source_of(good_id: String, min_qty: int, from_cell: Vector2i) -> int:
	var best_id := -1
	var best_distance := INF
	for id in building_ids():
		if inventory_of(id, good_id) < maxi(min_qty, 1):
			continue
		var d := _distance_from(id, from_cell)
		if d < best_distance:
			best_distance = d
			best_id = id
	return best_id


## The nearest complete storage building that accepts `good_id` (`Goods.storable_in`) and has
## room for at least one unit. -1 if none does. Used to source a "haul this out" destination.
func find_storage_accepting(good_id: String, from_cell: Vector2i) -> int:
	var best_id := -1
	var best_distance := INF
	for id in building_ids():
		var b: Building = _instances[id]
		if b.construction_state != Building.State.COMPLETE:
			continue
		if not Goods.can_be_stored_in(good_id, b.type_id):
			continue
		if capacity_of(id) - _total_inventory(b) <= 0:
			continue
		var d := _distance_from(id, from_cell)
		if d < best_distance:
			best_distance = d
			best_id = id
	return best_id


func _distance_from(id: int, from_cell: Vector2i) -> float:
	var b: Building = _instances[id]
	var reference := b.cached_door() if b.has_cached_door() else b.anchor
	return Vector2(reference - from_cell).length_squared()


# --- internals ------------------------------------------------------------------------------

func _normalize_rotation(rotation_deg: int) -> int:
	var m := posmod(rotation_deg, 360)
	if _ROTATIONS.has(m):
		return m
	return 0


func _register_footprint(b: Building) -> void:
	for cell in b.footprint_cells():
		_occupied[cell] = b.id


## Searches outward in square rings from the footprint's centre for the nearest walkable cell
## that is not part of the footprint itself — the same shape of search `Population` uses to seat
## the fixed greybox precinct, but centred on an arbitrary placed building instead.
func _find_door(b: Building) -> Vector2i:
	var centre := b.anchor + b.footprint / 2
	for radius in range(1, 20):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := centre + Vector2i(dx, dy)
				if b.contains_cell(cell):
					continue
				if Terrain.is_walkable(cell.x, cell.y):
					return cell
	return b.anchor


func _load_types() -> void:
	var file := FileAccess.open(BUILDINGS_PATH, FileAccess.READ)
	if file == null:
		push_error("Buildings: cannot open %s" % BUILDINGS_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		push_error("Buildings: %s is not a JSON object" % BUILDINGS_PATH)
		return
	for key in parsed.keys():
		if key == "_comment":
			continue
		_types[key] = parsed[key]


# --- save / load ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var list: Array = []
	for id in building_ids():
		list.append((_instances[id] as Building).to_dict())
	return {"buildings": list, "next_id": _next_id}


func deserialize(data: Dictionary) -> void:
	_instances.clear()
	_occupied.clear()
	for entry in data.get("buildings", []):
		var b := Building.from_dict(entry)
		_instances[b.id] = b
		_register_footprint(b)
	_next_id = int(data.get("next_id", _instances.size() + 1))
