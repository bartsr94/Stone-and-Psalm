# Stone and Psalm — Status

**Last updated:** 2026-09-04
**Test count:** 47 passing (GUT 9.6.0, headless)
**Doc version:** v1.0

---

## Project Phase

**Phase 0 — Foundations** ← current, all but task 0.7 done

A lit 3D scene renders with a working orthographic camera. Phase 1 — The Valley — is next.

---

## Milestone Status

| Milestone | Phases | Status |
|---|---|---|
| M1 — It's a place | 0–2 | 🔲 Not started |
| M2 — It's alive | 3 | 🔲 Not started |
| M3 — It's a settlement | 4–5 | 🔲 Not started |
| M4 — It's a monastery ★ vertical slice | 6 | 🔲 Not started |
| M5 — It's a game | 7–10 | 🔲 Not started |
| M6 — It's finished | 11–12 | 🔲 Not started |

---

## Phase 0 Task Status

| # | Task | Status | Notes |
|---|---|---|---|
| — | Historical Reference | ✅ Done | `docs/reference/HISTORICAL_REFERENCE.md` |
| — | GDD | ✅ Done | `docs/GDD_STONE_AND_PSALM.md` |
| — | Simulation Spec | ✅ Done | `docs/SIMULATION_SPEC.md` — the "no shortcuts" definition |
| — | Architecture Guide | ✅ Done | `docs/ARCHITECTURE_GUIDE.md` |
| — | Roadmap | ✅ Done | `docs/planning/ROADMAP.md` |
| — | CLAUDE.md | ✅ Done | |
| — | Asset Pipeline doc | ✅ Done | `docs/ASSET_PIPELINE.md` |
| — | Blender pipeline scripts | ✅ Done | `tools/blender/` — validate, export, setup_material. **Verified end to end against Blender 4.5.10 LTS** — see Decision Log 2026-09-04 |
| — | Project palette | ✅ Done | `data/palette.json`, 42 entries |
| — | `.mcp.json` (godot + blender) | ✅ Done | Only active in a session run from the project dir |
| — | Git LFS | ✅ Done | `.gitattributes`; no migration needed — first commit was text only |
| 0.1 | Create Godot project (4.6.1, Forward+/D3D12) | ✅ Done | `project.godot`; `rendering_device/driver.windows="d3d12"` |
| 0.2 | Folder scaffold | ✅ Done | Architecture Guide §3 tree created, `.gitkeep`'d where empty |
| 0.3 | Install GUT 9.6.0, verify headless, pin | ✅ Done | Vendored into `addons/gut/`; 1/1 smoke test passes headless on 4.6.1 |
| 0.4 | Git init + `.gitignore` | ✅ Done | Repo existed with docs commit; `.gitignore` merged, LFS added after |
| 0.5 | Fix 3D conventions in code | ✅ Done | `data/tuning.json` + `autoloads/tuning.gd`; locked by `test_tuning.gd` |
| 0.6 | Orthographic camera rig | ✅ Done | `scripts/view/camera_rig.gd`; pan, 90° yaw steps, zoom clamp |
| 0.7 | Vendor greybox kit into `assets/kit/` | 🔲 Not started | **Decision needed.** Not required for Phase 0 — the greybox building is a `BoxMesh` |
| 0.8 | `WorldEnvironment` v0 | ✅ Done | `scenes/environment/`; sky, sun, SSAO, SSIL, volumetric fog |
| 0.9 | Verify the test command, record it in CLAUDE.md | ✅ Done | Command in CLAUDE.md works verbatim; a fresh checkout needs one `--headless --import` pass first (generates GUT's class_name cache) — not needed again after |

---

## WIP checkpoint — Phase 1 terrain, mid-lighting-pass

Session ended mid-Phase-1 to preserve budget. State is committed but **not green**:
`test_main_scene.gd` has 5 failing assertions because it still checks for Phase 0's
`Ground`/`GreyboxBuilding` nodes and a 150 m shadow range, both of which Phase 1's
`main.tscn` replaced with `TerrainRenderer` and a 400 m shadow range. Not a regression —
just a test file that needs updating to match the new scene, first thing next session.

What's built and working:

- `data/terrain_presets.json` + `autoloads/terrain.gd`: the authoritative 192×192 cell grid
  (384 m), built deterministically from tuned parameters — meandering river, elevation
  7–58 m, meadow/woodland/moor/rock bands, each valley side varying independently along
  its length (`_build_columns`) so the dale has spurs rather than being parallel ribbons.
- `scripts/sim/valley_shape.gd`, `scripts/sim/terrain_types.gd`: pure, headless-testable —
  **no unit tests written for these yet**, do that before extending them further.
- `scripts/view/terrain_renderer.gd`: chunked mesh (36 chunks, dirty-chunk remeshing),
  corner-averaged heights and colours so chunk edges and terrain-band boundaries blend.
- `scripts/view/palette.gd`: `Palette.of()` for sRGB (materials/UI) vs `Palette.vertex()`
  for linear (mesh `ARRAY_COLOR`) — **this distinction is load-bearing, not stylistic.**

Three real bugs found only by rendering, fixed, worth knowing before touching this again:

1. **Triangle winding was backwards** — the whole terrain was invisible (backface-culled)
   from the only camera angle the game uses. Fixed in `_build_chunk_mesh`'s index order.
2. **Vertex colours need `srgb_to_linear()`.** `StandardMaterial3D.albedo_color` converts
   sRGB→linear for you; `ARRAY_COLOR` does not. Feeding it a raw palette hex washes
   everything out to pale pastel — looked like a tonemap problem, wasn't one. This is why
   `Palette.vertex()` exists as a separate method from `Palette.of()`.
3. **`-s` tool scripts can't resolve autoload globals by name** (`Terrain`, `Tuning`) —
   they're not registered at that script's compile time. Reach them via
   `root.get_node_or_null("Terrain")` in throwaway render/diagnostic scripts instead.

**Not yet verified:** whether the valley actually looks good with the sRGB fix and the
400 m shadow range applied together — the last render (before the interrupt) was queued
but its output wasn't reviewed. **First thing next session: render `main.tscn` at a wide
zoom and look at it.** If it's not attractive yet, the fog/lighting numbers from the Phase 0
decision log (150 m distance, 0.004 density / 512 m length) were tuned for a small box, not
a 384 m valley — expect to retune them at this larger scale before calling task 1.7 done.

Not started: 1.3 (this preset arguably already covers "handcrafted heightmap"), 1.4 (river
shader — currently just a flat mud-coloured band, no water surface at all), 1.5 (uses the
Phase 0 material path, not yet re-pointed at `m_stone_and_psalm.tres` everywhere), 1.6
(trees/rocks via MultiMesh — `forest_density` data exists, nothing reads it yet), 1.7
(lighting pass, see above).

---

## Start here next session

**Phase 0 is complete except task 0.7**, and its exit criteria are met: `Ctrl+F5` opens a lit 3D
scene with a ground plane, one greybox building, and a working orthographic camera. 47 tests pass
headless. Screenshot at `docs/screenshots/phase0_camera_rig.png`.

Two things before Phase 1:

| # | Task | Note |
|---|---|---|
| 0.7 | Choose and vendor a greybox kit into `assets/kit/` | **Decision needed** — Kenney medieval/survival (CC0) is the leading candidate. Record the licence in `assets/kit/LICENCE.md`. Not blocking: Phase 0's building is a `BoxMesh`, and nothing needs a kit until real building types arrive in Phase 4 |
| — | Open the project in the editor once | Everything so far was authored headlessly. The editor will rewrite `.tscn`/`.tres` with resource UIDs on first save — expect one noisy diff, and let it happen in its own commit |

**Then Phase 1 — The Valley**, and its exit criterion is a screenshot you actually like. If it
isn't attractive, iterate there rather than moving on. Start with 1.1/1.2 (`Terrain` autoload and
chunked mesh generation) but budget real time for 1.7, the lighting pass — Phase 0 already showed
how much of the look comes from the environment rather than the geometry.

