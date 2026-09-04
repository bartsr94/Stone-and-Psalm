## The haul task queue: what needs carrying, from where, to where. `SIMULATION_SPEC.md` §10,
## roadmap 4.6.
##
## Authoritative and headless. Tasks are rebuilt on `SimClock.hour_passed`, per spec §6.5 — this
## owns the queue and the pickup/dropoff transfer of goods between buildings' local inventories;
## `Population` owns walking a person there and calling `pickup`/`dropoff` at the right moments.
## Splitting it this way keeps the "no global pool" rule (`SIMULATION_SPEC.md` §10) enforced in
## one place: a good only ever moves from one `Building.inventory` to another, through here.
extends Node

## Construction material delivery outranks feeding a production building's next batch, which in
## turn outranks hauling produced goods off to storage — `SIMULATION_SPEC.md` §6.5's placeholder
## priority table (the other listed priorities — emergencies, food, fuel, harvest — belong to
## systems this project does not build yet). PRIORITY_INPUT has no line of its own in that table;
## it sits just under construction delivery because, same as a construction site, a production
## building can do nothing at all without it, and just over storage because a stocked producer
## already has something to show for itself while it waits.
const PRIORITY_DELIVERY := 70
const PRIORITY_INPUT := 65
const PRIORITY_STORAGE := 50

enum State { QUEUED, ASSIGNED }

var _tasks: Dictionary = {}   ## id -> Dictionary
var _next_id: int = 1
var _carry_max: int = 25


func _ready() -> void:
	_carry_max = Tuning.get_int("hauling.carry_max_units")
	SimClock.hour_passed.connect(_on_hour_passed)


func clear() -> void:
	_tasks.clear()
	_next_id = 1


func _on_hour_passed(_hour_of_day: int) -> void:
	rebuild_tasks()


## Scans every building for an unmet need and queues a task for it, unless one is already open.
## Public so a test (or a save/load boundary) can force a rebuild without waiting for the clock.
func rebuild_tasks() -> void:
	for id in Buildings.building_ids():
		var site := Buildings.get_building(id)
		if site.construction_state != Building.State.PLANNED and site.construction_state != Building.State.MATERIALS_PENDING:
			continue
		var needed: Dictionary = Buildings.materials_needed(id)
		for good_id in needed.keys():
			if _has_open_task(good_id, -1, id):
				continue
			var source := Buildings.find_source_of(good_id, 1, Buildings.door_cell(id))
			if source == -1:
				continue
			var qty: int = mini(int(needed[good_id]), Buildings.inventory_of(source, good_id))
			if qty <= 0:
				continue
			_queue(good_id, qty, source, id, PRIORITY_DELIVERY, "delivery")

	# Feed a production building's next batch, `SIMULATION_SPEC.md` §10: "a consuming building
	# pulls from its own inventory; when short, it queues a haul task from the nearest store that
	# holds the good." A no-input recipe (raw extraction — felling, quarrying) never appears here.
	for id in Buildings.building_ids():
		var b := Buildings.get_building(id)
		if b.construction_state != Building.State.COMPLETE:
			continue
		if str(Buildings.get_type(b.type_id).get("category", "")) != "production":
			continue
		for recipe_id in Production.recipe_ids_for(b.type_id):
			var inputs: Dictionary = Production.get_recipe(recipe_id).get("inputs", {})
			var good_ids := inputs.keys()
			good_ids.sort()
			for good_id in good_ids:
				var need: int = int(inputs[good_id]) - Buildings.inventory_of(id, good_id)
				if need <= 0 or _has_open_task(good_id, -1, id):
					continue
				var source := Buildings.find_source_of(good_id, 1, Buildings.door_cell(id))
				if source == -1 or source == id:   # never haul a building's own partial stock to itself
					continue
				var qty: int = mini(need, Buildings.inventory_of(source, good_id))
				if qty <= 0:
					continue
				_queue(good_id, qty, source, id, PRIORITY_INPUT, "input")

	for id in Buildings.building_ids():
		var b := Buildings.get_building(id)
		if b.construction_state != Building.State.COMPLETE:
			continue
		if str(Buildings.get_type(b.type_id).get("category", "")) == "storage":
			continue
		var good_ids := b.inventory.keys()
		good_ids.sort()
		for good_id in good_ids:
			var qty: int = int(b.inventory[good_id])
			if qty <= 0 or _has_open_task(good_id, id, -1):
				continue
			var destination := Buildings.find_storage_accepting(good_id, Buildings.door_cell(id))
			if destination == -1:
				continue
			_queue(good_id, qty, id, destination, PRIORITY_STORAGE, "storage")


