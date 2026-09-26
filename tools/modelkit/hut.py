# -*- coding: utf-8 -*-
"""Хатинка за малюнком hut_test_draw.jpg: кремові стіни, крутий дах зі звисом, димар ліворуч,
кругле вікно в щипці, арочні двері, вікна по боках і ззаду. Див. kit.py і build.py."""
import math

from kit import (arch_curve, arch_profile, box, cyl, prism, soften, sphere, window,
                 mat_door, mat_glass, mat_gradient, mat_roof)
import kit
import bpy

# Палітра з малюнка (k-means по пікселях будинку, 26.09): світло → тінь.
PAL = {
    # Малюнок — студійний рендер у теплому світлі; ігрове світло холодніше й знебарвлює, тому
    # стіни й дах узяті на крок жовтішими за «сирі» кластери (перша спроба вийшла сіруватою).
    # Кольори малюнка вже містять студійне світло; гра кладе своє зверху й загалом темніша,
    # тож основний колір стін і даху — на крок світліший за «сирі» кластери (друга спроба в
    # ігровому світлі вийшла брунатною).
    "wall_hi": "#EED8B0", "wall": "#E6C898", "wall_lo": "#DDB886", "wall_foot": "#D0A472",
    "roof_hi": "#FFFAE6", "roof": "#FFF3D0", "roof_edge": "#F9E4B8", "roof_line": "#EBCD9C",
    "roof_under": "#B68D68",
    "chimney_hi": "#E7CA9C", "chimney_lo": "#CFA47A",
    "cap_hi": "#C27856", "cap": "#B65E3E",
    "door_hi": "#8A4229", "door": "#6E341F", "door_line": "#4A2112",
    "frame_hi": "#A85C38", "frame": "#8E472B",
    "glass": "#7FB6D3", "glass_hi": "#D8F0FA",
    "step_hi": "#BBB4B3", "step_lo": "#928584",
    "stone": "#928584", "stone_lo": "#90724F",
    "lantern": "#CE8C56",
}



def materials(k):
    return {
        "wall": k.mat_gradient("wall", [(0.0, "wall_foot"), (0.22, "wall_lo"), (0.55, "wall"), (1.0, "wall_hi")], 0.0, 1.4),
        # Лусочки на малюнку великі (~7 рядів на скат), дрібна сітка робила дах брунатним.
        "roof": k.mat_roof("roof", rows_scale=6.0, seams=9.0),
        "chimney": k.mat_gradient("chimney", [(0.0, "chimney_lo"), (1.0, "chimney_hi")], 0.9, 1.5),
        "cap": k.mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 1.49, 1.62, 0.1, 9.0),
        "door": k.mat_door("door"),
        "frame": k.mat_gradient("frame", [(0.0, "frame"), (1.0, "frame_hi")], 0.0, 1.2, 0.3, 9.0),
        "glass": k.mat_glass("glass"),
        "step": k.mat_gradient("step", [(0.0, "step_lo"), (1.0, "step_hi")], 0.0, 0.08, 0.2, 8.0),
        "stone": k.mat_gradient("stone", [(0.0, "stone_lo"), (1.0, "stone")], 0.1, 0.55, 0.3, 10.0),
        "lantern": k.mat_gradient("lantern", [(0.0, "frame"), (1.0, "lantern")], 0.42, 0.52, 0.1, 9.0),
    }


