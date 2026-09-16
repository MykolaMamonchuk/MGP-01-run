#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_nature.py — зібрати природу геометрією: дерева, кущі, квіти, гриби, каміння.

Навіщо. На першому рівні 37 видів із 44 досі малюються вокселем, і поруч зі справжніми
моделями кубики читаються як брак. Чекати на згенеровані моделі для кожної квітки довго,
а половина цих речей — прості тіла обертання: стовбур і крона, ніжка й капелюшок, стебло
й пелюстки. Вони чесно збираються скриптом за секунди й виходять саме такими, як вимагає
арт-напрям: м'який ручний low-poly без текстур, самими кольорами.

Що НЕ треба робити скриптом: тварин, будівлі з характером, усе, де форма нерегулярна.
Там потрібен генератор моделей, і черга на нього лишається в docs/tasks/props.md.

    /Applications/Blender.app/Contents/MacOS/Blender --background --python tools/make_nature.py -- \\
        --kind tree_round --out assets/props/tree_round.glb --height 2.2

Види: tree_round · tree · pine · bush · flower · mushroom · rock · hay_bale
"""
import argparse
import math
import sys

import bpy
import bmesh


def parse_args(argv):
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--height", type=float, default=2.0)
    ap.add_argument("--main", default="")      ## основний колір (крона, пелюстки, капелюшок)
    ap.add_argument("--second", default="")    ## додатковий (стовбур, стебло, ніжка)
    ap.add_argument("--seed", type=int, default=1)
    return ap.parse_args(argv)


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def mat(name, hexcode):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    h = hexcode.lstrip("#")
    rgb = [srgb_to_linear(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4)]
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Roughness"].default_value = 0.9
    return m


def add(primitive, material, **kw):
    primitive(**kw)
    o = bpy.context.active_object
    o.data.materials.append(material)
    return o


## Пом'яти форму випадковим зсувом вершин. Саме це відрізняє «камінь» від «кулі»: ідеальні
## тіла обертання в цьому стилі виглядають як заготовка, а не як предмет.
def jitter(obj, amount, seed):
    import random
    rnd = random.Random(seed)
    for v in obj.data.vertices:
        v.co.x += rnd.uniform(-amount, amount)
        v.co.y += rnd.uniform(-amount, amount)
        v.co.z += rnd.uniform(-amount, amount) * 0.6


def build(kind, h, main, second, seed):
    C = bpy.ops.mesh
    if kind in ("tree_round", "tree"):
        trunk_h = h * 0.42
        add(C.primitive_cylinder_add, mat("bark", second), vertices=7,
            radius=h * 0.055, depth=trunk_h, location=(0, 0, trunk_h * 0.5))
        crown = add(C.primitive_ico_sphere_add, mat("leaf", main), subdivisions=2,
                    radius=h * 0.30, location=(0, 0, trunk_h + h * 0.26))
        crown.scale = (1.0, 1.0, 0.85)
        jitter(crown, h * 0.035, seed)
    elif kind == "pine":
        trunk_h = h * 0.26
        add(C.primitive_cylinder_add, mat("bark", second), vertices=6,
            radius=h * 0.045, depth=trunk_h, location=(0, 0, trunk_h * 0.5))
        for i in range(3):
            t = float(i) / 3.0
            add(C.primitive_cone_add, mat("needle", main), vertices=8,
                radius1=h * (0.26 - 0.06 * i), depth=h * 0.34,
                location=(0, 0, trunk_h + h * (0.14 + 0.24 * t)))
    elif kind == "bush":
        for i, (dx, dy, r) in enumerate(((0, 0, 0.52), (0.42, 0.18, 0.38), (-0.38, -0.22, 0.34))):
            b = add(C.primitive_ico_sphere_add, mat("leaf", main), subdivisions=2,
                    radius=h * r, location=(dx * h, dy * h, h * (0.42 if i == 0 else 0.32)))
            b.scale = (1.0, 1.0, 0.8)
            jitter(b, h * 0.05, seed + i)
    elif kind == "flower":
        add(C.primitive_cylinder_add, mat("stem", second), vertices=5,
            radius=h * 0.035, depth=h * 0.7, location=(0, 0, h * 0.35))
        for i in range(5):
            a = TAU_5 * i
            p = add(C.primitive_ico_sphere_add, mat("petal", main), subdivisions=1,
                    radius=h * 0.17, location=(math.cos(a) * h * 0.16, math.sin(a) * h * 0.16, h * 0.78))
            p.scale = (1.0, 1.0, 0.45)
        add(C.primitive_ico_sphere_add, mat("heart", "#F7E06A"), subdivisions=1,
            radius=h * 0.09, location=(0, 0, h * 0.82))
    elif kind == "mushroom":
        add(C.primitive_cylinder_add, mat("stem", second), vertices=7,
            radius=h * 0.16, depth=h * 0.55, location=(0, 0, h * 0.28))
        cap = add(C.primitive_ico_sphere_add, mat("cap", main), subdivisions=2,
                  radius=h * 0.40, location=(0, 0, h * 0.58))
        cap.scale = (1.0, 1.0, 0.62)
        for i, (dx, dy) in enumerate(((0.16, 0.10), (-0.18, 0.06), (0.02, -0.20))):
            add(C.primitive_ico_sphere_add, mat("spot", "#FFFFFF"), subdivisions=1,
                radius=h * 0.075, location=(dx * h, dy * h, h * 0.78))
    elif kind == "rock":
        r = add(C.primitive_ico_sphere_add, mat("stone", main), subdivisions=1,
                radius=h * 0.55, location=(0, 0, h * 0.38))
        r.scale = (1.25, 1.0, 0.78)
        jitter(r, h * 0.13, seed)
    elif kind == "hay_bale":
        b = add(C.primitive_cylinder_add, mat("hay", main), vertices=10,
                radius=h * 0.52, depth=h * 0.9, location=(0, 0, h * 0.5))
        b.rotation_euler = (math.pi * 0.5, 0, 0)
        for z in (-0.22, 0.22):
            add(C.primitive_torus_add, mat("rope", second), major_radius=h * 0.53,
                minor_radius=h * 0.035, major_segments=10, minor_segments=5,
                location=(0, z * h, h * 0.5), rotation=(math.pi * 0.5, 0, 0))
    elif kind == "arch":
        # Орієнтир над дорогою: дві опори й перекладина. Стоїть ПОПЕРЕК смуги руху, тож
        # ширина задається окремо від висоти — інакше низька арка виходила б вузькою.
        w = h * 1.5
        for sx in (-1, 1):
            add(C.primitive_cube_add, mat("pillar", main), size=1.0,
                location=(sx * w * 0.5, 0, h * 0.5)).scale = (h * 0.16, h * 0.16, h * 0.5)
        add(C.primitive_cube_add, mat("beam", second), size=1.0,
            location=(0, 0, h * 0.92)).scale = (w * 0.5 + h * 0.16, h * 0.13, h * 0.09)
        add(C.primitive_cube_add, mat("pillar", main), size=1.0,
            location=(0, 0, h * 1.05)).scale = (w * 0.30, h * 0.16, h * 0.06)
    elif kind == "gate_post":
        # Стовп воріт: база, стовбур зі звуженням, пояс і шапка. Раніше це був стос
        # кубиків різного кольору — читався як технічна заготовка, а не як ворота свята.
        add(C.primitive_cylinder_add, mat("stone", second), vertices=8,
            radius=h * 0.115, depth=h * 0.07, location=(0, 0, h * 0.035))
        add(C.primitive_cylinder_add, mat("post", main), vertices=8,
            radius=h * 0.075, depth=h * 0.88, location=(0, 0, h * 0.47))
        add(C.primitive_torus_add, mat("stone", second), major_radius=h * 0.085,
            minor_radius=h * 0.022, major_segments=8, minor_segments=5, location=(0, 0, h * 0.62))
        add(C.primitive_cone_add, mat("stone", second), vertices=8,
            radius1=h * 0.13, depth=h * 0.13, location=(0, 0, h * 0.97))
    elif kind == "tower":
        # Вежа-орієнтир: круглий стовбур, що звужується догори, пояс і конічний дах.
        # Раніше під цією назвою стояла арка — збоку від дороги вона читалась як голий
        # стовп, бо в арки збоку й видно лише опору.
        add(C.primitive_cylinder_add, mat("stone", main), vertices=9,
            radius=h * 0.20, depth=h * 0.62, location=(0, 0, h * 0.31))
        add(C.primitive_cylinder_add, mat("stone", main), vertices=9,
            radius=h * 0.155, depth=h * 0.26, location=(0, 0, h * 0.75))
        add(C.primitive_torus_add, mat("belt", second), major_radius=h * 0.205,
            minor_radius=h * 0.028, major_segments=9, minor_segments=5, location=(0, 0, h * 0.62))
        add(C.primitive_cone_add, mat("roof", second), vertices=9,
            radius1=h * 0.24, depth=h * 0.28, location=(0, 0, h * 1.02))
        for i in range(3):
            a = math.pi * 2.0 / 3.0 * i
            add(C.primitive_cube_add, mat("window", "#63C7E8"), size=1.0,
                location=(math.cos(a) * h * 0.20, math.sin(a) * h * 0.20, h * 0.46)
                ).scale = (h * 0.05, h * 0.05, h * 0.09)
    elif kind == "post_line":
        # Два стовпи з натягнутою линвою: мотузка з білизною, гірлянда прапорців.
        w = h * 1.6
        # Стовпи ТОНКІ. Були 0,05 від висоти — на зріст 1,3 м це 13 см у діаметрі, тобто
        # брус, а не жердина: у грі вони читались як голі планки посеред траси, і замовник
        # питав, що це взагалі таке. Плюс маленька шапка, щоб стовп мав верх.
        for sx in (-1, 1):
            add(C.primitive_cylinder_add, mat("pole", second), vertices=6,
                radius=h * 0.022, depth=h, location=(sx * w * 0.5, 0, h * 0.5))
            add(C.primitive_cone_add, mat("pole", second), vertices=6,
                radius1=h * 0.038, depth=h * 0.055, location=(sx * w * 0.5, 0, h * 1.02))
        add(C.primitive_cube_add, mat("line", main), size=1.0,
            location=(0, 0, h * 0.88)).scale = (w * 0.5, h * 0.012, h * 0.012)
        # Прапорці РІЗНОКОЛЬОРОВІ. Раніше всі брали один головний колір, і для мотузки з
        # білизною це давало п'ять однакових білих трикутників — у яскравій дитячій палітрі
        # вони читались як дірка, а не як прикраса.
        tints = ("#F07FAE", "#F5D34E", "#63C7E8", "#8FD16A", "#F2A0C0")
        for i in range(5):
            t = (i - 2) / 2.0
            add(C.primitive_cone_add, mat("flag%d" % i, tints[i]), vertices=3,
                radius1=h * 0.11, depth=h * 0.18,
                location=(t * w * 0.38, 0, h * 0.79), rotation=(math.pi, 0, 0))
    elif kind == "xbox":
        # Ящик із великим білим хрестом на передній грані — «сюди не можна».
        add(C.primitive_cube_add, mat("crate", main), size=1.0,
            location=(0, 0, h * 0.5)).scale = (h * 0.5, h * 0.5, h * 0.5)
        for sgn in (1, -1):
            add(C.primitive_cube_add, mat("cross", "#FFFFFF"), size=1.0,
                location=(0, -h * 0.51, h * 0.5),
                rotation=(0, sgn * math.pi * 0.25, 0)).scale = (h * 0.52, h * 0.02, h * 0.07)
    elif kind == "goose":
        # Гуска: тіло, шия, голова, дзьоб, дві лапки. Очей НЕ малюємо — їх малює гра.
        body = add(C.primitive_ico_sphere_add, mat("feather", main), subdivisions=2,
                   radius=h * 0.34, location=(0, 0, h * 0.42))
        body.scale = (0.85, 1.25, 0.9)
        add(C.primitive_cylinder_add, mat("feather", main), vertices=7,
            radius=h * 0.09, depth=h * 0.40, location=(0, -h * 0.20, h * 0.68))
        add(C.primitive_ico_sphere_add, mat("feather", main), subdivisions=2,
            radius=h * 0.15, location=(0, -h * 0.22, h * 0.88))
        add(C.primitive_cone_add, mat("beak", second), vertices=6,
            radius1=h * 0.07, depth=h * 0.16,
            location=(0, -h * 0.36, h * 0.86), rotation=(math.pi * 0.5, 0, 0))
        for sx in (-1, 1):
            add(C.primitive_cylinder_add, mat("beak", second), vertices=5,
                radius=h * 0.035, depth=h * 0.18, location=(sx * h * 0.12, 0, h * 0.09))
    else:
        raise SystemExit("невідомий вид: %s" % kind)


TAU_5 = math.pi * 2.0 / 5.0

DEFAULTS = {
    "tree_round": ("#5FA845", "#7A4A2A"), "tree": ("#4E9A3C", "#7A4A2A"),
    "pine": ("#2F7A48", "#6B4327"), "bush": ("#5BA34A", "#4C8C3E"),
    "flower": ("#F2A0C0", "#5FA845"), "mushroom": ("#D9503F", "#F1E4C8"),
    "rock": ("#A8ADB3", "#8E949B"), "hay_bale": ("#D9B65C", "#B08840"),
    "arch": ("#C97B5A", "#8D5524"), "gate_post": ("#C9A45C", "#8D5524"), "tower": ("#EFDDBC", "#C1452F"), "post_line": ("#E8F1E4", "#7A4A2A"),
    "xbox": ("#C1452F", "#FFFFFF"), "goose": ("#F7F3E8", "#E8A33D"),
}


def main():
    a = parse_args(sys.argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    dm, ds = DEFAULTS.get(a.kind, ("#5FA845", "#7A4A2A"))
    build(a.kind, a.height, a.main or dm, a.second or ds, a.seed)

    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:
        o.select_set(True)
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    # початок координат — унизу по центру, як вимагає гра (пропс ставиться на землю)
    lo = min((ob.matrix_world @ v.co).z for v in ob.data.vertices)
    cx = sum((ob.matrix_world @ v.co).x for v in ob.data.vertices) / len(ob.data.vertices)
    cy = sum((ob.matrix_world @ v.co).y for v in ob.data.vertices) / len(ob.data.vertices)
    for v in ob.data.vertices:
        w = ob.matrix_world @ v.co
        v.co = (w.x - cx, w.y - cy, w.z - lo)
    ob.matrix_basis.identity()

    bpy.ops.export_scene.gltf(filepath=a.out, export_format="GLB")
    print("  %s: %d граней → %s" % (a.kind, len(ob.data.polygons), a.out))


main()
