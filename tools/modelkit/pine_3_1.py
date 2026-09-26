# -*- coding: utf-8 -*-
"""Сосна за малюнком pine_3_1.png: три конічні яруси з круглими фестонами по краю й рядом
лусочок посередині схилу, гостра увігнута верхівка, темно-брунатний стовбур.
Родина — tree_common.py; тут лише параметри (частки висоти, зняті з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.90 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#245D32", "leaf_lo": "#326F3F", "leaf": "#498A4D", "leaf_hi": "#60A365",
    "bark_lo": "#453928", "bark": "#70523A", "bark_hi": "#8E6E54",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.2,
    "facet": 0.3,
    "trunk": dict(top=0.55, r0=0.10, r1=0.051, facets=True),
    "tiers": [
        dict(rim=0.325, apex=0.67, r=0.355, power=1.05, lobes=13, style="round", drop=0.018, bulge=0.05),
        dict(rim=0.54, apex=0.80, r=0.25, power=1.05, lobes=11, style="round", drop=0.018, bulge=0.05),
        dict(rim=0.725, apex=1.0, r=0.185, power=1.4, lobes=9, style="round", drop=0.018, bulge=0.05),
    ],
    "bones": [0.0, 0.30, 0.515, 0.705, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
