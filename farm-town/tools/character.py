"""用 Blender 生成人形角色的 3D 模型和动作，渲染成带描边的像素序列帧。

用法:  blender --background --python tools/character.py -- [配置名]
       配置在 tools/characters/<配置名>.json，默认 farmer
输出:  art/characters/<名字>.png   48x48 一格；行 = 动画 x 方向(下/上/右/左)，列 = 帧
       art/characters/<名字>.json  帧描述：每个动画在第几行、几帧、动作时间表
       tools/<名字>.blend          模型文件，可以用 Blender 打开查看
颜色全部来自 data/palette.json，和游戏里代码画的素材是同一套。
"""
import json
import math
import os
import shutil
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PROJ = os.path.dirname(HERE)
TMP = os.path.join(HERE, "_tmp")

_args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CONFIG_NAME = _args[0] if _args else "farmer"
with open(os.path.join(HERE, "characters", CONFIG_NAME + ".json"), encoding="utf-8") as _f:
    CONFIG = json.load(_f)
with open(os.path.join(PROJ, "data", "palette.json"), encoding="utf-8") as _f:
    LETTERS = json.load(_f)
NAME = CONFIG.get("name", CONFIG_NAME)
OUT_DIR = os.path.join(PROJ, "art", "characters")
OUT = os.path.join(OUT_DIR, NAME + ".png")
OUT_JSON = os.path.join(OUT_DIR, NAME + ".json")

CELL = 48          # 每帧像素
SS = 4             # 超采样倍数：先渲染 192x192，再按众数缩小
PPU = 16.0         # 每个 Blender 单位对应的像素
ELEV = math.radians(14.0)   # 相机俯角
FOOT_ROW = 40      # 脚底所在的像素行，与手绘版一致
PIX = 1.0 / PPU / math.cos(ELEV)   # 屏幕上 1 像素对应的世界高度
HIP = 0.36
THRESH = 0.2       # 明暗分界
SCALE = 1.2        # 整体放大，让角色和手绘版差不多高
SCALE = 1.2        # 整体放大，让角色和手绘版差不多高
SCALE = 1.2        # 整体放大，让角色和手绘版差不多高

# 动画表：帧数，以及游戏里怎么播放。seq 是 [帧, 秒] 的时间表，strike 是生效的那一步。
ANIMS = [
    ("idle", 4, {"loop": True, "fps": 3.0}),
    ("walk", 8, {"loop": True, "step_frames": [0, 4]}),
    ("hoe", 6, {"seq": [[0, 0.07], [1, 0.11], [2, 0.04], [3, 0.09], [4, 0.08], [5, 0.11]], "strike": 3}),
    ("water", 4, {"seq": [[0, 0.09], [1, 0.09], [2, 0.14], [3, 0.12], [2, 0.14], [0, 0.08]], "strike": 2}),
    ("reach", 3, {"seq": [[0, 0.06], [1, 0.06], [2, 0.15], [1, 0.06], [0, 0.06]], "strike": 2}),
]
DIRS = [0.0, 180.0, 90.0, -90.0]   # 下 上 右 左
COLS = 8

# 部位: (亮面, 暗面)，写的是 data/palette.json 里的键；配置文件可以覆盖
PARTS = {
    "skin": ("s", "S"),
    "hair": ("h", "H"),
    "shirt": ("b", "B"),
    "blue": ("p", "P"),
    "boot": ("t", "T"),
    "hat": ("y", "Y"),
    "band": ("r", "R"),
    "wood": ("w", "W"),
    "metal": ("m", "M"),
    "can": ("g", "G"),
    "eye": ("e", "e"),
}
for _part, _keys in CONFIG.get("parts", {}).items():
    PARTS[_part] = tuple(_keys)
PAL = {part: (LETTERS[a], LETTERS[b]) for part, (a, b) in PARTS.items()}
HAS_HAT = CONFIG.get("hat", True)


def d(deg):
    return math.radians(deg)


def hex_rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_lin(h):
    r, g, b = hex_rgb(h)
    return (lin(r), lin(g), lin(b), 1.0)


