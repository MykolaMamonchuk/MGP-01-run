# -*- coding: utf-8 -*-
"""Млин 4 за малюнком mill_4.jpg: вежа з кремових брил на помаранчевому обідку, темний пасок
із білими камінцями під дахом, червоний конічний дах із заокругленим низом і кулькою на
маківці, чотири крила-драбинки з темними поперечками на кінцях і товстими брусами від
маточини, кругле темне вікно в брунатних кільцях, арочні двері в арці з брил, чорна засувка.

Збирач — mill_common.build_mill; тут лише палітра й розміри з малюнка (пікселі 1024²)."""
import kit
from mill_common import build_mill, mill_materials

# Палітра — k-середні по пікселях млина (26.09) і точкові проби; на крок світліша за «сирі».
PAL = {
    "tower_hi": "#FCE6BC", "tower": "#F0D2A2", "tower_lo": "#D8B98A", "core": "#8C7A5C",
    "stone_hi": "#EDB97F", "stone": "#DCA56E", "stone_lo": "#C08A57",
    "roof_hi": "#E8807C", "roof": "#D86662", "roof_lo": "#BC4E4C",
    "band": "#555049", "pebble": "#D8D6D0", "pebble_lo": "#AFAEA8",
    "sail_hi": "#E0AC7E", "sail": "#D09A6C", "sail_lo": "#B27C54", "sail_cap": "#8E4F35",
    "hub": "#7A4632", "hub_hi": "#8E5840",
    "door_hi": "#9A5A3C", "door": "#874D33", "door_line": "#5E321E",
    "frame_hi": "#FCE6BC", "frame": "#F0D2A2", "frame_lo": "#D8B98A",
    "win": "#70402A", "win_hi": "#87543A", "ring_o": "#A86E4A",
    "glass": "#37414A", "glass_hi": "#8C9BA6", "latch": "#2A231D", "knob": "#2A231D",
}

SPEC = dict(
    ground=798, cx=515, fx=511,
    plinth=dict(style="ring", top=756, half=166),
    tower=dict(bottom=756, bottom_half=160, top=425, top_half=133, blocks=dict(rows=6, per=9, depth=12, seed=4)),
    band=dict(bottom=425, top=391, half=128, pebbles=14, pebble_r=13),
    roof=dict(profile=[(120, 393), (144, 384), (148, 368), (140, 352), (96, 300), (52, 250), (34, 223), (0, 220)],
              knob=(201, 27), bevel=0.03),
    hub=dict(y=421, r=21, style="cap", cap_r=15, cap_mat="hub"),
    sails=dict(reach=293, width=62, start=118, rows=9, cols=1, rail=12, rung=9, thick=12, over=4,
               caps=(80, 20), spar=22, rung_bevel=False),
    door=dict(half=65, top=651, frame="blocks", frame_w=30, stones=7, jambs=3, latch=(470, 740)),
    window=dict(y=568, r=18, ring=32, style="rings", out=12),
)


def flat(k, name, key):
    return k.mat_gradient(name, [(0.0, key), (1.0, key)], 0.0, 1.0, 0.0)


def materials(k):
    return mill_materials(k, {
        "band": flat(k, "band", "band"),
        "pebble": k.mat_gradient("pebble", [(0.0, "pebble_lo"), (1.0, "pebble")], 1.2, 1.36, 0.3, 30.0),
        "sail_cap": flat(k, "sail_cap", "sail_cap"),
        "ring_o": flat(k, "ring_o", "ring_o"),
    })


def build(m, k):
    return build_mill(m, k, SPEC)
