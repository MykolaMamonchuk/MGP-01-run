# -*- coding: utf-8 -*-
"""Кіоск за малюнком kiosk_1.png: круглий корпус із жовтих вертикальних дощок на кам'яному
цоколі, м'ятний купол пелюстками над спідницею з панелей, жовта фігурна шапочка з кулькою,
рожевий димар із комірцем, вікно зі шпросами й помаранчевим ящиком-підвіконням, двері із
заскленим верхом, вивіска на стовпчику (без напису: у грі його однаково не прочитати) і горщик
із кущиком ліворуч. Деталі розставлено так, як їх видно на малюнку (kiosk_common.cam_ang)."""
import math

from kit import box, cyl, soften, sphere
import kiosk_common as kc

AZ = -24          # кут камери заміру (refs/kiosk_1.json): двері — просто вперед (−Y)

PAL = {
    "wood_hi": "#CFAC71", "wood": "#C69B5D", "wood_lo": "#B2884E", "wood_line": "#A87E47",
    "dome_hi": "#83AC99", "dome": "#739E8B", "dome_lo": "#5E8D7D", "dome_line": "#457567",
    "cap_hi": "#D3B371", "cap": "#CA9753",
    "pink_hi": "#BE716E", "pink": "#A65B5A",
    "frame_hi": "#7D482C", "frame": "#6D3D2B", "frame_lo": "#5D3121",
    "door_hi": "#BD7E59", "door": "#B7744F", "door_lo": "#A05F3D",
    "glass": "#E6F8EE", "glass_hi": "#FFFFFF",
    "dglass": "#5A5560", "dglass_hi": "#7F92A8",
    "sill_hi": "#C88A4B", "sill": "#B37337",
    "stone_hi": "#7E7D79", "stone": "#656460", "stone_line": "#4B4A47",
    "brass": "#B28741",
    "sign_hi": "#9E6648", "sign": "#915A3D", "letter": "#F2E8D8",
    "pot": "#5A301F", "pot_hi": "#713D28",
    "bush": "#506032", "bush_hi": "#647741",
}


def materials(k):
    return {
        "wood": k.mat_door("wood", keys=("wood_line", "wood", "wood_hi"), planks=13.0, direction="X"),
        "dome": k.mat_gradient("dome", [(0.0, "dome_lo"), (0.45, "dome"), (1.0, "dome_hi")], 0.85, 1.12, 0.05, 6.0),
        "skirt": k.mat_gradient("skirt", [(0.0, "dome_line"), (0.35, "dome_lo"), (1.0, "dome_hi")], 0.64, 0.86, 0.05, 6.0),
        "cap": k.mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 1.1, 1.22, 0.1, 8.0),
        "pink": k.mat_roof("pink", keys=("pink", "pink_hi", "pink_hi", "pink"), rows_scale=14.0, seams=22.0),
        "frame": k.mat_gradient("frame", [(0.0, "frame_lo"), (0.5, "frame"), (1.0, "frame_hi")], 0.0, 0.8, 0.2, 8.0),
        "door": k.mat_door("door", keys=("door_lo", "door", "door_hi"), planks=9.0),
        "glass": k.mat_glass("glass"),
        "dglass": k.mat_glass("dglass", keys=("dglass", "dglass_hi")),
        "sill": k.mat_gradient("sill", [(0.0, "sill"), (1.0, "sill_hi")], 0.22, 0.29, 0.1, 8.0),
        "stone": k.mat_roof("stone", keys=("stone", "stone", "stone_hi", "stone_line"), rows_scale=12.0, seams=14.0),
        "brass": k.mat_gradient("brass", [(0.0, "brass"), (1.0, "brass")], 0.0, 1.0, 0.0),
        "sign": k.mat_door("sign", keys=("frame", "sign", "sign_hi"), planks=4.0, direction="Z"),
        "letter": k.mat_gradient("letter", [(0.0, "letter"), (1.0, "letter")], 0.0, 1.0, 0.0),
        "pot": k.mat_gradient("pot", [(0.0, "pot"), (1.0, "pot_hi")], 0.0, 0.1, 0.1, 8.0),
        "bush": k.mat_gradient("bush", [(0.0, "bush"), (1.0, "bush_hi")], 0.1, 0.2, 0.2, 9.0),
    }