PALETTE = []
for _n, (_a, _b) in PAL.items():
    for _h in (_a, _b):
        if hex_rgb(_h) not in PALETTE:
            PALETTE.append(hex_rgb(_h))
PAL_ARR = np.array(PALETTE, dtype=np.int32)
EYE_IDX = PALETTE.index(hex_rgb(PAL["eye"][0]))


# ------------------------------------------------------------------ 场景

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 1
scene.render.filter_size = 0.01
scene.render.dither_intensity = 0.0
scene.render.film_transparent = True
scene.render.resolution_x = CELL * SS
scene.render.resolution_y = CELL * SS
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "None"

world = bpy.data.worlds.new("World")
world.use_nodes = True
for n in world.node_tree.nodes:
    if n.type == "BACKGROUND":
        n.inputs[0].default_value = (0, 0, 0, 1)
scene.world = world

cam_data = bpy.data.cameras.new("Cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = CELL / PPU
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
# 让世界原点（脚底）落在第 FOOT_ROW 行
target_z = (FOOT_ROW - CELL / 2.0) / PPU / math.cos(ELEV)
cam.location = (0.0, -10.0 * math.cos(ELEV), target_z + 10.0 * math.sin(ELEV))
cam.rotation_euler = (math.pi / 2.0 - ELEV, 0.0, 0.0)

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = math.pi
sun_data.use_shadow = False
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = Vector((0.45, 0.55, -0.7)).to_track_quat("-Z", "Y").to_euler()


def make_mat(name):
    light, dark = PAL[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    diff = nt.nodes.new("ShaderNodeBsdfDiffuse")
    diff.inputs["Color"].default_value = (1, 1, 1, 1)
    to_rgb = nt.nodes.new("ShaderNodeShaderToRGB")
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].position = 0.0
    ramp.color_ramp.elements[0].color = hex_lin(dark)
    ramp.color_ramp.elements[1].position = THRESH
    ramp.color_ramp.elements[1].color = hex_lin(light)
    emit = nt.nodes.new("ShaderNodeEmission")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(diff.outputs[0], to_rgb.inputs[0])
    nt.links.new(to_rgb.outputs[0], ramp.inputs[0])
    nt.links.new(ramp.outputs[0], emit.inputs[0])
    nt.links.new(emit.outputs[0], out.inputs[0])
    return m


MATS = {n: make_mat(n) for n in PAL}


# ------------------------------------------------------------------ 建模

def empty(name, parent, loc=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    scene.collection.objects.link(o)
    o.parent = parent
    o.location = loc
    o.empty_display_size = 0.1
    return o


def _finish(name, parent, loc, mat, smooth):
    o = bpy.context.active_object
    o.name = name
    o.parent = parent
    o.location = loc
    o.data.materials.append(MATS[mat])
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
        try:
            o.data.set_sharp_from_angle(angle=d(50))
        except Exception:
            pass
    return o


def box(name, parent, size, loc, mat):
    bpy.ops.mesh.primitive_cube_add(size=1.0)
    o = _finish(name, parent, loc, mat, False)
    o.scale = size
    return o


def ball(name, parent, radii, loc, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1.0)
    o = _finish(name, parent, loc, mat, True)
    o.scale = radii
    return o


def cyl(name, parent, r1, r2, depth, loc, mat):
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r2, depth=depth)
    return _finish(name, parent, loc, mat, True)


root = empty("Root", None)
root.scale = (SCALE, SCALE, SCALE)
root.scale = (SCALE, SCALE, SCALE)
root.scale = (SCALE, SCALE, SCALE)
hips = empty("Hips", root, (0, 0, HIP))
# torso 只负责前倾；身体的扭转放在 chest 上，头不跟着扭，
# 这样走路时脸在屏幕上的位置不变，眼睛不会因为亚像素移动而闪烁。
torso = empty("Torso", hips)
chest = empty("ChestTwist", torso)

box("Pelvis", chest, (0.50, 0.32, 0.20), (0, 0, 0.08), "blue")
box("Chest", chest, (0.50, 0.32, 0.22), (0, 0, 0.28), "shirt")
box("Bib", chest, (0.26, 0.05, 0.17), (0, -0.165, 0.25), "blue")
for sx in (-1, 1):
    box("Strap", chest, (0.07, 0.35, 0.23), (0.115 * sx, 0, 0.285), "blue")

head = empty("Head", torso, (0, 0, 0.40))
ball("Skull", head, (0.37, 0.34, 0.30), (0, 0, 0.27), "skin")
hair = ball("Hair", head, (0.395, 0.365, 0.32), (0, 0.02, 0.285), "hair")
bm = bmesh.new()
bm.from_mesh(hair.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces
                           if f.calc_center_median().y < 0.0 and f.calc_center_median().z < 0.35],
                 context="FACES")
