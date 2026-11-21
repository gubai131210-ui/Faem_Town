"""把现有茶馆素材和 showcase_teahouse.py 出的两张图拼成一张对比图。

用系统 Python 跑（Blender 内置的 Python 没有 PIL）：
  D:\\Miniconda3\\python.exe tools\\showcase_compare.py
输出: _preview/showcase_compare.png、_preview/showcase_day_zoom.png
"""
import os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
PREVIEW = os.path.join(PROJ, "_preview")
FONT_CANDIDATES = (
    "C:/Windows/Fonts/msyh.ttc",
    "C:/Windows/Fonts/simhei.ttf",
    "/System/Library/Fonts/PingFang.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
)

SCALE = 3
BG = (244, 242, 236)
CARD = (255, 255, 255)
LINE = (214, 210, 200)
INK = (42, 41, 37)
MUTED = (108, 106, 100)


def font(size):
    # 默认位图字体只含 ASCII，中文标签会变成方块，所以宁可明确报错
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    raise RuntimeError("找不到中文字体；请安装微软雅黑或 Noto Sans CJK 后重跑")


def load(path):
    im = Image.open(path).convert("RGBA")
    return im.resize((im.width * SCALE, im.height * SCALE), Image.Resampling.NEAREST)


def main():
    panels = [
        ("现有 teahouse.png", os.path.join(PROJ, "art", "props", "teahouse.png")),
        ("重制 · 白天", os.path.join(PREVIEW, "showcase_day.png")),
        ("重制 · 雪夜（同一模型）", os.path.join(PREVIEW, "showcase_snow.png")),
    ]
    imgs = [(label, load(path)) for label, path in panels]
    cell_w = max(im.width for _, im in imgs) + 36
    cell_h = max(im.height for _, im in imgs) + 36
    pad = 28
    head = 88
    foot = 104
    W = pad * 2 + cell_w * 3 + 16 * 2
    H = head + cell_h + foot
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)
    d.text((pad, 22), "茶馆素材对比 · 同一规格 1 格 = 16 px，放大 3 倍", font=font(24), fill=INK)
    d.text((pad, 58), "管线相同（Blender 斜投影 → 三色阶 → 调色板量化 → 像素纹理 → 描边），差别只在建模",
           font=font(14), fill=MUTED)

    for i, (label, im) in enumerate(imgs):
        x0 = pad + i * (cell_w + 16)
        y0 = head
        d.rounded_rectangle((x0, y0, x0 + cell_w, y0 + cell_h), radius=8, fill=CARD, outline=LINE, width=1)
        d.text((x0 + 18, y0 + 12), label, font=font(17), fill=INK)
        px = x0 + (cell_w - im.width) // 2
        py = y0 + 46 + (cell_h - 46 - im.height) // 2
        layer = Image.new("RGBA", (im.width, im.height), (0, 0, 0, 0))
        layer.alpha_composite(im)
        canvas.paste(layer.convert("RGB"), (px, py), layer.getchannel("A"))

    y = head + cell_h + 18
    notes = [
        "轮廓：起翘屋脊 + 三级马头墙，不再与其他铺子共用同一道屋檐",
        "材质：逐片错缝的瓦、墙裙与潮痕、檐下椽子与挂落、窗下裙板",
        "时间与生活：雪后屋面积雪 / 冰棱 / 窗内暖光，茶炉、柴堆、竹匾、腊梅、碗筷",
    ]
    for i, line in enumerate(notes):
        d.text((pad, y + i * 26), "· " + line, font=font(14), fill=INK)

    out = os.path.join(PREVIEW, "showcase_compare.png")
    canvas.save(out)
    print("saved", out, canvas.size)

    zoom = os.path.join(PREVIEW, "showcase_day_zoom.png")
    imgs[1][1].save(zoom)
    print("saved", zoom, imgs[1][1].size)


main()
