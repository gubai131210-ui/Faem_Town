"""八种做法各四帧：切、炒、蒸、炖、炸、煮、拌、烤。人用主角已有的做菜动作，这里只画锅。

用法：D:\\Miniconda3\\python.exe tools\\method_art.py
输出：art/food/method_<id>.png（192×48），以及 _preview/methods.png
"""
import io
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
OUT = os.path.join(PROJ, "art", "food")
CELL = 48


def C(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


INK = C("2a2420")


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


def wok(im):
    disc(im, 24, 32, 16, 8, INK)
    disc(im, 24, 31, 14, 6, C("4a4e56"))
    rect(im, 8, 30, 4, 2, C("8a8e96"))


def fire(im, frame):
    for i, x in enumerate((18, 24, 30)):
        h = 4 + (frame + i) % 3
        rect(im, x, 36 - h, 2, h, C("f0a040" if i % 2 == 0 else "e05030"))


def steam(im, frame, y0=8):
    for i, x in enumerate((16, 24, 32)):
        y = y0 - (frame + i) % 4
        px(im, x, y, C("ffffff", 200))
        px(im, x, y + 1, C("ffffff", 90))


def cut(f):
    im = blank()
    rect(im, 8, 28, 32, 8, C("c4a574"))
    rect(im, 8, 28, 32, 2, C("e8d2a8"))
    rect(im, 14, 30, 6, 4, C("6fbf4a"))
    rect(im, 22, 31, 5, 3, C("3f8a32"))
    # 刀，每帧往下切一格
    rect(im, 18, 10 + f * 3, 3, 16, C("d8dce4"))
    rect(im, 16, 8 + f * 3, 7, 4, C("8a5a34"))
    return im


def stir(f):
    im = blank()
    fire(im, f)
    wok(im)
    disc(im, 22 + f % 2, 28, 6, 3, C("e07030"))
    disc(im, 28 - f % 2, 27, 3, 2, C("6fbf4a"))
    rect(im, 30, 12, 2, 16, C("8a5a34"))
    return im


def steam_pot(f):
    im = blank()
    rect(im, 12, 26, 24, 10, C("c4a06a"))
    rect(im, 14, 20, 20, 8, C("d8b888"))
    rect(im, 16, 16, 16, 6, C("e8c898"))
    rect(im, 20, 18, 8, 1, C("f2e2c4"))
    steam(im, f, 12)
    return im


def stew(f):
    im = blank()
    fire(im, f)
    disc(im, 24, 28, 12, 10, C("8a4030"))
    disc(im, 24, 26, 8, 5, C("c45a3a"))
    disc(im, 22 + (f % 2), 25, 2, 1, C("f2b23e"))
    rect(im, 20, 16, 8, 3, C("5a4030"))
    steam(im, f, 10)
    return im


def fry(f):
    im = blank()
    fire(im, f)
    wok(im)
    disc(im, 24, 28, 8, 3, C("e8c84a"))
    # 油花溅起来
    for i, (x, y) in enumerate(((14, 22), (24, 18), (32, 22), (20, 16))):
        px(im, x, y - (f + i) % 3, C("fff6d0"))
    return im


def boil(f):
    im = blank()
    fire(im, f)
    disc(im, 24, 30, 13, 8, INK)
    disc(im, 24, 28, 11, 6, C("6a90b8"))
    disc(im, 24, 26, 8, 4, C("d8e8f4"))
    disc(im, 20 + f % 3, 25, 2, 1, C("ffffff"))
    steam(im, f, 12)
    return im


def mix(f):
    im = blank()
    disc(im, 24, 30, 14, 8, INK)
    disc(im, 24, 28, 12, 6, C("f7f1e4"))
    disc(im, 24, 26, 8, 4, C("e8d8a0"))
    rect(im, 16 + f * 3, 14, 2, 14, C("c4a574"))
    rect(im, 28 - f, 16, 2, 12, C("8a5a34"))
    return im


def roast(f):
    im = blank()
    rect(im, 10, 34, 28, 4, C("5a4030"))
    fire(im, f)
    disc(im, 24, 24, 8, 5, C("8a4030"))
    rect(im, 18, 22, 8, 4, C("e07030"))
    if f % 2 == 0:
        px(im, 22, 20, C("f8cc70"))
    return im


DRAWS = {
    "cut": cut,
    "stir": stir,
    "steam": steam_pot,
    "stew": stew,
    "fry": fry,
    "boil": boil,
    "mix": mix,
    "roast": roast,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    preview = Image.new("RGBA", (8 * CELL * 2, CELL * 2), (30, 28, 26, 255))
    for i, (name, fn) in enumerate(DRAWS.items()):
        sheet = Image.new("RGBA", (CELL * 4, CELL), (0, 0, 0, 0))
        for f in range(4):
            fr = fn(f)
            sheet.paste(fr, (f * CELL, 0), fr)
        path = os.path.join(OUT, "method_%s.png" % name)
        buf = io.BytesIO()
        sheet.save(buf, format="PNG")
        tmp = path + ".tmp"
        with open(tmp, "wb") as f:
            f.write(buf.getvalue())
        os.replace(tmp, path)
        big = sheet.resize((CELL * 2, CELL * 2), Image.NEAREST)
        preview.paste(big, (i * CELL * 2, 0), big)
    prev = os.path.join(PROJ, "_preview", "methods.png")
    os.makedirs(os.path.dirname(prev), exist_ok=True)
    preview.save(prev)
    print("saved", len(DRAWS), "methods")


if __name__ == "__main__":
    main()
