# Stone and Psalm — Simulation Specification

**Version:** 1.0
**Date:** 2026-09-04

> **This is the authoritative definition of what the simulation must do.** The GDD says what
> the game *is*; this says what must actually be computed, in what order, from what state.
>
> The target is a **Banished-grade individual-agent simulation** — not an abstract resource
> ticker with a village skin on it. Every person is a real entity with a name, an age, a body,
> a job, a position, and a set of needs that can go unmet. Every good physically exists
> somewhere and must be physically carried to where it is used. Nothing teleports.
>
> All numbers here are **explicit placeholders** — deliberately concrete so implementation is
> never blocked on an unmade decision. They are meant to be wrong and then tuned. Every one of
> them lives in `data/tuning.json`, never in code.

---

## 1. What "Banished-grade" means — the acceptance checklist

The simulation is not done until all of these are true. This list exists so we can tell
"simulation" from "spreadsheet" without arguing about it.

| # | Requirement |
|---|---|
| 1 | Every person is an individually tracked entity with identity, age, health, skills and history. Nobody is a number in a population counter. |
| 2 | Every unit of every good exists in a specific place — a building, a stockpile, or a pair of hands. There is no global resource pool. |
| 3 | Goods only move because a person carries them. Hauling is real work, costs real time, and competes with production for labour. |
| 4 | Work is limited by **person-hours available today**, which is computed from daylight, the liturgical calendar and each person's obligations — not by a flat rate. |
| 5 | Buildings require materials delivered to the site before construction progresses, and progress persists across seasons. |
| 6 | Seasons change production, consumption, daylight, mortality and what can physically be built. |
| 7 | Resources deplete and regenerate on their own schedules (forest regrowth, soil fertility, ore exhaustion, fish stocks). |
| 8 | Needs can go unmet, and unmet needs cause illness and death, and death cascades — the **death spiral** must be reachable through ordinary mismanagement. |
| 9 | Population changes endogenously: recruitment, novitiate, ageing, illness, death, and departure. |
| 10 | The whole sim runs **headless and deterministically** from a seed, with no scene tree. |
| 11 | A save captures the exact state and reloads bit-identically. |

Requirements 8 and 10 are the ones most often quietly dropped. They are not optional.

---

## 2. Time

### 2.1 Clock

| Unit | Definition |
|---|---|
| **Sim step** | 1 sim-minute. The atomic unit of the authoritative clock. |
| **Sim hour** | 60 sim-minutes. The economy/production tick. |
| **Day** | 1440 sim-minutes. |
| **Month / Year** | Real Julian calendar, 365 days, 12 months. Leap years ignored (placeholder). |
| **Real time** | At 1× speed, **1 day = 20 real seconds** (placeholder). Speeds: pause, 1×, 3×, 10×. |

The clock is authoritative and saved. `SimClock` exposes `year, month, day, minute_of_day,
day_of_year, day_of_week`.

Agent movement is simulated on a **fixed 10-sim-minute substep** so pathing is deterministic
and independent of frame rate. Visual interpolation between substeps is presentation only
(see Architecture Guide §2).

### 2.2 Daylight at 54°N

Computed per day from `day_of_year`, not stored per day:

```
declination   = 23.44° * sin(360° * (day_of_year - 81) / 365)
hour_angle    = acos( -tan(54°) * tan(declination) )
daylight_hrs  = 2 * hour_angle / 15°
sunrise_min   = 720 - daylight_hrs * 30
sunset_min    = 720 + daylight_hrs * 30
```

Verified output of the formula above — **these are the expected values for `test_daylight`**,
tolerance ±2 min:

| Date | `day_of_year` | Daylight | Sunrise | Sunset | Unequal hour |
|---|---|---|---|---|---|
| Midsummer (Jun 21) | 172 | 16 h 53 m | 03:34 | 20:26 | **84 min** |
| Equinox (Mar 21) | 80 | 11 h 55 m | 06:02 | 17:58 | 60 min |
| Midwinter (Dec 21) | 355 | 7 h 06 m | 08:27 | 15:33 | **36 min** |

(Solar noon is fixed at minute 720; this model ignores the equation of time and refraction,
which is well within tolerance for a game.)

### 2.3 Unequal hours — the core mechanic

Daylight is divided into **twelve equal parts regardless of season** (see Historical Reference
§4.3). One "hour" runs ~84 minutes at midsummer and ~36 at midwinter.

```
unequal_hour_length = daylight_minutes / 12
hour_n_start        = sunrise_min + (n - 1) * unequal_hour_length
```

The night is divided into **four vigiliae** by the same logic, used to place Vigils.

**Consequence, and the reason this matters:** the eight offices are anchored to unequal hours,
so they occur at the same *canonical* time year-round but consume a *fixed number of real
minutes* each. In winter, a shorter day is interrupted the same eight times. Work capacity
therefore collapses in winter from the calendar alone, before weather is applied.

### 2.4 The liturgical calendar

`data/liturgical_calendar.json` defines:

- **Sundays** — no manual labour. Devotion penalty if worked.
- **Feast ranks** — `simplex`, `duplex`, `duplex maius`, `solemnity`. Higher ranks lengthen
  offices and further restrict labour.
