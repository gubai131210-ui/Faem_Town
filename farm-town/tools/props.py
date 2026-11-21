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

def sauce_vat():
    """酱缸：矮胖的黑釉缸，口里是深色的酱。"""
    cyl(0.42, 0.5, 0.35, (0, 0.4, 0.0), "clay")
    cyl(0.5, 0.42, 0.4, (0, 0.4, 0.35), "ink")
    cyl(0.36, 0.36, 0.06, (0, 0.4, 0.72), "wood_dk", segs=12)
    cyl(0.22, 0.22, 0.04, (0, 0.4, 0.7), "clay", segs=10)


def wine_jar():
    """酒坛：细颈坛，坛口蒙着红布。"""
    cyl(0.28, 0.4, 0.35, (0, 0.4, 0.0), "clay")
    cyl(0.4, 0.28, 0.35, (0, 0.4, 0.35), "clay")
    cyl(0.16, 0.2, 0.28, (0, 0.4, 0.7), "clay", segs=10)
    cyl(0.22, 0.22, 0.06, (0, 0.4, 0.96), "red", segs=10)
    box((0.04, 0.04, 0.16), (0, 0.4, 1.02), "gold")


def pickle_vat():
    """腌缸：一口大陶缸，压着石头的木盖。"""
    cyl(0.3, 0.44, 0.4, (0, 0.4, 0.0), "clay")
    cyl(0.44, 0.36, 0.42, (0, 0.4, 0.4), "clay")
    cyl(0.4, 0.4, 0.07, (0, 0.4, 0.82), "wood", segs=12)
    ball((0.2, 0.16, 0.12), (0.03, 0.4, 0.98), "stone", sub=2)


def smithy_room(window):
    """石叔的铁匠铺里间。石地、炉子、铁砧。和木匠铺不是一间屋。"""
    def build():
        box((12, 7, 0.04), (6, 3.5, -0.1), "stone_dk")
        for gy in range(8):
            for gx in range(10):
                mat = "stone" if (gx + gy) % 2 == 0 else "stone_dk"
                box((1.02, 0.72, 0.05), (0.75 + gx * 1.15, 0.5 + gy * 0.82, -0.02), mat)
        box((1.5, 0.5, 0.03), (6.0, 0.42, 0.02), "straw")
        box((12, 0.3, 2.0), (6, 7.15, 1.0), "stone")
        box((12, 0.32, 0.06), (6, 7.15, 2.02), "stone_dk")
        box((12, 0.06, 0.18), (6, 6.98, 0.1), "wood_dk")
        for x in (0.11, 4.0, 8.0, 11.89):
            box((0.2, 0.1, 2.0), (x, 6.96, 1.0), "wood_dk")
        lattice_window(9.3, 6.98, 1.2, window, w=1.2, h=0.8)
        # 炉子
        box((2.4, 1.3, 0.85), (2.4, 5.3, 0.42), "stone_dk")
        box((2.5, 1.4, 0.08), (2.4, 5.3, 0.88), "stone")
        box((1.3, 0.2, 0.28), (2.4, 4.75, 0.5), "ink")
        box((0.85, 0.1, 0.16), (2.4, 4.68, 0.62), "ember")
        box((0.4, 0.08, 0.1), (2.2, 4.66, 0.72), "gold")
        # 铁砧：宽顶、细腰、一头尖角。锤子横躺在旁边
        box((0.85, 0.4, 0.1), (5.85, 4.45, 0.1), "iron")
        box((0.32, 0.28, 0.28), (5.75, 4.45, 0.28), "iron")
        box((1.25, 0.48, 0.12), (5.95, 4.45, 0.48), "steel")
        box((0.4, 0.16, 0.08), (6.7, 4.45, 0.5), "steel")
        box((0.85, 0.1, 0.07), (7.35, 4.05, 0.1), "wood")
        box((0.24, 0.16, 0.12), (7.8, 4.05, 0.14), "iron")
        # 水桶
        cyl(0.22, 0.26, 0.4, (8.3, 4.6, 0.0), "wood", segs=10)
        cyl(0.2, 0.2, 0.06, (8.3, 4.6, 0.36), "quilt", segs=10)
        # 墙上挂的钳子
        box((0.08, 0.04, 0.7), (4.3, 6.9, 1.15), "iron")
        box((0.28, 0.04, 0.08), (4.2, 6.88, 1.45), "iron")
        box((0.28, 0.04, 0.08), (4.4, 6.88, 1.45), "iron")
    return build


def hall_room(window):
    """镇公所里间。一张桌子，墙上六格旧地图。窗不占用纸色，纸色只留给地图。"""
    def build():
        rnd = random.Random(19)
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
        box((1.6, 0.55, 0.03), (6.0, 0.45, 0.02), "straw")
        box((12, 0.3, 2.0), (6, 7.15, 1.0), "plaster")
        box((12, 0.32, 0.06), (6, 7.15, 2.02), "wood_dk")
        box((12, 0.06, 0.18), (6, 6.98, 0.1), "wood_dk")
        for x in (0.11, 11.89):
            box((0.2, 0.1, 2.0), (x, 6.96, 1.0), "wood_dk")
        lattice_window(10.2, 6.98, 1.25, window, w=1.15, h=0.75)
        # 六格地图，格子之间留开，免得连成一块。决策 118：纸上加方位刻度，
        # 让空纸框看得出是地图；点灯补色仍是代码子节点，尺寸和位置都不动。
        for row in range(2):
            for col in range(3):
                cx = 2.3 + col * 2.15
                cz = 1.55 - row * 0.85
                box((1.55, 0.05, 0.62), (cx, 6.96, cz), "wood_dk")
                box((1.25, 0.03, 0.42), (cx, 6.93, cz), "paper")
                # 十字刻度：一横一竖细线，像地图的经纬
                box((0.95, 0.012, 0.03), (cx, 6.915, cz), "floor_a")
                box((0.03, 0.012, 0.3), (cx, 6.915, cz), "floor_a")
        # 桌子和纸。决策 118：桌面与纸放大，房间不再空荡荡。
        for x in (5.2, 7.9):
            box((0.14, 0.14, 0.72), (x, 4.3, 0.36), "wood_dk")
        box((3.2, 1.45, 0.1), (6.55, 4.3, 0.76), "wood")
        box((0.9, 0.52, 0.02), (6.0, 3.9, 0.83), "linen")
        box((0.62, 0.38, 0.02), (7.05, 3.95, 0.85), "linen")
        box((0.7, 0.48, 0.4), (4.8, 3.5, 0.2), "wood")
        # 桌角一摞卷宗，填一点空
        box((0.5, 0.36, 0.14), (8.0, 4.0, 0.88), "paper")
        box((0.42, 0.3, 0.06), (8.0, 4.0, 0.98), "linen")
    return build


def mill():
    """老磨坊。白墙黛瓦，门口一扇石磨，侧面一架水车。锚点是正面墙根的中点，占地 4 格宽。"""
    shell(4.0, wall_top=2.5, rise=0.85)
    door(-0.35, w=1.25, h=1.9)
    cyl(0.42, 0.42, 0.14, (-1.35, -0.72, 0.07), "stone_dk", segs=14)
    cyl(0.34, 0.34, 0.12, (-1.35, -0.72, 0.2), "stone", segs=14)
    box((0.62, 0.05, 0.05), (-0.85, -0.72, 0.28), "wood")
    box((0.06, 0.05, 0.22), (-0.55, -0.72, 0.2), "wood_dk")
    # 水车立在门右侧，轮面朝前，一圈木板是水斗
    wx, wy, wz = 1.85, -0.35, 1.05
    cyl(0.72, 0.72, 0.1, (wx, wy, wz), "wood_dk", segs=18, rot=(90, 0, 0), center=True)
    cyl(0.55, 0.55, 0.08, (wx, wy, wz), "wood", segs=18, rot=(90, 0, 0), center=True)
    cyl(0.12, 0.12, 0.16, (wx, wy, wz), "wood_dk", segs=8, rot=(90, 0, 0), center=True)
    for i in range(8):
        a = i * math.pi / 4
        box((0.22, 0.16, 0.22), (wx + math.cos(a) * 0.78, wy, wz + math.sin(a) * 0.78), "wood")


