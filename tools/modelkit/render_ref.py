# -*- coding: utf-8 -*-
"""Рендер моделі «як на малюнку» — для tools/ref_similarity.py.

Тло — колір кутів малюнка, світло — тепле студійне спереду зліва (як на малюнках-зразках),
камера — під заданим кутом. Однакові умови для всіх моделей, інакше порівнюємо світло, а не
модель.

    Blender --background --python tools/modelkit/render_ref.py -- модель.glb вихід.png \\
        --bg "#F5D2B5" --az -12 --el 12 [--size 512]
"""
import argparse
import math
import sys

import bpy
import mathutils


def rgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return [x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("glb")
    ap.add_argument("out")
    ap.add_argument("--bg", default="#F5D2B5")
    ap.add_argument("--az", type=float, default=-12.0)
    ap.add_argument("--el", type=float, default=12.0)
    ap.add_argument("--size", type=int, default=512)
    # Звідки світло (градуси навколо вертикалі): −40 — спереду зліва, +40 — справа. Частина
    # малюнків освітлена справа, і з лівим світлом правий скат програвав через світло.
    ap.add_argument("--light-az", type=float, default=-40.0)
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=a.glb)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.resolution_x = sc.render.resolution_y = a.size
    # Прозоре тло: маска моделі — з альфа-каналу, без дір там, де колір моделі схожий на тло
    # (кремові стіни на персиковому — рецензія 26.09). Колір тла лишається для світла.
    sc.render.film_transparent = True
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    sc.world = w
    w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (*rgb(a.bg), 1.0)
    # Тло лише для маски; світити моделі воно має слабко, інакше персикове тло фарбує її
    # в помаранч і колір порівнюється зі світлом, а не з моделлю.
    bg.inputs[1].default_value = 0.8
    sun = bpy.data.lights.new("key", "SUN")
    sun.energy = 3.4
    sun.color = (1.0, 1.0, 1.0)
    so = bpy.data.objects.new("key", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), 0, math.radians(a.light_az))
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    lo = mathutils.Vector((1e9,) * 3)
    hi = mathutils.Vector((-1e9,) * 3)
    for o in meshes:
        for c in o.bound_box:
            p = o.matrix_world @ mathutils.Vector(c)
            lo = mathutils.Vector(map(min, lo, p))
            hi = mathutils.Vector(map(max, hi, p))
    tgt = (lo + hi) * 0.5
    r = (hi - lo).length
    cam = bpy.data.cameras.new("c")
    cam.lens = 60
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    az, el, d = math.radians(a.az), math.radians(a.el), r * 1.9
    co.location = tgt + mathutils.Vector((d * math.sin(az) * math.cos(el), -d * math.cos(az) * math.cos(el), d * math.sin(el)))
    co.rotation_euler = (tgt - co.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = a.out
    bpy.ops.render.render(write_still=True)


main()
