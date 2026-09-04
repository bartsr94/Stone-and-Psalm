## Shared vocabulary for the community: the founding orders and the classes of person in a
## house. On its own so `Liturgy`, `Population`, `Person` and the horarium calculators can all
## agree on what a Cistercian choir monk is without depending on each other.
##
## Enum order is part of the save format — **append, never reorder** (same rule as
## `TerrainTypes`).
class_name Monastic
extends RefCounted

## The founding orders modelled in v1 (`GDD` open question 5). The other three are deferred.
enum Order { CISTERCIAN, BENEDICTINE }

## What a person is in the house. `SIMULATION_SPEC.md` §4, `HISTORICAL_REFERENCE.md` §3.
enum Class {
	CHOIR_MONK,  ## professed, sings all eight offices in choir
	NOVICE,      ## in formation; same horarium as a choir monk
	CONVERSUS,   ## lay brother; a short office at the workplace, choir on Sundays and feasts
	FAMULUS,     ## hired servant; no office
}

const _ORDER_KEYS := {Order.CISTERCIAN: "cistercian", Order.BENEDICTINE: "benedictine"}
const _CLASS_NAMES := {
	Class.CHOIR_MONK: "choir monk",
	Class.NOVICE: "novice",
	Class.CONVERSUS: "conversus",
	Class.FAMULUS: "famulus",
}


## The lowercase key an order uses in `data/liturgical_calendar.json` and `data/orders.json`.
static func order_key(order: Order) -> String:
	return _ORDER_KEYS.get(order, "cistercian")


static func class_name_of(person_class: Class) -> String:
	return _CLASS_NAMES.get(person_class, "?")


## True if this class keeps the full choir horarium (all eight offices, chapter, lectio).
static func is_choir(person_class: Class) -> bool:
	return person_class == Class.CHOIR_MONK or person_class == Class.NOVICE
