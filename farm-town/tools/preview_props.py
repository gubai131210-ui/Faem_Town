"""把 art/props 里的图拼成一张预览（放大 3 倍），方便检查。用法: python tools/preview_props.py 输出名 物件名..."""
import json, os, sys
from PIL import Image
here = os.path.dirname(os.path.abspath(__file__)); proj = os.path.dirname(here)
out, names = sys.argv[1], sys.argv[2:]
char = Image.open(os.path.join(proj, "art/characters/farmer.png")).crop((0, 0, 48, 48))
ims = []
for n in names:
    ims.append(char if n == "@" else Image.open(os.path.join(proj, "art/props", n + ".png")).convert("RGBA"))
pad = 6
w = sum(i.width for i in ims) + pad * (len(ims) + 1); h = max(i.height for i in ims) + pad * 2
bg = (150, 120, 84, 255) if "--indoor" in os.environ.get("PV", "") else (128, 189, 78, 255)
sheet = Image.new("RGBA", (w, h), bg); x = pad
for i in ims:
    sheet.alpha_composite(i, (x, h - pad - i.height)); x += i.width + pad
k = 3 if w * 3 <= 1500 else 2
sheet = sheet.resize((w * k, h * k), Image.NEAREST)
os.makedirs(os.path.join(proj, "_preview"), exist_ok=True)
sheet.save(os.path.join(proj, "_preview", out + ".png")); print(sheet.size)