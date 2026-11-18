"""用 Blender 生成暖光灶台、透明食材与工具贴图，可选导出灶台 .blend。"""

import math
import os
import random
import sys
from pathlib import Path

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "art"
OUT.mkdir(exist_ok=True)
SCENE = bpy.context.scene
RNG = random.Random(712)
COLORS = {
    "room": "263c37", "tile": "39504a", "joint": "202c29",
    "stone": "413c34", "darkwood": "57362a", "wood": "8f5336",
    "board": "c98b55", "grain": "ae7348", "cream": "e7ca9b",
    "iron": "262933", "rim": "44454d", "clay": "974831",
    "fire": "ff7b28", "gold": "eab963", "leaf": "648752",
    "vine": "395f39", "red": "dd3926", "seed": "ffd985",
    "pulp": "f76a40", "porcelain": "d8d8b7", "jade": "547d70",
    "egg": "dbc19a", "yolk": "ffba27", "curd": "ffcd52", "steel": "939d9f",
}


def linear(x):
    return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4


def material(key):
    name = "灶间_" + key
    cached = bpy.data.materials.get(name)
    if cached:
        return cached
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    rgb = [linear(int(COLORS[key][i:i+2], 16) / 255) for i in (0, 2, 4)]
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*rgb, 1)
    bs.inputs["Roughness"].default_value = 0.31 if key in ("jade", "red", "porcelain", "iron") else 0.64
    if key in ("steel", "rim"):
        bs.inputs["Metallic"].default_value = 0.38
    if key == "fire":
        bs.inputs["Emission Color"].default_value = (*rgb, 1)
        bs.inputs["Emission Strength"].default_value = 1.2
    return m


def finish(obj, key, bevel=0, smooth=False):
    obj.data.materials.append(material(key))
    if smooth:
        for poly in obj.data.polygons:
            poly.use_smooth = True
    if bevel:
        b = obj.modifiers.new("圆边", "BEVEL")
        b.width = bevel
        b.segments = 3
        obj.modifiers.new("平面法线", "WEIGHTED_NORMAL")
    return obj


def box(p, dims, key, bevel=0.04, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p)
    obj = bpy.context.object
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.rotation_euler.z = angle
    return finish(obj, key, bevel)


def ball(p, dims, key, angle=0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=p)
    obj = bpy.context.object
    obj.scale = dims
    obj.rotation_euler.z = angle
    return finish(obj, key, smooth=True)


def lathe(p, profile, key):
    n = 64
    verts = [(r*math.cos(i*math.tau/n), r*math.sin(i*math.tau/n), z)
             for r, z in profile for i in range(n)]
    faces = [(j*n+i, j*n+(i+1)%n, (j+1)*n+(i+1)%n, (j+1)*n+i)
             for j in range(len(profile)-1) for i in range(n)]
    mesh = bpy.data.meshes.new(key)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(key, mesh)
    SCENE.collection.objects.link(obj)
    obj.location = p
    return finish(obj, key, smooth=True)


def hoop(p, radius, thickness, key):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=12,
                                     location=p, major_radius=radius, minor_radius=thickness)
    return finish(bpy.context.object, key, smooth=True)


def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()


