# The In-The-Nature look pass

**Date:** 2026-09-07
**Branch:** `feat/in-the-nature-look`
**Reference:** *In The Nature* by Toby Noby (BlenderKit), kept locally as
`assets/reference/forest_scene.blend` — gitignored, 510 MB, never committed.

## What the reference is, and what was taken from it

The reference is a Cycles still: 10.5 million triangles (five pines at 1.47 M each), sixty packed
4K PBR maps, 1024 samples, AgX Punchy with a compositor grade. It cannot be reproduced inside this
project's conventions (one vertex-colour material, no textures, `bld_` 2400 / `prop_` 400
triangles), and its grass and leaf textures are third-party library assets that must not be
lifted into the game.

What the image actually has that the valley did not, in order of how much each contributes:

1. Golden-hour light: a warm low sun against cool sky-lit shade.
2. Aerial perspective: the far ground goes pale and blue.
3. Ground cover at the camera's own scale.
4. Tree silhouettes against the sky, and more than one species.
5. Water that mirrors the sky.
6. A warm grade with a touch of glow.

All six were built, plus the building surface work Bart asked for on top.

## What changed

### Light and grade

- `data/sky.json` — keyframes retuned. Low-sun keys (1.5°–16°) carry a strong warm sun against a
  sky that stays blue; ambient energy raised across the board. A new 16° key sits between the
  8° and 28° keys so the golden hour is not a straight lerp from dawn to noon.
- `scripts/view/sky_cycle.gd` — **the ambient is coloured from the sky dome, not the horizon.**
  Taking it from the orange horizon tinted the shadows the same as the light and the frame
  collapsed into one brown. The depth fog's light colour is set per frame from the sky (blue) and
  the season's haze.
- `scenes/environment/valley_environment.tres` — glow (soft-light, low), screen-space
  reflections, depth fog for aerial perspective with `fog_depth_begin` past the near ground, and
  a gentler volumetric anisotropy. Full rationale in the resource's comment block.
- `scenes/environment/valley_environment.tscn` — the sun gets an angular size and a softer shadow
  edge.

**What went wrong first:** the initial fog settings (depth fog from 190 m with sun scatter, and
volumetric anisotropy 0.62) turned the whole frame into an orange filter at 19:10. Aerial haze
must be *blue* (sky light scattered in) and must start past the near ground; the orange belongs
only on the sun-facing rim.

### Ground cover

- `tools/blender/create_ground_cover_props.py` — `prop_grass_clump` (ten blades, ~30 tris) and
  `prop_moor_tuft`. Blades shade dark root to pale tip.
- `assets/materials/grass.gdshader` + `m_grass.tres` — wind sway in the vertex shader (height-
  weighted, phased by world position), the season's `ground_tint`, a per-instance colour, snow on
  the tips, `cull_disabled` so a blade is one quad, specular off.
- `scripts/view/vegetation_renderer.gd` — `_populate_ground_cover`: every eligible cell, several
  clumps per cell by terrain type (`data/vegetation.json` → `ground_cover`), per-instance
  straw/shade drift, ground height bilinear between cell centres, **no shadow casting**. Clumps
  are indexed by cell so those under a building placed later collapse to nothing
  (`Buildings.building_placed`), and the precinct's footprints are excluded up front — grass
  through a wall is the one thing this layer must never do.

### Trees

- `tools/blender/create_tree_props.py` — rebuilt for silhouette: the oak from ten smaller,
  heavily jittered masses in three tiers with limbs; the Scots pine with a tall bare orange-red
  trunk and a crown of flat plates; a new **birch** (pale, slender, light crown).
- `meshkit.blob` — jitter is now per *direction*, not per face corner, so canopies stay closed
  (the old per-corner jitter tore slits between facets).
- `data/vegetation.json` — tree sample stride 3 → 2 (a denser stand), `birch_fraction`,
  `canopy_recolour` 0.62 (the season tint used to replace 85 % of the authored canopy colour,
  flattening every tree to one green).
- `scripts/view/terrain_renderer.gd` — woodland floor is a new palette entry `woodland_floor`
  (leaf litter), not the canopy's dark green, which rendered as a black band on every wide shot.

### Water

- `assets/materials/river_water.gdshader` — the surface lifts toward a sky tint by a floor plus a
  Fresnel ramp, its normal ripples along TANGENT/BINORMAL so the low sun breaks into glints, and
  roughness is low enough for SSR. Drawn dark with a weak specular, the beck was a black trench.
- `scripts/view/terrain_renderer.gd` — **the water plane extends three cells under the banks**
  (`BANK_APRON_CELLS`), so the waterline is where the ground crosses the level: a smooth contour
  instead of a 2 m staircase. The mesh now carries tangents.

### Backdrop fells

