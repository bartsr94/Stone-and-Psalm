Conduct a systems design audit of Stone and Psalm, identifying where mechanics interact, where
connections are underutilized or missing, and where the current code deviates from the intended
architecture.

## Context

Stone and Psalm is a historically grounded 3D monastery builder (Godot 4.6.1, GDScript only)
set in a Yorkshire dale, 1132–1348. No combat, no fantasy, no invented religion — the
antagonists are winter, arithmetic, and the liturgical calendar. The player chooses which real
religious order founds the house (Benedictine, Cistercian, Cluniac, Carthusian,
Premonstratensian), and that choice is an argument about how a day should be spent.

The mechanic everything rests on: medieval time divides **daylight into twelve hours regardless
of season**. At 54°N an hour runs ~84 min at midsummer and ~36 at midwinter. The eight offices
are anchored to those unequal hours and each consumes fixed real minutes — so winter takes the
daylight and leaves all eight interruptions, and productive capacity collapses in the dark half
of the year from the calendar alone, before weather.

Architectural pillar (`docs/ARCHITECTURE_GUIDE.md` §2): **authoritative state lives outside the
scene tree; transient physical state lives inside it.** `world_renderer.gd` is the only autoload
permitted to touch the scene tree. Logical position is authoritative here (a monk halfway
across the precinct carrying fleece is real saved state).

Core pieces as specified in `docs/SIMULATION_SPEC.md` (check the codebase for what actually
exists — this list is the target, not a confirmed inventory; flag anything not yet built as
"not started"):
- **Clock / calendar** — date, unequal-hour time-of-day, day/season ticks, computus for feasts
- **`scripts/sim/` calculators** — `daylight`, `unequal_hours`, `horarium`, `computus`,
  `recipe`, `pathfinder`, `needs_math` (pure static functions, no state)
- **The labour system** (SPEC §6) — per-person, per-day person-hours from daylight minus office
  obligations minus the calendar
- **Person state** (SPEC §4) — every `Person` field, skills, traits, needs, health, devotion
- **Buildings & inventories** (SPEC §7) — goods held in a specific place or pair of hands
- **Production chains** (SPEC §9), **storage & hauling** (SPEC §10), **construction** (SPEC §11)
- **Population dynamics** (SPEC §12), **external economy** (SPEC §14), **institutional
  pressure** (SPEC §15 — visitation, orthodoxy, patron)
- **Events & disasters** (SPEC §16), **failure and end states** (SPEC §17)
- **`world_renderer.gd`** — the only scene-tree-facing autoload
- **UI** — Horarium, chain view, roster, chapter house, ledger

---

## 1. Systems Inventory

Map out all major systems and mechanics currently in the code:
- For each, identify its inputs (what feeds into it) and outputs (what it produces or affects)
- Note which systems currently have direct connections to each other
- Flag anything from the list above that doesn't exist yet as "not started"

## 2. Connection Audit

Evaluate the existing connections:
- Which connections are strong and bidirectional?
- Which are weak or one-directional?
- Which systems are currently siloed?
- **Specifically check**: does any `scripts/view/` or `scripts/ui/` script write to
  authoritative state directly instead of going through an autoload method? Does anything
  outside `world_renderer.gd` call `get_tree()`? This is the seam where "authoritative state
  stays out of the scene tree" either holds or quietly gets bypassed for convenience.
- **Also check**: is there any global resource pool — a good count that changes without a
  person carrying it? Every connection that moves goods must route through a hauler's hands and
  real labour (SPEC §1).
- Are there connections that exist in the data/code but aren't visible to the player (e.g.
  devotion tracked internally with no UI surface, conversi unrest with no legible signal)?

## 3. Missing Connection Analysis

For each potential new connection, assess:
- **What connects**: System A ↔ System B
- **How it could work**: brief mechanical description, grounded in the actual SPEC section it implements
- **Design fit**: does this reinforce the core argument (how a day is spent, winter vs. the
  calendar, the house can die), or add scope beyond what's documented?
- **Design risk**: could a shortcut here silently violate the authoritative/transient boundary,
  introduce non-determinism (`randf()`, unordered iteration), or create a global resource pool?
- **Implementation cost**: Small / Medium / Large

## 4. Feedback Loop Analysis

Look specifically for the loops core to the design:
- **The daylight loop**: season → daylight length → unequal-hour length → office minutes as a
  share of the day → labour capacity. Is this modelled end to end, or is labour a flat rate?
- **The devotion loop** (SPEC §5.3): observance kept vs. skipped → devotion → work quality /
  departures. Real loop, or a flat value?
- **The conversi unrest loop** (SPEC §5.4): workload vs. treatment → unrest → productivity /
  flight. Modelled, or cosmetic?
- **The hauling loop** (SPEC §10): more buildings / longer distances → more hauling person-hours
  → less labour for production. Is hauling actually competing for labour?
- **The construction loop** (SPEC §9.1, §11): the church consumes labour and materials for
  decades, trading against everything else. Is the multi-decade cost real?
- **The death spiral** (SPEC §17): food deficit → weakness → less labour → larger deficit.
  Reachable through ordinary mismanagement and legible in hindsight? Does `test_death_spiral`
  enforce it?
- **Institutional pressure** (SPEC §15): drift from the order's rule → visitation findings →
  patron confidence. Connected, or tracked with no effect?

## 5. Player-Facing Legibility

Flag any case where a connection exists mechanically but has no player-facing surface yet —
especially the ones the player needs to reason about a death spiral in hindsight (the ledger,
the roster, the chain view, the Horarium).

---

## Output Format

### 🗺️ Systems Map
Textual map of current systems and their connections (autoload → autoload, autoload →
`world_renderer.gd` → scene tree, sim calculator → autoload).

### 🔗 Underutilized or Bypassed Connections
| Connection | Current State | Opportunity | Priority |
|------------|--------------|-------------|----------|

### ✨ Proposed New Connections
For each proposal:
- **[System A] ↔ [System B]**: description, grounded in the relevant SPEC section number
- Design fit, design risk, cost

### 🔄 Feedback Loop Opportunities
Most promising loops ranked by design value vs. implementation cost.

### ⚠️ Legibility Issues
Systems or connections that need a player-facing surface (UI) before they're useful.

---

Be specific and grounded in the actual systems present in this code and in the SPEC. Prioritize
connections that serve the core argument — not new mechanics or scope beyond the GDD's explicit
non-goals (no combat, no fantasy, no invented religion). After the audit, suggest a shortlist
of the 3–5 highest-priority connections to wire up next, respecting the roadmap's phase order.
