"""展示用：用 Blender 重画一版「茶馆」，并输出同一模型的白天 / 雪夜两种状态。

不改动 art/props/ 下任何现有素材，只往 _preview/ 写图，用来并排比较。
复用 tools/props.py 里已经验证过的整条管线：剪切斜投影、三色阶材质、
4 倍超采样取调色板众数、像素纹理、描边。差别只在建模，所以对比是公平的。

用法:
  blender --background --python tools/showcase_teahouse.py

输出（farm-town/_preview/）:
  showcase_day.png       重制版 · 白天，144x110 左右的透明像素图，可直接替换
  showcase_snow.png      重制版 · 雪夜，同一模型 + 雪 / 暖光 / 冷色材质映射
  showcase_raw_day.png   白天版的原始 3D 渲染缩略图，用来证明是 Blender 渲的

再由 tools/showcase_compare.py（系统 Python + PIL）生成:
  showcase_compare.png    现有素材 / 白天 / 雪夜 三联对比
  showcase_day_zoom.png   白天版放大 3 倍的单图
"""
import atexit
import json
import math
import os
import random
import shutil

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TMP = os.path.join(HERE, "_showcase_tmp")
OUT_DIR = os.path.join(PROJ, "_preview")

PPU = 16
SS = 4
T_DARK = 0.3
T_LIGHT = 0.7

with open(os.path.join(PROJ, "data", "palette.json"), encoding="utf-8") as _f:
    RAMPS = json.load(_f)["ramps"]


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hex_lin(h):
    out = []
    for c in hex_rgb(h):
        c = c / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (out[0], out[1], out[2], 1.0)


PALETTE = []
for _name, _cols in RAMPS.items():
    for _h in _cols:
        if hex_rgb(_h) not in PALETTE:
            PALETTE.append(hex_rgb(_h))
PAL_ARR = np.array(PALETTE, dtype=np.int32)

_levels = (np.arange(64, dtype=np.int32) * 4 + 2)
_grid = np.stack(np.meshgrid(_levels, _levels, _levels, indexing="ij"), -1).reshape(-1, 3)
LUT = np.empty(len(_grid), dtype=np.int16)
for _i in range(0, len(_grid), 8192):
    _chunk = _grid[_i:_i + 8192]
    LUT[_i:_i + 8192] = ((_chunk[:, None, :] - PAL_ARR[None, :, :]) ** 2).sum(-1).argmin(-1)


# ------------------------------------------------------------------ 场景

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
_engine = None
for _name in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
    try:
        scene.render.engine = _name
        _engine = _name
        break
    except TypeError:
        continue
if _engine is None:
    # 不能悄悄回退到 Cycles：ShaderNodeShaderToRGB 在 Cycles 下输出近黑，
    # 三色阶会全部落到暗档，不报错但产出一张废图。
    raise RuntimeError("需要 EEVEE：本脚本的三色阶材质依赖 ShaderNodeShaderToRGB")
try:
    scene.eevee.taa_render_samples = 1
except AttributeError:
    pass
scene.render.filter_size = 0.01
scene.render.dither_intensity = 0.0
scene.render.film_transparent = True
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
cam_data.clip_start = 0.1
cam_data.clip_end = 200.0
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
cam.rotation_euler = (math.pi / 2.0, 0.0, 0.0)

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = math.pi
sun_data.angle = 0.0
sun_data.use_shadow = True
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = Vector((0.45, 0.55, -0.7)).to_track_quat("-Z", "Y").to_euler()


def make_mat(name):
    """三段色阶：受光低于 T_DARK 用暗色，高于 T_LIGHT 用亮色。"""
    light, mid, dark = RAMPS[name]
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
    ramp.color_ramp.elements[1].position = T_DARK
    ramp.color_ramp.elements[1].color = hex_lin(mid)
    top = ramp.color_ramp.elements.new(T_LIGHT)
    top.color = hex_lin(light)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(diff.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], emit.inputs[0])
    nt.links.new(emit.outputs[0], out.inputs[0])
    return m


def make_glow(h):
    """不受光照影响的固定色，用来做窗里的暖光和点着的灯笼。"""
    m = bpy.data.materials.new("glow_" + h)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    emit = nt.nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = hex_lin(h)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(emit.outputs[0], out.inputs[0])
    return m


