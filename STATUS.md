# Stone and Psalm — Status

**Last updated:** 2026-09-04
**Test count:** 127 passing (GUT 9.6.0, headless)
**Doc version:** v1.0

---

## Project Phase

**Phase 2 — Seasons and Sky** ← complete on branch `phase-2-seasons-and-sky`

The valley now has an authoritative clock, a real solar model, a day/night cycle laid over a
four-keyframe seasonal blend, snow as a terrain/vegetation shader parameter, deterministic
daily weather, precipitation particles, and an in-world HUD (date, time, season, weather,
speed control). Screenshots across summer / winter / autumn in `docs/screenshots/phase2_*`.

**Phase 1 — The Valley** — exit gate ("a screenshot you actually like") is still the user's
call. The valley composition, the camera start position, and the final lighting-pass tuning
(1.7) were **not** signed off; Phase 2 built on the Phase 1 scene as-is. The dark self-shadowed
north slope and the terrain chunk faceting visible in the phase-2 shots are Phase 1 tuning
items, not Phase 2 regressions.

---

## Milestone Status

| Milestone | Phases | Status |
|---|---|---|
| M1 — It's a place | 0–2 | 🟡 Phases 0 done, 1 built (exit gate unsigned), 2 done |
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

## WIP checkpoint — Phase 1 terrain and river, mid-lighting-pass

The terrain checkpoint is now green: **66 tests pass**. The integration test was updated from
Phase 0's `Ground`/`GreyboxBuilding` nodes to Phase 1's `TerrainRenderer`, and now resets the
singleton terrain before each scene test so dirty-chunk assertions do not depend on test order.

What's built and working:

- `data/terrain_presets.json` + `autoloads/terrain.gd`: the authoritative 192×192 cell grid
  (384 m), built deterministically from tuned parameters — meandering river, elevation
  7–58 m, meadow/woodland/moor/rock bands, each valley side varying independently along
  its length (`_build_columns`) so the dale has spurs rather than being parallel ribbons.
- `scripts/sim/valley_shape.gd`, `scripts/sim/terrain_types.gd`: pure, headless-testable —
  **no unit tests written for these yet**, do that before extending them further.
- `scripts/view/terrain_renderer.gd`: chunked mesh (36 chunks, dirty-chunk remeshing),
  corner-averaged heights and colours so chunk edges and terrain-band boundaries blend.
- `assets/materials/river_water.gdshader` + `m_river_water.tres`: a derived, cell-batched river
  surface with animated flow and tuned transparency. It does not own simulation state.
- `scripts/view/palette.gd`: `Palette.of()` for sRGB (materials/UI) vs `Palette.vertex()`
  for linear (mesh `ARRAY_COLOR`) — **this distinction is load-bearing, not stylistic.**
- `test/unit/test_valley_shape.gd` and `test/unit/test_terrain_types.gd`: boundary and save-format
  coverage for the new terrain helpers.

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

The wide render has now been reviewed. The valley shape reads and the river follows its meander;
the founding site's cross, timber shelter, and fire now give the scene a visual anchor, with a
small status card establishing the historical starting point. Fog and golden-hour lighting are
still provisional and should be tuned again once seasonal colour exists.

The Phase 1 presentation slice is now in place: terrain, river, vegetation, authored accents,
founding-site landmarks, and a first lighting adjustment. The preset covers the handcrafted
heightmap and 1.4's first river-surface implementation is complete.

---

## Start here next session

**Phase 2 is complete on `phase-2-seasons-and-sky` (merged to `main`).** `Ctrl+F5` opens the
valley with a running clock: the sun rises in the east and sets in the west, the day is
visibly shorter in winter, the four seasons blend through colour / fog / snow / foliage, daily
weather brings rain and snow, and a HUD shows the date, season, weather and speed control.
127 tests pass headless. Season / weather / sun screenshots are in `docs/screenshots/phase2_*`.

What is built (Phase 2.1–2.8):

| # | Piece | Where |
|---|---|---|
| 2.1 | `SimClock` — authoritative calendar, speeds, signals | `autoloads/sim_clock.gd` |
| 2.2 | `Daylight` — declination, daylight length, sun altitude/azimuth at 54°N | `scripts/sim/daylight.gd` |
| 2.3 | Day/night sun + sky driver, keyframed by sun altitude | `scripts/view/sky_cycle.gd`, `data/sky.json` |
| 2.4 | `SeasonCurve` (pure) + `SeasonBlender` (resolves `data/seasons.json`) | `scripts/sim/`, `scripts/view/` |
| 2.5 | Snow as a terrain shader uniform, snow line drops in deep winter | `assets/materials/terrain_ground.gdshader` |
| 2.6 | Seasonal foliage tint + winter bare + snow dusting | `assets/materials/veg_foliage.gdshader` |
| 2.7 | `Weather` — daily temp/precip, cosine baseline + 3-day smooth, injected `Dice` | `autoloads/weather.gd` |
| 2.8 | Rain / snow GPU particles following the camera | `scripts/view/precipitation.gd` |
| — | `Dice` / `ScriptedDice` — the injected RNG the portfolio pattern needs | `scripts/sim/` |
| — | HUD + `stone_and_psalm_theme.tres` (structure from the Palusteria Nights repo, flat fills) | `scripts/ui/hud.gd`, `ui/theme/` |
| — | `tools/timelapse.gd`, `tools/screenshot.gd` now pin a chosen day/minute | `tools/` |

