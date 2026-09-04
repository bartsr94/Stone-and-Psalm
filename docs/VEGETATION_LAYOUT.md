# Vegetation layout

## Purpose

`VegetationLayout` is the pure placement contract for Phase 1.6. It answers whether one sampled
terrain cell gets one visual vegetation candidate; the view layer later turns those decisions into
`MultiMeshInstance3D` transforms. It owns no terrain state, scene nodes, meshes, or save data.

## Rules

Each cell is evaluated at most once per vegetation category:

| Candidate | Eligible ground | Additional gates | Density source |
|---|---|---|---|
| Tree | `WOODLAND` | water is `NONE`; elevation is below the tree line; slope is below the tree limit | cell forest density |
| Scrub | `MOOR` | water is `NONE`; slope is below the scrub limit | cell forest density |
| Rock | `ROCK` | water is `NONE` | renderer-provided rock density |

The density is a probability in the inclusive range `0..1`. A density of zero never places a
candidate; a density of one always places one. Terrain categories are mutually exclusive, so a
cell produces at most one candidate in the initial implementation.

## Determinism

The helper uses an integer coordinate hash of `(world seed, cell x, cell y, category salt)` and
maps it to `[0, 1)`. It never calls `randf()`, never randomizes a generator, and never depends on
iteration order. Identical inputs must produce identical output across rebuilds and headless runs.

The category salt is part of the layout contract. It keeps trees, scrub, and rocks from sharing
the same random pattern while preserving repeatability.

## Renderer sampling

The renderer samples a coarse, category-specific cell stride from `data/vegetation.json` rather
than attempting one tree per cell. Each stride-sized tile contributes at most one candidate, but
the sampled cell is itself deterministically jittered in both axes. This keeps the low-poly
population legible and bounded without producing the vertical/horizontal rows of a fixed lattice.
Scale, rotation, and within-cell jitter are also derived from the seed, but are view transforms and
are not part of the authoritative layout.

## Renderer meshes

Each batch instances an authored low-poly `.glb` prop from `assets/models/`, named in the
`models` block of `data/vegetation.json` (`prop_tree_broadleaf`, `prop_tree_pine`, `prop_gorse`,
`prop_rock_boulder`). The props carry their colour in the `Col` vertex attribute and the batch
forces the shared `m_stone_and_psalm.tres` as `material_override`, so every category batches
together. A missing model falls back to a unit box and logs an error rather than failing.

`TREE` placements are split into two batches by elevation: cells at or above
`pine_min_elevation_m` render as pine, the rest as broadleaf. This is a mesh choice made in the
view layer — `VegetationLayout` still emits a single `TREE` decision and knows nothing about it.

The supporting authored props are view-only accents: `prop_stump` and `prop_fallen_log` replace a
small deterministic share of eligible woodland understory candidates, `prop_fern_clump` fills a
lower-density woodland sample, and `prop_river_reeds` samples dry cells directly beside the
meandering river. Their paths, densities, strides, and scale ranges live in `data/vegetation.json`;
they never enter save data or alter the authoritative terrain grid.

## Deliberate boundaries

- This layer decides placement only. Scale, rotation, mesh choice, and seasonal variants belong to
  the view renderer.
- `Terrain` remains authoritative. The renderer reads `terrain_at`, `water_at`,
  `forest_density_at`, `elevation_at`, and `slope_radians_at`; it does not write them.
- Save files do not store vegetation transforms. Rebuilding the same preset and seed recreates the
  same layout.
- Water suppression is checked before category rules so future ponds and marshes are excluded by
  the same contract.
