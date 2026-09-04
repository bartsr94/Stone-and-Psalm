## The injected random stream is reproducible from its seed and resumes mid-sequence after a
## save; the scripted double returns an exactly known sequence.
extends GutTest


func test_same_seed_gives_the_same_sequence() -> void:
	var a := Dice.new(12345)
	var b := Dice.new(12345)
	for _i in 20:
		assert_eq(a.randf(), b.randf(), "identical seeds stay in lockstep")


func test_different_seeds_diverge() -> void:
	var a := Dice.new(1)
	var b := Dice.new(2)
	var same := 0
	for _i in 20:
		if is_equal_approx(a.randf(), b.randf()):
			same += 1
	assert_lt(same, 5, "different seeds produce different streams")


func test_serialize_resumes_the_stream() -> void:
	var dice := Dice.new(999)
	for _i in 5:
		dice.randf()
	var saved := dice.serialize()

	var expected: Array[float] = []
	for _i in 5:
		expected.append(dice.randf())

	dice.deserialize(saved)
	for i in 5:
		assert_eq(dice.randf(), expected[i], "the stream continues, it does not restart")


func test_chance_bounds() -> void:
	var dice := Dice.new(7)
	for _i in 50:
		assert_false(dice.chance(0.0), "chance(0) never fires")
	for _i in 50:
		assert_true(dice.chance(1.0), "chance(1) always fires")


func test_randi_range_stays_in_bounds() -> void:
	var dice := Dice.new(42)
	for _i in 200:
		var value := dice.randi_range(3, 9)
		assert_between(value, 3, 9, "inclusive on both ends")


func test_pick_returns_a_member_or_null() -> void:
	var dice := Dice.new(3)
	var options := ["a", "b", "c"]
	for _i in 20:
		assert_has(options, dice.pick(options))
	assert_null(dice.pick([]), "nothing to pick from an empty array")


func test_scripted_dice_returns_its_script() -> void:
	var dice := ScriptedDice.new([0.1, 0.4, 0.9])
	assert_almost_eq(dice.randf(), 0.1, 0.0001)
	assert_almost_eq(dice.randf(), 0.4, 0.0001)
	assert_almost_eq(dice.randf(), 0.9, 0.0001)
	assert_false(dice.is_exhausted(), "not yet wrapped")
	assert_almost_eq(dice.randf(), 0.1, 0.0001, "wraps to the start")
	assert_true(dice.is_exhausted())


func test_scripted_dice_maps_onto_ranges() -> void:
	var dice := ScriptedDice.new([0.0, 0.5, 0.25])
	assert_almost_eq(dice.randf_range(10.0, 20.0), 10.0, 0.0001)
	assert_almost_eq(dice.randf_range(10.0, 20.0), 15.0, 0.0001)
	assert_eq(dice.randi_range(0, 3), 1, "0.25 * 4 = 1")


func test_scripted_dice_chance_uses_the_scripted_value() -> void:
	var dice := ScriptedDice.new([0.3, 0.8])
	assert_true(dice.chance(0.5), "0.3 < 0.5")
	assert_false(dice.chance(0.5), "0.8 >= 0.5")
