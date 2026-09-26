# -*- coding: utf-8 -*-
"""tree_round_1 восени: та сама геометрія, розгортка й скелет — лише інша PAL (листя
помаранчеве, кора та сама). Так перефарбовується будь-яке дерево родини tree_common."""
from tree_round_1 import DETAIL, P, materials, build  # noqa: F401
import tree_round_1 as base

PAL = dict(base.PAL, leaf_dark="#9A3F12", leaf_lo="#C0581A", leaf="#E08A2C", leaf_hi="#F5C04E")