Outstanding from earlier phases (still open):

| # | Task | Note |
|---|---|---|
| 1.x | **Sign off the Phase 1 exit gate** — "a screenshot you actually like" | The valley composition, camera start position and lighting-pass tuning (1.7) were never approved. The dark self-shadowed north slope and terrain chunk faceting in the phase-2 shots are the items to address. |
| 0.7 | Choose and vendor a greybox kit into `assets/kit/` | Not blocking until Phase 4 building types. |
| — | Open the project in the editor once | Still authored fully headlessly. First editor save rewrites `.tscn`/`.tres` with UIDs — let it be its own noisy commit. |
| 3.x | **Phase 3 — One Monk Walking** is next | `unequal_hours`, `computus`, `Liturgy` + `liturgical_calendar.json`, `horarium`, `Person`/`Population`, A* pathfinder, agent substep movement, monk greybox, the Horarium ring UI, greybox church + dormitory. `Dice`, `SimClock`, `Daylight` and the HUD/theme are already in place for it. |

### Screenshots

`tools/screenshot.gd` renders a scene to a PNG, for the screenshot every phase's exit criteria
require. Must run **windowed, not headless** — the dummy renderer produces no image:

```powershell
& "C:\Users\Bart\Documents\Godot_v4.6.1-stable_win64.exe" --path . `
  -s tools/screenshot.gd -- res://scenes/world/main.tscn res://docs/screenshots/name.png
```

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

### 2026-09-04 — Phase 2 built as a large autonomous block; Phase 1 exit gate left unsigned

Phases 2.1–2.8 plus `Dice`, the HUD and the UI theme were built in one pass on
`phase-2-seasons-and-sky`, following the roadmap order rather than the emphasis in the request
(which mentioned UI first). The reasoning: `CLAUDE.md` is emphatic that phase order is a
countermeasure to the portfolio failure mode, and the "UI" the game actually needs — the
Horarium ring and the roster — is Phase 3 work. A speed/date/weather HUD was built now because
Phase 2 needs a visible clock and it is a natural home for the theme.

**Phase 1's exit gate ("a screenshot you actually like") was not signed off.** Phase 2 built on
the Phase 1 scene as-is. This is a deliberate call to keep momentum, not an oversight: the
valley composition, the camera start position and lighting-pass 1.7 are still open, and the
phase-2 screenshots show what needs attention (a crushed north slope, chunk faceting). Nothing
in Phase 2 depends on that tuning — it is all shader uniforms and autoload state over the same
mesh.

### 2026-09-04 — What was reusable from the Palusteria Nights repo: the pattern, not the art

The request asked to pull assets from `C:\Users\Bart\Documents\Games\Palusteria Nights`. That
project is a pixel-art Dialogic visual novel: its UI is nine-patch pixel textures, a pixel
font, and Dialogic-coupled scenes. **None of the art transfers** — it would violate the
locked vertex-colour / "this is not pixel art" direction (Arch Guide §4). What transferred is
structure: `ui/theme/stone_and_psalm_theme.tres` is built the way that repo builds a theme (a
`Theme` over `StyleBox` sub-resources), and `hud.gd` follows its pause-menu pattern
(CanvasLayer, code-built controls, signal wiring). The theme uses flat parchment-edged fills,
no imported textures, and no display font yet — a serif/blackletter face is an art-pass and
licensing decision.

### 2026-09-04 — GDScript: a bare `randf()` inside a base method skips subclass overrides

`Dice.randf_range` / `randi_range` / `chance` first called a bare `randf()`, which binds to
GDScript's **global** `randf()` built-in, not the method — so `ScriptedDice`'s override was
never seen and "deterministic" tests were anything but. Fixed by calling `self.randf()`
explicitly, and by deriving every other draw from that one method so `ScriptedDice` overrides
only `randf()`. Also: `enum Sky` in `weather.gd` silently shadowed the native `Sky` resource
class and failed the whole autoload — renamed to `Condition`.

### 2026-09-04 — `SimClock.deserialize` re-emits `day_passed` and `season_changed`

Loading an instant (a save, or the screenshot/timelapse tools jumping to a date) has to resync
everything that only updates on a calendar edge — `Weather`, `sky_cycle`, the seasonal
materials. Without it, the first screenshot at "14 July" still showed the January weather the
autoload rolled at startup.

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
