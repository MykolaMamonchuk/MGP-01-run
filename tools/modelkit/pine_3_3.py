# -*- coding: utf-8 -*-
"""Сосна за малюнком pine_3_3.png: три яруси з великими загостреними «листками» по краю, що
звисають донизу, яскраво-зелена хвоя, рудувато-брунатний стовбур.
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#214126", "leaf_lo": "#3D6C3F", "leaf": "#508A52", "leaf_hi": "#5EA162",
    "bark_lo": "#855640", "bark": "#AB6D4D", "bark_hi": "#BB7D5D",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.2,
    "facet": 0.45,
    "trunk": dict(top=0.55, r0=0.095, r1=0.06, facets=True),
    "tiers": [
        dict(rim=0.35, apex=0.74, r=0.33, power=1.05, lobes=14, style="leaf", drop=0.05, bulge=0.05),
        dict(rim=0.60, apex=0.91, r=0.25, power=1.05, lobes=12, style="leaf", drop=0.04, bulge=0.07),
        dict(rim=0.80, apex=1.0, r=0.18, power=1.0, lobes=10, style="leaf", drop=0.03, bulge=0.07),
    ],
    "bones": [0.0, 0.35, 0.60, 0.80, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
