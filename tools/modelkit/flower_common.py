# -*- coding: utf-8 -*-
"""Родина квітів за малюнками flower_*.png: «пухкі» пелюстки навколо серединки, стебло-трубка,
листки з перегином по середній жилці, у декого — підставка (flower_6/7) і травинки (flower_7).

Модель задає лише параметри P (кількість / форма / нахил пелюсток, висота, листки, підставка)
і палітру PAL. Кольори окремими ключами: пелюстки (petal_*), серединка (center_*), стебло,
листки, підставка — кожна частина має свої острівці текстури, тож перефарбування — лише PAL
(див. flower_1_blue.py: ті самі P, інша PAL).

Усе — в частках висоти H (як з маски малюнка): x — праворуч від осі, z — від землі.
Голівка дивиться до камери (−Y), нахилена вгору на tilt°.

СКЕЛЕТ для гойдання: root (нерухомий, у землі) → stem0 (низ стебла) → stem1 (верх стебла) →
head (голівка). Ваги — не теплові (ARMATURE_AUTO на окремих острівцях пелюсток то дає
порожні групи, то чіпляє пелюстку до стебла), а за місцем на стеблі: кожна вершина несе
число s (атрибут rigw) — 0 біля землі, 1 під голівкою, 2 — голівка, −1 — підставка; листок
цілий бере s свого місця кріплення, тож гнеться разом зі стеблом, а не рветься. Для цього
модель підміняє kit.add_rig (лише в процесі свого збирання; kit.py не змінено).
"""
import math

import bpy
from mathutils import Matrix, Vector

import kit
import smallprop_common as sp

DETAIL = sp.DETAIL


def materials(k, P):
    H = P["H"]
    hz = P["head"]["z"] * H
    return {
        "petal": k.mat_gradient("petal", [(0.0, "petal_lo"), (0.5, "petal"), (1.0, "petal_hi")],
                                hz - P["head"]["L"] * H * 1.1, hz + P["head"]["L"] * H * 1.1, 0.2, 6.0),
        "center": k.mat_gradient("center", [(0.0, "center_lo"), (1.0, "center")], hz - 0.08 * H, hz + 0.08 * H, 0.1, 8.0),
        "stem": k.mat_gradient("stem", [(0.0, "stem_lo"), (1.0, "stem")], 0.0, hz, 0.1, 5.0),
        "leaf": k.mat_gradient("leaf", [(0.0, "leaf_lo"), (0.6, "leaf"), (1.0, "leaf_hi")], 0.0, hz, 0.3, 5.0),
        "leaf2": k.mat_gradient("leaf2", [(0.0, "leaf2_lo"), (1.0, "leaf2")], 0.0, hz, 0.2, 5.0),
        "base": k.mat_gradient("base", [(0.0, "base_lo"), (1.0, "base")], 0.0, P.get("base", {}).get("h", 0.1) * H, 0.1, 5.0),
    }


def set_rigw(ob, value=None, fn=None):
    """Атрибут rigw на вершинах: стале число або fn(координата)."""
    me = ob.data
    at = me.attributes.get("rigw") or me.attributes.new("rigw", "FLOAT", "POINT")
    mw = ob.matrix_world
    for i, v in enumerate(me.vertices):
        at.data[i].value = value if fn is None else fn(mw @ v.co)


def head_frame(P):
    """Центр голівки й поворот: локальна +Z — «обличчя» квітки, дивиться на −Y і вгору на tilt°."""
    H, h = P["H"], P["head"]
    c = Vector((h.get("x", 0.0) * H, 0.0, h["z"] * H))
    t = math.radians(h.get("tilt", 10.0))
    nrm = Vector((0.0, -math.cos(t), math.sin(t)))
    R = nrm.to_track_quat("Z", "Y").to_matrix()
    return c, R, nrm


