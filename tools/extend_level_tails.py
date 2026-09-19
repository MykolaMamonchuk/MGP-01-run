#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""extend_level_tails.py — дотягнути перешкоди до кінця рівня для ШВИДКОЇ дитини.

Вада. Рівень закінчується за ЧАСОМ (`level_t >= level_duration` у run3d.gd), а маркери стоять
у МЕТРАХ. Розкладені вони під профіль `mid`, тож швидка дитина (`older`) добігає далі, ніж
сягають маркери. Заміряно по всіх 17 рівнях: **остання чверть кожного рівня для `older` не
має жодної перешкоди** — від 90 м на першому до 311 м на сімнадцятому, скрізь 24–26%.
Для `mid` порожньо приблизно 10%. Задуманий спокійний фініш — це лише останні 6 секунд
(GATE_BEFORE_SEC), а не чверть рівня.

Що робимо. Продовжуємо ТОЙ САМИЙ візерунок, яким рівень складено: рівний крок по z,
пилка смуг −max…+max, види по колу. Нічого не переставляємо — тільки дописуємо хвіст.

Про запас. Цільову відстань беремо з великим запасом (×1,25 замість точної ×1,21): зайві
маркери за фінішем нічого не коштують, бо `spawn_finish_gate()` ставить `finish_pending`, і
`_advance_authored()` після цього не спавнить нічого взагалі. А ось недотягнути — це знову
порожній хвіст, тільки коротший.

Запуск:
    python3 tools/extend_level_tails.py            # порахувати й показати
    python3 tools/extend_level_tails.py --write    # записати
"""
import argparse
import glob
import json
import os
import re


# --- СТОП після переходу на локальні координати (18.09.2026) ---------------------------
# Маркери чанків більше не тримають абсолютну z: її дає корінь сцени (LevelLayout.z_offset_m),
# див. tools/localize_chunk_z.py. Цей інструмент рахує z як абсолютну, тож на нових файлах
# він порахував би неправильно — і зробив би це МОВЧКИ. Поки його не переписано, він
# відмовляється працювати.
def _refuse_if_localized():
    import glob as _glob
    for _p in _glob.glob("levels/level_*/chunk_*.tscn"):
        if "z_offset_m" in open(_p, encoding="utf-8").read():
            raise SystemExit(
                "%s: чанки вже в ЛОКАЛЬНИХ координатах (є z_offset_m), а цей інструмент\n"
                "рахує z як абсолютну. Перепиши його під зсув чанка, перш ніж запускати."
                % __file__)


_refuse_if_localized()


CHUNK_LENGTH_M = 150.0    # той самий поділ, що в src/run3d/level_chunk_loader.gd
SAFETY = 1.25             # див. «Про запас» у шапці

HEADER = ('[gd_scene load_steps=2 format=3]\n\n'
          '[ext_resource type="Script" path="res://src/run3d/level_marker_3d.gd" id="1"]\n\n'
          '[node name="LevelLayout" type="Node3D"]\n')

NODE = ('\n[node name="%s" type="Node3D" parent="." index="%d"]\n'
        'script = ExtResource("1")\n'
        'role = "obstacle"\n'
        'kind = "%s"\n'
        'lane = %d\n'
        'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0.0, 0.0, %.1f)\n')


def obstacles(num):
    """Усі перешкоди рівня: (z, смуга, вид), за зростанням z. Плюс найбільший номер маркера."""
    out, top = [], 0
    for f in sorted(glob.glob("levels/level_%02d/chunk_*.tscn" % num)):
        for block in open(f).read().split("[node ")[1:]:
            nm = re.match(r'name="M(\d+)_', block)
            if nm:
                top = max(top, int(nm.group(1)))
            role = re.search(r'role\s*=\s*"(\w+)"', block)
            if not role or role.group(1) != "obstacle":
                continue
            lane = re.search(r'lane\s*=\s*(-?\d+)', block)
            kind = re.search(r'kind\s*=\s*"([^"]+)"', block)
            tr = re.search(r'Transform3D\(([^)]*)\)', block)
            if lane and kind and tr:
                out.append((abs(float(tr.group(1).split(",")[-1])), int(lane.group(1)),
                            kind.group(1)))
    out.sort()
    return out, top


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    pr = json.load(open("data/profiles.json"))
    fastest = max(float(v["speed"]) for v in pr.values()
                  if isinstance(v, dict) and "speed" in v)

    for level in json.load(open("data/levels.json"))["levels"]:
        num = level["id"]
        obs, top = obstacles(num)
        if not obs:
            continue
        target = fastest * float(level["speed_mult"]) * float(level["duration_sec"]) * SAFETY
        last_z = obs[-1][0]
        if target <= last_z + 1.0:
            print("рівень %-2d: маркери вже сягають %.0f м — досить" % (num, last_z))
            continue

        step = (obs[-1][0] - obs[0][0]) / max(1, len(obs) - 1)
        wide = int(level.get("lanes_to", level["lanes"])) // 2
        cycle = list(range(-wide, wide + 1))
        # Види беремо зі списку РІВНЯ, якщо він є: obstacle_types задає криву навчання
        # (перший рівень — тільки пеньок і калюжа), і дотягувати хвіст видами, яких рівень
        # не дозволяє, означало б зламати її вдруге. Порожній список = усі види біому,
        # тоді беремо ті, що вже стоять у рівні.
        kinds = list(level.get("obstacle_types") or []) or sorted({k for _, _, k in obs})
        li = (cycle.index(obs[-1][1]) + 1) % len(cycle) if obs[-1][1] in cycle else 0
        ki = (kinds.index(obs[-1][2]) + 1) % len(kinds) if obs[-1][2] in kinds else 0

        added, z = [], last_z + step
        while z <= target:
            added.append((z, cycle[li], kinds[ki]))
            li = (li + 1) % len(cycle)
            ki = (ki + 1) % len(kinds)
            z += step
        print("рівень %-2d: було до %.0f м, треба до %.0f — дописуємо %d перешкод (крок %.1f м)"
              % (num, last_z, target, len(added), step))
        if not a.write:
            continue

        by_chunk = {}
        for z, lane, kind in added:
            by_chunk.setdefault(int(z // CHUNK_LENGTH_M), []).append((z, lane, kind))
        for ci, items in sorted(by_chunk.items()):
            path = "levels/level_%02d/chunk_%02d.tscn" % (num, ci)
            if os.path.exists(path):
                text = open(path).read()
                index = text.count("[node name=") - 1     # без кореня LevelLayout
            else:
                text, index = HEADER, 0
            for z, lane, kind in items:
                top += 1
                text += NODE % ("M%d_obstacle_%s" % (top, kind), index, kind, lane, -z)
                index += 1
            open(path, "w").write(text)
        print("     записано у %d файлів" % len(by_chunk))


main()
