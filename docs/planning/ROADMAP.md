# Stone and Psalm — Roadmap

**Version:** 1.0
**Date:** 2026-09-04

> Phased build order. See `../GDD_STONE_AND_PSALM.md` for design, `../SIMULATION_SPEC.md` for
> what must be computed, and `../ARCHITECTURE_GUIDE.md` for structure.

---

## Guiding principle for phase order

The stated goal of this project is **learning 3D and the visual side of games**. This
portfolio's documented failure mode is the opposite: a deep, well-tested simulation with no
rendering ever reached (Star Routes — 134 tests, 10 systems, zero rendering; Frontiers Unknown —
1251 tests, paused at "polish").

`SIMULATION_SPEC.md` is twenty-two sections of extremely tempting headless work. Left to its own
instincts this project would produce a magnificent invisible monastery.

**So the phase order deliberately inverts the usual instinct.** Phases 1–3 build a rendered,
lit, seasonal 3D valley with a monk walking around in it **before a single production chain
exists**. The simulation arrives only once there is something to watch it happen in.

### The three structural countermeasures

1. **Every phase's exit criteria include a screenshot or a recorded clip.** A phase with no
   visual output is not finished, regardless of its test count.
2. **Greybox from `assets/kit/` is always acceptable.** The sim never waits on art, and art
   never waits on the sim.
3. **The Horarium UI ships in Phase 3**, not at the end. The core mechanic must be *visible*
   before the systems that feed it are built.

**The vertical slice is Phases 0–6.** At the end of Phase 6 the game is playable: a monastery
with a working year, a community with names, and the ability to fail.

---

## Phase 0 — Foundations

**Goal:** a Godot project that opens, runs, tests, and renders one box on a plane.

| # | Task | Notes |
|---|---|---|
| 0.1 | Create project, Forward+ / D3D12, Godot 4.6.1 | Already installed |
| 0.2 | Folder scaffold per Architecture Guide §3 | |
| 0.3 | Install GUT **9.6.0**, verify headless, pin it | Do this *before* the first test. 9.7.1 fails on 4.6.1 |
| 0.4 | Git init, `.gitignore` (`.godot/`, `test_results.txt`, `test_errors.txt`) | Every paused project here that lacked git lost history |
| 0.5 | Fix the 3D conventions table (Arch Guide §4) in code: world scale, cell size, axes | Changing these later means remaking every asset |
| 0.6 | Orthographic camera rig: 40° starting pitch, continuous middle-drag yaw/pitch, 90° key steps, zoom clamp, pan | The single most-used piece of code in the game |
| 0.7 | Download and vendor the greybox kit into `assets/kit/` | Permissive licence only. Record the licence |
| 0.8 | `WorldEnvironment` v0: sun, sky, SSAO, fog | Rough is fine; Phase 2 makes it good |
| 0.9 | `CLAUDE.md` with the verified test command | |

**Exit criteria:** `Ctrl+F5` opens a lit 3D scene showing a ground plane and one greybox
building, with a working orthographic camera you can pan, orbit and tilt by middle-drag, turn in 90° key steps, and zoom. GUT
runs headless and reports 0 tests, 0 failures. Committed. **Screenshot taken.**

---

## Phase 1 — The Valley ★ *first look phase*

**Goal:** a Yorkshire dale you want to look at. No gameplay whatsoever.

| # | Task | Notes |
|---|---|---|
| 1.1 | `Terrain` autoload: the cell grid, elevation, water, terrain type | Authoritative data only |
| 1.2 | Terrain mesh generation, chunked at 32×32 cells | Dirty-chunk remeshing from the start — retrofitting is miserable |
| 1.3 | Handcrafted valley heightmap: river, flat meadow, wooded slopes, moor above | This is the founding site. Make it a good one |
| 1.4 | River as flowing water with a shader | Gates mill and reredorter siting later |
| 1.5 | Vertex-colour material + `data/palette.json` | Arch Guide §4.1 |
| 1.6 | Trees, rocks, scrub via `MultiMeshInstance3D` | First real instancing work |
| 1.7 | Lighting pass: sun angle, SSAO, SSIL, volumetric fog | **Spend real time here.** This is where quality comes from |