def build(m, k):
    R, H = 0.43, 0.68
    D = k.DET
    seg = max(12, D["cyl"] * 2)             # корпус і дах — круглі, на них дивляться впритул
    bev = min(2, D["bev"])

    kc.plank_body(m["wood"], R, 0.0, H, seg)
    # Кам'яний цоколь — кільце з каменів (шви — текстурою), трохи ширше за стіну.
    base = cyl("base", m["stone"], (0, 0, 0.045), R + 0.035, 0.09, verts=seg)
    soften(base, 0.02)

    # Спідниця даху: пологий розтруб із 16 панелей (подушечки між швами).
    rings = D["cyl"] >= 12
    # Профіль — «бублик» подушок: від низу біля стіни назовні, опукло вгору й до купола.
    sk_prof = [(0.5, 0.65), (0.57, 0.655), (0.588, 0.68)] + ([(0.575, 0.715), (0.535, 0.77)] if rings else [(0.56, 0.735)]) \
        + [(0.5, 0.815), (0.48, 0.84)]
    kc.revolve("skirt", m["skirt"], sk_prof, seg * 2 if D["cyl"] >= 20 else seg,
               rmod=lambda phi, i, f=kc.lobes(16, 0.06, 0.5): f(phi) if 0 < i < len(sk_prof) - 1 else 1.0,
               cap_bottom=False, cap_top=False)
    kc.revolve("skirt_under", m["skirt"], [(R - 0.01, 0.70), (0.5, 0.65)], seg, cap_bottom=False, cap_top=False)

    # Купол: 12 пелюсток-подушок.
    n_d = {20: 5, 12: 4, 6: 3}.get(D["cyl"], 4)
    kc.revolve("dome", m["dome"], kc.ellipse_prof(0.485, 0.27, 0.83, n_d, r_top=0.02), seg * 2 if D["cyl"] >= 20 else seg,
               rmod=lambda phi, i, f=kc.lobes(12, 0.06): f(phi), cap_bottom=False)

    # Жовта фігурна шапочка (8 пелюсток) з кулькою.
    kc.finial(m["cap"], m["cap"], 1.085, 0.15, 0.11, seg, n_lobes=8, lobe_depth=0.1, ball_r=0.036, rings=3)

    # Рожевий димар позаду праворуч: трохи звужений ствол із «лусочками», комірець зверху.
    cx, cy = kc.cam_xy(AZ, 0.38, -0.14)
    kc.place([kc.revolve("chimney", m["pink"], [(0.07, 0.9), (0.068, 1.02), (0.074, 1.13)], max(8, seg // 2)),
              kc.revolve("chimney_lip", m["pink"], [(0.078, 1.11), (0.105, 1.135), (0.105, 1.19), (0.09, 1.195)],
                         max(8, seg // 2), cap_bottom=False)], (cx, cy), 0.0)

    # Вікно ліворуч: товста рамка, світле скло, шпроси 1×2, помаранчевий ящик-підвіконня.
    win = []
    wz, ww, wh, ft = 0.465, 0.28, 0.33, 0.045
    win.append(box("win_glass", m["glass"], (0, 0.0, wz), (ww, 0.01, wh)))
    win.append(box("win_back", m["frame"], (0, 0.03, wz), (ww, 0.05, wh)))
    for dx in (-ww / 2 - ft / 2, ww / 2 + ft / 2):
        win.append(box("win_fs", m["frame"], (dx, 0.01, wz), (ft, 0.1, wh + 2 * ft)))
    for dz in (-wh / 2 - ft / 2, wh / 2 + ft / 2):
        win.append(box("win_ft", m["frame"], (0, 0.01, wz + dz), (ww + 2 * ft, 0.1, ft)))
    # горизонтальні шпроси на 3 мм попереду вертикальної: в одній площині перетин запікається
    # чорним квадратиком (див. kit.window)
    win.append(box("win_mv", m["frame"], (0, -0.012, wz), (0.02, 0.02, wh)))
    for dz in (-wh / 6, wh / 6):
        win.append(box("win_mh", m["frame"], (0, -0.015, wz + dz), (ww, 0.02, 0.02)))
    sill = box("win_sill", m["sill"], (0, -0.075, 0.262), (ww + 0.14, 0.15, 0.055))
    soften(sill, 0.012, bev)
    win.append(sill)
    sill2 = box("win_sill2", m["frame"], (0, -0.06, 0.212), (ww + 0.12, 0.12, 0.05))
    soften(sill2, 0.01, bev)
    win.append(sill2)
    kc.face_on(win, kc.cam_ang(AZ, -30), R + 0.01)

    # Двері: рамка, заскленений верх 2×2 (темне скло — видно нутро), дошки внизу, латунна ручка.
    door = []
    dw, dh, fd = 0.29, 0.6, 0.035
    door.append(box("door_panel", m["door"], (0, -0.02, dh * 0.5), (dw, 0.035, dh)))
    gz, gh = dh * 0.74, dh * 0.34
    door.append(box("door_glass", m["dglass"], (0, -0.04, gz), (dw * 0.72, 0.01, gh)))
    door.append(box("door_mv", m["door"], (0, -0.045, gz), (0.018, 0.012, gh)))
    door.append(box("door_mh", m["door"], (0, -0.048, gz), (dw * 0.72, 0.012, 0.018)))
    for dx in (-dw / 2 - fd / 2, dw / 2 + fd / 2):
        door.append(box("door_fs", m["door"], (dx, -0.005, (dh + fd) * 0.5), (fd, 0.09, dh + fd)))
    door.append(box("door_ft", m["door"], (0, -0.005, dh + fd / 2), (dw + 2 * fd, 0.09, fd)))
    door.append(sphere("door_knob", m["brass"], (dw * 0.36, -0.05, dh * 0.47), 0.024))
    kc.face_on(door, kc.cam_ang(AZ, 22), R - 0.01)

    # Вивіска на стовпчику праворуч попереду: стовпчик, комірець і кулька, дошка лицем до нас.
    sx, sy = kc.cam_xy(AZ, 0.56, 0.25)
    sign = [cyl("sign_post", m["sign"], (0, 0, 0.33), 0.036, 0.66, verts=max(6, seg // 3))]
    sign.append(kc.revolve("sign_top", m["sign"], [(0.04, 0.64), (0.05, 0.66), (0.03, 0.68)], max(6, seg // 3)))
    sign.append(sphere("sign_ball", m["sign"], (0, 0, 0.71), 0.04))
    board = box("sign_board", m["sign"], (0, -0.045, 0.43), (0.37, 0.035, 0.2))
    soften(board, 0.015, bev)
    sign.append(board)
    # напис «Hand & / Book» — світлими брусочками-буквами (читати не треба, а пляма світла є)
    for row, (zc, xs) in enumerate(((0.475, (-0.12, -0.065, -0.01, 0.045, 0.1)), (0.395, (-0.06, -0.005, 0.05, 0.1)))):
        for x in xs:
            sign.append(box("sign_letter", m["letter"], (x, -0.066, zc), (0.036, 0.008, 0.05)))
    kc.place(sign, (sx, sy), math.radians(AZ + 4))

    # Горщик із кущиком ліворуч попереду.
    px, py = kc.cam_xy(AZ, -0.53, 0.27)
    kc.place(kc.pot_plant(m["pot"], m["bush"], 0.1, 0.1, max(8, seg // 2), kind="bush", leaf_h=0.11), (px, py), 0.0)
    return {}
