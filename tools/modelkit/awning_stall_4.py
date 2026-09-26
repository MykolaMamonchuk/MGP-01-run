# -*- coding: utf-8 -*-
"""Ятка 4 за малюнком awning_stall_4.jpg (майже анфас): дерев'яний прилавок із рудих дощок
під світлішою стільницею, два темно-брунатні стовпи, зелено-білий тент-козирок із кремовою
планкою вгорі й фестонами, під ним підвісна поличка з червоними коробочками й жовтими
грушами, червоний ліхтарик і сіра «гирька» біля правого стовпа; на прилавку — гарбузики,
плетені кошики, мисочки, круглі хлібини й капуста; обабіч на землі — рожеві ящики з
кошиками овочів. Заготовки — awning_common.py. Покупець — у −Y."""
import math

import kit
from kit import box, cyl, soften
from awning_common import awning, basket, blob, crate, flat, lantern, post, side_flap

# Палітра з малюнка (k-середні по пікселях ятки, 26.09), на крок світліша за «сирі».
PAL = {
    "green_hi": "#A2CC9C", "green": "#96C290", "green_lo": "#80AC7A",
    "white_hi": "#FFFBEE", "white": "#FCF2DC", "white_lo": "#EADCC2",
    "trim": "#E8D4B6",
    "post_hi": "#8A4A2A", "post": "#7C3E22", "post_lo": "#6A321A",
    "board_hi": "#C0703C", "board": "#B36535", "board_lo": "#9A542C", "board_line": "#7C3E20",
    "top_hi": "#D89048", "top": "#CB8240", "top_lo": "#B06C34",
    "red": "#9E3A22", "red_hi": "#B84A2E",
    "pear": "#E6AC48", "gold": "#E8B040",
    "orange": "#EE8438", "orange_hi": "#F49A50",
    "wicker": "#E8B464", "wicker_lo": "#C8944C",
    "bread": "#9A5A34", "pinkmeat": "#D88A80", "cream": "#F2ECDA", "leaf": "#6C9A58",
    "crate_hi": "#E48C7A", "crate": "#D9806E", "crate_lo": "#BC6858",
    "teal": "#7EB8A8", "grey": "#A88A6E",
}


def materials(k):
    return {
        "green": k.mat_gradient("green", [(0.0, "green_lo"), (0.5, "green"), (1.0, "green_hi")], 1.1, 1.7, 0.08, 6.0),
        "white": k.mat_gradient("white", [(0.0, "white_lo"), (0.5, "white"), (1.0, "white_hi")], 1.1, 1.7, 0.08, 6.0),
        "trim": flat(k, "trim", "trim"),
        "post": k.mat_door("post", keys=("post_lo", "post", "post_hi"), planks=2.4, direction="X"),
        "board": k.mat_door("board", keys=("board_line", "board", "board_hi"), planks=3.4, direction="X"),
        "top": k.mat_gradient("top", [(0.0, "top_lo"), (0.5, "top"), (1.0, "top_hi")], 0.36, 0.46, 0.2, 9.0),
        "red": flat(k, "red", "red", "red_hi", 0.85, 1.0),
        "pear": flat(k, "pear", "pear"),
        "gold": flat(k, "gold", "gold"),
        "orange": flat(k, "orange", "orange", "orange_hi", 0.45, 0.6),
        "wicker": k.mat_door("wicker", keys=("wicker_lo", "wicker", "wicker"), planks=20.0, direction="Z"),
        "bread": flat(k, "bread", "bread"),
        "pinkmeat": flat(k, "pinkmeat", "pinkmeat"),
        "cream": flat(k, "cream", "cream"),
        "leaf": flat(k, "leaf", "leaf"),
        "crate": k.mat_door("crate", keys=("crate_lo", "crate", "crate_hi"), planks=9.0, direction="X"),
        "teal": flat(k, "teal", "teal"),
        "grey": flat(k, "grey", "grey"),
    }


