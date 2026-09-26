# -*- coding: utf-8 -*-
"""Млин 2 за малюнком mill_2.jpg: кремова вежа-зрізаний конус на цоколі з сірих брил,
червоний конічний дах із товстим краєм, чотири ґратчасті крила (дві клітинки завширшки),
маточина з кільцем, кругле брунатне віконце, арочні двері в сірій кам'яній арці, чорна
засувка й латунна ручка.

Збирач — mill_common.build_mill; тут лише палітра й розміри з малюнка (пікселі 1024²).
Крила — окрема частина «sails» з віссю в маточині, винесені перед краєм даху (зазор друкує
збірка: «ЗАЗОР КРИЛ»)."""
import kit
from mill_common import build_mill, mill_materials

# Палітра — k-середні по пікселях млина (26.09) і точкові проби; на крок світліша за «сирі».
# Кремова стіна й сірий камінь трохи тепліші за пробу: зелене тло малюнка підсвічує модель у
# рендері зеленим, і без цього стіна виходила оливковою.
PAL = {
    "tower_hi": "#FFF3E6", "tower": "#FAE6CF", "tower_lo": "#EBD3B6",
    "stone_hi": "#CFC3B3", "stone": "#B5AA98", "stone_lo": "#948976", "core": "#6F685C",
    "roof_hi": "#EE9C86", "roof": "#DC735C", "roof_lo": "#C45A42", "eave": "#B24C34",
    "sail_hi": "#CE9A63", "sail": "#BA8550", "sail_lo": "#A27043",
    "hub": "#A87444", "hub_hi": "#C89260",
    "door_hi": "#7C4E2B", "door": "#683F23", "door_line": "#472812",
    "frame_hi": "#BDB6A2", "frame": "#A69F8B", "frame_lo": "#8C8573",
    "win": "#8A5B30", "win_hi": "#9C6A3A", "latch": "#2E2A26", "knob": "#C8964E",
}

SPEC = dict(
    ground=812, cx=526, fx=492,
    plinth=dict(style="blocks", top=730, half=164, rows=2, per=11, depth=30, seed=5),
    tower=dict(bottom=730, bottom_half=150, top=478, top_half=135),
    roof=dict(eave=(478, 445, 166), profile=[(160, 446), (36, 291), (20, 284), (0, 282)], bevel=0.04),
    hub=dict(y=392, r=26, style="ring"),
    sails=dict(reach=252, width=58, start=45, rows=5, cols=2, rail=13, rung=10, thick=11, over=6),
    door=dict(half=52, top=695, frame="tube", frame_w=17, latch=(455, 772), knob=(521, 765, 9)),
    window=dict(y=583, r=18, style="disk"),
)


def materials(k):
    return mill_materials(k)


def build(m, k):
    return build_mill(m, k, SPEC)
