# -*- coding: utf-8 -*-
"""Родина каменів за малюнками rock_*.png і rock_grey_*.png: низькополігональна брила
(видимі грані), перехід кольору знизу вгору плямами, мох трьох видів і — у rock_grey_* —
личко (очі з відблиском, усмішка, рум'янець, вії).

Модель задає лише параметри P і палітру PAL. Кольори окремими ключами (камінь низ/середина/
верх, мох, очі, рум'янець, квіточка), тож перефарбування — лише PAL.

Форма — ПРОФІЛЬ силуету з малюнка: півширина на 21 рівні зверху донизу в частках висоти
(prof). Брила — ікосфера, кожне кільце якої розтягнуте до ширини профілю на своїй висоті,
плюс шум (горбки) — і грані окремо (faceted), як на малюнку. Анімації нема.

Мох:
  • "facets" — ділянка граней самої брили, трохи піднята (rock_2): зелені грані врівень з
    каменем, як на малюнку;
  • "cap" / "dot" / "star" — «наліпка» по поверхні (smallprop_common.decal_on): шапка моху
    згори (rock_grey_1/2), цятки, зірочка з хвилястим краєм (rock_3).
"""
import math

import bpy
import bmesh
from mathutils import Vector, noise

import kit
import smallprop_common as sp

DETAIL = sp.DETAIL


# Кольори личка й дрібниць — типові, якщо модель їх не задала.
DEFAULT_PAL = {"eye": "#1E1E22", "glint": "#FFFFFF", "blush": "#8FD3DA", "petal": "#F29AB2",
               "dark": "#2A2622", "moss_hi": "#9ACB4A", "moss": "#7DB53A", "moss_lo": "#5E9A2A"}


def materials(k, P):
    H = P["H"]
    for key, val in DEFAULT_PAL.items():
        k.PAL.setdefault(key, val)
    return {
        # stops — де по висоті середній і основний колір (частки): у rock_1/rock_3 брунатний низ вищий
        "rock": k.mat_gradient("rock", [(0.0, "rock_lo"), (P.get("stops", (0.35, 0.7))[0], "rock_mid"),
                                        (P.get("stops", (0.35, 0.7))[1], "rock"), (1.0, "rock_hi")],
                               0.0, H, P.get("jitter", 0.35), P.get("jscale", 3.0)),
        "moss": k.mat_gradient("moss", [(0.0, "moss_lo"), (0.6, "moss"), (1.0, "moss_hi")],
                               H * 0.3, H * 1.05, 0.25, 9.0),
        "eye": sp.mat_flat(k, "eye", "eye"),
        "glint": sp.mat_flat(k, "glint", "glint"),
        "blush": sp.mat_flat(k, "blush", "blush"),
        "petal": sp.mat_flat(k, "petal", "petal"),
        "dark": sp.mat_flat(k, "dark", "dark"),
    }


def body(m, P):
    H, prof = P["H"], P["prof"]
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sp.D("ico"), radius=1.0, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = "body"
    seed = P.get("seed", 0)
    off = Vector((seed * 7.31, seed * 3.17, seed * 5.53))
    amp, freq, depth = P.get("amp", 0.08), P.get("freq", 1.7), P.get("depth", 0.92)
    for v in ob.data.vertices:
        p = v.co.normalized()
        t = (1.0 - p.z) * 0.5                    # 0 — верх, 1 — низ
        w = sp.interp(prof, t) * H
        rho = math.hypot(p.x, p.y)
        d = 1.0 + amp * noise.noise(p * freq + off)
        if rho > 1e-6:
            x, y = p.x / rho * w * d, p.y / rho * w * d * depth
        else:
            x = y = 0.0
        z = H * (1.0 - t) + amp * 0.3 * H * noise.noise(p * freq + off + Vector((5, 5, 5)))
        v.co = Vector((x, y, max(0.0, z)))
    ob.data.materials.append(m["rock"])
    if sp.D("dec") < 1.0:   # mid: ті самі обриси, удвічі менше граней
        dm = ob.modifiers.new("dec", "DECIMATE")
        dm.ratio = sp.D("dec")
        sp.apply_mods(ob)
    return ob


