# -*- coding: utf-8 -*-
"""Хатинка 4 за малюнком hut_4.jpg — «грибок»: кругла кремова стіна дзвоном (ширша донизу),
жовтий солом'яний дах-капелюх із хвилястим звислим краєм і аркою спереду, у якій — кругле
червоне вікно з хрестом, солом'яний «вузол» на маківці, сірий димар праворуч позаду, жовта
«брова» над арочними дверима, сірі круглі вікна по боках, рожеве сердечко й камінці на стіні.

Розміри — з малюнка: 400 пк = 1 м, низ стіни — y 775 пк (26.09). Див. kit.py, hut_common.py."""
import math

import bpy

import kit
from kit import arch_profile, box, cyl, prism, soften, sphere
from hut_common import bent_bar_on, cut, lathe

PAL = {
    "wall_hi": "#F0DAAE", "wall": "#E6CC9C", "wall_lo": "#D8B888", "wall_foot": "#C4A070",
    "roof_hi": "#E8A838", "roof": "#DA922C", "roof_edge": "#C07824", "roof_line": "#A8681C",
    "roof_under": "#B87A36",
    "chimney_hi": "#EAD3A6", "chimney_lo": "#C9A97A",
    "cap_hi": "#BDB5AA", "cap": "#A39A8F",
    "red_hi": "#D6694C", "red": "#BE5037",
    "glass": "#6E2E22", "glass_hi": "#A2503C",
    "door_hi": "#8E5431", "door": "#74421F", "door_line": "#4E2812",
    "hinge": "#E9CB98",
    "grey_hi": "#C2B7A8", "grey": "#A89B89",
    "pane": "#EEDFC2",
    "brow_hi": "#F8C24E", "brow": "#E9A536",
    "pink": "#F08A7E", "pink_lo": "#DD6F66",
    "teal": "#A8D6CC", "teal_lo": "#86BDB2",
}


def materials(k):
    return {
        "wall": k.mat_gradient("wall", [(0.0, "wall_foot"), (0.2, "wall_lo"), (0.55, "wall"), (1.0, "wall_hi")], 0.0, 0.9, 0.2, 5.0),
        # Дах на малюнку гладкий, ліплений: лише м'який перелив, без смуг-рядів.
        "roof": k.mat_gradient("roof", [(0.0, "roof_edge"), (0.45, "roof"), (1.0, "roof_hi")], 0.5, 1.15, 0.35, 3.0),
        "under": k.mat_gradient("under", [(0.0, "roof_under"), (1.0, "roof_edge")], 0.45, 0.7, 0.1, 6.0),
        "straw": k.mat_door("straw", keys=("roof_line", "roof", "roof_hi"), planks=14.0, direction="X"),
        "chimney": k.mat_gradient("chimney", [(0.0, "chimney_lo"), (0.5, "chimney_hi"), (1.0, "chimney_lo")], 0.9, 1.25, 0.9, 7.0),
        "cap": k.mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 1.22, 1.34, 0.1, 8.0),
        "red": k.mat_gradient("red", [(0.0, "red"), (1.0, "red_hi")], 0.62, 0.86, 0.1, 8.0),
        "glass": k.mat_glass("glass"),
        "door": k.mat_door("door"),
        "hinge": k.mat_gradient("hinge", [(0.0, "hinge"), (1.0, "hinge")], 0.0, 1.0, 0.0),
        "grey": k.mat_gradient("grey", [(0.0, "grey"), (1.0, "grey_hi")], 0.2, 0.42, 0.1, 8.0),
        "pane": k.mat_gradient("pane", [(0.0, "pane"), (1.0, "pane")], 0.0, 1.0, 0.0),
        "brow": k.mat_gradient("brow", [(0.0, "brow"), (1.0, "brow_hi")], 0.36, 0.53, 0.1, 6.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink_lo"), (1.0, "pink")], 0.12, 0.26, 0.1, 8.0),
        "teal": k.mat_gradient("teal", [(0.0, "teal_lo"), (1.0, "teal")], 0.0, 0.3, 0.2, 8.0),
    }


# Стіна-дзвін: (радіус, висота). Верх ховається під дахом, спереду видно в арці даху.
WALL = [(0.0, 0.0), (0.52, 0.0), (0.57, 0.04), (0.59, 0.14), (0.59, 0.26), (0.57, 0.4),
        (0.53, 0.56), (0.47, 0.68), (0.4, 0.8), (0.3, 0.93), (0.16, 1.02), (0.0, 1.05)]


