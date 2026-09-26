# -*- coding: utf-8 -*-
"""Високе дерево за малюнком wall_tree_tall_1.png: довгий тонкий стовбур з коренями, угорі —
вузька крона з чотирьох ярусів листків із загостреними кінчиками, бірюзово-зелена.
Травичку й квіти на підставці не моделюємо (у замірі відрізані crop).
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.90 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#136444", "leaf_lo": "#318861", "leaf": "#47976E", "leaf_hi": "#5BA67A",
    "bark_lo": "#875036", "bark": "#A66D52", "bark_hi": "#B47E64",
}
DETAIL = tc.DETAIL
P = {
    "H": 3.0,
    "facet": 0.45,
    "trunk": dict(top=0.62, r0=0.07, r1=0.045, flare=0.035, roots=5, root_amp=0.6),
    "tiers": [
        dict(rim=0.515, apex=0.68, r=0.16, lobes=9, style="leaf", drop=0.025, bulge=0.06, ridge=0.1),
        dict(rim=0.605, apex=0.80, r=0.185, lobes=9, style="leaf", drop=0.025, bulge=0.06, ridge=0.1),
        dict(rim=0.715, apex=0.89, r=0.165, lobes=8, style="leaf", drop=0.022, bulge=0.06, ridge=0.1),
        dict(rim=0.815, apex=1.0, r=0.135, power=0.8, lobes=7, style="leaf", drop=0.02, bulge=0.06, ridge=0.1),
    ],
    "bones": [0.0, 0.25, 0.515, 0.715, 1.0],
    "bone_names": ["trunk", "trunk_top", "crown0", "crown1"],
}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    return tc.build_tree(m, k, P)