**Exit criteria:** an empty Yorkshire valley at golden hour, with mist in the low ground,
that looks like a place. **Screenshot posted. If it isn't attractive, do not proceed —
iterate here.** Nothing about later phases will fix a valley that looks bad.

---

## Phase 2 — Seasons and Sky ★ *the biggest visual payoff*

**Goal:** the same valley, transformed four times.

| # | Task | Notes |
|---|---|---|
| 2.1 | `SimClock`: calendar, day/year, speed control, pause | Authoritative, headless, tested |
| 2.2 | `scripts/sim/daylight.gd`: solar declination → sunrise/sunset at 54°N | Sim Spec §2.2. Unit-tested against real solstice values |
| 2.3 | Day/night cycle driving sun angle and colour | |
| 2.4 | `season_blender.gd` + `data/seasons.json` — 4 keyframes lerped by day-of-year | Arch Guide §4.7 |
| 2.5 | Snow as a terrain shader parameter, accumulating and thawing | |
| 2.6 | Tree seasonal states (4 `MultiMesh` variants) | |
| 2.7 | Weather: daily temperature and precipitation, 3-day smoothed | Sim Spec Open Q 9 |
| 2.8 | Rain and snowfall particles | |

**Exit criteria:** a time-lapse clip of one full year in the valley — spring green, summer haze,
autumn gold, deep winter snow with a low sun. Daylight length visibly changes. **Clip recorded.**

---

## Phase 3 — One Monk Walking ★ *the core mechanic, made visible*

**Goal:** a single monk who lives by the Divine Office, and a UI that shows why.

| # | Task | Notes |
|---|---|---|
| 3.1 | `scripts/sim/unequal_hours.gd`: daylight → 12 hours + 4 vigiliae | Sim Spec §2.3. **The heart of the game** |
| 3.2 | `scripts/sim/computus.gd`: Easter, and the moveable feasts | |
| 3.3 | `Liturgy` autoload + `liturgical_calendar.json` | Offices, feast ranks, fast days |
| 3.4 | `scripts/sim/horarium.gd`: person + order + day → **work blocks** | Sim Spec §6.1. Test against the §6.4 worked example |
| 3.5 | `Person` record and `Population` autoload (minimal: identity, class, position, state) | |
| 3.6 | A* pathfinder over the terrain grid | |
| 3.7 | Agent movement on the 10-minute substep; view lerps between | Arch Guide §2.3 |
| 3.8 | Monk model (greybox), 3-bone rig, walk bob shader | Arch Guide §4.4 |
| 3.9 | **The Horarium UI** — the day as a ring: offices, work blocks, live | The signature screen. Teaches the mechanic without words |
| 3.10 | Greybox church + dormitory; monk walks to church at each office | |

**Exit criteria:** a monk sleeps in the dormitory, rises for Vigils at 2 a.m., walks to the
church, returns, and repeats the full eight-office day — and the Horarium ring visibly compresses
as the year moves from midsummer to midwinter. **Clip recorded showing summer and winter days
side by side.**

> This is the moment the game becomes itself. If it isn't legible and interesting here, the
> design has a problem and it is cheap to fix now.

---

## Phase 4 — Build and Haul

**Goal:** placing buildings, delivering materials, and carrying things.

