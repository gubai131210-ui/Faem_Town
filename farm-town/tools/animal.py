"""用 Blender 生成动物的模型和动作，渲染成带描边的像素序列帧。

用法:  blender --background --python tools/animal.py -- [配置名]
       配置在 tools/animals/<配置名>.json，默认 chicken
输出:  art/creatures/<名字>.png   32x32 一格；行 = 动画 x 方向(下/上/右/左)，列 = 帧
       art/creatures/<名字>.json  帧描述，格式和角色的一样，游戏里用 CharacterSheet 读
骨架按 body 分：
    bird       鸡、鸭：圆身子、两条腿、脖子探出去的头，走路腿交替、头一点一点
    quadruped  山羊、绵羊、水牛、狗、猫：横着的身子、四条腿、脖子顶着头，走路对角的腿一起迈，低头是吃草
    flyer      燕子、雁这些在天上飞的：身子平着，两片翅膀上下扇，只有 flap 一个动作
    insect     蜻蜓：细长身子、两对翅膀，只有 flap 一个动作
渲染、像素化、描边那一套和 tools/character.py 相同，颜色也来自 data/palette.json。
"""
import json
import math
import os
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TMP = os.path.join(HERE, "_tmp_animal_" + str(os.getpid()))

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
#           还能加：ears "long" 兔耳 / "round" 圆耳；tail "bushy" 大蓬尾 / "fan" 竖着的扇尾；horns "single" 独角；
#           tusk_size 獠牙放大几倍；stripe_w 条纹的宽度；belly 浅色肚皮；ridge 背上几片鳍；独脚时 leg_r 是那条腿的粗细
#           tusks 獠牙；mane 一圈鬃毛；back_horns 背上的角；one_leg 只有一条腿；stripes 身上几道深色的纹
#   flyer   飞着的鸟或鱼：body 身子三个半径；head 头的半径；neck / neck_up 脖子；wing 翅长；chord 翅宽；
#           tail "fork" 剪刀尾 / "fan" 扇尾 / "fin" 鱼尾；throat 喉部一块别的颜色；fish 鱼的样子；fps 扇翅快慢
#   insect  蜻蜓：length 身长；wing 翅长
#   elev    相机俯角，默认 14 度。贴着水面飞的小虫从上往下看才认得出，写大一些
#   extra_anims  另外再渲染的动作：["lie", "shake"] 趴下、抖水
QUAD = CONFIG.get("quad", {})
# 核对改动有没有影响旧素材时，把输出指到别处：环境变量 ANIMAL_OUT_DIR
OUT_DIR = os.environ.get("ANIMAL_OUT_DIR") or os.path.join(PROJ, "art", "creatures")
OUT = os.path.join(OUT_DIR, NAME + ".png")
OUT_JSON = os.path.join(OUT_DIR, NAME + ".json")

CELL = int(CONFIG.get("cell", 32))
SS = 4
PPU = 16.0
ELEV = math.radians(float(CONFIG.get("elev", 14.0)))
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
    "belly": ("x", "X"),
    "throat": ("r", "R"),
    "horn": ("k", "K"),
    "hoof": ("T", "T"),
    "ear": ("x", "X"),
    "snout": ("c", "S"),
    "tail": ("x", "X"),
    # 下面几样只有新动物用。默认颜色都是上面已经有的，旧动物的色表不会多出颜色来。
    "mane": ("x", "X"),
    "tusk": ("x", "X"),
    "tailtip": ("x", "X"),
    "stripe": ("X", "K"),
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


