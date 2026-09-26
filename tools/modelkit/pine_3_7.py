# -*- coding: utf-8 -*-
"""Ялина за малюнком pine_3_7.png: чотири яруси довгих гілок-«лап», що звисають донизу
загостреними кінцями, сизувато-зелена хвоя, тонкий брунатний стовбур.
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра.
Лапи — лопаті «leaf» з великим опусканням кінця (drop) і ребрами по схилу (ridge)."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#2E4236", "leaf_lo": "#3E574A", "leaf": "#4E6A5A", "leaf_hi": "#6A836E",
    "bark_lo": "#73492F", "bark": "#A36E46", "bark_hi": "#B37E56",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.3,
    "facet": 0.45,
    "trunk": dict(top=0.5, r0=0.07, r1=0.045, flare=0.01, facets=True),
    "tiers": [
        dict(rim=0.33, apex=0.72, r=0.37, power=2.0, lobes=6, style="leaf", drop=0.08, bulge=0.05, ridge=0.35, rot=0.0, dx=-0.02, tilt=0.12),
        dict(rim=0.51, apex=0.80, r=0.315, power=2.0, lobes=6, style="leaf", drop=0.05, bulge=0.05, ridge=0.35, rot=0.45, dx=-0.015, tilt=0.07),
        dict(rim=0.61, apex=0.88, r=0.26, power=2.0, lobes=6, style="leaf", drop=0.045, bulge=0.05, ridge=0.35, rot=0.2, dx=-0.01, tilt=0.05),
        dict(rim=0.735, apex=1.0, r=0.225, power=1.6, lobes=5, style="leaf", drop=0.04, bulge=0.05, ridge=0.35, rot=0.7),
    ],
    "bones": [0.0, 0.33, 0.51, 0.735, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
