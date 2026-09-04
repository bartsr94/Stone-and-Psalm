# CLAUDE.md — Stone and Psalm

Orientation for working in this codebase. **Read this first, then the doc you need:**

| Question | Document |
|---|---|
| What is this game? | `docs/GDD_STONE_AND_PSALM.md` |
| **What must the simulation actually compute?** | `docs/SIMULATION_SPEC.md` |
| Is this historically right? | `docs/reference/HISTORICAL_REFERENCE.md` |
| Where does code live and why? | `docs/ARCHITECTURE_GUIDE.md` |
| What are we building next? | `docs/planning/ROADMAP.md` |
| What's done and what's broken? | `STATUS.md` |

---

## What this is

A historically grounded 3D monastery builder set in a Yorkshire dale, 1132–1348. *Banished*'s
simulation model and northern look, *Anno*'s production-chain depth, and *The Name of the Rose*'s
institutional tension. **No combat, no fantasy, no invented religion** — the antagonists are
winter, arithmetic, and the liturgical calendar.

You choose which real religious order founds the house — Benedictine, Cistercian, Cluniac,
Carthusian or Premonstratensian — and that choice is an argument about **how a day should be
spent**, not a stat block.

**This project exists to learn 3D and visual work.** That goal shapes the roadmap more than
anything else (see *The one risk that matters* below).

---

## Stack

**Godot 4.6.1** (`C:\Users\Bart\Documents\Godot_v4.6.1-stable_win64.exe`), Forward+ / D3D12,
**GDScript only**, Godot Physics 3D (no Jolt). Tests: **GUT 9.6.0** — pinned deliberately, see
below.

---

## Testing

```powershell
Start-Process -FilePath "C:\Users\Bart\Documents\Godot_v4.6.1-stable_win64.exe" `
  -ArgumentList "--headless -s addons/gut/gut_cmdln.gd --path ." `
  -WorkingDirectory "C:\Users\Bart\Documents\Games\Stone and Psalm" `
  -RedirectStandardOutput "test_results.txt" -RedirectStandardError "test_errors.txt" `
  -Wait -NoNewWindow; Get-Content "test_results.txt"
```

Two gotchas already paid for once elsewhere in this portfolio:

- **Never pipe Godot headless output with `*>&1`** — it hangs in PowerShell (vagrant-star).
  Use `-RedirectStandardOutput`.
- **GUT 9.6.0, not 9.7.1.** 9.6.0 is verified working on 4.6.1 (Star Routes, 134 tests). 9.7.1
  failed against 4.6.1 in Barbarian Prince.

---

## The Fundamental Rule — note the local variation

> **Authoritative state lives outside the scene tree.
> Transient physical state lives inside it.**

Standard portfolio separation — **but the boundary sits differently here than in Pirates of the
Misty Isles, and this matters.**

Pirates is mode-switching, so an agent's position was transient (the mode discards it).
*Stone and Psalm* is one persistent world: **a monk halfway across the precinct carrying twenty
units of fleece is real simulation state** that must survive a save and be reasoned about
headlessly.

**So logical position is authoritative here.**

| Authoritative (autoloads, headless, saved) | Transient (scene tree, never saved) |
|---|---|
| `grid_pos`, `path`, `carrying`, task | Interpolated `Vector3`, animation state |
| Every `Person` field; building inventories | Meshes, materials, particles, weather VFX |
| Clock, calendar, weather values, RNG state | Camera transform, selection highlight |

`world_renderer.gd` is the **only** autoload permitted to touch the scene tree. If you reach for
`get_tree()` anywhere else in `autoloads/`, something has gone wrong.

**The test that proves it:** `test_headless_world.gd` builds a monastery and runs fifty
simulated years with no scene tree at all. If that can't be written, the boundary has leaked.

---

## What "Banished-grade" means here

`docs/SIMULATION_SPEC.md` §1 has the full acceptance checklist. The three that get quietly
dropped and must not be:

1. **No global resource pool.** Every good exists in a specific building, stockpile, or pair of
   hands, and moves only because a person carries it. Hauling is real work competing for real
   labour.
2. **Labour is person-hours computed from daylight and the liturgical calendar**, per person,
   per day — not a flat rate. This is the game.
3. **The house must be able to die.** A reachable death spiral through ordinary mismanagement,
   legible in hindsight. `test_death_spiral` enforces it.

---

## The mechanic everything rests on

Medieval time divided **daylight into twelve hours regardless of season**. At 54°N an hour runs
~84 minutes at midsummer and ~36 at midwinter. The eight offices are anchored to those unequal
hours and each consumes a fixed number of real minutes.

**So winter takes your daylight and leaves all eight interruptions.** Productive capacity
collapses in the dark half of the year from the calendar alone, before weather is applied.

Everything else — the chains, the stores, the church that takes fifty years — is downstream of
this. `scripts/sim/unequal_hours.gd` and `scripts/sim/horarium.gd` are the two most important
files in the project.

---

## Folder layout

