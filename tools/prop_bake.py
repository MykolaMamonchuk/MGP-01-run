#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""prop_bake.py — ретопологія із запіканням: зробити з важкої моделі легку, не втративши вигляд.

Навіщо. Модель із генератора несе дрібний рельєф ГЕОМЕТРІЄЮ: у house_terra кожна черепичка —
окрема тонка оболонка, і разом вони дають 30 918 трикутників. Спрощення такий рельєф не
переживає: ребро черепички і є її силует, тож будь-яке схлопування його розплавляє (числа й
знімки — docs/tasks/house-retopo.md). MultiMesh, яким малюється весь декор, при цьому не вміє
LOD, тож відстань нічого не здешевлює.

Що робить цей інструмент. Рельєф переїздить із геометрії в ТЕКСТУРУ:
  1. з вихідної моделі робиться копія, зварюється по швах і спрощується до --tris — це ЦІЛЬ;
  2. цілі робиться нова UV-розгортка (smart project), бо стара після спрощення подерта;
  3. промені з цілі назовні влучають у ДЖЕРЕЛО (вихідну модель), і звідти забирається
     колір поверхні → базова текстура, і нахил поверхні → карта нормалей у дотичному просторі;
  4. ціль отримує ці дві текстури й експортується як .glb.
Далі світло малює черепицю на пласкому даху так, ніби вона є.

Запуск:
    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/prop_bake.py -- \\
        --in docs/refs/incoming/house_terra/house_terra_8.glb \\
        --out assets/props/house_terra.glb \\
        --tris 2000 --size 1024 --box 1.52x2.414x1.44

    --tris     скільки трикутників лишити в цілі (типово 2000)
    --size     сторона текстур, пікселів (типово 1024)
    --box      ШxВxГ у метрах — вписати результат у бокс, як у prop_prepare.py
    --cage     на скільки метрів відсувати промені назовні (типово 0.03). Замало — рельєф
               місцями не долетить і лишаться плями; забагато — у кадр промені наберуть
               сусідні деталі. Для будинку ~1,5 м заввишки 0.02–0.05 — робочий діапазон.
    --samples  семплів Cycles на запікання (типово 4; колір і нахил шуму майже не дають)
