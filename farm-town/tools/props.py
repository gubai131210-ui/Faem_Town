"""用 Blender 生成大件的静态物件（房子、家具、栅栏、灌木、石头……；树是脚本画的，见 art_gen/pixel_art.gd），渲染后加一遍像素纹理和描边。
图标、花草、作物这类 16 像素以内的小东西不在这里，由 art_gen/pixel_art.gd 直接画。

用法:  blender --background --python tools/props.py -- [物件名 ...]
       不写物件名就全部重新生成；写了就只更新这几个
输出:  art/props/<名字>.png   每个物件一张图，已裁到内容大小
       art/props/props.json   每张图里“锚点”的像素位置（物件脚下的参考点）
颜色全部来自 data/palette.json 的 ramps（亮/中/暗三段）。

投影方式：俯视斜投影。模型的纵深 y 每增加 1，画面上就上移 1，
所以占地 1x1 的东西在画面上正好盖住一个 16x16 的格子，高度也是 1:1。
灌木、石头这类不规则的东西不做斜切（upright），按正面画。
单位：1 = 一格 = 16 像素。x 向右，y 向远处，z 向上。
"""
import json
import math
import os
import random
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TMP = os.path.join(HERE, "_tmp")
OUT_DIR = os.path.join(PROJ, "art", "props")
OUT_JSON = os.path.join(OUT_DIR, "props.json")

PPU = 16
SS = 4              # 超采样倍数，缩小时每块取出现最多的颜色
T_DARK = 0.3        # 受光低于这个值用暗色
T_LIGHT = 0.7       # 高于这个值用亮色

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

# 把渲染出的颜色（每通道取高 6 位）映射到最近的调色板颜色
_levels = (np.arange(64, dtype=np.int32) * 4 + 2)
_grid = np.stack(np.meshgrid(_levels, _levels, _levels, indexing="ij"), -1).reshape(-1, 3)
LUT = np.empty(len(_grid), dtype=np.int16)
for _i in range(0, len(_grid), 8192):
    _chunk = _grid[_i:_i + 8192]
    LUT[_i:_i + 8192] = ((_chunk[:, None, :] - PAL_ARR[None, :, :]) ** 2).sum(-1).argmin(-1)


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
# 光从左前上方来：顶面最亮，正面中等，右侧和背光处最暗
sun.rotation_euler = Vector((0.45, 0.55, -0.7)).to_track_quat("-Z", "Y").to_euler()


def make_mat(name):
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


MATS = {n: make_mat(n) for n in RAMPS}


# ------------------------------------------------------------------ 建模工具

SHEAR = Matrix.Identity(4)
SHEAR[2][1] = 1.0
CURRENT = []
# 图标要塞进 16x16，整体缩小一点
PART_SCALE = 1.0


def _emit(bm, loc, rot, scale, mat, smooth, upright):
    local = (Matrix.Translation(loc)
             @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
             @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0)))
    outer = Matrix.Translation((0.0, 0.0, loc[1])) if upright else SHEAR
    bmesh.ops.transform(bm, matrix=Matrix.Scale(PART_SCALE, 4) @ outer @ local, verts=bm.verts)
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
    me.materials.append(MATS[mat])
    ob = bpy.data.objects.new("part", me)
    scene.collection.objects.link(ob)
    CURRENT.append(ob)
    return ob


