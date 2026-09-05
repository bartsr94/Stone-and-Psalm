# Stone and Psalm — Architecture Guide

**Version:** 1.0
**Date:** 2026-09-04

> How the code is organised and why. For what it must compute, see `SIMULATION_SPEC.md`.

---

## 1. Stack

| | |
|---|---|
| **Engine** | Godot **4.6.1** stable — `C:\Users\Bart\Documents\Godot_v4.6.1-stable_win64.exe` (already installed) |
| **Renderer** | Forward+ / D3D12 |
| **Language** | GDScript only |
| **Physics** | Godot Physics 3D. No Jolt — we have no rigid-body simulation worth the dependency. |
| **Tests** | GUT **9.6.0** (`addons/gut/`) |

### 1.1 Why 4.6.1 and not 4.6.2-mono

4.6.2 mono is installed but we do not need C#. GDScript keeps the whole portfolio consistent
and keeps headless test invocation simple. Do not introduce C# for performance without first
proving a bottleneck with a profiler — see §9.

### 1.2 Why GUT 9.6.0 specifically

9.6.0 is the version verified working in Star Routes (134 passing tests). **GUT 9.7.1 failed
against Godot 4.6.1 in Barbarian Prince** — this cost real time once already. Pin 9.6.0 and
verify headless before writing the first test.

---

## 2. The Fundamental Rule — adapted for a persistent world

The portfolio's standard is:

> **Authoritative state lives outside the scene tree. Transient physical state lives inside it.**

That holds here, but **the boundary sits in a different place than in Pirates of the Misty
Isles**, and getting this wrong would poison the whole project. Read this section carefully.

### 2.1 Why the boundary moves

Pirates is a **mode-switching** game: you enter Battle Mode, things happen, you leave, and the
ship's grid position is discarded because the mode is gone. Position was therefore transient.

*Stone and Psalm* is a **single persistent world**. A monk halfway across the precinct carrying
twenty units of fleece is not decoration — that is real simulation state which must survive a
save, and which the sim must be able to reason about headlessly.

**So in this project, logical position is authoritative.**

### 2.2 The split

| Authoritative — autoloads, pure GDScript, headless, saved | Transient — scene tree, dies with the scene, never saved |
|---|---|
| `grid_pos` (Vector2i), current `path`, `carrying` | Interpolated `Vector3` between substeps |
| Task, job assignment, work block spans | `AnimationPlayer` state, current frame |
| Every `Person` field (§4 of the Sim Spec) | Mesh instances, materials, LOD state |
| Building inventories, construction progress | Particle systems, smoke, weather VFX |
| Clock, calendar, weather values | Camera transform, cursor, selection highlight |
| Terrain cell data | `MeshInstance3D` terrain chunks, decals |
| RNG stream state | Anything you could delete and rebuild from sim state |

### 2.3 The contract

The sim **never** looks at the scene tree. The scene tree reads the sim every frame and renders
whatever it finds.

```gdscript
## scripts/view/monk_view.gd
## Presentation only. Owns no authoritative state.
func _process(delta: float) -> void:
    var p: Dictionary = Population.get_person_view(person_id)
    # Sim moves in discrete 10-minute substeps; the view smooths between them.
    var target := Terrain.grid_to_world(p.grid_pos)
    global_position = global_position.lerp(target, delta * LERP_RATE)
    _play_animation_for(p.state)
```

`WorldRenderer` is the **only** autoload permitted to touch the scene tree. If you reach for
`get_tree()` in any other autoload, something has gone wrong.

**The payoff:** the entire simulation runs headless at 10,000× for soak tests, every balance
question is a unit test, and a save file stores what matters instead of animation frames.

### 2.4 The test that proves it

`test_headless_world.gd` must construct a full monastery, run **fifty simulated years**, and
assert on the outcome — **with no scene tree instantiated at all.** If that test cannot be
written, the boundary has been violated somewhere.

---

## 3. Folder layout

