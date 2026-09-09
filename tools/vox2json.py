#!/usr/bin/env python3
"""Зворотний імпорт: MagicaVoxel .vox -> data/voxels/<name>.json (формат VoxelBuilder).

Приклад:
    python3 tools/vox2json.py docs/refs/models/out/lys_ai.vox --name hero_head_lys_ai --size 0.075
    python3 tools/vox2json.py fox.vox --name fox --palette tools/palette_hero.json

--palette — файл {"символ": "#RRGGBB"}; кожен колір .vox лягає на найближчий символ
(щоб Hero3D міг підміняти кольори героя). Без нього символи роздаються автоматично
за частотою: a, b, c, ... і в палітру йдуть справжні кольори з файлу.

Осі й порядок рядків — як у voxelize.py: layers[y][z][x], z від переду (-Z) до заду (+Z).
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path

try:
    import numpy as np
except ImportError:  # pragma: no cover
    sys.exit("Потрібні залежності. Встанови їх:\n    pip3 install trimesh numpy")

sys.path.insert(0, str(Path(__file__).resolve().parent))
from voxelize import EMPTY, ROOT, hex_to_rgb, read_vox, rgb_to_hex, to_def  # noqa: E402

## Символи для авто-режиму: спершу ті, які Hero3D уміє підміняти.
AUTO_SYMBOLS = "odckitm" + "abefghjlnpqrsuvwxyz0123456789"


def nearest_symbol(rgb, palette: dict) -> str:
    """Найближчий символ палітри за евклідовою відстанню в RGB."""
    best, best_d = EMPTY, None
    for sym, hex_color in palette.items():
        pr, pg, pb = hex_to_rgb(hex_color)
        d = (rgb[0] - pr) ** 2 + (rgb[1] - pg) ** 2 + (rgb[2] - pb) ** 2
        if best_d is None or d < best_d:
            best, best_d = sym, d
    return best


def convert(grid: np.ndarray, vox_palette: list, palette: dict | None) -> tuple[np.ndarray, dict]:
    """-> (сітка символів [x, y, z], палітра для JSON)."""
    used = Counter(int(i) for i in grid.ravel() if i)
    if not used:
        sys.exit("[!] у .vox нема вокселів")
    sym = np.full(grid.shape, EMPTY, dtype="<U1")
    out_palette: dict = {}
    mapping: dict = {}
    for n, (idx, _count) in enumerate(used.most_common()):
        rgb = vox_palette[idx]
        if palette:
            s = nearest_symbol(rgb, palette)
            out_palette[s] = palette[s]
        else:
            if n >= len(AUTO_SYMBOLS):
                print(f"[!] кольорів більше за {len(AUTO_SYMBOLS)} — зайві пропускаю")
                break
            s = AUTO_SYMBOLS[n]
            out_palette[s] = rgb_to_hex(rgb)
        mapping[idx] = s
    for idx, s in mapping.items():
        sym[grid == idx] = s
    return sym, out_palette


def trim(sym: np.ndarray) -> np.ndarray:
    """Прибирає порожні поля: база на y = 0, центрування по x/z робить сам VoxelBuilder."""
    pts = np.argwhere(sym != EMPTY)
    lo, hi = pts.min(axis=0), pts.max(axis=0) + 1
    return sym[lo[0]:hi[0], lo[1]:hi[1], lo[2]:hi[2]]


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description="MagicaVoxel .vox -> JSON для VoxelBuilder")
    p.add_argument("vox", help="шлях до .vox")
    p.add_argument("--name", required=True, help="ім'я вокселя (файл <name>.json)")
    p.add_argument("--size", type=float, default=0.075, help="розмір вокселя, м")
    p.add_argument("--palette", default="", help="JSON {символ: #RRGGBB} — кольори лягають на найближчий")
    p.add_argument("--out", default="data/voxels", help="куди класти JSON")
    opts = p.parse_args(argv)

    path = Path(opts.vox)
    if not path.exists():
        path = ROOT / opts.vox
    if not path.exists():
        sys.exit(f"[!] нема файлу {opts.vox}")

    palette = None
    if opts.palette:
        pal_path = Path(opts.palette)
        if not pal_path.exists():
            pal_path = ROOT / opts.palette
        palette = json.loads(pal_path.read_text(encoding="utf-8"))

    grid, vox_palette = read_vox(path)
    sym, out_palette = convert(grid, vox_palette, palette)
    sym = trim(sym)

    out_dir = ROOT / opts.out if not Path(opts.out).is_absolute() else Path(opts.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{opts.name}.json"
    d = to_def(sym, opts.size, out_palette, f"Імпортовано tools/vox2json.py з {path.name}.")
    out_path.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    nx, ny, nz = sym.shape
    print(f"[+] {out_path}  ({nx}×{ny}×{nz}, символи: {''.join(sorted(out_palette))})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
