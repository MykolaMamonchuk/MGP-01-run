#!/usr/bin/env python3
"""Одноразова міграція: розкладає levels/level_XX.tscn на levels/level_XX/chunk_NN.tscn —
фіксовані відрізки CHUNK_LENGTH_M метрів (той самий поділ, яким користується
LevelChunkLoader.CHUNK_LENGTH_M у src/run3d/level_chunk_loader.gd; тримати числа однаковими).

Маркери (LevelMarker3D) лишаються АБСОЛЮТНИМИ за z — не переписуємо transform, лише
розкладаємо вузли по файлах-чанках за floor(z_m / CHUNK_LENGTH_M), де z_m = -position.z
(той самий знак, що й LevelTimeline.extract()). Оригінальний плаский level_XX.tscn НЕ
чіпаємо — LevelChunkLoader сам вибирає чанкований шлях, коли є папка levels/level_XX/,
і падає назад на плаский файл, коли її нема.

Запуск: python3 tools/split_level_chunks.py [--verify]
--verify: після запису кожного рівня звіряє, що сума записів по чанках (кількість
маркерів кожної ролі) збігається з кількістю в оригінальному плаский файлі — проста
перевірка без запуску самого Godot (LevelTimeline.extract() тут не викликаємо, рахуємо
вузли з тексту так само, як має вважати extract()).
"""
import re
import sys
import os

CHUNK_LENGTH_M = 150.0   # має збігатися з LevelChunkLoader.CHUNK_LENGTH_M
LEVELS_DIR = os.path.join(os.path.dirname(__file__), "..", "levels")

NODE_RE = re.compile(
    r'\[node name="([^"]+)" type="Node3D" parent="\." index="(\d+)"\]\n'
    r'((?:(?!\[node).)*)',
    re.DOTALL,
)
TRANSFORM_Z_RE = re.compile(r"transform = Transform3D\(([^)]+)\)")


def parse_markers(text: str):
    """[(name, prop_block_text, z_m), ...] у вихідному порядку файлу."""
    out = []
    for m in NODE_RE.finditer(text):
        name, _index, body = m.group(1), m.group(2), m.group(3)
        tm = TRANSFORM_Z_RE.search(body)
        if not tm:
            continue
        parts = [p.strip() for p in tm.group(1).split(",")]
        z = float(parts[11])
        z_m = -z
        out.append((name, body, z_m))
    return out


def chunk_index_of(z_m: float) -> int:
    return int(z_m // CHUNK_LENGTH_M)


def write_chunk(out_dir: str, index: int, markers) -> None:
    lines = []
    lines.append('[gd_scene load_steps=2 format=3]')
    lines.append('')
    lines.append('[ext_resource type="Script" path="res://src/run3d/level_marker_3d.gd" id="1"]')
    lines.append('')
    lines.append('[node name="LevelLayout" type="Node3D"]')
    lines.append('')
    for i, (name, body, _z) in enumerate(markers):
        lines.append('[node name="%s" type="Node3D" parent="." index="%d"]' % (name, i))
        lines.append(body.rstrip("\n"))
        lines.append('')
    path = os.path.join(out_dir, "chunk_%02d.tscn" % index)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines).rstrip("\n") + "\n")
    return path


def split_level(num: int, verify: bool) -> None:
    flat_path = os.path.join(LEVELS_DIR, "level_%02d.tscn" % num)
    if not os.path.exists(flat_path):
        return
    text = open(flat_path, encoding="utf-8").read()
    markers = parse_markers(text)
    if not markers:
        print("level %02d: жодного маркера — пропускаю" % num)
        return
    buckets = {}
    for name, body, z_m in markers:
        idx = chunk_index_of(z_m)
        buckets.setdefault(idx, []).append((name, body, z_m))

    out_dir = os.path.join(LEVELS_DIR, "level_%02d" % num)
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for idx in sorted(buckets.keys()):
        bucket = sorted(buckets[idx], key=lambda t: t[2])
        written.append(write_chunk(out_dir, idx, bucket))

    n_chunks = len(buckets)
    n_markers = len(markers)
    print("level %02d: %d маркерів -> %d чанків (%s)" % (num, n_markers, n_chunks, out_dir))

    if verify:
        total_written = sum(len(b) for b in buckets.values())
        assert total_written == n_markers, (
            "level %02d: %d маркерів у чанках, мало бути %d" % (num, total_written, n_markers)
        )
        # z_m кожного маркера справді належить своєму файлу
        for idx, bucket in buckets.items():
            lo, hi = idx * CHUNK_LENGTH_M, (idx + 1) * CHUNK_LENGTH_M
            for name, _body, z_m in bucket:
                assert lo <= z_m < hi, (
                    "level %02d: %s z_m=%.1f поза межами чанку %d [%.0f, %.0f)"
                    % (num, name, z_m, idx, lo, hi)
                )
        print("  verify OK")


def main() -> None:
    verify = "--verify" in sys.argv
    for num in range(1, 18):
        split_level(num, verify)


if __name__ == "__main__":
    main()
