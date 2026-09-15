#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""project_texture.py — вдягнути модель у КОНЦЕПТ-КАРТИНКУ, з якої її згенерували (Blender headless).

Навіщо. Image-to-3D віддає меш без текстури, а картинка-джерело кольорова й уже містить
рівно ту палітру, яку ми хочемо. Замість малювати текстуру з нуля (чого генератор моделей
не робить, а ми не вміємо) — проєктуємо цю ж картинку на меш із того боку, з якого її знято.

Як це працює. Плоска (планарна) проєкція: UV кожної вершини — це її позиція у площині
екрана, нормована до габаритів моделі. Далі картинка вішається як базова текстура.

ЧЕСНЕ ОБМЕЖЕННЯ. Проєкція правильна лише з того боку, з якого дивилась камера. Протилежний
бік отримає ту саму картинку «наскрізь» — розмазану. Для пропсів, повз які біжать (ящик,
бочка, паркан), це зазвичай не видно; для чогось, що роздивляються з усіх боків, — видно.
Тому є `--mirror`: праву половину моделі фарбуємо дзеркалом лівої, що рятує симетричні речі.

Запуск:

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/project_texture.py -- \\
        --in ~/Downloads/crate.glb --image ~/Downloads/crate_concept.jpg \\
        --out assets/props/crate.glb --axis front

    --axis   front | back | left | right | top   (з якого боку знято картинку)
    --mirror дзеркалити по X: для симетричних пропсів прибирає розмазаний бік
    --fit    cover (типово, картинка заповнює габарит) | contain
    --vertex-colors  замість текстури запекти колір у ВЕРШИНИ (один матеріал, дружить
                     із MultiMesh-пачками; годиться для простих форм)
"""
import argparse
import os
import sys

import bpy
import bmesh


AXES = {
    # (горизонтальна вісь, вертикальна вісь, знак горизонталі)
    "front": ("x", "z", 1.0),
    "back": ("x", "z", -1.0),
    "right": ("y", "z", 1.0),
    "left": ("y", "z", -1.0),
    "top": ("x", "y", 1.0),
}


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--image", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--axis", default="front", choices=sorted(AXES.keys()))
    ap.add_argument("--mirror", action="store_true")
    ap.add_argument("--fit", default="cover", choices=["cover", "contain"])
    ap.add_argument("--vertex-colors", dest="vcol", action="store_true")
    ap.add_argument("--no-autocrop", dest="autocrop", action="store_false",
                    help="не шукати силует, підганяти меш до ВСІЄЇ картинки (майже завжди гірше)")
    return ap.parse_args(argv)


## Межі самого об'єкта на картинці. Без цього фон концепту (зазвичай рівний кольоровий)
## намалюється просто на моделі: габарит меша підганяється до всього кадру, а звірятко
## займає лише його середину. Фон шукаємо за кутами — він там майже завжди рівний.
def subject_box(img):
    import numpy as np
    w, h = img.size
    a = np.array(img.pixels[:], dtype="float32").reshape(h, w, 4)[:, :, :3]
    # Blender віддає пікселі ЛІНІЙНИМИ, а поріг підбирався по sRGB — без цього переводу
    # різниця виходить утричі меншою, і «силуетом» визнається весь кадр разом із фоном
    a = np.clip(a, 0.0, 1.0) ** (1.0 / 2.2)
    corners = np.concatenate([a[:8, :8].reshape(-1, 3), a[:8, -8:].reshape(-1, 3),
                              a[-8:, :8].reshape(-1, 3), a[-8:, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    mask = np.abs(a - bg).sum(axis=2) > 0.25
    ys, xs = np.nonzero(mask)
    if len(xs) < 50:
        return 0.0, 0.0, 1.0, 1.0
    pad = 0.01
    return (max(xs.min() / w - pad, 0.0), max(ys.min() / h - pad, 0.0),
            min(xs.max() / w + pad, 1.0), min(ys.max() / h + pad, 1.0))


def bounds(objs):
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for o in objs:
        for v in o.data.vertices:
            co = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], co[i])
                hi[i] = max(hi[i], co[i])
    return lo, hi


def main():
    a = parse_args(sys.argv)
    src = os.path.expanduser(a.src)
    img_path = os.path.abspath(os.path.expanduser(a.image))
    print("project_texture: %s + %s (Blender %s)" % (
        os.path.basename(src), os.path.basename(img_path), bpy.app.version_string))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("у файлі нема мешів")

    idx = {"x": 0, "y": 1, "z": 2}
    ha, va, hsign = AXES[a.axis]
    lo, hi = bounds(meshes)
    hw = max(hi[idx[ha]] - lo[idx[ha]], 1e-6)
    vh = max(hi[idx[va]] - lo[idx[va]], 1e-6)
    # cover: картинка квадратна, тож беремо БІЛЬШИЙ габарит, щоб модель улізла цілком
    side = max(hw, vh) if a.fit == "cover" else min(hw, vh)
    hc = (hi[idx[ha]] + lo[idx[ha]]) * 0.5
    vc = (hi[idx[va]] + lo[idx[va]]) * 0.5
    print("  габарит по %s=%.3f по %s=%.3f → сторона проєкції %.3f" % (ha, hw, va, vh, side))

    img = bpy.data.images.load(img_path)
    img.pack()
    if a.autocrop:
        bx0, by0, bx1, by1 = subject_box(img)
        print("  силует на картинці: x %.3f..%.3f  y %.3f..%.3f" % (bx0, bx1, by0, by1))
    else:
        bx0, by0, bx1, by1 = 0.0, 0.0, 1.0, 1.0
    pix = list(img.pixels) if a.vcol else None

    for obj in meshes:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()

        def uv_of(co):
            world = obj.matrix_world @ co
            h = world[idx[ha]]
            if a.mirror:
                h = hc + abs(h - hc)      # обидві половини беруть колір з однієї, «гарної»
            u = 0.5 + hsign * (h - hc) / side
            v = 0.5 + (world[idx[va]] - vc) / side
            # UV пікселів картинки рахуються знизу вгору, а рядки маски — згори вниз
            u = bx0 + u * (bx1 - bx0)
            v = (1.0 - by1) + v * (by1 - by0)
            return min(max(u, 0.0), 1.0), min(max(v, 0.0), 1.0)

        if a.vcol:
            layer = bm.loops.layers.color.get("Col") or bm.loops.layers.color.new("Col")
            w, h_px = img.size
            for face in bm.faces:
                for loop in face.loops:
                    u, v = uv_of(loop.vert.co)
                    x = min(int(u * (w - 1)), w - 1)
                    y = min(int(v * (h_px - 1)), h_px - 1)
                    o = (y * w + x) * 4
                    loop[layer] = (pix[o], pix[o + 1], pix[o + 2], 1.0)
        else:
            layer = bm.loops.layers.uv.verify()
            for face in bm.faces:
                for loop in face.loops:
                    loop[layer].uv = uv_of(loop.vert.co)

        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()

    mat = bpy.data.materials.new(name="Material_0")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.9
    if a.vcol:
        node = mat.node_tree.nodes.new("ShaderNodeVertexColor")
        node.layer_name = "Col"
        mat.node_tree.links.new(bsdf.inputs["Base Color"], node.outputs["Color"])
    else:
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = img
        mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(mat)

    dst = os.path.abspath(os.path.expanduser(a.out))
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
    print("  записано: %s (%s)" % (dst, "вершинні кольори" if a.vcol else "текстура-проєкція"))


main()
