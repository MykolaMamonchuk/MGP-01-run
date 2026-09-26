# -*- coding: utf-8 -*-
"""Криниця 4 за малюнком well_4.jpg: зруб із сірих брил трьома рядами вперебій і вінцем із
плит, темно-зелена вода, два брунатні стовпи, круглий ворот із ґулями на кінцях і витками
мотузки, дерев'яне відро з жовтим обідком на мотузці, двосхилий дах із помаранчевої гонти в
три ряди внахльост і дощаним щипцем.

Збирач — well_common.build_well; тут палітра й розміри (одиниці Blender, перед — −Y)."""
import kit
from well_common import build_well

# Палітра — k-середні по пікселях криниці (26.09) і точкові проби; на крок світліша за «сирі».
PAL = {
    "stone_hi": "#BDB6A6", "stone": "#A49D8D", "stone_lo": "#8A8676", "core": "#55564C",
    "water": "#557A60", "water_hi": "#6E9478",
    "wood_hi": "#8C5E3A", "wood": "#7C5232", "wood_lo": "#623F25", "wood2": "#704A2B",
    "roof_hi": "#F2A15A", "roof": "#E6924C", "roof_lo": "#CF7E3C", "roof_line": "#B86C32",
    "gable": "#C47C44", "rope": "#8C6E46", "bucket": "#86593A", "bucket_hi": "#9A6A45", "hoop": "#D6AE62",
}

SPEC = dict(
    ring=dict(r_out=0.64, r_in=0.38, h=0.64, rows=3, per=8, cap_h=0.13, cap_per=8, depth=0.1, seed=3,
              bevel=0.022, jitter=0.25, gap=0.011, arc_segs=2),
    water_z=0.55,
    posts=dict(x=0.43, w=0.155, top=1.47),
    plates=[(0.0, 1.47, 0.6, 0.1, 0.08)],
    crossbar=dict(z=1.23, r=0.04, half=0.58, knobs=True, coil=2),
    bucket=dict(z_top=1.02, h=0.3, r_top=0.13, r_bot=0.11, hoops=("hoop", "bucket"), hoop_z=(0.62, 0.97)),
    roof=dict(half_x=0.64, depth=0.52, ze=1.43, zr=1.8, n=3, th=0.04, shingles=8, gable=(0.6, 0.45, 1.44, 1.78)),
)


def materials(k):
    g = k.mat_gradient
    return {
        "stone": g("stone", [(0.0, "stone_lo"), (0.55, "stone"), (1.0, "stone_hi")], 0.0, 0.7, 0.45, 9.0),
        "core": g("core", [(0.0, "core"), (1.0, "core")], 0.0, 1.0, 0.0),
        "water": g("water", [(0.0, "water"), (1.0, "water_hi")], 0.5, 0.56, 0.3, 6.0),
        "wood": k.mat_door("wood", keys=("wood_lo", "wood", "wood_hi"), planks=14.0, direction="Z"),
        "wood2": g("wood2", [(0.0, "wood2"), (1.0, "wood")], 1.18, 1.28, 0.2, 9.0),
        "roof": k.mat_door("roof", keys=("roof_line", "roof", "roof_hi"), planks=11.0, direction="X"),
        "gable": g("gable", [(0.0, "gable"), (1.0, "roof_lo")], 1.4, 1.9, 0.2, 8.0),
        "rope": g("rope", [(0.0, "rope"), (1.0, "rope")], 0.0, 1.0, 0.0),
        "bucket": k.mat_door("bucket", keys=("bucket", "bucket", "bucket_hi"), planks=30.0, direction="X"),
        "hoop": g("hoop", [(0.0, "hoop"), (1.0, "hoop")], 0.0, 1.0, 0.0),
    }


def build(m, k):
    return build_well(m, k, SPEC)
