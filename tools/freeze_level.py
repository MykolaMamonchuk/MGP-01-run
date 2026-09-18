#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""freeze_level.py — перетворити те, що процедура поставила, на МАРКЕРИ СЦЕНИ.

Навіщо. Процедура зручна, поки світу мало. Коли рівень доводять до ладу руками, вона
заважає: її розстановки не видно в редакторі, її не можна посунути й важко дебажити. Тому
один раз записуємо, що вона вигадала (src/debug/freeze_level.tscn → JSON), розкладаємо це по
чанках як LevelMarker3D — і далі рівень правиться візуально.

Що заморожувати. Не все: стрічка поручнів — це один предмет на метр траси, вона тримається
берега й дизайнерського сенсу не має. Тому:

  --what structure (типово)  будинки, орієнтири, стіни, містки, арки — те, що АВТОР ставить
                             свідомо. Для рівня 1 це ~380 маркерів на 400 м
  --what all                 усе, крім стрічки поручнів (~1800)
  --what everything          геть усе, разом з поручнями (~2600)

Після заморожування поставити рівню `"authored": true` в data/levels.json — тоді Track
перестає класти процедурний декор і малює лише поверхні (дорога, узбіччя, канал, вода).

    python3 tools/freeze_level.py /tmp/level_01.json --level 1
    python3 tools/freeze_level.py /tmp/level_01.json --level 1 --what all --dry
"""
import argparse
import json
import os
import re

CHUNK_LENGTH_M = 150.0
## Стрічка поручнів: один предмет на метр, тримається берега. Дизайнерського сенсу не має,
## і в маркерах лише заважала б.
RIBBON = {"fence_rail"}


def structure_kinds(world):
    """Види, які автор ставить свідомо — беремо з самих даних світу, не зі списку в коді."""
    out = set()
    for key in ("buildings_far", "landmarks", "walls_near", "walls_far"):
        for v in world.get(key, []) or []:
            out.add(str(v))
    out.add("bridge_plank")
    return out


def marker(name, kind, x, y, z_local, yaw_deg, scale, script_id):
    lines = ['[node name="%s" type="Node3D" parent="."]' % name,
             'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.3f, %.3f, %.3f)'
             % (x, y, -z_local),
             'script = ExtResource("%s")' % script_id,
             'kind = "%s"' % kind]
    if abs(yaw_deg) > 0.05:
        lines.append("yaw_deg = %.1f" % yaw_deg)
    if abs(scale - 1.0) > 0.005:
        lines.append("scale_mul = %.3f" % scale)
    return "\n".join(lines) + "\n\n"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("journal", help="JSON від src/debug/freeze_level.tscn")
    ap.add_argument("--level", type=int, required=True)
    ap.add_argument("--what", default="structure", choices=["structure", "all", "everything"])
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    data = json.load(open(a.journal, encoding="utf-8"))
    levels = json.load(open("data/levels.json", encoding="utf-8"))["levels"]
    level = next((l for l in levels if int(l["id"]) == a.level), None)
    if level is None:
        raise SystemExit("нема рівня %d у data/levels.json" % a.level)
    world = json.load(open("data/worlds/%s.json" % level["world"], encoding="utf-8"))

    keep = structure_kinds(world)
    picked = []
    for r in data["decor"]:
        kind = r["kind"]
        if a.what == "structure" and kind not in keep:
            continue
        if a.what == "all" and kind in RIBBON:
            continue
        picked.append(r)

    buckets = {}
    skipped_before_start = 0
    for r in picked:
        if r["z_m"] < 0.0:
            # ряди, що стоять ПОЗАДУ старту: траса будується з запасом назад, у рівні їх нема
            skipped_before_start += 1
            continue
        idx = int(r["z_m"] // CHUNK_LENGTH_M)
        buckets.setdefault(idx, []).append(r)
    if skipped_before_start:
        print("  пропущено %d предметів позаду старту" % skipped_before_start)

    print("відібрано %d із %d предметів (%s), чанків %d"
          % (len(picked), len(data["decor"]), a.what, len(buckets)))
    for idx in sorted(buckets):
        path = "levels/level_%02d/chunk_%02d.tscn" % (a.level, idx)
        if not os.path.exists(path):
            # Рівень міг вирости за межі наявних чанків (хвости подовжували окремим
            # інструментом). Створюємо порожній чанк із правильним зсувом, а не губимо вміст.
            head = open("levels/level_%02d/chunk_00.tscn" % a.level, encoding="utf-8").read()
            head = head.split("[node name=")[0]
            open(path, "w", encoding="utf-8").write(
                head + '[node name="LevelLayout" type="Node3D"]\nscript = ExtResource("2")\n'
                       'z_offset_m = %.1f\n\n' % (idx * CHUNK_LENGTH_M))
            print("  створено %s" % path)
            text = open(path, encoding="utf-8").read()
        text = open(path, encoding="utf-8").read()
        # regex терпимий до uid: редактор Godot дописує його МІЖ type і path, і сувора
        # версія через це мовчки пропускала кожен чанк, який людина відкривала в редакторі.
        m = re.search(r'ext_resource[^]]*level_marker_3d\.gd[^]]*id="([^"]+)"', text)
        if m is None:
            print("  ПРОПУЩЕНО %s — не знайдено скрипта маркера" % path)
            continue
        script_id = m.group(1)
        offset = idx * CHUNK_LENGTH_M
        added = ""
        for n, r in enumerate(sorted(buckets[idx], key=lambda v: v["z_m"])):
            added += marker("P%03d_%s" % (n, re.sub(r"[^A-Za-z0-9_]", "", r["kind"])),
                            r["kind"], r["x_m"], r["y_m"], r["z_m"] - offset,
                            r.get("yaw_deg", 0.0), r.get("scale", 1.0), script_id)
        print("  %-34s +%d маркерів" % (path, len(buckets[idx])))
        if not a.dry:
            open(path, "a", encoding="utf-8").write("\n" + added.rstrip() + "\n")
    if a.dry:
        print("(--dry: нічого не записано)")


main()