- **Fixed feasts** (Christmas, Assumption, All Saints, patronal feast, etc.).
- **Moveable feasts** computed from Easter (computus). Easter drives Lent, Ascension,
  Pentecost, Corpus Christi.
- **Fast seasons** — Lent (40 days before Easter), Advent (4 weeks before Christmas), Ember
  days, Fridays.

Placeholder: **52 Sundays + 40 feast days = 92 days/year of restricted labour** (~25%).

---

## 3. The world

### 3.1 Terrain grid

The precinct map is a grid of cells. Placeholder: **192 × 192 cells at 2 m** = ~384 m square.

Per cell:

| Field | Type | Notes |
|---|---|---|
| `elevation` | float (m) | Drives drainage, buildability, water flow. |
| `water` | enum | `none`, `river`, `pond`, `marsh`. |
| `flow_direction` | dir | For rivers. Gates mill siting. |
| `soil_fertility` | 0.0–1.0 | Depleted by cropping, restored by fallow and manure. |
| `terrain` | enum | `meadow`, `woodland`, `moor`, `rock`, `arable`, `built`. |
| `forest_density` | 0.0–1.0 | Regrows; harvested by woodcutters. |
| `deposit` | enum + qty | `none`, `limestone`, `iron_ore`, `lead_ore`, `clay`, `building_stone`. **Finite.** |
| `occupant` | id or null | Building or construction site. |
| `passable` | bool | Derived. |
| `snow_cover` | 0.0–1.0 | Seasonal, visual + movement cost. |

### 3.2 Water — a hard constraint, not decoration

The river is the site's spine. Placement rules that must be enforced:

- **Watermill / fulling mill** — must be on a cell with `water == river` and sufficient
  `flow_direction` head. A **leat** (player-buildable channel) can carry water to a cell up to
  N cells from the river.
- **Reredorter** — must sit over a `river` or built drain cell, and **downstream** of the
  water intake. Placing it upstream contaminates the supply → illness. (Real, and a genuinely
  good puzzle.)
- **Stew ponds** — require a dammed side channel.
- **Tannery** — must be downstream of everything. It stinks and it poisons.

### 3.3 Resource regeneration

| Resource | Behaviour |
|---|---|
| **Forest** | `forest_density` regrows +0.002/day in growing season, 0 in winter. Clear-felling a region collapses regrowth (neighbour-seeded). |
| **Soil fertility** | −0.04 per harvest of the same crop; +0.02/year fallow; +0.10 per manure application. Below 0.3 → yields fall sharply. |
| **Iron / lead / limestone / clay** | Finite quantity per deposit cell. Exhausted deposits are gone permanently. |
| **Fish (stew ponds)** | Logistic growth toward pond capacity; over-fishing crashes the stock. |
| **Game / wild food** | Regenerates slowly; competes with woodland clearance. |

---

## 4. The person

Every human is a `Person` record in authoritative state. Target simulated population: **40–250**
individuals (choir monks + conversi + famuli + guests). This is deliberately small enough to
afford per-agent pathfinding and a per-agent mesh with no crowd system.

### 4.1 Fields

```
id                  : int
given_name          : String        # religious name in profession
secular_name        : String        # name before entering; used for records and flavour
person_class        : enum          { CHOIR_MONK, NOVICE, CONVERSUS, FAMULUS, GUEST,
                                      CORRODIAN, PILGRIM, TENANT }
sex                 : enum          { MALE, FEMALE }   # single-sex house; see Open Q 4
birth_year/day      : int
entered_year        : int
profession_year     : int or null   # null until professed
literacy            : 0..100        # Latin. Gates scriptorium/library/office roles.
health              : 0..100
devotion            : 0..100        # replaces "happiness"
obedience           : 0..100        # discipline; low → infractions, apostasy
fatigue             : 0..100
skills              : { skill_id -> 0..100 }
office_held         : obedientiary enum or null
assigned_job        : job_id or null
assigned_bed        : building_id or null
home_site           : PRECINCT | grange_id
grid_pos            : Vector2i
path                : Array[Vector2i]
carrying            : { good_id, qty } or null
current_task        : Task or null
state               : enum { IDLE, WALKING, WORKING, HAULING, AT_OFFICE, EATING,
                             SLEEPING, SICK, READING }
traits              : Array[trait_id]
history             : Array[LifeEvent]   # entered, professed, elected, fell ill, died
```

### 4.2 Skills

`0–100`, improve with use (+0.05/hour worked, diminishing above 70), decay −0.01/day unused.
Output scales `0.5 + skill/100`.

`farming, herding, forestry, masonry, carpentry, smithing, brewing, baking, milling, weaving,
tanning, beekeeping, fishing, gardening, healing, scribing, illuminating, administration, chant`

### 4.3 Traits

Placeholder set, drawn at entry: `devout, learned, strong, sickly, quarrelsome, gluttonous,
industrious, doubting, gifted_illuminator, gifted_chanter, worldly`.

Traits modify skill caps, devotion drift, health, and event eligibility.

---

## 5. Needs, health and devotion

### 5.1 Daily needs, per person

