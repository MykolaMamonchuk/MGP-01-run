# -*- coding: utf-8 -*-
"""Родина «ящик із хрестом» (xbox_red_*): дерев'яний ящик із дощок, білий (кремовий) хрест
навскоси спереду й ззаду, обв'язка по ребрах і куточки на восьми кутах. Модель задає лише PAL і
CFG, тож перефарбувати — це правка палітри, а не геометрії.

Ключі PAL: red_hi/red/red_lo/red_line (дошки), frame_hi/frame (обв'язка), x/x_hi (хрест),
cap/cap_hi (куточки), bolt (болтики); необов'язкові top/top_hi — кришка.

CFG:
  size (ш, в, г) — габарит без куточків; planks — ширина дошки на фасаді (м), plank_dir —
  "v" (вертикальні) або "h" (горизонтальні); top_plank — ширина дошки на кришці;
  beam — ширина обв'язки по ребрах (0 — без неї), beam_edges — "all" або "vertical";
  mid_rail — поперечна планка посередині фасаду (висота, м; 0 — нема);
  x_w, x_t — ширина й товщина дощок хреста, x_inset — відступ кінців від кута;
  cap — розмір куточка, cap_style — "box" (кутник) або "round" (кругла накладка);
  bolts — болтиків на гранях куточка (0; 1 — один на фасаді; 2 — по два на фасаді й боку),
  bolt_r — радіус болтика (частка куточка)."""
import math

import bpy
import bmesh
from mathutils import Matrix, Vector

import kit
from kit import box, cyl, soften, sphere


def flat(ob, deg=20):
    """Пласкі грані лишаються пласкими: join_all робить усе гладким, і на скошеній коробці
    нормалі кутів «розмазували» затінення через увесь фасад (хрест сірів до середини).
    Розрізані ребра, гостріші за deg, тримають грань пласкою. (harden_normals тут не
    рятує — перевірено: нормалі кутів грані після нього ще кривіші.)"""
    es = ob.modifiers.new("flat", "EDGE_SPLIT")
    es.split_angle = math.radians(deg)
    return ob


def chamfer(ob, k, width, level="high"):
    """Фаска в один сегмент — лише від рівня деталізації level і вище (з відстані гри
    заокруглення ребер ящика не видно, а кожна фаска з розрізаними ребрами — ×4 вершин)."""
    order = {"low": 1, "mid": 2, "high": 3}
    if order[{1: "low", 2: "mid"}.get(k.DET["bev"], "high")] >= order[level]:
        bv = ob.modifiers.new("bevel", "BEVEL")
        bv.width = width
        bv.segments = 1
        bv.limit_method = "ANGLE"
    return flat(ob)


