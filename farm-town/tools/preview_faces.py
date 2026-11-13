import sys
from PIL import Image
root = "D:/GoDot_Projects/Farm_Town/farm-town/"
names = sys.argv[1:]
K = 4
moods = 3
cols = 2
rows = (len(names) + cols - 1) // cols
out = Image.new("RGBA", (64 * K * moods * cols, 64 * K * rows), (247, 226, 180, 255))
for i, n in enumerate(names):
    im = Image.open(root + "art/characters/%s_face.png" % n).convert("RGBA")
    im = im.resize((im.width * K, 64 * K), Image.NEAREST)
    out.alpha_composite(im, ((i % cols) * 64 * K * moods, (i // cols) * 64 * K))
out.save(root + "_preview/faces.png")
print("ok")
