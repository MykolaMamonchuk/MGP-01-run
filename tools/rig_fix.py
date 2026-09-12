#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""rig_fix.py — чистка Meshy-рига в Blender headless (Blender 4.x, bpy).

Прибирає «зайві» кістки (бічні пасма хвоста, аксесуари), які ВОЛОДІЮТЬ шкірою
сусідньої частини тіла, і віддає їхні ваги тій кістці, якій ця шкіра належить
насправді. Кістка й вертекс-група зникають із `.glb` — у грі про них більше
не треба знати (жодних `rig_bones.static`).

Запуск (з кореня games/mgp-01-run):

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/rig_fix.py -- \
        --in assets/models/unicorn.glb --out assets/models/unicorn.glb \
        --remove Bone_025 Bone_024 Bone_023 Bone_028 Bone_027 Bone_026 \
        --merge-into nearest-leg

Тільки подивитись дерево кісток і вершини на кожній (нічого не змінює):

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/rig_fix.py -- \
        --in assets/models/unicorn.glb --list

Що робить:
  1. читає `.glb` у порожню сцену;
  2. знаходить арматуру й усі скіновані меші;
  3. для кожної кістки зі `--remove` розкидає її ваги:
     `--merge-into nearest-leg` — кожна вершина йде до НАЙБЛИЖЧОЇ (за позою спокою,
        відстань до відрізка head→tail у СВІТОВИХ координатах) кістки із `--legs`;
     `--merge-into parent`      — до батька видаленої кістки;
  4. видаляє вертекс-групу й саму кістку (в edit mode; дітей, якщо є,
     перевішує на батька видаленої);
  5. нормалізує ваги на кожній вершині (сума = 1);
  6. експортує `.glb` (skins так, анімації ні, матеріали не потрібні — фарбуємо самі).

Якщо `--in` == `--out`, поруч спершу пишеться `<файл>.bak`.
"""

import argparse
import os
import shutil
import sys

import bpy

# Задні лапки єдинорога (обидва ланцюжки, від стегна до копитця).
DEFAULT_LEGS = [
    "Bone_008", "Bone_007", "Bone_006",  # ліва задня
    "Bone_011", "Bone_010", "Bone_009",  # права задня
]

EPS = 1e-6


# ---------------------------------------------------------------- аргументи

def parse_args(argv):
    if "--" in argv:
        argv = argv[argv.index("--") + 1:]
    else:
        argv = []
    p = argparse.ArgumentParser(
        prog="rig_fix.py",
        description="Прибрати зайві кістки з .glb і віддати їхні ваги сусідам.")
    p.add_argument("--in", dest="src", required=True, help="вхідний .glb")
    p.add_argument("--out", dest="dst", default=None,
                   help="вихідний .glb (типово = --in; тоді пишеться .bak)")
    p.add_argument("--remove", nargs="*", default=[],
                   help="імена кісток, які прибрати (без урахування регістру)")
    p.add_argument("--merge-into", dest="merge", default="nearest-leg",
                   choices=["nearest-leg", "parent"],
                   help="кому віддати ваги видаленої кістки")
    p.add_argument("--legs", nargs="*", default=list(DEFAULT_LEGS),
                   help="ланцюжки лапок для nearest-leg (типово задні лапки єдинорога)")
    p.add_argument("--list", dest="do_list", action="store_true",
                   help="лише надрукувати дерево кісток із вершинами; нічого не міняти")
    p.add_argument("--report", action="store_true",
                   help="друкувати вершини на кістку до і після")
    p.add_argument("--dry-run", action="store_true",
                   help="усе порахувати й надрукувати, але не писати файл")
    return p.parse_args(argv)


# ------------------------------------------------------------------- сцена

def load(src):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kw = dict(filepath=src, import_pack_images=True, bone_heuristic="TEMPERANCE")
    bpy.ops.import_scene.gltf(**_supported(bpy.ops.import_scene.gltf, kw))


def _supported(op, kwargs):
    """Викинути ключі, яких немає в цій версії Blender (оператори змінюються)."""
    try:
        known = set(op.get_rna_type().properties.keys())
    except Exception:
        return kwargs
    out, dropped = {}, []
    for k, v in kwargs.items():
        if k in known:
            out[k] = v
        else:
            dropped.append(k)
    if dropped:
        print("  [i] пропущено невідомі цій версії Blender опції: %s" % ", ".join(dropped))
    return out


def find_armature():
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if not arms:
        sys.exit("[!] у файлі немає арматури — це не ригнута модель")
    arms.sort(key=lambda o: len(o.data.bones), reverse=True)
    if len(arms) > 1:
        print("  [!] арматур кілька (%s) — беру найбільшу «%s»"
              % (", ".join(o.name for o in arms), arms[0].name))
    return arms[0]


def find_meshes(arm):
    """Меші, скіновані цією арматурою (модифікатор Armature або парент)."""
    out = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        skinned = any(m.type == "ARMATURE" and m.object == arm for m in o.modifiers)
        if skinned or o.parent == arm:
            out.append(o)
    if not out:
        sys.exit("[!] не знайшлось жодного меша, скінованого арматурою «%s»" % arm.name)
    return out


# ------------------------------------------------------- імена без регістру

def resolve(name, arm):
    """Ім'я кістки в моделі за нашим написанням (без регістру; терпить .001)."""
    want = name.strip().lower()
    names = [b.name for b in arm.data.bones]
    for n in names:
        if n.lower() == want:
            return n
    # імпортер gltf інколи додає суфікс-унікалізатор: Bone_025.001
    for n in names:
        base = n.lower().rsplit(".", 1)[0]
        if base == want:
            return n
    return None


