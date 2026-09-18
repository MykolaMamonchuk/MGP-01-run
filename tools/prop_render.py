#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_render.py — знімок моделі з фіксованого ракурсу (Blender headless).

Потрібен, щоб порівнювати моделі ЧИСЛОМ: камера, світло й фон однакові завжди, тож різниця
між двома знімками — це різниця між моделями, а не між ракурсами.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/prop_render.py -- \\
        assets/props/barrel_1.glb /tmp/barrel.png [розмір]
"""
import math
import sys

import bpy
import mathutils


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out = argv[0], argv[1]
    size = int(argv[2]) if len(argv) > 2 else 700
    # --fit: підігнати модель до однакового розміру й центра перед зніманням. Потрібен для
    # ПОРІВНЯНЬ: дві моделі однієї речі майже завжди мають різні габарити й початок
    # координат, і без нормалізації різниця між знімками виходить від кадрування, а не від
    # самих моделей (на цьому 18.09.2026 прилад показав «57% схожості» для куща, якого на
    # око не відрізнити).
    fit = "--fit" in argv

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    if not objs:
        raise SystemExit("у файлі нема мешів")

    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in objs:
        for corner in o.bound_box:
            w = o.matrix_world @ mathutils.Vector(corner)
            for i in range(3):
                lo[i] = min(lo[i], w[i])
                hi[i] = max(hi[i], w[i])
    c = [(lo[i] + hi[i]) * 0.5 for i in range(3)]
    span = max(hi[i] - lo[i] for i in range(3))

    if fit:
        k = 1.0 / max(span, 1e-6)
        for o in objs:
            for v in o.data.vertices:
                v.co = ((o.matrix_world @ v.co) - mathutils.Vector(c)) * k
            o.matrix_world = mathutils.Matrix.Identity(4)
            o.data.update()
        lo = [-0.5] * 3
        hi = [0.5] * 3
        c = [0.0, 0.0, 0.0]
        span = 1.0

    bpy.ops.object.camera_add(location=(c[0] + span * 1.5, c[1] - span * 1.7, c[2] + span * 1.1))
    cam = bpy.context.object
    cam.rotation_euler = (math.radians(65), 0, math.radians(40))
    bpy.context.scene.camera = cam

    bpy.ops.object.light_add(type="SUN", location=(c[0] + span, c[1] - span, c[2] + span * 2))
    bpy.context.object.data.energy = 4

    world = bpy.data.worlds.new("w")
    bpy.context.scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.75, 0.85, 1)

    scene = bpy.context.scene
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    scene.render.resolution_x = size
    scene.render.resolution_y = size
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


main()