def earth_shrine():
    """路边的土地庙。小瓦顶、石供桌、一只香炉。锚点是正面中点，占地约 2 格。"""
    box((1.9, 1.15, 0.22), (0, 0.5, 0.11), "stone")
    box((1.55, 0.9, 1.05), (0, 0.55, 0.7), "plaster")
    box((2.15, 1.35, 0.1), (0, 0.5, 1.32), "tile", rot=(14, 0, 0))
    box((2.25, 0.16, 0.14), (0, 0.35, 1.42), "tile_dk")
    box((0.12, 0.12, 1.15), (-0.85, 0.15, 0.6), "wood_dk")
    box((0.12, 0.12, 1.15), (0.85, 0.15, 0.6), "wood_dk")
    box((1.15, 0.42, 0.26), (0, -0.15, 0.13), "stone")
    cyl(0.13, 0.16, 0.2, (0, -0.12, 0.36), "clay", segs=8)
    cyl(0.015, 0.015, 0.32, (-0.05, -0.12, 0.55), "wood_dk", segs=4)
    cyl(0.015, 0.015, 0.32, (0.05, -0.12, 0.55), "wood_dk", segs=4)
    box((0.32, 0.03, 0.5), (0, 0.08, 0.95), "red")


def miner_house():
    """矿工巷的空屋。门洞是暗的，门侧一块没字的木牌。锚点是正面墙根的中点，占地 3 格宽。"""
    shell(3.0, dep=2.0, wall_top=2.25, rise=0.7)
    box((1.05, 0.1, 1.65), (0.0, -0.03, 1.05), "wood_dk")
    box((0.82, 0.06, 1.42), (0.0, -0.08, 1.0), "ink")
    box((1.35, 0.4, 0.1), (0.0, -0.22, 0.05), "stone")
    box((0.55, 0.05, 0.32), (1.05, -0.06, 1.45), "wood")
    box((0.62, 0.04, 0.06), (1.05, -0.08, 1.62), "wood_dk")
    lattice_window(-0.95, -0.03, 1.35, w=0.55, h=0.55)


def _fish_on_ice(cx, cy, cz, body, length=1.0):
    """案上的一条鱼：纺锤身 + 分叉尾 + 背鳍 + 一只眼。决策 118：改到一眼认得出。"""
    # 鱼身三段，中间宽、头尾收窄，才不像一根木条
    box((0.42 * length, 0.26, 0.12), (cx + 0.28 * length, cy, cz), body)
    box((0.34 * length, 0.2, 0.1), (cx + 0.02 * length, cy, cz + 0.01), body)
    box((0.22 * length, 0.14, 0.09), (cx - 0.21 * length, cy, cz), body)
    # 分叉尾鳍，往左后方张开
    box((0.26 * length, 0.1, 0.07), (cx - 0.42 * length, cy + 0.12, cz + 0.04), "ink", rot=(0, 0, 24))
    box((0.26 * length, 0.1, 0.07), (cx - 0.42 * length, cy - 0.12, cz + 0.04), "ink", rot=(0, 0, -24))
    # 背鳍与眼睛
    box((0.2 * length, 0.09, 0.06), (cx + 0.16 * length, cy, cz + 0.09), body)
    box((0.06, 0.06, 0.05), (cx + 0.44 * length, cy + 0.05, cz + 0.07), "ink")


def fish_market():
    """鱼市的摊子。蓝棚、木案、两条有头有尾的鱼。锚点是案前中点。"""
    for x in (-1.35, 1.35):
        box((0.1, 0.1, 1.55), (x, 0.35, 0.78), "wood_dk")
    box((3.1, 1.7, 0.08), (0, 0.4, 1.55), "quilt")
    box((3.2, 0.08, 0.08), (0, 0.4, 1.62), "wood_dk")
    box((2.7, 0.95, 0.42), (0, 0.2, 0.21), "wood")
    box((2.5, 0.8, 0.06), (0, 0.15, 0.45), "linen")
    _fish_on_ice(-0.5, 0.08, 0.58, "steel", 1.0)   # 灰鱼
    _fish_on_ice(0.55, -0.02, 0.56, "clay", 0.82)  # 褐鱼
    cyl(0.2, 0.24, 0.2, (-1.3, -0.6, 0.1), "straw", segs=8)


def boatyard():
    """船坞。草棚底下两只翻扣的船壳、旁边一支桨。决策 118：船壳收头翘尾，桨叶加大。"""
    for x in (-1.4, 1.4):
        box((0.1, 0.1, 1.15), (x, 0.85, 0.55), "wood_dk")
    box((3.3, 1.5, 0.1), (0, 0.85, 1.2), "straw")
    for x in (-0.85, 0.75):
        # 船壳：三段宽度递变，两端收窄、中间鼓起，看着像翻扣的船而不是木箱
        box((0.9, 0.36, 0.16), (x, 0.1, 0.32), "wood_dk")
        box((1.5, 0.62, 0.18), (x, 0.1, 0.5), "wood")
        box((0.95, 0.44, 0.12), (x, 0.1, 0.64), "wood_dk")
        box((0.3, 0.16, 0.1), (x - 0.72, 0.1, 0.4), "wood")   # 收窄的船头
        box((0.3, 0.16, 0.1), (x + 0.72, 0.1, 0.4), "wood")   # 翘起的船尾
        box((1.0, 0.1, 0.08), (x, 0.1, 0.72), "wood")         # 船舷一道亮边
    # 桨：长柄 + 放大的桨叶，斜靠在船边
    box((0.1, 0.08, 1.45), (1.9, -0.15, 0.45), "wood", rot=(0, 20, 0))
    box((0.34, 0.07, 0.5), (2.1, -0.15, 1.05), "wood_dk", rot=(0, 20, 0))


def schoolhouse():
    """学堂。白墙黛瓦，门洞里一块黑板，门口两张小凳。占地 4 格宽。"""
    shell(4.0, wall_top=2.35, rise=0.75)
    box((1.15, 0.1, 1.55), (0.15, -0.03, 1.0), "wood_dk")
    box((0.9, 0.06, 1.3), (0.15, -0.08, 0.95), "ink")
    box((0.7, 0.04, 0.4), (0.15, -0.1, 1.15), "linen")
    # 决策 118：门侧空牌放大、加框，站远也看得见；牌面仍留空不上字
    box((0.95, 0.07, 0.42), (-1.25, -0.05, 1.6), "wood")
    # 门口两张小凳放大，减轻空旷
    for x in (-1.15, 1.35):
        box((0.62, 0.4, 0.1), (x, -0.35, 0.3), "wood")
        box((0.1, 0.1, 0.32), (x - 0.2, -0.35, 0.14), "wood_dk")
        box((0.1, 0.1, 0.32), (x + 0.2, -0.35, 0.14), "wood_dk")
    lattice_window(-1.45, -0.03, 1.4, w=0.6, h=0.6)


def mountain_gate():
    """山门。两根石柱夹着路，上面一条瓦脊，中间一块空匾。人从中间走过。"""
    for x in (-1.45, 1.45):
        box((0.48, 0.48, 2.15), (x, 0.25, 1.08), "stone")
        box((0.62, 0.62, 0.16), (x, 0.25, 2.22), "stone_dk")
    box((3.6, 0.55, 0.16), (0, 0.2, 2.32), "tile")
    box((3.7, 0.22, 0.12), (0, 0.15, 2.48), "tile_dk")
    # 决策 118：空匾放大、加一圈深框，远看也是一块匾而不是小木条；匾面留空不上字
    box((1.5, 0.08, 0.6), (0, -0.02, 1.85), "wood")
    box((1.6, 0.05, 0.08), (0, -0.04, 2.12), "wood_dk")
    box((1.6, 0.05, 0.08), (0, -0.04, 1.58), "wood_dk")


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


def bridge():
    """跨溪的木桥，约两格宽、三格长。锚点在桥面正中。"""
    box((1.9, 2.8, 0.12), (0, 0, 0.16), "wood")
    for sx in (-0.85, 0.85):
        box((0.1, 2.95, 0.38), (sx, 0, 0.28), "wood_dk")
    for y in (-1.2, 0.0, 1.2):
        box((1.85, 0.08, 0.05), (0, y, 0.24), "wood_dk")


