# -*- coding: utf-8 -*-
"""Ятка 2 за малюнком awning_stall_2.jpg: прилавок із сірого неправильного каменю під
світлою дерев'яною стільницею, два стовпи ззаду з колодою-балкою й кілочками, зелено-білий
смугастий тент із фестонами й бічними клапанами, ліхтарик на гачку, на прилавку — дві
капусти, рожевий батат, ящик з овочами й сірий ліхтар-скринька, ліворуч унизу — два ящики.
Заготовки — awning_common.py (родина яток), решта — kit.py. Покупець — у −Y."""
import math

import kit
from kit import box, soften
from awning_common import (awning, basket, blob, brace, crate, flat, lantern, log_beam, mat_stones, peg, post,
                           side_flap, slab)

# Палітра з малюнка (k-середні по пікселях ятки, 26.09), на крок світліша за «сирі».
PAL = {
    # тент на малюнку тьмяніший за «чистий» кластер (#8AA583 у тіні): м'ятне тло рендера
    # підсвічує зелене, тож беремо на крок темніше
    "green_hi": "#8CB474", "green": "#80A868", "green_lo": "#6E9458",
    "white_hi": "#FFFFF4", "white": "#F9F8EA", "white_lo": "#E8E4D0",
    "wood_hi": "#E8B27A", "wood": "#DFA671", "wood_lo": "#C98E5A",
    # стовпи на малюнку #986C47 і освітлені, а в рендері вони цілком у тіні тенту (сонце
    # згори), тож фарба на два кроки світліша — у тіні виходить колір малюнка
    "post_hi": "#E0AC7A", "post": "#D09A66", "post_lo": "#B88656", "post_line": "#9C7046",
    "top_hi": "#EEC48A", "top": "#E4B478", "top_lo": "#C89A60",
    "stone_hi": "#90968A", "stone": "#7E8478", "stone_lo": "#6E7468", "stone_line": "#585C50",
    "cab_hi": "#84BC5C", "cab": "#6FA24A", "cab_lo": "#5A863C",
    "pink": "#EE8C94", "red": "#E0583A", "orange": "#F78A50", "leafy": "#6E9C44",
    # відерця на малюнку в тіні прилавка: між #D29B63 (світлий бік) і #91714A (тінь)
    "crate_hi": "#D29E68", "crate": "#C08858", "crate_lo": "#9C6E46",
    "grey_hi": "#B2B6AC", "grey": "#9EA198",
    "glass": "#A6C87E", "glass_hi": "#D8E8B8",
    "yellow": "#C8C050", "flower": "#F58DA6",
}


def materials(k):
    return {
        "green": k.mat_gradient("green", [(0.0, "green_lo"), (0.5, "green"), (1.0, "green_hi")], 0.75, 1.2, 0.08, 6.0),
        "white": k.mat_gradient("white", [(0.0, "white_lo"), (0.5, "white"), (1.0, "white_hi")], 0.75, 1.2, 0.08, 6.0),
        "wood": k.mat_door("wood", keys=("wood_lo", "wood", "wood_hi"), planks=3.0, direction="Z"),
        "post": k.mat_door("post", keys=("post_line", "post", "post_hi"), planks=2.2, direction="X"),
        "top": k.mat_door("top", keys=("top_lo", "top", "top_hi"), planks=4.0, direction="X"),
        "stone": mat_stones(k, "stone", ("stone_line", "stone", "stone_hi"), 5.0),
        "cab": k.mat_gradient("cab", [(0.0, "cab_lo"), (0.6, "cab"), (1.0, "cab_hi")], 0.42, 0.62, 0.3, 14.0),
        "pink": flat(k, "pink", "pink"),
        "red": flat(k, "red", "red"),
        "orange": flat(k, "orange", "orange"),
        "leafy": flat(k, "leafy", "leafy"),
        "crate": k.mat_door("crate", keys=("crate_lo", "crate", "crate_hi"), planks=12.0, direction="X"),
        "grey": flat(k, "grey", "grey", "grey_hi", 0.4, 0.62),
        "glass": k.mat_glass("glass"),
        "yellow": flat(k, "yellow", "yellow"),
        "flower": flat(k, "flower", "flower"),
    }