def light(name, p, target, watt, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.color, data.shape, data.size = watt, color, "DISK", size
    ob = bpy.data.objects.new(name, data)
    SCENE.collection.objects.link(ob)
    ob.location = p
    aim(ob, target)


def camera(target, width):
    if SCENE.camera is None:
        bpy.ops.object.camera_add()
        SCENE.camera = bpy.context.object
    cam = SCENE.camera
    cam.location = Vector(target) + Vector((0, -8, 11))
    aim(cam, target)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = width


def render(name, w, h, transparent):
    SCENE.render.resolution_x = w
    SCENE.render.resolution_y = h
    SCENE.render.film_transparent = transparent
    tmp = OUT / (name + ".tmp.png")
    SCENE.render.filepath = str(tmp)
    bpy.ops.render.render(write_still=True)
    os.replace(tmp, OUT / (name + ".png"))


def clear_meshes():
    for ob in list(SCENE.objects):
        if ob.type == "MESH":
            bpy.data.objects.remove(ob, do_unlink=True)


def tomato():
    for i in range(6):
        a = i * math.tau / 6
        ball((0.27*math.cos(a), 0.27*math.sin(a), 0.02), (0.38, 0.38, 0.41), "red")
        ball((0.2*math.cos(a), 0.2*math.sin(a), 0.37), (0.23, 0.063, 0.028), "vine", a)
    box((0, 0, 0.43), (0.09, 0.1, 0.18), "vine", angle=0.3)


def wedge():
    lathe((0, 0, -0.1), [(0.02, 0), (0.48, 0), (0.55, 0.12), (0.49, 0.2), (0.02, 0.2)], "red")
    ball((0, 0, 0.075), (0.46, 0.46, 0.025), "pulp")
    for i in range(7):
        a = i * math.tau / 7
        ball((0.26*math.cos(a), 0.26*math.sin(a), 0.10), (0.075, 0.024, 0.015), "seed", a)


def egg():
    ball((-0.25, 0.04, 0), (0.32, 0.44, 0.33), "egg", -0.45)
    ball((0.29, -0.04, 0.02), (0.33, 0.45, 0.33), "cream", 0.62)


def bowl():
    lathe((0, 0, -0.23), [(0.02, 0), (0.28, 0), (0.56, 0.31), (0.53, 0.33),
                           (0.27, 0.08), (0.02, 0.08)], "jade")
    ball((0, 0, 0.025), (0.47, 0.47, 0.07), "yolk")
    hoop((0, 0, 0.094), 0.543, 0.025, "porcelain")
    ball((-0.11, 0.05, 0.084), (0.21, 0.13, 0.036), "gold", 0.3)


def curd():
    for i in range(9):
        a = i * math.tau / 9
        ball((0.25*math.cos(a), 0.22*math.sin(a), RNG.uniform(-0.1, 0.07)),
             (RNG.uniform(0.15, 0.28), 0.16, 0.14), "gold" if i % 3 == 0 else "curd", a)


def plate():
    lathe((0, 0, 0), [(0, -0.07), (0.42, -0.07), (0.7, 0.10), (0.68, 0.16),
                       (0.48, 0.04), (0, 0.04)], "porcelain")
    hoop((0, 0, 0.132), 0.639, 0.023, "jade")
    hoop((0, 0, 0.091), 0.572, 0.012, "jade")


def spatula():
    box((0.03, -0.13, 0), (0.16, 0.93, 0.10), "darkwood", 0.045, -0.19)
    box((-0.08, 0.37, 0.02), (0.34, 0.36, 0.073), "steel", 0.08, -0.19)


def knife():
    box((0, -0.32, 0.06), (0.22, 0.52, 0.15), "darkwood", 0.06)
    box((0.04, 0.27, -0.01), (0.36, 0.74, 0.09), "steel", 0.035)
    for y in (-0.20, -0.44):
        ball((0.01, y, 0.15), (0.033, 0.033, 0.008), "gold")


def stage():
    box((0, 0, -0.25), (23, 19, 0.45), "stone", 0)
    box((0, 5.6, 1.6), (23, 0.35, 4), "joint", 0)
    for row in range(6):
        for col in range(18):
            box((-11 + col*1.28 + 0.64*(row % 2), 5.40, row*0.53),
                (1.248, 0.09, 0.503), "tile", 0.025)
    for i in range(12):
        x = -9 + i*1.68
        box((x, 0.14, 0), (1.655, 9.4, 0.25), "wood", 0.027)
        for j in range(5):
            box((x+RNG.uniform(-0.75, 0.75), RNG.uniform(-4, 4), 0.129),
                (0.026, RNG.uniform(0.2, 1.25), 0.005), "darkwood", 0.002)
    # 砧板、瓷碗与铸铁锅一体构成工作台。
    box((-4, 0.05, 0.26), (3.93, 2.72, 0.26), "board", 0.17, -0.07)
    for i in range(14):
        box((-4 + RNG.uniform(-1.4, 1.45), RNG.uniform(-0.94, 1.05), 0.395),
            (RNG.uniform(0.13, 0.56), 0.017, 0.005), "grain", 0.003, -0.07)
    for x, y in ((-4.95, 2.08), (-3.88, 2.08), (-2.78, 2.08)):
        lathe((x,y,0.13), [(0.01,0),(.29,0),(.48,.24),(.45,.27),(.33,.16),(.01,.16)], "jade")
        hoop((x,y,0.385),.452,.017,"porcelain")
    # 炉体低，锅口足够开阔，可以看见食材受热。
    px, py = -0.05, 0.55
    box((px, py-0.06, 0.28), (3.6, 3.2, 0.32), "clay", 0.23)
    box((px, py-1.44, 0.26), (1.24, 0.15, 0.27), "joint", 0.12)
    hoop((px,py,0.48), 1.07, 0.085, "rim")
    lathe((px,py,0.45), [(0.01,0.01),(.65,.02),(1.02,.14),(1.40,.43),(1.58,.72),
                           (1.54,.75),(1.36,.46),(.99,.2),(.64,.071),(.01,.069)], "iron")
    hoop((px,py,1.17), 1.557, 0.035, "rim")
    for dx in (-1,1):
        ob = hoop((px+1.65*dx,py+0.02,1.09),0.33,0.052,"rim")
        ob.scale = (1.05, 0.55, 1)
    # 调料罐、绿叶与亚麻布放在互动区之外。
    for x, h, key in ((-5.8,.55,"clay"),(-4.85,.74,"jade"),(-3.92,.48,"cream"),(1.72,.61,"jade")):
        y = 3.48
        lathe((x,y,.11), [(0.02,0),(.29,0),(.34,h*.35),(.27,h*.80),(.19,h),(.03,h)], key)
        box((x,y,h+.12),(.38,.38,.07),"darkwood",.055,0.16)
    box((-0.15,3.42,.14),(2.04,1.06,.07),"cream",.06,.10)
    for i in range(10):
        x,y = -.74+RNG.random()*1.4,3.05+RNG.random()*.76
        ball((x,y,.22),(.28,.10,.04),"leaf",RNG.uniform(-1,1))
    box((-.42,-2.97,.14),(3.42,.62,.045),"jade",.045,.07)
    for i in range(12):
        box((-1.92+i*.27,-2.95,.168),(.018,.46,.008),"cream",.002,.07)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
SCENE.render.engine = "CYCLES"
SCENE.cycles.samples = 24
SCENE.cycles.use_denoising = True
SCENE.view_settings.view_transform = "AgX"
SCENE.render.image_settings.color_mode = "RGBA"
SCENE.render.resolution_percentage = 100
SCENE.world.color = (0.14, 0.14, 0.14)
light("暖窗", (-4.5,-1.5,7), (-1,0,0), 1400, (1,.86,.66), 5)
light("反光", (4,-2.5,5), (0,0,0), 580, (.66,.86,1), 5)
light("后光", (-.5,4.8,5), (-1,0,0), 660, (1,.77,.53), 3.5)

args = sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
if "sprites" not in args:
    stage()
    camera((-1.0, 0.3, 0.38), 13.1)
    render("kitchen", 920, 660, False)
    for name, pos in {"board": (-4, .07, .42), "pan": (-.05, .55, .65),
                      "fire": (-.05,-.90,.30)}.items():
        v = world_to_camera_view(SCENE, SCENE.camera, Vector(pos))
        print("ANCHOR", name, round(v.x*920), round((1-v.y)*660), flush=True)
    if "blend" in args:
        bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / "tools" / "kitchen.blend"))
    clear_meshes()
camera((0,0,0), 1.58)
SCENE.cycles.samples = 12
for make in [tomato, wedge, egg, bowl, curd, plate, spatula, knife]:
    if "plate" in args and make != plate:
        continue
    make()
    size = 560 if make == plate else 180
    render(make.__name__, size, size, True)
    clear_meshes()
