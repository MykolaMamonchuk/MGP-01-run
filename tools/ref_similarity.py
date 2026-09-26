#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""ref_similarity.py — наскільки модель схожа на МАЛЮНОК, у відсотках (силует і колір).

Навіщо. Замовник вимагає, щоб моделі «за малюнком» були схожі на нього мінімум на 60-70%.
Оком це не міряється: ми вже двічі казали «схоже», а в грі виходило інше. tools/prop_similarity.py
порівнює дві 3D-моделі; тут — рендер моделі з малюнком.

Три числа:
  СИЛУЕТ — IoU масок об'єкта (тло — по рядках з країв, бо воно градієнтом), обидві вписані в
    квадрат зі збереженням пропорцій: міряє форму й пропорції, а не кадрування.
  ПАЛІТРА — ¼ «покриття» (чи є кольори малюнка в моделі й навпаки: відстань до найближчого
    кольору, в обидва боки) + ¾ «частки» (8 кольорів малюнка, перетин розподілів — чи в тих
    самих пропорціях). Не залежить від того, чи дах піксель у піксель на місці.
  КОЛІР НА МІСЦІ — по клітинках сітки 8×8, де є і модель, і малюнок: 100% мінус середня різниця
    кольору (RGB-відстань 100 = 0%). Найсуворіше: карає й за інший колір, і за зсув деталей.
«Разом» — гармонійне середнє силуету й палітри: форма Й кольори, як просив замовник.

Рендер має бути під тим самим кутом, що й малюнок. Підставку, квіти, кущі з малюнка, яких у
моделі нема навмисно, відрізає --ref-crop x0,y0,x1,y1 (частки 0..1).

    python3 tools/ref_similarity.py малюнок.jpg рендер.png --ref-crop 0,0,1,0.78