def slab(name, parent, pts, thick, mat):
    """平放的一片板：pts 是 XY 平面上按顺序的一圈点。翅膀、鳍用它。"""
    mesh = bpy.data.meshes.new(name)
    bm = bmesh.new()
    top = [bm.verts.new((x, y, thick * 0.5)) for x, y in pts]
    bot = [bm.verts.new((x, y, -thick * 0.5)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    n = len(pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((top[j], top[i], bot[i], bot[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(o)
    o.parent = parent
    o.data.materials.append(MATS[mat])
    return o


root = empty("Root", None)
root.scale = (SCALE, SCALE, SCALE)
_px = 1.0 / (PPU * SCALE)
# 每一项是 (支点, 左右, 这只翅膀比别的多扇多少度)
wings = []
LEG_LEN = 0.0

# 鸟：身子是个椭球，腿从身子底下伸出来，脖子从身子前上方探出去顶着头
if BODY == "bird":
    BR = BIRD.get("body", [0.24, 0.32, 0.23])      # 身子半径 x(宽) y(长) z(高)
    LEG_LEN = float(BIRD.get("leg", 0.22))
    NECK = float(BIRD.get("neck", 0.30))            # 头在身子前方多远
    NECK_UP = float(BIRD.get("neck_up", 0.26))      # 头比身子中心高多少
    HEAD_R = float(BIRD.get("head_scale", 1.0)) * 0.21
    TAIL = float(BIRD.get("tail", 0.3))
    BILL = BIRD.get("bill", "cone")
    BODY_Z = LEG_LEN + BR[2] * 0.85
    body = empty("Body", root, (0, 0, BODY_Z))
    ball("Torso", body, tuple(BR), (0, 0, 0), "body")
    if BIRD.get("belly", False):
        # 肚皮一块浅色。写数字是大小的倍数
        _belly = float(BIRD.get("belly"))
        ball("Belly", body, (BR[0] * 0.72 * _belly, BR[1] * 0.5 * _belly, BR[2] * 0.42 * _belly), (0, -BR[1] * 0.05 * _belly, -BR[2] * 0.45), "belly")
    for sx in (-1, 1):
        w = ball("Wing", body, (BR[0] * 0.42, BR[1] * 0.7, BR[2] * 0.55), (BR[0] * 0.78 * sx, 0.03, 0.02), "wing")
        w.rotation_euler = (0, d(-8 * sx), 0)
    # 尾巴：几片往后上方翘的羽毛
    # 小鸟的尾巴短、往后平伸（tail_len、tail_tilt）；不写就是鸡鸭那样翘着的
    TAIL_LEN = float(BIRD.get("tail_len", 0.26))
    TAIL_TILT = BIRD.get("tail_tilt")
    for k, (dz, dy) in enumerate(((0.0, 0.0), (0.08, -0.04), (-0.07, -0.03))):
        f = box("Tail%d" % k, body, (0.16 - 0.03 * k, TAIL_LEN * 1.25, 0.07), (0, BR[1] * 0.9 + 0.08 + dy, BR[2] * 0.45 + TAIL * 0.7 + dz), "wing" if k else "body")
        f.rotation_euler = (d(-35 - 10 * k if TAIL_TILT is None else float(TAIL_TILT)), 0, 0)
    neck_base = empty("NeckBase", body, (0, -BR[1] * 0.75, BR[2] * 0.55))
    head = empty("Head", neck_base, (0, -NECK * 0.35, NECK_UP))
    cyl("Neck", neck_base, 0.06, 0.07, max(0.05, math.hypot(NECK * 0.35, NECK_UP)), (0, -NECK * 0.17, NECK_UP * 0.5), "body",
        rot=(math.degrees(math.atan2(NECK * 0.35, NECK_UP)), 0, 0))
    ball("Skull", head, (HEAD_R, HEAD_R * 1.1, HEAD_R), (0, 0, 0), "head")
    if BILL == "flat":
        if "bill_width" in BIRD:
            width = float(BIRD["bill_width"])
            ball("Bill", head, (HEAD_R * width * 0.62, HEAD_R * 0.86, HEAD_R * 0.3),
                 (0, -HEAD_R * 1.55, -HEAD_R * 0.2), "beak")
        else:
            box("Bill", head, (HEAD_R * 1.1, HEAD_R * 1.5, HEAD_R * 0.45),
                (0, -HEAD_R * 1.5, -HEAD_R * 0.2), "beak")
    else:
        BILL_LEN = float(BIRD.get("bill_len", 1.7))
        cyl("Bill", head, HEAD_R * 0.45, 0.01, HEAD_R * BILL_LEN, (0, -HEAD_R * (0.95 + BILL_LEN * 0.5), -HEAD_R * 0.1), "beak", rot=(-90, 0, 0))
    if BIRD.get("cap", False):
        # 头顶一块别的颜色（麻雀的栗色头顶、精卫的花头）
        ball("Cap", head, (HEAD_R * 0.9, HEAD_R * 1.0, HEAD_R * 0.55), (0, HEAD_R * 0.12, HEAD_R * 0.55), "comb")
    if BIRD.get("crest", False):
        box("Crest", head, (0.05, HEAD_R * 1.3, 0.05), (0, HEAD_R * 0.9, HEAD_R * 0.75), "comb", rot=(-25, 0, 0))
    if BIRD.get("comb", False):
        for k in range(3):
            if BIRD.get("round_comb", False):
                ball("Comb%d" % k, head, (0.067, 0.071, 0.095 + 0.026 * (k == 1)),
                     (0, -0.105 + 0.085 * k, HEAD_R * 0.98), "comb")
            else:
                box("Comb%d" % k, head, (0.06, 0.09, 0.16 + 0.05 * (k == 1)), (0, -0.05 + 0.09 * k, HEAD_R * 1.25), "comb")
    if BIRD.get("wattle", False):
        ball("Wattle", head, (0.04, 0.05, 0.06), (0, -HEAD_R * 1.0, -HEAD_R * 0.9), "comb")
    # 眼睛长在头两侧，各 1 像素
    for sx in (-1, 1):
        box("Eye", head, (0.05, 2.1 * _px, 2.4 * _px), (HEAD_R * 0.95 * sx, -HEAD_R * 0.35, HEAD_R * 0.25), "eye")
    if BIRD.get("neck_ring", False):
        ball("NeckRing", neck_base, (HEAD_R * 0.81, HEAD_R * 0.81, 0.061),
             (0, -NECK * 0.36, NECK_UP - HEAD_R * 0.72), "belly")
    legs = []
    for sx in ((0,) if BIRD.get("one_leg", False) else (-1, 1)):
        hip = empty("Hip", body, (BR[0] * 0.38 * sx, 0.02, -BR[2] * 0.6))
        cyl("Shin", hip, 0.03, 0.035, LEG_LEN + BR[2] * 0.3, (0, 0, -(LEG_LEN + BR[2] * 0.3) * 0.5), "leg")
        box("Foot", hip, (0.16, 0.22, 0.04), (0, -0.07, -(LEG_LEN + BR[2] * 0.3) + 0.02), "leg")
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
    if QUAD.get("one_leg", False):
        # 夔：身子底下正中一条粗腿
        hip = empty("Hip", body, (0, 0, -BR[2] * 0.45))
        _lr = float(QUAD.get("leg_r", 0.085))
        cyl("Shin", hip, _lr, _lr + 0.015, hip_len, (0, 0, -hip_len * 0.5), "leg")
        box("Hoof", hip, (_lr * 2.35, _lr * 2.6, 0.08), (0, -0.01, -hip_len + 0.04), "hoof")
        legs.append(hip)
    else:
        LEG_R = float(QUAD.get("leg_r", 0.045))
        for sy in (-1, 1):          # 前、后
            for sx in (-1, 1):
                hip = empty("Hip", body, (BR[0] * 0.55 * sx, BR[1] * 0.62 * sy, -BR[2] * 0.45))
                cyl("Shin", hip, LEG_R, LEG_R + 0.01, hip_len, (0, 0, -hip_len * 0.5), "leg")
                box("Hoof", hip, (0.11, 0.12, 0.07), (0, -0.01, -hip_len + 0.035), "hoof")
                legs.append(hip)
    if QUAD.get("stripes", 0):
        # 背上几道深色的纹：比身子略鼓出来的薄片
        n_stripes = int(QUAD.get("stripes", 0))
        for k in range(n_stripes):
            t = (k + 0.5) / n_stripes * 1.3 - 0.65
            r = math.sqrt(max(0.05, 1.0 - t * t))
            if "stripe_w" in QUAD:
                # 写了宽度的：箍在身上的一圈带子，从侧面看是整条竖纹
                band = cyl("Stripe%d" % k, body, 1.0, 1.0, 1.0, (0, BR[1] * t, BR[2] * 0.08), "stripe", rot=(90, 0, 0))
                band.scale = (BR[0] * r * 1.05, BR[2] * r * 1.0, BR[1] * 2.0 * float(QUAD["stripe_w"]))
            else:
                ball("Stripe%d" % k, body, (BR[0] * r * 1.04, BR[1] * 0.09, BR[2] * r * 1.04), (0, BR[1] * t, BR[2] * 0.06), "stripe")
    if QUAD.get("belly", False):
        # 肚皮一块浅色
        ball("Belly", body, (BR[0] * 0.9, BR[1] * 0.85, BR[2] * 0.7), (0, 0, -BR[2] * 0.38), "belly")
    if QUAD.get("ridge", 0):
        # 背上一排往后倒的鳍（夔）
        n_ridge = int(QUAD.get("ridge", 0))
        for k in range(n_ridge):
            t = (k + 0.5) / n_ridge * 1.5 - 0.75
            cyl("Ridge%d" % k, body, BR[0] * 0.34, 0.01, BR[2] * 0.75,
                (0, BR[1] * t, BR[2] * (0.95 + 0.25 * math.sqrt(max(0.0, 1.0 - t * t)))), "mane", rot=(22, 0, 0))
    neck_base = empty("NeckBase", body, (0, -BR[1] * 0.78, BR[2] * 0.3))
    head = empty("Head", neck_base, (0, -NECK, NECK_UP))
    cyl("Neck", neck_base, BR[0] * 0.55, BR[0] * 0.4, max(0.05, math.hypot(NECK, NECK_UP)), (0, -NECK * 0.5, NECK_UP * 0.5), "body",
        rot=(math.degrees(math.atan2(NECK, NECK_UP)), 0, 0))
    ball("Skull", head, tuple(HR), (0, 0, 0), "head")
    if SNOUT > 0.0:
        ball("Snout", head, (HR[0] * 0.72, SNOUT, HR[2] * 0.62), (0, -HR[1] * 0.8 - SNOUT * 0.3, -HR[2] * 0.3), "snout")
    for sx in (-1, 1):
        box("Eye", head, (0.05, 2.1 * _px, 2.4 * _px), (HR[0] * 0.98 * sx, -HR[1] * 0.22, HR[2] * 0.32), "eye")
        if QUAD.get("front_eyes", False):
            ball("FrontEye", head, (0.034, 0.029, 0.047),
                 (HR[0] * 0.55 * sx, -HR[1] * 0.84, HR[2] * 0.27), "eye")
    EARS = QUAD.get("ears", "side")
    for sx in (-1, 1):
        if EARS == "point":
            cyl("Ear", head, HR[0] * 0.34, 0.015, HR[2] * 1.45, (HR[0] * 1.15 * sx, 0.0, HR[2] * 1.05), "ear", rot=(0, 0, -32 * sx))
        elif EARS == "flop":
            box("Ear", head, (0.06, HR[1] * 0.7, HR[2] * 1.0), (HR[0] * 1.0 * sx, HR[1] * 0.15, HR[2] * 0.1), "ear")
        elif EARS == "long":
            # 兔耳：两根竖着的长耳朵，略往后、往外张
            ball("Ear", head, (HR[0] * 0.3, HR[1] * 0.28, HR[2] * 1.25), (HR[0] * 0.48 * sx, HR[1] * 0.35, HR[2] * 1.75), "ear", rot=(-12, 10 * sx, 0))
        elif EARS == "round":
            ball("Ear", head, (HR[0] * 0.62, HR[1] * 0.2, HR[2] * 0.68), (HR[0] * 0.85 * sx, HR[1] * 0.25, HR[2] * 0.85), "ear")
        elif EARS == "none":
            pass
        else:
            box("Ear", head, (HR[0] * 0.9, 0.08, 0.06), (HR[0] * 1.25 * sx, HR[1] * 0.3, HR[2] * 0.45), "ear", rot=(0, 20 * sx, 0))
    HORNS = QUAD.get("horns", "")
    for sx in (-1, 1):
        if HORNS == "goat":
            cyl("Horn", head, 0.045, 0.01, 0.26, (HR[0] * 0.45 * sx, HR[1] * 0.45, HR[2] * 0.95), "horn", rot=(35, 0, 0))
        elif HORNS == "buffalo":
            # 一对往两边再往后弯的大角：两截
            box("HornA", head, (HR[0] * 1.5, 0.1, 0.1), (HR[0] * 1.5 * sx, HR[1] * 0.35, HR[2] * 0.7), "horn", rot=(0, -12 * sx, 0))
            # 水牛角往外伸，再朝后上方弯；侧面看是一道往后斜的弧，不是一根竖棍
            box("HornB", head, (0.1, 0.1, HR[2] * 1.3), (HR[0] * 2.3 * sx, HR[1] * 0.7, HR[2] * 0.9), "horn", rot=(-50, -10 * sx, 0))
            box("HornC", head, (0.08, 0.08, HR[2] * 0.8), (HR[0] * 2.3 * sx, HR[1] * 1.5, HR[2] * 1.5), "horn", rot=(-95, 0, 0))
    if HORNS == "single":
        cyl("Horn", head, HR[0] * 0.3, 0.01, HR[2] * 1.7, (0, -HR[1] * 0.1, HR[2] * 1.5), "horn", rot=(-12, 0, 0))
    if QUAD.get("mane", False):
        # 头后面一大圈鬃毛，从正面看是围着脸的一圈
        ball("Mane", head, (HR[0] * 1.45, HR[1] * 0.75, HR[2] * 1.4), (0, HR[1] * 0.55, HR[2] * 0.05), "mane")
        ball("ManeBack", body, (BR[0] * 0.95, BR[1] * 0.4, BR[2] * 1.05), (0, -BR[1] * 0.6, BR[2] * 0.25), "mane")
    if QUAD.get("tusks", False):
        for sx in (-1, 1):
            _ts = float(QUAD.get("tusk_size", 1.0))
            cyl("Tusk", head, 0.03 * _ts, 0.006 * _ts, HR[2] * 0.8 * _ts,
                (HR[0] * (0.55 + 0.22 * (_ts - 1.0)) * sx, -HR[1] * 0.8 - SNOUT * 0.5, -HR[2] * 0.15 + HR[2] * 0.3 * (_ts - 1.0)), "tusk",
                rot=(0, 14 * sx * (_ts - 1.0), 0))
    if QUAD.get("back_horns", False):
        for k in (-1, 1):
            cyl("BackHorn", body, 0.05, 0.008, BR[2] * 1.1, (0, BR[1] * 0.28 * k - BR[1] * 0.1, BR[2] * 1.25), "horn", rot=(18, 0, 0))
    if QUAD.get("beard", False):
        box("Beard", head, (0.05, 0.05, 0.14), (0, -HR[1] * 0.95, -HR[2] * 1.0), "tail")
    TAILK = QUAD.get("tail", "short")
    if TAILK == "bushy":
        # 大蓬尾：往后上方翘的一大团，尾尖可以是另一个颜色
        ball("Tail", body, (BR[0] * 0.85, BR[1] * 0.7, BR[2] * 0.8), (0, BR[1] * 1.45, BR[2] * 0.55), "tail", rot=(-28, 0, 0))
        ball("TailTip", body, (BR[0] * 0.62, BR[1] * 0.42, BR[2] * 0.62), (0, BR[1] * 1.95, BR[2] * 0.95), "tailtip", rot=(-28, 0, 0))
    elif TAILK == "fan":
        # 竖着的一面扇尾（耳鼠靠它飞）
        ball("Tail", body, (BR[0] * 1.15, BR[1] * 0.22, BR[2] * 1.25), (0, BR[1] * 1.15, BR[2] * 1.0), "tail", rot=(-22, 0, 0))
    elif TAILK == "long":
        box("Tail", body, (0.05, 0.05, BR[2] * 1.5), (0, BR[1] * 1.0, -BR[2] * 0.3), "tail")
        box("Tuft", body, (0.09, 0.07, 0.12), (0, BR[1] * 1.0, -BR[2] * 1.05), "hoof")
    elif TAILK == "up":
        cyl("Tail", body, 0.045, 0.03, BR[1] * 1.0, (0, BR[1] * 1.15, BR[2] * 0.7), "tail", rot=(-25, 0, 0))
    else:
        ball("Tail", body, (0.07, 0.09, 0.07), (0, BR[1] * 1.0, BR[2] * 0.35), "tail")
elif BODY == "flyer":
    # 飞着的鸟（也拿来做会飞的鱼）。翅膀是平伸在身子两侧的两片板，绕着身子的前后轴上下扇：
    # 侧面看，举起来是身子上方的一片三角，压下去在身子下方；正面、背面看是张开的一对。
    FLY = CONFIG.get("flyer", {})
    BR = FLY.get("body", [0.07, 0.17, 0.065])
    NECK = float(FLY.get("neck", 0.0))
    NECK_UP = float(FLY.get("neck_up", 0.0))
    HEAD_R = float(FLY.get("head", 0.07))
    WING_L = float(FLY.get("wing", 0.36))
    CHORD = float(FLY.get("chord", 0.15))
    SWEEP = float(FLY.get("sweep", 0.5)) * CHORD
    TAILK = FLY.get("tail", "fork")
    FISH = bool(FLY.get("fish", False))
    BODY_Z = float(FLY.get("fly_z", 0.34))
    body = empty("Body", root, (0, 0, BODY_Z))
    ball("Torso", body, tuple(BR), (0, 0, 0), "body")
    if FLY.get("belly", True):
        ball("Belly", body, (BR[0] * 0.93, BR[1] * 0.86, BR[2] * 0.9), (0, -BR[1] * 0.06, -BR[2] * 0.3), "belly")
    neck_base = empty("NeckBase", body, (0, -BR[1] * 0.72, BR[2] * 0.12))
    head = empty("Head", neck_base, (0, -NECK - HEAD_R * 0.55, NECK_UP))
    if NECK > 0.03:
        cyl("Neck", neck_base, BR[0] * 0.6, HEAD_R * 0.75, math.hypot(NECK, NECK_UP) + HEAD_R * 0.5,
            (0, -NECK * 0.5, NECK_UP * 0.5), "throat" if FLY.get("dark_neck", False) else "body",
            rot=(math.degrees(math.atan2(NECK, max(NECK_UP, 0.001))), 0, 0))
    ball("Skull", head, (HEAD_R, HEAD_R * 1.1, HEAD_R), (0, 0, 0), "head")
    if FISH:
        ball("Mouth", head, (HEAD_R * 0.5, HEAD_R * 0.5, HEAD_R * 0.45), (0, -HEAD_R * 0.9, -HEAD_R * 0.15), "beak")
    else:
        BILL_LEN = float(FLY.get("bill_len", 1.2))
        cyl("Bill", head, HEAD_R * 0.42, 0.008, HEAD_R * BILL_LEN, (0, -HEAD_R * (0.85 + BILL_LEN * 0.5), -HEAD_R * 0.1), "beak", rot=(-90, 0, 0))
    if FLY.get("throat", False):
        ball("Throat", head, (HEAD_R * 0.8, HEAD_R * 0.75, HEAD_R * 0.6), (0, -HEAD_R * 0.15, -HEAD_R * 0.6), "throat")
    if FLY.get("cap", False):
        _cap = float(FLY.get("cap"))
        ball("Cap", head, (HEAD_R * 0.9 * _cap, HEAD_R * 1.0 * _cap, HEAD_R * 0.55 * _cap), (0, HEAD_R * 0.1, HEAD_R * 0.55), "comb")
    if FLY.get("feet", False):
        # 收在肚子底下的一双脚（精卫是红脚）
        for sx in (-1, 1):
            ball("Foot", body, (0.03, 0.06, 0.035), (BR[0] * 0.45 * sx, BR[1] * 0.35, -BR[2] * 1.05), "leg")
    for sx in (-1, 1):
        box("Eye", head, (0.05, 2.1 * _px, 2.4 * _px), (HEAD_R * 0.93 * sx, -HEAD_R * 0.3, HEAD_R * 0.15), "eye")
    TAIL_L = float(FLY.get("tail_len", 0.2))
    if TAILK == "fork":
        # 剪刀尾：两根往后张开的细羽
        for sx in (-1, 1):
            slab("Fork", body, [(0.0, 0.0), (0.035 * sx, 0.0), (0.105 * sx, TAIL_L), (0.07 * sx, TAIL_L)], 0.035, "wing").location = (0, BR[1] * 0.78, BR[2] * 0.1)
    elif TAILK == "fin":
        # 鱼尾：竖着的一片，上下两叉
        for sz in (-1, 1):
            fin = box("TailFin", body, (0.035, TAIL_L, BR[2] * 0.55), (0, BR[1] * 0.95 + TAIL_L * 0.4, BR[2] * 0.42 * sz), "tail")
            fin.rotation_euler = (d(-32 * sz), 0, 0)
        box("Dorsal", body, (0.03, BR[1] * 0.7, BR[2] * 0.5), (0, BR[1] * 0.05, BR[2] * 1.0), "tail", rot=(-12, 0, 0))
    else:
        slab("Tail", body, [(-0.04, 0.0), (0.04, 0.0), (0.075, TAIL_L), (-0.075, TAIL_L)], 0.035, "wing").location = (0, BR[1] * 0.78, BR[2] * 0.1)
    if FLY.get("stripes", 0):
        n_stripes = int(FLY.get("stripes", 0))
        for k in range(n_stripes):
            t = (k + 0.5) / n_stripes * 1.1 - 0.4
            r = math.sqrt(max(0.05, 1.0 - t * t))
            ball("Stripe%d" % k, body, (BR[0] * r * 1.05, BR[1] * float(FLY.get("stripe_w", 0.09)), BR[2] * r * 1.05), (0, BR[1] * t, BR[2] * 0.08), "stripe")
    legs = []
    WING_T = float(FLY.get("wing_thick", 0.04))
    for sx in (-1, 1):
        pivot = empty("WingPivot", body, (BR[0] * 0.55 * sx, -BR[1] * float(FLY.get("wing_at", 0.12)), BR[2] * 0.35))
        # 翅膀的平面形状：根部宽，往外收窄，翅尖往后掠
        slab("Wing", pivot, [
            (0.0, -CHORD * 0.5),
            (WING_L * 0.5 * sx, -CHORD * 0.42 + SWEEP * 0.25),
            (WING_L * sx, SWEEP),
            (WING_L * 0.62 * sx, CHORD * 0.3 + SWEEP * 0.55),
            (0.0, CHORD * 0.5),
        ], WING_T, "wing")
        wings.append((pivot, sx, 0.0))
elif BODY == "insect":
    # 蜻蜓：一根细长的身子，前后两对平伸的翅膀。相机俯角要写大（elev），从上往下看才是个十字。
    INS = CONFIG.get("insect", {})
    BODY_L = float(INS.get("length", 0.42))
    WING_L = float(INS.get("wing", 0.2))
    WING_W = float(INS.get("wing_w", 0.07))
    BODY_Z = float(INS.get("fly_z", 0.3))
    body = empty("Body", root, (0, 0, BODY_Z))
    box("Abdomen", body, (0.045, BODY_L * 0.66, 0.045), (0, BODY_L * 0.17, 0), "body")
    box("Thorax", body, (0.09, BODY_L * 0.2, 0.08), (0, -BODY_L * 0.27, 0.005), "body")
    neck_base = empty("NeckBase", body, (0, -BODY_L * 0.38, 0.0))
    head = empty("Head", neck_base, (0, -0.045, 0.0))
    ball("Skull", head, (0.06, 0.05, 0.05), (0, 0, 0), "head")
    legs = []
    for k, along in enumerate((-BODY_L * 0.32, -BODY_L * 0.2)):
        for sx in (-1, 1):
            pivot = empty("WingPivot", body, (0.03 * sx, along, 0.03))
            span = WING_L * (1.0 if k == 0 else 0.9)
            back = -WING_W * 0.4 if k == 0 else WING_W * 0.9
            slab("Wing", pivot, [
                (0.0, -WING_W * 0.3 + back * 0.2),
                (span * sx, -WING_W * 0.5 + back),
                (span * sx, WING_W * 0.5 + back),
                (0.0, WING_W * 0.3 + back * 0.2),
            ], 0.03, "wing")
            # 后一对翅膀和前一对错开半拍
            wings.append((pivot, sx, 0.0 if k == 0 else -1.0))
else:
    raise ValueError("unknown body " + BODY)


if BODY == "flyer":
    # 举起、放平、压下、放平，四帧一个来回
    ANIMS = [("flap", 4, {"loop": True, "fps": float(CONFIG.get("flyer", {}).get("fps", 9.0))})]
elif BODY == "insect":
    ANIMS = [("flap", 2, {"loop": True, "fps": 14.0})]
# 趴下、抖水是后加的，排在原来三个动作后面，原来的行号不变
_EXTRA = {
    "lie": ("lie", 2, {"loop": True, "fps": 1.2}),
    "shake": ("shake", 4, {"loop": True, "fps": 10.0}),
}
for _name in CONFIG.get("extra_anims", []):
    ANIMS.append(_EXTRA[_name])


# ------------------------------------------------------------------ 姿势

BASE = dict(bob=0.0, lean=0.0, head=0.0, neck=0.0, leg=(0.0, 0.0), lift=(0, 0), tilt=0.0, wing=0.0,
            # 整个身子绕前后轴歪多少度（抖水）
            roll=0.0,
            # 1 是趴到地上：身子落下去，腿收起来
            lie=0.0)


def pose(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


def frames(anim):
    if anim == "idle":
        return [pose(), pose(bob=-PIX, head=6, neck=-3)]
    if anim == "peck" and BODY == "quadruped":
        return [
            pose(neck=58, head=22),
            pose(neck=66, head=30, bob=-PIX),
        ]
    if anim == "walk" and BODY == "quadruped":
        # 正面看，往前收的那对腿提起两像素，才分得出是哪只脚离了地
        return [
            pose(leg=(30, -30), head=-5),
            pose(leg=(0, -6), head=3, lift=(2, 0)),
            pose(leg=(-30, 30), head=-5),
            pose(leg=(-6, 0), head=3, lift=(0, 2)),
        ]
    if anim == "walk":
        return [
            pose(leg=(36, -36), head=-8, neck=5),
            pose(leg=(0, -8), head=6, neck=-4, lift=(2, 0)),
            pose(leg=(-36, 36), head=-8, neck=5),
            pose(leg=(-8, 0), head=6, neck=-4, lift=(0, 2)),
        ]
    if anim == "peck":
        return [
            pose(lean=14, head=35, neck=20, bob=-PIX),
            pose(lean=28, head=55, neck=34, bob=-2 * PIX),
        ]
    if anim == "flap":
        if BODY == "insect":
            # 翅膀只是微微上下颤
            return [pose(wing=16), pose(wing=-12)]
        # 翅膀举起、放平、压下、放平；压下去的那一下身子往上顶一像素
        up = float(CONFIG.get("flyer", {}).get("flap_up", 52.0))
        down = float(CONFIG.get("flyer", {}).get("flap_down", -34.0))
        mid = (up + down) * 0.5
        return [pose(wing=up), pose(wing=mid), pose(wing=down, bob=PIX), pose(wing=mid)]
    if anim == "lie":
        # 趴着：头搁低一点，第二帧随着喘气起伏一像素
        if BODY == "quadruped":
            return [pose(lie=1.0, neck=26, head=10), pose(lie=1.0, neck=28, head=12, bob=-PIX)]
        return [pose(lie=1.0, neck=8, head=6), pose(lie=1.0, neck=10, head=8, bob=-PIX)]
    if anim == "shake":
        # 抖水：身子左右来回拧，头跟着甩
        return [
            pose(roll=16, tilt=14),
            pose(roll=-16, tilt=-14),
            pose(roll=11, tilt=10),
            pose(roll=-11, tilt=-10),
        ]
    raise ValueError(anim)


_LEG_BASE = []


def apply_pose(p, facing_deg):
    lie = float(p.get("lie", 0.0))
    z = round((p["bob"] - lie * LEG_LEN * 0.92) * SCALE / PIX) * PIX / SCALE
    root.rotation_euler = (0, 0, d(facing_deg))
    body.location = (0, 0, BODY_Z + z)
    roll = float(p.get("roll", 0.0))
    body.rotation_euler = (d(p["lean"]), d(roll), 0)
    neck_base.rotation_euler = (d(p["neck"]), 0, 0)
    head.rotation_euler = (d(p["head"]), 0, d(p["tilt"]))
    if not _LEG_BASE:
        _LEG_BASE.extend(h.location.copy() for h in legs)
    sideways = abs(abs(facing_deg) - 90.0) < 1.0
    for i, hip in enumerate(legs):
        # 四条腿的顺序是前左、前右、后左、后右：对角的一起迈
        g = i if len(legs) == 2 else (0, 1, 1, 0)[i]
        a = p["leg"][g]
        # 正面背面看不出前后摆，往前收的那条腿整条提起来，才看得出哪只脚离了地
        up = 0 if sideways else p["lift"][g]
        hip.location = _LEG_BASE[i] + Vector((0.0, 0.0, up * PIX / SCALE))
        # 身子歪的时候腿仍然竖着；趴下时腿缩到身子底下
        hip.rotation_euler = (d(a) - d(p["lean"]), -d(roll), 0)
        hip.scale = (1.0, 1.0, 1.0 - 0.85 * lie)
    ang = float(p.get("wing", 0.0))
    for pivot, sx, lag in wings:
        # 右边的翅膀绕前后轴负转是抬起，左边相反；蜻蜓的后一对和前一对反着颤
        wing_ang = ang if lag == 0.0 else -ang * 0.7
        pivot.rotation_euler = (0.0, -d(wing_ang) * sx, 0.0)
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
