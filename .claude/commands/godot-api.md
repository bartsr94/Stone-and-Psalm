# GDScript 4 Reference — Stone and Psalm

Adapted from godogen (htdt/godogen) for GDScript-only Godot 4.6.1. Covers non-obvious language
behaviour, engine quirks, and this project's orthographic-3D specifics. Not a tutorial — assume
basic GDScript is known.

---

## Type Inference Pitfalls

```gdscript
# := only works when the RHS has a concrete, unambiguous type
var bad := abs(speed)          # ERROR — abs() returns Variant
var bad2 := clamp(val, 0, 1.0) # ERROR — same
var bad3 := min(a, b)          # ERROR — same
var bad4 := dict["key"]        # ERROR — subscript returns Variant

var good: float = abs(speed)   # OK — explicit type
var also_ok = abs(speed)       # OK — untyped Variant

# Safe for literals and typed constructors:
var pos := Vector3(1, 0, 2)    # OK
var count := 0                 # OK (int literal)
```

## Value vs Reference Types

Value types (copy on assignment/pass): `bool`, `int`, `float`, `Vector2/3/4`, `Transform2D/3D`,
`Color`, `Rect2`, `AABB`, `Basis`, `Quaternion`

Reference types (shared): `Object`, `Node`, `Array`, `Dictionary`, `PackedArray*`, `Resource`

```gdscript
# Passing a Vector3 to a function — the caller's copy is NOT modified
func move(pos: Vector3) -> void:
    pos.x += 10  # only affects local copy

# To copy an Array or Dictionary:
var copy = arr.duplicate()     # shallow
var deep = arr.duplicate(true) # deep (nested refs also duplicated)
```

## Typed Arrays — Assignment Gotcha

```gdscript
var nodes3d: Array[Node3D] = [Node3D.new()]
var nodes: Array[Node] = []
# nodes = nodes3d  # ERROR: incompatible types even though Node3D extends Node
nodes.assign(nodes3d)          # OK — use .assign() to copy across typed arrays
```

## Lambda Capture Behaviour

```gdscript
var x = 42
var arr = []
var fn = func():
    print(x)       # Always 42 — primitives captured by VALUE at creation time
    arr.append(1)  # Shared — arrays/dicts/objects captured by REFERENCE
    x = 99         # Warning: only modifies the lambda's captured copy
```

## Signals

```gdscript
signal value_changed(new_val: int)

value_changed.emit(42)

# Connect with extra bound argument:
node.value_changed.connect(_on_changed.bind("extra"))  # handler receives (new_val, "extra")

# Await:
await value_changed
await get_tree().create_timer(1.0).timeout
```

## Properties (Getter/Setter)

```gdscript
var score: int:
    get:
        return score           # direct field access — no recursion
    set(value):
        score = clamp(value, 0, 100)
        score_changed.emit(score)

# Setter NOT called during class initialisation or inside its own accessor
var x: int = 5                 # setter not called here
```

## Deferred Calls

```gdscript
call_deferred("my_method")    # run after current frame
set_deferred("property", val) # set after current frame

# REQUIRED inside physics callbacks (body_entered, body_exited, area_entered):
# Changing collision shape.disabled directly causes "Can't change state while flushing queries"
$CollisionShape3D.set_deferred("disabled", true)  # correct
```

## Pause / Process Modes

```gdscript
get_tree().paused = true
process_mode = Node.PROCESS_MODE_ALWAYS    # exempt from pause (UI, dev console)
process_mode = Node.PROCESS_MODE_PAUSABLE  # pauses with tree (default)
process_mode = Node.PROCESS_MODE_DISABLED  # culled agents, off-screen props
process_mode = Node.PROCESS_MODE_INHERIT   # resume from parent (default for children)
```

## Common Patterns

```gdscript
# Assert (expression not evaluated in release builds!)
assert(x > 0, "x must be positive")
assert(do_check(), "msg")  # do_check() NOT called in release

# Groups
add_to_group("agents")
get_tree().get_nodes_in_group("agents")
get_tree().call_group("agents", "refresh_pose")

# Scene instantiation
var scene := preload("res://scenes/buildings/brewhouse.tscn")  # compile-time
var scene2 := load("res://scenes/buildings/brewhouse.tscn")    # runtime
var inst := scene.instantiate()
add_child(inst)

# Timer (one-shot, no node needed)
await get_tree().create_timer(1.0).timeout

# Instance validity check (for non-RefCounted nodes that may have been freed)
if is_instance_valid(agent):
    agent.do_thing()
```

## Math / Interpolation

```gdscript
lerp(a, b, t)
move_toward(from, to, delta)
smoothstep(from, to, val)
snappedf(val, step)
wrapf(val, min_val, max_val)
fmod(x, y)        # float modulo (not %)
fposmod(x, y)     # always positive result

# Frame-rate independent exponential decay (camera follow, smoothing):
# WRONG: value *= (1 - rate)            — result depends on tick rate
# CORRECT:
value *= exp(-rate * delta)            # frame-rate independent damping
```

## File I/O

```gdscript
# FileAccess auto-closes — do NOT call .close()
var f = FileAccess.open(path, FileAccess.WRITE)
f.store_string(data)

var text = FileAccess.get_file_as_string(path)

# JSON (all content and all numbers live in data/*.json)
var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/tuning.json"))
```

---

## Engine Quirks (Godot 4, GDScript)

