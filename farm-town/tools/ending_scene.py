"""用 Blender 画两张结局画。人用已经画好的序列帧，碑、梯子、灯和地面按同一套颜色用方块搭。

用法：blender --background --python tools/ending_scene.py
输出：art/cutscene/funeral.png、art/cutscene/shaft.png
"""
import math
import os

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
ART = os.path.join(PROJ, "art", "characters")
OUT = os.path.join(PROJ, "art", "cutscene")
TMP = os.path.join(HERE, "_tmp")

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
            n.inputs[0].default_value = hex_lin("141820")
    scene.world = world
    cam_data = bpy.data.cameras.new("Cam")
    cam_data.type = "ORTHO"
    # 宽是长边，320 个世界单位正好铺满
    cam_data.ortho_scale = float(W)
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam.location = (0.0, -20.0, 0.0)
    cam.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    return scene


def px(x, y):
    """画面左上角是 (0, 0)。"""
    return (x - W / 2.0, 0.0, H / 2.0 - y)


def flat(name, color, w, h, x, y, z=0.0):
    """一块纯色，左上角放在像素 (x, y)，z 越大越靠前。"""
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    cx, cy, cz = px(x + w / 2.0, y + h / 2.0)
    # 相机在 -Y 朝 +Y 看，y 越小离相机越近
    o.location = (cx, -z, cz)
    o.scale = (w, h, 1.0)
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


def sprite(name, who, row, frame, x, foot_y):
    """把序列帧里的一格贴上，脚底落在 foot_y。x 是格子左边缘。格子事先裁好在 tools/_tmp。"""
    path = os.path.join(TMP, "%s_%d_%d.png" % (who, row, frame))
    img = bpy.data.images.load(path)
    img.alpha_mode = "CHANNEL_PACKED"
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (math.pi / 2.0, 0.0, 0.0)
    # 脚在格子第 40 行，格子中心比脚高 16 像素
    cx, cy, cz = px(x + 24.0, foot_y - 16.0)
    o.location = (cx, -0.4, cz)
    o.scale = (48.0, 48.0, 1.0)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    try:
        m.blend_method = "CLIP"
    except Exception:
        pass
    nt = m.node_tree
    nt.nodes.clear()
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs[1].default_value = 1.0
    trans = nt.nodes.new("ShaderNodeBsdfTransparent")
    mix = nt.nodes.new("ShaderNodeMixShader")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(tex.outputs[0], emit.inputs[0])
    nt.links.new(tex.outputs[1], mix.inputs[0])
    nt.links.new(trans.outputs[0], mix.inputs[1])
    nt.links.new(emit.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    o.data.materials.append(m)
    return o


def save(scene, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("saved", path, flush=True)


def funeral():
    scene = new_scene()
    flat("Sky", "36426a", W, 108, 0, 0, -0.2)
    flat("Hill", "4a5a8a", W, 28, 0, 72, -0.1)
    flat("Ground", "4a9a3c", W, 72, 0, 108, -0.05)
    flat("Path", "8a6a4e", 150, 18, 20, 118, 0.0)
    # 碑
    flat("Base", "74787e", 36, 10, 118, 112, 0.1)
    flat("Stone", "9a9ea4", 28, 36, 122, 78, 0.15)
    flat("Top", "f1ead6", 22, 8, 125, 80, 0.2)
    # 人在游戏里按走路的序列帧贴上去，这里只留空场景
    save(scene, "funeral")


def shaft():
    scene = new_scene()
    flat("Dark", "141820", W, H, 0, 0, -0.2)
    flat("WallL", "2a2628", 28, H, 118, 0, 0.0)
    flat("WallR", "2a2628", 28, H, 174, 0, 0.0)
    flat("Hole", "1c1a18", 28, H, 146, 0, -0.05)
    # 梯子靠在井的左边
    flat("RailL", "7d5230", 3, H, 150, 0, 0.1)
    flat("RailR", "7d5230", 3, H, 166, 0, 0.1)
    for i in range(8):
        flat("Rung%d" % i, "b07a42", 19, 3, 150, 8 + i * 22, 0.12)
    for i in range(6):
        flat("Lamp%d" % i, "f7d24a", 6, 5, 182, 12 + i * 28, 0.2)
    save(scene, "shaft")


def letter_room():
    """农舍里的一张桌子和一封信。人在游戏里贴上去，再褪成旧照片。"""
    scene = new_scene()
    flat("Wall", "6a5a48", W, 118, 0, 0, -0.2)
    flat("Floor", "8a6a4e", W, 70, 0, 110, -0.05)
    flat("Win", "c5d0d4", 44, 32, 36, 36, 0.0)
    flat("WinFrame", "3a342c", 52, 4, 32, 32, 0.1)
    flat("WinFrameB", "3a342c", 52, 4, 32, 68, 0.1)
    flat("WinFrameL", "3a342c", 4, 40, 32, 32, 0.1)
    flat("WinFrameR", "3a342c", 4, 40, 80, 32, 0.1)
    flat("Table", "6a4328", 86, 16, 168, 112, 0.1)
    flat("Paper", "f4f0e6", 28, 16, 172, 106, 0.2)
    flat("Line1", "8a8478", 18, 2, 176, 110, 0.25)
    flat("Line2", "8a8478", 14, 2, 176, 115, 0.25)
    save(scene, "letter_room")


funeral()
shaft()
letter_room()