MATS = {n: make_mat(n) for n in RAMPS}
GLOWS = {
    "warm": make_glow(RAMPS["gold"][0]),
    "lamp": make_glow(RAMPS["ember"][0]),
}


# ------------------------------------------------------------------ 建模工具

SHEAR = Matrix.Identity(4)
SHEAR[2][1] = 1.0
CURRENT = []
# 雪夜把常见材质换成同色系里更冷更暗的一档。三色阶会把光照强度量化掉，
# 所以压暗太阳没用，得换材质；雪和自发光暖光不参与映射，才能留出对比。
TONE = {}


def _emit(bm, loc, rot, scale, mat, smooth, upright):
    local = (Matrix.Translation(loc)
             @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
             @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))
    outer = Matrix.Translation((0.0, 0.0, loc[1])) if upright else SHEAR
    bmesh.ops.transform(bm, matrix=outer @ local, verts=bm.verts)
    me = bpy.data.meshes.new("part")
    bm.to_mesh(me)
    bm.free()
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
        try:
            me.set_sharp_from_angle(angle=math.radians(50))
        except Exception:
            pass
    if mat.startswith("glow:"):
        me.materials.append(GLOWS[mat[5:]])
    else:
        me.materials.append(MATS[TONE.get(mat, mat)])
    ob = bpy.data.objects.new("part", me)
    scene.collection.objects.link(ob)
    CURRENT.append(ob)
    return ob


def box(size, loc, mat, rot=(0, 0, 0), upright=False):
    """长方体，loc 是中心。"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    return _emit(bm, loc, rot, size, mat, False, upright)


def cyl(r1, r2, h, loc, mat, rot=(0, 0, 0), segs=10, upright=False, center=False):
    """圆柱或圆台，默认 loc 是底面中心。"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=max(r2, 0.0001), depth=h)
    if not center:
        bmesh.ops.translate(bm, vec=(0, 0, h / 2.0), verts=bm.verts)
    return _emit(bm, loc, rot, (1, 1, 1), mat, True, upright)


