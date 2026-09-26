# -*- coding: utf-8 -*-
"""Хатинка 3 за малюнком hut_3_test_draw.jpg: «бочкуваті» кремові стіни, солом'яний дах із
пучками, що стирчать по краю, брунатний вузол на гребені, кінці балок під дахом, теракотовий
димар зі сходинкою, кругле вікно з хрестом і сірою поличкою, жовтий козирок над арочними
дверима. Див. kit.py і build.py."""
import math
import random

import bpy

import kit
from kit import arch_profile, box, cyl, prism, soften, sphere
from hut_common import bent_bar

PAL = {
    "wall_hi": "#F8E8B8", "wall": "#EFD9A5", "wall_lo": "#E0C48E", "wall_foot": "#CFB07C",
    "straw_hi": "#E4B456", "straw": "#D8982F", "straw_edge": "#C4841E", "straw_line": "#A86A12",
    "beam": "#6E421E", "beam_lo": "#50240C",
    "knot": "#A88A62", "knot_lo": "#8A6E4A",
    "brick_hi": "#C97F45", "brick": "#AE6630",
    "door_hi": "#7A4822", "door": "#5E3416", "door_line": "#3E1E0A",
    "ring": "#8C5C36", "ring_hi": "#A8714A",
    "glass": "#3E9A8C", "glass_hi": "#BDEBE0",
    "stone_hi": "#B5B2AE", "stone": "#9C9994",
    "awning_hi": "#F8C24E", "awning": "#E9A92E",
}


def materials(k):
    return {
        "wall": k.mat_gradient("wall", [(0.0, "wall_foot"), (0.25, "wall_lo"), (0.6, "wall"), (1.0, "wall_hi")], 0.0, 1.3, 0.3, 5.0),
        "straw": k.mat_roof("straw", keys=("straw_edge", "straw", "straw_hi", "straw_line"), rows_scale=5.0, seams=0, direction="X"),
        "beam": k.mat_gradient("beam", [(0.0, "beam_lo"), (1.0, "beam")], 0.0, 1.4, 0.2, 9.0),
        "knot": k.mat_gradient("knot", [(0.0, "knot_lo"), (1.0, "knot")], 1.1, 1.4, 0.4, 12.0),
        "brick": k.mat_door("brick", keys=("brick", "brick", "brick_hi"), planks=6.0, direction="Z"),
        "door": k.mat_door("door"),
        "ring": k.mat_gradient("ring", [(0.0, "ring"), (1.0, "ring_hi")], 0.8, 1.0, 0.1, 8.0),
        "glass": k.mat_glass("glass"),
        "stone": k.mat_gradient("stone", [(0.0, "stone"), (1.0, "stone_hi")], 0.0, 1.0, 0.2, 8.0),
        "awning": k.mat_gradient("awning", [(0.0, "awning"), (1.0, "awning_hi")], 0.5, 0.7, 0.1, 6.0),
    }


