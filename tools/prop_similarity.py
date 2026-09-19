#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_similarity.py — наскільки оброблена модель схожа на оригінал, у відсотках.

Навіщо. Вимога замовника: усе, що ми запікаємо чи спрощуємо, мусить лишатись схожим на
оригінал МІНІМУМ на 80%. Оком це не міряється — 18.09.2026 так у гру поїхав зіпсований
настил містка, а потім виявилось, що в ринкового воза розсипані колеса.

Дві числа, і обидва потрібні:

  ЗАГАЛЬНА схожість — частка площі моделі, що НЕ змінилась помітно. Ділити на весь кадр не
  можна: паркан тонкий і займає близько відсотка знімка, тож навіть розірваний він дав би
  «99% кадру однакові». Знаменник — площа, яку модель закриває хоч на одному зі знімків.

  НАЙГІРША ДІЛЯНКА — те саме, але порахуване по клітинках сітки, і взяте найменше. Без нього
  дрібна, але важлива деталь гине непоміченою: у воза колесо займає кілька відсотків площі,
  тож його можна знищити цілком, а загальна схожість лишиться 95%.

    python3 tools/prop_similarity.py оригінал.glb оброблена.glb
    python3 tools/prop_similarity.py --tiles 8 --diff 30 a.glb b.glb
"""
import argparse
import os
import subprocess
import tempfile

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"


def render(path, out, size):
    # --fit обов'язковий: дві моделі однієї речі майже завжди мають різні габарити й початок
    # координат, і без нормалізації прилад міряв би кадрування, а не схожість.
    subprocess.run([BLENDER, "--background", "--python", "tools/prop_render.py", "--",
                    path, out, str(size), "--fit"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
    return os.path.exists(out)


def compare(img_a, img_b, tiles=6, diff=40, min_cover=0.02, view=64):
    """(схожість %, найгірша ділянка %). Більше — краще.

    Що саме міряємо і чому НЕ піксель у піксель. Запікання переносить дрібний візерунок на
    нову UV-розгортку, тож кожен листочок лягає на сусідній піксель. Око цього не бачить —
    для нього кущ той самий, — а піксельна різниця дає «57% схожості» й бракує роботу, яку
    приймати треба. Тому схожість складається з двох речей, які ОКО й бачить:

      СИЛУЕТ — наскільки збігаються обриси (перетин площ до об'єднання). Саме він ловить
      справжні поломки: розсипане колесо воза, порваний паркан, зім'ятий настил містка.

      КОЛІР — різниця кольору на розмірі, з якого річ видно в грі (view, типово 64 px:
      пропс на телефоні займає сотню пікселів, і дрібнота там усереднюється). Ловить те,
      що форму зберегло, а тон утратило.

    Підсумок — гірше з двох: річ схожа рівно настільки, наскільки схожа її найслабша риса.
    Найгірша ділянка рахується по клітинках сітки, щоб дрібна, але важлива деталь не згинула
    непоміченою: колесо займає кілька відсотків площі воза.
    """
    from PIL import Image
    import numpy as np
    ia = Image.open(img_a).convert("RGB")
    ib = Image.open(img_b).convert("RGB")
    big_a = np.asarray(ia, float)
    big_b = np.asarray(ib, float)
    bg = big_a[0, 0]
    mask_a = np.abs(big_a - bg).max(2) > 10
    mask_b = np.abs(big_b - bg).max(2) > 10
    union = (mask_a | mask_b).sum()
    if union == 0:
        return 0.0, 0.0
    silhouette = (mask_a & mask_b).sum() * 100.0 / union

    sa = np.asarray(ia.resize((view, view), Image.LANCZOS), float)
    sb = np.asarray(ib.resize((view, view), Image.LANCZOS), float)
    m = (np.abs(sa - bg).max(2) > 10) | (np.abs(sb - bg).max(2) > 10)
    if m.sum() == 0:
        return silhouette, silhouette
    changed = (np.abs(sa - sb).max(2) > diff) & m
    colour = 100.0 - changed.sum() * 100.0 / m.sum()

    overall = min(silhouette, colour)

    # найгірша ділянка — по силуету й по кольору окремо, береться гірше
    worst = 100.0
    th = max(1, view // tiles)
    for ty in range(tiles):
        for tx in range(tiles):
            sl = (slice(ty * th, (ty + 1) * th), slice(tx * th, (tx + 1) * th))
            mm = m[sl]
            if mm.sum() < max(8, int(th * th * min_cover)):
                continue
            worst = min(worst, 100.0 - changed[sl].sum() * 100.0 / mm.sum())
    tb = max(1, mask_a.shape[0] // tiles)
    for ty in range(tiles):
        for tx in range(tiles):
            sl = (slice(ty * tb, (ty + 1) * tb), slice(tx * tb, (tx + 1) * tb))
            u = (mask_a[sl] | mask_b[sl]).sum()
            if u < max(30, int(tb * tb * min_cover)):
                continue
            worst = min(worst, (mask_a[sl] & mask_b[sl]).sum() * 100.0 / u)
    return overall, worst


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("original")
    ap.add_argument("processed")
    ap.add_argument("--size", type=int, default=800)
    ap.add_argument("--tiles", type=int, default=6)
    ap.add_argument("--diff", type=int, default=40)
    ap.add_argument("--view", type=int, default=64,
                    help="на якому розмірі порівнювати колір (типово 64: пропс на телефоні "
                         "займає сотню пікселів, дрібнота там усереднюється)")
    a = ap.parse_args()
    tmp = tempfile.mkdtemp(prefix="sim_")
    ra = os.path.join(tmp, "a.png")
    rb = os.path.join(tmp, "b.png")
    if not render(a.original, ra, a.size) or not render(a.processed, rb, a.size):
        raise SystemExit("не вдалось зняти одну з моделей")
    overall, worst = compare(ra, rb, a.tiles, a.diff, view=a.view)
    print("%-34s схожість %5.1f%%   найгірша ділянка %5.1f%%%s"
          % (os.path.basename(a.processed), overall, worst,
             "" if overall >= 80.0 else "   ← НИЖЧЕ 80%"))


if __name__ == "__main__":
    main()
