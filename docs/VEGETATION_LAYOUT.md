# Vegetation layout

## Purpose

`VegetationLayout` is the pure placement contract for Phase 1.6. It answers whether one cell gets
one visual vegetation candidate; the view layer later turns those decisions into
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

## Deliberate boundaries

- This layer decides placement only. Scale, rotation, mesh choice, and seasonal variants belong to
  the view renderer.
- `Terrain` remains authoritative. The renderer reads `terrain_at`, `water_at`,
  `forest_density_at`, `elevation_at`, and `slope_radians_at`; it does not write them.
- Save files do not store vegetation transforms. Rebuilding the same preset and seed recreates the
  same layout.
- Water suppression is checked before category rules so future ponds and marshes are excluded by
  the same contract.
