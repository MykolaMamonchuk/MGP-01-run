#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""widen_level_lanes.py — розкласти перешкоди на НОВІ смуги там, де дорога розширюється.

Вада, яку це лікує. Рівні 4, 11 і 16 мають фішку «дорога розширюється»: 3→5 смуг у
четвертого, 5→7 в одинадцятого й шістнадцятого. Але маркери перешкод у levels/level_XX/
користуються лише старим набором смуг до самого кінця рівня. Заміряно: після розширення в
нових крайніх смугах НУЛЬ перешкод — 105 штук на три рівні сидять у центрі. Дитина може
просто триматися скраю й до фінішу нікого не зустріти, а сама фішка рівня нічого не важить.

Чому це безпечно. Перевірено: у цих рівнях кожна перешкода стоїть сама на своїй відстані,
двох на одному z нема ніде. Тож перекрити всі смуги неможливо за побудовою — міняється лише
те, в яку смугу стає поодинока перешкода.

Звідки береться точка розширення. Гра рахує її за ЧАСОМ (`progress = level_t /
level_duration` у run3d.gd, поріг `lanes_at`), а маркери стоять у МЕТРАХ — тож для швидкого
й повільного профілю це різна відстань. Беремо найпізнішу з трьох (профіль older): далі за
неї дорога вже широка для будь-якої дитини, і перешкода в новій смузі не повисне за краєм.
Швидкість за рівнем: speed × speed_mult × (1 + 0.35 × прогрес), тож пройдена відстань —
v·D·(p + 0.175p²).

Смуги чергуються пилкою −max…+max, бо саме так зроблено в усіх рівнях гри (перевірено на
12 і 17, які сімсмугові від початку). Продовжуємо ту саму пилку, лише ширшу.

Запуск:
    python3 tools/widen_level_lanes.py            # порахувати й показати
    python3 tools/widen_level_lanes.py --write    # записати
"""
import argparse
import glob
import json
import os
import re

MARGIN_M = 10.0   # запас за точкою розширення, щоб не чіпати саму мить переходу


def widen_distance(level, profiles):
    """Найпізніша відстань (м), на якій дорога вже точно розширилась — по всіх профілях."""
    at = float(level.get("lanes_at", 0.5))
    dur = float(level["duration_sec"])
    mult = float(level["speed_mult"])
    best = 0.0
    for p in profiles.values():
        if not isinstance(p, dict) or "speed" not in p:
            continue
        v = float(p["speed"]) * mult
        best = max(best, v * dur * (at + 0.175 * at * at))
    return best


def obstacles_of(path):
    """(початок блоку, z, смуга) для кожного маркера-перешкоди у файлі."""
    text = open(path).read()
    out = []
    for m in re.finditer(r'\[node [^\]]*\]\n((?:[^\[]*\n)*)', text):
        block = m.group(0)
        role = re.search(r'role\s*=\s*"(\w+)"', block)
        if not role or role.group(1) != "obstacle":
            continue
        lane = re.search(r'lane\s*=\s*(-?\d+)', block)
        tr = re.search(r'Transform3D\(([^)]*)\)', block)
        if lane and tr:
            z = abs(float(tr.group(1).split(",")[-1]))
            out.append((m.start(), z, int(lane.group(1))))
    return text, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()

    profiles = json.load(open("data/profiles.json"))
    levels = {l["id"]: l for l in json.load(open("data/levels.json"))["levels"]}

    for num, level in sorted(levels.items()):
        if "lanes_to" not in level:
            continue
        cut = widen_distance(level, profiles) + MARGIN_M
        wide = int(level["lanes_to"]) // 2
        files = sorted(glob.glob("levels/level_%02d/chunk_*.tscn" % num))
        if not files:
            continue

        # Спершу збираємо ВСІ перешкоди рівня по порядку — пилку треба вести наскрізно,
        # інакше на межі чанків вона стрибне.
        everything = []
        for f in files:
            text, obs = obstacles_of(f)
            for start, z, lane in obs:
                everything.append([z, f, start, lane])
        everything.sort(key=lambda r: r[0])

        cycle = list(range(-wide, wide + 1))
        changed = {}
        # продовжуємо з тієї точки пилки, на якій зупинилась вузька частина
        idx = 0
        for rec in everything:
            z, f, start, lane = rec
            if z <= cut:
                idx = (cycle.index(lane) + 1) % len(cycle) if lane in cycle else 0
                continue
            want = cycle[idx]
            idx = (idx + 1) % len(cycle)
            if want != lane:
                changed.setdefault(f, []).append((start, lane, want))

        after = [r for r in everything if r[0] > cut]
        print("рівень %-2d: %d→%d смуг, розширення найпізніше на %.0f м (+запас) — "
              "перешкод далі %d, змінено смугу в %d"
              % (num, level["lanes"], level["lanes_to"], cut - MARGIN_M,
                 len(after), sum(len(v) for v in changed.values())))
        lanes_after = sorted({cycle[(i) % len(cycle)] for i in range(len(after))}) if after else []
        print("     смуги після розширення стануть: %s" % (lanes_after or "—"))
        if not a.write:
            continue

        for f, edits in changed.items():
            text = open(f).read()
            # правимо з кінця, щоб зсуви не поїхали
            for start, was, want in sorted(edits, reverse=True):
                end = text.find("\n[node ", start + 1)
                end = len(text) if end < 0 else end
                block = text[start:end]
                block2 = re.sub(r'(lane\s*=\s*)-?\d+', r'\g<1>%d' % want, block, count=1)
                text = text[:start] + block2 + text[end:]
            open(f, "w").write(text)
        print("     записано у %d файлів" % len(changed))


main()