bm.to_mesh(hair.data)
bm.free()
for sx in (-1, 1):
    # 眼睛略微包到侧面，侧脸也能看到
    box("Eye", head, (0.12, 0.13, 0.15), (0.155 * sx, -0.285, 0.235), "eye")
hat = empty("Hat", head, (0, 0.03, 0.50))
hat.rotation_euler = (d(-13), 0, 0)
if HAS_HAT:
    cyl("Brim", hat, 0.45, 0.45, 0.05, (0, 0, 0.0), "hat")
    cyl("Band", hat, 0.315, 0.31, 0.07, (0, 0, 0.06), "band")
    cyl("Crown", hat, 0.31, 0.25, 0.17, (0, 0, 0.18), "hat")

legs = []
arms = []
for sx in (1, -1):
    hip = empty("LegPivot", hips, (0.13 * sx, 0, 0))
    box("Thigh", hip, (0.20, 0.21, 0.20), (0, 0, -0.08), "blue")
    knee = empty("Knee", hip, (0, 0, -0.17))
    box("Shin", knee, (0.19, 0.20, 0.10), (0, 0, -0.03), "blue")
    box("Boot", knee, (0.22, 0.30, 0.12), (0, -0.035, -0.13), "boot")
    legs.append((hip, knee))

    sh = empty("ArmPivot", chest, (0.315 * sx, 0, 0.34))
    box("UpperArm", sh, (0.13, 0.14, 0.19), (0, 0, -0.075), "shirt")
    elbow = empty("Elbow", sh, (0, 0, -0.17))
    box("ForeArm", elbow, (0.12, 0.13, 0.12), (0, 0, -0.05), "shirt")
    ball("Hand", elbow, (0.075, 0.075, 0.075), (0, 0, -0.14), "skin")
    hand = empty("HandTip", elbow, (0, 0, -0.14))
    arms.append((sh, elbow, hand, sx))

grip = empty("Grip", root)
hoe = empty("Hoe", grip)
h = cyl("Handle", hoe, 0.036, 0.036, 0.86, (0, 0, -0.31), "wood")
box("Blade", hoe, (0.22, 0.20, 0.06), (0, 0.07, -0.74), "metal")
can = empty("Can", grip)
cyl("CanBody", can, 0.14, 0.13, 0.22, (0, -0.06, -0.08), "can")
sp = cyl("Spout", can, 0.035, 0.05, 0.26, (0, -0.27, 0.0), "can")
sp.rotation_euler = (d(-55), 0, 0)


def set_visible(obj, vis):
    obj.hide_render = not vis
    for c in obj.children:
        set_visible(c, vis)


# ------------------------------------------------------------------ 姿势

BASE = dict(bob=0.0, crouch=0.0, lean=0.0, twist=0.0, head=0.0,
            leg=(0.0, 0.0), knee=(0.0, 0.0), arm=(0.0, 0.0), elbow=(-8.0, -8.0),
            yaw=0.0, spread=4.0, tool=None, tool_pitch=0.0, tool_off=(0.0, 0.0))


def pose(**kw):
    p = dict(BASE)
    p.update(kw)
    return p


