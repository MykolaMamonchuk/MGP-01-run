# -*- coding: utf-8 -*-
"""Будиночок terra 1 за малюнком house_terra_1.jpg: вузька висока жовта хатка, щипець — на
боці (−X), помаранчевий черепичний дах, мансардне віконце з арочним вікном, вікно з
бірюзовими віконницями й ящиком квітів, двері в кам'яній арці з віялом над ними, сірий цоколь.
Гребінь даху — уздовж X, фасад (двері) — у −Y. Див. kit.py і build.py."""
import math

import bpy

import kit
from kit import arch_curve, arch_profile, box, prism, soften, sphere
from terra_common import prism_x

# Палітра з малюнка (k-середні по пікселях будинку, 26.09), на крок світліша за «сирі»
# кластери: малюнок уже містить студійне світло.
PAL = {
    "wall_hi": "#FCE2A0", "wall": "#F6D68E", "wall_lo": "#E2C27C",
    "roof_hi": "#FCA35E", "roof": "#F98D47", "roof_edge": "#E0703A", "roof_line": "#C4552C",
    "stone_hi": "#8E9A94", "stone": "#76827C", "stone_lo": "#5E6A65",
    "frame_hi": "#CFC2A8", "frame": "#BDAD94", "frame_lo": "#9C8F78",
    "door_hi": "#A07650", "door": "#8A6646", "door_line": "#5E4430",
    "fan": "#4A3A2A",
    "shutter_hi": "#4CD2C2", "shutter": "#35B8AA", "shutter_lo": "#23958A",
    "lintel": "#FCF8DA",
    "glass": "#7FB7C8", "glass_hi": "#D6F0F6",
    "wood": "#AE7448", "wood_lo": "#8A5A36",
    "leaf": "#4FA83A", "pink": "#F08ABB", "white": "#F7F2EE",
    "dormer": "#F8DC98",
}


