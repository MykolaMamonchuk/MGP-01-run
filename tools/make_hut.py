#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_hut.py — зібрати «пластиліновий» будиночок за малюнком (Blender headless).

Навіщо. Замовник дав малюнок (docs/refs/incoming/hut/hut_test_draw.jpg) і спитав, чи можна
з картинки зробити будинок із текстурами. Згенерована нейромережею модель — це мільйон
трикутників і «суп» граней, який не спрощується; а будиночок із малюнка — річ регулярна:
корпус із щипцем, крутий дах зі звисом, димар, кругле вікно, арочні двері. Це чесно
будується геометрією, а «пластилін» дають скошені краї, згладжування й запечена текстура.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/make_hut.py -- \\
        --detail high      # high | mid | low — повна, ~3000 і ~1500 вершин

Пише в assets/props/_exp/hut/: hut_<detail>.glb (з текстурою 1024) і окремо
hut_<detail>_{1024,512,256}.jpg — щоб у сцені порівняння (src/debug/hut_compare.tscn) було
видно, що дає кожен розмір текстури.

КОЛІР. Палітра знята з малюнка кластеризацією пікселів будинку (без тла й підставки): стіни
там не білі, а теплі пісочні зі світлом угорі й тінню по кутах; дах світлий, з темнішими
краями черепиці й тінню під звисом. Кожен матеріал — перехід між цими кольорами по висоті,
плюс легка нерівність ліплення; зверху запікається затінення в кутках і заглибинах (AO) —
саме воно дає ту «об'ємність», якої бракувало першій версії.

ДЕТАЛІЗАЦІЯ зменшується чесно — меншою кількістю сегментів у заокругленнях, дугах, кільцях,
а не різаком: різак на пластиліні лишає рвані краї.

Перед будинку — −Y у Blender, тобто +Z у Godot, як у решти хат. Результат — ОДИН меш з
ОДНИМ матеріалом і запеченою текстурою: так його малює MultiMesh декору.
"""
import argparse
import math
import os
import sys

import bpy
import bmesh
from mathutils import Matrix

# Палітра з малюнка (k-means по пікселях будинку, 26.09): світло → тінь.
PAL = {
    # Малюнок — студійний рендер у теплому світлі; ігрове світло холодніше й знебарвлює, тому
    # стіни й дах узяті на крок жовтішими за «сирі» кластери (перша спроба вийшла сіруватою).
    # Кольори малюнка вже містять студійне світло; гра кладе своє зверху й загалом темніша,
    # тож основний колір стін і даху — на крок світліший за «сирі» кластери (друга спроба в
    # ігровому світлі вийшла брунатною).
    "wall_hi": "#FAE8C4", "wall": "#F2D8AA", "wall_lo": "#E9C898", "wall_foot": "#DEB485",
    "roof_hi": "#FFF2CE", "roof": "#FDE8B6", "roof_edge": "#F1D39C", "roof_line": "#DEB67F",
    "roof_under": "#B68D68",
    "chimney_hi": "#E7CA9C", "chimney_lo": "#CFA47A",
    "cap_hi": "#C27856", "cap": "#B65E3E",
    "door_hi": "#94492F", "door": "#783A23", "door_line": "#4E2314",
    "frame_hi": "#BC6E41", "frame": "#A55432",
    "glass": "#7FB6D3", "glass_hi": "#D8F0FA",
    "step_hi": "#BBB4B3", "step_lo": "#928584",
    "stone": "#928584", "stone_lo": "#90724F",
    "lantern": "#CE8C56",
}

DETAIL = {
    #        скіс   дуга  бублик    сфера   арка вікна  циліндр
    # tube — переріз рамок вікон і дверей (0 — квадратний, 4 сторони)
    "high": dict(bev=3, arch=12, tor=(24, 8), sph=(10, 6), win=10, cyl=20, tube=3),
    "mid": dict(bev=2, arch=6, tor=(12, 5), sph=(8, 4), win=6, cyl=12, tube=1),
    "low": dict(bev=1, arch=4, tor=(8, 3), sph=(4, 3), win=3, cyl=6, tube=0),
}
DET = DETAIL["high"]


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--detail", default="high", choices=list(DETAIL.keys()))
    ap.add_argument("--out-dir", default="assets/props/_exp/hut")
    ap.add_argument("--name", default="hut")
    ap.add_argument("--tex", type=int, default=1024)
    return ap.parse_args(argv)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def rgb(hexcode):
    h = hexcode.lstrip("#")
    return tuple(srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)) + (1.0,)


# ---------- матеріали (процедурні, лише для запікання) ----------

def _new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
    return m


def _ramp(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, key) in zip(els, stops):
        el.position = pos
        el.color = rgb(PAL[key])
    return r


def _height(nt, z0, z1):
    """0..1 по висоті об'єкта між z0 і z1."""
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = z0
    mr.inputs["From Max"].default_value = z1
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    return mr.outputs["Result"], tc


