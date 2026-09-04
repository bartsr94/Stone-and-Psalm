Conduct a thorough performance audit on Stone and Psalm. Analyze the codebase and give
concrete, prioritized recommendations for a Godot 4.6.1 GDScript project using the Forward+
renderer (D3D12), an orthographic camera, one shared vertex-colour material, and a persistent
single-world simulation that must also run headless for fifty simulated years.

Note the project's phase (check `STATUS.md` and `docs/planning/ROADMAP.md`) — early phases have
little to audit beyond setup. The audit should still flag anything that would bite once the
full precinct, a full population of monks and conversi, seasonal weather, and the production
chains are all live simultaneously.

Performance targets are in `docs/ARCHITECTURE_GUIDE.md` §5 — check findings against those.

---

## 1. Simulation Tick Cost (headless path)

- Is the daily tick (`docs/SIMULATION_SPEC.md` §18) doing per-person work that scales badly
  with population? What population count makes a single day's tick non-trivial?
- Are `scripts/sim/` calculators (`daylight`, `unequal_hours`, `horarium`, `computus`,
  `recipe`, `pathfinder`, `needs_math`) pure and cheap, or recomputing values that only change
  once per day / once per season?
- Is anything sorting an unordered container on every tick where the sort could be done once,
  or the container kept ordered? (Sorting by `id` is required for determinism — but it should
  not be re-sorted every tick if the membership hasn't changed.)
- Does the fifty-year soak test complete in a reasonable wall-clock time, and has that time
  regressed?

## 2. Per-Frame Processing (`_process` / `_physics_process`)

- Are `_process` / `_physics_process` callbacks in `scripts/view/` doing work that could be
  event-driven — reacting to a sim signal instead of polling autoload state every frame?
- Is `world_renderer.gd` rebuilding or re-querying scene state every frame instead of updating
  on change?
- Are UI panels (Horarium, chain view, roster, ledger) polling sim state every frame instead
  of connecting to a signal / updating on the daily tick?
- Is agent position interpolation (the only thing the view should own for a monk) cheap?

## 3. Rendering — orthographic, one material, low-poly

- Is the single shared vertex-colour material actually shared across every mesh, or has a
  per-model material crept in? (Forward+ auto-instances identical mesh+material pairs — sharing
  the material is what matters; `docs/ARCHITECTURE_GUIDE.md` §4.5.)
- Are repeated props / buildings / agents using `MultiMeshInstance3D` where counts are high and
  meshes identical? Remember `MultiMeshInstance3D` has no per-instance frustum culling and
  takes LOD from the whole AABB — chunk large fields spatially.
- Agents are ~600 tris, 3 bones, walk bob in the vertex shader (§4.4) — is that budget held, or
  is anything doing per-frame CPU skinning / transform work per monk?
- Is anything transparent that doesn't need to be? Transparency breaks batching and forces
  back-to-front sorting — prefer alpha-scissor / dither.
- Lighting is one `DirectionalLight3D` + SSAO + SSIL + volumetric fog, **no SDFGI, no
  lightmaps** (§4.6). Confirm SDFGI hasn't been switched on and no lightmap bake step exists.
- Is volumetric fog density / SSIL quality set higher than the look needs?

## 4. GDScript Hotspots

- Are Dictionary/Array lookups in hot paths (per-tick per-person task assignment, per-frame
  agent updates) cached rather than recomputed?
- Are there string-formatting calls (UI text, ledger entries, tooltips) happening more often
  than the underlying state changes?
- Is any `scripts/sim/` calculator doing more work than it needs to for how often it's called?

## 5. Pathfinding & Hauling

- How is `scripts/sim/pathfinder.gd` scheduled — on demand, cached per (start, goal), or
  recomputed every time a monk needs a step? At what agent count does this dominate the tick?
- Is a haul route recomputed every tick, or only when the source/destination or the map changes?

## 6. Asset Loading & Memory

- Are `assets/blend/` source files or `assets/kit/` greybox ever loaded at runtime, or
  correctly confined to the Blender pipeline / greybox-only use?
- Are `.glb` meshes in `assets/models/` reused via the same imported resource across instances
  of the same building/agent type, or duplicated per instance?
- Is the season transition (§4.7) swapping large resources synchronously (a hitch), or is it a
  material-parameter / palette change?

## 7. Save / Load

- Does `serialize()` walk only authoritative state (`docs/ARCHITECTURE_GUIDE.md` §8), or is it
  accidentally pulling transient scene data?
- At a mature house size, is a save synchronous and large enough to cause a visible stall?

## Output Format

For each finding:
- **Location** (file, function, or system)
- **Current behaviour** (what is happening now)
- **Performance impact** (why this is costly, or why it's low-risk today but worth flagging)
- **Recommended fix** (specific change with GDScript snippet where helpful)
- **Effort estimate**: Small / Medium / Large
- **Expected gain**: Low / Medium / High

Prioritize findings as:
🔴 High – significant frame cost, stutter, or a soak-test regression; fix immediately
🟡 Medium – noticeable at scale (full precinct, full population, all chains live); address before then
🟢 Low – marginal gains, address when convenient

Start with an overall assessment (3-5 sentences) covering the biggest bottlenecks and highest
ROI areas, explicitly noting the project's current phase so early-phase findings are framed as
forward-looking rather than urgent. Then work through findings grouped by category above.
