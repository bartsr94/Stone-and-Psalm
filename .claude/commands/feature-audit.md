# Stub & Incomplete Feature Audit — Stone and Psalm

Audit the codebase for incomplete work: unimplemented systems, placeholder mechanics, stub
content, and any data or logic that exists in skeleton form but is not yet functional. Check
findings against `docs/SIMULATION_SPEC.md` and `docs/planning/ROADMAP.md`.

The goal is a prioritised backlog of everything that needs real work, so nothing gets shipped
half-finished or quietly forgotten.

---

## Step 1: Scan for Code-Level Stubs

Search for explicit markers of incomplete work:

**Keyword scan — flag every occurrence of:**
- TODO, FIXME, HACK, STUB, PLACEHOLDER, WIP, NYI
- GDScript functions whose entire body is `pass` with no meaningful logic
- Functions that return only `null`, `false`, `{}`, or `[]` with no logic
- `push_warning()` / `push_error()` calls that substitute for real handling
- Hardcoded values that should be data-driven — a `SIMULATION_SPEC.md` §22 open question still
  hardcoded rather than read from `data/`, or a balance number living in a `.gd` file instead
  of `data/tuning.json`
- Commented-out blocks that represent deferred logic rather than dead code

For each finding: file and line reference, what the stub represents, how critical it is to the
current roadmap phase.

---

## Step 2: Scan for Incomplete Systems

Review against `docs/SIMULATION_SPEC.md`. This list is the target, not a confirmed inventory —
flag anything below that doesn't exist yet as "not started" rather than assuming it does.

**Time & the core mechanic (SPEC §2)**
- Daylight-length model at 54°N not implemented or not matching §2.2
- Unequal hours (`scripts/sim/unequal_hours.gd`) — twelve daylight hours regardless of season,
  ~84 min at midsummer / ~36 at midwinter — not implemented or not driving the horarium
- The horarium (`scripts/sim/horarium.gd`) — eight offices anchored to unequal hours, each
  consuming fixed real minutes — not implemented or not subtracting from labour capacity
- Computus / liturgical calendar (`scripts/sim/computus.gd`) not implemented or feasts not
  affecting the working day

**The labour system (SPEC §6) — this is the game**
- Labour not computed as person-hours from daylight and the calendar, per person, per day —
  a flat rate instead of §6.1's daily budget computation
- Office obligations by class and order (§6.2) not differentiated
- Task assignment (§6.5) missing or not competing for real labour

**No global resource pool (SPEC §1)**
- **Specifically check**: is there any global good count, or a resource that changes without a
  person carrying it? Every good must exist in a specific building, stockpile, or pair of hands.
  Hauling must be real work. Grep for anything that looks like `resources[good] += n` at a
  global scope — that is the single most important violation to catch.

**Buildings & production (SPEC §7–9)**
- Building types in `data/*.json` present but not buildable / not doing anything
- Production chains (§9) partially wired
- The church as a multi-decade project (§9.1) — not modelled as spanning decades

**Storage, hauling, construction, population (SPEC §10–12)**
- Hauling and logistics (§10) not modelled as labour
- Construction (§11) not consuming person-hours and materials
- Population inflow/outflow/ageing (§12) missing or flat

**Failure states (SPEC §1, §17)**
- **The house must be able to die** through ordinary mismanagement, via a reachable death
  spiral legible in hindsight. Is there a `test_death_spiral` and does it actually pass by
  driving the house to collapse?

**Rendering & visual output (ROADMAP)**
- Any phase whose exit criteria include a screenshot or a clip that has no visual output yet
- The Horarium UI (due Phase 3) missing
- Lighting / seasonal environment (`docs/ARCHITECTURE_GUIDE.md` §4.6–4.7) not in place

**The boundary (ARCHITECTURE_GUIDE §2)**
- Any `get_tree()` outside `world_renderer.gd`
- Any view or UI script writing sim state instead of calling an autoload method
- Any authoritative field with no `serialize()`/`deserialize()` entry (§8)

---

## Step 3: Scan for Placeholder Content & Data

- JSON data files (`data/*.json`) that exist but contain dummy/sample entries rather than real
  content matching the GDD / SPEC
- Models in `assets/models/` that are still greybox, or third-party assets from `assets/kit/`
  used anywhere they'd ship (kit is greybox only, never shipped)
- Any `SIMULATION_SPEC.md` §22 open design question whose placeholder value is hardcoded such
  that resolving it would need a code change rather than a data edit

---

## Step 4: Summarise Findings

**By System** — group stubs and incomplete work under their SPEC section.

**By Severity**
- 🔴 Blocking — missing logic that breaks a core acceptance criterion (SPEC §1: no global pool,
  labour as person-hours, the house can die) or violates the Fundamental Rule
- 🟡 Significant — a whole SPEC-documented system with no implementation yet
- 🟢 Minor — placeholder art/text/values that don't affect simulation correctness

Call out explicitly which items are genuine gaps vs. intentional non-goals per the GDD (no
combat, no fantasy, no invented religion) — don't flag non-goals as bugs. Note where an item is
correctly deferred by the roadmap's inverted phase order (sim depth waits on Phases 1–3).
