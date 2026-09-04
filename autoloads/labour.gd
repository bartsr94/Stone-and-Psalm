## Task assignment: what an idle person with an open work block should do next.
## `SIMULATION_SPEC.md` §6.5, roadmap 4.8.
##
## Stateless by design — the queues it draws from are owned elsewhere (`Hauling`'s haul tasks,
## `Buildings`' construction states), so there is nothing here to save. A haul task always
## outranks construction labour, matching the priority table (haul delivery 70 vs. construction
## labour 40); within construction, the nearest site under an open frost gate wins. Skill scoring
## and the assigned-building/laborer-pool split (§6.5's other half) are Phase 6 and Phase 4.9
## respectively — every idle person is the laborer pool for now.
extends Node


## `{}` if there is nothing to do; otherwise `{"kind": "haul", "task_id": int}` or
## `{"kind": "build", "building_id": int}`.
func request_task(person: Person) -> Dictionary:
	var haul := Hauling.claim_task(person.grid_pos)
	if not haul.is_empty():
		return {"kind": "haul", "task_id": int(haul["id"])}

	var best_id := -1
	var best_distance := INF
	for id in Buildings.building_ids():
		var b := Buildings.get_building(id)
		if b.construction_state != Building.State.UNDER_CONSTRUCTION:
			continue
		if Buildings.is_frost_gated(id):
			continue
		var d := Vector2(b.anchor - person.grid_pos).length_squared()
		if d < best_distance:
			best_distance = d
			best_id = id

	if best_id != -1:
		return {"kind": "build", "building_id": best_id}
	return {}
