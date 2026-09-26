# -*- coding: utf-8 -*-
"""Кольоровий варіант flower_1: біла (ромашка). Та сама геометрія й скелет (P з flower_1), інша
лише палітра пелюсток і серединки — демонстрація перефарбування родини (малюнка-зразка нема,
тому й refs/*.json нема)."""
import flower_common as fc
import flower_1 as base

PAL = dict(base.PAL)
PAL.update({
    "petal_hi": "#FFFFFF", "petal": "#F6F4EE", "petal_lo": "#E4E0D6",
    "center": "#F6C43C", "center_lo": "#E8A628",
})
DETAIL = fc.DETAIL
P = base.P


def materials(k):
    return fc.materials(k, P)


def build(m, k):
    return fc.build(m, k, P)