def mat_planks(name, keys, width, axis):
    """Дошки шириною width уздовж осі axis ("X", "Y" або "Z" — вісь, ПОПЕРЕК якої йдуть
    дошки): світла середина, темніший край і тонкий шов. Шов — на межі дощок, а не посередині
    фасаду (зсув фази на півдошки)."""
    m = kit._new_mat(name)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Location"].default_value = (width / 2, width / 2, width / 2)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type = "BANDS"
    wave.bands_direction = axis
    # Хвиля Blender: n = 20 · scale · координата, смуга — 2π/n: ширина дошки → scale
    wave.inputs["Scale"].default_value = 2 * math.pi / (20.0 * width)
    wave.inputs["Distortion"].default_value = 0.3
    wave.inputs["Detail"].default_value = 1.0
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    r = kit._ramp(nt, [(0.03, keys[0]), (0.12, keys[1]), (0.7, keys[2])])
    nt.links.new(wave.outputs["Fac"], r.inputs["Fac"])
    nt.links.new(r.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    return m


def materials(k, c):
    w, h, d = c["size"]
    fdir = "X" if c["plank_dir"] == "v" else "Z"
    return {
        "front": mat_planks("front", ("red_line", "red_lo", "red_hi"), c["planks"], fdir),
        "side": mat_planks("side", ("red_line", "red_lo", "red_hi"), c["planks"],
                           "Y" if c["plank_dir"] == "v" else "Z"),
        # кришка може бути світлішою (на малюнку її освітлено згори): ключі top/top_hi, якщо є
        "top": mat_planks("top", ("red_line", "top" if "top" in kit.PAL else "red",
                                  "top_hi" if "top_hi" in kit.PAL else "red_hi"),
                          c.get("top_plank", c["planks"]), "Y"),
        "frame": k.mat_gradient("frame", [(0.0, "frame"), (1.0, "frame_hi")], 0.0, h, 0.15, 5.0),
        "x": k.mat_gradient("x", [(0.0, "x"), (1.0, "x_hi")], 0.0, h, 0.1, 4.0),
        "cap": k.mat_gradient("cap", [(0.0, "cap"), (1.0, "cap_hi")], 0.0, h, 0.1, 6.0),
        "bolt": k.mat_gradient("bolt", [(0.0, "bolt"), (1.0, "bolt")], 0.0, 1.0, 0.0),
    }


def faced_box(name, m, c, size):
    """Корпус: одна коробка, грані — свій матеріал за напрямком (фасад, бік, кришка)."""
    ob = box(name, m["front"], (0, 0, size[2] / 2), size)
    for key in ("side", "top"):
        ob.data.materials.append(m[key])
    for p in ob.data.polygons:
        n = p.normal
        p.material_index = 2 if abs(n.z) > 0.5 else 1 if abs(n.x) > 0.5 else 0
    return ob


def x_boards(m, k, c, y, sign):
    """Хрест на грані y (sign −1 — фасад, +1 — зад): ОДНА плоска фігура-«ікс» (12 вершин,
    видавлена на товщину), а не дві дошки внахлест — у дошок однакові грані в одній площині
    запікались чорним квадратом у перехресті, а зсунуті давали сходинку, якої нема на малюнку."""
    w, h, d = c["size"]
    ins = c["x_inset"]
    ax, az = w / 2 - ins, h / 2 - ins
    half = math.hypot(ax, az)
    a = math.atan2(az, ax)
    hw = c["x_w"] / 2
    u1, n1 = (math.cos(a), math.sin(a)), (-math.sin(a), math.cos(a))
    u2, n2 = (math.cos(a), -math.sin(a)), (math.sin(a), math.cos(a))
    pts = [(hw / math.sin(a), 0.0), (-hw / math.sin(a), 0.0), (0.0, hw / math.cos(a)), (0.0, -hw / math.cos(a))]
    for u, n in ((u1, n1), (u2, n2)):
        for e in (1, -1):
            for f in (1, -1):
                pts.append((e * half * u[0] + f * hw * n[0], e * half * u[1] + f * hw * n[1]))
    pts.sort(key=lambda p: math.atan2(p[1], p[0]))
    prof = [(x, h / 2 + z) for x, z in pts]
    t = c["x_t"]
    ob = k.prism("x_%d" % sign, m["x"], prof, min(y, y + sign * t), max(y, y + sign * t))
    chamfer(ob, k, min(0.01, c["x_w"] * 0.12), "mid")


def build(m, k, c):
    w, h, d = c["size"]
    b = c["beam"]
    rec = c.get("recess", 0.012) if b > 0 else 0.0      # фасад утоплений за обв'язку
    body = faced_box("body", m, c, (w - 2 * rec, d - 2 * rec, h - rec))
    chamfer(body, k, 0.01)
    if b > 0:
        edges = []
        for sx in (-1, 1):
            for sy in (-1, 1):
                edges.append(((sx * (w - b) / 2, sy * (d - b) / 2, h / 2), (b, b, h)))
        if c["beam_edges"] == "all":
            for sz in (b / 2, h - b / 2):
                for sy in (-1, 1):
                    edges.append(((0, sy * (d - b) / 2, sz), (w - 2 * b, b, b)))
                for sx in (-1, 1):
                    edges.append(((sx * (w - b) / 2, 0, sz), (b, d - 2 * b, b)))
        for i, (ctr, sz) in enumerate(edges):
            e = box("beam%d" % i, m["frame"], ctr, sz)
            chamfer(e, k, c.get("beam_bev", 0.008))
    if c.get("mid_rail"):
        for sy in (-1, 1):
            r = box("rail%d" % sy, m["frame"], (0, sy * (d / 2 - rec), c["mid_rail"]),
                    (w - 2 * b, 0.012, 0.02))
    x_boards(m, k, c, -d / 2 + rec * 0.5, -1)
    x_boards(m, k, c, d / 2 - rec * 0.5, 1)
    # Куточки на восьми кутах. Лице куточка — завжди попереду хреста (інакше в одній площині
    # з ним: чорні трикутники на кінцях хреста, рецензія оком 26.09).
    cs = c["cap"]
    o = max(c.get("cap_out", 0.012), rec * 0.5 + c["x_t"] + 0.006)
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (0, 1):
                cx = sx * (w / 2 - cs / 2 + o)
                cy = sy * (d / 2 - cs / 2 + o)
                cz = (cs / 2 - o) if sz == 0 else (h - cs / 2 + o)
                name = "cap_%d%d%d" % (sx > 0, sy > 0, sz)
                s = box(name, m["cap"], (cx, cy, cz), (cs, cs, cs))
                if c["cap_style"] == "round":
                    # кругла накладка: кубик із великим заокругленням
                    bv = s.modifiers.new("bevel", "BEVEL")
                    bv.width = cs * 0.3
                    bv.segments = max(1, min(3, k.DET["bev"]))
                    bv.limit_method = "ANGLE"
                else:
                    chamfer(s, k, min(0.015, cs * 0.12), "mid")
                nb = c.get("bolts", 0)
                if nb and k.DET["bev"] >= 2:
                    # болтики — круглі «ґудзики» на фасадній/задній грані куточка; bolts=2 — по
                    # два на гранях фасаду й боку (на обох «раменах» кутника)
                    br = cs * c.get("bolt_r", 0.2)
                    vz = 1 if sz == 0 else -1
                    fy, fx = sy * (d / 2 + o), sx * (w / 2 + o)
                    bv = max(8, k.DET["cyl"] // 2)
                    if nb == 1:
                        spots = [((cx, fy, cz), "y")]
                    else:
                        a = cs * 0.24
                        spots = [((cx - sx * a, fy, cz + vz * a * 0.2), "y"), ((cx + sx * a * 0.2, fy, cz + vz * a), "y"),
                                 ((fx, cy - sy * a, cz + vz * a * 0.2), "x"), ((fx, cy + sy * a * 0.2, cz + vz * a), "x")]
                    for j, (p, ax) in enumerate(spots):
                        rot = (math.pi / 2, 0, 0) if ax == "y" else (0, math.pi / 2, 0)
                        flat(cyl("%s_b%d" % (name, j), m["bolt"], p, br, 0.012, rot=rot, verts=bv), 60)
    return {}
