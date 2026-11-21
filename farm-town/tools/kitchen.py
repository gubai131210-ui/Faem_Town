"""用 Blender 画做菜这一场要用的东西：灶间、灶上八种做法的锅、灶膛里的火、菜。

用法:  blender --background --python tools/kitchen.py -- [stage] [pots] [fire] [dishes]
       不写就全部重画
输出:  art/cooking/kitchen.png        384x216，整间灶间，没有人（人在游戏里用序列帧贴）
       art/cooking/pot_<做法>.png      8 帧，每帧 96x64。锅口在格子右半，左边空出来给铲柄接到人的袖子上
       art/cooking/fire.png           3 行（小火、中火、旺火）x 4 帧，每帧 32x24
       art/food/<菜>.png              4 帧，每帧 32x32，和 tools/dish_art.py 的格式一样
       _preview/kitchen_pots.png、_preview/kitchen_dishes.png   放大的预览
建模工具、材质和像素化都用 tools/props.py 的，颜色只来自 data/palette.json。
灶间是 1 单位 = 32 像素（人放大两倍站进去正好）。
"""
import math
import os
import random
import shutil
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import props as P  # noqa: E402

box, cyl, ball = P.box, P.cyl, P.ball
PROJ = P.PROJ
OUT = os.path.join(PROJ, "art", "cooking")
FOOD = os.path.join(PROJ, "art", "food")
PREVIEW = os.path.join(PROJ, "_preview")
PPU = 32
W, H = 384, 216

# 外锅（做菜用的那口）和灶膛口在灶间里的位置，游戏里按这个摆锅和火
WOK = (8.0, 2.35, 0.97)
FIRE = (8.0, 1.5, 0.3)


def shoot(w, h, cx, cz, shear=1.0, ppu=PPU):
    """把现在场景里的东西拍成 w x h 的像素图，然后清掉。cx、cz 是画面中心。"""
    P.scene.render.resolution_x = w * P.SS
    P.scene.render.resolution_y = h * P.SS
    P.cam_data.ortho_scale = max(w, h) / float(ppu)
    P.cam.location = (cx, -60.0, cz)
    img = P.pixelate(P.render())
    P.clear_current()
    return img


def over(dst, src):
    m = src[..., 3] > 127
    dst[m] = src[m]
    return dst


def set_shear(k):
    P.SHEAR[2][1] = k


# ------------------------------------------------------------------ 灶间

def shell():
    """地面和后墙。"""
    rnd = random.Random(7)
    box((12.4, 3.8, 0.04), (6, 1.8, -0.1), "wood_dk")
    # 地上铺的是旧砖，一行行错开
    for r in range(8):
        x = -rnd.uniform(0.0, 0.8)
        while x < 12.2:
            ln = 0.9
            box((ln - 0.06, 0.4, 0.06), (x + ln / 2, r * 0.46 + 0.2, -0.05),
                "floor_a" if rnd.random() < 0.55 else "floor_b")
            x += ln
    box((12.4, 0.3, 3.6), (6, 3.75, 1.8), "plaster")
    box((12.4, 0.1, 0.3), (6, 3.58, 0.15), "stone_dk")
    box((12.4, 0.12, 0.28), (6, 3.56, 3.1), "wood_dk")
    for x in (0.12, 6.3):
        box((0.26, 0.1, 3.4), (x, 3.57, 1.7), "wood_dk")
    P.lattice_window(2.0, 3.58, 1.95, "paper", w=1.9, h=1.2)


def hangings():
    """墙上挂的：一串辣椒、一串玉米、一只筲箕。"""
    for i in range(6):
        box((0.16, 0.06, 0.2), (5.35 + (i % 2) * 0.12, 3.55, 2.6 - i * 0.2), "red")
    box((0.04, 0.04, 0.3), (5.41, 3.56, 2.8), "straw")
    for i in range(4):
        box((0.18, 0.08, 0.28), (5.8 + (i % 2) * 0.14, 3.55, 2.6 - i * 0.3), "gold")
        box((0.1, 0.06, 0.08), (5.8 + (i % 2) * 0.14, 3.54, 2.78 - i * 0.3), "leaf_dk")
    cyl(0.5, 0.5, 0.08, (0.95, 3.52, 2.2), "straw", rot=(90, 0, 0), segs=16, center=True)
    cyl(0.38, 0.38, 0.1, (0.95, 3.5, 2.2), "sack", rot=(90, 0, 0), segs=16, center=True)


def water_jar():
    """水缸，水面上浮着一只水瓢。"""
    x, y = 1.15, 3.0
    cyl(0.42, 0.62, 0.5, (x, y, 0), "clay", segs=16, upright=True)
    cyl(0.62, 0.56, 0.4, (x, y, 0.5), "clay", segs=16, upright=True)
    cyl(0.56, 0.56, 0.02, (x, y, 0.88), "clay", segs=16)
    cyl(0.5, 0.5, 0.02, (x, y, 0.9), "can", segs=16)
    cyl(0.14, 0.14, 0.04, (x - 0.12, y + 0.08, 0.92), "straw")
    box((0.4, 0.06, 0.04), (x + 0.2, y + 0.08, 0.92), "wood_dk")