| # | Task | Notes |
|---|---|---|
| 4.1 | `goods.json`, `buildings.json`, `Buildings` autoload | |
| 4.2 | Building placement: grid snap, validity rules, rotation, ghost preview | |
| 4.3 | Construction state machine + the **frost gate** | Sim Spec §11. Not polish — a core mechanic |
| 4.4 | Local building inventories. **No global pool** | Arch Guide §11 |
| 4.5 | Storage buildings with capacity | |
| 4.6 | `Hauling` autoload: haul tasks, pickup/dropoff | |
| 4.7 | Carried goods visible in the monk's hands | Small thing, enormous readability payoff |
| 4.8 | `Labour` autoload: the job queue and task assignment | Sim Spec §6.5 |
| 4.9 | Laborer pool + per-building worker assignment UI | Banished's model |
| 4.10 | Roads, and their haul-speed effect | Makes siting matter |
| 4.11 | Partial-construction visuals — a half-built wall must render half-built | It will stand that way for years |

**Exit criteria:** place a granary; watch conversi carry timber and stone to the site over
several days; watch it rise; watch work stop when frost arrives in November and resume in March.
**Clip recorded.**

---

## Phase 5 — The Working Year

**Goal:** production chains, food, and a year that actually has to be survived.

| # | Task | Notes |
|---|---|---|
| 5.1 | `recipes.json` + `Production` autoload | Sim Spec §9 |
| 5.2 | Chains, in this order: **timber → firewood; grain → flour → bread; barley → malt → ale** | Survival first |
| 5.3 | Fields: ploughing, sowing, growth, harvest windows, soil fertility | |
| 5.4 | Livestock as flock aggregates; shearing in June | Sim Spec Open Q 1 |
| 5.5 | Consumption: meals in the refectory, ale rations, fuel to the calefactory | |
| 5.6 | Spoilage | |
| 5.7 | Remaining chains: stone, lime, iron, wool → cloth, dairy, fish, wax → candles | |
| 5.8 | Seasonal work gating (no mortar in frost, no harvest in spring) | |
| 5.9 | **Chain view UI** — Anno-style graph with live throughput and bottleneck highlight | |

**Exit criteria:** a house of 20 survives its first winter on stores laid up in autumn — or
visibly fails to. **Screenshot of the chain view with a real bottleneck showing.**

---

## Phase 6 — The Community ★ *end of the vertical slice*

**Goal:** people with names who can die.

| # | Task | Notes |
|---|---|---|
| 6.1 | Full `Person` model: age, health, devotion, obedience, fatigue, skills, traits | Sim Spec §4 |
| 6.2 | Needs and health resolution, including the food-variety rule | Sim Spec §5 |
| 6.3 | Devotion system and its thresholds | |
| 6.4 | Conversi grievance and **revolt** | Sim Spec §5.4 |
| 6.5 | Population dynamics: postulants, novitiate, profession, ageing, illness, death | Sim Spec §12 |
| 6.6 | The twelve obedientiary offices as assignable roles | Historical Ref §3.6 |
| 6.7 | Skill growth and decay | |
| 6.8 | **Community roster UI** — every person by name, age, role, health, devotion | |
| 6.9 | Cemetery: monks who die are buried, and the graves persist | |
| 6.10 | `test_death_spiral` — prove the house can actually die | Sim Spec §20. Non-negotiable |

**Exit criteria: the vertical slice.** Found a house, staff it, survive five years, bury someone,
and be able to say from the UI exactly why they died. **Screenshot of the roster and the
cemetery.**

---

## Phase 7 — The Orders

| # | Task |
|---|---|
| 7.1 | `orders.json`; founding-choice screen |
| 7.2 | Benedictine and Cistercian fully differentiated (office durations, capital, buildings, recruitment) |
| 7.3 | Conversi as a distinct class with their own range, offices and visuals |
| 7.4 | Order-specific architecture styling (Cistercian austerity vs Benedictine elaboration) |
| 7.5 | Granges as off-map nodes; carting | Sim Spec §13 |

**Exit criteria:** two orders that demonstrably play differently over a 10-year run. **Side-by-side
screenshots of a Cistercian and a Benedictine house.**

---

## Phase 8 — The Church

