# -*- coding: utf-8 -*-
"""Хатинка 2 за малюнком hut_2_test_draw.jpg: лимонні стіни з горизонтальними швами, «пухкий»
жовтий дах із зеленою смугою під звисом, кам'яний цоколь валунами, сірий димар із рожевою
шапкою, кругле вікно в жовтій рамці, двері в сірій кам'яній арці з рожевою ручкою, маленький
ліхтарик-будиночок із рожевим дашком. Див. kit.py і build.py."""
import math

import bpy

import kit
from kit import arch_curve, arch_profile, box, cyl, prism, soften, sphere

# Палітра з малюнка (k-means по пікселях будинку, 26.09), на крок світліша за «сирі» кластери:
# малюнок уже містить студійне світло.
PAL = {
    "wall_hi": "#F7F3CC", "wall": "#EEEABB", "wall_lo": "#DEDAA6", "wall_line": "#D2CC96",
    "roof_hi": "#F8C84C", "roof": "#EFB52C", "roof_edge": "#DB9C1A", "roof_line": "#C98B12",
    "trim": "#3F6B34",
    "stone_hi": "#C2C5C1", "stone": "#A8ACA8", "stone_lo": "#858A7F",
    "chimney_hi": "#B9BCB8", "chimney_lo": "#8E938B",
    "pink": "#F2A7BC", "pink_lo": "#DE8AA2",
    "door_hi": "#B06E36", "door": "#945A2A", "door_line": "#6C3E19",
    "ring": "#E1A94B", "ring_hi": "#F0C46A",
    "glass": "#2F5A3C", "glass_hi": "#9CC7A4",
    "lamp": "#E3B254", "lamp_glass": "#FFF6E0",
}


