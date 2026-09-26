# -*- coding: utf-8 -*-
"""Сосна за малюнком pine_3_6.png: три пухкі яруси з великими круглими «подушками» по краю
(по 6-7 на ярус), увігнута гостра верхівка, товстий брунатний стовбур з розширеним комлем.
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#093720", "leaf_lo": "#26593C", "leaf": "#416E4C", "leaf_hi": "#6B8A66",
    "bark_lo": "#673B1D", "bark": "#835633", "bark_hi": "#AF7D51",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.2,
    "facet": 0.3,
    "trunk": dict(top=0.5, r0=0.10, r1=0.065, flare=0.025),
    "tiers": [
        dict(rim=0.37, apex=0.68, r=0.29, lobes=8, style="round", drop=0.045, bulge=0.1, ridge=0.2, thick=0.035),
        dict(rim=0.555, apex=0.80, r=0.255, lobes=6, style="round", drop=0.04, bulge=0.1, ridge=0.2, thick=0.03),
        dict(rim=0.715, apex=1.0, r=0.195, power=1.5, lobes=6, style="round", drop=0.035, bulge=0.1, ridge=0.2, thick=0.03),
    ],
    "bones": [0.0, 0.37, 0.555, 0.715, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