## The best open task for a hauler standing at `from_cell`: highest priority, ties broken by the
## nearest task's pickup point, ties on that broken by lowest id (Architecture Guide §7 — never
## let unordered iteration decide an outcome). Marks it `ASSIGNED` and returns a copy; `{}` if
## nothing is open.
func claim_task(from_cell: Vector2i) -> Dictionary:
	var ids := _tasks.keys()
	ids.sort()
	var best_id := -1
	var best_score := -INF
	for id in ids:
		var task: Dictionary = _tasks[id]
		if task["state"] != State.QUEUED:
			continue
		var door := Buildings.door_cell(int(task["from_id"]))
		var penalty: float = Vector2(door - from_cell).length() * 0.01
		var score: float = float(task["priority"]) - penalty
		if score > best_score:
			best_score = score
			best_id = id
	if best_id == -1:
		return {}
	_tasks[best_id]["state"] = State.ASSIGNED
	return (_tasks[best_id] as Dictionary).duplicate()


func get_task(task_id: int) -> Dictionary:
	if not _tasks.has(task_id):
		return {}
	return (_tasks[task_id] as Dictionary).duplicate()


## Puts a claimed-but-unstarted task back on the queue — a person pulled away to an office before
## reaching the pickup point should not strand the task forever.
func release_task(task_id: int) -> void:
	if _tasks.has(task_id) and not _tasks[task_id].get("picked_up", false):
		_tasks[task_id]["state"] = State.QUEUED


## Removes up to the carry cap of the task's good from its source building into a hauler's hands.
## Returns `{"good_id": .., "qty": ..}`, or `{}` if there was nothing left to take (the source ran
## dry between the task being queued and the hauler arriving — the next hourly rebuild will
## re-source it if the need still stands).
func pickup(task_id: int) -> Dictionary:
	if not _tasks.has(task_id):
		return {}
	var task: Dictionary = _tasks[task_id]
	var good_id: String = task["good_id"]
	var amount: int = mini(_carry_max, int(task["qty_remaining"]))
	var removed := Buildings.remove_from_inventory(int(task["from_id"]), good_id, amount)
	if removed <= 0:
		_tasks.erase(task_id)
		return {}
	task["picked_up"] = true
	task["carried_qty"] = removed
	return {"good_id": good_id, "qty": removed}


## Delivers whatever the hauler is carrying for this task to its destination — `deliver_material`
## for a construction site, `add_to_inventory` for a storage building. Any portion the
## destination cannot accept (a store that filled up in transit) is placeholder-lost rather than
## carried back; SIMULATION_SPEC.md does not specify a return-to-sender rule. Closes the task once
## its full quantity has moved; otherwise leaves it `QUEUED` for the remainder.
func dropoff(task_id: int) -> bool:
	if not _tasks.has(task_id):
		return false
	var task: Dictionary = _tasks[task_id]
	if not task.get("picked_up", false):
		return false

	var good_id: String = task["good_id"]
	var carried: int = int(task["carried_qty"])
	var to_id: int = int(task["to_id"])
	if str(task["purpose"]) == "delivery":
		Buildings.deliver_material(to_id, good_id, carried)
	else:
		Buildings.add_to_inventory(to_id, good_id, carried)

	task["qty_remaining"] = int(task["qty_remaining"]) - carried
	if int(task["qty_remaining"]) <= 0:
		_tasks.erase(task_id)
	else:
		task["picked_up"] = false
		task["carried_qty"] = 0
		task["state"] = State.QUEUED
	return true


func open_task_ids() -> Array:
	var ids := _tasks.keys()
	ids.sort()
	return ids


func _has_open_task(good_id: String, from_id: int, to_id: int) -> bool:
	for task in _tasks.values():
		if task["good_id"] != good_id:
			continue
		if from_id != -1 and int(task["from_id"]) == from_id:
			return true
		if to_id != -1 and int(task["to_id"]) == to_id:
			return true
	return false


func _queue(good_id: String, qty: int, from_id: int, to_id: int, priority: int, purpose: String) -> int:
	var id := _next_id
	_next_id += 1
	_tasks[id] = {
		"id": id,
		"good_id": good_id,
		"qty_remaining": qty,
		"from_id": from_id,
		"to_id": to_id,
		"priority": priority,
		"purpose": purpose,
		"state": State.QUEUED,
		"picked_up": false,
		"carried_qty": 0,
	}
	return id


# --- save / load ---------------------------------------------------------------------------

func serialize() -> Dictionary:
	var ids := open_task_ids()
	var list: Array = []
	for id in ids:
		list.append(_tasks[id].duplicate())
	return {"tasks": list, "next_id": _next_id}


func deserialize(data: Dictionary) -> void:
	_tasks.clear()
	for entry in data.get("tasks", []):
		var task: Dictionary = (entry as Dictionary).duplicate()
		_tasks[int(task["id"])] = task
	_next_id = int(data.get("next_id", _tasks.size() + 1))
