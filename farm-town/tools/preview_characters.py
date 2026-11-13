import sys
from PIL import Image
root = "D:/GoDot_Projects/Farm_Town/farm-town/"
names = sys.argv[1:]
C = 48
K = 6
W = 26  # 每格只截中间这么宽，放大了好看清
cells = [(0, 0), (0, 1), (0, 2), (0, 3), (1, 4), (3, 4), (1, 6), (3, 6)]
out = Image.new("RGBA", (W * K * len(cells), 34 * K * len(names)), (128, 189, 78, 255))
for i, n in enumerate(names):
    im = Image.open(root + "art/characters/%s.png" % n).convert("RGBA")
    # idle 下/上/右/左 各第一帧，接着 walk 下 2 帧、walk 右 2 帧
    for k, (cx, cy) in enumerate(cells):
        x0 = cx * C + (C - W) // 2
        cell = im.crop((x0, cy * C + 10, x0 + W, cy * C + 44)).resize((W * K, 34 * K), Image.NEAREST)
        out.alpha_composite(cell, (k * W * K, i * 34 * K))
out.save(root + "_preview/characters.png")
print("ok")