"""
import argparse
import os
import sys

import bpy


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--in", dest="src", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--tris", type=int, default=2000)
    ap.add_argument("--size", type=int, default=1024)
    ap.add_argument("--box", default="")
    ap.add_argument("--cage", type=float, default=0.03)
    ap.add_argument("--samples", type=int, default=4)
    ap.add_argument("--shape", default="decimate", choices=["decimate", "sphere"],
                    help="з чого робити ціль. decimate — спростити саму модель (типово). "
                         "sphere — взяти кулю й посадити кожну її вершину на справжню поверхню "
                         "оригіналу (промінь ззовні в центр). Друге потрібне для "
                         "форм із БАГАТЬОХ ОКРЕМИХ ОБОЛОНОК: у кущі кожен листочок сам по собі, "
                         "і схлопування впирається в дно (104 299 → 7 108 і далі нікуди), бо "
                         "оболонку не можна прибрати зовсім. Куля таких обмежень не має")
    ap.add_argument("--segments", type=int, default=20, help="--shape sphere: поділів по колу")
    ap.add_argument("--rings", type=int, default=10, help="--shape sphere: поділів по висоті")
    ap.add_argument("--shrink", type=float, default=0.92,
                    help="--shape sphere: наскільки підтиснути кулю всередину габаритів. "
                         "Промені запікання йдуть НАЗОВНІ, тож ціль мусить бути трохи меншою "
                         "за оригінал, інакше вони не долетять до поверхні й лишаться плями")
    return ap.parse_args(argv)


def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def bounds(objs):
    lo = [1e9] * 3
    hi = [-1e9] * 3
    for o in objs:
        for v in o.data.vertices:
            co = o.matrix_world @ v.co
            for i in range(3):
                lo[i] = min(lo[i], co[i])
                hi[i] = max(hi[i], co[i])
    return lo, hi


def select_only(objs, active=None):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = active if active is not None else (objs[0] if objs else None)


## ДЖЕРЕЛО — усе, що прийшло у файлі, злите в один об'єкт. Промені запікання стріляють саме
## в нього, тож дрібниці (комин, скриньки) мають бути там само, де й були.
def join_source():
    objs = meshes()
    select_only(objs, objs[0])
    if len(objs) > 1:
        bpy.ops.object.join()
    src = bpy.context.view_layer.objects.active
    src.name = "ДЖЕРЕЛО"
    return src


## ЦІЛЬ — копія джерела, зварена по швах і спрощена. Зварювання обов'язкове: glTF розщеплює
## вершину на кожному шві UV, і без нього спрощення рве оболонки на клапті.
## Ціль-ОБОЛОНКА для кулястих форм (кущ, крона). Беремо кулю з потрібною кількістю граней і
## САДИМО КОЖНУ ЇЇ ВЕРШИНУ на справжню поверхню оригіналу: з точки далеко зовні стріляємо
## променем у центр і беремо перше влучання.
##
## Чому не просто куля за габаритним боксом (так було спершу). Бокс куща 0,633 × 0,500 —
## куля виходила приплюснутою, оригінал же на око круглий, бо його силует тримає листя, а не
## бокс. Прилад це й показав: 57% схожості при вимозі 80%. З променями оболонка повторює
## справжній силует, і число піднімається туди, куди треба.
def make_shell_target(src, segments, rings, shrink):
    import mathutils
    lo, hi = bounds([src])
    c = mathutils.Vector([(lo[i] + hi[i]) * 0.5 for i in range(3)])
    span = max(hi[i] - lo[i] for i in range(3))
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=0.5)
    dst = bpy.context.view_layer.objects.active
    dst.name = "ЦІЛЬ"
    inv = src.matrix_world.inverted()
    hits = 0
    for v in dst.data.vertices:
        d = mathutils.Vector(v.co).normalized()
        start = c + d * span * 1.5
        ok, loc, _nrm, _idx = src.ray_cast(inv @ start, inv.to_3x3() @ (-d))
        if ok:
            v.co = c + (src.matrix_world @ loc - c) * shrink
            hits += 1
        else:
            # промінь нікуди не влучив (заглиблення в силуеті) — лишаємо точку на габаритах
            v.co = c + d * span * 0.5 * shrink
    dst.data.update()
    print("  ціль: оболонка %d×%d, %d граней (влучило променів: %d з %d)"
          % (segments, rings, len(dst.data.polygons), hits, len(dst.data.vertices)))
    return dst


def make_target(src, tris):
    select_only([src], src)
    bpy.ops.object.duplicate()
    dst = bpy.context.view_layer.objects.active
    dst.name = "ЦІЛЬ"
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.0005)
    bpy.ops.object.mode_set(mode="OBJECT")
    have = len(dst.data.polygons)
    if have > tris:
        m = dst.modifiers.new("d", "DECIMATE")
        m.ratio = max(tris / float(have), 0.01)
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
    print("  ціль: %d → %d граней" % (have, len(dst.data.polygons)))
    return dst


## Нова розгортка. Стара після спрощення подерта: її острівці різались по черепичках, яких
## уже нема. angle_limit великий — для твердотільної моделі це дає менше швів.
def unwrap(dst):
    select_only([dst], dst)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.005)
    bpy.ops.object.mode_set(mode="OBJECT")


def new_image(name, size, is_normal):
    img = bpy.data.images.new(name, size, size, alpha=False,
                              float_buffer=False, is_data=is_normal)
    if is_normal:
        img.generated_color = (0.5, 0.5, 1.0, 1.0)
    return img


## Матеріал цілі: базовий колір із запеченої картинки, нормаль — із своєї. Metallic 0 /
## roughness 1, як усі матеріали гри.
def target_material(dst, color_img, normal_img):
    mat = bpy.data.materials.new("Запечений")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = 0.0
    bsdf.inputs["Roughness"].default_value = 1.0

    tex_c = nt.nodes.new("ShaderNodeTexImage")
    tex_c.image = color_img
    nt.links.new(tex_c.outputs["Color"], bsdf.inputs["Base Color"])

    tex_n = nt.nodes.new("ShaderNodeTexImage")
    tex_n.image = normal_img
    tex_n.interpolation = "Linear"
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex_n.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])

    dst.data.materials.clear()
    dst.data.materials.append(mat)
    return mat, tex_c, tex_n


def bake_into(mat, node, src, dst, kind, cage, samples):
    """Запекти джерело в активний вузол-картинку цілі."""
    mat.node_tree.nodes.active = node
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    bake = scene.render.bake
    bake.use_selected_to_active = True
    bake.cage_extrusion = cage
    bake.max_ray_distance = cage * 2.0
    bake.use_clear = True
    if kind == "DIFFUSE":
        # Тільки ВЛАСНИЙ колір поверхні: без прямого й непрямого світла, інакше в текстуру
        # запечеться освітлення сцени, і в грі воно перемножиться на справжнє.
        bake.use_pass_direct = False
        bake.use_pass_indirect = False
        bake.use_pass_color = True
    select_only([src], dst)      # виділені — джерела, активний — ціль
    dst.select_set(True)
    bpy.ops.object.bake(type=kind)
    print("  запечено: %s" % kind)


def fit_box(objs, spec):
    if not spec:
        return
    parts = spec.lower().replace("×", "x").split("x")
    if len(parts) != 3:
        raise SystemExit("--box чекає ШxВxГ")
    want = [float(parts[0]), float(parts[1]), float(parts[2])]
    lo, hi = bounds(objs)
    size = [hi[i] - lo[i] for i in range(3)]
    # Blender після імпорту glTF тримає «вгору» по Z; бокс задано як Ш×В×Г = X×Y(вгору)×Z
    k = min(want[0] / max(size[0], 1e-6), want[1] / max(size[2], 1e-6), want[2] / max(size[1], 1e-6))
    for o in objs:
        for v in o.data.vertices:
            v.co *= k
        o.data.update()
    print("  бокс %.2f × %.2f → коефіцієнт %.3f" % (want[0], want[1], k))


## Початок координат — у НИЗ по центру: пропс у грі ставиться на землю.
def origin_bottom(objs):
    lo, hi = bounds(objs)
    cx = (lo[0] + hi[0]) * 0.5
    cy = (lo[1] + hi[1]) * 0.5
    for o in objs:
        for v in o.data.vertices:
            v.co.x -= cx
            v.co.y -= cy
            v.co.z -= lo[2]
        o.data.update()


def main():
    a = parse_args(sys.argv)
    src_path = os.path.abspath(os.path.expanduser(a.src))
    print("prop_bake: %s (Blender %s)" % (os.path.basename(src_path), bpy.app.version_string))

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src_path)
    if not meshes():
        raise SystemExit("у файлі нема мешів")

    src = join_source()
    print("  джерело: %d граней" % len(src.data.polygons))
    if a.shape == "sphere":
        dst = make_shell_target(src, a.segments, a.rings, a.shrink)
    else:
        dst = make_target(src, a.tris)
    unwrap(dst)

    color_img = new_image("baked_color", a.size, False)
    normal_img = new_image("baked_normal", a.size, True)
    mat, tex_c, tex_n = target_material(dst, color_img, normal_img)

    bake_into(mat, tex_n, src, dst, "NORMAL", a.cage, a.samples)
    bake_into(mat, tex_c, src, dst, "DIFFUSE", a.cage, a.samples)

    # Джерело більше не потрібне — у файл іде лише ціль.
    bpy.data.objects.remove(src, do_unlink=True)
    fit_box([dst], a.box)
    origin_bottom([dst])
    select_only([dst], dst)
    bpy.ops.object.shade_smooth()

    dst_path = os.path.abspath(os.path.expanduser(a.out))
    bpy.ops.export_scene.gltf(filepath=dst_path, export_format="GLB",
                              export_image_format="JPEG", export_jpeg_quality=90)
    print("  записано: %s (%.2f МБ)" % (dst_path, os.path.getsize(dst_path) / 1e6))


main()
