# -*- coding: utf-8 -*-
"""Тюк сіна за малюнком hay_bale_4.png: трохи сплющена грудкувата солом'яна куля з
«пластівців», обв'язана крученою мотузкою: дві паралельні петлі навколо низу, одна навскоси
через маківку й одна збоку.

Перешкода, що котиться: діаметр 0,62 м, висота 0,59 м (пропорція малюнка 476 : 499), початок у
центрі дна. Гра кладе модель на бік і крутить навколо колишньої вертикалі, тож коло має бути
в ГОРИЗОНТАЛЬНОМУ перерізі — він круглий; грудки лише всередину (до 8 мм), мотузки виступають
на 1,5 см. Геометрія — haybale_common."""
import math

import haybale_common as hc

PAL = {
    # Кластери малюнка (солома #C17925/#D7A038/#EFCA64/#F7D77E, мотузка #D0914A/#C17925/#DFA963),
    # тоновані під світло заміру: PAL ≈ 0,8 · (сер + 1,25 · (колір − сер)).
    "straw_lo": "#B47418", "straw": "#BE8A22", "straw_hi": "#CBA640", "straw_top": "#D0B057",
    "straw_seam": "#A86A16",
    "band_lo": "#9E4D08", "band": "#B4752E", "band_hi": "#BE8842",
}

R, SQ = 0.31, 0.95
TUBE = 0.015


def materials(k):
    return {
        "straw": hc.mat_straw("straw", flakes=14.0, seam_w=0.025),
        "rope": hc.mat_rope("rope", twist=90.0),
    }


def build(m, k):
    H = 2 * R * SQ
    hc.ball("body", m["straw"], k, R, squash=SQ, lumps=0.008, seed=4)
    # дві петлі навколо низу — кола «широти» (кола в горизонтальному перерізі)
    for i, lat in enumerate((-24, -33)):
        a = math.radians(lat)
        z = H / 2 + (H / 2) * math.sin(a)
        hc.ring("rope_low%d" % i, m["rope"], k, (0, 0, z), R * math.cos(a), TUBE, (0, 0, 1))
    # навскоси через маківку і збоку — великі кола (еліпсоїд майже куля: радіус — середній)
    rr = R * (1 + SQ) / 2
    for i, (tilt, turn) in enumerate(((70, 60), (80, -30))):
        hc.ring("rope%d" % i, m["rope"], k, (0, 0, H / 2), rr, TUBE, hc.axis_from(tilt, turn))
    return {}
