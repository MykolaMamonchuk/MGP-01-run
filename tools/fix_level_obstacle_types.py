#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix_level_obstacle_types.py — привести маркери рівня до його ж списку obstacle_types.

Навіщо. `obstacle_types` у data/levels.json задає криву навчання: перший рівень — тільки
пеньок і калюжа, другий додає гілку, третій кущ і ящик, і так далі. Але поле читає лише
ВИПАДКОВИЙ спавнер (Spawner3D._allowed_kinds); рівні з авторськими маркерами його оминають —
_spawn_authored_obstacle() питає тільки, чи є такий вид у світі взагалі.

Заміряно: усі рівні свій список шанують, крім ПЕРШОГО. Туторіал, де дозволено stump і
puddle, насправді кидав корів, вози, вулики, білизну та ящики — 21 зайва перешкода з 27,
тобто 78%, і це найперше, що бачить чотирирічна дитина.

Зайві види замінюємо дозволеними по колу, за зростанням z. Позиція й смуга не міняються —
малюнок рівня лишається тим самим, міняється тільки те, ЩО стоїть.

Запуск:
    python3 tools/fix_level_obstacle_types.py            # показати
    python3 tools/fix_level_obstacle_types.py --write    # записати
"""
import argparse
import glob
import json
import re


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    for level in json.load(open("data/levels.json"))["levels"]:
        allowed = level.get("obstacle_types") or []
        if not allowed:
            continue
        num = level["id"]
        # збираємо всі перешкоди рівня по z, щоб заміна йшла рівним чергуванням наскрізь
        found = []
        for f in sorted(glob.glob("levels/level_%02d/chunk_*.tscn" % num)):
            text = open(f).read()
            for m in re.finditer(r'\[node [^\]]*\]\n(?:[^\[]*\n)*', text):
                block = m.group(0)
                if 'role = "obstacle"' not in block:
                    continue
                kind = re.search(r'kind\s*=\s*"([^"]+)"', block)
                tr = re.search(r'Transform3D\(([^)]*)\)', block)
                if kind and tr:
                    z = abs(float(tr.group(1).split(",")[-1]))
                    found.append([z, f, m.start(), kind.group(1)])
        found.sort(key=lambda r: r[0])
        wrong = [r for r in found if r[3] not in allowed]
        if not wrong:
            continue
        print("рівень %-2d: дозволено %s — замінюємо %d з %d перешкод"
              % (num, allowed, len(wrong), len(found)))
        edits = {}
        for i, rec in enumerate(wrong):
            want = allowed[i % len(allowed)]
            edits.setdefault(rec[1], []).append((rec[2], rec[3], want))
        if not a.write:
            continue
        for f, items in edits.items():
            text = open(f).read()
            for start, was, want in sorted(items, reverse=True):
                end = text.find("\n[node ", start + 1)
                end = len(text) if end < 0 else end
                block = text[start:end]
                block = re.sub(r'(kind\s*=\s*")[^"]+(")', r'\g<1>%s\g<2>' % want, block, count=1)
                block = re.sub(r'(name="M\d+_obstacle_)[^"]+(")', r'\g<1>%s\g<2>' % want,
                               block, count=1)
                text = text[:start] + block + text[end:]
            open(f, "w").write(text)
        print("     записано у %d файлів" % len(edits))


main()
