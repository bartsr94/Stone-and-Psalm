"""Create the low-poly props that mark the first monastic foundation.

These are deliberately presentation-scale placeholders for the Phase 1 valley. They follow the
same contract as the vegetation assets: one mesh, one vertex-colour material, no UVs, and a
ground-centred origin. The final church and buildings remain hero assets to be modelled by hand.

Run from the repository root with:

    blender --background --python tools/blender/create_foundation_props.py

The generated .blend files are then exported by export_gltf.py.
"""

import math
import os
import sys

import bpy


ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BLEND_DIR = os.path.join(ROOT, "assets", "blend")

PALETTE = {
    "limestone_light": (0.788, 0.761, 0.698, 1.0),
    "limestone_mid": (0.663, 0.635, 0.588, 1.0),
    "limestone_shadow": (0.518, 0.494, 0.459, 1.0),
    "stone_weathered": (0.557, 0.545, 0.494, 1.0),
    "oak_fresh": (0.541, 0.420, 0.267, 1.0),
    "oak_weathered": (0.369, 0.298, 0.224, 1.0),
    "oak_dark": (0.243, 0.196, 0.153, 1.0),
    "charcoal": (0.149, 0.141, 0.122, 1.0),
    "fire": (0.816, 0.478, 0.196, 1.0),
}


class MeshBuilder:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.colours = []

    def vertex(self, position, colour):
        self.vertices.append(position)
        self.colours.append(PALETTE[colour])
        return len(self.vertices) - 1

    def face(self, positions, colour):
        self.faces.append(tuple(self.vertex(p, colour) for p in positions))

    def triangle(self, a, b, c, colour):
        self.face((a, b, c), colour)

    def quad(self, a, b, c, d, colour):
        self.face((a, b, c, d), colour)

    def box(self, centre, size, colour, top_colour=None):
        """Add an axis-aligned box with z as the Blender-up axis."""
        cx, cy, cz = centre
        sx, sy, sz = (value * 0.5 for value in size)
        bottom = ((cx - sx, cy - sy, cz - sz), (cx + sx, cy - sy, cz - sz),
                  (cx + sx, cy + sy, cz - sz), (cx - sx, cy + sy, cz - sz))
        top = ((cx - sx, cy - sy, cz + sz), (cx + sx, cy - sy, cz + sz),
               (cx + sx, cy + sy, cz + sz), (cx - sx, cy + sy, cz + sz))
        self.quad(bottom[0], bottom[1], bottom[2], bottom[3], colour)
        self.quad(bottom[1], top[1], top[2], bottom[2], colour)
        self.quad(bottom[2], top[2], top[3], bottom[3], colour)
        self.quad(bottom[3], top[3], top[0], bottom[0], colour)
        self.quad(bottom[0], top[0], top[1], bottom[1], colour)
        self.quad(top[0], top[3], top[2], top[1], top_colour or colour)

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
    min_x = min(vertex[0] for vertex in builder.vertices)
    max_x = max(vertex[0] for vertex in builder.vertices)
    min_y = min(vertex[1] for vertex in builder.vertices)
    max_y = max(vertex[1] for vertex in builder.vertices)
    min_z = min(vertex[2] for vertex in builder.vertices)
    shift_x = (min_x + max_x) * 0.5
    shift_y = (min_y + max_y) * 0.5
    builder.vertices = [(x - shift_x, y - shift_y, z - min_z) for x, y, z in builder.vertices]
    obj = builder.to_object(name)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    bpy.ops.object.select_all(action="DESELECT")


def make_founders_cross():
    b = MeshBuilder()
    b.cylinder((0.0, 0.0, 0.0), 0.58, 0.28, 8, "limestone_shadow", "limestone_mid")
    b.cylinder((0.0, 0.0, 0.28), 0.25, 2.20, 8, "limestone_mid", "limestone_light")
    b.box((0.0, 0.0, 1.63), (1.24, 0.34, 0.34), "limestone_mid", "limestone_light")
    b.box((0.0, 0.0, 2.20), (0.44, 0.30, 0.40), "limestone_shadow", "limestone_mid")
    finish("prop_founders_cross", b)


def make_timber_shelter():
    b = MeshBuilder()
    # Four squat posts and two ridge rails make a readable temporary shelter at wide zoom.
    for x in (-1.35, 1.35):
        for y in (-0.90, 0.90):
            b.box((x, y, 0.95), (0.22, 0.22, 1.90), "oak_weathered", "oak_fresh")
    b.box((0.0, -0.90, 1.82), (3.0, 0.22, 0.22), "oak_dark", "oak_fresh")
    b.box((0.0, 0.90, 1.82), (3.0, 0.22, 0.22), "oak_dark", "oak_fresh")
    # A simple pitched roof, with the open gable facing the approach.
    front = ((-1.62, -1.12, 1.72), (1.62, -1.12, 1.72), (0.0, -1.12, 2.90))
    back = ((-1.62, 1.12, 1.72), (1.62, 1.12, 1.72), (0.0, 1.12, 2.90))
    b.quad(front[0], front[1], back[1], back[0], "oak_weathered")
    b.quad(front[1], front[2], back[2], back[1], "oak_fresh")
    b.quad(front[2], front[0], back[0], back[2], "oak_dark")
    b.triangle(front[0], front[2], front[1], "oak_dark")
    b.triangle(back[1], back[2], back[0], "oak_weathered")
    finish("prop_timber_shelter", b)


def make_campfire():
    b = MeshBuilder()
    for i in range(8):
        angle = math.tau * i / 8.0
        b.cylinder((math.cos(angle) * 0.72, math.sin(angle) * 0.72, 0.0),
                   0.22, 0.28, 7, "stone_weathered", "limestone_light")
    b.cylinder((-0.48, 0.0, 0.23), 0.15, 1.05, 7, "oak_dark", "oak_fresh", "x")
    b.cylinder((0.0, -0.48, 0.31), 0.15, 1.05, 7, "oak_weathered", "oak_fresh", "x")
    b.cylinder((0.0, 0.0, 0.28), 0.25, 0.48, 7, "charcoal", "fire")
    finish("prop_campfire", b)


def main():
    os.makedirs(BLEND_DIR, exist_ok=True)
    for maker in (make_founders_cross, make_timber_shelter, make_campfire):
        reset_scene()
        maker()
    print("[foundation] created founders cross, timber shelter, and campfire")


if __name__ == "__main__":
    try:
        main()
    except Exception:
        import traceback
        traceback.print_exc()
        sys.exit(1)