def materials(k):
    return {
        "wall": k.mat_gradient("wall", [(0.0, "wall_lo"), (0.5, "wall"), (1.0, "wall_hi")], 0.3, 2.8, 0.15, 4.0),
        "roof": k.mat_roof("roof", rows_scale=11.0, seams=14.0),
        "stone": k.mat_gradient("stone", [(0.0, "stone_lo"), (0.6, "stone"), (1.0, "stone_hi")], 0.0, 0.35, 0.3, 9.0),
        "frame": k.mat_gradient("frame", [(0.0, "frame_lo"), (0.5, "frame"), (1.0, "frame_hi")], 0.0, 1.1, 0.2, 8.0),
        "door": k.mat_door("door", planks=7.0),
        "fan": k.mat_gradient("fan", [(0.0, "fan"), (1.0, "fan")], 0.0, 1.0, 0.0),
        "shutter": k.mat_door("shutter", keys=("shutter_lo", "shutter", "shutter_hi"), planks=9.0, direction="Z"),
        "lintel": k.mat_gradient("lintel", [(0.0, "lintel"), (1.0, "lintel")], 0.0, 1.0, 0.0),
        "glass": k.mat_glass("glass"),
        "wood": k.mat_gradient("wood", [(0.0, "wood_lo"), (1.0, "wood")], 1.0, 1.2, 0.2, 9.0),
        "leaf": k.mat_gradient("leaf", [(0.0, "leaf"), (1.0, "leaf")], 0.0, 1.0, 0.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink")], 0.0, 1.0, 0.0),
        "white": k.mat_gradient("white", [(0.0, "white"), (1.0, "white")], 0.0, 1.0, 0.0),
        "dormer": k.mat_gradient("dormer", [(0.0, "dormer"), (1.0, "dormer")], 0.0, 1.0, 0.0),
    }


def build(m, k):
    W, D = 1.0, 1.27          # фасад (X) вузький, хата глибока (Y)
    H, PEAK = 2.03, 2.8       # карниз і гребінь
    ZP = 0.33                 # висота цоколя
    hw, hd = W * 0.5, D * 0.5
    fy = -hd

    body = prism_x("body", m["wall"], [(-hd, 0.0), (hd, 0.0), (hd, H), (0.0, PEAK), (-hd, H)], -hw, hw)
    soften(body, 0.02)
    pl = box("plinth", m["stone"], (0.0, 0.0, ZP * 0.5), (W + 0.03, D + 0.03, ZP))
    soften(pl, 0.012, min(2, k.DET["bev"]))

    # Дах: два скати уздовж X, звис над фасадом і над щипцем.
    slope = math.atan2(PEAK - H, hd)
    t = 0.07
    run = math.hypot(hd, PEAK - H) + 0.1
    for side in (-1, 1):
        cy = side * (hd * 0.5 + 0.05)
        z_g = PEAK - abs(cy) * math.tan(slope)
        cz = z_g + (t * 0.5) / math.cos(slope)
        r = box("roof%d" % side, m["roof"], (0.0, cy, cz), (W + 0.06, run, t), rot=(-side * slope, 0.0, 0.0))
        soften(r, 0.03)

    # Мансардне віконце на передньому скаті, трохи праворуч.
    dx, dwid = 0.02, 0.46
    dy = fy + 0.03
    dz0, dzh = H - 0.02, 0.56
    dm = box("dormer", m["dormer"], (dx, dy + 0.25, dz0 + dzh * 0.5), (dwid, 0.5, dzh))
    soften(dm, 0.015, min(2, k.DET["bev"]))
    rp = 0.24
    top = dz0 + dzh
    prism("dormer_face", m["dormer"], [(dx - dwid * 0.5, top - 0.01), (dx + dwid * 0.5, top - 0.01), (dx, top + rp)],
          dy - 0.01, dy + 0.38)
    # Дашок — два тонкі скати зі звисом (суцільна призма читалась горбом).
    ang = math.atan2(rp, dwid * 0.5)
    ln = math.hypot(dwid * 0.5, rp) + 0.08
    for sgn in (-1, 1):
        cx = dx + sgn * (math.cos(ang) * ln * 0.5 - 0.02)
        cz = top + rp - math.sin(ang) * ln * 0.5 + 0.035
        r = box("dormer_roof%d" % sgn, m["roof"], (cx, dy + 0.18, cz), (ln, 0.5, 0.05), rot=(0.0, sgn * ang, 0.0))
        soften(r, 0.015, min(2, k.DET["bev"]))
    kit.window("dwin", {"glass": m["glass"], "frame": m["dormer"]}, (dx, dy - 0.012, dz0 + 0.1), "-y", 0.28, 0.22)

    # Вікно з бірюзовими віконницями, кремова перемичка, ящик із квітами.
    wz0, wh, ww = 1.26, 0.56, 0.26
    box("win_glass", m["glass"], (0.0, fy + 0.004, wz0 + wh * 0.5), (ww, 0.01, wh))
    for x in (-ww * 0.5, ww * 0.5, 0.0):
        box("win_fv", m["door"], (x, fy - 0.01, wz0 + wh * 0.5), (0.035, 0.03, wh))
    box("win_fb", m["door"], (0.0, fy - 0.01, wz0 + 0.01), (ww + 0.03, 0.03, 0.03))
    li = box("win_lintel", m["lintel"], (0.0, fy - 0.03, wz0 + wh + 0.04), (ww + 0.1, 0.06, 0.07))
    soften(li, 0.012, min(2, k.DET["bev"]))
    for sgn in (-1, 1):
        s = box("shutter%d" % sgn, m["shutter"], (sgn * (ww * 0.5 + 0.1), fy - 0.03, wz0 + wh * 0.5 - 0.02),
                (0.17, 0.035, wh + 0.04))
        soften(s, 0.008, min(2, k.DET["bev"]))
    fb = box("flower_box", m["wood"], (0.03, fy - 0.1, wz0 - 0.1), (0.46, 0.16, 0.15))
    soften(fb, 0.012, min(2, k.DET["bev"]))
    bpy.ops.object.select_all(action="DESELECT")
    for i, (x, col) in enumerate([(-0.16, "leaf"), (-0.08, "pink"), (0.0, "leaf"), (0.07, "pink"),
                                  (0.15, "leaf"), (0.21, "pink"), (-0.12, "white"), (0.11, "white")]):
        sphere("flower%d" % i, m[col], (x + 0.03, fy - 0.1 + (0.03 if i % 2 else -0.03), wz0 - 0.01 + (0.03 if col != "leaf" else 0.0)),
               0.05 if col == "leaf" else 0.04)

    # Двері в кам'яній арці: пілястри, дуга, темне віяло над полотном, дерев'яне полотно.
    dw, dh = 0.36, 0.66
    for sgn in (-1, 1):
        p = box("pilaster%d" % sgn, m["frame"], (sgn * (dw * 0.5 + 0.06), fy - 0.03, (dh + 0.02) * 0.5), (0.1, 0.07, dh + 0.02))
        soften(p, 0.01, min(2, k.DET["bev"]))
        c = box("capital%d" % sgn, m["frame"], (sgn * (dw * 0.5 + 0.07), fy - 0.045, dh + 0.02), (0.15, 0.09, 0.05))
    arch_curve("door_arch", m["frame"], dw + 0.12, dh, fy - 0.03, 0.055, 0.0)
    prism("door_fan", m["fan"], arch_profile(dw, dh, k.DET["arch"]), fy - 0.01, fy + 0.01)
    door = box("door", m["door"], (0.0, fy - 0.02, dh * 0.5), (dw, 0.03, dh))
    box("door_bar", m["door"], (0.0, fy - 0.04, dh + 0.01), (dw + 0.02, 0.03, 0.035))
    sphere("knob", m["lintel"], (0.07, fy - 0.045, dh * 0.5), 0.022)
    return {}