```
autoloads/           ← authoritative state. Headless. No scene tree (except world_renderer.gd).
  sim_clock.gd           calendar, unequal hours, daylight
  liturgy.gd             offices, feast ranks, fast days
  population.gd          every Person; needs, health, devotion, life events
  labour.gd              daily work-block computation; the job queue
  terrain.gd             the cell grid; deposits, fertility, water
  buildings.gd           building records, inventories, construction
  production.gd          recipe execution
  hauling.gd             goods movement tasks
  economy.gd             silver, market, contracts, obligations
  institutions.gd        visitation, patron, orthodoxy
  granges.gd             off-map nodes
  event_system.gd        data-driven events
  save_manager.gd        serialize / deserialize orchestration
  world_renderer.gd      THE ONLY autoload that touches the scene tree

scripts/sim/         ← pure, stateless calculators. Static functions over numbers. Tested hard.
  daylight.gd            solar declination -> sunrise/sunset at a latitude
  unequal_hours.gd       daylight -> the twelve hours and four vigiliae
  horarium.gd            offices + obligations -> work blocks for a person
  recipe.gd              input/output/labour resolution
  pathfinder.gd          A* over the terrain grid
  needs_math.gd          health/devotion deltas from conditions
  computus.gd            Easter, and the moveable feasts from it

scripts/view/        ← presentation. Reads the sim, renders it. Owns nothing.
scripts/ui/          ← Horarium, chain view, roster, chapter house, ledger.

data/                ← ALL content and ALL numbers as JSON.
  tuning.json            every balance constant in the game
  orders.json            the five founding orders
  goods.json
  recipes.json
  buildings.json
  liturgical_calendar.json
  terrain_presets.json
  events/*.json
  names/*.json           religious and secular name pools

scenes/
  world/                 terrain chunks, the precinct
  buildings/             one scene per building type
  agents/                monk, conversus, famulus
  ui/
  environment/           WorldEnvironment, seasonal lighting rigs

assets/
  models/                .glb from Blender
  materials/             the shared vertex-colour material, palette texture
  kit/                   THIRD-PARTY GREYBOX KIT. Placeholder only. Never shipped.

test/
  unit/                  mirrors autoloads/ and scripts/sim/
  integration/           multi-system: a working year, a death spiral
  soak/                  50-year headless runs

docs/                  ← this doc set
tools/                 ← Blender export scripts, data validators
```

---

## 4. 3D conventions — fix these before modelling anything

Changing these later means remaking every asset. Decide once, here.

| Convention | Value |
|---|---|
| **World unit** | 1 unit = **1 metre** |
| **Terrain cell** | **2 m × 2 m** |
| **Building grid snap** | 1 m; buildings occupy whole cells |
| **Up axis** | +Y (Godot default) |
| **Model forward** | −Z (Godot default). Blender export must match — see §4.3 |
| **Camera projection** | **Orthographic** |
| **Camera pitch** | **40°**, fixed |
| **Camera yaw** | Continuous 360° middle-mouse orbit; Q/E step 90° over 0.25 s |
| **Ortho size range** | 20 m (close) to 160 m (precinct overview) |
| **Shadows** | One `DirectionalLight3D`, 4 cascades, 150 m range |
| **Texture filter** | Linear + mipmaps (this is not pixel art) |

### 4.1 The art pipeline — vertex colours, one material

**Every mesh uses one shared `StandardMaterial3D` with `vertex_color_use_as_albedo = true`,
plus one small palette texture for the few things that need detail (thatch, glass, cloth).**

The reasons, in order of importance:

1. **It skips UV unwrapping and texturing entirely.** That is the skill that consumes months of
   a first 3D project, and it is not the skill this project exists to learn.
2. One material means aggressive batching and trivially consistent lighting.
3. A fixed palette makes everything look like it belongs to the same game, automatically — the
   exact failure the Pirates project's style-lock was designed to avoid, solved here by
   construction rather than by discipline.

