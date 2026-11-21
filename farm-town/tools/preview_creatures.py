"""把几只动物的序列帧拼在草地色上放大，旁边放主角和鸡做大小参照。

用法:  python tools/preview_creatures.py [-o 文件名] 名字 [名字 ...]
       名字是 art/creatures/ 下的；写成 人:名字 就从 art/characters/ 里取（居民）
输出:  _preview/<文件名>.png，默认 creatures.png；另外每只单独一张 _preview/<文件名>_<名字>.png
每只一行：每个动作取朝右、朝下各若干帧。
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
ZOOM = 4
GRASS = (104, 150, 78, 255)
SNOW = (226, 234, 244, 255)
WATER = (74, 140, 204, 255)
BACKS = {"sparrow": SNOW, "dragonfly": WATER}


def load(name):
    folder = "creatures"
    if name.startswith("人:"):
        folder, name = "characters", name[2:]
    base = os.path.join(PROJ, "art", folder, name)
    img = Image.open(base + ".png").convert("RGBA")
    with open(base + ".json", encoding="utf-8") as f:
        desc = json.load(f)
    return name, img, desc


def strip(name, img, desc, max_frames):
    cell = desc["cell"]
    tiles = []
    for anim, info in desc["anims"].items():
        n = min(int(info["frames"]), max_frames)
        for facing in (2, 0):
            row = int(info["row"]) + facing
            for k in range(n):
                tiles.append(img.crop((k * cell, row * cell, (k + 1) * cell, (row + 1) * cell)))
    return cell, tiles


def main():
    args = sys.argv[1:]
    out_name = "creatures"
    if args and args[0] == "-o":
        out_name = args[1]
        args = args[2:]
    refs = [load("人:farmer"), load("chicken")]
    rows = []
    for raw in args:
        name, img, desc = load(raw)
        cell, tiles = strip(name, img, desc, 4)
        rows.append((name, cell, tiles))
    ref_tiles = []
    for name, img, desc in refs:
        cell = desc["cell"]
        row = int(desc["anims"]["idle"]["row"]) + 2
        ref_tiles.append((cell, img.crop((0, row * cell, cell, (row + 1) * cell))))
    width = max(sum(cell + 2 for _ in tiles) for _, cell, tiles in rows) + 48 + 32 + 12
    height = sum(max(cell, 48) + 4 for _, cell, _ in rows)
    sheet = Image.new("RGBA", (width, height), GRASS)
    y = 0
    for name, cell, tiles in rows:
        band = max(cell, 48) + 4
        back = BACKS.get(name, GRASS)
        sheet.paste(Image.new("RGBA", (width, band), back), (0, y))
        x = 2
        for rc, tile in ref_tiles:
            sheet.alpha_composite(tile, (x, y + band - rc - 2))
            x += rc + 2
        x += 6
        for tile in tiles:
            sheet.alpha_composite(tile, (x, y + band - cell - 2))
            x += cell + 2
        y += band
    out_dir = os.path.join(PROJ, "_preview")
    os.makedirs(out_dir, exist_ok=True)
    _save(sheet, os.path.join(out_dir, out_name + ".png"))
    # 每只再单独存一张，一行排不下太多帧时看这个
    y = 0
    for name, cell, tiles in rows:
        band = max(cell, 48) + 4
        used = 48 + 32 + 12 + len(tiles) * (cell + 2)
        _save(sheet.crop((0, y, min(width, used), y + band)), os.path.join(out_dir, "%s_%s.png" % (out_name, name)))
        y += band


def _save(img, out):
    img = img.resize((img.width * ZOOM, img.height * ZOOM), Image.NEAREST)
    tmp = out + ".tmp.png"
    img.save(tmp)
    os.replace(tmp, out)
    print("saved", out, img.size)


main()
