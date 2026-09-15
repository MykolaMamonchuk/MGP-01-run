#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_prepare.py — привести згенеровану модель до вимог гри (Blender headless).

Навіщо. Генератор віддає пропси однаково: зріст рівно 1,0 м і початок координат ПОСЕРЕДИНІ.
У грі пропс ставиться на землю, тож половина моделі опиняється під нею, а розмір не має
нічого спільного з боксом зіткнення. Правити це в кожній моделі руками — довго й забудеться.

Що робить:
  1. опускає початок координат у НИЗ по центру (пропс стає на землю сам);
  2. масштабує до потрібної висоти в метрах (з таблиці `docs/tasks/props.md`);
  3. друкує габарити до і після — щоб приймання було числом, а не відчуттям.

Масштаб можна було б задати й у `data/props.json` (`scale`), але краще, щоб модель була
правильною сама: тоді `scale` лишається для дрібного доведення, а не для базового розміру.

Запуск:

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/prop_prepare.py -- \\
        --in docs/refs/incoming/barrel/barrel_1_mesh.glb \\
        --out assets/props/barrel.glb --height 0.70

    --height  цільова висота, м (з таблиці пропсів). Без неї розмір не чіпається.
    --box     ШxВxГ у метрах — бокс зіткнення зі світу. Модель вписується в нього ЦІЛКОМ,
              зберігаючи пропорції. Надійніше за --height: паркан, натягнутий за висотою,
              виходить ширшим за смугу (1,0 м) і залазить на сусідні — гравець бачить
              перешкоду там, де насправді вільно.
    --origin  bottom (типово) | center | keep
    --yaw     довернути навколо вертикалі, градуси (якщо модель прийшла боком)
"""
import argparse
import os
import sys

import bpy


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--height", type=float, default=0.0)
    ap.add_argument("--box", default="", help="ШxВxГ, м — вписати модель у бокс зіткнення")
    ap.add_argument("--origin", default="bottom", choices=["bottom", "center", "keep"])
    ap.add_argument("--yaw", type=float, default=0.0)
    ap.add_argument("--tex-size", type=int, default=0,
                    help="звести текстури до N×N. Генератор віддає 4096×4096 на кожну карту, "
                         "а пропс 0,95 м займає на екрані сотню пікселів: різниці не видно, "
                         "а пам'яті йде вдесятеро більше")
    return ap.parse_args(argv)


## Габарити рахуємо по ВЕРШИНАХ у світових координатах: bound_box об'єкта не враховує
## батьківських трансформів, а ми саме їх і крутимо.
def bounds(objs):
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in objs:
        for v in o.data.vertices:
            co = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], co[i])
                hi[i] = max(hi[i], co[i])
    return lo, hi


def describe(objs, label):
    lo, hi = bounds(objs)
    size = [hi[i] - lo[i] for i in range(3)]
    print("  %-8s Ш×В×Г %.3f × %.3f × %.3f   y від %.3f до %.3f" % (
        label, size[0], size[2], size[1], lo[1], hi[1]))
    return lo, hi, size


def main():
    a = parse_args(sys.argv)
    src = os.path.expanduser(a.src)
    print("prop_prepare: %s (Blender %s)" % (os.path.basename(src), bpy.app.version_string))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("у файлі нема мешів")

    # У glTF вісь «вгору» — Y, і саме так модель прийшла; Blender імпортує її з поворотом,
    # тож міряємо по тій осі, що після імпорту дивиться вгору (Z у Blender).
    lo, hi, size = describe(meshes, "було")


    # Правки йдемо просто у ВЕРШИНИ, а не в батьківський вузол. Причина конкретна:
    # PropLibrary.node_for() бере перший MeshInstance3D зі сцени, а трансформ його батька
    # ігнорує — модель, виправлена вузлом, приїхала б у гру такою ж кривою, як була.
    import math
    yaw = math.radians(a.yaw)
    k = 1.0
    if a.box:
        bw, bh, bd = [float(x) for x in a.box.lower().replace(",", ".").split("x")]
        # Розмір задають ШИРИНА й ВИСОТА. Ширина — бо смуга в грі рівно 1,0 м, і модель,
        # ширша за бокс, залазить на сусідню смугу: гравець бачить перешкоду там, де
        # насправді вільно. Глибина в це не входить навмисно: бокси писали під геймплей,
        # і в круглої бочки бокс 0,70 × 0,70 × 0,50 — не форма бочки, а «скільки метрів
        # дороги вона займає». Вписати в нього по глибині означало б стиснути бочку до
        # півметра й отримати ту саму ваду, тільки навпаки.
        k = min(bw / max(size[0], 1e-6), bh / max(size[2], 1e-6))
        print("  бокс %.2f × %.2f → коефіцієнт %.3f" % (bw, bh, k))
        got_d = size[1] * k
        if got_d > bd + 0.01:
            print("  УВАГА: глибина моделі %.3f більша за бокс %.2f — крізь краї можна "
                  "пройти. Або бокс замалий, або модель треба довернути (--yaw)" % (got_d, bd))
    elif a.height > 0.0 and size[2] > 1e-6:
        k = a.height / size[2]

    for o in meshes:
        m = o.matrix_world
        for v in o.data.vertices:
            v.co = m @ v.co
        o.matrix_basis.identity()
        o.data.update()

    if a.yaw != 0.0:
        c, s_ = math.cos(yaw), math.sin(yaw)
        for o in meshes:
            for v in o.data.vertices:
                x, y = v.co.x, v.co.y
                v.co.x = x * c - y * s_
                v.co.y = x * s_ + y * c
            o.data.update()
        lo, hi, size = describe(meshes, "поворот")

    if k != 1.0:
        for o in meshes:
            for v in o.data.vertices:
                v.co *= k
            o.data.update()
        lo, hi, size = describe(meshes, "масштаб")

    if a.origin != "keep":
        cx = (hi[0] + lo[0]) * 0.5
        cy = (hi[1] + lo[1]) * 0.5
        cz = lo[2] if a.origin == "bottom" else (hi[2] + lo[2]) * 0.5
        for o in meshes:
            for v in o.data.vertices:
                v.co.x -= cx
                v.co.y -= cy
                v.co.z -= cz
            o.data.update()
        lo, hi, size = describe(meshes, "початок")

    if a.tex_size > 0:
        for im in bpy.data.images:
            if im.size[0] > a.tex_size or im.size[1] > a.tex_size:
                was = tuple(im.size)
                im.scale(min(im.size[0], a.tex_size), min(im.size[1], a.tex_size))
                print("  текстура %d×%d → %d×%d" % (was[0], was[1], im.size[0], im.size[1]))

    dst = os.path.abspath(os.path.expanduser(a.out))
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
    print("  записано: %s" % dst)


main()