| # | Task |
|---|---|
| 8.1 | Seven-stage staged construction | Sim Spec §9.1 |
| 8.2 | Per-stage models, each renderable in partial construction |
| 8.3 | Scaffolding, masons' lodge, stone-dressing on site |
| 8.4 | Devotion and liturgical capacity scaling with stage |
| 8.5 | Romanesque → Gothic remodelling |

**Exit criteria:** a fifty-year time-lapse of the church rising from timber oratory to tower.
**This is the project's hero clip.** Everything else serves it.

---

## Phase 9 — Institutions and Economy

| # | Task |
|---|---|
| 9.1 | Silver, market, seasonal prices |
| 9.2 | Wool grading, buyers, and **forward contracts** |
| 9.3 | Rents, tithes, burial fees, obits, pilgrim offerings |
| 9.4 | **Corrodies** |
| 9.5 | Debt and its spiral |
| 9.6 | **Visitation** — the annual exam and its outcomes | Sim Spec §15.1 |
| 9.7 | Patron goodwill and its demands |
| 9.8 | Taxation: royal, papal, General Chapter |
| 9.9 | Ledger UI |

**Exit criteria:** a house can be ruined by finance alone, without ever running out of food.

---

## Phase 10 — The Library

| # | Task |
|---|---|
| 10.1 | Books as individual objects: title, subject, rarity, orthodoxy risk | Sim Spec Open Q 6 |
| 10.2 | Scriptorium: parchment, ink, pigment; the 400- and 1200-hour manuscripts |
| 10.3 | Library building; lectio requires books; literacy growth |
| 10.4 | `orthodoxy_standing` and its consequences |
| 10.5 | The inquiry event chain: examination, concealment, burning, loss |
| 10.6 | Manuscript sales and commissions |

**Exit criteria:** an inquisitor arrives, and the player has a real and uncomfortable decision.

---

## Phase 11 — Art Pass

| # | Task |
|---|---|
| 11.1 | Replace every `assets/kit/` placeholder with own Blender models |
| 11.2 | Build check: fail the release build if any kit asset is referenced |
| 11.3 | Interior-less building detail pass: roofs, chimneys, doors, wear |
| 11.4 | Agent variety: habit colours, ages, tonsures, beards |
| 11.5 | Environment detail: woodsmoke, laundry, tools left leaning, animal props |
| 11.6 | Full lighting and post-process polish pass |

**Exit criteria:** no third-party art remains. **A gallery of screenshots across four seasons.**

---

## Phase 12 — Content and Polish

Events, remaining three orders, the Black Death toggle, daughter houses, tutorial, audio
(plainchant, bells, weather, tools), save/load hardening, balance passes, accessibility.

---

## Milestone summary

| Milestone | Phases | Meaning |
|---|---|---|
| **M1 — It's a place** | 0–2 | A living, seasonal valley you want to look at |
| **M2 — It's alive** | 3 | A monk lives by the Office, and you can see why it matters |
| **M3 — It's a settlement** | 4–5 | Building, hauling, production, a survivable year |
| **M4 — It's a monastery** ★ | 6 | **Vertical slice.** People with names who can die |
| **M5 — It's a game** | 7–10 | Orders, the church, institutions, the library |
| **M6 — It's finished** | 11–12 | Own art throughout, content, polish |

---

## Explicitly deferred

Church interiors during an office · nunneries · the other three orders before Phase 12 ·
cell-level grange simulation · multiplayer · mod support · procedural map generation (the
founding valley is handcrafted) · a narrative/mystery layer.

---

## Review skills available

This portfolio has review skills that apply directly. Use them at phase boundaries:

| Skill | Use at |
|---|---|
| `game-design-review` | End of Phase 0 — review this doc set before code |
| `architecture-review` | End of Phases 3, 6 — check the sim/view boundary hasn't leaked |
| `systems-balance-review` | End of Phases 5, 9 — the economy and the chains |
| `performance-review` | End of Phases 4, 6 — pathfinding and the job queue |
| `ui-review` | End of Phases 3, 5 — the Horarium and the chain view |
| `game-code-review` | Any slice |
