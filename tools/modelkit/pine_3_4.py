# -*- coding: utf-8 -*-
"""Сосна за малюнком pine_3_4.png: «низькополігональна» — три гранчасті (10 граней) яруси з
рівним краєм-спідничкою, гостра верхівка, короткий брунатний стовбур.
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра.
Грані видно завдяки facet: колір грані залежить від її нормалі (намальовано в текстурі)."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#1C412E", "leaf_lo": "#2D5D46", "leaf": "#36694F", "leaf_hi": "#477A5E",
    "bark_lo": "#633F31", "bark": "#825846", "bark_hi": "#926856",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.2,
    "facet": 0.4,
    "trunk": dict(top=0.4, r0=0.065, r1=0.05, facets=True),
    "tiers": [
        dict(rim=0.19, apex=0.65, r=0.34, sides=10, rings=5, shoulder=(0.8, 0.93), thick=0.01, facets=True),
        dict(rim=0.50, apex=0.87, r=0.245, sides=10, rings=5, shoulder=(0.8, 0.93), thick=0.01, facets=True),
        dict(rim=0.735, apex=1.0, r=0.172, sides=10, rings=5, shoulder=(0.85, 0.93), thick=0.01, facets=True),
    ],
    "bones": [0.0, 0.20, 0.50, 0.735, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    for t in P["tiers"]:
        t["sides"] = 10 if k.DET["bev"] >= 2 else 8
    return tc.build_tree(m, k, P)
