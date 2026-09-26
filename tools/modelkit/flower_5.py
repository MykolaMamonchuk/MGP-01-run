# -*- coding: utf-8 -*-
"""Квітка 5 за малюнком flower_5.png: жовта «чашечка» з шести пелюсток, відігнутих угору, зелена основа голівки, тонке оливкове стебло, два вузькі листки.
Родина — flower_common.py; тут лише параметри (частки висоти, зняті з маски малюнка) і палітра."""
import flower_common as fc

PAL = {   # кластери непрозорих пікселів малюнка
    "petal_hi": "#E8CC10", "petal": "#DEC009", "petal_lo": "#CCAA06",
    "center": "#E2C60C", "center_lo": "#D0B006",
    "stem": "#7B8C2F", "stem_lo": "#6E7E28",
    "leaf_hi": "#83942F", "leaf": "#7B8C2F", "leaf_lo": "#6E7E28",
    "leaf2": "#7B8C2F", "leaf2_lo": "#6E7E28",
    "base": "#6DA347", "base_lo": "#5A8E38",
}
DETAIL = fc.DETAIL
P = {
    "H": 0.5,
    "head": dict(x=0.03, z=0.85, tilt=42, n=6, L=0.15, W=0.1, T=0.04, rc=0.07, dome=1.0, taper=0.5,
                 cup=18, calyx=0.06),
    "stem": dict(r=0.018, pts=[(0.01, 0.0), (0.01, 0.4), (0.02, 0.83)]),
    "leaves": [dict(z=0.67, side=1, el=25, L=0.15, W=0.05, curl=0.04),
               dict(z=0.55, side=-1, el=20, L=0.19, W=0.06, curl=0.04)],
}


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
