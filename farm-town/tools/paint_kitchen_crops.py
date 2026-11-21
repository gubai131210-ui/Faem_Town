"""按游戏里的 16×24 原尺寸绘制六种常见作物的三段地上形态。"""

import os
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent / "art" / "crops"
CELL = (16, 24)
STEM = "#55704a"
SHADOW = "#3f5942"
LEAF = "#699550"
LIGHT = "#92b165"
VEIN = "#b1c380"
EDGE = "#2d4036"


def leaf(d, root, tip, width=2, color=LEAF):
    x, y = root
    tx, ty = tip
    mx, my = (x+tx)//2, (y+ty)//2
    d.polygon([(x, y), (mx-width, my), (tx, ty), (mx+width, my-1)], fill=SHADOW)
    d.polygon([(x, y-1), (mx-width, my-1), (tx, ty), (mx+width-1, my-1)], fill=color)
    d.line([root, (mx, my), tip], fill=LIGHT)


def sprout(d, count):
    d.line([(8, 19), (8, 14-count)], fill=STEM)
    leaf(d, (8, 18), (4-count, 13), 2)
    leaf(d, (8, 17), (11+count, 12-count), 2, LIGHT)


def cabbage(d, stage):
    if stage == 3:
        leaf(d, (8, 19), (2, 12), 3)
        leaf(d, (8, 19), (13, 12), 3)
    leaf(d, (8, 20), (8, 7 if stage == 3 else 11), 4)
    leaf(d, (8, 20), (4, 9 if stage == 3 else 12), 3)
    leaf(d, (8, 20), (12, 9 if stage == 3 else 13), 3, LIGHT)
    d.polygon([(7, 19), (6, 14), (8, 12), (9, 17), (10, 13), (10, 19)], fill="#ecedc1")
    d.line([(8, 19), (7, 16), (5, 15)], fill=VEIN)


def radish(d, stage):
    if stage == 3:
        d.polygon([(5, 16), (11, 16), (12, 18), (10, 20), (7, 20), (5, 19)], fill="#d1d2c0")
        d.line([(6, 17), (10, 17), (10, 18), (7, 18)], fill="#fff2dc")
        d.line([(8, 20), (7, 21)], fill="#b4a895")
    leaf(d, (8, 17 if stage == 3 else 20), (3, 8 if stage == 3 else 12), 2)
    leaf(d, (8, 17 if stage == 3 else 20), (12, 8 if stage == 3 else 12), 2)
    leaf(d, (8, 17 if stage == 3 else 20), (8, 6 if stage == 3 else 11), 2, LIGHT)


def rapeseed(d, stage):
    d.line([(8, 20), (8, 7 if stage == 3 else 12)], fill=STEM, width=2)
    leaf(d, (8, 17), (2, 13), 2)
    leaf(d, (8, 14), (13, 10), 2)
    if stage == 3:
        for x, y in ((6, 8), (10, 8), (8, 5), (5, 11), (11, 10)):
            d.line([(8, 12), (x, y)], fill=STEM)
            d.point((x, y-1), fill="#fff4a0")
            d.line([(x-1, y), (x+1, y)], fill="#efc257")
            d.point((x, y+1), fill="#ca8d39")


def fruiting(d, stage, kind):
    tall = kind == "番茄"
    d.line([(7, 20), (8, 7 if tall else 12)], fill=STEM)
    if tall:
        d.line([(13, 20), (13, 5)], fill="#896748")
        d.line([(7, 12), (13, 12)], fill="#b5955c")
    for base, tip, w in (((8, 17), (2, 13), 3), ((8, 15), (13, 11), 3), ((8, 13), (4, 9 if tall else 11), 2)):
        leaf(d, base, tip, w)
    if tall:
        leaf(d, (8, 11), (10, 6), 2)
    if stage == 3:
        if kind == "辣椒":
            for x, y, dx in ((4, 14, -1), (10, 13, 1), (8, 16, 0)):
                d.line([(x, y-1), (x, y)], fill=LIGHT)
                d.polygon([(x-1, y), (x+1, y), (x+dx, y+4), (x+2*dx, y+5)], fill="#c9493c")
                d.point((x, y+1), fill="#f0865e")
        else:
            for x, y in ((5, 13), (11, 16), (8, 18)):
                d.polygon([(x-2, y-1), (x, y-2), (x+2, y-1), (x+2, y+1),
                           (x, y+2), (x-2, y+1)], fill="#cf4f3e" if tall else "#c9555b")
                d.point((x-1, y-1), fill="#f89467")
                d.point((x, y-2), fill=LIGHT)
                if not tall:
                    d.point((x+1, y+1), fill="#efc48c")


def finish(img):
    alpha = img.getchannel("A")
    out = Image.new("RGBA", CELL)
    d = ImageDraw.Draw(out)
    for y in range(1, CELL[1]-1):
        for x in range(1, CELL[0]-1):
            if not alpha.getpixel((x, y)) and any(alpha.getpixel((x+dx, y+dy))
                                                    for dx, dy in ((-1,0),(1,0),(0,-1),(0,1))):
                d.point((x, y), EDGE)
    out.alpha_composite(img)
    return out


atlas = Image.new("RGBA", (CELL[0]*3, CELL[1]*6))
for row, name in enumerate(("白萝卜", "小白菜", "油菜", "番茄", "辣椒", "草莓")):
    for stage in range(1, 4):
        img = Image.new("RGBA", CELL)
        d = ImageDraw.Draw(img)
        if stage == 1:
            sprout(d, row % 2)
        elif name == "白萝卜":
            radish(d, stage)
        elif name == "小白菜":
            cabbage(d, stage)
        elif name == "油菜":
            rapeseed(d, stage)
        else:
            fruiting(d, stage, name)
        atlas.alpha_composite(finish(img), ((stage-1)*CELL[0], row*CELL[1]))

ROOT.mkdir(exist_ok=True)
target = ROOT / "kitchen_crops.png"
tmp = target.with_suffix(".tmp.png")
atlas.save(tmp)
os.replace(tmp, target)
