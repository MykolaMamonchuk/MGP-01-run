# -*- coding: utf-8 -*-
"""Кіоск за малюнком kiosk_2.png: шестигранний корпус із кремових вертикальних дощок (на
малюнку видно ребро-стовпчик посередині й дві грані), бірюзовий конусний дах «сходинками» з
фестонами над кремовим карнизом, жовта маківка зі шпилем, бірюзовий димар-гриб на цегляному
стовпчику. Ліва грань — прилавок: смугаста маркіза, темне нутро з ящиком, жовта стільниця й
бірюзові дверцята з помаранчевими ручками. Права — вікно з візерунком (кремовий хрест і ромб,
рожеві кути, бірюзове скло, жовта серединка) на підвіконні, кронштейни під карнизом,
ліхтарик-крапля праворуч, кам'яна кладка знизу, горщик із листям і камінець біля ребра.

Деталі розставлено так, як їх видно на малюнку (kiosk_common.cam_ang); камера заміру —
refs/kiosk_2.json, AZ нижче мусить з ним збігатися. kiosk_3 = цей кіоск + табличка-мольберт."""
import math

from kit import box, soften, sphere
import kiosk_common as kc

AZ = -30          # кут камери заміру (refs/kiosk_2.json): ребро корпусу — просто на камеру

PAL = {
    "wood_hi": "#D0B078", "wood": "#C29B63", "wood_line": "#A9814B",
    "post_hi": "#D0B077", "post": "#C3A067",
    "roof_hi": "#75B5A9", "roof": "#549B8F", "roof_lo": "#337871",
    "eave_hi": "#D8BB85", "eave": "#CEAD75",
    "cap_hi": "#DAC97C", "cap": "#CFB35C",
    "brick_hi": "#AD673F", "brick": "#995631",
    "mush_hi": "#60A99D", "mush": "#439185",
    "awn_t": "#26776C", "awn_w": "#E7E1D2",
    "inside": "#4D3628", "inside_hi": "#655240",
    "counter_hi": "#D8AD59", "counter": "#CE9B49",
    "tdoor_hi": "#266E63", "tdoor": "#1E5E54", "tdoor_line": "#15443D",
    "knob": "#BB6F35",
    "frame_hi": "#A25B2C", "frame": "#8A4723",
    "cross": "#D3B985", "pink": "#C2857C", "tglass": "#5CA699", "yellow": "#D5B459",
    "sill_hi": "#DABE8A", "sill": "#D1AD75",
    "lamp_hi": "#FFFFF6", "lamp": "#EAE4D2",
    "stone_hi": "#A9A496", "stone": "#918B7F", "cblock": "#D0B075",
    "plinth": "#5E594E",
    "pot_hi": "#998F7A", "pot": "#837863", "leaf_hi": "#B9B260", "leaf": "#9F9D49",
    "box_hi": "#A67A47", "box": "#865E34", "label": "#333F36",
}


