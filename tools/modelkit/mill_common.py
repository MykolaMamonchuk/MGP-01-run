# -*- coding: utf-8 -*-
"""Родина млинів (mill_2..mill_4) — один збирач build_mill за СПЕКОЮ в пікселях малюнка.

Спека — розміри, зняті з малюнка (1024², у пікселях: y — рядок, «half» — пів ширини), тож
підгонка під малюнок — це правка чисел, які можна перевірити лінійкою на самому малюнку, а не
«на око» в коді. S — одиниць Blender на піксель: однаковий для всіх млинів, щоб у грі вони були
одного масштабу.

Частини: цоколь (брили або гладке кільце), вежа (гладка або з брил), край даху + дах (профіль
обертання: прямий конус, «капелюх» із загнутими крисами, кулька на маківці), пасок під дахом
(з камінцями), вісь, крила — ОКРЕМА частина «sails» (part_sails__…) з маточиною, двері в арці
(гладка трубка або клинчаки-брили), вікно (диск, ілюмінатор із заклепками, кільця).

Площина крил ставиться автоматично перед найвиступнішим, що є в колі замаху крил (край даху,
пасок, вежа з вікном), з зазором SAIL_GAP; sail_gap() міряє справжній зазор за повний оберт по
вершинах і зупиняє збірку, якщо крила чіпляють модель."""
import math

import bpy
from mathutils import Matrix, Vector

import kit
from kit import arch_curve, arch_profile, box, cyl, prism, soften, sphere
from well_common import lathe, ring_block, ring_wall

S = 0.0033          # одиниць Blender на піксель малюнка
SAIL_GAP = 0.06     # бажаний зазор між задом крил і найближчим виступом


def mill_materials(k, extra=None):
    """Стандартні матеріали млина; ключі палітри — tower*, stone*, roof*, eave, sail*, hub*,
    door*, frame*, win*, latch, knob. extra — {назва: матеріал} понад стандарт."""
    P = kit.PAL
    def g(name, stops, z0, z1, j=0.2, sc=6.0):
        return k.mat_gradient(name, [(p, key) for p, key in stops if key in P], z0, z1, j, sc)
    m = {
        "tower": g("tower", [(0.0, "tower_lo"), (0.45, "tower"), (1.0, "tower_hi")], 0.1, 1.3, 0.3, 4.0),
        "stone": g("stone", [(0.0, "stone_lo"), (0.55, "stone"), (1.0, "stone_hi")], 0.0, 0.45, 0.45, 9.0),
        "core": g("core", [(0.0, "core"), (1.0, "core")], 0.0, 1.0, 0.0),
        "roof": g("roof", [(0.0, "roof_lo"), (0.35, "roof"), (1.0, "roof_hi")], 1.1, 2.0, 0.2, 5.0),
        "eave": g("eave", [(0.0, "eave"), (1.0, "roof_lo")], 1.05, 1.3, 0.1, 6.0),
        "sail": g("sail", [(0.0, "sail_lo"), (0.5, "sail"), (1.0, "sail_hi")], 0.4, 2.3, 0.35, 9.0),
        "hub": g("hub", [(0.0, "hub"), (1.0, "hub_hi")], 1.2, 1.6, 0.1, 8.0),
        "door": k.mat_door("door"),
        "frame": g("frame", [(0.0, "frame_lo"), (0.5, "frame"), (1.0, "frame_hi")], 0.0, 0.7, 0.3, 9.0),
        "win": g("win", [(0.0, "win"), (1.0, "win_hi")], 0.0, 1.0, 0.05),
        "latch": g("latch", [(0.0, "latch"), (1.0, "latch")], 0.0, 1.0, 0.0),
        "knob": g("knob", [(0.0, "knob"), (1.0, "knob")], 0.0, 1.0, 0.0),
    }
    if "glass" in P:
        m["glass"] = k.mat_glass("glass")
    m.update(extra or {})
    return m