```
autoloads/       ← authoritative state. Headless. No scene tree (except world_renderer.gd).
scripts/sim/     ← pure static calculators: daylight, unequal_hours, horarium, computus,
                   recipe, pathfinder, needs_math. Tested exhaustively.
scripts/view/    ← reads the sim, renders it. Owns nothing.
scripts/ui/      ← Horarium, chain view, roster, chapter house, ledger.
data/            ← ALL content and ALL numbers as JSON. tuning.json holds every constant.
scenes/          ← world/ buildings/ agents/ ui/ environment/
assets/models/   ← own .glb from Blender.
assets/kit/      ← THIRD-PARTY GREYBOX. Placeholder only, never shipped.
test/            ← unit/ (mirrors autoloads + scripts/sim), integration/, soak/
docs/            ← GDD, SIMULATION_SPEC, ARCHITECTURE_GUIDE, planning/, reference/, implementations/
```

---

## 3D conventions — fixed, do not renegotiate casually

| Convention | Value |
|---|---|
| World unit | 1 unit = 1 metre |
| Terrain cell | 2 m × 2 m |
| Camera | **Orthographic**, 40° pitch fixed, 90° yaw steps |
| Materials | **One shared vertex-colour material** + one small palette texture |
| Models | glTF `.glb`, +Y up, −Z forward, transforms applied, colour attribute `Col` |
| Agents | ~600 tris, 3 bones, walk bob in the vertex shader |
| Lighting | One `DirectionalLight3D` + SSAO + SSIL + volumetric fog. **No SDFGI, no lightmaps** |

**Why vertex colours:** it skips UV unwrapping and texturing entirely — the skill that eats
months of a first 3D project and is not the skill this project exists to learn. It also makes
everything look like one game by construction rather than by discipline.

Rationale for all of the above in `docs/ARCHITECTURE_GUIDE.md` §4.

---

## Key patterns

- **Data, not hardcoded logic.** Buildings, goods, recipes, orders, feasts and events are JSON.
  Adding a building type needs an entry, a `.glb`, and zero code changes. If you write
  `if building_id == "brewhouse"`, stop and add a field.
- **All balance numbers in `data/tuning.json`.** No magic numbers in sim code, ever.
- **`Dice` is injected, never global** — a `ScriptedDice` double makes anything deterministic.
  No `randf()` in sim code.
- **Never iterate an unordered container** where order affects outcomes. Sort by `id` first.
  This is the commonest source of non-determinism in agent sims and it stays invisible until a
  soak test diverges.
- **The tick order in `SIMULATION_SPEC.md` §18 is a contract**, not a suggestion.
- **Doc comments.** Every script opens with a `##` block describing its role and any non-obvious
  behaviour.

---

## The research rule

The historical grounding is a feature, and it is also a rabbit hole. There is infinite real
material here.

> **Research produces a building, a chain, a number, or a named event. If it produces none of
> those four, it is flavour text — file it in `docs/reference/HISTORICAL_REFERENCE.md` and move
> on.** Do not open a new research thread mid-implementation.

---

## The one risk that matters

This portfolio's documented failure mode is a deep, well-tested simulation that never gets
rendered — Star Routes: 134 tests, ten systems, **zero rendering**. Frontiers Unknown: 1251
tests, paused.

`SIMULATION_SPEC.md` is twenty-two sections of extremely tempting headless work, and this
project's whole stated purpose is the opposite: **learning 3D and visual work**.

The roadmap is therefore deliberately inverted. **Phases 1–3 build a lit, seasonal 3D valley with
a monk walking around in it before a single production chain exists.**

- **Every phase's exit criteria include a screenshot or a clip.** No visual output, not finished.
- **Greybox is always acceptable.** The sim never waits on art; art never waits on the sim.
- **The Horarium UI ships in Phase 3**, not Phase 8.

If you find yourself about to build a production chain and Phase 3 isn't done, you are
reproducing the Star Routes outcome. Stop and check the roadmap.

---

## Anti-patterns

| Don't | Do |
|---|---|
| Add a global resource pool "just for food" | Goods live in a place and are carried |
| Let a view script write sim state | Views read only; writes go through autoload methods |
| `get_tree()` in a sim autoload | Only `world_renderer.gd` |
| `randf()` in sim code | Injected `Dice` |
| Hardcode a building's behaviour | Add a field to `buildings.json` |
| Put a balance number in a `.gd` file | `data/tuning.json` |
| Skip the frost gate "for now" | Core seasonal mechanic, not polish |
| Build the sim before rendering anything | Follow the roadmap phase order |
| Ship a kit asset | `assets/kit/` is greybox only |
| Add a per-model texture | One shared vertex-colour material |
| Model a building before the camera rig is fixed | Conventions first, assets second |
| Invent a historical detail | Check `HISTORICAL_REFERENCE.md`; the real answer is usually better |

---

## Current status

**Phase 0 — Foundations. Nothing built yet.** Design documentation only (v1.0). No Godot
project exists. See `STATUS.md` for live task state.
