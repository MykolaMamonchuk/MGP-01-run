# -*- coding: utf-8 -*-
"""Млин за малюнком mill_1_test_draw.jpg: кремова вежа-зрізаний конус зі світло-сірими каменями,
темне кільце й червоний гранчастий дах, маточина з рожевою кнопкою, чотири довгі ґратчасті
крила, арочні двері й вікно в товстих кремових рамках.

Пропорції зняті з малюнка (у пікселях, переведені через висоту вежі 1,15): дах ширший за верх
вежі на ~25% і трохи опуклий, крила сягають ~0,9 від осі — ширше за низ вежі.

Крила — ОКРЕМА частина «sails» (об'єкти part_sails__…): після запікання kit відокремлює її й
ставить початок координат у маточину, тож у грі й у сцені порівняння вона крутиться навколо
своєї осі (−Y у Blender = +Z у Godot, тобто до камери). Зазор крил до корпусу за повний оберт
перевіряє sail_gap() під час кожної збірки."""
import math
import random

import bmesh
import bpy

import kit
from kit import arch_curve, arch_profile, box, cyl, soften, sphere

PAL = {
    "tower_hi": "#FAE2BE", "tower": "#F2D2AA", "tower_lo": "#E0BC90",
    "stone_hi": "#D8D2C0", "stone": "#BDB9A8", "stone_lo": "#9EA096",
    "roof_hi": "#E86C56", "roof": "#D65440", "roof_lo": "#B0483A",
    "band": "#2E2E2E",
    "sail_hi": "#E0A468", "sail": "#CC8C58", "sail_lo": "#AE7648",
    "hub": "#9A5E40", "pink": "#E7A6C8",
    "door_hi": "#83483A", "door": "#6D3A2D", "door_line": "#4A2419",
    "frame_hi": "#F6EBC6", "frame": "#E8D9A6",
    "mull": "#86402F", "glass": "#7FA9C8", "glass_hi": "#D8ECF6",
}

TOWER_H, R_BOT, R_TOP = 1.15, 0.5, 0.325
# Точка обертання крил (Blender): маточина на даху трохи вище кільця. Площина крил винесена
# вперед так, щоб диск замаху (радіус ~0,92) не діставав ні вежі, ні каменів, ні рамки вікна.
HUB = (0.0, -0.475, 1.27)
SAIL_T = 0.03          # товщина крила по осі Y


def tower_r(z):
    return R_BOT + (R_TOP - R_BOT) * z / TOWER_H


def materials(k):
    return {
        "tower": k.mat_gradient("tower", [(0.0, "tower_lo"), (0.45, "tower"), (1.0, "tower_hi")], 0.0, 1.2, 0.3, 5.0),
        "stone": k.mat_gradient("stone", [(0.0, "stone_lo"), (0.55, "stone"), (1.0, "stone_hi")], 0.0, 1.2, 0.5, 12.0),
        "roof": k.mat_gradient("roof", [(0.0, "roof_lo"), (0.35, "roof"), (1.0, "roof_hi")], 1.2, 1.8, 0.2, 5.0),
        "band": k.mat_gradient("band", [(0.0, "band"), (1.0, "band")], 0.0, 1.0, 0.05),
        "sail": k.mat_gradient("sail", [(0.0, "sail_lo"), (0.5, "sail"), (1.0, "sail_hi")], 0.4, 2.2, 0.3, 9.0),
        "hub": k.mat_gradient("hub", [(0.0, "hub"), (1.0, "hub")], 0.0, 1.0, 0.05),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink")], 0.0, 1.0, 0.0),
        "door": k.mat_door("door"),
        "frame": k.mat_gradient("frame", [(0.0, "frame"), (1.0, "frame_hi")], 0.0, 1.2, 0.2, 8.0),
        "mull": k.mat_gradient("mull", [(0.0, "mull"), (1.0, "mull")], 0.0, 1.0, 0.05),
        "glass": k.mat_glass("glass"),
    }


