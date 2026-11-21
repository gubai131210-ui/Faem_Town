"""用 Blender 画亲手做菜（掌勺）那一屏要用的东西。

用法:  blender --background --python tools/stove.py -- [bench] [bits] [tools] [fire] [plate]
       不写就全部重画
输出:  art/cooking/bench/bench.png     384x216，灶台近景：左边案板，中间偏右一口大锅，锅下灶膛口，墙上窗、搁板、挂着的干货
       art/cooking/bench/bits.png      4 格，每格 16x16：丁、片、叶、蛋块。浅色，游戏里按食材染色
       art/cooking/bench/spatula.png   72x48，木铲，铲头在 (10, 38)
       art/cooking/bench/knife.png     48x40，菜刀，刀刃朝下，刃口在最底一行
       art/cooking/bench/fire.png      4 行（余火、小火、中火、旺火）x 4 帧，每帧 64x40，火根在格子底边正中
       art/cooking/bench/plate.png     160x96，出锅时的大盘
       _preview/bench_art.png          放大的预览
建模工具、材质和像素化都用 tools/props.py 的，颜色只来自 data/palette.json。
1 单位 = 32 像素。灶台是斜俯视（纵深压到六成），看得到灶身正面和灶膛口。
游戏里的坐标（features/ui/stove_workbench.gd）跟这里的 WOK、BOARD、MOUTH 对应，改了要一起改。
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
OUT = os.path.join(P.PROJ, "art", "cooking", "bench")
PREVIEW = os.path.join(P.PROJ, "_preview")
PPU = 32
W, H = 384, 216
TILT = 0.6
TOP = 1.5               # 台面高
WOK = (8.0, 2.3)        # 锅心（x, 纵深）。画面上是 (256, 124)
WOK_R = 1.75
BOARD = (2.5, 2.2)      # 案板中心。画面上是 (80, 126)
MOUTH = (8.0, 0.6)      # 灶膛口。画面上火根在 (256, 190)


def shoot(w, h, cx, cz, ppu=PPU):
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


def tilt(k):
    P.SHEAR[2][1] = k


def save(img, name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    tmp = path + ".tmp.png"
    P.save_png(img, tmp)
    os.replace(tmp, path)
    print("rendered", name, flush=True)


# ------------------------------------------------------------------ 灶台近景

def room():
    """地面一条、后墙、墙裙和梁。"""
    rnd = random.Random(3)
    box((12.4, 1.0, 0.04), (6, 0.2, -0.02), "wood_dk")
    x = -0.3
    while x < 12.2:
        box((0.86, 0.5, 0.05), (x + 0.45, 0.25, 0.0), "floor_a" if rnd.random() < 0.5 else "floor_b")
        x += 0.9
    box((12.4, 0.3, 6.0), (6, 4.45, 3.0), "plaster")
    box((12.4, 0.1, 0.34), (6, 4.28, TOP + 0.2), "stone_dk")
    box((12.4, 0.12, 0.3), (6, 4.27, 4.1), "wood_dk")


def wall_things():
    """墙上：左边一扇格子窗，中间一条搁板摆着罐子，右边挂着辣椒、蒜和一把漏勺。"""
    P.lattice_window(2.4, 4.28, 2.95, "paper", w=2.5, h=1.35)
    # 搁板和罐子
    box((2.6, 0.34, 0.08), (5.75, 4.16, 2.55), "wood")
    for sx in (-1.1, 1.1):
        box((0.1, 0.3, 0.3), (5.75 + sx, 4.18, 2.38), "wood_dk")
    for i, (mat, lid, r, hgt) in enumerate((("clay", "wood_dk", 0.24, 0.46), ("jade", "wood", 0.2, 0.36),
                                            ("quilt", "linen", 0.22, 0.42), ("sack", "wood_dk", 0.18, 0.32))):
        jx = 4.85 + i * 0.6
        cyl(r * 0.8, r, hgt, (jx, 4.12, 2.59), mat, segs=12)
        cyl(r * 0.7, r * 0.7, 0.06, (jx, 4.12, 2.59 + hgt), lid, segs=12)
    # 一串辣椒、一串蒜
    box((0.04, 0.04, 0.3), (9.9, 4.26, 3.75), "straw")
    for i in range(7):
        box((0.17, 0.08, 0.2), (9.84 + (i % 2) * 0.13, 4.24, 3.55 - i * 0.17), "red")
    box((0.04, 0.04, 0.3), (10.55, 4.26, 3.75), "straw")
    for i in range(5):
        ball((0.13, 0.08, 0.12), (10.48 + (i % 2) * 0.15, 4.24, 3.5 - i * 0.2), "linen", upright=False)
    # 漏勺和锅铲挂在钉子上
    box((0.06, 0.05, 1.0), (11.25, 4.25, 3.2), "wood_dk")
    cyl(0.22, 0.22, 0.06, (11.25, 4.23, 2.6), "steel", rot=(90, 0, 0), segs=12, center=True)
    box((1.6, 0.06, 0.06), (10.6, 4.26, 3.9), "wood_dk")


def counter():
    """左边的木案：案面、两条腿、底下一只竹篮。"""
    box((4.5, 3.5, 0.14), (2.35, 2.45, TOP - 0.07), "wood")
    box((4.5, 0.08, 0.26), (2.35, 0.7, TOP - 0.2), "wood_dk")
    for x in (0.35, 4.35):
        box((0.22, 0.2, TOP - 0.2), (x, 0.82, (TOP - 0.2) / 2), "wood_dk")
    cyl(0.5, 0.62, 0.5, (1.5, 1.3, 0.0), "straw", segs=14)
    for i, mat in enumerate(("leaf", "leaf_dk", "leaf")):
        ball((0.26, 0.2, 0.16), (1.3 + i * 0.22, 1.3, 0.56), mat, upright=False)
    cyl(0.42, 0.5, 0.42, (3.2, 1.25, 0.0), "clay", segs=14)
    cyl(0.44, 0.44, 0.03, (3.2, 1.25, 0.42), "soil", segs=14)


def board():
    """案板，和案上的几只小碗。"""
    box((3.1, 1.9, 0.12), (BOARD[0], BOARD[1], TOP + 0.06), "sack")
    box((3.0, 1.8, 0.02), (BOARD[0], BOARD[1], TOP + 0.13), "straw")
    box((0.3, 0.34, 0.1), (BOARD[0] - 1.72, BOARD[1], TOP + 0.05), "wood_dk")
    for i, fill in enumerate(("leaf", "red", "petal_y")):
        bx = 1.0 + i * 0.95
        cyl(0.24, 0.36, 0.2, (bx, 3.65, TOP), "quilt_hi", segs=14)
        cyl(0.3, 0.3, 0.02, (bx, 3.65, TOP + 0.2), fill, segs=14)
    # 一块抹布
    box((0.8, 0.5, 0.04), (3.9, 3.75, TOP + 0.02), "linen", rot=(0, 0, 12))
    box((0.8, 0.1, 0.045), (3.9, 3.75, TOP + 0.02), "quilt", rot=(0, 0, 12))


def stove():
    """土灶：白灶身黑压边，一眼大灶，正面开着灶膛口，旁边画一朵花。靠墙一排调料。"""
    cx, cy = 8.3, 2.45
    box((7.0, 3.6, TOP), (cx, cy, TOP / 2), "plaster")
    box((7.1, 3.7, 0.1), (cx, cy, TOP - 0.02), "ink")
    box((6.86, 3.46, 0.02), (cx, cy, TOP + 0.04), "stone_dk")
    box((7.0, 0.05, 0.14), (cx, 0.63, 0.07), "ink")
    # 灶膛口
    box((1.5, 0.05, 1.0), (MOUTH[0], 0.64, 0.62), "stone_dk")
    box((1.24, 0.06, 0.84), (MOUTH[0], 0.62, 0.56), "ink")
    box((1.7, 0.2, 0.08), (MOUTH[0], 0.56, 0.1), "stone_dk")
    # 灶身上画的花
    for fx in (5.6, 10.6):
        for dx, dz, mat in ((0, 0, "blossom"), (-0.16, 0.02, "leaf_dk"), (0.16, 0.02, "leaf_dk"),
                            (0, 0.16, "blossom"), (0, -0.18, "leaf_dk")):
            box((0.16, 0.03, 0.16), (fx + dx, 0.63, 0.82 + dz), mat)
    # 靠墙的调料：酱油瓶、醋瓶、盐罐、一碗葱花
    cyl(0.14, 0.17, 0.5, (5.35, 3.85, TOP + 0.05), "soil", segs=10)
    cyl(0.07, 0.07, 0.16, (5.35, 3.85, TOP + 0.55), "ink", segs=8)
    cyl(0.14, 0.17, 0.44, (5.8, 3.9, TOP + 0.05), "clay", segs=10)
    cyl(0.07, 0.07, 0.14, (5.8, 3.9, TOP + 0.49), "wood_dk", segs=8)
    cyl(0.2, 0.22, 0.26, (10.75, 3.85, TOP + 0.05), "linen", segs=12)
    cyl(0.17, 0.17, 0.03, (10.75, 3.85, TOP + 0.31), "petal_w", segs=12)
    cyl(0.2, 0.3, 0.16, (11.3, 3.8, TOP + 0.05), "quilt_hi", segs=12)
    cyl(0.25, 0.25, 0.02, (11.3, 3.8, TOP + 0.21), "leaf", segs=12)
    # 灶边靠着火钳，地上一小堆柴
    box((0.06, 0.06, 1.2), (11.55, 0.55, 0.6), "iron", rot=(0, 8, 0))
    rnd = random.Random(5)
    for row, n in enumerate((3, 2)):
        for i in range(n):
            cyl(0.14, 0.14, 0.7, (10.2 + i * 0.3 + row * 0.15, 0.2, 0.14 + row * 0.25),
                "wood" if rnd.random() < 0.6 else "wood_dk", rot=(90, 0, 0), segs=8, center=True)


def wok():
    """一口大铁锅：宽锅沿，锅壁一圈比一圈深，两只耳。"""
    x, y = WOK
    z = TOP + 0.04
    cyl(WOK_R + 0.12, WOK_R + 0.12, 0.05, (x, y, z), "ink", segs=28)
    cyl(WOK_R, WOK_R, 0.07, (x, y, z + 0.03), "iron", segs=28)
    cyl(WOK_R - 0.16, WOK_R - 0.16, 0.02, (x, y, z + 0.1), "ink", segs=28)
    cyl(WOK_R - 0.55, WOK_R - 0.55, 0.02, (x, y - 0.06, z + 0.105), "iron", segs=24)
    cyl(WOK_R - 0.95, WOK_R - 0.95, 0.02, (x, y - 0.1, z + 0.11), "ink", segs=20)
    for sx in (-1, 1):
        box((0.22, 0.5, 0.1), (x + sx * (WOK_R + 0.1), y, z + 0.06), "iron")


def bench():
    tilt(TILT)
    layers = []
    for build, edge in ((room, False), (wall_things, True), (counter, True), (stove, True),
                        (board, True), (wok, True)):
        build()
        img = P.texture(shoot(W, H, 6.0, H / 2.0 / PPU))
        layers.append(P.outline(img) if edge else img)
    out = np.zeros((H, W, 4), dtype=np.uint8)
    out[..., :3] = P.hex_rgb(P.RAMPS["ink"][2])
    out[..., 3] = 255
    for img in layers:
        over(out, img)
    save(out, "bench.png")
    return out


# ------------------------------------------------------------------ 锅里的碎料

def bits():
    """四种形状，都用最浅的料，游戏里按食材的颜色染。"""
    tilt(TILT)
    frames = []
    for kind in range(4):
        if kind == 0:
            box((0.26, 0.26, 0.2), (0, 0, 0), "radish", rot=(0, 0, 18))
        elif kind == 1:
            cyl(0.21, 0.21, 0.07, (0, 0, 0), "radish", segs=10)
        elif kind == 2:
            box((0.4, 0.2, 0.04), (0, 0, 0), "radish", rot=(0, 0, 28))
            box((0.3, 0.05, 0.05), (0, 0, 0.01), "linen", rot=(0, 0, 28))
        else:
            ball((0.2, 0.17, 0.1), (-0.03, 0.0, 0.08), "radish", upright=False)
            ball((0.13, 0.12, 0.08), (0.1, 0.06, 0.07), "radish", upright=False)
        frames.append(P.outline(shoot(16, 16, 0.0, 0.08)))
    img = np.concatenate(frames, axis=1)
    save(img, "bits.png")
    return img


# ------------------------------------------------------------------ 铲和刀

def spatula():
    """木铲。柄朝右上，铲头落在左下。"""
    tilt(TILT)
    ang = 32.0
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    box((1.7, 0.13, 0.07), (ux * 0.95, uy * 0.95, 0.1), "wood_dk", rot=(0, 0, ang))
    box((0.5, 0.36, 0.06), (ux * 0.02, uy * 0.02, 0.08), "wood", rot=(0, 0, ang))
    img = P.outline(shoot(72, 48, 0.8, 0.55))
    save(img, "spatula.png")
    return img


def knife():
    """菜刀：正面看，宽刀身，刃口朝下，木柄朝右。"""
    tilt(0.0)
    box((0.86, 0.05, 0.56), (-0.1, 0.0, 0.3), "steel")
    box((0.86, 0.06, 0.08), (-0.1, -0.01, 0.06), "petal_w")
    box((0.86, 0.06, 0.07), (-0.1, -0.01, 0.56), "iron")
    box((0.46, 0.1, 0.16), (0.52, 0.0, 0.46), "wood_dk")
    box((0.06, 0.11, 0.18), (0.36, 0.0, 0.46), "gold")
    img = P.outline(shoot(48, 40, 0.1, 0.58))
    save(img, "knife.png")
    return img


# ------------------------------------------------------------------ 火

def flames(level, f):
    rnd = random.Random(level * 7 + f)
    n = 3 + level * 2
    for i in range(n):
        x = (i - (n - 1) / 2.0) * 0.17 + rnd.uniform(-0.04, 0.04)
        mid = 1.0 - abs(i - (n - 1) / 2.0) / (n / 2.0 + 0.5) * 0.5
        hgt = (0.2 + level * 0.24) * rnd.uniform(0.7, 1.25) * mid
        box((0.2, 0.04, hgt), (x, 0.0, hgt / 2), "red")
        box((0.14, 0.04, hgt * 0.72), (x, -0.02, hgt * 0.36), "ember")
        if level > 0:
            box((0.08, 0.04, hgt * 0.42), (x, -0.04, hgt * 0.21), "gold")
    box((0.17 * n + 0.1, 0.04, 0.07), (0, -0.05, 0.035), "gold" if level > 0 else "ember")


def fire():
    tilt(0.0)
    rows = []
    for level in range(4):
        frames = []
        for f in range(4):
            flames(level, f)
            frames.append(shoot(64, 40, 0.0, 0.625))
        rows.append(np.concatenate(frames, axis=1))
    img = np.concatenate(rows, axis=0)
    save(img, "fire.png")
    return img


# ------------------------------------------------------------------ 盘子

def plate():
    """出锅的大盘：白盘蓝边，底下垫一块木托。"""
    tilt(TILT)
    box((4.6, 2.9, 0.1), (0, 0, 0), "wood")
    box((4.4, 2.7, 0.02), (0, 0, 0.06), "wood_dk")
    cyl(1.5, 2.0, 0.16, (0, 0, 0.08), "radish", segs=30)
    cyl(1.95, 1.95, 0.02, (0, 0, 0.24), "quilt_hi", segs=30)
    cyl(1.78, 1.78, 0.02, (0, 0, 0.25), "radish", segs=30)
    cyl(1.3, 1.3, 0.02, (0, 0, 0.26), "linen", segs=26)
    img = P.outline(P.texture(shoot(160, 96, 0.0, 0.1)))
    save(img, "plate.png")
    return img


def save_preview(parts):
    hgt = sum(p.shape[0] for p in parts) + 4 * (len(parts) + 1)
    wid = max(p.shape[1] for p in parts) + 8
    sheet = np.zeros((hgt, wid, 4), dtype=np.uint8)
    sheet[..., :3] = (58, 54, 60)
    sheet[..., 3] = 255
    y = 4
    for p in parts:
        a = p[..., 3:4].astype(np.float32) / 255.0
        region = sheet[y:y + p.shape[0], 4:4 + p.shape[1], :3]
        sheet[y:y + p.shape[0], 4:4 + p.shape[1], :3] = (p[..., :3] * a + region * (1 - a)).astype(np.uint8)
        y += p.shape[0] + 4
    big = np.repeat(np.repeat(sheet, 2, axis=0), 2, axis=1)
    os.makedirs(PREVIEW, exist_ok=True)
    P.save_png(big, os.path.join(PREVIEW, "bench_art.png"))


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    stages = {"bench": bench, "bits": bits, "tools": lambda: np.concatenate(
        [np.pad(spatula(), ((0, 0), (0, 0), (0, 0))), np.pad(knife(), ((0, 8), (0, 0), (0, 0)))], axis=1),
        "fire": fire, "plate": plate}
    todo = [a for a in args if a in stages] or list(stages)
    os.makedirs(P.TMP, exist_ok=True)
    parts = [stages[name]() for name in todo]
    save_preview(parts)
    shutil.rmtree(P.TMP, ignore_errors=True)


if __name__ == "__main__":
    main()
