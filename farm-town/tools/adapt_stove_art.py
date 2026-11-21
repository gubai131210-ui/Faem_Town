"""把 Blender 试玩贴图转成正式灶间的原尺寸像素素材。"""

import os
import sys
from pathlib import Path

from PIL import Image


GAME = Path(__file__).resolve().parent.parent
SOURCE = Path(sys.argv[1]) if len(sys.argv) > 1 else GAME.parent / "prototypes/kitchen-demo/art"
OUTPUT = GAME / "art/cooking/stove"
OUTPUT.mkdir(exist_ok=True)

# 景物压成有限色阶。透明器具先缩到游戏里的绘制尺寸，保留清楚的像素边。
SIZES = {"kitchen": (224, 160), "tomato": (34, 34), "wedge": (22, 22), "curd": (20, 20),
         "knife": (34, 34), "spatula": (48, 48), "bowl": (34, 34), "plate": (92, 92)}
for name, size in SIZES.items():
    with Image.open(SOURCE / f"{name}.png") as original:
        pix = original.convert("RGBA").resize(size, Image.Resampling.LANCZOS)
    if name == "kitchen":
        pix = pix.convert("RGB").quantize(colors=48, dither=Image.Dither.NONE).convert("RGB")
    else:
        pix.putalpha(pix.getchannel("A").point(lambda a: 255 if a >= 120 else 0))
    target = OUTPUT / f"{name}.png"
    tmp = target.with_suffix(".tmp.png")
    pix.save(tmp)
    os.replace(tmp, target)
