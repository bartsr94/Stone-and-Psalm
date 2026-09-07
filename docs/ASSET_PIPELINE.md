# Stone and Psalm — Asset Pipeline

**Version:** 1.0
**Date:** 2026-09-04

> How art gets made and how it gets into the game. The *conventions* live in
> `ARCHITECTURE_GUIDE.md` §4; this document is the *workflow* and the tooling that enforces them.

---

## 1. The split that governs everything here

There are two jobs that look like one, and they are handled completely differently:

| | Job | Who does it | Tooling |
|---|---|---|---|
| **1** | **Authoring hero assets** — the church, the chapter house, the tithe barn. The things you actually look at. | **Bart, by hand, in Blender.** | Blender GUI |
| **2** | **Pipeline** — export, validation, palette, batch operations. | Automated. | Headless Blender + Python |

**Job 1 is the point of the project.** This game exists to learn 3D and visual work. Handing
hero-asset modelling to an LLM defeats the entire purpose, and the output would need
retopologising anyway — Claude does not think in edge loops, pole management, or
subdivision-ready topology, and its spatial precision needs several correction rounds.

**Job 2 is pure win.** It costs no learning, it is deterministic, and it catches the class of
error that is invisible in Blender and expensive in Godot.

---

## 2. Tooling

| | |
|---|---|
| **Blender** | **4.5.10 LTS** — pinned, installed, and the pipeline is verified against it (§4.1). LTS because the Python API stays stable for the life of the project, and API drift between versions is the known way pipeline scripts break. |
| **Install** | `winget install BlenderFoundation.Blender.LTS.4.5` (needs a UAC prompt — run it interactively) |
| **Path** | `C:\Program Files\Blender Foundation\Blender 4.5\blender.exe` |
| **Git LFS** | On, for `*.blend`, `*.glb`, and image formats. See `.gitattributes`. |
| **MCP** | `blender-mcp` configured in `.mcp.json`, **scoped** — see §6. |

---

## 3. Repository layout

```
assets/blend/          ← .blend sources. LFS. The authored truth.
assets/models/         ← exported .glb. LFS. Committed, so the game runs without Blender.
assets/kit/            ← third-party greybox. Placeholder only, never shipped.
data/palette.json      ← the project palette. 42 entries. Every colour comes from here.
tools/blender/
  validate_assets.py   ← enforces ARCHITECTURE_GUIDE §4.3. Gates the build.
  export_gltf.py       ← batch .blend -> .glb with the settings locked.
  setup_material.py    ← creates/repairs the shared vertex-colour material.
```

**`.glb` is committed even though it is generated.** The Godot project must open and run on a
machine with no Blender installed — including a CI runner and any future collaborator.

---

## 4. The daily loop

```bash
# 1. Model in Blender, save into assets/blend/
# 2. Check it obeys the conventions
blender --background --python tools/blender/validate_assets.py -- assets/blend

# 3. Export what changed
blender --background --python tools/blender/export_gltf.py -- assets/blend assets/models

# 4. Open Godot; the .glb is already in place
```

Add `--force` to `export_gltf.py` to re-export everything rather than only stale files.

### 4.1 Verified behaviour (2026-09-04, Blender 4.5.10 + Godot 4.6.1)

Proved with a throwaway 2 m cube, so these are facts rather than assumptions:

- Vertex colours survive `.blend` → `.glb` → Godot. The `.glb` carries `COLOR_0`; Godot reports
  `has_vertex_colors=true`.
- **Godot's glTF importer sets `vertex_color_use_as_albedo = true` automatically** when `COLOR_0`
  is present. There is no manual step, and no import preset to configure.
- The export carries **0 images, 0 textures and no UVs** — exactly as intended.
- Scale and origin survive intact: a 2 m cube with its origin at the ground-centre of its
  footprint arrives in Godot with AABB position `(-1, 0, -1)` and size `(2, 2, 2)`. That confirms
  the 1 unit = 1 metre contract and the Y-up/−Z-forward convention across the whole chain.
- Roughness and metallic carry through from Blender's Principled BSDF.

**Blender exits 0 even when a Python script raises**, so all three scripts catch exceptions and
force `sys.exit(1)`. Without that, a validator that crashed would report success — never remove
those handlers.

To fix a file that fails validation on material or colour attribute:

```bash
blender assets/blend/bld_lime_kiln.blend --background --python tools/blender/setup_material.py -- --save
```

### What `validate_assets.py` checks

These are exactly the errors that are silent in Blender and costly later:

- **Naming** — `bld_` / `prop_` / `agent_` / `kit_` prefix, snake_case.
- **Transforms applied** — an unapplied scale silently breaks the 1 unit = 1 metre contract.
- **Origin at ground-centre of the footprint** — bbox sits on z=0, centred on x/y. Get this
  wrong and every building floats or sinks when placed.
- **Colour attribute named `Col`**, `BYTE_COLOR`. Without it the mesh is a grey box.
- **Exactly one material**, and it is `M_StoneAndPsalm`. More than one and both the batching
  and the palette-coherence arguments collapse.
- **Triangle budget** — `bld_` 2400, `prop_` 400, `agent_` 600, `kit_` 500. (`bld_` was 1500
  until the In-The-Nature look pass, 2026-09-07: with no textures, a roof's courses and a wall's
  studwork *are* the surface, and the tithe barn had already hit 1494. See
  `docs/implementations/in_the_nature_look_pass.md`.)
- **No lights or cameras** saved in an asset file — they travel into the `.glb` and fight the
  scene's own lighting rig.
