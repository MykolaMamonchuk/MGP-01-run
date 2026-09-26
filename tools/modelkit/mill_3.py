# -*- coding: utf-8 -*-
"""Млин 3 за малюнком mill_3.jpg: жовто-кремова вежа-конус на цоколі з бежевих брил,
червоний дах-«капелюх» із загнутими крисами й гострою маківкою, чотири довгі ґратчасті
крила, брунатна маточина з жовтою кнопкою, кругле вікно-ілюмінатор (кремова пластина з
заклепками, бірюзове скло з хрестом), арочні двері в арці з бежевих клинчаків, жовта ручка.

Збирач — mill_common.build_mill; тут лише палітра й розміри з малюнка (пікселі 1024²)."""
import kit
from mill_common import build_mill, mill_materials

# Палітра — k-середні по пікселях млина (26.09) і точкові проби; на крок світліша за «сирі».
PAL = {
    "tower_hi": "#FFE8B0", "tower": "#FCD690", "tower_lo": "#EEC07A",
    "stone_hi": "#EECBA0", "stone": "#D8B084", "stone_lo": "#BC966C", "core": "#8A6E50",
    "roof_hi": "#E8806A", "roof": "#D86650", "roof_lo": "#B84A38",
    "sail_hi": "#E6AE80", "sail": "#D49A6C", "sail_lo": "#BA805A",
    "hub": "#9A5A3C", "hub_hi": "#B06B48",
    "door_hi": "#B06A40", "door": "#9A5838", "door_line": "#6E3A20",
    "frame_hi": "#F2D6B0", "frame": "#E0BC8E", "frame_lo": "#C8A073",
    "win": "#8E6A48", "win_hi": "#A57C55", "glass": "#5FA595", "glass_hi": "#D5F0E8", "plate": "#FFF0D2", "plate_lo": "#E8D2A8",
    "latch": "#3A2A20", "knob": "#F0BE66",
}

SPEC = dict(
    ground=812, cx=510, fx=510,
    plinth=dict(style="blocks", top=690, half=162, rows=3, per=9, depth=26, seed=7),
    tower=dict(bottom=690, bottom_half=143, top=420, top_half=121),
    # «капелюх»: товсті загнуті криси, далі увігнутий конус до гострої маківки
    roof=dict(profile=[(112, 442), (144, 436), (150, 412), (143, 388), (120, 372), (90, 347), (66, 318),
                       (44, 285), (26, 257), (12, 238), (0, 231)], bevel=0.03),
    hub=dict(y=406, r=30, style="cap", cap_r=14, cap_mat="knob"),
    sails=dict(reach=284, width=62, start=42, rows=6, cols=2, rail=15, rung=11, thick=12, over=5),
    door=dict(half=50, top=668, frame="blocks", frame_w=38, stones=7, jambs=2, knob=(547, 735, 10)),
    window=dict(y=537, r=27, ring=44, style="porthole", rivets=8, out=12),
)


def materials(k):
    return mill_materials(k, {"plate": k.mat_gradient("plate", [(0.0, "plate_lo"), (0.6, "plate"), (1.0, "plate")], 1.0, 1.25, 0.1, 8.0)})


def build(m, k):
    return build_mill(m, k, SPEC)
