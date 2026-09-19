#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""frame_diff.py — наскільки два кадри гри різні, числом.

Навіщо. «Наче так само» — не відповідь. Після зміни імпорту текстур треба сказати, СКІЛЬКИ
пікселів кадру поїхало й НАСКІЛЬКИ, і мати з чим це порівняти: два прогони тієї самої збірки
теж дають ненульову різницю (жива гра, анімації, шум стиснення кадру). Тому міряти правку
можна лише поруч із контрольною парою.

    python3 tools/vram/frame_diff.py до/frame.png після/frame.png
    python3 tools/vram/frame_diff.py --thr 8 a.png b.png

Друкує частку пікселів, що відрізняються більше за поріг `--thr` (за максимумом по каналах),
середнє й найбільше відхилення. Поріг 4/255 — приблизно межа, за якою різницю видно оком на
рівному кольорі.
"""
import argparse

import numpy as np
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("a")
    ap.add_argument("b")
    ap.add_argument("--thr", type=int, default=4, help="поріг «пікселі різні», 0–255")
    args = ap.parse_args()

    a = np.asarray(Image.open(args.a).convert("RGB"), dtype=np.int16)
    b = np.asarray(Image.open(args.b).convert("RGB"), dtype=np.int16)
    if a.shape != b.shape:
        raise SystemExit("кадри різного розміру: %s проти %s" % (a.shape, b.shape))

    d = np.abs(a - b).max(axis=2)
    share = float((d > args.thr).mean()) * 100.0
    print("%-26s проти %-26s" % (args.a.split("/")[-2], args.b.split("/")[-2]))
    print("  різних пікселів (>%d): %6.3f%%   середнє відхилення %.3f   найбільше %d"
          % (args.thr, share, float(d.mean()), int(d.max())))


main()