def cupboard():
    """碗橱：上层敞着，摆着碗；下层两扇门；顶上叠两屉蒸笼。"""
    x, y = 4.0, 3.2
    box((1.8, 0.6, 2.3), (x, y, 1.15), "wood")
    box((1.9, 0.66, 0.1), (x, y, 2.33), "wood_dk")
    box((1.56, 0.04, 0.8), (x, y - 0.3, 1.72), "ink")
    box((1.6, 0.1, 0.06), (x, y - 0.3, 1.3), "wood_dk")
    for i, mat in enumerate(("quilt", "linen", "quilt", "linen")):
        bx = x - 0.57 + i * 0.38
        for k in range(2 + i % 2):
            box((0.28, 0.06, 0.07), (bx, y - 0.34, 1.37 + k * 0.09), mat)
    box((0.3, 0.06, 0.26), (x + 0.5, y - 0.34, 1.86), "clay")
    box((0.24, 0.06, 0.2), (x - 0.5, y - 0.34, 1.84), "jade")
    box((1.6, 0.06, 0.05), (x, y - 0.33, 1.72), "wood_dk")
    for sx in (-1, 1):
        box((0.72, 0.04, 0.95), (x + sx * 0.4, y - 0.31, 0.68), "wood_dk")
        box((0.56, 0.03, 0.78), (x + sx * 0.4, y - 0.33, 0.68), "wood")
        box((0.08, 0.05, 0.14), (x + sx * 0.1, y - 0.35, 0.7), "gold")
    for k in range(2):
        box((0.9, 0.5, 0.2), (x - 0.3, y, 2.48 + k * 0.22), "straw")
        box((0.92, 0.52, 0.04), (x - 0.3, y, 2.48 + k * 0.22), "wood")


def side_table():
    """靠窗的小桌：砧板、菜刀、一棵白菜、一只碗。"""
    x, y = 1.9, 1.1
    for sx in (-1, 1):
        for dy in (-0.32, 0.32):
            box((0.1, 0.1, 0.62), (x + sx * 0.8, y + dy, 0.31), "wood_dk")
    box((1.9, 0.9, 0.1), (x, y, 0.67), "wood")
    box((0.8, 0.5, 0.05), (x - 0.35, y, 0.75), "sack")
    box((0.34, 0.08, 0.03), (x - 0.25, y - 0.1, 0.79), "steel")
    box((0.16, 0.06, 0.04), (x - 0.02, y - 0.1, 0.79), "wood_dk")
    # 白菜躺在砧板左边：外层绿叶张开，中间一叠白帮，不要一颗绿球
    bx, by, bz = x - 0.55, y + 0.02, 0.78
    box((0.46, 0.3, 0.05), (bx, by, bz), "leaf_dk")
    box((0.34, 0.22, 0.05), (bx, by, bz + 0.04), "leaf")
    box((0.18, 0.24, 0.07), (bx, by, bz + 0.08), "linen")
    box((0.1, 0.16, 0.08), (bx, by, bz + 0.12), "petal_w")
    box((0.2, 0.1, 0.04), (bx - 0.18, by - 0.08, bz + 0.03), "leaf", rot=(0, 0, 28))
    box((0.2, 0.1, 0.04), (bx + 0.18, by + 0.06, bz + 0.03), "leaf_dk", rot=(0, 0, -22))
    cyl(0.14, 0.2, 0.12, (x + 0.5, y, 0.72), "quilt", segs=14)
    cyl(0.17, 0.17, 0.01, (x + 0.5, y, 0.84), "linen", segs=14)


def stove():
    """两眼的土灶：白灶身黑压边，外锅做菜，里锅盖着高木盖，中间一只汤罐。灶壁上有龛，贴着灶君的红纸。"""
    cx, cy = 9.1, 2.4
    box((4.4, 1.8, 0.9), (cx, cy, 0.45), "plaster")
    box((4.5, 1.9, 0.08), (cx, cy, 0.93), "ink")
    box((4.3, 1.7, 0.02), (cx, cy, 0.975), "stone_dk")
    box((4.4, 0.04, 0.1), (cx, cy - 0.9, 0.05), "ink")
    # 外锅
    cyl(0.74, 0.74, 0.05, (WOK[0], WOK[1], 0.96), "iron", segs=20)
    cyl(0.63, 0.63, 0.02, (WOK[0], WOK[1], 1.01), "ink", segs=20)
    # 里锅和高木盖
    cyl(0.84, 0.84, 0.05, (10.15, 2.4, 0.96), "iron", segs=20)
    cyl(0.78, 0.7, 0.14, (10.15, 2.4, 1.0), "wood", segs=20)
    cyl(0.6, 0.6, 0.03, (10.15, 2.4, 1.14), "wood_dk", segs=20)
    cyl(0.56, 0.56, 0.02, (10.15, 2.4, 1.17), "wood", segs=20)
    box((0.9, 0.12, 0.08), (10.15, 2.4, 1.2), "wood_dk")
    # 汤罐
    cyl(0.2, 0.2, 0.08, (9.1, 3.0, 0.96), "iron", segs=12)
    cyl(0.15, 0.15, 0.03, (9.1, 3.0, 1.04), "wood", segs=12)
    # 灶膛口：外锅底下的开着，里锅底下的关着铁门
    box((0.8, 0.04, 0.56), (FIRE[0], 1.49, 0.34), "stone_dk")
    box((0.62, 0.05, 0.44), (FIRE[0], 1.48, 0.3), "ink")
    box((0.56, 0.05, 0.4), (10.15, 1.49, 0.3), "iron")
    box((0.1, 0.06, 0.08), (10.15, 1.47, 0.3), "ink")
    # 灶身上画的花
    for dx, dz, mat in ((0, 0, "blossom"), (-0.12, 0.02, "leaf_dk"), (0.12, 0.02, "leaf_dk"),
                        (0, 0.12, "blossom"), (0, -0.14, "leaf_dk")):
        box((0.12, 0.03, 0.12), (9.1 + dx, 1.49, 0.5 + dz), mat)
    # 灶壁
    box((4.4, 0.3, 2.6), (cx, 3.45, 1.3), "plaster")
    box((4.5, 0.36, 0.12), (cx, 3.45, 2.66), "ink")
    box((1.5, 0.36, 0.12), (cx, 3.45, 2.9), "ink")
    box((1.3, 0.3, 0.14), (cx, 3.45, 2.78), "plaster")
    for sx in (-1, 1):
        box((0.08, 0.32, 2.6), (cx + sx * 2.2, 3.44, 1.3), "ink")
    # 左龛放盐罐，右龛放灯
    box((0.6, 0.04, 0.46), (7.75, 3.29, 1.75), "ink")
    box((0.2, 0.05, 0.22), (7.66, 3.27, 1.65), "linen")
    box((0.16, 0.05, 0.16), (7.9, 3.27, 1.62), "clay")
    box((0.6, 0.04, 0.46), (10.45, 3.29, 1.75), "ink")
    box((0.14, 0.05, 0.2), (10.45, 3.27, 1.64), "gold")
    box((0.08, 0.05, 0.1), (10.45, 3.27, 1.8), "ember")
    # 红纸金边。字不在模型上写：墙是斜的，格子会糊成金点。stage() 画完再往红纸上点字。
    box((1.7, 0.04, 0.95), (cx, 3.29, 2.2), "gold")
    box((1.52, 0.05, 0.78), (cx, 3.28, 2.2), "red")
    box((0.7, 0.16, 0.06), (cx, 3.22, 1.56), "wood_dk")
    box((0.2, 0.1, 0.14), (cx, 3.2, 1.66), "clay")
    # 烟囱
    box((0.5, 0.3, 0.9), (10.9, 3.45, 3.15), "plaster")
    box((0.6, 0.34, 0.08), (10.9, 3.45, 2.76), "ink")


