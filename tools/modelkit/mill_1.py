# -*- coding: utf-8 -*-
"""Млин за малюнком mill_1_test_draw.jpg: кремова вежа-зрізаний конус із сірими каменями,
темне кільце й червоний конічний дах, маточина з рожевою кнопкою, чотири ґратчасті крила,
арочні двері й вікно в кремових рамках.

Крила — ОКРЕМА частина «sails» (об'єкти part_sails__…): після запікання kit відокремлює її й
ставить початок координат у маточину, тож у грі й у сцені порівняння вона крутиться навколо
своєї осі (−Y у Blender = +Z у Godot, тобто до камери)."""
import math
import random

import bpy

import kit
from kit import arch_curve, arch_profile, box, cyl, prism, soften, sphere

PAL = {
    "tower_hi": "#F6EACB", "tower": "#EADBB4", "tower_lo": "#D3C396",
    "stone_hi": "#B7B9A6", "stone": "#A1A17E", "stone_lo": "#888A6E",
    "roof_hi": "#F07A63", "roof": "#DE5E48", "roof_lo": "#B25743",
    "band": "#3B3F40",
    "sail_hi": "#E0A77E", "sail": "#C68E60", "sail_lo": "#A8764C",
    "hub": "#8A5A3C", "pink": "#E7A6C8",
    "door_hi": "#83483A", "door": "#6A3B2D", "door_line": "#4A2419",
    "frame_hi": "#F8EDD2", "frame": "#E7D8B2",
    "mull": "#A24433", "glass": "#8FB9D4", "glass_hi": "#E4F2FA",
}

# Точка обертання крил (Blender). Винесена на 4 см уперед від стіни: з y=-0.37 крила замітали
# коло, в якому лежать рамка вікна й камені фасаду, і щопівоберту проходили крізь них (рецензія 26.09).
HUB = (0.0, -0.41, 1.27)


def materials(k):
    return {
        "tower": k.mat_gradient("tower", [(0.0, "tower_lo"), (0.5, "tower"), (1.0, "tower_hi")], 0.0, 1.2, 0.3, 5.0),
        "stone": k.mat_gradient("stone", [(0.0, "stone_lo"), (0.6, "stone"), (1.0, "stone_hi")], 0.0, 1.2, 0.4, 12.0),
        "roof": k.mat_gradient("roof", [(0.0, "roof_lo"), (0.4, "roof"), (1.0, "roof_hi")], 1.15, 1.7, 0.2, 5.0),
        "band": k.mat_gradient("band", [(0.0, "band"), (1.0, "band")], 0.0, 1.0, 0.05),
        "sail": k.mat_gradient("sail", [(0.0, "sail_lo"), (0.5, "sail"), (1.0, "sail_hi")], 0.6, 2.0, 0.3, 9.0),
        "hub": k.mat_gradient("hub", [(0.0, "hub"), (1.0, "hub")], 0.0, 1.0, 0.05),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink")], 0.0, 1.0, 0.0),
        "door": k.mat_door("door"),
        "frame": k.mat_gradient("frame", [(0.0, "frame"), (1.0, "frame_hi")], 0.0, 1.2, 0.2, 8.0),
        "mull": k.mat_gradient("mull", [(0.0, "mull"), (1.0, "mull")], 0.0, 1.0, 0.05),
        "glass": k.mat_glass("glass"),
    }


def blade(name, m, k, ang):
    """Ґратчасте крило-драбинка вздовж +Z від маточини, повернуте на ang навколо осі крил."""
    from mathutils import Matrix
    L, Wd = 0.6, 0.16
    parts = []
    for dx in (-Wd / 2, Wd / 2):
        parts.append(box(name + "_rail", m["sail"], (dx, 0.0, 0.14 + L / 2), (0.028, 0.03, L)))
    n = 7 if k.DET["bev"] >= 2 else 4
    for i in range(n):
        z = 0.2 + (i + 0.5) * (L - 0.08) / n
        parts.append(box(name + "_rung", m["sail"], (0.0, 0.0, z), (Wd, 0.022, 0.022)))
    parts.append(box(name + "_arm", m["sail"], (-Wd / 2 - 0.02, 0.0, 0.1 + L / 2), (0.03, 0.035, L + 0.08)))
    rot = Matrix.Translation(HUB) @ Matrix.Rotation(ang, 4, "Y")
    for ob in parts:
        ob.matrix_world = rot @ ob.matrix_world
    return parts


