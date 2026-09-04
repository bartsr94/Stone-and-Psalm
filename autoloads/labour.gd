## Task assignment: what an idle person with an open work block should do next.
## `SIMULATION_SPEC.md` §6.5, roadmap 4.8, extended 5.1 for production.
##
## Stateless by design — the queues it draws from are owned elsewhere (`Hauling`'s haul tasks,
## `Buildings`' construction states and worker assignments, `Production`'s recipe readiness), so
## there is nothing here to save. A person pinned to a crew (`Buildings.assign_worker`, roadmap
## 4.9/5.1) always works that site while there is something to do there — "assigned jobs...
## outrank the queue", §6.5 — falling back to the laborer pool only while a construction site is
## waiting on materials or shut by frost, or a production site has nothing startable (no recipe's
## inputs are in stock), so an assigned worker is never simply wasted standing at a site with
## nothing to do yet.
##
## Everyone else, in order: any open haul task, then the nearest site with something to produce,
## then the nearest site under construction. This is a placeholder ordering, not §6.5's literal
## priority-number table — a storage haul (50) should in principle lose to production (60), but
## this system does not yet score every task by its own priority number the way `Hauling.claim_task`
## does within haul tasks alone. Getting that right needs Phase 6's skill/scoring layer anyway
## ("priority − travel_time_penalty + skill_bonus"), so it is deferred with it rather than
## half-built here.
extends Node


## `{}` if there is nothing to do; otherwise `{"kind": "haul", "task_id": int}`,
## `{"kind": "build", "building_id": int}`, or `{"kind": "produce", "building_id": int}`.
func request_task(person: Person) -> Dictionary:
	var assigned := Buildings.building_for_worker(person.id)
	if assigned != -1:
		var site := Buildings.get_building(assigned)
		if site.construction_state == Building.State.UNDER_CONSTRUCTION and not Buildings.is_frost_gated(assigned):
			return {"kind": "build", "building_id": assigned}
		if site.construction_state == Building.State.COMPLETE and Production.can_produce(assigned):
			return {"kind": "produce", "building_id": assigned}

	var haul := Hauling.claim_task(person.grid_pos)
	if not haul.is_empty():
		return {"kind": "haul", "task_id": int(haul["id"])}

	var nearest_producing := _nearest(person.grid_pos, func(b: Building) -> bool:
		return b.construction_state == Building.State.COMPLETE and Production.can_produce(b.id)
	)
	if nearest_producing != -1:
		return {"kind": "produce", "building_id": nearest_producing}

	var nearest_building := _nearest(person.grid_pos, func(b: Building) -> bool:
		return b.construction_state == Building.State.UNDER_CONSTRUCTION and not Buildings.is_frost_gated(b.id)
	)
	if nearest_building != -1:
		return {"kind": "build", "building_id": nearest_building}

	return {}


func _nearest(from_cell: Vector2i, eligible: Callable) -> int:
	var best_id := -1
	var best_distance := INF
	for id in Buildings.building_ids():
		var b := Buildings.get_building(id)
		if not eligible.call(b):
			continue
		var d := Vector2(b.anchor - from_cell).length_squared()
		if d < best_distance:
			best_distance = d
			best_id = id
	return best_id
