#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""mesh_smooth_uv.py — розгладити ділянку меша, задану рамкою в ТЕКСТУРІ (Blender headless).

Навіщо. Meshy іноді ліпить очі просто в геометрію: на голові стирчать опуклі кулі з
райдужкою. Наша накладка обличчя малює своє око поверх — і та опуклість визирає крізь нього.
Прибрати її вручну в 3D-редакторі довго й неточно, а «на око» не зрозуміло, які саме вершини
чіпати.

Ідея: ділянку задаємо НЕ в просторі, а в UV — прямокутником на самій текстурі, де ця деталь
намальована. Рамку видно очима (або її знаходить пошук темних плям), і вона однозначна.
Далі вершини, чиї UV потрапили в рамку, розслабляються лапласіаном: кожна йде в середнє
сусідів, а межа (вершини поза рамкою) лишається на місці. Опуклість осідає в поверхню
голови сама, шви й UV не рухаються.

Запуск (з кореня games/mgp-01-run):

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/mesh_smooth_uv.py -- \
        --in ~/Downloads/fox_meshy.glb --out assets/models/fox_meshy_noeyes.glb \
        --uv-box 736 1579 861 1688 --uv-box 735 1875 859 1982 \
        --tex-size 2048 --pad 6 --iters 60

`--uv-box x1 y1 x2 y2` — рамка в ПІКСЕЛЯХ текстури (як її видно у графічному редакторі),
можна кілька. `--pad` розширює рамку на N пікселів, щоб захопити край опуклості.
`--iters` — скільки разів розслабляти (більше = гладкіше, але й більше «втягує» сусідів).
`--dry-run` — лише порахувати, скільки вершин потрапило, і нічого не писати.
"""
import argparse
import os
import sys

import bpy
import bmesh
import mathutils


def parse_args(argv):
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", dest="dst", default="")
    ap.add_argument("--uv-box", dest="boxes", nargs=4, type=float, action="append", required=True)
    ap.add_argument("--tex-size", dest="tex", type=float, default=2048.0)
    ap.add_argument("--pad", type=float, default=6.0)
    ap.add_argument("--iters", type=int, default=12,
                    help="скільки разів згладити ШОВ після посадки на сферу (не для самого "
                         "вирівнювання: чистий лапласіан робить мінімальну поверхню, тобто "
                         "ПЛАСКУ, і на опуклій голові лишає вм'ятину)")
    ap.add_argument("--tex-replace", dest="tex_new", default="",
                    help="підмінити базову текстуру моделі цим файлом (напр. із замальованими очима)")
    ap.add_argument("--normal-replace", dest="nrm_new", default="",
                    help="підмінити normal map: рельєф деталі буває запечений і в ній, і тоді "
                         "на розгладженій голові лишаються бліді «привиди»")
    ap.add_argument("--rough-replace", dest="rgh_new", default="",
                    help="підмінити metallic/roughness: деталь буває помітна ще й різним "
                         "блиском, і тоді на розгладженій поверхні лишається тонкий контур")
    ap.add_argument("--max-move", type=float, default=0.012,
                    help="СТЕЛЯ зсуву однієї вершини, м. Головний запобіжник: меш Meshy — це "
                         "десятки окремих панелей, і великий зсув біля стику рве шов. Спершу "
                         "зміряй рельєф деталі й постав стелю трохи більшою за нього.")
    ap.add_argument("--fit-sphere", action="store_true",
                    help="садити ділянку на сферу, підігнану по її межі. Типово ВИМКНЕНО: на "
                         "пласкій панелі сфера жолобить поверхню дужче, ніж вирівнює.")
    ap.add_argument("--no-geometry", action="store_true",
                    help="НЕ чіпати меш узагалі — лише підмінити карти. Майже завжди саме це й "
                         "потрібно: у Meshy-моделях «опуклість» деталі зазвичай не геометрія, "
                         "а normal map. Спершу зміряй місцевий виступ, і якщо він міліметровий — "
                         "бери цей режим, бо різати меш із багатьох окремих панелей означає рвати шви.")
    ap.add_argument("--dry-run", action="store_true")
    return ap.parse_args(argv)


## Метод найменших квадратів: |v|^2 = 2c.v + (r^2 - |c|^2) — лінійно щодо (c, r^2-|c|^2).
def _fit_sphere(points):
    n = len(points)
    if n < 4:
        return mathutils.Vector((0, 0, 0)), 0.0
    ata = [[0.0] * 4 for _ in range(4)]
    atb = [0.0] * 4
    for p in points:
        row = [p.x, p.y, p.z, 1.0]
        rhs = p.x * p.x + p.y * p.y + p.z * p.z
        for i in range(4):
            atb[i] += row[i] * rhs
            for j in range(4):
                ata[i][j] += row[i] * row[j]
    m = mathutils.Matrix(ata)
    try:
        x = m.inverted() @ mathutils.Vector(atb)
    except ValueError:
        return mathutils.Vector((0, 0, 0)), 0.0
    centre = mathutils.Vector((x[0] * 0.5, x[1] * 0.5, x[2] * 0.5))
    r2 = x[3] + centre.length_squared
    return centre, (r2 ** 0.5 if r2 > 0.0 else 0.0)


def main():
    a = parse_args(sys.argv)
    src = os.path.expanduser(a.src)
    print("mesh_smooth_uv: %s (Blender %s)" % (src, bpy.app.version_string))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)

    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("у файлі нема мешів")

    # рамки з пікселів у UV (0..1). У glTF V іде згори вниз, у Blender — знизу вгору.
    boxes = []
    for x1, y1, x2, y2 in a.boxes:
        boxes.append((
            (min(x1, x2) - a.pad) / a.tex,
            1.0 - (max(y1, y2) + a.pad) / a.tex,
            (max(x1, x2) + a.pad) / a.tex,
            1.0 - (min(y1, y2) - a.pad) / a.tex,
        ))
    for b in boxes:
        print("  рамка UV: u %.4f..%.4f  v %.4f..%.4f" % (b[0], b[2], b[1], b[3]))

    total = 0
    for obj in meshes:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        uv_layer = bm.loops.layers.uv.active
        if uv_layer is None:
            print("  %s: нема UV — пропускаю" % obj.name)
            bm.free()
            continue

        # вершина потрапляє в ділянку, якщо ХОЧ ОДИН її loop лежить у рамці
        inside = set()
        for face in bm.faces:
            for loop in face.loops:
                u, v = loop[uv_layer].uv
                for u1, v1, u2, v2 in boxes:
                    if u1 <= u <= u2 and v1 <= v <= v2:
                        inside.add(loop.vert.index)
                        break
        print("  %s: вершин у ділянці %d із %d" % (obj.name, len(inside), len(bm.verts)))
        total += len(inside)
        if a.no_geometry:
            bm.free()
            continue
        if a.dry_run or not inside:
            bm.free()
            continue

        orig = {i: bm.verts[i].co.copy() for i in inside}

        # 1) посадка на СФЕРУ, підігнану по межі ділянки. Голова опукла, тож вирівнювати
        #    треба не в площину, а по її ж кривині — інакше на місці деталі лишається
        #    помітна вм'ятина (перевірено: чистий лапласіан саме її й давав).
        border = set()
        for idx in inside:
            for e in bm.verts[idx].link_edges:
                other = e.other_vert(bm.verts[idx])
                if other.index not in inside:
                    border.add(other.index)
        if a.fit_sphere and len(border) >= 8:
            centre, radius = _fit_sphere([bm.verts[i].co for i in border])
            if radius > 0.0:
                for idx in inside:
                    v = bm.verts[idx]
                    d = v.co - centre
                    if d.length > 1e-9:
                        v.co = centre + d.normalized() * radius
                print("    посаджено на сферу r=%.4f (межа %d вершин)" % (radius, len(border)))

        # 2) лапласіан — лише щоб згладити шов між посадженою ділянкою й рештою голови
        for _ in range(a.iters):
            moved = {}
            for idx in inside:
                v = bm.verts[idx]
                nbrs = [e.other_vert(v) for e in v.link_edges]
                if not nbrs:
                    continue
                acc = nbrs[0].co.copy()
                for n in nbrs[1:]:
                    acc += n.co
                moved[idx] = acc / len(nbrs)
            for idx, co in moved.items():
                bm.verts[idx].co = co

        # стеля зсуву: жодна вершина не може поїхати далі, ніж дозволено. Без цього
        # вирівнювання одного разу зрушило вершини на 7,8 см при товщині панелі 23 см — і
        # порвало модель по швах між панелями.
        clipped = 0
        for idx in inside:
            v = bm.verts[idx]
            d = v.co - orig[idx]
            if d.length > a.max_move:
                v.co = orig[idx] + d.normalized() * a.max_move
                clipped += 1
        moved = max((bm.verts[i].co - orig[i]).length for i in inside) if inside else 0.0
        print("    зсув: максимум %.4f м (стеля %.3f, обрізано %d)" % (moved, a.max_move, clipped))

        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()

        # glTF привозить ВЛАСНІ нормалі (custom split normals). Вони описують стару форму —
        # і після розгладження геометрія вже пласка, а світло й далі малює купол: на голові
        # лишаються бліді «привиди» деталі. Скидаємо, хай рахуються з нової геометрії.
        try:
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
            obj.select_set(False)
            print("    власні нормалі скинуто")
        except RuntimeError as err:
            print("    (власних нормалей не було: %s)" % err)

    # підміна базової текстури: очі бувають не лише виліплені, а й намальовані — тоді
    # розгладити геометрію мало, намальоване око однаково просвічуватиме крізь накладку
    # Модель може приїхати БЕЗ матеріалів узагалі (експорт лише геометрії). Тоді підміняти
    # нема чого — матеріал треба створити, інакше текстура нікуди не ляже.
    if a.tex_new and not any(m.use_nodes for m in bpy.data.materials):
        mat = bpy.data.materials.new(name="Material_0")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        mat.node_tree.links.new(bsdf.inputs["Base Color"], tex.outputs["Color"])
        if a.nrm_new:
            nm = mat.node_tree.nodes.new("ShaderNodeNormalMap")
            ntex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            mat.node_tree.links.new(nm.inputs["Color"], ntex.outputs["Color"])
            mat.node_tree.links.new(bsdf.inputs["Normal"], nm.outputs["Normal"])
        if a.rgh_new:
            rtex = mat.node_tree.nodes.new("ShaderNodeTexImage")
            mat.node_tree.links.new(bsdf.inputs["Roughness"], rtex.outputs["Color"])
        for obj in meshes:
            obj.data.materials.clear()
            obj.data.materials.append(mat)
        print("  матеріалу не було — створено новий")

    if a.tex_new:
        tex_new = os.path.abspath(os.path.expanduser(a.tex_new))
        # саме ту картинку, що підключена в Base Color: «перша велика» — не годиться,
        # у Meshy-моделях першим лежить normal map, і підміна йшла в нікуди
        replaced = 0
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type != "BSDF_PRINCIPLED":
                    continue
                link = node.inputs["Base Color"].links
                if not link:
                    continue
                tex_node = link[0].from_node
                while tex_node.type != "TEX_IMAGE" and tex_node.inputs:
                    ins = [i for i in tex_node.inputs if i.links]
                    if not ins:
                        break
                    tex_node = ins[0].links[0].from_node
                if tex_node.type == "TEX_IMAGE":
                    was = tex_node.image.name if tex_node.image else "(порожньо)"
                    new_img = bpy.data.images.load(tex_new)
                    new_img.pack()
                    print("  базову текстуру %s підмінено на %s"
                        % (was, os.path.basename(tex_new)))
                    tex_node.image = new_img
                    replaced += 1
        if replaced == 0:
            print("  УВАГА: базової текстури не знайшов, підміну пропущено")

    if a.nrm_new:
        nrm_new = os.path.abspath(os.path.expanduser(a.nrm_new))
        done = 0
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type != "NORMAL_MAP":
                    continue
                link = node.inputs["Color"].links
                if not link or link[0].from_node.type != "TEX_IMAGE":
                    continue
                was_n = link[0].from_node.image.name if link[0].from_node.image else "(порожньо)"
                img = bpy.data.images.load(nrm_new)
                img.colorspace_settings.name = "Non-Color"
                img.pack()
                print("  normal map %s підмінено на %s" % (was_n, os.path.basename(nrm_new)))
                link[0].from_node.image = img
                done += 1
        if done == 0:
            print("  УВАГА: normal map не знайшов, підміну пропущено")

    if a.rgh_new:
        rgh_new = os.path.abspath(os.path.expanduser(a.rgh_new))
        done = 0
        for mat in bpy.data.materials:
            if not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type != "BSDF_PRINCIPLED":
                    continue
                for slot in ["Roughness", "Metallic"]:
                    links = node.inputs[slot].links
                    if not links:
                        continue
                    src_node = links[0].from_node
                    while src_node.type != "TEX_IMAGE" and src_node.inputs:
                        ins = [i for i in src_node.inputs if i.links]
                        if not ins:
                            break
                        src_node = ins[0].links[0].from_node
                    if src_node.type == "TEX_IMAGE":
                        was_r = src_node.image.name if src_node.image else "(порожньо)"
                        img = bpy.data.images.load(rgh_new)
                        img.colorspace_settings.name = "Non-Color"
                        img.pack()
                        print("  %s-карту %s підмінено на %s" % (slot, was_r, os.path.basename(rgh_new)))
                        src_node.image = img
                        done += 1
                        break
        if done == 0:
            print("  УВАГА: metallic/roughness не знайшов, підміну пропущено")

    if a.dry_run:
        print("  (--dry-run: нічого не записано, разом вершин %d)" % total)
        return
    if not a.dst:
        raise SystemExit("--out не заданий")
    dst = os.path.abspath(os.path.expanduser(a.dst))
    bpy.ops.export_scene.gltf(filepath=dst, export_format="GLB")
    print("  записано: %s" % dst)


main()
