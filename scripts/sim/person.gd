## One member of the community. Every field here is authoritative state — it is reasoned about
## headlessly and it goes in the save (Architecture Guide §2.2). The interpolated `Vector3` the
## view draws is *not* here; only the logical `grid_pos`, the `path`, and what the person is
## doing.
##
## Phase 3 uses a thin slice of `SIMULATION_SPEC.md` §4: identity, class, order, position, and
## an activity. Age, health, devotion, fatigue, skills and traits arrive in Phase 6.
##
## Phase 4 adds `current_task` and the two fields that go with actually carrying something:
## `Labour.request_task` fills it in, `Population` walks the person to it and executes the
## pickup/dropoff or the labour contribution — see `population.gd`'s `_resolve_work`.
class_name Person
extends RefCounted

## What the person is currently doing. The `TO_*` states are "walking there"; on arrival they
## become the matching settled state. HAULING and BUILDING are Phase 4: carrying a good between
## two buildings, or contributing labour-hours at a construction site.
enum Activity { SLEEP, TO_CHURCH, AT_OFFICE, TO_WORK, WORKING, IDLE, HAULING, BUILDING }

var id: int = 0
var given_name: String = ""
var person_class: Monastic.Class = Monastic.Class.CHOIR_MONK
var order: Monastic.Order = Monastic.Order.CISTERCIAN

var grid_pos: Vector2i = Vector2i.ZERO
var path: Array[Vector2i] = []          ## remaining cells to walk, grid_pos not included
var target_cell: Vector2i = Vector2i.ZERO
var activity: Activity = Activity.SLEEP
var current_office: String = ""         ## which office is being sung, when AT_OFFICE

## `{}` (idle/legacy work-site), `{"kind":"haul","task_id":int,"stage":"to_pickup"/"to_dropoff"}`,
## or `{"kind":"build","building_id":int}`. Owned by `Population`; `Hauling`/`Buildings` own the
## task and building records this points at.
var current_task: Dictionary = {}
var carrying_good: String = ""
var carrying_qty: int = 0


func has_arrived() -> bool:
	return path.is_empty()


func to_dict() -> Dictionary:
	var path_flat: Array = []
	for cell in path:
		path_flat.append([cell.x, cell.y])
	return {
		"id": id,
		"given_name": given_name,
		"person_class": person_class,
		"order": order,
		"grid_pos": [grid_pos.x, grid_pos.y],
		"path": path_flat,
		"target_cell": [target_cell.x, target_cell.y],
		"activity": activity,
		"current_office": current_office,
		"current_task": current_task.duplicate(),
		"carrying_good": carrying_good,
		"carrying_qty": carrying_qty,
	}


static func from_dict(data: Dictionary) -> Person:
	var person := Person.new()
	person.id = int(data.get("id", 0))
	person.given_name = str(data.get("given_name", ""))
	person.person_class = int(data.get("person_class", Monastic.Class.CHOIR_MONK)) as Monastic.Class
	person.order = int(data.get("order", Monastic.Order.CISTERCIAN)) as Monastic.Order
	person.grid_pos = _to_cell(data.get("grid_pos", [0, 0]))
	person.target_cell = _to_cell(data.get("target_cell", [0, 0]))
	person.activity = int(data.get("activity", Activity.SLEEP)) as Activity
	person.current_office = str(data.get("current_office", ""))
	person.current_task = (data.get("current_task", {}) as Dictionary).duplicate()
	person.carrying_good = str(data.get("carrying_good", ""))
	person.carrying_qty = int(data.get("carrying_qty", 0))
	var restored: Array[Vector2i] = []
	for pair in data.get("path", []):
		restored.append(Vector2i(int(pair[0]), int(pair[1])))
	person.path = restored
	return person


static func _to_cell(pair: Variant) -> Vector2i:
	return Vector2i(int(pair[0]), int(pair[1]))
