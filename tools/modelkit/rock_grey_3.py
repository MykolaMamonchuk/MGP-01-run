# -*- coding: utf-8 -*-
"""Камінь 3 за малюнком rock_grey_3.png: сіро-зеленкувата брила, купки моху згори ліворуч, цятки моху з боків, рожева квіточка.
Родина — rock_common.py; тут лише профіль силуету (знятий з малюнка), мох, квіточка і палітра."""
import rock_common as rc

PAL = {   # кластери малюнка, на крок ТЕМНІШІ (рендер світліший за малюнок, 26.09): камінь знизу вгору, мох, квіточка
    "rock_lo": "#5A7E72", "rock_mid": "#6D8C81", "rock": "#8D9A9A", "rock_hi": "#B2B6B6",
    "moss_hi": "#71A23E", "moss": "#5D9431", "moss_lo": "#4A8127",
    "petal": "#F29AB2", "glint": "#FFFFFF",
}
DETAIL = rc.DETAIL
P = {
    "H": 0.6,
    # півширина на 21 рівні зверху донизу, частки висоти (з маски малюнка)
    "prof": [0.02, 0.19, 0.25, 0.31, 0.39, 0.42, 0.45, 0.47, 0.50, 0.51, 0.52, 0.53, 0.53, 0.52, 0.50, 0.48, 0.44, 0.39, 0.33, 0.28, 0.10],
    "seed": 6, "amp": 0.08,
    "moss": [dict(kind="cap", az=-25, el=72, r=0.13, thick=0.03, dome=0.15, wobble=0.15, lobes=4),
             dict(kind="cap", az=15, el=78, r=0.12, thick=0.03, dome=0.15, wobble=0.15, lobes=3, seed=1.2),
             dict(kind="cap", az=-55, el=55, r=0.08, thick=0.025, dome=0.2, wobble=0.12, lobes=3, seed=2.0),
             dict(kind="dot", az=50, el=15, r=0.045, dome=0.3), dict(kind="dot", az=-85, el=20, r=0.05, dome=0.3),
             dict(kind="dot", az=-70, el=28, r=0.035, dome=0.3), dict(kind="dot", az=92, el=2, r=0.03, dome=0.3),
             dict(kind="dot", az=-5, el=58, r=0.03, dome=0.3)],
    "flower": dict(az=28, el=-18, r=0.045),
}


def materials(k):
    return rc.materials(k, P)


def build(m, k):
    return rc.build(m, k, P)
