Conduct a code review focused on architecture and code quality. Analyze this repository and
evaluate it against the following criteria:

## 1. Architecture & Organization
- Is the folder/file structure logical and consistent with `docs/ARCHITECTURE_GUIDE.md` §3?
- Are concerns properly separated — `autoloads/` (authoritative state), `scripts/sim/` (pure
  static calculators), `scripts/view/` (reads the sim, renders it, owns nothing), `scripts/ui/`?
- Is there a clear and predictable pattern for where things live?
- Are modules cohesive — do they do one thing well?
- **Project-specific — the Fundamental Rule** (`docs/ARCHITECTURE_GUIDE.md` §2): does
  authoritative state (`grid_pos`, `path`, `carrying`, task, every `Person` field, building
  inventories, clock, calendar, weather, RNG state) live in autoloads, headless, saved? Does
  transient physical state (interpolated `Vector3`, animation, meshes, materials, particles,
  camera, selection highlight) stay in the scene tree and never get saved? Is `world_renderer.gd`
  the **only** autoload that touches the scene tree — no `get_tree()` anywhere else in `autoloads/`?
- **Determinism** (`docs/ARCHITECTURE_GUIDE.md` §7): no `randf()` in sim code (injected `Dice`
  only); no iteration of an unordered container where order affects outcome (sort by `id` first);
  tick order matches `docs/SIMULATION_SPEC.md` §18.
- **Data, not hardcoded logic**: any `if building_id == "..."` / `if good == "..."` branch is a
  smell — behaviour belongs in `data/*.json`. Any balance number in a `.gd` file belongs in
  `data/tuning.json`.

## 2. KISS (Keep It Simple, Stupid)
- Are there unnecessarily complex solutions where a simpler one would suffice?
- Are abstractions justified, or over-engineered for the current phase?
- Are there functions/classes doing too much?
- Is there "clever" code that sacrifices readability for brevity?

## 3. DRY (Don't Repeat Yourself)
- Are there duplicated logic blocks that should be extracted into a shared `scripts/sim/`
  calculator or an autoload method?
- Are there copy-pasted patterns across files that suggest a missing abstraction?
- Are constants, types, or configs defined in multiple places instead of `data/tuning.json`?
- Are there similar systems that could be generalized (or generalized prematurely)?

## 4. Best Practices
- Are naming conventions consistent with `docs/ARCHITECTURE_GUIDE.md` §9?
- Does every script open with a `##` doc comment describing its role and non-obvious behaviour?
- Are functions/methods small and focused?
- Is error handling consistent and present where needed?
- Any obvious code smells (long parameter lists, deep nesting, magic numbers)?
- Are dependencies managed cleanly (no circular dependencies, clear boundaries between
  `autoloads/` → `scripts/sim/`, `scripts/view/` → reads only)?

## Output Format
Structure your response as follows:

### ✅ What's done well
Brief list of things that are solid.

### ⚠️ Areas of concern
For each issue found:
- **Location**: file/folder
- **Issue**: what the problem is
- **Severity**: Low / Medium / High
- **Suggestion**: concrete recommendation to fix it

### 🗺️ Structural recommendations
Any higher-level architectural changes worth considering.

Be direct and specific. Reference actual file/folder names from the repo.
Prioritize actionable findings over generic advice. Flag any deviation from the Fundamental
Rule or the determinism rules as at least Medium severity even if the code currently "works" —
those are the seams this project is built to protect.
