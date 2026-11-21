"""请大家吃饭的厅。人和菜在游戏里贴上去，这里只画长桌、盘子和灯。

用法：blender --background --python tools/feast_hall.py
输出：art/cutscene/feast_hall.png
"""
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
OUT = os.path.join(PROJ, "art", "cutscene")
W, H = 320, 180


def hex_lin(h):
    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    return (lin(r), lin(g), lin(b), 1.0)


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 1
    scene.render.filter_size = 0.01
    scene.render.dither_intensity = 0.0
    scene.render.film_transparent = False
    scene.render.resolution_x = W
    scene.render.resolution_y = H
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    world = bpy.data.worlds.new("World")
    world.use_nodes = True
    for n in world.node_tree.nodes:
        if n.type == "BACKGROUND":
            n.inputs[0].default_value = hex_lin("1a1814")
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = float(W)
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0.0, -20.0, 0.0)
    cam.rotation_euler = (1.5707963, 0.0, 0.0)
    return scene


def px(x, y):
    return (x - W / 2.0, 0.0, H / 2.0 - y)


def _mat(name, color):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = hex_lin(color)
    emit.inputs[1].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs[0], out.inputs[0])
    return m


def flat(name, color, w, h, x, y, z=0.0):
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (1.5707963, 0.0, 0.0)
    cx, _cy, cz = px(x + w / 2.0, y + h / 2.0)
    o.location = (cx, -z, cz)
    o.scale = (max(w, 1), max(h, 1), 1.0)
    o.data.materials.append(_mat(name, color))
    return o


def disc(name, color, r, x, y, z):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=r, depth=0.4)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (1.5707963, 0.0, 0.0)
    cx, _cy, cz = px(x, y)
    o.location = (cx, -z, cz)
    o.data.materials.append(_mat(name, color))
    return o


def hall(scene):
    flat("Wall", "c4a574", W, 96, 0, 0, -0.3)
    flat("Beam", "5c4030", W, 8, 0, 0, -0.1)
    flat("Night", "243044", 36, 22, 142, 28, 0.0)
    flat("MullionV", "5c4030", 2, 22, 159, 28, 0.05)
    flat("MullionH", "5c4030", 36, 2, 142, 38, 0.05)
    flat("Floor", "a67c52", W, 84, 0, 96, -0.2)
    for i in range(6):
        flat("Seam%d" % i, "7a5438", W, 2, 0, 108 + i * 12, -0.1)
    flat("TableLegL", "5c4030", 8, 36, 28, 128, 0.2)
    flat("TableLegR", "5c4030", 8, 36, 284, 128, 0.2)
    flat("Table", "6b4228", 280, 52, 20, 100, 0.4)
    flat("Cloth", "8f2e2e", 260, 16, 30, 108, 0.55)
    flat("ClothEdge", "f2e2c4", 260, 4, 30, 124, 0.56)
    seats = [36, 72, 108, 144, 180, 216, 252, 288]
    for i, x in enumerate(seats):
        flat("Chair%d" % i, "4a3024", 18, 10, x - 9, 92, 0.15)
        disc("Plate%d" % i, "f7f1e4", 8, x, 136, 0.7)
        disc("PlateRim%d" % i, "d8cfc0", 10, x, 136, 0.65)
    for i, x in enumerate([24, 296]):
        flat("Lantern%d" % i, "c4382a", 10, 16, x - 5, 16, 0.8)
        flat("LanternCap%d" % i, "e0b04a", 12, 3, x - 6, 14, 0.85)
        flat("Tassel%d" % i, "e0b04a", 2, 6, x - 1, 32, 0.8)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, "feast_hall.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("saved", path, flush=True)


if __name__ == "__main__":
    hall(new_scene())
