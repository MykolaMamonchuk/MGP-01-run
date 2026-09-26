# -*- coding: utf-8 -*-
"""Ятка 1 за малюнком awning_stall_1.jpg: чотири помаранчеві стовпи (передні — перед
прилавком, задні — під колодою-балкою з кілочками), біло-зелений смугастий тент із фестонами
й бічним скатом ліворуч, прилавок із сірувато-брунатного каменю блоками під помаранчевою
стільницею-полицею, на ній баклажани, жовті й помаранчеві овочі, перець, мисочки з
фіолетовим; ліворуч позаду — руде відерце на ніжках, праворуч попереду — кошик із фруктами.
Заготовки — awning_common.py (родина яток). Покупець — у −Y."""
import math

import kit
from kit import box, cyl, soften
from awning_common import awning, basket, blob, flat, log_beam, peg, post, tri_panel
from terra_common import mat_blocks

# Палітра з малюнка (k-середні по пікселях ятки, 26.09), на крок світліша за «сирі».
PAL = {
    "green_hi": "#D4E49E", "green": "#C6DC8E", "green_lo": "#B0C87C",
    "white_hi": "#FFFEF0", "white": "#FEF9E6", "white_lo": "#F2E6CC",
    "beam_hi": "#FDC87A", "beam": "#EFAE62", "beam_lo": "#C8803A",
    "post_hi": "#D08448", "post": "#C4763A", "post_lo": "#A05E2C",
    "shelf_hi": "#E49A52", "shelf": "#D88A44", "shelf_lo": "#B87034",
    "stone_hi": "#A09070", "stone": "#8E7C5E", "stone_lo": "#7A6A50", "stone_line": "#5C4E3A",
    "bucket_hi": "#B8603E", "bucket": "#A45438", "bucket_lo": "#843A28",
    "stand": "#86786A",
    "basket_hi": "#D29A66", "basket": "#BF8656", "basket_lo": "#9E6A40",
    "purple": "#6A3C86", "purple_lo": "#523068",
    "yellow": "#E8B028", "orange": "#EE8A2E", "pepper": "#4E8A34",
    "peach": "#F2A87A", "peach2": "#F6C27C",
    "bowl_hi": "#B8B2A6", "bowl": "#A09A8E",
    "nut": "#E2C28E",
}


def materials(k):
    return {
        "green": k.mat_gradient("green", [(0.0, "green_lo"), (0.5, "green"), (1.0, "green_hi")], 0.9, 1.35, 0.08, 6.0),
        "white": k.mat_gradient("white", [(0.0, "white_lo"), (0.5, "white"), (1.0, "white_hi")], 0.9, 1.35, 0.08, 6.0),
        "beam": k.mat_gradient("beam", [(0.0, "beam_lo"), (0.5, "beam"), (1.0, "beam_hi")], 1.26, 1.4, 0.1, 6.0),
        "post": k.mat_door("post", keys=("post_lo", "post", "post_hi"), planks=2.2, direction="X"),
        "shelf": k.mat_gradient("shelf", [(0.0, "shelf_lo"), (0.5, "shelf"), (1.0, "shelf_hi")], 0.34, 0.46, 0.2, 9.0),
        "stone": mat_blocks("stone", ("stone_line", "stone", "stone_hi"), 0.4, 0.17, 0.014),
        "bucket": k.mat_door("bucket", keys=("bucket_lo", "bucket", "bucket_hi"), planks=10.0, direction="X"),
        "stand": flat(k, "stand", "stand"),
        "basket": k.mat_door("basket", keys=("basket_lo", "basket", "basket_hi"), planks=14.0, direction="Z"),
        "purple": flat(k, "purple", "purple_lo", "purple", 0.4, 0.6),
        "yellow": flat(k, "yellow", "yellow"),
        "orange": flat(k, "orange", "orange"),
        "pepper": flat(k, "pepper", "pepper"),
        "peach": flat(k, "peach", "peach"),
        "peach2": flat(k, "peach2", "peach2"),
        "bowl": flat(k, "bowl", "bowl", "bowl_hi", 0.44, 0.52),
        "nut": flat(k, "nut", "nut"),
    }