def box(size, loc, mat, rot=(0, 0, 0), upright=False):
    """长方体，loc 是中心。"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    return _emit(bm, loc, rot, size, mat, False, upright)


def cyl(r1, r2, h, loc, mat, rot=(0, 0, 0), segs=12, upright=False, center=False):
    """圆柱或圆台，默认 loc 是底面中心；center 为真时 loc 是几何中心。"""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r1, radius2=max(r2, 0.0001), depth=h)
    if not center:
        bmesh.ops.translate(bm, vec=(0, 0, h / 2.0), verts=bm.verts)
    return _emit(bm, loc, rot, (1, 1, 1), mat, True, upright)


def ball(radii, loc, mat, rot=(0, 0, 0), upright=True, sub=3, smooth=True):
    """椭球，loc 是中心。默认不斜切。"""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    return _emit(bm, loc, rot, radii, mat, smooth, upright)


def clear_current():
    for ob in CURRENT:
        me = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(me)
    CURRENT.clear()


# ------------------------------------------------------------------ 室外：房子

def lattice_window(x, y, z, paper="paper", w=1.125, h=0.9375):
    box((w + 0.25, 0.08, h + 0.25), (x, y, z), "wood_dk")
    box((w, 0.04, h), (x, y - 0.04, z), paper)
    for i in (-1, 0, 1):
        box((0.0625, 0.03, h), (x + i * w / 4.0, y - 0.07, z), "wood_dk")
    for j in (-1, 1):
        box((w, 0.03, 0.0625), (x, y - 0.07, z + j * h / 4.0), "wood_dk")
    box((w + 0.4, 0.14, 0.09), (x, y - 0.05, z - h / 2.0 - 0.15), "wood")


def house():
    """白墙黛瓦的老屋。锚点是正面墙根的中点，占地 6 格宽。"""
    w, dep, wall_top = 6.0, 2.4, 3.0
    box((w, dep, 0.3), (0, dep / 2, 0.15), "stone")
    box((w - 0.1, dep - 0.1, wall_top - 0.3), (0, dep / 2, (wall_top + 0.3) / 2), "plaster")

    over, rise = 0.3, 1.0
    half = dep / 2 + over
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    ar = math.radians(a)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((6.9, length + 0.05, 0.12), (0, cy, cz), "tile", rot=(a * sgn, 0, 0))
        ny, nz = -math.sin(ar) * sgn, math.cos(ar)
        for i in range(14):
            x = -3.25 + i * 0.5
            cyl(0.11, 0.11, length, (x, cy + ny * 0.08, cz + nz * 0.08), "tile_hi",
                rot=(a * sgn - 90.0, 0, 0), segs=8, center=True)
        # 一排排瓦片之间的横缝
        for k in range(1, 5):
            t = (k / 5.0 - 0.5) * length
            box((6.9, 0.05, 0.05), (0, cy + math.cos(ar) * t + ny * 0.07, cz + math.sin(ar) * t * sgn + nz * 0.07),
                "tile_dk", rot=(a * sgn, 0, 0))
    box((6.9, 0.14, 0.2), (0, -over - 0.02, wall_top - 0.03), "tile_dk")
    ridge_z = wall_top + rise
    box((7.0, 0.3, 0.3), (0, dep / 2, ridge_z + 0.15), "tile_dk")
    box((7.0, 0.12, 0.08), (0, dep / 2 - 0.08, ridge_z + 0.32), "tile_hi")
    for sx in (-1, 1):
        box((0.6, 0.3, 0.22), (3.62 * sx, dep / 2, ridge_z + 0.3), "tile_dk", rot=(0, -30 * sx, 0))
    box((w - 0.1, 0.1, 0.16), (0, -0.04, wall_top - 0.08), "wood_dk")

    # 门
    box((1.9, 0.1, 2.45), (0, -0.03, 1.525), "wood_dk")
    for sx in (-1, 1):
        box((0.8, 0.06, 2.2), (0.42 * sx, -0.09, 1.4), "wood")
        box((0.56, 0.03, 0.06), (0.42 * sx, -0.125, 2.1), "wood_dk")
        box((0.56, 0.03, 0.06), (0.42 * sx, -0.125, 0.75), "wood_dk")
        box((0.1, 0.05, 0.16), (0.12 * sx, -0.13, 1.4), "gold")
    box((2.5, 0.55, 0.16), (0, -0.27, 0.08), "stone")
    box((2.0, 0.12, 0.3), (0, -0.06, 0.15), "stone_dk")
    # 对联
    for sx in (-1, 1):
        box((0.22, 0.04, 1.6), (1.12 * sx, -0.04, 1.6), "red")
        for k in range(4):
            box((0.09, 0.02, 0.12), (1.12 * sx, -0.07, 2.1 - k * 0.34), "gold")

    lattice_window(-2.02, -0.03, 1.75, w=0.9375, h=1.0)
    lattice_window(2.02, -0.03, 1.75, w=0.9375, h=1.0)

    # 檐下的灯笼
    for sx in (-1, 1):
        lx, ly, top = 1.47 * sx, -0.3, wall_top - 0.1
        box((0.04, 0.04, 0.3), (lx, ly, top - 0.15), "ink")
        cyl(0.1, 0.1, 0.06, (lx, ly, top - 0.36), "gold")
        cyl(0.13, 0.2, 0.16, (lx, ly, top - 0.52), "red")
        cyl(0.2, 0.13, 0.18, (lx, ly, top - 0.7), "red")
        cyl(0.1, 0.1, 0.05, (lx, ly, top - 0.75), "gold")
        box((0.05, 0.03, 0.22), (lx, ly, top - 0.86), "red")

def mailbox():
    """带小瓦顶的木信箱。锚点在柱脚。"""
    box((0.14, 0.14, 0.85), (0, 0, 0.425), "wood_dk")
    box((0.62, 0.42, 0.42), (0, 0, 1.02), "wood")
    box((0.36, 0.03, 0.07), (0, -0.22, 1.08), "ink")
    box((0.16, 0.03, 0.12), (0, -0.22, 0.93), "paper")
    for sx in (-1, 1):
        box((0.5, 0.6, 0.07), (0.22 * sx, 0, 1.3), "tile", rot=(0, 16 * sx, 0))
    box((0.1, 0.64, 0.08), (0, 0, 1.38), "tile_dk")
    box((0.05, 0.04, 0.3), (0.36, -0.1, 1.2), "red")
    box((0.16, 0.04, 0.12), (0.42, -0.1, 1.32), "red")


def stone_lamp():
    """石灯。锚点在底座中心。"""
    box((0.7, 0.7, 0.16), (0, 0, 0.08), "stone_dk")
    cyl(0.16, 0.13, 0.7, (0, 0, 0.16), "stone", segs=8)
    box((0.56, 0.56, 0.1), (0, 0, 0.9), "stone")
    box((0.42, 0.42, 0.34), (0, 0, 1.12), "stone")
    box((0.2, 0.03, 0.2), (0, -0.22, 1.12), "ink")
    cyl(0.5, 0.12, 0.26, (0, 0, 1.29), "stone_dk", segs=4, rot=(0, 0, 45))
    ball((0.09, 0.09, 0.09), (0, 0, 1.6), "stone")


# ------------------------------------------------------------------ 镇上的房子

def lantern(lx, ly, top):
    box((0.04, 0.04, 0.3), (lx, ly, top - 0.15), "ink")
    cyl(0.1, 0.1, 0.06, (lx, ly, top - 0.36), "gold")
    cyl(0.13, 0.2, 0.16, (lx, ly, top - 0.52), "red")
    cyl(0.2, 0.13, 0.18, (lx, ly, top - 0.7), "red")
    cyl(0.1, 0.1, 0.05, (lx, ly, top - 0.75), "gold")
    box((0.05, 0.03, 0.22), (lx, ly, top - 0.86), "red")


def shell(w, dep=2.4, wall_top=3.0, rise=1.0, wall="plaster"):
    """一栋房子的台基、墙和瓦顶。锚点是正面墙根的中点。"""
    box((w, dep, 0.3), (0, dep / 2, 0.15), "stone")
    box((w - 0.1, dep - 0.1, wall_top - 0.3), (0, dep / 2, (wall_top + 0.3) / 2), wall)
    over = 0.3
    rw = w + 0.9
    half = dep / 2 + over
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    ar = math.radians(a)
    ribs = int(rw / 0.5)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((rw, length + 0.05, 0.12), (0, cy, cz), "tile", rot=(a * sgn, 0, 0))
        ny, nz = -math.sin(ar) * sgn, math.cos(ar)
        for i in range(ribs + 1):
            x = -ribs * 0.25 + i * 0.5
            cyl(0.11, 0.11, length, (x, cy + ny * 0.08, cz + nz * 0.08), "tile_hi",
                rot=(a * sgn - 90.0, 0, 0), segs=8, center=True)
        for k in range(1, 5):
            t = (k / 5.0 - 0.5) * length
            box((rw, 0.05, 0.05), (0, cy + math.cos(ar) * t + ny * 0.07, cz + math.sin(ar) * t * sgn + nz * 0.07),
                "tile_dk", rot=(a * sgn, 0, 0))
    box((rw, 0.14, 0.2), (0, -over - 0.02, wall_top - 0.03), "tile_dk")
    ridge_z = wall_top + rise
    box((rw + 0.1, 0.3, 0.3), (0, dep / 2, ridge_z + 0.15), "tile_dk")
    box((rw + 0.1, 0.12, 0.08), (0, dep / 2 - 0.08, ridge_z + 0.32), "tile_hi")
    for sx in (-1, 1):
        box((0.6, 0.3, 0.22), ((rw / 2 + 0.17) * sx, dep / 2, ridge_z + 0.3), "tile_dk", rot=(0, -30 * sx, 0))
    box((w - 0.1, 0.1, 0.16), (0, -0.04, wall_top - 0.08), "wood_dk")


def door(x=0.0, w=1.9, h=2.45, step=True):
    """双开的木门，x 是门的中线。"""
    box((w, 0.1, h), (x, -0.03, 0.3 + h / 2), "wood_dk")
    leaf = (w - 0.3) / 2
    for sx in (-1, 1):
        box((leaf, 0.06, h - 0.25), (x + (leaf / 2 + 0.02) * sx, -0.09, 0.3 + (h - 0.25) / 2), "wood")
        box((leaf * 0.7, 0.03, 0.06), (x + (leaf / 2 + 0.02) * sx, -0.125, h - 0.35), "wood_dk")
        box((leaf * 0.7, 0.03, 0.06), (x + (leaf / 2 + 0.02) * sx, -0.125, 0.75), "wood_dk")
        box((0.1, 0.05, 0.16), (x + 0.12 * sx, -0.13, 1.4), "gold")
    if step:
        box((w + 0.6, 0.55, 0.16), (x, -0.27, 0.08), "stone")
        box((w + 0.1, 0.12, 0.3), (x, -0.06, 0.15), "stone_dk")


def plaque(x, z, w=1.5, mat="wood_dk", marks=3):
    """门上的匾：深色木板上几个金字。"""
    box((w, 0.08, 0.5), (x, -0.1, z), mat)
    box((w + 0.12, 0.06, 0.08), (x, -0.1, z + 0.27), "gold")
    for k in range(marks):
        mx = x + (k - (marks - 1) / 2.0) * (w / (marks + 0.6))
        box((0.2, 0.03, 0.26), (mx, -0.15, z), "gold")


def banner(x, z, mat, h=1.5, marks=3):
    """竖着挂的布幌子。"""
    box((0.5, 0.05, 0.06), (x, -0.22, z + h / 2 + 0.04), "wood_dk")
    box((0.4, 0.03, h), (x, -0.22, z), mat)
    for k in range(marks):
        box((0.2, 0.02, 0.2), (x, -0.245, z + h / 2 - 0.3 - k * (h - 0.5) / max(1, marks - 1)), "paper")


def basket(x, y, fill):
    cyl(0.26, 0.32, 0.3, (x, y, 0.0), "straw", segs=10)
    for dx, dy in ((-0.1, 0.05), (0.12, 0.0), (0.0, -0.1), (0.02, 0.12)):
        ball((0.12, 0.12, 0.1), (x + dx, y + dy, 0.34), fill, sub=2, upright=False)


def shop_grocery():
    """杂货铺：左边是门，右边是敞开的柜台和布棚，门口摆着几筐菜。占地 5 格宽。"""
    shell(5.0)
    door(-1.35, w=1.5, h=2.3)
    plaque(-1.35, 2.72, w=1.3, marks=3)
    # 柜台：墙上开一个口，里面是暗的，摆着货架
    box((2.3, 0.1, 1.5), (1.05, -0.03, 1.75), "wood_dk")
    box((2.1, 0.06, 1.3), (1.05, -0.06, 1.75), "ink")
    for k, mat in enumerate(("clay", "jade", "sack", "clay", "petal_y")):
        cyl(0.13, 0.11, 0.26, (0.25 + k * 0.4, -0.08, 1.75), mat, segs=8)
    box((2.1, 0.04, 0.06), (1.05, -0.09, 1.72), "wood")
    box((2.5, 0.5, 0.12), (1.05, -0.25, 1.04), "wood")
    box((2.3, 0.08, 0.7), (1.05, -0.06, 0.65), "wood_dk")
    # 布棚
    box((2.7, 0.75, 0.06), (1.05, -0.42, 2.62), "red", rot=(-24, 0, 0))
    for k in range(4):
        box((0.3, 0.76, 0.07), (0.15 + k * 0.6, -0.43, 2.63), "linen", rot=(-24, 0, 0))
    for sx in (-0.2, 2.3):
        box((0.06, 0.06, 2.1), (sx, -0.72, 1.05), "wood_dk")
    basket(-0.25, -0.38, "red")
    basket(0.45, -0.5, "leaf")
    lantern(-2.25, -0.3, 2.9)


def shop_herb():
    """药铺：门居中，两边是格子窗，挂着葫芦和绿幌子，门口晒着药材。占地 5 格宽。"""
    shell(5.0)
    door(0.0, w=1.6, h=2.3)
    plaque(0.0, 2.72, w=1.4, mat="ink", marks=3)
    lattice_window(-1.7, -0.03, 1.75, w=0.8, h=0.95)
    lattice_window(1.7, -0.03, 1.75, w=0.8, h=0.95)
    banner(2.3, 1.55, "jade", h=1.5, marks=2)
    # 葫芦
    box((0.03, 0.03, 0.4), (-2.3, -0.3, 2.7), "ink")
    ball((0.12, 0.12, 0.12), (-2.3, -0.3, 2.42), "petal_y", sub=2, upright=False)
    ball((0.18, 0.18, 0.18), (-2.3, -0.3, 2.18), "petal_y", sub=2, upright=False)
    box((0.06, 0.04, 0.2), (-2.3, -0.3, 1.92), "red")
    # 晒药的竹匾
    for x, fill in ((-1.6, "leaf_dk"), (1.55, "clay")):
        box((0.9, 0.5, 0.5), (x, -0.36, 0.25), "wood_dk")
        cyl(0.48, 0.48, 0.06, (x, -0.36, 0.5), "straw", segs=12)
        cyl(0.36, 0.36, 0.03, (x, -0.36, 0.56), fill, segs=10)


def teahouse():
    """茶馆兼饭馆：比别家宽，一排灯笼，蓝布幌子，门口一张条凳。占地 7 格宽。"""
    shell(7.0, wall_top=3.2)
    door(0.0, w=2.2, h=2.5)
    plaque(0.0, 2.95, w=1.8, marks=2)
    lattice_window(-2.3, -0.03, 1.8, w=1.3, h=1.0)
    lattice_window(2.3, -0.03, 1.8, w=1.3, h=1.0)
    for x in (-3.0, -1.5, 1.5, 3.0):
        lantern(x, -0.3, 3.1)
    # 挑出来的幌子
    box((0.08, 0.08, 2.9), (3.6, -0.5, 1.45), "wood_dk")
    box((0.9, 0.05, 0.06), (3.2, -0.5, 2.85), "wood_dk")
    box((0.7, 0.03, 1.1), (3.15, -0.5, 2.25), "quilt")
    cyl(0.22, 0.22, 0.02, (3.15, -0.53, 2.25), "linen", rot=(90, 0, 0), segs=12, center=True)
    # 条凳和小桌
    box((1.5, 0.3, 0.08), (-2.3, -0.5, 0.42), "wood")
    for sx in (-0.6, 0.6):
        box((0.1, 0.26, 0.4), (-2.3 + sx, -0.5, 0.2), "wood_dk")


def smithy():
    """铁匠铺：石墙，敞着的大门里透出炉火，屋顶有烟囱，门外是铁砧和水桶。占地 5 格宽。"""
    shell(5.0, wall="stone")
    # 敞开的门洞
    box((2.4, 0.1, 2.4), (-0.6, -0.03, 1.5), "wood_dk")
    box((2.1, 0.06, 2.15), (-0.6, -0.06, 1.38), "ink")
    box((0.9, 0.04, 0.7), (-0.9, -0.08, 0.8), "stone_dk")
    box((0.6, 0.03, 0.34), (-0.9, -0.1, 0.72), "ember")
    box((0.3, 0.03, 0.2), (-0.9, -0.11, 0.95), "ember")
    box((2.6, 0.5, 0.14), (-0.6, -0.25, 0.07), "stone_dk")
    plaque(-0.6, 2.86, w=1.2, mat="ink", marks=2)
    # 墙上挂的工具
    for k, (hh, mat) in enumerate(((0.9, "iron"), (0.7, "steel"), (0.8, "iron"))):
        box((0.06, 0.04, hh), (1.2 + k * 0.4, -0.06, 1.9 - hh / 2), "wood_dk")
        box((0.24, 0.05, 0.16), (1.2 + k * 0.4, -0.07, 1.9), mat)
    box((1.3, 0.05, 0.08), (1.6, -0.05, 2.0), "wood_dk")
    # 烟囱
    box((0.7, 0.7, 1.5), (1.5, 1.7, 3.9), "stone_dk")
    box((0.86, 0.86, 0.14), (1.5, 1.7, 4.68), "stone")
    # 铁砧和水桶
    box((0.5, 0.4, 0.4), (1.1, -0.45, 0.2), "wood_dk")
    box((0.7, 0.3, 0.16), (1.1, -0.45, 0.48), "iron")
    box((0.3, 0.2, 0.1), (1.5, -0.45, 0.5), "iron")
    cyl(0.28, 0.32, 0.5, (2.0, -0.42, 0.0), "wood", segs=10)
    cyl(0.26, 0.26, 0.02, (2.0, -0.42, 0.49), "quilt", segs=10)
    cyl(0.33, 0.33, 0.05, (2.0, -0.42, 0.3), "iron", segs=10)


def boathouse():
    """老周的船屋：木板墙的矮屋，草顶，门口挂着渔网和两支桨，檐下晾着鱼。占地 4 格宽。"""
    w, dep, wall_top = 4.0, 2.2, 2.3
    box((w, dep, 0.3), (0, dep / 2, 0.15), "stone_dk")
    box((w - 0.1, dep - 0.1, wall_top - 0.3), (0, dep / 2, (wall_top + 0.3) / 2), "wood")
    # 板墙的横缝
    for k in range(4):
        box((w - 0.05, 0.03, 0.05), (0, -0.03, 0.6 + k * 0.42), "wood_dk")
    # 草顶：两坡
    over, rise = 0.45, 0.9
    half = dep / 2 + over
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((w + 0.9, length + 0.1, 0.26), (0, cy, cz), "straw", rot=(a * sgn, 0, 0))
    box((w + 1.0, 0.3, 0.26), (0, dep / 2, wall_top + rise + 0.1), "wood_dk")
    # 门：单扇，开着一条缝
    box((1.1, 0.1, 1.7), (-0.9, -0.03, 0.3 + 0.85), "wood_dk")
    box((0.5, 0.06, 1.55), (-1.15, -0.09, 0.3 + 0.78), "wood")
    box((0.5, 0.06, 1.55), (-0.65, -0.09, 0.3 + 0.78), "ink")
    # 墙上挂的渔网：一张斜着的方格
    for k in range(5):
        box((1.2, 0.03, 0.03), (0.9, -0.08, 0.7 + k * 0.28), "linen")
    for k in range(5):
        box((0.03, 0.03, 1.2), (0.3 + k * 0.3, -0.08, 1.26), "linen")
    for k in range(3):
        ball((0.07, 0.07, 0.07), (0.45 + k * 0.45, -0.12, 0.62), "clay", sub=1)
    # 两支桨靠在墙边
    for k, lean in enumerate((8.0, 14.0)):
        cyl(0.04, 0.04, 2.0, (1.75 + k * 0.18, -0.2, 0.3), "wood_dk", rot=(0, lean, 0), segs=6)
        box((0.16, 0.05, 0.5), (1.75 + k * 0.18 + 0.28, -0.2, 2.1), "wood_dk", rot=(0, lean, 0))
    # 檐下晾的鱼
    box((2.2, 0.03, 0.03), (-0.5, -0.32, wall_top - 0.05), "ink")
    for k in range(4):
        fx = -1.3 + k * 0.55
        box((0.02, 0.02, 0.2), (fx, -0.32, wall_top - 0.15), "ink")
        ball((0.1, 0.05, 0.28), (fx, -0.32, wall_top - 0.5), "steel", sub=2)
    # 门前堆的木桶和鱼篓
    cyl(0.28, 0.3, 0.5, (-1.7, -0.45, 0.0), "wood", segs=10)
    cyl(0.33, 0.33, 0.05, (-1.7, -0.45, 0.3), "iron", segs=10)
    basket(1.2, -0.5, "steel")


def coop():
    """鸡舍：木板墙的矮屋，草顶，正面开一扇小门和一排透气的格栅，门口一截斜坡。占地 4 格宽、2 格深。"""
    w, dep, wall_top = 4.0, 2.0, 1.7
    box((w, dep, 0.25), (0, dep / 2, 0.125), "stone_dk")
    box((w - 0.1, dep - 0.1, wall_top - 0.25), (0, dep / 2, (wall_top + 0.25) / 2), "wood")
    for k in range(3):
        box((w - 0.05, 0.03, 0.05), (0, -0.03, 0.55 + k * 0.4), "wood_dk")
    # 草顶
    over, rise = 0.4, 0.8
    half = dep / 2 + over
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((w + 0.8, length + 0.1, 0.24), (0, cy, cz), "straw", rot=(a * sgn, 0, 0))
    box((w + 0.9, 0.3, 0.24), (0, dep / 2, wall_top + rise + 0.1), "wood_dk")
    # 小门：一扇板门，门口搭一块斜坡板
    box((0.9, 0.1, 1.0), (-1.1, -0.03, 0.25 + 0.5), "wood_dk")
    box((0.7, 0.06, 0.85), (-1.1, -0.09, 0.25 + 0.45), "ink")
    box((0.8, 0.7, 0.05), (-1.1, -0.4, 0.14), "wood", rot=(-18, 0, 0))
    # 右边一排透气的木格栅
    box((1.7, 0.08, 0.7), (0.85, -0.03, 1.05), "ink")
    for k in range(5):
        box((0.05, 0.1, 0.7), (0.2 + k * 0.33, -0.05, 1.05), "wood")
    box((1.7, 0.1, 0.06), (0.85, -0.05, 1.05), "wood")
    # 檐下挂一串玉米，门边一个食槽
    for k in range(3):
        ball((0.07, 0.07, 0.14), (1.4 + k * 0.17, -0.3, wall_top - 0.3), "gold", sub=1)
    box((0.9, 0.3, 0.2), (0.6, -0.5, 0.1), "wood_dk")
    box((0.8, 0.22, 0.05), (0.6, -0.5, 0.21), "straw")


def scaffold():
    """盖房子的工地：几根竖起来的木桩和横梁，地上堆着木板和草捆。和鸡舍一样 4 格宽。"""
    w, dep = 4.0, 2.0
    box((w, dep, 0.25), (0, dep / 2, 0.125), "stone_dk")
    for x in (-1.8, 0.0, 1.8):
        for y in (0.15, dep - 0.15):
            cyl(0.07, 0.07, 1.9, (x, y, 0.25), "wood_dk", segs=6)
    for y in (0.15, dep - 0.15):
        box((w, 0.1, 0.1), (0, y, 2.1), "wood")
    box((0.1, dep, 0.1), (-1.8, dep / 2, 2.1), "wood")
    box((0.1, dep, 0.1), (1.8, dep / 2, 2.1), "wood")
    # 斜撑
    box((0.08, 0.08, 1.6), (-0.9, 0.12, 1.1), "wood", rot=(0, 40, 0))
    # 地上的木板堆和草捆
    for k in range(4):
        box((1.6, 0.4, 0.08), (0.9 - k * 0.05, -0.45 + k * 0.03, 0.29 + k * 0.08), "wood")
    cyl(0.3, 0.3, 0.7, (-1.2, -0.5, 0.0), "straw", segs=10, rot=(0, 90, 0))
    cyl(0.3, 0.3, 0.7, (-1.2, -0.5, 0.52), "straw", segs=10, rot=(0, 90, 0))
    # 锯木架上一根料
    for x in (-0.3, 0.5):
        box((0.06, 0.5, 0.5), (x, -0.9, 0.25), "wood_dk")
    box((1.4, 0.14, 0.14), (0.1, -0.9, 0.55), "wood")


def _thatch(w, dep, wall_top, rise, over=0.45):
    half = dep / 2 + over
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((w + 0.9, length + 0.1, 0.26), (0, cy, cz), "straw", rot=(a * sgn, 0, 0))
    box((w + 1.0, 0.3, 0.26), (0, dep / 2, wall_top + rise + 0.1), "wood_dk")


def barn():
    """畜棚：比鸡舍高大的木板棚，草顶，正中一扇对开的大门，门上一个草料口，旁边堆着草垛和水槽。占地 6 格宽。"""
    w, dep, wall_top = 6.0, 2.4, 2.5
    box((w, dep, 0.3), (0, dep / 2, 0.15), "stone_dk")
    box((w - 0.1, dep - 0.1, wall_top - 0.3), (0, dep / 2, (wall_top + 0.3) / 2), "wood")
    for k in range(5):
        box((w - 0.05, 0.03, 0.05), (0, -0.03, 0.6 + k * 0.4), "wood_dk")
    for sx in (-1, 1):
        box((0.16, 0.12, wall_top - 0.3), ((w / 2 - 0.1) * sx, -0.03, (wall_top + 0.3) / 2), "wood_dk")
    _thatch(w, dep, wall_top, 1.1)
    # 大门：对开，一扇半掩，里面是暗的
    box((2.3, 0.1, 1.9), (0, -0.03, 0.3 + 0.95), "wood_dk")
    box((1.0, 0.06, 1.75), (-0.55, -0.09, 0.3 + 0.88), "red")
    box((0.9, 0.04, 0.07), (-0.55, -0.13, 1.7), "wood_dk")
    box((0.9, 0.04, 0.07), (-0.55, -0.13, 0.7), "wood_dk")
    box((1.0, 0.06, 1.75), (0.55, -0.09, 0.3 + 0.88), "ink")
    box((0.35, 0.06, 1.75), (0.92, -0.11, 0.3 + 0.88), "red")
    # 门楣上的草料口
    box((0.9, 0.08, 0.5), (0, -0.03, wall_top + 0.25), "wood_dk")
    box((0.7, 0.06, 0.36), (0, -0.07, wall_top + 0.25), "straw")
    # 两边的小窗
    for sx in (-1, 1):
        box((0.8, 0.08, 0.6), (2.1 * sx, -0.03, 1.6), "ink")
        box((0.9, 0.1, 0.06), (2.1 * sx, -0.05, 1.6), "wood")
        box((0.06, 0.1, 0.6), (2.1 * sx, -0.05, 1.6), "wood")
    # 草垛、水槽、靠墙的草叉
    cyl(0.4, 0.4, 0.8, (-2.3, -0.55, 0.0), "straw", segs=10, rot=(0, 90, 0))
    cyl(0.4, 0.4, 0.8, (-2.3, -0.55, 0.7), "straw", segs=10, rot=(0, 90, 0))
    box((1.2, 0.4, 0.3), (2.0, -0.5, 0.15), "wood_dk")
    box((1.05, 0.28, 0.04), (2.0, -0.5, 0.31), "can")
    cyl(0.03, 0.03, 1.7, (1.2, -0.15, 0.3), "wood_dk", rot=(0, 8, 0), segs=6)


def apiary():
    """蜂场：矮架子上并排三只蜂箱，各戴一顶草帽似的盖子。占地 3 格宽。"""
    box((2.8, 0.7, 0.12), (0, 0.35, 0.3), "wood_dk")
    for x in (-1.25, 1.25):
        box((0.12, 0.6, 0.3), (x, 0.35, 0.15), "wood_dk")
    for k, x in enumerate((-0.9, 0.0, 0.9)):
        box((0.7, 0.6, 0.6), (x, 0.35, 0.66), "paper" if k != 1 else "gold")
        box((0.72, 0.03, 0.04), (x, 0.03, 0.66), "wood_dk")
        box((0.3, 0.04, 0.06), (x, 0.03, 0.42), "ink")
        cyl(0.44, 0.05, 0.2, (x, 0.35, 0.96), "straw", segs=10)


def silk_house():
    """蚕房：白墙瓦顶的小屋，门在左边，右边一扇格子窗，门口架子上摆着几只养蚕的竹匾。占地 4 格宽。"""
    shell(4.0, dep=2.2, wall_top=2.5, rise=0.85)
    door(-1.0, w=1.3, h=1.9)
    lattice_window(0.95, -0.03, 1.6, w=0.9, h=0.8)
    # 竹匾架子：三层
    for sx in (0.35, 1.65):
        box((0.06, 0.06, 1.0), (sx, -0.55, 0.5), "wood_dk")
    for k in range(3):
        cyl(0.55, 0.55, 0.05, (1.0, -0.55, 0.25 + k * 0.33), "straw", segs=12)
        cyl(0.42, 0.42, 0.03, (1.0, -0.55, 0.31 + k * 0.33), "leaf", segs=10)
    # 墙边一筐桑叶
    basket(-1.75, -0.4, "leaf_dk")


def scaffold_of(w):
    """盖房子的工地：几根竖起来的木桩和横梁，地上堆着木板和草捆。w 是几格宽。"""
    def build():
        dep = 2.0
        box((w, dep, 0.25), (0, dep / 2, 0.125), "stone_dk")
        posts = [-(w / 2 - 0.2), 0.0, w / 2 - 0.2]
        for x in posts:
            for y in (0.15, dep - 0.15):
                cyl(0.07, 0.07, 1.9, (x, y, 0.25), "wood_dk", segs=6)
        for y in (0.15, dep - 0.15):
            box((w, 0.1, 0.1), (0, y, 2.1), "wood")
        for x in (posts[0], posts[2]):
            box((0.1, dep, 0.1), (x, dep / 2, 2.1), "wood")
        box((0.08, 0.08, 1.6), (posts[0] / 2, 0.12, 1.1), "wood", rot=(0, 40, 0))
        for k in range(4):
            box((min(1.6, w * 0.4), 0.4, 0.08), (w * 0.22 - k * 0.05, -0.45 + k * 0.03, 0.29 + k * 0.08), "wood")
        cyl(0.3, 0.3, 0.7, (-w * 0.3, -0.5, 0.0), "straw", segs=10, rot=(0, 90, 0))
        if w >= 4:
            cyl(0.3, 0.3, 0.7, (-w * 0.3, -0.5, 0.52), "straw", segs=10, rot=(0, 90, 0))
    return build


# ------------------------------------------------------------------ 加工设备（各占 1 格，锚点是底面中点）

def pickle_vat():
    """腌缸：一口大陶缸，压着石头的木盖。"""
    cyl(0.3, 0.44, 0.4, (0, 0.4, 0.0), "clay")
    cyl(0.44, 0.36, 0.42, (0, 0.4, 0.4), "clay")
    cyl(0.4, 0.4, 0.07, (0, 0.4, 0.82), "wood", segs=12)
    ball((0.2, 0.16, 0.12), (0.03, 0.4, 0.98), "stone", sub=2)


def millstone():
    """石磨：木架上两扇磨盘，上扇有一根推把，下面接着面槽。"""
    box((0.9, 0.7, 0.35), (0, 0.4, 0.175), "wood_dk")
    cyl(0.47, 0.47, 0.16, (0, 0.4, 0.35), "stone_dk", segs=14)
    cyl(0.4, 0.4, 0.22, (0, 0.4, 0.53), "stone", segs=14)
    cyl(0.08, 0.08, 0.05, (0, 0.4, 0.75), "ink", segs=8)
    box((0.6, 0.06, 0.06), (0.5, 0.4, 0.64), "wood")
    box((0.06, 0.06, 0.3), (0.78, 0.4, 0.5), "wood")
    box((0.3, 0.2, 0.06), (0, -0.02, 0.3), "linen")


def oil_press():
    """榨油机：一段横卧的粗木，中间开槽塞着木楔，下面接油的小罐。"""
    for x in (-0.38, 0.38):
        box((0.12, 0.5, 0.5), (x, 0.4, 0.25), "wood_dk")
    cyl(0.26, 0.26, 0.95, (0, 0.4, 0.62), "wood", segs=12, rot=(0, 90, 0), center=True)
    box((0.4, 0.08, 0.3), (0, 0.12, 0.62), "ink")
    for k in range(3):
        box((0.08, 0.1, 0.34 + 0.06 * (k == 1)), (-0.12 + k * 0.12, 0.08, 0.66), "wood_dk")
    for x in (-0.4, 0.4):
        cyl(0.275, 0.275, 0.06, (x, 0.4, 0.62), "iron", segs=12, rot=(0, 90, 0), center=True)
    cyl(0.1, 0.13, 0.2, (0, 0.05, 0.0), "gold", segs=8)


def tea_roaster():
    """茶焙：泥砌的小灶上斜架着一口炒茶的铁锅，旁边一只竹焙笼。"""
    box((0.8, 0.6, 0.5), (-0.05, 0.4, 0.25), "clay")
    box((0.25, 0.06, 0.2), (-0.05, 0.09, 0.14), "ink")
    box((0.12, 0.04, 0.08), (-0.05, 0.07, 0.1), "ember")
    cyl(0.4, 0.4, 0.08, (-0.05, 0.36, 0.5), "iron", segs=12, rot=(-22, 0, 0))
    cyl(0.3, 0.3, 0.04, (-0.05, 0.33, 0.57), "leaf_dk", segs=10, rot=(-22, 0, 0))
    cyl(0.16, 0.2, 0.3, (0.42, 0.1, 0.0), "bamboo", segs=8)


def silk_reel():
    """缫丝机：木架上一只绕丝的轮子，前面一口煮茧的小锅。"""
    for x in (-0.34, 0.34):
        box((0.07, 0.4, 0.95), (x, 0.45, 0.475), "wood_dk")
    box((0.75, 0.4, 0.07), (0, 0.45, 0.06), "wood_dk")
    cyl(0.04, 0.04, 0.8, (0, 0.45, 0.72), "wood", segs=6, rot=(0, 90, 0), center=True)
    for k in range(6):
        box((0.56, 0.04, 0.04), (0, 0.45 + 0.27 * math.cos(k * math.pi / 3), 0.72 + 0.27 * math.sin(k * math.pi / 3)), "wood")
    cyl(0.24, 0.24, 0.3, (0, 0.45, 0.72), "plaster", segs=10, rot=(0, 90, 0), center=True)
    cyl(0.2, 0.16, 0.18, (0, 0.08, 0.0), "iron", segs=10)
    for dx in (-0.06, 0.07):
        ball((0.06, 0.06, 0.05), (dx, 0.08, 0.2), "plaster", sub=1)


def cheese_rack():
    """奶酪架：三层的木架子，摆着一块块圆奶酪，盖着纱布。"""
    for x in (-0.4, 0.4):
        for y in (0.2, 0.6):
            box((0.06, 0.06, 1.0), (x, y, 0.5), "wood_dk")
    for k in range(3):
        box((0.9, 0.5, 0.05), (0, 0.4, 0.2 + k * 0.33), "wood")
        for j, x in enumerate((-0.22, 0.22)):
            if k == 2 and j == 1:
                continue
            cyl(0.16, 0.16, 0.12, (x, 0.3, 0.23 + k * 0.33), "petal_y", segs=10)
    box((0.5, 0.3, 0.03), (0.2, 0.3, 0.92), "linen")


def scarecrow():
    """稻草人：十字木架，草扎的头戴一顶破斗笠，披一件旧褂子。"""
    cyl(0.05, 0.05, 1.5, (0, 0.4, 0.0), "wood_dk", segs=6)
    box((1.2, 0.07, 0.07), (0, 0.4, 1.05), "wood_dk")
    box((0.55, 0.2, 0.6), (0, 0.38, 0.85), "quilt")
    for sx in (-1, 1):
        box((0.36, 0.16, 0.2), (0.42 * sx, 0.38, 1.05), "quilt")
        box((0.14, 0.06, 0.2), (0.66 * sx, 0.38, 1.0), "straw")
    box((0.5, 0.18, 0.14), (0, 0.38, 0.5), "straw")
    ball((0.2, 0.18, 0.2), (0, 0.38, 1.36), "sack", sub=2)
    cyl(0.36, 0.04, 0.14, (0, 0.38, 1.56), "straw", segs=10)
    box((0.04, 0.03, 0.04), (-0.07, 0.19, 1.38), "ink")
    box((0.04, 0.03, 0.04), (0.07, 0.19, 1.38), "ink")


def town_hall():
    """镇公所：最高最宽，四根红柱，三级台阶，门两边各一个石墩。占地 7 格宽。"""
    shell(7.0, wall_top=3.5, rise=1.2)
    door(0.0, w=2.3, h=2.7, step=False)
    plaque(0.0, 3.2, w=2.0, marks=3)
    lattice_window(-2.4, -0.03, 1.9, w=1.1, h=1.1)
    lattice_window(2.4, -0.03, 1.9, w=1.1, h=1.1)
    for x in (-3.3, -1.45, 1.45, 3.3):
        cyl(0.14, 0.14, 3.2, (x, -0.3, 0.3), "red", segs=10)
        box((0.4, 0.4, 0.3), (x, -0.3, 0.15), "stone")
    box((7.2, 0.6, 0.3), (0, -0.3, 0.15), "stone")
    box((3.2, 0.3, 0.2), (0, -0.7, 0.1), "stone")
    box((3.2, 0.3, 0.1), (0, -0.95, 0.05), "stone_dk")
    for sx in (-1, 1):
        box((0.5, 0.5, 0.5), (2.1 * sx, -0.85, 0.25), "stone_dk")
        ball((0.24, 0.24, 0.24), (2.1 * sx, -0.85, 0.7), "stone", sub=2, upright=False)
    lantern(-1.0, -0.35, 3.4)
    lantern(1.0, -0.35, 3.4)


def notice_board():
    """公告栏：两根柱子撑着一块木板，上面有小瓦檐，贴着几张告示。占地 2 格宽。"""
    for sx in (-1, 1):
        box((0.14, 0.14, 1.9), (0.85 * sx, 0, 0.95), "wood_dk")
    box((1.8, 0.08, 1.05), (0, 0, 1.15), "wood")
    box((2.2, 0.5, 0.08), (0, 0, 1.95), "tile", rot=(-14, 0, 0))
    box((2.2, 0.1, 0.1), (0, 0.12, 2.04), "tile_dk")
    box((0.5, 0.02, 0.6), (-0.5, -0.05, 1.2), "paper")
    box((0.42, 0.02, 0.36), (0.1, -0.05, 1.36), "linen")
    box((0.5, 0.02, 0.44), (0.52, -0.05, 0.98), "paper")
    box((0.3, 0.02, 0.24), (0.05, -0.05, 0.9), "red")
    for x, z in ((-0.5, 1.36), (-0.5, 1.2), (0.52, 1.06), (0.1, 1.4)):
        box((0.3, 0.02, 0.04), (x, -0.06, z), "ink")


def plaza_lamp(lit):
    """广场中央的大石灯，比路边的石灯高一倍。锚点在底座中心。"""
    def build():
        cyl(0.62, 0.56, 0.16, (0, 0, 0), "stone_dk", segs=8, rot=(0, 0, 22.5))
        cyl(0.44, 0.38, 0.16, (0, 0, 0.16), "stone", segs=8, rot=(0, 0, 22.5))
        cyl(0.2, 0.15, 1.3, (0, 0, 0.32), "stone", segs=8)
        cyl(0.16, 0.4, 0.16, (0, 0, 1.62), "stone_dk", segs=8, rot=(0, 0, 22.5))
        box((0.5, 0.5, 0.5), (0, 0, 2.03), "stone")
        box((0.28, 0.04, 0.32), (0, -0.26, 2.03), "ember" if lit else "ink")
        if lit:
            box((0.14, 0.05, 0.16), (0, -0.27, 2.0), "paper")
        cyl(0.6, 0.5, 0.06, (0, 0, 2.28), "stone_dk", segs=6)
        cyl(0.5, 0.1, 0.42, (0, 0, 2.34), "stone", segs=6)
        ball((0.1, 0.1, 0.13), (0, 0, 2.82), "stone_dk")
    return build


def bench():
    box((1.7, 0.4, 0.1), (0, 0.2, 0.42), "wood")
    for sx in (-0.7, 0.7):
        box((0.12, 0.34, 0.4), (sx, 0.2, 0.2), "wood_dk")


# ------------------------------------------------------------------ 室外：植物和石头

def bush(variant):
    def build():
        ball((0.62, 0.4, 0.45), (0, 0, 0.42), "leaf_dk")
        ball((0.42, 0.4, 0.34), (-0.42, -0.01, 0.34), "leaf_dk")
        ball((0.42, 0.4, 0.34), (0.44, -0.01, 0.34), "leaf_dk")
        ball((0.36, 0.3, 0.26), (-0.15, -0.03, 0.56), "leaf")
        ball((0.26, 0.3, 0.2), (0.32, -0.03, 0.44), "leaf")
        if variant == 1:
            for x, z in ((-0.4, 0.5), (0.1, 0.72), (0.45, 0.5), (-0.1, 0.36), (0.25, 0.26)):
                ball((0.09, 0.09, 0.09), (x, -0.5, z), "blossom", sub=2)
    return build


def rock(variant):
    def build():
        if variant == 0:
            ball((0.55, 0.4, 0.36), (0, 0, 0.3), "stone", sub=1, smooth=False)
            ball((0.26, 0.2, 0.2), (0.42, -0.05, 0.16), "stone_dk", sub=1, smooth=False)
        else:
            ball((0.42, 0.3, 0.42), (-0.1, 0, 0.34), "stone", sub=1, smooth=False, rot=(0, 20, 30))
            ball((0.34, 0.3, 0.26), (0.3, -0.04, 0.2), "stone", sub=1, smooth=False, rot=(0, -15, 0))
    return build


def fence(mask):
    """栅栏的一格。mask：1 上(远) 2 右 4 下(近) 8 左。锚点在格子中心。"""
    def build():
        box((0.22, 0.22, 0.95), (0, 0, 0.475), "wood")
        box((0.28, 0.28, 0.08), (0, 0, 0.97), "wood_dk")
        for z in (0.36, 0.68):
            if mask & 2:
                box((0.5, 0.08, 0.11), (0.25, 0, z), "wood")
            if mask & 8:
                box((0.5, 0.08, 0.11), (-0.25, 0, z), "wood")
            if mask & 1:
                box((0.08, 0.5, 0.11), (0, 0.25, z), "wood")
            if mask & 4:
                box((0.08, 0.5, 0.11), (0, -0.25, z), "wood")
    return build


# ------------------------------------------------------------------ 室内

def room(paper):
    """整间屋子的地板和后墙，12x9 格（后墙占上面 2 格）。锚点是地板的左前角。"""
    def build():
        rnd = random.Random(3)
        box((12, 7, 0.04), (6, 3.5, -0.1), "wood_dk")
        for r in range(14):
            x = -round(rnd.uniform(0.0, 1.5) * 16) / 16.0
            while x < 12:
                ln = round(rnd.uniform(1.8, 3.4) * 16) / 16.0
                x0, x1 = max(x, 0.0), min(x + ln, 12.0)
                if x1 - x0 > 0.1:
                    box((x1 - x0 - 0.0625, 0.4375, 0.06), ((x0 + x1) / 2 - 0.03125, r * 0.5 + 0.21875, -0.05),
                        "floor_a" if rnd.random() < 0.6 else "floor_b")
                x += ln
        # 草席和门口的垫子
        box((4.5, 2.5, 0.03), (8.0, 4.5, 0.0), "straw")
        for k in range(9):
            box((4.5, 0.0625, 0.035), (8.0, 3.375 + k * 0.28125, 0.0), "wood")
        for x in (5.78, 10.22):
            box((0.0625, 2.5, 0.036), (x, 4.5, 0.0), "wood_dk")
        box((1.6, 0.6, 0.03), (6.0, 0.5, 0.0), "straw")
        box((1.6, 0.06, 0.035), (6.0, 0.5, 0.0), "wood")

        box((12, 0.3, 2.0), (6, 7.15, 1.0), "plaster")
        box((12, 0.32, 0.06), (6, 7.15, 2.02), "wood_dk")
        box((12, 0.06, 0.22), (6, 6.98, 0.11), "wood_dk")
        box((12, 0.1, 0.2), (6, 6.96, 1.9), "wood_dk")
        for x in (0.11, 4.0, 7.6, 11.89):
            box((0.22, 0.1, 2.0), (x, 6.96, 1.0), "wood_dk")
        lattice_window(2.0, 6.98, 1.05, paper, w=1.5, h=0.9375)
        lattice_window(6.0, 6.98, 1.05, paper, w=1.5, h=0.9375)
        # 挂轴
        box((0.9, 0.03, 1.2), (8.75, 6.98, 1.0), "paper")
        box((1.0, 0.05, 0.07), (8.75, 6.97, 1.62), "wood_dk")
        box((1.0, 0.05, 0.07), (8.75, 6.97, 0.38), "wood_dk")
        for x, zz, ww, hh in ((8.6, 0.75, 0.3, 0.3), (8.85, 0.68, 0.36, 0.2), (8.75, 1.0, 0.16, 0.22), (8.55, 1.3, 0.1, 0.1)):
            box((ww, 0.02, hh), (x, 6.955, zz), "ink")
        box((0.1, 0.02, 0.1), (9.05, 6.955, 0.5), "red")

        for x in (0.08, 11.92):
            box((0.16, 7.0, 0.1), (x, 3.5, 0.05), "wood_dk")
        box((5.0, 0.16, 0.1), (2.5, 0.08, 0.05), "wood_dk")
        box((5.0, 0.16, 0.1), (9.5, 0.08, 0.05), "wood_dk")
    return build


def bed():
    """老式木床，占地 2x3 格。锚点是床尾正中。"""
    box((1.9, 2.9, 0.4), (0, 1.5, 0.2), "wood_dk")
    box((1.7, 2.7, 0.14), (0, 1.5, 0.47), "linen")
    box((1.74, 2.0, 0.2), (0, 1.15, 0.52), "quilt")
    box((1.74, 0.26, 0.22), (0, 2.1, 0.53), "quilt_hi")
    for iy in range(4):
        for ix in range(4):
            if (ix + iy) % 2 == 0:
                box((0.2, 0.2, 0.01), (-0.6 + ix * 0.4, 0.4 + iy * 0.4, 0.625), "quilt_hi", rot=(0, 0, 45))
    box((1.2, 0.42, 0.16), (0, 2.52, 0.6), "paper")
    box((1.9, 0.12, 1.5), (0, 2.92, 0.75), "wood")
    box((1.5, 0.03, 0.45), (0, 2.85, 1.15), "wood_dk")
    box((1.9, 0.1, 0.62), (0, 0.06, 0.31), "wood")
    for sx in (-1, 1):
        cyl(0.09, 0.09, 0.8, (0.9 * sx, 0.06, 0), "wood_dk", segs=8)
        cyl(0.09, 0.09, 1.7, (0.9 * sx, 2.92, 0), "wood_dk", segs=8)


def bowl_set(x, y, z, mat):
    cyl(0.13, 0.22, 0.12, (x, y, z), mat, segs=10)
    cyl(0.15, 0.15, 0.02, (x, y, z + 0.11), "stone_dk" if mat == "stone" else "jade", segs=10)
    box((0.03, 0.42, 0.02), (x + 0.26, y, z + 0.01), "wood_dk")
    box((0.03, 0.42, 0.02), (x + 0.32, y, z + 0.01), "wood_dk")


def table():
    """方桌，摆着两副碗筷，一副落了灰。占地 2x1 格，锚点是正面中点。"""
    for sx in (-1, 1):
        for y in (0.12, 0.98):
            box((0.14, 0.14, 0.74), (0.84 * sx, y, 0.37), "wood_dk")
    box((1.84, 0.06, 0.16), (0, 0.1, 0.66), "wood_dk")
    box((1.96, 1.2, 0.1), (0, 0.55, 0.79), "wood")
    bowl_set(-0.55, 0.55, 0.84, "linen")
    bowl_set(0.35, 0.55, 0.84, "stone")


def stool():
    for sx in (-1, 1):
        for y in (0.2, 0.6):
            box((0.1, 0.1, 0.42), (0.24 * sx, y, 0.21), "wood_dk")
    box((0.66, 0.6, 0.08), (0, 0.4, 0.46), "wood")


def stove():
    """灶台和铁锅。占地 2x1 格，锚点是正面中点。"""
    box((1.9, 1.0, 0.8), (0, 0.5, 0.4), "stone")
    box((1.96, 1.04, 0.1), (0, 0.5, 0.85), "stone_dk")
    box((0.56, 0.05, 0.42), (-0.4, -0.01, 0.27), "ink")
    box((0.36, 0.05, 0.1), (-0.4, -0.03, 0.12), "ember")
    box((0.16, 0.05, 0.1), (-0.4, -0.035, 0.2), "ember")
    cyl(0.5, 0.5, 0.07, (0.3, 0.5, 0.9), "iron", segs=14)
    cyl(0.4, 0.4, 0.02, (0.3, 0.5, 0.965), "ink", segs=14)
    box((0.4, 0.3, 1.5), (-0.65, 0.85, 0.75), "stone_dk")


def jar(mat, r, h):
    def build():
        cyl(r * 0.6, r, h * 0.4, (0, 0, 0), mat)
        cyl(r, r * 0.7, h * 0.42, (0, 0, h * 0.4), mat)
        cyl(r * 0.5, r * 0.55, h * 0.16, (0, 0, h * 0.82), mat)
        cyl(r * 0.4, r * 0.4, 0.02, (0, 0, h * 0.975), "ink")
    return build


def cabinet():
    """木柜，上面放着小罐和油灯。占地 2x1 格，锚点是正面中点。"""
    box((1.8, 0.8, 1.7), (0, 0.4, 0.85), "wood")
    box((1.9, 0.86, 0.08), (0, 0.4, 1.72), "wood_dk")
    box((1.8, 0.03, 0.1), (0, -0.01, 0.05), "wood_dk")
    box((0.05, 0.03, 1.5), (0, -0.01, 0.9), "wood_dk")
    for sx in (-1, 1):
        box((0.62, 0.02, 0.5), (0.45 * sx, -0.01, 1.3), "wood_dk")
        box((0.5, 0.02, 0.38), (0.45 * sx, -0.02, 1.3), "wood")
        box((0.62, 0.02, 0.6), (0.45 * sx, -0.01, 0.6), "wood_dk")
        box((0.5, 0.02, 0.48), (0.45 * sx, -0.02, 0.6), "wood")
        box((0.08, 0.04, 0.12), (0.1 * sx, -0.03, 0.95), "gold")
    cyl(0.12, 0.2, 0.2, (-0.5, 0.4, 1.76), "jade", segs=10)
    cyl(0.1, 0.1, 0.1, (-0.5, 0.4, 1.96), "jade", segs=10)
    cyl(0.14, 0.1, 0.08, (0.45, 0.4, 1.76), "iron", segs=8)
    ball((0.07, 0.07, 0.1), (0.45, 0.4, 1.93), "ember", sub=2, upright=False)


# ------------------------------------------------------------------ 物件表

# 名字: (建模函数, 固定尺寸)。固定尺寸为 None 时裁到内容大小。
PROPS = {
    "house": (house, None),
    "mailbox": (mailbox, None),
    "stone_lamp": (stone_lamp, None),
    "bush_0": (bush(0), None),
    "bush_1": (bush(1), None),
    "rock_0": (rock(0), None),
    "rock_1": (rock(1), None),
    "room_day": (room("paper"), None),
    "room_night": (room("paper_night"), None),
    "bed": (bed, None),
    "table": (table, None),
    "stool": (stool, None),
    "stove": (stove, None),
    "cabinet": (cabinet, None),
    "jar_jade": (jar("jade", 0.36, 0.7), None),
    "jar_clay": (jar("clay", 0.36, 0.6), None),
}
for _m in range(16):
    PROPS["fence_%d" % _m] = (fence(_m), None)
PROPS.update({
    "shop_grocery": (shop_grocery, None),
    "shop_herb": (shop_herb, None),
    "teahouse": (teahouse, None),
    "smithy": (smithy, None),
    "town_hall": (town_hall, None),
    "boathouse": (boathouse, None),
    "coop": (coop, None),
    "scaffold": (scaffold, None),
    "scaffold_3": (scaffold_of(3.0), None),
    "scaffold_6": (scaffold_of(6.0), None),
    "barn": (barn, None),
    "apiary": (apiary, None),
    "silk_house": (silk_house, None),
    "pickle_vat": (pickle_vat, None),
    "millstone": (millstone, None),
    "oil_press": (oil_press, None),
    "tea_roaster": (tea_roaster, None),
    "silk_reel": (silk_reel, None),
    "cheese_rack": (cheese_rack, None),
    "scarecrow": (scarecrow, None),
    "notice_board": (notice_board, None),
    "plaza_lamp": (plaza_lamp(False), None),
    "plaza_lamp_lit": (plaza_lamp(True), None),
    "bench": (bench, None),
})

# 渲染画布：足够放下最大的物件。锚点固定在画布的 (OX, OY)
CW, CH = 256, 208
OX, OY = 24, 176
WIDE = {"room_day", "room_night"}


# ------------------------------------------------------------------ 渲染与像素化

def setup_camera(ox):
    scene.render.resolution_x = CW * SS
    scene.render.resolution_y = CH * SS
    cam_data.ortho_scale = max(CW, CH) / PPU
    cam.location = ((CW / 2.0 - ox) / PPU, -60.0, (OY - CH / 2.0) / PPU)


def render():
    path = os.path.join(TMP, "p.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, hgt = img.size
    buf = np.empty(w * hgt * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    return (buf.reshape(hgt, w, 4)[::-1] * 255.0 + 0.5).astype(np.uint8)


def pixelate(a):
    """每个 SSxSS 块取出现最多的调色板颜色；覆盖不到一半的块视为透明。"""
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


def outline(a):
    """给不透明区域外侧加一圈描边，颜色取相邻像素的暗色（与 art_gen/pixel.gd 的算法一致）。"""
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


# ------------------------------------------------------------------ 像素纹理

def _rgb(h):
    return np.array(hex_rgb(h), dtype=np.uint8)


def _hash(xs, ys, seed):
    """每个像素一个 0..1 的固定随机数。"""
    v = (xs.astype(np.int64) * 73856093) ^ (ys.astype(np.int64) * 19349663) ^ (seed * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0


def _noise(xs, ys, cell, seed):
    """低频噪声：粗网格上的随机数做双线性插值，用来做成片的斑驳。"""
    gx, gy = xs / cell, ys / cell
    x0, y0 = np.floor(gx).astype(np.int64), np.floor(gy).astype(np.int64)
    fx, fy = gx - x0, gy - y0
    a, b = _hash(x0, y0, seed), _hash(x0 + 1, y0, seed)
    c, d = _hash(x0, y0 + 1, seed), _hash(x0 + 1, y0 + 1, seed)
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def _is(img, h):
    return (img[..., :3] == _rgb(h)).all(-1) & (img[..., 3] > 0)


def _inner(mask):
    """上下左右都是同一种颜色的像素。只改这些，细线和边缘保持原样。"""
    m = mask.copy()
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        m &= np.roll(mask, (dy, dx), (0, 1))
    return m


def texture(img):
    """在渲染出的平涂色块上加像素画的质感。只在同一种材质的三段色之间换色，不引入新颜色。"""
    hgt, w = img.shape[:2]
    ys, xs = np.mgrid[0:hgt, 0:w]
    out = img.copy()

    def put(mask, h):
        out[mask, :3] = _rgb(h)

    # 木头：横向的短木纹
    for name in ("wood", "wood_dk", "floor_a", "floor_b"):
        light, mid, dark = RAMPS[name]
        for src, dst in ((light, mid), (mid, dark)):
            m = _inner(_is(img, src))
            run = _hash(xs // 5 + (ys * 3) % 5, ys, 11) < 0.16
            put(m & run & (_hash(xs, ys, 12) < 0.85), dst)
    # 白墙：成片的浅色斑驳，零星的污点
    light, mid, dark = RAMPS["plaster"]
    m = _inner(_is(img, mid))
    put(m & (_noise(xs, ys, 7.0, 21) > 0.62), light)
    put(m & (_noise(xs, ys, 5.0, 22) < 0.2) & (_hash(xs, ys, 23) < 0.5), dark)
    # 瓦和石头：零星的深浅点
    for name in ("tile", "tile_hi", "stone", "stone_dk"):
        light, mid, dark = RAMPS[name]
        m = _inner(_is(img, light))
        put(m & (_hash(xs, ys, 31) < 0.07), mid)
        m = _inner(_is(img, mid))
        put(m & (_hash(xs, ys, 32) < 0.06), dark)
        put(m & (_hash(xs, ys, 33) < 0.04), light)
    # 叶子：明暗交界处抖动，色块里点一些小叶片
    chain = [RAMPS["leaf"][0], RAMPS["leaf"][1], RAMPS["leaf_dk"][1], RAMPS["leaf_dk"][2]]
    for chain in (chain, list(RAMPS["willow"]), list(RAMPS["bamboo"])):
        masks = [_is(img, h) for h in chain]
        for i in range(len(chain) - 1):
            below = np.roll(masks[i + 1], -1, 0) | np.roll(masks[i + 1], -2, 0)
            put(masks[i] & below & ((xs + ys) % 2 == 0), chain[i + 1])
            inner = _inner(masks[i + 1])
            dash = (_hash(xs // 2, ys, 41 + i) < 0.09)
            put(inner & dash, chain[i])
            put(_inner(masks[i]) & (_hash(xs // 2, ys, 51 + i) < 0.05), chain[i + 1])
    # 草席：竖向的编织纹
    light, mid, dark = RAMPS["straw"]
    m = _inner(_is(img, light))
    put(m & (xs % 3 == 0) & (_hash(xs, ys // 2, 61) < 0.7), mid)
    # 被面：细密的布纹
    light, mid, dark = RAMPS["quilt"]
    m = _inner(_is(img, light))
    put(m & ((xs + ys) % 4 == 0), mid)
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
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    names = args if args else list(PROPS)
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    desc = {}
    if args and os.path.exists(OUT_JSON):
        with open(OUT_JSON, encoding="utf-8") as f:
            desc = json.load(f)
    for name in names:
        build, fixed = PROPS[name]
        ox = OX if name in WIDE else CW // 2
        setup_camera(ox)
        global PART_SCALE
        PART_SCALE = 0.8 if fixed is not None else 1.0
        build()
        img = outline(texture(pixelate(render())))
        clear_current()
        ys, xs = np.nonzero(img[..., 3])
        if len(ys) == 0:
            print("EMPTY", name, flush=True)
            continue
        x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
        if x0 == 0 or y0 == 0 or x1 == CW or y1 == CH:
            print("CLIPPED", name, flush=True)
        if fixed is not None:
            fw, fh = fixed
            if x1 - x0 > fw or y1 - y0 > fh:
                print("TOO BIG", name, x1 - x0, y1 - y0, flush=True)
            x0 = (x0 + x1 - fw) // 2
            y0 = (y0 + y1 - fh) // 2
            x1, y1 = x0 + fw, y0 + fh
        save_png(img[y0:y1, x0:x1], os.path.join(OUT_DIR, name + ".png"))
        desc[name] = {"w": int(x1 - x0), "h": int(y1 - y0), "anchor": [int(ox - x0), int(OY - y0)]}
        print("rendered", name, x1 - x0, y1 - y0, flush=True)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(desc, f, ensure_ascii=False, indent="\t", sort_keys=True)
        f.write("\n")
    shutil.rmtree(TMP, ignore_errors=True)


main()