def petal(name, mat, P, i, c, R):
    """Пелюстка — «подушечка»: витягнута UV-сфера (полюси — на кінцях), вужча до серединки,
    з вирізом на кінчику (notch, flower_2) і відігнута вгору на cup° (flower_5)."""
    H, h = P["H"], P["head"]
    n = h["n"]
    L, W, T = h["L"] * H, h["W"] * H, h.get("T", 0.3 * h["W"]) * H
    seg, rings = sp.D("petal")
    bpy.ops.mesh.primitive_uv_sphere_add(radius=1.0, segments=seg, ring_count=rings, location=(0, 0, 0))
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(mat)
    a = math.radians(h.get("rot0", 90.0)) + 2 * math.pi * i / n
    d = Vector((math.cos(a), math.sin(a), 0.0))
    up = Vector((0.0, 0.0, 1.0))
    cup = math.radians(h.get("cup", 0.0) + h.get("droop", 0.0))
    d2 = d * math.cos(cup) + up * math.sin(cup)
    n2 = -d * math.sin(cup) + up * math.cos(cup)
    side = d.cross(up)
    r0 = h.get("r0", 0.35) * h.get("rc", 0.06) * H      # де починається пелюстка (під серединкою)
    notch = h.get("notch", 0.0)
    taper = h.get("taper", 0.45)
    lift = h.get("lift", 0.0) * H * ((i % 2) * 2 - 1) if h.get("lift") else 0.0   # черепицею: через одну вище
    for v in ob.data.vertices:
        x, y, z = v.co            # z — уздовж пелюстки (−1..1), x — ширина, y — товщина
        u = (z + 1.0) * 0.5       # 0 — біля серединки, 1 — кінчик
        wscale = (1.0 - taper) + taper * min(1.0, u * 1.6)
        px = x * W * 0.5 * wscale
        pz = u * L
        if notch and u > 0.7:
            pz -= notch * L * math.exp(-(x / 0.35) ** 2) * ((u - 0.7) / 0.3) ** 2
        py = y * T * 0.5 + h.get("bow", 0.0) * H * math.sin(math.pi * u)
        loc = d2 * (r0 + pz) + side * px + n2 * (py + lift)
        v.co = c + R @ loc
    return ob


def center(name, mat, P, c, R, nrm):
    H, h = P["H"], P["head"]
    rc = h.get("rc", 0.06) * H
    dh = h.get("dome", 0.5) * rc
    seg = h.get("center_seg") or sp.D("seg")
    # опукла пуговка: верх над пелюстками, спід заходить у них
    prof = [(0.0, dh + h.get("T", 0.1) * H * 0.3), (rc * 0.6, dh * 0.85 + h.get("T", 0.1) * H * 0.3),
            (rc, dh * 0.3 + h.get("T", 0.1) * H * 0.2), (rc * 0.95, -dh * 0.2), (0.0, -dh * 0.4)]
    ob = sp.lathe(name, mat, prof, seg)
    ob.matrix_world = Matrix.Translation(c) @ R.to_4x4()
    if h.get("center_facets"):
        sp.faceted(ob)
    return ob