def lathe(name, mat, prof, seg):
    """Тіло обертання навколо Z: prof — [(r, z)] знизу вгору; r=0 — вершина."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = []
    for r, z in prof:
        if r <= 1e-6:
            rings.append([bm.verts.new((0.0, 0.0, z))])
        else:
            rings.append([bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
                          for i in range(seg)])
    bm.faces.new(list(reversed(rings[0])))
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            if len(b) == 1:
                bm.faces.new((a[i], a[j], b[0]))
            else:
                bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def blade(name, m, k, ang):
    """Ґратчасте крило вздовж +Z від маточини, повернуте на ang навколо осі крил. Як на
    малюнку: три поздовжні рейки (середня — спиця від самої маточини), перекладини через усю
    ширину, тож клітинок два стовпчики; драбинка закрита перекладинами з обох кінців."""
    from mathutils import Matrix
    L0, L1, Wd = 0.17, 0.87, 0.165
    L = L1 - L0
    parts = []
    for dx in (-Wd / 2, Wd / 2):
        parts.append(box(name + "_rail", m["sail"], (dx, 0.0, L0 + L / 2), (0.024, SAIL_T * 0.9, L)))
    parts.append(box(name + "_arm", m["sail"], (0.0, 0.0, (L1 + 0.015) / 2), (0.032, SAIL_T, L1 + 0.015)))
    n = 9 if k.DET["bev"] >= 3 else (7 if k.DET["bev"] == 2 else 6)
    for i in range(n):
        z = L0 + 0.01 + i * (L - 0.02) / (n - 1)
        parts.append(box(name + "_rung", m["sail"], (0.0, 0.0, z), (Wd + 0.02, SAIL_T * 0.7, 0.02)))
    rot = Matrix.Translation(HUB) @ Matrix.Rotation(ang, 4, "Y")
    for ob in parts:
        ob.matrix_world = rot @ ob.matrix_world
    return parts


def sail_gap():
    """Зазор крил до корпусу за повний оберт. Крила крутяться в площині XZ навколо осі через
    HUB, тож замітають диск радіуса R (найдальша вершина крил від осі). Зазор = найближча до
    камери (найменша y) вершина корпусу в межах диска (+1 см) мінус найзадніша вершина крил.
    Маточину не рахуємо — це вісь. Від'ємне — крила проходять крізь стіну."""
    dg = bpy.context.evaluated_depsgraph_get()
    hx, hy, hz = HUB
    sails, rest = [], []
    for ob in bpy.data.objects:
        if ob.type not in ("MESH", "CURVE") or ob.name.startswith("hub"):
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        pts = [ob.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
        (sails if ob.name.startswith("part_sails__") else rest).extend(pts)
    # У конуса вежі вершини лише внизу й угорі — стіну між ними додаємо точками поверхні.
    from mathutils import Vector
    for iz in range(0, 116):
        z = TOWER_H * iz / 115
        for ia in range(-60, 61):
            a = math.radians(ia)
            rest.append(Vector((math.sin(a) * tower_r(z), -math.cos(a) * tower_r(z), z)))
    R = max(math.hypot(p.x - hx, p.z - hz) for p in sails)
    back = max(p.y for p in sails)
    near = [p for p in rest if math.hypot(p.x - hx, p.z - hz) <= R + 0.01]
    who = min(near, key=lambda p: p.y)
    gap = who.y - back
    print("ЗАЗОР КРИЛ: %.3f м (крила до y=%.3f, радіус замаху %.3f, найближче тіло y=%.3f у x=%.2f z=%.2f)"
          % (gap, back, R, who.y, who.x, who.z))
    if gap < 0.015:
        raise RuntimeError("крила за оберт ближче 1,5 см до корпусу: %.3f" % gap)
    return gap


def build(m, k):
    seg = max(12, k.DET["cyl"])
    # Вежа — «body»: зрізаний конус.
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=R_BOT, radius2=R_TOP, depth=TOWER_H,
                                    location=(0, 0, TOWER_H / 2))
    body = bpy.context.active_object
    body.name = "body"
    body.data.materials.append(m["tower"])
    soften(body, 0.02)

    # Камені: світло-сірі прямокутники, щільно на фасаді (його видно з дороги), рідше навколо.
    # Не ставимо їх туди, де стоять двері й вікно.
    rnd = random.Random(7)
    n = 30 if k.DET["bev"] >= 3 else (20 if k.DET["bev"] == 2 else 10)
    placed = 0
    tries = 0
    while placed < n and tries < 400:
        tries += 1
        # рівномірно по сітці «кут × висота» з тремтінням, щоб не збивались у купу
        cell = tries % 35
        a = (-1.3 + 2.6 * ((cell % 7) + rnd.uniform(0.15, 0.85)) / 7) if placed % 5 else rnd.uniform(-2.8, 2.8)
        z = 0.08 + 0.96 * ((cell // 7) + rnd.uniform(0.1, 0.9)) / 5
        x = math.sin(a) * tower_r(z)
        if abs(x) < 0.25 and z < 0.5:          # двері
            continue
        if abs(x) < 0.16 and 0.56 < z < 0.98:  # вікно
            continue
        r = tower_r(z) - 0.006
        w, h = rnd.uniform(0.11, 0.17), rnd.uniform(0.065, 0.1)
        st = box("stone%d" % placed, m["stone"], (math.sin(a) * r, -math.cos(a) * r, z), (w, 0.03, h), rot=(0, 0, a))
        soften(st, 0.01, 1)
        placed += 1

    # Темне кільце й червоний гранчастий дах, трохи опуклий, з напуском над вежею.
    cyl("band", m["band"], (0, 0, TOWER_H + 0.04), 0.36, 0.09, verts=seg)
    rseg = 14 if k.DET["bev"] >= 2 else 10
    # Профіль знятий з малюнка (частка висоти даху від низу → частка радіуса): внизу круглий
    # напуск, нижня третина опукла, верх — майже прямий гострий шпиль.
    R, z0, H = 0.435, TOWER_H + 0.07, 0.6
    prof = [(0.38, z0), (R, z0 + 0.025)]
    pts = [(0.07, 1.0), (0.19, 0.92), (0.35, 0.71), (0.58, 0.41), (0.8, 0.17), (1.0, 0.0)]
    if k.DET["bev"] < 2:
        pts = [(0.07, 1.0), (0.3, 0.78), (0.62, 0.36), (1.0, 0.0)]
    prof += [(R * f, z0 + 0.025 + (H - 0.025) * t) for t, f in pts]
    roof = lathe("roof", m["roof"], prof, rseg)
    roof.name = "roof"

    # Маточина на фасадному боці даху, рожева кнопка — це вісь крил.
    hub_back = 0.37
    cyl("hub", m["hub"], (HUB[0], (HUB[1] - 0.02 - hub_back) / 2, HUB[2]), 0.075,
        abs(-hub_back - (HUB[1] - 0.02)), rot=(math.pi / 2, 0, 0))

    # Крила — окрема частина «sails»: 4 драбинки хрестом навскоси.
    for i in range(4):
        for ob in blade("part_sails__b%d" % i, m, k, math.radians(45 + 90 * i)):
            ob.name = "part_sails__" + ob.name
    sphere("part_sails__cap", m["pink"], (HUB[0], HUB[1] - 0.035, HUB[2]), 0.03)

    # Арочні двері внизу: товста кремова рамка, темні дошки, рожева ручка.
    dw, dh = 0.3, 0.11
    fy = -R_BOT
    door = kit.prism("door", m["door"], arch_profile(dw, dh, k.DET["arch"]), fy - 0.012, fy + 0.06)
    arch_curve("door_frame", m["frame"], dw + 0.065, dh, fy - 0.01, 0.036)
    sphere("door_knob", m["pink"], (0.09, fy - 0.02, 0.14), 0.016)
    # Арочне вікно посередині: товста кремова рамка, темно-червоні шпроси сіткою, скло.
    wz = 0.63
    wy = -tower_r(wz + 0.08) - 0.004
    ww, wh = 0.13, 0.15
    kit.prism("win_glass", m["glass"], [(x, z + wz) for x, z in arch_profile(ww, wh, k.DET["win"])], wy + 0.002, wy + 0.04)
    arch_curve("win_frame", m["frame"], ww + 0.045, wh, wy - 0.004, 0.026, wz)
    arch_curve("win_red", m["mull"], ww + 0.005, wh, wy - 0.002, 0.009, wz)
    box("win_mv", m["mull"], (0, wy - 0.004, wz + (wh + ww / 2) / 2), (0.012, 0.012, wh + ww / 2))
    for zz in (0.35, 0.72):
        box("win_mh", m["mull"], (0, wy - 0.004, wz + wh * zz + 0.01), (ww, 0.012, 0.012))
    sail_gap()
    return {"parts": {"sails": HUB}}
