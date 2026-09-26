# -*- coding: utf-8 -*-
"""Тюк сіна за малюнком hay_bale_3.png: солом'яна куля, стягнута дерев'яними ременями навхрест,
із рожевими й салатовими намистинками-ягідками по боках і двома паличками з рожевими
квіточками на маківці. Траву-підставку не моделюємо (у мірі — erase).

Перешкода, що котиться: діаметр 0,62 м, початок у центрі дна. Щоб не «кульгала», усе виступає
за радіус не більше ніж на 2 см: ремені — на 1 см, ягідки втоплені, палички вигнуті по кулі,
квіточки — пласкі подушечки. Геометрія — haybale_common."""
import math

from mathutils import Vector

import haybale_common as hc
from kit import box, sphere

PAL = {
    # Кластери малюнка (солома #CB8E33/#E5AF47/#F8D464, ремені #BA7924/#9D5C1E/#7E4513, ягоди
    # #D9788F/#F9C7D8), тоновані під світло заміру: PAL ≈ 0,8 · (сер + 1,25 · (колір − сер)).
    "straw_lo": "#BB8020", "straw": "#C58F27", "straw_hi": "#CFA535", "straw_top": "#D2B75F",
    "straw_seam": "#A86A14",
    "band_lo": "#703705", "band": "#8A490B", "band_hi": "#A3620D",
    "stick": "#B88430", "stick_hi": "#D0A048",
    "pink": "#D86890", "pink_hi": "#E890B0", "green": "#88B840",
}

R = 0.31
# ремені (нахил осі, поворот осі): косий знизу-зліва вгору-направо, два меридіани (ліворуч і
# праворуч від середини фасаду) і ще один навскоси ззаду
BANDS = [(30, 210), (82, -55), (82, 35), (60, 110)]
# ягідки: (азимут, висота над екватором у градусах, колір) — з малюнка, спереду
BERRIES = [(-19, 42, "pink"), (-5, 17, "green"), (-57, -1, "pink"), (-41, -42, "pink"),
           (33, -42, "pink"), (49, -14, "green"), (61, -14, "pink"), (150, 20, "pink"), (200, -30, "green")]


def materials(k):
    return {
        "straw": hc.mat_straw("straw", flakes=5.0, seam_w=0.025),
        # ремінь — дерев'яна планка: рівний колір із плямами, не кручена мотузка
        "band": k.mat_gradient("band", [(0.0, "band_lo"), (0.45, "band"), (1.0, "band_hi")], 0.0, 2 * R, 0.5, 7.0),
        "stick": k.mat_gradient("stick", [(0.0, "stick"), (1.0, "stick_hi")], 0.0, 2 * R, 0.3, 9.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink_hi")], 0.0, 2 * R, 0.2, 6.0),
        "green": k.mat_gradient("green", [(0.0, "green"), (1.0, "green")], 0.0, 1.0, 0.0),
    }


def on_ball(az, el, r):
    """Точка на кулі: азимут від фасаду (−Y) за годинниковою, висота над екватором."""
    a, e = math.radians(az), math.radians(el)
    return Vector((r * math.cos(e) * math.sin(a), -r * math.cos(e) * math.cos(a), R + r * math.sin(e)))


def build(m, k):
    hc.ball("body", m["straw"], k, R)
    for i, (tilt, turn) in enumerate(BANDS):
        hc.ring("band%d" % i, m["band"], k, (0, 0, R), R, 0.01, hc.axis_from(tilt, turn), flat=2.6)
    lv = hc.level(k)
    for i, (az, el, key) in enumerate(BERRIES if lv != "low" else BERRIES[:6]):
        sphere("berry%d" % i, m[key], on_ball(az, el, R - 0.004), 0.022)
    # Палички на маківці: дуги по кулі (не прямі — прямі стирчали б на 3-4 см і тюк
    # «кульгав» би), на кінцях — рожеві квіточки-подушечки.
    for i, (turn, a0, a1) in enumerate(((20, -0.9, 0.2), (-35, -0.1, 0.75))):
        axis = hc.axis_from(90, turn)
        hc.arc("stick%d" % i, m["stick"], k, (0, 0, R), R + 0.004, 0.016, axis,
               math.pi / 2 + a0, math.pi / 2 + a1, start=Vector((1, 0, 0)))
    for i, (az, el) in enumerate(((-70, 62), (35, 70))):
        p = on_ball(az, el, R + 0.004)
        f = box("flower%d" % i, m["pink"], p, (0.05, 0.05, 0.018))
        f.rotation_mode = "QUATERNION"
        f.rotation_quaternion = Vector((0, 0, 1)).rotation_difference((p - Vector((0, 0, R))).normalized())
        sphere("flower_mid%d" % i, m["green"], p + (p - Vector((0, 0, R))).normalized() * 0.01, 0.009)
    return {}
