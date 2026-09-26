# -*- coding: utf-8 -*-
"""Кіоск за малюнком kiosk_1_test_draw.jpg: круглий корпус із жовтих вертикальних дощок на
кам'яному цоколі, м'ятний купол «пелюстками» зі спідницею, жовта шапочка з кулькою, рожевий
димар, вікно зі шпросами й помаранчевим підвіконням, двері із заскленим верхом, вивіска на
стовпчику (без напису: у грі його однаково не прочитати, а буквами — сотні трикутників)."""
import math

import bpy

import kit
from kit import box, cyl, soften, sphere

PAL = {
    "wood_hi": "#F2C68A", "wood": "#DDB072", "wood_lo": "#C19F62", "wood_line": "#98804F",
    "dome_hi": "#9FDABF", "dome": "#84C6A9", "dome_lo": "#6BAA91", "dome_line": "#4A8472",
    "cap_hi": "#FAD790", "cap": "#EDBD6C",
    "pink_hi": "#E7898F", "pink": "#D06A72",
    "frame_hi": "#C47A57", "frame": "#A9603F", "frame_lo": "#7C4630",
    "glass": "#DDEFF2", "glass_hi": "#FFFFFF",
    "sill_hi": "#F4B06A", "sill": "#E0914A",
    "stone_hi": "#9EA196", "stone": "#7C7F72",
    "brass": "#D8B24C",
}


def materials(k):
    return {
        "wood": k.mat_door("wood", keys=("wood_line", "wood_lo", "wood_hi"), planks=14.0, direction="X"),
        "dome": k.mat_roof("dome", keys=("dome_lo", "dome", "dome_hi", "dome_line"), rows_scale=2.2, seams=0, direction="X"),
        "skirt": k.mat_door("skirt", keys=("dome_line", "dome", "dome_hi"), planks=3.2, direction="X"),
        "cap": k.mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 1.3, 1.55, 0.1, 8.0),
        "pink": k.mat_gradient("pink", [(0.0, "pink"), (1.0, "pink_hi")], 0.9, 1.5, 0.15, 8.0),
        "frame": k.mat_gradient("frame", [(0.0, "frame_lo"), (0.5, "frame"), (1.0, "frame_hi")], 0.0, 1.0, 0.2, 8.0),
        "door": k.mat_door("door", keys=("frame_lo", "frame", "frame_hi"), planks=6.0),
        "glass": k.mat_glass("glass"),
        "sill": k.mat_gradient("sill", [(0.0, "sill"), (1.0, "sill_hi")], 0.3, 0.4, 0.1, 8.0),
        "stone": k.mat_gradient("stone", [(0.0, "stone"), (1.0, "stone_hi")], 0.0, 0.12, 0.3, 9.0),
        "brass": k.mat_gradient("brass", [(0.0, "brass"), (1.0, "brass")], 0.0, 1.0, 0.0),
    }


def face_on(obs, ang, r):
    """Поставити деталі, зібрані лицем до −Y у (0,0,z), на стіну циліндра під кутом ang."""
    from mathutils import Matrix
    for ob in obs:
        ob.matrix_world = Matrix.Rotation(ang, 4, "Z") @ Matrix.Translation((0.0, -r, 0.0)) @ ob.matrix_world


