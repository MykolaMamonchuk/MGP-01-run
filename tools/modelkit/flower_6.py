# -*- coding: utf-8 -*-
"""Квітка 6 за малюнком flower_6.png: п’ять пухких жовтих пелюсток з видимими гранями, гранована пісочна серединка, два листки різної зелені, восьмигранна зелена підставка.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#FCE440", "petal": "#F6D422", "petal_lo": "#E8BE10",
    "center": "#D8B462", "center_lo": "#C49C4C",
    "stem": "#6CA83C", "stem_lo": "#5E9832",
    "leaf_hi": "#9CC050", "leaf": "#86B048", "leaf_lo": "#6E9A38",
    "leaf2": "#4E8A2A", "leaf2_lo": "#3A6E1C",
    "base": "#76AE48", "base_lo": "#5E8E34",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=0.005, z=0.83, tilt=8, n=5, rot0=95, L=0.16, W=0.15, T=0.075, rc=0.06, dome=0.6, taper=0.3,
                 center_seg=8, center_facets=True, petal_facets=True),
    "stem": dict(r=0.028, pts=[(0.0, 0.1), (0.0, 0.4), (0.005, 0.82)]),
    "leaves": [dict(z=0.36, side=1, el=28, L=0.22, W=0.14, curl=0.05, full=0.6),
               dict(z=0.22, side=-1, el=40, L=0.24, W=0.14, curl=0.05, full=0.6, mat="leaf2")],
    "base": dict(style="facet", r=0.22, h=0.11, seg=8),
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
