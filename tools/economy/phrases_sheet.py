#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""phrases_sheet.py — показати бібліотеку фраз дороги ОКОМ, а не JSON'ом.

Навіщо. Фраза (data/phrases.json) — це шматок дороги, де перешкоди й золото задані разом,
у координатах z/доріжка. У такому вигляді неможливо побачити головне: чи монети справді
ведуть туди, куди треба, і чи лишається дитині прохід. Схема на три доріжки показує це за
секунду — так само, як вона показана в LDD §5.

    python3 tools/economy/phrases_sheet.py            # усі придатні
    python3 tools/economy/phrases_sheet.py --all      # разом із тими, що чекають механік
    python3 tools/economy/phrases_sheet.py gate_one   # одну

Легенда збігається з LDD §5. ВАЖЛИВО про читання схем: колонки — ДОРІЖКИ (ліва, середня,
права), рядки — МЕТРИ згори вниз, тобто дитина біжить зверху вниз. У самому LDD підпис до
схем каже навпаки («рядки = доріжки»), але жодна з тамтешніх схем так не читається —
`gate_one` при такому читанні дав би перешкоди в одній доріжці замість воріт. Тут — як
насправді.
"""
import argparse
import json
import os
import sys

STEP = 0.9          # крок між монетами (Spawner3D.STAR_STEP)
ARC_STEP = 1.2      # крок у дузі (spawn_star_arc)
ROW_M = 0.9         # висота рядка схеми в метрах

MARK_OBST = {"jump": "▄", "duck": "▀", "side": "✖", "any": "·"}
WHY_MARK = {"guide": "●", "reward": "◆", "celebration": "✦", "jackpot": "★"}


def coins(fig):
    """Фігура → список (z, доріжка). Та сама розкладка, що у Spawner3D._spawn_gold_figure."""
    z0 = float(fig.get("z", 0.0))
    lane = int(fig.get("lane", 0))
    n = int(fig.get("n", 1))
    kind = fig.get("kind", "line")
    if kind == "climb":
        to = int(fig.get("to_lane", lane + 1))
        return [(z0 + i * STEP, round(lane + (to - lane) * (i / max(1, n - 1))))
                for i in range(n)]
    if kind == "arc":
        return [(z0 + i * ARC_STEP, lane) for i in range(n)]
    if kind == "cluster":
        w = int(fig.get("w", 3))
        left = lane - (w - 1) // 2
        out = []
        for i in range(n):
            out.append((z0 + (i // w) * STEP, left + (i % w)))
        return out
    return [(z0 + i * STEP, lane) for i in range(n)]


def draw(p):
    nominal = sum(int(g["n"]) * int(g.get("value", 1)) for g in p["gold"])
    head = "%s  ·  тир %d  ·  з рівня %d  ·  %.0f м  ·  %d очок  ·  %d номіналу" % (
        p["id"], p["tier"], p["min_level"], p["length_m"], p["obstacle_points"], nominal)
    print(head)
    print("  " + p["teaches"])
    if "needs" in p:
        print("  ЧЕКАЄ МЕХАНІК: %s" % ", ".join(p["needs"]))
        print()
        return
    rows = max(1, int(round(float(p["length_m"]) / ROW_M)))
    grid = [[" ", " ", " "] for _ in range(rows + 1)]
    for o in p["obstacles"]:
        r = int(round(float(o.get("z", 0.0)) / ROW_M))
        c = int(o.get("lane", 0)) + 1
        if 0 <= r < len(grid) and 0 <= c < 3:
            grid[r][c] = MARK_OBST.get(o.get("action", "any"), "?")
    for g in p["gold"]:
        mark = WHY_MARK.get(g.get("why", ""), "●")
        for z, lane in coins(g):
            r = int(round(z / ROW_M))
            c = int(lane) + 1
            if 0 <= r < len(grid) and 0 <= c < 3 and grid[r][c] == " ":
                grid[r][c] = mark
    print("     ліво центр право")
    for r, row in enumerate(grid):
        if all(ch == " " for ch in row):
            continue
        print("  %4.1f м   %s   %s   %s" % (r * ROW_M, row[0], row[1], row[2]))
    print("  вдих після: %.1f с" % float(p["recovery_sec"]))
    print()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("only", nargs="*", help="id фраз; порожньо — усі")
    ap.add_argument("--all", action="store_true", help="разом із тими, що чекають механік")
    a = ap.parse_args()
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    data = json.load(open(os.path.join(root, "data", "phrases.json"), encoding="utf-8"))
    print("Легенда: ▄ стрибок · ▀ присід · ✖ обійти · ● веде · ◆ плата за ризик"
          " · ✦ святкування · ★ джекпот")
    print("Колонки — доріжки, рядки — метри згори вниз (дитина біжить униз).\n")
    for p in data["phrases"]:
        if a.only and p["id"] not in a.only:
            continue
        if "needs" in p and not a.all and not a.only:
            continue
        draw(p)
    return 0


if __name__ == "__main__":
    sys.exit(main())