def group_of(obj, bone_name):
    """Вертекс-група меша під цю кістку (без регістру), або None."""
    want = bone_name.lower()
    for vg in obj.vertex_groups:
        if vg.name.lower() == want:
            return vg
    return None


# ------------------------------------------------------------ вершини/ваги

def vert_counts(meshes, arm):
    """{ім'я кістки: (вершин із будь-якою вагою, вершин, де ця кістка головна)}."""
    any_w = {b.name: 0 for b in arm.data.bones}
    dom = {b.name: 0 for b in arm.data.bones}
    for obj in meshes:
        idx2name = {vg.index: vg.name for vg in obj.vertex_groups}
        for v in obj.data.vertices:
            best, best_w = None, 0.0
            for g in v.groups:
                n = idx2name.get(g.group)
                if n is None or g.weight <= EPS:
                    continue
                if n in any_w:
                    any_w[n] += 1
                if g.weight > best_w:
                    best, best_w = n, g.weight
            if best is not None and best in dom:
                dom[best] += 1
    return {n: (any_w[n], dom[n]) for n in any_w}


def seg_dist(p, a, b):
    ab = b - a
    L2 = ab.dot(ab)
    if L2 < EPS:
        return (p - a).length
    t = max(0.0, min(1.0, (p - a).dot(ab) / L2))
    return (p - (a + ab * t)).length


def bone_segment(arm, bone_name):
    """Відрізок кістки в позі спокою, у СВІТОВИХ координатах (масштаб 0.01 — не біда)."""
    b = arm.data.bones[bone_name]
    m = arm.matrix_world
    return m @ b.head_local, m @ b.tail_local


def normalise(obj):
    """Сума ваг на кожній вершині = 1 (вершини без ваг лишаємо як є)."""
    fixed = 0
    for v in obj.data.vertices:
        s = sum(g.weight for g in v.groups if g.weight > 0.0)
        if s <= EPS or abs(s - 1.0) < 1e-5:
            continue
        for g in v.groups:
            if g.weight > 0.0:
                g.weight = g.weight / s
        fixed += 1
    return fixed


# ------------------------------------------------------------------ дерево

def print_tree(arm, meshes):
    counts = vert_counts(meshes, arm)
    total = sum(len(o.data.vertices) for o in meshes)
    print("  арматура «%s», кісток %d, мешів %d (вершин %d), масштаб %s"
          % (arm.name, len(arm.data.bones), len(meshes), total,
             tuple(round(s, 4) for s in arm.matrix_world.to_scale())))
    print("  кістки (вершин з вагою / де кістка головна):")

    def walk(bone, depth):
        a, d = counts.get(bone.name, (0, 0))
        h = arm.matrix_world @ bone.head_local
        print("    %s%-16s  ваг %5d · головна %5d   голова (x %+.1f y %+.1f z %+.1f)"
              % ("  " * depth, bone.name, a, d, h.x, h.y, h.z))
        for c in bone.children:
            walk(c, depth + 1)

    for b in arm.data.bones:
        if b.parent is None:
            walk(b, 0)


# -------------------------------------------------------------------- дія

