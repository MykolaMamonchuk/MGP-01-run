# -*- coding: utf-8 -*-
"""Квітка 7 за малюнком flower_7.png: сім жовтих пелюсток, опукла серединка, зелена чашечка, дві тоненькі гілочки, чотири травинки з землі, кругла зелена підставка з комірцем.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#E2C63A", "petal": "#D8BA30", "petal_lo": "#C4A624",
    "center": "#DCC034", "center_lo": "#C8AA28",
    "stem": "#669440", "stem_lo": "#5C8A38",
    "leaf_hi": "#6A9E44", "leaf": "#5E9140", "leaf_lo": "#548636",
    "leaf2": "#6AA046", "leaf2_lo": "#5A8E38",
    "base": "#629A40", "base_lo": "#548636",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=0.01, z=0.8, tilt=8, n=7, rot0=115.7, L=0.15, W=0.13, T=0.055, rc=0.055, dome=0.8, taper=0.3, calyx=0.07),
    "stem": dict(r=0.026, pts=[(0.0, 0.08), (-0.01, 0.4), (0.0, 0.6), (0.01, 0.82)]),
    "leaves": [dict(z=0.52, side=-1, el=35, L=0.18, W=0.035, curl=0.05, full=0.9, low_skip=True),
               dict(z=0.64, side=1, el=25, L=0.13, W=0.035, curl=0.05, full=0.9, low_skip=True),
               dict(z=0.1, side=-1, el=52, L=0.4, W=0.075, curl=-0.06, grass=True, yaw=-10, dx=-0.03),
               dict(z=0.1, side=-1, el=64, L=0.32, W=0.065, curl=-0.05, grass=True, yaw=20, dx=-0.03, dy=0.03),
               dict(z=0.1, side=1, el=50, L=0.4, W=0.075, curl=-0.06, grass=True, yaw=-15, dx=0.03),
               dict(z=0.1, side=1, el=66, L=0.3, W=0.065, curl=-0.05, grass=True, yaw=25, dx=0.03, dy=0.03)],
    "base": dict(style="round", r=0.17, h=0.065),
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