def firewood():
    """灶下的小凳、火钳和一堆柴。"""
    rnd = random.Random(5)
    for row, n in enumerate((4, 3, 2)):
        for i in range(n):
            x = 10.6 + i * 0.3 + row * 0.15
            mat = "wood" if rnd.random() < 0.6 else "wood_dk"
            cyl(0.14, 0.14, 0.8, (x, 0.75, 0.14 + row * 0.25), mat, rot=(90, 0, 0), segs=8,
                upright=True, center=True)
    x, y = 9.0, 0.8
    for sx in (-1, 1):
        box((0.08, 0.5, 0.3), (x + sx * 0.3, y, 0.15), "wood_dk")
    box((0.8, 0.56, 0.08), (x, y, 0.34), "wood")
    box((0.05, 0.05, 0.9), (9.75, 1.42, 0.45), "iron", rot=(0, 12, 0))


# 火在左、土在右，所以是灶。口字头加尹，所以是君。每行从左到右、从上到下。
_ZAO = (
    "..#....#####",
    ".#.#......#.",
    "..#.......#.",
    "#.#.#.....#.",
    ".#.#......#.",
    "..#.......#.",
    ".#.#...#####",
    "#...#.......",
)
_JUN = (
    ".#########..",
    ".....#......",
    "..####.#....",
    "......#.....",
    ".....#......",
    "...######...",
    "...#....#...",
    "...#....#...",
    "...######...",
)


