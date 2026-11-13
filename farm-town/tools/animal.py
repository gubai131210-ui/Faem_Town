"""用 Blender 生成动物的模型和动作，渲染成带描边的像素序列帧。

用法:  blender --background --python tools/animal.py -- [配置名]
       配置在 tools/animals/<配置名>.json，默认 chicken
输出:  art/creatures/<名字>.png   32x32 一格；行 = 动画 x 方向(下/上/右/左)，列 = 帧
       art/creatures/<名字>.json  帧描述，格式和角色的一样，游戏里用 CharacterSheet 读
骨架按 body 分：
    bird       鸡、鸭：圆身子、两条腿、脖子探出去的头，走路腿交替、头一点一点
    quadruped  山羊、绵羊、水牛、狗、猫：横着的身子、四条腿、脖子顶着头，走路对角的腿一起迈，低头是吃草
渲染、像素化、描边那一套和 tools/character.py 相同，颜色也来自 data/palette.json。
"""
import json
import math
import os
import shutil
import sys

import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TMP = os.path.join(HERE, "_tmp_animal")

_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CONFIG_NAME = _args[0] if _args else "chicken"
with open(os.path.join(HERE, "animals", CONFIG_NAME + ".json"), encoding="utf-8") as _f:
    CONFIG = json.load(_f)
with open(os.path.join(PROJ, "data", "palette.json"), encoding="utf-8") as _f:
    LETTERS = json.load(_f)
NAME = CONFIG.get("name", CONFIG_NAME)
# 配置项：
#   body    骨架："bird"
#   scale   个头，鸡 1.0
#   parts   各部位的颜色：palette.json 里 cloth 的名字，或 [亮, 暗] 两个单字符键，或 ["#rrggbb", "#rrggbb"]
#   bird    鸟的样子：comb 鸡冠；wattle 肉垂；bill "cone" 尖嘴 / "flat" 扁嘴；tail 尾巴高度；neck 脖子伸出多少；
#           head_scale 头的大小；body 身子的三个半径
BODY = CONFIG.get("body", "bird")
BODY_SCALE = float(CONFIG.get("scale", 1.0))
BIRD = CONFIG.get("bird", {})
#   quad    四条腿的样子：body 身子三个半径；leg 腿长；neck / neck_up 头在身子前方多远、多高；head 头的三个半径；
#           horns "goat" / "buffalo"；ears "side" 横着 / "flop" 耷拉 / "point" 竖着；tail "short" / "long" / "up"；
#           wool 一身卷毛；beard 山羊胡；snout 嘴伸出多少
#   cell / foot_row  一格多大、脚底在第几行（大牲口用 48 / 40）
QUAD = CONFIG.get("quad", {})
OUT_DIR = os.path.join(PROJ, "art", "creatures")
OUT = os.path.join(OUT_DIR, NAME + ".png")
OUT_JSON = os.path.join(OUT_DIR, NAME + ".json")

CELL = int(CONFIG.get("cell", 32))
SS = 4
PPU = 16.0
ELEV = math.radians(14.0)
FOOT_ROW = int(CONFIG.get("foot_row", 26))
PIX = 1.0 / PPU / math.cos(ELEV)
THRESH = 0.2
SCALE = 1.25 * BODY_SCALE

ANIMS = [
    ("idle", 2, {"loop": True, "fps": 1.6}),
    ("walk", 4, {"loop": True, "step_frames": [0, 2]}),
    # 低头啄两下
    ("peck", 2, {"loop": True, "fps": 4.0}),
]
DIRS = [0.0, 180.0, 90.0, -90.0]   # 下 上 右 左
COLS = 8

PARTS = {
    "body": ("x", "X"),
    "wing": ("X", "K"),
    "head": ("x", "X"),
    "beak": ("q", "Y"),
    "leg": ("q", "Y"),
    "comb": ("r", "R"),
    "eye": ("e", "e"),
    "horn": ("k", "K"),
    "hoof": ("T", "T"),
    "ear": ("x", "X"),
    "snout": ("c", "S"),
    "tail": ("x", "X"),
}


def _pair(v):
    if isinstance(v, str):
        return tuple(LETTERS["cloth"][v])
    a, b = v
    if a.startswith("#"):
        return (a[1:], b[1:])
    return (LETTERS[a], LETTERS[b])


PAL = {part: (LETTERS[a], LETTERS[b]) for part, (a, b) in PARTS.items()}
for _part, _v in CONFIG.get("parts", {}).items():
    PAL[_part] = _pair(_v)


