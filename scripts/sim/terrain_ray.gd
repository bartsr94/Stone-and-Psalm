## Where a ray meets the ground — the maths behind mouse-driven building placement
## (`scripts/ui/building_placement.gd`, roadmap 4.2).
##
## Pure and headless-testable: it takes the height lookup as a `Callable(x: float, z: float) ->
## float` rather than reading `Terrain` itself, so a test can hand it a flat plane or a simple
## slope without building a real valley. The terrain is not a mathematical surface, so this
## marches the ray in fixed steps looking for the step where it crosses from above ground to
## below, then bisects that bracket down to a precise point — cheap, and exact enough that no
## placement will ever visibly float or clip.
class_name TerrainRay
extends RefCounted


## The world position where `origin + t * direction` first crosses the ground, or `null` if it
## never does within `max_distance`. `direction` need not be normalized.
static func intersect_ground(
	origin: Vector3,
	direction: Vector3,
	elevation_at: Callable,
	max_distance: float = 400.0,
	step: float = 2.0
) -> Variant:
	var dir := direction.normalized()
	if dir == Vector3.ZERO:
		return null

	var prev_t := 0.0
	var prev_h := _height(origin, dir, 0.0, elevation_at)
	if prev_h <= 0.0:
		return origin   # already at or under the ground (a stray camera angle, not the normal case)

	var t := step
	while t <= max_distance:
		var h := _height(origin, dir, t, elevation_at)
		if h < 0.0:
			var root := _bisect(origin, dir, prev_t, t, elevation_at)
			return origin + dir * root
		prev_t = t
		prev_h = h
		t += step
	return null


static func _height(origin: Vector3, dir: Vector3, t: float, elevation_at: Callable) -> float:
	var p := origin + dir * t
	return p.y - float(elevation_at.call(p.x, p.z))


static func _bisect(
	origin: Vector3, dir: Vector3, lo: float, hi: float, elevation_at: Callable, iterations: int = 14
) -> float:
	var a := lo
	var b := hi
	for _i in iterations:
		var mid := (a + b) * 0.5
		if _height(origin, dir, mid, elevation_at) >= 0.0:
			a = mid
		else:
			b = mid
	return (a + b) * 0.5
