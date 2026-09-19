#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""validate_chunks.py — перевірити описи чанків (`chunk.json`) ДО того, як вони поїдуть у гру.

Помилка в описі не падає й нічого не ламає одразу — вона стає МОВЧАЗНОЮ вадою: чанк, у якого
на певній складності немає жодного layout'а; перешкода, якої в цьому світі не існує; довжина,
за якої завантажувач не встигає підтягнути наступний чанк. Тому опис перевіряється окремо.

Що саме перевіряється — див. `src/run3d/chunk_descriptor.gd`. ЦЕЙ ФАЙЛ — ТОНКА ОБГОРТКА і
навмисно нічого не знає про правила: та сама перевірка сумісності потрібна ЗБИРАЧУ рівня, а
він працює всередині гри й python звідти не покличе. Два джерела правди тут коштували б рівно
того, заради чого валідатор і пишеться.

Запуск:
    python3 tools/validate_chunks.py
    GODOT=/шлях/до/Godot python3 tools/validate_chunks.py

Ненульовий код виходу — є помилки. Нічого не пише на диск.
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = "src/run3d/chunk_descriptor.gd"
DEFAULT_GODOT = "/Applications/Godot.app/Contents/MacOS/Godot"
# Рядок, з якого починається наш вихід: усе до нього — банер рушія й попередження імпорту.
MARK = "--- перевірка описів чанків ---"


def main() -> int:
    ap = argparse.ArgumentParser(description="перевірка описів чанків")
    ap.add_argument("--godot", default=os.environ.get("GODOT", DEFAULT_GODOT),
                    help="шлях до виконуваного Godot (godot не в PATH)")
    ap.add_argument("--root", default="",
                    help="шукати описи не в res://levels, а тут (для перевірки самого валідатора)")
    args = ap.parse_args()

    if not os.path.exists(args.godot):
        print("не знайдено Godot: %s (задай --godot або GODOT=)" % args.godot, file=sys.stderr)
        return 2

    env = dict(os.environ)
    if args.root:
        env["CHUNKS_ROOT"] = os.path.abspath(args.root)
    run = subprocess.run(
        [args.godot, "--headless", "--path", ROOT, "-s", SCRIPT],
        capture_output=True, text=True, env=env)
    lines = run.stdout.splitlines()
    if MARK in lines:
        lines = lines[lines.index(MARK) + 1:]
    for line in lines:
        print(line)
    if run.returncode not in (0, 1):
        sys.stderr.write(run.stderr)
        print("Godot завершився з кодом %d" % run.returncode, file=sys.stderr)
        return 2
    return run.returncode


if __name__ == "__main__":
    sys.exit(main())