def build(m, k):
    W, D, HC = 1.2, 0.46, 0.42          # прилавок (зсунутий праворуч від стовпів, як на малюнку)
    CX = 0.14
    # Стовпи ззаду, товсті, і НЕ симетрично: лівий — на лівому краї прилавка, правий —
    # усередині, під правою третиною (так на малюнку: балка коротша за тент і зсунута ліворуч).
    PXL, PXR, PY, PH = -0.54, 0.32, 0.16, 1.5
    # Прилавок — «body»: камінь, стільниця дошками з виступом.
    body = box("body", m["stone"], (CX, 0.0, HC * 0.5), (W, D, HC))
    soften(body, 0.03)
    top = box("counter_top", m["top"], (CX, -0.02, HC + 0.03), (W + 0.08, D + 0.08, 0.06))
    soften(top, 0.02)

    for i, (x, sgn) in enumerate(((PXL, 1), (PXR, -1))):
        post("post%d" % i, m["post"], x, PY, 0.0, PH, 0.17)
        peg("peg%d" % i, m["wood"], x, PY, PH + 0.06, 0.07, 0.12)
        brace("brace%d" % i, m["post"], PY, x, 1.06, x + sgn * 0.2, PH - 0.02, 0.06, axis="x")
    log_beam("beam", m["wood"], PXL - 0.16, PXR + 0.16, PY - 0.03, PH + 0.02, 0.075)

    # Тент: від балки вперед і вниз із легким «пузом», 9 смуг (крайні — зелені), фестони.
    # Переріз — дуга: майже рівний угорі й майже прямовисний спереду, як на малюнку.
    path = [(PY - 0.06, PH + 0.02), (-0.08, PH - 0.05), (-0.26, PH - 0.2), (-0.34, PH - 0.4)]
    awning(m["green"], m["white"], -0.66, 0.74, path, 9, 0.04)
    # Бічні скати тенту — короткі, від кінця балки вниз-назовні (на малюнку лівий видно
    # за краєм балки), лише в задній частині, під переднім скатом.
    # Лише лівий: праворуч на малюнку тент просто загинається донизу.
    ang = math.atan2(0.26, 0.16)
    sd = box("side_awn", m["green"], (-0.72, -0.06, PH - 0.13), (0.3, 0.28, 0.035), rot=(0.0, -ang, 0.0))
    soften(sd, 0.015, 2)

    # Ліхтарик на гачку під тентом, ліворуч від середини.
    box("lamp_chain", m["post"], (-0.18, -0.14, PH - 0.4), (0.012, 0.012, 0.2))
    lantern("lamp", m["wood"], m["glass"], m["wood"], (-0.18, -0.14, PH - 0.48), 1.7)

    # На прилавку: дві капусти, батат, ящик з овочами, сірий ліхтар-скринька.
    zt = HC + 0.06
    blob("cab1", m["cab"], (-0.26, -0.08, zt + 0.09), 0.13, (1.0, 1.0, 0.85))
    blob("cab2", m["cab"], (-0.06, 0.04, zt + 0.1), 0.13, (1.0, 1.0, 0.9))
    blob("yam", m["pink"], (0.12, -0.1, zt + 0.05), 0.09, (1.1, 0.8, 0.6))
    crate("veg", m["crate"], (0.34, -0.02, zt), (0.26, 0.2, 0.14), ([m["red"], m["orange"], m["leafy"], m["orange"]], 0.05, 8))
    g = box("stove", m["grey"], (0.6, 0.04, zt + 0.11), (0.11, 0.11, 0.22))
    soften(g, 0.01, 2)
    box("stove_cap", m["grey"], (0.6, 0.04, zt + 0.23), (0.14, 0.14, 0.025))

    # Ліворуч унизу — два відерця-ящики з клепок: із жовтим і з рожевою квіткою.
    crate("box1", m["crate"], (-0.74, 0.0, 0.0), (0.26, 0.24, 0.3), ([m["yellow"]], 0.05, 4))
    crate("box2", m["crate"], (-0.58, -0.24, 0.0), (0.28, 0.26, 0.26), None, m["crate"])
    blob("flower", m["flower"], (-0.6, -0.24, 0.29), 0.06, (1.0, 1.0, 0.6))
    return {}
