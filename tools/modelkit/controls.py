#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Контрольні пари для tools/ref_similarity.py — щоб межі міри можна було перевірити, а не
вірити докстрінгу (рецензія 26.09: контролі не були збережені, числа не відтворювались).

    python3 tools/modelkit/controls.py

Кожна пара — синтетичні картинки й очікування: що міра МУСИТЬ розрізняти (форма, колір) і що
МУСИТЬ вважати однаковим (той самий об'єкт у JPEG, ґратка з прозорими клітинками). Падіння
очікування — код виходу 1.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

BG = (200, 220, 200)


def canvas(alpha=False):
    return Image.new("RGBA", (400, 400), (0, 0, 0, 0)) if alpha else Image.new("RGB", (400, 400), BG)


def rect(im, box, col):
    ImageDraw.Draw(im).rectangle(box, fill=col + ((255,) if im.mode == "RGBA" else ()))
    return im


def lattice(im, col):
    d = ImageDraw.Draw(im)
    c = col + ((255,) if im.mode == "RGBA" else ())
    for i in range(6):
        d.rectangle((100 + i * 40, 100, 106 + i * 40, 300), fill=c)
        d.rectangle((100, 100 + i * 40, 306, 106 + i * 40), fill=c)
    return im


def run(a, b):
    out = subprocess.run([sys.executable, "tools/ref_similarity.py", a, b], capture_output=True, text=True, check=True).stdout
    return {k: int(out.split(k)[1].split("%")[0]) for k in ("силует", "палітра", "разом")}


def main():
    t = tempfile.mkdtemp()
    p = lambda n: os.path.join(t, n)
    pink, grey = (230, 120, 160), (120, 120, 120)
    rect(canvas(), (70, 170, 330, 230), pink).save(p("wide.png"))
    rect(canvas(), (170, 70, 230, 330), pink).save(p("tall.png"))
    rect(canvas(), (70, 170, 330, 230), grey).save(p("wide_grey.png"))
    rect(rect(canvas(), (100, 100, 300, 300), pink), (180, 180, 220, 220), grey).save(p("pink_dot.png"))
    rect(rect(canvas(), (100, 100, 300, 300), grey), (180, 180, 220, 220), pink).save(p("grey_dot.png"))
    lattice(canvas(), (180, 120, 70)).save(p("lat_ref.png"))
    lattice(canvas(True), (180, 120, 70)).save(p("lat_ours.png"))
    rect(canvas(), (100, 100, 300, 300), pink).save(p("box.png"))
    Image.open(p("box.png")).save(p("box.jpg"), quality=75)
    cases = [
        ("різна форма (широкий / вузький)", "wide.png", "tall.png", lambda r: r["силует"] <= 30 and r["разом"] < 50),
        ("різний колір (рожевий / сірий)", "wide.png", "wide_grey.png", lambda r: r["палітра"] <= 20 and r["разом"] < 50),
        ("стіна не того кольору (рожева з сірою цяткою / навпаки)", "pink_dot.png", "grey_dot.png", lambda r: r["разом"] < 60),
        ("однакові", "wide.png", "wide.png", lambda r: r["разом"] >= 98),
        ("той самий об'єкт у JPEG", "box.png", "box.jpg", lambda r: r["разом"] >= 90),
        ("ґратка / ґратка з прозорими клітинками", "lat_ref.png", "lat_ours.png", lambda r: r["разом"] >= 90),
    ]
    bad = 0
    for name, a, b, ok in cases:
        r = run(p(a), p(b))
        good = ok(r)
        bad += not good
        print("%s %-58s силует %3d  палітра %3d  разом %3d" % ("✓" if good else "✗", name, r["силует"], r["палітра"], r["разом"]))
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
