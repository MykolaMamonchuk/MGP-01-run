# -*- coding: utf-8 -*-
"""Гірлянда за малюнком banner_line_2.png: тонші світлі стовпчики з кремовими кульками, білий
шнур, обмотаний біля верхівок, сім широких прапорців, пришитих навскоси (сірий, бірюзовий, жовтий, рожевий, зелений,
лимонний, бірюзовий). Цятки на прапорцях не моделюємо: з відстані гри їх не видно.

Пропорції з малюнка (250 пк = 1 м): проліт 2,56 м, стовпчик 1,78 м, шнур на 1,72 м, провис
0,31 м. Геометрія — bunting_common."""
import bunting_common as bc

PAL = {
    # Кластери малюнка, тоновані під світло заміру (біле тло + сонце): рендер світліший і
    # блідіший за малюнок, тож PAL ≈ 0,8 · (сер + 1,25 · (колір − сер)).
    "wood_hi": "#BC8856", "wood": "#B27B4B", "wood_lo": "#AA7246", "wood_line": "#9D653D",
    "ball": "#B6B09A", "ball_hi": "#C2BCA8",
    "rope": "#C4C0BA",
    "grey": "#A9A7A1", "teal": "#48A5A6", "yellow": "#BBB141", "pink": "#D37B73", "green": "#7EA669",
    "lemon": "#C8C155",
}

CFG = dict(
    span=2.556, height=1.78, pole_r=0.044, ball_r=0.068,
    attach=1.715, sag=0.31, rope_r=0.011, wrap=True, wrap_r=0.072, wrap_h=0.04, beads=0,
    flag_w=0.28, flag_h=0.29, flag_t=0.012, skew=0.0, sag_pow=1.8,
    flags=[(0.085, "grey"), (0.215, "teal"), (0.357, "yellow"), (0.5, "pink"), (0.643, "green"),
           (0.785, "lemon"), (0.915, "teal")],
)


def materials(k):
    return bc.materials(k, CFG)


def build(m, k):
    return bc.bunting(m, k, CFG)
