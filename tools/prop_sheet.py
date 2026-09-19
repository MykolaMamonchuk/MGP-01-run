#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_sheet.py — один аркуш з УСІМА моделями гри, підписаними вагою.

Навіщо. Моделі накопичуються по одній, а дивитись на них доводиться поштучно: відкрити
Godot, знайти файл, покрутити. Через це легко не помітити, що якась модель приїхала важкою,
кривою або в чужому стилі. Тут усі вони поруч, з однакового ракурсу й з числами під кожною.

Кожна клітинка підписана: назва, трикутники, розмір файлу. Модель, що не вкладається в стелю
tests/test_prop_budget.gd (7000 граней / 2,5 МБ), обводиться червоним.

    python3 tools/prop_sheet.py                       # усі assets/props/*.glb → prop_sheet.png
    python3 tools/prop_sheet.py --out /tmp/s.png --cols 8 --cell 220
    python3 tools/prop_sheet.py assets/props/bush_*.glb   # тільки задані
"""
import argparse
import glob
import json
import os
import struct
import subprocess
import tempfile

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
## Тримати однаковим із tests/test_prop_budget.gd — саме він і є сторожем.
MAX_TRIS = 7000
MAX_BYTES = 2_500_000


def stat(path):
    """(трикутники, байти) з .glb, без Blender — читаємо JSON-шматок файлу."""
    data = open(path, "rb").read()
    if data[:4] != b"glTF":
        return 0, os.path.getsize(path)
    length = struct.unpack("<I", data[12:16])[0]
    j = json.loads(data[20:20 + length])
    tris = 0
    for mesh in j.get("meshes", []):
        for prim in mesh["primitives"]:
            if "indices" in prim:
                tris += j["accessors"][prim["indices"]]["count"] // 3
    return tris, os.path.getsize(path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="*")
    ap.add_argument("--out", default="prop_sheet.png")
    ap.add_argument("--cols", type=int, default=6)
    ap.add_argument("--cell", type=int, default=260)
    a = ap.parse_args()

    files = a.files or sorted(glob.glob("assets/props/*.glb"))
    if not files:
        raise SystemExit("моделей не знайдено — запускати з кореня проєкту")

    from PIL import Image, ImageDraw
    tmp = tempfile.mkdtemp(prefix="sheet_")
    label_h = 34
    cols = a.cols
    rows = (len(files) + cols - 1) // cols
    sheet = Image.new("RGB", (a.cell * cols, (a.cell + label_h) * rows), (250, 250, 250))
    draw = ImageDraw.Draw(sheet)

    for i, path in enumerate(files):
        name = os.path.basename(path)[:-4]
        shot = os.path.join(tmp, name + ".png")
        subprocess.run([BLENDER, "--background", "--python", "tools/prop_render.py", "--",
                        path, shot, str(a.cell * 2)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        x = (i % cols) * a.cell
        y = (i // cols) * (a.cell + label_h)
        if os.path.exists(shot):
            sheet.paste(Image.open(shot).convert("RGB").resize((a.cell, a.cell)), (x, y))
        tris, size = stat(path)
        over = tris > MAX_TRIS or size > MAX_BYTES
        if over:
            draw.rectangle([x + 1, y + 1, x + a.cell - 2, y + a.cell - 2], outline=(220, 40, 40), width=3)
        draw.text((x + 6, y + a.cell + 4), name, fill=(20, 20, 20))
        draw.text((x + 6, y + a.cell + 18),
                  "%d гр. · %.2f МБ%s" % (tris, size / 1e6, "  ПОНАД СТЕЛЮ" if over else ""),
                  fill=(200, 30, 30) if over else (90, 90, 90))
        print("  %-28s %6d гр. %6.2f МБ" % (name, tris, size / 1e6))

    sheet.save(a.out)
    print("аркуш: %s (%d моделей)" % (a.out, len(files)))


main()