def build(m, k):
    W, D, HC = 1.16, 0.46, 0.38
    ZT = HC + 0.07
    PX, PY = 0.52, 0.12
    TOP = 1.66
    # Прилавок — «body»: руді дошки, стільниця з виступом і передньою крайкою.
    body = box("body", m["board"], (0.0, 0.0, HC * 0.5), (W, D, HC))
    soften(body, 0.02)
    top = box("counter_top", m["top"], (0.0, -0.02, HC + 0.035), (W + 0.08, D + 0.08, 0.07))
    soften(top, 0.02)
    for sx in (-1, 1):
        box("leg%d" % sx, m["board"], (sx * (W * 0.5 - 0.03), -D * 0.5 - 0.01, HC * 0.5), (0.08, 0.04, HC))
    box("rail", m["board"], (0.0, -D * 0.5 - 0.015, HC * 0.3), (W - 0.1, 0.03, 0.05))

    # Два стовпи, кремова планка вгорі, тент-козирок зі смугами й фестонами, бічні клапани.
    for sx in (-1, 1):
        post("post%d" % sx, m["post"], sx * PX, PY, 0.0, TOP - 0.04, 0.12)
    tr = box("trim", m["trim"], (0.0, PY + 0.02, TOP), (1.46, 0.1, 0.06))
    soften(tr, 0.015, 2)
    path = [(PY, TOP - 0.02), (-0.14, 1.5), (-0.36, 1.24)]
    awning(m["green"], m["white"], -0.72, 0.72, path, 7, 0.04)
    for sx in (-1, 1):
        side_flap(m["green"], sx * 0.72, path, 0.1, 0.03, "flap%d" % sx)

    # Підвісна поличка ліворуч: дошка на двох шнурах, червоні коробочки, жовті груші.
    sx0, sz = -0.2, 0.9
    sh = box("hang_shelf", m["post"], (sx0, PY - 0.06, sz), (0.42, 0.16, 0.035))
    for dx in (-0.19, 0.19):
        box("hang_rope%.2f" % dx, m["post"], (sx0 + dx, PY - 0.06, (sz + 1.4) * 0.5), (0.012, 0.012, 1.4 - sz))
    for i, dx in enumerate((-0.13, 0.0, 0.13)):
        b = box("redbox%d" % i, m["red"], (sx0 + dx, PY - 0.06, sz + 0.05), (0.11, 0.1, 0.07))
        soften(b, 0.01, 2)
        blob("pear%d" % i, m["pear"], (sx0 + dx, PY - 0.06, sz + 0.14), 0.045, (1.0, 1.0, 1.5))

    # Червоний ліхтарик праворуч і сіра гирька на правому стовпі.
    box("lamp_rope", m["post"], (0.34, PY - 0.08, 1.33), (0.012, 0.012, 0.16))
    lantern("lamp", m["red"], m["gold"], m["red"], (0.34, PY - 0.08, 1.25), 1.5)
    g = box("weight", m["grey"], (PX, PY - 0.08, 1.12), (0.08, 0.05, 0.1))
    soften(g, 0.01, 2)

    # На прилавку: задній ряд — хлібина, рожева шинка, червоне яблуко; передній — гарбузики,
    # кошики, мисочки, капуста.
    blob("apple_big", m["red"], (-0.3, 0.08, ZT + 0.09), 0.09)
    blob("ham", m["pinkmeat"], (-0.12, 0.1, ZT + 0.1), 0.1, (1.0, 0.8, 1.0))
    blob("bread", m["bread"], (0.1, 0.1, ZT + 0.09), 0.11, (1.1, 0.9, 0.8))
    blob("bread_top", m["cream"], (0.1, 0.1, ZT + 0.17), 0.06, (1.2, 1.0, 0.4))
    blob("pump1", m["orange"], (-0.44, -0.1, ZT + 0.06), 0.08, (1.0, 1.0, 0.75))
    basket("bask1", m["wicker"], (-0.3, -0.1, ZT), 0.08, 0.08, ([m["gold"]], 0.04, 3))
    basket("bask2", m["wicker"], (-0.12, -0.12, ZT), 0.1, 0.12, ([m["leaf"], m["gold"]], 0.04, 3))
    blob("pump2", m["orange"], (0.04, -0.12, ZT + 0.07), 0.09, (1.0, 1.0, 0.85))
    blob("pump3", m["orange"], (0.16, -0.06, ZT + 0.06), 0.08, (1.0, 1.0, 0.8))
    b = cyl("bowl", m["orange"], (0.34, -0.06, ZT + 0.035), 0.1, 0.07, verts=max(10, k.DET["cyl"]))
    soften(b, 0.015, 2)
    for j in range(3):
        blob("bowl_f%d" % j, m["gold"], (0.3 + 0.04 * j, -0.06, ZT + 0.09), 0.04)
    blob("cabbage", m["cream"], (0.24, -0.16, ZT + 0.06), 0.065)
    blob("cab_leaf", m["leaf"], (0.26, -0.16, ZT + 0.11), 0.04, (1.2, 1.0, 0.6))
    blob("leafy", m["leaf"], (0.46, -0.1, ZT + 0.03), 0.05, (1.6, 0.8, 0.5))
    blob("tom", m["red"], (0.1, -0.2, ZT + 0.03), 0.035)

    # Обабіч на землі — рожеві ящики з плетеними кошиками овочів.
    for sx, fill in ((-1, [m["leaf"], m["red"], m["teal"], m["leaf"], m["orange"]]), (1, [m["leaf"], m["red"], m["leaf"], m["leaf"]])):
        x = sx * (W * 0.5 + 0.2)
        crate("crate%d" % sx, m["crate"], (x, -0.08, 0.0), (0.3, 0.28, 0.24), None, m["crate"])
        basket("cbask%d" % sx, m["wicker"], (x, -0.08, 0.24), 0.15, 0.08, (fill, 0.05, len(fill)))
    return {}
