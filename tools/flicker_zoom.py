#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""flicker_zoom.py — показати МІСЦЯ, де два сусідні кадри різняться найсильніше, збільшено.

Навіщо. 17–18.09.2026 два дні шукали мерехтіння й не могли знайти. Причина одна: я міряв
кадр числами й жодного разу не подивився на самі пікселі. Щойно два сусідні кадри лягли
поруч у кропі 720×200 із двократним збільшенням — причина стала очевидна за секунди
(олівкова смужка полотна дороги, що визирала з-під трави через ряд).

Числа тут брешуть трьома способами, і всі три ми пройшли:
  - різниця по всьому кадру в РУСІ — це переважно сам рух (світ їде на 0,195 м за кадр);
  - класифікатор кольорів ловить не те (наше «коричневе» виявилось дорогою й парканом);
  - «нічого не змінюється на паузі» не означає «все гаразд»: z-fighting і різниця між рядами
    при нерухомій камері не проявляються взагалі.

Тому цей інструмент нічого не вирішує за людину. Він робить одне: РІЖЕ кадр на клітинки,
бере найбільш змінені й кладе їх поруч збільшеними, щоб на них можна було просто подивитись.

    python3 tools/flicker_zoom.py кадр400.png кадр401.png кадр402.png --out /tmp/zoom.png

ТРИ кадри, а не два. З двома інструмент показує найбільші зміни — а це просто рух: бочка,
паркан і дерево, що їдуть повз камеру. Мерехтіння відрізняється тим, що ВЕРТАЄТЬСЯ: піксель
змінився й став назад. Перевірити це можна лише за трьома кадрами поспіль.
"""
import argparse


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("first")
    ap.add_argument("second")
    ap.add_argument("third", nargs="?", default=None,
                    help="ТРЕТІЙ кадр. З ним шукається «змінилось і ПОВЕРНУЛОСЬ» — саме "
                         "цим мерехтіння й відрізняється від руху. Без нього — просто «змінилось», "
                         "і в топі опиняться бочки та паркан, що просто їдуть повз камеру")
    ap.add_argument("--out", default="flicker_zoom.png")
    ap.add_argument("--tiles", type=int, default=20, help="на скільки клітинок різати по ширині")
    ap.add_argument("--top", type=int, default=5, help="скільки найгірших місць показати")
    ap.add_argument("--zoom", type=int, default=2)
    ap.add_argument("--threshold", type=int, default=40,
                    help="наскільки має змінитись піксель, щоб його рахувати")
    a = ap.parse_args()

    from PIL import Image, ImageDraw
    import numpy as np

    first = Image.open(a.first).convert("RGB")
    second = Image.open(a.second).convert("RGB")
    if first.size != second.size:
        raise SystemExit("кадри різного розміру — порівнювати нічого")
    x = np.asarray(first, int)
    y = np.asarray(second, int)
    if a.third:
        # «змінилось і повернулось»: піксель відрізняється від обох сусідів, але перший і
        # третій кадри між собою СХОЖІ. Рух такого не дає — там піксель їде далі й не
        # вертається. Саме через відсутність цієї перевірки перша версія інструмента
        # показала бочку й паркан замість причини.
        z = np.asarray(Image.open(a.third).convert("RGB"), int)
        ab = np.abs(x - y).max(2)
        bc = np.abs(y - z).max(2)
        ac = np.abs(x - z).max(2)
        changed = (ab > a.threshold) & (bc > a.threshold) & (ac < a.threshold // 2)
    else:
        changed = np.abs(x - y).max(2) > a.threshold

    h, w = changed.shape
    tw = max(8, w // a.tiles)
    th = max(8, tw * 9 // 16)
    scored = []
    for ty in range(0, h - th, th):
        for tx in range(0, w - tw, tw):
            scored.append((int(changed[ty:ty + th, tx:tx + tw].sum()), tx, ty))
    scored.sort(reverse=True)

    picked = []
    for score, tx, ty in scored:
        if score <= 0:
            break
        # не показувати те саме місце двічі
        if any(abs(tx - px) < tw and abs(ty - py) < th for _, px, py in picked):
            continue
        picked.append((score, tx, ty))
        if len(picked) >= a.top:
            break
    if not picked:
        print("різниць вище порога немає")
        return

    z = a.zoom
    cell_w, cell_h = tw * z, th * z
    sheet = Image.new("RGB", (cell_w * len(picked), cell_h * 2 + 40), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((6, 4), "верхній ряд — перший кадр, нижній — другий; "
                      "місця відсортовані за величиною зміни", fill=(20, 20, 20))
    for i, (score, tx, ty) in enumerate(picked):
        box = (tx, ty, tx + tw, ty + th)
        for r, img in ((0, first), (1, second)):
            crop = img.crop(box).resize((cell_w, cell_h), Image.NEAREST)
            sheet.paste(crop, (i * cell_w, 22 + r * cell_h))
        draw.text((i * cell_w + 6, 22 + cell_h * 2 + 4),
                  "x=%d y=%d · змінено %d px" % (tx, ty, score), fill=(20, 20, 20))
        print("  місце %d: x=%d y=%d, змінено %d пікселів" % (i + 1, tx, ty, score))
    sheet.save(a.out)
    print("аркуш: %s" % a.out)


main()
