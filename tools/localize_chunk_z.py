#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""localize_chunk_z.py — перевести маркери чанків із АБСОЛЮТНИХ метрів рівня в ЛОКАЛЬНІ.

Навіщо. Чанк, відкритий у редакторі, виглядав порожнім: маркери chunk_05 стояли на z = −750,
за сотні метрів від початку координат, куди камера не дивиться. Правити карту оком було
неможливо. Тепер маркер знає своє місце В ЧАНКУ, а зсув чанка в рівні тримає корінь сцени
(LevelLayout.z_offset_m); LevelTimeline.extract() складає одне з одним і віддає грі ту саму
абсолютну відстань, що й раніше.

Що робить із кожним levels/level_XX/chunk_NN.tscn:
  1. z кожного маркера += NN × 150 (маркери йдуть по −Z, тож локальна z виходить у [−150, 0]);
  2. кореню призначає скрипт level_layout.gd і z_offset_m = NN × 150.

Запуск:
    python3 tools/localize_chunk_z.py            # переписати всі рівні
    python3 tools/localize_chunk_z.py --dry      # лише показати, що зміниться
Перевірка вбудована: скрипт сам звіряє набір абсолютних z до і після й відмовляється
писати, якщо вони розійшлись.
"""
import argparse
import glob
import os
import re

CHUNK_LENGTH_M = 150.0
LAYOUT_SCRIPT = "res://src/run3d/level_layout.gd"
TRANSFORM_RE = re.compile(r"transform = Transform3D\(([^)]*)\)")


def chunk_index(path):
    return int(re.search(r"chunk_(\d+)\.tscn$", path).group(1))


def marker_zs(text):
    return [float(m.group(1).split(",")[-1]) for m in TRANSFORM_RE.finditer(text)]


def localize(text, offset):
    """z += offset для кожного маркера; корінь отримує скрипт і z_offset_m."""
    def shift(m):
        args = [a.strip() for a in m.group(1).split(",")]
        args[-1] = repr(round(float(args[-1]) + offset, 4))
        return "transform = Transform3D(%s)" % ", ".join(args)

    out = TRANSFORM_RE.sub(shift, text)

    # ext_resource для скрипта кореня. Номер беремо вільний, щоб не зіткнутись із наявними.
    if LAYOUT_SCRIPT not in out:
        ids = [int(i) for i in re.findall(r'ext_resource type="Script" path="[^"]*" id="(\d+)"', out)]
        new_id = (max(ids) + 1) if ids else 1
        line = '[ext_resource type="Script" path="%s" id="%d"]\n' % (LAYOUT_SCRIPT, new_id)
        last = out.rindex("[ext_resource")
        end = out.index("\n", last) + 1
        out = out[:end] + line + out[end:]
        out = re.sub(r"load_steps=(\d+)", lambda m: "load_steps=%d" % (int(m.group(1)) + 1), out, count=1)
    else:
        new_id = int(re.search(r'ext_resource type="Script" path="%s" id="(\d+)"' % re.escape(LAYOUT_SCRIPT), out).group(1))

    # Корінь: рядок [node name="LevelLayout" type="Node3D"] без parent=
    root = re.search(r'\[node name="[^"]*" type="Node3D"\]\n', out)
    if root is None:
        raise SystemExit("не знайдено кореневий вузол")
    head = out[: root.end()]
    tail = out[root.end():]
    tail = re.sub(r'^script = ExtResource\("\d+"\)\n', "", tail)
    tail = re.sub(r"^z_offset_m = [-\d.]+\n", "", tail)
    out = head + 'script = ExtResource("%d")\nz_offset_m = %s\n' % (new_id, repr(offset)) + tail
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()
    files = sorted(glob.glob("levels/level_*/chunk_*.tscn"))
    if not files:
        raise SystemExit("чанків не знайдено — запускати з кореня проєкту")
    changed = 0
    for path in files:
        offset = chunk_index(path) * CHUNK_LENGTH_M
        text = open(path, encoding="utf-8").read()
        if "z_offset_m" in text:
            continue                       # уже переведено
        out = localize(text, offset)
        before = sorted(round(z, 3) for z in marker_zs(text))
        after = sorted(round(z - offset, 3) for z in marker_zs(out))
        if before != after:
            raise SystemExit("%s: абсолютні z розійшлись — нічого не записано" % path)
        changed += 1
        if a.dry:
            print("%-34s зсув %6.0f, маркерів %d" % (path, offset, len(before)))
            continue
        open(path, "w", encoding="utf-8").write(out)
    print("%s: %d файлів із %d" % ("показано" if a.dry else "переписано", changed, len(files)))


main()