def _jitter(nt, value_socket, tc, amount, scale):
    """Нерівність ліплення: висота трохи «гуляє» плямами — перехід не лінійка."""
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = scale
    noise.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], noise.inputs["Vector"])
    sub = nt.nodes.new("ShaderNodeMath")
    sub.operation = "SUBTRACT"
    nt.links.new(noise.outputs["Fac"], sub.inputs[0])
    sub.inputs[1].default_value = 0.5
    mul = nt.nodes.new("ShaderNodeMath")
    mul.operation = "MULTIPLY"
    nt.links.new(sub.outputs["Value"], mul.inputs[0])
    mul.inputs[1].default_value = amount
    add = nt.nodes.new("ShaderNodeMath")
    add.operation = "ADD"
    nt.links.new(value_socket, add.inputs[0])
    nt.links.new(mul.outputs["Value"], add.inputs[1])
    return add.outputs["Value"]


def mat_gradient(name, stops, z0, z1, jitter=0.25, scale=6.0):
    m = _new_mat(name)
    nt = m.node_tree
    h, tc = _height(nt, z0, z1)
    r = _ramp(nt, stops)
    nt.links.new(_jitter(nt, h, tc, jitter, scale), r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_roof(name):
    """Черепиця: ряди вздовж схилу; кожен ряд світлий угорі й темніший до нижнього краю
    (так «лусочки» читаються об'ємом), між лусочками — тонкий шов."""
    m = _new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    rows = nt.nodes.new("ShaderNodeTexWave")
    rows.wave_type = "BANDS"
    rows.bands_direction = "Z"
    rows.wave_profile = "SAW"
    rows.inputs["Scale"].default_value = 9.0
    rows.inputs["Distortion"].default_value = 0.5
    nt.links.new(tc.outputs["Object"], rows.inputs["Vector"])
    shade = _ramp(nt, [(0.0, "roof_edge"), (0.55, "roof"), (1.0, "roof_hi")])
    nt.links.new(rows.outputs["Fac"], shade.inputs["Fac"])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.feature = "DISTANCE_TO_EDGE"
    vor.inputs["Scale"].default_value = 16.0
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    seam = nt.nodes.new("ShaderNodeMapRange")
    seam.inputs["From Min"].default_value = 0.0
    seam.inputs["From Max"].default_value = 0.05
    nt.links.new(vor.outputs["Distance"], seam.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["B"].default_value = rgb(PAL["roof_line"])
    nt.links.new(shade.outputs["Color"], mix.inputs["A"])
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(seam.outputs["Result"], inv.inputs[1])
    nt.links.new(inv.outputs["Value"], mix.inputs["Factor"])
    nt.links.new(mix.outputs["Result"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_door(name):
    """Дошки: кожна світліша посередині й темніша до шва; зверху трохи світліше."""
    m = _new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "X"
    wave.inputs["Scale"].default_value = 5.5
    wave.inputs["Distortion"].default_value = 0.4
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    r = _ramp(nt, [(0.04, "door_line"), (0.18, "door"), (0.6, "door_hi")])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_glass(name):
    """Скло блакитне, з косим білим відблиском: темне скло малюнка в грі читалось діркою."""
    m = _new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.inputs["Scale"].default_value = 6.0
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    r = _ramp(nt, [(0.78, "glass"), (0.86, "glass_hi")])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


# ---------- геометрія ----------

def link(me, name, mat):
    ob = bpy.data.objects.new(name, me)
    me.materials.append(mat)
    bpy.context.collection.objects.link(ob)
    return ob


def soften(ob, width=0.02, segments=None):
    """Пластилін: скошені, заокруглені краї. У найпростішому варіанті дрібні деталі без
    скосу: на відстані, де він стоїть, заокруглення в 1-2 см не видно."""
    if DET["bev"] <= 1 and width < 0.03:
        return
    bv = ob.modifiers.new("bevel", "BEVEL")
    bv.width = width
    bv.segments = segments if segments is not None else DET["bev"]
    bv.limit_method = "ANGLE"


def prism(name, mat, profile, y0, y1):
    """Призма: 2D-профіль у площині XZ, витягнутий від y0 до y1. Нормалі — назовні."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    front = [bm.verts.new((x, y0, z)) for x, z in profile]
    back = [bm.verts.new((x, y1, z)) for x, z in profile]
    n = len(profile)
    bm.faces.new(front)
    bm.faces.new(list(reversed(back)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((front[i], front[j], back[j], back[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return link(me, name, mat)


def box(name, mat, c, size, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=c, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    ob.data.materials.append(mat)
    return ob


def cyl(name, mat, c, r, depth, rot=(0, 0, 0), verts=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts or DET["cyl"], radius=r, depth=depth,
                                        location=c, rotation=rot)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    return ob


def sphere(name, mat, c, r, scale=(1, 1, 1)):
    s, rings = DET["sph"]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=s, ring_count=rings, location=c)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = scale
    ob.data.materials.append(mat)
    return ob


def arch_profile(w, h_side, steps):
    """Прямокутник + півколо зверху: профіль арки шириною w, бічні стінки h_side."""
    r = w * 0.5
    prof = [(-r, 0.0), (r, 0.0)]
    for i in range(0, steps + 1):
        a = math.pi * i / steps
        prof.append((r * math.cos(a), h_side + r * math.sin(a)))
    return prof


def arch_curve(name, mat, w, h_side, y, thick, z0=0.0):
    """Арочна рамка: П-подібний шлях (бік — дуга — бік) з круглим перерізом."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = DET["tube"]
    cu.resolution_u = 2
    sp = cu.splines.new("POLY")
    r = w * 0.5
    steps = DET["arch"]
    pts = [(-r, z0), (-r, z0 + h_side)]
    for i in range(1, steps):
        a = math.pi - math.pi * i / steps
        pts.append((r * math.cos(a), z0 + h_side + r * math.sin(a)))
    pts += [(r, z0 + h_side), (r, z0)]
    sp.points.add(len(pts) - 1)
    for p, (x, z) in zip(sp.points, pts):
        p.co = (x, y, z, 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


FRAME_T = 0.024   # товщина (радіус) рамки вікна


def window(name, m, base, facing, w=0.2, h_side=0.16):
    """Арочне вікно лицем до −Y у початку координат, повернуте на свою стіну.
    Скло — ДО СЕРЕДИНИ рамки (замовник 26.09: «синє скло трішки менше за саме вікно»)."""
    made = []
    made.append(prism(name + "_glass", m["glass"], arch_profile(w, h_side, DET["win"]), 0.002, 0.014))
    made.append(arch_curve(name + "_frame", m["frame"], w, h_side, -0.006, FRAME_T))
    r = w * 0.5
    made.append(box(name + "_v", m["frame"], (0.0, -0.01, (h_side + r) * 0.5), (0.022, 0.02, h_side + r)))
    made.append(box(name + "_h", m["frame"], (0.0, -0.01, h_side * 0.8), (w, 0.02, 0.022)))
    sill = box(name + "_sill", m["frame"], (0.0, -0.035, -0.02), (w + 0.09, 0.07, 0.035))
    soften(sill, 0.012, min(2, DET["bev"]))
    made.append(sill)
    rot = {"-y": 0.0, "+x": math.pi / 2, "-x": -math.pi / 2, "+y": math.pi}[facing]
    for ob in made:
        ob.matrix_world = Matrix.Translation(base) @ Matrix.Rotation(rot, 4, "Z") @ ob.matrix_world
    return made


def build(m):
    W, D = 1.0, 0.95          # корпус: ширина (X) і глибина (Y)
    H = 0.78                  # висота стіни до карниза
    PEAK = 1.42               # гребінь щипця
    hw, hd = W * 0.5, D * 0.5
    # Корпус із щипцем, трохи ширший унизу — «ліплений», а не з лінійки.
    prof = [(-hw - 0.03, 0.0), (hw + 0.03, 0.0), (hw, H), (0.0, PEAK), (-hw, H)]
    body = prism("body", m["wall"], prof, -hd, hd)
    soften(body, 0.035)

    # ДАХ ЛЯГАЄ НА ЩИПЕЦЬ (замовник 26.09: «ніби парить над основою»). Раніше центр ската
    # стояв на 5 см вище, ніж треба, і під ним світилась щілина по всьому краю. Тепер спід
    # ската — рівно на лінії щипця, ще й на 1,5 см утоплений (скіс корпусу з'їдає ребро).
    slope = math.atan2(PEAK - H, hw)
    t = 0.09                                      # товщина ската
    run = math.hypot(hw, PEAK - H) + 0.22         # довжина ската зі звисом
    for side in (-1, 1):
        cx = side * (hw * 0.5 + 0.05)
        z_gable = PEAK - abs(cx) * math.tan(slope)
        cz = z_gable + (t * 0.5) / math.cos(slope) - 0.015
        r = box("roof%d" % side, m["roof"], (cx, 0.0, cz), (run, D + 0.26, t),
                rot=(0.0, side * slope, 0.0))
        soften(r, 0.03)

    # Димар ліворуч, ближче до фасаду (як на малюнку), крізь скат; шапка — брунатний «гриб».
    ch = box("chimney", m["chimney"], (-0.33, -0.08, 1.18), (0.2, 0.2, 0.62))
    soften(ch, 0.04)
    cap = cyl("cap", m["cap"], (-0.33, -0.08, 1.52), 0.15, 0.07)
    soften(cap, 0.02, min(2, DET["bev"]))
    cap2 = cyl("cap2", m["cap"], (-0.33, -0.08, 1.58), 0.09, 0.07)
    soften(cap2, 0.02, min(2, DET["bev"]))

    fy = -hd - 0.012          # передня площина стіни (−Y — фасад)

    # Кругле вікно в щипці: рамка-бублик, скло до середини бублика, хрестовина перед склом.
    ts, tr = DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.035, major_segments=ts,
                                     minor_segments=tr, location=(0.0, fy, 1.0), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = "win_ring"
    ring.data.materials.append(m["frame"])
    cyl("win_glass", m["glass"], (0.0, fy + 0.012, 1.0), 0.12, 0.012, rot=(math.pi / 2, 0, 0))
    box("win_v", m["frame"], (0.0, fy - 0.008, 1.0), (0.026, 0.024, 0.22))
    box("win_h", m["frame"], (0.0, fy - 0.008, 1.0), (0.22, 0.024, 0.026))

    # Віддушина під гребенем: коротка брунатна планка з поличкою.
    box("vent", m["frame"], (0.0, fy, 1.27), (0.025, 0.03, 0.12))
    box("vent_b", m["frame"], (0.0, fy - 0.01, 1.2), (0.07, 0.04, 0.025))

    # Арочні двері: дошки (профіль — прямокутник + півколо) і товста рамка.
    dw, dh = 0.34, 0.36
    door = prism("door", m["door"], arch_profile(dw, dh, DET["arch"]), fy - 0.02, fy + 0.02)
    soften(door, 0.012, min(2, DET["bev"]))
    arch_curve("door_frame", m["frame"], dw + 0.05, dh, fy - 0.015, 0.035)
    sphere("knob", m["frame"], (0.1, fy - 0.035, 0.26), 0.025)

    # Поріг — сірий заокруглений брусок перед дверима.
    st = box("step", m["step"], (0.0, fy - 0.08, 0.04), (0.46, 0.16, 0.08))
    soften(st, 0.035)

    # Ліхтарик ліворуч від дверей, камінці, втоплені в стіну.
    ln = box("lantern", m["lantern"], (-0.34, fy - 0.03, 0.47), (0.07, 0.06, 0.1))
    soften(ln, 0.012, min(2, DET["bev"]))
    sphere("stone", m["stone"], (-0.36, fy + 0.005, 0.22), 0.07, (0.9, 0.35, 1.2))
    sphere("pebble", m["stone"], (0.34, fy + 0.005, 0.44), 0.05, (0.7, 0.3, 1.0))

    # Вікна по боках і ззаду: арочні, з рамкою, хрестовиною, склом і підвіконням.
    for sx in (-1, 1):
        for wy in (-0.2, 0.22):
            window("side_win", m, (sx * (hw + 0.02), wy, 0.3), "+x" if sx > 0 else "-x")
    window("back_win", m, (0.0, hd + 0.012, 0.3), "+y")


def join_all():
    bpy.ops.object.select_all(action="DESELECT")
    for ob in list(bpy.data.objects):
        if ob.type == "CURVE":
            bpy.context.view_layer.objects.active = ob
            ob.select_set(True)
            bpy.ops.object.convert(target="MESH")
            ob.select_set(False)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            bpy.context.view_layer.objects.active = ob
            for md in list(ob.modifiers):
                bpy.ops.object.modifier_apply(modifier=md.name)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.select_set(True)
    bpy.context.view_layer.objects.active = [o for o in bpy.data.objects if o.name == "body"][0]
    bpy.ops.object.join()
    hut = bpy.context.active_object
    hut.name = "hut"
    for p in hut.data.polygons:
        p.use_smooth = True
    return hut


def bake(hut, size):
    """Колір і затінення (AO) — два запікання, а в текстуру йде колір × м'яке затінення."""
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.bake.margin = 6
    # Світ — рівне світле тло, щоб AO рахувався від неба, а не від чорноти.
    w = bpy.data.worlds.new("bake")
    sc.world = w
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    imgs = {}
    for kind in ("color", "ao"):
        img = bpy.data.images.new("hut_" + kind, size, size)
        for mat in hut.data.materials:
            nt = mat.node_tree
            node = nt.nodes.get("bake_target") or nt.nodes.new("ShaderNodeTexImage")
            node.name = "bake_target"
            node.image = img
            nt.nodes.active = node
        bpy.ops.object.select_all(action="DESELECT")
        hut.select_set(True)
        bpy.context.view_layer.objects.active = hut
        if kind == "color":
            sc.render.bake.use_pass_direct = False
            sc.render.bake.use_pass_indirect = False
            sc.render.bake.use_pass_color = True
            bpy.ops.object.bake(type="DIFFUSE")
        else:
            bpy.ops.object.bake(type="AO")
        imgs[kind] = img
    # колір × (0,78 + 0,22 · AO): затінення в кутках і під звисом, але не чорнота — гра
    # кладе ще й своє світло, і сильніше затінення робило хатинку брунатною
    import numpy as np
    n = size * size * 4
    col = np.empty(n, dtype=np.float32)
    ao = np.empty(n, dtype=np.float32)
    imgs["color"].pixels.foreach_get(col)
    imgs["ao"].pixels.foreach_get(ao)
    col = col.reshape(-1, 4)
    k = 0.78 + 0.22 * ao.reshape(-1, 4)[:, :1]
    col[:, :3] *= k
    col[:, 3] = 1.0
    final = bpy.data.images.new("hut_final", size, size)
    final.pixels.foreach_set(col.ravel())
    return final


def main():
    global DET
    a = parse_args(sys.argv)
    DET = DETAIL[a.detail]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = {
        "wall": mat_gradient("wall", [(0.0, "wall_foot"), (0.22, "wall_lo"), (0.55, "wall"), (1.0, "wall_hi")], 0.0, 1.4),
        "roof": mat_roof("roof"),
        "chimney": mat_gradient("chimney", [(0.0, "chimney_lo"), (1.0, "chimney_hi")], 0.9, 1.5),
        "cap": mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 1.49, 1.62, 0.1, 9.0),
        "door": mat_door("door"),
        "frame": mat_gradient("frame", [(0.0, "frame"), (1.0, "frame_hi")], 0.0, 1.2, 0.3, 9.0),
        "glass": mat_glass("glass"),
        "step": mat_gradient("step", [(0.0, "step_lo"), (1.0, "step_hi")], 0.0, 0.08, 0.2, 8.0),
        "stone": mat_gradient("stone", [(0.0, "stone_lo"), (1.0, "stone")], 0.1, 0.55, 0.3, 10.0),
        "lantern": mat_gradient("lantern", [(0.0, "frame"), (1.0, "lantern")], 0.42, 0.52, 0.1, 9.0),
    }
    build(m)
    hut = join_all()
    hut.data.calc_loop_triangles()
    print("трикутників:", len(hut.data.loop_triangles), "вершин (Blender):", len(hut.data.vertices))

    img = bake(hut, a.tex)
    out_mat = bpy.data.materials.new("hut_baked")
    out_mat.use_nodes = True
    b = out_mat.node_tree.nodes["Principled BSDF"]
    b.inputs["Roughness"].default_value = 0.9
    tex = out_mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = img
    out_mat.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
    hut.data.materials.clear()
    hut.data.materials.append(out_mat)

    out_dir = os.path.abspath(a.out_dir)
    os.makedirs(out_dir, exist_ok=True)
    base = "%s_%s" % (a.name, a.detail)
    # Три розміри текстури окремими файлами — для порівняння в грі. Менші — усередненням
    # пікселів (як mipmap), а не копією зображення: копія згенерованого в Blender зображення
    # приходить порожньою (перша спроба дала чорні файли).
    import numpy as np
    full = np.empty(a.tex * a.tex * 4, dtype=np.float32)
    img.pixels.foreach_get(full)
    full = full.reshape(a.tex, a.tex, 4)
    for size in (1024, 512, 256):
        f = a.tex // size
        arr = full.reshape(size, f, size, f, 4).mean(axis=(1, 3)) if f > 1 else full
        im = bpy.data.images.new("%s_%d" % (base, size), size, size)
        im.pixels.foreach_set(arr.astype(np.float32).ravel())
        im.filepath_raw = os.path.join(out_dir, "%s_%d.jpg" % (base, size))
        im.file_format = "JPEG"
        im.save()
    img.pack()
    out = os.path.join(out_dir, base + ".glb")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG",
                              export_jpeg_quality=90)
    print("OUT", out, os.path.getsize(out))


main()
