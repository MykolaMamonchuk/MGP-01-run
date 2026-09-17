#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""fix_side_decor_x.py — відсунути бічний декор за край дороги на КОЖНОМУ рівні.

Вада. Маркери декору розставлені з фіксованими |x| = 1,9 / 2,1 / 2,3 м на всіх сімнадцяти
рівнях. Для трисмугової дороги це правильно: край у неї на ±1,60 м
(`road_width() = lanes * LANE_W + 0.2`, ділене навпіл), тож декор стоїть на 0,3–0,7 м далі.
Але п'ятисмугова дорога має край ±2,60, а семисмугова ±3,60 — і ті самі 1,9–2,3 опиняються
ПРОСТО НА БІГОВІЙ СМУЗІ. Заміряно: 776 маркерів на рівнях 6–17, тобто ВЕСЬ бічний декор
дванадцяти рівнів із сімнадцяти. Дерева, пальми, парасолі, хмари — у смузі, якою біжить герой.

Рівні 1–5 (три смуги) не зачеплені.

Що робимо. Зберігаємо ЗАДУМАНИЙ відступ від краю: margin = |x| − 1,60 (край, під який
розкладали), і ставимо |x| = край_цього_рівня + margin. Знак і z не чіпаємо, тож малюнок
рівня лишається тим самим — міняється лише відстань від дороги.

Рівні з розширенням (4, 11, 16) мають ДВА краї: до точки розширення діє `lanes`, після —
`lanes_to`. Точку беремо ту саму, що й tools/widen_level_lanes.py: найпізнішу з профілів,
бо розширення рахується за ЧАСОМ, а маркери стоять у метрах.

Орієнтири (маркери по центру, |x| < 0.3) не чіпаємо — арка стоїть над дорогою за задумом.

Запуск:
    python3 tools/fix_side_decor_x.py            # показати
    python3 tools/fix_side_decor_x.py --write    # записати
"""
import argparse
import glob
import json
import re

LANE_W = 1.0        # Hero3D.LANE_W
ROAD_PAD = 0.2      # road_width() = lanes * LANE_W + ROAD_PAD
AUTHORED_EDGE = (3 * LANE_W + ROAD_PAD) / 2.0   # ±1.60 — під це розкладали маркери
MARGIN_M = 10.0     # той самий запас за точкою розширення, що в widen_level_lanes.py


def edge(lanes):
    return (float(lanes) * LANE_W + ROAD_PAD) / 2.0


def widen_distance(level, profiles):
    """Найпізніша відстань, на якій дорога вже точно розширилась — по всіх профілях."""
    at = float(level.get("lanes_at", 0.5))
    dur = float(level["duration_sec"])
    mult = float(level["speed_mult"])
    best = 0.0
    for p in profiles.values():
        if isinstance(p, dict) and "speed" in p:
            best = max(best, float(p["speed"]) * mult * dur * (at + 0.175 * at * at))
    return best + MARGIN_M


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write", action="store_true")
    a = ap.parse_args()
    profiles = json.load(open("data/profiles.json"))

    for level in json.load(open("data/levels.json"))["levels"]:
        num = level["id"]
        narrow = edge(level["lanes"])
        wide = edge(level.get("lanes_to", level["lanes"]))
        cut = widen_distance(level, profiles) if "lanes_to" in level else None
        moved = 0
        for f in sorted(glob.glob("levels/level_%02d/chunk_*.tscn" % num)):
            text = open(f).read()
            pieces = text.split("[node ")
            changed = False
            for i, piece in enumerate(pieces):
                if 'role = "decor"' not in piece:
                    continue
                m = re.search(r'(Transform3D\()([^)]*)(\))', piece)
                if not m:
                    continue
                args = [x.strip() for x in m.group(2).split(",")]
                if len(args) < 12:
                    continue
                x = float(args[9])
                z = abs(float(args[11]))
                if abs(x) < 0.3:
                    continue                      # орієнтир по центру — не наш випадок
                want_edge = wide if (cut is not None and z > cut) else narrow
                margin = abs(x) - AUTHORED_EDGE
                # Уже правильно розставлений декор (або вже виправлений) не чіпаємо.
                if margin < 0.0:
                    margin = abs(x) - AUTHORED_EDGE
                new = want_edge + margin
                if abs(abs(x) - new) < 0.01:
                    continue
                args[9] = "%.1f" % (new if x > 0 else -new)
                pieces[i] = piece[:m.start()] + m.group(1) + ", ".join(args) + m.group(3) \
                    + piece[m.end():]
                changed = True
                moved += 1
            if changed and a.write:
                open(f, "w").write("[node ".join(pieces))
        if moved:
            span = "±%.2f" % narrow if cut is None else "±%.2f → ±%.2f" % (narrow, wide)
            print("рівень %-2d: %d смуг, край %s — відсунуто %d маркерів"
                  % (num, level["lanes"], span, moved))


main()
