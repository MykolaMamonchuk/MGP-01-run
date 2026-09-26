# -*- coding: utf-8 -*-
"""Фахверковий будиночок terra 6 за малюнком house_terra_6.jpg: два поверхи з кремовими
стінами в темно-брунатному брусі (верхній поверх трохи виступає), крутий червоний дах
«пухкою» черепицею, сірий кам'яний димар, кам'яний цоколь, арочні дерев'яні двері з червоним
дашком на кронштейнах, вікна з темними шибками, помаранчевими віконницями й ящиками квітів.
Гребінь — уздовж X (щипці на боках ±X), фасад із дверима — у −Y.

Малюнок неможливий як коробка: крім фасаду й правого щипця, на ньому видно ще й смужку лівого
боку з вікнами. Цю смужку прочитано як вузьку ліву частину фасаду (вікна з віконницями,
відділені брусом) — так силует і розклад деталей збігаються, а геометрія чесна.
Див. kit.py, terra_common.py і build.py."""
import math

import bpy
from mathutils import Matrix

import kit
from kit import arch_curve, arch_profile, box, cyl, prism, soften, sphere
from terra_common import blob, gable_roof_x, mat_blocks, prism_x

# Палітра з малюнка (k-середні по пікселях будинку, 26.09), на крок світліша за «сирі».
# Світло на малюнку — справа (refs: light_az 40): фасад у тіні, щипець світлий — це світло, а не фарба.
PAL = {
    "wall_hi": "#FFF0D6", "wall": "#FDE9CA", "wall_lo": "#F0DAB8",
    # скат під світлом рендера вигорав (#FB8271 проти #DC6351 малюнка) — на крок темніше
    "roof_hi": "#CC5646", "roof": "#B4463A", "roof_edge": "#963A32", "roof_line": "#7A2C2A",
    "timber_hi": "#86604A", "timber": "#6E4A3C", "timber_lo": "#56382C",
    "stone_hi": "#A8A8A0", "stone": "#92928A", "stone_lo": "#7E7E78", "stone_line": "#5E5E5A",
    "chim_hi": "#A6A29E", "chim": "#938E8A", "chim_line": "#6E6A68",
    "shutter_hi": "#D88A5A", "shutter": "#C8784C", "shutter_lo": "#A8603A",
    "frame": "#5A3A2E", "glass": "#2E2A28", "glass_hi": "#6A6460",
    "door_hi": "#B86C42", "door": "#A45C36", "door_line": "#7A4226",
    "darch_hi": "#D4884E", "darch": "#C17748",
    "canopy_hi": "#F47266", "canopy": "#EA6256",
    "leaf": "#6AA852", "white": "#F4F0EA", "pink": "#F0A6C0",
}


