#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""freeze_chunk.py — перетворити процедурне оздоблення цеглинки на МАРКЕРИ СЦЕНИ.

Навіщо. Процедурний декоратор зручний, поки світу мало, але має дві вади, і обидві заміряні:

  ВІН НЕСТАЛИЙ. Рівень 2, два прогони з різними зернами: 3042 і 3018 предметів, однакових
  лише 868. Найгірше з будинками (house_small 21↔30, house_teal 32↔24) і містками (104↔98) —
  вони йдуть лічильниками, тобто залежать від історії прогону, а не від місця.

  ЙОГО НЕ ВИДНО В РЕДАКТОРІ. Те, що він поставив, не можна ні посунути, ні прибрати, ні
  побачити, доки не запустиш гру. Через це предмети налазять одне на одне (дерево в будинку,
  тюки один на одному), і полагодити це нічим.

Заморожування прибирає обидві: оздоблення стає звичайними маркерами, які видно у сцені й
можна правити мишею, а рівень із `"authored": true` більше нічого не досипає.

Заморожуємо саме ЦЕГЛИНКУ, а не рівень: рівень тепер складається з цеглинок, і та сама
цеглинка стоїть на різних метрах різних рівнів. Тоді вона виглядає однаково скрізь.

Маркери лягають у теку «Декор» — ту саму, що й рукотворний декор: сторож
`tests/test_level_chunk_groups.gd` вимагає теку за РОЛЛЮ, а не за походженням.

Результат лягає в `dress_<світ>.tscn` ПОРУЧ із `chunk.tscn`, а не всередину нього. Так
рукотворне лишається в маленькому файлі, який можна читати очима, а вісім сотень маркерів
оздоблення — у своєму, куди зазирають лише за потреби.

    python3 tools/freeze_chunk.py meadow_village          # усі світи цеглинки
    python3 tools/freeze_chunk.py --all                   # усі цеглинки бібліотеки
    python3 tools/freeze_chunk.py meadow_village --world meadow

Запускати з кореня проєкту.
"""
import argparse
import glob
import json
import os
import subprocess
import tempfile

GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
ROOT = "levels/chunks"
HEAD = '''[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://src/run3d/level_marker_3d.gd" id="1"]
[ext_resource type="Script" path="res://src/run3d/level_layout.gd" id="2"]

[node name="LevelLayout" type="Node3D"]
script = ExtResource("2")

[node name="Декор" type="Node3D" parent="."]
'''


def freeze(chunk, world, out_json):
    env = dict(os.environ, CHUNK=chunk, WORLD=world, OUT=out_json)
    env.pop("GAME_SEED", None)          # зерно ставить сам інструмент, стале
    subprocess.run([GODOT, "--headless", "--path", ".", "res://src/debug/freeze_chunk.tscn"],
                   env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    with open(out_json) as f:
        return json.load(f)


def scene_text(records):
    out = [HEAD]
    for i, r in enumerate(records):
        if not r.get("kind") or r["kind"] == "?":
            continue          # декоратор не назвав вид — такий маркер нічого не намалює
        # Роль завжди «decor»: журнал декоратора не розрізняє забудову й дрібницю, а для
        # Track вони й так ідуть одним шляхом (_add_decor). Роль тут потрібна лише щоб
        # LevelTimeline поклав запис у потрібний масив.
        out.append('\n[node name="D%d_%s" type="Node3D" parent="Декор"]\n' % (i + 1, r["kind"]))
        out.append('script = ExtResource("1")\n')
        out.append('role = "decor"\n')
        out.append('kind = "%s"\n' % r["kind"])
        if abs(float(r.get("yaw_deg", 0.0))) > 0.01:
            out.append("yaw_deg = %.1f\n" % float(r["yaw_deg"]))
        if abs(float(r.get("scale", 1.0)) - 1.0) > 0.001:
            out.append("scale_mul = %.3f\n" % float(r["scale"]))
        out.append("transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, %.2f, %.2f, %.2f)\n"
                   % (float(r["x_m"]), float(r.get("y_m", 0.0)), -float(r["z_m"])))
    return "".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("chunks", nargs="*")
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--world", default="")
    a = ap.parse_args()

    ids = a.chunks
    if a.all:
        ids = sorted(os.path.basename(os.path.dirname(p))
                     for p in glob.glob("%s/*/chunk.json" % ROOT))
    if not ids:
        raise SystemExit("треба назвати цеглинку або --all")

    tmp = tempfile.mkdtemp(prefix="freeze_")
    for chunk in ids:
        desc_path = "%s/%s/chunk.json" % (ROOT, chunk)
        if not os.path.exists(desc_path):
            print("  ПРОПУЩЕНО %s — нема опису" % chunk)
            continue
        with open(desc_path) as f:
            desc = json.load(f)
        worlds = [a.world] if a.world else list(desc.get("worlds", []))
        for world in worlds:
            data = freeze(chunk, world, os.path.join(tmp, "%s_%s.json" % (chunk, world)))
            out = "%s/%s/dress_%s.tscn" % (ROOT, chunk, world)
            with open(out, "w") as f:
                f.write(scene_text(data["decor"]))
            print("  %-22s %-8s %4d маркерів → %s" % (chunk, world, len(data["decor"]),
                                                      os.path.basename(out)))


main()