- `scripts/view/backdrop_renderer.gd` + `data/backdrop.json` — a ring of low-poly hills outside
  the map on a "squircle": the inner vertices sit on the square map edge at the terrain's own
  height and blend into noise-shaped fells over 150 m, rising to ~210 m by 900 m out. Terrain
  ground material (so the snow line and seasonal tint apply), no shadows. Only visible at a low
  pitch or near an edge, which is exactly when the map used to end in nothing.

### Buildings (`tools/blender/create_building_models.py`, `meshkit.py`)

From the game's 40° camera a building is two-thirds roof, and a roof drawn as clean bands is a
slab however good the walls are. Three surface treatments, no shape changes:

- **Thatch as aged segments** (`thatch_texture`): every course split into hand-width segments,
  each aged its own amount toward `thatch_old`, darker toward its lower edge (a per-corner
  gradient via the new `MeshBuilder.face_shaded`), rain-darkened lower courses, moss creeping down
  the north pitch, and a fringe that is never new gold.
- **Eaves shadow** (`MeshBuilder.shade_band`): every wall darkens toward the eaves before the
  roof is built, so only the wall takes it.
- **Weathering** (`MeshBuilder.weather`): a deterministic per-face value jitter over the whole
  model, seeded from its name.

The `bld_` budget rose from 1500 to 2400 (`validate_assets.py`); the tithe barn is 2236.

### Tooling

- `tools/screenshot.gd` — two new arguments: `ortho_size_m` (8th) and `pitch_deg` (9th), for a
  wide overview or a low tilt without editing tuning.
- `tools/blender/preview_assets.py` is unchanged and remains the fastest way to see a set.
- `assets/reference/` is gitignored and carries a `.gdignore`; Godot had already tried to import
  the 510 MB blend from the repo root and extracted 89 textures into `textures/` (removed).

## Terrain3D

`addons/terrain_3d` (1.0.2, compatibility 4.4+, Windows binaries present, plugin not enabled) is
installed. It was **not** used in this pass, deliberately:

- Its strengths are clipmap LOD, tiling texture splats and a painted foliage instancer. The
  terrain here is a 384 m grid the simulation owns (`Terrain` autoload), rendered in dirty chunks
  with a derived river surface and road plates that tests assert on; replacing that renderer is a
  rewrite of `terrain_renderer.gd` and its tests, not a drop-in.
- Splatted textures are the one thing the conventions rule out, and the ground now carries
  noise variation, slope wear, snow, grass and a backdrop without them.

If it is ever adopted, the honest shape is *Terrain3D as the ground renderer fed from the sim
grid* (heights and a control map written from `Terrain`), with the vertex-colour ground shader
ported to its material, and a written exception for ground textures in this folder. Its foliage
instancer would replace `_populate_ground_cover`. Worth a spike only once the ground is the
weakest thing on screen again.

## Screenshots

- `docs/screenshots/look_pass_golden_hour.png` — the founding site at 17:45 midsummer.
- `docs/screenshots/look_pass_wide.png` — the dale at 140 m ortho.
- `docs/screenshots/look_pass_fells.png` — 32° pitch, 160 m, the backdrop beyond the map edge.
- `docs/screenshots/asset_sheet.png` — the rebuilt buildings.

## Open follow-ups

- **Low pitch at a wide zoom looks up through the ground.** With an orthographic camera
  `camera.distance_m` (150 m) from its focus, the bottom of the frustum starts
  `size/2 · cos(pitch)` below the camera, and the camera is only `150 · sin(pitch)` above the
  focus — with the valley side rising behind the camera, the lower rays begin underground, pass
  through the terrain's culled back faces and show fog (a grey band along the bottom of the
  frame). Solving `150·sin(p) > size/2·cos(p) + Δh` with the slope behind the camera ~45 m
  above the floor gives a floor of roughly 26° at the default 44 m zoom, 35° at 100 m and 44° at
  160 m — so the convention's 15° is only honest at close zoom on the valley floor. Two fixes,
  neither done here: a zoom-dependent pitch floor in `camera_rig.gd`, or a larger
  `camera.distance_m` (~400 m gives ~20° at 160 m) with the fog and shadow ranges re-tuned to
  match, which the tuning comment on `distance_m` already warns about. Until then the fells
  read only as a hazy band at the top of a wide shot, and `look_pass_fells.png` is taken at
  the default pitch for that reason.
- Grass under buildings loaded from a save (no `building_placed` fires on deserialize).
- A wide zoom still shows the whole meadow's clumps at once; if it ever costs frames, thin them
  by distance from the camera focus.
- Cloud cover from `Weather` does not yet dim the sun; a rainy day is lit like a clear one.
- The precinct church and dormitory are the same generator as the outer court; the stone church
  (Phase 8) is untouched.