### Screenshots

`tools/screenshot.gd` renders a scene to a PNG, for the screenshot every phase's exit criteria
require. Must run **windowed, not headless** — the dummy renderer produces no image:

```powershell
& "C:\Users\Bart\Documents\Godot_v4.6.1-stable_win64.exe" --path . `
  -s tools/screenshot.gd -- res://scenes/world/main.tscn res://docs/screenshots/name.png
```

**Then Phase 1 is the valley, and its exit criterion is a screenshot you actually like.** If it
isn't attractive, iterate there rather than moving on — nothing later fixes a valley that looks
bad.

### Environment notes

- **`.mcp.json` only activates in a session started from this directory.** It configures `godot`
  and `blender`; Claude Code asks to approve the servers on first use.
- **`blender-mcp` is not usable yet** — it needs `uv` (`winget install --id astral-sh.uv`), then
  the addon from [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp) installed into
  Blender and its server started from the viewport sidebar. Steps in `docs/ASSET_PIPELINE.md` §6.
  It is optional; the headless scripts do not need it.
- Git LFS is active for `*.blend`, `*.glb` and images. `git lfs install --local` has been run in
  this clone; a fresh clone elsewhere needs it again.
- Installing Blender via winget needs a **UAC prompt**, so it cannot be done from a
  non-interactive agent session. Already done here.

---

## Known Gaps / Blockers

| Item | Note |
|---|---|
| **Greybox kit not chosen** | Blocks task 0.7. Kenney's medieval/survival packs are the leading candidate (CC0). Needs a licence check and a look at whether the massing suits an abbey. |
| **Valley heightmap authoring method undecided** | Handcrafted, but by what tool — Godot terrain plugin, Blender sculpt, or a hand-painted heightmap PNG? Decide in Phase 1. |
| **Liturgical calendar data not authored** | `liturgical_calendar.json` needs real feast dates. Phase 3 blocker, not Phase 0. |
| **Performance of 250 agents unproven** | Assumed fine with one material and no `MultiMesh`. Profile at Phase 4 before committing (Architecture Guide §5). |

---

## Decision Log

### 2026-09-04 — Project founded

New project. Goal: **learn 3D and the visual side of game development**, following the Pirates
of the Misty Isles pivot which traded that goal away in favour of a 2.5D pixel-art pipeline.

Concept: a *Banished*-style monastery builder with *Anno*-depth production chains and a *Name of
the Rose* institutional layer.

### 2026-09-04 — Historical setting, not Palusteria

**Considered and rejected:** setting the game in the established Palusteria universe, reusing the
1,305-line Solar Church of Imani lore from The Trading Post — which already contains six named
religious orders, a doctrinal schism, an Inquisition, and an existing "Port Iron Monastery".
That would have been a large amount of free, portfolio-connected content.

**Chosen instead:** real history — Catholic monastic orders, a Yorkshire dale, c. 1132–1348.

Rationale:

1. **The stated intent was to do historical work** rather than the usual fantasy/sci-fi.
2. **Ground truth for the 3D learning goal.** Fontenay, Fountains, Rievaulx, Le Thoronet and
   Tintern give thousands of reference photographs and measured drawings. For a project whose
   entire purpose is learning to make things look right, not having to *invent* what a chapter
   house looks like is worth more than pre-written lore.
3. **The real orders differ more than invented ones would.** Cistercian vs. Cluniac is a genuine
   historical argument about how a day should be spent — which maps directly onto the core loop.
4. Public-domain primary sources: the Rule of St Benedict, the Plan of St Gall, the *Carta
   Caritatis*, Pegolotti's wool tables.

**Cost accepted:** no reuse of the Palusteria lore, and no portfolio interconnection with The
Trading Post / Ashmark Chronicles / Palusteria Nights. The Solar Church material stays where it
is and is not migrated.

**New risk introduced:** research becoming the project. Mitigated by the research rule in
`CLAUDE.md` — research must produce a building, a chain, a number, or a named event.

### 2026-09-04 — Yorkshire over Burgundy or Poland

Burgundy (Cîteaux, Cluny, Fontenay intact) and Polish foundations (Tyniec 1044, Jędrzejów 1140)
were both considered. Yorkshire chosen for: the post-Harrying "found a house in the waste" being
literal history, the wool economy, locally available lead/iron/limestone completing every chain
without imports, the 54°N daylight swing that drives the core mechanic, and a climate palette
that matches the *Banished* visual target.

### 2026-09-04 — The Fundamental Rule adapted: position is authoritative

Unlike Pirates of the Misty Isles, where agent position is transient because modes discard it,
this is one persistent world. A monk carrying goods across the precinct is real state that must
survive a save and be reasoned about headlessly.

**Logical position (`grid_pos`, `path`, `carrying`) is therefore authoritative here**; only the
interpolated `Vector3` and animation state are transient. Documented in Architecture Guide §2 and
§12. This is a deliberate deviation, not drift.

### 2026-09-04 — Visual-first roadmap ordering

The roadmap deliberately inverts this portfolio's usual sim-first instinct. Phases 1–3 deliver a
lit, seasonal 3D valley with a monk walking by the Divine Office **before any production chain
exists**, and every phase carries a screenshot or clip as an exit criterion.

This is a direct countermeasure to the documented portfolio failure mode (Star Routes: 134 tests,
ten systems, zero rendering; Frontiers Unknown: 1251 tests, paused at polish) — a risk that is
unusually high here because `SIMULATION_SPEC.md` is deep and headless work is tempting.

### 2026-09-04 — Blender is a headless pipeline tool, not an authoring agent

Asset work is split in two (`docs/ASSET_PIPELINE.md` §1): **hero assets are modelled by hand**,
because that is the entire point of the project and because LLM-driven modelling produces
topology that needs redoing anyway; **pipeline is automated** through headless
`blender --background --python`, which costs no learning and catches conventions errors that are
invisible in Blender and expensive in Godot.

`blender-mcp` is configured but **deliberately scoped** to blockout/massing, script debugging and
one-off batch cleanup. It cannot be a build step regardless — it needs Blender running
interactively with its socket server started. The bundled AI mesh generators (Rodin, Hunyuan3D)
are not used: they emit textured meshes, which fights the vertex-colour decision below.

**Blender 4.5 LTS pinned** rather than the current 5.2.1, because Python API drift between
versions is the known way pipeline scripts break, and third-party addons lag new majors.

### 2026-09-04 — Asset pipeline verified end to end

Blender **4.5.10 LTS** installed. The full round-trip was proved with a throwaway 2 m cube,
which closes the "no Blender pipeline verified" blocker:

| Step | Result |
|---|---|
| `validate_assets.py` on a raw cube | **Correctly failed** (exit 1) on missing `Col` and missing material — and did *not* false-flag naming, transforms or origin |
| `setup_material.py -- --save` | Created `M_StoneAndPsalm`, added the `Col` attribute, assigned it |
| `validate_assets.py` again | Passed, exit 0 |
| `export_gltf.py` | Exported; **no settings were rejected by 4.5**, so the version-drift filter had nothing to drop |
| `.glb` inspection | `COLOR_0` present; 0 images, 0 textures, no UVs; Y-up; bbox `[-1,0,-1]`→`[1,2,1]`, confirming origin at ground-centre and 1 unit = 1 metre |
| Godot 4.6.1 headless import | Imports clean; `has_vertex_colors=true`; AABB pos `(-1,0,-1)` size `(2,2,2)`; material `M_StoneAndPsalm` |
| Godot material flags | **`vertex_color_use_as_albedo=true` is set automatically** by Godot's glTF importer when `COLOR_0` is present — no manual step needed. Roughness 0.85 and metallic 0.0 carry through from the Blender Principled BSDF. |

**Three bugs were found and fixed by running it**, all of which would have bitten later:

1. `report_palette()` crashed on the `_comment` key (string, not a dict), and because it ran
   *before* the save, the file silently went unwritten. Reordered so the save happens first.
2. The palette path was resolved relative to the caller's working directory. Now resolved
   relative to the script's own location.
3. **Blender exits 0 even when a Python script raises an unhandled exception.** A validator that
   "passes" because it crashed is worse than no validator. All three scripts now catch and
   `sys.exit(1)`.

### 2026-09-04 — An orthographic camera should sit as close as the geometry allows

The first render of the Phase 0 scene was a flat brown haze with the box barely visible. The
cause was the camera's distance, which had been set to 300 m on the reasoning that for an
orthographic projection distance does not affect apparent size — which is true, and is exactly
what makes it easy to set carelessly.

**Volumetric fog and `directional_shadow_max_distance` are both measured from the camera.** At
300 m every object in the scene sat beyond `volumetric_fog_length`, so all of it received the
full fog accumulation — at the authored density that left roughly 15% of the surface colour
intact. The shadow range of 150 m was likewise meaningless.

Fixed by dropping `camera.distance_m` to **150 m** — enough to clear the geometry at the widest
zoom, computed rather than guessed:

| Constraint | Working |
|---|---|
| Ground visible up the screen at 160 m ortho | 160 / sin 40° ≈ 249 m, so ~124 m in front of the focus |
| That ground's depth from the camera | 150 − 124·cos 40° ≈ 55 m, comfortably inside the near plane |
| Tall geometry (a 30 m tower) | closer by 30·sin 40° ≈ 19 m, still clear |

Fog density also dropped from 0.015 to **0.004** over a 512 m length, which reads as haze in the
distance rather than a veil over everything. The reasoning is recorded in `data/tuning.json`
beside the value, because the next person to raise the distance will have the same good reason
for doing it.

**Method worth repeating:** the fix came from rendering a sweep of variants and looking at them,
not from reading the code. `tools/screenshot.gd` exists so that stays cheap.

### 2026-09-04 — Two bugs only a render would have found

Both were invisible to the test suite as written, and both are now covered by it:

1. **The ground ran out at the widest zoom.** A 200 m plane does not fill a 160 m ortho view: the
   40° pitch stretches the vertical extent across the ground by 1/sin 40°, needing ~249 m, and
   the 16:9 aspect needs ~284 m across. Plane is now 400 m (200 cells), and
   `test_ground_covers_the_widest_zoom` computes the requirement rather than hard-coding it.
2. **GUT silently skipped a whole test file and still reported "All tests passed".** A new script
   with a `class_name` does not resolve until Godot has re-imported, and an unparseable test file
   is reported as a one-line warning rather than a failure. **Read the warning count, not just
   the pass line** — and re-import after adding any `class_name`.

### 2026-09-04 — Git LFS from day zero

`*.blend`, `*.glb` and image formats tracked via LFS. Binary art does not diff or merge, and
migrating to LFS later means rewriting history. Nearly free now, painful in six months. The
existing first commit was text-only, so no migration was needed.

### 2026-09-04 — Vertex colours over textures

One shared vertex-colour material plus a small palette texture, rather than per-model UV
unwrapping and texturing. Chosen to skip the single largest time sink in a first 3D project, and
because a fixed palette produces visual coherence by construction rather than by discipline.

Recorded as a decision because reversing it later means remaking every asset.

### 2026-09-04 — Godot project created, GUT pinned

Tasks 0.1–0.3 and 0.9 done. `project.godot` sets Forward+ / D3D12
(`rendering_device/driver.windows="d3d12"`, confirmed the correct key by grepping the installed
4.6.1 binary — Godot's own docs for this setting are thin). The full Architecture Guide §3 folder
tree exists, `.gitkeep`'d wherever nothing lives yet.

GUT 9.6.0 vendored into `addons/gut/` from the `v9.6.0` source tag (no prebuilt release asset
exists upstream, only source zip/tarball — pulled `addons/gut/` out of that). `plugin.cfg`
confirms `version="9.6.0"` exactly. A minimal `test/unit/test_gut_smoke.gd` proved the CLAUDE.md
test command works verbatim and passes (1/1) headless on 4.6.1.

**One gotcha for a fresh checkout, not yet in CLAUDE.md's test command:** GUT's `class_name`s
aren't resolved until Godot has imported the project once. A brand-new clone (or this first run)
needs `godot --headless --import --path .` before the test command; a plain, unqualified error
("Some GUT class_names have not been imported") is the symptom if this is skipped. Not needed
again after the first import.

`run/main_scene` is left unset — nothing to run yet. `.godot/` (the import cache) stays untracked
per `.gitignore`; `*.import` files for the assets already in the repo (GUT's fonts/icons) are
committed as expected in Godot 4.

---

## Open Questions

Design questions with placeholders in force: `docs/GDD_STONE_AND_PSALM.md` §14 and
`docs/SIMULATION_SPEC.md` §22. Placeholders are deliberately concrete so implementation is never
blocked waiting on a decision.

The two worth revisiting early:

| # | Question | Placeholder | Revisit at |
|---|---|---|---|
| GDD 5 | Are all five orders in v1? | **No — Cistercian and Benedictine only.** | Phase 7 |
| Sim 6 | Books as individual objects or a library number? | **Individual objects.** Costly but it's the *Name of the Rose* hook. | Phase 10 |
