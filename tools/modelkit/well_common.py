# -*- coding: utf-8 -*-
"""Родина криниць (well_1..well_4) — спільні заготовки, плюс загальна геометрія, якою
користуються й млини (mill_common):

  lathe        — тіло обертання за профілем [(r, z), …] (вежа, дах, відро, кільце);
  ring_block   — брила-сектор кільця (вигнута цеглина зрубу, камінь цоколя, клинчак арки);
  ring_wall    — кам'яний зруб рядами брил уперебій, з вирізом «перед дверима» за потреби;
  post, beam   — дерев'яні стовп і брус (фаска, волокно — матеріалом);
  bucket       — відро: зрізаний конус із обідками й дужкою;
  rope         — мотузка ламаною лінією (трубка, кручена матеріалом).

Криниця — це зруб (ring_wall) + два стовпи + брус-ворот + дашок + відро на мотузці. Дах у
кожної свій (двосхилий із дощок, односхилий, з колодою-гребенем), тож він — у файлі моделі
з допоміжною plank_roof звідси. Перед — −Y (Blender)."""
import math
import random

import bpy
import bmesh
from mathutils import Matrix, Vector

import kit
from kit import box, cyl, soften


def harden(obs):
    """Фаска з «жорсткими» нормалями (bevel.harden_normals): у бруска з фаскою в один сегмент
    після згладжування вся грань ставала «подушкою» — нормалі кутів тягнули її тінь. З жорсткими
    нормалями грань плоска, а заокруглений лише край, як у пластиліні, — без зайвих сегментів."""
    for ob in obs:
        bv = ob.modifiers.get("bevel")
        if bv is not None:
            bv.harden_normals = True
    return obs


