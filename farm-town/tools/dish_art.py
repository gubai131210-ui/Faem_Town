"""每道菜一张 32×32 的四帧：热气、油光、汤面会动。

用法：D:\\Miniconda3\\python.exe tools\\dish_art.py
输出：art/food/<id>.png，以及 _preview/dishes.png
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
OUT = os.path.join(PROJ, "art", "food")
CELL = 32


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK = C("2a2420")
PLATE = C("f7f1e4")
PLATE_RIM = C("c4b49a")
BOWL = C("6a90b8")
BOWL_DK = C("3a5878")
STEAM = C("ffffff", 180)


def blank():
    return Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < CELL and 0 <= y < CELL and c[3] > 0:
        im.putpixel((int(x), int(y)), c)


def rect(im, x, y, w, h, c):
    for yy in range(int(y), int(y + h)):
        for xx in range(int(x), int(x + w)):
            px(im, xx, yy, c)


def disc(im, cx, cy, rx, ry, c):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if rx > 0 and ry > 0 and ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1:
                px(im, x, y, c)


def steam(im, frame):
    shift = frame % 4
    for i, x in enumerate((12, 16, 21)):
        y = 6 - ((shift + i) % 4)
        px(im, x, y, STEAM)
        px(im, x, y + 1, C("ffffff", 90))


def plate(im):
    disc(im, 16, 22, 13, 6, INK)
    disc(im, 16, 21, 12, 5, PLATE_RIM)
    disc(im, 16, 20, 10, 4, PLATE)


def bowl(im, fill):
    disc(im, 16, 20, 12, 8, INK)
    disc(im, 16, 19, 11, 7, BOWL_DK)
    disc(im, 16, 18, 10, 6, BOWL)
    disc(im, 16, 16, 8, 4, fill)
    rect(im, 8, 14, 16, 1, C("d8e4ee"))


def soup(fill, bits, hot=True):
    frames = []
    for f in range(4):
        im = blank()
        bowl(im, C(fill))
        for i, (x, y) in enumerate(bits):
            px(im, x, y + (f + i) % 2, C(bits and "ffffff"))
            px(im, x, y, C(bits[i][2]) if False else C(bits[i][2] if isinstance(bits[i], tuple) else "ffffff"))
        # bits are (x, y, color)
        for x, y, col in bits:
            px(im, x + (f % 2), y, C(col))
            px(im, x, y + 1, C(col))
        if hot:
            steam(im, f)
        frames.append(im)
    return frames


def piled(chunks, hot=False):
    frames = []
    for f in range(4):
        im = blank()
        plate(im)
        for x, y, w, h, col in chunks:
            rect(im, x, y + (0 if f < 2 else 0), w, h, C(col))
            rect(im, x, y, w, 1, INK)
        if hot and f % 2 == 0:
            steam(im, f)
        frames.append(im)
    return frames


def shine(im, frame, x, y):
    if frame % 2 == 0:
        px(im, x, y, C("ffffff", 220))


# 每道菜手画，不靠同一只碗换颜色。
def draw_radish_soup(f):
    im = blank()
    bowl(im, C("e8c888"))
    for i, x in enumerate((10, 16, 21)):
        disc(im, x, 16, 3, 2, C("fbf7ec"))
        rect(im, x - 1, 13, 2, 3, C("6fbf4a" if (i + f) % 2 == 0 else "3f8a32"))
    steam(im, f)
    return im


def draw_stir_greens(f):
    im = blank()
    plate(im)
    for i, x in enumerate((8, 12, 16, 20)):
        rect(im, x, 14 + (i + f) % 2, 3, 6, C("3f8a32" if i % 2 == 0 else "6fbf4a"))
        px(im, x + 1, 14, C("d8f0a8"))
    return im


def draw_roast(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 8, 4, C("8a4030"))
    rect(im, 10, 17, 12, 4, C("e07030"))
    rect(im, 12, 17, 4, 2, C("f8cc70"))
    if f % 2 == 0:
        steam(im, f)
    return im


def draw_egg(f):
    im = blank()
    plate(im)
    disc(im, 16, 20, 9, 5, C("fbf7ec"))
    disc(im, 17, 19, 3, 3, C("f2b23e"))
    shine(im, f, 14, 17)
    return im


def draw_rice(f):
    im = blank()
    bowl(im, C("f4efe4"))
    disc(im, 16, 16, 7, 3, C("fffaf0"))
    for x, y in ((11, 15), (14, 14), (17, 15), (20, 16), (13, 17), (16, 17), (19, 15)):
        px(im, x, y, C("e8dcc0" if (x + f) % 2 == 0 else "ffffff"))
    steam(im, f)
    return im


def draw_fish_soup(f):
    im = blank()
    bowl(im, C("d8d2c4"))
    disc(im, 14, 16, 6, 3, C("6a7a6a"))
    rect(im, 18, 15, 5, 2, C("4a5848"))
    disc(im, 11, 15, 2, 2, C("d8dcc8"))
    px(im, 12, 15, INK)
    steam(im, f)
    return im


def draw_noodles(f, green=True, yolk=False):
    im = blank()
    bowl(im, C("f2dc8a"))
    for i in range(6):
        x = 9 + i * 2
        rect(im, x, 12 + (i + f) % 2, 2, 8, C("ffe9a8" if i % 2 == 0 else "e0b050"))
    if green:
        rect(im, 18, 13, 4, 3, C("3f8a32"))
    if yolk:
        disc(im, 13, 14, 3, 2, C("f2b23e"))
    steam(im, f)
    return im


def draw_tea_egg(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 5, 6, C("a8784a"))
    rect(im, 14, 16, 1, 6, C("6a4830"))
    rect(im, 12, 18, 8, 1, C("6a4830"))
    shine(im, f, 14, 16)
    return im


def draw_fried_rice(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 9, 4, C("f2dc8a"))
    for x, y, col in ((11, 17, "fbf7ec"), (14, 18, "f0a040"), (18, 17, "e07030"), (15, 16, "5fa848"), (20, 19, "f2b23e")):
        disc(im, x, y + f % 2, 2, 1, C(col))
    steam(im, f)
    return im


def draw_porridge(f, fill, chunks):
    im = blank()
    bowl(im, C(fill))
    disc(im, 16, 16, 8, 4, C(fill))
    for x, y, col in chunks:
        disc(im, x, y, 2, 2, C(col))
    steam(im, f)
    return im


def draw_cake(f, top, dots):
    im = blank()
    rect(im, 5, 22, 22, 3, INK)
    rect(im, 6, 23, 20, 2, C("8a6a4e"))
    rect(im, 7, 12, 18, 11, C("f0d8a0"))
    rect(im, 7, 12, 18, 3, C(top))
    rect(im, 7, 20, 18, 3, C("c89858"))
    for i, (x, y) in enumerate(dots):
        disc(im, x, y, 1, 1, C("f6b83a" if (i + f) % 2 == 0 else "fff6d0"))
    return im


def draw_tea(f, fill):
    im = blank()
    disc(im, 15, 24, 8, 3, C("c4b49a"))
    rect(im, 9, 10, 12, 14, INK)
    rect(im, 10, 11, 10, 12, C("f7f1e4"))
    rect(im, 11, 16, 8, 6, C(fill))
    rect(im, 21, 14, 4, 1, INK)
    rect(im, 24, 14, 1, 4, INK)
    rect(im, 21, 18, 4, 1, INK)
    steam(im, f)
    return im


def draw_shrimp(f):
    im = blank()
    plate(im)
    # 三只弯虾：粉壳、深色尾巴，不画成番茄块
    for i, (x, y) in enumerate(((6, 19), (13, 16), (19, 19))):
        shell = C("f0a888" if (i + f) % 2 == 0 else "e08060")
        rect(im, x, y, 7, 2, shell)
        rect(im, x + 5, y - 3, 2, 3, shell)
        rect(im, x, y + 1, 2, 3, C("c04838"))
        px(im, x + 6, y - 3, INK)
    return im


def draw_crab(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 7, 5, C("6a7a48"))
    disc(im, 16, 18, 5, 3, C("c8c090"))
    rect(im, 6, 16 + f % 2, 5, 3, C("c45a3a"))
    rect(im, 21, 15 + (1 - f % 2), 5, 3, C("c45a3a"))
    px(im, 14, 17, INK)
    px(im, 18, 17, INK)
    return im


def draw_corn(f):
    im = blank()
    plate(im)
    rect(im, 10, 14, 12, 8, C("f2cf4f"))
    for y in range(14, 22):
        for x in range(10, 22, 2):
            px(im, x + (y + f) % 2, y, C("e0b030"))
    rect(im, 8, 16, 2, 4, C("6aaa40"))
    return im


def draw_lotus(f):
    im = blank()
    plate(im)
    for i, x in enumerate((8, 13, 18)):
        disc(im, x + 2, 19, 3, 3, C("f4f0e6"))
        disc(im, x + 2, 19, 1, 1, C("e0cfae"))
        px(im, x + 2, 17, C("c45a3a") if (i + f) % 2 == 0 else C("e07050"))
    return im


def draw_balls(f):
    im = blank()
    bowl(im, C("f7f1e4"))
    for i, (x, y) in enumerate(((12, 16), (16, 15), (20, 17))):
        disc(im, x, y, 2, 2, C("ffffff" if (i + f) % 2 == 0 else "f2dc8a"))
    steam(im, f)
    return im


def draw_napa(f):
    im = blank()
    bowl(im, C("f4f6e0"))
    rect(im, 10, 12, 5, 8, C("f7f3ea"))
    rect(im, 15, 13, 6, 7, C("c8e090"))
    rect(im, 12, 14, 2, 5, C("8cc85c"))
    steam(im, f)
    return im


def draw_mustard(f):
    im = blank()
    plate(im)
    for i, x in enumerate((9, 13, 17, 21)):
        rect(im, x, 15 + (i + f) % 2, 2, 5, C("3f8f52"))
    return im


def draw_fish_plate(f, body):
    im = blank()
    plate(im)
    disc(im, 16, 19, 9, 3, C(body))
    disc(im, 16, 19, 6, 2, C("f7f1e4"))
    px(im, 22, 18, INK)
    rect(im, 8, 18, 3, 2, C(body))
    steam(im, f)
    return im


def draw_tomato_egg(f):
    im = blank()
    plate(im)
    for x, y, col in ((9, 16, "e5503c"), (13, 15, "f2dc8a"), (17, 16, "e5503c"), (12, 18, "fbf7ec"), (16, 18, "f2b23e"), (20, 17, "6fbf4a")):
        rect(im, x, y + f % 2, 3, 2, C(col))
    steam(im, f)
    return im


def draw_strawberry(f):
    im = blank()
    disc(im, 16, 20, 8, 4, C("f7f1e4"))
    disc(im, 16, 18, 6, 4, C("f4c2d0"))
    for x, y in ((13, 17), (16, 16), (19, 18)):
        px(im, x, y, C("e2463f"))
    shine(im, f, 14, 16)
    return im


def draw_eight(f):
    im = blank()
    disc(im, 16, 20, 10, 6, INK)
    disc(im, 16, 19, 9, 5, C("fbf3dc"))
    for i, (x, y, col) in enumerate(((12, 17, "c45a3a"), (16, 16, "f6b83a"), (20, 18, "6a8a48"), (14, 20, "f2b23e"), (18, 20, "8a4030"))):
        px(im, x, y, C(col if (i + f) % 5 else "ffffff"))
    return im


DRAW = {
    "radish_soup": draw_radish_soup,
    "stir_greens": draw_stir_greens,
    "roast_sweet_potato": draw_roast,
    "fried_egg": draw_egg,
    "rice_bowl": draw_rice,
    "fish_soup": draw_fish_soup,
    "plain_noodles": lambda f: draw_noodles(f, True, False),
    "farewell_noodles": lambda f: draw_noodles(f, True, True),
    "tea_egg": draw_tea_egg,
    "egg_fried_rice": draw_fried_rice,
    "pumpkin_porridge": lambda f: draw_porridge(f, "f0a23c", [(12, 15, "e88a2e"), (17, 16, "f8cc70")]),
    "laba_porridge": lambda f: draw_porridge(f, "c48a55", [(12, 15, "f4f0e6"), (16, 16, "8a4030"), (19, 15, "d8c27a")]),
    "milk_cake": lambda f: draw_cake(f, "f7f1e4", [(10, 16), (14, 16), (18, 16), (12, 18), (16, 18)]),
    "osmanthus_cake": lambda f: draw_cake(f, "f6b83a", [(10, 15), (14, 16), (18, 15), (12, 18), (16, 18)]),
    "eight_treasure": draw_eight,
    "herb_tea": lambda f: draw_tea(f, "cfe6c8"),
    "fog_tonic": lambda f: draw_tea(f, "d5e6f2"),
    "qingming_tea": lambda f: draw_tea(f, "7fb87a"),
    "oil_shrimp": draw_shrimp,
    "steamed_crab": draw_crab,
    "corn_cob": draw_corn,
    "lotus_slices": draw_lotus,
    "winter_balls": draw_balls,
    "napa_pot": draw_napa,
    "mustard_fry": draw_mustard,
    "perch_steam": lambda f: draw_fish_plate(f, "8a9aa8"),
    "mandarin_steam": lambda f: draw_fish_plate(f, "c4a060"),
    "peach_soup": lambda f: draw_fish_soup_pink(f),
    "silver_soup": lambda f: draw_silver(f),
    "tomato_egg": draw_tomato_egg,
    "strawberry_bowl": draw_strawberry,
    "pea_egg": lambda f: draw_pea_egg(f),
    "lixia_egg": lambda f: draw_salt_egg(f),
    "cold_noodles": lambda f: draw_cold_noodles(f),
}


def draw_soy_greens(f):
    im = blank()
    plate(im)
    for i, x in enumerate((10, 14, 18)):
        rect(im, x, 16 + (i + f) % 2, 3, 6, C("3f8a32"))
    disc(im, 16, 20, 6, 2, C("5a3018"))
    return im


def draw_vinegar_napa(f):
    im = blank()
    plate(im)
    rect(im, 10, 16, 5, 6, C("f4f6e0"))
    rect(im, 16, 15, 5, 7, C("d8e8a8"))
    disc(im, 15, 20, 5, 2, C("e8d080"))
    shine(im, f, 18, 16)
    return im


def draw_wine_perch(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 10, 4, C("8a9aa8"))
    rect(im, 24, 18, 4, 2, C("5a6874"))
    px(im, 12, 18, INK)
    disc(im, 16, 21, 6, 2, C("f2e2c4"))
    steam(im, f)
    return im


def draw_sugar_roast(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 7, 4, C("c06030"))
    rect(im, 12, 17, 8, 3, C("e88840"))
    # 糖丝
    rect(im, 18, 12 + f % 2, 1, 6, C("f8e0a0"))
    rect(im, 14, 13, 1, 5, C("fff6d0"))
    return im


DRAW["soy_greens"] = draw_soy_greens
DRAW["vinegar_napa"] = draw_vinegar_napa
DRAW["wine_perch"] = draw_wine_perch
DRAW["sugar_roast"] = draw_sugar_roast


def draw_fish_soup_pink(f):
    im = blank()
    bowl(im, C("fde4ea"))
    rect(im, 12, 16, 7, 2, C("e8a0b0"))
    px(im, 18, 16, C("c85878"))
    steam(im, f)
    return im


def draw_silver(f):
    im = blank()
    bowl(im, C("d5e0ea"))
    rect(im, 10, 15, 12, 2, C("f7fbff"))
    rect(im, 20, 15, 3, 1, C("c8d4e0"))
    px(im, 12, 15, INK)
    shine(im, f, 16, 15)
    steam(im, f)
    return im


def draw_pea_egg(f):
    im = blank()
    plate(im)
    disc(im, 13, 18, 3, 3, C("f2b23e"))
    for x, y in ((17, 16), (19, 18), (16, 19), (20, 16)):
        px(im, x, y + f % 2, C("8ad060"))
    return im


def draw_salt_egg(f):
    im = blank()
    plate(im)
    disc(im, 16, 19, 5, 6, C("f4efe6"))
    disc(im, 16, 20, 2, 3, C("e07030"))
    rect(im, 11, 16, 10, 1, C("c4b49a"))
    shine(im, f, 14, 16)
    return im


def draw_cold_noodles(f):
    im = blank()
    plate(im)
    for i in range(6):
        rect(im, 8 + i * 2, 16 + (i + f) % 2, 1, 6, C("f2dc8a"))
    rect(im, 18, 17, 4, 2, C("5fa848"))
    return im


def save_sheet(name, frames):
    sheet = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
    for i, fr in enumerate(frames):
        sheet.paste(fr, (i * CELL, 0), fr)
    path = os.path.join(OUT, name + ".png")
    sheet.save(path)


def main():
    os.makedirs(OUT, exist_ok=True)
    ids = list(DRAW)
    for name, fn in DRAW.items():
        save_sheet(name, [fn(f) for f in range(4)])
    cols = 8
    rows = (len(ids) + cols - 1) // cols
    preview = Image.new("RGBA", (cols * CELL * 2, rows * CELL * 2), (40, 36, 32, 255))
    for i, name in enumerate(ids):
        fr = DRAW[name](0).resize((CELL * 2, CELL * 2), Image.NEAREST)
        preview.paste(fr, ((i % cols) * CELL * 2, (i // cols) * CELL * 2), fr)
    prev = os.path.join(PROJ, "_preview", "dishes.png")
    os.makedirs(os.path.dirname(prev), exist_ok=True)
    preview.save(prev)
    print("saved", len(ids), "dishes", prev)


if __name__ == "__main__":
    main()