def frames(anim):
    if anim == "idle":
        return [
            pose(),
            pose(arm=(3, 3), head=2),
            pose(bob=-PIX, arm=(5, 5), head=3, spread=6),
            pose(arm=(3, 3), head=2),
        ]
    if anim == "walk":
        out = []
        amp, bend = 38.0, 60.0
        for i in range(8):
            ph = math.tau * i / 8.0 + math.pi / 2.0
            s, c = math.sin(ph), math.cos(ph)
            out.append(pose(
                bob=0.035 * math.cos(2.0 * ph) - 0.03,
                lean=4, twist=9.0 * s, head=-6,
                leg=(amp * s, -amp * s),
                knee=(bend * max(0.0, -c), bend * max(0.0, c)),
                arm=(-34.0 * s, 34.0 * s),
                elbow=(-14 - 12 * max(0.0, s), -14 - 12 * max(0.0, -s)),
            ))
        return out
    if anim == "hoe":
        return [
            pose(arm=(-115, -115), elbow=(-30, -30), yaw=25, lean=-2, tool="hoe", tool_pitch=-150),
            pose(arm=(-195, -195), elbow=(-25, -25), yaw=10, lean=-5, head=-5, bob=PIX,
                 tool="hoe", tool_pitch=-215),
            # 下砸途中锄头已经低于脸，正面看不会挡住眼睛
            pose(arm=(-78, -78), elbow=(-10, -10), yaw=30, lean=6, crouch=10, head=-4,
                 tool="hoe", tool_pitch=-98),
            pose(arm=(-42, -42), elbow=(-12, -12), yaw=35, lean=15, head=-4, crouch=26,
                 tool="hoe", tool_pitch=-68),
            pose(arm=(-52, -52), elbow=(-18, -18), yaw=35, lean=11, head=-3, crouch=18,
                 tool="hoe", tool_pitch=-76),
            pose(arm=(-45, -45), elbow=(-25, -25), yaw=35, lean=7, crouch=8,
                 tool="hoe", tool_pitch=-88),
        ]
    if anim == "water":
        return [
            pose(arm=(-38, -38), elbow=(-45, -45), yaw=38, lean=3, tool="can", tool_pitch=-5),
            pose(arm=(-52, -52), elbow=(-30, -30), yaw=38, lean=9, crouch=10, head=5,
                 tool="can", tool_pitch=-28),
            pose(arm=(-58, -58), elbow=(-22, -22), yaw=38, lean=13, crouch=16, head=8,
                 tool="can", tool_pitch=-42),
            pose(arm=(-55, -55), elbow=(-26, -26), yaw=38, lean=11, crouch=13, head=7,
                 tool="can", tool_pitch=-36),
        ]
    if anim == "reach":
        return [
            pose(arm=(-25, -25), elbow=(-25, -25), yaw=15, lean=14, crouch=14, head=6),
            pose(arm=(-42, -42), elbow=(-15, -15), yaw=22, lean=24, crouch=30, head=2),
            pose(arm=(-50, -50), elbow=(-8, -8), yaw=25, lean=32, crouch=42, head=4),
        ]
    raise ValueError(anim)


def apply_pose(p, facing_deg):
    c = d(p["crouch"])
    drop = (0.17 + 0.19) * (1.0 - math.cos(c))
    z = round((p["bob"] - drop) * SCALE / PIX) * PIX / SCALE
    root.rotation_euler = (0, 0, d(facing_deg))
    hips.location = (0, 0, HIP + z)
    torso.rotation_euler = (d(p["lean"]), 0, 0)
    chest.rotation_euler = (0, 0, d(p["twist"]))
    head.rotation_euler = (d(p["head"]), 0, 0)
    for i, (hip, knee) in enumerate(legs):
        hip.rotation_euler = (d(p["leg"][i]) - c, 0, 0)
        knee.rotation_euler = (d(p["knee"][i]) + 2.0 * c, 0, 0)
    for i, (sh, elbow, hand, sx) in enumerate(arms):
        sh.rotation_euler = (d(p["arm"][i]), d(-p["spread"] * sx), d(p["yaw"] * sx))
        elbow.rotation_euler = (d(p["elbow"][i]), 0, 0)
    set_visible(hoe, p["tool"] == "hoe")
    set_visible(can, p["tool"] == "can")
    if p["tool"] is not None:
        bpy.context.view_layer.update()
        inv = root.matrix_world.inverted()
        mid = (inv @ arms[0][2].matrix_world.translation + inv @ arms[1][2].matrix_world.translation) * 0.5
        grip.location = mid
        grip.rotation_euler = (d(p["tool_pitch"]), 0, 0)
    bpy.context.view_layer.update()


