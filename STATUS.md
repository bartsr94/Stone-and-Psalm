# Stone and Psalm — Status

**Last updated:** 2026-09-04
**Test count:** 0 (project not yet created)
**Doc version:** v1.0

---

## Project Phase

**Phase 0 — Foundations** ← current

Design documentation complete. No Godot project exists yet.

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
| 0.5 | Fix 3D conventions in code | 🔲 Not started | Architecture Guide §4 |
| 0.6 | Orthographic camera rig | 🔲 Not started | Most-used code in the game |
| 0.7 | Vendor greybox kit into `assets/kit/` | 🔲 Not started | Permissive licence; record it |
| 0.8 | `WorldEnvironment` v0 | 🔲 Not started | |
| 0.9 | Verify the test command, record it in CLAUDE.md | ✅ Done | Command in CLAUDE.md works verbatim; a fresh checkout needs one `--headless --import` pass first (generates GUT's class_name cache) — not needed again after |

---

## Start here next session

Docs are complete, the art pipeline is verified, and the Godot project exists: `project.godot`,
the full folder scaffold, and GUT 9.6.0 pinned and passing headless.

Remaining, in order (Roadmap Phase 0):

| # | Task | Note |
|---|---|---|
| 0.7 | Choose and vendor a greybox kit into `assets/kit/` | **Decision needed** — Kenney medieval/survival (CC0) is the leading candidate. Record the licence in `assets/kit/LICENCE.md` |
| 0.5 | Fix the 3D conventions in code | Architecture Guide §4 |
| 0.6 | Orthographic camera rig — 40° pitch, 90° yaw steps | The most-used code in the game |
| 0.8 | `WorldEnvironment` v0 — sun, sky, SSAO, fog | Rough is fine; Phase 2 makes it good |

**Once godot-mcp is live in-session** (needs a VS Code restart to pick up `.mcp.json` — see
Environment notes), 0.6 and 0.8 are the first tasks worth driving through it: opening the editor,
running the scene, and taking the Phase 1 screenshot.

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
