# -*- coding: utf-8 -*-
"""Сосна за малюнком pine_3_2_test_draw.png: три яруси-«спідниці» з хвилястим нижнім краєм на
конічному брунатному стовбурі.

Скелет для гойдання на вітрі: стовбур → нижній → середній → верхній ярус (ланцюжком, ваги —
автоматичні). Верх гойдається сильніше за низ, як справжнє дерево; у сцені порівняння кістки
крутить процедурно (src/debug/model_compare.gd)."""
import math

import bpy
import bmesh

import kit
from kit import soften

PAL = {
    "leaf_hi": "#8CC094", "leaf": "#6CA477", "leaf_lo": "#538960", "leaf_dark": "#3A6E48",
    "bark_hi": "#A2703F", "bark": "#855B35", "bark_lo": "#6A4526",
}

TIERS = [      # (низ ярусу z, верх z, радіус низу) — пропорції з малюнка
    (0.72, 1.5, 0.64),
    (1.05, 1.75, 0.47),
    (1.36, 2.1, 0.3),
]


def materials(k):
    return {
        "leaf": k.mat_gradient("leaf", [(0.0, "leaf_lo"), (0.5, "leaf"), (1.0, "leaf_hi")], 0.7, 2.1, 0.35, 4.0),
        "bark": k.mat_door("bark", keys=("bark_lo", "bark", "bark_hi"), planks=9.0, direction="X"),
    }


def tier(name, mat, z0, z1, r, k, scallops=9):
    """Конус-ярус: нижній край хвилею («спідничка» з фестонами), трохи увігнутий схил."""
    seg = max(scallops * 2, k.DET["cyl"] * 2)
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rings = 3 if k.DET["bev"] >= 2 else 2
    tip = bm.verts.new((0, 0, z1))
    prev = None
    rows = []
    for ri in range(1, rings + 1):
        f = ri / rings                          # 0 — верхівка, 1 — нижній край
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            rr = r * (f ** 0.85)                # трохи увігнутий схил
            z = z1 - (z1 - z0) * f
            if ri == rings:                     # фестони на краю: край то нижче, то вище
                z += 0.035 * math.cos(a * scallops)
                rr *= 1.0 + 0.04 * math.cos(a * scallops)
            row.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rows.append(row)
    for i in range(seg):
        bm.faces.new((tip, rows[0][i], rows[0][(i + 1) % seg]))
    for ri in range(1, len(rows)):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((rows[ri - 1][i], rows[ri][i], rows[ri][j], rows[ri - 1][j]))
    # спід ярусу — пласке денце трохи вище краю (знизу його видно лише зблизька)
    ctr = bm.verts.new((0, 0, z0 + 0.06))
    last = rows[-1]
    for i in range(seg):
        bm.faces.new((ctr, last[(i + 1) % seg], last[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    ob = kit.link(me, name, mat)
    return ob


def build(m, k):
    # Стовбур — «body»: конічний, брунатний.
    bpy.ops.mesh.primitive_cone_add(vertices=max(8, k.DET["cyl"]), radius1=0.17, radius2=0.12, depth=0.85,
                                    location=(0, 0, 0.425))
    body = bpy.context.active_object
    body.name = "body"
    body.data.materials.append(m["bark"])
    soften(body, 0.02, min(2, k.DET["bev"]))
    for i, (z0, z1, r) in enumerate(TIERS):
        tier("tier%d" % i, m["leaf"], z0, z1, r, k)
    # Скелет: стовбур → яруси ланцюжком.
    return {"rig": [
        ("trunk", (0, 0, 0.0), (0, 0, 0.6), None),
        ("tier0", (0, 0, 0.6), (0, 0, 1.0), "trunk"),
        ("tier1", (0, 0, 1.0), (0, 0, 1.4), "tier0"),
        ("tier2", (0, 0, 1.4), (0, 0, 2.1), "tier1"),
    ]}