def hit(target, P, az, el, h=0.5):
    """Точка на брилі в напрямку (кут від фронту −Y, кут над горизонтом) з точки на висоті h·H."""
    H = P["H"]
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    c = Vector((0.0, 0.0, H * h))
    return sp.ray_hit(target, c + d * H * 3, -d)


def front(target, P, x, z):
    """Точка на лиці брили навпроти (x, z) — для очей і усмішки (промінь з −Y до +Y)."""
    H = P["H"]
    return sp.ray_hit(target, (x * H, -H * 3, z * H), (0, 1, 0))


def facet_patch(name, mat, target, P, az, el, angle, thick, rag=0.3):
    """Мох «гранями»: грані брили, чий центр — у конусі angle° довкола напрямку (az, el), з
    рваним краєм (шум), піднята на thick уздовж нормалей вершин, з бортиком до поверхні."""
    H = P["H"]
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    c = Vector((0.0, 0.0, H * 0.5))
    src = bmesh.new()
    src.from_mesh(target.data)
    src.normal_update()
    thr = math.cos(math.radians(angle))
    faces = []
    for f in src.faces:
        v = (f.calc_center_median() - c).normalized()
        if v.dot(d) + rag * 0.15 * noise.noise(v * 3.0 + Vector((az, el, 1))) > thr:
            faces.append(f)
    bm = bmesh.new()
    top, bot = {}, {}
    for f in faces:
        for v in f.verts:
            if v.index not in top:
                top[v.index] = bm.verts.new(v.co + v.normal * thick)
                bot[v.index] = bm.verts.new(v.co - v.normal * thick * 0.5)
    for f in faces:
        bm.faces.new([top[v.index] for v in f.verts])
    sel = set(faces)
    for f in faces:   # бортик по краю ділянки
        for ed in f.edges:
            if sum(1 for lf in ed.link_faces if lf in sel) == 1:
                i0, i1 = ed.verts[0].index, ed.verts[1].index
                try:
                    bm.faces.new((top[i1], top[i0], bot[i0], bot[i1]))
                except ValueError:
                    pass
    src.free()
    return sp.finish_bm(bm, name, mat)


def eye(name, m, target, P, x, z, r, glint=True, lashes=0):
    pos, nor = front(target, P, x, z)
    if pos is None:
        return
    s = sp.D("sph")
    e = sp.blob(name, m["eye"], (0, 0, 0), r, scale=(1.0, 1.1, 0.45))
    sp.orient(e, pos + nor * r * 0.1, nor)
    if glint:
        g = sp.blob(name + "_glint", m["glint"], (0, 0, 0), r * 0.3, scale=(1, 1, 0.6),
                    seg=(max(6, s[0] - 4), max(3, s[1] - 2)))
        # відблиск — угорі праворуч на обох очах (світло одне), як на малюнку
        sp.orient(g, pos + nor * r * 0.42 + Vector((r * 0.32, 0, r * 0.38)), nor)
    for j in range(lashes):   # вії — дві рисочки назовні вгору
        side = 1 if x > 0 else -1
        a = math.radians(35 + 30 * j)
        p0 = pos + Vector((side * r * 0.9 * math.cos(a), 0, r * 1.0 * math.sin(a)))
        p1 = p0 + Vector((side * r * 0.35 * math.cos(a), -r * 0.1, r * 0.35 * math.sin(a)))
        sp.tube(name + "_lash%d" % j, m["eye"], [tuple(p0), tuple(p1)], r * 0.08, res=0)


def smile(name, m, target, P, x, z, w, depth, thick):
    """Усмішка — трубка по дузі, кожна точка покладена на лице."""
    n = 7 if sp.D("seg") >= 12 else 5
    pts = []
    for i in range(n):
        t = -1 + 2 * i / (n - 1)
        pos, nor = front(target, P, x + t * w * 0.5, z - depth * (1 - t * t))
        if pos is not None:
            pts.append(tuple(pos + nor * thick * 0.3))
    sp.tube(name, m["eye"], pts, thick, res=0 if sp.D("seg") < 12 else 1)