def build(m, kit):
    W, D = 1.0, 0.95          # корпус: ширина (X) і глибина (Y)
    # Пропорції — з малюнка (у пікселях фасаду, 320 пк = 1 м, 26.09): стіна до карниза 0,62,
    # скат 55°, звис опускається нижче верху дверей. Було 0,78 / 1,42 — хата виходила
    # «на ніжках», а дах коротким капелюхом.
    H = 0.62                  # висота стіни до карниза
    PEAK = 1.33               # гребінь щипця
    hw, hd = W * 0.5, D * 0.5
    # Корпус із щипцем, трохи ширший унизу — «ліплений», а не з лінійки.
    prof = [(-hw - 0.03, 0.0), (hw + 0.03, 0.0), (hw, H), (0.0, PEAK), (-hw, H)]
    body = prism("body", m["wall"], prof, -hd, hd)
    soften(body, 0.035)

    # ДАХ ЛЯГАЄ НА ЩИПЕЦЬ (замовник 26.09: «ніби парить над основою»). Раніше центр ската
    # стояв на 5 см вище, ніж треба, і під ним світилась щілина по всьому краю. Тепер спід
    # ската — рівно на лінії щипця, ще й на 1,5 см утоплений (скіс корпусу з'їдає ребро).
    slope = math.atan2(PEAK - H, hw)
    t = 0.09                                      # товщина ската
    run = math.hypot(hw, PEAK - H) + 0.22         # довжина ската зі звисом
    for side in (-1, 1):
        cx = side * (hw * 0.5 + 0.05)
        z_gable = PEAK - abs(cx) * math.tan(slope)
        cz = z_gable + (t * 0.5) / math.cos(slope) - 0.015
        r = box("roof%d" % side, m["roof"], (cx, 0.0, cz), (run, D + 0.16, t),
                rot=(0.0, side * slope, 0.0))
        soften(r, 0.03)

    # Димар ліворуч, ближче до фасаду (як на малюнку), крізь скат; шапка — брунатний «гриб».
    # На малюнку димар далеко ліворуч (−0,47 м від осі) і його шапка — врівень із гребенем,
    # а не над ним.
    CX = -0.47
    ch = box("chimney", m["chimney"], (CX, -0.08, 0.95), (0.22, 0.22, 0.76))
    soften(ch, 0.04)
    cap = cyl("cap", m["cap"], (CX, -0.08, 1.355), 0.16, 0.07)
    soften(cap, 0.02, min(2, kit.DET["bev"]))
    cap2 = cyl("cap2", m["cap"], (CX, -0.08, 1.42), 0.11, 0.07)
    soften(cap2, 0.02, min(2, kit.DET["bev"]))

    fy = -hd - 0.012          # передня площина стіни (−Y — фасад)

    # Кругле вікно в щипці: рамка-бублик, скло до середини бублика, хрестовина перед склом.
    ts, tr = kit.DET["tor"]
    bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.035, major_segments=ts,
                                     minor_segments=tr, location=(0.0, fy, 0.81), rotation=(math.pi / 2, 0, 0))
    ring = bpy.context.active_object
    ring.name = "win_ring"
    ring.data.materials.append(m["frame"])
    cyl("win_glass", m["glass"], (0.0, fy + 0.012, 0.81), 0.12, 0.012, rot=(math.pi / 2, 0, 0))
    box("win_v", m["frame"], (0.0, fy - 0.008, 0.81), (0.026, 0.024, 0.22))
    box("win_h", m["frame"], (0.0, fy - 0.008, 0.81), (0.22, 0.024, 0.026))

    # Віддушина під гребенем: коротка брунатна планка з поличкою.
    box("vent", m["frame"], (0.0, fy, 1.16), (0.025, 0.03, 0.12))
    box("vent_b", m["frame"], (0.0, fy - 0.01, 1.09), (0.07, 0.04, 0.025))

    # Арочні двері: дошки (профіль — прямокутник + півколо) і товста рамка.
    dw, dh = 0.34, 0.36
    door = prism("door", m["door"], arch_profile(dw, dh, kit.DET["arch"]), fy - 0.02, fy + 0.02)
    soften(door, 0.012, min(2, kit.DET["bev"]))
    arch_curve("door_frame", m["frame"], dw + 0.05, dh, fy - 0.015, 0.035)
    sphere("knob", m["frame"], (0.1, fy - 0.035, 0.26), 0.025)

    # Поріг — сірий заокруглений брусок перед дверима.
    st = box("step", m["step"], (0.0, fy - 0.08, 0.04), (0.46, 0.16, 0.08))
    soften(st, 0.035)

    # Ліхтарик ліворуч від дверей, камінці, втоплені в стіну.
    ln = box("lantern", m["lantern"], (-0.34, fy - 0.03, 0.47), (0.07, 0.06, 0.1))
    soften(ln, 0.012, min(2, kit.DET["bev"]))
    sphere("stone", m["stone"], (-0.36, fy + 0.005, 0.22), 0.07, (0.9, 0.35, 1.2))
    sphere("pebble", m["stone"], (0.34, fy + 0.005, 0.44), 0.05, (0.7, 0.3, 1.0))

    # Вікна по боках і ззаду: арочні, з рамкою, хрестовиною, склом і підвіконням.
    for sx in (-1, 1):
        for wy in (-0.2, 0.22):
            window("side_win", m, (sx * (hw + 0.02), wy, 0.24), "+x" if sx > 0 else "-x")
    window("back_win", m, (0.0, hd + 0.012, 0.3), "+y")


