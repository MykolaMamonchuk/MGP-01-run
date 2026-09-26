# -*- coding: utf-8 -*-
"""Ятка 5 за малюнком awning_stall_5.jpg: дерев'яний прилавок із брунатних дощок під світлою
стільницею, два стовпи, згори — пласка кремово-персикова дошка-дашок, під нею кремово-зелений
смугастий тент із фестонами й зеленим бічним клапаном ліворуч; поперечка з ліхтарем, пляшечкою
й дзвіночком, ліхтарики на стовпах; на прилавку — сіра вага-скринька, ящички з помаранчами,
відерця; попереду на землі — три ящики з лимонами й овочами, ліворуч — сірі бочки й червоний
мішок, праворуч — вазон із зеленню. Заготовки — awning_common.py. Покупець — у −Y."""
import math

import kit
from kit import box, cyl, soften
from awning_common import awning, basket, blob, crate, flat, lantern, post, slab

# Палітра з малюнка (k-середні по пікселях ятки, 26.09), на крок світліша за «сирі».
PAL = {
    "green_hi": "#AAD8A0", "green": "#9ED094", "green_lo": "#86B87C",
    "white_hi": "#FFFBF0", "white": "#F8EFE0", "white_lo": "#E4D6C2",
    "board_hi": "#FCDCB2", "board": "#EFC89C", "board_lo": "#DDB488",
    "post_hi": "#B87838", "post": "#8A4E26", "post_lo": "#6E3C1C",
    "wood_hi": "#B07434", "wood": "#A4682C", "wood_lo": "#8A5424", "wood_line": "#6A3E18",
    "top_hi": "#F2B270", "top": "#E6A462", "top_lo": "#CC8C4E",
    "bar": "#5A2E16",
    "grey_hi": "#B09888", "grey": "#9E8676", "grey_lo": "#7E6A5C",
    "crate_hi": "#E4AE6C", "crate": "#D8A060", "crate_lo": "#B8844C",
    "dcrate": "#9A4E1C",
    "orange": "#FFC456", "lemon": "#FFE060", "leaf": "#7AA868", "red": "#A84434",
    "barrel_hi": "#9A908A", "barrel": "#867C76", "barrel_band": "#6A625E",
    "pot": "#8A602E", "plant": "#7AB05A",
    "lamp": "#4A3A30", "lamp_glass": "#FAE890", "lamp_glass_hi": "#FFFBD0",
    "teal": "#8EB0A8",
}


def materials(k):
    return {
        "green": k.mat_gradient("green", [(0.0, "green_lo"), (0.5, "green"), (1.0, "green_hi")], 1.2, 1.6, 0.08, 6.0),
        "white": k.mat_gradient("white", [(0.0, "white_lo"), (0.5, "white"), (1.0, "white_hi")], 1.2, 1.6, 0.08, 6.0),
        "board": flat(k, "board", "board_lo", "board_hi", 1.6, 1.72),
        "post": k.mat_door("post", keys=("post_lo", "post", "post_hi"), planks=2.4, direction="X"),
        "wood": k.mat_door("wood", keys=("wood_line", "wood", "wood_hi"), planks=5.0, direction="Z"),
        "top": k.mat_gradient("top", [(0.0, "top_lo"), (0.5, "top"), (1.0, "top_hi")], 0.42, 0.52, 0.2, 9.0),
        "bar": flat(k, "bar", "bar"),
        "grey": flat(k, "grey", "grey_lo", "grey_hi", 0.5, 0.75),
        "crate": k.mat_door("crate", keys=("crate_lo", "crate", "crate_hi"), planks=10.0, direction="Z"),
        "dcrate": flat(k, "dcrate", "dcrate"),
        "orange": flat(k, "orange", "orange"),
        "lemon": flat(k, "lemon", "lemon"),
        "leaf": flat(k, "leaf", "leaf"),
        "red": flat(k, "red", "red"),
        "barrel": k.mat_door("barrel", keys=("barrel_band", "barrel", "barrel_hi"), planks=10.0, direction="Z"),
        "pot": flat(k, "pot", "pot"),
        "plant": flat(k, "plant", "plant"),
        "lamp": flat(k, "lamp", "lamp"),
        "lamp_glass": flat(k, "lamp_glass", "lamp_glass", "lamp_glass_hi", 0.9, 1.1),
        "teal": flat(k, "teal", "teal"),
    }