def d(deg):
    return math.radians(deg)


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_lin(h):
    r, g, b = hex_rgb(h)
    return (lin(r), lin(g), lin(b), 1.0)


PALETTE = []
for _n, (_a, _b) in PAL.items():
    for _h in (_a, _b):
        if hex_rgb(_h) not in PALETTE:
            PALETTE.append(hex_rgb(_h))
PAL_ARR = np.array(PALETTE, dtype=np.int32)
EYE_IDX = PALETTE.index(hex_rgb(PAL["eye"][0]))


# ------------------------------------------------------------------ 场景

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 1
scene.render.filter_size = 0.01
scene.render.dither_intensity = 0.0
scene.render.film_transparent = True
scene.render.resolution_x = CELL * SS
scene.render.resolution_y = CELL * SS
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"

world = bpy.data.worlds.new("World")
world.use_nodes = True
for n in world.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs[0].default_value = (0, 0, 0, 1)
scene.world = world

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = CELL / PPU
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
target_z = (FOOT_ROW - CELL / 2.0) / PPU / math.cos(ELEV)
cam.location = (0.0, -10.0 * math.cos(ELEV), target_z + 10.0 * math.sin(ELEV))
cam.rotation_euler = (math.pi / 2.0 - ELEV, 0.0, 0.0)

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = math.pi
sun_data.use_shadow = False
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = Vector((0.45, 0.55, -0.7)).to_track_quat("-Z", "Y").to_euler()


def make_mat(name):
    light, dark = PAL[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = hex_lin(dark)
    ramp.color_ramp.elements[1].position = THRESH
    ramp.color_ramp.elements[1].color = hex_lin(light)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(diff.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], emit.inputs[0])
    nt.links.new(emit.outputs[0], out.inputs[0])
    return m


MATS = {n: make_mat(n) for n in PAL}


# ------------------------------------------------------------------ 建模

