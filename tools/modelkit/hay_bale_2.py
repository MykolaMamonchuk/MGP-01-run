# -*- coding: utf-8 -*-
"""Тюк сіна за малюнком hay_bale_2.png: солом'яний рулон-«барило» (трохи опуклий посередині,
із заокругленими краями), що ЛЕЖИТЬ на боці на чотирьох брунатних колодочках-колесах; дві
мотузки обперізують його, третя йде вздовж верху й спускається по торцю. На боках — поздовжні
смуги соломи, на торцях — кільця намотки.

Це декор, а не перешкода, що котиться: рулон на колодках котитись не може (для «roll» годяться
кулі hay_bale_1/_3/_4). Габарит 0,71 × 0,6 × 0,63 м, початок у центрі дна. Геометрія —
haybale_common і своя (барило вздовж осі X)."""
import math

import bpy
import bmesh

import kit
import haybale_common as hc

PAL = {
    # Кластери малюнка (#EAA031, #F6B039, #FCC545, #FDD550, #FEF469; торець #F5B844; мотузка
    # #FDE35A; колодки #9C603E). Малюнок дуже яскравий, тож тонування слабше, ніж у куль:
    # PAL ≈ 0,92 · (сер + 1,15 · (колір − сер)).
    "straw_lo": "#EEA426", "straw": "#F3B931", "straw_hi": "#F3C83C", "straw_top": "#F1E653",
    "straw_seam": "#E3951F",
    "end_lo": "#E09D26", "end": "#ECAC31", "end_hi": "#F3B931",
    "band_lo": "#E4C25D", "band": "#F1D645", "band_hi": "#F0E17B",
    "wood": "#874B29", "wood_hi": "#9A5A34",
}

L, R = 0.64, 0.3          # довжина рулону й радіус посередині
LIFT = 0.025              # на колодках: низ рулону майже на землі, колодки визирають з-під країв
ZC = LIFT + R             # вісь


def mat_rings(name, keys, zc, width=0.045):
    """Торець рулону: концентричні кільця намотки навколо осі (0, 0, zc)."""
    m = kit._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (0.0, 0.0, -zc)
    mp.inputs["Scale"].default_value = (0.0, 1.0, 1.0)     # лише відстань від осі X
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "RINGS"
    wave.inputs["Scale"].default_value = 2 * math.pi / (20.0 * width)
    wave.inputs["Distortion"].default_value = 1.5
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    r = kit._ramp(nt, [(0.02, keys[0]), (0.15, keys[1]), (0.8, keys[2])])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def materials(k):
    return {
        # поздовжні смуги соломи вздовж осі рулону (хвиля поперек — по висоті)
        "straw": k.mat_door("straw", keys=("straw_lo", "straw", "straw_hi"), planks=4.0, direction="Z"),
        "end": mat_rings("end", ("end_lo", "end", "end_hi"), ZC),
        "rope": hc.mat_rope("rope", twist=90.0),
        "wood": k.mat_gradient("wood", [(0.0, "wood"), (1.0, "wood_hi")], 0.0, 0.16, 0.3, 8.0),
    }


def barrel(name, m, k):
    """Барило вздовж X: профіль (x, радіус), обертом навколо осі; бік — «straw», торці — «end»."""
    seg = hc.SEG[hc.level(k)][0]
    prof = [(-L / 2, 0.0), (-L / 2, R * 0.8), (-L / 2 + 0.014, R * 0.89), (-L / 2 + 0.05, R * 0.95),
            (-L / 4, R * 0.99), (0.0, R), (L / 4, R * 0.99), (L / 2 - 0.05, R * 0.95),
            (L / 2 - 0.014, R * 0.89), (L / 2, R * 0.8), (L / 2, 0.0)]
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    rows = []
    for x, r in prof:
        if r == 0.0:
            rows.append([bm.verts.new((x, 0.0, ZC))])
        else:
            rows.append([bm.verts.new((x, r * math.cos(2 * math.pi * i / seg), ZC + r * math.sin(2 * math.pi * i / seg)))
                         for i in range(seg)])
    for a, b in zip(rows, rows[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            if len(a) == 1:
                f = bm.faces.new((a[0], b[j], b[i]))
            elif len(b) == 1:
                f = bm.faces.new((a[i], a[j], b[0]))
            else:
                f = bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        f.material_index = 1 if abs(f.normal.x) > 0.7 else 0
    bm.to_mesh(me)
    bm.free()
    ob = kit.link(me, name, m["straw"])
    ob.data.materials.append(m["end"])
    return ob


def build(m, k):
    barrel("body", m, k)
    lv = hc.level(k)
    tube = 0.013
    # дві мотузки навколо
    for i, x in enumerate((-0.15, 0.09)):
        hc.ring("rope%d" % i, m["rope"], k, (x, 0, ZC), R * 0.995 + 0.004, tube, (1, -0.12, 0))
    # третя — уздовж верху (трохи до фасаду) і вниз по правому торцю
    a = math.radians(140)
    pts = []
    n = 6 if lv != "low" else 3
    for i in range(n + 1):
        x = -0.3 + (L / 2 - 0.02 + 0.3) * i / n
        rr = R * (0.99 if abs(x) < L / 2 - 0.05 else 0.93) + 0.004
        pts.append((x, rr * math.cos(a), ZC + rr * math.sin(a)))
    for i in range(1, n + 2):
        b = a - math.radians(150) * i / (n + 1)
        rr = R * (0.78 - 0.2 * i / (n + 1))
        pts.append((L / 2 + 0.006, rr * math.cos(b), ZC + rr * math.sin(b)))
    cu = bpy.data.curves.new("rope_top", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = tube
    cu.bevel_resolution = max(0, hc.RING[lv][1] // 2 - 1)
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1.0)
    ob = bpy.data.objects.new("rope_top", cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m["rope"])
    # колодки: грубі багатогранники під чотирма кутами
    for i, (x, y) in enumerate(((-0.27, -0.21), (0.27, -0.21), (-0.27, 0.21), (0.27, 0.21))):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.085, location=(x, y, 0.07))
        w = bpy.context.active_object
        w.name = "wheel%d" % i
        w.scale = (1.0, 0.75, 0.9)
        w.rotation_euler = (0.3 * i, 0.5, 0.2 * i)
        w.data.materials.append(m["wood"])
        es = w.modifiers.new("flat", "EDGE_SPLIT")
        es.split_angle = math.radians(20)
    return {}
