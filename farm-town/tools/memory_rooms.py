"""五级忆的场景。人在游戏里放大贴上去，再褪成旧照片。道具加一圈深色边，免得褪色以后糊成一块。

用法：blender --background --python tools/memory_rooms.py
输出：art/cutscene/mem_<居民>.png，以及姜婆婆的 mem_jiang.png
"""
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
OUT = os.path.join(PROJ, "art", "cutscene")
W, H = 320, 180
INK = "241c18"


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
            n.inputs[0].default_value = hex_lin("141820")
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


def flat(name, color, w, h, x, y, z=0.0):
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (1.5707963, 0.0, 0.0)
    cx, _cy, cz = px(x + w / 2.0, y + h / 2.0)
    o.location = (cx, -z, cz)
    o.scale = (max(w, 1), max(h, 1), 1.0)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs[0].default_value = hex_lin(color)
    emit.inputs[1].default_value = 1.0
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs[0], out.inputs[0])
    o.data.materials.append(m)
    return o


def inked(name, color, w, h, x, y, z):
    flat(name + "o", INK, w + 4, h + 4, x - 2, y - 2, z)
    flat(name, color, w, h, x, y, z + 0.02)


def save(scene, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("saved", path, flush=True)


def indoors():
    flat("Wall", "d2b48a", W, 120, 0, 0, -0.2)
    flat("Beam", "5c4030", W, 10, 0, 0, -0.05)
    flat("Base", "3a2c24", W, 8, 0, 112, 0.02)
    flat("Floor", "c4986a", W, 68, 0, 112, -0.08)
    for i in range(5):
        flat("Seam%d" % i, "7a5438", W, 2, 0, 126 + i * 12, 0.0)


def lines(name, x, y, n, w, gap, z):
    for i in range(n):
        flat("%s%d" % (name, i), "5c4030", w, 2, x, y + i * gap, z)


def jiang():
    scene = new_scene()
    indoors()
    # 测试认窗户：玻璃落在 (50, 50)，人站在右边，不挡这块
    inked("Win", "c5d0d4", 44, 32, 36, 36, 0.1)
    flat("Mullion", "5c4030", 2, 32, 56, 36, 0.14)
    inked("Table", "8a5a34", 150, 28, 160, 142, 0.2)
    inked("Paper", "f7f1e4", 70, 44, 200, 108, 0.3)
    lines("Ln", 210, 116, 4, 50, 7, 0.34)
    save(scene, "mem_jiang")


def ahe():
    scene = new_scene()
    indoors()
    flat("Roof", "6a3030", 210, 18, 110, 16, 0.12)
    for i in range(6):
        flat("Tile%d" % i, "3a201c", 210, 2, 110, 18 + i * 3, 0.15)
    inked("Awning", "a33b32", 190, 12, 120, 36, 0.18)
    flat("Stripe", "f4f0e6", 190, 3, 120, 40, 0.2)
    inked("Post", "5c4030", 8, 78, 250, 46, 0.16)
    inked("Board", "f7f1e4", 110, 46, 188, 48, 0.25)
    lines("S", 200, 58, 3, 86, 10, 0.3)
    inked("Door", "5c4030", 34, 64, 270, 78, 0.12)
    inked("Counter", "8a5a34", 170, 16, 140, 148, 0.22)
    save(scene, "mem_ahe")


def egret():
    scene = new_scene()
    indoors()
    inked("LegL", "5c4030", 8, 78, 196, 92, 0.15)
    inked("LegR", "5c4030", 8, 78, 286, 92, 0.15)
    inked("Shelf", "8a5a34", 120, 8, 184, 88, 0.18)
    inked("Canvas", "f7f1e4", 110, 84, 190, 16, 0.25)
    flat("Road", "8a6a4e", 70, 5, 210, 58, 0.3)
    flat("Bend", "8a6a4e", 5, 28, 210, 34, 0.3)
    flat("Hill", "5a8a40", 36, 16, 230, 28, 0.3)
    save(scene, "mem_egret")


def qingzhu():
    scene = new_scene()
    flat("Sky", "9eb0c4", W, 52, 0, 0, -0.2)
    flat("Far", "6a8a58", W, 22, 0, 48, -0.1)
    for i in range(4):
        inked("Tree%d" % i, "3d6a30", 18, 22, 24 + i * 78, 34, -0.05)
        flat("Trunk%d" % i, "5c4030", 4, 14, 31 + i * 78, 52, -0.02)
    flat("Water", "3d7a88", W, 70, 0, 68, -0.04)
    for i in range(6):
        flat("Rip%d" % i, "2a5a68", 40, 2, 12 + i * 52, 86 + (i % 3) * 14, 0.0)
    inked("Deck", "a56b3c", W, 48, 0, 132, 0.2)
    for i in range(7):
        flat("Plank%d" % i, "5c4030", W, 2, 0, 140 + i * 6, 0.24)
    for i in range(6):
        inked("P%d" % i, "5c4030", 8, 48, 28 + i * 52, 108, 0.26)
    flat("Rail", "c48a55", 300, 5, 10, 112, 0.3)
    save(scene, "mem_qingzhu")


def shishu():
    scene = new_scene()
    indoors()
    flat("Roof", "4a4038", 160, 14, 150, 22, 0.1)
    inked("Forge", "3a3834", 100, 90, 200, 36, 0.14)
    flat("Mouth", "1a1412", 52, 36, 224, 62, 0.18)
    flat("Fire", "e07030", 28, 16, 236, 74, 0.22)
    inked("Anvil", "4a5058", 78, 20, 150, 146, 0.24)
    inked("Horn", "4a5058", 22, 14, 214, 140, 0.26)
    inked("Hammer", "5c4030", 6, 28, 168, 118, 0.28)
    flat("Head", "4a5058", 18, 8, 162, 114, 0.3)
    save(scene, "mem_shishu")


def amu():
    scene = new_scene()
    flat("Sky", "b7c4a0", W, 64, 0, 0, -0.2)
    flat("Hill", "6a8a48", W, 28, 0, 56, -0.1)
    flat("Grass", "5aaa40", W, 100, 0, 80, -0.05)
    for i in range(10):
        flat("Tuft%d" % i, "3d7a28", 6, 12, 8 + i * 32, 158, 0.05)
    inked("Shed", "8a5a34", 70, 48, 240, 78, 0.1)
    flat("ShedRoof", "6a3030", 82, 12, 234, 68, 0.14)
    inked("Rail", "a56b3c", 130, 6, 180, 108, 0.16)
    inked("PL", "5c4030", 8, 56, 180, 86, 0.18)
    inked("PR", "5c4030", 8, 56, 302, 86, 0.18)
    save(scene, "mem_amu")


def laozhou():
    scene = new_scene()
    flat("Sky", "9eb0c4", W, 48, 0, 0, -0.2)
    flat("Water", "3d7a88", W, 90, 0, 48, -0.1)
    for i in range(6):
        flat("Rip%d" % i, "2a5a68", 36, 2, 8 + i * 52, 70 + (i % 3) * 16, 0.0)
    inked("Dock", "a56b3c", 240, 46, 80, 134, 0.2)
    for i in range(6):
        flat("Gap%d" % i, "5c4030", 240, 2, 80, 142 + i * 6, 0.24)
    inked("Post", "5c4030", 8, 40, 292, 108, 0.22)
    inked("Rod", "e6d2a4", 5, 100, 236, 40, 0.3)
    flat("Tip", "c45a3a", 10, 6, 233, 36, 0.32)
    flat("Line", "2a2420", 2, 48, 238, 90, 0.28)
    save(scene, "mem_laozhou")


def yunniang():
    scene = new_scene()
    indoors()
    inked("Stove", "6a4030", 140, 40, 160, 128, 0.16)
    flat("Mouth", "1a1412", 40, 16, 186, 140, 0.2)
    flat("Ember", "e07030", 22, 8, 194, 144, 0.22)
    inked("Pot", "3a4048", 52, 36, 210, 96, 0.26)
    inked("Lid", "8a9098", 62, 8, 205, 90, 0.3)
    flat("Steam", "d8d0c4", 4, 16, 228, 72, 0.32)
    save(scene, "mem_yunniang")


def bai():
    scene = new_scene()
    indoors()
    inked("Shelf", "5c4030", 100, 8, 190, 28, 0.1)
    inked("Book", "8a3a32", 18, 26, 204, 32, 0.14)
    inked("Book2", "3a4a6a", 18, 26, 228, 32, 0.14)
    inked("Desk", "8a5a34", 160, 24, 150, 146, 0.2)
    inked("Paper", "f7f1e4", 84, 52, 190, 100, 0.28)
    lines("L", 200, 110, 4, 64, 8, 0.32)
    flat("Seal", "a33b32", 14, 14, 248, 128, 0.34)
    save(scene, "mem_bai")


def luyuan():
    scene = new_scene()
    indoors()
    inked("Board", "f7f1e4", 100, 132, 190, 20, 0.16)
    lines("N", 204, 32, 11, 72, 10, 0.22)
    flat("Mark", "a33b32", 28, 4, 204, 92, 0.26)
    save(scene, "mem_luyuan")


jiang()
ahe()
egret()
qingzhu()
shishu()
amu()
laozhou()
yunniang()
bai()
luyuan()
