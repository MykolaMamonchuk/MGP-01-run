# -*- coding: utf-8 -*-
"""Сосна за малюнком pine_3_2.png: три конічні яруси з гострими зубцями по краю, гостра
верхівка, конічний брунатний стовбур.
Родина — tree_common.py; тут лише параметри (частки висоти, зняті з силуету малюнка) і палітра.

Скелет для гойдання на вітрі: стовбур → нижній → середній → верхній ярус (ланцюжком, ваги —
автоматичні); у сцені порівняння кістки крутить src/debug/model_compare.gd."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.80 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#25462D", "leaf_lo": "#406749", "leaf": "#547F5D", "leaf_hi": "#68926E",
    "bark_lo": "#684628", "bark": "#7F5836", "bark_hi": "#A17045",
}
DETAIL = tc.DETAIL
P = {
    "H": 2.2,
    "facet": 0.45,
    "trunk": dict(top=0.55, r0=0.085, r1=0.055, facets=True),
    "tiers": [
        dict(rim=0.325, apex=0.73, r=0.305, power=1.1, lobes=11, style="round", drop=0.03, bulge=0.04),
        dict(rim=0.575, apex=0.82, r=0.195, power=1.3, lobes=9, style="round", drop=0.025, bulge=0.04),
        dict(rim=0.76, apex=1.0, r=0.135, power=1.4, lobes=7, style="round", drop=0.022, bulge=0.04),
    ],
    "bones": [0.0, 0.325, 0.575, 0.76, 1.0],
    "bone_names": ["trunk", "tier0", "tier1", "tier2"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
