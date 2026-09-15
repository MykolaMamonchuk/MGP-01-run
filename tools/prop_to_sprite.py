#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_to_sprite.py — зрізати пропс-модель у 2D-спрайт на кілька кілобайтів.

Навіщо. Ціль — мобільний додаток, а пакет із моделями важить 296 МБ: самі текстури
2048×2048 на кожен пропс. При цьому пропс у раннері проїжджає повз за секунду й займає на
екрані сотню пікселів. Уся та геометрія й текстури живуть заради кадру, який чесно
малюється картинкою на 3–6 КБ.

Два кроки, і другий важливіший за перший:
  1. рендер моделі В САМІЙ ГРІ (src/debug/prop_sprite.tscn) — так спрайт гарантовано має
     те саме освітлення, матеріал і кут, що й модель, яку він заміняє;
  2. палітра. PNG із мільйоном кольорів на мультяшному пропсі — марнотратство: реальних
     відтінків там десятки. 64 кольори дають ту саму картинку вп'ятеро легшою, і це не
     припущення — скрипт друкує обидва розміри.

Запуск:

    python3 tools/prop_to_sprite.py barrel_1 crate_1 bush_flower_1
    python3 tools/prop_to_sprite.py --all --size 128 --colors 64

Результат — assets/sprites/<ім'я>.png і рядок із розміром на кожен.
"""
import argparse
import glob
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
BUDGET = 9 * 1024          ## стеля на спрайт, байтів — вимога замовника під мобільний додаток


## Вихідні моделі тих пропсів, що вже стали спрайтами, лежать в assets/props/3d — вони
## потрібні лише щоб перемалювати спрайт, і в збірку не потрапляють (див. docs/build.md).
def source_of(name):
    for rel in ("assets/props/3d/%s.glb" % name, "assets/props/%s.glb" % name):
        if os.path.exists(os.path.join(ROOT, rel)):
            return "res://" + rel
    return None


def render(name, size, out_png):
    src = source_of(name)
    if src is None:
        return False
    env = dict(os.environ, PROP=src, OUT=out_png, SIZE=str(size))
    subprocess.run([GODOT, "res://src/debug/prop_sprite.tscn"], cwd=ROOT, env=env,
                   capture_output=True, timeout=300)
    return os.path.exists(out_png)


def shrink(png, colors):
    from PIL import Image
    import json
    im = Image.open(png).convert("RGBA")
    full_px = im.size[0]
    # Обрізаємо порожнечу: спрайт має щільно облягати силует, інакше половина пікселів
    # (і ваги) йде на прозоре тло.
    box = im.getbbox()
    if box:
        im = im.crop(box)
    q = im.quantize(colors=colors, method=Image.FASTOCTREE)
    q.save(png, optimize=True)

    # Перераховуємо розмір у метрах ПІСЛЯ обрізання: Godot знає, скільки метрів покривав
    # цілий кадр, а скільки лишилось — залежить від того, що ми відрізали. Пишемо поруч,
    # щоб гра брала точний розмір, а не вгадувала його з пропорцій.
    side = png[:-4] + ".json"
    if os.path.exists(side):
        meta = json.load(open(side, encoding="utf-8"))
        mpp = float(meta["span_m"]) / float(full_px)
        json.dump({"w_m": round(im.size[0] * mpp, 4), "h_m": round(im.size[1] * mpp, 4)},
                  open(side, "w", encoding="utf-8"))
    return im.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("names", nargs="*")
    ap.add_argument("--all", action="store_true", help="усі моделі з assets/props")
    ap.add_argument("--size", type=int, default=128)
    ap.add_argument("--colors", type=int, default=64)
    a = ap.parse_args()

    names = a.names
    if a.all:
        names = sorted(set(os.path.basename(p)[:-4]
                           for p in glob.glob(os.path.join(ROOT, "assets/props/*.glb"))
                           + glob.glob(os.path.join(ROOT, "assets/props/3d/*.glb"))))
    if not names:
        raise SystemExit("нема що робити: задай імена або --all")

    os.makedirs(os.path.join(ROOT, "assets/sprites"), exist_ok=True)
    over = []
    for n in names:
        out = os.path.join(ROOT, "assets/sprites", n + ".png")
        if not render(n, a.size, out):
            print("  %-16s НЕ ВИЙШЛО (модель не знайдено?)" % n)
            continue
        raw = os.path.getsize(out)
        w, h = shrink(out, a.colors)
        small = os.path.getsize(out)
        flag = ""
        if small > BUDGET:
            flag = "  <-- ПОНАД СТЕЛЮ %d КБ" % (BUDGET // 1024)
            over.append(n)
        print("  %-16s %d×%d  %6d Б → %5d Б (%.1f КБ)%s" % (n, w, h, raw, small, small / 1024.0, flag))

    if over:
        print("\nпонад стелю: %s — зменш --size або --colors" % ", ".join(over))
        sys.exit(1)


main()
