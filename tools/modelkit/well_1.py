# -*- coding: utf-8 -*-
"""Криниця 1 за малюнком well_1.jpg: зруб із великих круглястих світло-сірих валунів
(три ряди й вінець), бірюзова вода, два дерев'яні стовпи, круглий брус-ворот із торцем, що
виступає праворуч, товста кручена мотузка й чорне відро, двосхилий дах щипцем до камери з
широких світлих дощок у два ряди внахльост, колода-гребінь із торцями, у щипці — каркас і
сіра зірочка.

Збирач — well_common.build_well; тут палітра, розміри й зірочка (одиниці Blender, перед — −Y)."""
import math

import bmesh
import bpy

import kit
from well_common import build_well

# Палітра — k-середні по пікселях криниці (26.09) і точкові проби; на крок світліша за «сирі».
PAL = {
    "stone_hi": "#CAC6BE", "stone": "#AEAAA0", "stone_lo": "#8C887E", "core": "#454A4A",
    "water": "#62AA9E", "water_hi": "#7CC0B2",
    "wood_hi": "#9A7254", "wood": "#806048", "wood_lo": "#654933", "wood2": "#7A5A42",
    "ridge_hi": "#FFC48C", "ridge": "#F4B07A", "ring": "#C8925E",
    "roof_hi": "#FFBC86", "roof": "#F2AA74", "roof_lo": "#D88E5A", "roof_line": "#C07C4E",
    "rope": "#8E7056", "bucket": "#2E3336", "bucket_hi": "#454B4E", "hoop": "#202426", "star": "#A3A2A6",
}

SPEC = dict(
    ring=dict(r_out=0.76, r_in=0.46, h=0.72, rows=3, per=8, cap_h=0.15, cap_per=9, cap_out=0.03, depth=0.12, seed=11,
              bevel=0.06, jitter=0.5, gap=0.02, bulge=0.05, bev_segs=1, hard=False, arc_segs=2),
    water_z=0.63,
    posts=dict(x=0.46, w=0.2, top=1.46),
    crossbar=dict(z=1.42, r=0.065, half=0.66, style="log", coil=2),
    plates=[],
    bucket=dict(z_top=1.0, h=0.25, r_top=0.12, r_bot=0.1, hoops=("hoop",), hoop_z=(0.95,)),
    rope_r=0.022,
    roof=dict(axis="y", half_x=0.56, depth=0.9, ze=1.52, zr=2.06, n=2, th=0.05, lift=0.05, shingles=2,
              ridge=(0.09, 0.62), ridge_end=(-1, 1), truss=(0.5, 0.065)),
)


def materials(k):
    g = k.mat_gradient
    return {
        "stone": g("stone", [(0.0, "stone_lo"), (0.55, "stone"), (1.0, "stone_hi")], 0.0, 0.7, 0.45, 7.0),
        "core": g("core", [(0.0, "core"), (1.0, "core")], 0.0, 1.0, 0.0),
        "water": g("water", [(0.0, "water"), (1.0, "water_hi")], 0.6, 0.66, 0.3, 6.0),
        "wood": k.mat_door("wood", keys=("wood_lo", "wood", "wood_hi"), planks=12.0, direction="Z"),
        "wood2": g("wood2", [(0.0, "wood2"), (1.0, "wood")], 1.35, 1.5, 0.2, 9.0),
        "ridge": k.mat_door("ridge", keys=("roof_line", "ridge", "ridge_hi"), planks=10.0, direction="Z"),
        "ring": g("ring", [(0.0, "ring"), (1.0, "ring")], 0.0, 1.0, 0.0),
        "roof": k.mat_door("roof", keys=("roof_line", "roof", "roof_hi"), planks=5.0, direction="Y"),
        "rope": k.mat_door("rope", keys=("wood_lo", "rope", "rope"), planks=60.0, direction="Z"),
        "bucket": g("bucket", [(0.0, "bucket"), (1.0, "bucket_hi")], 0.75, 1.0, 0.2, 8.0),
        "hoop": g("hoop", [(0.0, "hoop"), (1.0, "hoop")], 0.0, 1.0, 0.0),
        "handle": g("handle", [(0.0, "rope"), (1.0, "rope")], 0.0, 1.0, 0.0),
        "star": g("star", [(0.0, "star"), (1.0, "star")], 0.0, 1.0, 0.0),
    }


def star(name, mat, c, r_out, r_in, thick):
    """П'ятикутна зірочка — призма в площині XZ, лицем до −Y."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    x, y, z = c
    prof = []
    for i in range(10):
        a = math.pi / 2 + math.pi * i / 5
        r = r_out if i % 2 == 0 else r_in
        prof.append((x + r * math.cos(a), z + r * math.sin(a)))
    f = [bm.verts.new((px, y - thick / 2, pz)) for px, pz in prof]
    b = [bm.verts.new((px, y + thick / 2, pz)) for px, pz in prof]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    for i in range(10):
        j = (i + 1) % 10
        bm.faces.new((f[i], f[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = kit.link(me, name, mat)
    kit.soften(ob, 0.012, min(2, kit.DET["bev"]))
    return ob


def build(m, k):
    info = build_well(m, k, SPEC)
    # зірочка в передньому щипці, на стояку каркаса
    star("star", m["star"], (0.0, -SPEC["roof"]["truss"][0] - 0.05, 1.74), 0.13, 0.06, 0.05)
    return info
