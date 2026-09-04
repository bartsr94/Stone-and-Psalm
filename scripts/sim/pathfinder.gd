## A* over the terrain grid. `SIMULATION_SPEC.md` §6.5 (task assignment paths) and Architecture
## Guide §5 (pathfinding is the likely hot path — cache and invalidate on building change).
##
## Pure and deterministic: it takes the grid bounds and two `Callable`s — one that says whether
## a cell can be entered, one that gives the cost of a single step — and returns the cell path
## from `start` to `goal` inclusive, or an empty array if there is no route. No dependency on
## `Terrain`, so it can be tested against a hand-built grid; `terrain.gd` supplies the real
## callables.
##
## Eight-connected. Diagonal moves are blocked when both orthogonal neighbours are unwalkable
## (no cutting a corner through a wall). The heuristic is the octile distance scaled by the
## cheapest possible step, so it never overestimates and the path is optimal.
class_name Pathfinder
extends RefCounted

const _SQRT2 := 1.4142135623730951
const _ORTHO := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const _DIAG := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]


## The path of cells from `start` to `goal`, inclusive. Empty if unreachable, if either end is
## unwalkable, or if the search exceeds `max_expansions` nodes.
##
## `walkable` is `func(cell: Vector2i) -> bool`. `step_cost` is
## `func(from_cell: Vector2i, to_cell: Vector2i) -> float` and must return a value ≥
## `min_step_cost` for every legal step (the heuristic relies on it).
static func find_path(
	start: Vector2i,
	goal: Vector2i,
	walkable: Callable,
	step_cost: Callable,
	min_step_cost: float = 1.0,
	max_expansions: int = 30000
) -> Array:
	if start == goal:
		return [start] if walkable.call(start) else []
	if not walkable.call(start) or not walkable.call(goal):
		return []

	var came_from := {}
	var g_score := {start: 0.0}
	var open := _Heap.new()
	open.push(start, _octile(start, goal) * min_step_cost)
	var expansions := 0

	while not open.is_empty():
		var current: Vector2i = open.pop()
		if current == goal:
			return _reconstruct(came_from, current)

		expansions += 1
		if expansions > max_expansions:
			return []

		for neighbour in _neighbours(current, walkable):
			var tentative: float = float(g_score[current]) + float(step_cost.call(current, neighbour))
			if not g_score.has(neighbour) or tentative < float(g_score[neighbour]):
				came_from[neighbour] = current
				g_score[neighbour] = tentative
				open.push(neighbour, tentative + _octile(neighbour, goal) * min_step_cost)

	return []


## The walkable neighbours of a cell, orthogonals first then diagonals; a diagonal is only
## offered if it does not squeeze between two blocked orthogonals.
static func _neighbours(cell: Vector2i, walkable: Callable) -> Array:
	var out: Array = []
	for delta in _ORTHO:
		var n: Vector2i = cell + delta
		if walkable.call(n):
			out.append(n)
	for delta in _DIAG:
		var n: Vector2i = cell + delta
		if not walkable.call(n):
			continue
		if walkable.call(Vector2i(cell.x + delta.x, cell.y)) or walkable.call(Vector2i(cell.x, cell.y + delta.y)):
			out.append(n)
	return out


static func _octile(a: Vector2i, b: Vector2i) -> float:
	var dx := absi(a.x - b.x)
	var dy := absi(a.y - b.y)
	return float(maxi(dx, dy)) + (_SQRT2 - 1.0) * float(mini(dx, dy))


static func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array:
	var path := [current]
	while came_from.has(current):
		current = came_from[current]
		path.append(current)
	path.reverse()
	return path


## A tiny binary min-heap keyed by float priority. Godot has no built-in priority queue and a
## re-sorted Array is O(n log n) per pop; this keeps A* near O(log n) per step.
class _Heap:
	var _cells: Array[Vector2i] = []
	var _priorities: Array[float] = []

	func is_empty() -> bool:
		return _cells.is_empty()

	func push(cell: Vector2i, priority: float) -> void:
		_cells.append(cell)
		_priorities.append(priority)
		var i := _cells.size() - 1
		while i > 0:
			var parent := (i - 1) >> 1
			if _priorities[parent] <= _priorities[i]:
				break
			_swap(parent, i)
			i = parent

	func pop() -> Vector2i:
		var top := _cells[0]
		var last := _cells.size() - 1
		_swap(0, last)
		_cells.remove_at(last)
		_priorities.remove_at(last)
		var i := 0
		var size := _cells.size()
		while true:
			var left := (i << 1) + 1
			var right := (i << 1) + 2
			var smallest := i
			if left < size and _priorities[left] < _priorities[smallest]:
				smallest = left
			if right < size and _priorities[right] < _priorities[smallest]:
				smallest = right
			if smallest == i:
				break
			_swap(i, smallest)
			i = smallest
		return top

	func _swap(a: int, b: int) -> void:
		var c := _cells[a]
		_cells[a] = _cells[b]
		_cells[b] = c
		var p := _priorities[a]
		_priorities[a] = _priorities[b]
		_priorities[b] = p