def bed_wide():
    """青竹想起来以后换上的床：比原来宽一截，被子是新的。占地仍是 2x3，锚点在床尾正中。"""
    box((2.3, 2.9, 0.42), (0, 1.5, 0.2), "wood")
    box((2.1, 2.7, 0.14), (0, 1.5, 0.48), "linen")
    box((2.14, 2.0, 0.22), (0, 1.15, 0.54), "quilt")
    box((2.14, 0.28, 0.24), (0, 2.1, 0.55), "quilt_hi")
    box((1.4, 0.42, 0.16), (0, 2.52, 0.62), "paper")
    box((2.3, 0.12, 1.55), (0, 2.92, 0.78), "wood")
    box((2.3, 0.1, 0.62), (0, 0.06, 0.32), "wood")
    for sx in (-1.15, 1.15):
        cyl(0.09, 0.09, 0.85, (sx, 0.06, 0), "wood_dk", segs=8)
        cyl(0.09, 0.09, 1.75, (sx, 2.92, 0), "wood_dk", segs=8)


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


def well():
    """广场上的老井。石井圈、木架、一只吊桶。锚点是井沿靠近人的那一侧。"""
    cyl(0.78, 0.86, 0.16, (0, 0.62, 0.0), "stone_dk", segs=14)
    cyl(0.66, 0.66, 0.46, (0, 0.62, 0.16), "stone", segs=14)
    cyl(0.5, 0.44, 0.1, (0, 0.62, 0.6), "stone", segs=14)
    cyl(0.3, 0.3, 0.06, (0, 0.62, 0.58), "ink", segs=10)
    for sx in (-0.58, 0.58):
        box((0.14, 0.14, 1.45), (sx, 0.62, 0.75), "wood_dk")
    box((1.45, 0.14, 0.14), (0, 0.62, 1.45), "wood")
    box((0.05, 0.05, 0.55), (0.22, 0.48, 1.1), "straw")
    cyl(0.18, 0.15, 0.24, (0.22, 0.32, 0.7), "wood", segs=8)
    box((0.28, 0.05, 0.05), (0.22, 0.32, 0.84), "wood_dk")


def stage():
    """戏台。木台、四根柱、红帐从中间分开。锚点是台口正中。占地约 4 格宽。"""
    box((4.2, 2.3, 0.22), (0, 1.15, 0.11), "wood_dk")
    box((3.9, 2.0, 0.1), (0, 1.2, 0.26), "wood")
    for k in range(7):
        box((3.7, 0.08, 0.03), (0, 0.45 + k * 0.28, 0.33), "floor_b" if k % 2 else "floor_a")
    box((1.6, 0.45, 0.14), (0, 0.12, 0.07), "stone")
    for sx in (-1.7, 1.7):
        box((0.16, 0.16, 1.85), (sx, 0.4, 1.15), "wood_dk")
        box((0.16, 0.16, 1.55), (sx, 1.95, 1.0), "wood_dk")
    box((3.7, 0.14, 0.12), (0, 0.4, 2.05), "wood")
    box((3.7, 0.14, 0.12), (0, 1.95, 1.75), "wood")
    box((1.2, 0.05, 1.25), (-0.95, 0.48, 1.3), "red")
    box((1.2, 0.05, 1.25), (0.95, 0.48, 1.3), "red")
    box((3.5, 0.08, 0.16), (0, 0.46, 1.88), "gold")
    cyl(0.42, 0.42, 0.3, (-0.35, 1.25, 0.38), "wood", segs=10)
    cyl(0.36, 0.36, 0.06, (-0.35, 1.25, 0.68), "red", segs=8)
    box((0.08, 0.06, 0.45), (0.15, 1.25, 0.7), "wood")


def alley_gate():
    """后街巷口。两堵白墙夹着一个深色门洞，顶上盖瓦。锚点是门口地面正中。"""
    box((0.7, 0.4, 2.3), (-1.15, 0.25, 1.15), "plaster")
    box((0.7, 0.4, 2.3), (1.15, 0.25, 1.15), "plaster")
    box((3.1, 0.45, 0.4), (0, 0.25, 2.35), "plaster")
    box((3.4, 0.6, 0.16), (0, 0.25, 2.6), "tile")
    box((1.55, 0.16, 1.75), (0, 0.22, 1.0), "ink")
    box((1.75, 0.08, 0.1), (0, 0.08, 1.9), "wood_dk")
    box((0.1, 0.08, 1.85), (-0.82, 0.08, 1.0), "wood_dk")
    box((0.1, 0.08, 1.85), (0.82, 0.08, 1.0), "wood_dk")
    box((0.55, 0.5, 0.12), (-1.15, 0.25, 0.06), "stone")
    box((0.55, 0.5, 0.12), (1.15, 0.25, 0.06), "stone")


def shop_carpenter():
    """河埠的木匠铺。门口一摞木料、一张锯。匾在出图后点上「木」。占地 3 格宽。"""
    shell(3.2, dep=2.0, wall_top=2.15, rise=0.7)
    door(0.15, w=1.25, h=1.75)
    for k in range(5):
        box((1.7, 0.55, 0.09), (-1.25, -0.75, 0.08 + k * 0.1), "floor_a" if k % 2 else "wood")
    box((1.05, 0.08, 0.14), (-1.2, -0.95, 0.64), "iron")
    box((0.4, 0.1, 0.12), (-0.5, -0.95, 0.66), "wood_dk")
    box((0.14, 0.08, 1.7), (1.2, -0.35, 1.05), "wood_dk")
    box((0.95, 0.06, 1.5), (1.2, -0.48, 1.0), "gold")
    box((0.78, 0.08, 1.28), (1.2, -0.54, 1.0), "red")


def shop_soy():
    """酱园。门口三口酱缸，比屋子还显眼。占地 3 格宽。"""
    shell(3.2, dep=2.0, wall_top=2.15, rise=0.7)
    door(0.0, w=1.15, h=1.7)
    for i, (rad, hgt) in enumerate(((0.34, 0.42), (0.42, 0.55), (0.32, 0.38))):
        x = -0.9 + i * 0.9
        cyl(rad, rad * 0.9, hgt, (x, -0.9, 0.0), "clay", segs=12)
        cyl(rad * 0.72, rad * 0.78, 0.08, (x, -0.9, hgt), "wood_dk", segs=10)
        cyl(rad * 0.28, rad * 0.28, 0.05, (x, -0.9, hgt + 0.07), "ink", segs=8)


def shop_teastall():
    """渡口茶摊。蓝布棚、一条柜台、一把壶两只杯。不是一整栋房子。"""
    for sx in (-1.15, 1.15):
        for sy in (0.35, 1.25):
            box((0.12, 0.12, 1.55), (sx, sy, 0.78), "wood_dk")
    box((2.7, 1.35, 0.08), (0, 0.8, 1.58), "quilt")
    box((2.9, 0.1, 0.08), (0, 0.28, 1.5), "wood")
    box((2.2, 0.55, 0.62), (0, 0.55, 0.31), "wood")
    box((2.0, 0.4, 0.06), (0, 0.45, 0.64), "wood_dk")
    cyl(0.28, 0.2, 0.4, (-0.55, 0.42, 0.68), "clay", segs=10)
    ball((0.16, 0.16, 0.1), (-0.55, 0.42, 1.12), "clay", sub=1, upright=False)
    box((0.28, 0.08, 0.1), (-0.28, 0.42, 0.88), "clay")
    for x in (0.15, 0.55):
        cyl(0.14, 0.12, 0.16, (x, 0.4, 0.68), "linen", segs=8)
    box((0.12, 0.06, 1.2), (1.05, 0.28, 1.05), "wood_dk")
    box((0.85, 0.05, 1.05), (1.05, 0.16, 0.95), "gold")
    box((0.68, 0.07, 0.88), (1.05, 0.1, 0.95), "red")