def materials(k):
    return {
        "wall": k.mat_door("wall", keys=("wall_line", "wall", "wall_hi"), planks=1.6, direction="Z"),
        "roof": k.mat_roof("roof", rows_scale=3.0, seams=0),
        "trim": k.mat_gradient("trim", [(0.0, "trim"), (1.0, "trim")], 0.0, 1.0, 0.1),
        "stone": k.mat_gradient("stone", [(0.0, "stone_lo"), (0.6, "stone"), (1.0, "stone_hi")], 0.0, 0.2, 0.3, 7.0),
        "chimney": k.mat_gradient("chimney", [(0.0, "chimney_lo"), (1.0, "chimney_hi")], 0.9, 1.4, 0.2, 6.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink_lo"), (1.0, "pink")], 0.0, 1.5, 0.1, 8.0),
        "door": k.mat_door("door"),
        "ring": k.mat_gradient("ring", [(0.0, "ring"), (1.0, "ring_hi")], 0.9, 1.1, 0.1, 8.0),
        "glass": k.mat_glass("glass"),
        "lamp": k.mat_gradient("lamp", [(0.0, "lamp"), (1.0, "lamp")], 0.0, 1.0, 0.05),
        "lamp_glass": k.mat_gradient("lamp_glass", [(0.0, "lamp_glass"), (1.0, "lamp_glass")], 0.0, 1.0, 0.0),
    }


def build(m, k):
    W, D = 1.0, 0.86
    H, PEAK = 0.74, 1.24
    hw, hd = W * 0.5, D * 0.5
    Z0 = 0.1                   # корпус стоїть на цоколі
    prof = [(-hw, Z0), (hw, Z0), (hw, H), (0.0, PEAK), (-hw, H)]
    body = prism("body", m["wall"], prof, -hd, hd)
    soften(body, 0.03)

    # Цоколь — валуни: по два обабіч дверей спереду, довгі вздовж боків і ззаду.
    for x, sx in ((-0.3, 0.34), (0.32, 0.36)):
        v = box("plinth_f%.1f" % x, m["stone"], (x, -hd + 0.02, 0.1), (sx, 0.24, 0.2))
        soften(v, 0.08)
    for sgn in (-1, 1):
        v = box("plinth_s%d" % sgn, m["stone"], (sgn * (hw - 0.06), 0.02, 0.09), (0.2, D - 0.02, 0.18))
        soften(v, 0.07)
    v = box("plinth_b", m["stone"], (0.0, hd - 0.06, 0.09), (W - 0.1, 0.2, 0.18))
    soften(v, 0.07)

    # Дах: товсті «пухкі» скати, сильно заокруглені, спід — рівно на лінії щипця.
    slope = math.atan2(PEAK - H, hw)
    t = 0.15
    run = math.hypot(hw, PEAK - H) + 0.3
    for side in (-1, 1):
        cx = side * (hw * 0.5 + 0.08)
        z_gable = PEAK - abs(cx) * math.tan(slope)
        cz = z_gable + (t * 0.5) / math.cos(slope) - 0.02
        r = box("roof%d" % side, m["roof"], (cx, 0.0, cz), (run, D + 0.3, t), rot=(0.0, side * slope, 0.0))
        soften(r, 0.065)
        # Зелена смужка під звисом — ТОНКА, рівно вздовж лінії щипця й лише до краю стіни.
        # Перша версія була довгою широкою планкою, що вилазила на стіну й за край щипця
        # (замовник 26.09: «незрозумілі зелені вставки»).
        edge = math.hypot(hw, PEAK - H)
        box("trim%d" % side, m["trim"], (side * hw * 0.5, -hd - 0.012, (H + PEAK) * 0.5 - 0.035),
            (edge, 0.018, 0.03), rot=(0.0, side * slope, 0.0))
    # Гребеня-циліндра нема: у нього торці запікались чорним (крихітні острівці розгортки);
    # заокруглені скати перекриваються на вершині самі.

    # Димар праворуч позаду: сірий, з рожевою шапкою.
    ch = box("chimney", m["chimney"], (0.3, -0.02, 1.18), (0.2, 0.2, 0.66))
    soften(ch, 0.03)
    cp = box("chimney_cap", m["pink"], (0.3, -0.02, 1.53), (0.28, 0.28, 0.07))
    soften(cp, 0.025)

    fy = -hd - 0.012
    # Кругле вікно в щипці: товсте жовте кільце, темно-зелене скло з відблиском.
    ts, tr_ = k.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.028, major_segments=ts,
                                     minor_segments=tr_, location=(0.0, fy, 0.98), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = "win_ring"
    ring.data.materials.append(m["ring"])
    cyl("win_glass", m["glass"], (0.0, fy + 0.012, 0.98), 0.12, 0.012, rot=(math.pi / 2, 0, 0))

    # Двері в сірій кам'яній арці, рожева ручка, сірий поріг.
    dw, dh = 0.3, 0.3
    door = prism("door", m["door"], [(x, z + Z0) for x, z in arch_profile(dw, dh, k.DET["arch"])], fy - 0.02, fy + 0.02)
    soften(door, 0.01, min(2, k.DET["bev"]))
    arch_curve("door_arch", m["stone"], dw + 0.08, dh, fy - 0.02, 0.05, Z0)
    sphere("knob", m["pink"], (-0.08, fy - 0.035, Z0 + 0.2), 0.03)
    # Поріг — до низу дверей (Z0): з низьким порогом між ним і дверима лишався проміжок, і
    # полотно дверей «стікало» до землі.
    st = box("step", m["stone"], (0.0, fy - 0.08, Z0 * 0.5), (0.4, 0.14, Z0))
    soften(st, 0.02)

    # Ліхтарик-будиночок ліворуч: жовта коробочка з білим «вікном» і рожевим дашком.
    lx, lz = -0.36, 0.52
    lb = box("lamp", m["lamp"], (lx, fy - 0.02, lz), (0.1, 0.05, 0.1))
    soften(lb, 0.01, min(2, k.DET["bev"]))
    box("lamp_win", m["lamp_glass"], (lx, fy - 0.046, lz), (0.06, 0.005, 0.06))
    lr = prism("lamp_roof", m["pink"], [(lx - 0.075, lz + 0.05), (lx + 0.075, lz + 0.05), (lx, lz + 0.12)],
               fy - 0.05, fy + 0.005)

    # Бічні вікна: маленькі круглі в жовтій рамці — по одному на бік.
    for sgn in (-1, 1):
        x = sgn * (hw + 0.012)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.085, minor_radius=0.03, major_segments=ts,
                                         minor_segments=tr_, location=(x, -0.05, 0.46), rotation=(0, math.pi / 2, 0))
        rr = bpy.context.active_object
        rr.name = "side_ring%d" % sgn
        rr.data.materials.append(m["ring"])
        cyl("side_glass%d" % sgn, m["glass"], (x - sgn * 0.01, -0.05, 0.46), 0.085, 0.012, rot=(0, math.pi / 2, 0))
    return {}
