#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Схожість моделей «за малюнком» — ОДНІЄЮ командою, з записаними параметрами.

Рецензія 26.09: відсотки в коміті не відтворювались, бо кут камери й обрізання малюнка ніде не
були записані. Тепер вони в tools/modelkit/refs/<модель>.json — ОКРЕМИЙ файл на модель, щоб
кілька людей чи агентів могли додавати моделі паралельно без конфліктів:

    {"ref": "mushroom_red_3.png", "az": -20, "el": 10, "crop": "0,0,1,1"}

az/el — кут камери як на малюнку, crop — прямокутник малюнка без підставок, квітів, кущів
(частки 0..1: x0,y0,x1,y1). Скрипт рендерить повний варіант (render_ref.py, прозоре тло) і
міряє tools/ref_similarity.py. Ціль замовника — «разом» ≥ 80% (26.09); нижче — позначка ✗.

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
TARGET = 80   # замовник 26.09: «краще довести схожість до 80-85% мінімум»


def main():
    cfg = {}
    for f in sorted(os.listdir("tools/modelkit/refs")):
        if f.endswith(".json"):
            cfg[f[:-5]] = json.load(open(os.path.join("tools/modelkit/refs", f), encoding="utf-8"))
    names = sys.argv[1:] or list(cfg)
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
        line = r.stdout.strip()
        total = int(line.split("разом")[1].strip().rstrip("%"))
        print("%-16s %s  %s" % (name, line, "✓" if total >= TARGET else "✗ (ціль %d%%)" % TARGET))
    print("рендери:", tmp)


if __name__ == "__main__":
    main()
