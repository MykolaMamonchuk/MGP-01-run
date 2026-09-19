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
    ap.add_argument("--trim-top", type=float, default=0.0,
                    help="відрізати верхню частку силуету (0..1) перед обгортанням. Концепт "
                         "малюють ЗВЕРХУ ПІД КУТОМ, тож верхівка картинки — це кришка-еліпс, "
                         "а не бік. Без відрізання вона лягає на бік моделі сірою кашею")
    ap.add_argument("--wrap", default="plane", choices=["plane", "cylinder"],
                    help="cylinder — обгорнути картинку НАВКОЛО вертикальної осі. Для бочок, "
                         "діжок, стовпів: плоска проєкція розмазує їм боки, бо там силует "
                         "загинається від камери, а обгортка лягає рівно")
    ap.add_argument("--vertex-colors", dest="vcol", action="store_true")
    ap.add_argument("--no-bleed", dest="bleed", action="store_false",
                    help="не розтягувати колір об'єкта на фон (тоді фон тече на невидимі боки)")
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


## Розтягнути колір об'єкта на фон. Проєкція неминуче зачіпає й ті боки, яких на картинці
## не видно, — і вони брали б колір ФОНУ: у концепту візка фон чорний, тож задній бік навісу
## виходив чорним. Кілька проходів «розмазування» замінюють фон найближчим кольором об'єкта,
## і невидимі боки отримують хоча б правдоподібний відтінок замість діри.
def bleed_background(img, passes=48):
    import numpy as np
    w, h = img.size
    a = np.array(img.pixels[:], dtype="float32").reshape(h, w, 4)
    rgb = a[:, :, :3]
    srgb = np.clip(rgb, 0.0, 1.0) ** (1.0 / 2.2)
    corners = np.concatenate([srgb[:8, :8].reshape(-1, 3), srgb[:8, -8:].reshape(-1, 3),
                              srgb[-8:, :8].reshape(-1, 3), srgb[-8:, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    known = np.abs(srgb - bg).sum(axis=2) > 0.25
    out = rgb.copy()
    out[~known] = 0.0
    for _ in range(passes):
        if known.all():
            break
        k = known.astype("float32")[..., None]
        acc = np.zeros_like(out)
        cnt = np.zeros((h, w, 1), dtype="float32")
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            acc += np.roll(out * k, (dy, dx), axis=(0, 1))
            cnt += np.roll(k, (dy, dx), axis=(0, 1))
        fill = (cnt[..., 0] > 0) & (~known)
        out[fill] = (acc[fill] / np.maximum(cnt[fill], 1e-6))
        known = known | fill
    a[:, :, :3] = out
    img.pixels[:] = a.reshape(-1).tolist()
    print("  фон розтягнуто на %d проходів" % passes)


## Вирізати силует в ОКРЕМУ картинку. Для обгортки це не косметика, а умова: інакше шов
## (грань, що перетинає кут ±180°) мусив би взяти UV з двох протилежних країв силуету, і
## між ними лягла б уся решта аркуша — фон. Коли ж силует і є вся картинка, координата за
## шов просто повторюється по колу, як і має бути в обгортці.
def crop_to_subject(img, box):
    bx0, by0, bx1, by1 = box
    w, h = img.size
    inset = (bx1 - bx0) * 0.06
    bx0, bx1 = bx0 + inset, bx1 - inset
    x0, x1 = int(bx0 * w), max(int(bx1 * w), int(bx0 * w) + 1)
    # subject_box міряє y ВІД ВЕРХУ, а pixels ідуть знизу вгору
    y0, y1 = int((1.0 - by1) * h), max(int((1.0 - by0) * h), int((1.0 - by1) * h) + 1)
    src = list(img.pixels)
    nw, nh = x1 - x0, y1 - y0
    out = bpy.data.images.new("subject", width=nw, height=nh, alpha=True)
    buf = [0.0] * (nw * nh * 4)
    for row in range(nh):
        a0 = ((y0 + row) * w + x0) * 4
        buf[row * nw * 4:(row + 1) * nw * 4] = src[a0:a0 + nw * 4]
    # Концепти приходять з ПРОЗОРИМ фоном, і та прозорість їде в текстуру: у грі крізь
    # бочку видно небо. Тут силует уже вирізано, тож альфа не несе жодної інформації —
    # гасимо її повністю, інакше модель буде дірява.
    for i in range(3, len(buf), 4):
        buf[i] = 1.0
    out.pixels = buf
    out.alpha_mode = "NONE"
    out.pack()
    print("  силует вирізано в окрему картинку: %d×%d" % (nw, nh))
    return out


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
        if a.bleed:
            bleed_background(img)
        print("  силует на картинці: x %.3f..%.3f  y %.3f..%.3f" % (bx0, bx1, by0, by1))
        if a.trim_top > 0.0:
            by0 = by0 + (by1 - by0) * a.trim_top      # by міряється ВІД ВЕРХУ
            print("  верх силуету відрізано на %.0f%% → y від %.3f" % (a.trim_top * 100.0, by0))
        if a.wrap == "cylinder":
            img = crop_to_subject(img, (bx0, by0, bx1, by1))
            bx0, by0, bx1, by1 = 0.0, 0.0, 1.0, 1.0
    else:
        bx0, by0, bx1, by1 = 0.0, 0.0, 1.0, 1.0
    pix = list(img.pixels) if a.vcol else None

    for obj in meshes:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()

        def uv_cyl(co):
            world = obj.matrix_world @ co
            import math
            ang = math.atan2(world[1], world[0])          # навколо вертикалі (Z у Blender)
            u = (ang / (2.0 * math.pi)) + 0.5
            v = (world[2] - lo[2]) / max(hi[2] - lo[2], 1e-6)
            return bx0 + u * (bx1 - bx0), (1.0 - by1) + v * (by1 - by0)

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
                if a.wrap == "cylinder":
                    uvs = [uv_cyl(loop.vert.co) for loop in face.loops]
                    us = [p[0] for p in uvs]
                    if (max(us) - min(us)) > 0.5:
                        # грань лежить на шві: її кути прийшли з протилежних країв картинки.
                        # Виводимо «малі» за 1.0 — далі спрацює повтор, і грань лишиться
                        # вузькою, замість розтягнутись на весь обхват.
                        uvs = [((u + 1.0) if u < 0.5 else u, v) for u, v in uvs]
                    nz = (obj.matrix_world.to_3x3() @ face.normal).normalized().z
                    if abs(nz) > 0.7:
                        # кришка й дно. У концепті їх не видно взагалі — бочку намальовано
                        # збоку, і найвищий рядок силуету це темний обруч. Взяти його
                        # означає чорну кришку, тож беремо колір із тіла бочки.
                        band = 0.80 if nz > 0.0 else 0.15
                        uvs = [(u, (1.0 - by1) + band * (by1 - by0)) for u, _ in uvs]
                    for loop, uv in zip(face.loops, uvs):
                        loop[layer].uv = uv
                else:
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
        tex.extension = "REPEAT" if a.wrap == "cylinder" else "EXTEND"
        mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
    for obj in meshes:
        obj.data.materials.clear()
        obj.data.materials.append(mat)

    dst = os.path.abspath(os.path.expanduser(a.out))
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
    print("  записано: %s (%s)" % (dst, "вершинні кольори" if a.vcol else "текстура-проєкція"))


main()
