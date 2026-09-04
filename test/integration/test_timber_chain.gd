## The first real production chain, run headlessly end to end: a woodcutters' hut fells timber,
## a sawpit turns it into sawn timber — with `Hauling`'s "production input delivery" scan (roadmap
## 5.2, `SIMULATION_SPEC.md` §10) doing the carrying, no chain-specific code anywhere. Both
## buildings are raised first, same as `test_build_and_haul.gd`.
extends GutTest

const SUBSTEPS_PER_DAY := 144   ## 1440 minutes / SimClock.MINUTES_PER_SUBSTEP


func before_each() -> void:
	Terrain.build_preset("founding_valley")
	Buildings.clear()
	Hauling.clear()
	Population.clear()


func _open_site(type_id: String, target: Vector2i = Vector2i(100, 100), max_radius: int = 60) -> Vector2i:
	for radius in range(0, max_radius):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var cell := target + Vector2i(dx, dy)
				if Buildings.can_place(type_id, cell):
					return cell
	fail_test("no buildable site found near %s for %s" % [target, type_id])
	return Vector2i(-1, -1)


func _force_weather(scripted: Array, day: int) -> void:
	Weather.set_dice(ScriptedDice.new(scripted))
	Weather.roll_day(day)


func _advance_one_day() -> void:
	for _i in SUBSTEPS_PER_DAY:
		SimClock.advance_minutes(10.0)


func test_timber_felled_at_the_hut_becomes_sawn_timber_at_the_sawpit() -> void:
	var stockpile := Buildings.seed_building(
		"open_stockpile", _open_site("open_stockpile"), 0, {"sawn_timber": 30, "nails": 4}
	)
	var hut := Buildings.place_building("woodcutters_hut", _open_site("woodcutters_hut"))
	var sawpit := Buildings.place_building("sawpit", _open_site("sawpit"))

	var stockpile_door: Vector2i = Buildings.door_cell(stockpile)
	for name in ["Brother Osric", "Brother Ediva", "Brother Wulfric"]:
		Population.add_person(name, Monastic.Class.CONVERSUS, Monastic.Order.CISTERCIAN, stockpile_door)

	SimClock.deserialize({"abs_minute": (152 - 75) * 1440.0, "speed_index": 0})   # a mild summer day

	var both_raised := false
	for _day in 40:
		_force_weather([0.5, 0.5, 0.99], SimClock.day_of_year())
		_advance_one_day()
		if (
			Buildings.get_building(hut).construction_state == Building.State.COMPLETE
			and Buildings.get_building(sawpit).construction_state == Building.State.COMPLETE
		):
			both_raised = true
			break
	assert_true(both_raised, "three conversi hauling and building should raise both within forty days")

	# Pin exactly one worker to each site — and, just as important, leave the third in the pool.
	# An assigned worker never does haul work ("assigned jobs... outrank the queue", §6.5), so
	# pinning all three would leave nobody free to carry timber from the hut to the sawpit at all.
	var ids := Population.person_ids()
	assert_true(Buildings.assign_worker(hut, ids[0]))
	assert_true(Buildings.assign_worker(sawpit, ids[1]))

	var sawn_timber_produced := false
	for _day in 60:
		_force_weather([0.5, 0.5, 0.99], SimClock.day_of_year())
		_advance_one_day()
		if Buildings.inventory_of(sawpit, "sawn_timber") > 0:
			sawn_timber_produced = true
			break

	assert_true(
		sawn_timber_produced,
		"felled timber, hauled to the sawpit by Hauling's own input-delivery scan, should turn into sawn timber"
	)
