# -*- coding: utf-8 -*-
"""Ятка 3 за малюнком awning_stall_3.jpg: будочка з двосхилим зелено-білим смугастим дахом
(фестони на передньому схилі, щипець праворуч — у брусі з двома трикутними віконцями й
круглими торцями ригеля), чотири дерев'яні стовпи, задня стінка з полицями (огірок,
помідори, баклажан), прилавок із сірого каменю під помаранчевою стільницею; на ній кошики з
бананами й капустою, гарбузики, мисочки з рожевим і кокосом, помідори; ліхтарик під
ригелем, табличка на задньому стовпі; ліворуч — зелений глечик-гарбуз, праворуч — лавка.
Заготовки — awning_common.py. Покупець — у −Y, щипець — на +X."""
import math

import kit
from kit import box, cyl, prism, soften
from awning_common import awning, basket, blob, flat, lantern, mat_stones, post, slab, tri_panel

# Палітра з малюнка (k-середні по пікселях ятки, 26.09), на крок світліша за «сирі».
PAL = {
    "green_hi": "#9AD092", "green": "#8CC684", "green_lo": "#76B06E",
    "white_hi": "#FFFFF0", "white": "#F8F9E2", "white_lo": "#E6E8CC",
    "wood_hi": "#EAB072", "wood": "#E2A366", "wood_lo": "#C08650",
    "post_hi": "#AA7E4E", "post": "#9A7044", "post_lo": "#7C5836",
    "dark": "#5A3E26", "dark_lo": "#46301C",
    "stone_hi": "#8A9282", "stone": "#76806C", "stone_lo": "#646E5C", "stone_line": "#4E5646",
    "glass": "#86C4B0", "glass_hi": "#CBEBDF",
    "yellow": "#F2D24A", "yellow_lo": "#D4B03A", "tub": "#D8B650", "tub_lo": "#B8983C",
    "leafy": "#8CBC58", "leafy_lo": "#6E9C44", "cuc": "#56702E",
    "tomato": "#D65642", "pink": "#E0909A", "purple": "#7C4A86", "coco": "#86583A",
    "bowl": "#A87448", "sign": "#F4A080", "sign_lo": "#D8886A",
    "lamp_glass": "#FFF6A0", "lamp_glass_hi": "#FFFFE0", "lamp": "#8A5E3A",
    "gourd": "#5E9454", "gourd_lo": "#4A7C44",
}


def materials(k):
    return {
        "green": k.mat_gradient("green", [(0.0, "green_lo"), (0.5, "green"), (1.0, "green_hi")], 1.2, 1.85, 0.08, 6.0),
        "white": k.mat_gradient("white", [(0.0, "white_lo"), (0.5, "white"), (1.0, "white_hi")], 1.2, 1.85, 0.08, 6.0),
        "wood": k.mat_door("wood", keys=("wood_lo", "wood", "wood_hi"), planks=5.0, direction="X"),
        "ctop": k.mat_gradient("ctop", [(0.0, "wood_lo"), (0.5, "wood"), (1.0, "wood_hi")], 0.5, 0.6, 0.2, 9.0),
        "post": k.mat_door("post", keys=("post_lo", "post", "post_hi"), planks=2.6, direction="X"),
        "dark": flat(k, "dark", "dark_lo", "dark", 0.5, 1.4),
        "stone": mat_stones(k, "stone", ("stone_line", "stone", "stone_hi"), 4.0),
        "glass": k.mat_glass("glass"),
        "yellow": flat(k, "yellow", "yellow_lo", "yellow", 0.6, 0.8),
        "tub": k.mat_door("tub", keys=("tub_lo", "tub", "yellow"), planks=16.0, direction="X"),
        "leafy": flat(k, "leafy", "leafy_lo", "leafy", 0.6, 0.9),
        "cuc": flat(k, "cuc", "cuc"),
        "tomato": flat(k, "tomato", "tomato"),
        "pink": flat(k, "pink", "pink"),
        "purple": flat(k, "purple", "purple"),
        "coco": flat(k, "coco", "coco"),
        "bowl": flat(k, "bowl", "bowl"),
        "sign": flat(k, "sign", "sign_lo", "sign", 0.9, 1.1),
        "lamp_glass": flat(k, "lamp_glass", "lamp_glass", "lamp_glass_hi", 0.9, 1.1),
        "lamp": flat(k, "lamp", "lamp"),
        "gourd": flat(k, "gourd", "gourd_lo", "gourd", 0.0, 0.4),
    }


