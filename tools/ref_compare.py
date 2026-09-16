#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ref_compare.py — порівняти знімок гри з референсним малюнком ЧИСЛОМ.

Навіщо. «Схоже на референс» без числа — це суперечка смаків, і перевірити її неможливо.
Піксель у піксель порівнювати теж не можна: референс намальовано, а не відрендерено.

Що міряємо. Частку кадру, яку займає кожен ЗМІСТОВНИЙ клас кольору — небо, вода, трава,
дорога, дерево/черепиця, листя. Саме ці частки й відрізняють «містечко над річкою» від
«лужка з дорогою»: у референсі забудова займає п'яту частину кадру, у нас спершу займала
кілька відсотків. Додатково — розклад по ГОРИЗОНТАЛІ (дорога посередині, вода обабіч,
забудова скраю), бо однакові частки можна набрати й геть іншою розкладкою.

    python3 tools/ref_compare.py --ref docs/refs/.../riverside-0.jpg --shot /tmp/track.png

Відповідь — таблиця «клас: у референсі / у нас / різниця» і підсумковий відсоток збігу.
"""
import argparse
import colorsys

from PIL import Image

## Класи задано в HSV, бо в референсі та в грі різна яскравість і насиченість, а ВІДТІНОК
## тримається: червона черепиця лишається червоною, вода синьою. Пороги широкі навмисно —
## завдання відрізнити «є забудова» від «нема», а не впізнати конкретний будинок.
## Аргумент cx — де піксель лежить по горизонталі (0 лівий край, 1 правий). Він потрібен
## рівно одному класу. Кремова бруківка й кремова стіна будинку мають ОДИН колір, і за
## самим кольором їх не розрізнити — прилад через це називав забудову скраю «дорогою» й
## показував 16% дороги там, де її нема. Але в раннері дорога завжди посередині кадру, і
## цього досить: крем у центрі — дорога, крем скраю — стіна.
ROAD_BAND = (0.33, 0.67)

CLASSES = [
    ("небо",      lambda h, s, v, cx: 0.50 <= h <= 0.65 and s < 0.45 and v > 0.62),
    # Поріг насиченості для води знижено з 0,30 до 0,18: спокійна річкова синь має меншу
    # насиченість за басейнову бірюзу, і прилад карав саме за те, що вода стала природнішою.
    # Від неба її все одно відрізняє те, що небо блідіше й світліше (див. клас вище).
    ("вода",      lambda h, s, v, cx: 0.47 <= h <= 0.68 and s >= 0.18 and v > 0.30),
    ("трава",     lambda h, s, v, cx: 0.20 <= h <= 0.45 and s >= 0.25),
    # дерево СТОЇТЬ ПЕРЕД забудовою навмисно: правило забудови ширше й поглинуло б його,
    # і тоді містки з поручнями зникли б з обліку, хоч їх на екрані повно
    ("дерево",    lambda h, s, v, cx: 0.06 <= h <= 0.14 and s >= 0.30),
    ("дорога",    lambda h, s, v, cx: (h < 0.16 or h > 0.92) and s < 0.35 and v > 0.70
                                      and ROAD_BAND[0] <= cx <= ROAD_BAND[1]),
    ("забудова",  lambda h, s, v, cx: (h < 0.16 or h > 0.92) and v > 0.25
                                      and (s >= 0.35 or not (ROAD_BAND[0] <= cx <= ROAD_BAND[1]))),
]


def profile(img, cols=0):
    img = img.convert("RGB").resize((240, 135), Image.LANCZOS)
    w, h = img.size
    px = img.load()
    total = w * h
    share = {name: 0 for name, _ in CLASSES}
    share["інше"] = 0
    bycol = [dict((n, 0) for n, _ in CLASSES) for _ in range(cols)] if cols else []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            hit = "інше"
            for name, test in CLASSES:
                if test(hh, ss, vv, x / float(w - 1)):
                    hit = name
                    break
            share[hit] += 1
            if cols and hit != "інше":
                bycol[min(x * cols // w, cols - 1)][hit] += 1
    return {k: v / total for k, v in share.items()}, bycol


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True)
    ap.add_argument("--shot", required=True)
    ap.add_argument("--columns", type=int, default=6)
    a = ap.parse_args()

    ref, ref_cols = profile(Image.open(a.ref), a.columns)
    shot, shot_cols = profile(Image.open(a.shot), a.columns)

    print("  клас        референс     у нас    різниця")
    overlap = 0.0
    for name in [n for n, _ in CLASSES] + ["інше"]:
        d = shot[name] - ref[name]
        overlap += min(ref[name], shot[name])
        flag = "   <--" if abs(d) > 0.06 else ""
        print("  %-10s %7.1f%%  %7.1f%%  %+7.1f%%%s" % (name, ref[name] * 100, shot[name] * 100, d * 100, flag))
    print("\n  збіг за частками кадру: %.0f%%" % (overlap * 100))

    # розклад по горизонталі: та сама частка, набрана іншою розкладкою, — не те саме
    names = [n for n, _ in CLASSES]
    col_hit = 0
    for i in range(a.columns):
        r = max(names, key=lambda n: ref_cols[i][n])
        s = max(names, key=lambda n: shot_cols[i][n])
        col_hit += 1 if r == s else 0
        print("  стовпчик %d: референс %-9s у нас %-9s %s" % (i + 1, r, s, "" if r == s else "<--"))
    print("  збіг за розкладкою: %d/%d" % (col_hit, a.columns))


main()