def lattice_blade(name, mat, k, hub, ang, length, width, start=0.1, rows=5, cols=2,
                  rail=0.032, rung=0.024, thick=0.03, over=0.02, spar=0.0, caps=None, cap_mat=None,
                  rung_bevel=True):
    """Ґратчасте крило від маточини вздовж +Z, повернуте на ang навколо осі крил (−Y).
    cols — клітинок завширшки (2 — із середнім поздовжнім брусом), rows — клітинок уздовж;
    поперечки виступають за бічні бруси на over. spar > 0 — брус такої ширини від маточини до
    ґратки (і вздовж неї, по середині). caps=(ширина, товщина) — поперечні бруси на обох кінцях
    ґратки (mill_4). Скіс — фаска в один сегмент: круглий скіс на сорока брусках з'їв би бюджет."""
    L = length - start
    zc = start + L / 2
    made = []
    for i in range(cols + 1):
        x = -width / 2 + width * i / cols
        edge = i in (0, cols)
        made.append(box(name + "_rail%d" % i, mat, (x, 0.0, zc), (rail if edge else rung, thick, L)))
    for i in range(rows + 1):
        z = start + rail * 0.5 + (L - rail) * i / rows
        made.append(box(name + "_rung%d" % i, mat, (0.0, 0.0, z), (width + 2 * over, thick * 0.8, rung)))
    if spar > 0:
        made.append(box(name + "_spar", mat, (0.0, 0.0, (start + 0.02) / 2), (spar, thick, start + 0.02)))
    if caps:
        cw, ct = caps
        for z in (start + ct / 2, length - ct / 2):
            made.append(box(name + "_cap%.2f" % z, cap_mat or mat, (0.0, -thick * 0.15, z), (cw, thick * 1.3, ct)))
    for ob in made:
        # тонкі поперечки густої драбинки (mill_4) — без фаски: її там не видно, а це ~30
        # трикутників на кожну з сорока
        if k.DET["bev"] >= 2 and (rung_bevel or "_rung" not in ob.name):
            soften(ob, 0.007, 1)
    rot = Matrix.Translation(Vector(hub)) @ Matrix.Rotation(ang, 4, "Y")
    for ob in made:
        ob.matrix_world = rot @ ob.matrix_world
    return made