def wall_r(z):
    """Радіус стіни на висоті z (лінійно між точками профілю)."""
    for (r0, z0), (r1, z1) in zip(WALL[1:], WALL[2:]):
        if z0 <= z <= z1:
            return r0 + (r1 - r0) * (z - z0) / (z1 - z0)
    return WALL[1][0]


def on_wall(obs, ang, z, out=0.0):
    """Деталі, зібрані лицем до −Y у (0, 0, z_деталі), — на круглу стіну під кутом ang
    (0 — фасад, + — праворуч) на відстань радіуса стіни на висоті z (+ out)."""
    from mathutils import Matrix
    r = wall_r(z) + out
    for ob in obs:
        ob.matrix_world = (Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0.0, -r, 0.0))
                           @ ob.matrix_world)


def round_window(name, m, ring_mat, glass_mat, r, minor, z, ang, out=0.0, tor=None, cross=True):
    """Кругле вікно лицем до −Y: кільце, скло й хрестовина. Площина кільця — y = 0 (на стіні —
    радіус стіни + out). Скло ПЕРЕД цією площиною (−1…−9 мм): за нею воно ховалось у фронтоні
    (рецензія 26.09 — червоне вікно було «глухим»). Планки хреста — ще попереду, і горизонтальна
    на 3 мм попереду вертикальної: в одній площині перетин запікався чорним квадратиком."""
    ts, tr = tor or kit.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=minor, major_segments=ts,
                                     minor_segments=tr, location=(0, 0, z), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = name + "_ring"
    ring.data.materials.append(ring_mat)
    made = [ring, cyl(name + "_glass", glass_mat, (0, -0.005, z), r, 0.008, rot=(math.pi / 2, 0, 0))]
    if cross:
        made.append(box(name + "_v", ring_mat, (0, -0.013, z), (minor * 0.8, 0.012, 2 * r)))
        made.append(box(name + "_h", ring_mat, (0, -0.016, z), (2 * r, 0.012, minor * 0.8)))
    on_wall(made, ang, z, out)
    return made


def conform(obs, R_of_z, step=0.025, zcuts=()):
    """Деталі, зібрані на ПЛОЩИНІ y = 0 (0 — поверхня стіни, − — назовні), — вигнути по круглій
    стіні: y → y − √(R(z)² − x²). Пласка дошка на круглій стіні відставала краями на ~4 см і
    показувала торець (рецензія 26.09). Перед вигином — вертикальні розрізи кожні step м, щоб
    було що гнути, і горизонтальні на zcuts: без них лице дверей між низом і верхом ішло
    прямою, а стіна посередині опукла — і випирала крізь дошки плямою."""
    import bmesh
    from mathutils import Vector
    for ob in obs:
        me = ob.data
        me.transform(ob.matrix_world)
        ob.matrix_world.identity()
        bm = bmesh.new()
        bm.from_mesh(me)
        xs = [v.co.x for v in bm.verts]
        x = math.floor(min(xs) / step) * step + step
        while x < max(xs):
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((x, 0, 0)), plane_no=Vector((1, 0, 0)))
            x += step
        for z in zcuts:
            geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector((0, 0, z)), plane_no=Vector((0, 0, 1)))
        for v in bm.verts:
            R = R_of_z(v.co.z)
            v.co.y = v.co.y - math.sqrt(max(R * R - v.co.x * v.co.x, 0.0))
        bm.to_mesh(me)
        bm.free()


