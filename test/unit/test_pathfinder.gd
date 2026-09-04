## A* over a grid: shortest routes, obstacles, no corner-cutting, and graceful failure.
## Tested against hand-built grids so it never touches the Terrain autoload.
extends GutTest

var _grid: Array = []  # rows of ints; 0 = open, 1 = wall
var _width := 0
var _height := 0


func _load(rows: Array) -> void:
	_grid = rows
	_height = rows.size()
	_width = (rows[0] as String).length()


func _walkable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= _width or cell.y >= _height:
		return false
	return (_grid[cell.y] as String)[cell.x] == "."


func _step_cost(_from: Vector2i, to: Vector2i) -> float:
	return 1.4142135623730951 if _from.x != to.x and _from.y != to.y else 1.0


func _find(start: Vector2i, goal: Vector2i) -> Array:
	return Pathfinder.find_path(start, goal, _walkable, _step_cost, 1.0)


func test_straight_line_on_open_ground() -> void:
	_load(["......", "......", "......"])
	var path := _find(Vector2i(0, 1), Vector2i(5, 1))
	assert_eq(path.front(), Vector2i(0, 1), "path starts at the start")
	assert_eq(path.back(), Vector2i(5, 1), "path ends at the goal")
	assert_eq(path.size(), 6, "six cells across, no detour")


func test_diagonal_shortcut_is_taken() -> void:
	_load(["......", "......", "......", "......", "......"])
	var path := _find(Vector2i(0, 0), Vector2i(4, 4))
	assert_eq(path.size(), 5, "a clean diagonal is five cells, not nine")


func test_it_routes_around_a_wall() -> void:
	_load([
		"......",
		"..##..",
		"..##..",
		"..##..",
		"......",
	])
	var path := _find(Vector2i(0, 2), Vector2i(5, 2))
	assert_eq(path.front(), Vector2i(0, 2))
	assert_eq(path.back(), Vector2i(5, 2))
	for cell in path:
		assert_true(_walkable(cell), "the path never crosses a wall at %s" % cell)


func test_it_does_not_cut_a_diagonal_corner_through_a_wall() -> void:
	# The only way from A to B squeezes between two walls at the diagonal.
	_load([
		".#",
		"#.",
	])
	var path := Pathfinder.find_path(Vector2i(0, 0), Vector2i(1, 1), _walkable, _step_cost, 1.0)
	assert_eq(path, [], "no legal route — the diagonal is blocked on both sides")


func test_unreachable_goal_returns_empty() -> void:
	_load([
		"...#...",
		"...#...",
		"...#...",
	])
	assert_eq(_find(Vector2i(0, 1), Vector2i(6, 1)), [], "a full-height wall cannot be passed")


func test_start_equals_goal() -> void:
	_load(["..."])
	assert_eq(_find(Vector2i(1, 0), Vector2i(1, 0)), [Vector2i(1, 0)])


func test_start_or_goal_on_a_wall_is_no_path() -> void:
	_load(["#.."])
	assert_eq(_find(Vector2i(0, 0), Vector2i(2, 0)), [], "cannot start inside a wall")


func test_path_is_contiguous_single_steps() -> void:
	_load([
		"........",
		".###.##.",
		".#...#..",
		".#.#.#..",
		"...#....",
	])
	var path := _find(Vector2i(0, 0), Vector2i(7, 4))
	assert_gt(path.size(), 0, "there is a route")
	for i in path.size() - 1:
		var delta: Vector2i = path[i + 1] - path[i]
		assert_lte(absi(delta.x), 1, "each step moves at most one cell in x")
		assert_lte(absi(delta.y), 1, "each step moves at most one cell in y")
		assert_ne(delta, Vector2i.ZERO, "no step stays in place")


func test_the_cheaper_route_wins_when_costs_differ() -> void:
	# Left corridor is length 8; right corridor is length 4. Expect the short one.
	_load([
		".....",
		".###.",
		".###.",
		".....",
	])
	var down_then_across := _find(Vector2i(0, 0), Vector2i(0, 3))
	assert_eq(down_then_across.size(), 4, "straight down the left edge, four cells")