def lathe(name, mat, prof, segs, a0=0.0, a1=2 * math.pi):
    """Тіло обертання навколо осі Z: prof — [(r, z), …] знизу догори. Кінці з r > 0
    закриваються гранню, з r == 0 — сходяться в точку. Нормалі — назовні."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    full = abs(a1 - a0 - 2 * math.pi) < 1e-6
    ns = segs if full else segs + 1
    rows = []
    for r, z in prof:
        if r <= 1e-6:
            rows.append([bm.verts.new((0.0, 0.0, z))])
            continue
        rows.append([bm.verts.new((r * math.cos(a0 + (a1 - a0) * i / segs),
                                   r * math.sin(a0 + (a1 - a0) * i / segs), z)) for i in range(ns)])
    for ra, rb in zip(rows, rows[1:]):
        for i in range(ns if full else ns - 1):
            j = (i + 1) % ns
            if len(ra) == 1 and len(rb) == 1:
                continue
            if len(ra) == 1:
                bm.faces.new((ra[0], rb[i], rb[j]))
            elif len(rb) == 1:
                bm.faces.new((ra[i], ra[j], rb[0]))
            else:
                bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    if full:
        for row in (rows[0], rows[-1]):
            if len(row) > 2:
                bm.faces.new(row)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def ring_block(name, mat, a0, a1, r_in, r_out, z0, z1, segs=2, taper=0.0):
    """Брила — сектор кільця від кута a0 до a1 (0 — напрям −Y, «перед», кути — за
    годинниковою, якщо дивитись згори), радіуси r_in..r_out, висота z0..z1. taper — на скільки
    зовнішній радіус угорі менший, ніж унизу (брила на конічній вежі)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    def ang(t):
        return a0 + (a1 - a0) * t
    V = {}
    for side, (r0, r1) in (("i", (r_in, r_in - taper)), ("o", (r_out, r_out - taper))):
        for lvl, z in (("b", z0), ("t", z1)):
            rr = r0 if lvl == "b" else r1
            V[side + lvl] = [bm.verts.new((rr * math.sin(ang(i / segs)), -rr * math.cos(ang(i / segs)), z))
                             for i in range(segs + 1)]
    for i in range(segs):
        j = i + 1
        bm.faces.new((V["ob"][i], V["ob"][j], V["ot"][j], V["ot"][i]))
        bm.faces.new((V["ib"][j], V["ib"][i], V["it"][i], V["it"][j]))
        bm.faces.new((V["ot"][i], V["ot"][j], V["it"][j], V["it"][i]))
        bm.faces.new((V["ib"][i], V["ib"][j], V["ob"][j], V["ob"][i]))
    bm.faces.new((V["ib"][0], V["ob"][0], V["ot"][0], V["it"][0]))
    bm.faces.new((V["ob"][segs], V["ib"][segs], V["it"][segs], V["ot"][segs]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)


def ring_wall(name, mat, k, z0, z1, rows, per, r_in, r_out, gap=0.012, seed=1, skip=None,
              bevel=0.03, taper=0.0, jitter=0.25, stagger=0.5, rot0=0.0, bulge=0.0, bev_segs=1, arc_segs=None, hard=False):
    """Зруб рядами брил уперебій: rows рядів по per брил між z0 і z1. skip(a_mid, row) → True —
    брилу пропустити (двері). Брили трохи різні завширшки й заввишки (jitter), між ними шов gap,
    крізь який видно темніше осердя (його ставить модель). bulge — брила виступає назовні на
    стільки посередині ряду (круглий «подушковий» камінь). taper — звуження зовнішнього радіуса
    на весь зруб (конічна вежа)."""
    rnd = random.Random(seed)
    hrow = (z1 - z0) / rows
    segs = arc_segs or (2 if k.DET["bev"] >= 2 else 1)
    made = []
    step = 2 * math.pi / per
    for ri in range(rows):
        zb = z0 + ri * hrow
        zt = zb + hrow - gap
        tb = taper * (zb - z0) / max(z1 - z0, 1e-6)
        tt = taper * (zt - z0) / max(z1 - z0, 1e-6)
        edges = []
        acc = rot0 + stagger * step * (ri % 2)
        for i in range(per):
            w = step * (1.0 + rnd.uniform(-jitter, jitter) * 0.6)
            edges.append(acc)
            acc += w
        scale = 2 * math.pi / (acc - edges[0])
        edges = [edges[0] + (e - edges[0]) * scale for e in edges] + [edges[0] + 2 * math.pi]
        for i in range(per):
            a0 = edges[i] + gap / r_out * 0.5
            a1 = edges[i + 1] - gap / r_out * 0.5
            am = (a0 + a1) * 0.5
            if skip and skip(math.atan2(math.sin(am), math.cos(am)), ri, zb, zt):
                continue
            ro = r_out - tb + bulge * rnd.uniform(0.6, 1.0)
            b = ring_block("%s_%d_%d" % (name, ri, i), mat, a0, a1, r_in, ro, zb, zt, segs, tt - tb)
            # фаска в один сегмент: брил десятки, і круглий скіс на кожній з'їдав половину бюджету
            soften(b, min(bevel, hrow * 0.3), min(bev_segs, k.DET["bev"]))
            if hard:
                harden([b])
            made.append(b)
    return made


def post(name, mat, c, size, k, bev=0.02):
    ob = box(name, mat, c, size)
    soften(ob, bev, min(2, k.DET["bev"]))
    return ob


def beam(name, mat, p0, p1, w, h, k, bev=0.015):
    """Брус між точками p0 і p1 (перетин w × h)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    ob = box(name, mat, (0, 0, 0), (w, h, d.length))
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.matrix_world = Matrix.Translation((p0 + p1) * 0.5) @ q.to_matrix().to_4x4()
    soften(ob, bev, min(2, k.DET["bev"]))
    return ob


def log(name, mat, p0, p1, r, k, verts=None):
    """Кругла колода між p0 і p1 (ворот, гребінь даху)."""
    p0, p1 = Vector(p0), Vector(p1)
    d = p1 - p0
    ob = cyl(name, mat, (0, 0, 0), r, d.length, verts=verts or max(8, k.DET["cyl"] - 4))
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    ob.matrix_world = Matrix.Translation((p0 + p1) * 0.5) @ q.to_matrix().to_4x4()
    soften(ob, min(0.02, r * 0.3), min(2, k.DET["bev"]))
    return ob


def bucket(name, m, k, c, r_bot, r_top, h, handle=True, hoops=("hoop",), body="bucket", hoop_z=(0.2, 0.8)):
    """Відро: зрізаний конус (дно вужче), обідки, дужка-півкільце. c — центр дна."""
    x, y, z = c
    segs = max(10, k.DET["cyl"] - 6)
    t = 0.012
    prof = [(0.0, 0.0), (r_bot, 0.0), (r_top, h), (r_top - t, h), (r_bot - t * 1.2, t * 2), (0.0, t * 2)]
    b = lathe(name, m[body], prof, segs)
    b.location = (x, y, z)
    soften(b, 0.006, min(2, k.DET["bev"]))
    made = [b]
    ts, tr_ = k.DET["tor"]
    for i, f in enumerate(hoop_z):
        rr = r_bot + (r_top - r_bot) * f
        bpy.ops.mesh.primitive_torus_add(major_radius=rr + 0.003, minor_radius=0.011,
                                         major_segments=max(10, ts - 8), minor_segments=max(3, tr_ - 4),
                                         location=(x, y, z + h * f))
        hp = bpy.context.active_object
        hp.name = name + "_hoop%d" % i
        hp.data.materials.append(m[hoops[i % len(hoops)]])
        made.append(hp)
    if handle:
        made.append(arc_wire(name + "_handle", m.get("handle", m[body]), (x, y, z + h), r_top * 0.95, r_top * 1.1, 0.008, k))
    return made


def arc_wire(name, mat, c, rx, rz, thick, k, a0=0.0, a1=math.pi):
    """Дужка — півеліпс у площині XZ над точкою c."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = max(0, k.DET["tube"] - 1)
    sp = cu.splines.new("POLY")
    n = max(4, k.DET["arch"])
    sp.points.add(n)
    for i, p in enumerate(sp.points):
        a = a0 + (a1 - a0) * i / n
        p.co = (c[0] + rx * math.cos(a), c[1], c[2] + rz * math.sin(a), 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def rope(name, mat, pts, thick, k):
    """Мотузка — трубка ламаною через pts."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = thick
    cu.bevel_resolution = max(0, k.DET["tube"] - 1)
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (q[0], q[1], q[2], 1.0)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    return ob


def plank_slope(name, mat, k, x0, x1, eave, ridge, n, thick, overlap=0.0, gap=0.004, bev=0.012, rnd=None):
    """Схил даху з n дощок уздовж X (від x0 до x1), кожна від лінії звису eave=(y, z) до
    гребеня ridge=(y, z). Дошки — окремі бруски з фаскою й трохи різною довжиною (rnd), тож
    між ними темний шов, як на малюнках. Повертає список брусків."""
    ey, ez = eave
    ry, rz = ridge
    dy, dz = ry - ey, rz - ez
    L = math.hypot(dy, dz)
    ang = math.atan2(dz, dy)
    w = (x1 - x0) / n
    made = []
    for i in range(n):
        xc = x0 + w * (i + 0.5)
        ext = rnd.uniform(-0.02, 0.02) if rnd else 0.0
        ob = box("%s_%d" % (name, i), mat, (0, 0, 0), (w - gap, L + overlap + ext, thick))
        # доска лежить уздовж локальної Y, нахилена на ang навколо X
        c = Vector((xc, ey + dy * 0.5, ez + dz * 0.5))
        nrm = Vector((0.0, -math.sin(ang), math.cos(ang)))
        c += nrm * (thick * 0.5)
        ob.matrix_world = Matrix.Translation(c) @ Matrix.Rotation(ang, 4, "X")
        soften(ob, bev, min(2, k.DET["bev"]))
        made.append(ob)
    return made


# ---------------------------------------------------------------------------------------
# Криниця за спекою. На відміну від млинів, розміри тут — одразу в одиницях Blender: криниці
# на малюнках зняті згори (el 15-28°), і пікселі малюнка не переводяться в висоти лінійно.
# Підгонка — порівнянням рамок і рядків масок (див. звіт), а не «на око».

def _frame(E, U, sgn):
    """Базис схилу: X — уздовж гребеня (sgn задає напрям, щоб базис був правим і нормаль W
    дивилась назовні-вгору), U — угору по схилу, W = X × U."""
    X = Vector((sgn, 0.0, 0.0))
    W = X.cross(U)
    if W.z < 0:
        X = -X
        W = X.cross(U)
    B = Matrix((X, U, W)).transposed().to_4x4()
    return Matrix.Translation(E) @ B


def roof_courses(name, mat, k, half_x, depth, ze, zr, n, th, lift=None, shingles=1, gap=0.006, seed=2,
                 overlap=0.03, flare=0.0, bev=0.012, y0=0.0, bev_segs=1):
    """Двосхилий дах із рядів дощок (courses): на кожному схилі n рядів від звису до гребеня,
    кожен ряд нижнім краєм трохи піднятий над нижчим (lift) — як внахльост, звідси темні
    «сходинки» на малюнках. shingles > 1 — ряд розбитий на гонтини з швами й трохи різної
    довжини. flare > 0 — нижні ряди положистіші (загнуті догори звиси, well_2). y0 — зсув
    гребеня по Y. Повертає список брусків."""
    rnd = random.Random(seed)
    lift = th * 0.8 if lift is None else lift
    made = []
    for side in (-1, 1):
        E = Vector((0.0, y0 + side * depth, ze))
        Rr = Vector((0.0, y0, zr))
        L = (Rr - E).length
        U = (Rr - E).normalized()
        M = _frame(E, U, 1.0)
        for i in range(n):
            s0 = i * L / n - (overlap if i else 0.0)
            s1 = (i + 1) * L / n + (0.02 if i == n - 1 else 0.0)
            li = lift if i < n - 1 else lift * 0.5
            fl = flare * (1.0 - i / max(n - 1, 1)) ** 2
            d = math.atan2(li, s1 - s0) + fl
            cu, cw = (s0 + s1) / 2, th / 2 + li / 2
            ln = math.hypot(s1 - s0, li)
            pcs = shingles if shingles > 1 else 1
            w = 2 * half_x / pcs
            off = (i % 2) * w * 0.5 if pcs > 1 else 0.0
            xs = []
            x = -half_x - off
            while x < half_x - 1e-6:
                a, b = max(x, -half_x), min(x + w, half_x)
                if b - a > w * 0.25:
                    xs.append((a, b))
                x += w
            for j, (a, b) in enumerate(xs):
                ext = rnd.uniform(-0.015, 0.015) if pcs > 1 else 0.0
                ob = box("%s_%d_%d_%d" % (name, side + 1, i, j), mat, (0, 0, 0),
                         (b - a - (gap if pcs > 1 else 0.0), ln + ext, th))
                loc = Matrix.Translation(((a + b) / 2 * (1 if M.col[0].x > 0 else -1), cu, cw))
                ob.matrix_world = M @ loc @ Matrix.Rotation(-d, 4, "X")
                # фаска в один сегмент: гонтин на дасі десятки
                soften(ob, bev, min(bev_segs, k.DET["bev"]))
                harden([ob])
                made.append(ob)
    return made


def build_well(m, k, sp):
    """Криниця за спекою sp (див. well_4.py): зруб, вода, стовпи, ворот, мотузка, відро, дах."""
    hi = k.DET["bev"] >= 3
    mid = k.DET["bev"] == 2
    seg = max(12, k.DET["cyl"] + 4)
    rg = sp["ring"]
    Ro, Ri, H = rg["r_out"], rg["r_in"], rg["h"]
    cap_h = rg.get("cap_h", 0.0)
    # Осердя: темна труба за брилами (видно в швах) і дно-вода. «body» — вона: стоїть у (0,0,0).
    core = lathe("body", m["core"], [(Ri + 0.015, 0.0), (Ro - rg.get("depth", 0.08), 0.0),
                                     (Ro - rg.get("depth", 0.08), H - cap_h), (Ri + 0.015, H - cap_h)], seg)
    rows = rg["rows"] if (hi or mid) else max(2, rg["rows"] - 1)
    per = rg["per"] if hi else (max(7, rg["per"] - 2) if mid else max(6, rg["per"] - 4))
    ring_wall("stone", m["stone"], k, 0.0, H - cap_h, rows, per, Ri, Ro, gap=rg.get("gap", 0.018),
              seed=rg.get("seed", 1), bevel=rg.get("bevel", 0.035), jitter=rg.get("jitter", 0.3),
              bulge=rg.get("bulge", 0.0), bev_segs=rg.get("bev_segs", 1), arc_segs=rg.get("arc_segs"),
              hard=rg.get("hard", True))
    if cap_h > 0:
        cper = rg.get("cap_per", per) if hi else max(6, rg.get("cap_per", per) - 2)
        ring_wall("cap", m.get("cap", m["stone"]), k, H - cap_h, H, 1, cper, Ri - 0.02, Ro + rg.get("cap_out", 0.02),
                  gap=rg.get("gap", 0.018), seed=rg.get("seed", 1) + 7, bevel=rg.get("cap_bevel", 0.03),
                  jitter=0.25, bev_segs=rg.get("bev_segs", 1), arc_segs=rg.get("arc_segs"), rot0=0.13,
                  hard=rg.get("hard", True))
    # вода — диск трохи нижче вінця
    wz = sp.get("water_z", H - 0.1)
    cyl("water", m["water"], (0, 0, wz - 0.02), Ri + 0.01, 0.04, verts=seg)

    # стовпи
    ps = sp["posts"]
    px_, py_, pw, ptop = ps["x"], ps.get("y", 0.0), ps["w"], ps["top"]
    for sx in (-1, 1):
        post("post%d" % sx, m["wood"], (sx * px_, py_, (H - 0.02 + ptop) / 2), (pw, ps.get("d", pw), ptop - H + 0.02), k,
             bev=0.02)
    # укоси між стовпом і верхнім брусом (well_2)
    if ps.get("braces"):
        bz, bl = ps["braces"]
        for sx in (-1, 1):
            beam("brace%d" % sx, m["wood"], (sx * px_, py_, ptop - bz), (sx * (px_ - bl), py_, ptop - 0.03),
                 pw * 0.55, pw * 0.5, k)
    # верхні бруси вздовж гребеня (на стовпах, під дахом)
    for tp in sp.get("plates", []):
        y, z, hx, w, h = tp
        beam("plate%.2f" % y, m["wood"], (-hx, py_ + y, z), (hx, py_ + y, z), w, h, k)

    # ворот / поперечка з мотузкою (без поперечки — мотузка від верхнього бруса, well_2)
    cb = sp.get("crossbar") or dict(z=sp["plates"][0][1] - sp["plates"][0][4] / 2, r=0.0, half=0.0, style="none")
    cz, cr, chx = cb["z"], cb["r"], cb["half"]
    if cb.get("style", "log") == "none":
        pass
    elif cb.get("style", "log") == "log":
        log("crossbar", m["wood2"] if "wood2" in m else m["wood"], (-chx, py_, cz), (chx, py_, cz), cr, k)
    else:
        beam("crossbar", m["wood2"] if "wood2" in m else m["wood"], (-chx, py_, cz), (chx, py_, cz), cr * 2, cr * 2, k)
    if cb.get("hook"):
        # гачок-ґуля посередині поперечки, з неї звисає мотузка (well_3)
        log("cb_hook", m["wood2"] if "wood2" in m else m["wood"], (0.0, py_ - cb["hook"], cz),
            (0.0, py_ + cb["hook"], cz), cb["hook"] * 0.9, k)
    for sx in (-1, 1):
        if cb.get("knobs"):
            log("cb_knob%d" % sx, m["wood2"] if "wood2" in m else m["wood"], (sx * (chx - 0.05), py_, cz),
                (sx * (chx + 0.01), py_, cz), cr * 1.35, k)
    bk = sp["bucket"]
    btop = bk["z_top"]
    # мотузка: кілька витків на вороті (бублики) і пряма до дужки
    coil = cb.get("coil", 0)
    if coil:
        ts, tr_ = k.DET["tor"]
        for i in range(coil if hi else max(1, coil - 1)):
            bpy.ops.mesh.primitive_torus_add(major_radius=cr + 0.012, minor_radius=0.014,
                                             major_segments=max(8, ts - 8), minor_segments=max(3, tr_ - 4),
                                             location=((i - (coil - 1) / 2) * 0.03, py_, cz), rotation=(0, math.pi / 2, 0))
            t = bpy.context.active_object
            t.name = "coil%d" % i
            t.data.materials.append(m["rope"])
    hook_z = btop + bk["h"] * 0.0 + bk["r_top"] * 1.1
    rope("rope", m["rope"], [(0.0, py_, cz - cr), (0.0, py_, hook_z)], sp.get("rope_r", 0.012), k)
    bucket("bucket", m, k, (0.0, py_, btop - bk["h"]), bk["r_bot"], bk["r_top"], bk["h"],
           hoops=bk.get("hoops", ("hoop",)), hoop_z=bk.get("hoop_z", (0.2, 0.8)))

    # дах (будується з гребенем уздовж X; axis="y" — повертається на 90°, щипцем до камери)
    rf = sp["roof"]
    before = set(bpy.data.objects.keys())
    roof_courses("roof", m["roof"], k, rf["half_x"], rf["depth"], rf["ze"], rf["zr"],
                 rf["n"] if (hi or mid) else max(2, rf["n"] - 1), rf["th"], lift=rf.get("lift"),
                 shingles=rf.get("shingles", 1) if hi else max(1, rf.get("shingles", 1) // 2),
                 seed=rf.get("seed", 2), flare=rf.get("flare", 0.0), y0=rf.get("y0", py_))
    if rf.get("gable"):
        gx, gd, gz0, gz1 = rf["gable"]
        for sx in (-1, 1):
            prism_x("gable%d" % sx, m.get("gable", m["roof"]), sx * gx, [(-gd, gz0), (gd, gz0), (0.0, gz1)], 0.03,
                    rf.get("y0", py_))
    if rf.get("ridge"):
        rr, rhx = rf["ridge"]
        rz = rf["zr"] + rf["th"] + rr * 0.5
        log("ridge", m.get("ridge", m["wood"]), (-rhx, rf.get("y0", py_), rz), (rhx, rf.get("y0", py_), rz), rr, k,
            verts=max(8, k.DET["cyl"] - 2))
        if rf.get("ridge_end"):
            # торець колоди — світліший кружок із «річницею» (well_1, well_2)
            for sx in rf["ridge_end"]:
                cyl("ridge_end%d" % sx, m["ring"], (sx * (rhx + 0.004), rf.get("y0", py_), rz), rr * 0.8, 0.012,
                    rot=(0, math.pi / 2, 0), verts=max(8, k.DET["cyl"] - 2))
    if rf.get("truss"):
        # каркас щипця: затяжка, стояк під гребенем і дві крокви — видно під звисом (well_1, well_2)
        tx, tw = rf["truss"]
        y0 = rf.get("y0", py_)
        for sx in (-1, 1):
            x = sx * tx
            beam("truss_tie%d" % sx, m["wood"], (x, y0 - rf["depth"] * 0.75, rf["ze"] - 0.02),
                 (x, y0 + rf["depth"] * 0.75, rf["ze"] - 0.02), tw, tw, k)
            beam("truss_king%d" % sx, m["wood"], (x, y0, rf["ze"] - 0.02), (x, y0, rf["zr"] - 0.02), tw, tw, k)
            for sy in (-1, 1):
                beam("truss_raf%d_%d" % (sx, sy), m["wood"], (x, y0 + sy * rf["depth"] * 0.92, rf["ze"] + 0.01),
                     (x, y0, rf["zr"] - 0.01), tw, tw * 0.9, k)
    if rf.get("axis") == "y":
        R90 = Matrix.Translation((0.0, py_, 0.0)) @ Matrix.Rotation(math.pi / 2, 4, "Z") @ Matrix.Translation((0.0, -py_, 0.0))
        for name in set(bpy.data.objects.keys()) - before:
            ob = bpy.data.objects[name]
            ob.matrix_world = R90 @ ob.matrix_world
    return {}


def prism_x(name, mat, x, prof, thick, y0=0.0):
    """Призма з профілю в площині YZ (y, z), товщиною thick по X, у точці x."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    a = [bm.verts.new((x - thick / 2, y0 + y, z)) for y, z in prof]
    b = [bm.verts.new((x + thick / 2, y0 + y, z)) for y, z in prof]
    bm.faces.new(a)
    bm.faces.new(list(reversed(b)))
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(me)
    bm.free()
    return kit.link(me, name, mat)
