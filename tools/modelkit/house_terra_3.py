# -*- coding: utf-8 -*-
"""Будиночок terra 3 за малюнком house_terra_3.jpg: вузька висока персикова хатка, щипець —
на боці (−X) з кремовою лиштвою, пологий кораловий черепичний дах, жовтий димар на щипці,
арочне вікно в кремовій рамці з бірюзовими віконницями, дерев'яний балкончик із квітами,
двері в кремовому обрамленні з ромбиком-віконцем, цоколь із сірих блоків.
Гребінь — уздовж X, фасад (двері) — у −Y. Див. kit.py, terra_common.py і build.py."""
import math

import bpy

import kit
from kit import arch_curve, arch_profile, box, cyl, prism, soften, sphere
from terra_common import gable_roof_x, mat_blocks, prism_x

# Палітра з малюнка (k-середні по пікселях будинку, 26.09), на крок світліша за «сирі».
PAL = {
    "wall_hi": "#FCDCA8", "wall": "#F6D09A", "wall_lo": "#E8BE88",
    "roof_hi": "#FCA07A", "roof": "#F98C62", "roof_edge": "#E4724C", "roof_line": "#C85E3E",
    "trim": "#F0E8D8", "trim_lo": "#D8CFBE",
    "chim_hi": "#FCC862", "chim": "#F7B64E", "chim_lo": "#D89A3C",
    "stone_hi": "#D2C8B4", "stone": "#C2B8A4", "stone_lo": "#A89E8A", "stone_line": "#8E8676",
    "shutter_hi": "#78DADD", "shutter": "#5CCBCF", "shutter_lo": "#3FA8AE",
    "glass": "#A4CCDA", "glass_hi": "#E6F4F8",
    "wood_hi": "#B8805A", "wood": "#A06E4A", "wood_lo": "#7C5236", "wood_line": "#5A3A24",
    "door_hi": "#AE7A52", "door": "#9C6A46", "door_line": "#6E4A30",
    "dark": "#3E3C36",
    "leaf": "#62B048", "leaf_lo": "#4C9036", "pink": "#F48CC4",
}


