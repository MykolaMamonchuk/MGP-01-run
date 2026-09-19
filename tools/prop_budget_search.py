#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_budget_search.py — знайти НАЙМЕНШУ кількість граней, за якої модель ще не псується.

Навіщо. Спрощення ламає моделі по-різному й непередбачувано: паркан тримає 600 граней, а
бочка на 900 уже рве обручі, настил містка на 600 згортає грань і дістає темний клин.
Обирати цифру оком — значить щось пропустити: рівно так 18.09.2026 у гру поїхав зіпсований
місток, і побачив це замовник, а не я.

Як працює. Для кожної моделі:
  1. знімок оригіналу (tools/prop_render.py — фіксовані камера, світло, фон);
  2. по черзі, від найдешевшого бюджету до найдорожчого, модель спрощується
     (tools/prop_prepare.py --weld --tris N) і знімається тим самим ракурсом;
  3. рахується частка пікселів, що помітно змінились (|Δ| > 30);
  4. береться ПЕРШИЙ бюджет, де ця частка нижча за --max-diff.
Частка рахується від площі САМОЇ МОДЕЛІ, а не від кадру: інакше тонкі речі (паркан) проходять
будь-який поріг навіть розірваними.
Модель не переписується — інструмент лише каже число. Застосовує його людина.

    python3 tools/prop_budget_search.py assets/props/barrel_*.glb
    python3 tools/prop_budget_search.py --max-diff 0.5 --steps 600,900,1200 assets/props/crate_3.glb
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile

BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"


def blender(script, args):
    subprocess.run([BLENDER, "--background", "--python", script, "--"] + args,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)


def diff_percent(a, b):
    """Скільки відсотків ПЛОЩІ САМОЇ МОДЕЛІ змінилось помітно.

    Ділити на весь кадр не можна: паркан тонкий і займає близько відсотка знімка, тож навіть
    геть поламаний він дає «0,75% кадру» й проходить будь-який поріг. Саме так 18.09.2026
    метрика пропустила розірваний паркан, і побачило це вже око. Знаменник — площа, яку
    модель закриває хоч на одному зі знімків.
    """
    from PIL import Image
    import numpy as np
    x = np.asarray(Image.open(a).convert("RGB"), float)
    y = np.asarray(Image.open(b).convert("RGB"), float)
    bg = x[0, 0]                                  # кут знімка — завжди фон
    mask = (np.abs(x - bg).max(2) > 10) | (np.abs(y - bg).max(2) > 10)
    if mask.sum() == 0:
        return 100.0
    changed = (np.abs(x - y).max(2) > 30) & mask
    return float(changed.sum() * 100.0 / mask.sum())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--steps", default="600,900,1200,1500,1800,2400",
                    help="бюджети граней, які пробувати, від дешевшого")
    ap.add_argument("--max-diff", type=float, default=3.0,
                    help="скільки відсотків ПЛОЩІ МОДЕЛІ дозволено змінити (типово 3.0)")
    a = ap.parse_args()
    steps = [int(s) for s in a.steps.split(",")]

    tmp = tempfile.mkdtemp(prefix="budget_")
    try:
        print("%-20s %8s %8s %s" % ("модель", "було", "треба", "різниця"))
        for path in a.files:
            name = os.path.basename(path)[:-4]
            ref = os.path.join(tmp, name + "_ref.png")
            blender("tools/prop_render.py", [path, ref])
            picked = None
            for tris in steps:
                out_glb = os.path.join(tmp, "%s_%d.glb" % (name, tris))
                blender("tools/prop_prepare.py",
                        ["--in", path, "--out", out_glb, "--weld", "--tris", str(tris)])
                shot = os.path.join(tmp, "%s_%d.png" % (name, tris))
                blender("tools/prop_render.py", [out_glb, shot])
                d = diff_percent(ref, shot)
                if d <= a.max_diff:
                    picked = (tris, d)
                    break
            if picked is None:
                print("%-20s %8s %8s не знайдено — лишати як є" % (name, "", ""))
            else:
                print("%-20s %8s %8d %6.2f%%" % (name, "", picked[0], picked[1]))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


main()
