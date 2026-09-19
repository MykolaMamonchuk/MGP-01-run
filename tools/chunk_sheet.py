#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""chunk_sheet.py — один аркуш з УСІМА цеглинками бібліотеки, зверху й підписаними.

Навіщо. Рівень тепер складається зі списку імен у data/levels.json:

    "chunks": ["meadow_gate", "meadow_orchard", "meadow_yard"]

Щоб вибирати ці імена свідомо, треба бачити, що за ними стоїть: наскільки густо йдуть
перешкоди, який у цеглинки силует, скільки доріжок вона віддає наступній. Тримати це в
голові на дев'ятьох цеглинках уже важко, а їх ставатиме більше. Тут вони всі поруч, з
однакового ракурсу й з числами.

Кожна смуга — 150 м дороги зверху, як у редакторі. Підпис: id, крок між перешкодами,
стик (вхід → вихід), світи й яку розкладку показано.

    python3 tools/chunk_sheet.py                      # усі → chunk_sheet.png
    python3 tools/chunk_sheet.py --layout hard        # важкий варіант замість легкого
    python3 tools/chunk_sheet.py --out /tmp/s.png --width 1600

Запускати з кореня проєкту. Godot тут БЕЗ --headless — у headless він не малює взагалі
(той самий урок, що й для tools/probe/).
"""
import argparse
import glob
import json
import os
import re
import subprocess
import tempfile

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
ROOT = "levels/chunks"
## Скільки відсотків кадру по висоті лишити. Знімок зверху — 150 м упоперек, а по вертикалі
## у нього влазить ~80 м, з яких дорога з каналами займає середину; решта — порожнє тло.
KEEP_BAND = 0.34
## Шрифт проєкту: у типового растрового шрифта PIL кирилиці немає взагалі, і підписи виходили
## рядком порожніх квадратиків.
FONT = "assets/fonts/BalsamiqSans-Regular.ttf"


def steps(scene_path):
    """Кроки між сусідніми перешкодами розкладки, у метрах."""
    if not os.path.exists(scene_path):
        return []
    zs = []
    for block in open(scene_path).read().split("[node ")[1:]:
        if 'role = "obstacle"' not in block:
            continue
        m = re.search(r"Transform3D\(([^)]*)\)", block)
        if m:
            zs.append(abs(float(m.group(1).split(",")[-1])))
    zs.sort()
    return [round(b - a) for a, b in zip(zs, zs[1:])]


def label_of(desc, scene_path):
    gaps = steps(scene_path)
    step = "крок %d м" % (sum(gaps) // len(gaps)) if gaps else "без перешкод"
    seam = "%d → %d" % (int(desc.get("entry_lanes", 3)), int(desc.get("exit_lanes", 3)))
    return "%s   ·   %s   ·   %s   ·   %s" % (
        desc.get("id", "?"), step, seam, ", ".join(desc.get("worlds", []) or ["будь-який"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="chunk_sheet.png")
    ap.add_argument("--layout", default="easy", help="easy / mid / hard — яку розкладку показати")
    ap.add_argument("--width", type=int, default=1800)
    a = ap.parse_args()

    descs = []
    for path in sorted(glob.glob("%s/*/chunk.json" % ROOT)):
        with open(path) as f:
            descs.append((os.path.dirname(path), json.load(f)))
    if not descs:
        raise SystemExit("цеглинок не знайдено — запускати з кореня проєкту")

    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(FONT, 17) if os.path.exists(FONT) else ImageFont.load_default()
    tmp = tempfile.mkdtemp(prefix="chunks_")
    strips = []
    for folder, desc in descs:
        cid = os.path.basename(folder)
        shot = os.path.join(tmp, cid + ".png")
        env = dict(os.environ, OUT=shot, CHUNK=cid, LAYOUT=a.layout,
                   VIEW="top", FROM="0", SPAN="150")
        subprocess.run([GODOT, "--path", ".", "res://src/debug/chunk_shot.tscn"],
                       env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                       check=False)
        if not os.path.exists(shot):
            print("  ПРОПУЩЕНО %s — знімок не зробився" % cid)
            continue
        im = Image.open(shot).convert("RGB")
        band = int(im.height * KEEP_BAND)
        im = im.crop((0, (im.height - band) // 2, im.width, (im.height + band) // 2))
        im = im.resize((a.width, int(im.height * a.width / im.width)))
        strips.append((im, label_of(desc, "%s/layout_%s.tscn" % (folder, a.layout))))
        print("  %-22s %s" % (cid, strips[-1][1]))

    bar = 28
    sheet = Image.new("RGB", (a.width, sum(s.height + bar for s, _ in strips)), (245, 245, 245))
    draw = ImageDraw.Draw(sheet)
    y = 0
    for im, text in strips:
        draw.text((8, y + 6), text, fill=(20, 20, 20), font=font)
        y += bar
        sheet.paste(im, (0, y))
        y += im.height
    sheet.save(a.out)
    print("аркуш: %s (%d цеглинок, розкладка %s)" % (a.out, len(strips), a.layout))


main()
