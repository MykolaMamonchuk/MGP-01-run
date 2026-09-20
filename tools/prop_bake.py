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
import math
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
    # ПЕРЕВІРЕНО 20.09.2026 на house_terra_4, щоб не пробували вдруге: різниці між `after` і
    # `before` око не бачить, а `auto` ВІДЧУТНО ГІРШИЙ — черепиця перетворюється на ковбаски.
    # Тобто типове `after` і лишається; вибір тут для того, щоб це можна було переперевірити.
    ap.add_argument("--unwrap", default="smart", choices=["smart", "seams"],
                    help="як різати розгортку: smart — smart_project (як було, надійно), "
                         "seams — шви за кутом і кутова розгортка (менше островів, але на "
                         "частині моделей дає розтяг і втрату деталі, див. коментар)")
    ap.add_argument("--seam-angle", type=float, default=60.0,
                    help="різкіші за цей кут ребра стають швами. Більший кут — менше швів і "
                         "більші острови; 60° для твердотільної будівлі")
    ap.add_argument("--pack-margin", type=float, default=0.002,
                    help="проміжок між островами при пакуванні — ЧАСТКА ВСЬОГО АТЛАСУ, "
                         "не пікселі. Підібрано заміром на house_terra_4: 0.015 давало 1.6% "
                         "заповнення, 0.003 — 15.5%, 0.002 — 58.1%, 0.001 — 34.4%. Замалий "
                         "проміжок пускає сусідів один в одного на mip'ах, завеликий з'їдає "
                         "атлас полями: островів сотні, і кожен бере поле з обох боків")
    ap.add_argument("--smooth", default="after",
                    choices=["after", "before", "auto"],
                    help="коли й як згладжувати ціль: after — типово, before — згладити ДО "
                         "запікання, auto — за кутом (гірше, див. коментар)")
    ap.add_argument("--smooth-angle", type=float, default=35.0,
                    help="--smooth auto: різкіші за цей кут ребра лишаються гострими")
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


## Скільки проходів спрощення дозволено й на скільки може зсістись габарит. Одним проходом
## нижче 1% Blender не йде (ratio там працює ненадійно), тож кільком проходам бути; але кожен
## наступний прохід ріже вже спрощену сітку, і з якогось моменту він не спрощує, а ламає.
## СКІЛЬКИ ПРОХОДІВ — це питання ЯКОСТІ, а не лише ваги. Заміряно 20.09.2026 на
## house_terra_4 (вихідник 1 003 379 граней), метрика — найгірша ділянка `prop_similarity.py`:
##
##     6 000 граней   2 проходи   93.9%
##    10 000 граней   2 проходи   93.9%
##    11 000 граней   1 прохід    95.3%
##    12 000 граней   1 прохід    96.0%
##    15 000 граней   1 прохід    97.0%
##
## Стрибок на межі 10→11 тисяч — це не граней побільшало, а прохід став ОДИН: запобіжник
## `max(ratio, 0.01)` не дає спуститись нижче за 1% за раз, тож усе, що дрібніше за соту
## частину вихідника, ріжеться двічі, і другий раз їсть уже те, що лишилось від рельєфу.
##
## Практично: для моделі на мільйон граней «один прохід» починається з ~10 000, а стеля
## гри — 7 000 (tests/test_prop_budget.gd). Тобто будинки неминуче йдуть у два проходи, і
## 6 000 — найкраще, що з цього виходить. Якщо колись знадобиться більше, дешевше підняти
## стелю для КІЛЬКОХ найближчих до дороги будівель, ніж для всіх.
## Поля запікання в пікселях. 16 — нижня робоча межа для 1024; для 2048 краще 24–32.
BAKE_MARGIN = 24
MAX_PASSES = 4
SHRINK_LIMIT = 0.05


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
    # Спрощуємо ЗА КІЛЬКА ПРОХОДІВ, а не одним. Ratio модифікатора Blender нижче 1% працює
    # ненадійно, і тут стояв відповідний запобіжник — max(..., 0.01). На моделі з генератора
    # у 30 тисяч граней це було байдуже, але наступні прийшли по 425–627 тисяч, і той самий
    # запобіжник давав 4 835 граней замість замовлених 2 000 — тобто понад стелю
    # tests/test_prop_budget.gd (4 000). Кілька помірних проходів і форму бережуть краще за
    # один екстремальний.
    guard = 0
    box0 = bounds([dst])
    while len(dst.data.polygons) > tris and guard < MAX_PASSES:
        guard += 1
        before = len(dst.data.polygons)
        m = dst.modifiers.new("d", "DECIMATE")
        m.ratio = max(tris / float(before), 0.01)
        m.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=m.name)
        if len(dst.data.polygons) >= before:
            break        # спрощення вперлось у дно — далі проходи нічого не дадуть
    # ГАБАРИТ — найпростіша ознака того, що модель не спростилась, а схлопнулась. Без цієї
    # перевірки house_terra_2 (626 тис. граней) пройшов п'ять проходів і перетворився на чорну
    # скалку: схожість 12.9% замість 99%, а в консолі все виглядало нормально — «ціль: 616793
    # → 3732». Число граней про форму не каже нічого.
    box1 = bounds([dst])
    shrink = max((box0[1][i] - box0[0][i] - (box1[1][i] - box1[0][i]))
                 / max(box0[1][i] - box0[0][i], 1e-6) for i in range(3))
    print("  ціль: %d → %d граней (проходів: %d, габарит зсів на %.0f%%)"
          % (have, len(dst.data.polygons), guard, shrink * 100))
    if shrink > SHRINK_LIMIT:
        raise SystemExit(
            "модель не спрощується до %d граней: габарит зсівся на %.0f%% (межа %.0f%%) — "
            "форма схлопнулась, а не спростилась.\nВізьми більший --tris "
            "(tools/prop_budget_search.py підкаже найменший придатний) або --shape sphere, "
            "якщо це листяна форма з багатьох оболонок." % (tris, shrink * 100, SHRINK_LIMIT * 100))
    return dst