def materials(k):
    return {
        "wall": k.mat_gradient("wall", [(0.0, "wall_lo"), (0.5, "wall"), (1.0, "wall_hi")], 0.2, 1.9, 0.12, 4.0),
        "roof": k.mat_roof("roof", rows_scale=2.8, seams=0),
        "timber": k.mat_gradient("timber", [(0.0, "timber_lo"), (0.5, "timber"), (1.0, "timber_hi")], 0.0, 1.9, 0.3, 10.0),
        "stone": mat_blocks("stone", ("stone_line", "stone", "stone_hi"), 0.2, 0.1, 0.012),
        "chim": mat_blocks("chim", ("chim_line", "chim", "chim_hi"), 0.12, 0.08, 0.01),
        "shutter": k.mat_door("shutter", keys=("shutter_lo", "shutter", "shutter_hi"), planks=24.0, direction="X"),
        "frame": k.mat_gradient("frame", [(0.0, "frame"), (1.0, "frame")], 0.0, 1.0, 0.0),
        "glass": k.mat_glass("glass"),
        "door": k.mat_door("door", planks=14.0),
        "darch": k.mat_gradient("darch", [(0.0, "darch"), (1.0, "darch_hi")], 0.2, 0.7, 0.1, 8.0),
        "canopy": k.mat_roof("canopy", keys=("canopy", "canopy", "canopy_hi", "roof_edge"), rows_scale=30.0, seams=0),
        "leaf": k.mat_gradient("leaf", [(0.0, "leaf"), (1.0, "leaf")], 0.0, 1.0, 0.0),
        "white": k.mat_gradient("white", [(0.0, "white"), (1.0, "white")], 0.0, 1.0, 0.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink")], 0.0, 1.0, 0.0),
    }


def place(obs, base, facing):
    """Деталі, зібрані лицем до −Y навколо (0,0,0), — на стіну: base і напрям лиця."""
    rot = {"-y": 0.0, "+x": math.pi / 2, "-x": -math.pi / 2, "+y": math.pi}[facing]
    for ob in obs:
        ob.matrix_world = Matrix.Translation(base) @ Matrix.Rotation(rot, 4, "Z") @ ob.matrix_world


def win6(name, m, k, w=0.2, h=0.2, flowers=True):
    """Вікно: темні шибки 2×2 у брунатній рамці, дошка-перемичка, відчинені помаранчеві
    віконниці, ящик із квітами. Лицем до −Y, низ скла — z=0."""
    bev2 = min(2, k.DET["bev"])
    o = []
    o.append(box(name + "_gl", m["glass"], (0, 0.0, h * 0.5), (w, 0.02, h)))
    for x in (-w * 0.5, 0.0, w * 0.5):
        o.append(box(name + "_fv", m["frame"], (x, -0.012, h * 0.5), (0.028, 0.02, h + 0.02)))
    for z in (0.0, h * 0.5, h):
        o.append(box(name + "_fh", m["frame"], (0, -0.012, z), (w + 0.02, 0.02, 0.028)))
    li = box(name + "_lin", m["timber"], (0, -0.025, h + 0.045), (w + 0.1, 0.05, 0.05))
    soften(li, 0.012, bev2)
    o.append(li)
    for sgn in (-1, 1):
        s = box(name + "_sh", m["shutter"], (sgn * (w * 0.5 + 0.055), -0.04, h * 0.5), (0.1, 0.02, h + 0.02),
                rot=(0, 0, sgn * math.radians(25)))
        o.append(s)
    if flowers:
        bx = box(name + "_box", m["timber"], (0, -0.05, -0.05), (w + 0.08, 0.09, 0.08))
        soften(bx, 0.01, bev2)
        o.append(bx)
        o.append(box(name + "_leaf", m["leaf"], (0, -0.05, 0.0), (w + 0.06, 0.07, 0.03)))
        n = 5
        for i in range(n):
            x = -w * 0.5 + w * i / (n - 1)
            o.append(blob(name + "_fl%d" % i, m["white" if i % 2 else "pink"], (x, -0.07, 0.025), 0.026))
    return o


def build(m, k):
    W, D = 1.1, 1.14
    ZP, ZB, H, PEAK = 0.2, 0.74, 1.2, 1.86
    J = 0.03                    # виступ верхнього поверху
    hw, hd = W * 0.5, D * 0.5
    bev2 = min(2, k.DET["bev"])
    T = 0.055                   # переріз бруса

    # Нижній поверх — «body» (головний об'єкт), верхній — ширший на J з кожного боку, щипці.
    body = box("body", m["wall"], (0.0, 0.0, (ZP + ZB) * 0.5), (W, D, ZB - ZP))
    up = prism_x("upper", m["wall"], [(-hd - J, ZB), (hd + J, ZB), (hd + J, H), (0.0, PEAK), (-hd - J, H)], -hw - J, hw + J)
    pl = box("plinth", m["stone"], (0.0, 0.0, ZP * 0.5), (W + 0.05, D + 0.05, ZP))
    soften(pl, 0.02, bev2)

    # Брус: кутові стовпи, пояс між поверхами, ригель під щипцем, ліва стійка фасаду.
    for sx in (-1, 1):
        for sy in (-1, 1):
            box("post_lo%d%d" % (sx, sy), m["timber"], (sx * (hw - T * 0.3), sy * (hd - T * 0.3), (ZP + ZB) * 0.5), (T, T, ZB - ZP))
            box("post_up%d%d" % (sx, sy), m["timber"], (sx * (hw + J - T * 0.3), sy * (hd + J - T * 0.3), (ZB + H) * 0.5), (T, T, H - ZB))
    band = box("band", m["timber"], (0.0, 0.0, ZB + 0.01), (W + 2 * J + 0.04, D + 2 * J + 0.04, 0.07))
    soften(band, 0.015, bev2)
    for sx in (-1, 1):
        x = sx * (hw + J + 0.012)
        box("tie%d" % sx, m["timber"], (x, 0.0, H), (0.03, D + 2 * J, T))
        box("king%d" % sx, m["timber"], (x, 0.0, (H + PEAK) * 0.5 - 0.03), (0.03, T, PEAK - H - 0.06))
        # подкоси щипця: від ригеля до стовпа-бабки
        for sy in (-1, 1):
            a = math.atan2(0.36, 0.34)
            box("brace_g%d%d" % (sx, sy), m["timber"], (x, sy * 0.19, H + 0.17), (0.03, 0.46, 0.045), rot=(sy * a, 0, 0))
        # верхній поверх боку: подкоси «\ /» від кутів до пояса
        for sy in (-1, 1):
            a = math.atan2(H - ZB, 0.3)
            box("brace_u%d%d" % (sx, sy), m["timber"], (x, sy * (hd - 0.12), (ZB + H) * 0.5), (0.03, 0.5, 0.045), rot=(-sy * a, 0, 0))
        # нижній поверх боку: середня стійка
        box("mid_lo%d" % sx, m["timber"], (sx * (hw + 0.012), 0.2, (ZP + ZB) * 0.5), (0.03, T, ZB - ZP))
    for sy in (-1, 1):
        y = sy * (hd + 0.012)
        box("fpost_lo%d" % sy, m["timber"], (-0.3, y, (ZP + ZB) * 0.5), (T, 0.03, ZB - ZP))
        box("fpost_up%d" % sy, m["timber"], (-0.3, sy * (hd + J + 0.012), (ZB + H) * 0.5), (T, 0.03, H - ZB))
        box("fplate%d" % sy, m["timber"], (0.0, sy * (hd + J + 0.012), H - 0.02), (W + 2 * J, 0.03, T))

    # Дах: крутий, «пухка» черепиця, великий звис; гребінь валиком.
    # Звис малий і дах піднято так, щоб його край ішов по верху стіни, а не на вікна: з
    # крутим скатом кожні 10 см звису опускають край на 13 см (перша збірка ховала вікна).
    ov = 0.07
    lift = ov * (PEAK - H) / (hd + J)
    gable_roof_x(m["roof"], W + 2 * J, D + 2 * J, H + lift, PEAK + lift, 0.1, ov, 0.09, 0.045)
    cyl("ridge", m["roof"], (0.0, 0.0, PEAK + lift + 0.09), 0.07, W + 2 * J + 0.2, rot=(0, math.pi / 2, 0), verts=max(6, k.DET["cyl"] // 2))

    # Кам'яний димар на гребені ближче до лівого краю.
    # верх — на ~0,2 над гребенем-валиком, як на малюнку (нижчий ховався за валиком)
    ch = box("chimney", m["chim"], (-0.3, 0.02, PEAK + 0.17), (0.2, 0.2, 0.5))
    soften(ch, 0.015, bev2)
    cc = box("chimney_cap", m["chim"], (-0.3, 0.02, PEAK + 0.43), (0.25, 0.25, 0.06))
    soften(cc, 0.012, bev2)

    # Вікна: фасад (великий проліт праворуч і вузький ліворуч) і щипці.
    fy_up, fy_lo = -hd - J - 0.02, -hd - 0.02
    place(win6("wf_up", m, k), (0.14, fy_up, 0.88), "-y")
    place(win6("wf_l_up", m, k, 0.1, 0.18), (-0.43, fy_up, 0.88), "-y")
    place(win6("wf_l_lo", m, k, 0.1, 0.18), (-0.43, fy_lo, 0.4), "-y")
    for sx, face in ((1, "+x"), (-1, "-x")):
        place(win6("ws_up%d" % sx, m, k), (sx * (hw + J + 0.02), 0.0, 0.88), face)
        place(win6("ws_lo%d" % sx, m, k), (sx * (hw + 0.02), -0.05, 0.4), face)

    # Двері: арка в помаранчево-брунатній рамці, полотно дошками, ручка, сходинка.
    dx, dw, dh = 0.14, 0.3, 0.3
    door = prism("door", m["door"], [(x + dx, z + ZP) for x, z in arch_profile(dw, dh, k.DET["arch"])], fy_lo - 0.01, fy_lo + 0.03)
    arch_curve("door_arch", m["darch"], dw + 0.06, dh, fy_lo - 0.01, 0.035, ZP)
    sphere("knob", m["frame"], (dx + 0.08, fy_lo - 0.03, ZP + 0.2), 0.016)
    st = box("step", m["stone"], (dx, fy_lo - 0.07, 0.04), (0.38, 0.14, 0.08))
    soften(st, 0.015, bev2)
    # Червоний дашок над дверима на двох кронштейнах.
    cz = ZP + dh + dw * 0.5 + 0.1
    prism("canopy", m["canopy"], [(dx - 0.2, cz), (dx + 0.2, cz), (dx, cz + 0.12)], fy_lo - 0.16, fy_lo)
    box("canopy_board", m["timber"], (dx, fy_lo - 0.08, cz - 0.015), (0.42, 0.17, 0.03))
    for sgn in (-1, 1):
        box("canopy_br%d" % sgn, m["timber"], (dx + sgn * 0.15, fy_lo - 0.05, cz - 0.06), (0.03, 0.1, 0.08))
    return {}