def ball(radii, loc, mat, rot=(0, 0, 0), upright=True, sub=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    return _emit(bm, loc, rot, radii, mat, True, upright)


def clear_current():
    for ob in CURRENT:
        me = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(me)
    CURRENT.clear()


# ------------------------------------------------------------------ 茶馆

W = 7.0
DEP = 2.4
WALL_TOP = 3.2
RISE = 1.0
OVER = 0.35
RW = W + 0.9
HALF = DEP / 2.0 + OVER
ROOF_A = math.degrees(math.atan2(RISE, HALF))
ROOF_LEN = math.hypot(RISE, HALF)
AR = math.radians(ROOF_A)
RIDGE_Z = WALL_TOP + RISE


def lantern(x, y, top, lit):
    """檐下灯笼：雪夜时芯是自发光的暖色。"""
    core = "glow:lamp" if lit else "gold"
    box((0.04, 0.04, 0.28), (x, y, top - 0.14), "ink")
    cyl(0.09, 0.09, 0.05, (x, y, top - 0.32), "gold", segs=8)
    cyl(0.12, 0.19, 0.15, (x, y, top - 0.47), "red", segs=10)
    box((0.16, 0.02, 0.1), (x, y - 0.19, top - 0.5), core)
    cyl(0.19, 0.12, 0.17, (x, y, top - 0.63), "red", segs=10)
    cyl(0.09, 0.09, 0.05, (x, y, top - 0.70), "gold", segs=8)
    box((0.05, 0.03, 0.2), (x, y, top - 0.82), "red")


def lattice_window(x, z, w, h, glow, frame="wood_dk"):
    """细格木窗：4 竖 3 横，窗纸白天是纸色，雪夜是暖光。"""
    paper = "glow:warm" if glow else "paper"
    box((w + 0.26, 0.09, h + 0.26), (x, -0.05, z), frame)
    box((w, 0.04, h), (x, -0.10, z), paper)
    for i in range(1, 4):
        box((0.05, 0.03, h), (x - w / 2 + i * w / 4, -0.13, z), frame)
    for j in range(1, 3):
        box((w, 0.03, 0.05), (x, -0.13, z - h / 2 + j * h / 3), frame)
    box((w + 0.4, 0.16, 0.1), (x, -0.12, z - h / 2 - 0.16), "wood")
    # 窗下的木裙板
    box((w + 0.26, 0.05, 0.7), (x, -0.07, 0.85), "wood_dk")
    for k in range(4):
        box((0.04, 0.02, 0.6), (x - w / 2 + 0.12 + k * w / 3.4, -0.10, 0.85), "wood")


def roof(snow):
    """两坡瓦顶：逐片错缝的瓦、起翘的屋脊、檐口滴水，雪夜另加薄雪。"""
    for sgn in (1, -1):
        cy = DEP / 2.0 - sgn * HALF / 2.0
        cz = WALL_TOP + RISE / 2.0
        ny, nz = -math.sin(AR) * sgn, math.cos(AR)
        box((RW, ROOF_LEN + 0.06, 0.10), (0, cy, cz), "tile_dk", rot=(ROOF_A * sgn, 0, 0))
        # 逐片瓦：16 垄 x 7 排，隔排错缝，深浅交替
        nx, ny_cnt = 16, 7
        tw, tl = RW / nx, ROOF_LEN / ny_cnt
        for j in range(ny_cnt):
            t = (j + 0.5 - ny_cnt / 2.0) * tl
            stagger = (tw * 0.35) if j % 2 else 0.0
            for i in range(nx + 1):
                u = -RW / 2.0 + (i + 0.5) * tw + stagger
                if abs(u) > RW / 2.0 - tw * 0.3:
                    continue
                mat = "tile_hi" if (i + j) % 5 == 0 else "tile"
                if (i * 7 + j * 3) % 17 == 0:
                    mat = "tile_dk"
                py = cy + math.cos(AR) * t + ny * 0.075
                pz = cz + math.sin(AR) * sgn * t + nz * 0.075
                box((tw * 0.94, tl * 0.94, 0.05), (u, py, pz), mat,
                    rot=(ROOF_A * sgn, 0, 0))
        # 檐口一排滴水瓦当
        for i in range(24):
            x = -RW / 2.0 + (i + 0.5) * RW / 24.0
            box((RW / 24.0 * 0.8, 0.12, 0.12),
                (x, DEP / 2.0 - sgn * (HALF - 0.02), WALL_TOP - 0.04), "tile_hi")
        if snow:
            # 靠檐口的一线断续积雪，扁长条顺着瓦垄；再在靠脊处点几处细斑。
            # 不做随机大方块，否则在 16px/格上看着像贴图错误。
            rnd = random.Random(31 + sgn)
            for k in range(14):
                if rnd.random() < 0.24:
                    continue
                u = -RW / 2.0 + (k + 0.5) * RW / 14.0 + rnd.uniform(-0.08, 0.08)
                t = -ROOF_LEN * rnd.uniform(0.30, 0.44)
                sw, sl = rnd.uniform(0.3, 0.72), rnd.uniform(0.07, 0.14)
                py = cy + math.cos(AR) * t + ny * 0.12
                pz = cz + math.sin(AR) * sgn * t + nz * 0.12
                box((sw, sl, 0.04), (u, py, pz), "steel", rot=(ROOF_A * sgn, 0, 0))
            for k in range(4):
                u = rnd.uniform(-RW / 2.0 + 0.6, RW / 2.0 - 0.6)
                t = ROOF_LEN * rnd.uniform(0.26, 0.4)
                py = cy + math.cos(AR) * t + ny * 0.12
                pz = cz + math.sin(AR) * sgn * t + nz * 0.12
                box((rnd.uniform(0.18, 0.4), 0.08, 0.04), (u, py, pz), "steel",
                    rot=(ROOF_A * sgn, 0, 0))
    # 屋脊
    box((RW + 0.24, 0.32, 0.26), (0, DEP / 2.0, RIDGE_Z + 0.13), "tile_dk")
    box((RW + 0.24, 0.12, 0.07), (0, DEP / 2.0 - 0.12, RIDGE_Z + 0.29), "tile_hi")
    # 两端起翘的脊：四段逐节抬高
    for s in (-1, 1):
        for k in range(4):
            x = s * (RW / 2.0 + 0.02 + k * 0.17)
            z = RIDGE_Z + 0.28 + k * k * 0.075
            box((0.22, 0.26, 0.15), (x, DEP / 2.0, z), "tile_dk", rot=(0, -14 * s * k, 0))
        ball((0.09, 0.09, 0.1), (s * (RW / 2.0 + 0.6), DEP / 2.0, RIDGE_Z + 1.12),
             "tile_dk", upright=False, sub=1)
    if snow:
        box((RW + 0.1, 0.26, 0.09), (0, DEP / 2.0 + 0.02, RIDGE_Z + 0.31), "steel")


def gables():
    """两端的马头墙：三级阶梯，每级压一道瓦檐，打破清一色的屋脊轮廓。"""
    for s in (-1, 1):
        gx = s * (W / 2.0 + 0.04)
        for (y0, y1, hh) in ((-0.16, 0.55, 3.85), (0.55, 1.55, 4.35), (1.55, 2.5, 3.9)):
            # 山墙用和瓦同色系的深灰：斜投影会在瓦面上露出它的侧面，
            # 用白墙就会变成几块白色补丁。
            box((0.26, y1 - y0, hh), (gx, (y0 + y1) / 2.0, hh / 2.0), "tile_dk")
            box((0.4, y1 - y0 + 0.1, 0.11), (gx, (y0 + y1) / 2.0, hh + 0.04), "tile")
        # 山墙侧面的一小块砖饰
        box((0.03, 0.62, 0.42), (gx + s * 0.15, 1.05, 2.5), "stone_dk")


def build(state):
    snow = state == "snow"
    glow = snow
    rnd = random.Random(7)

    # 台基、墙裙、墙面
    box((W, DEP, 0.3), (0, DEP / 2.0, 0.15), "stone")
    box((W - 0.1, DEP - 0.1, WALL_TOP - 0.3), (0, DEP / 2.0, (WALL_TOP + 0.3) / 2.0), "plaster")
    box((W + 0.12, 0.1, 0.5), (0, -0.05, 0.55), "stone_dk")
    for k in range(3):
        box((W - 0.1, 0.04, 0.03), (0, -0.11, 0.38 + k * 0.15), "stone")
    # 墙脚潮痕与零星的旧砖
    for k in range(9):
        x = rnd.uniform(-3.2, 3.2)
        box((rnd.uniform(0.14, 0.4), 0.02, rnd.uniform(0.06, 0.14)),
            (x, -0.11, rnd.uniform(0.86, 1.35)), "stone_dk")
    # 前后四根角柱和柱础
    for sx in (-1, 1):
        for sy in (-0.06, DEP - 0.04):
            box((0.17, 0.17, WALL_TOP - 0.3), (sx * 3.36, sy, (WALL_TOP + 0.3) / 2.0), "wood_dk")
            box((0.3, 0.3, 0.16), (sx * 3.36, sy, 0.38), "stone")

    # 檐枋、椽子、门上的挂落
    box((W - 0.1, 0.16, 0.17), (0, -0.06, WALL_TOP - 0.1), "wood_dk")
    for i in range(26):
        x = -3.35 + i * 0.268
        box((0.09, 0.46, 0.09), (x, -0.24, WALL_TOP - 0.02), "wood")
    for k in range(5):
        box((2.4, 0.04, 0.04), (0, -0.28, 2.62 + k * 0.09), "wood_dk")
    for k in range(7):
        box((0.04, 0.04, 0.42), (-1.05 + k * 0.35, -0.29, 2.8), "wood_dk")

    # 门：双开，带门簪、门环、门槛
    box((2.1, 0.12, 2.55), (0, -0.07, 0.3 + 1.275), "wood_dk")
    for s in (-1, 1):
        box((0.9, 0.07, 2.3), (s * 0.5, -0.14, 0.3 + 1.2), "wood")
        for zz in (0.85, 2.15):
            box((0.72, 0.03, 0.07), (s * 0.5, -0.18, zz), "wood_dk")
        box((0.6, 0.03, 0.5), (s * 0.5, -0.18, 1.75), "wood_dk")
        box((0.1, 0.05, 0.16), (s * 0.13, -0.2, 1.35), "gold")
    for k in range(2):
        box((0.22, 0.09, 0.14), (-0.32 + k * 0.64, -0.19, 2.72), "wood_dk")
    box((2.5, 0.6, 0.16), (0, -0.33, 0.08), "stone")
    box((2.2, 0.12, 0.26), (0, -0.1, 0.16), "stone_dk")
    # 匾额和门联
    box((1.9, 0.09, 0.52), (0, -0.14, 2.98), "ink")
    box((2.02, 0.06, 0.07), (0, -0.16, 3.25), "gold")
    for k in range(2):
        box((0.24, 0.03, 0.3), (-0.38 + k * 0.76, -0.2, 2.98), "gold")
    for s in (-1, 1):
        box((0.2, 0.04, 1.35), (s * 1.28, -0.13, 1.85), "red")
        for k in range(4):
            box((0.09, 0.02, 0.11), (s * 1.28, -0.16, 2.3 - k * 0.32), "gold")

    # 两扇细格窗
    lattice_window(-2.35, 1.85, 1.35, 1.05, glow)
    lattice_window(2.35, 1.85, 1.35, 1.05, glow)
    # 窗台上的一盆腊梅
    cyl(0.16, 0.2, 0.18, (-2.35, -0.22, 1.16), "clay", segs=8)
    box((0.03, 0.03, 0.3), (-2.35, -0.22, 1.42), "wood_dk")
    for dx, dz in ((-0.16, 0.2), (0.13, 0.28), (0.02, 0.4)):
        ball((0.07, 0.07, 0.07), (-2.35 + dx, -0.24, 1.45 + dz), "blossom", sub=1, upright=False)

    # 屋顶与山墙
    roof(snow)
    gables()

    # 四盏灯笼、挑出来的幌子
    for x in (-3.0, -1.55, 1.55, 3.0):
        lantern(x, -0.34, WALL_TOP - 0.12, glow)
    box((0.09, 0.09, 3.0), (3.68, -0.6, 1.5), "wood_dk")
    box((0.95, 0.06, 0.07), (3.25, -0.6, 2.95), "wood_dk")
    box((0.72, 0.04, 1.2), (3.2, -0.6, 2.3), "quilt")
    cyl(0.23, 0.23, 0.02, (3.2, -0.63, 2.3), "linen", rot=(90, 0, 0), segs=12, center=True)
    if snow:
        box((0.76, 0.05, 0.08), (3.2, -0.6, 2.92), "steel")

    # 门口的条凳、小桌和碗
    box((1.6, 0.32, 0.09), (-2.3, -0.62, 0.46), "wood")
    for s in (-0.65, 0.65):
        box((0.11, 0.28, 0.42), (-2.3 + s, -0.62, 0.23), "wood_dk")
    cyl(0.13, 0.19, 0.11, (-2.05, -0.62, 0.51), "clay", segs=8)
    box((0.03, 0.34, 0.02), (-1.78, -0.62, 0.52), "wood_dk")
    # 茶炉和铜壶
    box((0.62, 0.55, 0.55), (2.05, -0.72, 0.28), "clay")
    box((0.3, 0.04, 0.24), (2.05, -1.0, 0.22), "ink")
    if snow:
        box((0.2, 0.03, 0.14), (2.05, -1.01, 0.2), "glow:lamp")
    ball((0.16, 0.16, 0.13), (2.05, -0.72, 0.63), "iron", sub=2, upright=False)
    box((0.05, 0.2, 0.04), (2.24, -0.72, 0.68), "iron", rot=(0, 0, 22))
    # 靠墙的柴堆和竹匾
    for k in range(4):
        cyl(0.07, 0.07, 0.8, (-3.15 + k * 0.09, -0.5 - (k % 2) * 0.1, 0.1 + (k // 2) * 0.15),
            "wood_dk", segs=6, rot=(0, 90, 0))
    cyl(0.26, 0.26, 0.05, (-3.0, -0.48, 0.55), "wood_dk", rot=(74, 0, 0), segs=12, center=True)
    cyl(0.2, 0.2, 0.03, (-3.0, -0.5, 0.56), "straw", rot=(74, 0, 0), segs=12, center=True)

    if snow:
        # 台阶、门前扫出的一小路、檐下冰棱
        box((2.6, 0.24, 0.07), (0, -0.45, 0.18), "steel")
        for k in range(16):
            x = -3.3 + k * 0.44
            if abs(x) < 1.1:
                continue
            ln = rnd.uniform(0.12, 0.3)
            cyl(0.018, 0.002, ln, (x, -0.42, WALL_TOP - 0.16 - ln / 2.0), "steel",
                segs=5, rot=(180, 0, 0))


# ------------------------------------------------------------------ 渲染与像素化

CW, CH = 256, 208
OY = 176


def setup_camera():
    scene.render.resolution_x = CW * SS
    scene.render.resolution_y = CH * SS
    cam_data.ortho_scale = max(CW, CH) / PPU
    cam.location = (0.0, -60.0, (OY - CH / 2.0) / PPU)


def render(tag):
    path = os.path.join(TMP, "p_%s.png" % tag)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, hgt = img.size
    buf = np.empty(w * hgt * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return (buf.reshape(hgt, w, 4)[::-1] * 255.0 + 0.5).astype(np.uint8)


def pixelate(a):
    key = ((a[..., 0].astype(np.int32) >> 2) << 12) | ((a[..., 1].astype(np.int32) >> 2) << 6) \
        | (a[..., 2].astype(np.int32) >> 2)
    idx = LUT[key].astype(np.int32)
    idx[a[..., 3] <= 127] = -1
    hgt, w = idx.shape[0] // SS, idx.shape[1] // SS
    blocks = idx.reshape(hgt, SS, w, SS).transpose(0, 2, 1, 3).reshape(hgt, w, SS * SS)
    best = np.full((hgt, w), -1, dtype=np.int32)
    best_n = np.zeros((hgt, w), dtype=np.int32)
    for p in np.unique(idx):
        if p < 0:
            continue
        n = (blocks == p).sum(-1)
        better = n > best_n
        best[better] = p
        best_n[better] = n[better]
    cover = (blocks >= 0).sum(-1)
    out = np.zeros((hgt, w, 4), dtype=np.uint8)
    ok = cover >= (SS * SS) // 2
    out[ok, :3] = PAL_ARR[best[ok]]
    out[ok, 3] = 255
    return out


def _rgb(h):
    return np.array(hex_rgb(h), dtype=np.uint8)


def _hash(xs, ys, seed):
    v = (xs.astype(np.int64) * 73856093) ^ (ys.astype(np.int64) * 19349663) ^ (seed * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0


def _noise(xs, ys, cell, seed):
    gx, gy = xs / cell, ys / cell
    x0, y0 = np.floor(gx).astype(np.int64), np.floor(gy).astype(np.int64)
    fx, fy = gx - x0, gy - y0
    a, b = _hash(x0, y0, seed), _hash(x0 + 1, y0, seed)
    c, d = _hash(x0, y0 + 1, seed), _hash(x0 + 1, y0 + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def _is(img, h):
    return (img[..., :3] == _rgb(h)).all(-1) & (img[..., 3] > 0)


def _inner(mask):
    m = mask.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        m &= np.roll(mask, (dy, dx), (0, 1))
    return m


def texture(img):
    """与 props.py 完全相同的像素质感处理，不引入新颜色。"""
    hgt, w = img.shape[:2]
    ys, xs = np.mgrid[0:hgt, 0:w]
    out = img.copy()

    def put(mask, h):
        out[mask, :3] = _rgb(h)

    for name in ("wood", "wood_dk", "floor_a", "floor_b"):
        light, mid, dark = RAMPS[name]
        for src, dst in ((light, mid), (mid, dark)):
            m = _inner(_is(img, src))
            run = _hash(xs // 5 + (ys * 3) % 5, ys, 11) < 0.16
            put(m & run & (_hash(xs, ys, 12) < 0.85), dst)
    light, mid, dark = RAMPS["plaster"]
    m = _inner(_is(img, mid))
    put(m & (_noise(xs, ys, 7.0, 21) > 0.62), light)
    put(m & (_noise(xs, ys, 5.0, 22) < 0.2) & (_hash(xs, ys, 23) < 0.5), dark)
    for name in ("tile", "tile_hi", "stone", "stone_dk"):
        light, mid, dark = RAMPS[name]
        m = _inner(_is(img, light))
        put(m & (_hash(xs, ys, 31) < 0.07), mid)
        m = _inner(_is(img, mid))
        put(m & (_hash(xs, ys, 32) < 0.06), dark)
        put(m & (_hash(xs, ys, 33) < 0.04), light)
    # 叶子链：明暗交界抖动 + 小叶片
    chains = (
        [RAMPS["leaf"][0], RAMPS["leaf"][1], RAMPS["leaf_dk"][1], RAMPS["leaf_dk"][2]],
        list(RAMPS["willow"]), list(RAMPS["bamboo"]),
    )
    for chain in chains:
        masks = [_is(img, h) for h in chain]
        for i in range(len(chain) - 1):
            below = np.roll(masks[i + 1], -1, 0) | np.roll(masks[i + 1], -2, 0)
            put(masks[i] & below & ((xs + ys) % 2 == 0), chain[i + 1])
            inner = _inner(masks[i + 1])
            dash = (_hash(xs // 2, ys, 41 + i) < 0.09)
            put(inner & dash, chain[i])
            put(_inner(masks[i]) & (_hash(xs // 2, ys, 51 + i) < 0.05), chain[i + 1])
    # 草席：竖向编织纹（竹匾用得到）
    light, mid, dark = RAMPS["straw"]
    m = _inner(_is(img, light))
    put(m & (xs % 3 == 0) & (_hash(xs, ys // 2, 61) < 0.7), mid)
    # 被面：细密布纹（幌子用得到）
    light, mid, dark = RAMPS["quilt"]
    m = _inner(_is(img, light))
    put(m & ((xs + ys) % 4 == 0), mid)
    return out


def outline(a):
    out = a.copy()
    solid = a[..., 3] > 127
    done = solid.copy()
    f = a[..., :3].astype(np.float32) / 255.0
    dark = np.stack([f[..., 0] * 0.36 + 0.03, f[..., 1] * 0.30 + 0.01, f[..., 2] * 0.38 + 0.06], -1)
    dark = (dark * 255.0 + 0.5).astype(np.uint8)
    for dy, dx in ((1, 0), (0, -1), (0, 1), (-1, 0)):
        nb_solid = np.roll(solid, (-dy, -dx), (0, 1))
        nb_dark = np.roll(dark, (-dy, -dx), (0, 1))
        take = nb_solid & ~done
        out[take, :3] = nb_dark[take]
        out[take, 3] = 255
        done |= take
    return out


def save_png(arr, path):
    hgt, w = arr.shape[:2]
    img = bpy.data.images.new("out", w, hgt, alpha=True)
    img.pixels.foreach_set((arr[::-1].astype(np.float32) / 255.0).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def crop_to_content(img):
    ys, xs = np.nonzero(img[..., 3])
    if len(ys) == 0:
        return img
    return img[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def main():
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    # 渲染中途抛异常也要收掉临时目录，别在 tools/ 里留垃圾
    atexit.register(shutil.rmtree, TMP, ignore_errors=True)
    setup_camera()
    for state in ("day", "snow"):
        clear_current()
        TONE.clear()
        if state == "snow":
            # 墙和木头换到同色系更冷更暗的一档；瓦面主体保留、只压暗亮片，
            # 免得夜里糊成一片黑。雪（steel）、窗光和灯芯（glow:*）、
            # 灯笼（red）不映射，冷暖对比才出得来。
            TONE.update({
                "plaster": "stone", "wood": "wood_dk", "stone": "stone_dk",
                "stone_dk": "tile_dk", "tile_hi": "tile_dk",
            })
        build(state)
        print("SHOWCASE building", state, "objects", len(CURRENT), flush=True)
        raw = render(state)
        final = outline(texture(pixelate(raw)))
        final = crop_to_content(final)
        save_png(final, os.path.join(OUT_DIR, "showcase_%s.png" % state))
        if state == "day":
            # 原始 3D 渲染缩到一半存一张，用来证明不是 2D 画的
            save_png(raw[::2, ::2], os.path.join(OUT_DIR, "showcase_raw_day.png"))
        print("SHOWCASE rendered", state, final.shape[1], "x", final.shape[0], flush=True)


main()