def leaf(name, mat, P, lf, stem_pt):
    """Листок: вузький біля черешка, гострий кінчик, перегин V по жилці (fold), кінчик
    загнутий (curl). Лінза в перерізі (верх і низ), щоб було видно з обох боків — у грі задні
    грані відсікаються."""
    H = P["H"]
    L, W = lf["L"] * H, lf["W"] * H
    side = lf.get("side", 1)
    el, yaw = math.radians(lf.get("el", 30)), math.radians(lf.get("yaw", 0))
    d = Vector((side * math.cos(el) * math.cos(yaw), -math.cos(el) * math.sin(yaw), math.sin(el)))
    face = Vector((0.0, -1.0, 0.0))
    wa = face.cross(d)
    if wa.length < 1e-4:
        wa = Vector((1.0, 0.0, 0.0))
    wa.normalize()
    roll = math.radians(lf.get("roll", 0))
    nrm = d.cross(wa).normalized()
    wa, nrm = wa * math.cos(roll) + nrm * math.sin(roll), nrm * math.cos(roll) - wa * math.sin(roll)
    if nrm.dot(face) > 0:
        nrm = -nrm
    n = sp.D("leaf")
    th = lf.get("T", 0.012) * H
    base = Vector(stem_pt)
    import bmesh
    bm = bmesh.new()
    top, bot, le, ri = [], [], [], []
    for k in range(n + 1):
        u = k / n
        # повнота: 0.9 — гострий «ланцет», 0.5 — круглий (flower_1)
        w = W * 0.5 * (math.sin(math.pi * min(1.0, u ** lf.get("shape", 0.8)))) ** lf.get("full", 0.8)
        if k == 0:
            w = W * 0.04
        spine = base + d * (L * u) + nrm * (lf.get("curl", 0.1) * L * u * u)
        f = lf.get("fold", 0.25) * w
        t = th * (1 - u * 0.7)
        top.append(bm.verts.new(spine + nrm * t))
        bot.append(bm.verts.new(spine - nrm * t))
        le.append(bm.verts.new(spine - wa * w + nrm * f))
        ri.append(bm.verts.new(spine + wa * w + nrm * f))
    tip = bm.verts.new(base + d * (L * 1.04) + nrm * (lf.get("curl", 0.1) * L))
    for k in range(n):
        bm.faces.new((le[k], le[k + 1], top[k + 1], top[k]))
        bm.faces.new((top[k], top[k + 1], ri[k + 1], ri[k]))
        bm.faces.new((ri[k], ri[k + 1], bot[k + 1], bot[k]))
        bm.faces.new((bot[k], bot[k + 1], le[k + 1], le[k]))
    for ring in ((le[n], top[n], ri[n]), (ri[n], bot[n], le[n])):
        bm.faces.new((ring[0], ring[1], tip))
        bm.faces.new((ring[1], ring[2], tip))
    bm.faces.new((le[0], top[0], ri[0], bot[0]))
    return sp.finish_bm(bm, name, mat)


def stem_points(P):
    H = P["H"]
    return [Vector((x * H, 0.0, z * H)) for x, z in P["stem"]["pts"]]


def point_at(pts, z):
    """Точка стебла на висоті z (м)."""
    for a, b in zip(pts, pts[1:]):
        if a.z <= z <= b.z:
            f = (z - a.z) / max(b.z - a.z, 1e-9)
            return a.lerp(b, f)
    return pts[-1] if z > pts[-1].z else pts[0]


def base(name, mat, P):
    H, b = P["H"], P["base"]
    r, h = b["r"] * H, b["h"] * H
    if b.get("style") == "facet":     # низька восьмигранна «таблетка» (flower_6)
        prof = [(0.0, h), (r * 0.82, h), (r, h * 0.55), (r * 0.96, 0.0), (0.0, 0.0)]
        ob = sp.lathe(name, mat, prof, b.get("seg", 8), rot0=math.pi / 8)
        sp.faceted(ob)
    else:                              # кругла тарілочка з комірцем біля стебла (flower_7)
        rs = P["stem"]["r"] * H
        prof = [(0.0, h * 1.9), (rs * 1.9, h * 1.9), (rs * 2.4, h * 1.2), (r * 0.85, h), (r, h * 0.6),
                (r * 0.98, 0.0), (0.0, 0.0)]
        ob = sp.lathe(name, mat, prof, sp.D("seg") + 4)
    return ob


