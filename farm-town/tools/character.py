"""用 Blender 生成人形角色的 3D 模型和动作，渲染成带描边的像素序列帧。

用法:  blender --background --python tools/character.py -- [配置名]
       配置在 tools/characters/<配置名>.json，默认 farmer
       配置里能写的东西见下面 CONFIG 的说明
输出:  art/characters/<名字>.png   48x48 一格；行 = 动画 x 方向(下/上/右/左)，列 = 帧
       art/characters/<名字>.json  帧描述：每个动画在第几行、几帧、动作时间表
       tools/<名字>.blend          模型文件，可以用 Blender 打开查看
颜色全部来自 data/palette.json，和游戏里代码画的素材是同一套。
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
from bpy_extras.object_utils import world_to_camera_view

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TMP = os.path.join(HERE, "_tmp_" + str(os.getpid()))

_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CONFIG_NAME = _args[0] if _args else "farmer"
with open(os.path.join(HERE, "characters", CONFIG_NAME + ".json"), encoding="utf-8") as _f:
    CONFIG = json.load(_f)
with open(os.path.join(PROJ, "data", "palette.json"), encoding="utf-8") as _f:
    LETTERS = json.load(_f)
NAME = CONFIG.get("name", CONFIG_NAME)
# 配置项（都可以不写）：
#   anims   只渲染这些动画，居民只要 ["idle", "walk", "sit"]
#   scale   个头，1 是成年人，小孩 0.8 左右
#   bulk    身板的宽度，1 是普通
#   stoop   驼背的角度
#   hat     true 或 "straw" 草帽；"headband" 头巾；"cone" 斗笠；"beret" 软帽；"cap" 瓜皮帽；false 不戴
#   pack    背上背的东西："box" 木箱；"basket" 背篓；不写就不背
#   hair    "short" 短发；"bun" 发髻；"pigtails" 两个小辫；"long" 披肩；"ponytail" 马尾；"bald" 光头
#   beard   true 留胡子
#   outfit  "overalls" 背带裤；"tunic" 上衣加裤子；"apron" 再系一条围裙；"robe" 长袍
#   parts   各部位的颜色：写 data/palette.json 里 cloth 的名字，或者 [亮, 暗] 两个单字符键
#   blend   true 时另存一份 .blend 模型文件
# 下面几样是给人形的异兽用的：
#   hair    另有 "shaggy" 一头乱毛
#   hat     另有 "official" 两边带翅的乌纱帽
#   beard   写 "long" 是垂到胸口的长须
#   ears    "ape" 头两侧一对圆耳朵，用 ear 这个部位的颜色
#   muzzle  true 脸下半截鼓出一块嘴，用 band 的颜色
#   legs    "fishtail" 没有腿，腰以下是一条鱼尾（尾巴用 blue 的颜色，尾鳍用 band 的颜色）
#   parts   颜色也可以直接写 ["#rrggbb", "#rrggbb"]
BODY_SCALE = float(CONFIG.get("scale", 1.0))
BULK = float(CONFIG.get("bulk", 1.0))
STOOP = float(CONFIG.get("stoop", 0.0))
HAIR = CONFIG.get("hair", "short")
OUTFIT = CONFIG.get("outfit", "overalls")
BEARD = bool(CONFIG.get("beard", False))
OUT_DIR = os.path.join(PROJ, "art", "characters")
OUT = os.path.join(OUT_DIR, NAME + ".png")
OUT_JSON = os.path.join(OUT_DIR, NAME + ".json")

CELL = 48          # 每帧像素
SS = 4             # 超采样倍数：先渲染 192x192，再按众数缩小
PPU = 16.0         # 每个 Blender 单位对应的像素
ELEV = math.radians(14.0)   # 相机俯角
FOOT_ROW = 40      # 脚底所在的像素行，与手绘版一致
PIX = 1.0 / PPU / math.cos(ELEV)   # 屏幕上 1 像素对应的世界高度
HIP = 0.36
THRESH = 0.2       # 明暗分界
SCALE = 1.2 * BODY_SCALE   # 整体放大，让角色和手绘版差不多高

# 动画表：帧数，以及游戏里怎么播放。seq 是 [帧, 秒] 的时间表，strike 是生效的那一步。
ANIMS = [
    ("idle", 4, {"loop": True, "fps": 3.0}),
    ("walk", 8, {"loop": True, "step_frames": [0, 4]}),
    # 坐在长凳上：只有居民用，一帧
    ("sit", 1, {"loop": True, "fps": 1.0}),
    ("hoe", 6, {"seq": [[0, 0.07], [1, 0.11], [2, 0.04], [3, 0.09], [4, 0.08], [5, 0.11]], "strike": 3}),
    ("water", 4, {"seq": [[0, 0.09], [1, 0.09], [2, 0.14], [3, 0.12], [2, 0.14], [0, 0.08]], "strike": 2}),
    ("reach", 3, {"seq": [[0, 0.06], [1, 0.06], [2, 0.15], [1, 0.06], [0, 0.06]], "strike": 2}),
    # 甩竿：举竿、往后扬两步、甩出去（strike，线落水）、前倾跟随、收势
    ("cast", 6, {"seq": [[0, 0.1], [1, 0.08], [2, 0.12], [3, 0.08], [4, 0.1], [5, 0.12]], "strike": 3}),
    # 持竿等鱼：两帧轻轻晃，循环
    ("fish", 2, {"loop": True, "fps": 1.5}),
    # 钩住那一下：猛地抬竿
    ("hook", 1, {"loop": True, "fps": 1.0}),
    # 收线：两只手交替摇轮
    ("reel", 3, {"loop": True, "fps": 7.0}),
    # 鱼挣扎时绷着竿后仰
    ("strain", 2, {"loop": True, "fps": 4.0}),
    # 双手把鱼举过头顶
    ("trophy", 1, {"loop": True, "fps": 1.0}),
    # 井里用武器：镰刀横扫（从一侧扫到另一侧）、短剑直刺、锤往下砸（姿势和挥锄一样，慢一点）
    ("slash", 4, {"seq": [[0, 0.06], [1, 0.04], [2, 0.07], [3, 0.07]], "strike": 1}),
    ("stab", 3, {"seq": [[0, 0.05], [1, 0.07], [2, 0.06]], "strike": 1}),
    ("smash", 6, {"seq": [[0, 0.08], [1, 0.13], [2, 0.04], [3, 0.1], [4, 0.09], [5, 0.12]], "strike": 3}),
    # 翻滚：缩成一团往前滚一圈，四帧；游戏里按翻滚的时长摊开播
    ("roll", 4, {"loop": True, "fps": 13.0}),
    # 下雨打伞走：走路的腿 + 一只手举伞（居民共用）
    ("umbrella_walk", 8, {"loop": True, "step_frames": [0, 4]}),
    # 扇扇子：一手举扇轻摇，四帧循环
    ("fan", 4, {"loop": True, "fps": 3.0}),
    # 搓手：两只手在胸前搓，四帧循环
    ("rub", 4, {"loop": True, "fps": 3.0}),
    # 扫地：双手握帚左右扫，六帧循环
    ("sweep", 6, {"loop": True, "fps": 4.0}),
    # 蹲下：蹲在地上，两帧轻轻起伏
    ("squat", 2, {"loop": True, "fps": 1.5}),
    # 踩水洼：原地高抬腿踩，四帧循环
    ("stomp", 4, {"loop": True, "fps": 5.0}),
    # 画画：一手执笔在画布上点，四帧循环
    ("paint", 4, {"loop": True, "fps": 3.0}),
    # 做菜：一手端锅、铲子绕着圈炒，八帧转一整圈（只有主角用；排在最后，前面的行号不变）
    ("cook", 8, {"loop": True, "fps": 10.0}),
]
if "anims" in CONFIG:
    ANIMS = [a for a in ANIMS if a[0] in CONFIG["anims"]]
# 试渲染：blender ... -- farmer idle walk hoe，并设 CHAR_OUT 写到别的文件，不覆盖正式序列帧
_ONLY = _args[1:]
if _ONLY:
    ANIMS = [a for a in ANIMS if a[0] in _ONLY]
if os.environ.get("CHAR_OUT"):
    OUT = os.environ["CHAR_OUT"]
    OUT_JSON = os.path.splitext(OUT)[0] + ".json"
DIRS = [0.0, 180.0, 90.0, -90.0]   # 下 上 右 左
COLS = 8

# 部位: (亮面, 暗面)，写的是 data/palette.json 里的键；配置文件可以覆盖
PARTS = {
    "skin": ("s", "S"),
    "hair": ("h", "H"),
    "shirt": ("b", "B"),
    "blue": ("p", "P"),
    "boot": ("t", "T"),
    "hat": ("y", "Y"),
    "band": ("r", "R"),
    "wood": ("w", "W"),
    "metal": ("m", "M"),
    "can": ("g", "G"),
    "eye": ("e", "e"),
    "apron": ("b", "B"),
    "ear": ("s", "S"),
    # 锅里的菜：暖红，读作食物而不是草帽的黄
    "food": ("r", "R"),
}
PAL = {part: (LETTERS[a], LETTERS[b]) for part, (a, b) in PARTS.items()}
for _part, _keys in CONFIG.get("parts", {}).items():
    if isinstance(_keys, str):
        PAL[_part] = tuple(LETTERS["cloth"][_keys])
    elif _keys[0].startswith("#"):
        PAL[_part] = (_keys[0][1:], _keys[1][1:])
    else:
        PAL[_part] = (LETTERS[_keys[0]], LETTERS[_keys[1]])
HAT = CONFIG.get("hat", True)
if HAT is True:
    HAT = "straw"


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


def lighten(h, t):
    return "".join("%02x" % int(round(c + (255 - c) * t)) for c in hex_rgb(h))


# 头发多一档高光，头顶受光的地方亮一块，不然是一整片平的颜色
HAIR_HI = lighten(PAL["hair"][0], 0.26)
PALETTE = [hex_rgb(HAIR_HI)]
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
# 让世界原点（脚底）落在第 FOOT_ROW 行
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
    if name == "hair":
        hi = ramp.color_ramp.elements.new(0.95)
        hi.color = hex_lin(HAIR_HI)
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


def box(name, parent, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = _finish(name, parent, loc, mat, False)
    o.scale = size
    return o


def ball(name, parent, radii, loc, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0)
    o = _finish(name, parent, loc, mat, True)
    o.scale = radii
    return o


def cyl(name, parent, r1, r2, depth, loc, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r2, depth=depth)
    return _finish(name, parent, loc, mat, True)


root = empty("Root", None)
root.scale = (SCALE, SCALE, SCALE)
hips = empty("Hips", root, (0, 0, HIP))
# torso 只负责前倾；身体的扭转放在 chest 上，头不跟着扭，
# 这样走路时脸在屏幕上的位置不变，眼睛不会因为亚像素移动而闪烁。
torso = empty("Torso", hips)
chest = empty("ChestTwist", torso)

chest.scale = (BULK, 1.0 + (BULK - 1.0) * 0.5, 1.0)
box("Pelvis", chest, (0.50, 0.32, 0.20), (0, 0, 0.08), "blue" if OUTFIT == "overalls" else "shirt")
box("Chest", chest, (0.50, 0.32, 0.22), (0, 0, 0.28), "shirt")
if OUTFIT == "overalls":
    box("Bib", chest, (0.26, 0.05, 0.17), (0, -0.165, 0.25), "blue")
    for sx in (-1, 1):
        box("Strap", chest, (0.07, 0.35, 0.23), (0.115 * sx, 0, 0.285), "blue")
elif OUTFIT == "apron":
    box("ApronTop", chest, (0.30, 0.05, 0.20), (0, -0.165, 0.24), "apron")
    box("ApronSkirt", chest, (0.44, 0.05, 0.30), (0, -0.175, 0.0), "apron")
    box("ApronTie", chest, (0.52, 0.34, 0.05), (0, 0, 0.15), "apron")
elif OUTFIT == "robe":
    # 长袍的下摆挂在胯上，不跟着腿摆，走路时只露出鞋尖
    skirt = cyl("Skirt", hips, 0.34, 0.26, 0.36, (0, 0, -0.14), "shirt")
    skirt.scale = (1.0, 0.78, 1.0)
    box("Sash", chest, (0.52, 0.34, 0.06), (0, 0, 0.14), "band")

detail = CONFIG.get("costume_detail", "")
if detail == "field":
    box("PinaforePocket", chest, (0.16, 0.039, 0.084), (0, -0.201, 0.225), "apron")
    box("Scarf", chest, (0.27, 0.35, 0.07), (0, 0, 0.364), "band")
elif detail == "herbalist":
    lapel = box("CrossCollar", chest, (0.085, 0.045, 0.28), (0.045, -0.171, 0.256), "band")
    lapel.rotation_euler.y = d(-33)
    box("MedicinePouch", hips, (0.16, 0.18, 0.16), (0.26, -0.073, 0.022), "wood")
elif detail == "child":
    strap = box("SatchelStrap", chest, (0.074, 0.04, 0.31), (0, -0.168, 0.24), "band")
    strap.rotation_euler.y = d(35)
    box("Satchel", hips, (0.19, 0.22, 0.19), (0.235, -0.091, 0.065), "wood")
elif detail == "cook":
    box("ApronPocket", chest, (0.18, 0.035, 0.105), (-0.1, -0.204, 0.018), "band")
    for sx in (-1, 1):
        tie = box("ApronRibbon", chest, (0.095, 0.05, 0.21), (0.08 * sx, 0.189, 0.058), "apron")
        tie.rotation_euler.y = d(23 * sx)

head = empty("Head", torso, (0, 0, 0.40))
ball("Skull", head, (0.37, 0.34, 0.30), (0, 0, 0.27), "skin")
if HAIR != "bald":
    hair = ball("Hair", head, (0.395, 0.365, 0.32), (0, 0.02, 0.285), "hair")
    bm = bmesh.new()
    bm.from_mesh(hair.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces
                               if f.calc_center_median().y < 0.0 and f.calc_center_median().z < 0.35],
                     context="FACES")
    bm.to_mesh(hair.data)
    bm.free()
if HAIR == "bun":
    # 髻盘在头顶偏后，正面从额头上方冒出一截，侧面是脑后一个圆包
    ball("Bun", head, (0.17, 0.16, 0.15), (0, 0.2, 0.56), "hair")
elif HAIR == "pigtails":
    # 两根小辫垂在耳朵下面，比脸宽出一截，正面才看得出是辫子
    for sx in (-1, 1):
        ball("Pigtail", head, (0.12, 0.12, 0.22), (0.43 * sx, 0.1, 0.06), "hair")
        ball("PigtailTie", head, (0.08, 0.08, 0.05), (0.41 * sx, 0.1, 0.27), "band")
elif HAIR == "long":
    ball("HairBack", head, (0.37, 0.2, 0.36), (0, 0.2, 0.1), "hair")
elif HAIR == "ponytail":
    ball("TailTie", head, (0.08, 0.08, 0.07), (0, 0.36, 0.36), "band")
    ball("Tail", head, (0.1, 0.11, 0.24), (0, 0.42, 0.16), "hair")
if HAIR == "shaggy":
    # 一头乱毛：脑后一大团，两鬓各一撮，头顶翘一撮
    ball("ShagBack", head, (0.42, 0.26, 0.4), (0, 0.2, 0.2), "hair")
    for sx in (-1, 1):
        ball("ShagSide", head, (0.13, 0.2, 0.24), (0.36 * sx, 0.02, 0.12), "hair")
    ball("ShagTop", head, (0.2, 0.2, 0.14), (0, 0.02, 0.6), "hair")
if BEARD:
    # 胡子贴在下半张脸上，不垂到胸口
    ball("Beard", head, (0.25, 0.1, 0.085), (0, -0.215, 0.07), "hair")
if CONFIG.get("beard") == "long":
    ball("BeardLong", head, (0.16, 0.08, 0.2), (0, -0.23, -0.07), "hair")
if CONFIG.get("ears") == "ape":
    for sx in (-1, 1):
        ball("ApeEar", head, (0.09, 0.07, 0.12), (0.4 * sx, 0.0, 0.3), "ear")
if CONFIG.get("muzzle", False):
    ball("Muzzle", head, (0.2, 0.11, 0.11), (0, -0.27, 0.11), "band")
# 眼睛在屏幕上是 1 像素宽、2 像素高的一竖，两眼之间空 4 像素；按像素算位置，个头不同的人也对得齐
_px = 1.0 / (PPU * SCALE)


def _skull(u, r_other, r_self):
    """头是个椭球：眼睛那一圈上，另一个方向离中心 u 时，这个方向的表面离中心多远。"""
    return r_self * math.sqrt(max(0.05, 1.0 - (u / r_other) ** 2 - 0.0225))


_front = _skull(2.5 * _px, 0.37, 0.34)
_side_px = math.floor(0.336 / _px - 1.5) + 0.5
# 驼背的人头往前探出一截，侧脸的眼睛往回挪同样多，在屏幕上还是落在整像素上
_stoop_shift = 0.40 * math.sin(d(STOOP)) + 0.225 * math.sin(d(STOOP * 0.3))
_side_y = _side_px * _px - _stoop_shift
_side = _skull(_side_y, 0.34, 0.37) + 0.012
# 正面和侧面各有一套眼睛，渲染哪个方向就只显示哪一套（见 apply_pose），
# 不然另一套露出一条边也会被像素化成一整格黑
front_eyes = empty("FrontEyes", head)
side_eyes = empty("SideEyes", head)
for sx in (-1, 1):
    box("Eye", front_eyes, (1.1 * _px, 0.06, 2.2 * _px), (2.5 * _px * sx, -(_front - 0.01), 0.225), "eye")
    box("SideEye", side_eyes, (0.06, 0.95 * _px, 2.2 * _px), (_side * sx, -_side_y, 0.225), "eye")
hat = empty("Hat", head, (0, 0.03, 0.50))
hat.rotation_euler = (d(-13), 0, 0)
if HAT == "straw":
    if detail == "field":
        hat.location.z += 0.025
        hat.rotation_euler.x = d(-4)
    brim = 0.425 if detail == "field" else 0.45
    cyl("Brim", hat, brim, brim, 0.05, (0, 0, 0.0), "hat")
    cyl("Band", hat, 0.315, 0.31, 0.07, (0, 0, 0.06), "band")
    cyl("Crown", hat, 0.31, 0.25, 0.17, (0, 0, 0.18), "hat")
elif HAT == "cone":
    cyl("Cone", hat, 0.5, 0.04, 0.26, (0, 0, 0.1), "hat")
elif HAT == "beret":
    beret = ball("Beret", hat, (0.38, 0.36, 0.13), (0.06, 0, 0.06), "hat")
    beret.rotation_euler = (0, d(12), 0)
    ball("BeretStem", hat, (0.04, 0.04, 0.05), (0.08, 0, 0.2), "hat")
elif HAT == "headband":
    hb = cyl("Headband", head, 0.375, 0.375, 0.07, (0, 0.01, 0.45), "band")
    hb.scale = (1.0, 0.93, 1.0)
elif HAT == "official":
    # 乌纱帽：前低后高两截，后面横着一对帽翅
    cyl("OfficialRim", hat, 0.34, 0.33, 0.12, (0, 0, 0.02), "hat")
    box("OfficialBack", hat, (0.44, 0.26, 0.2), (0, 0.14, 0.16), "hat")
    for sx in (-1, 1):
        box("OfficialWing", hat, (0.3, 0.05, 0.09), (0.44 * sx, 0.2, 0.1), "hat")
elif HAT == "cap":
    # 瓜皮帽：扣在头顶的半个圆，顶上一粒结子
    cyl("CapRim", hat, 0.33, 0.33, 0.06, (0, 0, -0.02), "hat")
    ball("Cap", hat, (0.33, 0.33, 0.16), (0, 0, 0.0), "hat")
    ball("CapKnob", hat, (0.05, 0.05, 0.05), (0, 0, 0.17), "band")

# 背上的东西："box" 货郎的木箱；"basket" 山里人的背篓。用 wood 这个部位的颜色
PACK = CONFIG.get("pack", "")
if PACK == "box":
    box("PackBox", chest, (0.44, 0.2, 0.42), (0, 0.27, 0.24), "wood")
    box("PackLid", chest, (0.48, 0.24, 0.05), (0, 0.27, 0.47), "band")
    for sx in (-1, 1):
        box("PackStrap", chest, (0.06, 0.36, 0.05), (0.17 * sx, 0.02, 0.4), "band")
    # 箱子上插一根杆，杆头一面拨浪鼓，高过帽檐，从正面也看得见
    cyl("PackPole", chest, 0.028, 0.028, 0.8, (0.33, 0.3, 0.86), "wood")
    cyl("PackDrum", chest, 0.11, 0.11, 0.07, (0.33, 0.3, 1.26), "band").rotation_euler = (d(90), 0, 0)
    cyl("PackDrumFace", chest, 0.07, 0.07, 0.085, (0.33, 0.3, 1.26), "hat").rotation_euler = (d(90), 0, 0)
elif PACK == "basket":
    cyl("PackBasket", chest, 0.21, 0.15, 0.4, (0, 0.3, 0.26), "wood")
    cyl("PackRim", chest, 0.225, 0.225, 0.05, (0, 0.3, 0.47), "band")
    for sx in (-1, 1):
        box("PackStrap", chest, (0.06, 0.36, 0.05), (0.17 * sx, 0.02, 0.4), "band")

legs = []
arms = []
FISHTAIL = CONFIG.get("legs") == "fishtail"
if FISHTAIL:
    # 鲛人：腰以下一条鱼尾，尾尖往后拐，末端一对尾鳍
    _t = cyl("FishTail", hips, 0.27, 0.13, 0.3, (0, 0.0, -0.12), "blue")
    _t.scale = (1.0, 0.8, 1.0)
    cyl("FishTailEnd", hips, 0.13, 0.07, 0.16, (0, 0.05, -0.27), "blue").rotation_euler = (d(-40), 0, 0)
    for sx in (-1, 1):
        ball("TailFin", hips, (0.21, 0.12, 0.075), (0.2 * sx, 0.12, -0.3), "band").rotation_euler = (0, d(-18 * sx), d(-25 * sx))
for sx in (1, -1):
    hip = empty("LegPivot", hips, (0.13 * sx, 0, 0))
    knee = empty("Knee", hip, (0, 0, -0.17))
    if not FISHTAIL:
        # 两条腿之间留一条缝，正面才看得出是两条腿、哪只脚抬了起来
        box("Thigh", hip, (0.15, 0.20, 0.20), (0.015 * sx, 0, -0.08), "blue")
        box("Shin", knee, (0.14, 0.19, 0.10), (0.015 * sx, 0, -0.03), "blue")
        box("Boot", knee, (0.18, 0.30, 0.12), (0.02 * sx, -0.035, -0.13), "boot")
    legs.append((hip, knee))

    sh = empty("ArmPivot", chest, (0.315 * sx, 0, 0.34))
    box("UpperArm", sh, (0.13, 0.14, 0.19), (0, 0, -0.075), "shirt")
    elbow = empty("Elbow", sh, (0, 0, -0.17))
    box("ForeArm", elbow, (0.12, 0.13, 0.12), (0, 0, -0.05), "shirt")
    ball("Hand", elbow, (0.075, 0.075, 0.075), (0, 0, -0.14), "skin")
    hand = empty("HandTip", elbow, (0, 0, -0.14))
    arms.append((sh, elbow, hand, sx))

grip = empty("Grip", root)
hoe = empty("Hoe", grip)
h = cyl("Handle", hoe, 0.036, 0.036, 0.86, (0, 0, -0.31), "wood")
box("Blade", hoe, (0.22, 0.20, 0.06), (0, 0.07, -0.74), "metal")
can = empty("Can", grip)
cyl("CanBody", can, 0.14, 0.13, 0.22, (0, -0.06, -0.08), "can")
sp = cyl("Spout", can, 0.035, 0.05, 0.26, (0, -0.27, 0.0), "can")
sp.rotation_euler = (d(-55), 0, 0)
# 鱼竿分两节：下半截直的，上半截可以弯（rod_bend），竿尖的位置渲染时算出来写进 json
rod = empty("Rod", grip)
cyl("RodPole", rod, 0.03, 0.02, 0.9, (0, 0, 0.3), "wood")
rod_upper = empty("RodUpper", rod, (0, 0, 0.75))
cyl("RodTipSeg", rod_upper, 0.02, 0.01, 0.75, (0, 0, 0.375), "wood")
rod_tip = empty("RodTip", rod_upper, (0, 0, 0.75))
# 三件武器，和锄头一样顺着 -Z 伸出去
sickle = empty("Sickle", grip)
cyl("SickleHandle", sickle, 0.034, 0.034, 0.42, (0, 0, -0.14), "wood")
box("SickleBlade", sickle, (0.06, 0.30, 0.09), (0, -0.12, -0.38), "metal")
box("SickleTip", sickle, (0.06, 0.09, 0.14), (0, -0.25, -0.31), "metal")
dagger = empty("Dagger", grip)
cyl("DaggerHandle", dagger, 0.034, 0.034, 0.16, (0, 0, 0.0), "wood")
box("DaggerGuard", dagger, (0.18, 0.07, 0.05), (0, 0, -0.1), "band")
box("DaggerBlade", dagger, (0.08, 0.05, 0.40), (0, 0, -0.32), "metal")
hammer = empty("Hammer", grip)
cyl("HammerHandle", hammer, 0.038, 0.038, 0.72, (0, 0, -0.24), "wood")
box("HammerHead", hammer, (0.22, 0.34, 0.22), (0, 0, -0.64), "metal")
# 雨伞：柄朝上（+Z），伞面撑在头顶；打伞走时举在一只手上方
umbrella = empty("Umbrella", grip)
cyl("UmbrellaShaft", umbrella, 0.035, 0.035, 0.75, (0, 0, 0.375), "wood")
cyl("UmbrellaCanopy", umbrella, 0.34, 0.04, 0.20, (0, 0, 0.80), "band")
ball("UmbrellaTip", umbrella, (0.022, 0.022, 0.03), (0, 0, 0.92), "wood")
# 团扇：短柄 + 一面圆扇，举在胸前轻摇
fan = empty("Fan", grip)
cyl("FanHandle", fan, 0.02, 0.02, 0.12, (0, 0, -0.06), "wood")
cyl("FanFace", fan, 0.16, 0.16, 0.02, (0, 0, -0.20), "band")
# 扫帚：长柄斜朝下，帚头扫到地面
broom = empty("Broom", grip)
cyl("BroomHandle", broom, 0.025, 0.025, 0.80, (0, 0, -0.30), "wood")
box("BroomHead", broom, (0.16, 0.10, 0.20), (0, 0, -0.74), "band")
# 画笔：短柄，笔头朝下点在画布上
brush = empty("Brush", grip)
cyl("BrushHandle", brush, 0.015, 0.015, 0.22, (0, 0, -0.05), "wood")
box("BrushTip", brush, (0.03, 0.03, 0.06), (0, 0, -0.18), "metal")
# 炒锅：锅口比锅底宽、锅壁有一点深，斜着看才是一口锅。柄和铲要够粗，像素化之后还剩得下。
wok = empty("Wok", grip)
cyl("WokHandle", wok, 0.035, 0.035, 0.22, (0, -0.04, 0.02), "wood").rotation_euler = (d(90), 0, 0)
cyl("WokPan", wok, 0.16, 0.32, 0.20, (0, -0.36, 0.02), "metal")
wok_food = ball("WokFood", wok, (0.16, 0.16, 0.07), (0, -0.36, 0.10), "food")
spatula = empty("Spatula", wok)
cyl("SpatulaHandle", spatula, 0.045, 0.04, 0.58, (0, 0, 0.18), "wood")
# 铲刃用木色：金属灰和锅同色，静帧上铲刃会溶进锅里只剩一根柄。
box("SpatulaBlade", spatula, (0.22, 0.10, 0.05), (0, 0.02, -0.04), "wood")


def set_visible(obj, vis):
    obj.hide_render = not vis
    for c in obj.children:
        set_visible(c, vis)


# ------------------------------------------------------------------ 姿势

BASE = dict(bob=0.0, crouch=0.0, lean=0.0, twist=0.0, head=0.0,
            leg=(0.0, 0.0), knee=(0.0, 0.0), arm=(0.0, 0.0), elbow=(-8.0, -8.0),
            yaw=0.0, spread=4.0, sway=0.0, step=False, tool=None, tool_pitch=0.0, tool_off=(0.0, 0.0),
            # 正面和背面时工具绕竖轴转开这个角度，不然鱼竿正对镜头看不见
            tool_yaw=0.0,
            # 鱼竿上半截往线的方向弯多少度
            rod_bend=0.0,
            # 工具绕竖轴横着扫开的角度（镰刀横扫），四个方向都生效
            tool_swing=0.0,
            # 整个人绕腰往前翻多少度（翻滚）
            tumble=0.0,
            # 整个人再往上抬多少（翻到头朝下的那一帧不抬会伸到格子外面）
            lift=0.0,
            # 道具锚在哪只手：-1 双手中间（默认），0 第一只手，1 第二只手
            grip_hand=-1,
            # 锅里的菜颠起来多高
            toss=0.0,
            # 铲子绕锅转过的角度（弧度）。四个方向都用它，不跟着朝向清掉
            stir=0.0)


def pose(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


# 八拍，0 和 4 是落脚。负的 leg 是往前迈，knee 是膝盖往后弯。
# 俯视正面看不出前后摆，要靠三样：抬起来的那只脚比另一只高两像素、
# 身子往撑地的那条腿那边挪一像素、落脚后往下沉一像素。侧面照样是一整步。
# (leg, knee, bob 像素, sway 像素)
def _walk_row(i):
    """按相位生成：腿按余弦前后摆，抬腿那一程膝盖才弯，相邻两帧的角度差都在 40 度以内。"""
    t = math.tau * i / 8.0
    amp = 34.0
    leg = (-amp * math.cos(t), amp * math.cos(t))
    # 腿往前迈的那一程（余弦在变小）是抬腿，膝盖弯；落地那一程伸直
    swing = (max(0.0, -math.sin(t)), max(0.0, math.sin(t)))
    knee = tuple(6.0 + 78.0 * s ** 0.9 for s in swing)
    bob = -1 if i in (1, 5) else 0
    sway = (0, 1, 1, 1, 0, -1, -1, -1)[i]
    return (leg, knee, bob, sway)


_WALK = [_walk_row(i) for i in range(8)]


def _walk_pose(i, hold=None):
    leg, knee, bob, sway = _WALK[i]
    # 手和对侧的腿一起摆；往前的那只手肘弯得多一点，正面也能看出手抬了起来
    arm = (-leg[1] * 1.1, -leg[0] * 1.1)
    elbow = tuple(-12 - 22 * max(0.0, -a / 30.0) for a in arm)
    kw = dict(bob=bob * PIX, lean=4, head=-5, leg=leg, knee=knee, arm=arm, elbow=elbow, sway=sway, step=True)
    if hold == "umbrella":
        kw["arm"] = (-124, arm[1])
        kw["elbow"] = (-28, elbow[1])
        kw["grip_hand"] = 0
        kw["tool"] = "umbrella"
        kw["tool_pitch"] = 0
    return pose(**kw)


def frames(anim):
    if anim == "idle":
        return [
            pose(),
            pose(arm=(3, 3), head=2),
            pose(bob=-PIX, arm=(5, 5), head=3, spread=6),
            pose(arm=(3, 3), head=2),
        ]
    if anim == "walk":
        return [_walk_pose(i) for i in range(8)]
    if anim == "sit":
        # 大腿平放、小腿垂下，屁股落到凳面的高度；手搭在腿上
        return [pose(bob=-0.19, lean=-3, head=3, leg=(-84, -84), knee=(80, 80),
                     arm=(-30, -30), elbow=(-45, -45), spread=2)]
    if anim == "hoe":
        return [
            pose(arm=(-115, -115), elbow=(-30, -30), yaw=25, lean=-2, tool="hoe", tool_pitch=-150),
            pose(arm=(-195, -195), elbow=(-25, -25), yaw=10, lean=-5, head=-5, bob=PIX,
                 tool="hoe", tool_pitch=-215),
            # 下砸途中锄头已经低于脸，正面看不会挡住眼睛
            pose(arm=(-78, -78), elbow=(-10, -10), yaw=30, lean=6, crouch=10, head=-4,
                 tool="hoe", tool_pitch=-98),
            pose(arm=(-42, -42), elbow=(-12, -12), yaw=35, lean=15, head=-4, crouch=26,
                 tool="hoe", tool_pitch=-68),
            pose(arm=(-52, -52), elbow=(-18, -18), yaw=35, lean=11, head=-3, crouch=18,
                 tool="hoe", tool_pitch=-76),
            pose(arm=(-45, -45), elbow=(-25, -25), yaw=35, lean=7, crouch=8,
                 tool="hoe", tool_pitch=-88),
        ]
    if anim == "water":
        return [
            pose(arm=(-38, -38), elbow=(-45, -45), yaw=38, lean=3, tool="can", tool_pitch=-5),
            pose(arm=(-52, -52), elbow=(-30, -30), yaw=38, lean=9, crouch=10, head=5,
                 tool="can", tool_pitch=-28),
            pose(arm=(-58, -58), elbow=(-22, -22), yaw=38, lean=13, crouch=16, head=8,
                 tool="can", tool_pitch=-42),
            pose(arm=(-55, -55), elbow=(-26, -26), yaw=38, lean=11, crouch=13, head=7,
                 tool="can", tool_pitch=-36),
        ]
    if anim == "reach":
        return [
            pose(arm=(-25, -25), elbow=(-25, -25), yaw=15, lean=14, crouch=14, head=6),
            pose(arm=(-42, -42), elbow=(-15, -15), yaw=22, lean=24, crouch=30, head=2),
            pose(arm=(-50, -50), elbow=(-8, -8), yaw=25, lean=32, crouch=42, head=4),
        ]
    HOLD = pose(arm=(-42, -42), elbow=(-30, -30), yaw=22, lean=4, head=3, tool="rod", tool_pitch=52, tool_yaw=-68)
    if anim == "cast":
        # 竿尖朝向 (0, -sin, cos)：pitch 为负时竿尖向后上方，为正时向前
        return [
            pose(arm=(-70, -70), elbow=(-30, -30), yaw=20, lean=-2, head=-2, tool="rod", tool_pitch=8, tool_yaw=-30),
            pose(arm=(-120, -120), elbow=(-35, -35), yaw=15, lean=-6, head=-4, tool="rod", tool_pitch=-50, tool_yaw=-30),
            pose(arm=(-150, -150), elbow=(-30, -30), yaw=12, lean=-10, head=-6, bob=PIX, tool="rod", tool_pitch=-85, tool_yaw=-30, rod_bend=-10),
            pose(arm=(-45, -45), elbow=(-15, -15), yaw=25, lean=12, head=4, crouch=6, tool="rod", tool_pitch=70, tool_yaw=-68, rod_bend=15),
            pose(arm=(-38, -38), elbow=(-25, -25), yaw=24, lean=8, head=4, crouch=3, tool="rod", tool_pitch=60, tool_yaw=-68, rod_bend=5),
            HOLD,
        ]
    if anim == "fish":
        return [
            HOLD,
            pose(arm=(-44, -44), elbow=(-32, -32), yaw=22, lean=5, head=4, bob=-PIX, tool="rod", tool_pitch=50, tool_yaw=-68),
        ]
    if anim == "hook":
        return [pose(arm=(-110, -110), elbow=(-40, -40), yaw=18, lean=-10, head=-5, bob=PIX, tool="rod", tool_pitch=-5, tool_yaw=-50, rod_bend=25)]
    if anim == "reel":
        return [
            pose(arm=(-58, -30), elbow=(-44, -18), yaw=22, lean=2, head=4, tool="rod", tool_pitch=50, tool_yaw=-68, rod_bend=18),
            pose(arm=(-44, -44), elbow=(-30, -30), yaw=22, lean=4, head=4, bob=-PIX, tool="rod", tool_pitch=44, tool_yaw=-68, rod_bend=24),
            pose(arm=(-30, -58), elbow=(-18, -44), yaw=22, lean=2, head=4, tool="rod", tool_pitch=50, tool_yaw=-68, rod_bend=18),
        ]
    if anim == "strain":
        return [
            pose(arm=(-72, -72), elbow=(-42, -42), yaw=20, lean=-12, head=-4, crouch=4, tool="rod", tool_pitch=38, tool_yaw=-62, rod_bend=65),
            pose(arm=(-76, -76), elbow=(-44, -44), yaw=20, lean=-15, head=-5, crouch=6, bob=-PIX, tool="rod", tool_pitch=34, tool_yaw=-62, rod_bend=76),
        ]
    if anim == "slash":
        return [
            pose(arm=(-60, -60), elbow=(-22, -22), yaw=20, twist=-42, lean=4, head=-2,
                 tool="sickle", tool_pitch=-95, tool_swing=-70),
            pose(arm=(-72, -72), elbow=(-10, -10), yaw=25, twist=0, lean=10, crouch=8, head=2,
                 tool="sickle", tool_pitch=-90, tool_swing=0),
            pose(arm=(-68, -68), elbow=(-12, -12), yaw=22, twist=42, lean=9, crouch=8, head=2,
                 tool="sickle", tool_pitch=-90, tool_swing=70),
            pose(arm=(-50, -50), elbow=(-22, -22), yaw=20, twist=22, lean=5, crouch=3,
                 tool="sickle", tool_pitch=-88, tool_swing=38),
        ]
    if anim == "stab":
        return [
            pose(arm=(-30, -30), elbow=(-62, -62), yaw=25, twist=-14, lean=-4, head=-2,
                 tool="dagger", tool_pitch=-90),
            pose(arm=(-86, -86), elbow=(-5, -5), yaw=30, lean=18, crouch=10, head=4,
                 tool="dagger", tool_pitch=-92),
            pose(arm=(-60, -60), elbow=(-26, -26), yaw=28, lean=8, crouch=4,
                 tool="dagger", tool_pitch=-90),
        ]
    if anim == "smash":
        out = []
        for p in frames("hoe"):
            q = dict(p)
            q["tool"] = "hammer"
            out.append(q)
        return out
    if anim == "roll":
        tuck = dict(crouch=38, lean=34, head=16, leg=(-72, -72), knee=(96, 96),
                    arm=(-64, -64), elbow=(-70, -70), spread=2)
        return [pose(tumble=t, lift=up, **tuck) for t, up in ((45, 0.0), (135, 0.4), (225, 0.1), (315, 0.0))]
    if anim == "trophy":
        return [pose(arm=(-168, -168), elbow=(-15, -15), yaw=4, spread=12, head=10, lean=-3)]
    if anim == "umbrella_walk":
        return [_walk_pose(i, "umbrella") for i in range(8)]
    if anim == "fan":
        return [
            pose(arm=(-40, -18), elbow=(-70, -12), yaw=12, head=3, grip_hand=0, tool="fan", tool_pitch=-75, tool_swing=-18),
            pose(arm=(-46, -18), elbow=(-62, -12), yaw=12, head=3, grip_hand=0, tool="fan", tool_pitch=-75, tool_swing=0),
            pose(arm=(-40, -18), elbow=(-70, -12), yaw=12, head=3, grip_hand=0, tool="fan", tool_pitch=-75, tool_swing=18),
            pose(arm=(-34, -18), elbow=(-78, -12), yaw=12, head=3, grip_hand=0, tool="fan", tool_pitch=-75, tool_swing=0),
        ]
    if anim == "rub":
        return [
            pose(arm=(-46, -46), elbow=(-62, -62), yaw=10, lean=3, head=4, spread=8),
            pose(arm=(-42, -50), elbow=(-66, -58), yaw=10, lean=3, head=4, spread=8, bob=-PIX),
            pose(arm=(-46, -46), elbow=(-62, -62), yaw=10, lean=3, head=4, spread=8),
            pose(arm=(-50, -42), elbow=(-58, -66), yaw=10, lean=3, head=4, spread=8, bob=-PIX),
        ]
    if anim == "sweep":
        return [
            pose(arm=(-50, -50), elbow=(-25, -25), yaw=20, lean=12, head=4, tool="broom", tool_pitch=-58, tool_swing=-26),
            pose(arm=(-52, -48), elbow=(-22, -28), yaw=24, lean=14, head=4, tool="broom", tool_pitch=-60, tool_swing=-10),
            pose(arm=(-50, -50), elbow=(-25, -25), yaw=20, lean=12, head=4, tool="broom", tool_pitch=-58, tool_swing=8),
            pose(arm=(-48, -52), elbow=(-28, -22), yaw=16, lean=10, head=4, tool="broom", tool_pitch=-56, tool_swing=24),
            pose(arm=(-50, -50), elbow=(-25, -25), yaw=20, lean=12, head=4, tool="broom", tool_pitch=-58, tool_swing=8),
            pose(arm=(-52, -48), elbow=(-22, -28), yaw=24, lean=14, head=4, tool="broom", tool_pitch=-60, tool_swing=-10),
        ]
    if anim == "squat":
        return [
            pose(bob=-0.11, crouch=26, lean=10, head=6, leg=(-80, -80), knee=(62, 62),
                 arm=(-30, -30), elbow=(-50, -50), spread=3),
            pose(bob=-0.12, crouch=28, lean=11, head=7, leg=(-82, -82), knee=(64, 64),
                 arm=(-32, -28), elbow=(-52, -48), spread=3),
        ]
    if anim == "stomp":
        out = []
        for i in range(4):
            hi, lo = (74.0, 0.0) if i % 2 == 0 else (0.0, 74.0)
            out.append(pose(
                bob=-0.02, lean=3, head=2,
                leg=(-hi, -lo), knee=(hi * 1.15, lo * 1.15),
                arm=(-20, -20), elbow=(-30, -30), spread=5, step=True,
            ))
        return out
    if anim == "paint":
        return [
            pose(arm=(-55, -18), elbow=(-30, -12), yaw=16, lean=6, head=5, grip_hand=0, tool="brush", tool_pitch=-70, tool_swing=-6),
            pose(arm=(-58, -18), elbow=(-26, -12), yaw=16, lean=7, head=5, grip_hand=0, tool="brush", tool_pitch=-72, tool_swing=4),
            pose(arm=(-55, -18), elbow=(-30, -12), yaw=16, lean=6, head=5, grip_hand=0, tool="brush", tool_pitch=-70, tool_swing=10),
            pose(arm=(-52, -18), elbow=(-34, -12), yaw=16, lean=5, head=5, grip_hand=0, tool="brush", tool_pitch=-68, tool_swing=2),
        ]
    if anim == "cook":
        # 八帧绕一圈，首尾接得上。锅一直偏在身侧，不从身子正前穿过去，背面才不会被挡住。
        # 每一步的位移一样大。正弦会在两端停住、中间跳一截。
        xs = [-1.0, -0.5, 0.0, 0.5, 1.0, 0.5, 0.0, -0.5]
        ys = [0.0, 0.5, 1.0, 0.5, 0.0, -0.5, -1.0, -0.5]
        out = []
        for i in range(8):
            x, y = xs[i], ys[i]
            out.append(pose(
                arm=(-16 + x * 30, -52),
                elbow=(2 + y * 18, -42),
                yaw=36, spread=14,
                lean=4 + x * 4,
                head=1 + y * 2,
                bob=y * PIX * 0.25,
                grip_hand=0,
                tool="wok",
                tool_pitch=-24 + y * 6,
                tool_swing=-72 + x * 8,
                tool_yaw=62,
                # 颠锅高度整圈都变：原来 y<=0 时 toss 恒定，圈底几步几乎不动、像素差掉下去
                toss=0.06 + y * 0.05,
                # 铲子每步转同样 45°：atan2 会在圈顶压小角速度，那几步像素差掉下去。
                stir=math.tau * i / 8.0 - math.pi / 2.0,
            ))
        return out
    raise ValueError(anim)


def apply_pose(p, facing_deg):
    c = d(p["crouch"])
    drop = (0.17 + 0.19) * (1.0 - math.cos(c))
    z = round((p["bob"] - drop) * SCALE / PIX) * PIX / SCALE
    root.rotation_euler = (d(p["tumble"]), 0, d(facing_deg))
    # 翻滚绕着腰翻，不是绕着脚底：把根节点挪一下，让腰留在原地
    _pivot = Vector((0.0, 0.0, 0.5 * SCALE))
    root.location = _pivot - root.rotation_euler.to_matrix() @ _pivot if p["tumble"] else (0.0, 0.0, 0.0)
    root.location.z += p["lift"]
    # 左右挪按整像素，正面看是重心换到另一条腿上
    hips.location = (p["sway"] * _px, 0, HIP + z)
    torso.rotation_euler = (d(p["lean"] + STOOP), 0, 0)
    chest.rotation_euler = (0, 0, d(p["twist"]))
    head.rotation_euler = (d(p["head"] - STOOP * 0.7), 0, 0)
    sideways = abs(abs(facing_deg) - 90.0) < 1.0
    for i, (hip, knee) in enumerate(legs):
        # 正面和背面俯视时，抬腿往镜头那边送，屏幕上几乎不往上走。
        # 弯得厉害的那条腿整条往上提一两像素，才看得出是哪只脚离了地。
        hike = 0
        if not sideways and p["step"]:
            hike = 2 if p["knee"][i] >= 80 else (1 if p["knee"][i] >= 30 else 0)
        hip.location = (0.13 * (1 if i == 0 else -1), 0, hike * PIX / SCALE)
        hip.rotation_euler = (d(p["leg"][i]) - c, 0, 0)
        knee.rotation_euler = (d(p["knee"][i]) + 2.0 * c, 0, 0)
    for i, (sh, elbow, hand, sx) in enumerate(arms):
        sh.rotation_euler = (d(p["arm"][i]), d(-p["spread"] * sx), d(p["yaw"] * sx))
        elbow.rotation_euler = (d(p["elbow"][i]), 0, 0)
    sideways = abs(abs(facing_deg) - 90.0) < 1.0
    set_visible(front_eyes, not sideways)
    set_visible(side_eyes, sideways)
    set_visible(hoe, p["tool"] == "hoe")
    set_visible(can, p["tool"] == "can")
    set_visible(rod, p["tool"] == "rod")
    set_visible(sickle, p["tool"] == "sickle")
    set_visible(dagger, p["tool"] == "dagger")
    set_visible(hammer, p["tool"] == "hammer")
    set_visible(umbrella, p["tool"] == "umbrella")
    set_visible(fan, p["tool"] == "fan")
    set_visible(broom, p["tool"] == "broom")
    set_visible(brush, p["tool"] == "brush")
    set_visible(wok, p["tool"] == "wok")
    ang = p["stir"]
    sx, sy = math.sin(ang), math.cos(ang)
    wok_food.location = (sx * 0.07, -0.36 + sy * 0.04, 0.1 + p["toss"])
    # 铲子绕得离身子更远一点，背面看才不会贴进后背里
    spatula.location = (sx * 0.22, -0.30 + sy * 0.10, 0.2 + p["toss"] * 0.5)
    spatula.rotation_euler = (d(50), 0, -ang)
    if p["tool"] is not None:
        bpy.context.view_layer.update()
        inv = root.matrix_world.inverted()
        gh = p["grip_hand"]
        if gh < 0:
            anchor = (inv @ arms[0][2].matrix_world.translation + inv @ arms[1][2].matrix_world.translation) * 0.5
        else:
            anchor = inv @ arms[gh][2].matrix_world.translation
        grip.location = anchor
        yaw = d(p["tool_yaw"])
        # 侧面把工具的左右转平掉，锄头鱼竿才不会横着穿出画面。
        # 炒锅留一半转角，侧面才看得见锅口，不是一条边。
        if sideways and p["tool"] != "wok":
            yaw = 0.0
        elif sideways:
            yaw *= 0.55
        grip.rotation_euler = (d(p["tool_pitch"]), 0, yaw + d(p["tool_swing"]))
        rod_upper.rotation_euler = (d(p["rod_bend"]), 0, 0)
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
    """每个 4x4 块取出现最多的调色板颜色；覆盖不足一半的块视为透明。"""
    rgb = a[..., :3].astype(np.int32)
    dist = ((rgb[:, :, None, :] - PAL_ARR[None, None, :, :]) ** 2).sum(-1)
    idx = dist.argmin(-1)
    opaque = a[..., 3] > 127
    idx = np.where(opaque, idx, -1)
    blocks = idx.reshape(CELL, SS, CELL, SS).transpose(0, 2, 1, 3).reshape(CELL, CELL, SS * SS)
    out = np.zeros((CELL, CELL, 4), dtype=np.uint8)
    cover = (blocks >= 0).sum(-1)
    ys, xs = np.nonzero(cover >= 7)
    for y, x in zip(ys, xs):
        vals = blocks[y, x]
        counts = np.bincount(vals[vals >= 0], minlength=len(PALETTE))
        best = int(counts.argmax())
        if counts[EYE_IDX] >= 5:
            best = EYE_IDX
        out[y, x, :3] = PALETTE[best]
        out[y, x, 3] = 255
    return out


def outline(a):
    """给不透明区域外侧加一圈描边，颜色取相邻像素的暗色（与 art_gen/pixel.gd 的算法一致）。"""
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
        tips = []
        for facing in DIRS:
            tips_dir = []
            for k, p in enumerate(fr):
                apply_pose(p, facing)
                a = render_frame(os.path.join(TMP, "f.png"))
                sheet[row * CELL:(row + 1) * CELL, k * CELL:(k + 1) * CELL] = outline(pixelate(a))
                if p["tool"] == "rod":
                    # 竿尖相对脚底的像素偏移，游戏里鱼线从这里画出去
                    v = world_to_camera_view(scene, cam, rod_tip.matrix_world.translation)
                    tips_dir.append([round(v.x * CELL - CELL / 2.0), round((1.0 - v.y) * CELL - FOOT_ROW)])
            if tips_dir:
                tips.append(tips_dir)
            row += 1
        if tips:
            info["tips"] = tips
        print("rendered", anim, flush=True)
    save_png(sheet, OUT)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(desc, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    shutil.rmtree(TMP, ignore_errors=True)

    if CONFIG.get("blend", False) and not os.environ.get("CHAR_OUT"):
        # 存一份模型文件，停在挥锄的姿势，方便用 Blender 打开看
        apply_pose(frames("hoe")[3], 0.0)
        scene.render.resolution_x = 768
        scene.render.resolution_y = 768
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, NAME + ".blend"))
    print("saved", OUT, flush=True)


main()
