# -*- coding: utf-8 -*-
"""Родина «тюк сіна» (hay_bale_*): солом'яне тіло, стягнуте мотузками чи ременями. Солома —
процедурна: «пластівці» (клітинки Вороного різного тону з темним швом між ними) і тонкі
волокна зверху. Модель задає PAL і CFG, тож перефарбувати — правка палітри.

Тюки-кулі (hay_bale_1, _3, _4) — ПЕРЕШКОДИ, що котяться (anim "roll" у data/worlds/*.json,
src/run3d/obstacle3d.gd): початок координат — у центрі дна, переріз справді круглий (не менше
12 сегментів і на low), мотузки й дрібниці виступають за радіус не більше ніж на 1–2 см, габарит
під box [0.65, 0.7, 0.65].

Ключі PAL: straw_lo/straw/straw_hi/straw_top (солома), straw_seam (шов між пластівцями),
band_lo/band/band_hi (мотузки чи ремені)."""
import math

import bpy
import bmesh
from mathutils import Matrix, Vector

import kit

# сегменти кулі (по колу, по меридіану): і на low ≥ 12 по колу, щоб котилась, не кульгаючи
SEG = {"high": (28, 16), "mid": (18, 11), "low": (12, 8)}
RING = {"high": (32, 6), "mid": (20, 5), "low": (14, 4)}   # мотузка: сегменти по колу, у перерізі


def level(k):
    return {3: "high", 2: "mid"}.get(k.DET["bev"], "low")


def mat_straw(name, keys=("straw_lo", "straw", "straw_hi", "straw_top"), seam="straw_seam",
              flakes=9.0, fibers=40.0, seam_w=0.06):
    """Солома: пластівці (Вороного) чотирьох тонів, темний шов між ними й світлі волокна."""
    m = kit._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = flakes
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vor.outputs["Color"], sep.inputs["Color"])
    tone = kit._ramp(nt, [(0.0, keys[0]), (0.35, keys[1]), (0.75, keys[2]), (1.0, keys[3])])
    nt.links.new(sep.outputs[0], tone.inputs["Fac"])
    # шов між пластівцями
    edge = nt.nodes.new("ShaderNodeTexVoronoi")
    edge.feature = "DISTANCE_TO_EDGE"
    edge.inputs["Scale"].default_value = flakes
    nt.links.new(tc.outputs["Object"], edge.inputs["Vector"])
    sm = nt.nodes.new("ShaderNodeMapRange")
    sm.inputs["From Min"].default_value = 0.0
    sm.inputs["From Max"].default_value = seam_w
    nt.links.new(edge.outputs["Distance"], sm.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.inputs["A"].default_value = kit.rgb(kit.PAL[seam])
    nt.links.new(tone.outputs["Color"], mix.inputs["B"])
    nt.links.new(sm.outputs["Result"], mix.inputs["Factor"])
    # волокна: тонкі світлі риски шумом
    fib = nt.nodes.new("ShaderNodeTexWave")
    fib.wave_type = "BANDS"
    fib.bands_direction = "DIAGONAL"
    fib.inputs["Scale"].default_value = fibers
    fib.inputs["Distortion"].default_value = 6.0
    fib.inputs["Detail"].default_value = 2.0
    nt.links.new(tc.outputs["Object"], fib.inputs["Vector"])
    fr = nt.nodes.new("ShaderNodeMapRange")
    fr.inputs["From Min"].default_value = 0.9
    fr.inputs["From Max"].default_value = 1.0
    fr.inputs["To Max"].default_value = 0.35
    nt.links.new(fib.outputs["Fac"], fr.inputs["Value"])
    mix2 = nt.nodes.new("ShaderNodeMix")
    mix2.data_type = "RGBA"
    nt.links.new(mix.outputs["Result"], mix2.inputs["A"])
    mix2.inputs["B"].default_value = kit.rgb(kit.PAL[keys[3]])
    nt.links.new(fr.outputs["Result"], mix2.inputs["Factor"])
    nt.links.new(mix2.outputs["Result"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def mat_rope(name, keys=("band_lo", "band", "band_hi"), twist=60.0):
    """Мотузка: скручені пасма — косі смуги."""
    m = kit._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = "DIAGONAL"
    wave.inputs["Scale"].default_value = twist
    wave.inputs["Distortion"].default_value = 0.5
    nt.links.new(tc.outputs["Object"], wave.inputs["Vector"])
    r = kit._ramp(nt, [(0.1, keys[0]), (0.45, keys[1]), (0.85, keys[2])])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def ball(name, mat, k, r, squash=1.0, lumps=0.0, seed=1):
    """Куля-тюк радіуса r, центр дна в (0,0,0). squash — висота/ширина; lumps — нерівність
    поверхні (м, лише ВСЕРЕДИНУ, щоб габарит котіння лишився колом)."""
    seg, rings = SEG[level(k)]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=rings,
                                         location=(0, 0, r * squash))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = (1, 1, squash)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if lumps > 0:
        from mathutils import noise
        for v in ob.data.vertices:
            n = noise.noise(v.co * 6.0 + Vector((seed, seed * 2, 0)))
            v.co = v.co * (1.0 - lumps / r * (0.5 + 0.5 * n))
    ob.data.materials.append(mat)
    return ob


def ring(name, mat, k, center, radius, tube, axis, flat=1.0):
    """Мотузка чи ремінь кільцем: тор радіуса radius навколо осі axis (вектор) з центром
    center; flat > 1 — ремінь (переріз витягнутий уздовж осі)."""
    maj, mnr = RING[level(k)]
    bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=tube, major_segments=maj,
                                     minor_segments=mnr, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = (1, 1, flat)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    q = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized())
    ob.matrix_world = Matrix.Translation(center) @ q.to_matrix().to_4x4()
    ob.data.materials.append(mat)
    return ob


def arc(name, mat, k, center, radius, tube, axis, a0, a1, start=None):
    """Відрізок кола (дуга мотузки чи палички) — крива з круглим перерізом."""
    maj, mnr = RING[level(k)]
    n = max(3, int(maj * abs(a1 - a0) / (2 * math.pi)))
    ax = Vector(axis).normalized()
    u = (start or ax.orthogonal()).normalized()
    v = ax.cross(u)
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = tube
    cu.bevel_resolution = max(0, mnr // 2 - 1)
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(n)
    for i, p in enumerate(sp.points):
        a = a0 + (a1 - a0) * i / n
        pos = Vector(center) + radius * (math.cos(a) * u + math.sin(a) * v)
        p.co = (*pos, 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def axis_from(tilt_deg, turn_deg):
    """Вісь кільця: від вертикалі нахилена на tilt, повернута навколо вертикалі на turn."""
    t, p = math.radians(tilt_deg), math.radians(turn_deg)
    return (math.sin(t) * math.cos(p), math.sin(t) * math.sin(p), math.cos(t))