Palette lives in `data/palette.json` and as a Blender colour-attribute preset in
`tools/blender/`. **Do not introduce a per-model texture without a written reason in
`docs/implementations/`.**

### 4.2 Greybox first, always

`assets/kit/` holds a third-party low-poly medieval kit (Kenney or equivalent, permissive
licence) used **only** as placeholder. Rules:

- The sim never waits on art. A new building type ships as a kit box first.
- Replace kit pieces with own models one at a time, each in its own implementation slice.
- **Nothing from `assets/kit/` ships in a release build.** A build check enforces this.

### 4.3 Blender export

- Export **glTF 2.0 (.glb)**, +Y up, −Z forward.
- Apply all transforms. Scale 1.0. Origin at the building's ground-centre footprint.
- Colour attribute named `Col`, stored as **sRGB byte**.
- No lights, no cameras, no armature unless the mesh is animated.
- Naming: `bld_<snake_case>.glb`, `prop_<name>.glb`, `agent_<name>.glb`.

### 4.4 Agents

- ~600 triangles each, one material.
- **3 bones** (root, torso, head) plus a walk bob in the vertex shader. Not a full humanoid rig.
  At our camera distance, a proper rig is invisible cost.
- Visual class distinction is the UI: **tonsured monk in the order's habit colour**, **bearded
  conversus in undyed russet**, famulus in ordinary clothes.
- Peak on-screen agents: **250**. `MultiMeshInstance3D` is *not* needed at that count with one
  material — but profile at Phase 4 before assuming so.

### 4.5 Instancing

Use `MultiMeshInstance3D` for: trees, crops, wall segments, fence posts, stone piles, hay
cocks. Anything that appears more than ~50 times and does not animate individually.

### 4.6 Lighting and environment — where the quality actually comes from

One `WorldEnvironment`, driven by the season blender (§4.7):

- `DirectionalLight3D` — sun. Colour, angle and energy are all seasonal.
- **SSAO on, SSIL on.** These do most of the visual work in a scene made of untextured
  low-poly stone.
- **Volumetric fog**, seasonal density. This is the single biggest contributor to the northern
  look — morning mist in the valley is most of the mood.
- Sky: `ProceduralSkyMaterial` driven by season and time of day.
- **No SDFGI, no baked lightmaps.** SDFGI is too expensive for a builder; lightmap baking is
  incompatible with buildings appearing at runtime. Revisit only with profiler evidence.

### 4.7 Seasons

`scripts/view/season_blender.gd` lerps a parameter set across the year — sun colour and angle,
fog density and colour, sky tint, ground colour ramp, snow coverage (a shader parameter on the
terrain material), tree state (four `MultiMesh` variants), and water colour.

Parameters live in `data/seasons.json` as four keyframes lerped by `day_of_year`.

**This is the highest visual-payoff-per-hour system in the project.** Build it in Phase 2, not
Phase 8.

---

## 5. Performance targets

| Metric | Target |
|---|---|
| Frame rate | 60 fps at 250 agents, 120 buildings, on the dev machine |
| Sim hour (headless) | < 2 ms |
| Sim year (headless) | < 15 s at max speed |
| Save file | < 5 MB at year 50 |
| Save write | < 500 ms |

Profile before optimising. The likely hot paths, in order: pathfinding, the hourly job-queue
rebuild, and terrain chunk remeshing. Mitigations, if needed: cache paths and invalidate on
building change; rebuild the queue incrementally rather than wholesale; chunk the terrain mesh
at 32×32 cells and remesh only dirty chunks.

---

## 6. Data, not hardcoded logic

Portfolio hard rule, inherited from Barbarian Prince's 195-event graph and The Trading Post's
`tuning.ts`.

- Every building, good, recipe, order, feast and event is a **data entry**, not code.
- Adding a building type requires: an entry in `buildings.json`, a `.glb`, and **zero code
  changes**.
- If you write `if building_id == "brewhouse"`, stop and add a field to the data instead.
- **All balance numbers live in `data/tuning.json`.** No magic numbers in sim code, ever.

