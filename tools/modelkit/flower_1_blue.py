# -*- coding: utf-8 -*-
"""Кольоровий варіант flower_1: блакитна. Та сама геометрія й скелет (P з flower_1), інша
лише палітра пелюсток і серединки — демонстрація перефарбування родини (малюнка-зразка нема,
тому й refs/*.json нема)."""
import flower_common as fc
import flower_1 as base

PAL = dict(base.PAL)
PAL.update({
    "petal_hi": "#BFDDF8", "petal": "#9CC8F0", "petal_lo": "#7FB0E0",
    "center": "#F7D468", "center_lo": "#EDB652",
})
DETAIL = fc.DETAIL
P = base.P


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
