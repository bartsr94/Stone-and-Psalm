## `data/goods.json` loaded and looked up. `SIMULATION_SPEC.md` §8.
extends GutTest


func test_a_known_good_resolves() -> void:
	assert_true(Goods.exists("timber"))
	assert_eq(Goods.label("timber"), "Timber")
	assert_eq(Goods.category("timber"), "raw")


func test_an_unknown_good_does_not_exist() -> void:
	assert_false(Goods.exists("no_such_good"))


func test_spoilage_matches_the_spec_placeholders() -> void:
	assert_almost_eq(Goods.spoilage_pct_per_day("bread"), 2.0, 0.0001)
	assert_almost_eq(Goods.spoilage_pct_per_day("milk"), 20.0, 0.0001)
	assert_almost_eq(Goods.spoilage_pct_per_day("fish"), 8.0, 0.0001)
	assert_almost_eq(Goods.spoilage_pct_per_day("cheese"), 0.2, 0.0001)
	assert_almost_eq(Goods.spoilage_pct_per_day("ale"), 0.5, 0.0001)
	assert_almost_eq(Goods.spoilage_pct_per_day("barley"), 0.05, 0.0001)
	assert_almost_eq(Goods.spoilage_pct_per_day("salt_fish"), 0.05, 0.0001)


func test_all_ids_are_sorted() -> void:
	var ids := Goods.all_ids()
	var sorted_copy := ids.duplicate()
	sorted_copy.sort()
	assert_eq(ids, sorted_copy)


## Referential integrity, Architecture Guide §6: every good's storable_in names a real building.
func test_storable_in_names_real_building_types() -> void:
	for good_id in Goods.all_ids():
		for building_id in Goods.storable_in(good_id):
			assert_true(
				Buildings.has_type(building_id),
				"%s claims storage in unknown building type %s" % [good_id, building_id]
			)


func test_can_be_stored_in_matches_storable_in() -> void:
	assert_true(Goods.can_be_stored_in("timber", "open_stockpile"))
	assert_false(Goods.can_be_stored_in("timber", "granary"))
