# -*- coding: utf-8 -*-
"""Криниця 3 за малюнком well_3.jpg: зруб із теплих сірих брил двома рядами під вінцем із
великих плит, блакитна вода, два брунатні стовпи ближче до заднього краю, тонка поперечка з
гачком посередині, помаранчеве відро на мотузці, двосхилий дах із широких помаранчевих
дощок у чотири ряди внахльост на верхньому брусі.

Збирач — well_common.build_well; тут палітра й розміри (одиниці Blender, перед — −Y)."""
import kit
from well_common import build_well

# Палітра — k-середні по пікселях криниці (26.09) і точкові проби; на крок світліша за «сирі».
PAL = {
    "stone_hi": "#A89A90", "stone": "#93857A", "stone_lo": "#7A6C62", "core": "#5A4E48",
    "cap_hi": "#C4B4AA", "cap": "#AE9F95", "cap_lo": "#958780",
    "water": "#8EBBD0", "water_hi": "#B0D4E4",
    "wood_hi": "#9A5A3E", "wood": "#8A4E34", "wood_lo": "#6E3C26", "wood2": "#6E3A24",
    "roof_hi": "#F2A472", "roof": "#E4935F", "roof_lo": "#C87A4D", "roof_line": "#A05B3D",
    "rope": "#8A5A3A", "bucket": "#EA8C4E", "bucket_hi": "#F29C5E", "hoop": "#C8663A",
}

SPEC = dict(
    ring=dict(r_out=0.6, r_in=0.38, h=0.6, rows=2, per=8, cap_h=0.15, cap_per=8, cap_out=0.03, depth=0.1, seed=6,
              bevel=0.03, jitter=0.3, gap=0.014, arc_segs=2),
    water_z=0.5,
    posts=dict(x=0.335, y=0.2, w=0.17, top=1.44),
    plates=[(0.0, 1.45, 0.52, 0.12, 0.07)],
    crossbar=dict(z=1.27, r=0.024, half=0.33, style="log", hook=0.04),
    bucket=dict(z_top=1.03, h=0.22, r_top=0.11, r_bot=0.085, hoops=("hoop",), hoop_z=(0.96,)),
    roof=dict(half_x=0.6, depth=0.52, ze=1.47, zr=2.02, n=4, th=0.05, lift=0.045, y0=0.12),
)


def materials(k):
    g = k.mat_gradient
    return {
        "stone": g("stone", [(0.0, "stone_lo"), (0.55, "stone"), (1.0, "stone_hi")], 0.0, 0.5, 0.45, 9.0),
        "cap": g("cap", [(0.0, "cap_lo"), (0.5, "cap"), (1.0, "cap_hi")], 0.45, 0.62, 0.4, 9.0),
        "core": g("core", [(0.0, "core"), (1.0, "core")], 0.0, 1.0, 0.0),
        "water": g("water", [(0.0, "water"), (1.0, "water_hi")], 0.46, 0.52, 0.3, 6.0),
        "wood": k.mat_door("wood", keys=("wood_lo", "wood", "wood_hi"), planks=14.0, direction="Z"),
        "wood2": g("wood2", [(0.0, "wood2"), (1.0, "wood")], 1.1, 1.25, 0.2, 9.0),
        "roof": k.mat_gradient("roof", [(0.0, "roof_lo"), (0.5, "roof"), (1.0, "roof_hi")], 1.3, 1.95, 0.25, 7.0),
        "rope": g("rope", [(0.0, "rope"), (1.0, "rope")], 0.0, 1.0, 0.0),
        "bucket": g("bucket", [(0.0, "bucket"), (1.0, "bucket_hi")], 0.7, 0.95, 0.2, 8.0),
        "hoop": g("hoop", [(0.0, "hoop"), (1.0, "hoop")], 0.0, 1.0, 0.0),
    }


def build(m, k):
    return build_well(m, k, SPEC)
