# -*- coding: utf-8 -*-
"""Квітка 3 за малюнком flower_3.png: п’ять круглих коралово-рожевих пелюсток, велика жовта серединка, тонке пряме стебло, два гострі листки на різній висоті.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#F2B8B4", "petal": "#EAA19C", "petal_lo": "#DC8880",
    "center": "#F4D670", "center_lo": "#E9BC58",
    "stem": "#69A64E", "stem_lo": "#5D9444",
    "leaf_hi": "#78B862", "leaf": "#69AA56", "leaf_lo": "#5A9848",
    "leaf2": "#69AA56", "leaf2_lo": "#5A9848",
    "base": "#6DA347", "base_lo": "#5A8E38",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=0.0, z=0.835, tilt=6, n=5, L=0.15, W=0.17, T=0.055, rc=0.085, dome=0.6, taper=0.3),
    "stem": dict(r=0.020, pts=[(-0.005, 0.0), (-0.005, 0.4), (-0.005, 0.82)]),
    "leaves": [dict(z=0.27, side=-1, el=40, L=0.23, W=0.09, curl=0.06),
               dict(z=0.18, side=1, el=42, L=0.22, W=0.09, curl=0.06)],
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
