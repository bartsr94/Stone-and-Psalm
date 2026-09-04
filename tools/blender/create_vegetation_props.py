"""Create the small authored vegetation props used around the founding valley.

The output follows the same deliberately constrained contract as the hand-authored props:
one mesh object, one shared vertex-colour material, no UVs, and a ground-centred origin.
Run from the repository root with:

    blender --background --python tools/blender/create_vegetation_props.py

The generated .blend files are then exported by export_gltf.py.
"""

import math
import os
import sys

import bpy


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_DIR = os.path.join(ROOT, "assets", "blend")

PALETTE = {
    "oak_fresh": (0.541, 0.420, 0.267, 1.0),
    "oak_weathered": (0.369, 0.298, 0.224, 1.0),
    "oak_dark": (0.243, 0.196, 0.153, 1.0),
    "foliage_dark": (0.243, 0.322, 0.196, 1.0),
    "foliage_light": (0.361, 0.455, 0.251, 1.0),
    "bracken": (0.541, 0.384, 0.212, 1.0),
    "gritstone": (0.486, 0.463, 0.424, 1.0),
    "stone_weathered": (0.557, 0.545, 0.494, 1.0),
    "mud": (0.361, 0.310, 0.251, 1.0),
}


class MeshBuilder:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.colours = []

    def vertex(self, position, colour):
        self.vertices.append(position)
        self.colours.append(PALETTE[colour] if isinstance(colour, str) else colour)
        return len(self.vertices) - 1

    def face(self, positions, colour):
        self.faces.append(tuple(self.vertex(p, colour) for p in positions))

    def triangle(self, a, b, c, colour):
        self.face((a, b, c), colour)

    def quad(self, a, b, c, d, colour):
        self.face((a, b, c, d), colour)

    def cylinder(self, centre, radius, height, sides, side_colour, top_colour=None, direction="z"):
        """Add a capped low-poly cylinder, with its base on centre along direction."""
        top_colour = top_colour or side_colour
        cx, cy, cz = centre
        bottom = []
        top = []
        for i in range(sides):
            angle = math.tau * i / sides
            c = math.cos(angle) * radius
            s = math.sin(angle) * radius
            if direction == "x":
                bottom.append((cx, cy + c, cz + s))
                top.append((cx + height, cy + c, cz + s))
            elif direction == "y":
                bottom.append((cx + c, cy, cz + s))
                top.append((cx + c, cy + height, cz + s))
            else:
                bottom.append((cx + c, cy + s, cz))
                top.append((cx + c, cy + s, cz + height))
        for i in range(sides):
            nxt = (i + 1) % sides
            self.quad(bottom[i], bottom[nxt], top[nxt], top[i], side_colour)
        if direction == "x":
            self.face(tuple(reversed(bottom)), side_colour)
            self.face(top, top_colour)
        elif direction == "y":
            self.face(tuple(reversed(bottom)), side_colour)
            self.face(top, top_colour)
        else:
            self.face(tuple(reversed(bottom)), side_colour)
            self.face(top, top_colour)

    def to_object(self, name):
        mesh = bpy.data.meshes.new(name + "_mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)

        colours = mesh.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
        mesh.color_attributes.active_color = colours
        for polygon in mesh.polygons:
            for loop_index in polygon.loop_indices:
                colours.data[loop_index].color = self.colours[mesh.loops[loop_index].vertex_index]

        obj.data.materials.append(shared_material())
        return obj


def shared_material():
    material = bpy.data.materials.get("M_StoneAndPsalm")
    if material is None:
        material = bpy.data.materials.new("M_StoneAndPsalm")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Roughness"].default_value = 0.85
    colour = nodes.new("ShaderNodeVertexColor")
    colour.layer_name = "Col"
    links.new(colour.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    return material


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
        for block in list(datablocks):
            if block.users == 0:
                datablocks.remove(block)


def finish(name, builder):
    # Normalize the authored footprint after all silhouette details are present. This makes the
    # origin contract explicit even for deliberately asymmetric clumps and faceted cylinders.
    min_x = min(vertex[0] for vertex in builder.vertices)
    max_x = max(vertex[0] for vertex in builder.vertices)
    min_y = min(vertex[1] for vertex in builder.vertices)
    max_y = max(vertex[1] for vertex in builder.vertices)
    min_z = min(vertex[2] for vertex in builder.vertices)
    shift_x = (min_x + max_x) * 0.5
    shift_y = (min_y + max_y) * 0.5
    builder.vertices = [
        (x - shift_x, y - shift_y, z - min_z)
        for x, y, z in builder.vertices
    ]
    obj = builder.to_object(name)
    # Geometry is authored directly in final coordinates, so the object transform is already
    # applied and the validator can enforce the origin/scale contract without exceptions.
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    bpy.ops.object.select_all(action="DESELECT")


def make_stump():
    b = MeshBuilder()
    b.cylinder((0.0, 0.0, 0.0), 0.44, 0.78, 10, "oak_weathered", "oak_fresh")
    # Four low triangular root flares keep the silhouette grounded without becoming a building.
    for angle in (0.0, math.pi / 2.0, math.pi, math.pi * 1.5):
        direction = (math.cos(angle), math.sin(angle))
        side = (-direction[1], direction[0])
        base = (direction[0] * 0.34, direction[1] * 0.34, 0.02)
        left = (base[0] + side[0] * 0.16, base[1] + side[1] * 0.16, 0.02)
        right = (base[0] - side[0] * 0.16, base[1] - side[1] * 0.16, 0.02)
        tip = (direction[0] * 0.78, direction[1] * 0.78, 0.0)
        peak = (direction[0] * 0.30, direction[1] * 0.30, 0.44)
        b.triangle(left, right, peak, "oak_dark")
        b.triangle(right, tip, peak, "oak_weathered")
        b.triangle(tip, left, peak, "oak_fresh")
    finish("prop_stump", b)


def make_fallen_log():
    b = MeshBuilder()
    b.cylinder((-1.18, 0.0, 0.34), 0.32, 2.36, 10, "oak_weathered", "oak_fresh", "x")
    # A pair of short broken branches gives the log a readable profile at game distance.
    for x, y, z, radius, height in ((-0.55, 0.0, 0.54, 0.12, 0.48), (0.56, 0.02, 0.56, 0.10, 0.38)):
        b.cylinder((x, y, z), radius, height, 7, "oak_dark", "oak_fresh", "z")
    finish("prop_fallen_log", b)


def make_fern_clump():
    b = MeshBuilder()
    blade_count = 12
    for i in range(blade_count):
        angle = math.tau * i / blade_count
        lean = 0.30 + 0.10 * math.sin(i * 2.7)
        height = 0.62 + 0.25 * (0.5 + 0.5 * math.sin(i * 1.9))
        width = 0.11
        direction = (math.cos(angle), math.sin(angle))
        side = (-direction[1], direction[0])
        base = (0.0, 0.0, 0.02)
        shoulder = (direction[0] * lean * 0.45, direction[1] * lean * 0.45, height * 0.53)
        tip = (direction[0] * lean, direction[1] * lean, height)
        left = (shoulder[0] + side[0] * width, shoulder[1] + side[1] * width, shoulder[2])
        right = (shoulder[0] - side[0] * width, shoulder[1] - side[1] * width, shoulder[2])
        colour = "foliage_light" if i % 3 == 0 else "foliage_dark"
        b.triangle(base, left, tip, colour)
        b.triangle(base, tip, right, colour)
        b.triangle(left, right, tip, "foliage_light")
    b.cylinder((0.0, 0.0, 0.0), 0.16, 0.18, 7, "bracken", "foliage_dark")
    finish("prop_fern_clump", b)


def make_reeds():
    b = MeshBuilder()
    stems = ((-0.24, -0.08, 1.35), (-0.08, 0.04, 1.72), (0.10, -0.05, 1.48),
             (0.25, 0.05, 1.62), (-0.16, 0.16, 1.18), (0.05, 0.18, 1.28))
    for i, (x, y, height) in enumerate(stems):
        b.cylinder((x, y, 0.0), 0.035, height, 5, "bracken", "foliage_light")
        # One pair of flat, tapered leaves per stem keeps the silhouette legible and cheap.
        angle = math.tau * (i / len(stems) + 0.17)
        direction = (math.cos(angle), math.sin(angle))
        for side_sign in (-1.0, 1.0):
            z = height * (0.42 + 0.08 * (i % 2))
            root = (x, y, z)
            tip = (x + direction[0] * 0.25 * side_sign, y + direction[1] * 0.25 * side_sign, z + 0.30)
            side = (-direction[1] * 0.035, direction[0] * 0.035, 0.0)
            b.triangle((root[0] - side[0], root[1] - side[1], root[2]),
                       (root[0] + side[0], root[1] + side[1], root[2]), tip,
                       "foliage_light" if i % 2 else "bracken")
    finish("prop_river_reeds", b)


def main():
    os.makedirs(BLEND_DIR, exist_ok=True)
    shared_material()
    for maker in (make_stump, make_fallen_log, make_fern_clump, make_reeds):
        reset_scene()
        maker()
    print("[props] created stump, fallen log, fern clump, and river reeds")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
