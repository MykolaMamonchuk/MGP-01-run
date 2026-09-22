# Що насправді в матеріалах пропса: однотонний колір чи текстура?
import bpy, sys, os
argv = sys.argv[sys.argv.index("--") + 1:]
for src in argv:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(src))
    print("МАТ === %s" % os.path.basename(src))
    seen = set()
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        has_vcol = len(ob.data.color_attributes) > 0
        print("МАТ   меш %s: вершинні кольори %s, слотів %d" % (ob.name, has_vcol, len(ob.material_slots)))
        for slot in ob.material_slots:
            m = slot.material
            if m is None or m.name in seen:
                continue
            seen.add(m.name)
            col, tex = None, []
            if m.use_nodes:
                for n in m.node_tree.nodes:
                    if n.type == "BSDF_PRINCIPLED":
                        c = n.inputs["Base Color"]
                        if not c.is_linked:
                            col = tuple(round(v, 3) for v in c.default_value[:3])
                    if n.type == "TEX_IMAGE" and n.image is not None:
                        tex.append(n.image.name)
            print("МАТ      %-28s колір %s  текстури %s" % (m.name, col, tex or "нема"))