def build(m, k):
    W, D, HC = 1.12, 1.0, 0.5          # прилавок-будочка майже квадратна
    ZT = HC + 0.08                      # верх стільниці
    EAVE, RIDGE = 1.42, 1.78            # карниз і гребінь
    hw, hd = W * 0.5, D * 0.5
    # Кам'яна основа — «body», стільниця з виступом.
    body = box("body", m["stone"], (0.0, 0.0, HC * 0.5), (W, D, HC))
    soften(body, 0.03)
    top = box("counter_top", m["ctop"], (0.0, -0.03, HC + 0.04), (W + 0.1, D + 0.08, 0.08))
    soften(top, 0.02)

    # Чотири стовпи по кутах, задня стінка з двома полицями (темне нутро будочки).
    px, py = hw - 0.07, hd - 0.07
    for sx in (-1, 1):
        for sy in (-1, 1):
            post("post%d%d" % (sx, sy), m["post"], sx * px, sy * py, ZT, EAVE, 0.11)
    # Стінка з полицями — на лівому боці (−X): на малюнку крізь фасад видно полиці, а крізь
    # щипець (+X) — тло, тож задньої стінки нема.
    box("back_wall", m["dark"], (-px - 0.02, 0.0, (ZT + EAVE) * 0.5), (0.03, D - 0.2, EAVE - ZT))
    for z in (0.95, 1.2):
        sh = box("shelf%.2f" % z, m["post"], (-px + 0.08, 0.0, z), (0.16, D - 0.2, 0.03))
    sx_ = -px + 0.08
    blob("cucumber", m["cuc"], (sx_, -0.12, 1.02), 0.06, (0.8, 3.0, 0.8))
    for i, y in enumerate((0.1, 0.2, 0.3)):
        blob("tom_b%d" % i, m["tomato"], (sx_, y, 1.005), 0.045)
    blob("eggpl", m["purple"], (sx_, -0.1, 1.26), 0.06, (0.9, 1.2, 0.9))
    blob("tom_b3", m["tomato"], (sx_, 0.1, 1.255), 0.045)

    # Ригелі по верху стовпів (спереду, ззаду, на боках) і щипець +X: брус, бабка, віконця.
    for sy in (-1, 1):
        box("plate%d" % sy, m["post"], (0.0, sy * py, EAVE), (W, 0.1, 0.1))
    for sx in (-1, 1):
        b = box("tie%d" % sx, m["post"], (sx * px, 0.0, EAVE), (0.1, D + 0.12, 0.1))
        soften(b, 0.02, 2)
        for sy in (-1, 1):
            cyl("tie_end%d%d" % (sx, sy), m["wood"], (sx * px, sy * (hd + 0.07), EAVE), 0.06, 0.04, rot=(math.pi / 2, 0, 0),
                verts=max(8, k.DET["cyl"] // 2))
    gx = px + 0.02
    # трикутник щипця (дошки) і дві трикутні шибки з бабкою посередині
    tri_panel("gable", m["post"], (gx, -py, EAVE + 0.05), (gx, py, EAVE + 0.05), (gx, 0.0, RIDGE - 0.03), 0.03)
    tri_panel("gable_b", m["post"], (-gx, -py, EAVE + 0.05), (-gx, py, EAVE + 0.05), (-gx, 0.0, RIDGE - 0.03), 0.03)
    for sy in (-1, 1):
        tri_panel("gwin%d" % sy, m["glass"], (gx + 0.02, sy * 0.06, EAVE + 0.11), (gx + 0.02, sy * 0.3, EAVE + 0.11),
                  (gx + 0.02, sy * 0.06, EAVE + 0.34), 0.01)
    box("king", m["post"], (gx + 0.025, 0.0, (EAVE + RIDGE) * 0.5), (0.02, 0.07, RIDGE - EAVE - 0.05))

    # Дах: два схили зі смуг уздовж X (гребінь уздовж X), фестони лише спереду; звис на боках.
    ov = 0.3
    path_f = [(0.0, RIDGE), (-hd - 0.02, EAVE + 0.06), (-hd - 0.2, EAVE - 0.1)]
    path_b = [(0.0, RIDGE), (hd + 0.02, EAVE + 0.06), (hd + 0.14, EAVE - 0.04)]
    awning(m["green"], m["white"], -hw - ov, hw + 0.16, path_f, 7, 0.045, first_b=True)
    for j in range(len(path_b) - 1):
        s = slab("roof_b%d" % j, m["green"], -hw - ov, hw + 0.16, path_b[j], path_b[j + 1], 0.045)
        soften(s, 0.012, 2)
    # зелена крайка по краю щипця
    for sy, (p0, p1) in ((-1, (path_f[0], path_f[1])), (1, (path_b[0], path_b[1]))):
        s = slab("rake%d" % sy, m["green"], hw + 0.14, hw + 0.2, (p0[0], p0[1] + 0.02), (p1[0], p1[1] + 0.02), 0.09)
        soften(s, 0.015, 2)

    # Ліхтарик під ригелем щипця, табличка на задньому правому стовпі (без напису).
    lantern("lamp", m["lamp"], m["lamp_glass"], m["lamp"], (px, 0.05, EAVE - 0.05), 1.3)
    sg = box("sign", m["sign"], (px + 0.08, py - 0.02, 1.1), (0.03, 0.2, 0.26))
    soften(sg, 0.012, 2)

    # На стільниці: жовті відерця з бананами й капустою, гарбузики, мисочки, кокос, помідори.
    basket("tub1", m["tub"], (-0.4, -0.3, ZT), 0.15, 0.17, ([m["yellow"]], 0.065, 4))
    basket("tub2", m["tub"], (-0.14, -0.34, ZT), 0.16, 0.18)
    blob("cabbage", m["leafy"], (-0.14, -0.34, ZT + 0.25), 0.15, (1.0, 1.0, 0.85))
    blob("gourd1", m["leafy"], (0.04, -0.38, ZT + 0.1), 0.08, (0.9, 0.9, 1.3))
    blob("squash", m["leafy"], (0.14, -0.42, ZT + 0.07), 0.1, (1.0, 1.0, 0.7))
    blob("banana", m["yellow"], (0.14, -0.42, ZT + 0.16), 0.05, (1.6, 0.8, 0.6))
    for i, (x, y, fill) in enumerate(((0.28, -0.1, "pink"), (0.36, 0.1, "coco"))):
        b = cyl("bowl%d" % i, m["bowl"], (x, y, ZT + 0.05), 0.13, 0.1, verts=max(10, k.DET["cyl"]))
        soften(b, 0.02, 2)
    for j, c in enumerate(("pink", "purple", "pink")):
        blob("bowl0_%d" % j, m[c], (0.25 + 0.05 * j, -0.1 + 0.02 * (j % 2), ZT + 0.12), 0.045)
    blob("coconut", m["coco"], (0.36, 0.1, ZT + 0.17), 0.08)
    blob("tom1", m["tomato"], (0.5, -0.16, ZT + 0.04), 0.045)
    blob("tom2", m["tomato"], (0.52, -0.06, ZT + 0.04), 0.04)

    # Ліворуч на землі — зелений глечик-гарбуз із жовтим хвостиком; праворуч — лавка.
    blob("big_gourd", m["gourd"], (-0.78, -0.36, 0.16), 0.17, (1.0, 1.0, 1.0))
    blob("big_gourd_top", m["gourd"], (-0.78, -0.36, 0.34), 0.08, (1.0, 1.0, 1.2))
    blob("big_gourd_stem", m["yellow"], (-0.78, -0.36, 0.45), 0.06, (1.4, 1.4, 0.6))
    bench = box("bench", m["wood"], (0.84, 0.0, 0.24), (0.2, 0.62, 0.06))
    soften(bench, 0.015, 2)
    for sy in (-1, 1):
        box("bench_leg%d" % sy, m["wood"], (0.84, sy * 0.24, 0.1), (0.16, 0.06, 0.2))
    return {}
