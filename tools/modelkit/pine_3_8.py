# -*- coding: utf-8 -*-
"""Ялинка за малюнком pine_3_8.png: чотири яруси з округлими пелюстками-лусками по краю
(гранчасті, як ліплені), приглушено-зелена хвоя, світлий сірувато-брунатний стовбур.
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#162919", "leaf_lo": "#2B4730", "leaf": "#43644A", "leaf_hi": "#648368",
    "bark_lo": "#634A32", "bark": "#7F6147", "bark_hi": "#AD8C6E",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.2,
    "facet": 0.5,
    "trunk": dict(top=0.5, r0=0.10, r1=0.065, facets=True),
    "tiers": [
        dict(rim=0.36, apex=0.66, r=0.32, power=0.9, lobes=10, style="round", drop=0.04, bulge=0.05, ridge=0.15),
        dict(rim=0.575, apex=0.80, r=0.28, power=0.9, lobes=9, style="round", drop=0.035, bulge=0.05, ridge=0.15),
        dict(rim=0.725, apex=0.90, r=0.22, power=0.9, lobes=8, style="round", drop=0.03, bulge=0.05, ridge=0.15),
        dict(rim=0.845, apex=1.0, r=0.14, power=0.9, lobes=7, style="round", drop=0.025, bulge=0.05),
    ],
    "bones": [0.0, 0.36, 0.575, 0.725, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