def sail_gap(hub, exclude=("axle",)):
    """Зазор крил до решти моделі за повний оберт: крила крутяться в площині XZ навколо осі
    через hub, тож їх замітає диск радіуса R (найдальша вершина крил від осі). Зазор = найближча
    до камери (найменша y) вершина решти моделі в межах цього диска мінус найзадніша (найбільша
    y) вершина крил. Від'ємне — крила проходять крізь стіну, і збірка зупиняється."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    hx, hy, hz = hub
    sails, rest = [], []
    for ob in bpy.data.objects:
        if ob.type not in ("MESH", "CURVE") or any(ob.name.startswith(e) for e in exclude):
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        pts = [ob.matrix_world @ v.co for v in me.vertices]
        ev.to_mesh_clear()
        (sails if ob.name.startswith("part_sails__") else rest).extend(pts)
    R = max(math.hypot(p.x - hx, p.z - hz) for p in sails)
    back = max(p.y for p in sails)
    near = [p for p in rest if math.hypot(p.x - hx, p.z - hz) <= R + 0.01]
    front = min(p.y for p in near)
    who = min(near, key=lambda p: p.y)
    gap = front - back
    print("ЗАЗОР КРИЛ: %.3f (зад крил y=%.3f, радіус замаху %.3f, найближче в колі замаху y=%.3f у x=%.2f z=%.2f)"
          % (gap, back, R, front, who.x, who.z))
    if gap <= 0.0:
        raise RuntimeError("крила за оберт проходять крізь модель: зазор %.3f" % gap)
    return gap


def front_y(hx, hz, radius, exclude=("axle", "part_")):
    """Найменша y (найближче до камери) серед вершин моделі в межах кола radius навколо осі
    (hx, hz) — те, що крила могли б зачепити."""
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    best = 0.0
    for ob in bpy.data.objects:
        if ob.type not in ("MESH", "CURVE") or any(ob.name.startswith(e) for e in exclude):
            continue
        ev = ob.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            p = ob.matrix_world @ v.co
            if math.hypot(p.x - hx, p.z - hz) <= radius:
                best = min(best, p.y)
        ev.to_mesh_clear()
    return best


def build_mill(m, k, sp):
    """Зібрати млин за спекою sp (див. mill_2.py). Повертає {"parts": {"sails": HUB}}."""
    G = sp["ground"]
    def Z(y):
        return (G - y) * S
    def R(half):
        return half * S
    seg = max(12, k.DET["cyl"] + 4)
    hi = k.DET["bev"] >= 3
    mid = k.DET["bev"] == 2

    # ---- вежа («body»): профіль обертання ----
    tw = sp["tower"]
    z_t0, z_t1 = 0.0, Z(tw["top"]) + 0.03
    r_t0, r_t1 = R(tw["bottom_half"]), R(tw["top_half"])
    def tower_r(z):
        f = (z - Z(tw.get("bottom", G))) / max(z_t1 - Z(tw.get("bottom", G)), 1e-6)
        return r_t0 + (r_t1 - r_t0) * max(0.0, min(1.0, f))
    # під брилами (mill_4) осердя майже не видно — йому вистачає половини сегментів і без скосу
    body = lathe("body", m["tower"], [(r_t0, z_t0), (r_t0, Z(tw.get("bottom", G))), (r_t1, z_t1), (0.0, z_t1)],
                 seg // 2 if tw.get("blocks") else seg)
    if not tw.get("blocks"):
        soften(body, 0.03)
    front = {"r": tower_r}           # зовнішній радіус фасаду на висоті z (для дверей і вікна)

    # вежа з брил (mill_4): ряди вигнутих брил поверх гладкого осердя
    if tw.get("blocks"):
        bl = tw["blocks"]
        rows = bl["rows"] if hi else (max(3, bl["rows"] - 2) if mid else 3)
        per = bl["per"] if hi else (max(6, bl["per"] - 2) if mid else 6)
        z0b, z1b = Z(tw.get("bottom", G)), Z(tw["top"])
        t = R(bl.get("depth", 12))
        dr_ = sp["door"]
        d_top = Z(dr_["top"]) + R(dr_.get("frame_w", 16)) * 0.5
        d_ang = math.asin(min(0.99, R(dr_["half"] + dr_.get("frame_w", 16) * 0.5) / r_t0))
        # брили за дверима й аркою не видно — їх і не ставимо
        skip_t = lambda a, ri, zb, zt: zt < d_top and abs(a) < d_ang
        ring_wall("tblock", m["tower"], k, z0b, z1b, rows, per, r_t0 - t, r_t0 + t * 0.4, gap=0.014,
                  seed=bl.get("seed", 3), bevel=0.035, taper=r_t0 - r_t1, jitter=0.35, bulge=t * 0.3,
                  skip=skip_t, arc_segs=bl.get("arc_segs", 1))
        old = front["r"]
        front["r"] = lambda z, old=old, t=t: old(z) + t * 0.7

    # ---- цоколь ----
    pl = sp["plinth"]
    z_p1 = Z(pl["top"])
    r_p = R(pl["half"])
    door = sp["door"]
    d_half = R(door["half"] + door.get("frame_w", 16))
    if pl["style"] == "blocks":
        cyl("plinth_core", m["core"], (0, 0, z_p1 * 0.5), r_p - R(pl.get("depth", 30)) * 0.6, z_p1, verts=seg)
        rows = pl["rows"] if (hi or mid) else 1
        per = pl["per"] if hi else (max(7, pl["per"] - 3) if mid else 7)
        skip = lambda a, ri, zb, zt: abs(a) < math.asin(min(0.99, d_half / r_p)) + 0.02
        ring_wall("plinth", m["stone"], k, 0.0, z_p1, rows, per, r_p - R(pl.get("depth", 30)), r_p,
                  gap=0.016, seed=pl.get("seed", 5), skip=skip, bevel=0.035, jitter=0.4, bulge=R(pl.get("bulge", 0)))
    else:   # гладке кільце (mill_4 — помаранчевий обідок)
        lathe("plinth", m["stone"], [(r_p - 0.015, 0.0), (r_p, 0.012), (r_p, z_p1 - 0.015), (r_p - 0.02, z_p1),
                                     (0.0, z_p1)], seg)
    old = front["r"]
    front["r"] = lambda z, old=old: max(old(z), r_p if z < z_p1 else 0.0)

    # ---- пасок під дахом (mill_4: темне кільце з камінцями) ----
    reach_r = 0.0
    if sp.get("band"):
        bd = sp["band"]
        zb0, zb1, rb = Z(bd["bottom"]), Z(bd["top"]), R(bd["half"])
        band = cyl("band", m["band"], (0, 0, (zb0 + zb1) / 2), rb, zb1 - zb0, verts=seg)
        soften(band, 0.015, min(2, k.DET["bev"]))
        n = bd.get("pebbles", 0)
        if n:
            n = n if hi else (max(10, n - 6) if mid else 10)
            pr = R(bd.get("pebble_r", 12))
            for i in range(n):
                a = 2 * math.pi * i / n
                bpy.ops.mesh.primitive_uv_sphere_add(radius=pr, segments=6, ring_count=4,
                                                     location=(rb * math.sin(a), -rb * math.cos(a), (zb0 + zb1) / 2))
                pb = bpy.context.active_object
                pb.name = "pebble%d" % i
                pb.scale = (1, 0.7, 1)
                pb.rotation_euler = (0, 0, a)
                pb.data.materials.append(m["pebble"])
            rb += pr * 0.7
        reach_r = max(reach_r, rb)

    # ---- край даху і дах (профіль обертання) ----
    rf = sp["roof"]
    prof = [(R(h), Z(y)) for h, y in rf["profile"]]
    roof = lathe("roof", m["roof"], prof, seg)
    soften(roof, rf.get("bevel", 0.03), min(3, k.DET["bev"]))
    reach_r = max(reach_r, max(r for r, z in prof if z < Z(sp["hub"]["y"]) + 0.9))
    if rf.get("eave"):
        e0, e1, eh = rf["eave"]
        ev = cyl("eave", m["eave"], (0, 0, (Z(e0) + Z(e1)) / 2), R(eh), Z(e1) - Z(e0), verts=seg)
        soften(ev, min(0.035, (Z(e1) - Z(e0)) * 0.4), min(2, k.DET["bev"]))
        reach_r = max(reach_r, R(eh))
    if rf.get("knob"):
        ky, kr = rf["knob"]
        sphere("knob_top", m["roof"], (0, 0, Z(ky)), R(kr), scale=(1, 1, 0.75))

    # ---- двері в арці ----
    dz1 = Z(door["top"])
    dhalf = R(door["half"])
    z_mid = dz1 * 0.5
    fy = -(max(front["r"](z) for z in (0.02, z_mid, dz1)) + 0.012)
    dr = prism("door", m["door"], arch_profile(2 * dhalf, dz1 - dhalf, k.DET["arch"]), fy, fy + 0.25)
    soften(dr, 0.01, min(2, k.DET["bev"]))
    fw = R(door.get("frame_w", 16))
    if door["frame"] == "tube":
        arch_curve("door_arch", m["frame"], 2 * dhalf + fw, dz1 - dhalf, fy - 0.004, fw * 0.55)
    else:
        # клинчаки: брили навколо арки (сектори кільця в площині фасаду), боки — стовпчики брил
        n = door.get("stones", 7) if hi else (5 if mid else 3)
        rin, rout = dhalf + 0.004, dhalf + fw
        cz = dz1 - dhalf
        for i in range(n):
            a0 = math.pi * i / n + 0.03
            a1 = math.pi * (i + 1) / n - 0.03
            b = ring_block("vous%d" % i, m["frame"], a0 - math.pi / 2, a1 - math.pi / 2, rin, rout, -0.03, 0.05,
                           segs=2 if hi else 1)
            # сектор будувався в площині XY навколо Z — кладемо його на фасад (XZ)
            b.matrix_world = Matrix.Translation((0.0, fy + 0.012, cz)) @ Matrix.Rotation(math.pi / 2, 4, "X") @ \
                Matrix.Rotation(math.pi, 4, "Z")
            soften(b, 0.012, 1)
        nj = door.get("jambs", 3) if (hi or mid) else 2
        for side in (-1, 1):
            for j in range(nj):
                h = cz / nj
                bj = box("jamb%d_%d" % (side, j), m["frame"], (side * (rin + rout) / 2, fy - 0.02, h * (j + 0.5)),
                         (rout - rin, 0.08, h - 0.012))
                soften(bj, 0.012, 1)
    if door.get("latch"):
        lx, ly = door["latch"]
        box("latch", m["latch"], (R(lx - sp.get("fx", sp["cx"])), fy - 0.012, Z(ly)), (R(24), 0.02, R(9)))
    if door.get("knob"):
        kx, ky, kr = door["knob"]
        sphere("knob", m["knob"], (R(kx - sp.get("fx", sp["cx"])), fy - 0.02, Z(ky)), R(kr))

    # ---- вікно ----
    w = sp["window"]
    wz = Z(w["y"])
    wy = -front["r"](wz)
    wr = R(w["r"])
    ts, tr_ = k.DET["tor"]
    def torus(name, mat, rmaj, rmin, y):
        bpy.ops.mesh.primitive_torus_add(major_radius=rmaj, minor_radius=rmin, major_segments=max(8, ts - 6),
                                         minor_segments=max(3, tr_ - 4), location=(0.0, y, wz),
                                         rotation=(math.pi / 2, 0, 0))
        o = bpy.context.active_object
        o.name = name
        o.data.materials.append(mat)
        return o
    if w["style"] == "disk":
        cyl("win", m["win"], (0.0, wy - 0.005, wz), wr, 0.05, rot=(math.pi / 2, 0, 0))
    elif w["style"] == "porthole":
        rr = R(w["ring"])
        cyl("win_plate", m.get("plate", m["frame"]), (0.0, wy - 0.012, wz), rr, 0.05, rot=(math.pi / 2, 0, 0))
        soften(bpy.context.active_object, 0.014, min(2, k.DET["bev"]))
        torus("win_ring", m["win"], wr + 0.01, 0.014, wy - 0.038)
        cyl("win_glass", m["glass"], (0.0, wy - 0.03, wz), wr, 0.02, rot=(math.pi / 2, 0, 0))
        box("win_mv", m["win"], (0.0, wy - 0.042, wz), (0.016, 0.01, 2 * wr))
        box("win_mh", m["win"], (0.0, wy - 0.042, wz), (2 * wr, 0.01, 0.016))
        nr = w.get("rivets", 8) if hi else (6 if mid else 0)
        for i in range(nr):
            a = 2 * math.pi * (i + 0.5) / nr
            rv = (wr + rr) / 2 + 0.004
            cyl("rivet%d" % i, m["frame"], (rv * math.cos(a), wy - 0.038, wz + rv * math.sin(a)), 0.011, 0.012,
                rot=(math.pi / 2, 0, 0), verts=6)
    elif w["style"] == "rings":
        rr = R(w["ring"])
        torus("win_ring_o", m.get("ring_o", m["frame"]), rr - 0.018, 0.022, wy - 0.02)
        torus("win_ring_i", m["win"], wr + 0.012, 0.016, wy - 0.028)
        cyl("win_glass", m["glass"], (0.0, wy - 0.01, wz), wr + 0.01, 0.03, rot=(math.pi / 2, 0, 0))

    # ---- крила ----
    hb, sl = sp["hub"], sp["sails"]
    hz = Z(hb["y"])
    L = R(sl["reach"])
    thick = R(sl.get("thick", 10))
    # Площина крил — перед найвиступнішою вершиною моделі в колі замаху (край даху, пасок,
    # клинчаки арки, вікно): рахуємо по справжній геометрії, бо «на око» з розмірів уже раз
    # пропустили арку дверей, у яку крила й влізли.
    sweep = math.hypot(L, max(R(sl["width"]) / 2 + R(sl.get("over", 5)), R(sl["caps"][0]) / 2 if sl.get("caps") else 0))
    near = -front_y(0.0, hz, sweep + 0.02)
    hy = -(near + SAIL_GAP + thick / 2)
    HUB = (0.0, hy, hz)
    rows = sl["rows"] if (hi or mid) else max(3, sl["rows"] - 2)
    for i in range(4):
        for ob in lattice_blade("b%d" % i, m["sail"], k, HUB, math.radians(sl.get("ang", 45) + 90 * i), L, R(sl["width"]),
                                start=R(sl["start"]), rows=rows, cols=sl.get("cols", 2), rail=R(sl["rail"]),
                                rung=R(sl["rung"]), thick=thick, over=R(sl.get("over", 5)), spar=R(sl.get("spar", 0)),
                                caps=(R(sl["caps"][0]), R(sl["caps"][1])) if sl.get("caps") else None,
                                cap_mat=m.get("sail_cap"), rung_bevel=sl.get("rung_bevel", True)):
            ob.name = "part_sails__" + ob.name
    # вісь від даху до маточини (лежить на осі обертання — крутитись їй не заважає)
    roof_r_at_hub = max(r for r, z in prof if z >= hz - 0.05) if prof else 0.3
    alen = abs(hy) - roof_r_at_hub * 0.6
    cyl("axle", m["hub"], (0.0, hy + alen / 2, hz), R(hb.get("axle", 10)), alen, rot=(math.pi / 2, 0, 0),
        verts=max(8, k.DET["cyl"] // 2))
    hr = R(hb["r"])
    cyl("part_sails__hub", m["hub"], (0.0, hy - thick * 0.3, hz), hr, thick * 1.6, rot=(math.pi / 2, 0, 0))
    style = hb.get("style", "ring")
    if style == "ring":
        ts, tr_ = k.DET["tor"]
        bpy.ops.mesh.primitive_torus_add(major_radius=hr * 0.8, minor_radius=hr * 0.2, major_segments=ts,
                                         minor_segments=max(3, tr_ - 2), location=(0.0, hy - thick * 1.1, hz),
                                         rotation=(math.pi / 2, 0, 0))
        ring = bpy.context.active_object
        ring.name = "part_sails__ring"
        ring.data.materials.append(m["hub"])
        sphere("part_sails__cap", m["hub"], (0.0, hy - thick * 1.1, hz), hr * 0.4)
    elif style == "cap":
        sphere("part_sails__cap", m[hb.get("cap_mat", "knob")], (0.0, hy - thick * 1.2, hz), R(hb["cap_r"]), scale=(1, 0.6, 1))

    sail_gap(HUB)
    return {"parts": {"sails": HUB}}
