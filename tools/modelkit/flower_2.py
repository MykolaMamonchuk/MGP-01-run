# -*- coding: utf-8 -*-
"""Квітка 2 за малюнком flower_2.png: шість великих блідо-рожевих пелюсток-сердечок, маленька жовта серединка, вигнуте світло-зелене стебло, два маленькі листки.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#FFDCE8", "petal": "#FCCCDA", "petal_lo": "#F2B8C9",
    "center": "#F2D38E", "center_lo": "#E3B870",
    "stem": "#88A858", "stem_lo": "#789848",
    "leaf_hi": "#9EB870", "leaf": "#8CA85E", "leaf_lo": "#7A984E",
    "leaf2": "#A2BA70", "leaf2_lo": "#8FA85E",
    "base": "#6DA347", "base_lo": "#5A8E38",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=0.0, z=0.775, tilt=6, n=6, rot0=0, L=0.2, W=0.22, T=0.05, rc=0.05, dome=0.7, taper=0.35, notch=0.12),
    "stem": dict(r=0.027, pts=[(0.03, 0.0), (0.0, 0.12), (-0.01, 0.35), (0.0, 0.6), (0.0, 0.77)]),
    "leaves": [dict(z=0.43, side=-1, el=35, L=0.13, W=0.07, curl=0.08, full=0.6),
               dict(z=0.16, side=1, el=38, L=0.2, W=0.095, curl=0.08, full=0.6)],
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
