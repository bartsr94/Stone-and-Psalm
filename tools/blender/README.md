# tools/blender

Headless Blender pipeline for Stone and Psalm. Full rationale and workflow in
`docs/ASSET_PIPELINE.md`; the conventions these enforce are `docs/ARCHITECTURE_GUIDE.md` §4.3.

**Blender 4.5 LTS**, pinned. LTS because these scripts break on Python API drift.

Set `BLENDER` once per shell (PowerShell):

```powershell
$BLENDER = "C:\Program Files\Blender Foundation\Blender 4.5\blender.exe"
```

## Validate — run before every commit

```powershell
& $BLENDER --background --python tools/blender/validate_assets.py -- assets/blend
```

Exits non-zero on failure, so it can gate a build. Catches the errors that are invisible in
Blender and expensive in Godot: unapplied transforms, wrong origin, missing `Col` attribute,
stray material, stray light or camera, triangle budget overrun.

## Export

```powershell
& $BLENDER --background --python tools/blender/export_gltf.py -- assets/blend assets/models
```

Only re-exports `.blend` files newer than their `.glb`. Add `--force` after the paths to
re-export everything.

## Create the small vegetation props

The reproducible low-poly source for the supporting valley props lives in
`create_vegetation_props.py`. It creates `prop_stump`, `prop_fallen_log`, `prop_fern_clump`, and
`prop_river_reeds` in `assets/blend`; run the validator and exporter afterwards.

## Create the founding-site props

`create_foundation_props.py` creates the Phase 1 presentation landmarks: `prop_founders_cross`,
`prop_timber_shelter`, and `prop_campfire`. They are intentionally placeholders for the future
hand-modelled church and settlement buildings; run the validator and exporter afterwards.

## Create the trees, the ground cover and the buildings

- `create_tree_props.py` — `prop_tree_broadleaf` (oak), `prop_tree_pine` (Scots pine, bare
  trunk and plated crown) and `prop_tree_birch`. Silhouette is the point; see the docstring.
- `create_ground_cover_props.py` — `prop_grass_clump` and `prop_moor_tuft`, instanced in the
  tens of thousands by `scripts/view/vegetation_renderer.gd`. ~30 triangles each, on purpose.
- `create_building_models.py` — one `bld_*` per entry in `data/buildings.json` plus the two
  precinct buildings, sized from the JSON footprints. Thatch is laid as aged segments, walls
  carry their eaves' shadow, and every face is weathered (`meshkit.shade_band` / `weather`).

All three are deterministic: a rebuild is byte-identical. Run the validator and exporter after
any of them, then `godot --headless --import --path .` so Godot picks up new `.glb` files.

To see a set before it goes in game:

```powershell
& $BLENDER --background --python tools/blender/preview_assets.py -- "prop_tree_*" docs/screenshots/trees.png
```

## Repair a file's material / colour attribute

```powershell
& $BLENDER assets/blend/bld_lime_kiln.blend --background --python tools/blender/setup_material.py -- --save
```

Creates or rewires `M_StoneAndPsalm` (Colour Attribute → Base Color), adds the `Col` attribute
if missing, and assigns the material to every mesh. Without `--save` it reports only.

Also prints `data/palette.json`, which is handy to have open in Blender's scripting console
while painting.

## Conventions these enforce

| Rule | Value |
|---|---|
| Naming | `bld_` / `prop_` / `agent_` / `kit_`, snake_case |
| Scale / rotation | Applied — 1 unit = 1 metre |
| Origin | Ground-centre of the footprint (bbox on z=0, centred x/y) |
| Colour attribute | `Col`, `BYTE_COLOR`, corner domain |
| Material | Exactly one: `M_StoneAndPsalm` |
| Triangle budget | `bld_` 2400 · `prop_` 400 · `agent_` 600 · `kit_` 500 |
| Export | glTF `.glb`, +Y up, −Z forward, no lights/cameras/UVs |
