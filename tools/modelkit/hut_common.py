# -*- coding: utf-8 -*-
"""Спільне для родини хатинок (hut, hut_2, hut_3, hut_4): заготовки, яких нема в kit.py.
Файл моделі імпортує потрібне: `from hut_common import bent_bar`."""
import math

import bmesh
import bpy

import kit


def bent_bar(name, mat, w, rise, y, thick, z_ends, steps=None):
    """Вигнута «підкова» — брус круглого перерізу по пологій дузі (парабола): кінці на z_ends,
    середина на z_ends + rise, ширина w. Козирки над дверима, брови над вікнами. На відміну від
    kit.arch_curve (півколо), дуга тут може бути якою завгодно пологою."""
    steps = steps or max(4, kit.DET["arch"])
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = kit.DET["tube"]
    cu.resolution_u = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(steps)
    for i, p in enumerate(sp.points):
        u = -1.0 + 2.0 * i / steps
        p.co = (u * w * 0.5, y, z_ends + rise * (1.0 - u * u), 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def bent_bar_on(name, mat, pts_xz, thick, wrap_r=None, y=0.0, off=0.0):
    """Брус круглого перерізу по довільній ламаній (x, z). Якщо wrap_r задано — брус лежить
    на круглій стіні радіуса wrap_r (з центром у 0,0): y = −√(R² − x²) − off, тож кінці не
    висять у повітрі над вигнутою стіною (козирок над дверима круглої хатки)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = kit.DET["tube"]
    cu.resolution_u = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts_xz) - 1)
    for p, (x, z) in zip(sp.points, pts_xz):
        yy = -math.sqrt(max(wrap_r * wrap_r - x * x, 0.0)) - off if wrap_r else y
        p.co = (x, yy, z, 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def lathe(name, mat, prof, segs, wobble=None):
    """Тіло обертання навколо осі Z: prof — ЗАМКНЕНИЙ контур [(r, z), …] (точки з r = 0
    зливаються в полюс). wobble(θ, r, z) → (dr, dz) — нерівність ліплення: хвилястий край
    даху, «м'ята» стіна. Сітка замкнена (придатна для булевих), нормалі назовні."""
    bm = bmesh.new()
    rings = []
    for i in range(segs):
        a = 2 * math.pi * i / segs
        ring = []
        for r, z in prof:
            dr, dz = wobble(a, r, z) if wobble else (0.0, 0.0)
            rr = max(r + dr, 0.0) if r > 1e-6 else 0.0
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z + dz)))
        rings.append(ring)
    n = len(prof)
    for i in range(segs):
        A, B = rings[i], rings[(i + 1) % segs]
        for j in range(n):
            k = (j + 1) % n
            quad = [A[j], B[j], B[k], A[k]]
            try:
                bm.faces.new(quad)
            except ValueError:
                pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    # вироджені грані біля полюсів (дві вершини злились) — прибрати
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def cut(ob, cutter):
    """Булеве віднімання: з ob вирізати об'єм cutter, cutter — геть."""
    md = ob.modifiers.new("cut", "BOOLEAN")
    md.operation = "DIFFERENCE"
    md.solver = "EXACT"
    md.object = cutter
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=md.name)
    bpy.data.objects.remove(cutter, do_unlink=True)
