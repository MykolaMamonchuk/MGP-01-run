# -*- coding: utf-8 -*-
"""Висока ялина за малюнком wall_tree_tall_2.png: чотири конічні яруси з дрібними зубцями на
високому конічному стовбурі з борознами, світла жовтувато-зелена хвоя.
Травичку-підставку не моделюємо (у замірі відрізана crop).
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#305119", "leaf_lo": "#4B7236", "leaf": "#59864C", "leaf_hi": "#759A65",
    "bark_lo": "#683518", "bark": "#854E2C", "bark_hi": "#B58056",
}
DETAIL = tc.DETAIL
P = {
    "H": 3.0,
    "facet": 0.45,
    "trunk": dict(top=0.6, r0=0.095, r1=0.05, flare=0.05, facets=True),
    "tiers": [
        dict(rim=0.47, apex=0.80, r=0.18, lobes=11, style="point", drop=0.015, bulge=0.04),
        dict(rim=0.61, apex=0.84, r=0.16, lobes=10, style="point", drop=0.014, bulge=0.04),
        dict(rim=0.74, apex=0.96, r=0.125, lobes=9, style="point", drop=0.012, bulge=0.04),
        dict(rim=0.86, apex=1.0, r=0.085, lobes=8, style="point", drop=0.01, bulge=0.04),
    ],
    "bones": [0.0, 0.25, 0.47, 0.74, 1.0],
    "bone_names": ["trunk", "trunk_top", "crown0", "crown1"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