## НОВА РОЗГОРТКА — і це найважливіше місце всього інструмента.
##
## Було: `smart_project` на всю модель і більше нічого. Заміряно 21.09.2026 на house_terra_4:
## 1 460 островів, із них 619 однограневих (42%), і — головне — **зайнято лише 17,5% площі
## текстури**. Решта 82% — порожні поля між острівцями. Тобто карта 1024 працювала як ~450,
## і вся запечена деталь розчинялась у mipmap'ах ще до того, як будинок відійде на п'ять
## метрів. Саме тому модель зблизька в Blender виглядала пристойно, а в грі — мило.
##
## Стало: шви за кутом → кутова розгортка → ВИРІВНЯТИ МАСШТАБ островів → СПАКУВАТИ їх.
## Двох останніх кроків не було зовсім, а саме вони й прибирають порожнечу.
##
## `seams_by_angle` великий (60°) навмисно: у твердотільної будівлі різкі ребра — це кути
## стін, стики даху й межі оздоблення, тобто рівно ті лінії, по яких шов і має йти. Дрібніші
## згини лишаються всередині острова, і острів виходить великим.
def unwrap(dst, seam_angle, pack_margin, mode):
    select_only([dst], dst)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    if mode == "seams":
        # старі шви прибираємо: після спрощення вони вже не по тих ребрах
        bpy.ops.mesh.mark_seam(clear=True)
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.mesh.select_mode(type="EDGE")
        bpy.ops.mesh.edges_select_sharp(sharpness=math.radians(seam_angle))
        bpy.ops.mesh.mark_seam(clear=False)
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.uv.unwrap(method="ANGLE_BASED", margin=0.001)
    else:
        bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.0)
    # Вирівняти масштаб: без цього дрібні острови пакуються такими ж дрібними, і texel
    # density стіни й дверної ручки різниться в рази.
    bpy.ops.uv.select_all(action="SELECT")
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(margin=pack_margin, rotate=True)
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
    # Поля навколо островів. Без них на межі острова лишається колір фону, і на mip'ах він
    # затікає всередину — саме те, що видно як брудну облямівку кожної деталі.
    bake.margin = BAKE_MARGIN
    bake.margin_type = "ADJACENT_FACES"
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
    unwrap(dst, a.seam_angle, a.pack_margin, a.unwrap)

    color_img = new_image("baked_color", a.size, False)
    normal_img = new_image("baked_normal", a.size, True)
    mat, tex_c, tex_n = target_material(dst, color_img, normal_img)

    # ЗГЛАДЖУВАННЯ ДО ЗАПІКАННЯ. Карта нормалей — тангенційна: вона зберігає РІЗНИЦЮ між
    # поверхнею оригіналу й нормалями цілі. Якщо цілі змінити згладжування ПІСЛЯ запікання,
    # нормалі стануть іншими, а карта лишиться від старих — і рельєф поїде. Саме тому тут
    # є вибір, і саме тому "after" (як було) лишено окремим режимом, а не прибрано.
    if a.smooth == "before":
        select_only([dst], dst)
        bpy.ops.object.shade_smooth()
    elif a.smooth == "auto":
        select_only([dst], dst)
        bpy.ops.object.shade_auto_smooth(angle=math.radians(a.smooth_angle))
    bake_into(mat, tex_n, src, dst, "NORMAL", a.cage, a.samples)
    bake_into(mat, tex_c, src, dst, "DIFFUSE", a.cage, a.samples)

    # Джерело більше не потрібне — у файл іде лише ціль.
    bpy.data.objects.remove(src, do_unlink=True)
    fit_box([dst], a.box)
    origin_bottom([dst])
    select_only([dst], dst)
    if a.smooth == "after":
        bpy.ops.object.shade_smooth()

    dst_path = os.path.abspath(os.path.expanduser(a.out))
    # ТАНГЕНТИ. Карта нормалей тангенційна, тобто без тангентного базису вона нічого не
    # означає. Godot уміє порахувати його сам при імпорті, але це буде ІНШИЙ базис, ніж той,
    # у якому пекли, — і рельєф виходить слабшим або з дивними переходами. Експортуємо явно.
    bpy.ops.export_scene.gltf(filepath=dst_path, export_format="GLB",
                              export_image_format="JPEG", export_jpeg_quality=90,
                              export_tangents=True, export_normals=True)
    print("  записано: %s (%.2f МБ)" % (dst_path, os.path.getsize(dst_path) / 1e6))


main()
