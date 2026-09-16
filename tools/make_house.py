#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_house.py — зібрати казковий будиночок геометрією (Blender headless).

Навіщо. Забудова рівня — найбільша частина кадру й найгірше, що в ньому є: воксельні
сітки 7×7, розтягнуті вдвічі, читаються як гладкі плити без вікон. Чекати на згенеровані
моделі для десятка будинків довго, а виглядати добре треба зараз.

Будиночок — річ проста й регулярна: коробка, двосхилий дах, віконця, двері, фахверк. Усе
це чесно будується кількома сотнями трикутників, без текстур, самими кольорами матеріалів.
Виходить саме «м'який ручний low-poly», якого вимагає арт-напрям, і жодного вокселя.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/make_house.py -- \\
        --out assets/props/house_a.glb --width 1.6 --depth 1.4 --height 1.5 \\
        --roof "#C1452F" --wall "#F2E6CE" --beam "#7A4A2A" --storeys 2

Кольори — як у грі, з арт-бази. Дах, стіна, балка, віконце задаються окремо, тож із одного
скрипта виходить ціла вулиця несхожих будинків.
"""
import argparse
import math
import sys

import bpy
import bmesh


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--width", type=float, default=1.6)
    ap.add_argument("--depth", type=float, default=1.4)
    ap.add_argument("--height", type=float, default=1.5)
    ap.add_argument("--storeys", type=int, default=2)
    ap.add_argument("--roof", default="#C1452F")
    ap.add_argument("--wall", default="#F2E6CE")
    ap.add_argument("--beam", default="#7A4A2A")
    ap.add_argument("--window", default="#63C7E8")
    ap.add_argument("--door", default="#8D5524")
    ap.add_argument("--awning", default="")
    ap.add_argument("--seed", type=int, default=0)
    return ap.parse_args(argv)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, hexcode):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    h = hexcode.lstrip("#")
    rgb = [srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = 0.85
    return m


def box(bm, x0, y0, z0, x1, y1, z1):
    """Коробка як 8 вершин і 6 граней — рівно те, що треба для чанкі-стилю."""
    v = [bm.verts.new((x, y, z)) for x, y, z in (
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1))]
    for a, b, c, d in ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
                       (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new((v[a], v[b], v[c], v[d]))
    return v


def part(name, material, build):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    build(bm)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    ob.data.materials.append(material)
    bpy.context.collection.objects.link(ob)
    return ob


def main():
    a = parse_args(sys.argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)

    w, d, h = a.width, a.depth, a.height
    hw, hd = w * 0.5, d * 0.5
    eaves = 0.12          # звис даху — без нього будинок читається як коробка, а не як дім
    roof_h = h * 0.42

    part("walls", mat("wall", a.wall), lambda bm: box(bm, -hw, -hd, 0.0, hw, hd, h))

    # Дах двосхилий: два скошені боки й два трикутні щипці. Робимо його ОКРЕМИМ мешем, щоб
    # колір був справді інший, а не градієнтом по одній коробці.
    def roof(bm):
        rw, rd = hw + eaves, hd + eaves
        top = h + roof_h
        p = [bm.verts.new(v) for v in (
            (-rw, -rd, h), (rw, -rd, h), (rw, rd, h), (-rw, rd, h),
            (0.0, -rd, top), (0.0, rd, top))]
        bm.faces.new((p[0], p[1], p[4]))            # щипець спереду
        bm.faces.new((p[2], p[3], p[5]))            # щипець ззаду
        bm.faces.new((p[1], p[2], p[5], p[4]))      # схил
        bm.faces.new((p[3], p[0], p[4], p[5]))      # схил
        bm.faces.new((p[3], p[2], p[1], p[0]))      # низ (видно знизу з дороги)
    part("roof", mat("roof", a.roof), roof)

    # Фахверк: горизонтальні балки між поверхами й кутові стояки. Саме вони роблять будинок
    # «казковим», а не просто кольоровою коробкою.
    def beams(bm):
        t = 0.055
        # Виступ 0,035 замість 0,01. Один сантиметр — це замало: на відстані стіна й балка
        # опиняються на практично однаковій глибині, відеокарта не може вирішити, котра
        # ближче, і грань починає мерехтіти (z-fighting). Саме це й було видно на будинках.
        out = 0.035
        for i in range(1, max(a.storeys, 1)):
            z = h * i / float(a.storeys)
            box(bm, -hw - out, -hd - out, z - t, hw + out, hd + out, z + t)
        # Кутові стояки. Раніше межі рахувались виразом зі знаками, який на одних кутах
        # давав вироджену коробку нульової товщини — вона й мерехтіла. Тепер просто:
        # квадратний стояк, насаджений на кут і трохи виступає назовні.
        for sx in (-1, 1):
            for sy in (-1, 1):
                cx, cy = sx * hw, sy * hd
                box(bm, cx - t, cy - t, 0.0, cx + t, cy + t, h)
    part("beams", mat("beam", a.beam), beams)

    # Віконця на кожному поверсі, по фасаду й боках — глибина втоплена, щоб була тінь
    def windows(bm):
        ww, wh, inset = 0.20, 0.24, 0.03
        for s in range(a.storeys):
            z = h * (s + 0.55) / float(a.storeys)
            for x in (-w * 0.22, w * 0.22):
                box(bm, x - ww * 0.5, -hd - inset, z - wh * 0.5, x + ww * 0.5, -hd + inset, z + wh * 0.5)
            for y in (-d * 0.2, d * 0.2):
                box(bm, hw - inset, y - ww * 0.5, z - wh * 0.5, hw + inset, y + ww * 0.5, z + wh * 0.5)
    part("windows", mat("window", a.window), windows)

    def door(bm):
        dw, dh = 0.26, 0.42
        box(bm, -dw * 0.5, -hd - 0.035, 0.0, dw * 0.5, -hd + 0.035, dh)
    part("door", mat("door", a.door), door)

    if a.awning:
        # смугаста маркіза над входом — прикмета ринкової вулиці з референсу
        def awning(bm):
            box(bm, -w * 0.34, -hd - 0.30, h * 0.40, w * 0.34, -hd - 0.02, h * 0.40 + 0.05)
        part("awning", mat("awning", a.awning), awning)

    # Один меш на виході: гра бере ПЕРШИЙ MeshInstance3D і малює його пачкою, тож частини
    # треба з'єднати, інакше в кадр потрапить лише стіна без даху.
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        o.select_set(True)
    bpy.ops.object.join()

    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB")
    me = bpy.context.view_layer.objects.active.data
    print("  будинок: %d трикутників, %d матеріалів → %s" % (
        len(me.loop_triangles) if me.loop_triangles else sum(len(p.vertices) - 2 for p in me.polygons),
        len(me.materials), a.out))


main()