def build(m, k):
    seg = {20: 26, 12: 18, 6: 10}.get(k.DET["cyl"], 24)
    low = k.DET["bev"] <= 1
    # Стіна — головний об'єкт «body». У найпростішому варіанті — менше точок профілю (бюджет
    # low ~1,5 тис. вершин у .glb); радіус стіни для деталей (wall_r) — з повного WALL.
    body = lathe("body", m["wall"], [WALL[i] for i in (0, 1, 3, 4, 6, 8, 10, 11)] if low else WALL, seg,
                 wobble=lambda a, r, z: (0.012 * math.sin(3 * a + 1.0) * min(r, 0.5), 0.0))

    # Дах-капелюх: товстий, звислий край (спід темніший), трохи хвилястий по колу.
    # Скат від маківки до краю — прямий, ~45° (на малюнку не баня, а капелюх).
    outer = [(0.0, 1.12), (0.18, 1.12), (0.26, 1.1), (0.4, 0.96), (0.55, 0.81), (0.69, 0.67),
             (0.79, 0.58), (0.81, 0.52)]
    inner = [(0.76, 0.49), (0.62, 0.6), (0.45, 0.74), (0.3, 0.88), (0.15, 0.97), (0.0, 0.99)]
    if low:
        outer = [outer[i] for i in (0, 2, 4, 6, 7)]
        inner = [inner[i] for i in (0, 2, 4, 5)]

    def wavy(a, r, z):
        f = max(0.0, (r - 0.45) / 0.32)          # хвилі лише біля краю
        return (0.03 * f * math.sin(5 * a + 0.6), -0.035 * f * (0.5 + 0.5 * math.sin(5 * a + 2.1)))
    roof = lathe("roof", m["roof"], outer + inner, seg, wobble=wavy)
    # Арка спереду: у даху вирізано отвір, у ньому — кремовий «фронтон» (на малюнку вікно не в
    # печері, а на стіні врівень з дахом) і над ним — «каптур» з того ж даху.
    aw, az0, ah = 0.46, 0.3, 0.36          # ширина арки, низ вирізу, висота прямих боків
    asteps = {12: 12, 6: 8}.get(k.DET["arch"], 5)   # сегментів дуги арки
    arch = prism("roof_arch_cut", m["roof"], arch_profile(aw, ah, asteps), -1.2, -0.2)
    arch.location.z = az0
    bpy.context.view_layer.update()
    cut(roof, arch)
    soften(roof, 0.02, 1)
    # Фронтон на 3 мм ширший за виріз (боки заходять у тіло даху) і з тим самим центром дуги:
    # на 2 см вужчий, він лишав темну щілину по всьому краю арки (рецензія 26.09).
    FZ = 0.5
    front = prism("dormer", m["wall"], arch_profile(aw + 0.006, az0 + ah - FZ, asteps), -0.6, -0.3)
    front.location.z = FZ
    # Каптур: арочна «підкова» даху навколо фронтону, на 2,5 см попереду нього. Закриває шов
    # фронтону з дахом і верх фронтону, що стирчав із ската.
    hood = prism("hood", m["roof"], arch_profile(aw + 0.11, az0 + ah - FZ + 0.02, asteps), -0.625, -0.32)
    hood.location.z = FZ - 0.02
    hole = prism("hood_cut", m["roof"], arch_profile(aw - 0.004, az0 + ah - FZ + 0.05, asteps), -1.0, 0.0)
    hole.location.z = FZ - 0.05
    bpy.context.view_layer.update()
    cut(hood, hole)
    soften(hood, 0.025, 1)
    # Спід даху — темніша «тінь» під звисом: тонка оболонка, що ЙДЕ ПО внутрішньому профілю
    # даху (на 1 см нижче, з тими ж хвилями). Конус замість неї лишав між собою й дахом
    # темну порожнину до 8 см.
    ui = inner[:2] if low else inner[:3]
    under_prof = [(r, z - 0.01) for r, z in ui] + [(r - 0.01, z - 0.025) for r, z in reversed(ui)]
    und = lathe("roof_under", m["under"], under_prof, seg, wobble=wavy)
    cutter = prism("under_cut", m["under"], arch_profile(aw, ah, asteps), -1.2, -0.2)
    cutter.location.z = az0
    bpy.context.view_layer.update()
    cut(und, cutter)

    # Солом'яний вузол на маківці: пласка «подушка» з ребрами, ширша за маківку даху.
    kn = cyl("knob", m["straw"], (0.0, 0.0, 1.15), 0.28, 0.14)
    soften(kn, 0.06, min(2, k.DET["bev"]))
    if not low:
        sphere("knob_top", m["straw"], (0.0, 0.0, 1.21), 0.2, (1.0, 1.0, 0.3))

    # Димар праворуч позаду: плямистий бежевий стовп, сіра шапка — найвища точка хати.
    cx, cy = 0.33, 0.16
    ch = cyl("chimney", m["chimney"], (cx, cy, 1.05), 0.105, 0.34)
    soften(ch, 0.02, min(2, k.DET["bev"]))
    cp = cyl("chimney_cap", m["cap"], (cx, cy, 1.25), 0.145, 0.11)
    soften(cp, 0.035, min(2, k.DET["bev"]))

    # Кругле червоне вікно в арці.
    round_window("win", m, m["red"], m["glass"], 0.1, 0.03, 0.74, 0.0, 0.6 - wall_r(0.74))   # площина фронтону

    # Двері: арочні дошки, кругле віконце вгорі, світлі петлі — ВИГНУТІ по стіні (conform):
    # лице дверей на 1,2 см над стіною по всій ширині, дошка на 4 см утоплена.
    dx = 0.04
    dw, dh = 0.29, 0.23
    door = [prism("door", m["door"], arch_profile(dw, dh, k.DET["arch"]), -0.012, 0.04)]
    soften(door[0], 0.01, min(2, k.DET["bev"]))
    door.append(cyl("door_hole", m["glass"], (0.0, -0.014, 0.3), 0.03, 0.006, rot=(math.pi / 2, 0, 0)))
    ts, tr = k.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.035, minor_radius=0.011, major_segments=max(8, ts // 2),
                                     minor_segments=max(3, tr // 2), location=(0, -0.016, 0.3), rotation=(math.pi / 2, 0, 0))
    hr = bpy.context.active_object
    hr.name = "door_hole_ring"
    hr.data.materials.append(m["hinge"])
    if not low:
        door.append(hr)                      # на відстані low кільце віконця не видно
    else:
        bpy.data.objects.remove(hr, do_unlink=True)
    for hz in (0.08, 0.2):
        door.append(box("hinge", m["hinge"], (-0.07, -0.016, hz), (0.13, 0.012, 0.022)))
    door.append(sphere("knob", m["hinge"], (0.1, -0.024, 0.17), 0.018))
    from mathutils import Matrix
    for ob in door:
        ob.matrix_world = Matrix.Translation((dx, 0.0, 0.0)) @ ob.matrix_world
    # Низ стіни круто заокруглений (0,52 → 0,59 за 14 см): двері по ньому не гнемо, щоб поріг
    # не западав у стіну, — радіус не менший за 0,575.
    R_door = lambda z: max(wall_r(z), 0.575)
    conform(door[:1], R_door, step=0.05, zcuts=(0.14,) if low else (0.07, 0.14, 0.26))
    # Петлі довгі — гнемо з розрізами; віконце й ручка малі, їм досить зсуву вершин.
    for ob in door[1:]:
        conform([ob], R_door, step=0.035 if ob.name.startswith("hinge") and not low else 1.0)

    # Жовта «брова» над дверима — пологий дах-шеврон, що лежить на круглій стіні: радіус стіни
    # береться НА ВИСОТІ кожної точки (дзвін звужується догори). Зі сталим радіусом середина
    # брови висіла на 6 см перед стіною й ховалась під фронтоном — брова читалась двома шматками.
    pts = [(dx - 0.22, 0.33), (dx - 0.1, 0.415), (dx + 0.02, 0.465), (dx + 0.09, 0.465),
           (dx + 0.18, 0.405), (dx + 0.25, 0.33)]
    bent_bar_on("brow", m["brow"], pts, 0.042, wrap_r=wall_r, off=0.012)

    # Сірі круглі вікна по боках (на ±38° від фасаду) і ззаду.
    for ang in (-38, 38, 180):
        round_window("side%d" % ang, m, m["grey"], m["pane"], 0.085, 0.022, 0.31, math.radians(ang), 0.005,
                     tor=(16, 6) if k.DET["bev"] >= 3 else None,   # малі вікна — легше кільце
                     cross=not low)   # хрестик 3 см на відстані low — не видно, а це 144 вершини

    # Сердечко й камінці, втоплені в стіну.
    hz, ha = 0.19, math.radians(34)
    heart = [sphere("heart_l", m["pink"], (-0.022, 0.0, hz + 0.01), 0.035, (1.0, 0.5, 1.0)),
             sphere("heart_r", m["pink"], (0.022, 0.0, hz + 0.01), 0.035, (1.0, 0.5, 1.0)),
             sphere("heart_b", m["pink"], (0.0, 0.0, hz - 0.02), 0.035, (1.1, 0.5, 1.0))]
    on_wall(heart, ha, hz, -0.005)
    for name, ang, z, s in (("peb_l", -46, 0.14, 0.035), ("peb_r", 50, 0.2, 0.03), ("peb_ll", -72, 0.2, 0.03))[:2 if low else 3]:
        pb = [sphere(name, m["teal"], (0.0, 0.0, z), s, (1.3, 0.45, 1.0))]
        on_wall(pb, math.radians(ang), z, -0.004)
    return {}