def merge_weights(arm, meshes, removed, legs, mode):
    """Розкидати ваги видалених кісток. Повертає скільки вершин переїхало."""
    # відрізки лапок рахуємо завжди: у режимі parent вони запасний план
    # для кістки без батька.
    leg_segments = []
    for name in legs:
        real = resolve(name, arm)
        if real is None:
            print("  [!] кістку лапки «%s» у моделі не знайдено — пропускаю" % name)
            continue
        leg_segments.append((real, ) + bone_segment(arm, real))
    if mode == "nearest-leg" and not leg_segments:
        sys.exit("[!] жодної кістки зі --legs немає в моделі; nearest-leg нема куди зливати")
    if leg_segments:
        print("  лапки для злиття: %s" % ", ".join(n for n, _, _ in leg_segments))

    moved_total = 0
    for obj in meshes:
        mw = obj.matrix_world
        per_target = {}
        for src_name in removed:
            vg = group_of(obj, src_name)
            if vg is None:
                continue
            # 1. зібрати ваги групи
            picked = []  # (vertex index, weight)
            for v in obj.data.vertices:
                for g in v.groups:
                    if g.group == vg.index and g.weight > EPS:
                        picked.append((v.index, g.weight))
                        break
            if not picked:
                print("  [i] %s: група «%s» порожня" % (obj.name, vg.name))
                continue

            # 2. кому віддати
            if mode == "parent":
                # батько теж може бути в --remove (ланцюжок пасма) — ідемо вгору
                # до першого предка, який лишається в моделі
                pb = arm.data.bones[src_name].parent
                while pb is not None and pb.name in removed:
                    pb = pb.parent
                if pb is None:
                    if not leg_segments:
                        sys.exit("[!] у кістки «%s» немає батька і нема --legs — "
                                 "нема кому віддати ваги" % src_name)
                    print("  [!] у кістки «%s» немає батька — ваги йдуть у nearest-leg"
                          % src_name)
                    target_for = None
                else:
                    target_for = lambda _vi, _pn=pb.name: _pn  # noqa: E731
            else:
                target_for = None

            for vi, w in picked:
                if target_for is not None:
                    tgt = target_for(vi)
                else:
                    p = mw @ obj.data.vertices[vi].co
                    tgt = min(leg_segments, key=lambda s: seg_dist(p, s[1], s[2]))[0]
                per_target.setdefault(tgt, []).append((vi, w))
                moved_total += 1

            print("  %s: «%s» — %d вершин переїхали" % (obj.name, vg.name, len(picked)))

        # 3. дописати ваги (ADD) і прибрати вихідні групи
        for tgt, items in per_target.items():
            dst = group_of(obj, tgt)
            if dst is None:
                dst = obj.vertex_groups.new(name=tgt)
                print("  %s: створив групу «%s»" % (obj.name, tgt))
            for vi, w in items:
                dst.add([vi], w, "ADD")

        for src_name in removed:
            vg = group_of(obj, src_name)
            if vg is not None:
                obj.vertex_groups.remove(vg)

        n = normalise(obj)
        print("  %s: нормалізовано %d вершин" % (obj.name, n))
    return moved_total


def delete_bones(arm, removed):
    """Видалити кістки в edit mode; дітей перевісити на батька видаленої."""
    if bpy.context.object is not None and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    arm.hide_set(False)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for name in removed:
        b = eb.get(name)
        if b is None:
            continue
        parent = b.parent
        for child in list(b.children):
            child.parent = parent
            child.use_connect = False
            if parent is not None:
                print("  дитину «%s» перевісив на «%s»" % (child.name, parent.name))
            else:
                print("  [!] дитина «%s» лишилась без батька" % child.name)
        eb.remove(b)
        print("  кістку «%s» видалено" % name)
    bpy.ops.object.mode_set(mode="OBJECT")


def export(dst):
    kw = dict(
        filepath=dst,
        export_format="GLB",
        export_skins=True,
        export_animations=False,
        export_apply=True,
        export_materials="NONE",
        export_yup=True,
        use_selection=False,
        export_cameras=False,
        export_lights=False,
    )
    bpy.ops.export_scene.gltf(**_supported(bpy.ops.export_scene.gltf, kw))


# -------------------------------------------------------------------- main

def main():
    args = parse_args(list(sys.argv))
    src = os.path.abspath(args.src)
    dst = os.path.abspath(args.dst or args.src)
    if not os.path.isfile(src):
        sys.exit("[!] немає файлу: %s" % src)

    print("rig_fix: %s (Blender %s)" % (src, bpy.app.version_string))
    load(src)
    arm = find_armature()
    meshes = find_meshes(arm)

    if args.do_list or not args.remove:
        print_tree(arm, meshes)
        if not args.remove:
            print("  (--remove не задано — нічого не змінюю)")
        return

    before = vert_counts(meshes, arm) if args.report else None

    # звести імена до тих, що справді є в моделі
    removed, missing = [], []
    for name in args.remove:
        real = resolve(name, arm)
        (removed.append(real) if real else missing.append(name))
    for name in missing:
        print("  [!] кістки «%s» у моделі немає — пропускаю "
              "(перевір дамп через --list: імпортер gltf інколи додає суфікси)" % name)
    if not removed:
        sys.exit("[!] жодної з --remove кісток немає в моделі; нічого робити")
    print("  прибираю: %s" % ", ".join(removed))

    merge_weights(arm, meshes, removed, args.legs, args.merge)
    delete_bones(arm, removed)

    if args.report:
        after = vert_counts(meshes, arm)
        print("  вершини на кістку (було → стало, «ваг / головна»):")
        for name in sorted(before):
            a0, d0 = before[name]
            a1, d1 = after.get(name, (0, 0))
            flag = "  ← прибрана" if name in removed else ("  ← +%d" % (d1 - d0) if d1 != d0 else "")
            print("    %-16s %5d/%-5d → %5d/%-5d%s" % (name, a0, d0, a1, d1, flag))
        print("  кістки після чистки (%d): %s"
              % (len(arm.data.bones), ", ".join(b.name for b in arm.data.bones)))

    if args.dry_run:
        print("  --dry-run: файл не пишу")
        return

    if os.path.abspath(src) == dst:
        bak = dst + ".bak"
        shutil.copy2(dst, bak)
        print("  бекап: %s" % bak)

    export(dst)
    print("  записано: %s (%.1f КБ)" % (dst, os.path.getsize(dst) / 1024.0))
    print("  далі: godot --headless --import  і  RIG=unicorn godot res://src/debug/voxel_preview.tscn")


if __name__ == "__main__":
    main()