def materials(k):
    return {
        "wood": k.mat_door("wood", keys=("wood_line", "wood", "wood_hi"), planks=16.0, direction="X"),
        "post": k.mat_gradient("post", [(0.0, "post"), (1.0, "post_hi")], 0.0, 0.8, 0.2, 7.0),
        "roof": k.mat_gradient("roof", [(0.0, "roof_lo"), (0.25, "roof"), (1.0, "roof_hi")], 0.86, 1.24, 0.05, 6.0),
        "eave": k.mat_gradient("eave", [(0.0, "eave"), (1.0, "eave_hi")], 0.8, 0.87, 0.05, 6.0),
        "cap": k.mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 1.23, 1.36, 0.1, 8.0),
        "brick": k.mat_gradient("brick", [(0.0, "brick"), (1.0, "brick_hi")], 1.0, 1.3, 0.2, 9.0),
        "mush": k.mat_gradient("mush", [(0.0, "mush"), (1.0, "mush_hi")], 1.3, 1.39, 0.05, 8.0),
        "awn": kc.mat_stripes(k, "awn", ("awn_t", "awn_w"), 0.16, kc.cam_ang(AZ, -30)),
        "inside": k.mat_gradient("inside", [(0.0, "inside"), (1.0, "inside_hi")], 0.35, 0.62, 0.3, 8.0),
        "counter": k.mat_gradient("counter", [(0.0, "counter"), (1.0, "counter_hi")], 0.3, 0.37, 0.1, 8.0),
        "tdoor": k.mat_door("tdoor", keys=("tdoor_line", "tdoor", "tdoor_hi"), planks=22.0, direction="X"),
        "knob": k.mat_gradient("knob", [(0.0, "knob"), (1.0, "knob")], 0.0, 1.0, 0.0),
        "frame": k.mat_gradient("frame", [(0.0, "frame"), (1.0, "frame_hi")], 0.3, 0.8, 0.2, 8.0),
        "cross": k.mat_gradient("cross", [(0.0, "cross"), (1.0, "cross")], 0.0, 1.0, 0.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink")], 0.0, 1.0, 0.0),
        "tglass": k.mat_gradient("tglass", [(0.0, "tglass"), (1.0, "tglass")], 0.0, 1.0, 0.0),
        "yellow": k.mat_gradient("yellow", [(0.0, "yellow"), (1.0, "yellow")], 0.0, 1.0, 0.0),
        "sill": k.mat_gradient("sill", [(0.0, "sill"), (1.0, "sill_hi")], 0.3, 0.36, 0.1, 8.0),
        "lamp": k.mat_gradient("lamp", [(0.0, "lamp"), (1.0, "lamp_hi")], 0.5, 0.72, 0.05, 8.0),
        "stone": k.mat_gradient("stone", [(0.0, "stone"), (1.0, "stone_hi")], 0.0, 0.3, 0.3, 9.0),
        "cblock": k.mat_gradient("cblock", [(0.0, "cblock"), (1.0, "cblock")], 0.0, 1.0, 0.0),
        "plinth": k.mat_gradient("plinth", [(0.0, "plinth"), (1.0, "stone")], 0.0, 0.06, 0.2, 9.0),
        "pot": k.mat_gradient("pot", [(0.0, "pot"), (1.0, "pot_hi")], 0.0, 0.1, 0.1, 8.0),
        "leaf": k.mat_gradient("leaf", [(0.0, "leaf"), (1.0, "leaf_hi")], 0.08, 0.22, 0.1, 8.0),
        "box": k.mat_gradient("box", [(0.0, "box"), (1.0, "box_hi")], 0.35, 0.45, 0.1, 8.0),
        "label": k.mat_gradient("label", [(0.0, "label"), (1.0, "label")], 0.0, 1.0, 0.0),
    }


R = 0.48                          # радіус описаного кола шестигранника
AP = R * math.cos(math.pi / 6)    # до середини грані
H = 0.8                           # від землі до карниза


def stall(m, k, bev, fine=True):
    """Прилавок на грані (лицем до −Y у (0,0)): отвір із темним нутром, маркіза, стільниця,
    бірюзові дверцята з ручками, брунатний брус угорі."""
    obs = []
    ow, oz0, oz1 = 0.34, 0.34, 0.62
    obs.append(box("st_inside", m["inside"], (0, 0.02, (oz0 + oz1) / 2), (ow, 0.03, oz1 - oz0)))
    # ящик на прилавку з темною табличкою й стовпчик-підставка за ним
    obs.append(box("st_box", m["box"], (0.04, -0.03, oz0 + 0.05), (0.14, 0.08, 0.1)))
    if fine:   # дрібниці нутра — лише зблизька
        obs.append(box("st_label", m["label"], (0.04, -0.072, oz0 + 0.05), (0.1, 0.006, 0.04)))
        obs.append(box("st_stand", m["box"], (0.04, -0.0, oz0 + 0.16), (0.03, 0.03, 0.14)))
        obs.append(box("st_jar", m["box"], (-0.1, -0.02, oz0 + 0.04), (0.06, 0.05, 0.07)))
    # бокові одвірки й брус угорі
    for dx in (-ow / 2 - 0.02, ow / 2 + 0.02):
        obs.append(box("st_jamb", m["post"], (dx, -0.01, (oz0 + oz1) / 2), (0.04, 0.05, oz1 - oz0)))
    head = box("st_head", m["frame"], (0, -0.03, 0.735), (ow + 0.1, 0.04, 0.04))
    obs.append(head)
    # маркіза: похилий дашок зі смугами, передній край нижче
    awn = box("st_awning", m["awn"], (-0.02, -0.075, 0.672), (ow + 0.14, 0.17, 0.02), rot=(math.radians(28), 0, 0))
    soften(awn, 0.006, bev)
    obs.append(awn)
    obs.append(box("st_awn_lip", m["awn"], (-0.02, -0.152, 0.612), (ow + 0.14, 0.014, 0.05)))
    # стільниця
    ctr = box("st_counter", m["counter"], (-0.01, -0.06, oz0 - 0.005), (ow + 0.12, 0.13, 0.045))
    soften(ctr, 0.012, bev)
    obs.append(ctr)
    # дверцята (дві стулки) і ручки
    obs.append(box("st_doors", m["tdoor"], (0, -0.012, 0.165), (ow, 0.025, 0.27)))
    if fine:
        obs.append(box("st_doorgap", m["tdoor"], (0, -0.026, 0.165), (0.012, 0.006, 0.27)))
    for dx in (-0.12, 0.12):
        obs.append(sphere("st_knob", m["knob"], (dx, -0.03, 0.2), 0.02))
    return obs