def build(m, k):
    W, D, HC = 1.28, 0.5, 0.44
    ZT = HC + 0.07
    PXL, PXR, PY = -0.6, 0.56, -0.1
    TOP = 1.62
    # Прилавок — «body»: брунатні дошки, світла стільниця, ліворуч — бічна поличка.
    body = box("body", m["wood"], (0.0, 0.0, HC * 0.5), (W, D, HC))
    soften(body, 0.02)
    top = box("counter_top", m["top"], (0.0, -0.02, HC + 0.035), (W + 0.08, D + 0.08, 0.07))
    soften(top, 0.02)
    side = box("side_shelf", m["top"], (-W * 0.5 - 0.1, 0.08, HC - 0.02), (0.22, 0.34, 0.05))

    # Стовпи, пласка дошка-дашок угорі, тент під нею, бічний клапан ліворуч.
    for x in (PXL, PXR):
        post("post%.1f" % x, m["post"], x, PY, 0.0, TOP - 0.03, 0.11)
    bd = box("roof_board", m["board"], (0.0, PY + 0.06, TOP + 0.03), (1.44, 0.46, 0.08))
    soften(bd, 0.02, 2)
    path = [(PY - 0.14, TOP - 0.02), (-0.4, 1.46), (-0.52, 1.28)]
    awning(m["green"], m["white"], -0.7, 0.72, path, 7, 0.04, first_b=True)
    ang = math.atan2(0.3, 0.14)
    sd = box("side_awn", m["green"], (-0.76, (PY - 0.52) * 0.5 + 0.1, TOP - 0.17), (0.3, 0.52, 0.035), rot=(0.0, -ang, 0.0))
    soften(sd, 0.015, 2)

    # Поперечка з підвісками: ліхтар, пляшечка, дзвіночок; ліхтарики на стовпах.
    box("bar", m["bar"], (-0.24, PY - 0.02, 1.2), (0.72, 0.05, 0.05))
    lantern("lamp", m["lamp"], m["lamp_glass"], m["lamp"], (-0.34, PY - 0.02, 1.18), 1.4)
    cyl("bottle", m["dcrate"], (-0.14, PY - 0.02, 1.08), 0.03, 0.12, verts=max(8, k.DET["cyl"] // 2))
    bpy_cone = __import__("bpy").ops.mesh.primitive_cone_add
    bpy_cone(vertices=max(8, k.DET["cyl"] // 2), radius1=0.05, radius2=0.015, depth=0.08, location=(-0.02, PY - 0.02, 1.1))
    ob = __import__("bpy").context.active_object
    ob.name = "bell"
    ob.data.materials.append(m["grey"])
    for x in (PXL - 0.08, PXR - 0.08):
        b = box("post_lamp%.1f" % x, m["teal"], (x, PY - 0.06, 1.2), (0.09, 0.08, 0.1))
        soften(b, 0.01, 2)

    # На прилавку: сіра вага-скринька, ящички з помаранчами, ящик нагорі, відерця.
    g = box("scale", m["grey"], (-0.3, 0.02, ZT + 0.1), (0.2, 0.14, 0.2))
    soften(g, 0.03, 2)
    box("scale_top", m["grey"], (-0.3, 0.02, ZT + 0.22), (0.12, 0.1, 0.06))
    box("scale_base", m["grey"], (-0.3, 0.0, ZT + 0.01), (0.24, 0.18, 0.03))
    for i, x in enumerate((-0.08, 0.06, 0.18)):
        crate("tray%d" % i, m["crate"], (x, -0.08, ZT), (0.13, 0.12, 0.05), ([m["orange"], m["lemon"]], 0.03, 4), slats=False)
    crate("stack1", m["crate"], (0.3, 0.12, ZT), (0.22, 0.18, 0.1), None, m["dcrate"], slats=False)
    crate("stack2", m["crate"], (0.3, 0.12, ZT + 0.1), (0.2, 0.16, 0.08), None, m["dcrate"], slats=False)
    for i, x in enumerate((0.3, 0.46)):
        basket("pail%d" % i, m["crate"], (x, -0.06, ZT), 0.07, 0.1, ([m["orange"]], 0.035, 2), band=m["top"])

    # На землі попереду — три ящики; ліворуч — сірі бочки й червоний мішок; праворуч — вазон.
    crate("fbox1", m["crate"], (-0.38, -0.46, 0.0), (0.36, 0.24, 0.15), ([m["lemon"], m["orange"], m["lemon"]], 0.05, 6), m["dcrate"])
    crate("fbox2", m["crate"], (0.04, -0.4, 0.0), (0.36, 0.24, 0.15), ([m["leaf"], m["orange"]], 0.05, 5), m["dcrate"])
    crate("fbox3", m["crate"], (0.44, -0.36, 0.0), (0.34, 0.26, 0.2), ([m["lemon"], m["leaf"]], 0.05, 4), m["crate"], slats=False)
    # ліворуч — стос сірих ящиків (на малюнку — скриньки з планками) і червона скриня позаду
    for i, z in enumerate((0.0, 0.2)):
        crate("gbox%d" % i, m["barrel"], (-0.84, -0.14, z), (0.26, 0.24, 0.19), None, None)
    rb = box("redbox", m["red"], (-0.8, 0.1, 0.2), (0.26, 0.22, 0.4))
    soften(rb, 0.02, 2)
    basket("pot", m["pot"], (0.9, -0.2, 0.0), 0.14, 0.18, band=m["barrel"])
    for i in range(5):
        a = i * 2 * math.pi / 5
        blob("plant%d" % i, m["plant"], (0.9 + 0.04 * math.cos(a), -0.2 + 0.04 * math.sin(a), 0.32 + 0.06 * (i % 2)), 0.04, (0.6, 0.6, 2.4))
    return {}