| Need | Requirement | Failure effect |
|---|---|---|
| **Bread** | 1.0 ration/day (≈1.5 lb). Halved on fast days. | Missed day: health −6, devotion −3. |
| **Ale** | 1.0 gallon/day (adult). | Missed day: health −2, devotion −5. Substituting water: health −4 (contamination risk). |
| **Companatum** (pottage, fish, cheese, eggs, beans) | 1.0 portion/day | Missed: health −4. |
| **Variety** | Distinct food types eaten in the last 7 days | 1 type: health −0.5/day. 2: 0. 3: +0.5/day. 4+: +1.0/day. *(Banished's model.)* |
| **Warmth** | Access to a heated calefactory Nov–Easter | Unheated winter day: health −1.5, ×2 if age > 55. |
| **Clothing** | 1 habit per 2 years, 1 pair shoes per year | Lacking: health −1/day in winter. |
| **Rest** | Sleep in a dormitory bed, both night segments | Each broken night: fatigue +8. |
| **Office attendance** | Attend the offices your class requires | Each missed: devotion −2. |
| **Lectio** | Choir monks: required reading hours | Denied (no books/light): devotion −1/day. |

### 5.2 Health

`health` drifts toward a target set by the above. Clamped 0–100.

- `health < 30` → `SICK`. Cannot work. Requires infirmary care.
- `health == 0` → death.
- Infirmary with a skilled infirmarer: +3 health/day and permits meat (Rule ch. 39 exemption).
- Age: from 50, −0.05/day; from 65, −0.15/day. Death risk rises sharply past 70.

### 5.3 Devotion — the morale system

Community mean devotion drives institutional outcomes.

Raised by: office attendance, a beautiful/complete church, relics, adequate food, observance
of the Rule, a respected abbot, feast celebration.
Lowered by: missed offices, hunger, cold, overwork, scandal, harsh discipline, worldliness
(luxurious abbot's lodging, meat-eating, excessive corrodians), visitation censure.

| Community devotion | Effect |
|---|---|
| **> 80** | Vocations increase, +10% work output, visitation praise. |
| **50–80** | Normal. |
| **30–50** | Infractions; minor scandal events. |
| **< 30** | Apostasy (monks flee), conversi unrest, visitation censure. |
| **< 15** | Risk of the house being dissolved or the abbot deposed. |

### 5.4 Conversi unrest — separate from devotion

Conversi track their own grievance score, raised by: ration cuts, denial of ale, excessive
grange isolation, harsh discipline, being worked on feast days.

| Grievance | Effect |
|---|---|
| **> 60** | Slowdown: −25% output. |
| **> 80** | **Revolt** — all conversi stop work for N days; may depart permanently. |

Historically attested (Historical Reference §3.2). This is the failure mode that punishes
squeezing your labour force.

---

## 6. The labour system — the heart of the simulation

This is the system that makes the game a monastery game rather than a village game. Specify it
first, implement it first, test it hardest.

### 6.1 Daily budget computation

Run once per day at midnight, per person:

```
1. daylight = daylight_minutes(day_of_year)
2. unequal_hour = daylight / 12
3. Place the 8 offices on the unequal-hour scale + the 4 night vigiliae.
4. For this person's class and this order, look up each office's obligation and duration.
5. Subtract obligations, meals, sleep and lectio from the 1440-minute day.
6. The remainder, chopped by the offices into discrete WORK BLOCKS, is this person's
   available labour today — as a list of (start_minute, end_minute) spans, not a total.
```

Work blocks are **spans, not a budget**. A task that needs 90 minutes cannot be done in a
40-minute block; the agent must resume it next block. Fragmentation is the winter penalty.

### 6.2 Office obligations by class and order

Base office durations in minutes (placeholder):

| Office | Base | Cistercian | Cluniac | Carthusian |
|---|---|---|---|---|
| Vigils | 90 | 75 | 150 | 120 |
| Lauds | 30 | 25 | 50 | 40 |
| Prime | 20 | 15 | 35 | 25 |
| Terce | 15 | 12 | 30 | 20 |
| Sext | 15 | 12 | 30 | 20 |
| None | 15 | 12 | 30 | 20 |
| Vespers | 30 | 25 | 55 | 40 |
| Compline | 20 | 15 | 35 | 25 |
| **Daily total** | **235** | **191** | **415** | **310** |

Plus daily **chapter meeting** (30 min, choir monks) and **morrow Mass** (30 min); **High Mass**
(45 min) on Sundays and feasts. Feast ranks multiply office duration by 1.25 / 1.5 / 2.0.

Attendance by class:

| Class | Offices attended |
|---|---|
| **Choir monk / novice** | All eight, in choir. |
| **Conversus** | A short memorised form **at the workplace** — 10 min total/day. Attends in choir on Sundays and feasts only. |
| **Famulus** | None. |
| **Carthusian monk** | Most offices **alone in cell**; community only for Vigils, Lauds, Vespers. |

### 6.3 Lectio divina

Choir monks only. Placeholder: **180 min/day**, rising to 240 in Lent. Requires a book
available from the library and adequate light (daylight, or candles — which consumes wax).

Reduced lectio is possible by decree but costs devotion (−3/day) and slows literacy growth.
**This is a real player lever**: trade formation for labour, and pay for it.

### 6.4 Worked example — the whole point of the system

A Cistercian house, one choir monk and one conversus:

| | Midsummer | Midwinter |
|---|---|---|
| Daylight | 16 h 53 m | 7 h 06 m |
| Unequal hour | 84 min | 36 min |
| **Choir monk** | | |
| Offices | 191 min | 191 min |
| Chapter + Mass | 60 min | 60 min |
| Lectio | 180 min | 180 min |
| Meals + sleep | 480 min | 480 min |
| **Manual labour** | **~529 min (8.8 h)** | **~529 min, but only ~180 in daylight** |
| Usable outdoor labour | ~8.8 h | **~3.0 h** |
| **Conversus** | | |
| Offices | 10 min | 10 min |
| Meals + sleep | 480 min | 480 min |
| **Manual labour** | **~950 min (15.8 h)** | **~950 min, ~7 h in daylight** |
| Usable outdoor labour | ~15.8 h (daylight-capped) | **~7 h** |

Winter outdoor labour is roughly **a third** of summer. Indoor work (scriptorium, smithy,
weaving, brewing) is unaffected and becomes the winter economy — which is exactly why medieval
houses did their copying in winter.

### 6.5 Task assignment

A global **job queue**, rebuilt each sim-hour, holds every outstanding task with a priority:

```
Priority (placeholder, descending):
  100  Emergency (fire, flood)
   90  Food/ale distribution to refectory
   85  Fuel to the calefactory (winter only)
   80  Harvest during the harvest window
   70  Construction material delivery
   60  Production at a staffed building
   50  Hauling produced goods to storage
   40  Construction labour
   30  Field maintenance
   10  Idle work (clearing, gathering)
```

Assignment each hour, per idle person with an open work block:

1. Filter tasks to those legal for the person's class, skill and location.
2. Score `priority − travel_time_penalty + skill_bonus`.
3. Assign the best; path to it; work until the block ends or the task completes.
4. If interrupted by an office, **suspend** (partial progress persists) and resume later.

Assigned jobs (a person attached to a specific building) outrank the queue: they go to their
building and work it. The queue absorbs everyone unassigned — the **laborer pool**, exactly as
in Banished.

---

## 7. Buildings and jobs

### 7.1 Building record

```
id, type_id, grid_rect, rotation
construction_state  : { PLANNED, MATERIALS_PENDING, UNDER_CONSTRUCTION, COMPLETE, RUINED }
build_progress      : 0.0..1.0
delivered_materials : { good_id -> qty }
worker_slots        : int
assigned_workers    : Array[person_id]
inventory           : { good_id -> qty }        # local storage, capacity-limited
active_recipe       : recipe_id or null
recipe_progress     : 0.0..1.0
condition           : 0..100                    # decays; needs repair
```

### 7.2 Building types — the full first-pass list

**Claustral (devotion, housing, governance)**

| Building | Slots | Function |
|---|---|---|
| Church (staged build) | — | Offices. Quality drives devotion. The decades-long project. |
| Cloister | — | Circulation; enables lectio. |
| Chapter house | — | Governance events; abbot election. |
| Dormitory | — | Beds for choir monks. |
| Lay brothers' range | — | Beds for conversi. |
| Refectory | 2 | Meals. |
| Kitchen | 2 | Converts stores → meals. |
| Warming house | 1 | **The only heat.** Consumes firewood. |
| Reredorter | — | Sanitation. Siting rules (§3.2). |
| Infirmary | 2 | Heals the sick; permits meat. |
| Novitiate | 1 | Trains novices. |
| Abbot's lodging | — | Patron/guest relations; worldliness cost. |
| Guest house | 1 | Fulfils the hospitality obligation. |
| Gatehouse / almonry | 1 | Alms; controls entry. |
| Library | 1 | Stores manuscripts; enables lectio; scrutiny risk. |
| Scriptorium | 4 | Produces manuscripts. |

**Production**

| Building | Slots | Function |
|---|---|---|
| Woodcutter's hut | 2 | Timber from woodland. |
| Sawpit | 2 | Timber → sawn timber. |
| Charcoal stack | 1 | Timber → charcoal. |
| Quarry | 4 | Building stone, limestone. |
| Masons' lodge | 3 | Stone → dressed stone. |
| Lime kiln | 2 | Limestone + charcoal → quicklime. |
| Bloomery | 2 | Iron ore + charcoal → iron bloom. |
| Smithy | 2 | Iron → tools, nails, fittings. |
| Lead smelter | 2 | Lead ore + charcoal → lead sheet. |
| Watermill | 1 | Grain → flour. **River required.** |
| Bakehouse | 2 | Flour → bread. |
| Malthouse | 1 | Barley → malt. |
| Brewhouse | 2 | Malt → ale. |
| Fulling mill | 2 | Cloth → fulled cloth. **River required.** |
| Weaving shed | 3 | Wool → cloth. |
| Tailor's shop | 2 | Cloth → habits. |
| Tannery | 2 | Hides → leather. **Downstream siting.** |
| Chandlery | 2 | Wax → altar candles; tallow → common candles. |
| Parchmenter | 2 | Hides + quicklime → parchment. |
| Dairy | 2 | Milk → cheese, butter. |
| Salting house | 1 | Fish/meat → salt fish/salt meat. |
| Physic garden | 2 | Herbs. |
| Apothecary (in infirmary) | 1 | Herbs → medicines. |
| Apiary | 1 | Honey + beeswax. |
| Dovecote | — | Eggs, squab. |
| Stew ponds | 1 | Fish. |
| Byre / sheepfold | 2 | Livestock. |
| Fields (arable) | var | Crops on a rotation. |
| Orchard | 1 | Fruit → cider. |

**Storage**

| Building | Capacity | Holds |
|---|---|---|
| Granary | 4000 | Grain, flour, malt. Dry, vermin-proofed. |
| Tithe barn | 8000 | Bulk harvest. |
| Cellarer's undercroft | 3000 | Ale, food, general. |
| Wool store | 2000 | Fleece. |
| Open stockpile | 1000 | Stone, timber. **Spoils in rain.** |

### 7.3 Job assignment UI model

Banished's model, which we adopt: the player sets **worker counts per building**, plus a
**laborer pool** that takes queued tasks. Individual override is available (assign Brother
Aldred specifically) but never required.

---

## 8. Goods

Every good: `id, name, category, unit, weight_per_unit, spoilage_rate, base_price, storable_in`.

| Category | Goods |
|---|---|
| **Raw** | timber, building_stone, limestone, iron_ore, lead_ore, clay, peat, wool_fleece, hides, milk, eggs, honey, beeswax, wheat, rye, barley, oats, peas, beans, hay, flax, herbs, fish, oak_galls, sand, wild_food |
| **Intermediate** | sawn_timber, charcoal, dressed_stone, quicklime, mortar, iron_bloom, wrought_iron, flour, malt, cloth, fulled_cloth, leather, tallow, parchment, ink, pigment, lead_sheet, wax |
| **Finished** | bread, ale, cheese, butter, salt_fish, salt_meat, cider, habits, shoes, candles_wax, candles_tallow, tools, nails, medicines, **manuscripts** |
| **Abstract** | silver (coin), devotion, prestige, orthodoxy_standing |

**Spoilage** (placeholder, %/day in appropriate storage): bread 2.0, milk 20.0, fish 8.0,
cheese 0.2, ale 0.5, grain 0.05, salt_fish 0.05. Open stockpiles double the rate.

---

## 9. Production chains

Every recipe: inputs → outputs, **labour-hours**, required skill, building, season gate.

Placeholder values, one worker at skill 50, per batch:

| # | Chain | Inputs | Output | Labour-h | Building |
|---|---|---|---|---|---|
| 1 | Felling | — (woodland cell) | 10 timber | 4 | Woodcutter |
| 2 | Sawing | 10 timber | 8 sawn_timber | 3 | Sawpit |
| 3 | Charcoal | 10 timber | 4 charcoal | 12 (burn) | Charcoal stack |
| 4 | Quarrying | — (stone deposit) | 8 building_stone | 6 | Quarry |
| 5 | Dressing | 4 building_stone | 3 dressed_stone | 5 | Masons' lodge |
| 6 | Burning lime | 6 limestone + 2 charcoal | 4 quicklime | 8 | Lime kiln |
| 7 | Mortar | 2 quicklime + 4 sand | 5 mortar | 1 | On site. **Frost-blocked.** |
| 8 | Smelting iron | 8 iron_ore + 6 charcoal | 2 iron_bloom | 10 | Bloomery |
| 9 | Forging | 1 iron_bloom | 3 wrought_iron | 4 | Smithy |
| 10 | Toolmaking | 2 wrought_iron | 4 tools | 5 | Smithy |
| 11 | Lead | 6 lead_ore + 4 charcoal | 3 lead_sheet | 8 | Smelter |
| 12 | Ploughing/sowing | 2 grain (seed) | — (field state) | 8/field | Field. **Spring only.** |
| 13 | Harvest | — | 40 grain/field × fertility | 12/field | Field. **Autumn only.** |
| 14 | Milling | 10 grain | 8 flour | 1 (water-powered) | Watermill |
| 15 | Baking | 8 flour + 1 firewood | 20 bread | 3 | Bakehouse |
| 16 | Malting | 10 barley | 8 malt | 6 | Malthouse |
| 17 | Brewing | 8 malt + water | 30 ale | 5 | Brewhouse |
| 18 | Shearing | — (flock) | 1 fleece/sheep | 0.2/sheep | Sheepfold. **June only.** |
| 19 | Weaving | 6 wool_fleece | 4 cloth | 10 | Weaving shed |
| 20 | Fulling | 4 cloth | 4 fulled_cloth | 2 (water) | Fulling mill |
| 21 | Tailoring | 3 fulled_cloth | 2 habits | 6 | Tailor |
| 22 | Dairying | 20 milk | 4 cheese | 3 | Dairy |
| 23 | Tanning | 4 hides + 1 quicklime | 3 leather | 20 (soak) | Tannery |
| 24 | Beekeeping | — | 4 honey + 2 beeswax | 2 | Apiary. **Summer.** |
| 25 | Chandlery (altar) | 2 beeswax | 8 candles_wax | 3 | Chandlery |
| 26 | Chandlery (common) | 2 tallow | 10 candles_tallow | 2 | Chandlery |
| 27 | Fishing | — (pond stock) | 6 fish | 3 | Stew ponds |
| 28 | Salting | 10 fish + 2 salt | 9 salt_fish | 2 | Salting house |
| 29 | Herbs | — | 6 herbs | 3 | Physic garden |
| 30 | Medicines | 6 herbs + 1 honey | 4 medicines | 4 | Apothecary |
| 31 | **Parchment** | 4 hides + 2 quicklime | 12 parchment | 24 (soak+stretch) | Parchmenter |
| 32 | **Ink** | 4 oak_galls + 1 wrought_iron | 6 ink | 3 | Scriptorium |
| 33 | **Manuscript (plain)** | 30 parchment + 4 ink | 1 manuscript | **400** | Scriptorium. Literacy ≥ 60. |
| 34 | **Manuscript (illuminated)** | 30 parchment + 4 ink + 6 pigment | 1 illuminated_manuscript | **1200** | Scriptorium. Literacy ≥ 80, illuminating ≥ 70. |

Chain 33/34 are deliberately enormous: a single fine manuscript was **a year or more** of one
man's labour. That is the whole point — it makes the scriptorium a real strategic commitment
and the library a genuine treasure.

### 9.1 The church — the multi-decade project

Built in **stages**, each a separate construction job. Each completed stage raises devotion and
unlocks liturgical capacity.

| Stage | Materials (placeholder) | Labour-h |
|---|---|---|
| 1. Timber oratory | 200 sawn_timber, 40 nails | 2,000 |
| 2. Stone presbytery | 1,300 dressed_stone, 650 mortar, 300 sawn_timber, 120 lead_sheet | 22,000 |
| 3. Transepts | 1,900 dressed_stone, 950 mortar, 180 lead_sheet | 32,000 |
| 4. Nave (Romanesque) | 4,000 dressed_stone, 2,000 mortar, 400 lead_sheet, 1,300 sawn_timber | 68,000 |
| 5. Cloister ranges | 2,900 dressed_stone, 1,450 mortar, 1,000 sawn_timber | 46,000 |
| 6. Gothic remodelling | 2,600 dressed_stone, 1,300 mortar, glass, 260 lead_sheet | 56,000 |
| 7. Tower / lantern | 2,300 dressed_stone, 1,150 mortar, 200 lead_sheet | 48,000 |
| | | **274,000** |

**The arithmetic that sets these numbers.** Workable building days per year:

```
365 - 120 (frost gate, Nov 15 - Mar 15) - 62 (Sundays/feasts outside the frost window) = 183
```

| Masons dedicated | Labour-h/year | Years to complete all seven stages |
|---|---|---|
| 5 (a poor house) | 5,490 | **~50** |
| 8 | 8,784 | ~31 |
| 10 (a prosperous house) | 10,980 | ~25 |

So the full programme spans **roughly one to two generations of monks** — the founding abbot
will not see the tower. That is historically correct and it is the spine of the whole campaign.
It also means the mason count is one of the most consequential standing decisions the player
makes, because those are hands not farming.

---

## 10. Storage, hauling and logistics

**There is no global resource pool.** This is the single most important implementation rule in
this document, and the one most likely to be violated for convenience.

- A produced good is placed in its **producing building's local inventory**.
- When that inventory exceeds a threshold, a **haul task** is queued to move it to an
  appropriate store.
- A consuming building pulls from its own inventory; when short, it queues a haul task **from**
  the nearest store that holds the good.
- A person carries **max 25 units** (placeholder), modified by strength.
- Travel time is real: **1.2 m/s walking**, ×0.7 loaded, ×0.6 in snow, ×1.5 on a built road.

**Roads** are therefore a genuine investment: they cut haul time across the whole precinct.

**Consequence to design for:** siting matters enormously. A quarry across the valley from the
masons' lodge silently eats the labour budget. This is the "why is nothing getting built"
puzzle that gives a builder game its texture, and it only exists if hauling is real.

---

## 11. Construction

```
1. Player places a building. State = PLANNED.
2. Material requirements are posted as haul tasks (priority 70).
3. As materials arrive they accumulate in delivered_materials. State = MATERIALS_PENDING.
4. When all materials are present, state = UNDER_CONSTRUCTION.
5. Builders (laborer pool + masons/carpenters) contribute labour-hours.
   build_progress += hours * skill_factor / total_labour_hours
6. At 1.0, state = COMPLETE.
```

Rules:

- **Frost rule.** Any stage requiring mortar cannot progress when `temperature < 2°C`.
  Placeholder: mortar work is blocked **Nov 15 – Mar 15**, and an unfinished mortar course must
  be capped (consumes 5 thatch) or it takes frost damage (−10% progress).
- Partial progress **persists indefinitely**. A half-built nave stands half-built for years, and
  must render as such.
- Materials delivered to a cancelled site are recoverable at 50%.
- Buildings **decay**: `condition` −0.02/day, more in bad weather. Below 50, output falls; below
  20, risk of collapse. Repairs cost materials and labour.

---

## 12. Population dynamics

A monastery is celibate, so population is driven by **recruitment**, not birth. This is a
meaningful difference from Banished and it changes the whole feel: you cannot breed your way out
of a labour shortage.

### 12.1 Inflow

| Source | Rate (placeholder) | Gated by |
|---|---|---|
| **Postulants** (choir) | 0–4/year | Reputation, devotion, church quality, food security |
| **Conversi** | 0–8/year | Local prosperity, reputation, ale ration generosity |
| **Oblates** (children given) | 0–2/year | Patron and local gentry relations |
| **Famuli** (hired) | On demand | Silver, local population |
| **Transfers** from mother house | Event | Order standing |

Postulant → **novice** (1 year under the novice master) → **professed choir monk**. Novices may
leave during the novitiate (placeholder: 20% attrition; higher if devotion is low).

### 12.2 Outflow

| Cause | Trigger |
|---|---|
| **Death** | health 0; age; epidemic; accident (quarry, felling, mill). |
| **Apostasy** | devotion < 30 and obedience < 40 → chance to flee. |
| **Expulsion** | Player disciplinary action; serious infraction. |
| **Departure to a daughter house** | Endgame: an abbot + 12 monks leave permanently. |
| **Conversi departure** | After a revolt. |

### 12.3 Ageing

Aged monks (65+) stop manual labour but retain devotion and advisory value, and consume
infirmary capacity. **An ageing community with no recruitment is a real, slow failure state** —
and it is exactly what killed many houses.

---

## 13. Granges

Off-precinct satellite farms. Not fully simulated at cell level (scope control) — modelled as
**nodes**:

```
grange: { id, type, distance_days, assigned_conversi, buildings, production_rate,
          stored_goods, condition }
```

- Types: arable, sheep, cattle, iron, quarry, fishery, vineyard/orchard.
- Assigned conversi are **removed from the precinct labour pool** and live there.
- Production accrues into `stored_goods`; a **carting task** brings it in, taking
  `distance_days × 2` and requiring a cart and a draught animal.
- Granges are exposed to raids, weather and neglect; unvisited granges lose condition.
- Founding a grange requires a **land grant** (patron, purchase, or gift).

This gives expansion without exploding map scale.

---

## 14. External economy

- **Silver** in pounds/shillings/pence. Placeholder start: **£20** (Benedictine) to **£2**
  (Cistercian).
- **Market** at the nearest town (2 days' travel). Prices fluctuate seasonally and by event
  (famine raises grain, war raises iron).
- **Wool buyers** arrive in a seasonal window (placeholder: July–Sept). They offer a price per
  sack by grade. **Forward contracts** are available: take payment now for a clip delivered in
  1–3 years. Failure to deliver = debt, penalty, and reputation loss. Historically ruinous;
  should be here too.
- **Recurring obligations:** famuli wages (quarterly), royal taxation (annual), papal levy
  (event), General Chapter dues (annual).
- **Income streams:** rents, tithes, burial fees, obits, pilgrim offerings, manuscript sales,
  corrodies (§7.3 of the Historical Reference).

Debt: if silver goes negative, the house borrows (from Jewish moneylenders or Italian bankers,
both historically accurate) at interest. Sustained debt forces corrody sales and land
alienation — a documented monastic death spiral, and a good one.

---

## 15. Institutional pressure

### 15.1 Visitation

Annual (Cistercian: from the mother house; Benedictine: from the bishop). Scores the house on:

`observance of the Rule · fabric condition · financial solvency · care of the sick and poor ·
discipline · liturgical adequacy · library and learning`

Outcomes: **commendation** (+prestige, +recruitment), **admonition** (warnings), **censure**
(−prestige, forced remedies), **deposition of the abbot**, or in the extreme, **dissolution**.

This is the game's recurring "exam", and it is a genuinely different pressure from a raid.

### 15.2 Orthodoxy and the library

`orthodoxy_standing` 0–100. Lowered by holding rare/suspect texts, syncretic practice, and
scandal; raised by donations to the Church, relic acquisition, and inquisitorial cooperation.

Below a threshold → an **episcopal or inquisitorial inquiry** event chain: books examined,
possible burning, possible loss of monks. The library remains an asset *and* a liability, per
Historical Reference §9.

### 15.3 Patron

Goodwill 0–100. Expects: burial rights, perpetual prayers, hospitality on demand, and
occasionally military or political support. Rewards: land grants, cash, protection.
Displeasure: withdrawn grants, seized lands, legal harassment.

---

## 16. Events and disasters

Data-driven (`data/events/*.json`), the Barbarian Prince pattern: conditions → weighted
selection → outcomes. Never hardcoded.

| Category | Examples |
|---|---|
| **Weather** | Hard winter, wet summer (harvest rots), drought, flood (mills, ponds), storm damage. |
| **Biological** | Murrain (cattle/sheep death), crop blight, plague, dysentery from bad water. |
| **Fire** | Kitchen, bakehouse, malthouse fires. Historically the commonest monastic catastrophe. |
| **Human** | Scandal, apostasy, conversi revolt, theft, a dispute with a neighbouring lord. |
| **Institutional** | Visitation, taxation, papal levy, an inquisitor's arrival. |
| **Opportunity** | A relic offered for sale, a scholar seeking refuge, a rich corrody offer, a land grant, a commissioned manuscript. |
| **Historical** | Dated events from the real timeline for flavour and pressure. |

### 16.1 The Black Death (optional endgame, 1348)

If the campaign reaches 1348: a mortality event killing **40–60%** of the community, with
conversi recruitment permanently collapsing afterward. Historically accurate and a superb
final test. Should be **toggleable** at campaign start.

---

## 17. Failure and end states

There is no "win" in the Banished sense, but there are outcomes:

**Failure**
- Starvation/cold death spiral to zero population.
- Dissolution after sustained visitation censure.
- Insolvency: lands alienated until the house is unviable.
- Ageing out: no recruitment, community dies of old age.

**Success arcs**
- **The completed church** — all seven stages.
- **The great library** — N manuscripts, of which M illuminated.
- **The daughter house** — send an abbot and twelve monks to found a new house. Repeatable;
  each one is a filial line.
- **Survival to 1348** and beyond.

---

## 18. Tick order

Determinism requires a fixed order. **This is the contract.**

```
Per sim-minute:
  1. SimClock.advance()

Per 10-minute substep:
  2. AgentMovement.step()          # path following, arrival

Per sim-hour:
  3. Environment.tick()            # temperature, precipitation, snow
  4. Liturgy.tick()                # office start/end -> interrupt or release agents
  5. JobQueue.rebuild()
  6. TaskAssignment.tick()         # idle agents claim tasks
  7. Production.tick()             # staffed buildings consume/progress/emit
  8. Hauling.tick()                # pickup/dropoff resolution
  9. Construction.tick()           # progress, frost gate
 10. Spoilage.tick()

Per day (at minute 0):
 11. Daylight.recompute()
 12. LiturgicalCalendar.resolve()  # feast rank, fast status
 13. LabourBudget.recompute()      # per person work blocks (§6.1)
 14. Consumption.resolve()         # meals, ale, fuel
 15. Needs.update()                # health, devotion, fatigue, grievance
 16. Population.dailyTick()        # illness, death, ageing
 17. Fields.dailyTick()            # growth, ripeness
 18. Resources.regenerate()
 19. EventSystem.evaluate()

Per month:
 20. Economy.monthlyTick()         # market prices, wages, rents

Per year:
 21. Population.annualTick()       # recruitment, profession, ageing
 22. Institutions.annualTick()     # visitation, taxation, patron
 23. Grange.annualTick()
```

---

## 19. Save / load

Every autoload implements `serialize() -> Dictionary` and `deserialize(Dictionary)`.

The save must contain: clock, RNG stream states, terrain deltas, every `Person` in full
(including position, path and carried goods), every building with inventory and progress,
every grange, economy state, institutional standing, and event history.

**Acceptance test:** save → load → run 1,000 ticks; and separately run 1,000 ticks from the
same point. The two resulting states must be **byte-identical**.

---

## 20. Determinism and testing

- **One seeded RNG stream per system**, never a global. `Dice` is injected (house convention),
  so a `ScriptedDice` double makes any test deterministic.
- No `randf()` anywhere in sim code.
- No dependence on iteration order of an unordered container — sort by `id` before any
  iteration that affects outcomes.
- The entire sim runs **headless**: `godot --headless` with no scene tree, at 10,000× speed
  for soak tests.

**Required test suites:**

| Suite | Must prove |
|---|---|
| `test_daylight` | Solstice/equinox daylight values within tolerance at 54°N. |
| `test_unequal_hours` | Office placement at both solstices; block lengths correct. |
| `test_labour_budget` | The §6.4 worked example reproduces exactly, all five orders. |
| `test_production` | Every recipe's mass balance; no good created from nothing. |
| `test_hauling` | Goods never teleport; carried goods survive a save/load. |
| `test_construction` | Frost gate; partial progress persistence; material recovery. |
| `test_needs` | Each unmet need produces its stated effect. |
| `test_death_spiral` | A 30-person house with no food **does** die out — and the failure is legible in the logs. |
| `test_determinism` | Same seed, 10,000 ticks, identical state hash. |
| `test_save_load` | Byte-identical round-trip (§19). |
| `test_soak` | 50 sim-years, no crash, no NaN, no unbounded growth. |

---

## 21. Tuning constants

**All** numbers in this document live in `data/tuning.json`. No magic numbers in code — house
rule, inherited from The Trading Post's `content/tuning.ts`.

Top-level groups: `time`, `daylight`, `liturgy`, `labour`, `needs`, `health`, `devotion`,
`production`, `hauling`, `construction`, `population`, `economy`, `institutions`, `events`.

---

## 22. Open design questions

Per house convention, each carries an **explicit placeholder** so implementation is never
blocked.

| # | Question | Placeholder in force |
|---|---|---|
| 1 | Do we simulate individual sheep/cattle or flocks as aggregates? | **Aggregates** (`flock: {count, health, wool_quality}`). Revisit only if herding gameplay is thin. |
| 2 | Are granges cell-simulated or node-abstracted? | **Node-abstracted** (§13). |
| 3 | Is the interior of buildings ever entered? | **No.** Agents despawn at the door and re-emerge. Exterior-only rendering. |
| 4 | Nunneries (female houses)? | **Deferred.** Yorkshire had them and the sim supports `sex`; not in v1 scope. |
| 5 | How is the player represented — an abbot avatar, or a disembodied hand? | **Disembodied.** The abbot is an NPC you appoint. Revisit if a narrative layer is added. |
| 6 | Do we model individual books as objects, or the library as a number? | **Individual objects** with title, subject, rarity, orthodoxy risk. This is the *Name of the Rose* hook and is worth the cost. |
| 7 | Real Latin in the UI? | **Yes, sparingly** — office names, building names, with English gloss on hover. |
| 8 | Is there a fail-forward, or can the house actually die? | **It can actually die.** Non-negotiable (§1.8). |
| 9 | Weather granularity? | **Daily** temperature + precipitation, seasonally driven, with a 3-day smoothing. |
| 10 | Multi-generational time span? | **Yes.** Individual monks live and die; the house is the persistent entity. |