def empty(name, parent, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.empty_display_size = 0.1
    return o


def _finish(name, parent, loc, mat, smooth):
    o = bpy.context.active_object
    o.name = name
    o.parent = parent
    o.location = loc
    o.data.materials.append(MATS[mat])
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
        try:
            o.data.set_sharp_from_angle(angle=d(50))
        except Exception:
            pass
    return o


def box(name, parent, size, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = _finish(name, parent, loc, mat, False)
    o.scale = size
    o.rotation_euler = tuple(d(r) for r in rot)
    return o


def ball(name, parent, radii, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0)
    o = _finish(name, parent, loc, mat, True)
    o.scale = radii
    o.rotation_euler = tuple(d(r) for r in rot)
    return o


def cyl(name, parent, r1, r2, depth, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r1, radius2=r2, depth=depth)
    o = _finish(name, parent, loc, mat, True)
    o.rotation_euler = tuple(d(r) for r in rot)
    return o


root = empty("Root", None)
root.scale = (SCALE, SCALE, SCALE)
_px = 1.0 / (PPU * SCALE)

# 鸟：身子是个椭球，腿从身子底下伸出来，脖子从身子前上方探出去顶着头
if BODY == "bird":
    BR = BIRD.get("body", [0.24, 0.32, 0.23])      # 身子半径 x(宽) y(长) z(高)
    LEG_LEN = float(BIRD.get("leg", 0.22))
    NECK = float(BIRD.get("neck", 0.30))            # 头在身子前方多远
    NECK_UP = float(BIRD.get("neck_up", 0.26))      # 头比身子中心高多少
    HEAD_R = float(BIRD.get("head_scale", 1.0)) * 0.15
    TAIL = float(BIRD.get("tail", 0.3))
    BILL = BIRD.get("bill", "cone")
    BODY_Z = LEG_LEN + BR[2] * 0.85
    body = empty("Body", root, (0, 0, BODY_Z))
    ball("Torso", body, tuple(BR), (0, 0, 0), "body")
    for sx in (-1, 1):
        w = ball("Wing", body, (BR[0] * 0.42, BR[1] * 0.7, BR[2] * 0.55), (BR[0] * 0.78 * sx, 0.03, 0.02), "wing")
        w.rotation_euler = (0, d(-8 * sx), 0)
    # 尾巴：几片往后上方翘的羽毛
    for k, (dz, dy) in enumerate(((0.0, 0.0), (0.08, -0.04), (-0.07, -0.03))):
        f = box("Tail%d" % k, body, (0.12 - 0.03 * k, 0.26, 0.05), (0, BR[1] * 0.85 + 0.06 + dy, BR[2] * 0.3 + TAIL * 0.5 + dz), "wing" if k else "body")
        f.rotation_euler = (d(-35 - 10 * k), 0, 0)
    neck_base = empty("NeckBase", body, (0, -BR[1] * 0.75, BR[2] * 0.55))
    head = empty("Head", neck_base, (0, -NECK * 0.35, NECK_UP))
    cyl("Neck", neck_base, 0.06, 0.07, max(0.05, math.hypot(NECK * 0.35, NECK_UP)), (0, -NECK * 0.17, NECK_UP * 0.5), "body",
        rot=(math.degrees(math.atan2(NECK * 0.35, NECK_UP)), 0, 0))
    ball("Skull", head, (HEAD_R, HEAD_R * 1.1, HEAD_R), (0, 0, 0), "head")
    if BILL == "flat":
        box("Bill", head, (HEAD_R * 1.1, HEAD_R * 1.5, HEAD_R * 0.45), (0, -HEAD_R * 1.5, -HEAD_R * 0.2), "beak")
    else:
        cyl("Bill", head, HEAD_R * 0.45, 0.01, HEAD_R * 1.1, (0, -HEAD_R * 1.5, -HEAD_R * 0.1), "beak", rot=(-90, 0, 0))
    if BIRD.get("comb", False):
        for k in range(3):
            box("Comb%d" % k, head, (0.05, 0.07, 0.08 + 0.02 * (k == 1)), (0, -0.07 + 0.07 * k, HEAD_R * 0.95), "comb")
    if BIRD.get("wattle", False):
        ball("Wattle", head, (0.04, 0.05, 0.06), (0, -HEAD_R * 1.0, -HEAD_R * 0.9), "comb")
    # 眼睛长在头两侧，各 1 像素
    for sx in (-1, 1):
        box("Eye", head, (0.04, 1.1 * _px, 1.1 * _px), (HEAD_R * 0.95 * sx, -HEAD_R * 0.35, HEAD_R * 0.2), "eye")
    legs = []
    for sx in (-1, 1):
        hip = empty("Hip", body, (BR[0] * 0.38 * sx, 0.02, -BR[2] * 0.6))
        cyl("Shin", hip, 0.03, 0.035, LEG_LEN + BR[2] * 0.3, (0, 0, -(LEG_LEN + BR[2] * 0.3) * 0.5), "leg")
        box("Foot", hip, (0.11, 0.16, 0.03), (0, -0.05, -(LEG_LEN + BR[2] * 0.3) + 0.015), "leg")
        legs.append(hip)
elif BODY == "quadruped":
    BR = QUAD.get("body", [0.22, 0.4, 0.22])
    LEG_LEN = float(QUAD.get("leg", 0.3))
    NECK = float(QUAD.get("neck", 0.2))
    NECK_UP = float(QUAD.get("neck_up", 0.28))
    HR = QUAD.get("head", [0.13, 0.19, 0.14])
    SNOUT = float(QUAD.get("snout", 0.12))
    BODY_Z = LEG_LEN + BR[2] * 0.9
    body = empty("Body", root, (0, 0, BODY_Z))
    ball("Torso", body, tuple(BR), (0, 0, 0), "body")
    if QUAD.get("wool", False):
        # 一身卷毛：身子外面再鼓出几团
        for k, (x, y, z, r) in enumerate(((0, -0.5, 0.25, 0.55), (0, 0.5, 0.2, 0.6), (0.55, 0, 0.15, 0.5), (-0.55, 0, 0.15, 0.5),
                                         (0, 0, 0.55, 0.6), (0.4, 0.45, 0.35, 0.45), (-0.4, -0.4, 0.4, 0.45), (0, -0.75, -0.05, 0.4))):
            ball("Wool%d" % k, body, (BR[0] * r * 1.2, BR[1] * r * 0.9, BR[2] * r * 1.2), (BR[0] * x, BR[1] * y, BR[2] * z), "wing" if k % 3 == 2 else "body")
    legs = []
    hip_len = LEG_LEN + BR[2] * 0.45
    for sy in (-1, 1):          # 前、后
        for sx in (-1, 1):
            hip = empty("Hip", body, (BR[0] * 0.55 * sx, BR[1] * 0.62 * sy, -BR[2] * 0.45))
            cyl("Shin", hip, 0.045, 0.055, hip_len, (0, 0, -hip_len * 0.5), "leg")
            box("Hoof", hip, (0.11, 0.12, 0.07), (0, -0.01, -hip_len + 0.035), "hoof")
            legs.append(hip)
    neck_base = empty("NeckBase", body, (0, -BR[1] * 0.78, BR[2] * 0.3))
    head = empty("Head", neck_base, (0, -NECK, NECK_UP))
    cyl("Neck", neck_base, BR[0] * 0.55, BR[0] * 0.4, max(0.05, math.hypot(NECK, NECK_UP)), (0, -NECK * 0.5, NECK_UP * 0.5), "body",
        rot=(math.degrees(math.atan2(NECK, NECK_UP)), 0, 0))
    ball("Skull", head, tuple(HR), (0, 0, 0), "head")
    if SNOUT > 0.0:
        ball("Snout", head, (HR[0] * 0.72, SNOUT, HR[2] * 0.62), (0, -HR[1] * 0.8 - SNOUT * 0.3, -HR[2] * 0.3), "snout")
    for sx in (-1, 1):
        box("Eye", head, (0.04, 1.1 * _px, 1.1 * _px), (HR[0] * 0.97 * sx, -HR[1] * 0.3, HR[2] * 0.25), "eye")
    EARS = QUAD.get("ears", "side")
    for sx in (-1, 1):
        if EARS == "point":
            cyl("Ear", head, HR[0] * 0.42, 0.01, HR[2] * 0.9, (HR[0] * 0.6 * sx, HR[1] * 0.1, HR[2] * 0.95), "ear")
        elif EARS == "flop":
            box("Ear", head, (0.06, HR[1] * 0.7, HR[2] * 1.0), (HR[0] * 1.0 * sx, HR[1] * 0.15, HR[2] * 0.1), "ear")
        else:
            box("Ear", head, (HR[0] * 0.9, 0.08, 0.06), (HR[0] * 1.25 * sx, HR[1] * 0.3, HR[2] * 0.45), "ear", rot=(0, 20 * sx, 0))
    HORNS = QUAD.get("horns", "")
    for sx in (-1, 1):
        if HORNS == "goat":
            cyl("Horn", head, 0.045, 0.01, 0.26, (HR[0] * 0.45 * sx, HR[1] * 0.45, HR[2] * 0.95), "horn", rot=(35, 0, 0))
        elif HORNS == "buffalo":
            # 一对往两边再往后弯的大角：两截
            box("HornA", head, (HR[0] * 1.5, 0.1, 0.1), (HR[0] * 1.5 * sx, HR[1] * 0.35, HR[2] * 0.7), "horn", rot=(0, -12 * sx, 0))
            box("HornB", head, (0.1, 0.1, HR[2] * 1.3), (HR[0] * 2.3 * sx, HR[1] * 0.45, HR[2] * 1.25), "horn", rot=(0, -25 * sx, 0))
    if QUAD.get("beard", False):
        box("Beard", head, (0.05, 0.05, 0.14), (0, -HR[1] * 0.95, -HR[2] * 1.0), "tail")
    TAILK = QUAD.get("tail", "short")
    if TAILK == "long":
        box("Tail", body, (0.05, 0.05, BR[2] * 1.5), (0, BR[1] * 1.0, -BR[2] * 0.3), "tail")
        box("Tuft", body, (0.09, 0.07, 0.12), (0, BR[1] * 1.0, -BR[2] * 1.05), "hoof")
    elif TAILK == "up":
        cyl("Tail", body, 0.045, 0.03, BR[1] * 1.0, (0, BR[1] * 1.15, BR[2] * 0.7), "tail", rot=(-25, 0, 0))
    else:
        ball("Tail", body, (0.07, 0.09, 0.07), (0, BR[1] * 1.0, BR[2] * 0.35), "tail")
else:
    raise ValueError("unknown body " + BODY)


# ------------------------------------------------------------------ 姿势

BASE = dict(bob=0.0, lean=0.0, head=0.0, neck=0.0, leg=(0.0, 0.0), tilt=0.0)


def pose(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


def frames(anim):
    if anim == "idle":
        return [pose(), pose(bob=-PIX, head=6, neck=-3)]
    if anim == "walk":
        return [
            pose(leg=(28, -28), bob=0.0, head=-8, neck=4),
            pose(leg=(0, 0), bob=PIX, head=6, neck=-4),
            pose(leg=(-28, 28), bob=0.0, head=-8, neck=4),
            pose(leg=(0, 0), bob=PIX, head=6, neck=-4),
        ]
    if anim == "peck" and BODY == "quadruped":
        return [
            pose(neck=58, head=22),
            pose(neck=66, head=30, bob=-PIX),
        ]
    if anim == "walk" and BODY == "quadruped":
        return [
            pose(leg=(24, -24), head=-4),
            pose(leg=(0, 0), bob=PIX, head=3),
            pose(leg=(-24, 24), head=-4),
            pose(leg=(0, 0), bob=PIX, head=3),
        ]
    if anim == "peck":
        return [
            pose(lean=14, head=35, neck=20, bob=-PIX),
            pose(lean=28, head=55, neck=34, bob=-2 * PIX),
        ]
    raise ValueError(anim)


def apply_pose(p, facing_deg):
    z = round(p["bob"] * SCALE / PIX) * PIX / SCALE
    root.rotation_euler = (0, 0, d(facing_deg))
    body.location = (0, 0, BODY_Z + z)
    body.rotation_euler = (d(p["lean"]), 0, 0)
    neck_base.rotation_euler = (d(p["neck"]), 0, 0)
    head.rotation_euler = (d(p["head"]), 0, d(p["tilt"]))
    for i, hip in enumerate(legs):
        # 四条腿的顺序是前左、前右、后左、后右：对角的一起迈
        a = p["leg"][i] if len(legs) == 2 else p["leg"][(0, 1, 1, 0)[i]]
        hip.rotation_euler = (d(a) - d(p["lean"]), 0, 0)
    bpy.context.view_layer.update()


# ------------------------------------------------------------------ 渲染与像素化

def render_frame(path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, hgt = img.size
    buf = np.empty(w * hgt * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    arr = (buf.reshape(hgt, w, 4)[::-1] * 255.0 + 0.5).astype(np.uint8)
    return arr


def pixelate(a):
    rgb = a[..., :3].astype(np.int32)
    dist = ((rgb[:, :, None, :] - PAL_ARR[None, None, :, :]) ** 2).sum(-1)
    idx = dist.argmin(-1)
    opaque = a[..., 3] > 127
    idx = np.where(opaque, idx, -1)
    blocks = idx.reshape(CELL, SS, CELL, SS).transpose(0, 2, 1, 3).reshape(CELL, CELL, SS * SS)
    out = np.zeros((CELL, CELL, 4), dtype=np.uint8)
    cover = (blocks >= 0).sum(-1)
    ys, xs = np.nonzero(cover >= 6)
    for y, x in zip(ys, xs):
        vals = blocks[y, x]
        counts = np.bincount(vals[vals >= 0], minlength=len(PALETTE))
        best = int(counts.argmax())
        if counts[EYE_IDX] >= 4:
            best = EYE_IDX
        out[y, x, :3] = PALETTE[best]
        out[y, x, 3] = 255
    return out


def outline(a):
    out = a.copy()
    hgt, w = a.shape[:2]
    for y in range(hgt):
        for x in range(w):
            if a[y, x, 3] > 0:
                continue
            for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < hgt and a[ny, nx, 3] > 127:
                    r, g, b = (a[ny, nx, :3].astype(np.float32) / 255.0)
                    col = (r * 0.36 + 0.03, g * 0.30 + 0.01, b * 0.38 + 0.06)
                    out[y, x, :3] = [int(c * 255.0 + 0.5) for c in col]
                    out[y, x, 3] = 255
                    break
    return out


def save_png(arr, path):
    hgt, w = arr.shape[:2]
    img = bpy.data.images.new("out", w, hgt, alpha=True)
    img.pixels.foreach_set((arr[::-1].astype(np.float32) / 255.0).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def main():
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = len(ANIMS) * len(DIRS)
    sheet = np.zeros((rows * CELL, COLS * CELL, 4), dtype=np.uint8)
    row = 0
    desc = {"cell": CELL, "foot_row": FOOT_ROW, "dirs": ["down", "up", "right", "left"], "anims": {}}
    for anim, count, play in ANIMS:
        fr = frames(anim)
        info = {"row": row, "frames": count}
        info.update(play)
        desc["anims"][anim] = info
        assert len(fr) == count, anim
        for facing in DIRS:
            for k, p in enumerate(fr):
                apply_pose(p, facing)
                a = render_frame(os.path.join(TMP, "f.png"))
                sheet[row * CELL:(row + 1) * CELL, k * CELL:(k + 1) * CELL] = outline(pixelate(a))
            row += 1
        print("rendered", anim, flush=True)
    save_png(sheet, OUT)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(desc, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    shutil.rmtree(TMP, ignore_errors=True)
    print("saved", OUT, flush=True)


main()
