#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_textures_sync.py — чи сітка й текстура кожної моделі з ОДНОГО запікання.

    python3 tools/check_textures_sync.py        # ненульовий код виходу, якщо є розбіжність

Навіщо. Запікання (`prop_bake.py`) кладе текстури ВСЕРЕДИНУ `.glb`, а Godot при імпорті
видобуває їх у файли поруч. Тобто на диску лежать дві копії тієї самої картинки, і вони
мусять збігатися. Якщо не збігаються — модель малюється чужою текстурою: нова розгортка UV
поверх старого атласу дає шмаття, дірки й клапті на випадкових місцях.

Сталось це 20.09.2026 не на диску, а в редакторі (він тримав стару сітку в пам'яті, поки
файли вже змінились), але симптом той самий, і відрізнити одне від одного оком неможливо.
Ця перевірка відповідає на питання однозначно: диск у порядку чи ні.

Звіряємо за ТОЧНОЮ назвою `<модель>_<картинка>`, а не входженням підрядка: «house_terra» є
початком «house_terra_4», і глоб радо підсовує чужий файл. На цій самій пастці вже горіло
`KEEP_FULL_SIZE` у `tools/textures_vram.py`.
"""
import glob
import hashlib
import json
import os
import struct
import sys

EXTS = (".jpg", ".png")


def embedded(path):
    """Картинки, вбудовані в .glb: [(ім'я, байти)]."""
    d = open(path, "rb").read()
    if d[:4] != b"glTF":
        return []
    jl = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20:20 + jl])
    off, bin_start = 20 + jl, None
    while off < len(d):
        blen, btype = struct.unpack("<II", d[off:off + 8])
        if btype == 0x004E4942:          # "BIN"
            bin_start = off + 8
            break
        off += 8 + blen
    if bin_start is None:
        return []
    out = []
    for img in j.get("images", []):
        if "bufferView" not in img:
            continue
        bv = j["bufferViews"][img["bufferView"]]
        s = bin_start + bv.get("byteOffset", 0)
        out.append((img.get("name", "?"), d[s:s + bv["byteLength"]]))
    return out


def main():
    bad, missing, checked = [], [], 0
    for g in sorted(glob.glob("assets/props/*.glb")):
        base = os.path.basename(g)[:-4]
        for name, data in embedded(g):
            stem = "assets/props/%s_%s" % (base, name.split(".")[0])
            found = next((stem + e for e in EXTS if os.path.exists(stem + e)), None)
            if found is None:
                missing.append("%s → %s(%s)" % (base, os.path.basename(stem), "/".join(EXTS)))
                continue
            checked += 1
            if hashlib.md5(open(found, "rb").read()).hexdigest() != hashlib.md5(data).hexdigest():
                bad.append("%s: %s не той, що всередині .glb" % (base, os.path.basename(found)))

    print("звірено пар «вбудована картинка ↔ файл на диску»: %d" % checked)
    for m in missing:
        print("  файлу нема: %s" % m)
    for b in bad:
        print("  РОЗБІЖНІСТЬ: %s" % b)
    if not bad and not missing:
        print("усе сходиться — сітка й текстура кожної моделі з одного запікання")
    sys.exit(1 if bad else 0)


main()