def build(m, k, P):
    H = P["H"]
    ob = body(m, P)
    seg = sp.D("seg")
    for j, ms in enumerate(P.get("moss", [])):
        kind = ms["kind"]
        if kind == "facets":
            facet_patch("moss%d" % j, m["moss"], ob, P, ms["az"], ms["el"], ms["angle"], ms.get("thick", 0.012) * H)
            continue
        if seg < 12 and ms.get("r", 0.1) < P.get("low_min", 0.04):
            continue   # у найпростішому — без дрібних цяток
        pos, nor = hit(ob, P, ms["az"], ms["el"], ms.get("h", 0.5))
        if pos is None:
            continue
        if kind == "cap":
            sp.decal_on("moss%d" % j, m["moss"], ob, pos, nor, ms["r"] * H, center=(0, 0, H * 0.5), thick=ms.get("thick", 0.03) * H,
                        seg=max(8, seg), rings=3 if seg >= 12 else 2, dome=ms.get("dome", 0.06),
                        wobble=ms.get("wobble", 0.08), lobes=ms.get("lobes", 5), seed=ms.get("seed", 0.4))
        elif kind == "star":
            sp.decal_on("moss%d" % j, m["moss"], ob, pos, nor, ms["r"] * H, center=(0, 0, H * 0.5), thick=ms.get("thick", 0.008) * H,
                        seg=max(10, seg * 3 // 2), rings=2, dome=0.0, wobble=ms.get("wobble", 0.4),
                        lobes=ms.get("lobes", 7), seed=ms.get("seed", 1.0))
        else:   # dot
            sp.decal_on("moss%d" % j, m["moss"], ob, pos, nor, ms["r"] * H, center=(0, 0, H * 0.5), thick=ms.get("thick", 0.01) * H,
                        seg=max(6, seg // 2 + 2), rings=2, dome=ms.get("dome", 0.25),
                        wobble=ms.get("wobble", 0.12), lobes=ms.get("lobes", 3), seed=ms.get("seed", 0.0))
    f = P.get("face")
    if f:
        for side in (-1, 1):
            eye("eye%d" % (side > 0), m, ob, P, side * f["eye_x"], f["eye_z"], f["eye_r"] * H,
                lashes=f.get("lashes", 0) if seg >= 12 else 0)
            if f.get("blush"):
                bx, bz, br = f["blush"]
                pos, nor = front(ob, P, side * bx, bz)
                if pos is not None:
                    sp.decal_on("blush%d" % (side > 0), m["blush"], ob, pos, nor, br * H, thick=0.003 * H,
                                seg=max(6, seg // 2 + 2), rings=1)
        sx, sz, sw, sd, st = f["smile"]
        smile("smile", m, ob, P, sx, sz, sw, sd, st * H)
    fl = P.get("flower")
    if fl:
        pos, nor = hit(ob, P, fl["az"], fl["el"], fl.get("h", 0.5))
        if pos is not None:
            sp.decal_on("flower", m["petal"], ob, pos, nor, fl["r"] * H, thick=0.006 * H,
                        seg=max(10, seg * 5 // 4), rings=2, dome=0.1, wobble=0.45, lobes=5, seed=1.57)
            sp.decal_on("flower_mid", m["glint"], ob, pos, nor, fl["r"] * H * 0.25, thick=0.012 * H,
                        seg=6, rings=1, dome=0.3)
    for j, (az, el, r) in enumerate(P.get("holes", [])):
        pos, nor = hit(ob, P, az, el)
        if pos is not None:
            sp.decal_on("hole%d" % j, m["dark"], ob, pos, nor, r * H, thick=0.002 * H, seg=6, rings=1)
    sp.faceted(ob)
    return {}
