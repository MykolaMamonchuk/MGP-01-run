# -*- coding: utf-8 -*-
"""Ялина за малюнком pine_3_5.png: шість ярусів-спідничок із дрібною бахромою (зубці-хвоїнки
по краю) і гостра верхівка; стовбур з розширеним комлем.
Родина — tree_common.py; тут лише параметри (частки висоти з силуету малюнка) і палітра.
Бахрома — lobe_seg=2 (вершина-зубець, вершина-виріз), щоб дрібні зубці не коштували вершин."""
import tree_common as tc

PAL = {   # кластери непрозорих пікселів малюнка: сирі кластери × 0.90 (листя), × 1.00 (кора) — підібрано заміром
    "leaf_dark": "#284434", "leaf_lo": "#345D4A", "leaf": "#3C6B56", "leaf_hi": "#517E68",
    "bark_lo": "#754E35", "bark": "#9A6A4A", "bark_hi": "#AA7A5A",
}
DETAIL = tc.DETAIL
# (край, радіус) ярусів знизу вгору — з силуету; верхівка кожного — на схилі всього дерева
RIMS = [(0.325, 0.33), (0.445, 0.29), (0.545, 0.245), (0.635, 0.205), (0.725, 0.165), (0.815, 0.11)]
P = {
    "H": 2.2,
    "facet": 0.35,
    "trunk": dict(top=0.5, r0=0.075, r1=0.05, flare=0.03, facets=True),
    "tiers": [dict(rim=z, apex=min(1.0, z + r / 0.62) if i < len(RIMS) - 1 else 1.0, r=r, lobes=0,
                   style="point", drop=0.028, bulge=0.06, lobe_seg=2, rings=2, power=1.6 if i < len(RIMS) - 1 else 1.0,
                   thick=0.012)
              for i, (z, r) in enumerate(RIMS)],
    "bones": [0.0, 0.325, 0.545, 0.725, 1.0],
    "bone_names": ["trunk", "crown0", "crown1", "crown2"],
}
LOBES = {"high": (28, 26, 22, 18, 16, 12), "mid": (18, 16, 14, 12, 10, 8), "low": (10, 9, 8, 8, 6, 6)}


def materials(k):
    return tc.materials(k, P)


def build(m, k):
    key = "high" if k.DET["bev"] >= 3 else "mid" if k.DET["bev"] == 2 else "low"
    for t, n in zip(P["tiers"], LOBES[key]):
        t["lobes"] = n
    return tc.build_tree(m, k, P)