A `tools/validate_data.gd` script checks referential integrity across the JSON files (every
recipe input is a real good, every building references a real recipe, every recipe has a
building that can run it) and runs as part of the test suite.

---

## 7. Determinism

- **One seeded RNG stream per system.** `Dice` is injected, never global — a `ScriptedDice`
  double makes any test deterministic. Same pattern as Barbarian Prince.
- **No `randf()` in sim code.** Ever.
- **Never iterate an unordered container** where the order affects outcomes. Sort by `id` first.
  This is the most common source of non-determinism in agent sims and it is invisible until a
  soak test diverges.
- The tick order in `SIMULATION_SPEC.md` §18 is a contract, not a suggestion.

---

## 8. Save / load

Each autoload implements `serialize() -> Dictionary` / `deserialize(d: Dictionary)`.
`save_manager.gd` orchestrates, writes JSON (compressed), and stamps a schema version.

Acceptance test: save → load → 1,000 ticks, versus 1,000 ticks straight through, must produce
**identical state hashes**.

---

## 9. GDScript conventions

- Static typing everywhere. `var x: int = 0`, typed params, typed returns.
- Every script opens with a `##` doc block describing its role and any non-obvious behaviour.
- Autoloads expose methods, never raw dictionaries: `Population.get_person(id)`, not
  `Population.people[id]`.
- Pure calculators in `scripts/sim/` are `static func` on a class with no state.
- Signals for sim → view notification; never for sim → sim (that would make tick order
  implicit, which breaks §7).

---

## 10. Testing

```powershell
Start-Process -FilePath "C:\Users\Bart\Documents\Godot_v4.6.1-stable_win64.exe" `
  -ArgumentList "--headless -s addons/gut/gut_cmdln.gd --path ." `
  -WorkingDirectory "C:\Users\Bart\Documents\Games\Stone and Psalm" `
  -RedirectStandardOutput "test_results.txt" -RedirectStandardError "test_errors.txt" `
  -Wait -NoNewWindow; Get-Content "test_results.txt"
```

Two gotchas already paid for elsewhere in this portfolio:

- **Never pipe Godot headless output with `*>&1`** — it hangs in PowerShell (vagrant-star).
  Use `-RedirectStandardOutput`.
- **Pin GUT and verify headless before writing tests against it** (§1.2).

Required suites are listed in `SIMULATION_SPEC.md` §20. The non-negotiable ones:
`test_labour_budget` (the worked example must reproduce exactly), `test_death_spiral` (the house
must actually be able to die), `test_determinism`, and `test_save_load`.

---

## 11. Anti-patterns

| Don't | Do |
|---|---|
| Add a global resource pool "just for food" | Goods live in a place and are carried (Sim Spec §10) |
| Let a view script write sim state | Views read only. All writes go through autoload methods |
| Use `get_tree()` in a sim autoload | Only `world_renderer.gd` touches the scene tree |
| `randf()` in sim code | Injected `Dice` |
| Hardcode a building's behaviour | Add a field to `buildings.json` |
| Put a balance number in a `.gd` file | `data/tuning.json` |
| Skip the frost gate "for now" | It is a core seasonal mechanic, not polish |
| Build the whole sim before rendering anything | Follow the roadmap phase order — this is the portfolio's documented failure mode |
| Ship a kit asset | `assets/kit/` is greybox only, enforced by build check |
| Add a per-model texture | One shared vertex-colour material (§4.1) |
| Model a building before the camera rig is fixed | §4 conventions first, assets second |

---

## 12. Known deviations from portfolio norms

1. **Logical position is authoritative here** (§2.1), unlike Pirates. Deliberate, and justified
   by the persistent single-world design.
2. **No mode system.** One world, one scene. `WorldRenderer` replaces `ModeManager`.
3. **Third-party art is permitted as greybox** (§4.2), unlike Pirates' style-locked pipeline —
   but only as placeholder, and never in a release build.
