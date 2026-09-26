# -*- coding: utf-8 -*-
"""Криниця 2 за малюнком well_2.jpg: зруб із сірих брил трьома рядами під гладким вінцем,
бірюзова вода, два брунатні стовпи з укосами до верхнього бруса, відро з дужкою на мотузці,
двосхилий дах щипцем до камери — гонта рядами внахльост із загнутими догори звисами, під
звисом видно каркас щипця, на гребені — колода з торцем.

Збирач — well_common.build_well; тут палітра й розміри (одиниці Blender, перед — −Y)."""
import kit
from well_common import build_well

# Палітра — k-середні по пікселях криниці (26.09) і точкові проби; на крок світліша за «сирі».
PAL = {
    "stone_hi": "#C8BDAC", "stone": "#A8A08C", "stone_lo": "#88846F", "core": "#4E4C44",
    "cap_hi": "#D0C8B8", "cap": "#B8B0A0", "cap_lo": "#9C9484",
    "water": "#468C7C", "water_hi": "#5CA090",
    "wood_hi": "#A06648", "wood": "#86523A", "wood_lo": "#6C402A", "wood2": "#8A5238", "ring": "#B07A55",
    "roof_hi": "#F0AE88", "roof": "#E29C76", "roof_lo": "#C47E5A", "roof_line": "#BC7652",
    "rope": "#8A6A55", "bucket": "#A06648", "bucket_hi": "#B07452", "hoop": "#6E3E28",
}

SPEC = dict(
    ring=dict(r_out=0.76, r_in=0.47, h=0.74, rows=3, per=9, cap_h=0.13, cap_per=10, cap_out=0.02, depth=0.1, seed=8,
              bevel=0.025, jitter=0.25, gap=0.012, arc_segs=2),
    water_z=0.64,
    posts=dict(x=0.47, w=0.18, top=1.56, braces=(0.28, 0.22)),
    plates=[(0.0, 1.56, 0.62, 0.12, 0.12)],
    crossbar=None,
    bucket=dict(z_top=1.1, h=0.24, r_top=0.13, r_bot=0.11, hoops=("hoop", "hoop"), hoop_z=(0.3, 0.8)),
    roof=dict(axis="y", half_x=0.62, depth=0.92, ze=1.62, zr=2.12, n=4, th=0.035, lift=0.03, shingles=4,
              flare=0.12, ridge=(0.075, 0.68), ridge_end=(-1,), truss=(0.55, 0.06)),
)


def materials(k):
    g = k.mat_gradient
    return {
        "stone": g("stone", [(0.0, "stone_lo"), (0.55, "stone"), (1.0, "stone_hi")], 0.0, 0.6, 0.45, 9.0),
        "cap": g("cap", [(0.0, "cap_lo"), (0.5, "cap"), (1.0, "cap_hi")], 0.55, 0.72, 0.4, 9.0),
        "core": g("core", [(0.0, "core"), (1.0, "core")], 0.0, 1.0, 0.0),
        "water": g("water", [(0.0, "water"), (1.0, "water_hi")], 0.56, 0.62, 0.3, 6.0),
        "wood": k.mat_door("wood", keys=("wood_lo", "wood", "wood_hi"), planks=14.0, direction="Z"),
        "wood2": g("wood2", [(0.0, "wood2"), (1.0, "wood")], 2.0, 2.2, 0.2, 9.0),
        "ring": g("ring", [(0.0, "ring"), (1.0, "ring")], 0.0, 1.0, 0.0),
        "roof": k.mat_door("roof", keys=("roof_line", "roof", "roof_hi"), planks=9.0, direction="Y"),
        "rope": g("rope", [(0.0, "rope"), (1.0, "rope")], 0.0, 1.0, 0.0),
        "bucket": k.mat_door("bucket", keys=("bucket", "bucket", "bucket_hi"), planks=30.0, direction="X"),
        "hoop": g("hoop", [(0.0, "hoop"), (1.0, "hoop")], 0.0, 1.0, 0.0),
    }


def build(m, k):
    return build_well(m, k, SPEC)
