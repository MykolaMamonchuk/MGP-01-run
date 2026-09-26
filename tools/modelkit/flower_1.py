# -*- coding: utf-8 -*-
"""Квітка 1 за малюнком flower_1.png: п'ять круглих рожевих пелюсток, велика жовта серединка,
пряме стебло, два широкі листки навскоси вгору.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра.
Кольорові варіанти з тими самими P: flower_1_blue.py, flower_1_violet.py, flower_1_white.py."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#FCC8CA", "petal": "#F8B0B3", "petal_lo": "#EC9A9C",
    "center": "#F7C868", "center_lo": "#EDAA52",
    "stem": "#55A36A", "stem_lo": "#468C56",
    "leaf_hi": "#5CB073", "leaf": "#4E9C63", "leaf_lo": "#3F8753",
    "leaf2": "#4E9C63", "leaf2_lo": "#3F8753", "base": "#6DA347", "base_lo": "#5A8E38",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=0.025, z=0.8, tilt=4, n=5, L=0.185, W=0.2, T=0.06, rc=0.08, dome=0.5, taper=0.4),
    "stem": dict(r=0.030, pts=[(0.005, 0.0), (0.008, 0.3), (0.01, 0.55), (0.02, 0.78)]),
    # z — де кріпиться (частка висоти), side ±1, el — кут угору, L/W — довжина й ширина
    "leaves": [dict(z=0.27, side=-1, el=22, L=0.28, W=0.18, curl=0.05, fold=0.2, full=0.55, shape=0.7),
               dict(z=0.27, side=1, el=20, L=0.27, W=0.18, curl=0.05, fold=0.2, full=0.55, shape=0.7)],
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