def build(m, k):
    # Пропорції — з малюнка (335 пк = 1 м по низу стіни, 26.09): стіна до звису лише 0,5 м,
    # скат ~48°, кругле вікно на 0,68, козирок над дверима на 0,33–0,5. Було 0,76 / 1,28 —
    # хата виходила вищою й вужчою за малюнок, а вікно — під самим гребенем.
    W, D = 0.94, 0.86
    H, PEAK = 0.5, 1.02
    hw, hd = W * 0.5, D * 0.5
    prof = [(-hw - 0.04, 0.0), (hw + 0.04, 0.0), (hw, H), (0.0, PEAK), (-hw, H)]
    body = prism("body", m["wall"], prof, -hd, hd)
    soften(body, 0.12)          # великі заокруглення — «бочкуваті» стіни

    slope = math.atan2(PEAK - H, hw)
    t = 0.18
    run = math.hypot(hw, PEAK - H) + 0.25
    rnd = random.Random(7)
    for side in (-1, 1):
        cx = side * (hw * 0.5 + 0.09)
        z_gable = PEAK - abs(cx) * math.tan(slope)
        cz = z_gable + (t * 0.5) / math.cos(slope) - 0.02
        r = box("roof%d" % side, m["straw"], (cx, 0.0, cz), (run, D + 0.3, t), rot=(0.0, side * slope, 0.0))
        soften(r, 0.05)
        # Пучки соломи вздовж переднього краю ската: стирчать уперед і трохи донизу, неоднакові,
        # як на малюнку. Кожен лежить на верхній площині ската (тому й видно).
        n = 5 if k.DET["bev"] >= 2 else 3
        for i in range(n):
            f = (i + 0.4) / n
            ex = side * (0.04 + f * (hw + 0.16))
            ez = PEAK + t * 0.9 - abs(ex) * math.tan(slope)
            ln = 0.16 + rnd.uniform(-0.03, 0.06)
            b = box("tuft%d_%d" % (side, i), m["straw"], (ex, -hd - 0.16 - ln * 0.35, ez),
                    (0.12, ln, 0.08), rot=(rnd.uniform(0.05, 0.3), side * slope, rnd.uniform(-0.25, 0.25)))
            soften(b, 0.02, min(2, k.DET["bev"]))
    # І нижній край кожного ската — пучки донизу по всій глибині.
    for side in (-1, 1):
        n = 4 if k.DET["bev"] >= 2 else 3
        for i in range(n):
            y = -hd - 0.1 + (i + 0.5) * (D + 0.2) / n
            b = box("eave%d_%d" % (side, i), m["straw"], (side * (hw + 0.2), y, H - 0.03),
                    (0.12, 0.16, 0.06), rot=(0.0, side * (slope + 0.25), rnd.uniform(-0.2, 0.2)))
            soften(b, 0.02, min(2, k.DET["bev"]))

    # Брунатний вузол на гребені і кінці балок під дахом (два з боків і один під гребенем).
    # Вузол — на самому передньому краї гребеня, великий (на малюнку 0,28 × 0,15 м): глибше
    # його ховала солома, і з фасаду він читався цяткою.
    sphere("knot", m["knot"], (0.05, -hd - 0.06, PEAK + 0.15), 0.13, (1.15, 0.9, 0.6))
    for sgn in (-1, 1):
        cyl("beam_end%d" % sgn, m["beam"], (sgn * (hw - 0.08), -hd - 0.06, H + 0.02), 0.045, 0.16, rot=(math.pi / 2, 0, 0))
    cyl("beam_top", m["beam"], (0.0, -hd - 0.04, PEAK - 0.07), 0.045, 0.12, rot=(math.pi / 2, 0, 0))

    # Теракотовий димар ліворуч, зі сходинкою зверху.
    # На малюнку димар — найвища точка хати (1,4 м), на 0,15 вищий за вузол на гребені.
    ch = box("chimney", m["brick"], (-0.28, 0.02, 0.97), (0.23, 0.22, 0.58))
    soften(ch, 0.02)
    lip = box("chimney_lip", m["brick"], (-0.28, 0.02, 1.27), (0.3, 0.27, 0.075))
    soften(lip, 0.015)
    lip2 = box("chimney_lip2", m["brick"], (-0.28, 0.02, 1.345), (0.27, 0.24, 0.075))
    soften(lip2, 0.015)

    fy = -hd - 0.012
    # Кругле вікно: брунатне кільце, бірюзове скло з хрестом, сіра поличка під ним.
    ts, tr_ = k.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.1, minor_radius=0.03, major_segments=ts,
                                     minor_segments=tr_, location=(0.0, fy, 0.68), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = "win_ring"
    ring.data.materials.append(m["ring"])
    cyl("win_glass", m["glass"], (0.0, fy + 0.012, 0.68), 0.1, 0.012, rot=(math.pi / 2, 0, 0))
    box("win_v", m["ring"], (0.0, fy - 0.006, 0.68), (0.018, 0.02, 0.18))
    box("win_h", m["ring"], (0.0, fy - 0.006, 0.68), (0.18, 0.02, 0.018))
    sill = box("win_sill", m["stone"], (0.0, fy - 0.04, 0.55), (0.26, 0.08, 0.075))
    soften(sill, 0.015, min(2, k.DET["bev"]))

    # Жовтий вигнутий козирок над дверима — товста дуга (та сама заготовка, що й рамки арок).
    # На малюнку — пласка «підкова»: кінці на 0,36, середина на 0,45, ширина 0,46 м.
    bent_bar("awning", m["awning"], 0.4, 0.09, fy - 0.06, 0.06, 0.36)

    # Арочні двері: темні дошки, сіра ручка, сірий поріг.
    dw, dh = 0.31, 0.22
    door = prism("door", m["door"], arch_profile(dw, dh, k.DET["arch"]), fy - 0.02, fy + 0.02)
    soften(door, 0.01, min(2, k.DET["bev"]))
    sphere("knob", m["stone"], (-0.09, fy - 0.035, 0.24), 0.025)
    st = box("step", m["stone"], (0.0, fy - 0.08, 0.03), (0.4, 0.14, 0.06))
    soften(st, 0.02)

    # Бічні вікна: маленькі круглі з хрестом, по одному на бік.
    for sgn in (-1, 1):
        x = sgn * (hw + 0.02)
        bpy.ops.mesh.primitive_torus_add(major_radius=0.08, minor_radius=0.026, major_segments=ts,
                                         minor_segments=tr_, location=(x, -0.02, 0.3), rotation=(0, math.pi / 2, 0))
        rr = bpy.context.active_object
        rr.name = "side_ring%d" % sgn
        rr.data.materials.append(m["ring"])
        cyl("side_glass%d" % sgn, m["glass"], (x - sgn * 0.01, -0.02, 0.3), 0.08, 0.012, rot=(0, math.pi / 2, 0))
    return {}
