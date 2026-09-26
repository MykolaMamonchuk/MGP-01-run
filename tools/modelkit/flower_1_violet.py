# -*- coding: utf-8 -*-
"""Кольоровий варіант flower_1: фіалкова. Та сама геометрія й скелет (P з flower_1), інша
лише палітра пелюсток і серединки — демонстрація перефарбування родини (малюнка-зразка нема,
тому й refs/*.json нема)."""
import flower_common as fc
import flower_1 as base

PAL = dict(base.PAL)
PAL.update({
    "petal_hi": "#D8C2F4", "petal": "#BFA2EA", "petal_lo": "#A486D8",
    "center": "#F7C868", "center_lo": "#EDAA52",
})
DETAIL = fc.DETAIL
P = base.P


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
