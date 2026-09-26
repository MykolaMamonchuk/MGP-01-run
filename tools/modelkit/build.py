# -*- coding: utf-8 -*-
"""Зібрати модель «за малюнком»: палітра й форма — у tools/modelkit/<модель>.py.

    /Applications/Blender.app/Contents/MacOS/Blender --background \
        --python tools/modelkit/build.py -- --model hut --detail high

Пише в assets/props/_exp/models/<модель>/: <модель>_<detail>.glb (текстура 1024) і
<модель>_<detail>_{1024,512,256}.jpg. Деталізація: high (~4-5 тис. вершин), mid (~3 тис.),
low (~1,5 тис.) — чесно меншою кількістю сегментів, а не різаком.
"""
import argparse
import importlib
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy  # noqa: E402
import kit  # noqa: E402


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--detail", default="high", choices=list(kit.DETAIL.keys()))
    ap.add_argument("--out-dir", default="")
    ap.add_argument("--tex", type=int, default=1024)
    a = ap.parse_args(argv)
    model = importlib.import_module(a.model)
    kit.PAL = model.PAL
    kit.MODEL_NAME = a.model
    details = getattr(model, "DETAIL", kit.DETAIL)
    kit.DET = details[a.detail]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m = model.materials(kit)
    info = model.build(m, kit) or {}
    obj = kit.join_all()
    obj.data.calc_loop_triangles()
    print("трикутників:", len(obj.data.loop_triangles), "вершин (Blender):", len(obj.data.vertices))
    img = kit.bake(obj, a.tex)
    out_dir = a.out_dir or os.path.join("assets/props/_exp/models", a.model)
    kit.finish(obj, img, os.path.abspath(out_dir), "%s_%s" % (a.model, a.detail), a.tex,
               parts=info.get("parts"), rig=info.get("rig"))


main()