**`queue_free()` vs `free()`**
`queue_free()` removes the node at end of frame — it remains in `get_children()` until then.
Use `free()` if you need immediate removal and are certain it's safe. In most cases
`queue_free()` is correct.

**Sibling signal timing in `_ready()`**
`_ready()` fires in tree order (children first, then parent, then siblings in order). If sibling
A emits a signal in its `_ready()`, sibling B has not connected yet. Fix: after connecting,
manually call the handler if the emitter already has data. Expect this when `world_renderer.gd`
wires up several sibling view nodes under one root.

**Collision state changes inside callbacks**
Changing a `CollisionShape3D`'s `disabled` property inside `body_entered` / `body_exited` /
`area_entered` causes "Can't change state while flushing queries". Always use
`set_deferred("disabled", true)`.

**Collision layer bitmasks vs UI layer numbers**
In code, `collision_layer` and `collision_mask` are bitmasks — **not** the UI layer numbers:
UI Layer 1 → `1`, Layer 2 → `2`, Layer 3 → `4`, Layer 4 → `8` (powers of 2).
`collision_layer = 4` means UI Layer 3, not Layer 4.

**`.gdignore` silently blocks imports**
A `.gdignore` file in any directory makes Godot's importer skip that entire directory. Never
place one in `data/` or `assets/models/`. If JSON or a `.glb` isn't importing, check for a
stray `.gdignore` first.

**RID leak errors on headless exit**
Harmless. Godot always emits these when exiting in headless mode. Ignore them.

**`@onready` with `@export`**
Combining both annotations on the same variable is not recommended — `@onready` overwrites the
exported value at runtime. Triggers `ONREADY_WITH_EXPORT` warning.

**`assert()` in release builds**
The expression inside `assert()` is **not evaluated** in release builds. Do not put side-effect
code inside assert expressions.

**GUT `class_name` resolution**
GUT reports an unloadable test file as a warning, not a failure, and still prints "All tests
passed". A new script carrying a `class_name` does not resolve until Godot re-imports. After
adding any `class_name`, run `godot --headless --import --path .` and check the warning count,
not just the pass line. (See `CLAUDE.md` Testing.)

---

## Stone and Psalm 3D specifics

The language and engine sections above apply generally. These are the project's fixed 3D
conventions — see `docs/ARCHITECTURE_GUIDE.md` §4 for the rationale. Do not renegotiate them
casually.

### Camera — orthographic orbit

- `Camera3D.projection = PROJECTION_ORTHOGONAL`, `size` set for the tile scale, starting at
  **40° pitch**. Middle-mouse drag controls continuous yaw and 15–80° pitch; Q/E still turn in
  animated **90° yaw steps**. No roll, no perspective, no zoom-to-cursor.
- 1 world unit = 1 metre; terrain cell is 2 m × 2 m. Snap building placement to the 2 m grid.
- Because the camera never rolls and its transform is rebuilt from yaw and clamped pitch, you
  never need basis-drift `orthonormalized()` bookkeeping.

### One shared material

- **One shared vertex-colour `StandardMaterial3D`** (plus one small palette texture) for
  everything. `vertex_color_use_as_albedo` is set **automatically** by Godot when the `.glb`
  carries `COLOR_0` — no import preset, no manual step.
- Never add a per-model texture or a per-model material. Forward+ auto-instances identical
  mesh+material pairs; sharing the material is what makes that work and what makes the game
  look like one game by construction.
- Vary per-instance look with `set_instance_shader_parameter()` — it does **not** break
  batching. A unique material per object does.

### Models / import

- glTF `.glb`, +Y up, −Z forward, transforms applied, colour attribute named `Col`.
- Exported from Blender 4.5 LTS via `tools/blender/export_gltf.py`; validated by
  `tools/blender/validate_assets.py` (run before every commit — it exits 1 on any conventions
  violation). See `docs/ASSET_PIPELINE.md`.
- Agents: ~600 tris, 3 bones, **walk bob in the vertex shader** — not per-frame CPU transform
  work per agent.
- `assets/kit/` is third-party greybox, placeholder only, never shipped. `assets/models/` is
  own work.

### Lighting / environment

- One `DirectionalLight3D` + SSAO + SSIL + volumetric fog. **No SDFGI. No lightmaps.** Don't
  switch SDFGI on and don't add a bake step — the look comes from fog + SSIL + the palette.
- Seasons change the environment via palette / light parameters, not by swapping large
  resources synchronously (`docs/ARCHITECTURE_GUIDE.md` §4.7).

### The boundary and determinism (the part that bites silently)

- **Authoritative state lives in `autoloads/`, headless, saved. Transient physical state lives
  in the scene tree, never saved.** Logical position is authoritative here. Only
  `world_renderer.gd` may touch the scene tree — no `get_tree()` anywhere else in `autoloads/`.
- Read interpolated `global_position` for rendering in `_process()`; keep the authoritative
  `grid_pos` / `path` in the sim.
- **No `randf()` in sim code** — the `Dice` object is injected; a `ScriptedDice` double makes
  anything deterministic.
- **Never iterate an unordered `Dictionary` / set where order affects outcome.** Sort keys by
  `id` first. This is the commonest source of non-determinism and it stays invisible until a
  soak test diverges.
- The tick order in `docs/SIMULATION_SPEC.md` §18 is a contract, not a suggestion.