- Warns on unapplied modifiers.

Exits non-zero on failure, so it can gate a build.

---

## 5. Modelling conventions in practice

**Start small.** The first asset is not the church. It is a lime kiln or a woodshed — a box, a
roof, done, in Godot the same evening.

**Go modular from day one.** Wall segment, corner, buttress, roof section, window, door. The
claustral plan was near-standardised across Europe (see `reference/HISTORICAL_REFERENCE.md` §8),
so modularity pays off here more than in almost any other setting: a monastery becomes assembly
rather than sculpting.

**Vertex colours, never textures.** One material, colours painted into `Col` from
`data/palette.json`. This is what lets us skip UV unwrapping and texturing — the skill that eats
months of a first 3D project and is not the skill this project exists to learn. Rationale in
`ARCHITECTURE_GUIDE.md` §4.1.

**The skill actually worth building is silhouette and proportion**, not tool fluency. At a 40°
orthographic camera, massing and roofline are the entire read. Detail below that threshold is
wasted work.

**Work from reference.** Fontenay, Fountains, Rievaulx, Le Thoronet, Tintern
(`HISTORICAL_REFERENCE.md` §8.3). Ruins are ideal modelling reference — the structure is exposed
and the massing is legible without a roof in the way. This is the chief practical advantage of
the historical setting: nothing has to be invented.

---

## 6. `blender-mcp` — deliberately scoped

Configured in `.mcp.json`, and **limited to these uses**:

| Use it for | Why |
|---|---|
| **Blockout and massing** | Arranging the claustral plan as labelled boxes at correct real-world dimensions is a structured geometric task, which is what it is actually good at. Feeds the Phase 0 greybox directly. |
| **Writing and debugging the pipeline scripts** | Fast visual feedback beats working blind. |
| **One-off batch cleanup** | Across many files, once. |

| Do **not** use it for | Why |
|---|---|
| **Hero assets** | Defeats the project's purpose, and produces topology that needs redoing. |
| **Anything in the build** | It needs Blender running interactively with the addon's socket server started. Useless as a build step — that is what the headless scripts are for. |
| **Geometry Nodes** | Brittle; the API shifts between versions and generated node graphs rarely survive. |

**Setup** (one time, and it is manual by design):

1. `uv` must be installed — `winget install astral-sh.uv`.
2. Download `addon.py` from [ahujasid/blender-mcp](https://github.com/ahujasid/blender-mcp).
3. Blender → Edit → Preferences → Add-ons → Install from Disk → pick `addon.py` → enable it.
4. In the 3D viewport sidebar (`N` key) → **BlenderMCP** tab → **Start MCP Server**.
5. Run Claude Code **from the project directory** so `.mcp.json` is picked up.

> **Caution:** the server exposes `execute_blender_code`, which runs arbitrary Python in your
> live Blender session. Its own documentation says to always save first. Treat it as such.

The bundled AI mesh generators (Hyper3D Rodin, Hunyuan3D) are **not used** — they output
textured meshes with poor topology, which fights the vertex-colour decision this whole pipeline
rests on.

---

## 7.1 Founding-site placeholders

The Phase 1 valley includes three deliberately small presentation props: the founder's cross,
a timber shelter, and a founding fire. They are generated by
`tools/blender/create_foundation_props.py` and placed by
`scripts/view/founding_site_renderer.gd` from `data/founding_site.json`.

These are not the final church or production buildings. The renderer searches outward from each
anchor for a flat, dry meadow cell, which makes the composition robust while the handcrafted
heightmap is tuned. The future `Buildings` system can replace the layer without changing terrain
or save data.

## 7. Where ComfyUI fits

ComfyUI is installed locally and there is a project skill for it. Its uses here are **2D only**:

- **Reference boards before modelling** — generate a three-quarter view of a Cistercian lime
  kiln so you are working from an image rather than a description.
- **The small palette texture** — thatch, cloth, glass. The only bitmap in the project.
- **Illuminated manuscript art for the library UI.** The strongest fit in the whole game, and
  the one place where generated 2D art genuinely belongs.

Not for 3D. Low-poly trees and rocks are five minutes each by hand.

---

## 8. Greybox policy

`assets/kit/` holds a permissively-licensed third-party low-poly kit, used **only** as
placeholder.

- The sim never waits on art; art never waits on the sim.
- A new building type ships as a kit box first, and is replaced later in its own implementation
  slice.
- **Nothing from `assets/kit/` ships in a release build.** Phase 11 adds a build check that
  fails if any kit asset is still referenced.
- Record the kit's licence in `assets/kit/LICENCE.md` when it is vendored.

---

## 9. Open questions

| # | Question | Placeholder in force |
|---|---|---|
| 1 | Which greybox kit? | **Undecided** — Kenney medieval/survival packs (CC0) are the leading candidate. Needs a licence check and a look at whether the massing suits an abbey. Blocks Roadmap task 0.7. |
| 2 | LOD levels for buildings? | **None for now.** 250 agents and ~120 buildings with one material should hold 60 fps. Profile at Phase 4 before adding complexity. |
| 3 | Are agent walk cycles hand-animated or shader-driven? | **Shader-driven bob** on a 3-bone rig (`ARCHITECTURE_GUIDE.md` §4.4). Revisit only if it reads badly at mid zoom. |
| 4 | Terrain authoring tool? | **Undecided** — Godot terrain plugin, Blender sculpt, or a painted heightmap PNG. Decide in Phase 1. |
