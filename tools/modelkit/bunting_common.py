# -*- coding: utf-8 -*-
"""Родина «гірлянда» (banner_line_*): два дерев'яні стовпчики з кульками на верхівках, шнур,
що провисає дугою, трикутні прапорці по черзі кольорів. Модель задає лише PAL і CFG — форму
й кольори прапорців (ключі PAL), тож перефарбувати — це правка палітри, а не геометрії.

Ключі PAL: wood_hi/wood/wood_lo/wood_line (стовпчики), ball, ball_hi (кульки), rope (шнур),
кольори прапорців — будь-які ключі, названі в CFG["flags"]."""
import math

import bpy
from mathutils import Matrix

import kit
from kit import cyl, soften, sphere


def flat(k, key):
    return k.mat_gradient(key, [(0.0, key), (1.0, key)], 0.0, 1.0, 0.0)


def materials(k, cfg):
    m = {
        "wood": k.mat_door("wood", keys=("wood_line", "wood_lo", "wood_hi"), planks=38.0, direction="X"),
        "ball": k.mat_gradient("ball", [(0.0, "ball"), (1.0, "ball_hi")], cfg["height"], cfg["height"] + cfg["ball_r"] * 1.6, 0.1, 8.0),
        "rope": flat(k, "rope"),
    }
    for _, key in cfg["flags"]:
        if key not in m:
            m[key] = flat(k, key)
    return m


def rope_z(c, t):
    """Висота мотузки в точці t (0 — лівий стовпчик, 1 — правий): парабола-провис."""
    # sag_pow < 2 — шнур натягнутіший: біля стовпчиків іде вище, провис зосереджений посередині
    return c["attach"] - c["sag"] * (1.0 - abs(2.0 * t - 1.0) ** c.get("sag_pow", 2.0))


def bunting(m, k, c):
    half = c["span"] / 2
    pr = c["pole_r"]
    # Лівий стовпчик — «body» (головний об'єкт).
    for i, x in enumerate((-half, half)):
        p = cyl("body" if i == 0 else "pole_r", m["wood"], (x, 0, c["height"] / 2), pr, c["height"])
        soften(p, 0.01, min(2, k.DET["bev"]))
        sphere("ball%d" % i, m["ball"], (x, 0, c["height"] + c["ball_r"] * 0.75), c["ball_r"])
        if c["wrap"]:
            # кільце обмотки: товщина й радіус — з малюнка, або «на шнур більше за стовпчик»
            cyl("wrap%d" % i, m["rope"], (x, 0, c["attach"]), c.get("wrap_r", pr + c["rope_r"]),
                c.get("wrap_h", c["rope_r"] * 3.5))
    # Мотузка — крива з круглим перерізом від стовпчика до стовпчика.
    n = max(8, k.DET["cyl"] * 2)
    x0, x1 = -half + pr, half - pr
    cu = bpy.data.curves.new("rope", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = c["rope_r"]
    cu.bevel_resolution = max(0, k.DET["tube"] - 1)
    sp = cu.splines.new("POLY")
    sp.points.add(n)
    for i, p in enumerate(sp.points):
        t = i / n
        x = x0 + (x1 - x0) * t
        p.co = (x, 0.0, rope_z(c, (x + half) / c["span"]), 1.0)
    ob = bpy.data.objects.new("rope", cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m["rope"])
    # Прапорці: верхній край — по хорді мотузки, вістря донизу.
    w, h, th = c["flag_w"], c["flag_h"], c["flag_t"]
    for i, (t, key) in enumerate(c["flags"]):
        xa, xb = -half + c["span"] * t - w / 2, -half + c["span"] * t + w / 2
        za, zb = rope_z(c, (xa + half) / c["span"]), rope_z(c, (xb + half) / c["span"])
        ang = math.atan2(zb - za, xb - xa)
        # Вістря зсунуте до ближчого стовпчика (skew — частка півширини): на деяких малюнках
        # прапорці пришиті навскоси, і зовнішній край висить майже прямовисно.
        tip = -c.get("skew", 0.0) * w / 2 * (0 if abs(t - 0.5) < 0.02 else (-1 if t < 0.5 else 1))
        f = k.prism("flag%d" % i, m[key], [(-w / 2, 0.0), (w / 2, 0.0), (tip, -h)], -th / 2, th / 2)
        f.matrix_world = (Matrix.Translation(((xa + xb) / 2, 0.0, (za + zb) / 2 - c["rope_r"]))
                          @ Matrix.Rotation(-ang, 4, "Y"))
        # Плоский прапорець: join_all робить усе гладким, і нормалі бічних граней тонкої
        # призми «розмазували» затінення — низ прапорця темнів. Розрізані ребра тримають грань
        # пласкою.
        es = f.modifiers.new("flat", "EDGE_SPLIT")
        es.split_angle = math.radians(30)
    # Намистини на мотузці між прапорцями (banner_line_3).
    for i in range(c["beads"]):
        ts = c["bead_t"][i]
        x = -half + c["span"] * ts
        sphere("bead%d" % i, m["ball"], (x, 0, rope_z(c, ts)), c["rope_r"] * 2.2)
    return {}
