"""画居民的对话头像：正面半身像，直接按像素画，不经过 Blender。

用法:  python tools/portraits.py [名字 ...]      不写名字就画 tools/characters/ 下所有带 "face" 的配置
输出:  art/characters/<名字>_face.png   192x64，从左到右三格：平常、高兴、不高兴
造型（发型、帽子、衣服、颜色）读 tools/characters/<名字>.json，和小人的序列帧是同一份；
头像自己的设定写在配置的 "face" 里：
  age     "child" 孩子；"young" 年轻人；"adult" 中年；"old" 老人
  eyes    "big" 大眼睛；"calm" 普通；"narrow" 细长
  brow    "thin" 细眉；"thick" 粗眉
  fringe  "short" 露额头；"bangs" 齐刘海；"part" 偏分
  blush   true 脸颊带红晕
  mouth   平常的嘴："smile" 带笑；"neutral" 平；"flat" 抿着
  jaw     "soft" 圆脸；"square" 方脸
  crop    true 头发剪得短，两鬓露出来
  moustache  true 上唇留一撇胡子
"""
import json
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
OUT_DIR = os.path.join(PROJ, "art", "characters")
N = 64
MOODS = ["neutral", "happy", "sad"]

with open(os.path.join(PROJ, "data", "palette.json"), encoding="utf-8") as _f:
    LETTERS = json.load(_f)

YY, XX = np.mgrid[0:N, 0:N]
PX = XX + 0.5
PY = YY + 0.5


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def ell(cx, cy, rx, ry):
    return ((PX - cx) / rx) ** 2 + ((PY - cy) / ry) ** 2 <= 1.0


def rect(x0, y0, x1, y1):
    """含 x0、y0，不含 x1、y1。"""
    return (XX >= x0) & (XX < x1) & (YY >= y0) & (YY < y1)


def shift(mask, dx, dy):
    out = np.zeros_like(mask)
    h, w = mask.shape
    ys0, ys1 = max(0, dy), min(h, h + dy)
    xs0, xs1 = max(0, dx), min(w, w + dx)
    out[ys0:ys1, xs0:xs1] = mask[ys0 - dy:ys1 - dy, xs0 - dx:xs1 - dx]
    return out


class Canvas:
    def __init__(self):
        self.a = np.zeros((N, N, 4), dtype=np.uint8)

    def paint(self, mask, col):
        self.a[mask, :3] = col
        self.a[mask, 3] = 255

    def px(self, x, y, col):
        if 0 <= x < N and 0 <= y < N:
            self.a[y, x, :3] = col
            self.a[y, x, 3] = 255

    def row(self, x0, x1, y, col):
        for x in range(x0, x1 + 1):
            self.px(x, y, col)

    def shaded(self, mask, light, dark, dx=-3, dy=-1):
        """涂一块带暗面的颜色：暗面在右下。"""
        self.paint(mask, light)
        self.paint(mask & ~shift(mask, dx, dy), dark)

    def outline(self):
        a = self.a
        out = a.copy()
        for y in range(N):
            for x in range(N):
                if a[y, x, 3] > 0:
                    continue
                for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < N and 0 <= ny < N and a[ny, nx, 3] > 0:
                        r, g, b = a[ny, nx, :3] / 255.0
                        out[y, x, :3] = [int(c * 255 + 0.5) for c in (r * 0.36 + 0.03, g * 0.30 + 0.01, b * 0.38 + 0.06)]
                        out[y, x, 3] = 255
                        break
        self.a = out


def colors(cfg):
    base = {
        "skin": ("s", "S"), "hair": ("h", "H"), "shirt": ("b", "B"), "blue": ("p", "P"),
        "hat": ("y", "Y"), "band": ("r", "R"), "apron": ("b", "B"),
    }
    pal = {k: (rgb(LETTERS[a]), rgb(LETTERS[b])) for k, (a, b) in base.items()}
    for part, keys in cfg.get("parts", {}).items():
        if isinstance(keys, str):
            pal[part] = tuple(rgb(c) for c in LETTERS["cloth"][keys])
        else:
            pal[part] = (rgb(LETTERS[keys[0]]), rgb(LETTERS[keys[1]]))
    return pal


