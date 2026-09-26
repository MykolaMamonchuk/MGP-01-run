# -*- coding: utf-8 -*-
"""Квітка 4 за малюнком flower_4.png: густа жовта голівка з семи пелюсток, нахилена вгору, опукла серединка; темно-зелені листки — малий угорі й довгий знизу вздовж стебла.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#E2B414", "petal": "#D6A40E", "petal_lo": "#C4920A",
    "center": "#D8A60E", "center_lo": "#C4920A",
    "stem": "#44702A", "stem_lo": "#3A6224",
    "leaf_hi": "#3D6724", "leaf": "#335B1D", "leaf_lo": "#284C14",
    "leaf2": "#2E5818", "leaf2_lo": "#224A0C",
    "base": "#6DA347", "base_lo": "#5A8E38",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=-0.01, z=0.865, tilt=0, n=7, L=0.12, W=0.115, T=0.05, rc=0.055, dome=0.9, taper=0.3, lift=0.006),
    "stem": dict(r=0.016, pts=[(0.0, 0.0), (0.0, 0.4), (0.0, 0.85)]),
    "leaves": [dict(z=0.56, side=-1, el=40, L=0.15, W=0.11, curl=0.05, full=0.6),
               dict(z=0.08, side=1, el=65, L=0.34, W=0.115, curl=-0.04, mat="leaf2")],
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