def build(m, k):
    R, H = 0.42, 0.8
    seg = max(12, k.DET["cyl"])
    # Корпус — «body» (головний об'єкт), круглий, з вертикальних дощок.
    bpy.ops.mesh.primitive_cylinder_add(vertices=seg, radius=R, depth=H, location=(0, 0, 0.08 + H / 2))
    body = bpy.context.active_object
    body.name = "body"
    body.data.materials.append(m["wood"])
    soften(body, 0.02)
    base = cyl("base", m["stone"], (0, 0, 0.05), R + 0.05, 0.1, verts=seg)
    soften(base, 0.02)

    # Купол: спідниця (зрізаний конус) і сам купол, пелюстки — шви текстури.
    bpy.ops.mesh.primitive_cone_add(vertices=seg, radius1=R + 0.22, radius2=R + 0.06, depth=0.16,
                                    location=(0, 0, 0.08 + H + 0.05))
    skirt = bpy.context.active_object
    skirt.name = "skirt"
    skirt.data.materials.append(m["skirt"])
    soften(skirt, 0.03)
    s, rings = k.DET["sph"]
    bpy.ops.mesh.primitive_uv_sphere_add(radius=R + 0.07, segments=max(s, 12), ring_count=max(rings, 6),
                                         location=(0, 0, 0.08 + H + 0.1))
    dome = bpy.context.active_object
    dome.name = "dome"
    dome.scale = (1.0, 1.0, 0.72)
    dome.data.materials.append(m["dome"])
    # нижню половину сфери не видно (вона в корпусі) — геть, щоб не платити трикутниками
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="DESELECT")
    bpy.ops.object.mode_set(mode="OBJECT")
    for v in dome.data.vertices:
        v.select = v.co.z < -0.02
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.delete(type="VERT")
    bpy.ops.object.mode_set(mode="OBJECT")

    # Жовта шапочка з кулькою.
    top = 0.08 + H + 0.1 + (R + 0.07) * 0.72
    sphere("cap", m["cap"], (0, 0, top - 0.01), 0.15, (1.0, 1.0, 0.45))
    sphere("cap_ball", m["cap"], (0, 0, top + 0.1), 0.05)

    # Рожевий димар позаду праворуч.
    ch = cyl("chimney", m["pink"], (0.25, 0.2, top - 0.05), 0.07, 0.42)
    soften(ch, 0.015, min(2, k.DET["bev"]))
    lip = cyl("chimney_lip", m["pink"], (0.25, 0.2, top + 0.17), 0.09, 0.06)
    soften(lip, 0.01, min(2, k.DET["bev"]))

    # Вікно ліворуч від дверей: рамка, скло, шпроси 2×3, підвіконня двома дошками.
    win = []
    wz, ww, wh = 0.52, 0.3, 0.34
    win.append(box("win_glass", m["glass"], (0, 0.005, wz), (ww, 0.01, wh)))
    for dx in (-ww / 2, ww / 2):
        win.append(box("win_fs", m["frame"], (dx, -0.01, wz), (0.035, 0.04, wh + 0.035)))
    for dz in (-wh / 2, wh / 2):
        win.append(box("win_ft", m["frame"], (0, -0.01, wz + dz), (ww + 0.035, 0.04, 0.035)))
    win.append(box("win_mv", m["frame"], (0, -0.012, wz), (0.018, 0.02, wh)))
    for dz in (-wh / 6, wh / 6):
        win.append(box("win_mh", m["frame"], (0, -0.012, wz + dz), (ww, 0.02, 0.018)))
    sill = box("win_sill", m["sill"], (0, -0.05, wz - wh / 2 - 0.03), (ww + 0.12, 0.09, 0.04))
    soften(sill, 0.012, min(2, k.DET["bev"]))
    win.append(sill)
    sill2 = box("win_sill2", m["frame"], (0, -0.04, wz - wh / 2 - 0.075), (ww + 0.1, 0.07, 0.04))
    win.append(sill2)
    face_on(win, math.radians(-48), R)

    # Двері праворуч: рамка, заскленений верх зі шпросами, дошки внизу, латунна ручка.
    door = []
    dz0, dw, dh = 0.1, 0.3, 0.66
    door.append(box("door_panel", m["door"], (0, -0.005, dz0 + dh * 0.3), (dw, 0.03, dh * 0.6)))
    door.append(box("door_glass", m["glass"], (0, 0.0, dz0 + dh * 0.78), (dw * 0.8, 0.01, dh * 0.36)))
    door.append(box("door_mv", m["frame"], (0, -0.012, dz0 + dh * 0.78), (0.016, 0.02, dh * 0.36)))
    door.append(box("door_mh", m["frame"], (0, -0.012, dz0 + dh * 0.78), (dw * 0.8, 0.02, 0.016)))
    for dx in (-dw / 2, dw / 2):
        door.append(box("door_fs", m["frame"], (dx, -0.012, dz0 + dh / 2), (0.035, 0.045, dh + 0.03)))
    door.append(box("door_ft", m["frame"], (0, -0.012, dz0 + dh), (dw + 0.035, 0.045, 0.035)))
    door.append(sphere("door_knob", m["brass"], (dw * 0.32, -0.04, dz0 + dh * 0.45), 0.022))
    face_on(door, math.radians(8), R)

    # Вивіска на стовпчику праворуч попереду (без напису).
    px, py = 0.62, -0.34
    post = cyl("sign_post", m["frame"], (px, py, 0.42), 0.035, 0.84)
    sphere("sign_ball", m["frame"], (px, py, 0.88), 0.045)
    board = box("sign_board", m["frame"], (px - 0.05, py - 0.05, 0.62), (0.34, 0.04, 0.17),
                rot=(0, 0, math.radians(10)))
    soften(board, 0.015, min(2, k.DET["bev"]))
    return {}
