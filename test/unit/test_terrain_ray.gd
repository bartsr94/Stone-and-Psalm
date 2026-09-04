## `TerrainRay.intersect_ground` against synthetic height fields — no `Terrain` autoload needed.
extends GutTest


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _slope(x: float, _z: float) -> float:
	return -x   # rises as x decreases, so a ray drifting in +x finds lower ground


func test_straight_down_hits_flat_ground_directly_below() -> void:
	var hit: Variant = TerrainRay.intersect_ground(Vector3(3.0, 10.0, -4.0), Vector3(0.0, -1.0, 0.0), _flat)
	assert_not_null(hit)
	assert_almost_eq((hit as Vector3).x, 3.0, 0.01)
	assert_almost_eq((hit as Vector3).y, 0.0, 0.01)
	assert_almost_eq((hit as Vector3).z, -4.0, 0.01)


func test_an_angled_ray_hits_the_slope_where_the_maths_says_it_should() -> void:
	# Ray from (0, 10, 0) toward (1, -1, 0) (unnormalized): height above ground is
	# y - (-x) = y + x. Parametrised x=t, y=10-t → crosses zero at 10 + t - t = ... solve directly:
	# p = (t, 10 - t, 0); ground = -t; height = (10 - t) - (-t) = 10. That never crosses, so use a
	# steeper descent instead: direction (1, -3, 0) → p = (t, 10 - 3t, 0); height = 10 - 3t + t = 10 - 2t;
	# crosses zero at t = 5, giving the point (5, -5, 0).
	var hit: Variant = TerrainRay.intersect_ground(Vector3(0.0, 10.0, 0.0), Vector3(1.0, -3.0, 0.0), _slope)
	assert_not_null(hit)
	assert_almost_eq((hit as Vector3).x, 5.0, 0.05)
	assert_almost_eq((hit as Vector3).y, -5.0, 0.05)


func test_a_ray_pointed_away_from_the_ground_never_hits() -> void:
	var hit: Variant = TerrainRay.intersect_ground(Vector3(0.0, 10.0, 0.0), Vector3(0.0, 1.0, 0.0), _flat)
	assert_null(hit)


func test_a_ray_already_under_the_ground_returns_its_own_origin() -> void:
	var hit: Variant = TerrainRay.intersect_ground(Vector3(1.0, -2.0, 1.0), Vector3(0.0, -1.0, 0.0), _flat)
	assert_eq(hit, Vector3(1.0, -2.0, 1.0))


func test_a_zero_direction_is_refused_not_crashed_on() -> void:
	assert_null(TerrainRay.intersect_ground(Vector3(0.0, 10.0, 0.0), Vector3.ZERO, _flat))


func test_beyond_max_distance_is_no_hit() -> void:
	# A very shallow descent that would eventually cross, but not within a short max_distance.
	var hit: Variant = TerrainRay.intersect_ground(
		Vector3(0.0, 10.0, 0.0), Vector3(1.0, -0.01, 0.0), _flat, 50.0
	)
	assert_null(hit)
