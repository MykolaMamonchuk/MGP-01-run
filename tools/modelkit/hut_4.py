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


def round_window(name, m, ring_mat, glass_mat, r, minor, z, ang, out=0.0):
    ts, tr = kit.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=r, minor_radius=minor, major_segments=ts,
                                     minor_segments=tr, location=(0, 0, z), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = name + "_ring"
    ring.data.materials.append(ring_mat)
    made = [ring, cyl(name + "_glass", glass_mat, (0, 0.012, z), r, 0.02, rot=(math.pi / 2, 0, 0))]
    made.append(box(name + "_v", ring_mat, (0, -0.004, z), (minor * 0.8, 0.02, 2 * r)))
    made.append(box(name + "_h", ring_mat, (0, -0.004, z), (2 * r, 0.02, minor * 0.8)))
    on_wall(made, ang, z, out)
    return made


def build(m, k):
    seg = {20: 26, 12: 18, 6: 10}.get(k.DET["cyl"], 24)
    # Стіна — головний об'єкт «body».
    body = lathe("body", m["wall"], WALL, seg,
                 wobble=lambda a, r, z: (0.012 * math.sin(3 * a + 1.0) * min(r, 0.5), 0.0))

    # Дах-капелюх: товстий, звислий край (спід темніший), трохи хвилястий по колу.
    # Скат від маківки до краю — прямий, ~45° (на малюнку не баня, а капелюх).
    outer = [(0.0, 1.12), (0.18, 1.12), (0.26, 1.1), (0.4, 0.96), (0.55, 0.81), (0.69, 0.67),
             (0.79, 0.58), (0.81, 0.52)]
    inner = [(0.76, 0.49), (0.62, 0.6), (0.45, 0.74), (0.3, 0.88), (0.15, 0.97), (0.0, 0.99)]

    def wavy(a, r, z):
        f = max(0.0, (r - 0.45) / 0.32)          # хвилі лише біля краю
        return (0.03 * f * math.sin(5 * a + 0.6), -0.035 * f * (0.5 + 0.5 * math.sin(5 * a + 2.1)))
    roof = lathe("roof", m["roof"], outer + inner, seg, wobble=wavy)
    # Арка спереду: у даху вирізано отвір до стіни, в ньому кругле вікно.
    aw = 0.46
    arch = prism("roof_arch_cut", m["roof"], arch_profile(aw, 0.36, 12), -1.2, -0.2)
    arch.location.z = 0.3
    bpy.context.view_layer.update()
    cut(roof, arch)
    soften(roof, 0.02, 1)
    # У арці — кремовий «фронтон» урівень із краєм даху (на малюнку вікно не в печері, а на
    # стіні врівень з дахом).
    front = prism("dormer", m["wall"], arch_profile(aw - 0.02, 0.16, 12), -0.6, -0.3)
    front.location.z = 0.5
    # Спід даху — темніша «тінь» під звисом (кільце трохи всередині краю).
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=0.77, radius2=0.52, depth=0.12, location=(0, 0, 0.56))
    und = bpy.context.active_object
    und.name = "roof_under"
    und.data.materials.append(m["under"])
    cutter = prism("under_cut", m["under"], arch_profile(aw, 0.36, 12), -1.2, -0.2)
    cutter.location.z = 0.3
    bpy.context.view_layer.update()
    cut(und, cutter)

    # Солом'яний вузол на маківці: пласка «подушка» з ребрами, ширша за маківку даху.
    kn = cyl("knob", m["straw"], (0.0, 0.0, 1.15), 0.28, 0.14)
    soften(kn, 0.06, max(2, k.DET["bev"]))
    sphere("knob_top", m["straw"], (0.0, 0.0, 1.21), 0.2, (1.0, 1.0, 0.3))

    # Димар праворуч позаду: плямистий бежевий стовп, сіра шапка — найвища точка хати.
    cx, cy = 0.33, 0.16
    ch = cyl("chimney", m["chimney"], (cx, cy, 1.05), 0.105, 0.34)
    soften(ch, 0.02, min(2, k.DET["bev"]))
    cp = cyl("chimney_cap", m["cap"], (cx, cy, 1.25), 0.145, 0.11)
    soften(cp, 0.035, max(2, k.DET["bev"]))

    # Кругле червоне вікно в арці.
    round_window("win", m, m["red"], m["glass"], 0.1, 0.03, 0.74, 0.0, 0.6 - wall_r(0.74))

    # Двері: арочні дошки, кругле віконце вгорі, світлі петлі.
    dx = 0.04
    dw, dh = 0.29, 0.23
    door = [prism("door", m["door"], arch_profile(dw, dh, k.DET["arch"]), -0.03, 0.05)]
    soften(door[0], 0.012, min(2, k.DET["bev"]))
    door.append(cyl("door_hole", m["glass"], (0.0, -0.031, 0.3), 0.03, 0.01, rot=(math.pi / 2, 0, 0)))
    ts, tr = k.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.035, minor_radius=0.011, major_segments=max(8, ts // 2),
                                     minor_segments=max(3, tr // 2), location=(0, -0.034, 0.3), rotation=(math.pi / 2, 0, 0))
    hr = bpy.context.active_object
    hr.name = "door_hole_ring"
    hr.data.materials.append(m["hinge"])
    door.append(hr)
    for hz in (0.08, 0.2):
        door.append(box("hinge", m["hinge"], (-0.07, -0.036, hz), (0.13, 0.012, 0.022)))
    door.append(sphere("knob", m["hinge"], (0.1, -0.045, 0.17), 0.018))
    from mathutils import Matrix
    for ob in door:
        ob.matrix_world = Matrix.Translation((dx, -wall_r(0.2) + 0.02, 0.0)) @ ob.matrix_world

    # Жовта «брова» над дверима — пологий дах-шеврон, що лежить на круглій стіні.
    pts = [(dx - 0.22, 0.37), (dx - 0.1, 0.46), (dx + 0.02, 0.52), (dx + 0.09, 0.52),
           (dx + 0.18, 0.45), (dx + 0.25, 0.37)]
    bent_bar_on("brow", m["brow"], pts, 0.042, wrap_r=wall_r(0.45), off=0.02)

    # Сірі круглі вікна по боках (на ±38° від фасаду) і ззаду.
    for ang in (-38, 38, 180):
        round_window("side%d" % ang, m, m["grey"], m["pane"], 0.085, 0.022, 0.31, math.radians(ang), 0.005)

    # Сердечко й камінці, втоплені в стіну.
    hz, ha = 0.19, math.radians(34)
    heart = [sphere("heart_l", m["pink"], (-0.022, 0.0, hz + 0.01), 0.035, (1.0, 0.5, 1.0)),
             sphere("heart_r", m["pink"], (0.022, 0.0, hz + 0.01), 0.035, (1.0, 0.5, 1.0)),
             sphere("heart_b", m["pink"], (0.0, 0.0, hz - 0.02), 0.035, (1.1, 0.5, 1.0))]
    on_wall(heart, ha, hz, -0.005)
    for name, ang, z, s in (("peb_l", -46, 0.14, 0.035), ("peb_r", 50, 0.2, 0.03), ("peb_ll", -72, 0.2, 0.03)):
        pb = [sphere(name, m["teal"], (0.0, 0.0, z), s, (1.3, 0.45, 1.0))]
        on_wall(pb, math.radians(ang), z, -0.004)
    return {}