def build(m, k):
    seg = max(12, k.DET["cyl"])
    # Вежа — «body»: зрізаний конус.
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=0.42, radius2=0.3, depth=1.1, location=(0, 0, 0.55))
    body = bpy.context.active_object
    body.name = "body"
    body.data.materials.append(m["tower"])
    soften(body, 0.02)

    # Камені на стінах: опуклі сірі шматочки, розкидані стало (зерно фіксоване).
    rnd = random.Random(11)
    n = 16 if k.DET["bev"] >= 3 else (10 if k.DET["bev"] == 2 else 6)
    for i in range(n):
        # більшість — на фасадному боці (його видно з дороги), решта навколо
        a = rnd.uniform(-1.1, 1.1) if i % 3 else rnd.uniform(-2.6, 2.6)
        z = rnd.uniform(0.15, 0.95)
        r = 0.42 - (0.12 * z / 1.1) + 0.005
        st = box("stone%d" % i, m["stone"], (math.sin(a) * r, -math.cos(a) * r, z),
                 (rnd.uniform(0.07, 0.11), 0.03, rnd.uniform(0.045, 0.07)), rot=(0, 0, a))
        soften(st, 0.012, min(2, k.DET["bev"]))

    # Темне кільце й червоний конічний дах.
    cyl("band", m["band"], (0, 0, 1.13), 0.33, 0.07, verts=seg)
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=0.37, radius2=0.0, depth=0.58, location=(0, 0, 1.45))
    roof = bpy.context.active_object
    roof.name = "roof"
    roof.data.materials.append(m["roof"])
    soften(roof, 0.02, min(2, k.DET["bev"]))

    # Маточина на фасадному боці даху, рожева кнопка — це вісь крил.
    cyl("hub", m["hub"], (HUB[0], HUB[1] + 0.07, HUB[2]), 0.065, 0.16, rot=(math.pi / 2, 0, 0))

    # Крила — окрема частина «sails»: 4 драбинки хрестом навскоси.
    for i in range(4):
        for ob in blade("part_sails__b%d" % i, m, k, math.radians(45 + 90 * i)):
            ob.name = "part_sails__" + ob.name
    sp = sphere("part_sails__cap", m["pink"], (HUB[0], HUB[1] - 0.03, HUB[2]), 0.035)

    fy = -0.42
    # Арочні двері внизу: кремова рамка, темні дошки.
    dw, dh = 0.26, 0.2
    door = prism("door", m["door"], arch_profile(dw, dh, k.DET["arch"]), fy - 0.01, fy + 0.03)
    arch_curve("door_frame", m["frame"], dw + 0.04, dh, fy - 0.01, 0.03)
    # Арочне вікно посередині: кремова рамка, червоні шпроси, скло.
    wz = 0.62
    wy = -(0.42 - 0.12 * wz / 1.1) - 0.005
    ww, wh = 0.15, 0.1
    prism("win_glass", m["glass"], [(x, z + wz) for x, z in arch_profile(ww, wh, k.DET["win"])], wy + 0.002, wy + 0.014)
    arch_curve("win_frame", m["frame"], ww + 0.03, wh, wy - 0.004, 0.022, wz)
    box("win_mv", m["mull"], (0, wy - 0.008, wz + (wh + ww / 2) / 2), (0.014, 0.012, wh + ww / 2))
    box("win_mh", m["mull"], (0, wy - 0.008, wz + wh * 0.6), (ww, 0.012, 0.014))
    return {"parts": {"sails": HUB}}