def _stamp_zaojun(img):
    """红纸是一块斜墙上的模型，字直接点在像素上，才不会被斜切糊掉。"""
    red = (img[:, :, 0] > 150) & (img[:, :, 1] < 110) & (img[:, :, 2] < 100)
    red[:10, :] = False
    red[:, :200] = False
    red[80:, :] = False
    ys, xs = np.nonzero(red)
    if len(xs) == 0:
        return
    x0, x1 = int(xs.min()) + 2, int(xs.max()) - 1
    y0, y1 = int(ys.min()) + 2, int(ys.max()) - 1
    gold = np.array(P.hex_rgb(P.RAMPS["gold"][0]), dtype=np.uint8)
    scale = 2
    gap = 2
    glyphs = (_ZAO, _JUN)
    rows = max(len(g) for g in glyphs)
    cols = max(len(g[0]) for g in glyphs)
    block_w = cols * scale
    total = block_w * 2 + gap
    ox = x0 + max(0, (x1 - x0 - total) // 2)
    oy = y0 + max(0, (y1 - y0 - rows * scale) // 2)
    for i, glyph in enumerate(glyphs):
        gx = ox + i * (block_w + gap)
        for r, row in enumerate(glyph):
            for c, ch in enumerate(row):
                if ch != "#":
                    continue
                yy = oy + r * scale
                xx = gx + c * scale
                img[yy:yy + scale, xx:xx + scale, :3] = gold
                img[yy:yy + scale, xx:xx + scale, 3] = 255


def stage():
    set_shear(1.0)
    layers = []
    for build, edge in ((shell, False), (hangings, True), (stove, True), (cupboard, True),
                        (water_jar, True), (side_table, True), (firewood, True)):
        build()
        img = P.texture(shoot(W, H, 6.0, H / 2.0 / PPU))
        layers.append(P.outline(img) if edge else img)
    out = np.zeros((H, W, 4), dtype=np.uint8)
    out[..., :3] = P.hex_rgb(P.RAMPS["ink"][2])
    out[..., 3] = 255
    for img in layers:
        over(out, img)
    _stamp_zaojun(out)
    P.save_png(out, os.path.join(OUT, "kitchen.png"))
    print("rendered kitchen", flush=True)


# ------------------------------------------------------------------ 锅

def wok():
    cyl(0.74, 0.74, 0.05, (0, 0, 0), "iron", segs=20)
    cyl(0.63, 0.63, 0.02, (0, 0, 0.05), "ink", segs=20)


def bits(rnd, n, mats, r, z, f, turn=0.0, size=0.12):
    """锅里的碎料。turn 是每帧转过的角度，翻炒时整锅在转。"""
    for i in range(n):
        a = rnd.uniform(0, math.tau) + math.radians(turn) * f
        d = rnd.uniform(0.05, r)
        s = size * rnd.uniform(0.8, 1.3)
        box((s, s, 0.04), (math.cos(a) * d, math.sin(a) * d, z), mats[i % len(mats)],
            rot=(0, 0, rnd.uniform(0, 90)))


def dots(seed, f, n, mat, r, z, size=0.06):
    """冒泡：每帧换一批位置。"""
    rnd = random.Random(seed * 10 + f)
    for _ in range(n):
        a, d = rnd.uniform(0, math.tau), rnd.uniform(0.0, r)
        box((size, size, 0.02), (math.cos(a) * d, math.sin(a) * d, z), mat)


def stick(angle, mat="wood", tip="steel", length=1.85):
    """从左边伸进锅里的铲或勺。锅画在格子右半，柄要够到站在锅沿外面的人。"""
    a = math.radians(angle)
    ux, uy = math.cos(a), math.sin(a)
    box((length, 0.16, 0.06), (-ux * length / 2 - ux * 0.2, -uy * length / 2 - uy * 0.2, 0.24), mat,
        rot=(0, 0, angle))
    box((0.46, 0.34, 0.06), (ux * 0.02, uy * 0.02, 0.22), tip, rot=(0, 0, angle))


# 每一步转过的角度一样大。正弦会在两端停一下。
# 角度收在朝向左边的人，转到太陡柄就离开袖子
STIR_SWEEP = [18, 26, 34, 42, 34, 26, 18, 26]
SPOON_SWEEP = [22, 30, 38, 46, 38, 30, 22, 30]


def _wave(f, center, amp):
    return center + math.sin(f / 8.0 * math.tau) * amp


def pot_stir(f):
    wok()
    # 炒是暖色碎块（蛋、番茄、酱色），不再是一锅通用的绿菜
    bits(random.Random(1), 12, ("petal_y", "radish", "gold", "red", "petal_y"), 0.5, 0.08, f, turn=45)
    stick(STIR_SWEEP[f % 8], tip="wood")


def pot_fry(f):
    wok()
    cyl(0.6, 0.6, 0.02, (0, 0, 0.07), "petal_y", segs=20)
    bits(random.Random(2), 5, ("sack", "gold", "sack"), 0.42, 0.1, f, turn=12, size=0.2)
    dots(2, f, 7, "linen", 0.55, 0.12)


def pot_boil(f):
    wok()
    cyl(0.6, 0.6, 0.02, (0, 0, 0.07), "can", segs=20)
    bits(random.Random(3), 6, ("leaf", "radish", "leaf_dk"), 0.45, 0.1, f, turn=8, size=0.14)
    dots(3, f, 8, "petal_w", 0.55, 0.12)
    stick(SPOON_SWEEP[f % 8], tip="wood")


def pot_stew(f):
    wok()
    cyl(0.56, 0.6, 0.3, (0, 0, 0.06), "clay", segs=18)
    for sx in (-1, 1):
        box((0.16, 0.2, 0.08), (sx * 0.66, 0, 0.3), "clay")
    dx = math.sin(f / 8.0 * math.tau) * 0.04
    cyl(0.52, 0.4, 0.1, (dx, 0, 0.36 + (0.03 if f % 2 else 0.0)), "soil", segs=18)
    cyl(0.1, 0.1, 0.08, (dx, 0, 0.46), "clay", segs=10)


def pot_steam(f):
    wok()
    cyl(0.66, 0.66, 0.24, (0, 0, 0.06), "straw", segs=20)
    cyl(0.67, 0.67, 0.04, (0, 0, 0.14), "wood", segs=20)
    lift = 0.03 + 0.03 * math.sin(f / 8.0 * math.tau)
    cyl(0.66, 0.5, 0.1, (0, 0, 0.3 + lift), "straw", segs=20)
    cyl(0.44, 0.44, 0.02, (0, 0, 0.4 + lift), "sack", segs=20)
    cyl(0.3, 0.3, 0.02, (0, 0, 0.42 + lift), "straw", segs=20)
    box((0.24, 0.08, 0.05), (0, 0, 0.46 + lift), "wood_dk")


def pot_cut(f):
    wok()
    box((1.5, 1.0, 0.08), (0, 0, 0.1), "wood")
    box((1.4, 0.9, 0.02), (0, 0, 0.15), "sack")
    kx = -0.28 + f * 0.07
    left = max(0.05, 0.5 - f * 0.06)
    box((left, 0.3, 0.1), (0.55 - left / 2, 0.02, 0.2), "leaf")
    for i in range(min(f, 6) + 1):
        box((0.06, 0.28, 0.06), (-0.5 + i * 0.11, 0.0, 0.2), "leaf_dk" if i % 2 else "leaf")
    box((0.1, 0.5, 0.16 if f % 2 == 0 else 0.28), (kx, -0.02, 0.3), "steel")
    box((0.1, 0.26, 0.1), (kx, -0.4, 0.34), "wood_dk")


def pot_mix(f):
    wok()
    cyl(0.44, 0.62, 0.22, (0, 0, 0.06), "quilt", segs=20)
    cyl(0.55, 0.55, 0.02, (0, 0, 0.28), "radish", segs=20)
    bits(random.Random(6), 10, ("leaf", "leaf_dk", "red", "leaf", "petal_y"), 0.42, 0.31, f, turn=45, size=0.11)
    ang = _wave(f, 40, 18)
    for off in (-4, 6):
        a = math.radians(ang + off)
        box((1.0, 0.04, 0.04), (-math.cos(a) * 0.4, -math.sin(a) * 0.4, 0.4), "wood", rot=(0, 0, ang + off))


def pot_roast(f):
    cyl(0.74, 0.74, 0.05, (0, 0, 0), "iron", segs=20)
    cyl(0.63, 0.63, 0.02, (0, 0, 0.05), "red" if f % 2 else "ember", segs=20)
    dots(8, f, 9, "gold", 0.55, 0.08, size=0.09)
    for i in range(5):
        box((1.2, 0.04, 0.04), (0, -0.44 + i * 0.22, 0.12), "iron")
    ball((0.3, 0.16, 0.14), (-0.18, 0.12, 0.24), "clay", rot=(0, 0, 20))
    ball((0.26, 0.15, 0.13), (0.22, -0.18, 0.24), "soil", rot=(0, 0, -15))


POTS = {"stir": pot_stir, "fry": pot_fry, "boil": pot_boil, "stew": pot_stew,
        "steam": pot_steam, "cut": pot_cut, "mix": pot_mix, "roast": pot_roast}


def sheet(frames):
    return np.concatenate(frames, axis=1)


def pots():
    set_shear(1.0)
    rows = []
    for name, build in POTS.items():
        frames = []
        for f in range(8):
            build(f)
            # 锅口落在格子的 x=64，左边 64 像素是铲柄。游戏里按这个对齐灶眼。
            frames.append(P.outline(shoot(96, 64, -0.5, 0.1)))
        img = sheet(frames)
        P.save_png(img, os.path.join(OUT, "pot_%s.png" % name))
        rows.append(img)
        print("rendered pot", name, flush=True)
    save_preview(np.concatenate(rows, axis=0), "kitchen_pots.png", 3)


# ------------------------------------------------------------------ 火

def flames(level, f):
    rnd = random.Random(level * 7 + f)
    n = 3 + level
    for i in range(n):
        x = (i - (n - 1) / 2.0) * 0.14 + rnd.uniform(-0.03, 0.03)
        hgt = (0.12 + level * 0.09) * rnd.uniform(0.7, 1.25)
        box((0.14, 0.04, hgt), (x, 0.0, hgt / 2), "red", upright=True)
        box((0.1, 0.04, hgt * 0.7), (x, -0.02, hgt * 0.35), "ember", upright=True)
        if level > 0:
            box((0.06, 0.04, hgt * 0.4), (x, -0.04, hgt * 0.2), "gold", upright=True)
    box((0.12 * n + 0.1, 0.04, 0.05), (0, -0.05, 0.025), "gold", upright=True)


def fire():
    rows = []
    for level in range(3):
        frames = []
        for f in range(4):
            flames(level, f)
            frames.append(shoot(32, 24, 0.0, 0.3))
        rows.append(sheet(frames))
    img = np.concatenate(rows, axis=0)
    P.save_png(img, os.path.join(OUT, "fire.png"))
    save_preview(img, "kitchen_fire.png", 4)
    print("rendered fire", flush=True)


# ------------------------------------------------------------------ 菜

def plate():
    cyl(0.3, 0.4, 0.05, (0, 0, 0), "sack", segs=20)
    cyl(0.36, 0.36, 0.01, (0, 0, 0.05), "radish", segs=20)


def bowl(fill):
    cyl(0.2, 0.36, 0.22, (0, 0, 0), "quilt", segs=20)
    cyl(0.31, 0.31, 0.01, (0, 0, 0.22), fill, segs=20)


def cup(fill):
    cyl(0.2, 0.24, 0.3, (0, 0, 0), "radish", segs=16)
    cyl(0.2, 0.2, 0.01, (0, 0, 0.3), fill, segs=16)


def dish_bamboo_stir():
    """炒春笋：一盘斜切的笋片，撒了葱花。"""
    plate()
    # 笋片是尖头的，横着码成一排
    for i, (x, y, ang) in enumerate(((-0.17, 0.05, 80), (-0.04, -0.04, 100), (0.1, 0.06, 75), (0.2, -0.05, 95))):
        cyl(0.085, 0.01, 0.3, (x, y, 0.12), "paper" if i % 2 else "petal_y", rot=(90, 0, ang - 90), segs=6,
            center=True)
    for x, y in ((-0.12, -0.1), (0.04, 0.12), (0.16, 0.0), (-0.02, 0.02)):
        box((0.06, 0.06, 0.03), (x, y, 0.2), "leaf")


def dish_fern_salad():
    """凉拌蕨菜：一盘深绿的长条，点着红椒。"""
    plate()
    rnd = random.Random(12)
    for i in range(9):
        box((0.36, 0.045, 0.04), (rnd.uniform(-0.06, 0.06), -0.16 + i * 0.04, 0.08 + (i % 2) * 0.04),
            "leaf_dk" if i % 3 else "bamboo", rot=(0, 0, rnd.uniform(-25, 25)))
    for x, y in ((-0.08, 0.02), (0.1, -0.06), (0.0, 0.1)):
        box((0.05, 0.05, 0.03), (x, y, 0.17), "red")


def dish_bayberry_drink():
    """杨梅饮：白杯里紫红的汤，浮着两颗杨梅。"""
    cup("petal_v")
    ball((0.07, 0.07, 0.05), (-0.06, 0.0, 0.32), "red")
    ball((0.06, 0.06, 0.05), (0.07, -0.03, 0.32), "red")


def dish_wheat_rice():
    """新麦饭：蓝碗里堆起来的麦饭，麦粒黄。"""
    bowl("sack")
    ball((0.26, 0.26, 0.12), (0, 0, 0.25), "sack")
    for x, y in ((-0.1, -0.04), (0.06, 0.02), (0.0, -0.1), (0.12, -0.08), (-0.04, 0.08)):
        box((0.05, 0.05, 0.03), (x, y, 0.36), "gold")


def dish_mint_drink():
    """薄荷饮：白杯里浅绿的水，一片薄荷叶。"""
    cup("jade")
    box((0.14, 0.08, 0.02), (0.02, -0.02, 0.32), "leaf", rot=(0, 0, 30))
    box((0.05, 0.05, 0.02), (-0.08, 0.04, 0.32), "petal_w")


def dish_chestnut_porridge():
    """栗子粥：蓝碗白粥，几颗栗子。"""
    bowl("linen")
    for x, y in ((-0.1, 0.02), (0.08, -0.06), (0.04, 0.1)):
        ball((0.07, 0.07, 0.05), (x, y, 0.24), "wood")


def dish_salted_soybean():
    """盐水毛豆：一盘带壳的绿豆荚。"""
    plate()
    rnd = random.Random(17)
    for i in range(7):
        a = i * 0.9
        ball((0.13, 0.05, 0.04), (math.cos(a) * 0.13, math.sin(a) * 0.11, 0.1 + (i % 3) * 0.035),
             "bamboo" if i % 2 else "leaf", rot=(0, 0, rnd.uniform(0, 180)))


def dish_baked_persimmon():
    """烘柿：盘里两只橙红的柿子，顶上带蒂。"""
    plate()
    for x, y in ((-0.13, 0.02), (0.13, -0.04)):
        ball((0.13, 0.13, 0.11), (x, y, 0.17), "ember")
        box((0.09, 0.09, 0.03), (x, y, 0.28), "leaf_dk")


def dish_oyster_egg():
    """牡蛎煎蛋：一张黄蛋饼，嵌着灰白的牡蛎，撒葱花。"""
    plate()
    cyl(0.29, 0.27, 0.06, (0, 0, 0.06), "petal_y", segs=16)
    for x, y in ((-0.12, 0.04), (0.08, 0.08), (0.02, -0.1), (0.15, -0.05)):
        ball((0.06, 0.05, 0.03), (x, y, 0.13), "steel")
    for x, y in ((-0.04, -0.02), (0.1, 0.0), (-0.14, -0.08)):
        box((0.04, 0.04, 0.02), (x, y, 0.14), "leaf")


def dish_scallion_cake():
    """葱油饼：一叠金黄的饼，面上几段葱。"""
    plate()
    for i in range(4):
        cyl(0.26 - i * 0.02, 0.24 - i * 0.02, 0.035, (0, 0, 0.06 + i * 0.04), "petal_y", segs=16)
    for x, y in ((-0.08, 0.02), (0.06, -0.04), (0.0, 0.08), (0.1, 0.06)):
        box((0.08, 0.03, 0.02), (x, y, 0.24), "leaf")


def dish_wine_balls():
    """酒酿圆子：一碗浅汤，浮着白圆子。"""
    bowl("paper")
    for x, y, z in ((-0.1, 0.02, 0.24), (0.08, -0.04, 0.25), (0.0, 0.08, 0.26), (-0.02, -0.08, 0.23)):
        ball((0.07, 0.07, 0.06), (x, y, z), "linen")


def dish_stir_purse():
    """清炒荠菜：一盘细长的绿叶。"""
    plate()
    rnd = random.Random(21)
    for i in range(8):
        box((0.28, 0.04, 0.035), (rnd.uniform(-0.04, 0.04), -0.14 + i * 0.04, 0.09),
            "leaf" if i % 2 else "bamboo", rot=(0, 0, rnd.uniform(-20, 20)))


def dish_roast_mushroom():
    """烤野菇：两朵褐色的菇，帽上有纹。"""
    plate()
    for x, y in ((-0.1, 0.02), (0.12, -0.04)):
        cyl(0.04, 0.05, 0.08, (x, y, 0.06), "wood_dk", segs=8)
        ball((0.11, 0.11, 0.06), (x, y, 0.16), "soil")


def dish_loquat_honey():
    """蜜渍枇杷：几颗橙黄的果，亮着蜜。"""
    plate()
    for i, (x, y) in enumerate(((-0.12, 0.04), (0.02, -0.06), (0.14, 0.05), (0.0, 0.1))):
        ball((0.08, 0.08, 0.07), (x, y, 0.14), "gold" if i % 2 else "petal_y")
        box((0.03, 0.03, 0.04), (x, y, 0.22), "leaf_dk")


def dish_watermelon_cup():
    """西瓜盅：半只红瓤的西瓜，嵌着一点瓜子。"""
    cyl(0.22, 0.3, 0.16, (0, 0, 0), "leaf_dk", segs=16)
    cyl(0.2, 0.26, 0.04, (0, 0, 0.16), "red", segs=16)
    for x, y in ((-0.06, 0.02), (0.05, -0.03), (0.0, 0.06)):
        box((0.03, 0.02, 0.02), (x, y, 0.21), "ink")


def dish_wintersweet_tea():
    """腊梅茶：一杯黄茶，浮着两朵小花。"""
    cup("gold")
    ball((0.04, 0.04, 0.03), (-0.04, 0.0, 0.32), "petal_y")
    ball((0.035, 0.035, 0.025), (0.05, -0.02, 0.32), "petal_y")


def dish_sesame_pumpkin():
    """芝麻南瓜饼：两块橙饼，撒着芝麻。"""
    plate()
    for x, y in ((-0.1, 0.02), (0.1, -0.02)):
        cyl(0.12, 0.12, 0.05, (x, y, 0.06), "ember", segs=14)
        for dx, dy in ((-0.03, 0.02), (0.02, -0.02), (0.0, 0.03)):
            box((0.025, 0.025, 0.02), (x + dx, y + dy, 0.12), "ink")


def dish_chestnut_yam():
    """栗子煨红薯：一只红薯，旁边两颗栗子。"""
    plate()
    ball((0.16, 0.1, 0.08), (-0.04, 0.0, 0.14), "clay", rot=(0, 0, 20))
    ball((0.07, 0.07, 0.05), (0.14, 0.06, 0.12), "wood")
    ball((0.06, 0.06, 0.045), (0.16, -0.08, 0.12), "wood_dk")


def dish_pan_loach():
    """干煎泥鳅：一口铁锅，一条褐色的泥鳅，旁边一根锅柄。"""
    cyl(0.26, 0.34, 0.05, (0, 0, 0), "iron", segs=16)
    box((0.14, 0.05, 0.04), (0.28, 0.0, 0.04), "wood_dk")
    ball((0.2, 0.055, 0.035), (-0.02, 0.0, 0.08), "soil", rot=(0, 0, 18))
    box((0.03, 0.03, 0.02), (0.08, 0.02, 0.1), "ink")


def dish_vinegar_carp():
    """醋溜鲤鱼：盘里一条橙鲤，身上一道红醋。"""
    plate()
    ball((0.26, 0.09, 0.05), (0, 0.0, 0.12), "clay", rot=(0, 0, -16))
    box((0.18, 0.05, 0.03), (0.0, 0.0, 0.17), "red", rot=(0, 0, -16))
    box((0.03, 0.03, 0.02), (0.1, 0.04, 0.16), "ink")


def dish_steam_grass_carp():
    """清蒸草鱼：盘里一条绿草鱼。"""
    plate()
    ball((0.28, 0.1, 0.055), (0, 0.0, 0.12), "leaf", rot=(0, 0, 12))
    ball((0.08, 0.05, 0.03), (0.02, 0.0, 0.16), "willow")
    box((0.03, 0.03, 0.02), (0.12, 0.03, 0.15), "ink")


def dish_steam_sharpbelly():
    """清蒸白条：盘里两条细银鱼。"""
    plate()
    ball((0.2, 0.035, 0.025), (-0.02, 0.05, 0.1), "steel", rot=(0, 0, 14))
    ball((0.16, 0.03, 0.02), (0.04, -0.06, 0.1), "steel", rot=(0, 0, -10))
    box((0.02, 0.02, 0.015), (0.06, 0.06, 0.12), "ink")


def dish_clam_soup():
    """蛤蜊萝卜汤：白汤里一片灰壳、一片浅壳，一块白萝卜。"""
    bowl("linen")
    ball((0.09, 0.06, 0.04), (-0.08, -0.02, 0.26), "stone")
    ball((0.07, 0.05, 0.03), (0.01, 0.06, 0.27), "radish")
    box((0.07, 0.06, 0.06), (0.09, -0.04, 0.28), "paper")


def dish_winter_shoot():
    """炒冬笋：盘里三片厚笋，没有葱。"""
    plate()
    for x, y, ang, mat in ((-0.12, 0.04, 75, "paper"), (0.0, -0.02, 95, "straw"), (0.13, 0.05, 80, "paper")):
        cyl(0.07, 0.02, 0.26, (x, y, 0.12), mat, rot=(90, 0, ang - 90), segs=6, center=True)


def dish_chili_potato():
    """辣椒炒土豆：黄土豆块，两根红辣椒。"""
    plate()
    for x, y in ((-0.1, 0.06), (0.06, -0.07), (0.1, 0.08), (-0.04, 0.0)):
        box((0.08, 0.07, 0.05), (x, y, 0.1), "sack")
    box((0.18, 0.045, 0.035), (0.02, -0.02, 0.16), "red", rot=(0, 0, 32))
    box((0.14, 0.04, 0.03), (-0.08, 0.05, 0.16), "red", rot=(0, 0, -38))


def dish_pickle_rice():
    """腌菜炒饭：白米饭，两丝深色腌菜，一块蛋黄。"""
    bowl("linen")
    cyl(0.16, 0.16, 0.04, (0, 0, 0.22), "linen", segs=14)
    box((0.12, 0.04, 0.03), (-0.04, 0.02, 0.28), "leaf_dk", rot=(0, 0, 24))
    box((0.1, 0.035, 0.03), (0.06, -0.05, 0.28), "leaf_dk", rot=(0, 0, -18))
    box((0.07, 0.06, 0.04), (0.02, 0.05, 0.3), "petal_y")


def dish_caltrop_porridge():
    """菱角粥：白粥上两只尖菱角。"""
    bowl("linen")
    box((0.16, 0.03, 0.03), (-0.06, 0.02, 0.27), "wood_dk", rot=(0, 0, 52))
    box((0.14, 0.03, 0.03), (0.08, -0.03, 0.27), "soil", rot=(0, 0, -42))


def dish_hawthorn_cake():
    """山楂糕：一块红糕，面上几点糖。"""
    plate()
    box((0.28, 0.18, 0.08), (0, 0, 0.1), "red")
    for x, y in ((-0.06, 0.02), (0.05, -0.02), (0.0, 0.04), (0.07, 0.03)):
        box((0.03, 0.03, 0.02), (x, y, 0.15), "gold")


def dish_kelp_soup():
    """海带汤：白汤上三条深绿的带子。"""
    bowl("linen")
    for ang, z in ((-24, 0.27), (12, 0.29), (38, 0.28)):
        box((0.2, 0.05, 0.04), (0, 0, z), "leaf_dk", rot=(0, 0, ang))


def dish_chrys_tea():
    """菊花茶：浅茶上是一朵黄菊花，花心深一点。腊梅茶是黄汤里两朵小花。"""
    cup("paper")
    for ang in range(0, 360, 45):
        rad = math.radians(ang)
        ball((0.055, 0.03, 0.02), (math.cos(rad) * 0.07, math.sin(rad) * 0.048, 0.35), "petal_y")
    ball((0.04, 0.04, 0.025), (0, 0, 0.38), "ember")


def dish_steam_fog_carp():
    """清蒸雾鲤王：盘里一条又大又白的鲤。"""
    plate()
    ball((0.34, 0.12, 0.06), (0, 0, 0.14), "linen", rot=(0, 0, -8))
    ball((0.1, 0.06, 0.03), (0.04, 0.0, 0.18), "steel")
    box((0.035, 0.03, 0.02), (0.14, 0.04, 0.17), "ink")


def dish_catfish_soup():
    """井鲶萝卜汤：白汤里一只宽黑头，旁边一块白萝卜。"""
    bowl("linen")
    ball((0.16, 0.12, 0.05), (-0.05, 0.0, 0.27), "ink")
    box((0.04, 0.03, 0.02), (0.0, 0.04, 0.32), "gold")
    box((0.08, 0.06, 0.05), (0.1, -0.03, 0.28), "radish")


def dish_tide_soup():
    """潮生鱼羹：浅汤里三块发蓝的鱼。"""
    bowl("linen")
    ball((0.09, 0.06, 0.04), (-0.07, 0.02, 0.27), "quilt")
    ball((0.08, 0.055, 0.04), (0.08, -0.04, 0.28), "can")
    ball((0.06, 0.045, 0.03), (0.0, 0.07, 0.29), "quilt_hi")


def dish_giant_melon():
    """整瓜盏：比西瓜盅更大的一盏，绿皮红瓤，籽多。"""
    cyl(0.28, 0.38, 0.18, (0, 0, 0), "leaf_dk", segs=16)
    cyl(0.24, 0.32, 0.05, (0, 0, 0.18), "red", segs=16)
    for x, y in ((-0.1, 0.02), (0.08, -0.05), (0.0, 0.08), (-0.04, -0.08), (0.1, 0.06), (0.02, -0.01)):
        box((0.03, 0.02, 0.02), (x, y, 0.24), "ink")


# 名字, 画法, 冒不冒热气
DISHES = [
    ("bamboo_stir", dish_bamboo_stir, True),
    ("fern_salad", dish_fern_salad, False),
    ("bayberry_drink", dish_bayberry_drink, False),
    ("wheat_rice", dish_wheat_rice, True),
    ("mint_drink", dish_mint_drink, False),
    ("chestnut_porridge", dish_chestnut_porridge, True),
    ("salted_soybean", dish_salted_soybean, False),
    ("baked_persimmon", dish_baked_persimmon, True),
    ("oyster_egg", dish_oyster_egg, True),
    ("scallion_cake", dish_scallion_cake, True),
    ("wine_balls", dish_wine_balls, True),
    ("stir_purse", dish_stir_purse, True),
    ("roast_mushroom", dish_roast_mushroom, True),
    ("loquat_honey", dish_loquat_honey, False),
    ("watermelon_cup", dish_watermelon_cup, False),
    ("wintersweet_tea", dish_wintersweet_tea, True),
    ("sesame_pumpkin", dish_sesame_pumpkin, True),
    ("chestnut_yam", dish_chestnut_yam, True),
    ("pan_loach", dish_pan_loach, True),
    ("vinegar_carp", dish_vinegar_carp, True),
    ("steam_grass_carp", dish_steam_grass_carp, True),
    ("steam_sharpbelly", dish_steam_sharpbelly, True),
    ("clam_soup", dish_clam_soup, True),
    ("winter_shoot", dish_winter_shoot, True),
    ("chili_potato", dish_chili_potato, True),
    ("pickle_rice", dish_pickle_rice, True),
    ("caltrop_porridge", dish_caltrop_porridge, True),
    ("hawthorn_cake", dish_hawthorn_cake, True),
    ("kelp_soup", dish_kelp_soup, True),
    ("chrys_tea", dish_chrys_tea, True),
    ("steam_fog_carp", dish_steam_fog_carp, True),
    ("catfish_soup", dish_catfish_soup, True),
    ("tide_soup", dish_tide_soup, True),
    ("giant_melon", dish_giant_melon, False),
]


def steam(img, f):
    """和 tools/dish_art.py 一样的三点热气，每帧往上挪一格。"""
    for i, x in enumerate((12, 16, 21)):
        y = 6 - ((f + i) % 4)
        img[y, x] = (255, 255, 255, 180)
        img[y + 1, x] = (255, 255, 255, 90)


def shine(img, f):
    """凉的菜不冒气，隔一帧亮一个点。"""
    if f % 2 == 0:
        ys, xs = np.nonzero(img[..., 3])
        img[ys.min() + 3, 16 - 4] = (255, 255, 255, 220)


# 命令行在 dishes 后面写菜的 id，就只画这几道。空着表示 DISHES 里全部重画。
DISH_ONLY = []


def dishes():
    set_shear(0.5)
    rows = []
    for name, build, hot in DISHES:
        if DISH_ONLY and name not in DISH_ONLY:
            continue
        build()
        base = P.outline(shoot(32, 32, 0.0, 0.32))
        frames = []
        for f in range(4):
            im = base.copy()
            if hot:
                steam(im, f)
            else:
                shine(im, f)
            frames.append(im)
        img = sheet(frames)
        P.save_png(img, os.path.join(FOOD, name + ".png"))
        rows.append(img)
        print("rendered dish", name, flush=True)
    set_shear(1.0)
    save_preview(np.concatenate(rows, axis=0), "kitchen_dishes.png", 6)


def save_preview(img, name, scale):
    big = np.repeat(np.repeat(img, scale, axis=0), scale, axis=1)
    bg = np.zeros_like(big)
    bg[..., :3] = (58, 54, 60)
    bg[..., 3] = 255
    a = big[..., 3:4].astype(np.float32) / 255.0
    bg[..., :3] = (big[..., :3] * a + bg[..., :3] * (1 - a)).astype(np.uint8)
    os.makedirs(PREVIEW, exist_ok=True)
    P.save_png(bg, os.path.join(PREVIEW, name))


def main():
    global DISH_ONLY
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stages = ("stage", "pots", "fire", "dishes")
    todo = [a for a in args if a in stages]
    DISH_ONLY = [a for a in args if a not in stages]
    known = {name for name, _build, _hot in DISHES}
    missing = [name for name in DISH_ONLY if name not in known]
    if missing:
        raise SystemExit("没有这道菜：" + " ".join(missing))
    if not todo:
        todo = ["dishes"] if DISH_ONLY else ["stage", "pots", "fire", "dishes"]
    os.makedirs(P.TMP, exist_ok=True)
    os.makedirs(OUT, exist_ok=True)
    for name in todo:
        {"stage": stage, "pots": pots, "fire": fire, "dishes": dishes}[name]()
    shutil.rmtree(P.TMP, ignore_errors=True)


main()