def deco_window(m, k, bev, fine=True):
    """Вікно з візерунком (лицем до −Y у (0,0)): брунатна рамка, бірюзове скло, рожеві кути,
    кремовий хрест і ромб, жовта серединка; підвіконня й два кронштейни над вікном."""
    obs = []
    wz, ww, wh, ft = 0.545, 0.26, 0.34, 0.035
    obs.append(box("dw_glass", m["tglass"], (0, 0.0, wz), (ww, 0.02, wh)))
    for sx in ((-1, 1) if fine else ()):
        for sz in (-1, 1):
            c = box("dw_pink", m["pink"], (sx * (ww / 2 - 0.035), -0.012, wz + sz * (wh / 2 - 0.035)), (0.07, 0.006, 0.07))
            obs.append(c)
    obs.append(box("dw_cross_v", m["cross"], (0, -0.014, wz), (0.05, 0.008, wh)))
    obs.append(box("dw_cross_h", m["cross"], (0, -0.017, wz), (ww, 0.008, 0.05)))   # на 3 мм попереду: без чорного перетину
    obs.append(box("dw_diamond", m["cross"], (0, -0.0105, wz), (0.15, 0.008, 0.15), rot=(0, math.radians(45), 0)))
    obs.append(sphere("dw_center", m["yellow"], (0, -0.03, wz), 0.028))
    for dx in (-ww / 2 - ft / 2, ww / 2 + ft / 2):
        obs.append(box("dw_fs", m["frame"], (dx, -0.01, wz), (ft, 0.06, wh + 2 * ft)))
    for dz in (-wh / 2 - ft / 2, wh / 2 + ft / 2):
        obs.append(box("dw_ft", m["frame"], (0, -0.01, wz + dz), (ww + 2 * ft, 0.06, ft)))
    sill = box("dw_sill", m["sill"], (0.03, -0.05, wz - wh / 2 - ft - 0.02), (ww + 0.16, 0.11, 0.04))
    soften(sill, 0.01, bev)
    obs.append(sill)
    # кронштейни під карнизом (Г-подібні): стояк на стіні і плече вперед
    for dx in (-ww / 2 + 0.01,):
        obs.append(box("dw_br_v", m["frame"], (dx, -0.02, 0.73), (0.04, 0.04, 0.12)))
        obs.append(box("dw_br_h", m["frame"], (dx, -0.07, 0.775), (0.04, 0.1, 0.04)))
        if fine:
            obs.append(box("dw_br_d", m["frame"], (dx, -0.05, 0.735), (0.03, 0.03, 0.09), rot=(math.radians(45), 0, 0)))
    return obs


def stones(m, fine=True):
    """Кладка знизу праворуч: сірі камені й кремові блоки (лицем до −Y у (0,0)); на low —
    лише чотири найбільші."""
    obs = []
    rows = ((0.02, 0.06, 0.11, 0.1, "stone"), (0.14, 0.05, 0.1, 0.09, "stone"),
            (0.2, 0.16, 0.08, 0.12, "stone"), (0.07, 0.19, 0.1, 0.1, "cblock"),
            (0.0, 0.29, 0.06, 0.05, "stone"), (0.17, 0.27, 0.07, 0.06, "cblock"),
            (0.24, 0.05, 0.05, 0.09, "stone"))
    for i, (x, z, w, h, mat) in enumerate(rows if fine else rows[:4]):
        b = box("stone_%d" % i, m[mat], (x, -0.012, z), (w, 0.03, h))
        soften(b, 0.01, 1)
        obs.append(b)
    return obs