def materials(k):
    return {
        "wall": k.mat_gradient("wall", [(0.0, "wall_lo"), (0.5, "wall"), (1.0, "wall_hi")], 0.5, 2.4, 0.15, 4.0),
        "roof": k.mat_roof("roof", rows_scale=10.0, seams=12.0),
        "trim": k.mat_gradient("trim", [(0.0, "trim_lo"), (1.0, "trim")], 0.0, 2.6, 0.1, 6.0),
        "chim": k.mat_gradient("chim", [(0.0, "chim_lo"), (0.5, "chim"), (1.0, "chim_hi")], 2.2, 3.0, 0.2, 6.0),
        # Цоколь блоками: шви — ряди «дошок» по висоті, як у hut_2
        "stone": mat_blocks("stone", ("stone_line", "stone", "stone_hi")),
        "shutter": k.mat_door("shutter", keys=("shutter_lo", "shutter", "shutter_hi"), planks=10.0, direction="Z"),
        "glass": k.mat_glass("glass"),
        "wood": k.mat_gradient("wood", [(0.0, "wood_lo"), (0.5, "wood"), (1.0, "wood_hi")], 0.95, 1.25, 0.2, 9.0),
        "door": k.mat_door("door", planks=4.0),
        "dark": k.mat_gradient("dark", [(0.0, "dark"), (1.0, "dark")], 0.0, 1.0, 0.0),
        "leaf": k.mat_gradient("leaf", [(0.0, "leaf_lo"), (1.0, "leaf")], 1.2, 1.4, 0.3, 12.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink")], 0.0, 1.0, 0.0),
    }


def build(m, k):
    W, D = 1.0, 1.34
    H, PEAK = 2.05, 2.45
    ZP = 0.57
    hw, hd = W * 0.5, D * 0.5
    fy = -hd
    bev2 = min(2, k.DET["bev"])

    body = prism_x("body", m["wall"], [(-hd, 0.0), (hd, 0.0), (hd, H), (0.0, PEAK), (-hd, H)], -hw, hw)
    soften(body, 0.02)
    pl = box("plinth", m["stone"], (0.0, 0.0, ZP * 0.5), (W + 0.04, D + 0.04, ZP))
    soften(pl, 0.015, bev2)
    cap = box("plinth_cap", m["stone"], (0.0, 0.0, ZP), (W + 0.06, D + 0.06, 0.04))

    # Кремова лиштва: по краю щипця (−X, +X) і карнизом під звисом фасаду й тилу.
    slope = math.atan2(PEAK - H, hd)
    ln = math.hypot(hd, PEAK - H) + 0.08
    for sx in (-1, 1):
        for sy in (-1, 1):
            cy = sy * math.cos(slope) * ln * 0.5
            cz = PEAK - math.sin(slope) * ln * 0.5 + 0.01
            box("rake%d%d" % (sx, sy), m["trim"], (sx * (hw + 0.035), cy, cz), (0.05, ln, 0.08), rot=(-sy * slope, 0.0, 0.0))
    for sy in (-1, 1):
        box("fascia%d" % sy, m["trim"], (0.0, sy * (hd + 0.02), H - 0.02), (W + 0.1, 0.05, 0.07))
    gable_roof_x(m["roof"], W, D, H + 0.035, PEAK + 0.035, 0.08, 0.16, 0.1, 0.03)
    # Гребінь — валик уздовж X: без нього між плитами на вершині видно щілину (чорна цятка).
    rg = cyl("ridge", m["roof"], (0.0, 0.0, PEAK + 0.09), 0.055, W + 0.2, rot=(0, math.pi / 2, 0), verts=max(6, k.DET["cyl"] // 2))

    # Жовтий димар на лівому щипці, над гребенем, з шапкою.
    cx, cy = -hw + 0.17, 0.1   # бічна грань не в площині щипця: інакше мерехтіння й чорна пляма AO
    ch = box("chimney", m["chim"], (cx, cy, PEAK + 0.05), (0.24, 0.24, 0.6))
    soften(ch, 0.02, bev2)
    cc = box("chimney_cap", m["chim"], (cx, cy, PEAK + 0.37), (0.32, 0.3, 0.06))
    soften(cc, 0.02, bev2)
    # шапочка — півциліндр уздовж X, як дашок на малюнку
    top = cyl("chimney_top", m["chim"], (cx, cy, PEAK + 0.4), 0.12, 0.26, rot=(0, math.pi / 2, 0), verts=max(8, k.DET["cyl"] // 2))
    top.scale = (1.0, 1.0, 1.0)

    # Арочне вікно: кремова арка-обрамлення, скло, хрест рамок, бірюзові віконниці.
    wz0, ww, wside = 1.36, 0.24, 0.34
    prism("win_sur", m["trim"], [(x, z + wz0 - 0.03) for x, z in arch_profile(ww + 0.12, wside, k.DET["arch"])], fy - 0.02, fy + 0.01)
    prism("win_glass", m["glass"], [(x, z + wz0) for x, z in arch_profile(ww, wside, k.DET["arch"])], fy - 0.03, fy - 0.015)
    box("win_mv", m["wood"], (0.0, fy - 0.04, wz0 + (wside + ww * 0.5) * 0.5), (0.025, 0.02, wside + ww * 0.5))
    box("win_mh", m["wood"], (0.0, fy - 0.04, wz0 + wside * 0.72), (ww, 0.02, 0.025))
    arch_curve("win_fr", m["wood"], ww, wside, fy - 0.035, 0.014, wz0)
    for sgn in (-1, 1):
        s = box("shutter%d" % sgn, m["shutter"], (sgn * (ww * 0.5 + 0.14), fy - 0.03, wz0 + 0.24), (0.14, 0.035, 0.48))
        soften(s, 0.008, bev2)

    # Балкончик: підлога, перила зі стовпчиками, два кронштейни, квіти поверх.
    bw, bd, bz = 0.72, 0.2, 1.0
    fl = box("balc_floor", m["wood"], (0.0, fy - bd * 0.5, bz), (bw, bd, 0.05))
    soften(fl, 0.01, bev2)
    box("balc_rail", m["wood"], (0.0, fy - bd + 0.02, bz + 0.2), (bw, 0.05, 0.05))
    box("balc_bottom", m["wood"], (0.0, fy - bd + 0.02, bz + 0.05), (bw, 0.05, 0.05))
    n = 6
    for i in range(n + 1):
        x = -bw * 0.5 + 0.025 + (bw - 0.05) * i / n
        box("balc_post%d" % i, m["wood"], (x, fy - bd + 0.02, bz + 0.12), (0.04, 0.04, 0.16))
    for sgn in (-1, 1):
        box("balc_side%d" % sgn, m["wood"], (sgn * (bw * 0.5 - 0.02), fy - bd * 0.5, bz + 0.2), (0.05, bd, 0.05))
        br = box("bracket%d" % sgn, m["wood"], (sgn * 0.26, fy - 0.08, bz - 0.08), (0.08, 0.15, 0.14))
        soften(br, 0.03, bev2)
    for i in range(9):
        x = -0.3 + 0.075 * i
        sphere("leaf%d" % i, m["leaf"], (x, fy - bd * 0.5, bz + 0.27 + 0.02 * (i % 2)), 0.08)
    for i, x in enumerate((-0.27, -0.14, -0.02, 0.1, 0.2, 0.3)):
        sphere("pink%d" % i, m["pink"], (x, fy - bd * 0.55 - 0.04 * (i % 2), bz + 0.34 + 0.03 * ((i + 1) % 2)), 0.06)

    # Двері: кремове обрамлення (стовпчики + перемичка), полотно, ромб-віконце, ручка.
    dw, dh = 0.3, 0.76
    for sgn in (-1, 1):
        p = box("dframe%d" % sgn, m["trim"], (sgn * (dw * 0.5 + 0.055), fy - 0.03, (dh + 0.06) * 0.5), (0.11, 0.07, dh + 0.06))
        soften(p, 0.012, bev2)
    t = box("dframe_top", m["trim"], (0.0, fy - 0.03, dh + 0.06), (dw + 0.22, 0.07, 0.1))
    soften(t, 0.015, bev2)
    box("door", m["door"], (0.0, fy - 0.015, dh * 0.5), (dw, 0.03, dh))
    box("door_win", m["dark"], (0.0, fy - 0.035, dh - 0.12), (0.09, 0.012, 0.09), rot=(0.0, math.pi / 4, 0.0))
    box("door_winfr", m["wood"], (0.0, fy - 0.032, dh - 0.12), (0.12, 0.01, 0.12), rot=(0.0, math.pi / 4, 0.0))
    sphere("knob", m["wood"], (-0.1, fy - 0.045, dh * 0.45), 0.02)
    return {}
