#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Схожість моделей «за малюнком» — ОДНІЄЮ командою, з записаними параметрами.

Рецензія 26.09: відсотки в коміті не відтворювались, бо кут камери й обрізання малюнка ніде не
були записані. Тепер вони в tools/modelkit/refs.json, а цей скрипт для кожної моделі рендерить
повний варіант (tools/modelkit/render_ref.py, прозоре тло) і міряє tools/ref_similarity.py.

    python3 tools/modelkit/measure.py            # усі моделі
    python3 tools/modelkit/measure.py mill_1     # одна
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
REFS = "docs/refs/incoming/test_models"


def main():
    cfg = json.load(open("tools/modelkit/refs.json", encoding="utf-8"))
    names = sys.argv[1:] or [k for k in cfg if not k.startswith("_")]
    tmp = tempfile.mkdtemp()
    for name in names:
        c = cfg[name]
        ref = os.path.join(REFS, c["ref"])
        glb = "assets/props/_exp/models/%s/%s_high.glb" % (name, name)
        im = Image.open(ref).convert("RGB")
        bg = "#%02X%02X%02X" % im.getpixel((3, 3))
        out = os.path.join(tmp, name + ".png")
        subprocess.run([BLENDER, "--background", "--python", "tools/modelkit/render_ref.py", "--",
                        glb, out, "--bg", bg, "--az", str(c["az"]), "--el", str(c["el"])],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        r = subprocess.run([sys.executable, "tools/ref_similarity.py", ref, out, "--ref-crop", c["crop"]],
                           capture_output=True, text=True, check=True)
        print("%-9s %s" % (name, r.stdout.strip()))
    print("рендери:", tmp)


if __name__ == "__main__":
    main()