def build(m, k):
    W, D, HC = 1.2, 0.5, 0.34
    FY, BY = -0.42, 0.2                # передні й задні стовпи
    PH_F, PH_B = 1.0, 1.32
    # Прилавок — «body»: кам'яна кладка блоками, над нею помаранчева стільниця-полиця.
    body = box("body", m["stone"], (0.0, 0.0, HC * 0.5), (W, D, HC))
    soften(body, 0.02)
    base = box("base", m["stone"], (0.0, 0.0, 0.03), (W + 0.06, D + 0.06, 0.06))
    soften(base, 0.015, 2)
    top = box("shelf", m["shelf"], (0.0, -0.02, HC + 0.04), (W + 0.1, D + 0.1, 0.08))
    soften(top, 0.02)
    # передня дошка полиці висока — на малюнку це широка помаранчева смуга
    lip = box("shelf_lip", m["shelf"], (0.0, -D * 0.5 - 0.07, HC + 0.03), (W + 0.12, 0.05, 0.16))
    soften(lip, 0.015, 2)

    for sx in (-1, 1):
        post("post_f%d" % sx, m["post"], sx * 0.52, FY, 0.0, PH_F, 0.1)
        post("post_b%d" % sx, m["post"], sx * 0.56, BY, 0.0, PH_B, 0.1)
        peg("peg%d" % sx, m["beam"], sx * 0.56, BY, PH_B + 0.04, 0.045, 0.1)
    log_beam("beam", m["beam"], -0.8, 0.74, BY - 0.01, PH_B + 0.02, 0.07)

    # Тент: від балки вперед і вниз, 8 смуг (ліва — біла), фестони; бічний скат ліворуч.
    # Тент кріпиться під балкою спереду і круто йде вниз до передніх стовпів.
    path = [(BY - 0.08, PH_B - 0.03), (-0.2, 1.13), (-0.47, 0.99)]
    awning(m["green"], m["white"], -0.64, 0.68, path, 8, 0.04, first_b=True)
    # Бічний скат-«вальма» ліворуч: трикутник від кінця балки до переднього кута й назовні.
    # Бічний скат ліворуч — похила плита на всю глибину тенту, униз-назовні (на малюнку його
    # край із фестонами сягає далеко ліворуч за балку).
    ang = math.atan2(0.3, 0.3)
    sd = box("side_awn", m["green"], (-0.79, (BY - 0.47) * 0.5, PH_B - 0.18), (0.42, BY + 0.47, 0.035), rot=(0.0, -ang, 0.0))
    soften(sd, 0.015, 2)

    # На полиці: баклажани, жовта й помаранчева «тиква», перець, мисочки з фіолетовим і горіхами.
    zt = HC + 0.08
    blob("egg1", m["purple"], (-0.5, -0.05, zt + 0.05), 0.06, (1.4, 0.8, 0.8))
    blob("egg2", m["purple"], (-0.44, -0.14, zt + 0.05), 0.06, (1.4, 0.8, 0.8))
    blob("sq1", m["orange"], (-0.28, -0.12, zt + 0.06), 0.07, (1.0, 1.0, 0.8))
    blob("sq2", m["yellow"], (-0.18, -0.16, zt + 0.06), 0.07, (1.0, 1.0, 0.85))
    blob("sq3", m["orange"], (-0.08, -0.1, zt + 0.06), 0.07, (1.0, 1.0, 0.8))
    blob("pep", m["pepper"], (-0.2, -0.02, zt + 0.08), 0.08, (1.0, 1.0, 0.9))
    blob("sq4", m["yellow"], (-0.34, 0.0, zt + 0.06), 0.06)
    for i, (x, y, fill) in enumerate(((0.06, -0.08, "nut"), (0.28, -0.06, "purple"), (0.46, 0.02, "purple"))):
        b = cyl("bowl%d" % i, m["bowl"], (x, y, zt + 0.03), 0.1, 0.06, verts=max(10, k.DET["cyl"]))
        soften(b, 0.015, 2)
        for j in range(4):
            a = j * math.pi / 2 + 0.4
            blob("bowl%d_%d" % (i, j), m[fill], (x + 0.045 * math.cos(a), y + 0.045 * math.sin(a), zt + 0.07), 0.04)
        blob("bowl%d_c" % i, m[fill], (x, y, zt + 0.09), 0.04)

    # Ліворуч позаду — руде відерце на ніжках.
    bx, byy = -0.86, 0.08
    for sx in (-1, 1):
        post("stand%d" % sx, m["stand"], bx + sx * 0.08, byy, 0.0, 0.3, 0.06, 0.01)
    box("stand_top", m["stand"], (bx, byy, 0.3), (0.3, 0.24, 0.04))
    basket("bucket", m["bucket"], (bx, byy, 0.32), 0.21, 0.32, band=m["bucket"])
    cyl("bucket_in", m["bucket"], (bx, byy, 0.63), 0.19, 0.01, verts=max(10, k.DET["cyl"]))

    # Праворуч попереду — плетений кошик із фруктами.
    basket("fruit_basket", m["basket"], (0.36, -0.5, 0.0), 0.17, 0.17,
           ([m["peach"], m["peach2"], m["orange"], m["peach"], m["yellow"], m["peach"], m["peach2"]], 0.055, 7))
    return {}