def build(m, k, P):
    H = P["H"]
    c, R, nrm = head_frame(P)
    pts = stem_points(P)
    z_head = pts[-1].z
    z0 = P.get("base", {}).get("h", 0.0) * H * 0.5

    # Стебло — «body»: трубка по ламаній, тоншає догори; кінець ховається в голівці.
    st = sp.tube("body", m["stem"], [tuple(p) for p in pts], P["stem"]["r"] * H,
                 taper=[1.0 - 0.3 * i / (len(pts) - 1) for i in range(len(pts))])
    st = sp.curve_to_mesh(st)
    st.name = "body"
    set_rigw(st, fn=lambda p: max(0.0, min(1.0, (p.z - z0) / max(z_head - z0, 1e-6))))

    h = P["head"]
    for i in range(h["n"]):
        pt = petal("petal%d" % i, m["petal"], P, i, c, R)
        if h.get("petal_facets"):   # гранчасті пелюстки (flower_6)
            sp.faceted(pt)
        set_rigw(pt, 2.0)
    set_rigw(center("center", m["center"], P, c, R, nrm), 2.0)
    if h.get("calyx"):   # зелена «чашечка» під голівкою
        cx = sp.blob("calyx", m["stem"], (0, 0, 0), h["calyx"] * H, scale=(1, 1, 0.7))
        bpy.context.view_layer.update()
        cx.matrix_world = Matrix.Translation(c - nrm * h["calyx"] * H * 0.4) @ R.to_4x4() @ cx.matrix_world
        set_rigw(cx, 2.0)

    for j, lf in enumerate(P.get("leaves", [])):
        if lf.get("low_skip") and sp.D("seg") < 12:
            continue   # у найпростішому — без тоненьких гілочок
        zz = lf["z"] * H
        sp_ = point_at(pts, zz) + Vector((lf.get("dx", 0.0) * H, lf.get("dy", 0.0) * H, 0.0))   # травинки — не з одної точки
        mat = m["leaf2"] if lf.get("mat") == "leaf2" else m["leaf"]
        ob = leaf("leaf%d" % j, mat, P, lf, sp_)
        if lf.get("grass"):   # травинка з землі гнеться сама, як нижня частина стебла
            set_rigw(ob, fn=lambda p: max(0.0, min(0.6, (p.z - z0) / max(z_head - z0, 1e-6))))
        else:
            set_rigw(ob, max(0.0, min(1.0, (zz - z0) / max(z_head - z0, 1e-6))))

    if P.get("base"):
        set_rigw(base("base", m["base"], P), -1.0)

    # Кістки йдуть по стеблу: середина стебла — по висоті посередині.
    zm = z0 + (z_head - z0) * 0.5
    mid = point_at(pts, zm)
    root_top = Vector((pts[0].x, 0.0, max(z0, 0.02 * H)))
    kit.add_rig = add_rig_weighted
    return {"rig": [
        ("root", (pts[0].x, 0.0, 0.0), tuple(root_top), None),
        ("stem0", tuple(root_top), tuple(mid), "root"),
        ("stem1", tuple(mid), tuple(pts[-1]), "stem0"),
        ("head", tuple(pts[-1]), tuple(pts[-1] + nrm * 0.12 * H + Vector((0, 0, 0.05 * H))), "stem1"),
    ]}


def _smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def weights(s):
    """Ваги кісток за числом s (див. докстрінг модуля)."""
    if s < -0.5:
        return {"root": 1.0}
    if s >= 1.5:
        return {"head": 1.0}
    w1 = _smooth(0.3, 0.7, s)          # плавний перехід stem0 → stem1 посередині стебла
    out = {"stem0": 1.0 - w1, "stem1": w1}
    if s < 0.12:                       # біля самої землі стебло тримається за корінь
        f = s / 0.12
        out = {"root": 1.0 - f, "stem0": f * out["stem0"], "stem1": f * out["stem1"]}
    return {k_: v for k_, v in out.items() if v > 1e-4}


def add_rig_weighted(obj, bones):
    """Як kit.add_rig, але ваги — з атрибута rigw (див. докстрінг модуля), а не теплові."""
    arm_data = bpy.data.armatures.new("rig")
    arm = bpy.data.objects.new("rig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    made = {}
    for name, head, tail, parent in bones:
        b = arm_data.edit_bones.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = made[parent]
            b.use_connect = True
        made[name] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    at = obj.data.attributes.get("rigw")
    if at is None:
        raise RuntimeError("немає атрибута rigw: ваги скелета квітки нема з чого рахувати")
    vals = [d.value for d in at.data]
    groups = {name: obj.vertex_groups.new(name=name) for name, *_ in bones}
    for i, s in enumerate(vals):
        for bn, w in weights(s).items():
            groups[bn].add([i], w, "REPLACE")
    obj.data.attributes.remove(at)
    obj.parent = arm
    md = obj.modifiers.new("rig", "ARMATURE")
    md.object = arm
    return arm