"""
import argparse

from PIL import Image


def mask_of(im, thr, alpha=None):
    """Маска об'єкта.

    Рендер моделі — з прозорим тлом: маска просто з альфа-каналу.
    Малюнок — тло ЗАЛИВКОЮ від країв кадру: піксель іде в тло, якщо він майже такий, як сусід,
    що вже в тлі (крок ≤ 6), і не дуже далекий від кольору країв свого рядка (≤ thr·1.6). Так
    плавні градієнти й віньєтка — тло, а різкий край об'єкта зупиняє заливку. Усе, до чого
    заливка не дійшла, — об'єкт, тож дірки всередині (скло, кремова стіна) заповнюються самі.
    Попередня версія порівнювала кожен піксель лише з краями рядка і давала решето
    (рецензія 26.09)."""
    w, h = im.size
    if alpha is not None:
        return alpha.point(lambda v: 255 if v > 127 else 0)
    px = im.load()
    rowbg = []
    for y in range(h):
        edge = [px[x, y] for x in (1, 2, 3, w - 4, w - 3, w - 2)]
        rowbg.append(tuple(sum(c[i] for c in edge) / len(edge) for i in range(3)))
    far = (thr * 1.6) ** 2
    bg = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    for x, y in stack:
        bg[y * w + x] = 1
    while stack:
        x, y = stack.pop()
        c = px[x, y]
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx]:
                n = px[nx, ny]
                step = sum((n[i] - c[i]) ** 2 for i in range(3))
                rb = rowbg[ny]
                if step <= 36 and sum((n[i] - rb[i]) ** 2 for i in range(3)) <= far:
                    bg[ny * w + nx] = 1
                    stack.append((nx, ny))
    m = Image.new("L", im.size, 0)
    mp = m.load()
    for y in range(h):
        for x in range(w):
            if not bg[y * w + x]:
                mp[x, y] = 255
    return m


def norm(im, m, size):
    """Вписати об'єкт у квадрат, ЗБЕРІГАЮЧИ пропорції (доповнити тлом), — інакше широкий і
    вузький прямокутники давали «силует 100%»."""
    box = m.getbbox()
    if box is None:
        raise SystemExit("порожня маска: об'єкта не знайдено (тло того ж кольору? чорний рендер?)")
    im, m = im.crop(box), m.crop(box)
    side = max(im.size)
    sq_i = Image.new("RGB", (side, side), (0, 0, 0))
    sq_m = Image.new("L", (side, side), 0)
    off = ((side - im.size[0]) // 2, side - im.size[1])   # по центру й на «землі»
    sq_i.paste(im, off)
    sq_m.paste(m, off)
    return sq_i.resize((size, size)), sq_m.resize((size, size))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("ref")
    ap.add_argument("ours")
    ap.add_argument("--ref-crop", default="0,0,1,1")
    ap.add_argument("--thr", type=float, default=28.0)
    ap.add_argument("--size", type=int, default=128)
    ap.add_argument("--grid", type=int, default=8)
    a = ap.parse_args()
    ref = Image.open(a.ref)
    if ref.mode in ("RGBA", "LA", "P"):
        # Прозоре тло (PNG) — на біле; інакше прозорість стає випадковим кольором палітри.
        rgba = ref.convert("RGBA")
        white = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        ref = Image.alpha_composite(white, rgba)
    ref = ref.convert("RGB")
    ours_raw = Image.open(a.ours)
    ours_alpha = ours_raw.convert("RGBA").split()[3] if ours_raw.mode in ("RGBA", "LA") else None
    ours = ours_raw.convert("RGBA")
    if ours_alpha is not None:
        # колір — на тлі кольору кутів малюнка, щоб напівпрозорі краї не чорніли
        bgc = Image.new("RGBA", ours.size, ref.getpixel((2, 2)) + (255,))
        ours = Image.alpha_composite(bgc, ours)
    ours = ours.convert("RGB")
    x0, y0, x1, y1 = [float(v) for v in a.ref_crop.split(",")]
    w, h = ref.size
    ref = ref.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    ref = ref.resize((256, int(256 * ref.size[1] / ref.size[0])))
    oh = int(256 * ours.size[1] / ours.size[0])
    ours = ours.resize((256, oh))
    if ours_alpha is not None:
        ours_alpha = ours_alpha.resize((256, oh))
    ri, rm = norm(ref, mask_of(ref, a.thr), a.size)
    oi, om = norm(ours, mask_of(ours, a.thr, ours_alpha), a.size)
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
    # Палітра — два числа, середнє яких і є «палітра»:
    #  • покриття: для кожного пікселя — відстань до найближчого кольору другої картинки (в обидва
    #    боки), 100% мінус середня (RGB 100 = 0%) — чи ті самі кольори взагалі є;
    #  • частки: 8 кольорів малюнка (k-середні), обидві картинки розкладені по них — перетин
    #    розподілів. Без нього один рожевий піксель «покривав» цілу рожеву стіну (рецензія 26.09).
    import random
    def samples(ip, mp, n=600):
        pts = [ip[x, y] for y in range(a.size) for x in range(a.size) if mp[x, y] > 127]
        random.seed(3)
        return random.sample(pts, min(n, len(pts)))
    sr, so = samples(rip, rmp), samples(oip, omp)
    def d2(c, e):
        return (c[0] - e[0]) ** 2 + (c[1] - e[1]) ** 2 + (c[2] - e[2]) ** 2
    def cover(src, dst):
        return max(0.0, 100.0 - sum(min(d2(c, e) for e in dst) ** 0.5 for c in src) / max(len(src), 1))
    coverage = (cover(sr, so) + cover(so, sr)) / 2
    random.seed(5)
    cent = random.sample(sr, min(8, len(sr)))
    for _ in range(12):
        groups = [[] for _ in cent]
        for c in sr:
            groups[min(range(len(cent)), key=lambda i: d2(c, cent[i]))].append(c)
        cent = [tuple(sum(q[j] for q in g) / len(g) for j in range(3)) if g else cent[i] for i, g in enumerate(groups)]
    def dist(src):
        hst = [0] * len(cent)
        for c in src:
            hst[min(range(len(cent)), key=lambda i: d2(c, cent[i]))] += 1
        return [v / max(len(src), 1) for v in hst]
    shares = 100.0 * sum(min(x, y) for x, y in zip(dist(sr), dist(so)))
    # Частки важать утричі більше за покриття: покриття ≈ 90-100%, щойно колір є хоч цяткою, і
    # «рожева стіна з сірою цяткою» проти «сірої з рожевою» проходила поріг (рецензія 26.09).
    palette = 0.25 * coverage + 0.75 * shares
    # «Разом» — гармонійне середнє силуету й палітри: погане одне число не перекривається
    # гарним іншим (з простим середнім і «силует 13% / палітра 97%», і «100% / 9%» давали 55%).
    total = 2 * shape * palette / max(shape + palette, 1e-9)
    print("силует %.0f%%  палітра %.0f%%  колір на місці %.0f%%  разом %.0f%%"
          % (shape, palette, color, total))


if __name__ == "__main__":
    main()