def draw(cfg, mood):
    face = cfg.get("face", {})
    age = face.get("age", "adult")
    eyes = face.get("eyes", "calm")
    brow = face.get("brow", "thin")
    fringe = face.get("fringe", "short")
    jaw = face.get("jaw", "soft")
    mouth = face.get("mouth", "neutral")
    blush = bool(face.get("blush", False))
    hair_style = cfg.get("hair", "short")
    hat = cfg.get("hat", True)
    if hat is True:
        hat = "straw"
    outfit = cfg.get("outfit", "overalls")
    bulk = float(cfg.get("bulk", 1.0))
    beard = bool(cfg.get("beard", False))
    pal = colors(cfg)
    skin, skin_d = pal["skin"]
    skin_dd = mix(skin_d, (120, 60, 50), 0.35)
    hair, hair_d = pal["hair"]
    hair_hi = mix(hair, (255, 255, 255), 0.28)
    ink = rgb(LETTERS["e"])
    white = rgb(LETTERS["x"])
    lip = mix(rgb(LETTERS["R"]), skin_d, 0.25)
    pink = mix(rgb(LETTERS["c"]), skin, 0.25)
    brow_col = hair_d if sum(hair_d) < 420 else mix(hair_d, ink, 0.35)

    c = Canvas()
    child = age == "child"
    # 孩子的头大一点、位置低一点，肩膀窄
    cy = 31 if child else 29
    hw = 15.0 if child else 14.0          # 半个脸宽
    chin = cy + (16 if child else 18)     # 下巴尖所在的行
    sh_w = (19 if child else 25) * (0.9 + 0.1 * bulk) * bulk ** 0.5
    sh_top = chin + 5

    # ---- 披在背后的头发
    if hair_style == "long":
        c.shaded(ell(32, cy + 8, hw + 5.5, 22) & (YY < sh_top + 9), hair, hair_d)
    elif hair_style == "ponytail":
        c.shaded(ell(32 + hw + 3, cy + 12, 4.5, 10), hair, hair_d, -2, -1)
    elif hair_style == "pigtails":
        for sx in (-1, 1):
            c.shaded(ell(32 + sx * (hw + 4.5), cy + 9, 5.0, 9.5), hair, hair_d, -2, -1)

    # ---- 肩膀和衣服
    body = ell(32, sh_top + 19, sh_w, 19) & (YY >= sh_top)
    shirt, shirt_d = pal["shirt"]
    c.shaded(body, shirt, shirt_d, -4, -2)
    if outfit == "overalls":
        blue, blue_d = pal["blue"]
        for sx in (-1, 1):
            c.shaded(rect(32 + sx * 10 - 2, sh_top, 32 + sx * 10 + 2, N) & body, blue, blue_d, -1, 0)
        c.shaded(rect(22, sh_top + 7, 43, N), blue, blue_d, -3, 0)
    elif outfit == "apron":
        ap, ap_d = pal["apron"]
        for sx in (-1, 1):
            c.paint(rect(32 + sx * 9 - 1, sh_top, 32 + sx * 9 + 1, sh_top + 7) & body, ap_d)
        c.shaded(rect(22, sh_top + 6, 43, N), ap, ap_d, -3, 0)
    elif outfit == "robe":
        band, band_d = pal["band"]
        # 交领：两条斜的衣襟
        for i in range(0, 13):
            y = sh_top - 1 + i
            c.row(26 + i * 6 // 10, 27 + i * 6 // 10, y, band)
            c.row(37 - i * 9 // 10, 38 - i * 9 // 10, y, band_d if i > 6 else band)
    else:
        c.paint(ell(32, sh_top - 1, 7.5, 4.5) & body, shirt_d)

    # ---- 脖子
    c.paint(rect(28, chin - 4, 37, sh_top + 2), skin_d)
    c.paint(rect(28, chin - 1, 37, chin + 2), skin_dd)
    if outfit == "robe":
        c.paint(ell(32.5, sh_top + 1, 5.0, 3.5) & (YY >= sh_top - 1), skin_d)

    # ---- 脸
    if jaw == "square":
        head = ell(32, cy, hw, 15) | (ell(32, cy + 6, hw - 1.0, 12.3) & (YY < chin))
    else:
        head = ell(32, cy, hw, 15) | ell(32, cy + 6.5, hw - 2.5, chin - cy - 6.5)
    ears_visible = hair_style not in ("long",)
    if ears_visible:
        for sx in (-1, 1):
            ear = ell(32 + sx * (hw + 0.8), cy + 4, 2.6, 3.6)
            c.paint(ear, skin if sx < 0 else skin_d)
            c.px(int(32 + sx * (hw + 0.8) - (0 if sx > 0 else 1)), cy + 4, skin_dd)
    c.shaded(head, skin, skin_d, -3, -1)

    # ---- 头发（前面）
    crop = bool(face.get("crop", False))
    cap = ell(32, cy - 2, hw + (1.2 if crop else 2.2), 15.6 if crop else 16.5)
    if hair_style != "bald":
        if fringe == "bangs":
            window = ell(32, cy + 8, hw - 0.6, 17) & (YY >= cy - 4)
        elif fringe == "part":
            window = ell(34.5, cy + 9, hw - 0.2, 19.5)
        else:
            window = ell(32, cy + 9, hw - 0.8, 19.0)
        side = cy + (9 if hair_style in ("long", "pigtails") or fringe == "bangs" else 4)
        if crop:
            side = cy - 1
        front = cap & ~window & (YY < side)
        if hair_style == "bun":
            c.shaded(ell(32, cy - 20, 6.5, 5.5), hair, hair_d, -2, -1)
        c.shaded(front | (cap & ~head & (YY < cy + 2)), hair, hair_d, -3, -1)
        # 发丝的高光：头顶一道弧
        arc = ell(31, cy - 1, 11.5, 13.2) & ~ell(31, cy - 0.2, 11.5, 13.2) & (XX >= 22) & (XX <= 36)
        c.paint(arc & front, hair_hi)
        if fringe == "bangs":
            for x in (25, 31, 37):
                c.px(x, cy - 4, hair_d)
                c.px(x, cy - 5, hair_d)
        # 刘海在额头上的影子
        under = shift(front, 0, 1) & head & ~front
        c.paint(under, skin_d)
        if hair_style == "pigtails":
            band = pal["band"][0]
            for sx in (-1, 1):
                c.paint(rect(32 + sx * (hw + 3) - 1, cy + 1, 32 + sx * (hw + 3) + 2, cy + 4), band)
    elif age == "old":
        # 光头的老人：耳朵上面留两撮
        for sx in (-1, 1):
            c.paint(ell(32 + sx * (hw - 0.2), cy - 1, 2.2, 4.0) & ~ell(32, cy + 2, hw - 2.0, 16), hair)

    # ---- 胡子
    mouth_y = chin - 6
    if beard:
        jawline = head & (YY >= mouth_y - 3) & ~ell(32, mouth_y - 9, hw - 4.5, 9.5)
        c.shaded(jawline | (ell(32, chin - 1, 6.5, 4.0)), hair, hair_d, -2, -1)
        c.paint(rect(27, mouth_y - 3, 38, mouth_y - 1), hair)
        c.paint(rect(29, mouth_y - 1, 36, mouth_y + 2), skin_d)

    # ---- 五官
    eye_y = cy + 4
    gap = 6 if child else 6
    lx, rx = 32 - gap - 1, 32 + gap
    for ex, sx in ((lx, -1), (rx, 1)):
        if mood == "happy" and eyes != "big":
            # 笑得眯起来
            for dx, dy in ((-2, 0), (-1, -1), (0, -1), (1, -1), (2, 0)):
                c.px(ex + dx, eye_y + dy, ink)
        elif eyes == "narrow":
            c.row(ex - 2, ex + 2, eye_y - 1, ink)
            c.row(ex - 1, ex + 1, eye_y, ink)
            c.px(ex + 2 * sx, eye_y, ink)
            c.px(ex - 1, eye_y, mix(ink, white, 0.45))
        else:
            tall = 4 if eyes == "big" else 3
            top = eye_y - 2
            c.row(ex - 2, ex + 2, top, ink)
            c.px(ex + 3 * sx, top + 1, ink)
            for k in range(1, tall + 1):
                c.px(ex - 2, top + k, white)
                c.px(ex + 2, top + k, white)
                c.row(ex - 1, ex + 1, top + k, ink)
            c.px(ex - 1, top + 1, white)
            if eyes == "big":
                c.row(ex - 1, ex + 1, top + tall, mix(ink, pal["hair"][0], 0.45))
                c.px(ex + 1, top + tall - 1, mix(ink, pal["hair"][0], 0.45))
            if mood == "sad":
                c.row(ex - 2, ex + 2, top, skin_d)
                c.row(ex - 2, ex + 2, top + 1, ink)
        # 眉毛
        by = eye_y - (6 if eyes == "big" else 5)
        thick = brow == "thick"
        for k in range(-2, 3):
            # k 是从内到外：内侧 -2，外侧 +2
            x = ex + k * sx
            dy = 0
            if mood == "sad":
                dy = -1 if k <= -1 else (1 if k == 2 else 0)
            elif mood == "happy":
                dy = -1 if abs(k) <= 1 else 0
            else:
                dy = 1 if k == 2 else 0
            c.px(x, by + dy, brow_col)
            if thick:
                c.px(x, by + dy + 1, brow_col)
        if age == "old":
            c.px(ex + 4 * sx, eye_y + 1, skin_d)
            c.row(ex - 1, ex + 1, eye_y + 2, skin_d)

    # 鼻子
    c.px(33, eye_y + 4, skin_d)
    c.px(33, eye_y + 5, skin_d)
    c.px(32, eye_y + 6, skin_d)
    c.px(31, eye_y + 6, skin_d)
    if age in ("old", "adult") and not beard:
        c.px(27, mouth_y - 2, skin_d)
        c.px(37, mouth_y - 2, skin_dd if age == "old" else skin_d)
    if age == "old" and hair_style == "bald":
        c.row(28, 35, cy - 9, skin_d)

    if face.get("moustache", False):
        c.row(28, 36, mouth_y - 2, hair)
        c.px(27, mouth_y - 1, hair_d)
        c.px(37, mouth_y - 1, hair_d)
        c.row(28, 29, mouth_y - 1, hair)
        c.row(35, 36, mouth_y - 1, hair)

    # 嘴
    if mood == "happy":
        c.row(29, 35, mouth_y, lip)
        c.row(30, 34, mouth_y + 1, lip)
        c.row(31, 33, mouth_y + 1, white)
        c.px(28, mouth_y - 1, lip)
        c.px(36, mouth_y - 1, lip)
    elif mood == "sad":
        c.row(30, 34, mouth_y, lip)
        c.px(29, mouth_y + 1, lip)
        c.px(35, mouth_y + 1, lip)
    elif mouth == "smile":
        c.row(30, 34, mouth_y, lip)
        c.px(29, mouth_y - 1, lip)
        c.px(35, mouth_y - 1, lip)
    elif mouth == "flat":
        c.row(30, 34, mouth_y, lip)
    else:
        c.row(30, 34, mouth_y, lip)
        c.px(35, mouth_y - 1, skin_d)
    c.row(31, 33, mouth_y + 2, skin_d)

    if blush or mood == "happy":
        for sx in (-1, 1):
            bx = 32 + sx * (hw - 5)
            c.row(int(bx) - 1, int(bx) + 1, eye_y + 5, pink)
            if child or blush:
                c.row(int(bx) - 1, int(bx), eye_y + 6, pink)

    # ---- 帽子
    hat_c, hat_d = pal["hat"]
    band_c, band_d2 = pal["band"]
    top = cy - 15
    if hat == "straw":
        crown = (ell(32, top + 4, 13.5, 11) & (YY < top + 6)) | rect(19, top - 2, 46, top + 6)
        crown &= ell(32, top + 4, 14.5, 12.5)
        c.shaded(crown, hat_c, hat_d, -3, -1)
        c.shaded(rect(19, top + 2, 46, top + 6) & crown, band_c, band_d2, -3, 0)
        brim = ell(32, top + 7, 29, 5.5)
        c.shaded(brim, hat_c, hat_d, -2, -2)
        c.paint(shift(brim, 0, 2) & head & ~brim, skin_d)
        c.paint(shift(brim, 0, 1) & ~brim & ~head & (c.a[..., 3] > 0), hair_d)
    elif hat == "cone":
        apex = top - 9
        cone = (np.abs(PX - 32) <= (PY - apex) * 2.0) & (YY >= apex) & (PY <= top + 9)
        cone |= ell(32, top + 8, 28.5, 4.5) & (YY >= top + 6)
        c.shaded(cone, hat_c, hat_d, -5, 0)
        for k in range(1, 5):
            c.px(32 - k * 5, apex + k * 4, hat_d)
        c.paint(shift(cone, 0, 2) & head & ~cone, skin_d)
    elif hat == "beret":
        beret = ell(30, top + 1, 18, 8.5)
        c.shaded(beret, hat_c, hat_d, -3, -2)
        c.paint(rect(34, top - 9, 36, top - 6), hat_d)
        c.paint(shift(beret, 0, 1) & ~beret & (c.a[..., 3] > 0) & ~head, hair_d)
    elif hat == "headband":
        hb = rect(0, cy - 10, N, cy - 6) & (cap | head)
        c.shaded(hb, band_c, band_d2, -3, 0)
        knot = rect(int(32 + hw + 1), cy - 9, int(32 + hw + 4), cy - 3)
        c.paint(knot, band_d2)

    c.outline()
    return c.a


def render(name):
    with open(os.path.join(HERE, "characters", name + ".json"), encoding="utf-8") as f:
        cfg = json.load(f)
    if "face" not in cfg:
        return False
    strip = np.zeros((N, N * len(MOODS), 4), dtype=np.uint8)
    for i, mood in enumerate(MOODS):
        strip[:, i * N:(i + 1) * N] = draw(cfg, mood)
    path = os.path.join(OUT_DIR, cfg.get("name", name) + "_face.png")
    tmp = path + ".tmp.png"
    Image.fromarray(strip, "RGBA").save(tmp)
    os.replace(tmp, path)
    print("saved", path)
    return True


def main():
    names = sys.argv[1:]
    if not names:
        names = sorted(f[:-5] for f in os.listdir(os.path.join(HERE, "characters")) if f.endswith(".json"))
    for n in names:
        render(n)


if __name__ == "__main__":
    main()
