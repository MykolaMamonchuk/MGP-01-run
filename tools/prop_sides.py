#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_sides.py — аркуш УСІХ пропсів із ЧОТИРЬОХ боків, із числом деталізації кожного.

Навіщо окремо від `prop_sheet.py`. Той знімає з одного ракурсу, і саме тому пропустив цілу
ваду: три будинки, згенеровані з однієї картинки-виду спереду, мають детальний ЛИШЕ фасад, а
з трьох інших боків у них гола стіна. На аркуші вони виглядали бездоганно. Побачив це
замовник — у грі, коли будинок став боком до дитини.

Число тут — **щільність країв усередині силуету**, у відсотках: скільки пікселів моделі лежать
на перепаді яскравості. Вікно, двері, віконниця, квіткова скринька — це краї; гола стіна їх не
має зовсім. Обрис моделі до рахунку не входить (сусіди пікселя мусять теж бути моделлю),
інакше вузький будинок здавався б детальнішим за широкий просто через довший контур.

Спершу тут стояла ПАЛІТРА — скільки різних кольорів видно з цього боку. Метрика виявилась
сліпа: згладжування й м'яка тінь дають сотні відтінків навіть на голій стіні, і всі чотири
боки показували те саме число.

Модель, у якої найбідніший бік має менше за `--ratio` (типово 0.6) від найбагатшого,
обводиться червоним і йде на ПОЧАТОК аркуша — щоб її було видно одразу.

Поріг 0.6 узято із заміру: у будинка, детального з усіх боків, боки дають 37 / 37 / 32 / 32%
країв (найгірший — 86% від найкращого), а в будинка, згенерованого з однієї картинки, —
19 / 19 / 8 / 8% (43%). Між цими числами й проходить межа. Це не вирок: у бочки чи каменя боки й мусять
бути однакові, а от у будинку така різниця означає, що ставити його можна лише фасадом до
камери — або в ряд, де сусід затуляє голий бік.

    python3 tools/prop_sides.py                       # усі → prop_sides.png
    python3 tools/prop_sides.py --only house          # лише ті, чиє ім'я містить «house»
    python3 tools/prop_sides.py --out docs/refs/prop_sides.png --cell 190

Запускати з кореня проєкту. Один запуск Blender на модель (чотири кадри за раз), тож повний
аркуш — кілька хвилин.
"""
import argparse
import glob
import os
import subprocess
import tempfile

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"
YAWS = [0, 90, 180, 270]
FONT = "assets/fonts/BalsamiqSans-Regular.ttf"


## Перепад яскравості, з якого починається «край», і розмір, до якого зменшуємо кадр перед
## заміром: на повному кадрі це мільйони ітерацій пітона без жодного виграшу в точності.
EDGE = 18
MEASURE = 240
## Нижче цієї деталізації відношення боків не має сенсу: у калюжі, каменя чи гуски країв
## 0.2–5% З УСІХ боків, і «найбідніший бік 24% від найкращого» там означає лише шум заміру,
## а не ваду. Такі моделі просто не мають поверхневої деталі ніде — і не мусять.
MIN_DETAIL = 6.0


def detail(im):
    """Відсоток пікселів моделі, що лежать на краї. Гола стіна — одиниці, фасад — десятки."""
    im = im.resize((MEASURE, MEASURE))
    px = im.load()
    gp = im.convert("L").load()
    bg = px[2, 2]

    def is_bg(c):
        return abs(c[0] - bg[0]) + abs(c[1] - bg[1]) + abs(c[2] - bg[2]) < 24

    inside = 0
    edges = 0
    for y in range(1, MEASURE - 1):
        for x in range(1, MEASURE - 1):
            if is_bg(px[x, y]):
                continue
            # Обрис не рахуємо: якщо поруч тло, перепад тут від силуету, а не від деталі.
            if is_bg(px[x - 1, y]) or is_bg(px[x + 1, y]) \
                    or is_bg(px[x, y - 1]) or is_bg(px[x, y + 1]):
                continue
            inside += 1
            if abs(gp[x + 1, y] - gp[x, y]) + abs(gp[x, y + 1] - gp[x, y]) > EDGE:
                edges += 1
    return 100.0 * edges / max(inside, 1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="prop_sides.png")
    ap.add_argument("--cell", type=int, default=190)
    ap.add_argument("--only", default="")
    ap.add_argument("--ratio", type=float, default=0.6)
    a = ap.parse_args()

    files = sorted(glob.glob("assets/props/*.glb"))
    if a.only:
        files = [f for f in files if a.only in os.path.basename(f)]
    if not files:
        raise SystemExit("моделей не знайдено — запускати з кореня проєкту")

    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype(FONT, 15) if os.path.exists(FONT) else ImageFont.load_default()
    tmp = tempfile.mkdtemp(prefix="sides_")
    rows = []
    for path in files:
        name = os.path.basename(path)[:-4]
        stem = os.path.join(tmp, name)
        subprocess.run([BLENDER, "--background", "--python", "tools/prop_render.py", "--",
                        path, stem + ".png", str(a.cell * 2), "--fit",
                        "--yaws", ",".join(str(y) for y in YAWS)],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        shots = ["%s_%d.png" % (stem, y) for y in YAWS]
        if not all(os.path.exists(s) for s in shots):
            print("  ПРОПУЩЕНО %s — знімки не зробились" % name)
            continue
        ims = [Image.open(s).convert("RGB") for s in shots]
        counts = [detail(i) for i in ims]
        worst = min(counts) / max(max(counts), 0.01)
        rows.append((name, ims, counts, worst))
        print("  %-24s країв %s   найбідніший бік %.0f%% від найкращого%s"
              % (name, " ".join("%5.1f%%" % c for c in counts), worst * 100,
                 "   ← ЛИШЕ З ОДНОГО БОКУ"
                 if (worst < a.ratio and max(counts) >= MIN_DETAIL) else ""))

    # Найпідозріліші згори, але моделі без деталі взагалі — у кінець: вони не проблема.
    rows.sort(key=lambda r: (r[3] if max(r[2]) >= MIN_DETAIL else 9.0, r[0]))
    label_h = 26
    sheet = Image.new("RGB", (a.cell * 4, (a.cell + label_h) * len(rows)), (248, 248, 248))
    draw = ImageDraw.Draw(sheet)
    for i, (name, ims, counts, worst) in enumerate(rows):
        y = i * (a.cell + label_h)
        for k, im in enumerate(ims):
            sheet.paste(im.resize((a.cell, a.cell)), (k * a.cell, y + label_h))
            draw.text((k * a.cell + 6, y + label_h + 4), "%d°  %.1f%% країв" % (YAWS[k], counts[k]),
                      fill=(70, 70, 70), font=font)
        bad = worst < a.ratio and max(counts) >= MIN_DETAIL
        draw.text((6, y + 5), "%s   ·   найбідніший бік %.0f%% від найкращого%s"
                  % (name, worst * 100, "   ← ЛИШЕ З ОДНОГО БОКУ" if bad else ""),
                  fill=(190, 30, 30) if bad else (20, 20, 20), font=font)
        if bad:
            draw.rectangle([1, y + label_h, a.cell * 4 - 2, y + label_h + a.cell - 1],
                           outline=(210, 40, 40), width=3)
    sheet.save(a.out)
    flagged = sum(1 for r in rows if r[3] < a.ratio and max(r[2]) >= MIN_DETAIL)
    print("аркуш: %s (%d моделей, лише з одного боку: %d)" % (a.out, len(rows), flagged))


main()
