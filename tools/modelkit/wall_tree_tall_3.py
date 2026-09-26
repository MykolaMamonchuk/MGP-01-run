# -*- coding: utf-8 -*-
"""Кипарис за малюнком wall_tree_tall_3.png: видовжена крона-«яйце» з рядів круглих лусок
(шість ярусів-спідничок, округла верхівка), знизу — темніша закруглена куля, стовбур з коренями.
Травичку-підставку не моделюємо (у замірі відрізана crop).
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери
    "leaf_dark": "#346C25", "leaf_lo": "#528139", "leaf": "#58A256", "leaf_hi": "#84CF89",
    "bark_lo": "#8D532D", "bark": "#A46D48", "bark_hi": "#BE8763",
}
DETAIL = tc.DETAIL
RIMS = [(0.42, 0.18), (0.52, 0.18), (0.62, 0.17), (0.72, 0.155), (0.81, 0.13), (0.90, 0.10)]
P = {
    "H": 3.0,
    "facet": 0.4,
    "trunk": dict(top=0.4, r0=0.05, r1=0.042, flare=0.04, roots=5, root_amp=0.45),
    "tiers": [dict(rim=z, apex=(z + 0.17) if i < len(RIMS) - 1 else 1.0, r=r, power=0.7 if i == len(RIMS) - 1 else 1.0,
                   lobes=6 if i < 3 else 5, style="round", drop=0.025, bulge=0.03, thick=0.015, rot=0.45 * i)
              for i, (z, r) in enumerate(RIMS)],
    "balls": [(0.0, 0.0, 0.42, 0.19, 1)],
    "ball_squash": 0.85,
    "ball_amp": 0.03,
    "bones": [0.0, 0.3, 0.55, 0.78, 1.0],
    "bone_names": ["trunk", "crown0", "crown1", "crown2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
