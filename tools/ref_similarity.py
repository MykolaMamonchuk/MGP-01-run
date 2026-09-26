#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ref_similarity.py — наскільки модель схожа на МАЛЮНОК, у відсотках (силует і колір).

Навіщо. Замовник вимагає, щоб моделі «за малюнком» були схожі на нього мінімум на 60-70%.
Оком це не міряється: ми вже двічі казали «схоже», а в грі виходило інше. tools/prop_similarity.py
порівнює дві 3D-моделі; тут — рендер моделі з малюнком.

Три числа:
  СИЛУЕТ — IoU масок об'єкта (тло відкидається за кольором кутів), обидві вписані в однакову
    рамку: міряє форму й пропорції, а не кадрування.
  ПАЛІТРА — чи є кольори малюнка в моделі й навпаки: для кожного пікселя об'єкта відстань до
    найближчого кольору другої картинки, 100% мінус середня (RGB 100 = 0%), в обидва боки. Не
    залежить від того, чи дах піксель у піксель там, де на малюнку.
  КОЛІР НА МІСЦІ — по клітинках сітки 8×8, де є і модель, і малюнок: 100% мінус середня різниця
    кольору (RGB-відстань 100 = 0%). Найсуворіше: карає й за інший колір, і за зсув деталей.
«Разом» — середнє силуету й палітри: форма й кольори, як просив замовник.

Рендер має бути під тим самим кутом, що й малюнок. Підставку, квіти, кущі з малюнка, яких у
моделі нема навмисно, відрізає --ref-crop x0,y0,x1,y1 (частки 0..1).

    python3 tools/ref_similarity.py малюнок.jpg рендер.png --ref-crop 0,0,1,0.78
"""
import argparse

from PIL import Image


def mask_of(im, thr):
    w, h = im.size
    px = im.load()
    corners = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    bg = tuple(sorted(c[i] for c in corners)[1] for i in range(3))
    m = Image.new("L", im.size, 0)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            c = px[x, y]
            if sum((c[i] - bg[i]) ** 2 for i in range(3)) > thr * thr:
                mp[x, y] = 255
    return m


def norm(im, m, size):
    box = m.getbbox()
    return im.crop(box).resize((size, size)), m.crop(box).resize((size, size))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref")
    ap.add_argument("ours")
    ap.add_argument("--ref-crop", default="0,0,1,1")
    ap.add_argument("--thr", type=float, default=28.0)
    ap.add_argument("--size", type=int, default=128)
    ap.add_argument("--grid", type=int, default=8)
    a = ap.parse_args()
    ref = Image.open(a.ref).convert("RGB")
    ours = Image.open(a.ours).convert("RGB")
    x0, y0, x1, y1 = [float(v) for v in a.ref_crop.split(",")]
    w, h = ref.size
    ref = ref.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    ref = ref.resize((256, int(256 * ref.size[1] / ref.size[0])))
    ours = ours.resize((256, int(256 * ours.size[1] / ours.size[0])))
    ri, rm = norm(ref, mask_of(ref, a.thr), a.size)
    oi, om = norm(ours, mask_of(ours, a.thr), a.size)
    rmp, omp, rip, oip = rm.load(), om.load(), ri.load(), oi.load()
    inter = union = 0
    for y in range(a.size):
        for x in range(a.size):
            r_, o_ = rmp[x, y] > 127, omp[x, y] > 127
            inter += r_ and o_
            union += r_ or o_
    shape = 100.0 * inter / max(union, 1)
    cell = a.size // a.grid
    scores = []
    for gy in range(a.grid):
        for gx in range(a.grid):
            rs, os_, n = [0, 0, 0], [0, 0, 0], 0
            for y in range(gy * cell, (gy + 1) * cell):
                for x in range(gx * cell, (gx + 1) * cell):
                    if rmp[x, y] > 127 and omp[x, y] > 127:
                        n += 1
                        for i in range(3):
                            rs[i] += rip[x, y][i]
                            os_[i] += oip[x, y][i]
            if n > cell * cell * 0.3:
                d = sum((rs[i] / n - os_[i] / n) ** 2 for i in range(3)) ** 0.5
                scores.append(max(0.0, 100.0 - d))
    color = sum(scores) / max(len(scores), 1)
    # Палітра: чи є кольори малюнка в моделі й навпаки. Для кожного з 600 випадкових пікселів
    # об'єкта — відстань до найближчого кольору другої картинки; 100% мінус середня відстань
    # (RGB 100 = 0%), в обидва боки. Кошики гістограми тут не годяться: колір, зсунутий на пів
    # кошика, рахувався б «зовсім іншим».
    import random
    def samples(ip, mp, n=600):
        pts = [ip[x, y] for y in range(a.size) for x in range(a.size) if mp[x, y] > 127]
        random.seed(3)
        return random.sample(pts, min(n, len(pts)))
    sr, so = samples(rip, rmp), samples(oip, omp)
    def cover(src, dst):
        tot = 0.0
        for c in src:
            tot += min(((c[0] - d[0]) ** 2 + (c[1] - d[1]) ** 2 + (c[2] - d[2]) ** 2) for d in dst) ** 0.5
        return max(0.0, 100.0 - tot / max(len(src), 1))
    palette = (cover(sr, so) + cover(so, sr)) / 2
    print("силует %.0f%%  палітра %.0f%%  колір на місці %.0f%%  разом %.0f%%"
          % (shape, palette, color, (shape + palette) / 2))


if __name__ == "__main__":
    main()