def build(m, k):
    D = k.DET
    bev = min(2, D["bev"])
    lvl = {20: "high", 12: "mid", 6: "low"}.get(D["cyl"], "mid")
    # дах: фестонів 16 (на low — 12), на кожен щонайменше 2 вершини кільця
    seg, scal = {"high": (48, 16), "mid": (32, 16), "low": (24, 12)}[lvl]
    eseg = {"high": 32, "mid": 16, "low": 12}[lvl]
    phase = math.radians(AZ)                               # ребро шестигранника — на камеру

    kc.plank_body(m["wood"], R, 0.0, H, 6, phase=phase)
    kc.revolve("plinth", m["plinth"], [(R + 0.015, 0.0), (R + 0.015, 0.05), (R - 0.02, 0.05)], 6, phase=phase)
    # ребра-стовпчики на кожній вершині
    for j in range(6):
        a = phase + j * math.pi / 3
        p = box("corner_post", m["post"], (0, 0, H / 2 + 0.01), (0.09, 0.05, H - 0.02))
        kc.face_on([p], a, R - 0.012)

    # Карниз і дах: кремове кільце, бірюзовий конус з 5 сходинок над смугою фестонів.
    kc.revolve("eave", m["eave"], [(R + 0.0, 0.775), (0.515, 0.78), (0.525, 0.82), (0.52, 0.87), (0.44, 0.875)],
               eseg, cap_bottom=False, cap_top=False)
    kc.revolve("eave_under", m["eave"], [(0.1, 0.775), (R, 0.775)], 6, cap_bottom=False, cap_top=False, phase=phase)
    kc.stepped_cone("roof", m["roof"], 0.54, 0.86, 0.14, 1.235, 4 if lvl == "low" else 5, seg, lip=0.016,
                    scallops=scal, scallop_h=0.04, skirt_h=0.13, bulge=lvl == "high")

    # Маківка: гладка жовта шапочка зі шпилем і кулькою.
    kc.finial(m["cap"], m["cap"], 1.228, 0.118, 0.125, max(8, seg // 3), spire=0.11 if lvl != "low" else 0.0,
              ball_r=0.03, rings=3)

    # Димар: цегляний стовпчик (квадратний) і бірюзовий гриб-шапка.
    cx, cy = kc.cam_xy(AZ, 0.30, 0.1)
    ch = [box("chimney", m["brick"], (0, 0, 1.15), (0.13, 0.13, 0.32), rot=(0, 0, math.radians(AZ)))]
    ch.append(kc.revolve("chimney_cap", m["mush"], [(0.08, 1.295), (0.122, 1.3)] +
                         kc.ellipse_prof(0.122, 0.085, 1.31, 3 if lvl != "low" else 2), max(8, seg // 3)))
    kc.place(ch, (cx, cy), 0.0)

    # Ліва грань — прилавок, права — вікно, кладка, ліхтарик.
    fine = lvl != "low"
    kc.face_on(stall(m, k, bev, fine), kc.cam_ang(AZ, -30), AP)
    kc.face_on(kc.shift(deco_window(m, k, bev, fine), 0.04), kc.cam_ang(AZ, 30), AP)
    kc.face_on(kc.shift(stones(m, fine), 0.03), kc.cam_ang(AZ, 30), AP)

    # Ліхтарик-крапля на плечі кронштейна, що виходить із правого ребра вбік.
    vx, vy = kc.cam_xy(AZ, R * math.sin(math.pi / 3), R * 0.5)
    arm = [box("lamp_arm", m["frame"], (0.045, 0, 0.77), (0.1, 0.035, 0.035)),
           box("lamp_arm_v", m["frame"], (0.0, 0, 0.73), (0.035, 0.035, 0.1))]
    kc.place(arm, (vx, vy), math.radians(AZ))
    lx, ly = kc.cam_xy(AZ, 0.495, R * 0.5)
    lamp = [kc.revolve("lamp", m["lamp"], [(0.0, 0.49), (0.022, 0.53), (0.042, 0.59), (0.046, 0.63), (0.036, 0.67),
                                          (0.012, 0.695), (0.0, 0.7)], max(6, seg // 4))]
    lamp.append(box("lamp_hook", m["frame"], (0, 0, 0.73), (0.012, 0.012, 0.06)))
    kc.place(lamp, (lx, ly), 0.0)

    # Горщик із листям біля ребра праворуч і камінець біля нього.
    px, py = kc.cam_xy(AZ, 0.12, 0.44)
    kc.place(kc.pot_plant(m["pot"], m["leaf"], 0.065, 0.085, max(6, seg // 4), kind="leaves", leaf_h=0.1, n_leaves=7 if lvl != "low" else 4), (px, py), 0.3)
    rx, ry = kc.cam_xy(AZ, -0.02, 0.5)
    sphere("rock", m["stone"], (rx, ry, 0.012), 0.04, (1.2, 0.8, 0.45))
    return {}
