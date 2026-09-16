#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""shrink_gltf_textures.py — зменшити текстури всередині .glb, не чіпаючи більше нічого.

Навіщо. Заміряно накладкою профілювання (PERF=1): гра тримає **348 МБ текстур**, і це число
однакове на Лужку й у Місті — тобто платять за нього всі рівні однаково. Причина — герої:
карта шорсткості оленяти й черепахи має 4096×4096, альбедо єдинорога теж, решта по 2048.
Якщо порахувати всі разом, виходить ~619 МБ. На телефоні стільки відеопам'яті просто нема.

Герой займає на екрані телефона десь двісті точок. Альбедо 1024 для нього вже із запасом,
нормалі вистачає 512, а шорсткість у мальованого звірка майже стала — їй досить 256.

Чому НЕ Blender і не tools/prop_prepare.py. Герої — риговані, і hero_rig.gd нормалізує їх
за габаритами під час гри. Будь-який перепрогін через Blender переписує сітку, скелет і
анімації, тобто ризикує рівно тим, що працює. Тут натомість чиста хірургія: зображення
розпаковується, зменшується, пакується назад, а всі інші шматки буфера переносяться байт
у байт. Індекси bufferView не міняються, тож accessor'и (вершини, ваги, анімації) лишаються
чинними за визначенням.

Розмір вибирається за РОЛЛЮ карти в матеріалі (baseColor / normal / metallicRoughness /
emissive / occlusion), а не за назвою файлу: назви на кшталт «Image_0» ролі не кажуть.

Запуск:
    python3 tools/shrink_gltf_textures.py assets/models/*.glb
    python3 tools/shrink_gltf_textures.py --dry assets/models/unicorn_mesh.glb   # лише показати
"""
import argparse
import io
import json
import os
import struct
import sys

from PIL import Image

JSON_CHUNK = 0x4E4F534A
BIN_CHUNK = 0x004E4942

## Стеля розміру за роллю карти. Колір бачить око, тому йому найбільше; шорсткість і
## метал у мальованого звірка майже сталі, тому найменше.
LIMITS = {
    "baseColor": 1024,
    "emissive": 512,
    "normal": 512,
    "metallicRoughness": 256,
    "occlusion": 256,
    "?": 1024,          # роль не знайдена — беремо обережну стелю кольору
}


def read_glb(path):
    data = open(path, "rb").read()
    if data[:4] != b"glTF":
        raise SystemExit("%s — не GLB" % path)
    off, js, binary = 12, None, b""
    while off < len(data):
        ln, ty = struct.unpack_from("<II", data, off)
        chunk = data[off + 8:off + 8 + ln]
        if ty == JSON_CHUNK:
            js = json.loads(chunk.decode("utf-8"))
        elif ty == BIN_CHUNK:
            binary = chunk
        off += 8 + ln
    return js, binary


## Роль кожного зображення — з матеріалів. Одне зображення може стояти в кількох ролях;
## тоді беремо найбільшу стелю, щоб не зіпсувати ту, якій розмір потрібен.
def image_roles(js):
    textures = js.get("textures", [])
    roles = {}

    def mark(tex_info, role):
        if not tex_info:
            return
        idx = tex_info.get("index")
        if idx is None or idx >= len(textures):
            return
        src = textures[idx].get("source")
        if src is None:
            return
        # Одне зображення може стояти в кількох ролях — тоді лишаємо ту, якій потрібен
        # БІЛЬШИЙ розмір, щоб не зіпсувати ту, де око це побачить.
        if src not in roles or LIMITS[role] > LIMITS[roles[src]]:
            roles[src] = role

    for m in js.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        mark(pbr.get("baseColorTexture"), "baseColor")
        mark(pbr.get("metallicRoughnessTexture"), "metallicRoughness")
        mark(m.get("normalTexture"), "normal")
        mark(m.get("emissiveTexture"), "emissive")
        mark(m.get("occlusionTexture"), "occlusion")
    return roles


def shrink(path, dry=False):
    js, binary = read_glb(path)
    views = js.get("bufferViews", [])
    roles = image_roles(js)
    new_bytes = {}
    report = []

    for i, im in enumerate(js.get("images", [])):
        bv_index = im.get("bufferView")
        if bv_index is None:
            continue
        bv = views[bv_index]
        raw = binary[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]]
        img = Image.open(io.BytesIO(raw))
        role = roles.get(i, "?")
        limit = LIMITS[role]
        if max(img.size) <= limit:
            report.append("   %-22s %-18s %dx%d — лишаємо" % (
                im.get("name", "?")[:22], role, img.size[0], img.size[1]))
            continue
        was = img.size
        k = limit / float(max(img.size))
        img = img.resize((max(1, int(img.size[0] * k)), max(1, int(img.size[1] * k))),
                         Image.LANCZOS)
        buf = io.BytesIO()
        if im.get("mimeType") == "image/png" or img.mode in ("RGBA", "LA", "P"):
            img.save(buf, "PNG", optimize=True)
            im["mimeType"] = "image/png"
        else:
            img.save(buf, "JPEG", quality=92)
            im["mimeType"] = "image/jpeg"
        new_bytes[bv_index] = buf.getvalue()
        report.append("   %-22s %-18s %dx%d → %dx%d" % (
            im.get("name", "?")[:22], role, was[0], was[1], img.size[0], img.size[1]))

    print("%s" % path)
    for line in report:
        print(line)
    if dry or not new_bytes:
        if not new_bytes:
            print("   нічого зменшувати")
        return

    # Новий BIN: усі bufferView по порядку, замінені — новими байтами. Індекси не міняються,
    # тож accessor'и (вершини, ваги, анімації) лишаються чинними; міняються лише зсуви.
    out = bytearray()
    for idx, bv in enumerate(views):
        while len(out) % 4:
            out.append(0)
        if idx in new_bytes:
            blob = new_bytes[idx]
        else:
            o = bv.get("byteOffset", 0)
            blob = binary[o:o + bv["byteLength"]]
        bv["byteOffset"] = len(out)
        bv["byteLength"] = len(blob)
        out += blob
    while len(out) % 4:
        out.append(0)
    js["buffers"] = [{"byteLength": len(out)}]

    js_bytes = json.dumps(js, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    total = 12 + 8 + len(js_bytes) + 8 + len(out)
    with open(path, "wb") as f:
        f.write(b"glTF" + struct.pack("<II", 2, total))
        f.write(struct.pack("<II", len(js_bytes), JSON_CHUNK) + js_bytes)
        f.write(struct.pack("<II", len(out), BIN_CHUNK) + bytes(out))
    print("   записано: %.1f МБ" % (total / 1048576.0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--dry", action="store_true", help="лише показати, нічого не писати")
    a = ap.parse_args()
    for p in a.files:
        if os.path.exists(p):
            shrink(p, a.dry)


main()