# ------------------------------------------------------------------ 渲染与像素化

def render_frame(path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, hgt = img.size
    buf = np.empty(w * hgt * 4, dtype=np.float32)
    img.pixels.foreach_get(buf)
    bpy.data.images.remove(img)
    arr = (buf.reshape(hgt, w, 4)[::-1] * 255.0 + 0.5).astype(np.uint8)
    return arr


def pixelate(a):
    """每个 4x4 块取出现最多的调色板颜色；覆盖不足一半的块视为透明。"""
    rgb = a[..., :3].astype(np.int32)
    dist = ((rgb[:, :, None, :] - PAL_ARR[None, None, :, :]) ** 2).sum(-1)
    idx = dist.argmin(-1)
    opaque = a[..., 3] > 127
    idx = np.where(opaque, idx, -1)
    blocks = idx.reshape(CELL, SS, CELL, SS).transpose(0, 2, 1, 3).reshape(CELL, CELL, SS * SS)
    out = np.zeros((CELL, CELL, 4), dtype=np.uint8)
    cover = (blocks >= 0).sum(-1)
    ys, xs = np.nonzero(cover >= 7)
    for y, x in zip(ys, xs):
        vals = blocks[y, x]
        counts = np.bincount(vals[vals >= 0], minlength=len(PALETTE))
        best = int(counts.argmax())
        if counts[EYE_IDX] >= 5:
            best = EYE_IDX
        out[y, x, :3] = PALETTE[best]
        out[y, x, 3] = 255
    return out


def outline(a):
    """给不透明区域外侧加一圈描边，颜色取相邻像素的暗色（与 art_gen/pixel.gd 的算法一致）。"""
    out = a.copy()
    hgt, w = a.shape[:2]
    for y in range(hgt):
        for x in range(w):
            if a[y, x, 3] > 0:
                continue
            for dx, dy in ((0, 1), (-1, 0), (1, 0), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < hgt and a[ny, nx, 3] > 127:
                    r, g, b = (a[ny, nx, :3].astype(np.float32) / 255.0)
                    col = (r * 0.36 + 0.03, g * 0.30 + 0.01, b * 0.38 + 0.06)
                    out[y, x, :3] = [int(c * 255.0 + 0.5) for c in col]
                    out[y, x, 3] = 255
                    break
    return out


def save_png(arr, path):
    hgt, w = arr.shape[:2]
    img = bpy.data.images.new("out", w, hgt, alpha=True)
    img.pixels.foreach_set((arr[::-1].astype(np.float32) / 255.0).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def main():
    os.makedirs(TMP, exist_ok=True)
    os.makedirs(OUT_DIR, exist_ok=True)
    rows = len(ANIMS) * len(DIRS)
    sheet = np.zeros((rows * CELL, COLS * CELL, 4), dtype=np.uint8)
    row = 0
    desc = {"cell": CELL, "foot_row": FOOT_ROW, "dirs": ["down", "up", "right", "left"], "anims": {}}
    for anim, count, play in ANIMS:
        fr = frames(anim)
        info = {"row": row, "frames": count}
        info.update(play)
        desc["anims"][anim] = info
        assert len(fr) == count, anim
        for facing in DIRS:
            for k, p in enumerate(fr):
                apply_pose(p, facing)
                a = render_frame(os.path.join(TMP, "f.png"))
                sheet[row * CELL:(row + 1) * CELL, k * CELL:(k + 1) * CELL] = outline(pixelate(a))
            row += 1
        print("rendered", anim, flush=True)
    save_png(sheet, OUT)
    with open(OUT_JSON, "w", encoding="utf-8") as f:
        json.dump(desc, f, ensure_ascii=False, indent="\t")
        f.write("\n")
    shutil.rmtree(TMP, ignore_errors=True)

    # 存一份模型文件，停在挥锄的姿势，方便用 Blender 打开看
    apply_pose(frames("hoe")[3], 0.0)
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, NAME + ".blend"))
    print("saved", OUT, flush=True)


main()