def _stamp_glyph(img, glyph):
    """红纸上点字。模型是斜的，字写在像素上才不会糊。"""
    red = (img[:, :, 0] > 160) & (img[:, :, 1] < 90) & (img[:, :, 2] < 80) & (img[:, :, 3] > 200)
    ys, xs = np.nonzero(red)
    if len(xs) < 8:
        return
    x0, x1 = int(xs.min()) + 1, int(xs.max())
    y0, y1 = int(ys.min()) + 1, int(ys.max())
    gold = np.array(hex_rgb(RAMPS["gold"][0]), dtype=np.uint8)
    rows, cols = len(glyph), len(glyph[0])
    ox = x0 + max(0, (x1 - x0 - cols) // 2)
    oy = y0 + max(0, (y1 - y0 - rows) // 2)
    for r, row in enumerate(glyph):
        for c, ch in enumerate(row):
            if ch != "#":
                continue
            yy, xx = oy + r, ox + c
            if 0 <= yy < img.shape[0] and 0 <= xx < img.shape[1]:
                img[yy, xx, :3] = gold
                img[yy, xx, 3] = 255


_MU = (
    "....##....",
    "....##....",
    "....##....",
    "##########",
    "....##....",
    "....##....",
    "...#..#...",
    "..#....#..",
    ".#......#.",
    "#........#",
)
_CHA = (
    "##..##..##",
    "##########",
    "....##....",
    "..##..##..",
    "##......##",
    "##########",
    "....##....",
    "..##..##..",
    "##......##",
)


def herb_room(paper):
    """姜记药铺的堂屋。和农舍同一格尺寸，墙是一排小抽屉，梁上挂着草药。"""
    def build():
        rnd = random.Random(11)
        box((12, 7, 0.04), (6, 3.5, -0.1), "wood_dk")
        for r in range(14):
            x = -round(rnd.uniform(0.0, 1.2) * 16) / 16.0
            while x < 12:
                ln = round(rnd.uniform(1.6, 3.0) * 16) / 16.0
                x0, x1 = max(x, 0.0), min(x + ln, 12.0)
                if x1 - x0 > 0.1:
                    box((x1 - x0 - 0.0625, 0.4375, 0.06), ((x0 + x1) / 2 - 0.03125, r * 0.5 + 0.21875, -0.05),
                        "floor_a" if rnd.random() < 0.45 else "floor_b")
                x += ln
        # 当中一条窄席，深边、浅心、几道织纹，不是一整块亮绿
        box((2.05, 4.4, 0.02), (6.0, 3.3, 0.012), "leaf_dk")
        box((1.65, 4.0, 0.02), (6.0, 3.3, 0.028), "leaf")
        for k in range(5):
            box((1.65, 0.05, 0.012), (6.0, 1.55 + k * 0.78, 0.04), "leaf_dk")
        box((0.06, 4.0, 0.012), (6.0, 3.3, 0.04), "leaf_dk")
        box((1.5, 0.55, 0.03), (6.0, 0.55, 0.02), "straw")
        box((1.5, 0.06, 0.035), (6.0, 0.55, 0.03), "wood")

        box((12, 0.3, 2.15), (6, 7.15, 1.05), "plaster")
        box((12, 0.32, 0.08), (6, 7.15, 2.16), "wood_dk")
        box((12, 0.08, 0.16), (6, 6.98, 0.08), "wood_dk")
        for x in (0.12, 11.88):
            box((0.22, 0.12, 2.15), (x, 6.96, 1.05), "wood_dk")
        lattice_window(1.55, 6.95, 1.35, paper, w=1.35, h=0.85)

        # 药柜：一墙小抽屉，每格一颗铜钮
        box((8.4, 0.22, 1.85), (7.3, 6.95, 1.05), "wood")
        box((8.15, 0.08, 1.7), (7.3, 6.84, 1.05), "wood_dk")
        for row in range(4):
            for col in range(6):
                x = 4.05 + col * 1.3
                z = 0.42 + row * 0.42
                box((1.12, 0.06, 0.32), (x, 6.78, z), "wood")
                box((0.1, 0.07, 0.08), (x, 6.74, z), "gold")
        # 梁上挂着的药草，从木梁垂下来，绿的和晒黄的岔开
        for i in range(5):
            x = 4.35 + i * 1.42
            mat = "leaf" if i % 2 == 0 else "gold"
            box((0.28, 0.06, 0.12), (x, 6.7, 1.92), "straw")
            for k in range(5):
                box((0.08, 0.05, 0.62), (x - 0.16 + k * 0.08, 6.6, 1.55), mat)
        # 矮架上的药罐
        box((7.6, 0.42, 0.1), (7.2, 6.45, 0.28), "wood_dk")
        for i, (mat, hgt) in enumerate((("clay", 0.42), ("jade", 0.55), ("linen", 0.32),
                                        ("radish", 0.48), ("clay", 0.38), ("jade", 0.5))):
            x = 4.15 + i * 1.22
            cyl(0.2, 0.16, hgt, (x, 6.28, 0.33), mat, segs=10)
            cyl(0.14, 0.14, 0.05, (x, 6.28, 0.33 + hgt), "wood_dk", segs=8)
        # 窗下的红纸，字在出图之后点上去
        box((1.9, 0.05, 1.25), (2.65, 6.78, 0.68), "gold")
        box((1.65, 0.07, 1.05), (2.65, 6.74, 0.68), "red")
        # 墙根一只石臼
        cyl(0.26, 0.18, 0.2, (10.75, 6.32, 0.32), "stone", segs=10)
        cyl(0.045, 0.04, 0.42, (11.0, 6.28, 0.58), "wood", rot=(0, 50, 20), segs=6, center=True)
    return build


def _stamp_yao(img):
    """红纸上点一个「药」。"""
    _stamp_glyph(img, (
        "..##...##...##..",
        "################",
        "....##....##....",
        ".##.............",
        "####............",
        ".##....######...",
        ".##........##...",
        ".##....####.....",
        "........##......",
        "......####......",
        "........##......",
        "......####......",
    ))


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


def workshop(paper):
    """青竹的木匠铺里间。12x9 格。木料、锯和图纸，和药铺、农舍不是一间屋。"""
    def build():
        rnd = random.Random(11)
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
        box((1.6, 0.6, 0.03), (6.0, 0.5, 0.0), "straw")
        box((1.6, 0.06, 0.035), (6.0, 0.5, 0.0), "wood")
        box((12, 0.3, 2.0), (6, 7.15, 1.0), "plaster")
        box((12, 0.32, 0.06), (6, 7.15, 2.02), "wood_dk")
        box((12, 0.06, 0.22), (6, 6.98, 0.11), "wood_dk")
        box((12, 0.1, 0.2), (6, 6.96, 1.9), "wood_dk")
        for x in (0.11, 4.2, 8.0, 11.89):
            box((0.22, 0.1, 2.0), (x, 6.96, 1.0), "wood_dk")
        lattice_window(9.4, 6.98, 1.15, paper, w=1.35, h=0.9)
        # 左边一架木料，横板一层层码出来
        for x in (1.15, 3.35):
            box((0.14, 0.16, 1.55), (x, 5.35, 0.78), "wood_dk")
        for i, z in enumerate((0.28, 0.52, 0.76, 1.0, 1.24)):
            span = 2.15 - (i % 2) * 0.35
            box((span, 0.42, 0.1), (2.25, 5.28, z), "wood" if i % 2 == 0 else "floor_b")
        # 工作台、锯、锤子
        for x in (5.15, 7.25):
            box((0.12, 0.12, 0.62), (x, 4.15, 0.31), "wood_dk")
        box((2.5, 1.15, 0.1), (6.2, 4.15, 0.66), "wood")
        box((1.35, 0.06, 0.07), (6.05, 3.72, 0.78), "iron")
        box((0.16, 0.22, 0.08), (5.28, 3.72, 0.78), "wood_dk")
        box((0.34, 0.16, 0.16), (7.05, 3.78, 0.82), "wood_dk")
        box((0.1, 0.1, 0.28), (7.05, 3.78, 0.62), "wood")
        # 墙上两张图纸
        box((1.15, 0.03, 1.25), (5.15, 6.95, 1.2), "paper")
        box((1.15, 0.03, 1.25), (6.7, 6.95, 1.2), "linen")
        for x, zz, ww, hh in ((4.9, 1.45, 0.55, 0.06), (5.15, 1.15, 0.06, 0.55), (5.4, 0.85, 0.4, 0.06),
                              (6.45, 1.5, 0.6, 0.06), (6.7, 1.2, 0.06, 0.5), (6.95, 0.9, 0.35, 0.06)):
            box((ww, 0.02, hh), (x, 6.93, zz), "ink")
        # 红纸，字后盖上去
        box((0.72, 0.04, 1.2), (10.55, 6.94, 1.25), "red")
    return build


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


# ------------------------------------------------------------------ 大地图：茶岭、藕花荡、古木林

def _bamboo_tray(x, y, z, r=0.55, fill="leaf"):
    """一只晒东西的竹匾。"""
    cyl(r, r, 0.06, (x, y, z), "straw", segs=14)
    cyl(r - 0.12, r - 0.12, 0.04, (x, y, z + 0.05), fill, segs=12)


def drying_rack():
    """晒青的架子：两层木架，上面三只竹匾。锚点在架子前沿中点，占地 2 格宽。"""
    for x in (-0.95, 0.95):
        for y in (0.15, 0.75):
            box((0.07, 0.07, 0.95), (x, y, 0.475), "wood_dk")
    box((2.0, 0.07, 0.07), (0, 0.15, 0.55), "wood")
    box((2.0, 0.07, 0.07), (0, 0.75, 0.95), "wood")
    _bamboo_tray(-0.5, 0.2, 0.6, 0.48)
    _bamboo_tray(0.5, 0.2, 0.6, 0.48, "leaf_dk")
    _bamboo_tray(0.0, 0.78, 1.0, 0.5)


def tea_factory():
    """半山的老茶坊。白墙黛瓦，左边是门，右边一扇大格窗，门口一口炒茶的灶和两只竹匾。占地 6 格宽。"""
    shell(6.0, wall_top=2.7, rise=0.95)
    door(-1.4, w=1.6, h=2.05)
    plaque(-1.4, 2.62, w=1.3, marks=2)
    lattice_window(1.35, -0.03, 1.6, w=1.5, h=0.9)
    lantern(-2.55, -0.3, 2.6)
    # 炒茶灶：土灶上一口斜着的铁锅
    box((1.0, 0.8, 0.62), (2.3, -0.62, 0.31), "clay")
    box((0.36, 0.06, 0.26), (2.3, -1.03, 0.2), "ink")
    cyl(0.4, 0.3, 0.14, (2.3, -0.62, 0.62), "iron", segs=12)
    cyl(0.3, 0.26, 0.05, (2.3, -0.62, 0.7), "leaf", segs=10)
    # 门边的竹匾和茶篓
    _bamboo_tray(0.2, -0.65, 0.06, 0.5)
    _bamboo_tray(1.05, -0.9, 0.06, 0.42, "leaf_dk")
    basket(-2.5, -0.5, "leaf")


def pavilion():
    """观云亭。石台、四根红柱、攒尖的瓦顶，三面是坐栏。锚点是正面台沿中点，占地 3 格宽、2 格深。"""
    box((3.0, 2.2, 0.3), (0, 1.1, 0.15), "stone")
    box((1.2, 0.4, 0.15), (0, -0.18, 0.08), "stone_dk")
    for x in (-1.25, 1.25):
        for y in (0.2, 2.0):
            cyl(0.11, 0.11, 1.95, (x, y, 0.3), "red", segs=8)
    for x in (-1.25, 1.25):
        box((0.1, 1.7, 0.1), (x, 1.1, 0.72), "wood")
        box((0.08, 1.7, 0.3), (x, 1.1, 0.48), "wood_dk")
    box((2.4, 0.1, 0.1), (0, 2.0, 0.72), "wood")
    box((2.4, 0.08, 0.3), (0, 2.0, 0.48), "wood_dk")
    # 石桌
    cyl(0.4, 0.4, 0.1, (0, 1.1, 0.72), "stone", segs=10)
    cyl(0.14, 0.14, 0.42, (0, 1.1, 0.3), "stone_dk", segs=8)
    box((3.0, 0.12, 0.16), (0, 0.2, 2.2), "wood_dk")
    # 攒尖顶：一层层收小的瓦面，每层檐口一道亮边
    for k, (rw, rd) in enumerate(((3.7, 2.9), (2.9, 2.2), (2.1, 1.5), (1.3, 0.9), (0.6, 0.4))):
        z = 2.3 + k * 0.3
        box((rw, rd, 0.3), (0, 1.1, z + 0.15), "tile")
        box((rw + 0.06, 0.08, 0.1), (0, 1.1 - rd / 2, z + 0.07), "tile_hi")
        box((rw + 0.1, rd + 0.1, 0.06), (0, 1.1, z + 0.02), "tile_dk")
    for sx in (-1, 1):
        box((0.5, 0.3, 0.16), (1.95 * sx, -0.3, 2.5), "tile_dk", rot=(0, -30 * sx, 0))
    ball((0.17, 0.17, 0.24), (0, 1.1, 3.95), "gold", upright=False)


def tea_hut():
    """茶农的草屋。泥墙草顶，门开在左边，檐下挂着斗笠和一串干辣椒，墙边靠着茶篓和背篓。占地 4 格宽。"""
    w, dep, wall_top = 4.0, 2.2, 2.2
    box((w, dep, 0.25), (0, dep / 2, 0.125), "stone_dk")
    box((w - 0.1, dep - 0.1, wall_top - 0.25), (0, dep / 2, (wall_top + 0.25) / 2), "sack")
    for sx in (-1, 1):
        box((0.16, 0.12, wall_top - 0.25), ((w / 2 - 0.1) * sx, -0.03, (wall_top + 0.25) / 2), "wood_dk")
    box((w - 0.1, 0.1, 0.14), (0, -0.04, wall_top - 0.07), "wood_dk")
    _thatch(w, dep, wall_top, 1.0)
    box((1.15, 0.1, 1.7), (-0.95, -0.03, 0.25 + 0.85), "wood_dk")
    box((0.95, 0.06, 1.5), (-0.95, -0.09, 0.25 + 0.78), "wood")
    box((0.06, 0.04, 1.5), (-0.95, -0.12, 0.25 + 0.78), "wood_dk")
    lattice_window(0.95, -0.03, 1.4, w=0.8, h=0.7)
    # 斗笠
    cyl(0.34, 0.03, 0.2, (-0.1, -0.12, 1.55), "straw", rot=(90, 0, 0), segs=12, center=True)
    for k in range(4):
        ball((0.06, 0.06, 0.1), (1.72, -0.2, 1.75 - k * 0.17), "red", sub=1)
    basket(1.6, -0.5, "leaf")
    cyl(0.24, 0.3, 0.5, (0.2, -0.5, 0.0), "straw", segs=10)
    box((0.9, 0.35, 0.12), (-2.3, -0.2, 0.3), "wood")
    for sx in (-2.65, -1.95):
        box((0.1, 0.3, 0.26), (sx, -0.2, 0.13), "wood_dk")


def stilt_house():
    """水上人家。木板墙、瓦顶的屋子架在木桩上，前面一圈晒台，栏杆上晾着渔网，台边挂着两只鱼篓。占地 5 格宽，前面 1 格是台子。"""
    w, dep, base = 5.0, 2.2, 0.55
    for x in (-2.3, -0.8, 0.8, 2.3):
        for y in (-0.85, 0.2, dep - 0.2):
            cyl(0.1, 0.1, base, (x, y, 0.0), "wood_dk", segs=6)
    box((w + 0.4, dep + 1.2, 0.12), (0, dep / 2 - 0.5, base + 0.06), "wood")
    for k in range(6):
        box((w + 0.4, 0.04, 0.03), (0, -1.0 + k * 0.22, base + 0.13), "wood_dk")
    wall_top = base + 2.2
    box((w - 0.3, dep - 0.2, 2.1), (0, dep / 2, base + 1.15), "wood")
    for k in range(5):
        box((w - 0.25, 0.03, 0.05), (0, 0.06, base + 0.45 + k * 0.4), "wood_dk")
    half = dep / 2 + 0.35
    rise = 0.95
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((w + 0.7, length + 0.05, 0.14), (0, cy, cz), "tile", rot=(a * sgn, 0, 0))
        for k in range(1, 5):
            t = (k / 5.0 - 0.5) * length
            box((w + 0.7, 0.05, 0.06), (0, cy + math.cos(math.radians(a)) * t, cz + math.sin(math.radians(a)) * t * sgn + 0.09),
                "tile_dk", rot=(a * sgn, 0, 0))
    box((w + 0.8, 0.28, 0.26), (0, dep / 2, wall_top + rise + 0.1), "tile_dk")
    box((1.2, 0.1, 1.6), (-1.1, 0.05, base + 0.92), "wood_dk")
    box((1.0, 0.06, 1.4), (-1.1, 0.0, base + 0.86), "ink")
    box((0.45, 0.05, 1.4), (-1.42, -0.03, base + 0.86), "quilt")
    lattice_window(1.1, 0.07, base + 1.25, w=1.0, h=0.75)
    # 栏杆和渔网
    for x in (-2.6, -1.3, 1.3, 2.6):
        box((0.08, 0.08, 0.6), (x, -1.05, base + 0.4), "wood_dk")
    box((1.4, 0.06, 0.07), (-1.95, -1.05, base + 0.68), "wood_dk")
    box((1.4, 0.06, 0.07), (1.95, -1.05, base + 0.68), "wood_dk")
    for k in range(4):
        box((1.2, 0.02, 0.03), (1.95, -1.08, base + 0.2 + k * 0.14), "linen")
    for k in range(5):
        box((0.03, 0.02, 0.5), (1.4 + k * 0.28, -1.08, base + 0.42), "linen")
    for x in (-2.2, -1.7):
        cyl(0.16, 0.2, 0.3, (x, -0.8, base + 0.12), "straw", segs=8)
    # 下水的木梯
    box((0.7, 0.08, 0.6), (0, -1.12, 0.3), "wood_dk", rot=(-20, 0, 0))
    for k in range(3):
        box((0.6, 0.06, 0.05), (0, -1.2, 0.12 + k * 0.2), "wood")


def duck_shed():
    """鸭棚。矮矮的草顶，前面敞着，里面铺着稻草，门口一只食槽。占地 3 格宽。"""
    w, dep, wall_top = 3.0, 1.6, 1.1
    for x in (-1.4, 1.4):
        for y in (0.1, dep - 0.1):
            box((0.12, 0.12, wall_top), (x, y, wall_top / 2), "wood_dk")
    box((w - 0.1, 0.1, wall_top - 0.1), (0, dep - 0.08, wall_top / 2), "wood")
    box((w - 0.2, dep - 0.2, 0.1), (0, dep / 2, 0.05), "straw")
    _thatch(w, dep, wall_top, 0.7, over=0.35)
    box((1.3, 0.34, 0.2), (0.3, -0.45, 0.1), "wood_dk")
    box((1.15, 0.22, 0.04), (0.3, -0.45, 0.2), "can")
    cyl(0.2, 0.24, 0.26, (-1.1, -0.4, 0.0), "straw", segs=8)


def hunter_cabin():
    """猎户的木屋。原木垒的墙，木瓦顶，侧面一根石头烟囱，门口挂着兽角，墙边码着柴。占地 4 格宽。"""
    w, dep, wall_top = 4.0, 2.2, 2.5
    box((w, dep, 0.22), (0, dep / 2, 0.11), "stone_dk")
    box((w - 0.2, dep - 0.2, wall_top - 0.22), (0, dep / 2, (wall_top + 0.22) / 2), "wood_dk")
    for k in range(7):
        cyl(0.17, 0.17, w - 0.05, (0, -0.02, 0.38 + k * 0.31), "wood", rot=(0, 90, 0), segs=8, center=True)
    for sx in (-1, 1):
        for k in range(7):
            cyl(0.13, 0.13, 0.3, ((w / 2 - 0.02) * sx, -0.05, 0.38 + k * 0.31), "wood_dk", rot=(90, 0, 0), segs=8, center=True)
    half = dep / 2 + 0.25
    rise = 1.0
    a = math.degrees(math.atan2(rise, half))
    length = math.hypot(rise, half)
    for sgn in (1, -1):
        cy = dep / 2 - sgn * half / 2.0
        cz = wall_top + rise / 2.0
        box((w + 0.8, length + 0.08, 0.16), (0, cy, cz), "floor_b", rot=(a * sgn, 0, 0))
        for k in range(1, 4):
            t = (k / 4.0 - 0.5) * length
            box((w + 0.8, 0.05, 0.05), (0, cy + math.cos(math.radians(a)) * t, cz + math.sin(math.radians(a)) * t * sgn + 0.1),
                "wood_dk", rot=(a * sgn, 0, 0))
    box((w + 0.9, 0.26, 0.24), (0, dep / 2, wall_top + rise + 0.1), "wood_dk")
    box((0.7, 0.7, 3.9), (1.55, dep - 0.5, 1.95), "stone")
    box((0.85, 0.85, 0.16), (1.55, dep - 0.5, 3.92), "stone_dk")
    box((1.1, 0.1, 1.65), (-0.6, -0.1, 0.22 + 0.82), "wood_dk")
    box((0.9, 0.06, 1.45), (-0.6, -0.16, 0.22 + 0.76), "floor_a")
    box((0.1, 0.05, 0.14), (-0.3, -0.2, 1.0), "iron")
    # 门上的兽角
    for sx in (-1, 1):
        box((0.36, 0.05, 0.07), (-0.6 + 0.22 * sx, -0.18, 2.12), "linen", rot=(0, -30 * sx, 0))
        box((0.07, 0.05, 0.22), (-0.6 + 0.4 * sx, -0.18, 2.26), "linen")
    box((0.7, 0.08, 0.5), (0.85, -0.1, 1.35), "ink")
    box((0.8, 0.1, 0.06), (0.85, -0.12, 1.35), "wood")
    box((0.06, 0.1, 0.5), (0.85, -0.12, 1.35), "wood")
    # 柴垛
    for row in range(3):
        for k in range(4 - row):
            cyl(0.13, 0.13, 0.6, (-1.95 + k * 0.27 + row * 0.13, -0.45, 0.13 + row * 0.24), "wood",
                rot=(90, 0, 0), segs=8, center=True)


def charcoal_kiln():
    """炭窑。黄泥垒的圆包，正面一个黑洞口，顶上一截烟囱，旁边码着劈好的木头和一筐炭。占地 3 格宽。"""
    ball((1.25, 1.0, 1.05), (0, 0.9, 0.5), "clay", upright=False, sub=3)
    box((2.3, 1.7, 0.3), (0, 0.9, 0.15), "clay")
    box((0.8, 0.12, 0.85), (0, -0.02, 0.5), "soil")
    box((0.56, 0.1, 0.62), (0, -0.07, 0.42), "ink")
    box((0.72, 0.1, 0.1), (0, -0.07, 0.86), "stone_dk")
    cyl(0.17, 0.14, 0.5, (0.35, 1.05, 1.45), "stone_dk", segs=8)
    for row in range(3):
        for k in range(3 - row):
            cyl(0.13, 0.13, 0.7, (1.45 + k * 0.27 + row * 0.13, -0.3, 0.13 + row * 0.24), "wood",
                rot=(90, 0, 0), segs=8, center=True)
    cyl(0.26, 0.32, 0.3, (-1.45, -0.35, 0.0), "straw", segs=10)
    for dx, dy in ((-0.1, 0.05), (0.12, 0.0), (0.0, -0.1)):
        ball((0.12, 0.12, 0.1), (-1.45 + dx, -0.35 + dy, 0.34), "ink", sub=1, upright=False)


def relay_ruin():
    """老驿站剩下的墙。屋顶没了，白墙塌了半边，门框还立着，地上一根倒下的梁。占地 5 格宽。"""
    box((5.0, 2.2, 0.25), (0, 1.1, 0.125), "stone_dk")
    box((2.0, 0.3, 2.3), (-1.5, 2.0, 1.4), "plaster")
    box((1.1, 0.3, 1.5), (0.05, 2.0, 1.0), "plaster")
    box((1.6, 0.3, 0.9), (1.6, 2.0, 0.7), "plaster")
    box((0.3, 1.9, 1.9), (-2.35, 1.05, 1.2), "plaster")
    box((0.3, 1.2, 1.0), (2.35, 1.4, 0.75), "plaster")
    box((1.3, 0.3, 1.2), (-1.85, 0.12, 0.85), "plaster")
    box((0.5, 0.3, 0.7), (1.9, 0.12, 0.6), "plaster")
    for x in (-0.95, 0.35):
        box((0.2, 0.2, 2.2), (x, 0.12, 1.35), "wood_dk")
    box((1.6, 0.22, 0.2), (-0.3, 0.12, 2.5), "wood_dk")
    box((2.4, 0.2, 0.2), (0.9, -0.55, 0.12), "wood", rot=(0, 0, 14))
    box((2.05, 0.34, 0.12), (-1.5, 2.0, 2.6), "tile_dk")
    for k in range(4):
        box((0.36, 0.3, 0.1), (-1.0 + k * 0.5, 1.0 + (k % 2) * 0.35, 0.3), "tile")
    ball((0.5, 0.4, 0.3), (1.3, 0.9, 0.38), "leaf_dk", upright=False)
    ball((0.34, 0.3, 0.24), (-1.7, 1.1, 0.36), "leaf", upright=False)


def stone_arch():
    """老驿道上的石牌坊。两根石柱、三道横额，顶上一条瓦脊。人从中间走过。占地 4 格宽。"""
    for x in (-1.6, 1.6):
        box((0.5, 0.5, 3.0), (x, 0.25, 1.5), "stone")
        box((0.74, 0.74, 0.3), (x, 0.25, 0.15), "stone_dk")
        box((0.3, 0.5, 0.5), (x - 0.4 * (1 if x > 0 else -1) * -1, 0.25, 0.4), "stone_dk")
    box((3.7, 0.4, 0.34), (0, 0.25, 2.3), "stone")
    box((2.2, 0.1, 0.5), (0, 0.02, 2.75), "stone_dk")
    box((2.4, 0.06, 0.08), (0, 0.0, 3.02), "stone")
    box((3.9, 0.44, 0.24), (0, 0.25, 3.12), "stone")
    box((4.5, 0.7, 0.14), (0, 0.25, 3.3), "tile")
    box((4.6, 0.26, 0.14), (0, 0.25, 3.42), "tile_dk")
    for sx in (-1, 1):
        box((0.5, 0.26, 0.2), (2.35 * sx, 0.25, 3.5), "tile_dk", rot=(0, -30 * sx, 0))


def lotus_boat():
    """采莲的小船。船头堆着莲蓬和荷叶，一根竹篙斜搁着。锚点在船身中点，约 3 格长。"""
    box((2.0, 0.7, 0.2), (0, 0, 0.1), "wood_dk")
    box((2.3, 0.62, 0.12), (0, 0, 0.24), "wood")
    box((0.5, 0.44, 0.18), (-1.3, 0, 0.2), "wood_dk")
    box((0.5, 0.44, 0.18), (1.3, 0, 0.22), "wood_dk")
    box((1.9, 0.4, 0.04), (0, 0, 0.3), "floor_a")
    for dx, dy in ((-0.7, 0.05), (-0.45, -0.08), (-0.55, 0.12)):
        ball((0.15, 0.15, 0.09), (dx, dy, 0.38), "leaf", sub=2, upright=False)
    ball((0.3, 0.24, 0.05), (-0.1, 0.02, 0.35), "leaf_dk", sub=2, upright=False)
    ball((0.1, 0.1, 0.1), (-0.3, -0.05, 0.42), "blossom", sub=2, upright=False)
    cyl(0.03, 0.03, 2.6, (0.2, -0.1, 0.36), "bamboo", rot=(0, 78, 0), segs=6)


def wood_pile():
    """码好的一垛木头。占地 2 格宽。"""
    for row in range(4):
        for k in range(6 - row):
            cyl(0.14, 0.14, 0.8, (-0.7 + k * 0.29 + row * 0.145, 0.3, 0.14 + row * 0.25), "wood",
                rot=(90, 0, 0), segs=8, center=True)
    for x in (-0.95, 0.95):
        box((0.08, 0.08, 0.9), (x, 0.3, 0.45), "wood_dk")


# ------------------------------------------------------------------ 农舍扩建和家具（决策 148）

def house_wing(side):
    """老屋两边加盖的一间，比正屋矮一截，3 格宽。锚点是正面墙根的中点。side：1 东边灶屋（有烟囱），-1 西厢。"""
    def build():
        shell(3.0, dep=2.2, wall_top=2.3, rise=0.8)
        lattice_window(-0.35 * side, -0.03, 1.35, w=0.9375, h=0.8)
        if side > 0:
            box((0.5, 0.5, 1.5), (0.8, 1.4, 2.75), "stone_dk")
            box((0.62, 0.62, 0.12), (0.8, 1.4, 3.55), "stone")
            # 墙根码着一小垛柴
            for row in range(2):
                for k in range(3 - row):
                    cyl(0.1, 0.1, 0.5, (0.55 + k * 0.21 + row * 0.1, -0.2, 0.1 + row * 0.18), "wood",
                        rot=(90, 0, 0), segs=6, center=True)
        else:
            # 墙上挂一顶斗笠、一串干辣椒
            cyl(0.42, 0.04, 0.16, (0.75, -0.08, 1.75), "straw", rot=(90, 0, 0), segs=12)
            box((0.03, 0.03, 0.5), (-1.05, -0.08, 1.6), "ink")
            for k in range(4):
                ball((0.06, 0.05, 0.09), (-1.05, -0.1, 1.42 + k * 0.1), "red", sub=2, upright=False)
    return build


def bookshelf():
    """书架，三层，书高高低低。占地 2x1，锚点是正面中点。"""
    box((1.8, 0.06, 1.9), (0, 0.52, 0.95), "ink")
    for sx in (-1, 1):
        box((0.08, 0.5, 1.9), (0.86 * sx, 0.3, 0.95), "wood_dk")
    rnd = random.Random(5)
    for z in (0.1, 0.68, 1.26):
        box((1.66, 0.42, 0.06), (0, 0.27, z), "wood")
        x = -0.78
        while x < 0.72:
            bw = rnd.choice((0.1, 0.12, 0.14, 0.16))
            bh = rnd.uniform(0.34, 0.5)
            mat = rnd.choice(("red", "jade", "linen", "paper", "quilt", "clay"))
            box((bw - 0.02, 0.32, bh), (x + bw / 2, 0.24, z + 0.03 + bh / 2), mat)
            x += bw
            if rnd.random() < 0.12:
                x += 0.12
    box((1.9, 0.56, 0.08), (0, 0.3, 1.92), "wood_dk")


def folding_screen():
    """三扇纸屏风，画着远山。占地 2x1，锚点是正面中点。"""
    for i, x in enumerate((-0.62, 0, 0.62)):
        ry = (-12, 0, 12)[i]
        box((0.6, 0.06, 1.5), (x, 0.5, 0.95), "wood_dk", rot=(0, 0, ry))
        box((0.5, 0.04, 1.32), (x, 0.47, 0.95), "paper", rot=(0, 0, ry))
        box((0.32, 0.02, 0.16), (x - 0.06, 0.44, 0.92 + i * 0.05), "ink", rot=(0, 0, ry))
        box((0.18, 0.02, 0.26), (x + 0.08, 0.44, 1.0 - i * 0.04), "ink", rot=(0, 0, ry))
        box((0.12, 0.12, 0.14), (x - 0.2, 0.5, 0.07), "wood_dk")
        box((0.12, 0.12, 0.14), (x + 0.2, 0.5, 0.07), "wood_dk")
    box((0.06, 0.02, 0.06), (0.75, 0.43, 1.4), "red")


def bonsai():
    """方盆里一棵小松。占地 1x1，锚点在格子前边中点。"""
    box((0.68, 0.46, 0.26), (0, 0.45, 0.13), "clay")
    box((0.74, 0.5, 0.05), (0, 0.45, 0.27), "clay")
    box((0.6, 0.4, 0.03), (0, 0.45, 0.28), "soil")
    cyl(0.05, 0.07, 0.4, (-0.05, 0.45, 0.28), "wood_dk", rot=(0, 18, 0), segs=6)
    cyl(0.04, 0.05, 0.3, (0.06, 0.45, 0.58), "wood_dk", rot=(0, -30, 0), segs=6)
    ball((0.26, 0.2, 0.12), (-0.14, 0.45, 0.66), "leaf_dk", sub=2, upright=False)
    ball((0.22, 0.18, 0.1), (0.18, 0.45, 0.82), "leaf_dk", sub=2, upright=False)
    ball((0.18, 0.15, 0.08), (0.0, 0.45, 0.95), "leaf", sub=2, upright=False)


def fish_bowl():
    """青瓷鱼缸，两尾红鱼。占地 1x1，锚点在格子前边中点。"""
    cyl(0.3, 0.42, 0.42, (0, 0.5, 0.0), "jade", segs=16)
    cyl(0.44, 0.44, 0.04, (0, 0.5, 0.42), "jade", segs=16)
    cyl(0.38, 0.38, 0.02, (0, 0.5, 0.46), "quilt_hi", segs=16)
    for x, y in ((-0.12, 0.45), (0.12, 0.62)):
        ball((0.1, 0.05, 0.03), (x, y, 0.49), "ember", sub=2, upright=False)
    ball((0.07, 0.07, 0.02), (0.08, 0.36, 0.49), "leaf", sub=2, upright=False)


def floor_lamp():
    """落地的宫灯：木架子，方纸灯。占地 1x1，锚点在格子前边中点。"""
    box((0.44, 0.44, 0.08), (0, 0.5, 0.04), "wood_dk")
    box((0.08, 0.08, 1.1), (0, 0.5, 0.6), "wood_dk")
    box((0.42, 0.42, 0.5), (0, 0.5, 1.35), "paper")
    for sx in (-1, 1):
        box((0.05, 0.46, 0.56), (0.21 * sx, 0.5, 1.35), "red")
    box((0.5, 0.5, 0.06), (0, 0.5, 1.63), "red")
    box((0.5, 0.5, 0.06), (0, 0.5, 1.08), "red")
    box((0.04, 0.03, 0.2), (0, 0.24, 0.94), "gold")


def tea_table():
    """矮茶几，一壶两杯。占地 2x1，锚点是正面中点。"""
    for sx in (-1, 1):
        for y in (0.2, 0.8):
            box((0.12, 0.12, 0.36), (0.75 * sx, y, 0.18), "wood_dk")
    box((1.8, 0.86, 0.08), (0, 0.5, 0.4), "wood")
    box((1.7, 0.06, 0.1), (0, 0.08, 0.33), "wood_dk")
    cyl(0.15, 0.12, 0.18, (-0.25, 0.5, 0.44), "clay", segs=10)
    cyl(0.06, 0.06, 0.05, (-0.25, 0.5, 0.62), "clay", segs=8)
    box((0.14, 0.04, 0.04), (-0.06, 0.5, 0.55), "clay", rot=(0, -30, 0))
    for x in (0.25, 0.5):
        cyl(0.06, 0.07, 0.08, (x, 0.45, 0.44), "linen", segs=8)


def wardrobe():
    """樟木衣柜，两扇门。占地 2x1，锚点是正面中点。"""
    box((1.8, 0.7, 2.1), (0, 0.4, 1.1), "wood")
    box((1.92, 0.76, 0.1), (0, 0.4, 2.2), "wood_dk")
    box((1.84, 0.74, 0.12), (0, 0.4, 0.06), "wood_dk")
    for sx in (-1, 1):
        box((0.8, 0.02, 1.7), (0.43 * sx, 0.04, 1.12), "wood_dk")
        box((0.68, 0.02, 1.58), (0.43 * sx, 0.03, 1.12), "clay")
        box((0.06, 0.04, 0.22), (0.08 * sx, 0.01, 1.1), "gold")
    box((0.02, 0.03, 1.72), (0, 0.02, 1.12), "wood_dk")


def rug():
    """一块红毯子，人能踩。占地 3x2，锚点是正面中点。"""
    box((2.8, 1.8, 0.03), (0, 1.0, 0.0), "red")
    box((2.5, 1.5, 0.035), (0, 1.0, 0.0), "gold")
    box((2.36, 1.36, 0.04), (0, 1.0, 0.0), "red")
    for x, y in ((-0.7, 1.0), (0, 1.0), (0.7, 1.0)):
        box((0.3, 0.3, 0.045), (x, y, 0.0), "gold", rot=(0, 0, 45))
        box((0.14, 0.14, 0.05), (x, y, 0.0), "red", rot=(0, 0, 45))


def wall_scroll():
    """墙上的山水挂轴，锚点在下轴中点。"""
    box((0.9, 0.03, 1.2), (0, 0, 0.62), "paper")
    box((1.0, 0.05, 0.07), (0, -0.01, 1.24), "wood_dk")
    box((1.0, 0.05, 0.07), (0, -0.01, 0.0), "wood_dk")
    for x, zz, ww, hh in ((-0.15, 0.37, 0.3, 0.3), (0.1, 0.3, 0.36, 0.2), (0.0, 0.62, 0.16, 0.22), (-0.2, 0.92, 0.1, 0.1)):
        box((ww, 0.02, hh), (x, -0.025, zz), "ink")
    box((0.1, 0.02, 0.1), (0.3, -0.025, 0.12), "red")


def wall_fu():
    """斜贴的红纸福字，锚点在纸的下角。"""
    box((0.62, 0.02, 0.62), (0, 0, 0.44), "red", rot=(0, 45, 0))
    box((0.16, 0.01, 0.3), (-0.04, -0.015, 0.46), "gold")
    box((0.3, 0.01, 0.06), (0.04, -0.015, 0.54), "gold")
    box((0.1, 0.01, 0.12), (0.12, -0.015, 0.38), "gold")


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
    "herb_room_day": (herb_room("paper"), None),
    "herb_room_night": (herb_room("paper_night"), None),
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
    "sauce_vat": (sauce_vat, None),
    "well": (well, None),
    "stage": (stage, None),
    "alley_gate": (alley_gate, None),
    "wine_jar": (wine_jar, None),
    "shop_carpenter": (shop_carpenter, None),
    "shop_soy": (shop_soy, None),
    "shop_teastall": (shop_teastall, None),
    "workshop_day": (workshop("paper"), None),
    "workshop_night": (workshop("paper_night"), None),
    "smithy_room_day": (smithy_room("paper"), None),
    "smithy_room_night": (smithy_room("paper_night"), None),
    "hall_room_day": (hall_room("linen"), None),
    "hall_room_night": (hall_room("paper_night"), None),
    "mill": (mill, None),
    "earth_shrine": (earth_shrine, None),
    "miner_house": (miner_house, None),
    "fish_market": (fish_market, None),
    "boatyard": (boatyard, None),
    "schoolhouse": (schoolhouse, None),
    "mountain_gate": (mountain_gate, None),
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
    "bridge": (bridge, None),
    "bed_wide": (bed_wide, None),
})
PROPS.update({
    "drying_rack": (drying_rack, None),
    "tea_factory": (tea_factory, None),
    "pavilion": (pavilion, None),
    "tea_hut": (tea_hut, None),
    "stilt_house": (stilt_house, None),
    "duck_shed": (duck_shed, None),
    "hunter_cabin": (hunter_cabin, None),
    "charcoal_kiln": (charcoal_kiln, None),
    "relay_ruin": (relay_ruin, None),
    "stone_arch": (stone_arch, None),
    "lotus_boat": (lotus_boat, None),
    "wood_pile": (wood_pile, None),
})
PROPS.update({
    "house_wing_e": (house_wing(1), None),
    "house_wing_w": (house_wing(-1), None),
    "bookshelf": (bookshelf, None),
    "folding_screen": (folding_screen, None),
    "bonsai": (bonsai, None),
    "fish_bowl": (fish_bowl, None),
    "floor_lamp": (floor_lamp, None),
    "tea_table": (tea_table, None),
    "wardrobe": (wardrobe, None),
    "rug": (rug, None),
    "wall_scroll": (wall_scroll, None),
    "wall_fu": (wall_fu, None),
})

# 渲染画布：足够放下最大的物件。锚点固定在画布的 (OX, OY)
CW, CH = 256, 208
OX, OY = 24, 176
WIDE = {"room_day", "room_night", "herb_room_day", "herb_room_night", "workshop_day", "workshop_night", "smithy_room_day", "smithy_room_night", "hall_room_day", "hall_room_night"}


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
        if name.startswith("herb_room"):
            _stamp_yao(img)
        elif name == "shop_carpenter":
            _stamp_glyph(img, _MU)
        elif name == "shop_teastall":
            _stamp_glyph(img, _CHA)
        elif name.startswith("workshop"):
            _stamp_glyph(img, _MU)
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


# tools/kitchen.py 把这个文件当模块用（材质、建模工具、像素化），那时不出图
if __name__ == "__main__":
    main()
